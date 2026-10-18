#include "mc/output.hpp"
#include <iostream>
#include <limits>
#include <locale>
#include <sstream>
#include <stdexcept>

namespace {
void check(bool ok, const char* message) {
    if (!ok) throw std::runtime_error(message);
}
class CommaDecimal : public std::numpunct<char> {
    char do_decimal_point() const override { return ','; }
};
}
int main() {
    try {
        mc::Request request;
        request.seed = std::numeric_limits<std::uint64_t>::max();
        request.model.volatility = 0;
        const std::vector<double> normals(request.scenarios, 0);
        auto result = mc::SerialEngine().run(request, &normals);
        result.backend = "test\"\\\n";
        std::ostringstream out;
        out.imbue(std::locale(std::locale::classic(), new CommaDecimal));
        mc::write_run_json(out, request, result);
        const auto text = out.str();
        check(text.find("\"application_version\":\"0.3.0\"") != std::string::npos,
              "application version");
        check(text.find("\"requested_threads\":0,\"threads_used\":1,\"openmp_version\":0")
              != std::string::npos, "serial thread metadata");
        check(text.find("\"seed\":\"18446744073709551615\"") != std::string::npos,
              "uint64 seed must remain exact");
        check(text.find("test\\\"\\\\\\u000a") != std::string::npos, "JSON escaping");
        check(text.find("\"drift_annual\":0.05") != std::string::npos, "locale-independent numbers");
        check(text.find("\"calibration\":null") != std::string::npos, "demo metadata");
        check(text.find("\"cuda\":null") != std::string::npos, "CPU CUDA metadata is null");
        check(text.find("\"mc_var\":-") != std::string::npos, "negative VaR preserved");
        mc::CsvMetadata csv{3, 2, "2026-01-01", "2026-01-05", 0, 0, 10, 252};
        std::ostringstream csv_out;
        mc::write_run_json(csv_out, request, result, &csv);
        check(csv_out.str().find("\"observations\":3") != std::string::npos, "CSV metadata");
        result.cuda.emplace();
        result.cuda->device_name = "GPU\"test";
        result.cuda->cub_version = 300403;
        std::ostringstream device_out;
        mc::write_run_json(device_out, request, result);
        check(device_out.str().find("GPU\\\"test") != std::string::npos, "CUDA device JSON escaping");
        check(device_out.str().find("\"host_sorting_used\":false") != std::string::npos, "GPU quantile contract");
        check(device_out.str().find("\"milestone\":\"full_device_scale_up\"") != std::string::npos, "CUDA milestone");
        check(device_out.str().find("\"scenario_limit\":10000000") != std::string::npos, "CUDA support limit");
        check(device_out.str().find("\"allocation_budget_limit_bytes\":0") != std::string::npos, "CUDA budget metadata");
        result.cuda->mode="hybrid";
        result.cuda->requested_batch_size=3; result.cuda->effective_batch_size=4; result.cuda->batch_count=3;
        std::ostringstream hybrid_out; mc::write_run_json(hybrid_out,request,result);
        check(hybrid_out.str().find("\"quantile_location\":\"host\"") != std::string::npos
            && hybrid_out.str().find("\"host_sorting_used\":true") != std::string::npos
            && hybrid_out.str().find("\"requested_batch_size\":3,\"effective_batch_size\":4,\"batch_count\":3") != std::string::npos,
            "Hybrid quantile and batch output");
        result.cuda->host_to_device_ms = std::numeric_limits<double>::infinity();
        std::ostringstream bad_device;
        bool bad_device_threw = false;
        try { mc::write_run_json(bad_device, request, result); }
        catch (const std::invalid_argument&) { bad_device_threw = true; }
        check(bad_device_threw && bad_device.str().empty(), "invalid transfer time must not emit partial JSON");
        result.cuda.reset();
        result.estimates[0].var = std::numeric_limits<double>::infinity();
        std::ostringstream invalid;
        bool threw = false;
        try { mc::write_run_json(invalid, request, result); }
        catch (const std::invalid_argument&) { threw = true; }
        check(threw && invalid.str().empty(), "invalid JSON must not be partially emitted");
        std::cout << "All JSON output tests passed.\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Test failure: " << e.what() << '\n';
        return 1;
    }
}
