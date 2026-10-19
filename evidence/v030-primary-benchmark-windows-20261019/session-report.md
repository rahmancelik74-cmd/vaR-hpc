# Formal Plan A CPU/GPU primary benchmark

Source SHA:  89536e38b01230fce3b4667096c29dde56795c23

Completed: 312/312 processes, 72 excluded warm-ups and 240 measured samples. Ten measured repetitions per configuration; no outlier filtering or replacement. Both recorder and supplemental session audits passed.

Fixture: exact synthetic_prices.csv bytes; seed 42; one unit; T=10/252 years; confidence .95/.99; native RNG; double precision.

Primary engine host time includes allocation, RNG, simulation, global quantile, necessary transfers, synchronization and temporary cleanup. It excludes process startup, shared CSV/calibration and output. Every sample uses a fresh CLI process/context; initial CUDA context/API work inside the engine remains included. Stage diagnostics and profilers were OFF for all primary samples.

## Complete configuration summary

| N | Configuration | Samples | Mean ms | Sample stddev ms | Scenarios/s | Serial/config | Best OpenMP/config |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 100000 | CUDA full-device | 10 | 98.587 | 15.929 | 1014331.28 | 0.093 | 0.085 |
| 100000 | CUDA hybrid | 10 | 104.551 | 21.564 | 956470.82 | 0.088 | 0.080 |
| 100000 | OpenMP 1 | 10 | 9.487 | 0.728 | 10541028.85 | 0.964 | 0.880 |
| 100000 | OpenMP 2 | 10 | 8.351 | 0.642 | 11974570.80 | 1.095 | 1.000 |
| 100000 | OpenMP 4 | 10 | 8.447 | 0.963 | 11838746.80 | 1.083 | 0.989 |
| 100000 | OpenMP 8 | 10 | 9.389 | 0.776 | 10650920.35 | 0.974 | 0.889 |
| 100000 | OpenMP 10 | 10 | 9.180 | 0.969 | 10893056.33 | 0.997 | 0.910 |
| 100000 | Serial | 10 | 9.149 | 0.950 | 10930693.94 | 1.000 | 0.913 |
| 1000000 | CUDA full-device | 10 | 105.347 | 18.269 | 9492478.92 | 1.018 | 0.915 |
| 1000000 | CUDA hybrid | 10 | 187.943 | 23.761 | 5320756.77 | 0.571 | 0.513 |
| 1000000 | OpenMP 1 | 10 | 105.688 | 10.355 | 9461774.53 | 1.015 | 0.912 |
| 1000000 | OpenMP 2 | 10 | 96.450 | 8.616 | 10368097.53 | 1.112 | 0.999 |
| 1000000 | OpenMP 4 | 10 | 96.368 | 9.213 | 10376892.90 | 1.113 | 1.000 |
| 1000000 | OpenMP 8 | 10 | 104.080 | 8.169 | 9608034.47 | 1.030 | 0.926 |
| 1000000 | OpenMP 10 | 10 | 107.315 | 11.005 | 9318342.73 | 0.999 | 0.898 |
| 1000000 | Serial | 10 | 107.222 | 10.360 | 9326441.59 | 1.000 | 0.899 |
| 10000000 | CUDA full-device | 10 | 126.720 | 21.834 | 78914079.14 | 9.740 | 8.307 |
| 10000000 | CUDA hybrid | 10 | 1087.934 | 74.898 | 9191730.51 | 1.134 | 0.968 |
| 10000000 | OpenMP 1 | 10 | 1223.901 | 111.922 | 8170593.29 | 1.008 | 0.860 |
| 10000000 | OpenMP 2 | 10 | 1110.965 | 123.347 | 9001184.63 | 1.111 | 0.948 |
| 10000000 | OpenMP 4 | 10 | 1052.690 | 113.526 | 9499469.89 | 1.172 | 1.000 |
| 10000000 | OpenMP 8 | 10 | 1072.683 | 112.909 | 9322415.17 | 1.151 | 0.981 |
| 10000000 | OpenMP 10 | 10 | 1068.608 | 119.312 | 9357964.47 | 1.155 | 0.985 |
| 10000000 | Serial | 10 | 1234.245 | 120.522 | 8102119.31 | 1.000 | 0.853 |

