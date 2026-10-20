# Unified CPU/GPU benchmark

This infrastructure implements Plan A recording, auditing and opt-in timing.
The formal primary benchmark is complete; see the dated result below.
Measured DRAM bandwidth, documented-peak utilization, convergence and
profiling-driven optimization are not established by that primary campaign.
The engine numerical contract, native RNG partition and primary timer are unchanged.
The separate [18-process stage-diagnostic checkpoint](cuda-stage-diagnostics.md)
is also closed; its instrumented samples do not enter primary statistics.

## Commands and source policy

Run from the repository root in Windows PowerShell. CUDA 13.4, VS 2022 x64,
architecture 89, OpenMP and CPU tools are explicit. CUDA remains default OFF
for ordinary project builds. The unified recorder requires all backends and
creates a dedicated build directory; it does not reuse historical build trees.

```powershell
# Development verification only; dirty files are hashed and labeled.
./scripts/run-benchmark.ps1 -Mode smoke -AllowDirtySource -OutputDirectory results/benchmark-smoke-unique
./scripts/run-benchmark.ps1 -Mode diagnostic -AllowDirtySource -UseExistingBuild -OutputDirectory results/benchmark-diagnostic-unique
./scripts/verify-benchmark.ps1 -Directory results/benchmark-smoke-unique

# Formal command reference; completed campaign below used a dedicated build.
# Any new campaign requires separate authorization; closure does not rerun it.
./scripts/run-benchmark.ps1 -Mode formal -ConditionsFile results/conditions.json -OutputDirectory results/benchmark-formal-unique
```

`-UseExistingBuild` requires an exact source-snapshot and build-artifact binding
written by this recorder. Changed source requires rebuilding. Formal mode rejects
dirty source even with `-AllowDirtySource`; only untracked AGENTS.md and output/
are excluded from source status/snapshots. Output must be a new ignored results/
directory. No script commits, pushes, publishes or changes machine settings.

## Fixed matrix and order

All configurations use exact bytes of data/synthetic_prices.csv, one unit,
10/252 years, seed string `42`, confidence .95/.99, double precision, terminal
GBM, signed loss and ascending ceil(alpha*N)-1. The independent fixture auditor
recalibrates with two-pass sample variance (n-1). Native streams differ across
backends; equal seeds do not imply equal samples.

| Mode | N | Configurations | Phases | CLI processes |
| --- | --- | --- | --- | --- |
| smoke | 100000 | serial, OpenMP 1/2/4/8/10, full-device, hybrid | 1 warm-up + 2 measured each | 24: 8 warm-up, 16 measured |
| diagnostic | 100000 | full-device, hybrid | 1 baseline OFF + 1 diagnostic ON each | 4, no primary benchmark summary |
| formal | 100000/1000000/10000000 | all eight at each N | 3 warm-ups + 10 measured each | 312: 72 warm-up, 240 measured |

Hybrid always requests 65535; native effective size is 65536 for these N values,
with 2/16/153 batches. No batch-size search is performed. Full-device uses one
batch. Both confidence estimates share one run timer, never two timing samples.

plan.json is persisted before build/tests/samples. At each phase, round r starts
from configuration indices in declared order, reverses them on odd r, then
rotates by 5*(r-1) positions. All warm-up rounds precede measured rounds.
Diagnostic baseline precedes its diagnostic phase. This deterministic order
spreads position effects but is not a claim of complete positional balance.
Processes execute sequentially with a fixed excluded 100 ms delay.

Every attempted sample has its own record, partial output and error status.
A failure or power-condition change stops the attempt and prevents completion;
no successful slow sample is removed or selectively replaced. Incomplete evidence
is retained. Any later rerun must use a new evidence directory and explain why.

## Timing fields

`end_to_end_ms` is the existing steady-clock engine timer. It excludes process
startup, shared CSV loading/calibration, output, launcher telemetry and delays.
It includes per-run allocation, native RNG, loss simulation, global quantile,
required transfers, synchronization and temporary cleanup. Initial CUDA context
and API work inside the engine are included. Every sample uses a fresh suspended
CLI process and fresh CUDA context; warm-ups do not preserve an engine/context.

Primary samples do not pass `--cuda-diagnostics`. Default schema_version=1 output
is preserved: CUDA diagnostics is an absent field, not a fabricated zero reading.
Opt-in `--cuda-diagnostics` adds cuda.diagnostics, nested schema_version=1:

