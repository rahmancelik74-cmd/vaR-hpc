#pragma once
#include "mc/core.hpp"
#include <iosfwd>

namespace mc {
struct CsvMetadata {
    std::size_t observations = 0;
    std::size_t returns_count = 0;
    std::string date_start;
    std::string date_end;
    double mean_log_return = 0;
    double sample_log_variance = 0;
    std::uint64_t horizon_trading_days = 10;
    std::uint64_t trading_days_per_year = 252;
};
// One ASCII JSON object. The experiment manifest owns file paths and hashes.
// Output and analytical comparisons are outside the engine timer.
void write_run_json(std::ostream& output, const Request& request,
                    const Result& result, const CsvMetadata* csv = nullptr);
} // namespace mc
