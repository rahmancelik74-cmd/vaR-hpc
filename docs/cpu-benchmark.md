# Serial and OpenMP CPU scaling recorder

For the later unified CPU/GPU preparation, use
[cpu-gpu-benchmark.md](cpu-gpu-benchmark.md). The historical CPU recorder and
its archived campaign remain separate; their old timing rows are not fresh
baselines for a new CPU/GPU comparison.

The validated v0.3.0 numerical engines and serial sorting are unchanged.
scripts/run-cpu-benchmark.ps1 builds a clean source revision with MSVC x64
Release, MC_ENABLE_OPENMP=ON and MC_BUILD_CPU_TOOLS=ON. It runs all retained
tests and the instrumentation/statistics tests. One mc_var.exe and one exact
synthetic CSV file are shared by the fresh serial and OpenMP configurations.
Historical v0.2.2 timings are never used as references.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run-cpu-benchmark.ps1 -Mode smoke
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-cpu-benchmark.ps1 -Directory results/<smoke-directory> -VerifyLocalArtifacts
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run-cpu-benchmark.ps1 -Mode benchmark -ConditionsFile results/physical-conditions.json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-cpu-benchmark.ps1 -Directory results/<benchmark-directory> -VerifyLocalArtifacts
```

The conditions file is an English JSON object documenting charger, ambient
temperature, surface/cooling and competing applications, distinguishing user
reports from measurements. Full campaigns require this file. Smoke is a small
recorder check (N=10000, six configurations, one warm-up and two measured runs
each); it is not the performance baseline. A full campaign uses N=100000,
1000000,10000000, seed 42, serial plus OpenMP requested threads 1,2,4,8,10,
three warm-ups and ten measured repetitions per configuration: 234 processes,
54 warm-ups and 180 measured samples across 18 configurations.

## Lifetime, timing and order

Each sample creates a fresh suspended mc_var process. The separate Windows
mc_cpu_probe launcher sets and reads back its affinity mask and normal priority
before resuming it. It captures stdout/stderr and power/frequency snapshots.
No engine, OpenMP team or RNG persists across samples. Warm-ups precondition
OS caches and machine conditions, not a persistent engine. Warm-up runs are
never included in summaries. Three warm-ups do not establish thermal equilibrium.

The existing application engine timer remains authoritative: allocation, RNG,
simulation, serial sorting, quantiles, cleanup and synchronization are included;
process startup, CSV calibration, launcher telemetry, output and a fixed 100 ms
inter-run delay are excluded. Telemetry runs outside the timed engine. All
warm-up rounds precede measured rounds. The configuration list is rotated by
five positions per round and reversed on odd rounds; timestamps and explicit
sequence/repetition/configuration IDs record the actual order. This spreads
order effects but does not eliminate laptop thermal or scheduler variability.
All successful slow samples are retained. Power source/scheme changes fail
the full campaign after retaining its partial records.

## Placement and available measurements

The probe uses GetLogicalProcessorInformationEx to record physical-core masks,
SMT flags and reported efficiency classes. It does not infer physical cores
from an OpenMP team size. This implementation explicitly supports one processor
group, suitable for the target laptop; multi-group systems fail clearly.

Every configuration uses the same full available logical-CPU pool. Within that
pool Windows schedules threads; no per-thread pinning is claimed. Separate
runtime probes run each team size both with binding variables unset and with
OMP_PROC_BIND=TRUE / OMP_PLACES=cores. Worker allowed masks and sampled CPU masks
show whether those requests constrain placement with the installed runtime.
A one-logical-CPU process-mask control must constrain all four probe workers;
the launcher also verifies every CLI's process mask before its first instruction.
These probes are separate from timed Monte Carlo runs; they do not trace the
engine's per-thread migration history. The benchmark leaves runtime binding
variables unset and fixes OMP_DYNAMIC=FALSE and OMP_NESTED=FALSE for all cases.
Original environment values are saved and restored in the recorder process.

The probe records GetSystemPowerStatus AC/battery/saver values, active power
scheme GUID and CallNtPowerInformation frequency/throttle reports before and
after each process. These frequency values are OS reports, not measured turbo
clocks. CPU package temperature, fan speed, package power and thermal throttling
events are not measured by this recorder and must not be inferred from those
reports. User ambient reports are not thermometer measurements. The power
scheme's settings are not changed; unknown vendor fan/power modes remain unknown.
The runtime DLL version is queried in the probe linked to the same OpenMP target
as mc_var; both executables reside in the same directory.

## Artifacts and statistics

manifest.json records provenance, exact-byte hashes, compiler/runtime settings,
conditions, configurations and run counts. inventory.json and affinity-checks.json
contain topology and placement control observations. runs.jsonl contains one
record per CLI process, including both confidence estimates but only one timer.
process-observations.jsonl contains the corresponding raw launcher JSON in the
same sequence, including unmodified application stdout and telemetry. Configure,
build and CTest logs redact source/user path prefixes. Localized MSBuild banners
have explicitly labeled English transcriptions with capture hashes; native
captures stay local under ignored results/. Failed attempts are retained.

summary.json and summary.csv report the arithmetic mean, sample standard
deviation (denominator n-1), N*1000/mean_ms throughput, fresh serial mean divided
by the configuration mean, and one-thread OpenMP mean divided by the OpenMP
configuration mean. Serial's OpenMP scaling field is null. RNG streams differ
between engines, so these are native pipeline timings, not common-input tests.
No confidence-row doubling or outlier filtering is performed. The verifier
independently recomputes sums/two-pass variance and ratios, checks raw process
timings, every repetition and actual team, CSV/JSON agreement and power fields.
It writes independent-audit.json. The recorder uses Welford variance, providing
a separate calculation path. Archive only reviewed completed campaigns.

## API references

- [MSVC OpenMP environment variables](https://learn.microsoft.com/en-us/cpp/parallel/openmp/reference/openmp-environment-variables)
- [Processor topology fields](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-processor_relationship)
- [Windows processor power information and its limitations](https://learn.microsoft.com/en-us/windows/win32/power/processor-power-information-str)
