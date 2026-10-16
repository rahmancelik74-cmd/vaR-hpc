#include "mc/openmp.hpp"
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>

namespace {
void check(bool ok, const char* message) {
    if (!ok) throw std::runtime_error(message);
}
void equal(const mc::Result& a, const mc::Result& b) {
    check(a.estimates.size() == b.estimates.size(), "estimate count");
    for (std::size_t i = 0; i < a.estimates.size(); ++i)
        check(a.estimates[i].confidence == b.estimates[i].confidence &&
              a.estimates[i].var == b.estimates[i].var, "estimates must agree exactly");
}
template<class Exception, class F> void rejects(F f) {
    bool caught = false;
    try { f(); } catch (const Exception&) { caught = true; }
    check(caught, "expected exception type was not propagated");
}
}
int main() {
    try {
        mc::Request r;
        // Boundary sizes, a single scenario, complete and partial blocks.
        for (std::size_t n : {1u, 5u, 4095u, 4096u, 4097u, 10000u}) {
            r.scenarios = n;
            r.confidence_levels = {.5, .6, .95, .99};
            std::vector<double> common(n);
            for (std::size_t i = 0; i < n; ++i)
                common[i] = static_cast<double>(i % 101) / 10.0 - 5.0;
            const auto original = common;
            const auto serial = mc::SerialEngine().run(r, &common);
            const auto native = mc::OpenMPEngine(1).run(r);
            for (int threads : {1, 2, 4, 8, 10}) {
                const mc::OpenMPEngine engine(threads);
                const auto shared = engine.run(r, &common);
                equal(serial, shared);
                check(common == original, "caller inputs modified");
                check(shared.random_source == "common-host-inputs", "common RNG label");
                const auto a = engine.run(r);
                equal(native, a);
                equal(a, engine.run(r));
                check(a.requested_threads == threads && a.threads_used >= 1 &&
                      a.threads_used <= threads && a.openmp_version > 0 &&
                      a.end_to_end_ms >= 0 && a.backend == "openmp", "runtime metadata");
            }
        }
        r.scenarios = 8193;
        r.seed = 0;
        const auto zero_seed = mc::OpenMPEngine(1).run(r);
        equal(zero_seed, mc::OpenMPEngine(10).run(r));
        r.seed = 1;
        const auto other_seed = mc::OpenMPEngine(4).run(r);
        check(zero_seed.estimates.back().var != other_seed.estimates.back().var,
              "native stream must depend on run seed");
        r.seed = (std::numeric_limits<std::uint64_t>::max)();
        equal(mc::OpenMPEngine(1).run(r), mc::OpenMPEngine(10).run(r));
        r.scenarios = 4097;
        for (bool zero_horizon : {false, true}) {
            r.model = {};
            if (zero_horizon) r.model.horizon = 0;
            else r.model.volatility = 0;
            const auto a = mc::OpenMPEngine(4).run(r);
            for (const auto& e : a.estimates)
                check(e.var == mc::scenario_loss(r.model, 0), "deterministic edge case");
        }
        r.model = {};
        const mc::OpenMPEngine engine(4);
        rejects<std::invalid_argument>([]{ mc::OpenMPEngine invalid(-1); });
        std::vector<double> common(r.scenarios, 0);
        auto short_input = common; short_input.pop_back();
        rejects<std::invalid_argument>([&]{ engine.run(r, &short_input); });
        // Invalid value in the partial block must escape via worker exception capture.
        common.back() = std::numeric_limits<double>::quiet_NaN();
        rejects<std::invalid_argument>([&]{ engine.run(r, &common); });
        common.back() = std::numeric_limits<double>::infinity();
        rejects<std::invalid_argument>([&]{ engine.run(r, &common); });
        common.back() = 1e308;
        rejects<std::overflow_error>([&]{ engine.run(r, &common); });
        equal(mc::OpenMPEngine(1).run(r), engine.run(r)); // Recovery after failed runs.
        r.model.drift = 1e308;
        rejects<std::overflow_error>([&]{ engine.run(r); });
        r.model = {}; r.model.volatility = -1;
        rejects<std::invalid_argument>([&]{ engine.run(r); });
        r.model = {}; r.scenarios = 0;
        rejects<std::invalid_argument>([&]{ engine.run(r); });
        r.scenarios = 1; r.confidence_levels.clear();
        rejects<std::invalid_argument>([&]{ engine.run(r); });
        for (double c : {0.0, 1.0, -1.0, std::numeric_limits<double>::quiet_NaN()}) {
            r.confidence_levels = {c};
            rejects<std::invalid_argument>([&]{ engine.run(r); });
        }
        std::cout << "OpenMP common-input, native determinism and failure tests passed.\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Test failure: " << e.what() << '\n';
        return 1;
    }
}
