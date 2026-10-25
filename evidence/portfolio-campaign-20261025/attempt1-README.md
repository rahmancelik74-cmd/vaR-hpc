# Portfolio native VaR validation, convergence and formal timing

Executed on 2026-10-25 against production baseline
`b33f061a75c17e579ce27bcc9915284e6d9d7812`. Production engines and numerical
contracts were unchanged. This is a separate extension study, not a replacement
for FR-1..FR-9/NFR-1..NFR-9 or the historical single-asset campaigns.

## Frozen protocol and coverage

[PROTOCOL-v1.md](PROTOCOL-v1.md), [protocol-v1.json](protocol-v1.json), and
[freeze-v1.json](freeze-v1.json) were persisted before any reference/native
campaign output. No pilot, protocol revision, replacement attempt or outlier
exclusion occurred. Initial exact-byte SHA-256:

- Protocol prose: `b3f83822b69d10efa5aef081c944b20bb72f60daa9ab88fde2fdf7f4d2545471`.
- Protocol matrix: `7bbc540d342a1458de01e888f0e58bf5d6af9f165d6c3c202b0f5a31fdb0123c`.

Original two-asset +0.6 and five-asset identity fixtures are copied exactly;
an original-parameter two-asset -0.6 fixture adds a contrasting case. Input
hashes are frozen in the protocol. All inputs are redistributable synthetic USD
fixed positive holdings, with no provider data/calibration/FX/rebalancing.

Independent NumPy PCG64DXSM references use 20M scenarios per fixture, explicit
known correlation construction, terminal-price sums and one global
`quantile(method="inverted_cdf")`. They do not call the production serial
engine or its helpers. Python 3.11.4, NumPy 1.24.3, SciPy 1.10.1; runtime/module
hashes and oracle checks are in [reference.json](reference.json) and
[oracle-checks.json](oracle-checks.json). Large sorted arrays are ignored locally.
Reference order-statistic intervals are uncertain, not exact truth.

Native serial, OpenMP10 and CUDA full-device use N=100000/1000000/10000000
and seeds 2026102501..2026102505. [validation-raw.csv](validation-raw.csv)
retains 135 runs; [validation-details.csv](validation-details.csv) retains
270 quantile comparisons. Common normals are not used.

## Statistical outcomes and limits

Family error allocation is .01: .0025 reference binomial quantile intervals,
.0025 reference DKW uniform CDF bounds and .005 native order-statistic Beta
bounds. The probability-scale consistency test rejected 0/270 native seed
quantiles. Nonrejection is not equivalence. The practical target is .0005*V0
(5 capital basis points), applied to the observed five-seed mean and the entire
reference interval, with a separate reference half-width <= target/2 gate.
No target was borrowed from the single-asset 1%-of-VaR rule.

| Fixture | Alpha | Independent reference | Reference interval (USD) | Half-width / V0 (bp) | N=10M practical result, all three engines |
| --- | --- | --- | --- | --- | --- |
| five-identity | 0.95 | 87.403951359 | [87.316166127, 87.492891857] | 1.244547 | pass |
| five-identity | 0.99 | 121.674185534 | [121.536891539, 121.818196426] | 1.981020 | pass |
| two-negative | 0.95 | 70.515078407 | [70.442589521, 70.583956126] | 1.606439 | pass |
| two-negative | 0.99 | 98.320144762 | [98.203467962, 98.439250952] | 2.679352 | inconclusive |
| two-positive | 0.95 | 133.161756576 | [133.050425982, 133.276727039] | 2.571603 | inconclusive |
| two-positive | 0.99 | 176.442775697 | [176.270991389, 176.610487281] | 3.857908 | inconclusive |

The N=10M endpoint has 9/18 passed and 9/18 inconclusive practical cells,
0 failed cells under the frozen decision rule. Five-asset .95/.99 and
two-negative .95 passed for all engines. Both two-positive confidence levels
and two-negative .99 remain inconclusive because their reference half-width
exceeds the frozen 2.5-capital-bp precision gate (the practical target is 5 bp).
The fixed 20M reference cap was honored: no post-outcome escalation or tuning.
Across all N there are 23 passed / 31 inconclusive / 0 failed practical cells.
This is uncertainty-limited evidence, not completion of general portfolio VaR
statistical acceptance. Exact bounds/dispersion/decisions are retained in
[convergence.csv](convergence.csv).

Six of the 18 fixture/engine/confidence trajectories of absolute error in the
seed mean are nonmonotonic over the N grid. Larger-N dispersion is informative for these
fixtures, but three N values/five seeds do not establish a universal rate.
The test relies on ideal-iid modeling of PRNG samples and continuous losses;
equal seed labels across backends do not promise common paths. No market
predictive validity, advisor approval or academic submission is claimed.

## Formal portfolio benchmark

[benchmark-raw.csv](benchmark-raw.csv) retains every one of 546 fresh-process
samples: 126 excluded warm-ups plus 420 measured runs. Each fixture/N/config
has 3 warm-ups and 10 measured repetitions. All 42 rows, including OpenMP
1/2/4/8/10, are in [benchmark-summary.csv](benchmark-summary.csv). Both VaR
levels share one timer; they are not two performance samples.

