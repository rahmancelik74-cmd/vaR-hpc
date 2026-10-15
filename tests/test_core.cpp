#include "mc/core.hpp"
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>

namespace {
void check(bool ok, const char* name) {
    if (!ok) throw std::runtime_error(name);
}
void close(double a, double b, double tolerance, const char* name) {
    check(std::isfinite(a) && std::abs(a - b) <= tolerance, name);
}
template<class F> void rejects(F f, const char* name) {
    bool threw = false;
    try { f(); } catch (const std::exception&) { threw = true; }
    check(threw, name);
}
}
int main() {
    try {
        close(mc::normal_quantile(0.5), 0.0, 1e-12, "normal median");
        close(mc::normal_quantile(0.01), -2.3263478740408408, 1e-12, "normal 1% reference");
        close(mc::normal_quantile(0.05), -1.6448536269514722, 1e-12, "normal 5% reference");
        const std::vector<double> ordered{-3, -2, 0, 4, 8};
        close(mc::sorted_quantile(ordered, 0.6), 0, 0, "nearest rank");
        close(mc::sorted_quantile(ordered, 0.99), 8, 0, "tail rank");
        mc::Model m;
        m.horizon = 0;
        close(mc::analytical_var(m, 0.99), 0, 0, "zero horizon");
        m.horizon = 1;
        m.volatility = 0;
        close(mc::analytical_var(m, 0.95), 100 * (1 - std::exp(0.05)), 1e-12, "deterministic GBM");
        check(mc::analytical_var(m, 0.99) < 0, "negative VaR is not clipped");
        mc::Request r;
        r.scenarios = 5;
        r.confidence_levels = {0.6, 0.99};
        const std::vector<double> normals{-2, -1, 0, 1, 2};
        const mc::SerialEngine serial;
        const mc::Engine& engine = serial;
        const auto result = engine.run(r, &normals);
        close(result.estimates[0].var, -100 * std::expm1(0.03), 1e-12, "common median loss");
        close(result.estimates[1].var, -100 * std::expm1(-0.37), 1e-12, "common tail loss");
        check(result.end_to_end_ms >= 0, "nonnegative timing");
        const auto a = engine.run(r);
        const auto b = engine.run(r);
        close(a.estimates[1].var, b.estimates[1].var, 0, "same-build seed reproducibility");
        rejects([]{ mc::normal_quantile(1); }, "bad confidence");
        const std::vector<double> short_inputs{0};
        rejects([&]{ engine.run(r, &short_inputs); }, "input size mismatch");
        rejects([]{ mc::sorted_quantile({}, .95); }, "empty losses");
        r.scenarios = 0;
        rejects([&]{ engine.run(r); }, "zero scenarios");
        m.volatility = -1;
        rejects([&]{ mc::analytical_var(m, .95); }, "negative volatility");
        rejects([]{ mc::scenario_loss({}, std::numeric_limits<double>::quiet_NaN()); }, "NaN input");
        std::cout << "All core tests passed.\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Test failure: " << e.what() << '\n';
        return 1;
    }
}
