# Architecture baseline

Historical portfolio inputs can now be prepared offline by
`scripts/calibrate_portfolio.py`; see [its strict calibration contract](portfolio-calibration.md).
It reuses existing import artifacts and produces unchanged portfolio-v1 input.
Alignment/calibration stay outside Engine::run and engine timing. The independent
original-byte Decimal audit and native integration recorder are in
`scripts/verify_portfolio_calibration.py`. The calibration extension itself did not change engine/RNG contracts; the
subsequent PH extension below adds portfolio hybrid execution.

Optional portfolio extension: [contract, inputs and validation](portfolio.md).
`Request::portfolio` is a borrowed immutable optional input to the same Engine
boundary; null retains the established single-asset path. `portfolio.cpp` owns
shared input validation and Cholesky preparation outside engine timing. Each
backend retains native RNG, scalar loss storage and its own quantile pipeline.
Portfolio CUDA supports full-device and explicit hybrid batches with one global
host scalar-loss quantile; see [the PH contract](portfolio-hybrid.md).

Application version: 0.3.0. This document describes the current software
architecture; dated experiment results are recorded in the evidence packages.
OpenMP is implemented and Windows-verified. CUDA now supports the full-device
path up to 10000000 scenarios with a checked 80%-free explicit-memory preflight.
GPU statistical acceptance, memory/race checking and benchmarking remain separate.

## Purpose and scope

The contribution of this project is computational correctness and performance.
Single-asset GBM and VaR provide a well-defined, independently verifiable
workload for comparing sequential C++, OpenMP and CUDA implementations.
No claim is made about predictive validity in real markets.

The computational core is a C++ CLI application with replaceable compute
backends, validation evidence and reproducible performance experiments. A
separate loopback-only browser adapter provides local interaction and a
portable CPU distribution. Portfolio valuation is a separately validated
extension. Public hosting, live market APIs, database infrastructure, MPI and
machine-learning prediction are outside the implemented research scope.

## Implemented components

| Component | Files | Responsibility |
| --- | --- | --- |
| CLI and orchestration | src/main.cpp | Parse arguments, load/calibrate once, invoke an engine, display results |
| Data and calibration | include/mc/data.hpp, src/data.cpp | Validate price CSV, compute log returns and GBM parameters |
| Compute contract | include/mc/core.hpp | Define Model, Request, Result and Engine |
| Serial implementation | src/core.cpp | Own RNG/buffers, simulate terminal losses, sort, return VaR |
| OpenMP implementation | include/mc/openmp.hpp, src/openmp.cpp | Separate library; private fixed-block RNG, parallel loss generation, serial sort |
| CUDA engine | include/mc/cuda.hpp, src/cuda.cu | Optional mc_cuda library; default global device CUB quantile or explicitly selected bounded batches with one global host quantile; N <= 10000000 subject to memory checks |
| Structured export | include/mc/output.hpp, src/output.cpp | Serialize one complete run without changing Engine |
| Offline equity conversion | scripts/equity-data-common.ps1, scripts/import-equity-data.ps1 | Validate provider CSV/provenance, preserve raw bytes and produce ignored strict date,close input |
| Experiment recorders | scripts/run-experiment.ps1, scripts/run-openmp-validation.ps1 | Serial campaigns and separate clean-source OpenMP correctness evidence |
| CPU scaling recorder | scripts/run-cpu-benchmark.ps1, tools/cpu_probe.cpp | Fresh native serial/OpenMP pipeline timings, separate Windows topology/affinity/power instrumentation |
| Analytical reference | src/core.cpp | Compute GBM VaR independently of Monte Carlo samples |
| Verification | tests/test_core.cpp, tests/test_data.cpp, tests/test_output.cpp | Model, quantile, data, calibration and JSON checks |
| Local browser adapter | local_app/server.py, local_app/static/ | Validate local requests, invoke existing tools, present results and downloads |
| Portable CPU distribution | packaging/portable_entry.py, scripts/build_portable.py | Package app-local runtime, launcher, engine and integrity metadata |
| Build and smoke test | CMakeLists.txt | Core/data/JSON/CLI tests plus platform/option-dependent recorder and backend regressions; query current CTest registration |

Current data flow: CLI parses options; data loading produces observations;
calibration creates Model; CLI creates Request; Engine returns Result;
CLI computes analytical comparison and prints the output.
The CSV/calibration stage is shared and outside engine timing.

## Current engine contract

`Engine::run(const Request&, const std::vector<double>* common_normals)`
is one batch operation. Request carries the model, scenario count, seed and
confidence levels. Result carries backend/RNG labels, VaR estimates and
end-to-end engine time. The optional host input vector is validation-only.

The caller owns the request and common inputs throughout the call.
The engine owns its temporary storage and RNG. No per-scenario CPU callback
is required. No complete host loss vector is required in Result. These choices
support device-resident loss generation and quantile computation.

Normal mode: each backend generates its own samples. Validation mode: each
backend consumes the same normal value for the same scenario index. A CUDA
implementation may copy validation inputs to the device without requiring
host-generated inputs in normal performance mode. The run call must not return
until its reported results are ready; CUDA synchronization belongs inside it.

