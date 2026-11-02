# GPU Accelerated Monte Carlo Simulation for Financial Risk Analysis

Abdurrahman Celik - application v0.3.0, 16 October 2026.


I developed this project to evaluate the numerical correctness, reproducibility
and performance of serial C++, OpenMP and CUDA Monte Carlo implementations.

Project code and original synthetic fixtures: [MIT License](LICENSE).
Third-party components retain their own licenses; provider data is not licensed here.
[Code signing policy](docs/code-signing.md): the application has been submitted;
provider acceptance and certificate access are unconfirmed. Portable downloads
remain unsigned.

Local browser application: run `python -B scripts/start_local.py`, then open
`http://127.0.0.1:8765`. See [prerequisites, supported data and limits](docs/local-browser.md)
for synthetic examples, strict local uploads, engine comparisons and downloads.

Optional [synthetic portfolio mode](docs/portfolio.md) supports 1..5 assets on
serial, OpenMP and full-device or explicit hybrid CUDA, with independent structural/moment checks.
The [portfolio hybrid contract and local evidence](docs/portfolio-hybrid.md)
cover global host quantiles and bounded GPU batches.
It is a separate extension; existing single-asset acceptance and campaigns remain unchanged.
The [published portfolio implementation](https://github.com/rahmancelik74-cmd/vaR-hpc/commit/f0b887819976ff0b579acc1a308991177f05aeda)
has [successful exact-SHA CPU CI](https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/40136758943).
Local Windows/OpenMP/RTX validation is separate; hosted CI did not execute CUDA.
See [current delivery status and the historical evidence clarification](docs/portfolio.md#published-implementation-and-hosted-ci).
Separate [portfolio statistical validation and formal timing](docs/portfolio-campaign.md)
retain a frozen independent-reference protocol, all native seeds, all benchmark
samples and uncertainty-limited outcomes; historical single-asset ratios are unchanged.

Technical [reproducibility entry point](docs/reproducibility.md) and
[FR/NFR evidence audit](docs/requirements-audit.md): distinguish clean software
builds, selected public integrity checks, local raw archives and offline figures.
Kernel-scope [DRAM baseline](evidence/v030-dram-baseline-20261020/README.md)
reporting is complete within its recorded scope, using the documented NVIDIA
App configuration-bandwidth reference. See the
[reference interpretation and limits](docs/acceptance-source.md#documented-peak-interpretation-audit-2026-10-21).
The [evidence guide](docs/evidence-guide.md) distinguishes current summaries,
original experiment records and historical document snapshots.

Current OpenMP implementation and verification procedure:
[docs/openmp.md](docs/openmp.md). Serial remains the default backend.
Fresh CPU scaling procedure and recorded limits:
[docs/cpu-benchmark.md](docs/cpu-benchmark.md).
Completed formal primary CPU/GPU comparison, all 24 rows and limitations:
[docs/cpu-gpu-benchmark.md](docs/cpu-gpu-benchmark.md#formal-primary-result-2026-10-19).
At 10 million scenarios, full-device reached 9.739930524x serial and 8.307208722x
best measured OpenMP; the 10x serial target was not met.
Separate instrumented CUDA stage timings and limits:
[docs/cuda-stage-diagnostics.md](docs/cuda-stage-diagnostics.md).
Optional full-device CUDA backend (N <= 10000000, memory preflight, disabled by default):
[docs/cuda-skeleton.md](docs/cuda-skeleton.md).
Explicit bounded-memory CUDA batching with a global host quantile:
[docs/cuda-hybrid.md](docs/cuda-hybrid.md).
Historical equity import and provenance requirements:
[docs/historical-data.md](docs/historical-data.md).
Current data rights and local session-date audit:
[docs/data-rights-and-calendar.md](docs/data-rights-and-calendar.md).
Small offline serial/OpenMP demonstration:
[docs/synthetic-demo.md](docs/synthetic-demo.md).
CPU and GPU demonstration launchers, technical explanations and recovery:
[docs/live-demos.md](docs/live-demos.md).

The contribution of this project is computational. GBM and VaR provide a
well-defined, independently verifiable workload for comparing the correctness
and performance of CPU and GPU implementations. No claim is made about
predictive validity in real markets.

## Implementation

- C++17, CMake and CTest with serial, OpenMP and optional CUDA backends.
- Shared Engine interface with backend-owned RNG, storage, valuation and quantiles.
- CSV validation, log-return calibration and an analytical single-asset GBM reference.
- Single-asset validation and separately scoped 1..5-asset portfolio extensions.
- Reproducible experiment recorders, stage diagnostics and convergence figures.
- A local browser application and a Windows portable CPU preview.

## Build

CMake and a C++17 compiler are required. An NVIDIA GPU is not required to start.

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --parallel
ctest --test-dir build -C Release --output-on-failure
```

Linux or a single-configuration Ninja/MinGW build:

```sh
./build/mc_var 10000 42
```

Windows Visual Studio multi-configuration build, using PowerShell:

```powershell
.\build\Release\mc_var.exe 10000 42
```

The example uses `V0=100`, annual `mu=0.05`, `sigma=0.20` and `T=1` year.
These are demo values, not the final data or horizon. Output includes 95%/99%
Monte Carlo VaR, analytical VaR, their difference and one run's elapsed time.
A single run is neither a benchmark campaign nor a 1% convergence guarantee.

## CSV mode

Version check: `mc_var.exe --version` must report
`mc_var 0.3.0 (CSV support enabled)`. Registered tests depend on the platform
and selected CMake options; inspect them with `ctest --show-only=json-v1`.
Configure a separate build directory, compile and run the registered tests:

```powershell
cmake -S . -B build-x64 -G "Visual Studio 17 2022" -A x64
cmake --build build-x64 --config Release --parallel
ctest --test-dir build-x64 -C Release --output-on-failure
.\build-x64\Release\mc_var.exe --csv .\data\synthetic_prices.csv 10000 42 10
```

Linux: `./build/mc_var --csv data/synthetic_prices.csv 10000 42 10`.

The final argument specifies a 10-trading-day horizon. CSV mode defaults to
252 trading days/year and one asset unit; V0 is the last row's closing price.
The study convention is a 10-trading-day horizon with 252 trading days/year.
To specify the annual scale explicitly, use `--csv file.csv 10000 42 10 252`.

CSV contract: the exact header `date,close`; two columns; YYYY-MM-DD dates;
decimal dot; unique, increasing dates; finite, positive prices.
UTF-8 BOM and CRLF are supported. Quoted fields, extra columns, semicolons,
decimal commas and blank records are unsupported. Invalid rows are not skipped;
an error identifies the line number. At least three prices are required.

Each record represents the next trading observation. The C++ CSV reader checks
dates and ordering but does not infer exchange sessions. The separate importer
and browser workflow validate completeness against the supplied Nasdaq
2023-2025 calendar; see [calendar scope](docs/data-rights-and-calendar.md).
Provider conversion must document the price-adjustment policy; Close and
adjusted Close are not interchangeable.

`data/synthetic_prices.csv` is hand-written software test data, not evidence of
a real stock, price provider or market performance. It contains only 12 prices;
no claim is made that this is sufficient for statistical model calibration.
CSV loading/calibration is outside the engine's `end_to_end_ms` measurement.

Calibration uses sample variance with denominator n-1 for n log returns.
Annual price drift equals annual mean log return plus half the annual variance.
See `docs/requirements-design.md` for details.

## Computational workflow

1. Validate input observations, provenance and model parameters.
2. Calibrate annual GBM parameters from log returns outside engine timing.
3. Evaluate the analytical reference and validate the serial implementation.
4. Compare backends using common inputs and independent-seed analytical checks.
5. Execute serial, OpenMP or CUDA through the shared Engine interface.
6. Report engine wall time, separately scoped stage diagnostics, convergence
   and reproducibility metadata.

The single-asset implementation is the validation and performance baseline.
Profiling-driven optimization and multi-asset valuation are separate extensions
with their own validation requirements; they do not replace the baseline.

## Sources

- https://docs.nvidia.com/cuda/curand/device-api-overview.html
- https://cmake.org/cmake/help/latest/guide/tutorial/index.html

## RNG note

`std::normal_distribution` need not produce identical output across standard
library implementations. The same seed does not imply identical CPU/GPU samples.
Cross-engine numerical tests use pre-generated common inputs. The validated
CUDA path uses device cuRAND and CUB; versions and hardware are
recorded in [the environment inventory](docs/environment.md).

## Structured experiment output (v0.2.2)

Append `--json` to a normal CLI call for schema-versioned output. See
[docs/experiments.md](docs/experiments.md) for the PowerShell experiment runner,
metadata, timing boundary and verification limits. Start with `-Mode smoke`.
