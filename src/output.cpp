#include "mc/output.hpp"
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
}
void write_run_json(std::ostream& output, const Request& r,
                    const Result& result, const CsvMetadata* csv) {
    validate_model(r.model);
    if (!std::isfinite(result.end_to_end_ms) || result.end_to_end_ms < 0)
        throw std::invalid_argument("Invalid elapsed time");
    std::ostringstream out;
    out.imbue(std::locale::classic());
    out << std::setprecision(17);
    out << "{\"schema_version\":1,\"application_version\":\"0.2.2\",\"backend\":";
    string_value(out, result.backend);
    out << ",\"random_source\":";
    string_value(out, result.random_source);
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