| Field | Actual measured scope |
| --- | --- |
| initialization_ms | Same-stream Event intervals around device error-flag memset only; not allocations/context/host RNG setup |
| rng_ms | Device work enqueued by each native cuRAND normal-generation call; common-input runs have zero RNG intervals |
| loss_ms | Event interval around loss-kernel submission |
| cub_ms | CUB SortKeys execution interval; full-device only, excludes scratch query/allocation |
| gather_ms | Device nearest-rank gather interval; full-device only |
| pipeline_span_ms | One elapsed Event span from first pipeline enqueue through final required D2H; includes submission/host gaps; hybrid excludes subsequent host sort |
| host_quantile_ms | Hybrid host steady-clock sort and global quantile over all N losses; zero/inapplicable in full-device |
| covered_device_stage_sum_ms | Explicit sum of initialization+RNG+loss+CUB+gather intervals, accumulated over all batches |

Each stage includes an interval count. Event pairs are created only when enabled,
resolved after pipeline completion and released within the original host boundary.
Stage sums are cumulative covered device intervals, not elapsed pipeline spans or
active-kernel hardware durations. Instrumentation can perturb diagnostic runs;
their host times are not primary benchmark samples. No extra per-stage barrier
is introduced. Existing copy barriers and RNG/sort/quantile behavior remain.

Existing host_to_device_ms/device_to_host_ms remain sums of copy Event intervals;
pageable host staging is included fully only in primary host time. Transfer-excluded
diagnostics mean the explicitly covered device-stage sum, excluding copies, host
setup/staging/global quantile, allocation/context/cleanup and inter-stage gaps.
Never subtract Event copy times from host wall time to claim a transfer-free total.

## Statistics and audit

All 24 formal rows remain available, including every OpenMP team and spread.
Record mean host ms, sample standard deviation with denominator n-1 and
N*1000/mean_ms scenarios/s. Select the OpenMP team with lowest mean separately
at each N (exact ties choose lower thread count deterministically).
For each GPU mode report mean_serial/mean_GPU and mean_best_OpenMP/mean_GPU.
At N=10000000 record whether serial speedup reaches 10x, without promising it.
Do not average individual speedups or choose fastest individual samples.

The recorder uses Welford; the independent auditor uses explicit sums/two-pass
variance and a separate baseline-selection loop. It checks canonical plan/order,
coverage/uniqueness, raw launcher/result agreement, exact source/input/build/binary
bindings, actual teams, mode/batch/transfer/global-quantile metadata, independently
calibrated model, finite positive primary times and diagnostics OFF status.
Diagnostic mode separately checks exact same-build native estimates ON versus OFF,
stage counts/sums and pipeline scope. Completion is explicitly mode-specific;
successful smoke is never formal completion or five-seed acceptance.

## Environment, conditions and launcher lifetime

The Windows probe records topology, runtime DLL version, active power-scheme
GUID, AC/battery/saver and OS frequency snapshots. All configurations use its
same full available logical-CPU mask, verified before resume, normal priority.
Separate affinity probes record requested/actual worker placement; team count
does not mean per-core pinning. Runtime binding controls are unset and process-
local OMP_DYNAMIC/OMP_NESTED are FALSE; prior values are restored afterward.

user-conditions.json holds declarations separately from measured telemetry. Suggested
English fields are charger, surface_and_ventilation, cooling_pad,
vendor_performance_mode, vendor_fan_mode, competing_applications and
ambient_temperature {status, value_c}. Explicit unknown/unmeasured/null is valid.
Formal execution requires a supplied conditions object and measured AC connection.
Record the actual existing settings; do not change power/driver/registry/fan modes.

NVSMI before/after snapshots record GPU temperature/power/clocks/pstate where
available; raw N/A/error remains unavailable. These point observations do not
measure CPU temperature, fan speed or prove thermal equilibrium/no throttling.
CPU OS frequency reports are not measured turbo clocks. The preparation smoke
recorder does not implement observation windows. The formal session wrapper
separately completed the reviewed 2-minute pre / 30-second post procedure;
actual spans and gaps are documented in the dated result below.

`mc_cpu_probe --run-timeout milliseconds mask_hex executable [args]` bounds the
owned process tree, including descendants that retain output pipes after their
parent exits. A Job Object is assigned while suspended, with kill-on-close.
Nonblocking bounded pipe drains allow deadline checks even under continuous output.
Timeout terminates the owned job and retains stdout/stderr, actual root exit code,
timed_out, owned_job_terminated, active_processes_at_timeout and launcher_elapsed_ms.
owned_tree_exited confirms zero active processes in the job, including after a
bounded five-second termination drain; incomplete cleanup cannot pass auditing.
The legacy --run command retains a 60000 ms default. Launcher time is not engine time.

