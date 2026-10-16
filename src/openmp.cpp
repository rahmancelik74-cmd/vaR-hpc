#include "mc/openmp.hpp"
#include <omp.h>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <exception>
#include <limits>
#include <random>
#include <stdexcept>

namespace mc {
namespace {
// SplitMix64 finalizer after adding a block-specific Weyl increment.
std::uint64_t block_seed(std::uint64_t seed, std::uint64_t block) {
    auto value = seed + UINT64_C(0x9e3779b97f4a7c15) * (block + 1);
    value = (value ^ (value >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    value = (value ^ (value >> 27)) * UINT64_C(0x94d049bb133111eb);
    return value ^ (value >> 31);
}
}
OpenMPEngine::OpenMPEngine(int threads) : requested_threads_(threads) {
    if (threads < 0) throw std::invalid_argument("Requested threads cannot be negative");
}
Result OpenMPEngine::run(const Request& r, const std::vector<double>* common) const {
    validate_model(r.model);
    if (r.scenarios == 0 || r.confidence_levels.empty())
        throw std::invalid_argument("Nonzero scenarios and confidence levels required");
    for (double c : r.confidence_levels)
        if (!std::isfinite(c) || c <= 0 || c >= 1)
            throw std::invalid_argument("Probability must be finite and in (0,1)");
    if (common && common->size() != r.scenarios)
        throw std::invalid_argument("Common input count must equal scenario count");
    constexpr std::size_t block_size = 4096;
    const auto blocks = 1 + (r.scenarios - 1) / block_size;
    if (blocks > static_cast<std::size_t>((std::numeric_limits<long long>::max)()))
        throw std::invalid_argument("Scenario count too large");
    const auto start = std::chrono::steady_clock::now();
    Result result;
    {
        result.backend = "openmp";
        result.random_source = common ? "common-host-inputs" :
            "block4096/splitmix64/mt19937_64/std::normal_distribution";
        result.requested_threads = requested_threads_;
        result.openmp_version = _OPENMP;
        std::vector<double> losses(r.scenarios);
        std::exception_ptr failure;
        const int team_size = requested_threads_ ? requested_threads_ : omp_get_max_threads();
        // Signed canonical loop and critical/single work with MSVC OpenMP 2.0.
#pragma omp parallel num_threads(team_size)
        {
#pragma omp single
            result.threads_used = omp_get_num_threads();
#pragma omp for schedule(static)
            for (long long block = 0; block < static_cast<long long>(blocks); ++block) {
                try {
                    std::mt19937_64 rng(block_seed(r.seed, static_cast<std::uint64_t>(block)));
                    std::normal_distribution<double> normal(0.0, 1.0);
                    const auto begin = static_cast<std::size_t>(block) * block_size;
                    const auto count = (std::min)(block_size, r.scenarios - begin);
                    for (std::size_t offset = 0; offset < count; ++offset) {
                        const auto i = begin + offset;
                        losses[i] = scenario_loss(r.model, common ? (*common)[i] : normal(rng));
                    }
                } catch (...) {
#pragma omp critical(mc_worker_failure)
                    {
                        if (!failure) failure = std::current_exception();
                    }
                }
            }
        }
        if (failure) std::rethrow_exception(failure);
        // Only generation is parallel. Quantiles currently use serial sorting.
        std::sort(losses.begin(), losses.end());
        for (double c : r.confidence_levels)
            result.estimates.push_back({c, sorted_quantile(losses, c)});
    }
    result.end_to_end_ms = std::chrono::duration<double, std::milli>(
        std::chrono::steady_clock::now() - start).count();
    return result;
}
} // namespace mc
