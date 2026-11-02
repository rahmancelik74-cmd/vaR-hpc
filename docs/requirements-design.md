# Requirements and Design Document

This technical design summary accompanies the
[FR/NFR evidence audit](requirements-audit.md) and
[numerical acceptance register](acceptance-source.md). The R01-R14/B01-B02
identifiers below retain the original design mapping. The separate academic
Requirements and Design document remains v1.0.

## Scope

The primary contribution of this work is computational correctness and
performance analysis. Geometric Brownian Motion and Value at Risk provide a
well-defined, independently verifiable computational workload for comparing
sequential C++, OpenMP and CUDA implementations. No claim is made about
predictive validity in real markets, the adequacy of stress testing or the
superiority of the financial model. This scope applies to the implementation
and its performance evaluation.

The baseline is one asset and a positive long position. The implemented
portfolio mode and local browser adapter are separate extensions; neither
replaces the single-asset analytical benchmark. Public hosting, live price APIs,
machine learning and MPI are outside the implemented scope.

## Model and numerical contract

- V0 = q * S0; S0 > 0 and q > 0. The initial demo operates directly on V0.
- `mu` is price drift, not mean log return; its unit is year^-1.
- `sigma` is volatility; its unit is year^-1/2. T is measured in years.
- Z is standard normal: V_T = V0 * exp((mu - sigma^2/2)*T + sigma*sqrt(T)*Z).
- L = V0 - V_T; positive values represent losses. Negative VaR is not clipped.
- Confidence levels are alpha = 0.95 and 0.99. All computational values use double.
- Losses are sorted ascending: one-based k = ceil(alpha*N), C++ index k-1.
- Analytical VaR = V0 - Q_(1-alpha)(V_T). At 99%, the lower terminal quantile is 1%.
- The analytical terminal quantile substitutes Phi^-1(1-alpha) into the same GBM formula.
- Full price paths are not simulated because only terminal values are needed.

GBM assumes constant drift/volatility, continuous paths, independent normal
log-return increments and lognormal terminal values. Time-varying volatility,
volatility clustering, heavy tails and jumps in real markets can violate these
assumptions. Analytical agreement establishes implementation correctness within
the model, not validity in real markets.

## Parameter calibration design

For equally spaced observations, r_i = log(P_i/P_(i-1)). If the observation
interval is dt years, use the mean m and sample variance s^2 to calculate
sigma = sqrt(s^2/dt) and mu = m/dt + sigma^2/2. This project's contract uses
sample variance with denominator n-1. Record the annual trading-day count and
selected horizon explicitly; do not mix calendar days and trading days. Do not substitute the
mean arithmetic daily return into this formula.

Public examples are synthetic. Private MSFT/AAPL integration uses the documented
2023-2025 Nasdaq window and unadjusted Close policy; it does not select a final
redistributable historical-study dataset. See
[data rights and calendar scope](data-rights-and-calendar.md). Missing, duplicate,
out-of-order, zero and negative observations are rejected. Original input bytes
and hashes are retained; loading/calibration are shared and outside engine timing.

## Numbered requirements

| ID | Requirement | Acceptance evidence | Technical evidence entry point |
| --- | --- | --- | --- |
| R01 | Computational scope and GBM limitations | Statement at the start of requirements and technical report | Scope and model limitations above |
| R02 | Units, loss sign, quantile and double precision | Documented contract and deterministic tests | core_tests; acceptance-source.md |
| R03 | Hardware/toolchain and build settings | Inventory of the target machine | environment.md |
| R04 | CMake and basic CI | Local build/CTest and repository CI result | reproducibility.md; current CPU CI |
| R05 | Shared engine interface | Backends called with the same Request/Result | architecture.md; gpu-acceptance.md |
| R06 | CSV and log-return calibration | Calibration tests using known inputs | historical-data.md; data-rights-and-calendar.md |
| R07 | Analytical single-asset VaR | Known normal quantiles and edge cases | core_tests; analytical reference |
| R08 | Analytical validation of the serial engine | 95%/99%, five seeds, approved thresholds | evidence/v022-validation-20261016 |
| R09 | OpenMP and thread scaling | Common inputs, thread sweep, affinity record | openmp.md; cpu-benchmark.md |
| R10 | GPU connectivity prototype | CSV -> calibration -> cuRAND -> GPU quantile -> VaR, N=10000 | evidence/v030-cuda-skeleton-windows-20261016 |
| R11 | Full-scale CUDA and memory management | 100 thousand/1 million/10 million, memory and race checks | cuda-skeleton.md; cuda-hybrid.md; gpu-acceptance.md |
| R12 | Complete engine validation | Common inputs plus separate analytical/seed tests | gpu-acceptance.md; requirements-audit.md |
| R13 | Fair benchmark and convergence | 3 warm-ups, 10 repetitions, mean/std, two CPU references | cpu-gpu-benchmark.md; convergence.md |
| R14 | Reproducibility and reporting | Build/run scripts, inventory, checksum, report | reproducibility.md; evidence-guide.md |
| B01 | Optional profiling-driven optimization | Nsight, bottleneck, before/after evidence, revalidation | quantile-selection-experiment.md; isolated experiment only |
| B02 | Optional additional multi-asset mode | Explicit scope decision and separate validation strategy | portfolio.md; portfolio-campaign.md; separate scope |