## Evidence schema

manifest.json binds source SHA/tree/status and exact-byte source-snapshot.json,
fixture/build caches/executables/DLLs and every recorder output except its own
manifest and subsequent independent audit. A dirty development smoke records both
base HEAD and modified/untracked source hashes; it is not a clean tested commit.
Build binding prevents stale binary reuse. CTest discovery/results are recorded.
plan.json, independent-fixture.json, user-conditions.json, runtime-environment.json,
inventory/affinity outputs, GPU snapshots, per-attempt process/raw/JSON files and
runs.jsonl are retained. summary.json/CSV exist only for primary smoke/formal modes.
independent-audit.json records the manifest hash and explicit mode/formal verdict.
Evidence stays ignored/local pending a separate publication review.
Clean snapshots additionally record each index blob ID, independently checked
against the tested commit's complete tree. The recorder verifies unchanged exact
source bytes, HEAD and clean status at run end. This allows audit after a later
documentation commit without changing archived SHA-256 values or restoring old
files. Dirty development snapshots still require their matching local files.

## Bandwidth discovery and unresolved limits

The [2026-10-20 bounded access investigation](../evidence/v030-bandwidth-access-20261020/README.md)
reconfirms the permission error without launching a workload. It identifies the
Casper G870/NLXB family and checks official NVIDIA/OEM specifications; effective
memory data rate and applicable theoretical peak remain unresolved. The record
includes the current Windows administrator remedy. It does not close baseline
DRAM reporting or authorize system changes. Historical discovery below is retained.

Optional `-DiscoverBandwidth` performs version/metric discovery only, outside
samples. It does not launch Nsight profiling. bandwidth-preparation.json records
tool absence/error, ERR_NVGPUCTRPERM, incomplete metric discovery or discovery-only
success. Fatal output is rejected even when exit code is zero. Raw commands,
statuses and output are retained. measured_dram_status stays not-measured,
documented_peak_gbs stays null and orchestration stays unverified.

Preparation discovery observed Nsight Compute 2026.3.1.0 build 38829034 and
ERR_NVGPUCTRPERM on the RTX 4060 Laptop/AD107, driver 610.88. Offline AD107 metric
definitions are not evidence of permission to collect counters. No permissions
or other machine-wide settings were changed. The exact laptop's documented peak
memory bandwidth is unverified; no desktop specification or clock multiplier is
substituted. NVIDIA's laptop table documents 128-bit interface, not this OEM
configuration's verified effective data rate/peak bandwidth.

Future separately authorized profiling: attachment pilot, then 3 N x 2 GPU modes,
cover all actual RNG/loss/CUB/gather kernel instances and hybrid batches; record
unclassified kernels rather than dropping them. Candidate metrics are
dram__bytes_read.sum, dram__bytes_write.sum (byte), gpu__time_duration.sum (ns).
Aggregate each stage as sum(read+write bytes)/sum(kernel seconds)/1e9 GB/s, not a
mean of per-kernel rates. Copy/host-quantile costs are outside that kernel-only
bandwidth. Explicitly record replay passes, cache/clock policy and overhead;
proposed application replay with cache-control none and clock-control none is
not yet validated orchestration. Default NCU clock locking must not be used
silently. No profiler sample enters primary timings.

Percentage of documented peak remains unavailable until an authoritative exact-
configuration bandwidth or effective-data-rate/bus-width source is established.
Profiler pct_of_peak_sustained_elapsed has its own denominator and must be labeled
separately. If counters remain blocked, 16*N logical loss-kernel bytes divided by
its Event interval is only effective/application bandwidth, not measured DRAM
traffic or completion of the original Plan A bandwidth reporting requirement.

Official references:
- https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html
- https://docs.nvidia.com/nsight-compute/ReleaseNotes/index.html
- https://developer.nvidia.com/ERR_NVGPUCTRPERM
- https://www.nvidia.com/en-me/geforce/laptops/compare/

## Clean-source preparation checkpoint: 2026-10-19

