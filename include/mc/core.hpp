#pragma once
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace mc {
struct Portfolio;
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
    // Optional borrowed portfolio, immutable for the duration of Engine::run.
    const Portfolio* portfolio = nullptr;
};
struct Estimate { double confidence; double var; };
struct CudaDiagnostics {
    double initialization_ms = 0, rng_ms = 0, loss_ms = 0, cub_ms = 0, gather_ms = 0;
    double pipeline_span_ms = 0, host_quantile_ms = 0;
    std::size_t initialization_intervals = 0, rng_intervals = 0, loss_intervals = 0;
    std::size_t cub_intervals = 0, gather_intervals = 0;
};
struct CudaMetadata {
    int portfolio_assets = 0;
    std::optional<CudaDiagnostics> diagnostics;
    std::string mode = "full-device";
    std::size_t requested_batch_size = 0, effective_batch_size = 0, batch_count = 0;
    std::size_t normals_generated = 0, host_loss_bytes = 0, losses_transferred = 0;
    std::string device_name, compiler_version, curand_header_version;
    int compute_major = 0, compute_minor = 0;
    int driver_api_version = 0, runtime_version = 0, runtime_header_version = 0;
    int curand_runtime_version = 0, cub_version = 0;
    double host_to_device_ms = 0, device_to_host_ms = 0;
    std::size_t host_to_device_bytes = 0, device_to_host_bytes = 0;
    std::size_t normals_allocated = 0, cub_temporary_bytes = 0, explicit_device_bytes = 0;
    std::size_t total_vram_bytes = 0, free_before_bytes = 0, free_with_pipeline_bytes = 0;
    std::size_t allocation_budget_limit_bytes = 0;
};
struct Result {
    std::string backend;
    std::string random_source;
    std::vector<Estimate> estimates;
    double end_to_end_ms = 0.0;
    int requested_threads = 0; // Zero means runtime default; serial always uses one.
    int threads_used = 1;
    int openmp_version = 0; // _OPENMP date value; zero for serial.
    std::optional<CudaMetadata> cuda;
};
// A backend owns RNG, buffers, simulation, quantile and synchronization.
// No per-scenario CPU callback and no mandatory host loss vector.
// common_normals is validation-only; caller retains ownership for the call.
// Portfolio layout: exactly scenarios * asset_count, scenario major.
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
