# CUDA stage-diagnostic checkpoint: 2026-10-19

Clean RTX-tested source: 80148cee0ba5a52b1c67ca98a6ad4eb91e4d7817.
The separate campaign completed all 18 processes: six configurations, three
diagnostic repetitions each, no campaign warm-ups or replacements. Diagnostics
were ON and the profiler OFF. Closure reran the final auditor without launching
measurements. All 36 native VaR values match compatible uninstrumented records.
No instrumentation defect was found. This later documentation/evidence commit
is distinct from the tested measurement source.

## Procedure and evidence

The [reviewed evidence](../evidence/v030-cuda-stage-diagnostics-windows-20261019/README.md)
contains all [66 per-field statistics](../evidence/v030-cuda-stage-diagnostics-windows-20261019/summary.csv),
the [six-row full-precision summary](../evidence/v030-cuda-stage-diagnostics-windows-20261019/six-configuration-summary.csv),
and [all 18 sample projections](../evidence/v030-cuda-stage-diagnostics-windows-20261019/samples.csv).
Raw launcher/target stdout, stderr, exit statuses, attempt records, source snapshot,
build artifacts and telemetry remain unchanged in the ignored local directories:

- results/cuda-stage-diagnostics-80148ce-20261019-run2/: completed campaign,
  manifest.json, delivery-manifest.json, runs.jsonl and original report.md.
- results/cuda-stage-diagnostics-80148ce-20261019-review/: final passed audit,
  failed audit revisions, correction history and six-configuration summary.
- results/cuda-stage-diagnostics-80148ce-20261019-run1/: incomplete preflight;
  CMake/MSBuild SDK discovery was denied by the sandbox before any sample.

The committed recorder's diagnostic mode is a four-process N=100000 OFF/ON smoke.
This larger authorized matrix used an ignored local wrapper around the existing
argument builder/process launcher and unchanged opt-in instrumentation. No engine,
RNG, quantile, compiler setting or recorder feature was changed. Each CLI sample
used a fresh process/CUDA context, owned Job Object, verified ffff CPU pool and
normal priority. There is no per-core pinning claim. Process-local OpenMP controls
were restored; the fixed 100 ms inter-run delay is outside engine time.

The fixture is the existing synthetic CSV, SHA-256
8dbb7c73e6ad48cb8c8c175aff6684d2a0433e5f08424ec7ea1e69037bb36210.
All runs use native seed string 42, one unit, T=10/252 years, alpha=.95/.99,
double precision and one global ascending nearest-rank loss quantile. Hybrid
requests 65535, effective 65536, with 2/16/153 batches at increasing N. This
is computational evidence, not predictive market validation.

The dedicated Release build used VS 2022/MSVC 19.44.35227.0, CMake
3.31.6-msvc6, nvcc 13.4.92, architecture 89, CUB 3.4.3, C++
/O2 /Ob2 /DNDEBUG and CUDA --fmad=false /Zc:preprocessor. CUDA/OpenMP/CPU
tools/testing were enabled. Driver 610.88 and CUDA runtime DLL bindings matched
compatible prior records. Fresh cuda_diagnostics_contract passed 1/1; compatible
earlier full regressions were reused after implementation/test/recorder comparison
against df34111. Acceptance and sanitizer campaigns were not repeated.

## Complete six-configuration results

All timing cells are mean +/- sample standard deviation in ms, n=3; variance
uses n-1. Tables are rounded to six decimals; linked CSV/JSON records preserve
full precision. The two confidence estimates share one timer per process.