Tested source: df34111faa3c64b52f03d493ef5aaeb0b41a82b1.
Source tree: 51cd74478c232d3b2b9d8efb8d432df34034815b.
This result entry belongs to a subsequent documentation-only commit. No formal
benchmark, full diagnostic/profiling, acceptance/sanitizer, convergence or
optimization campaign was run to close this infrastructure checkpoint.

Implementation was committed as 231fbf6. Follow-up ffc8375 added explicit
owned-job zero-active-process confirmation and clean snapshot Git-tree binding.
Its clean CTest exposed a working-directory dependency in the new source-binding
unit fixture: relative git ls-tree returned an empty list inside build directories.
df34111 uses --full-tree and rejects an empty fixture. Focused tests passed from
both the repository root and a build directory before clean verification.

The ffc8375 attempt stopped in CTest before any recorder sample. Its failed
manifest/audit remain in results/benchmark-prep-ffc8375-clean-20261019-smoke/;
the partial CPU regression attempt and interruption.json remain in the matching
-regressions/ directory. They are not successful smoke evidence. Original dirty
evidence in benchmark-prep-smoke-20261019-attempt1/,
benchmark-prep-diagnostic-20261019-attempt1/ and benchmark-prep-regressions-20261019/
was inspected and preserved, not relabeled as clean-source evidence.

Successful clean evidence, all below ignored results/:

| Directory | Verified outcome |
| --- | --- |
| benchmark-prep-df34111-clean-20261019-smoke | 24 processes: 8 warm-ups excluded, 16 measured infrastructure samples; all eight configurations; independent audit passed |
| benchmark-prep-df34111-clean-20261019-diagnostic | 4 processes: two baseline OFF, two diagnostic ON; exact same-build per-mode estimates; independent audit passed |
| benchmark-prep-df34111-clean-20261019-regressions | Separately rebuilt CUDA OFF/OpenMP ON 12/12 and serial-only 11/11; CPU-only caches did not discover the Toolkit |
| benchmark-prep-df34111-clean-20261019-review | Read-only compatibility checks: default result/CUDA key sets unchanged; model, calibration and estimates match the prior same-configuration dirty smoke |

The unified CUDA/OpenMP/CPU-tools Release build passed all 18 discovered CTests,
including 61 recorder/auditor checks, 9 launcher checks and CUDA diagnostic
equivalence/scope tests. Diagnostic runs also passed the same 18-test suite.
Native diagnostic batches were 1 for full-device and 2 for hybrid at N=100000;
hybrid reported zero CUB/gather intervals and a separately timed host quantile.
All primary CUDA samples omitted diagnostics. No source/HEAD change occurred
during either successful clean run; only untracked AGENTS.md and output/ were
excluded. Each manifest binds 15 build artifacts; output hashes cover 295 smoke
records and 81 diagnostic records. Both audits explicitly report formal=false.

Exact-byte SHA-256 bindings:

| Artifact | SHA-256 |
| --- | --- |
| Clean source snapshot (both smokes) | 7c3b6504207d568327c9fcb2f545c6b80321e422fb1c26e648f9a9c53f52e282 |
| Smoke manifest.json | e20acca2ddca3d3d3aa9b3d4bf6fdf5ab4dd6c6c6cb66d960ca7d9a094c0af00 |
| Smoke independent-audit.json | fb488b107c69d6af700de6640b2e8bc708e46f217f5c594d3bd9df3a42531d9b |
| Diagnostic manifest.json | 8e5d6c0e61eb5531a412594707066c3f71d5e78b9d9db8aa227863af6f6ee38f |
| Diagnostic independent-audit.json | 968bf5a3254e18f8f1d110425c24e050fec3b4e543705d7b67559f768ee88e82 |
| Shared CUDA/OpenMP CLI | b998132680254a10a9ee44789e1243749d93df0a885d6032e3c61773a70a7c53 |
| Shared synthetic fixture | 8dbb7c73e6ad48cb8c8c175aff6684d2a0433e5f08424ec7ea1e69037bb36210 |

Read-only Nsight discovery again reported ERR_NVGPUCTRPERM, correctly classified
despite exit code zero. Measured DRAM traffic and exact-laptop documented peak
remain unavailable. Profiler orchestration is unverified; permissions, registry,
drivers and machine-wide power settings were not changed. Hosted CPU CI must be
checked for the exact final pushed SHA and is not local RTX acceptance evidence.

## Inputs and operational prerequisites for a later formal benchmark

