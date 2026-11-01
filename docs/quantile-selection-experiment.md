# CPU quantile selection experiment

The production serial/OpenMP engines retain `std::sort`. An optional research
executable compares full sorting with partial selection on identical finite
loss samples. It does not change `Engine::run`, RNG assignment, the CLI, JSON
schema, application package or previous benchmark evidence.

## Quantile methods and comparison boundary

| Engine/mode | Existing quantile path | Location |
| --- | --- | --- |
| Serial and OpenMP | `std::sort` ascending, then shared nearest-rank lookup | Host |
| CUDA full-device | CUB `DeviceRadixSort::SortKeys<double>` over all N keys, bits 0..64; device rank gather | Device |
| CUDA hybrid | Transfer all batch losses; `std::sort` once over all N losses; shared rank lookup | Host |

These paths were inspected in `src/core.cpp`, `src/openmp.cpp`, `src/cuda.cu`
and their exported metadata in `src/output.cpp`. Full-device does perform a
full radix sort, not a partial order-statistic selection. Hybrid computes one
global quantile and does not average batch quantiles. The maintained CUDA
library reference is CUB 3.4.3; runtime output records the built library version.

Primary CPU/GPU speedups use each engine's host `end_to_end_ms`: per-run
allocation, RNG, loss generation, quantile work, required copies/synchronization
and resource cleanup. Shared CSV loading/calibration, CLI output and process
startup are excluded. CUDA device discovery/context initialization on the
measured path is inside host time; context/process reuse policy must match the
campaign. CUDA Event intervals exclude host allocation and cleanup, and the
device-stage sum also excludes copies and submission gaps. Neither is an
alternative numerator/denominator for primary total-engine speedup.

Use fresh matched CPU baselines and the fastest measured OpenMP configuration
in a common campaign for a new GPU speedup. Do not divide historical GPU times
by the November CPU stage diagnostic or by this selection microbenchmark.

## Selection algorithm

The experimental helper uses the same zero-based index
`min(ceil(alpha*N)-1, N-1)`. It orders and deduplicates requested ranks, selects
each with `std::nth_element`, and continues only in the suffix above the last
selected rank. Selected values are saved before later partitions. Output
preserves confidence order and repeated confidences/ranks. For 95% and 99%,
only the needed order statistics are returned; other losses need not be sorted.

Losses are caller-owned mutable storage with the same finite-sample precondition
as the existing sorted quantile. Empty samples/confidence lists and invalid
probabilities are rejected before mutation. No interpolation, clipping,
precision change or acceptance relaxation is used. Selection remains serial.

## Validation and timing

The oracle test covers negative and repeated losses, singleton/small samples,
shared ranks, reversed/repeated confidences, already sorted/reversed arrays,
extreme finite values, adjacent doubles, random duplicate-heavy samples and
invalid probabilities. It compares exact numeric values with the existing
sorted quantile and checks preservation of the sample multiset.

`--validate FILE N` regenerates the unchanged serial-native stream for seeds
42,123,456,789,2026 and compares both selected quantiles exactly with the actual
`SerialEngine`. At N=10000000 it also applies the unchanged five-seed error-of-
the-mean analytical criterion separately at 95% and 99%. A separate common-input
check compares serial and available OpenMP 1/2/4/8/10 outputs and verifies that
borrowed normals remain unchanged. Small validation is included in CTest.

The Windows recorder runs N=100000,1000000,10000000, three excluded warm-ups and
ten measured fresh-process runs for each method: 78 timed processes, including
60 measurements and 18 warm-ups. Method and size order alternate by repetition.
Each method regenerates the same fixed seed/model input outside its timer;
native-byte FNV-1a fingerprints and exact quantile values must match across
methods and repetitions. FNV is a diagnostic fingerprint, not a security hash;
SHA-256 records source, binary, probe and input provenance separately.

The microtimer includes sorting plus lookup/result allocation, or selection
rank planning plus partitioning/result allocation. It excludes loss generation,
loss-vector allocation and cleanup, fingerprinting, CSV calibration and process
startup/output. It is a quantile-stage comparison only. A faster stage is not
a measured total-engine speedup or evidence that OpenMP generation became
linear. No production integration or new GPU campaign is implied.

## Reproduction

```powershell
cmake -S . -B build-selection -G "Visual Studio 17 2022" -A x64 -DMC_ENABLE_CUDA=OFF -DMC_ENABLE_OPENMP=ON -DMC_BUILD_CPU_TOOLS=ON -DMC_BUILD_QUANTILE_EXPERIMENT=ON -DBUILD_TESTING=ON
cmake --build build-selection --config Release --parallel 4
ctest --test-dir build-selection -C Release --output-on-failure
python -B scripts/run_quantile_selection.py --exe build-selection/Release/mc_quantile_experiment.exe --probe build-selection/Release/mc_cpu_probe.exe --output results/quantile-selection-unique
```

The build option defaults OFF. CI enables it in Linux CPU configurations for
the oracle and small engine-equality tests; these are not laptop timings.
Raw observations and machine metadata stay under ignored `results/`.
The recorder observes AC/power state, verifies the full inherited processor pool
and normal priority, and retains every slow sample. No settings are changed.
Competing applications, per-core placement, temperature, cooling and thermal
equilibrium are not controlled or inferred. Failures remain in the attempt
directory and stop the campaign.

## Measured results: 2 November 2026

Source `08d7b89b4c03c567be6ca96ab473f1ca6c695e79`; MSVC 19.44.35227.0, C++17 Release /O2 /Ob2 /DNDEBUG, Windows x64 on Intel Core i7-12650H. The [full-precision aggregate](quantile-selection-summary.json) records the binary/input hashes, all means and sample SDs, scope, conditions and five-seed values. Raw process and machine records remain private under ignored `results/quantile-selection-20261102/`.

| Scenarios | Sort + lookup (ms, mean +/- sample SD) | Selection (ms, mean +/- sample SD) | Stage speedup |
| ---: | ---: | ---: | ---: |
| 100000 | 6.08379 +/- 0.22010 | 0.97400 +/- 0.09047 | 6.24619x |
| 1000000 | 73.60622 +/- 3.84345 | 8.57179 +/- 0.55653 | 8.58703x |
| 10000000 | 839.31637 +/- 22.86605 | 76.27798 +/- 3.55137 | 11.00339x |

All 78 timed processes completed: 18 warm-ups and 60 retained measurements, no failures or removed slow samples. Loss fingerprints and both quantiles match exactly for every size, method and repetition. The values also match the archived serial-native VaRs from the earlier CPU stage campaign at all three N values. Five independent seeds at 10M match the actual serial engine exactly and meet the unchanged analytical criterion at both confidence levels. Common-input serial and OpenMP 1/2/4/8/10 agree with selection, and borrowed normals are unchanged.

At 10M the measured quantile stage is 11.00339x faster. This is not an end-to-end engine, application or GPU speedup. The next integration question is whether replacing the bottleneck yields a meaningful total-time improvement with matched fresh baselines; no production substitution or such total-time campaign has occurred.

Local Release CTest: OpenMP/tools 25/25, serial 21/21. The latest validation-output change also passed the two focused OpenMP selection tests. Independent raw-record auditing passed:

```powershell
python -B scripts/verify_quantile_selection.py results/quantile-selection-20261102
```