| N | Mode | Host total | Event pipeline span | Covered device-stage sum | Host global quantile | H2D Event sum | D2H Event sum |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 100000 | full-device | 76.926600 +/- 1.761343 | 6.738859 +/- 0.504523 | 6.052768 +/- 0.510090 | 0 +/- 0 | 0.003072 +/- 0 | 0.084864 +/- 0.009057 |
| 100000 | hybrid | 84.577567 +/- 1.115536 | 6.717835 +/- 0.548807 | 6.366912 +/- 0.489860 | 6.446100 +/- 0.102400 | 0 +/- 0 | 0.282709 +/- 0.054139 |
| 1000000 | full-device | 91.640367 +/- 9.078888 | 8.622624 +/- 1.206277 | 7.978805 +/- 1.174642 | 0 +/- 0 | 0.003413 +/- 0.000591 | 0.140960 +/- 0.035323 |
| 1000000 | hybrid | 162.102867 +/- 7.169224 | 11.159061 +/- 0.744213 | 8.060597 +/- 0.574160 | 76.012333 +/- 2.947261 | 0 +/- 0 | 2.598997 +/- 0.117646 |
| 10000000 | full-device | 110.996567 +/- 8.165285 | 24.259818 +/- 1.373012 | 23.519552 +/- 1.381327 | 0 +/- 0 | 0.003755 +/- 0.000591 | 0.163776 +/- 0.032142 |
| 10000000 | hybrid | 1020.957067 +/- 65.930355 | 50.215679 +/- 1.823335 | 21.581387 +/- 0.912191 | 882.868300 +/- 68.314774 | 0 +/- 0 | 24.443232 +/- 0.998514 |

| N | Mode | Flag memset Event sum | RNG Event sum | Loss Event sum | CUB Event interval | Gather Event interval |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 100000 | full-device | 0.003072 +/- 0 | 5.519701 +/- 0.518501 | 0.107861 +/- 0.002577 | 0.351819 +/- 0.012090 | 0.070315 +/- 0.005912 |
| 100000 | hybrid | 0.005803 +/- 0.000591 | 5.637173 +/- 0.450450 | 0.723936 +/- 0.041199 | 0 +/- 0 | 0 +/- 0 |
| 1000000 | full-device | 0.003072 +/- 0 | 6.560768 +/- 0.814363 | 0.528725 +/- 0.011045 | 0.823776 +/- 0.378324 | 0.062464 +/- 0.002709 |
| 1000000 | hybrid | 0.046421 +/- 0.002956 | 6.772373 +/- 0.465449 | 1.241803 +/- 0.125308 | 0 +/- 0 | 0 +/- 0 |
| 10000000 | full-device | 0.003072 +/- 0 | 10.887115 +/- 0.626207 | 4.856160 +/- 0.345572 | 7.672171 +/- 0.766465 | 0.101035 +/- 0.002132 |
| 10000000 | hybrid | 0.417792 +/- 0.007168 | 15.274027 +/- 0.790823 | 5.889568 +/- 0.146331 | 0 +/- 0 | 0 +/- 0 |

RNG had the largest mean among the five covered device-stage intervals in all
six configurations. This does not establish RNG as the largest end-to-end cost.
Full-device CUB means were 0.351819, 0.823776 and 7.672171 ms; loss means
were 0.107861, 0.528725 and 4.856160 ms. Hybrid's separate host global quantile
means were 6.446100, 76.012333 and 882.868300 ms, with their substantial spread
retained above. At N=10000000 its D2H Event sum also exceeded its RNG sum.
These are measured interval observations, not a proof of a bottleneck or an
explanation of an uninstrumented CPU/GPU performance gap.

## Timing definitions and omissions

- Host total retains the existing engine steady-clock boundary: allocation,
  native RNG, simulation, global quantile, required transfers, synchronization,
  temporary cleanup and initial CUDA context/API work inside the engine. Enabled
  diagnostic Event creation/query/destruction is included. Process startup,
  shared CSV/calibration, output, telemetry and delays are excluded.
- Pipeline span is one same-stream elapsed Event span through the final required
  D2H. It includes host enqueue gaps and waits between operations, including
  repeated synchronized batch-copy gaps. Full-device starts before the index
  copy and generator setup; hybrid starts after initial generator setup. Earlier
  allocation/context and subsequent cleanup are outside it; hybrid's later host
  global quantile is also outside it.
