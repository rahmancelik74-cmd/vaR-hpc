#include "mc/data.hpp"
#include <cmath>
#include <iostream>
#include <sstream>
#include <stdexcept>

namespace {
void close(double a, double b, double tol, const char* name) {
    if (!std::isfinite(a) || std::abs(a-b) > tol) throw std::runtime_error(name);
}
template<class F> void rejects(F f, const char* name) {
    bool threw = false;
    try { f(); } catch (const std::exception&) { threw = true; }
    if (!threw) throw std::runtime_error(name);
}
auto parse(const std::string& text) {
    std::istringstream input(text);
    return mc::read_prices_csv(input);
}
}
int main() {
    try {
        // Independent fixture: log returns .01, .02, .03; mean .02,
        // unbiased sample variance .0001 (not population .0000666...).
        const std::vector<mc::PriceObservation> prices{
            {"2026-01-01", 100}, {"2026-01-02", 100*std::exp(.01)},
            {"2026-01-05", 100*std::exp(.03)}, {"2026-01-06", 100*std::exp(.06)}};
        const auto fitted = mc::calibrate(prices, 252, 10, 2);
        if (fitted.returns_count != 3) throw std::runtime_error("return count");
        close(fitted.mean_log_return, .02, 1e-14, "mean log return");
        close(fitted.sample_log_variance, .0001, 1e-14, "sample variance denominator");
        close(fitted.model.volatility, std::sqrt(.0252), 1e-12, "annual volatility");
        close(fitted.model.drift, 5.04 + .0126, 1e-12, "price drift variance correction");
        close(fitted.model.initial_value, 200*std::exp(.06), 1e-12, "latest close and units");
        close(fitted.model.horizon, 10.0/252, 1e-15, "trading-day horizon");
        const auto flat = parse("date,close\n2026-01-01,100\n2026-01-02,100\n2026-01-05,100\n");
        close(mc::calibrate(flat).model.volatility, 0, 0, "flat price volatility");
        close(mc::analytical_var(mc::calibrate(flat).model, .99), 0, 0, "flat price VaR");
        const auto bom = parse("\xEF\xBB\xBF" "date,close\r\n2024-02-28,100\r\n2024-02-29,101\r\n2024-03-01,99\r\n");
        if (bom.size() != 3) throw std::runtime_error("BOM CRLF leap date");
        rejects([]{ parse("date,close\n2026-01-01,100\n"); }, "insufficient observations");
        rejects([]{ parse("date,close\n2026-01-01,100\n2026-01-01,101\n2026-01-02,102\n"); }, "duplicate date");
        rejects([]{ parse("date,close\n2026-01-02,100\n2026-01-01,101\n2026-01-03,102\n"); }, "out of order");
        rejects([]{ parse("date,close\n2026-02-29,100\n2026-03-01,101\n2026-03-02,102\n"); }, "invalid calendar date");
        rejects([]{ parse("date,close\n2026-01-01,0\n2026-01-02,101\n2026-01-03,102\n"); }, "zero close");
        rejects([]{ parse("date,close\n2026-01-01,-1\n2026-01-02,101\n2026-01-03,102\n"); }, "negative close");
        rejects([]{ parse("date,close\n2026-01-01,100oops\n2026-01-02,101\n2026-01-03,102\n"); }, "numeric trailing text");
        rejects([]{ parse("date,close\n2026-01-01,nan\n2026-01-02,101\n2026-01-03,102\n"); }, "NaN");
        rejects([]{ parse("date,close\n2026-01-01,1e999\n2026-01-02,101\n2026-01-03,102\n"); }, "overflow");
        rejects([]{ parse("date,close\n2026-01-01,100,20\n2026-01-02,101\n2026-01-03,102\n"); }, "extra column");
        rejects([]{ parse("Date,Close\n2026-01-01,100\n"); }, "wrong header");
        rejects([]{ parse("date,close\n\n"); }, "blank record");
        rejects([&]{ mc::calibrate(prices, 0); }, "invalid time scale");
        rejects([&]{ mc::calibrate(prices, 252, 0); }, "invalid horizon");
        rejects([&]{ mc::calibrate(prices, 252, 10, -1); }, "short position excluded");
        rejects([]{ mc::load_prices_csv("__no_such_file__.csv"); }, "missing file");
        std::cout << "All CSV and calibration tests passed.\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Test failure: " << e.what() << '\n';
        return 1;
    }
}