| Fixture | N | CUDA mean +/- sample SD (ms) | Serial / CUDA | Best OpenMP | Best OpenMP / CUDA |
| --- | --- | --- | --- | --- | --- |
| two-positive | 100000 | 86.809620 +/- 4.920209 | 0.135832872 | openmp2 | 0.117702854 |
| two-positive | 1000000 | 100.206900 +/- 12.372209 | 1.247797208 | openmp4 | 0.970144272 |
| two-positive | 10000000 | 142.357330 +/- 21.379169 | 10.028741267 | openmp10 | 7.928185574 |
| five-identity | 100000 | 90.091240 +/- 7.759674 | 0.198629412 | openmp4 | 0.140493793 |
| five-identity | 1000000 | 102.694510 +/- 9.825845 | 1.482139211 | openmp4 | 1.032470090 |
| five-identity | 10000000 | 176.255010 +/- 20.127852 | 9.660401199 | openmp10 | 6.596053638 |

CPU baselines are faster at 100k for both fixtures. At 1M the two-asset best
OpenMP mean is faster than CUDA; five-asset CUDA is only 1.032470090x best
OpenMP by observed means, without a claim of statistically significant dominance.
At 10M CUDA is faster than both CPU baselines in these measurements. There is
no portfolio 10x threshold and no before/after optimization claim. Two- and
five-asset scenarios perform different work; ratios compare like fixtures/N.

The primary timer includes per-run allocation, native RNG, correlated terminal
GBM, portfolio losses, global quantile, transfers, synchronization and cleanup
plus CUDA context work within Engine::run. Process startup, shared input/
Cholesky preparation, output, launcher telemetry and 100ms delays are excluded.
Every process/context is fresh, including warm-ups; no persistent engine reuse.
CUDA Event diagnostics/profiling/sanitizers are not part of these samples.
Reference and validation completed before benchmark execution.

## Provenance, checks and figures

[manifest.json](manifest.json) binds the dedicated x64 Ninja Release executable,
DLLs/CMake cache/build plan, exact local production bytes and separately
labelled Git-normalized source blobs. New tooling was uncommitted during
execution; production files matched the baseline. This is an observed fresh
build trace, not independent source-to-binary proof or a claimed clean tooling
commit. Ignored build log: `results/portfolio-campaign-20261025/build.log`.

[build-environment.json](build-environment.json) records i7-12650H, MSVC
19.44.35227.0, nvcc13.4.92, architecture89, CMake3.31.6-msvc6 and flags.
[machine-inventory.json](machine-inventory.json) records 10 physical core records,
16 logical CPUs and full mask ffff. The launcher sets/checks normal priority
and the same full pool; it is not per-core pinning. Native GPU metadata records
RTX4060 Laptop/CUB3.4.3 and distinct runtime/header/driver observations. All
benchmark AC-source, battery-saver and power-scheme snapshots matched initial
conditions. Battery percentage is retained without filtering. CPU temperature,
ambient/cooling/vendor settings and thermal equilibrium remain unverified;
GPU snapshots are point readings. No machine settings were changed.

The independent read-only verifier reconstructs mean/sample SD/throughput/
speedups and practical decisions from raw CSVs, checks figure series against
exports, and with --local checks all 681 full process-record hashes, launcher
conditions, sorted reference arrays/order ranks/binomial coverage and binary
hashes. The local audit passed. Fresh-build focused CTests passed 8/8; Python
discovery passed 25 tests, including 3 new tooling checks. Historical selected
public-evidence integrity passed. Engine behavior and original evidence packages
were unchanged. No new sanitizer scope is claimed.

Figures were visually inspected: labels/legends/spread are readable without
clipping. The first render failed an object-dtype artist comparison; the display
audit now explicitly converts artist values to float without changing data.
The failed render log is retained locally, and no campaign was rerun.

- [Convergence PNG](figures/convergence.png) / [SVG](figures/convergence.svg): seed means +/- sample SD, reference uncertainty, 5bp target.
- [Runtime PNG](figures/runtime.png) / [SVG](figures/runtime.svg): complete thread sweep, mean +/- sample SD.
- [CUDA speedup PNG](figures/speedup.png) / [SVG](figures/speedup.svg): like-workload mean ratios; descriptive spread envelopes, not confidence intervals.
- [figure-data.json](figure-data.json): artist values independently checked against CSV exports.

## Reproduce analysis without campaigns

```text
python -B scripts/verify_portfolio_campaign.py
python -B scripts/portfolio_campaign.py analyze
python -B scripts/plot_portfolio_campaign.py
python -B scripts/verify_portfolio_campaign.py --local
```

Only the first command needs public CSV/JSON alone and standard-library Python.
The other commands use retained local arrays/records and installed numerical
libraries as described in [the runbook](../../docs/portfolio-campaign.md). Raw
launch records, arrays, logs and the persistent completion note are ignored
under `results/portfolio-campaign-20261025/`. SHA-256 inventory is separate
from Git-normalized blob identities; package .gitattributes preserves exact
protocol/fixture/export/figure bytes. No school repository was used.