Speedups are ratios of measured configuration means. Best OpenMP is selected independently per N by lowest mean; all five OpenMP rows and their sample standard deviations remain above and in campaign/summary.csv. The denominator of sample variance is n-1. Throughput is 1000*N/mean_ms.

## GPU comparison

| N | GPU mode | Mean ms | Sample stddev ms | Million scenarios/s | Serial/GPU | Best OpenMP/GPU | Best OpenMP threads |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 100000 | full-device | 98.587 | 15.929 | 1.014 | 0.093 | 0.085 | 2 |
| 100000 | hybrid | 104.551 | 21.564 | 0.956 | 0.088 | 0.080 | 2 |
| 1000000 | full-device | 105.347 | 18.269 | 9.492 | 1.018 | 0.915 | 4 |
| 1000000 | hybrid | 187.943 | 23.761 | 5.321 | 0.571 | 0.513 | 4 |
| 10000000 | full-device | 126.720 | 21.834 | 78.914 | 9.740 | 8.307 | 4 |
| 10000000 | hybrid | 1087.934 | 74.898 | 9.192 | 1.134 | 0.968 | 4 |

At N=10000000 the full-device serial speedup is 9.7399305240447234, below the 10x target. Hybrid serial speedup is 1.1344847146209416, also below 10x. Full-device beats the best measured OpenMP mean at this N; hybrid does not. No selective rerun was performed. These are observations for this machine, fixture, native streams and declared conditions, not universal speed guarantees.

## Conditions and observation limits

USER DECLARATIONS, not measured facts: adapter connected; air intakes unobstructed with surface type unknown; built-in laptop cooling, with no external pad reported; vendor performance/fan modes unknown; GPT and Codex remain open; ambient temperature approximately 15 C, estimated without an instrument. Original declarations and the recorder copy are retained separately from telemetry.

Measured power records show AC connected, battery saver and active power scheme stable. The common process mask was ffff, normal priority; actual OpenMP teams matched requests. Windows schedules threads within the pool; no per-core pinning is claimed. Process-local OpenMP controls and original environment are archived.

Pre-observation: 25 GPU points scheduled at 0..120 seconds every five seconds; post-observation: 7 points at 0..30 seconds. Actual observed point spans were  119.999651  and  30.015172  seconds. Recorder preflight leaves  16.674  seconds between the pre-window end and first attempt; statistics/hash/audit work leaves  27.317  seconds between the last attempt and first post-window point. These gaps are outside primary engine timing.

All 657 GPU telemetry queries were available. Observed GPU temperature point range: 44..51 C. GPU power limit was N/A in every query. CPU temperature, fan mode, thermal equilibrium and absence of throttling are not established. OS CPU frequency fields are not measured turbo clocks. Open applications and laptop clock/power/thermal variability remain limitations; all slow samples are retained.

## Provenance and scope

Clean source and source tree, raw source snapshot, Release cache/project options, one shared executable, DLLs, fixture, exact argv, all attempts/raw output, per-attempt power/GPU observations and every recorder result hash are bound in campaign/manifest.json. The recorder independent audit and supplemental session-independent-audit.json cross-check the full matrix, numerical/model bindings, raw JSON, every CSV field, actual teams/modes/batches, user declarations and observation records.

The campaign manifest binds  3163  output records and  15  build artifacts. Hybrid requested/effective batch was 65535/65536 with 2,16,153 batches across the three N values. No confidence-row doubling, clipping or averaging of batch VaRs occurred.

A prior session, ../benchmark-formal-89536e3-20261019-run1/, stopped before campaign directory creation because the caller supplied an absolute build path to the recorder relative-build parameter. It started zero benchmark samples and is preserved as incomplete. The successful session is distinct and used the unchanged committed recorder with a relative build argument. No benchmark samples were rerun.

No profiling, separate diagnostic matrix, bandwidth campaign, convergence or optimization was run. Prior ERR_NVGPUCTRPERM remains unresolved; measured DRAM traffic and exact-laptop documented peak bandwidth are unavailable; profiler orchestration remains unverified. No machine settings, tracked source, commits or remote history changed. 