Before separately authorized formal execution, supply an English conditions JSON
object containing charger, surface_and_ventilation, cooling_pad,
vendor_performance_mode, vendor_fan_mode, competing_applications and
ambient_temperature {status, value_c}. Values must describe actual conditions;
unknown/unmeasured/null are allowed and must remain explicit. User declarations
are separate from AC/battery/power-scheme and GPU telemetry. This checkpoint does
not establish those physical conditions for a later run.

Use a clean reviewed source revision, a new dedicated build/evidence directory,
all required backend/tool/runtime availability, successful applicable regressions
and recorder preflight, the exact synthetic fixture and independent calibration.
Keep diagnostics/profilers off for the 312 primary processes, use the fixed hybrid
batch, record actual teams and the shared affinity/priority/environment policy,
retain every attempt and stop on detected power-source/saver/scheme changes.
Formal mode requires actual AC connection. Record the existing vendor/fan/display
and competing-application conditions without changing machine-wide settings.
Prepare and execute the bounded two-minute pre-observation / thirty-second
post-observation procedure described above; it is still separate operational work
and cannot establish thermal equilibrium. Resolve counter access and the exact
peak specification separately before claiming the Plan A bandwidth measurements.

## Formal primary result: 2026-10-19

The primary checkpoint is closed after review of the existing records; no
benchmark sample, diagnostic measurement or optimization was run during closure.
Tested clean source: 89536e38b01230fce3b4667096c29dde56795c23, tree
8edb98064ec2a8d6ed5ab8ac40fef62c9d905e51. Fresh Release preflight passed all
18 discovered CTests. All 312 processes completed: 72 excluded warm-ups and
240 measurements, three plus ten per configuration. No sample was discarded,
replaced or selectively rerun. The fixture/model, native RNGs, double precision,
signed losses and global nearest-rank quantile follow the contract above.

The [curated record](../evidence/v030-primary-benchmark-windows-20261019/README.md)
contains [all 24 full-precision summary rows](../evidence/v030-primary-benchmark-windows-20261019/summary.csv),
[all 312 timing samples](../evidence/v030-primary-benchmark-windows-20261019/samples.csv)
and the [original session report with a complete readable table](../evidence/v030-primary-benchmark-windows-20261019/session-report.md).
The following GPU-only table is a rounded summary; full records are authoritative.
Means and sample standard deviations use ten measured runs; scenarios/s is
1000*N/mean_ms. Ratios divide the fresh CPU configuration mean by GPU mean.

| N | GPU mode | Mean ms | Sample stddev ms | Scenarios/s | Serial/GPU | Best OpenMP/GPU | Best OpenMP threads |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 100000 | full-device | 98.58712 | 15.92891 | 1014331.28 | 0.092797 | 0.084707 | 2 |
| 100000 | hybrid | 104.55102 | 21.56428 | 956470.82 | 0.087503 | 0.079875 | 2 |
| 1000000 | full-device | 105.34656 | 18.26856 | 9492478.92 | 1.017803 | 0.914771 | 4 |
| 1000000 | hybrid | 187.94319 | 23.76113 | 5320756.77 | 0.570502 | 0.512750 | 4 |
| 10000000 | full-device | 126.72010 | 21.83381 | 78914079.14 | 9.739931 | 8.307209 | 4 |
| 10000000 | hybrid | 1087.93442 | 74.89774 | 9191730.51 | 1.134485 | 0.967605 | 4 |

At N=10000000, full-device serial speedup is exactly the recorded
9.7399305240447234x, below the 10x target; hybrid is 1.1344847146209416x.
Neither meets 10x. Full-device beats best measured OpenMP there; hybrid does not.
At smaller N, full-device is slower than best OpenMP; hybrid is slower than
best OpenMP at every measured N. Lowest OpenMP means select 2,4,4 threads;
the close 2/4-thread means at N=1000000 do not establish a universal best team.
No bottleneck or general speed guarantee is inferred from these host timings.

### Audit and evidence trail

Original successful session: results/benchmark-formal-89536e3-20261019-run2/.
campaign/manifest.json binds 3163 recorder outputs and 15 build artifacts.
The recorder and supplemental independent audits passed originally and again
during closure. Existing auditor logic checked complete canonical order,
unique phase/repetition coverage, raw launcher/result equality, native estimates,
model/calibration, actual teams, batches/transfers, source/build/fixture hashes,
diagnostics OFF, independent two-pass statistics, best-team selection and both
ratios. The supplemental auditor checked every CSV field and observation record.
Closure also verified all 3391 session-file hashes and run1's 226 hashes;
all 3619 original files, including session manifests, remained byte-identical.
Reaudit reports were redirected to a separate review directory; original audit
files were not overwritten. No numerical or evidence discrepancy was found.
Stale current documentation labels were corrected in this closure; historical
dated entries and the original session report remain unchanged.

