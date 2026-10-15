#include "mc/data.hpp"
#include <cmath>
#include <fstream>
#include <locale>
#include <sstream>
#include <stdexcept>

namespace mc {
namespace {
std::string trim(const std::string& s) {
    const auto first = s.find_first_not_of(" \t\r");
    if (first == std::string::npos) return {};
    return s.substr(first, s.find_last_not_of(" \t\r") - first + 1);
}
bool valid_date(const std::string& s) {
    if (s.size() != 10 || s[4] != '-' || s[7] != '-') return false;
    for (std::size_t i = 0; i < s.size(); ++i)
        if (i != 4 && i != 7 && (s[i] < '0' || s[i] > '9')) return false;
    const int year = std::stoi(s.substr(0, 4));
    const int month = std::stoi(s.substr(5, 2));
    const int day = std::stoi(s.substr(8, 2));
    if (year == 0 || month < 1 || month > 12) return false;
    const int days[] = {31,28,31,30,31,30,31,31,30,31,30,31};
    const bool leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    return day >= 1 && day <= days[month - 1] + (month == 2 && leap ? 1 : 0);
}
void validate_observation(const PriceObservation& p, const std::string& previous) {
    if (!valid_date(p.date)) throw std::invalid_argument("Invalid date; expected YYYY-MM-DD");
    if (!previous.empty() && p.date <= previous)
        throw std::invalid_argument("Dates must be unique and strictly increasing");
    if (!std::isfinite(p.close) || p.close <= 0.0)
        throw std::invalid_argument("Closing prices must be finite and positive");
}
}
std::vector<PriceObservation> read_prices_csv(std::istream& input) {
    std::string line;
    if (!std::getline(input, line)) throw std::invalid_argument("Empty CSV");
    // UTF-8 BOM and CRLF accepted; other dialects explicitly unsupported.
    if (line.compare(0, 3, "\xEF\xBB\xBF") == 0) line.erase(0, 3);
    if (trim(line) != "date,close")
        throw std::invalid_argument("CSV header must be date,close");
    std::vector<PriceObservation> prices;
    std::size_t line_number = 1;
    while (std::getline(input, line)) {
        ++line_number;
        try {
            const auto comma = line.find(',');
            if (comma == std::string::npos || line.find(',', comma + 1) != std::string::npos)
                throw std::invalid_argument("Expected exactly two CSV fields");
            PriceObservation p{trim(line.substr(0, comma)), 0.0};
            const auto value = trim(line.substr(comma + 1));
            std::istringstream number(value);
            number.imbue(std::locale::classic());
            if (!(number >> p.close)) throw std::invalid_argument("Invalid close value");
            number >> std::ws;
            if (!number.eof()) throw std::invalid_argument("Trailing text in close value");
            validate_observation(p, prices.empty() ? "" : prices.back().date);
            prices.push_back(p);
        } catch (const std::exception& e) {
            throw std::invalid_argument("CSV line " + std::to_string(line_number) + ": " + e.what());
        }
    }
    if (input.bad()) throw std::runtime_error("CSV read failed");
    if (prices.size() < 3)
        throw std::invalid_argument("At least three prices are needed for sample variance");
    return prices;
}
std::vector<PriceObservation> load_prices_csv(const std::string& path) {
    std::ifstream file(path);
    if (!file) throw std::runtime_error("Cannot open CSV: " + path);
    return read_prices_csv(file);
}
Calibration calibrate(const std::vector<PriceObservation>& prices,
                      double days_per_year, double horizon_days, double units) {
    if (prices.size() < 3) throw std::invalid_argument("At least three prices required");
    if (!std::isfinite(days_per_year) || days_per_year <= 0 ||
        !std::isfinite(horizon_days) || horizon_days <= 0 ||
        !std::isfinite(units) || units <= 0)
        throw std::invalid_argument("Trading-day scale, horizon and units must be positive");
    double mean = 0.0, m2 = 0.0;
    std::size_t n = 0;
    std::string previous;
    for (std::size_t i = 0; i < prices.size(); ++i) {
        validate_observation(prices[i], previous);
        previous = prices[i].date;
        if (i == 0) continue;
        // Log difference avoids overflow in a ratio of extreme valid prices.
        const double r = std::log(prices[i].close) - std::log(prices[i-1].close);
        ++n;
        const double delta = r - mean;
        mean += delta / static_cast<double>(n);
        m2 += delta * (r - mean);
    }
    const double variance = m2 / static_cast<double>(n - 1);
    const double annual_variance = variance * days_per_year;
    const Model model{prices.back().close * units,
                      mean * days_per_year + 0.5 * annual_variance,
                      std::sqrt(annual_variance), horizon_days / days_per_year};
    validate_model(model);
    return {model, n, mean, variance};
}
} // namespace mc
