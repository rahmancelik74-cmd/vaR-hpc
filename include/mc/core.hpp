#pragma once
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace mc {
struct Model {
    double initial_value = 100.0; // Positive long holding, V0 = units * S0.
    double drift = 0.05;         // Price drift per year, not mean log return.
    double volatility = 0.20;   // Per sqrt(year).
    double horizon = 1.0;       // Years; demo default, not an approved horizon.
};
struct Request {
    Model model;
    std::size_t scenarios = 10000;
    std::uint64_t seed = 42;
    std::vector<double> confidence_levels{0.95, 0.99};
};
struct Estimate { double confidence; double var; };
struct Result {
    std::string backend;
    std::string random_source;
    std::vector<Estimate> estimates;
    double end_to_end_ms = 0.0;
    int requested_threads = 0; // Zero means runtime default; serial always uses one.
    int threads_used = 1;
    int openmp_version = 0; // _OPENMP date value; zero for serial.
};
// A backend owns RNG, buffers, simulation, quantile and synchronization.
// No per-scenario CPU callback and no mandatory host loss vector.
// common_normals is validation-only; caller retains ownership for the call.
class Engine {
public:
    virtual ~Engine() = default;
    virtual Result run(const Request& request,
                       const std::vector<double>* common_normals = nullptr) const = 0;
};
class SerialEngine final : public Engine {
public:
    Result run(const Request& request,
               const std::vector<double>* common_normals = nullptr) const override;
};
void validate_model(const Model& model);
double normal_quantile(double probability);
double analytical_var(const Model& model, double confidence);
double scenario_loss(const Model& model, double normal);
double sorted_quantile(const std::vector<double>& sorted_losses, double confidence);
} // namespace mc