The retained results/benchmark-formal-89536e3-20261019-run1/ stopped on an
absolute-versus-relative build-path caller error before campaign creation.
Its recorder exit code was 1 and it launched zero benchmark samples. The new
run2 session used the relative build argument with unchanged recorder source.
This was not replacement of a slow or failed benchmark sample.

| Original local artifact | Exact-byte SHA-256 |
| --- | --- |
| run2/campaign/manifest.json | 6f7e9c26291df236b755f16ff210aef0fa3070ae7cad1231b4c5175f7f1a2771 |
| run2/campaign/independent-audit.json | 7910c56bbe62bdff8e81ced9990cc222f6a7b18a3a0a9d373e3c882da5a2221b |
| run2/session-independent-audit.json | 253bf296163b6dcd5efb07f3e260df16e4270e26330622a177faed0db5fe561c |
| run2/session-manifest.json | c3733885fba543889d34afbd3a529e5dd95d5cd949bd318ad3f93d7ba02815b8 |
| run1/session-manifest.json | 95795db7a39243c14635f97478b5fff04786780cbecd5d7fed425c8423df7c9a |

### Timing and recorded conditions

Each sample used a fresh CLI process and CUDA context. end_to_end_ms includes
initial CUDA context/API work inside the engine, per-run allocation, native RNG,
simulation, global quantile, required transfers, synchronization and temporary
cleanup. Process startup, shared CSV/calibration, output, telemetry and the fixed
100 ms delay are excluded. Warm-ups precondition the machine, not a retained
context. All primary samples omitted --cuda-diagnostics and cuda.diagnostics;
no profiler ran. Copy Event fields remain separate from host time and are not
subtracted to construct a transfer-free total. Hybrid requested/effective batch
is 65535/65536, with 2/16/153 batches; one global host quantile covers all losses.

Recorded hardware/software: i7-12650H, 10 physical/16 logical CPUs; RTX 4060
Laptop GPU, 8 GB class; Windows 10.0.26200.0; PowerShell 5.1.26100.9711;
Visual Studio 17 2022 generator, MSVC 19.44.35227.0, CMake 3.31.6-msvc6,
nvcc 13.4.92, driver 610.88, architecture 89, CUB 3.4.3. Release C++ flags
are /O2 /Ob2 /DNDEBUG; CUDA retains --fmad=false and /Zc:preprocessor.
OpenMP is version 2.0 (200203), vcomp140.dll 14.50.35719.0. All processes
used the verified ffff pool and normal priority; actual teams matched requests.
Windows scheduled threads within the pool; no per-core pinning is established.
OMP_DYNAMIC and OMP_NESTED were FALSE, other listed binding controls unset.

User declarations: adapter connected, unobstructed intakes (surface unknown),
built-in cooling, no external pad reported, vendor performance/fan modes unknown,
GPT/Codex open. Approximately 15 C ambient was an estimate without an instrument.
Measured AC connection, saver and active power scheme remained stable. The
two-minute pre-window had 25 points spanning 119.999651 s; the thirty-second
post-window had 7 points spanning 30.0151721 s. Preflight produced a
16.6744291 s gap before the first attempt; audit/statistics work produced a
27.3165226 s gap before post-observation. Gaps are outside primary timing.
All 657 GPU point queries were available, with 44-51 C temperatures; GPU power
limit was N/A throughout. CPU temperature, thermal equilibrium and absence of
throttling are not established; OS CPU frequency fields are not measured turbo
clocks. Open applications and unmeasured laptop thermal/clock variation qualify
these results. All slow samples remain retained.

Separate stage/transfer-excluded diagnostics are complete; see
[the six-configuration result](cuda-stage-diagnostics.md) for definitions, spread
and limitations. Measured DRAM GB/s and percentage of documented peak, verified
profiler orchestration, convergence and final reproducibility remain separate
work. ERR_NVGPUCTRPERM persists from prior
discovery; this primary campaign requested no new discovery or profiling.
Exact-laptop documented peak is unavailable. Plan B optimization is optional.
Academic delivery and live demonstration are not established. Hosted CPU CI for
the closure commit is distinct from this local RTX-tested source and cannot
serve as benchmark evidence.
