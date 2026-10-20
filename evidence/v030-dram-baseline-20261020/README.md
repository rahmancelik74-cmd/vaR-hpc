# Baseline DRAM counters and isolated portability, 2026-10-20

Inspection base: main 663fcc3086c1d752cb2f18218cf73ca188832847. Tracked files
were clean; AGENTS.md and output/ were untracked and preserved. No existing ncu
or mc_var process was found. The user reported enabling counter access. One
metric discovery succeeded, followed by exactly two successful target processes:
full-device and hybrid, each N=10000000, seed 42. No benchmark, convergence,
optimization or sanitizer campaign was restarted. No system settings changed.

## Workload and identity

The existing primary-benchmark Release executable is reused, not rebuilt:
source 89536e38b01230fce3b4667096c29dde56795c23, executable SHA-256
3c5c7e47ed870fb99ad733326ebbd9c8edf88558909b9905c1b2d5faa647d255.
workload-identity.json verifies five original executable/cache/project/DLL bindings
and all 14 current numerical source/input files against that source snapshot.
The source snapshot itself matches its archived manifest hash. The original
manifest, source tree, cache, binary and runtime files remain unchanged.
This does not repair historical serial source-to-binary=false or the unavailable
independent historical OpenMP cache. No new CUDA build is claimed.

Input is the public hand-written synthetic_prices.csv, exact SHA-256
8dbb7c73e6ad48cb8c8c175aff6684d2a0433e5f08424ec7ea1e69037bb36210.
Both profiles use the existing double GBM calibration, q=1, T=10/252, alpha .95
and .99, nearest-rank quantiles and PHILOX normal-double. Diagnostics are OFF.
Full-device has one batch; hybrid requests 65535, uses 65536 and 153 batches,
then one global host quantile. workload-check.json verifies exact equality of
model, calibration, both VaRs, RNG, seed and N to compatible archived primary
records. Profiled host/Event timings are retained but do not replace benchmark
times, stage diagnostics or acceptance observations.

## Commands, metrics and scope

Exact absolute argv, cwd and UTC intervals are in each selected process JSON.
Equivalent commands from repository root (existing validated build required):

```powershell
$ncu = 'C:/Program Files/NVIDIA Corporation/Nsight Compute 2026.3.1/target/windows-desktop-win7-x64/ncu.exe'
$sections = 'C:/Program Files/NVIDIA Corporation/Nsight Compute 2026.3.1/sections'
$exe = './build-benchmark-formal-89536e3-20261019-run2/Release/mc_var.exe'
& $ncu --section-folder $sections --metrics dram__bytes_read.sum,dram__bytes_write.sum,gpu__time_duration.sum --replay-mode kernel --cache-control all --clock-control none --export results/new-full-device $exe --csv data/synthetic_prices.csv 10000000 42 10 252 --backend cuda --cuda-mode full-device --json
& $ncu --section-folder $sections --metrics dram__bytes_read.sum,dram__bytes_write.sum,gpu__time_duration.sum --replay-mode kernel --cache-control all --clock-control none --export results/new-hybrid $exe --csv data/synthetic_prices.csv 10000000 42 10 252 --backend cuda --cuda-mode hybrid --batch-size 65535 --json
```