- Flag initialization covers device error-flag memset only. RNG brackets the
  cuRAND generation call, excluding complete host generator setup. Loss brackets
  the loss kernel; CUB brackets full-device SortKeys execution, excluding scratch
  query/allocation; gather brackets the nearest-rank gather. These Event intervals
  can contain host submission delay within their brackets and are not isolated
  active-kernel hardware durations.
- Hybrid initialization/RNG/loss intervals and counts are summed across all
  2/16/153 batches per run before repetition statistics. They are not average
  batch durations. Hybrid has zero CUB/gather intervals and one host sort/global
  quantile over all N losses. Full-device host_quantile_ms=0 is inapplicable.
- Copy diagnostics sum Event intervals. Native hybrid H2D is zero; full-device
  H2D transfers 16-byte rank indices. Hybrid D2H includes loss batches and error
  flags; full-device D2H includes two VaRs and the error flag. Pageable host
  staging is fully accounted for only in host total.
- The covered device-stage sum is a LIMITED transfer-excluded diagnostic:
  initialization+RNG+loss+CUB+gather, accumulated across batches. It omits copies,
  host setup/quantile/staging, allocation, context, cleanup and gaps between
  intervals. It is not a transfer-free end-to-end time.

Stage sums, pipeline span and host total are distinct; no equality is assumed.
No copy Event duration is subtracted from host time. Context, allocation, host
setup/staging, Event bookkeeping and cleanup are not independently measured as
stages. A host-versus-span difference does not measure any one of these costs.
Three repetitions provide limited spread evidence; a tiny interval's zero sample
standard deviation does not establish a constant hardware cost.

## Audit, conditions and remaining scope

The unchanged final auditor passed again at closure. Its explicit-sum/two-pass
variance independently reproduces all 66 Welford rows and checks complete order,
repetitions, raw outputs/exit statuses, lifetime, source/build/input/output hashes,
calibration, modes, batches, transfers, stage counts/sums and scope validity.
The original 260 campaign records and all 289 delivery records verified;
all 290 original campaign/review/failed-attempt files stayed unchanged.

The original auditor used internal C++ names instead of exported JSON
nvcc_version/device and stopped. The first correction then exposed PowerShell
5.1 Decimal decoding: later binary64 casts shifted 16 statistics by one ULP.
The final auditor parses serialized CSV/JSON numeric tokens directly to binary64
and compares them exactly. The existing 2e-12 statistics tolerance was unchanged.
All failed scripts/audits and correction hashes are retained. Reusable closure
auditing preserves this final calculation and is explicitly tested, including a
synthetic rehashed wrong-summary rejection; no measurement is run by the auditor.

During measurement, AC connection/saver/power scheme were stable. There were
37 available GPU point queries at 49-52 C; power limit was N/A throughout.
Physical conditions were NOT freshly confirmed. Earlier primary declarations
remain dated declarations only; the old approximately 15 C ambient estimate is
not a current measurement. CPU temperature, thermal equilibrium and absence of
throttling remain unknown. No bounded pre/post thermal windows were performed
for this diagnostic campaign; no machine-wide setting was changed.

The [closed primary benchmark](cpu-gpu-benchmark.md#formal-primary-result-2026-10-19)
remains separate and unchanged: 9.739930524x serial and 8.307208722x best
OpenMP at N=10000000 for full-device; the 10x serial target was not met and
hybrid did not beat best OpenMP. Instrumented diagnostic times are not replacement
primary samples or new uninstrumented speedup claims.

Bandwidth/counter permissions, exact-laptop documented peak, achieved DRAM GB/s
and percentage-of-peak reporting, convergence and final reproducibility/delivery
remain open. ERR_NVGPUCTRPERM persists; profiler orchestration remains unverified.
Optimization is optional and was not started. Academic submission and live
demonstration are unverified. Hosted CPU CI for the closure commit is separate
from local RTX diagnostic execution.
