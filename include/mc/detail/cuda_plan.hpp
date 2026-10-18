#pragma once
#include <cmath>
#include <cstddef>
#include <limits>
#include <stdexcept>
#include <string>

// CUDA-independent planning helpers, also tested in CPU-only builds.
namespace mc { namespace detail {
inline constexpr std::size_t cuda_scenario_limit = 10000000;
inline constexpr std::size_t cuda_confidence_limit = 16;
inline constexpr unsigned cuda_loss_threads = 256;

inline std::size_t checked_add(std::size_t a, std::size_t b) {
    if (b > (std::numeric_limits<std::size_t>::max)() - a)
        throw std::overflow_error("CUDA size addition overflow");
    return a + b;
}
inline std::size_t checked_multiply(std::size_t a, std::size_t b) {
    if (a != 0 && b > (std::numeric_limits<std::size_t>::max)() / a)
        throw std::overflow_error("CUDA byte multiplication overflow");
    return a * b;
}
inline int checked_int(std::size_t value) {
    if (value > static_cast<std::size_t>((std::numeric_limits<int>::max)()))
        throw std::overflow_error("CUDA count exceeds int range");
    return static_cast<int>(value);
}
inline void validate_cuda_counts(std::size_t n, std::size_t k) {
    if (n == 0 || n > cuda_scenario_limit)
        throw std::invalid_argument("CUDA requires 1 through 10000000 scenarios");
    if (k == 0 || k > cuda_confidence_limit)
        throw std::invalid_argument("CUDA requires 1 through 16 confidence levels");
}
inline std::size_t normal_count(std::size_t n, bool common) {
    return common ? n : checked_add(n, n % 2);
}
inline std::size_t hybrid_batch_size(std::size_t n, std::size_t requested, bool common) {
    if (n == 0 || n > cuda_scenario_limit || requested == 0 || requested > cuda_scenario_limit)
        throw std::invalid_argument("Hybrid CUDA batch size must be 1 through 10000000");
    // Interior native batches consume even counts; only the total request's tail is padded.
    const auto rounded = common ? requested : normal_count(requested, false);
    return rounded < n ? rounded : n;
}
inline std::size_t hybrid_device_bytes(std::size_t normals, std::size_t losses) {
    return checked_add(checked_add(checked_multiply(normals, sizeof(double)),
        checked_multiply(losses, sizeof(double))), sizeof(int));
}
inline std::size_t host_loss_storage(std::size_t n, std::size_t max_count) {
    const auto bytes = checked_multiply(n, sizeof(double));
    if (n > max_count) throw std::length_error("Hybrid host loss count exceeds vector capacity");
    return bytes;
}
inline std::size_t explicit_device_bytes(std::size_t normals, std::size_t n,
                                         std::size_t k, std::size_t workspace) {
    auto bytes = checked_multiply(normals, sizeof(double));
    bytes = checked_add(bytes, checked_multiply(checked_multiply(n, 2), sizeof(double)));
    bytes = checked_add(bytes, checked_multiply(k, sizeof(double)));
    bytes = checked_add(bytes, checked_multiply(k, sizeof(std::size_t)));
    bytes = checked_add(bytes, sizeof(int));
    return checked_add(bytes, workspace == 0 ? 1 : workspace);
}
inline std::size_t memory_budget_80pct(std::size_t free_bytes) {
    // floor(4*free/5), without overflow or floating-point rounding.
    return (free_bytes / 5) * 4 + ((free_bytes % 5) * 4) / 5;
}
inline void require_memory_budget(std::size_t required, std::size_t available) {
    const auto limit = memory_budget_80pct(available);
    if (required > limit)
        throw std::runtime_error("CUDA explicit allocation budget " + std::to_string(required)
            + " bytes exceeds 80% of free device memory (" + std::to_string(limit) + " bytes)");
}
inline unsigned loss_blocks(std::size_t n, int max_grid_x, int max_block_x, int max_threads) {
    const auto blocks = checked_add(n, cuda_loss_threads - 1) / cuda_loss_threads;
    // Bound the largest launched index before the kernel's unsigned-to-int conversion.
    checked_int(checked_multiply(blocks, cuda_loss_threads));
    if (blocks == 0 || max_grid_x <= 0 || blocks > static_cast<std::size_t>(max_grid_x)
        || max_block_x < static_cast<int>(cuda_loss_threads)
        || max_threads < static_cast<int>(cuda_loss_threads))
        throw std::runtime_error("CUDA device launch dimensions do not support this request");
    return static_cast<unsigned>(checked_int(blocks));
}
inline std::size_t quantile_index(double confidence, std::size_t n) {
    if (n == 0 || n > cuda_scenario_limit || !std::isfinite(confidence)
        || confidence <= 0 || confidence >= 1)
        throw std::invalid_argument("Invalid CUDA quantile request");
    const double rank = std::ceil(confidence * static_cast<double>(n));
    if (!std::isfinite(rank) || rank < 1 || rank > static_cast<double>(n))
        throw std::overflow_error("CUDA quantile rank is out of range");
    return static_cast<std::size_t>(rank) - 1;
}
} } // namespace mc::detail