These are reproduction references, not instructions to rerun completed profiles.
Nsight Compute 2026.3.1.0 build 38829034; driver 610.88; AD107 / RTX 4060 Laptop.
tool-identity.json binds the profiler bytes. Collection is kernel replay with
cache-control all (clean caches before each pass) and clock-control none.
[NVIDIA's profiling guide](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html)
explains these cache/replay effects and asynchronous DRAM contamination. Clocks
were not locked; the tool explicitly warns about variation. This is a cold-cache
profile baseline, not the ordinary application's preserved inter-kernel cache state.

Metrics are dram__bytes_read.sum and dram__bytes_write.sum, bytes summed across
DRAM unit instances, and gpu__time_duration.sum, ns for the same kernel instance.
Discovery describes duration as measured user time where collectable, otherwise
measured wallclock. Only the .sum variants enter calculations; raw exports also
contain automatically supplied sibling statistics, which are not added again.
Each selected kernel retains the profiler__replayer_passes and
profiler__replayer_passes_type_warmup metadata (pass units).

All 14 full-device and 307 hybrid kernel instances used exactly ONE collection
pass, ZERO additional replay passes and ZERO profiler warmup passes. The latter
is not benchmark warmup policy. No application replay occurred. Hybrid's 153 RNG
and 153 simulation launches are real batches, not replays; initialization runs
once. Full-device radix sort has ten actual library launches, including eight
Onesweep kernels. The small metric set avoided multipass recombination.

For a stage or the collected-kernel aggregate:

```text
GB/s = sum(DRAM_read_bytes + DRAM_write_bytes) / sum(kernel_duration_ns)
```

One GB=10^9 bytes and one second=10^9 ns, hence cancellation in this expression.
Both numerator and denominator contain identical kernel IDs exactly once.
This is a ratio of sums, never a mean of kernel rates. It excludes host gaps,
allocation, transfers/copy-engine intervals, cache-flush overhead, cleanup and
hybrid host quantile. It is not whole-pipeline or end-to-end bandwidth.

## Measured results

All exact per-kernel counters, names, IDs and classification are retained in
kernel-metrics.json; summary.json retains full-precision ratios.

| Mode / covered stage | Kernels | DRAM read bytes | DRAM write bytes | Duration ns | GB/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| Full-device RNG initialization | 1 | 5504 | 0 | 18944 | 0.290541 |
| Full-device RNG generation | 1 | 16845952 | 79739776 | 5057920 | 19.095938 |
| Full-device simulation | 1 | 83507712 | 64668032 | 4437792 | 33.389520 |
| Full-device radix sort | 10 | 734338816 | 556174720 | 6891168 | 187.270654 |
| Full-device quantile gather | 1 | 2688 | 0 | 2080 | 1.292308 |
| Full-device all collected kernels | 14 | 834700672 | 700582528 | 16407904 | 93.569733 |
| Hybrid RNG initialization | 1 | 11264 | 0 | 19232 | 0.585691 |
| Hybrid RNG generation | 153 | 173362176 | 0 | 5660608 | 30.626070 |
| Hybrid simulation | 153 | 84903296 | 0 | 4818688 | 17.619588 |
| Hybrid all collected kernels | 307 | 258276736 | 0 | 10498528 | 24.601233 |

Zeros are the actual observed counters; none is filled from allocation sizes.
Zero hybrid DRAM writes do not mean no global stores or no D2H traffic. Stores
may remain cached, and traffic outside kernel collection intervals is excluded.
Neither a cache-residency cause nor exclusive workload traffic is proven here.
DRAM is a shared resource: display/copy/background activity can contribute,
especially for tiny kernels. No exclusive/headless GPU environment was established.
These are two single-profile observations, not repeated-sample means, sustainable
device peak measurements or a new performance comparison. The two modes cover
different stages and their aggregate ratios do not rank their end-to-end speed.

Point telemetry was 46 C / P3 / 2100 MHz SM / 7001 MHz memory before, and
47 C / P8 / 345 MHz SM / 405 MHz memory after. Power limits were N/A. These are
not workload-average clocks. CPU temperature, AC/power mode, fan settings,
ambient temperature, throttling absence and thermal equilibrium were not freshly
established. No power, driver, clock or permission policy was changed by this task.

## Documented peak remains unresolved

source-review.json records a bounded NVIDIA/OEM source review. NVIDIA supports
8 GB GDDR6 / 128-bit; the current Casper G870 page spans other configurations.
No official rate applicable to this G870/NLXB was established. Reports from other
OEM laptops, even when posted on NVIDIA forums, are not this unit's specification.
Runtime memory clocks and profiler device attributes are not substituted.
If applicable effective rate R in Gbit/s per pin is obtained, theoretical decimal
peak is R*128/8 GB/s, and percent=100*measured_GBps/peak_GBps. R, peak and
percentage remain null. The profiler's sustained-peak percentage is a different
quantity and is not used. Counter-access administrator action is no longer needed
for this verified session; a documented applicable rate/peak remains external input.

## Portability review and actual limits

portability.json records an independent full-history local clone at the inspection
SHA, created with --no-hardlinks inside ignored results/portability-663fcc3-20261020/.
Its checkout and new build paths contain spaces. The clone copied tracked files
and Git history, not original build/results trees, AGENTS.md, output/ or private
inputs. It used the existing dependencies on the SAME machine, not a fresh machine.

Public integrity passed from a working directory outside the clone (78 selected
files, historical Git comparisons), and all 15 stdlib Python tests passed inside
it. Fixture exact bytes survived core.autocrlf=true. The optional local convergence
path failed as expected with an actionable missing original archive message; it
did not consume the primary checkout's archives or regenerate simulations.

One relocated VS2022 x64 Release CPU build, OpenMP ON, CUDA/tools OFF, succeeded.
CTest discovered 13: ten passed initially; three Git-using recorder/import tests
failed because the sandbox created the clone under one Windows account while
SDK-access execution used another. Their exact logs remain local. Rechecking ONLY
those three with process-local safe.directory set to this exact known clone
passed 3/3. No persistent Git setting, ownership or permission was changed.
Thus all 13 passed across the two attempts; the original 10/13 run is preserved.
This is an execution-account trust condition, not a source portability defect.
No engine/recorder fix was needed. Tests create their own ignored synthetic
fixtures, including data/local; those are not private provider inputs.

Public evidence verification needs full Git history; an archive export alone is
not supported. Historical full-session audits still need original ignored
binaries/caches/archives and documented path layouts. No claim of historical
campaign reproduction, new-machine portability or original serial provenance repair.

## Verification and preservation

verify.py is stdlib-only, read-only, independent of cwd and uses no Git/GPU.
It verifies the selected-file hashes, units/schema, unique complete kernel IDs,
stage coverage, pass metadata and exact aggregate recomputation. With local
records it also checks their bytes and reprojects every metric from raw exports:

```text
python -B evidence/v030-dram-baseline-20261020/verify.py
python -B evidence/v030-dram-baseline-20261020/verify.py --local-records results/bandwidth-baseline-663fcc3-20261020
```

independent-audit.json records a separate Decimal/explicit-integer-sum audit
of all 321 raw-export rows, ten stage/aggregate groups and the successful process
and single-pass stdout records, without importing verify.py. Its source remains
hash-bound in the local records. Thirteen focused malformed-counter, ID, stage,
duration, replay/warmup and locale cases were rejected. The existing historical
integrity/local convergence audit also passed (78 selected artifacts, 22 delivery
bindings, 160 values, 32 groups, eight acceptance rows). The old bandwidth
follow-up validator passed 39 immutable/local bindings with current-document
comparison deliberately omitted after this legitimate documentation advance.
That validator's counter_access=denied describes its historical record, not
this newly successful collection.

Raw .ncu-repz reports, wide CSV exports, process captures and local harnesses stay
in that ignored directory and are hash-bound by manifest.json. Selected process
stdout/stderr and argv are exact copies. Nsight now defaults to .ncu-repz; one
offline import initially used .ncu-rep and failed, then the correct extension
was imported successfully. That failure is preserved; no workload was repeated.
The normalized metric projection explicitly parses the observed Turkish numeric
format (period grouping/comma decimal), rejects unexpected formats, and uses
Decimal before integer conversion. No engine value or numerical tolerance changed.

manifest.json excludes itself, binds selected files and original local records,
and has no current-document hash dependencies. portability.json binds its local
logs separately. Historical manifests, failures, figures and raw input hashes
remain unchanged. Full-device 9.739930524x serial (10x unmet), 8.307208722x best
OpenMP, hybrid not beating best OpenMP, limited sanitizer coverage and mixed
convergence revisions remain. RNG's largest covered device-stage mean does not
establish the largest end-to-end cost. Academic submission/live demo remain
unverified. Final commit/push/exact-SHA CPU CI are separate publication facts.
