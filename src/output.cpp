#include "mc/output.hpp"
#include "mc/detail/cuda_plan.hpp"
#include "mc/version.hpp"
#include <cmath>
#include <iomanip>
#include <locale>
#include <ostream>
#include <sstream>
#include <stdexcept>

namespace mc {
namespace {
void string_value(std::ostream& out, const std::string& value) {
    out << '"';
    const char* hex = "0123456789abcdef";
    for (unsigned char c : value) {
        if (c == '"' || c == '\\') out << '\\' << static_cast<char>(c);
        else if (c < 32 || c >= 127)
            out << "\\u00" << hex[c >> 4] << hex[c & 15];
        else out << static_cast<char>(c);
    }
    out << '"';
}
void number(std::ostream& out, double value) {
    if (!std::isfinite(value)) throw std::invalid_argument("Nonfinite JSON number");
    out << value;
}
void cuda_metadata(std::ostream& out, const CudaMetadata& c) {
    const bool hybrid = c.mode == "hybrid";
    out << "{\"milestone\":";
    string_value(out, hybrid ? "hybrid_batching" : "full_device_scale_up");
    out << ",\"mode\":"; string_value(out, c.mode);
    out << ",\"quantile_location\":"; string_value(out, hybrid ? "host" : "device");
    out << ",\"requested_batch_size\":" << c.requested_batch_size
        << ",\"effective_batch_size\":" << c.effective_batch_size << ",\"batch_count\":" << c.batch_count
        << ",\"normals_generated\":" << c.normals_generated << ",\"host_loss_bytes\":" << c.host_loss_bytes
        << ",\"losses_transferred\":" << c.losses_transferred
        << ",\"rng_partition_policy\":";
    string_value(out, hybrid ? "One persistent PHILOX generator; even interior calls; final total-request padding only; call partition is part of RNG configuration, no batch-size invariance promised"
        : "One PHILOX normal-double call; final total-request padding only");
    out << ",\"scenario_limit\":"
        << detail::cuda_scenario_limit << ",\"device\":";
    string_value(out, c.device_name);
    out << ",\"compute_major\":" << c.compute_major << ",\"compute_minor\":" << c.compute_minor
        << ",\"nvcc_version\":"; string_value(out, c.compiler_version);
    out << ",\"driver_api_version\":" << c.driver_api_version << ",\"runtime_version\":" << c.runtime_version
        << ",\"runtime_header_version\":" << c.runtime_header_version << ",\"curand_header_version\":";
    string_value(out, c.curand_header_version);
    out << ",\"curand_runtime_version\":" << c.curand_runtime_version
        << ",\"quantile_library\":";
    string_value(out, hybrid ? "std::sort<double> and shared sorted_quantile over all N host losses"
        : "CUB DeviceRadixSort::SortKeys<double> and device nearest-rank gather");
    out << ",\"cub_version\":" << c.cub_version << ",\"host_sorting_used\":" << (hybrid ? "true" : "false")
        << ",\"host_to_device_ms\":"; number(out, c.host_to_device_ms);
    out << ",\"device_to_host_ms\":"; number(out, c.device_to_host_ms);
    out << ",\"host_to_device_bytes\":" << c.host_to_device_bytes << ",\"device_to_host_bytes\":" << c.device_to_host_bytes
        << ",\"transfer_timer\":\"Sum of CUDA Event copy intervals on the engine stream across all batches; pageable host staging is included only in primary wall time\""
        << ",\"normals_allocated\":" << c.normals_allocated << ",\"cub_temporary_bytes\":" << c.cub_temporary_bytes
        << ",\"explicit_device_bytes\":" << c.explicit_device_bytes << ",\"total_vram_bytes\":" << c.total_vram_bytes
        << ",\"free_before_bytes\":" << c.free_before_bytes << ",\"free_with_pipeline_bytes\":" << c.free_with_pipeline_bytes
        << ",\"allocation_budget_limit_bytes\":" << c.allocation_budget_limit_bytes
        << ",\"capacity_policy\":";
    string_value(out, hybrid ? "Reject three explicit batch buffers exceeding floor(4*free_before_bytes/5); queried after context/stream/events, before buffer allocation; excludes host losses, opaque library/context allocations and other GPU activity; not a capacity guarantee"
        : "Reject explicit buffers exceeding floor(4*free_before_bytes/5); queried after context, stream, events and CUB storage query, before pipeline allocation; excludes opaque library/context allocations and other GPU activity; not a capacity guarantee");
    if (c.diagnostics) {
        const auto& d = *c.diagnostics;
        out << ",\"diagnostics\":{\"schema_version\":1,\"enabled\":true";
        out << ",\"initialization_ms\":"; number(out, d.initialization_ms);
        out << ",\"rng_ms\":"; number(out, d.rng_ms);
        out << ",\"loss_ms\":"; number(out, d.loss_ms);
        out << ",\"cub_ms\":"; number(out, d.cub_ms);
        out << ",\"gather_ms\":"; number(out, d.gather_ms);
        out << ",\"pipeline_span_ms\":"; number(out, d.pipeline_span_ms);
        out << ",\"host_quantile_ms\":"; number(out, d.host_quantile_ms);
        out << ",\"covered_device_stage_sum_ms\":";
        number(out, d.initialization_ms + d.rng_ms + d.loss_ms + d.cub_ms + d.gather_ms);
        out << ",\"initialization_intervals\":" << d.initialization_intervals
            << ",\"rng_intervals\":" << d.rng_intervals << ",\"loss_intervals\":" << d.loss_intervals
            << ",\"cub_intervals\":" << d.cub_intervals << ",\"gather_intervals\":" << d.gather_intervals;
        out << ",\"scope\":\"Same-stream Event intervals; stage durations summed across batches; initialization is device error-flag memset only; RNG includes device work enqueued by generation call, not host generator setup; span from first pipeline enqueue through final required D2H, includes host submission gaps; excludes allocations/context/cleanup and hybrid host quantile\""
            << ",\"transfer_excluded_scope\":\"Explicit initialization+RNG+loss+CUB+gather Event sum; excludes copies, host setup/quantile/staging, allocation, context, cleanup and gaps between intervals; not host wall time minus copies\"}";
    }
    out << '}';
}
}
void write_run_json(std::ostream& output, const Request& r,
                    const Result& result, const CsvMetadata* csv) {
    validate_model(r.model);
    if (!std::isfinite(result.end_to_end_ms) || result.end_to_end_ms < 0)
        throw std::invalid_argument("Invalid elapsed time");
    std::ostringstream out;
    out.imbue(std::locale::classic());
    out << std::setprecision(17);
    out << "{\"schema_version\":1,\"application_version\":\"" MC_APPLICATION_VERSION "\",\"backend\":";
    string_value(out, result.backend);
    out << ",\"random_source\":";
    string_value(out, result.random_source);
    out << ",\"requested_threads\":" << result.requested_threads
        << ",\"threads_used\":" << result.threads_used
        << ",\"openmp_version\":" << result.openmp_version;
    out << ",\"cuda\":";
    if (result.cuda) cuda_metadata(out, *result.cuda); else out << "null";
    // Strings avoid precision loss for uint64 seeds in JSON consumers.
    out << ",\"scenarios\":" << r.scenarios << ",\"seed\":\"" << r.seed << '"';
    out << ",\"input_mode\":\"" << (csv ? "csv_calibration" : "fixed_parameter_demo") << '"';
    out << ",\"model\":{\"initial_value\":";
    number(out, r.model.initial_value);
    out << ",\"drift_annual\":"; number(out, r.model.drift);
    out << ",\"volatility_annual\":"; number(out, r.model.volatility);
    out << ",\"horizon_years\":"; number(out, r.model.horizon);
    out << "},\"calibration\":";
    if (!csv) out << "null";
    else {
        out << "{\"observations\":" << csv->observations
            << ",\"returns_count\":" << csv->returns_count << ",\"date_start\":";
        string_value(out, csv->date_start);
        out << ",\"date_end\":"; string_value(out, csv->date_end);
        out << ",\"mean_log_return\":"; number(out, csv->mean_log_return);
        out << ",\"sample_log_variance\":"; number(out, csv->sample_log_variance);
        out << ",\"horizon_trading_days\":" << csv->horizon_trading_days
            << ",\"trading_days_per_year\":" << csv->trading_days_per_year << '}';
    }
    out << ",\"estimates\":[";
    bool first = true;
    for (const auto& e : result.estimates) {
        const double reference = analytical_var(r.model, e.confidence);
        if (!first) out << ',';
        first = false;
        out << "{\"confidence\":"; number(out, e.confidence);
        out << ",\"mc_var\":"; number(out, e.var);
        out << ",\"analytical_var\":"; number(out, reference);
        out << ",\"signed_error\":"; number(out, e.var - reference);
        out << '}';
    }
    out << "],\"end_to_end_ms\":"; number(out, result.end_to_end_ms);
    out << ",\"timing_scope\":\"engine_including_allocation_rng_simulation_quantile_cleanup\""
        << ",\"market_predictive_validity_claimed\":false}\n";
    output << out.str();
}
} // namespace mc
