# Requirements and Design Document

Current technical evidence mapping: [FR/NFR audit](requirements-audit.md).
The R01-R14/B01-B02 draft and its dated statuses below are preserved; the audit
adds a clearly identified crosswalk without renumbering these older labels.

Status: initial draft v0.1. This is a basis for the content of the at-most-eight-
page v1.0 document to be submitted to the supervisor, not the final approved
submission. The requirement IDs and snapshot statuses below are retained from
the initial draft.

## Scope

The primary contribution of this work is computational correctness and
performance analysis. Geometric Brownian Motion and Value at Risk provide a
well-defined, independently verifiable computational workload for comparing
sequential C++, OpenMP and CUDA implementations. No claim is made about
predictive validity in real markets, the adequacy of stress testing or the
superiority of the financial model. The same scope statement will appear at
the beginning of the technical report.

The baseline scope is one asset and a positive long position. GUI, live price
APIs, machine learning and MPI are excluded. A multi-asset portfolio does not
replace the core benchmark; it is an additional mode that may be agreed with
the supervisor under Plan B only.

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
sample variance with denominator n-1; the final document will explain the
estimator choice. Record the annual trading-day count and selected horizon
explicitly; do not mix calendar days and trading days. Do not substitute the
mean arithmetic daily return into this formula.

The CSV source, ticker, date range and price-adjustment policy have not yet
been selected. Define explicit error handling for missing, duplicate,
out-of-order, zero or negative prices; do not clean data silently. Record the
final input file's SHA-256. Input data and calibration are shared by all engines.

## Numbered requirements

| ID | Requirement | Acceptance evidence | Status in the initial package |
| --- | --- | --- | --- |
| R01 | Computational scope and GBM limitations | Statement at the start of requirements and technical report | Draft available |
| R02 | Units, loss sign, quantile and double precision | Documented contract and deterministic tests | Initial tests available |
| R03 | Hardware/toolchain and build settings | Inventory of the student's target machine | Template available |
| R04 | CMake and basic CI | Local build/CTest and repository CI result | Definition available; CI pending |
| R05 | Shared engine interface | Backends called with the same Request/Result | Serial interface available; GPU evidence pending |
| R06 | CSV and log-return calibration | Calibration tests using known inputs | v0.2 implementation and controlled tests available; real-data selection pending |
| R07 | Analytical single-asset VaR | Known normal quantiles and edge cases | Initial implementation/tests available |
| R08 | Analytical validation of the serial engine | 95%/99%, five seeds, approved thresholds | Demo available; acceptance campaign pending |
| R09 | OpenMP and thread scaling | Common inputs, thread sweep, affinity record | Pending |
| R10 | First-term GPU walking skeleton | CSV -> calibration -> cuRAND -> GPU quantile -> VaR, N=10000 | Pending |
| R11 | Full-scale CUDA and memory management | 100 thousand/1 million/10 million, memory and race checks | Pending |
| R12 | Complete engine validation | Common inputs plus separate analytical/seed tests | Pending |
| R13 | Fair benchmark and convergence | 3 warm-ups, 10 repetitions, mean/std, two CPU references | Pending |
| R14 | Reproducibility and reporting | Build/run scripts, inventory, checksum, report | Pending |
| B01 | Plan B profiling-driven optimization | Nsight, bottleneck, before/after evidence, revalidation | Conditional |
| B02 | Plan B additional multi-asset mode | Supervisor decision and separate validation strategy | Conditional |

## Engine interface and data ownership

`Engine::run(Request, common_normals)` is one batch call. Request contains the
model, scenario count, seed and confidence levels. Result contains VaR values,
backend/RNG information and timing. Each backend owns its temporary buffers,
RNG state, simulation, quantile and synchronization. Returning all losses to
the host is not mandatory. The interface imposes neither a CPU loop nor a
host RNG callback.

`common_normals` is for validation only. Either it contains exactly N inputs
or the engine uses its own RNG. The caller owns common inputs; the engine only
reads them during the call. CUDA will copy them to the device in this mode,
without requiring generation on the CPU and transfer to the GPU in normal
performance mode. Since the CUDA engine has not yet been implemented, no claim
is made that the interface has been validated with a GPU backend.

Thrust `sort` is the provisional GPU quantile-library candidate; the choice
will be fixed after a compatibility check on the actual device. The skeleton
and full engine will use the same library. If CUB is selected, the skeleton
will use CUB from the outset.

## Validation and measurement

First run deterministic edge-case and quantile tests; then compare
scenario-level losses and VaR using common normal inputs; finally compare
against analytical VaR and study convergence using independent seeds. The same
seed does not guarantee the same sequence across different RNGs. Numerical and
statistical tests are not interchangeable.

Candidate numerical conditions are recorded in `acceptance-source.md`; the
identity of the supervisor-approved proposal still needs confirmation. For
N=10000000 and five seeds, evaluate the absolute error of the mean of the five
VaR estimates against the stated tolerance, separately at 95% and 99%. Record
individual seed values and errors for diagnosis; do not require each seed to
pass that aggregate condition. Common-input cross-engine validation is a
separate numerical check. The GPU skeleton only proves end-to-end connectivity;
it is not an accuracy or speed acceptance test.

The benchmark harness will be developed alongside the serial engine. The
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
The initial serial demo is unoptimized; the final CPU reference will be
measured using reasonable compiler optimizations.

If GPU memory is insufficient, generate batches on the GPU, accumulate scalar
losses on the host and compute one global quantile. Never average batch VaRs.
Label the hybrid mode separately and include transfer/host quantile time in
the total.

## Open decisions from the first two weeks

1. Target CPU/GPU, operating system and driver/Toolkit/compiler availability.
2. T, trading-day scale, data source and price-adjustment policy.
3. Error thresholds and success targets from the approved proposal.
4. Repository location and actual CI execution.
5. GPU quantile library and a small device smoke test.

Source: supervisor's Plan A/Plan B v2.0, 2026-10-14. The approved proposal is
also authoritative for numerical acceptance conditions. All progress reports
will reference requirement IDs Rxx/Bxx and the corresponding test/measurement
evidence.
