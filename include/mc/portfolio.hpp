#pragma once
#include "mc/core.hpp"

namespace mc {
struct Asset {
    std::string id;
    double quantity, price, drift, volatility;
};
struct Portfolio {
    std::string unit;
    double horizon = 1;
    std::vector<Asset> assets;
    std::vector<double> correlation; // Row major, in asset order.
};
// POD copied by value to CUDA kernels. Preparation is outside engine timing.
struct PreparedPortfolio {
    int count = 0;
    double initial_value = 0;
    double values[5]{}, drifts[5]{}, scales[5]{}, factor[25]{};
};
constexpr double correlation_tolerance = 1e-12;
constexpr double cholesky_pivot_tolerance = 1e-14;
Portfolio load_portfolio(const std::string& path);
PreparedPortfolio prepare_portfolio(const Portfolio& portfolio);
PreparedPortfolio validate_portfolio_request(const Request& request,
    const std::vector<double>* common);
double portfolio_loss(const PreparedPortfolio& portfolio, const double* epsilon);
void portfolio_shocks(const PreparedPortfolio& portfolio, const double* epsilon, double* shocks);
}
