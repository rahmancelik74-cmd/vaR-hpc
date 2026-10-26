# Portfolio statistical validation and formal benchmark

A separate [post-campaign precision follow-up](../evidence/portfolio-precision-20261025-v1/README.md)
now supplies fixed 80M references for both two-asset fixtures and corroborating
one-dimensional conditional integration. Its twelve unchanged N=10M observed
five-seed means all pass the original .0005*V0 practical rule against the new
rank intervals, including all nine formerly inconclusive rows. The new 99%
coverage family includes only its four reference quantiles; original coverage
and results below remain separate. No historical Beta/DKW decision, five-asset
reference, native output or formal benchmark was replaced or rerun. The new
interval widths also reflect a distinct predeclared error-budget allocation.

This synthetic extension study has its own P-V1/P-V2/P-V3/P-B1 protocol.
The existing single-asset FR/NFR requirements and historical campaigns are
unchanged. The initial [portfolio implementation evidence](../evidence/portfolio-extension-20261025/README.md)
remains historical structural/moment/capacity/sanitizer coverage. The new
[campaign package](../evidence/portfolio-campaign-20261025/README.md) reports
native-RNG quantile validation, convergence and portfolio timing separately.

## Frozen design and statistical meaning

The [v1 protocol](../evidence/portfolio-campaign-20261025/PROTOCOL-v1.md),
[executable matrix](../evidence/portfolio-campaign-20261025/protocol-v1.json) and
[initial exact-byte freeze ledger](../evidence/portfolio-campaign-20261025/freeze-v1.json)
precede campaign results. No pilot or revised acceptance threshold was used.
The original two/five-asset fixtures are included byte-for-byte; an additional
two-asset correlation -0.6 fixture contrasts with +0.6 and five-asset identity.
All remain fixed positive holdings in USD under constant-parameter GBM.

An independent installed Python/NumPy/SciPy CPU reference uses PCG64DXSM,
explicit known factors and terminal-price summation, not production serial,
Cholesky or loss/quantile helpers. It generates 20M reference scenarios per
fixture in bounded chunks and sorts the complete scalar loss file. One global
inverted-CDF quantile is used, with no interpolation or chunk VaR averaging.
One-asset analytical, deterministic, small-scenario and exact-moment checks
validate the oracle. Reference arrays stay ignored; summaries and reproduction
code are public. A high-N reference is not exact truth.

Both .95 and .99 are evaluated for native serial, OpenMP10 and CUDA full-device
at N=100000/1000000/10000000, with five fixed seed settings
2026102501..2026102505: 135 independent CLI invocations, 270 quantile estimates.
Equal seed labels across backends do not identify equal sample streams.
The same seed's samples across N may be related; no independence across the
entire comparison matrix is required by the Bonferroni allocation.

Total simultaneous error allocation .01 is split among reference quantile
binomial rank intervals (.0025), uniform reference empirical CDF error via
DKW-Massart (.0025), and native order-statistic Beta bounds (.005). Native
consistency means that the reference empirical CDF at a native quantile is
inside its calibrated probability-scale acceptance band. A nonrejection is
not equivalence. Separately, the practical target is .0005*V0 (5 capital basis
points), justified as a numerical loss resolution for these examples. It is
not the old single-asset 1%-of-VaR criterion or a supervisor-approved extension
requirement. The maximum distance from the realized five-seed mean to either
reference CI endpoint must be within that target to demonstrate it; an interval
overlap alone is insufficient. This targets the observed mean, not an expected
estimator mean across all possible seeds. Excess reference uncertainty yields
inconclusive status without unbounded escalation. See the protocol for exact
ranks, multiplicity, failures and the 20M hard reference cap.

Convergence tables retain every seed, seed mean/sample SD, signed and absolute
error, reference CI and each decision. Three N values do not establish a
universal convergence rate or require monotonically decreasing realized error.

## Formal timing scope

Original two/five-asset fixtures only; same three N; serial, OpenMP1/2/4/8/10
and CUDA full-device. Each of the 42 cells has 3 excluded warm-ups and 10
measured repetitions, for 546 fresh-process invocations (126/420). Every slow
sample is retained; no value-based outlier removal or selective replacement.
Validation/reference runs finish before timing. No profiling/sanitizer work
overlaps measured samples. Portfolio hybrid remains explicitly unsupported.

