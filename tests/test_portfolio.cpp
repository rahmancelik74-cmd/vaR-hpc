#include "mc/portfolio.hpp"
#include "mc/output.hpp"
#ifdef MC_HAS_OPENMP
#include "mc/openmp.hpp"
#endif
#ifdef MC_HAS_CUDA
#include "mc/cuda.hpp"
#endif
#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <limits>
#include <random>
#include <sstream>
#include <stdexcept>

namespace {
void require(bool ok, const char* message) {
    if (!ok) throw std::runtime_error(message);
}
template<class F> void rejects(F operation) {
    bool rejected = false;
    try { operation(); } catch (const std::exception&) { rejected = true; }
    require(rejected, "Expected portfolio rejection");
}
mc::Portfolio fixture(int n, double rho = 0) {
    mc::Portfolio p;
    p.unit = "USD"; p.horizon = 0.5;
    for (int i = 0; i < n; ++i)
        p.assets.push_back({"A"+std::to_string(i), 2.0+i, 100.0-10*i, .03+.01*i, .15+.03*i});
    for (int i = 0; i < n; ++i) for (int j = 0; j < n; ++j)
        p.correlation.push_back(i == j ? 1 : rho);
    return p;
}
// Test-only sample summary. Native test RNG -> production transform/valuation;
// Python uses independent exact Gaussian/lognormal moments, no production oracle.
void samples() {
    constexpr int n = 200000;
    std::cout << std::setprecision(17);
    for (double rho : {0.0, 0.6, -0.3}) {
        const auto p = fixture(3, rho);
        const auto b = mc::prepare_portfolio(p);
        std::mt19937_64 rng(20261025);
        std::normal_distribution<double> normal;
        long double sums[11]{};
        for (int s = 0; s < n; ++s) {
            double e[3], z[3];
            for (auto& x : e) x = normal(rng);
            mc::portfolio_shocks(b, e, z);
            for (int i = 0; i < 3; ++i) sums[i] += z[i];
            int k = 3;
            for (int i = 0; i < 3; ++i) for (int j = i; j < 3; ++j) sums[k++] += z[i]*z[j];
            const double vt = b.initial_value-mc::portfolio_loss(b, e);
            sums[9] += vt; sums[10] += static_cast<long double>(vt)*vt;
        }
        std::cout << rho;
        for (auto x : sums) std::cout << ' ' << static_cast<double>(x/n);
        std::cout << '\n';
    }
}
void structural() {
    auto p = fixture(2, .6);
    auto b = mc::prepare_portfolio(p);
    require(std::abs(b.factor[5]-.6) < 1e-15 && std::abs(b.factor[6]-.8) < 1e-15, "Known factor");
    const double independent[2]{1,0}; double correlated[2];
    mc::portfolio_shocks(b, independent, correlated);
    require(correlated[0] == 1 && correlated[1] == .6, "Explicit C times epsilon orientation");
    for (int i = 0; i < 2; ++i) for (int j = 0; j < 2; ++j) {
        double x = 0;
        for (int k = 0; k < 2; ++k) x += b.factor[i*5+k]*b.factor[j*5+k];
        require(std::abs(x-p.correlation[i*2+j]) < 1e-14, "Reconstruction");
    }
    auto bad = [&](auto mutate) { auto q = p; mutate(q); rejects([&] { mc::prepare_portfolio(q); }); };
    bad([](auto& q) { q.assets.clear(); });
    bad([](auto& q) { q.assets.resize(6); });
    bad([](auto& q) { q.correlation.pop_back(); });
    bad([](auto& q) { q.assets[1].id = q.assets[0].id; });
    bad([](auto& q) { q.unit = ""; });
    bad([](auto& q) { q.correlation[1] = .5; });
    bad([](auto& q) { q.correlation[0] = .99; });
    bad([](auto& q) { q.correlation[1] = q.correlation[2] = 1.01; });
    bad([](auto& q) { q.correlation[1] = q.correlation[2] = -1.01; });
    bad([](auto& q) { q.correlation[1] = q.correlation[2] = 1; });
    bad([](auto& q) { q.correlation[1] = q.correlation[2] = .999999999999999; });
    for (double x : {std::numeric_limits<double>::quiet_NaN(), std::numeric_limits<double>::infinity()}) {
        bad([&](auto& q) { q.correlation[1] = x; });
        bad([&](auto& q) { q.assets[0].drift = x; });
        bad([&](auto& q) { q.assets[0].quantity = x; });
        bad([&](auto& q) { q.assets[0].price = x; });
        bad([&](auto& q) { q.assets[0].volatility = x; });
        bad([&](auto& q) { q.horizon = x; });
    }
    bad([](auto& q) { q.assets[0].quantity = 0; });
    bad([](auto& q) { q.assets[0].price = -1; });
    bad([](auto& q) { q.assets[0].volatility = -1; });
    bad([](auto& q) { q.horizon = -1; });
    bad([](auto& q) { q.assets[0].quantity = 1e308; });
    auto indefinite = fixture(3, -.9);
    rejects([&] { mc::prepare_portfolio(indefinite); });
    // Explicit independent 2-asset oracle, using terminal values rather than expm1.
    const std::vector<double> epsilon{1,0, 0,1, -1,2, 2,-1, 0,0, -3,-2, .5,-.7, -2,1, 1,1, -1,-1,
        3,0, 0,3, -3,0, 0,-3, .4,.9, -.8,.2, 0.1,-.2, 1.2,2.3, -.5,-1.5, -4,-3};
    std::vector<double> oracle;
    for (std::size_t s = 0; s < epsilon.size()/2; ++s) {
        const double z0 = epsilon[s*2], z1 = .6*z0+.8*epsilon[s*2+1];
        const double vt = 200*std::exp((.03-.15*.15/2)*.5+.15*std::sqrt(.5)*z0)
            +270*std::exp((.04-.18*.18/2)*.5+.18*std::sqrt(.5)*z1);
        oracle.push_back(470-vt);
        require(std::abs(mc::portfolio_loss(b, epsilon.data()+s*2)-oracle.back()) < 1e-10*470, "Independent scenario oracle/orientation");
    }
    std::sort(oracle.begin(), oracle.end());
    mc::Request r; r.portfolio = &p; r.scenarios = 20;
    const auto result = mc::SerialEngine{}.run(r, &epsilon);
    require(std::abs(result.estimates[0].var-oracle[18]) < 1e-10*470, "Independent 95 rank");
    require(std::abs(result.estimates[1].var-oracle[19]) < 1e-10*470, "Independent 99 rank");
    std::ostringstream out; mc::write_run_json(out, r, result);
    require(out.str().find("\"analytical_var\":null") != std::string::npos, "No general analytical VaR");
    r.scenarios = 0; rejects([&] { mc::SerialEngine{}.run(r); });
    r.scenarios = 10000001; rejects([&] { mc::SerialEngine{}.run(r); });
    r.scenarios = (std::numeric_limits<std::size_t>::max)(); rejects([&] { mc::SerialEngine{}.run(r); });
    r.scenarios = 20; r.confidence_levels = {.5}; rejects([&] { mc::SerialEngine{}.run(r); });
    r.confidence_levels = {.95,.99};
    auto e = epsilon; e.pop_back(); rejects([&] { mc::SerialEngine{}.run(r, &e); });
    e = epsilon; e[0] = std::numeric_limits<double>::infinity(); rejects([&] { mc::SerialEngine{}.run(r, &e); });
    p.horizon = 0;
    require(mc::SerialEngine{}.run(r, &epsilon).estimates[0].var == 0, "T=0");
    p.horizon = 1;
    for (auto& a : p.assets) { a.volatility = 0; a.drift = .1; }
    require(std::abs(mc::SerialEngine{}.run(r).estimates[0].var-(470-470*std::exp(.1))) < 1e-10, "Deterministic negative VaR");
    p.assets[0].drift = 1e308;
    rejects([&] { mc::SerialEngine{}.run(r); });
    // One asset reduction and analytical quantile, deterministic normal grid.
    p = fixture(1); p.assets[0] = {"ONE", 1,100,.05,.2}; p.horizon = 1;
    r.scenarios = 1000;
    e.clear(); for (int i = 0; i < 1000; ++i) e.push_back(mc::normal_quantile((i+.5)/1000));
    const auto a = mc::SerialEngine{}.run(r, &e);
    auto single = r; single.portfolio = nullptr;
    const auto c = mc::SerialEngine{}.run(single, &e);
    for (int i = 0; i < 2; ++i) {
        require(a.estimates[i].var == c.estimates[i].var, "One asset exact reduction");
        const auto alpha = a.estimates[i].confidence;
        const auto idx = static_cast<int>(std::ceil(alpha*1000))-1;
        const auto expected = mc::analytical_var(single.model, (idx+.5)/1000);
        require(std::abs(a.estimates[i].var-expected) < 1e-10, "One asset analytical grid");
    }
}
void backends() {
    for (int a : {1,2,3,5}) for (std::size_t n : {1,17,257,4097,10003}) {
        auto p = fixture(a, .2); mc::Request r; r.portfolio = &p; r.scenarios = n;
        std::vector<double> common(n*a);
        std::mt19937_64 rng(81023); std::normal_distribution<double> normal;
        for (auto& x : common) x = normal(rng);
        const auto saved = common;
        const auto reference = mc::SerialEngine{}.run(r, &common);
        const auto v0 = mc::prepare_portfolio(p).initial_value;
        auto compare = [&](const mc::Result& actual) {
            for (int i = 0; i < 2; ++i)
                require(std::abs(actual.estimates[i].var-reference.estimates[i].var) <= 1e-10*v0, "Backend common portfolio mismatch");
        };
#ifdef MC_HAS_OPENMP
        const auto native = mc::OpenMPEngine(1).run(r);
        for (int t : {1,2,4,8,10}) {
            compare(mc::OpenMPEngine(t).run(r, &common));
            const auto next = mc::OpenMPEngine(t).run(r);
            require(next.threads_used == t, "Requested OpenMP team");
            for (int i = 0; i < 2; ++i) require(next.estimates[i].var == native.estimates[i].var, "Native thread invariance");
        }
#endif
#ifdef MC_HAS_CUDA
        compare(mc::CudaEngine{}.run(r, &common));
        const auto native_gpu = mc::CudaEngine{}.run(r);
        require(native_gpu.cuda->normals_generated == (n*a+(n*a)%2), "CUDA normal padding");
        rejects([&] { mc::CudaEngine(mc::CudaMode::Hybrid, 17).run(r); });
        auto invalid = common; invalid[0] = std::numeric_limits<double>::quiet_NaN();
        rejects([&] { mc::CudaEngine{}.run(r, &invalid); });
#endif
        require(common == saved, "Caller input mutated");
    }
    auto p = fixture(3, -.3);
    mc::Request r; r.portfolio = &p; r.scenarios = 17;
    auto check_deterministic = [&](double expected) {
        auto check = [&](const mc::Engine& engine) {
            for (const auto& e : engine.run(r).estimates)
                require(std::abs(e.var-expected) <= 1e-10*790, "Backend deterministic case");
        };
        check(mc::SerialEngine{});
#ifdef MC_HAS_OPENMP
        check(mc::OpenMPEngine(10));
#endif
#ifdef MC_HAS_CUDA
        check(mc::CudaEngine{});
#endif
    };
    p.horizon = 0; check_deterministic(0);
    p.horizon = .5;
    for (auto& asset : p.assets) { asset.volatility = 0; asset.drift = .1; }
    check_deterministic(790*(1-std::exp(.05)));
    p.assets[0].drift = 10000;
#ifdef MC_HAS_OPENMP
    rejects([&] { mc::OpenMPEngine(10).run(r); });
#endif
#ifdef MC_HAS_CUDA
    rejects([&] { mc::CudaEngine{}.run(r); });
#endif
}
}
int main(int argc, char** argv) {
    try {
        if (argc == 2 && std::string(argv[1]) == "--samples") samples();
        else { structural(); backends(); std::cout << "Portfolio structural/backend tests passed\n"; }
        return 0;
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