The RTX-verified walking skeleton demonstrates a GPU implementation through this
interface. It does not establish full-scale capacity or performance. Small later
interface changes based on evidence are allowed and must be recorded.

## Model and data decisions already implemented

- Positive long position in one asset; V0 is the latest close times units.
- Double precision. Direct GBM terminal sampling, without path time steps.
- Positive loss is V0 minus terminal value. Negative VaR is not clipped.
- Confidence levels are 0.95 and 0.99. Ascending loss rank is ceil(alpha*N),
  converted to zero-based indexing by subtracting one.
- Annual price drift is annual mean log return plus half the annual variance.
- Calibration uses sample log-return variance with denominator n-1.
- CSV defaults and the study convention use 252 trading observations/year and
  a 10-trading-day horizon. Quantity defaults to one positive unit.
- Dates must be valid, unique and increasing; prices finite and positive.
- The CSV contract is deliberately narrow: date,close; ISO dates; decimal dot.
- Each row is the next trading observation. The CLI does not infer exchange
  sessions. A separate offline check-equity-calendar.ps1 audits imported dates
  against a bounded calendar; it neither fills observations nor validates prices.

GBM assumes constant drift/volatility, independent normal log increments and
continuous paths. Time-varying/clustered volatility, jumps and heavy tails in
markets limit the model. Analytical agreement validates implementation under
this model rather than market forecasting quality.

## Separate execution purposes

| Purpose | Inputs and rules | Evidence |
| --- | --- | --- |
| Unit verification | Fixed fixtures and edge cases | CTest results |
| Cross-engine numerical validation | Identical pre-generated normal inputs and quantile rule | Absolute VaR differences, plus scenario checks where useful |
| Statistical validation | Analytical reference, multiple seeds and scenario counts | Per-seed values and convergence summary |
| Performance benchmark | Native backend RNG, shared model and precision | Warm-ups, repetitions, timing statistics, throughput and speedup |

The CLI supports final-argument --json output and a PowerShell runner
for separate smoke, statistical-validation and benchmark campaigns. It keeps
the existing Engine interface. File hashes and run metadata are recorded in
the manifest. Windows smoke verification passed on 2026-10-15; see experiments.md.
The runner records execution results; acceptance is evaluated separately.
Do not label exploratory one-run times as official benchmark measurements.

## OpenMP and CUDA execution

OpenMP implements Engine independently of serial RNG state in mc_openmp.
Blocks of 4096 own private mt19937_64 and normal_distribution state; seeds
are derived from the run seed and block index with SplitMix64 mixing. Native
results are invariant across requested thread counts within the same build;
native serial and OpenMP samples differ. Common-input validation is separate.
Worker exceptions are captured inside the team and rethrown after completion.
Sorting is serial, so only scenario generation is parallel. Details and the
Windows correctness evidence procedure are in [openmp.md](openmp.md).
The additive Result metadata records requested/actual threads and _OPENMP.

The initial CUDA skeleton now connects shared CSV/calibration, device cuRAND
PHILOX normal-double generation for 10000 scenarios, GPU double losses, CUB
DeviceRadixSort and a device nearest-rank gather through Engine::run. Only scalar
quantiles and an error flag return to the host; there is no host sorting.
The RTX 4060 checks include common inputs separately from native RNG smoke.
This proves connectivity, not full-scale analytical acceptance or speed.

The first scale-up retains that path up to 10 million scenarios with checked
sizes, device launch limits and an actual-request CUB workspace budget.
Explicit hybrid batching is now implemented separately from the default path;
see [cuda-hybrid.md](cuda-hybrid.md). CUB 3.4.3 is
validated locally and used by the full-device quantile path. Runtime metadata
records the built library version. Details, limits, transfer
events and the initial VRAM estimate are in [cuda-skeleton.md](cuda-skeleton.md).

The explicitly selected hybrid mode generates batches on GPU and computes one global host
quantile from all scalar losses. Never average batch VaRs. Mark the hybrid
backend and include transfers and host quantile time in its end-to-end result.

## Timing boundary

The primary timer starts after shared CSV loading/calibration. Per-run buffer
allocation, RNG initialization/generation, simulation, quantile, required data
transfers and synchronization are included. Current serial timing also includes
temporary buffer destruction. Printing and result-file output are excluded.

The skeleton's H2D/D2H transfers use CUDA Events. Distinguish simulation kernel,
complete device pipeline including quantile, and host wall-clock end-to-end
times. Event transfer totals do not represent the full pipeline. Pageable
staging is included in host wall time. Separate
[GPU acceptance checks](gpu-acceptance.md),
[primary benchmarks](cpu-gpu-benchmark.md) and
[DRAM profiles](../evidence/v030-dram-baseline-20261020/README.md) define their own
source revisions and coverage; connectivity evidence alone establishes none of
those broader results.

## Design constraints

The Engine boundary remains independent of the browser adapter and experiment
recorders. Native RNG streams, double precision, nearest-rank quantiles and
host timing scope are preserved across extensions. Validation-only common
inputs remain caller-owned. Hybrid execution computes one global quantile
over all scalar losses, and never averages batch VaRs. Current implementation
and evidence boundaries are summarized in [project-state.md](project-state.md).
