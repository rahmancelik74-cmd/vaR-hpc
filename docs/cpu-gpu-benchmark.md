# Unified CPU/GPU benchmark preparation

This infrastructure implements Plan A recording, auditing and opt-in timing.
It does not establish a completed formal benchmark, measured DRAM bandwidth,
documented-peak utilization, convergence or profiling-driven optimization.
The engine numerical contract, native RNG partition and primary timer are unchanged.

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

# Future formal execution ONLY after separate authorization, clean source,
# physical-condition recording and review. Not executed during preparation.
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
CPU OS frequency reports are not measured turbo clocks. A future formal run should
add the reviewed bounded 2-minute pre-observation / 30-second post-observation
procedure before execution; this thermal observation window is not implemented
by the preparation smoke recorder and must not be claimed as performed.

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
