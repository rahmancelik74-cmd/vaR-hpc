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
        check(text.find("\"mc_var\":-") != std::string::npos, "negative VaR preserved");
        mc::CsvMetadata csv{3, 2, "2026-01-01", "2026-01-05", 0, 0, 10, 252};
        std::ostringstream csv_out;
        mc::write_run_json(csv_out, request, result, &csv);
        check(csv_out.str().find("\"observations\":3") != std::string::npos, "CSV metadata");
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