All samples use the same freshly built Release executable. Existing
`end_to_end_ms` excludes process startup, shared input parsing/Cholesky and output;
it includes per-run allocation, native RNG, correlation, GBM valuation, scalar
portfolio losses, global quantile, required transfers, synchronization, cleanup
and CUDA context work inside the engine. Every warm-up/measured process has a
fresh CUDA context. Native GPU generation is not replaced with host normals.
Diagnostic CUDA Events are disabled; there is no kernel-time speedup substitution.

The existing launcher creates suspended owned processes at normal priority,
sets/checks the same full available CPU pool before resuming, and records
power snapshots. OS worker scheduling is not per-core pinning. AC source,
battery saver and active scheme must match initial observations. CPU temperature,
room temperature, cooling/fan settings and thermal equilibrium are unverified.
GPU temperatures/clocks are point observations, not proof of stable operation.
No system settings were changed. The 2- and 5-asset workloads perform different
work per scenario; ratios compare the same fixture and N. No portfolio 10x
target, DRAM-counter measurement or optimization improvement is claimed.

## Reproduction

Production baseline is b33f061a75c17e579ce27bcc9915284e6d9d7812. The manifest
distinguishes exact local source bytes, Git-normalized blobs, tooling dirty
state and the fresh build/binary/cache hashes. A build trace is provenance,
not independent source-to-binary reproducibility proof. NumPy/SciPy/Matplotlib
are analysis dependencies only; the application has no new dependency.

Read-only public arithmetic/figure-data checks (standard library):

```powershell
python -B scripts/verify_portfolio_campaign.py
```

Recreate summaries/figures locally with the retained reference arrays and runs:

```powershell
python -B scripts/portfolio_benchmark_replacement.py analyze
python -B scripts/plot_portfolio_campaign.py
python -B scripts/verify_portfolio_campaign.py --local
```

`--local` additionally checks all native process record hashes, launcher/power
conditions, global reference sorting/order ranks and exact build artifacts.
For fresh execution, use a new dated attempt directory and update the tool's
PUBLIC/LOCAL/BUILD constants to it, retain the frozen protocol/fixtures, and
build with the existing VS x64 developer environment:

```powershell
cmake -S . -B build-portfolio-campaign-20261025 -G Ninja -DCMAKE_BUILD_TYPE=Release -DMC_ENABLE_CUDA=ON -DMC_ENABLE_OPENMP=ON -DMC_BUILD_CPU_TOOLS=ON -DCMAKE_CUDA_ARCHITECTURES=89
cmake --build build-portfolio-campaign-20261025 --parallel 4
python -B scripts/portfolio_campaign.py reference
python -B scripts/portfolio_campaign.py run
```

Reference and run actions refuse existing attempt data. A fresh execution must
not overwrite the published package or ignored original arrays. Protocol
revisions require a preserved new version and fresh confirmatory evaluation.
No general portfolio VaR correctness, market prediction, advisor approval or
academic submission follows from the finite synthetic study.

## Measurement-condition correction

The first complete timing attempt overlapped an executor metadata serialization
that unexpectedly consumed CPU time. The entire first benchmark was invalidated
for primary performance interpretation, rather than removing selected slow rows.
Its 546 raw samples, summaries, figures and tooling snapshots remain retained.
The protocol's single complete replacement is recorded in
`evidence/portfolio-campaign-20261025/benchmark-replacement-v1/` and
`results/portfolio-campaign-20261025/benchmark-replacement-v1/` using the same
binary, fixtures, seed42, N grid and 3/10 repetition policy. Metadata setup
finishes before replacement timing. No more replacements are permitted.

The 20M references and 135 native statistical runs completed before the
interfering operation and are reused unchanged, with explicit original record
identities. They are not rerun or relabelled as a pilot. `primary-selection.json`
directs plotting and the read-only verifier to the replacement dataset.
The replacement analysis wrapper above uses original reference arrays read-only.
The old `portfolio_campaign.py analyze` command reproduces the retained first
attempt's summaries, whose performance interpretation is invalidated.
