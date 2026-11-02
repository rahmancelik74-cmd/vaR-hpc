# Current technical state

Application version: 0.3.0. This summary distinguishes the implemented software,
recorded computational evidence and remaining research limitations. Original
experiment records retain their own source revisions and measurement conditions;
see the [evidence guide](evidence-guide.md).

## Software and distribution

- Serial C++, OpenMP and optional CUDA full-device/hybrid engines implement the
  shared Engine interface. Double precision and nearest-rank quantiles are retained.
- The separately scoped portfolio extension supports 1..5 positive long holdings,
  Cholesky-correlated shocks and one global loss quantile in every backend mode.
- The local browser application supports synthetic examples, validated local
  imports/calibration, backend comparisons, cancellation and JSON/CSV downloads.
  The service binds to loopback; no public hosting is provided.
- The [Windows portable CPU preview](windows-portable.md) includes its own Python
  runtime, serial/OpenMP engine, native launcher, required runtime DLLs and
  integrity metadata. CUDA development support remains a source-build option.
- [MIT](../LICENSE) applies to project code and original synthetic fixtures.
  Third-party runtime licenses and provider-data rights remain separate.
- The SignPath application has been submitted. Acceptance and certificate access
  are unconfirmed. No signing workflow is active; the published preview is unsigned.
  [Signing and privacy policy](code-signing.md).

The published portable ZIP retains source
`ab184ae913e52d9b41deadc9b0df316a4b189b55` and SHA-256
`3e6836f8c50936b87480b9488559d5326bfc5872d49fc8d06a9248c4c40b3b77`.
Later documentation does not change those release bytes.

## Numerical and data contract

The single-asset baseline uses exact terminal GBM, positive long value V0=q*S0,
loss V0-VT and confidence levels 0.95/0.99. Negative VaR is retained. The ascending
zero-based rank is ceil(alpha*N)-1 without interpolation. The analytical reference
uses the lower terminal-price quantile 1-alpha. Calibration uses log returns,
sample variance with denominator n-1 and annual price drift m/dt+0.5*sigma^2.
The study convention is 10 trading days with 252 trading days/year.

Public examples and benchmark fixtures are synthetic. Private historical
integration uses documented MSFT/AAPL unadjusted Close inputs and a bounded
Nasdaq 2023-2025 session calendar. Original data and derived private outputs are
not redistributed. A final redistributable historical-study dataset remains
unselected. [Data rights and calendar](data-rights-and-calendar.md),
[calibration](portfolio-calibration.md), [acceptance criteria](acceptance-source.md).

## Validation and reproducibility

Single-asset serial/OpenMP/CUDA validation separates common-input numerical
agreement, five-seed analytical acceptance and dynamic memory/race checks.
At N=10000000, analytical acceptance uses the error of the five-seed mean,
separately per backend and confidence. It is not an individual-seed or mean-
absolute-error test. The [FR/NFR audit](requirements-audit.md) preserves the
exact conditions and their recorded coverage.

Portfolio structural checks, independent-reference studies and hybrid validation
have separate registers and tolerances. The precision follow-up resolves the
recorded two-asset practical-target rows within its frozen scope; it does not
establish a universal portfolio convergence guarantee. See
[portfolio study](portfolio-campaign.md), [portfolio contract](portfolio.md),
[hybrid contract](portfolio-hybrid.md) and
[precision follow-up](../evidence/portfolio-precision-20261025-v1/README.md).

Hosted CI validates CPU builds, software contracts, portable packaging and
selected public evidence arithmetic. It does not execute local CUDA campaigns
or reproduce historical laptop performance. The
[reproducibility procedure](reproducibility.md) separates new builds from raw
execution provenance and derived figures. Original serial source-to-binary
limitations, mixed historical builds and local archive dependencies remain explicit.

## Recorded performance results

### Primary CPU/GPU comparison

The fixed synthetic campaign at source `89536e3` recorded 312 fresh processes:
72 excluded warm-ups and 240 measurements across 24 configurations. At 10000000
scenarios, CUDA full-device reached 9.739930524x serial and 8.307208722x best
measured OpenMP. The 10x serial target was not met. Hybrid did not beat best
OpenMP at that size. All repetitions and placement/power/thermal limitations
remain in the [primary benchmark](cpu-gpu-benchmark.md).

Primary host wall time includes allocation, RNG, valuation, quantiles, required
transfers, synchronization and cleanup; shared loading/calibration and output
are excluded. CUDA Event stages have a different scope and are reported separately.

### CPU stage diagnosis and isolated selection

The separate CPU stage campaign recorded 234 processes, with 54 warm-ups and
180 measurements. At N=10000000/OpenMP 10, loss generation averaged 47.99057 ms,
serial sorting 862.65182 ms and total engine time 929.58113 ms. Sorting accounted
for approximately 92.800% of that diagnostic total.
[Stage definitions and conditions](cpu-stage-diagnostics.md).

The isolated selection experiment at source
`08d7b89b4c03c567be6ca96ab473f1ca6c695e79` recorded 78 timed processes, including
18 warm-ups and 60 measurements. At N=10000000, sort plus lookup averaged
839.31637 ms and partial selection 76.27798 ms, a quantile-stage ratio of
11.00339x. Exact nearest-rank values and the recorded five-seed checks passed.
Production engines retain std::sort; total-engine improvement is unmeasured.
These results are not combined with older GPU times to claim a new speedup.
[Selection method, results and limitations](quantile-selection-experiment.md).

### DRAM reporting and convergence

The archived cold-cache collected-kernel profiles report 93.56973322125727 GB/s
full-device and 24.601233239555107 GB/s hybrid. Against the NVIDIA App-reported
256.032 GB/s configuration reference, the ratios are 36.54610877595663% and
9.60865565224468%. Reporting is satisfied within that recorded kernel scope;
these are not sustainable-peak or end-to-end utilization measurements.
[Interpretation](acceptance-source.md#documented-peak-interpretation-audit-2026-10-21).

Fixed-fixture convergence comprises 80 native observations, 160 estimates and
32 groups, with versioned figures and separate N=10000000 analytical acceptance.
Five-seed sample-size and historical provenance limitations remain.
[Convergence evidence](convergence.md).

## Application verification boundaries

Service/controller/engine checks cover input rejection, direct CLI equivalence,
cancellation/recovery, stale-result download prevention and raw export precision.
Bounded Windows VM observations cover startup, CPU analyses, JSON/CSV downloads
and native Stop with endpoint shutdown. Manual cancellation observations remain
distinct from instrumented process cleanup. Full clean-consumer certification,
all responsive layouts and assistive-technology coverage are not established.
[Browser coverage](local-browser.md), [portable verification](windows-portable.md).

## Remaining technical work

- Select a redistributable historical series and document its adjustment/reuse policy.
- Evaluate production selection integration using a matched total-engine protocol.
- Keep independent hardware validation and broader accessibility coverage separate
  from the bounded checks already recorded.
- Activate signing only after provider acceptance, confirmed access controls and
  signature/package verification. Existing unsigned assets remain immutable.

Analytical GBM agreement establishes computational correctness within the model,
not market predictive validity or investment suitability.
