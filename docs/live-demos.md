# Live demonstration runbook

Two separate required roadmap demonstrations are prepared here. Preparation and
local rehearsal do not establish academic week, presentation, submission or
overall project completion. No presentation or submission is performed by the
launcher. Use Windows PowerShell 5.1+, from the repository root.

## Prerequisites and launch

Use a validated Windows x64 Release build with OpenMP ON, testing ON and
`mc_var.exe` plus `mc_openmp_tests.exe` under `Release/`. The final flow also
requires CUDA ON, its deployed runtime/cuRAND DLLs and a working NVIDIA device.
The existing local `build-convergence-b5f1a0f-5c4032` is suitable for rehearsal;
it is an archived build, not proof of compilation from the current HEAD.
The launcher records executable, test, cache and exact-byte fixture hashes and
explicitly leaves source-to-binary verification false. It does not build/install
anything or alter environment/system settings.

```powershell
./scripts/run-live-demo.ps1 -Demo first-term -BuildDirectory build-convergence-b5f1a0f-5c4032
./scripts/run-live-demo.ps1 -Demo final -BuildDirectory build-convergence-b5f1a0f-5c4032
```

Each launch creates a unique ignored `results/live-demo-*` directory. Keep
`commands.json` (argv, actual output, exit status and observed command duration),
per-engine JSON and `summary.json`. These local captures can contain local paths;
do not publish them as historical campaign evidence. Failure stops the flow and
retains partial logs. Ctrl+C interrupts a run; retain that directory, check that
the child has ended, then relaunch to a new directory. Only a completed
`status: rehearsed` summary establishes successful local rehearsal.

## A. First-term: CPU validation and timing

Allow about 2-3 minutes for narration; actual execution is much shorter.

1. State the model: one positive long unit, `V0=q*S0`, double precision, exact
   terminal GBM `VT=V0*exp((mu-.5*sigma*sigma)*T+sigma*sqrt(T)*Z)`.
   Loss is `V0-VT`; negative VaR is retained. Sort losses ascending and select
   zero-based `ceil(alpha*N)-1`, without interpolation. Mu is annual price drift,
   sigma is per square root of year and T is in years. Values use the fixture's
   arbitrary price/value units, not asserted real currency.
2. The launcher runs the existing focused `mc_openmp_tests.exe`. Expect
   `OpenMP common-input, native determinism and failure tests passed.`
   It supplies identical read-only normals to serial/OpenMP at boundary sizes,
   checks exact agreement and caller preservation, and separately checks native
   OpenMP thread invariance. It is not a five-seed campaign or race proof.
3. Show the small serial CSV run, then OpenMP with explicit 1 and 4 threads.
   All use N=100000, seed 42, horizon 10 trading days and 252 trading days/year.
   The JSON shows .95/.99 `mc_var`, `analytical_var`, `signed_error`, model,
   calibration, requested/actual threads, RNG and `end_to_end_ms`.

Talking points: "This is hand-written synthetic data, not historical market
observations. The serial result is the baseline. Equal seeds across native
engines do not imply identical samples; the preceding test used common inputs.
These single-run timings illustrate execution, not measured speedup evidence."

## B. Final: input to all engines and evidence

Allow about 4-5 minutes including evidence discussion. The final launcher runs
the same focused CPU check and three CPU examples, then explicit CUDA full-device
and hybrid at N=100000. No automatic engine fallback is permitted.

Explain the pipeline using [the public synthetic fixture](../data/synthetic_prices.csv):
12 closes, 11 log returns, sample variance denominator n-1, annualization
`sigma=sqrt(s2/dt)`, `mu=m/dt+.5*sigma*sigma`, `dt=1/252`, last close 100.4,
q=1 and T=10/252. Expect annual drift about 0.112217495 and volatility
0.203783791; analytical VaR about 6.143576939 at 95% and 8.715446716 at 99%.
MC values vary by native stream/build; no individual-run accuracy threshold is
imposed by this demo. Analytical VaR uses terminal-price probability `1-alpha`.

