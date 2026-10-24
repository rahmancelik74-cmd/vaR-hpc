#include "mc/portfolio.hpp"
#include <cmath>
#include <fstream>
#include <limits>
#include <locale>
#include <set>
#include <stdexcept>

namespace mc {
namespace {
bool token(const std::string& s) {
    return !s.empty() && s.find_first_not_of(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-") == std::string::npos;
}
}
Portfolio load_portfolio(const std::string& path) {
    std::ifstream in(path);
    in.imbue(std::locale::classic());
    Portfolio p;
    std::string magic, trailing;
    int n = 0;
    if (!(in >> magic >> p.unit >> p.horizon >> n) || magic != "portfolio-v1" || n < 1 || n > 5)
        throw std::invalid_argument("Invalid portfolio header: portfolio-v1 UNIT T asset_count");
    for (int i = 0; i < n; ++i) {
        Asset a;
        if (!(in >> a.id >> a.quantity >> a.price >> a.drift >> a.volatility))
            throw std::invalid_argument("Invalid portfolio asset row");
        p.assets.push_back(a);
    }
    for (int i = 0; i < n*n; ++i) {
        double x;
        if (!(in >> x)) throw std::invalid_argument("Invalid portfolio correlation matrix");
        p.correlation.push_back(x);
    }
    if (in >> trailing) throw std::invalid_argument("Unexpected portfolio trailing data");
    prepare_portfolio(p);
    return p;
}
PreparedPortfolio prepare_portfolio(const Portfolio& p) {
    const auto n = p.assets.size();
    if (n < 1 || n > 5 || p.correlation.size() != n*n || !token(p.unit) ||
        !std::isfinite(p.horizon) || p.horizon < 0)
        throw std::invalid_argument("Invalid portfolio dimensions, unit or horizon");
    PreparedPortfolio b;
    b.count = static_cast<int>(n);
    std::set<std::string> ids;
    for (std::size_t i = 0; i < n; ++i) {
        const auto& a = p.assets[i];
        if (!token(a.id) || !ids.insert(a.id).second || !std::isfinite(a.quantity) ||
            a.quantity <= 0 || !std::isfinite(a.price) || a.price <= 0 ||
            !std::isfinite(a.drift) || !std::isfinite(a.volatility) || a.volatility < 0)
            throw std::invalid_argument("Invalid or duplicate portfolio asset");
        b.values[i] = a.quantity * a.price;
        b.initial_value += b.values[i];
        b.drifts[i] = (a.drift - 0.5*a.volatility*a.volatility)*p.horizon;
        b.scales[i] = a.volatility*std::sqrt(p.horizon);
        if (!std::isfinite(b.values[i]) || b.values[i] <= 0 || !std::isfinite(b.initial_value) ||
            !std::isfinite(b.drifts[i]) || !std::isfinite(b.scales[i]))
            throw std::overflow_error("Portfolio parameter arithmetic overflow");
    }
    for (std::size_t i = 0; i < n; ++i)
        for (std::size_t j = 0; j < n; ++j) {
            const double x = p.correlation[i*n+j];
            if (!std::isfinite(x) || x < -1 || x > 1 ||
                (i == j && std::abs(x-1) > correlation_tolerance) ||
                std::abs(x-p.correlation[j*n+i]) > correlation_tolerance)
                throw std::invalid_argument("Invalid correlation bounds, diagonal or symmetry");
        }
    for (std::size_t i = 0; i < n; ++i)
        for (std::size_t j = 0; j <= i; ++j) {
            double x = p.correlation[i*n+j];
            for (std::size_t k = 0; k < j; ++k) x -= b.factor[i*5+k]*b.factor[j*5+k];
            if (i == j) {
                if (!(x > cholesky_pivot_tolerance))
                    throw std::invalid_argument("Correlation is not numerically positive definite");
                b.factor[i*5+j] = std::sqrt(x);
            } else b.factor[i*5+j] = x/b.factor[j*5+j];
        }
    for (std::size_t i = 0; i < n; ++i)
        for (std::size_t j = 0; j < n; ++j) {
            double x = 0;
            for (std::size_t k = 0; k < n; ++k) x += b.factor[i*5+k]*b.factor[j*5+k];
            if (std::abs(x-p.correlation[i*n+j]) > 2*correlation_tolerance)
                throw std::invalid_argument("Correlation reconstruction failed");
        }
    return b;
}
PreparedPortfolio validate_portfolio_request(const Request& r, const std::vector<double>* common) {
    if (!r.portfolio) throw std::invalid_argument("Portfolio input is required");
    const auto b = prepare_portfolio(*r.portfolio);
    if (!r.scenarios || r.scenarios > 10000000 || r.confidence_levels.empty() || r.confidence_levels.size() > 16)
        throw std::invalid_argument("Portfolio requires 1 through 10000000 scenarios and confidence levels");
    for (double c : r.confidence_levels)
        if (c != 0.95 && c != 0.99) throw std::invalid_argument("Portfolio confidence must be 0.95 or 0.99");
    const auto n = static_cast<std::size_t>(b.count);
    if (r.scenarios > (std::numeric_limits<std::size_t>::max)()/n/sizeof(double))
        throw std::overflow_error("Portfolio normal allocation size overflow");
    if (common) {
        if (common->size() != r.scenarios*n) throw std::invalid_argument("Portfolio common input requires N*assets normals");
        for (double x : *common)
            if (!std::isfinite(x)) throw std::invalid_argument("Portfolio normal must be finite");
    }
    return b;
}
void portfolio_shocks(const PreparedPortfolio& b, const double* epsilon, double* shocks) {
    for (int i = 0; i < b.count; ++i) {
        shocks[i] = 0;
        for (int j = 0; j <= i; ++j) shocks[i] += b.factor[i*5+j]*epsilon[j];
    }
}
double portfolio_loss(const PreparedPortfolio& b, const double* epsilon) {
    double shocks[5];
    portfolio_shocks(b, epsilon, shocks);
    double loss = 0;
    for (int i = 0; i < b.count; ++i) {
        loss -= b.values[i]*std::expm1(b.drifts[i]+b.scales[i]*shocks[i]);
    }
    if (!std::isfinite(loss)) throw std::overflow_error("Portfolio scenario loss overflow");
    return loss;
}
}
