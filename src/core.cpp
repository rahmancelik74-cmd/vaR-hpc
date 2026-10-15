#include "mc/core.hpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <random>
#include <stdexcept>

namespace mc {
namespace {
void validate_probability(double p) {
    if (!std::isfinite(p) || p <= 0.0 || p >= 1.0)
        throw std::invalid_argument("Probability must be finite and in (0,1)");
}
}
void validate_model(const Model& m) {
    if (!std::isfinite(m.initial_value) || m.initial_value <= 0.0 ||
        !std::isfinite(m.drift) || !std::isfinite(m.volatility) ||
        m.volatility < 0.0 || !std::isfinite(m.horizon) || m.horizon < 0.0)
        throw std::invalid_argument("Invalid GBM model parameters");
}
double normal_quantile(double p) {
    validate_probability(p);
    // Solve the lower-tail CDF using erfc and bisection. No MC dependency.
    double lo = -40.0, hi = 40.0;
    for (int i = 0; i < 120; ++i) {
        const double mid = (lo + hi) / 2.0;
        const double cdf = 0.5 * std::erfc(-mid / std::sqrt(2.0));
        if (cdf < p) lo = mid; else hi = mid;
    }
    return (lo + hi) / 2.0;
}
double analytical_var(const Model& m, double confidence) {
    validate_model(m);
    validate_probability(confidence);
    const double exponent = (m.drift - 0.5 * m.volatility * m.volatility) * m.horizon
        + m.volatility * std::sqrt(m.horizon) * normal_quantile(1.0 - confidence);
    const double loss = -m.initial_value * std::expm1(exponent);
    if (!std::isfinite(loss)) throw std::overflow_error("Analytical VaR overflow");
    return loss; // Not clipped at zero; sign convention is explicit.
}
double scenario_loss(const Model& m, double z) {
    validate_model(m);
    if (!std::isfinite(z)) throw std::invalid_argument("Normal input must be finite");
    const double exponent = (m.drift - 0.5 * m.volatility * m.volatility) * m.horizon
        + m.volatility * std::sqrt(m.horizon) * z;
    const double loss = -m.initial_value * std::expm1(exponent);
    if (!std::isfinite(loss)) throw std::overflow_error("Scenario loss overflow");
    return loss;
}
double sorted_quantile(const std::vector<double>& losses, double confidence) {
    validate_probability(confidence);
    if (losses.empty()) throw std::invalid_argument("Empty loss sample");
    // Preconditions: finite values, sorted ascending. Nearest-rank quantile.
    const double rank = std::ceil(confidence * static_cast<double>(losses.size()));
    const auto index = static_cast<std::size_t>(rank) - 1;
    return losses.at(std::min(index, losses.size() - 1));
}
Result SerialEngine::run(const Request& r, const std::vector<double>* common) const {
    validate_model(r.model);
    if (r.scenarios == 0 || r.confidence_levels.empty())
        throw std::invalid_argument("Nonzero scenarios and confidence levels required");
    for (double c : r.confidence_levels) validate_probability(c);
    if (common && common->size() != r.scenarios)
        throw std::invalid_argument("Common input count must equal scenario count");
    // Parsed model already available; allocations, RNG, sort and buffer
    // destruction are included. CLI printing and input parsing are excluded.
    const auto start = std::chrono::steady_clock::now();
    Result result;
    {
        result.backend = "serial";
        result.random_source = common ? "common-host-inputs" : "mt19937_64/std::normal_distribution";
        std::vector<double> losses(r.scenarios);
        std::mt19937_64 rng(r.seed);
        std::normal_distribution<double> normal(0.0, 1.0);
        for (std::size_t i = 0; i < r.scenarios; ++i)
            losses[i] = scenario_loss(r.model, common ? (*common)[i] : normal(rng));
        std::sort(losses.begin(), losses.end());
        for (double c : r.confidence_levels)
            result.estimates.push_back({c, sorted_quantile(losses, c)});
    }
    result.end_to_end_ms = std::chrono::duration<double, std::milli>(
        std::chrono::steady_clock::now() - start).count();
    return result;
}
} // namespace mc
