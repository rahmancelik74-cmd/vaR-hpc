#pragma once
#include "mc/core.hpp"
#include <istream>
#include <string>
#include <vector>

namespace mc {
struct PriceObservation { std::string date; double close; };
struct Calibration {
    Model model;
    std::size_t returns_count;
    double mean_log_return;
    double sample_log_variance;
};
// Deliberately narrow CSV contract: date,close; ISO dates; decimal dot.
// Each row represents the next trading observation (weekend gaps are normal).
std::vector<PriceObservation> read_prices_csv(std::istream& input);
std::vector<PriceObservation> load_prices_csv(const std::string& path);
Calibration calibrate(const std::vector<PriceObservation>& prices,
                      double trading_days_per_year = 252.0,
                      double horizon_trading_days = 10.0,
                      double units = 1.0);
} // namespace mc
