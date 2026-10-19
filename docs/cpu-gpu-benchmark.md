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
