#include "mc/cuda.hpp"
#include "mc/data.hpp"
#include "mc/detail/cuda_plan.hpp"
#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <limits>
#include <locale>
#include <sstream>
#include <stdexcept>

namespace {
void check(bool ok, const char* label) { if (!ok) throw std::runtime_error(label); }
template<class E, class F> void rejects(F f) {
    bool threw = false;
    try { f(); } catch (const E&) { threw = true; }
    check(threw, "Expected CUDA error was not propagated");
}
}
int main(int argc, char** argv) {
    try {
        const bool scale_common = argc == 2 && std::string(argv[1]) == "--scale-common";
        if (argc > 1 && !scale_common) throw std::invalid_argument("Expected --scale-common or no arguments");
        const mc::CudaEngine gpu;
        std::ostringstream evidence;
        evidence.imbue(std::locale::classic()); evidence << std::setprecision(17);
        evidence << "{\"purpose\":\"Common-input numerical checks, separate from native cuRAND smoke\",\"cases\":[";
        bool first = true;
        auto compare = [&](const char* label, const mc::Request& request, const std::vector<double>& inputs) {
            const auto original = inputs;
            const auto serial = mc::SerialEngine().run(request, &inputs);
            const auto device = gpu.run(request, &inputs);
            check(original == inputs, "Common inputs modified");
            check(device.cuda.has_value() && device.random_source == "common-host-inputs", "Common CUDA metadata missing");
            const auto& metadata = *device.cuda;
            check(metadata.host_to_device_bytes == inputs.size()*sizeof(double)+request.confidence_levels.size()*sizeof(std::size_t), "H2D accounting");
            check(metadata.device_to_host_bytes == sizeof(int)+request.confidence_levels.size()*sizeof(double), "D2H accounting");
            check(metadata.explicit_device_bytes == mc::detail::explicit_device_bytes(inputs.size(),
                inputs.size(), request.confidence_levels.size(), metadata.cub_temporary_bytes), "Exact workspace accounting");
            check(metadata.allocation_budget_limit_bytes == mc::detail::memory_budget_80pct(metadata.free_before_bytes)
                && metadata.explicit_device_bytes <= metadata.allocation_budget_limit_bytes, "Memory preflight accounting");
            for (std::size_t i = 0; i < serial.estimates.size(); ++i) {
                const auto cpu = serial.estimates[i].var, value = device.estimates[i].var;
                const double tolerance = 1e-10*(std::max)(1.0, std::abs(cpu));
                check(std::isfinite(value) && std::abs(cpu-value) <= tolerance, "CPU/GPU common-input quantile differs");
                check(std::abs(cpu-value) <= .00001*request.model.initial_value, "Project common-input tolerance exceeded");
                if (!first) evidence << ','; first = false;
                evidence << "{\"case\":\"" << label << "\",\"scenarios\":" << request.scenarios
                    << ",\"confidence\":" << serial.estimates[i].confidence << ",\"serial_var\":" << cpu
                    << ",\"cuda_var\":" << value << ",\"absolute_difference\":" << std::abs(cpu-value)
                    << ",\"tolerance\":" << tolerance << ",\"project_tolerance\":" << .00001*request.model.initial_value
                    << ",\"host_to_device_ms\":" << metadata.host_to_device_ms
                    << ",\"device_to_host_ms\":" << metadata.device_to_host_ms
                    << ",\"host_to_device_bytes\":" << metadata.host_to_device_bytes
                    << ",\"device_to_host_bytes\":" << metadata.device_to_host_bytes
                    << ",\"cub_temporary_bytes\":" << metadata.cub_temporary_bytes
                    << ",\"explicit_device_bytes\":" << metadata.explicit_device_bytes << ",\"passed\":true}";
            }
        };
        std::vector<std::size_t> sizes{1,5,256,257,9999,10000,10001};
        if (scale_common) sizes = {100000,1000000,10000000};
        for (std::size_t n : sizes) {
            mc::Request r; r.scenarios = n; r.confidence_levels = {.5,.6,.95,.99};
            std::vector<double> inputs(n);
            for (std::size_t i = 0; i < n; ++i) inputs[i] = (static_cast<int>(i*37%101)-50)/10.0;
            compare("signed_losses_ties_and_partial_blocks",r,inputs);
        }
        mc::Request r; r.scenarios = 5; r.confidence_levels = {.6,.99};
        const std::vector<double> fixed{-2,-1,0,1,2};
        compare("known_nearest_rank_fixture",r,fixed);
        r.model.horizon = 0; compare("zero_horizon",r,fixed);
        r.model = {}; r.model.volatility = 0; compare("zero_volatility_negative_var",r,fixed);
        r.model = {}; r.model.drift = 0; r.model.volatility = 0; compare("all_zero_losses",r,fixed);
        const auto prices = mc::load_prices_csv("data/synthetic_prices.csv");
        r.model = mc::calibrate(prices).model; r.scenarios = 10000; r.confidence_levels = {.95,.99};
        std::vector<double> common(r.scenarios);
        for (std::size_t i = 0; i < common.size(); ++i) common[i] = (static_cast<int>(i*37%101)-50)/10.0;
        compare("shared_csv_calibration",r,common);
        auto bad = common; bad.pop_back(); rejects<std::invalid_argument>([&]{gpu.run(r,&bad);});
        common.back() = std::numeric_limits<double>::quiet_NaN();
        rejects<std::invalid_argument>([&]{gpu.run(r,&common);});
        common.back() = std::numeric_limits<double>::infinity();
        rejects<std::invalid_argument>([&]{gpu.run(r,&common);});
        common.back() = 1e308; rejects<std::overflow_error>([&]{gpu.run(r,&common);});
        common.back() = 0; compare("recovery_after_device_rejection",r,common);
        r.scenarios = 0; rejects<std::invalid_argument>([&]{gpu.run(r);});
        r.scenarios = 10000001; rejects<std::invalid_argument>([&]{gpu.run(r);});
        r.scenarios = (std::numeric_limits<std::size_t>::max)();
        rejects<std::invalid_argument>([&]{gpu.run(r);});
        r.scenarios = 5; r.confidence_levels.clear(); rejects<std::invalid_argument>([&]{gpu.run(r);});
        r.confidence_levels.assign(16, .95); compare("maximum_confidence_count",r,fixed);
        r.confidence_levels.push_back(.99); rejects<std::invalid_argument>([&]{gpu.run(r);});
        for (double c : {0.0,1.0,std::numeric_limits<double>::quiet_NaN()}) {
            r.confidence_levels = {c}; rejects<std::invalid_argument>([&]{gpu.run(r);});
        }
        r.confidence_levels = {.95}; r.model.volatility = -1; rejects<std::invalid_argument>([&]{gpu.run(r);});
        evidence << "],\"invalid_input_and_recovery_checks_passed\":true,\"fixture\":\"z[i]=((i*37 mod 101)-50)/10; explicit five-value fixture uses [-2,-1,0,1,2]\"}\n";
        std::cout << evidence.str();
        return 0;
    } catch (const std::exception& e) { std::cerr << "CUDA test failure: " << e.what() << '\n'; return 1; }
}
