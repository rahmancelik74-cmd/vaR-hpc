# Primary portfolio benchmark and statistical dataset

This directory is the single complete benchmark replacement permitted by
[the unchanged protocol v1](../PROTOCOL-v1.md). See [the attempt validity record](../attempt-validity.json).
The first full 546 timing processes remain unchanged in the parent, invalidated
for primary performance interpretation because executor metadata formatting
overlapped their measurements. The replacement has 546 new fresh processes:
126 excluded warm-ups and 420 measured runs, all retained across 42 cells.
No selective row replacement, parameter/tolerance change or additional attempt.

## Statistical scope

The original three independent 20M references and 135 native validation
processes were completed before the interfering operation. Their results and
records are copied byte-for-byte, not rerun: [reference](reference.json),
[native raw](validation-raw.csv), [per-seed estimates](validation-details.csv),
[convergence](convergence.csv). PCG64DXSM/NumPy reference generation with explicit
known factors is independent of serial/OpenMP/CUDA production RNG paths.
Both 95/99 percent quantiles, N=100k/1M/10M, seeds2026102501..2026102505.
Total simultaneous error allocation .01 is split between reference binomial
quantile bounds, DKW reference-CDF bounds and native Beta order statistics.
The practical target is .0005*V0 for the realized five-seed mean, including
the full reference CI and its half-width precision gate. It is not population
mean equivalence or the single-asset 1%-of-VaR criterion.

| Fixture | Alpha | Reference VaR | Reference interval (USD) | N=10M, all three engines |
| --- | --- | --- | --- | --- |
| five-identity | 0.95 | 87.403951359 | [87.316166127, 87.492891857] | pass |
| five-identity | 0.99 | 121.674185534 | [121.536891539, 121.818196426] | pass |
| two-negative | 0.95 | 70.515078407 | [70.442589521, 70.583956126] | pass |
| two-negative | 0.99 | 98.320144762 | [98.203467962, 98.439250952] | inconclusive |
| two-positive | 0.95 | 133.161756576 | [133.050425982, 133.276727039] | inconclusive |
| two-positive | 0.99 | 176.442775697 | [176.270991389, 176.610487281] | inconclusive |

No native seed quantile was rejected (0/270). At N=10M practical outcomes are
9 passed / 9 inconclusive / 0 failed. The inconclusive two-positive .95/.99
and two-negative .99 cases exceed the frozen reference half-width gate,
and the 20M reference cap was honored. Across all N: 23 passed / 31 inconclusive
/ 0 failed. Six of 18 absolute-error trajectories of seed means are nonmonotonic.
These results do not establish general portfolio VaR acceptance, a universal
convergence rate or market prediction.

## Primary timing results

| Fixture | N | CUDA mean +/- sample SD (ms) | Serial/CUDA | Best OpenMP | Best OpenMP/CUDA |
| --- | --- | --- | --- | --- | --- |
| two-positive | 100000 | 94.226190 +/- 14.591780 | 0.123277297 | openmp2 | 0.100001496 |
| two-positive | 1000000 | 104.426100 +/- 21.304540 | 1.126049331 | openmp4 | 0.905827375 |
| two-positive | 10000000 | 138.483330 +/- 14.969652 | 9.361277708 | openmp10 | 7.009375208 |
| five-identity | 100000 | 91.785140 +/- 9.545936 | 0.174796596 | openmp2 | 0.127902948 |
| five-identity | 1000000 | 98.336290 +/- 12.852780 | 1.561119908 | openmp4 | 1.066032489 |
| five-identity | 10000000 | 192.931080 +/- 14.859179 | 9.492752075 | openmp10 | 6.444923908 |

CPU baselines are faster at 100k in both fixtures; the two-asset 1M best OpenMP
mean is also faster than CUDA. The five-asset 1M CUDA advantage over best OpenMP
is only 1.066032489x by observed means, without a significance/dominance claim.
At 10M CUDA is faster than both CPU baselines here. No portfolio 10x threshold
or before/after optimization claim is imposed. All 42 thread-sweep rows and
scenarios/s appear in [benchmark-summary.csv](benchmark-summary.csv); every
warm-up/measured sample is in [benchmark-raw.csv](benchmark-raw.csv). Different
asset counts perform different work per scenario; ratios compare like workloads.

The engine timer includes per-run allocation/native RNG/correlation/GBM/
portfolio loss/global quantile/transfers/synchronization/cleanup and CUDA
context work inside the engine. It excludes process startup, shared parsing/
Cholesky, output, telemetry and 100ms delays. All processes and contexts are
fresh; diagnostic Events are disabled. Reference/validation, tests, formatting,
plotting, profiling and sanitizer work do not run alongside this replacement.

## Provenance and limitations

[manifest.json](manifest.json) identifies the same single freshly built x64
Release binary and source snapshot as the first attempt; no engine changed.
`executed_in_this_attempt=546` and `validation_records_reused=135` distinguish
new timing from copied validation. Full record IDs are scoped to this dataset.
Reference arrays are reused read-only from the original ignored directory.
Exact local production bytes and Git-normalized blob hashes are separate.
New tooling was uncommitted; the build trace is not independent source-to-binary
proof. [Environment](build-environment.json) and [inventory](machine-inventory.json)
record i7-12650H (10 core records/16 logical CPUs), RTX4060 Laptop, CUB3.4.3,
MSVC19.44.35227.0, nvcc13.4.92, architecture89 and Release flags.

All benchmark AC-source/battery-saver/scheme snapshots remained equal to this
attempt initial inventory. Same full pool ffff, normal priority, no per-core
pinning. CPU/ambient temperatures, vendor cooling/fan state and thermal
equilibrium are unverified; GPU temperatures/clocks are point observations.
No settings were changed. Existing sanitizer limitations remain; no new race
freedom, profiling-counter or general memory-safety claim is made.

Fresh-build focused CTests passed 8/8 and local Python tests passed 25 before
primary selection; read-only primary public/local audits passed. They rebuild
mean/SD/throughput/ratios/decisions independently from CSV, check figure values,
and locally verify all 681 selected record hashes and global reference arrays.
The 135 copied records count once as statistical executions. Original evidence
and single-asset FR/NFR requirements remain unchanged.

- [Convergence PNG](figures/convergence.png) / [SVG](figures/convergence.svg): mean +/- per-seed sample SD, reference CI band, 5bp target.
- [Runtime PNG](figures/runtime.png) / [SVG](figures/runtime.svg): all configurations, mean +/- sample SD.
- [Speedup PNG](figures/speedup.png) / [SVG](figures/speedup.svg): mean ratios with descriptive spread envelopes, not CIs.
- [Figure values](figure-data.json) are checked against exported CSVs. Final figures were visually inspected.

```text
python -B scripts/portfolio_benchmark_replacement.py analyze
python -B scripts/plot_portfolio_campaign.py
python -B scripts/verify_portfolio_campaign.py
python -B scripts/verify_portfolio_campaign.py --local
```

Public verification needs standard-library Python only; analysis/figures need
the existing NumPy/SciPy/Matplotlib environment and original ignored arrays.
Large local artifacts, failed metadata/render attempts and the completion record
are in `results/portfolio-campaign-20261025/`. No advisor approval, academic
submission or overall project completion is claimed.