Talking points: "The contribution is verifiable computational correctness and
performance, not market prediction or investment suitability. Full-device uses
GPU RNG, simulation and CUB quantile selection. Hybrid is explicitly selected:
requested batch 65535 becomes 65536, with two batches here. Its host sort selects
one global nearest-rank quantile over all scalar losses; it never averages batch
VaRs. Read mode, device, quantile location, transfers and batch metadata from the
actual JSON. Native equal seeds do not ensure common samples."

All fresh times are illustrative rehearsal timings. Each CLI has a fresh process
and CUDA context. `end_to_end_ms` includes engine allocation, RNG, simulation,
quantile, necessary transfers, synchronization and cleanup; it excludes process
startup, shared input/calibration and output. Captured command duration is a
different wall-time scope. No CUDA Event diagnostic/profiling sample is requested.
Temperatures, clocks and thermal equilibrium are unknown. Do not infer speedup
from these isolated, unconditioned executions.

Open these existing records for the historical discussion, without rerunning them:

| Evidence | Observable fact and boundary |
| --- | --- |
| [CPU common-input evidence](../evidence/v030-openmp-windows-correctness-20261016/README.md) | Established synthetic correctness; native seeds and common inputs are distinct |
| [Convergence and 10M acceptance](../evidence/v030-convergence-windows-20261020/README.md), [eight acceptance rows](../evidence/v030-convergence-windows-20261020/acceptance-10m.csv) | Five seeds 42/123/456/789/2026 per engine/mode and confidence; error of mean criterion, not mean absolute error or per-seed rule |
| [Convergence figures](../evidence/v030-convergence-figures-20261020-v2/README.md), [protocol](convergence.md) | 80 runs, 160 values, 32 groups; error is not monotonic at every N increase |
| [Formal benchmark](../evidence/v030-primary-benchmark-windows-20261019/README.md), [interpretation](cpu-gpu-benchmark.md) | Full-device 9.739930524x serial, 8.307208722x best OpenMP; 10x serial target unmet; hybrid did not beat best OpenMP at 10M |
| [GPU checks and sanitizer scope](gpu-acceptance.md) | Representative recorded cases; no sanitizer-at-10M or general global-memory race-freedom claim |
| [Reproducibility](reproducibility.md), [FR/NFR mapping](requirements-audit.md) | Hosted CPU reproduction does not reproduce CUDA/historical performance; historical serial source-to-binary=false, missing independent historical OpenMP cache and mixed-revision convergence remain |
| [Bandwidth interpretation](acceptance-source.md#documented-peak-interpretation-audit-2026-10-21), [environment](environment.md) | Reporting closed in recorded cold-cache kernel scope using NVIDIA App configuration reference; no new administrator/OEM research action or supervisor approval inferred |

The exact 10M criterion is separately per engine and confidence:
`abs(mean(VaR)-analytical_VaR) <= .01*max(abs(analytical_VaR),.01*V0)`.
Common-input difference must be `<= .00001*V0`; agreement does not replace
memory/concurrency checks. Live 100K execution is neither of those campaigns.

## Recovery

Missing executable/cache/test: stop and use the explicit current Release build
commands in [reproducibility.md](reproducibility.md#1-build-and-check-current-software).
Choose a new build directory; check each configure/build exit before launching.
For CUDA use its documented CUDA ON/toolset/architecture options and deployed
DLLs, and validate the build before the demonstration. Do not reuse an unrelated
binary by renaming it or install dependencies from the launcher.

Unavailable CUDA/device/runtime or allocation failure: preserve the error and
failed final summary. The first-term command remains an explicit CPU recovery
flow; historical GPU evidence can be discussed separately. Neither establishes
a successful live CUDA demonstration. Resolve the actual reported prerequisite
and retry only when it changes. An interrupted/failed final flow is incomplete,
even if its CPU examples succeeded. No private Kibot input, correspondence or
calibration output is needed or redistributed.
