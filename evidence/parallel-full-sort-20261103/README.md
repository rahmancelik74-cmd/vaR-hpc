# Matched full-sort study, 2026-11-03

Shareable aggregate evidence only; private raw observations remain under ignored
results/performance-study-20261103-run1. Measurement source:
1c5487e (full SHA in provenance.json). No source revisions were mixed.

39 full-engine configurations/sizes; 3 excluded warm-ups and 10 observations
each. Mean and sample SD use all ten samples. All times are milliseconds.
Serial-sort OpenMP rows precede explicit parallel-sort rows (including S=1).
The explicit CPU sort team is bounded by num_threads(S); useful merge work
shrinks by level. See docs/parallel-full-sort.md for algorithm and runtime.

At N=10000000, full-device GPU / fresh serial baseline = 10.061592590x.
The original 10x definition was met in this campaign. Historical 9.739930524x
remains separate. Estimates of 143 ms and 1.3x are not measured results here.
No portable EXE speedup was established or release package modified.

GPU diagnostics are separate fresh-process Event measurements at N=10000000,
3 excluded warm-ups plus 10 measured runs. RNG is the largest covered device
interval (46.2351%), CUB sort is 32.2873%. Host time is a separate denominator;
span/sum/copy/host rows overlap and cannot be added. Host generator setup,
context, allocation, staging and cleanup are not individually isolated.
No new hybrid bottleneck attribution or memory/race check is claimed.

Local CUDA-ON CTest 24/24; CUDA-OFF/OpenMP-ON CTest 23/23. Changed CPU pipelines
pass exact common-input/native invariance tests and five-seed N=10000000
analytical error-of-mean acceptance independently at .95 and .99.
Raw audit passed: 545 retained processes (13 diagnostic, 25 analytical,
507 primary), full coverage, means/sample SD, ratios, percentages, hashes and
CSV/JSON agreement. Temperature/equilibrium and actual clocks are unknown;
power conditions observed without changing settings; competing apps uncontrolled.

aggregate.csv/json contains every group; gpu-stages.csv/json contains means,
sample SD and percentages. percent_host divides by mean diagnostic host wall;
percent_covered divides by mean sum of initialization+RNG+loss+CUB+gather.
Only those five component intervals partition the covered denominator.
