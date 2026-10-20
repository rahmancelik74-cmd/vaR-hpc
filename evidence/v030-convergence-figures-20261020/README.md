# Offline convergence figures, 2026-10-20

These selected technical figures use the completed
[fixed-fixture convergence evidence](../v030-convergence-windows-20261020/README.md).
No native simulation, timing campaign, regression/acceptance campaign, profiling,
optimization or academic authoring ran for this figure checkpoint.
Repository HEAD during generation was 390ffa670960f83a0de4fb0b9cd595cb03cdbc8e;
the new GPU observations were tested at b5f1a0f5b72bca8f1f21555236d938501f7faee8.
Earlier reused observations retain their individual source revisions.

## Figures and interpretation

[Combined four-page PDF](convergence_figures.pdf):

1. [Error versus scenario count](01_error_vs_scenarios.svg): absolute error of
   the five-seed mean and descriptive mean absolute error, separately at .95/.99.
2. [Per-seed signed errors](02_seed_signed_errors.svg): all 160 estimates,
   separated by engine/mode and confidence. Equal seed labels do not imply
   common random samples across backends or modes.
3. [Variation across seeds](03_seed_standard_deviation.svg): sample standard
   deviation with denominator n-1; this is not a confidence interval.
4. [Separate 10M acceptance](04_separate_10m_acceptance.svg): absolute error of
   mean divided by allowed error; all eight rows pass the original criterion:
   abs(mean(VaR)-analytical) <= .01*max(abs(analytical),.01*V0).

The complete matrix is serial, OpenMP with four threads, CUDA full-device and
CUDA hybrid, N=10000/100000/1000000/10000000, seeds 42/123/456/789/2026 and
alpha=.95/.99. It reuses 55 observations and 25 completed missing GPU processes;
it is not one new common-build campaign. Exact fixture/model and actual batch
metadata are retained in the numerical evidence linked above.

Error is not monotonic: GPU .95 mean error increases from 10K to 100K, and .99
mean error increases from 1M to 10M. All 40 paired full-device/hybrid VaRs match
exactly in this dataset. Distinct markers retain the overlap without jitter;
neither mode equivalence nor batch-size invariance is established.

Five seeds and one synthetic fixture do not establish a fitted/universal Monte
Carlo rate, an error guarantee or predictive market validity. Serial historical
source-to-binary verification=false, unavailable published standalone OpenMP
cache and mixed-revision reuse remain explicit limitations. Timing and primary
benchmark speedup claims are separate and unchanged.

## Calculation, scales and reproduction

verification.json records independent fixture log-return/two-pass sample-variance
calibration and analytical reference checks, 160 per-seed values, 32 groups and
eight unchanged acceptance rows. Means, signed/absolute mean errors, seed sample
SD, MAE and RMSE were independently recomputed with a 2e-12 relative rounding
tolerance. All original input hashes remained unchanged. The original generation
verification lists PNG/SVG/PDF outputs; this selected record retains four SVGs
and the combined PDF. selection-manifest.json inventories this directory only.

Positive logarithmic axes preserve raw zero values with separately labeled zero
markers rather than epsilon substitution; none of the plotted group metrics is
zero here. Signed errors use symlog with the explicitly labeled linear region
|error| <= .001. Relative error is N/A when |reference| < .01*V0, retaining
error/V0; current references exceed that threshold. Raw values stay unchanged.

Full underlying per-seed.csv, summary.csv, acceptance-10m.csv, analysis.json and
provenance are retained in ../v030-convergence-windows-20261020/. The script
requires the original hash-bound local archive as well as those selected exports;
a Git checkout alone does not provide every original archived build/result.
It rejects an existing output directory and never starts an engine process.
Using the already installed Python 3.11.4 and Matplotlib 3.7.1, from repo root:

```text
python -B evidence/v030-convergence-figures-20261020/convergence_figures.py --repository . --output results/convergence-figures-reproduced
```

No dependency installation is implied. The local complete PNG/SVG/PDF package
remains under results/convergence-figures-390ffa6-20261020-final/; layout drafts
run1/run2 are preserved separately. Historical measurement evidence is untouched.
The figures and local Git documentation changes do not establish a commit, push,
hosted CI result, academic submission or live demonstration.