## Engine interface and data ownership

`Engine::run(Request, common_normals)` is one batch call. Request contains the
model, scenario count, seed and confidence levels. Result contains VaR values,
backend/RNG information and timing. Each backend owns its temporary buffers,
RNG state, simulation, quantile and synchronization. Returning all losses to
the host is not mandatory. The interface imposes neither a CPU loop nor a
host RNG callback.

`common_normals` is for validation only. Either it contains exactly N inputs
or the engine uses its own RNG. The caller owns common inputs; the engine only
reads them during the call. CUDA copies them to the device in this mode.
Normal performance mode uses backend-native RNG rather than host-generated
samples. Portfolio common inputs contain N times the asset count values.

CUDA full-device execution uses CUB DeviceRadixSort::SortKeys<double> and a
device nearest-rank gather. The validated library reference is CUB 3.4.3. Hybrid
execution transfers scalar batch losses and sorts the complete host sample once.
The isolated CPU selection experiment does not replace production std::sort.

## Validation and measurement

First run deterministic edge-case and quantile tests; then compare
scenario-level losses and VaR using common normal inputs; finally compare
against analytical VaR and study convergence using independent seeds. The same
seed does not guarantee the same sequence across different RNGs. Numerical and
statistical tests are not interchangeable.

The numerical acceptance conditions are recorded in `acceptance-source.md`. For
N=10000000 and five seeds, evaluate the absolute error of the mean of the five
VaR estimates against the stated tolerance, separately at 95% and 99%. Record
individual seed values and errors for diagnosis; do not require each seed to
pass that aggregate condition. Common-input cross-engine validation is a
separate numerical check. The GPU skeleton only proves end-to-end connectivity;
it is not an accuracy or speed acceptance test.

The benchmark harness records separate validation and timing campaigns. The
primary measurement is host wall-clock time starting after shared CSV loading/
calibration and ending when the engine completes. It includes allocation,
RNG initialization/generation, simulation, quantile, required transfers and
synchronization. GPU stages are reported separately using CUDA Events. Do not
confuse kernel-only, device-pipeline and end-to-end timing. Profiling runs are
separate from timed benchmark repetitions.

N = 100000, 1000000, 10000000; 3 warm-ups + 10 timed repetitions; mean and
sample standard deviation; scenarios/s; speedup relative to serial and the
best OpenMP configuration. The thread sweep includes 1,2,4,... and the physical
core count explicitly. Common-input test mode is not labeled as a benchmark.
Benchmark records identify Release compiler settings and the tested CPU binary.

Hybrid mode must be selected explicitly with a batch size. It generates batches
on the GPU, accumulates scalar losses on the host and computes one global quantile.
Full-device allocation failure does not silently select hybrid mode. Never
average batch VaRs.
Label the hybrid mode separately and include transfer/host quantile time in
the total.

## Reproducibility and interpretation

Hardware, software, compiler options and measured power/placement conditions
are recorded with each experiment. Native equal seeds do not imply equal
samples across different backends. Fixed synthetic validation does not establish
market predictive validity. The original design identifiers retain the
[FR/NFR crosswalk](requirements-audit.md#preserved-older-label-crosswalk);
no acceptance threshold is changed by this summary.
