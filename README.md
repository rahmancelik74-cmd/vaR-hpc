# GPU Accelerated Monte Carlo Simulation for Financial Risk Analysis

Abdurrahman Celik - application v0.3.0, 16 October 2026.

Current OpenMP implementation and verification procedure:
[docs/openmp.md](docs/openmp.md). Serial remains the default backend.
Fresh CPU scaling procedure and recorded limits:
[docs/cpu-benchmark.md](docs/cpu-benchmark.md).
Optional RTX-verified CUDA walking skeleton (N <= 10000, disabled by default):
[docs/cuda-skeleton.md](docs/cuda-skeleton.md).
Historical equity import, provenance requirements and current acquisition blocker:
[docs/historical-data.md](docs/historical-data.md).

The contribution of this project is computational. GBM and VaR provide a
well-defined, independently verifiable workload for comparing the correctness
and performance of CPU and GPU implementations. No claim is made about
predictive validity in real markets.

## Starter package contents

The status statements in this section describe the original starter snapshot;
later validation, benchmark, CUDA-probe and CI evidence is recorded separately.

- C++17, CMake and CTest project; GitHub Actions CPU build/test workflow.
- Shared `Engine` interface in which the backend owns RNG, memory, simulation
  and quantile computation.
- Unoptimized serial example using fixed synthetic parameters.
- Single-asset analytical GBM VaR reference and deterministic unit tests.
- CSV reader, log-return calibration and corresponding tests.
- Numbered requirements/design draft and hardware inventory template.

At this snapshot, no OpenMP engine, CUDA engine or GPU quantile code was present.
The serial example had not yet completed the five-seed analytical acceptance
campaign. The CI definition was prepared, but no remote repository or successful
CI execution had yet been established.

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
`mc_var 0.3.0 (CSV support enabled)`. CTest retains the four original tests
and adds cli_contract_tests and, with OpenMP ON, openmp_tests.
Continue in the existing authoritative source folder; do not create or merge
a second source tree. Reconfigure and rebuild after applying the patch.
The following commands are an example of a separate build directory only:

```powershell
cmake -S . -B build-x64 -G "Visual Studio 17 2022" -A x64
cmake --build build-x64 --config Release --parallel
ctest --test-dir build-x64 -C Release --output-on-failure
.\build-x64\Release\mc_var.exe --csv .\data\synthetic_prices.csv 10000 42 10
```

Linux: `./build/mc_var --csv data/synthetic_prices.csv 10000 42 10`.

The final argument specifies a 10-trading-day horizon. CSV mode defaults to
252 trading days/year and one asset unit; V0 is the last row's closing price.
These are initial settings, not a supervisor-confirmed final horizon. To specify
the annual scale explicitly, use `--csv file.csv 10000 42 10 252`.

CSV contract: the exact header `date,close`; two columns; YYYY-MM-DD dates;
decimal dot; unique, increasing dates; finite, positive prices.
UTF-8 BOM and CRLF are supported. Quoted fields, extra columns, semicolons,
decimal commas and blank records are unsupported. Invalid rows are not skipped;
an error identifies the line number. At least three prices are required.

Each record represents the next trading observation. Weekend/holiday gaps are
normal; a market calendar for detecting missing trading sessions is not yet
implemented. Convert the provider's CSV to this contract and document the
price-adjustment policy. Do not silently choose close versus adjusted close.

`data/synthetic_prices.csv` is hand-written software test data, not evidence of
a real stock, price provider or market performance. It contains only 12 prices;
no claim is made that this is sufficient for statistical model calibration.
CSV loading/calibration is outside the engine's `end_to_end_ms` measurement.

Calibration uses sample variance with denominator n-1 for n log returns.
Annual price drift equals annual mean log return plus half the annual variance.
See `docs/requirements-design.md` for details.

## Initial implementation sequence

1. Complete `docs/environment.md` for the target computer.
2. Resolve the open decisions in `docs/requirements-design.md`.
3. Build and test locally; establish the Git repository.
4. Run CSV/calibration tests locally and complete the data-source contract.
5. Validate the serial engine against the analytical reference at both
   confidence levels using five seeds.
6. Add OpenMP and thread scaling.
7. In first-term weeks 12-13, connect CSV -> calibration -> GPU/cuRAND -> GPU
   quantile -> VaR for 10000 scenarios through the same interface.

Plan A is the main plan. Plan B is selected with the supervisor if first-term
work leaves sufficient capacity. Profiling-driven optimization and the optional
multi-asset extension are not added to the initial implementation.

## Sources

- Supervisor's Plan A and Plan B roadmaps dated 2026-10-14.
- https://docs.nvidia.com/cuda/curand/device-api-overview.html
- https://cmake.org/cmake/help/latest/guide/tutorial/index.html

## RNG note

`std::normal_distribution` need not produce identical output across standard
library implementations. The same seed does not imply identical CPU/GPU samples.
Cross-engine numerical tests use pre-generated common inputs. The CUDA RNG API
and Toolkit version will be fixed after inspecting the target computer.

## Structured experiment output (v0.2.2)

Append `--json` to a normal CLI call for schema-versioned output. See
[docs/experiments.md](docs/experiments.md) for the PowerShell experiment runner,
metadata, timing boundary and verification limits. Start with `-Mode smoke`.
