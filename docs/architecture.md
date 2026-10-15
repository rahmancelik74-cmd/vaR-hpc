# Architecture baseline

Baseline date: 2026-10-15. Application version: 0.2.1.
This records the implemented design and planned extensions separately.
It does not claim that OpenMP or CUDA has been implemented.

## Purpose and scope

The contribution of this project is computational correctness and performance.
Single-asset GBM and VaR provide a well-defined, independently verifiable
workload for comparing sequential C++, OpenMP and CUDA implementations.
No claim is made about predictive validity in real markets.

The product is a C++ CLI application with replaceable compute backends,
validation evidence and reproducible performance experiments. It is not a
web service. GUI, live APIs, database infrastructure, MPI and machine-learning
prediction are outside Plan A. Multi-asset work is a conditional extension.

## Implemented components

| Component | Files | Responsibility |
| --- | --- | --- |
| CLI and orchestration | src/main.cpp | Parse arguments, load/calibrate once, invoke an engine, display results |
| Data and calibration | include/mc/data.hpp, src/data.cpp | Validate price CSV, compute log returns and GBM parameters |
| Compute contract | include/mc/core.hpp | Define Model, Request, Result and Engine |
| Serial implementation | src/core.cpp | Own RNG/buffers, simulate terminal losses, sort, return VaR |
| Analytical reference | src/core.cpp | Compute GBM VaR independently of Monte Carlo samples |
| Verification | tests/test_core.cpp, tests/test_data.cpp | Deterministic model, quantile, data and calibration checks |
| Build and smoke test | CMakeLists.txt | Build targets and register three CTest tests |

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
allow device-resident loss generation and quantile computation later.

Normal mode: each backend generates its own samples. Validation mode: each
backend consumes the same normal value for the same scenario index. A CUDA
implementation may copy validation inputs to the device without requiring
host-generated inputs in normal performance mode. The run call must not return
until its reported results are ready; CUDA synchronization belongs inside it.

The interface is designed to admit a GPU implementation, but only the planned
walking skeleton can demonstrate that it actually does. Small changes based on
that evidence are allowed and must be recorded.

## Model and data decisions already implemented

- Positive long position in one asset; V0 is the latest close times units.
- Double precision. Direct GBM terminal sampling, without path time steps.
- Positive loss is V0 minus terminal value. Negative VaR is not clipped.
- Confidence levels are 0.95 and 0.99. Ascending loss rank is ceil(alpha*N),
  converted to zero-based indexing by subtracting one.
- Annual price drift is annual mean log return plus half the annual variance.
- Calibration uses sample log-return variance with denominator n-1.
- Demo CSV mode uses 252 trading observations/year, 10 trading-day horizon
  and one unit. These are documented defaults, not confirmed final choices.
- Dates must be valid, unique and increasing; prices finite and positive.
- The CSV contract is deliberately narrow: date,close; ISO dates; decimal dot.
- Each row is the next trading observation. A missing-session calendar check
  is not implemented; record this limitation when choosing real input data.

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

Statistical validation is currently a PowerShell-driven series of CLI calls,
not a dedicated C++ validation subcommand. Machine-readable export and a
repeatable experiment runner are planned; their CLI/API is not implemented.
Do not label exploratory one-run times as official benchmark measurements.

## Planned backend additions

OpenMP will implement Engine independently of the serial RNG state. It needs
safe parallel RNG ownership, common-input validation and explicit thread control.
Initially the loss quantile may use serial CPU sorting. Measure this limitation
rather than claiming the whole pipeline is parallel. Do not share one mutable
standard-library RNG across threads.

The first-term CUDA skeleton must connect CSV, calibration, device cuRAND
generation for 10000 scenarios, the intended full-version GPU quantile library
and the same engine interface to a VaR result. A standalone kernel does not
satisfy the milestone. It makes no accuracy or speed claim.

Full CUDA development grows this skeleton to 10 million scenarios, memory
management, batching and validated full-scale quantiles. Select and document
CUB or Thrust before the skeleton is accepted; Thrust is only a candidate now.

The hybrid fallback generates batches on GPU and computes one global host
quantile from all scalar losses. Never average batch VaRs. Mark the hybrid
backend and include transfers and host quantile time in its end-to-end result.

## Timing boundary

The primary timer starts after shared CSV loading/calibration. Per-run buffer
allocation, RNG initialization/generation, simulation, quantile, required data
transfers and synchronization are included. Current serial timing also includes
temporary buffer destruction. Printing and result-file output are excluded.

Future device-stage timing uses CUDA Events. Distinguish simulation kernel,
complete device pipeline including quantile, and host wall-clock end-to-end
times. Profiling and memory/race checking run separately from benchmarks.

## Next architecture work

1. Preserve the established Git baseline adb49bc and Windows test evidence
   commit 48429b5; continue in the same authoritative source folder.
2. Finalize numbered requirements and the supervisor-confirmed acceptance source.
3. Add reusable result export and experiment metadata without replacing Engine
   with a CPU-specific loop or a requirement to return all losses to the host.
4. Implement and validate OpenMP; keep the GPU skeleton milestone visible.

Use small, reviewable changes. The current source layout is adequate; no
framework, database or large directory refactor is required for these steps.
