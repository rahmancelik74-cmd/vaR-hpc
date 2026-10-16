# CSV and calibration verification v0.2

2026-10-14. Compiled without warnings using GCC 13.3.0, C++17,
-O2 -Wall -Wextra -Wpedantic.

- Core tests passed; existing synthetic CLI behavior was preserved.
- CSV/calibration tests passed. Independently expected log returns .01, .02,
  .03 checked the mean, n-1 variance, annual volatility, drift correction,
  latest price/V0 and trading-day horizon.
- CSV/calibration tests also passed with UndefinedBehaviorSanitizer.
- UTF-8 BOM/CRLF and a valid leap-year date were accepted.
- Invalid dates, duplicate/out-of-order dates, missing data, zero/negative
  prices, NaN, overflow, trailing numeric text, extra columns, incorrect headers
  and blank records were rejected.
- `--csv data/synthetic_prices.csv 10000 42 10` worked end to end:
  12 observations, 11 returns, V0=100.4, mu=0.112217495, sigma=0.2037837913.
- Analytical 95% VaR=6.143576939; 99% VaR=8.715446716. Assumptions: one unit,
  a 10-trading-day horizon and 252 trading days/year. These values refer to
  synthetic test data with no specified currency.
- Monte Carlo output may differ between Windows/Linux because of the standard
  library RNG implementation. The analytical reference does not depend on it.
- v0.2 was checked directly with g++ in this environment. CMake/CTest and MSVC
  verification were to be performed on the student's computer. For the earlier
  v0.1, the student had reported successful tests and demo execution.
- Real-market data, the performance campaign, GPU kernel execution and the
  five-seed acceptance campaign were not yet complete at this date.
