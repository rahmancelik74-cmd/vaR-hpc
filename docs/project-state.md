# Project state

## CUDA stage-diagnostic checkpoint closed: 2026-10-19

Tested clean source: 80148cee0ba5a52b1c67ca98a6ad4eb91e4d7817. All
18 diagnostic processes completed: N=100000/1000000/10000000, full-device
and hybrid, three repetitions each, diagnostics ON and profiler OFF. The final
auditor passed again at closure without launching measurements. All 11 timing
fields, six configurations and 36 native VaRs were verified; native estimates
match compatible uninstrumented records. No instrumentation defect was found.

See [all six configurations and timing definitions](cuda-stage-diagnostics.md)
and [selected technical evidence](../evidence/v030-cuda-stage-diagnostics-windows-20261019/README.md).
RNG has the largest mean among covered device-stage intervals, not necessarily
the largest end-to-end cost. Hybrid host global quantile means/sample standard
deviations are 6.446100 +/- 0.102400, 76.012333 +/- 2.947261 and
882.868300 +/- 68.314774 ms at increasing N. Host total, pipeline span,
cumulative device stages, copy intervals and host quantile remain distinct.

The original 260 campaign records and 289 delivery-record hashes verified;
all 290 original files stayed unchanged. The incomplete first invocation stopped
in sandbox-denied SDK discovery before any sample. Failed auditors and their
JSON-name/PowerShell Decimal corrections remain preserved; calculations and
unchanged tolerances are reproducible. This is a later documentation/evidence
commit, distinct from the tested source and the closed primary benchmark.

Physical conditions were not freshly confirmed. AC/power records were stable,
GPU point readings were 49-52 C; CPU temperature, thermal equilibrium and
absence of throttling remain unknown. The earlier ambient estimate is not a
current measurement. The primary 9.739930524x/8.307208722x findings are unchanged.
Bandwidth/counter permissions/documented peak, convergence and final
reproducibility/delivery remain separate open items. No profiling, optimization,
academic authoring or new measurement was performed to close this checkpoint.

## Formal primary benchmark closed: 2026-10-19

Clean tested source: 89536e38b01230fce3b4667096c29dde56795c23. The fresh
Windows x64 Release preflight passed 18/18 discovered CTests. The completed
primary campaign contains 312/312 processes: 72 excluded warm-ups and 240
retained measurements, with all 24 configuration rows and all slow samples.
Both existing independent auditors passed again during closure without running
benchmark samples or modifying original evidence. Exact-byte checks verified
3391 run2 session records and 226 run1 records; all 3619 original files,
including both session manifests, remained unchanged throughout review.

At N=10000000, full-device mean was 126.72009999999999 ms (sample standard
deviation 21.833814572813424 ms), 9.7399305240447234x fresh serial and
8.30720872221534x best measured OpenMP. The 10x serial target was NOT met.
Hybrid mean was 1087.93442 ms, 1.1344847146209416x serial and
0.96760457307711611x best OpenMP. Full-device beat best OpenMP here; hybrid
did not. Lowest OpenMP means used 2,4,4 threads at the three increasing N.
These are machine/workload observations, not predictive market validity.

See [the complete result and limits](cpu-gpu-benchmark.md#formal-primary-result-2026-10-19)
and [curated technical evidence](../evidence/v030-primary-benchmark-windows-20261019/README.md).
Original local evidence remains in results/benchmark-formal-89536e3-20261019-run2/;
run1 remains incomplete after a caller path error before any benchmark sample.
This closure is a documentation/evidence change, not the RTX-tested source.

Primary samples used fresh processes/CUDA contexts, diagnostics OFF and the
existing inclusive engine host boundary. Pre/post observation windows completed;
the recorded gaps were 16.6744291 s and 27.3165226 s. GPU point temperatures
were 44-51 C; ambient 15 C was only an estimate. CPU temperature, thermal
equilibrium and absence of throttling were not established. Full conditions
and timing exclusions are retained in the linked result.

The primary benchmark checkpoint is complete. Stage/transfer-excluded diagnostics
are now separately closed above. Achieved DRAM GB/s and percentage-of-documented-peak reporting,
profiling orchestration, convergence and final reproducibility work remain.
ERR_NVGPUCTRPERM and the unverified exact-laptop peak remain blockers to bandwidth
reporting. Plan B optimization is optional and was not started. Academic
submission and live demonstration remain unverified. Earlier dated entries
below describe their historical checkpoint and do not reopen this campaign.

## Benchmark infrastructure preparation: 2026-10-19

Clean source df34111faa3c64b52f03d493ef5aaeb0b41a82b1 verifies the unified
CPU/GPU recorder/auditor, opt-in CUDA stage diagnostics and owned-process-tree
launcher timeouts. Windows Release CTest passed CUDA/OpenMP 18/18, CPU/OpenMP
12/12 and serial-only 11/11. Focused auditor tests passed 61 checks and launcher
tests passed 9 checks. A 24-process primary smoke and separate 4-process
diagnostic smoke both passed independent audits; diagnostics OFF/ON numerical
results matched in each CUDA mode. These are infrastructure smokes, not formal
performance samples. The later documentation commit is not the tested source.
See
[cpu-gpu-benchmark.md](cpu-gpu-benchmark.md) for commands, schemas, timing scope,
formal counts and conditions. This prepares a future fresh CPU/GPU comparison;
it does not replace the accepted 8df5f28 GPU campaign or historical CPU baseline.
Clean evidence: results/benchmark-prep-df34111-clean-20261019-smoke/,
results/benchmark-prep-df34111-clean-20261019-diagnostic/ and the matching
-regressions/ and -review/ directories. Earlier dirty-source evidence and the
stopped ffc8375 verification remain separate. Exact bindings and limitations
are recorded in cpu-gpu-benchmark.md.
Counter permission and exact-laptop documented-peak bandwidth remain unresolved.
No formal benchmark, profiling, convergence, optimization or academic delivery
is established by this preparation. Existing evidence remains unchanged.

Updated: 2026-10-19, Europe/Istanbul. Current source version: 0.3.0.
Windows Release tests, CPU correctness/scaling and full-device/hybrid GPU
five-seed analytical acceptance are verified for their documented cases.
Representative Compute Sanitizer checks passed separately at source 8df5f28;
their coverage limits remain explicit. Earlier hosted CPU CI is distinct from
later checkpoint commits. Formal primary CPU/GPU benchmarking is now complete
as recorded above; stage diagnostics are separately closed; bandwidth reporting remains pending.
The full-device/hybrid implementation supersedes the old N <= 10000 source cap.
This dated ledger supersedes stale progress labels in initial snapshot documents.
It does not replace the supervisor's roadmap or the requirements document.

## Current agreement

Plan A is the agreed complete project. Plan B is an optional extension if
first-term delivery leaves enough capacity; it is not a fallback for failure.
Scope or schedule reductions are discussed with the supervisor. Do not quietly
drop the CUDA skeleton, validation or measurement requirements.

All project documents, submission materials, file names, code identifiers,
comments, scripts and program messages use English. Code and program messages
use ASCII. Conversations with the student and separate explanatory files for
the student may use Turkish. Historical evidence may contain actual local
file paths; these are recorded values, not translated prose.

## Evidence already obtained

- Windows x64 Release configuration and build succeeded in build-foundation
  with Visual Studio 2022 / MSVC 19.44.35227.0. All three CTest tests passed.
  Evidence: evidence/windows-release-ctest-20261015.log, commit 48429b5.
- The authoritative local source folder is graduation_project/gpu-montecarlo-starter.
  Git main baseline: adb49bc. The student reported a clean working tree after
  48429b5. The repository is now hosted at
  https://github.com/rahmancelik74-cmd/vaR-hpc. Main was clean and synchronized
  with origin/main at 31fe206; the student reported successful hosted CPU CI
  with all four tests passing.
- CSV input, log-return calibration, analytical GBM reference and the serial
  engine are implemented. The sample data is hand-written synthetic data.
- Statistical runs cover four scenario counts, five seeds, two confidence
  levels: 20 runs and 40 VaR estimates. The evidence CSV transcribes pasted
  terminal results; it is not an exact export of the student's original log.
- CUDA nvcc 13.4 V13.4.92 works on the student's machine. A standalone
  1024-element CUDA calculation passed on the RTX 4060 Laptop GPU. Evidence:
  evidence/cuda-probe-20261016, commit 1acfee3. Compute capability: 8.9;
  reported VRAM: 8187 MiB. At that earlier probe, no Monte Carlo CUDA pipeline
  or device quantile result had been demonstrated; the later skeleton below
  now supplies this connectivity evidence.
- Target CPU: i7-12650H, 10 physical cores / 16 logical processors. GPU:
  RTX 4060 Laptop GPU, 8 GB VRAM. RAM: 16 GB. Windows 11; VS 2022 17.14.32;
  MSVC 19.44.35227; CMake 3.31.6-msvc6.

## Statistical summary

Mean absolute relative error is the average of each seed's absolute error
divided by the analytical reference. It is a descriptive convergence metric,
not the acceptance formula imported from the revised proposal.

| Scenarios | Mean absolute relative error, 95% VaR | Mean absolute relative error, 99% VaR |
| --- | --- | --- |
| 10000 | 1.365730% | 1.221823% |
| 100000 | 0.254890% | 0.208718% |
| 1000000 | 0.061220% | 0.072268% |
| 10000000 | 0.020966% | 0.040986% |

At 10 million, maximum per-seed relative error is 0.036503% (95%) and
0.068708% (99%). Results support convergence for this parameter case only.
No real-market predictive validity or universal error guarantee is claimed.

## Open work and decisions

| Item | Status | Next evidence needed |
| --- | --- | --- |
| One authoritative local folder / Git | Continued from clean 254de8d; OpenMP source verified at 05f982e and pushed normally | Continue in the existing repository |
| Requirements and Design Document | Draft, not delivered v1.0 | At most eight pages, numbered requirements and checked conventions |
| Proposal source | Student identified the approved Revised file on 2026-10-16; original proposal and v2.0 Plan A/B directly reviewed on 2026-10-18 | Hashes and reconciled criteria in acceptance-source.md; approval/submission receipt not independently verified |
| Core timing / data contract | Implementation and documentation compared with proposal and Plan A; numerical conventions preserved | Preserve primary host scope and separate device diagnostics; academic requirement mapping/delivery remains deferred |
| Data provenance | Local integration and session-date audit complete; user-supplied correspondence permits scoped final academic use and derived sharing without raw data | Preserve private original-message archive and raw-data restrictions; see data-rights-and-calendar.md |
| Metadata / structured result export | v0.3.0 retains schema 1 and adds requested/actual threads and OpenMP version; existing recorder retains serial support and supports OpenMP in smoke mode only | Preserve v0.2.2 evidence; use the separate OpenMP correctness recorder |
| OpenMP | Correctness, CPU scaling and formal primary CPU/GPU comparison verified | Preserve baseline limitations; sorting remains serial; all five team sizes retained |
| CI | CUDA-disabled Ubuntu ON/OFF and Windows CPU recorder smoke passed at 8e3a7e1; run 39161829944 | Keep tested revisions distinct; GPU evidence remains local RTX execution |
| CUDA path | Full-device/hybrid implementation, five-seed acceptance, representative sanitizer checks, primary benchmark and separate stage diagnostics complete | Preserve coverage limits; profiling/bandwidth reporting remains |
| Benchmark | Formal primary comparison at 89536e3: 240 measurements, 72 excluded warm-ups, 24 rows; 10x target not met | Primary checkpoint closed; preserve all samples and condition limits; do not selectively rerun |

The student is on a laptop. Later performance work must record thread placement,
power/thermal conditions and compiler settings. Do not infer CUDA runtime success
from nvcc output or CPU success from an assistant-side Linux build.

## Build incident already resolved

Older sources lacked csv_mode in main.cpp and had only one CTest despite a
data.cpp file being present. Clean v0.2.1 sources resolved the mismatch.
Moving folders also invalidated older CMake caches. Future delivery should use
one source tree, Git commits and explicit version checks rather than repeatedly
merging ZIP source folders. This foundation update contains no replacement C++.

## Existing reminder

An automation already reminds the student to prepare a progress report every
two weeks from 2026-10-28, Wednesday around 10:00 Europe/Istanbul.
Do not create a duplicate. Meeting dates themselves are not known.

## v0.2.2 export and experiment runner

Adds structured JSON output and a serial experiment runner with distinct smoke,
validation and benchmark modes. Windows Release build, all four CTest tests and the serial smoke run passed. Evidence is archived in evidence/v022-smoke-20261015. The older three-test record applies to v0.2.1.
No new OpenMP, CUDA, formal benchmark or supervisor acceptance is claimed.

## Automated serial validation: 2026-10-16

Completed against clean revision 33102c4 using v0.2.2.
Four scenario counts, five seeds, 20 runs and 40 VaR estimates.
CSV and JSONL values agree; manifest configuration was checked.
Evidence: evidence/v022-validation-20261016.
At N=10000000, both confidence levels satisfy the aggregate error condition
for this synthetic case. The proposal identity was pending at the time of
the campaign review and was subsequently confirmed by the student on
2026-10-16. This campaign is not a performance benchmark and does not establish
acceptance for the unimplemented OpenMP/CUDA engines.

## Serial benchmark infrastructure verified: 2026-10-16

Clean revision 6e3fc97; three scenario counts, three warm-ups and
ten measured repetitions each. All 39 runs were checked.
Mean, sample standard deviation and throughput were independently
recomputed and matched the summary. Warm-ups were excluded.
Evidence: evidence/v022-serial-benchmark-20261016.
Power/thermal conditions still need explicit recording for final comparisons.
OpenMP and CUDA comparisons remain pending.

## Current continuation point: academic week 5

The student identified the current academic week as week 5. The initial CUDA
compatibility check and hosted CPU CI are complete. This does not close the
whole weeks 5-6 foundation milestone: the Requirements and Design submission,
remaining inventory decisions and data provenance still require follow-up.
The submission document is deferred until the student requests preparation;
progress and presentation templates are also prepared only on request.

Documentation translation was committed in 31fe206. The two translated CTest
logs identify themselves as English transcriptions and retain the original
revision and SHA-256; byte-original logs remain available in Git history.
No numerical model, acceptance threshold or application behavior was changed.

The serial Release flags are `/O2 /Ob2 /DNDEBUG`, in addition to the common
flags `/DWIN32 /D_WINDOWS /GR /EHsc`. See environment.md for the recorded
CMake generator and remaining settings. OpenMP implementation and correctness
verification and the CPU scaling baseline are complete as recorded below.
This advances work from the weeks 10-11 block without closing unfinished
earlier milestones. Later GPU work requires a separately authorized task.

## Windows OpenMP correctness milestone: 2026-10-16

Source revision: 05f982effc570366597fc5f13f8b3a0440b293a8, clean before
the recorded clean-first Windows x64 Release rebuild. Application: 0.3.0.
Evidence: evidence/v030-openmp-windows-correctness-20261016.
MSVC 19.44.35227.0; OpenMP 2.0, _OPENMP=200203, compiler flag -openmp.
ON passed all six CTests; OFF passed all five applicable CTests, including
clear rejection of unavailable OpenMP. Existing serial positional commands
and JSON output work; serial calculations and RNG were not changed.

The separate mc_openmp library generates double losses in fixed blocks of
4096 using private RNG state. Native streams differ from serial, but estimates
are invariant across requested threads 1,2,4,8,10 in the same build. Recorded
native thread checks at N=10000 and 100000 used exactly those actual team sizes.
Common-input tests compare identical read-only normals separately, cover block
boundaries and worker exceptions, and do not constitute statistical validation.
Sorting is serial. See openmp.md for RNG derivation and timing boundaries.

The native-RNG correctness campaign contains all 20 combinations of four
scenario counts (10000 through 10000000) and five seeds (42,123,456,789,2026).
All runs requested and used four threads; 40 estimates were archived.
CSV/JSON agreement, unique configurations, exact-byte input/executable hashes
and error-of-mean calculations were independently checked.

| Confidence | Five-seed mean at N=10000000 | Analytical VaR | Absolute error of mean | Allowed error | Result |
| --- | --- | --- | --- | --- | --- |
| 0.95 | 6.142451880525334 | 6.143576939418958 | 0.001125058893624242 | 0.06143576939418959 | Pass |
| 0.99 | 8.712967414933399 | 8.715446716200948 | 0.002479301267548806 | 0.08715446716200948 | Pass |

Criterion, separately per confidence:
abs(mean(VaR)-analytical) <= 0.01*max(abs(analytical),0.01*initial_value).
This is the error of the five-seed mean, not mean absolute error or a per-seed
requirement. Initial value is 100.4. These are synthetic correctness runs,
not a formal performance benchmark or market validation.

Hosted CI for the verified source passed both matrix jobs:
https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/38926767341.
The archive includes job metadata and contiguous CTest log excerpts.
No CUDA Monte Carlo work or supervisor submission was prepared. Plan A remains
the main roadmap; academic week 5 and earlier open milestone items are unchanged.

## Fresh CPU scaling baseline: 2026-10-16

Clean source aa901a38b0d903d73a817aaf16c2a3743413b6af, application 0.3.0,
Windows x64 Release. The recorder and separate instrumentation do not change
the numerical engines. Evidence: evidence/v030-cpu-scaling-windows-20261016.
The eight Windows CTests include the retained six correctness tests plus
statistics and CPU instrumentation contracts. An 18-process smoke campaign
and independent audit passed before the full campaign.

Full campaign: N=100000,1000000,10000000; seed 42; serial and OpenMP requested
threads 1,2,4,8,10; three warm-ups plus ten measured repetitions per row.
All 234 processes are retained: 54 warm-ups excluded, 180 measured runs and
18 summary rows. The fresh serial and OpenMP results share the same clean
source, Release build, executable and exact input bytes. Historical v0.2.2
timings are not the reference. Explicit-sum/two-pass recomputation independently
matched means, sample standard deviations, throughput and both speedup ratios.

At N=10000000, serial mean was 1088.13644 ms (sample stddev 9.85657 ms).
OpenMP 10 mean was 915.65387 ms (stddev 10.74795 ms), 10921157 scenarios/s,
1.18837x fresh-serial speedup and 1.17994x scaling from OpenMP 1. Means for
4/8/10 threads were close relative to variation. At N=100000 and 1000000,
the lowest observed means used OpenMP 1 and 2 respectively. Higher thread
counts sometimes slowed smaller workloads; no slow run was filtered.

Actual teams matched all requests. Topology was read from Windows physical
core masks: 10 cores / 16 logical processors, with six SMT class-1 cores and
four single-logical class-0 cores. The same process pool ffff and normal
priority were set and verified before every CLI process resumed. Thread
placement within that pool was left to Windows. Runtime binding variables
did not keep probe workers on one physical core; all 25 requested-binding
probe workers migrated across core masks. A single-logical-CPU process-mask
control did constrain all four workers. No physical-core placement is inferred
from thread count. Runtime: vcomp140.dll 14.50.35719.0; _OPENMP=200203.

AC connection, battery 100%, saver off and the active power-scheme GUID were
consistent in every pre/post observation. The user reported charger connection,
heavy applications closed and comfortable unmeasured room temperature. Surface,
cooling and vendor fan mode were unspecified. CPU package temperature, fan speed,
package power and throttling events were not measured. OS frequency/throttle
snapshots do not measure turbo clocks or establish thermal equilibrium.
These limitations qualify the baseline and are retained in the evidence.

Each sample used a new CLI process/runtime. The existing engine timing boundary
is unchanged, including serial sorting; telemetry, process startup, shared CSV
calibration and the fixed 100 ms between processes are excluded. Warm-ups do
not retain an engine/team. Recorded rotating/reversing order spreads temporal
effects without claiming to eliminate them. See cpu-benchmark.md.

This completes the requested CPU scaling baseline. Full cross-engine benchmark
work, real data provenance, earlier foundation decisions and the later GPU
walking skeleton remain on Plan A. No CUDA engine or submission document was
started. Academic week remains 5.

Hosted source-commit CI passed Ubuntu ON/OFF tests and Windows instrumentation
with all eight CTests plus the recorder smoke campaign:
https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/38929662346.

## CUDA walking skeleton verified: 2026-10-16

Clean source 89512365186698278d0f79688d200e9039276415, rebuilt Windows x64
Release, architecture 89. Evidence: evidence/v030-cuda-skeleton-windows-20261016.
The optional MC_ENABLE_CUDA flag defaults OFF. A separate mc_cuda library now
implements Engine::run: shared CSV/calibration -> device cuRAND PHILOX double
normals -> terminal losses -> CUB DeviceRadixSort<double> -> device nearest-rank
gather -> scalar VaR. No host sorting or host loss-vector quantile is used.
CUB 3.4.3 is verified here and selected for the intended later implementation.
CPU serial/OpenMP numerical code and historical evidence are unchanged.

All seven CUDA-enabled CTests passed. CUDA-disabled OpenMP ON passed six and
serial-only passed five, including explicit unavailable-backend rejection.
Fresh CPU estimates match exactly between ON/OFF builds and the preserved
previous CPU executable. Thirty-two common-input comparisons passed, including
negative/tied/zero losses, nearest ranks, 1/5/257/9999/10000 samples, shared
CSV calibration, invalid input/overflow and recovery. Maximum absolute CPU/GPU
difference was 7.105427357601002e-15 under a fixed math-library tolerance.
Native cuRAND execution is a separate connectivity smoke, not statistical
acceptance. N=10000, seed 42 produced VaR95=6.159886901343543 and
VaR99=8.715234403518073. Odd N=5 also verified even normal-buffer padding
and the exact uint64 maximum seed string. Equal CPU/GPU seeds do not imply
equal native samples. Requests above 10000 are explicitly rejected.

The primary host timer includes allocation, RNG, simulation, CUB scratch/sort,
gather, transfers, synchronization and cleanup, plus initial CUDA context/API
work. Shared calibration and printing are excluded. Separate CUDA Events
record native H2D 16 bytes / 0.0235520005 ms and D2H 20 bytes / 0.0706879981 ms.
These single-run copy diagnostics are not performance measurements for a
comparison campaign. Pageable staging belongs to primary wall time.

The N=10000 explicit VRAM budget is 331939 bytes, including 91903 CUB scratch
bytes and both sort arrays. Free-memory snapshots are archived. The initial
80%-free linear extrapolation is 179579526 scenarios, not a verified capacity;
opaque library/context allocations, nonlinear scratch scaling and concurrent
GPU use limit it. No large allocation or full-scale run was attempted.

Actual versions: nvcc 13.4.92, MSVC 19.44.35227.0, Windows driver package
32.0.16.1088, driver API 13030, runtime API 13030, runtime header 13040,
cuRAND header 10.4.4.72/runtime 10404 and CUB 300403. DLL versions/hashes are
recorded separately. The runtime API/header discrepancy is documented without
substitution. See cuda-skeleton.md for the build, timing and library contract.

The first-term connectivity task is complete; later full-scale GPU acceptance,
memory/batching, profiling and CPU/GPU benchmarking remain pending. Academic
week 5, Plan A, earlier foundation/data-provenance gaps and deferred supervisor
submissions are unchanged. No requirement IDs or submission documents changed.

Hosted CPU regression at the verified source passed all three existing jobs:
https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/38934437451.
CUDA is disabled in hosted CI; these results do not substitute for local GPU
execution. Job metadata and CPU test/progress excerpts are archived separately.

## Historical equity integration preparation: 2026-10-16

Working candidate: MSFT daily Close, requested 2023-01-01 through 2025-12-31,
one share, ten trading days and 252 observations/year. These remain working
settings. No historical observations or calibration values are available yet.
Stooq download/policy pages returned browser-verification HTML; adjustment and
reuse conditions could not be verified. Alpha Vantage's free daily compact
history cannot cover the requested interval; paid full history was not introduced.

The offline converter preserves exact raw/metadata bytes, validates all rows,
requires explicit reordering and records ranges, selected Close, transformations,
hashes and policy declarations. Data and local outputs are ignored. Artificial
fixtures independently check log returns and calibration against C++ JSON.
The genuine-data runner separates CPU integration from capped CUDA native smoke
and rejects artificial imports. No historical integration, GPU benchmark or
full-scale GPU acceptance is claimed. Engines, IDs, previous evidence and local
submission files are preserved. Protocol and exact missing inputs: historical-data.md.

Local Windows x64 Release verification passed 7 CTests with OpenMP ON/CUDA OFF,
6 with both OFF and 8 with CUDA ON. The new converter test passed 38 artificial
fixture checks, independent C++ calibration, labelled runner smoke and tampering
rejection. This is software verification while genuine historical acquisition
is blocked; it is not a completed historical-data campaign.

## Local historical pipeline evaluation: 2026-10-17

The documented Kibot public guest path supplied genuine MSFT daily data for
the requested interval. Explicit unadjusted=1 selects prices without split or
dividend back-adjustment. Close is the last regular-session trade, which is
not necessarily the official closing auction. USD is documented from the
instrument's denomination, not claimed as a CSV-returned currency field.
One share, ten trading days and 252 observations/year remain working settings.

Source 1b61903 was rebuilt clean-first in Windows x64 Release with CUDA ON.
All eight CTests passed; OpenMP ON/CUDA OFF passed seven and serial-only six.
The converter test now has 46 artificial checks. Independent calibration,
serial/OpenMP native integration and separate N=10000 CUDA connectivity passed
on genuine imported data. No native CPU/GPU sample equality, full-scale GPU
acceptance or speedup is claimed. Engines, IDs and historical evidence remain
unchanged. This resolves the earlier local-access blocker, not final dataset rights.

The guest route is for evaluation and the license prohibits redistribution of
data and related/derived information. Raw responses, complete policy snapshots,
coverage/counts, hashes, calibration and numerical results remain only under
ignored data/local and results. Public records retain procedure and software
verification status without provider observations or derived numerical tables.
The final research/publication dataset, suitable sharing rights and exchange-
calendar completeness still require a separate decision. See kibot-evaluation.md.

## Rights review and local calendar audit: 2026-10-17

Current primary license/access pages were reviewed and preserved locally. The
published grant remains internal-use only, covers related/derived information,
and prohibits redistribution; guest API access is for evaluation. Final research,
supervisor sharing and public derived-result rights are not established. Explicit
permission covering those uses or a suitably licensed replacement source remains
the next data decision. No contact, paid access or replacement was initiated.

A separate offline checker now compares the existing import with the bounded
Nasdaq US cash-equity session calendar, retaining early closes and the special
January 9, 2025 closure. Its input hashes, differences, annual counts and conclusion
remain under ignored results. Existing raw/metadata/price bytes and the original
manifest are preserved; no observations were filled or removed and no settings
changed. Completed calibration/backend integration was not restarted.

Twelve artificial calendar checks and the new Windows CTest passed in the CPU
build. Engines and the N <= 10000 CUDA guard are unchanged. Full-scale GPU work,
performance campaigns and academic document authoring were not started. See
data-rights-and-calendar.md for the procedure, sources and limits.

## Offline serial/OpenMP demonstration

The existing experiment recorder now permits OpenMP in smoke mode only, while
retaining default serial behavior and serial v0.2.2 CLI compatibility. Separate
native runs use the existing synthetic fixture, N=10000, seed 42, ten observation
steps, 252 observations/year and a requested OpenMP team of four. Models,
analytical references, estimates, engine times and hashes remain in local results.
These runs are demos, not benchmark or aggregate statistical acceptance evidence.
See synthetic-demo.md. The established OpenMP validation and CPU benchmark
recorders, numerical engines and capped CUDA path are unchanged.

## Continuation verification: 2026-10-17

Read-only remote verification confirmed main HEAD and origin/main at 7497f10,
with 1b61903 in its history. Existing staged changes, untracked local files and
historical evidence were preserved. This verification used the current working
tree, not a clean committed revision; no new commit or push was performed.

Local import artifact hashes matched the existing manifest. The historical
integration records and separate provenance binding were inspected without
repeating acquisition, calibration or backend integration. A fresh offline
calendar audit completed; its provider-derived conclusion and details remain
private in ignored results. Local evidence paths:

- `results/msft-kibot-integration-1b61903/manifest.json`
- `results/msft-kibot-verification-20261017/provenance-binding.json`
- `results/msft-calendar-continuation-05eff05b115e42a988d4e2d1557b1389/calendar-audit.json`

Windows Release CTest passed 9/9 tests in build-historical-cpu (OpenMP ON,
CUDA OFF) and 8/8 in build-historical-off (both OFF), including the calendar
and synthetic demo recorder regressions. These checks used existing builds;
no fresh compilation or CUDA test rerun is claimed. Local test logs are
`build-historical-cpu/Testing/Temporary/LastTest.log` and
`build-historical-off/Testing/Temporary/LastTest.log`; CTest may overwrite them
on subsequent runs. The staged patch also passed `git diff --cached --check`.

Final research, academic sharing and publication rights remain unresolved;
local evaluation permission does not establish those rights. Next data step:
obtain and review any additional written provider permission, or decide on a
source with suitable documented rights before final research use. Full-scale
CUDA acceptance and CPU/GPU benchmarking remain pending; the N <= 10000
guard is unchanged. No restricted observations or derived numerical tables
were added to repository documentation, and no academic deliverable was authored.

## Calendar/demo review and Git recording: 2026-10-17

Reviewed the bounded session calendar, immutable-input/hash checks, synthetic
smoke recorder, regression tests and associated documentation. Corrected output
path resolution to follow the PowerShell location rather than the process-wide
current directory; the new regression deliberately separates those locations.
The calendar suite now passes thirteen artificial checks.

Both existing Windows x64 Release configurations were reconfigured and built
with CUDA OFF. Final CTest passed 9/9 with OpenMP ON and 8/8 with OpenMP OFF.
The first test attempt could not resolve Get-FileHash in child Windows PowerShell;
the final runs used the standard Windows PowerShell module directories in the
process environment only. No persistent environment setting was changed.
Final logs and CMake caches are preserved under ignored
results/calendar-demo-review-3a1607cf04fa47d29ec9e12bc2eafdec/ (openmp-ctest.log and serial-ctest.log).
The tested checkout included the pending patch on base 7497f10; this is not a
claim of clean-commit testing or a new CUDA execution result.

Only calendar/demo code, tests and related documentation are selected for Git
recording. Local AGENTS.md, output/, provider data and derived local results
remain excluded. Engines, acceptance criteria and the CUDA cap are unchanged.
The user reports that the provider has not replied to the permission request;
final research/sharing rights remain unresolved. Full-scale CUDA acceptance,
GPU benchmarking and academic authoring remain pending.

## Hosted CPU CI verification for b0cd749: 2026-10-17

GitHub Actions run [39058591082](https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/39058591082),
attempt 1, completed successfully for pushed commit
`b0cd749d62e05d8c04ed73e8d20d3e8cf342dd10` on main. The remote main reference
was checked and matched this commit before this documentation update.
Run metadata, individual job/step conclusions and decoded job logs were reviewed:

- Ubuntu `cpu (ON)`, job 117471580693: Release configure/build and CTest
  succeeded; 6/6 tests passed with OpenMP ON and CUDA OFF.
- Ubuntu `cpu (OFF)`, job 117471580927: Release configure/build and CTest
  succeeded; 5/5 tests passed with OpenMP OFF and CUDA OFF.
- `windows-instrumentation`, job 117471580913, on windows-2022: the existing
  CPU recorder smoke/instrumentation step succeeded, including one warm-up
  round and two measured smoke rounds. Its console log does not print a
  CTest count; the local Windows counts below are separate evidence.

No CI failure required a source correction. Local Windows Release evidence
remains in `results/calendar-demo-review-3a1607cf04fa47d29ec9e12bc2eafdec/`:
OpenMP 9/9, serial-only 8/8, and thirteen artificial calendar checks, as recorded
in the preceding review. Hosted CPU success is not local RTX execution,
full-scale CUDA acceptance or a performance benchmark. This follow-up changes
only this state document; `git diff --check` is the relevant local check.

The user reports no Kibot permission response; final research, academic sharing
and publication rights remain open. Next data step is to review a provider
response when available, without treating evaluation access as research or
redistribution permission. Completed historical integration was not repeated.
No restricted data/results, local AGENTS.md or output/ are selected for commit.
Full-scale CUDA, GPU benchmarking and academic authoring were not started.
This documentation update is to be committed and pushed separately from the
CI-tested source commit; that new commit is not covered by run 39058591082.

## Scoped correspondence and CI verification: 2026-10-18

Initial branch main, HEAD and remote main matched
`69e558b72ba97b79c7f4b0e98e96f6979d8ca5fd`. The tracked working tree was clean;
untracked AGENTS.md and output/ were preserved and excluded from this task.
GitHub Actions [run 39059075567](https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/39059075567),
attempt 1, completed successfully for that exact commit. Reviewed job metadata
and decoded logs show Ubuntu OpenMP ON 6/6 (job 117473127714), OpenMP OFF 5/5
(job 117473127666), and successful windows-instrumentation smoke (job
117473127716; one warm-up and two measured smoke rounds). Windows console output
does not expose a CTest count. This run tests 69e558b; the earlier run 39058591082
tests b0cd749. Neither run tests the new documentation commit from this task or
establishes RTX execution, GPU acceptance or performance benchmarking.

The user now reports a provider reply permitting retention and final academic
experiments for internal use on the two computers normally used. Derived
statistics, calibration parameters, VaR estimates and charts may be shared in
reports, supervisor/committee copies, submissions, public thesis/project
documentation and outside reviews, provided they contain no raw data. Raw
prices may not be resold or redistributed. Acquisition methods, guest API
requests and scripts may be described without price data; attribution is optional.

The reply was accessible through connected Gmail and consistent with the user's
supplied scope. A raw RFC 2822 mailbox export, including sender/date headers and
attachment bytes, was preserved outside the repository at
`../private-evidence/kibot-permission-20261018/provider-reply.eml`, with
`archive-metadata.json` recording provenance and its exact-byte hash. This is
user-supplied provider correspondence, not independent authentication of the
sender or authority. Full email/contact details remain private. The current
scope in data-rights-and-calendar.md supersedes the dated permission-pending
statements above; those entries and acquisition-time manifests remain intact.

Only rights and state documentation changed: data-rights-and-calendar.md,
kibot-evaluation.md, historical-data.md and this file. The focused diff, local
Markdown links and whitespace were checked; no code tests or completed
integration were rerun. No dataset, calibration, model or engine setting changed.
Raw data and derived local outputs remain ignored and are not selected for Git.
This documentation patch is committed/pushed separately; its new CI result must
not be inferred from 69e558b. No benchmark, CUDA expansion or academic deliverable
was started. The remaining evidence limitation is independent authentication,
not a provider-response-pending status within the supplied scope.

Next first-term technical step: review the remaining hardware/software inventory
and timing/acceptance-contract decisions against the approved proposal. The
Requirements and Design delivery remains outstanding and its authoring stays
deferred until explicitly requested. Preserve the completed integration and
calendar work; full-scale CUDA and GPU benchmarking remain later tasks.

## First-term readiness audit: 2026-10-18

Initial main HEAD and remote main both matched
`8e3a7e1d18ed759b327aef4b3f42b839e57ac363`; tracked files were clean and
untracked AGENTS.md/output/ were preserved. GitHub Actions
[run 39161829944](https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/39161829944),
attempt 1, passed for that exact commit. Job metadata and logs show Ubuntu
OpenMP ON 6/6 (117776554574), OFF 5/5 (117776554548), and Windows instrumentation
smoke success (117776554336; one warm-up/two measured rounds, no console CTest
count). Earlier run 39059075567 tests 69e558b. Neither run tests this audit patch.

Sources were accessible: existing Downloads copies of the Revised proposal,
Plan A and Plan B v2.0 dated 2026-10-14 were read directly, including tables;
their exact-byte hashes are in [acceptance-source.md](acceptance-source.md).
The student-reported approved-file identity remains distinct from a signed
approval/submission receipt, which was not verified. No private academic source
was copied into Git. The comparison uses proposal sections 5/8/9 and the original
roadmaps, rather than treating older repository summaries as authoritative.

Inventory comparison: the required CPU/GPU, topology, memory and toolchain fields
are recorded in [environment.md](environment.md). Archived CPU inventory confirms
i7-12650H, 10 physical/16 logical cores, process OS version 10.0.26200.0 and
vcomp140.dll 14.50.35719.0 (_OPENMP=200203). Windows 11 edition, nominal 16 GB RAM
and VS 17.14.32 include earlier student reports; RAM was not newly measured.
CUDA records confirm RTX 4060 Laptop GPU, 8585216000 bytes VRAM (8187 MiB),
compute capability 8.9, nvcc 13.4.92, MSVC 19.44.35227.0 and CMake 3.31.6-msvc6.
Release x64 uses /O2 /Ob2 /DNDEBUG plus /DWIN32 /D_WINDOWS /GR /EHsc; core/OpenMP
targets add /W4 and OpenMP uses -openmp. CUDA uses architecture 89, --fmad=false and
-Xcompiler=/Zc:preprocessor. Driver package 32.0.16.1088, driver/runtime APIs
13030, runtime header 13040 and DLL file version 6,14,11,13040 remain distinct.
cuRAND header 10.4.4.72/runtime 10404 and CUB 300403 (3.4.3) match the skeleton
record. The API/header discrepancy is documented without an invented explanation.

The numerical/timing contract agrees with the source criteria: five independent
seeds at N=10000000, separately per engine and alpha=0.95/0.99, use
abs(mean(VaR)-analytical) <= 0.01*max(abs(analytical),0.01*V0); common-input
absolute difference <= 0.00001*V0. Mean absolute error and individual-seed checks
do not replace error of the mean. Double precision, ascending nearest rank
ceil(alpha*N)-1, negative VaR, lower analytical terminal quantile 1-alpha,
log-return sample variance n-1 and annual price drift m/dt+0.5*sigma^2 remain
implemented conventions. The proposal requires explicit consistent conventions;
it does not itself specify every calibration/quantile formula. Native RNG checks
remain separate from common inputs and memory/race verification.

Primary host time includes allocation, RNG, simulation, global quantile,
required transfers, synchronization and cleanup; shared input/calibration and
output are excluded. Fresh-process/context policy is explicit; the skeleton
includes initial CUDA context/API work. CUDA Events are separate device stages,
not a substitute for host time. Plan A also requires clearly scoped transfer-
excluded figures. Final benchmarking remains N=100000/1000000/10000000,
3 excluded warm-ups and 10 measured repetitions, mean/sample SD/scenarios per
second, OpenMP 1/2/4/8/10, and GPU speedups against fresh serial and best measured
OpenMP for the same workload. The 10x serial target is not guaranteed.

The proposal's baseline achieved DRAM GB/s and percentage of documented peak,
with metric definitions and profiling outside timed samples, remain required.
Plan A preserves those criteria; Plan B adds optional targeted optimization and
before/after evidence. Stage coverage, aggregation and peak-source selection
remain explicit term-two reporting decisions, not a reason to delete the
baseline requirement or start optimization now. No fixed bandwidth/GFLOPS target.

Readiness evidence reviewed: serial validation at 33102c4
(`evidence/v022-validation-20261016`), OpenMP correctness at 05f982e
(`evidence/v030-openmp-windows-correctness-20261016`), CPU scaling at aa901a3
(`evidence/v030-cpu-scaling-windows-20261016/benchmark/manifest.json`,
`inventory.json`, `independent-audit.json`), and CUDA skeleton at 8951236
(`evidence/v030-cuda-skeleton-windows-20261016/manifest.json` and
`native-N10000.json`). Existing CPU aggregate acceptance/scaling and capped GPU
connectivity are complete for their documented cases, not full project acceptance.
Calendar/integration and scoped Kibot correspondence remain as previously recorded
and were not repeated. No independent email authentication is newly claimed.

Unknown package temperatures, actual turbo clocks, cooling/fan mode and thermal
equilibrium remain unknown. Full-pool process affinity ffff was verified; runtime
binding requests did not establish per-core pinning. These limits and the version
discrepancy do not prove past results failed. Final study units/horizon/day scale
remain working choices. No new hardware query, campaign, profiling or dependency
was introduced; this audit reviewed stored evidence and current source only.

Corrected stale approval/evidence wording in acceptance-source.md, top inventory
fields in environment.md, source/milestone/reporting distinctions in milestones.md,
and obsolete planned-interface/calendar/test-count wording in architecture.md.
Academic requirements/report/presentation files and README cleanup were untouched.
Documentation checks cover the focused diff, whitespace, ASCII and local links.
Only these four technical documents and this state file are selected for the
separate audit commit/push; its CI result is not inferred from 8e3a7e1.

Next first-term step: confirm the existing Requirements and Design delivery
status and its numbered mapping to this audited contract when that work is
requested, then the live CPU demonstration/interim delivery. Offline demo
readiness is not proof of a live demo or academic submission. Full-scale CUDA,
batching/global hybrid fallback, GPU five-seed and memory/race checks, complete
CPU/GPU comparisons, baseline bandwidth reporting, convergence and final
reproducibility/reporting belong to term two. Optional Plan B remains optional.

## First full-device CUDA scale-up: 2026-10-18

Continued on main at 995cd0974fe9757da9a37ba27da550744da4a6e6 with a clean
tracked tree and preserved untracked AGENTS.md/output/. This is working-tree
implementation verification, not clean-commit testing. No commit or push was
performed. Existing historical evidence was not edited or regenerated.

CudaEngine retains Engine::run, device PHILOX/normal-double, caller-owned common
inputs, double losses and one global CUB 3.4.3 sort/gather. Its explicit support
limit is now 1 through 10000000 scenarios, still 1 through 16 confidence levels.
Checked arithmetic covers padding, bytes and totals; counts, ranks and launch
dimensions are validated before use. Actual-request workspace query precedes
all seven pipeline buffer allocations. The following free-memory snapshot is
used to reject explicit budgets above floor(4*free/5); opaque allocations and
competing activity prevent a capacity guarantee. Every actual API/allocation
remains checked. Current JSON replaces the old linear estimate with the budget
limit and labels the milestone full_device_scale_up. See cuda-skeleton.md for
ownership, error handling, policy exclusions and unchanged timing boundaries.

Windows x64 Release was configured and built in build-cuda-scale-up (CUDA ON,
OpenMP ON, architecture 89), build-cuda-scale-cpu (CUDA OFF, OpenMP ON), and
build-cuda-scale-serial (both OFF). CPU instrumentation was OFF and testing ON.
The initial sandbox configure could not access the Windows SDK directory;
authorized builds outside the sandbox succeeded with MSVC 19.44.35227.0 and
nvcc 13.4.92. Current test lists were inspected: 11, 10 and 9 registrations.
Final CTest passed 11/11, 10/10 and 9/9 respectively. The initial CUDA CTest
caught the integration recorder's stale scenario-limit expectation; that check
was updated without rerunning genuine historical work.

Final CTest logs and working-tree source/artifact hashes are recorded under
ignored results/cuda-scale-up-995cd097-working-20261018/. Tests include pure CPU
arithmetic and synthetic memory-budget rejection without GPU exhaustion,
10000/10001, odd/even/partial blocks, upper-limit rejection, signed/tied losses,
negative VaR, caller-input preservation and recovery after invalid device data.
The integration/calendar tests use artificial fixtures, not provider campaigns.
Serial and OpenMP smoke estimates agreed exactly across CUDA ON/OFF builds.
The revised legacy recorder was syntax-checked and its native Sample function
was exercised at odd N=5 with the maximum uint64 seed; its complete clean-source
workflow was not invoked on this dirty/untracked working tree.

Separate fresh-process native scale checks used the CLI's default synthetic
GBM model, seed 42, alpha=0.95/0.99 and N=100000/1000000/10000000. All completed
on RTX 4060 Laptop GPU with finite results and CUB_VERSION=300403. Observed
explicit budgets were 3236387 / 32276003 / 322676259 bytes; workspace bytes were
836351 / 8275967 / 82676223. Each preflight saw 7449083904 free bytes and an
80% limit of 5959267123 bytes. An additional native N=10001 check allocated
10002 normals and reported 331971 explicit bytes. These snapshots are not peaks.

Focused common-input scale checks at those three N values passed the absolute
project tolerance 0.00001*V0 as well as the retained stricter regression tolerance.
At alpha=0.95/0.99 the default-model scale fixture differences were zero. All
40 comparisons in the scale-check executable, including edge/recovery cases,
had maximum absolute difference 7.105427357601002e-15; the regular regression
executable emitted 56 comparisons. Repeated deterministic fixtures are numerical
checks, not native random samples or statistical acceptance.

No five-seed GPU acceptance, memory/race sanitizer, profiling or formal benchmark
was run. Actual out-of-memory/driver failures were not forced. Package thermal
conditions were not measured. Native scale timings are diagnostics only; no
speedup claim follows. Batching and the explicitly labeled global host-quantile
hybrid fallback remain the next separate implementation step; never average
batch VaRs. This does not complete the Plan A memory/batching milestone or
establish any academic submission. Data rights and historical integration remain
as previously recorded; no acquisition, provider calibration or calendar audit
was repeated.

## CUDA checkpoint review: 2026-10-19

Reviewed the scale-up diff and the existing working-tree evidence manifest.
The recorded source, binary and evidence hashes matched before review edits.
No numerical engine defect or unrelated source change was found. The recorder's
clean-source check needed to preserve the deliberately untracked AGENTS.md and
output/ paths; only those exact untracked entries are now excluded, with the
policy recorded explicitly. All tracked edits and other untracked paths still
fail the check. Deterministic helper checks covered these exclusions/rejections,
missing common-input sizes and tolerance failures; PowerShell syntax passed.

The complete recorder is to run from the source commit with -IncludeScaleChecks,
using only data/synthetic_prices.csv and separate native/common-input records.
It now records source commit/tree, exact build caches and executable hashes for
CUDA ON and both CPU-only configurations, CPU equivalence records, and output
record hashes. The option also invokes the common-input scale checks. Explicit
build/testing options avoid stale-cache assumptions. Output must be a new
directory below ignored results/. Clean-source verification results belong in
a subsequent entry naming the tested source commit separately from the later
documentation commit. No existing historical or working-tree record is replaced.

## Clean-source CUDA checkpoint verification: 2026-10-19

Tested source commit: e4ae78849d3a55baf08b21ccc86934d3ec0ed86a on main.
Source tree: 4f425dde682dd6f41d07264d404f488c06c38320. The tracked source was
clean before and after the complete recorder workflow; the only untracked paths
were AGENTS.md and output/, explicitly excluded from the source check and left
untouched. This entry is recorded in a later documentation-only commit, which
must not be described as the locally GPU-tested source revision.

Invocation: scripts/run-cuda-skeleton.ps1 -OutputDirectory
results/cuda-scale-up-e4ae788-clean-20261019 -IncludeScaleChecks.
The complete workflow ran from 2026-10-18T21:21:36.5485301Z through
2026-10-18T21:22:37.7617766Z (October 19 locally), with status completed.
Windows SDK/CUDA build access used the authorized execution outside the sandbox.
Standard Windows PowerShell module directories were supplied only in that
process's PSModulePath; no persistent environment setting changed.

Clean-first Windows x64 Release builds passed all registered tests: CUDA ON /
OpenMP ON 11/11, CUDA OFF / OpenMP ON 10/10, and both OFF 9/9. CPU tools were
explicitly OFF, testing ON and CUDA architecture 89. No CPU-only configuration
discovered the CUDA Toolkit. CUB_VERSION remained 300403. Serial and OpenMP
synthetic smoke estimates matched exactly across CUDA ON/OFF builds. Only
artificial import/calendar regression fixtures ran, not historical acquisition,
provider calibration or a historical calendar audit.

Native seed-42 scale checks at N=100000/1000000/10000000 used the documented
hand-written data/synthetic_prices.csv, one unit, 10 observation intervals and
252 observations/year. The separate native odd-N smoke used N=5 and seed
18446744073709551615. Common-input regression produced 56 comparisons; the
separate common-input scale executable produced 40 including edge/recovery
cases, with maximum absolute difference 7.105427357601002e-15. All satisfied
both the retained regression tolerance and the project bound 0.00001*V0.

Native explicit device budgets at the three target N values were
3236387 / 32276003 / 322676259 bytes, including CUB workspace of
836351 / 8275967 / 82676223 bytes. Each observed 7449083904 free bytes at
preflight and a floor(4*free/5) budget limit of 5959267123 bytes. These are
allocation budgets and snapshots, not measured peaks or capacity guarantees.

The ignored local evidence directory is
results/cuda-scale-up-e4ae788-clean-20261019/. Its manifest binds the exact
source revision/tree, synthetic input, CUDA executable/test executable, all
three build caches and CLI executables, and resulting record hashes. Each
record hash and current build artifact hash was independently rechecked.
Exact-byte SHA-256 values:

- manifest.json: 42fcb301fad4755d514690eaa229502babce33662d185734aec317d9c778597e
- synthetic input: 8dbb7c73e6ad48cb8c8c175aff6684d2a0433e5f08424ec7ea1e69037bb36210
- CUDA CLI: 51493016071b6f6b64eedf46f56e157857c27c2b17f209a07aa060a0a0a9ef97
- CUDA test executable: f69c60dc3977d7122c18c6b457a05c3eaa36d675039640488a882573f29b0ad0

Previous working-tree and first-term evidence remains unchanged. This is
implementation/scale verification with fresh-process native calls, not five-seed
GPU acceptance, memory/race sanitizer evidence, profiling, formal benchmarking
or speedup evidence. Batching/hybrid support remains unimplemented. No academic
document or submission was created. The source and this later documentation
commit are to be pushed normally; hosted CI must be checked against the exact
final pushed SHA separately and does not establish RTX execution.

## Bounded-memory hybrid implementation: 2026-10-19

Started on main at 9fa1d2772b0a6853342d8ece18c13c8eb5cf63fa with a clean tracked
tree; untracked AGENTS.md/output/ and all historical evidence were preserved.
This task makes no commit or push. Results describe the working-tree source,
not a clean committed revision or hosted CI of these edits.

The default full-device CUDA/cuRAND/CUB path remains available unchanged in
numerical behavior, including N <= 10000000. Explicit --cuda-mode hybrid with
--batch-size uses GPU normals/losses and three bounded device buffers, copies
all N scalar losses to one host array and takes one global host sort/quantile.
Engine::run, CPU numerical engines, precision and acceptance criteria are
unchanged. No automatic fallback, N reduction or batch-VaR aggregation exists.
See cuda-hybrid.md for selection, ownership and the exact memory/RNG contract.

Native mode keeps one seeded PHILOX generator alive across even interior calls.
An odd requested batch is rounded up to even before capping at N; only an odd
total request pads its final call. Batch partition is part of RNG configuration;
batch-size invariance is not claimed. Common input retains its exact requested
partition (capped at N), bypasses RNG and remains caller-owned and unchanged.
Independent native-reference tests concatenate explicitly specified cuRAND call
outputs and compare CPU/global quantiles. One-batch native tests also compare
against full-device. Per-batch errors and total transfer/normal counts are checked.

Fresh Windows x64 Release configurations in build-cuda-hybrid (CUDA/OpenMP ON,
architecture 89), build-hybrid-cpu (CUDA OFF/OpenMP ON) and build-hybrid-serial
(both OFF), with testing ON/CPU tools OFF, passed 12/12, 10/10 and 9/9 final
CTests. Current test lists were captured rather than assuming counts. Initial
SDK access was sandbox-blocked; authorized SDK/toolchain builds succeeded.
The Windows PowerShell module path adjustment was process-only. Artificial
import/calendar regression fixtures ran; no historical-data workflow was repeated.

The regular hybrid executable checks 16 common-input/native-reference cases;
--scale-common checks 19 including N=100000/1000000/10000000. Small fixtures
check all eleven nearest ranks, signed/tied losses, negative VaR, zero horizon,
single/multiple/partial batches, odd/even sizes, batch > N, confidence limits,
invalid data in first/middle/final batches and recovery. CPU-only planning tests
cover overflow, synthetic device-budget rejection and host vector limits without
memory exhaustion. Maximum common-input difference over all cases was
2.8421709430404007e-14; each large-N case's maximum was
4.440892098500626e-16, below the project absolute tolerance 0.00001*V0 and the
retained stricter regression bound. Default native full-device synthetic smoke
matched the earlier e4ae788 record exactly, and CPU CUDA ON/OFF smoke agreed.

Forced multi-batch native scale checks used data/synthetic_prices.csv, seed 42,
one unit, 10 intervals and 252 observations/year. Requested batch 65535 became
native effective 65536: N=100000/1000000/10000000 used 2/16/153 batches.
Explicit device storage stayed 1048580 bytes, with zero CUB scratch; host loss
storage was 800000/8000000/80000000 bytes. Preflight snapshots showed
7451181056 free bytes and an 80% budget limit of 5960944844 bytes. Native H2D
was zero; D2H was 800008/8000064/80000612 bytes, including per-batch error flags.
Common scale checks used effective 65535, also forcing multiple/partial batches.

Evidence is under ignored results/cuda-hybrid-9fa1d27-working-20261019/;
final-checks/ contains final native records and hybrid-checks.json. manifest.json
binds the base SHA, dirty source hashes, build caches, binaries, synthetic input,
test lists/logs and resulting records. These allocation snapshots are not peaks.
Host time includes host/device allocation, all generation/transfers, global host
quantile, synchronization and temporary cleanup. Copy Events sum across batches
and remain separate diagnostics, with pageable staging covered by host time.

The existing clean-source recorder now supports -IncludeHybridChecks and
-HybridBatchSize, with -IncludeScaleChecks adding both hybrid native/common scale
checks. Its parser and native Sample/HybridSample helpers were exercised against
the built CLI; the complete clean-source workflow was not run on this uncommitted
source. A later checkpoint can run that workflow from its exact committed SHA.
No five-seed acceptance, sanitizer/memory-race checks, profiling, convergence or
formal benchmark was run. Actual host/GPU exhaustion and broken-driver cleanup
were not forced; thermal conditions are unmeasured. No academic material or
automation was created. Later acceptance and measurement remain separate work.

## Clean-source hybrid CUDA checkpoint: 2026-10-19

Reviewed the focused hybrid diff against the prior working-tree manifest; source,
binary and evidence hashes matched. Coverage, global host quantile, requested /
effective batches, final padding, independent native reference, checked memory,
cleanup/recovery, timing and default full-device/CPU-only behavior were inspected.
No source correction or unrelated change was required. Only the 18 cohesive
implementation/test/technical-document files were explicitly selected for the
source commit; private data/results, AGENTS.md and output/ were excluded.

Tested source commit: f03903402ddfb3bfc591dcb092dec73603448854 on main.
Source tree: ea1ddbf8852cf17d09b9d411561c585ce80d2b08. The tracked source was
clean throughout the complete recorder; only deliberately untracked AGENTS.md
and output/ remained. This outcome is recorded in a subsequent documentation-only
commit, which must not be called the locally RTX-tested source revision.

Invocation: scripts/run-cuda-skeleton.ps1 -OutputDirectory
results/cuda-hybrid-f039034-clean-20261019 -IncludeHybridChecks
-IncludeScaleChecks -HybridBatchSize 65535. It completed successfully from
2026-10-18T21:40:46.8011552Z through 2026-10-18T21:41:50.4340115Z (October 19
locally). Authorized execution outside the sandbox supplied Windows SDK/CUDA
access. The Windows PowerShell module path adjustment affected that process only.

All three Windows x64 Release configurations were rebuilt clean-first: CUDA /
OpenMP ON, architecture 89, passed 12/12; CUDA OFF / OpenMP ON passed 10/10; both
OFF passed 9/9. Current test registration was captured. Testing was ON and CPU
tools OFF; CPU-only configurations did not discover the Toolkit. CUB remained
300403. CPU synthetic smoke estimates matched exactly across CUDA ON/OFF builds.
Only artificial import/calendar fixtures ran; no historical-data work or completed
CPU performance campaign was repeated.

Separate native and common-input records cover N=100000/1000000/10000000.
Native uses the hand-written synthetic CSV, seed 42, one unit, ten observation
intervals and 252 observations/year. Requested batch 65535 produced effective
65536, with 2/16/153 batches. All N losses and N native normal outputs were
accounted for; H2D was zero and D2H bytes were 800008/8000064/80000612 including
per-batch error flags. Explicit device bytes stayed 1048580 and host loss bytes
were 800000/8000000/80000000. Each preflight observed 7451181056 free bytes and
an 80% limit of 5960944844 bytes. These are budgets/snapshots, not memory peaks.
Odd total-request padding and requested batch rounding are covered separately by
small native-reference tests; batch-size invariance remains unclaimed.

Hybrid checks passed 19 common-input/native-reference cases including scale and
edge/recovery cases. Maximum common-input difference was 2.8421709430404007e-14;
the three large-N cases each had maximum 4.440892098500626e-16, below the
0.00001*V0 project bound and retained stricter regression bound. Full-device
common-input checks remained separate (56 regression comparisons and 40 in the
scale executable). An independent audit compared full-device native results with
clean source e4ae78849d3a55baf08b21ccc86934d3ec0ed86a: model/calibration and both
VaR estimates matched exactly at N=10000/100000/1000000/10000000. This compares
the same native CUDA configuration; it does not assert CPU/GPU native equality.

Local evidence: results/cuda-hybrid-f039034-clean-20261019/. The recorder manifest
binds source SHA/tree, build caches, executable/test/runtime/input hashes and all
recorder outputs. A separate independent-audit.json rechecks those bindings,
CPU-only isolation, all-N transfer/normal accounting, budgets, case completeness
and the earlier full-device records. Prior evidence files remain unchanged.
Exact-byte SHA-256 values:

- manifest.json: 4352958e62f77d0b059d7362056fb66b09d6dcfae95cc352bcdd61d84149d9b8
- independent-audit.json: b91d0df65d4347d8bee42601f9bd30ac02dcab92502705d3b23a6ca96d632af3
- synthetic input: 8dbb7c73e6ad48cb8c8c175aff6684d2a0433e5f08424ec7ea1e69037bb36210
- CUDA CLI: e08a64ae46a1cefe56b593a33dec68413903b69b0196033b5f821ee7b34a9c76
- full-device test: 28f73147f142f723155399611fa00d41bb5826ab140c031945be29c559ae1f5c
- hybrid test: c365b928f2107d18431b8d0755f92409c361cf56421808483520d4478af5a8e0

Plan A's full-scale/memory/batching implementation is complete for this scoped
single-asset engine, including the explicitly selected hybrid fallback. This is
not full project acceptance. Five-seed analytical GPU acceptance, separate
sanitizer/memory-race checks, profiling/bandwidth reporting, convergence, formal
CPU/GPU benchmarking and later reproducibility/reporting remain separate work.
Host timing still includes allocation, RNG, all transfers, global quantile,
synchronization and cleanup; summed copy Events remain separate diagnostics.
No prohibited campaign, academic file or automation was created. Source and this
later documentation commit are to be pushed normally; hosted CPU CI must be
checked for the exact final pushed SHA and is separate from local RTX evidence.

## GPU acceptance recorder preparation: 2026-10-19

The next scoped task adds recording, independent numerical auditing and separate
Compute Sanitizer orchestration; see [gpu-acceptance.md](gpu-acceptance.md).
It preserves engines/RNG/quantile and reuses compatible f039034 large common-input
evidence. Focused corruption tests are registered in Windows CTest. The authorized
campaign is to bind a clean local source commit, ten native acceptance processes
and the separate representative sanitizer matrix. This preparation entry does
not claim acceptance or sanitizer success. No push is authorized in this task.

## GPU analytical acceptance and representative sanitizer checks: 2026-10-19

Tested clean source: 8df5f28b877b15d0d2b513b8e8786e41d4af7c05; source tree:
8b8dbdb14a952fa808c29d2d9a938b88b941edf7. The complete recorder ran from
2026-10-18T22:23:07.0645698Z through 2026-10-18T22:30:38.6026727Z. HEAD and
the tracked source remained unchanged during execution; only untracked AGENTS.md
and output/ were excluded. The subsequent result-documentation commit is not
the RTX-tested source revision. All task commits remain local; no push or new
hosted CI result is claimed.

Recording support was added in 0807400e73b64e73b79b70d80ad30b4fb13dd181.
Two concrete recording defects were fixed in separate commits: d40c6ec corrected
culture-sensitive/non-round-trip CSV numbers; 8df5f28 corrected PowerShell 5.1
Decimal confidence grouping and JSON array enumeration. The earlier incomplete
attempts are preserved under results/gpu-acceptance-0807400-20261019/ and
results/gpu-acceptance-d40c6ec-20261019/, including interruption.json records.
The first stopped before native acceptance; the second retained all ten native
attempts and its completed/partial sanitizer records but produced an empty
acceptance summary. Neither is presented as a completed campaign. Development
attachment/option probes also remain separately labeled under results/.
No engine, RNG, quantile, CPU numerical behavior or acceptance threshold changed.

New separate Windows x64 Release builds used VS 2022/MSVC 19.44.35227.0,
nvcc 13.4.92, architecture 89, CUB 300403 and existing --fmad=false and
/Zc:preprocessor flags. Actual discovery and CTest results: CUDA/OpenMP 13/13,
CUDA OFF/OpenMP ON 11/11, serial-only 10/10, separate -lineinfo CUDA build 13/13.
The added recorder/auditor contract passes 57 positive/corrupted-record checks,
including actual JSON Decimal spelling, array reading, tr-TR CSV round-trip,
source/input/build/model/batch changes, duplicate/missing seeds, nonfinite values,
incorrect summaries, failed processes and unexplained sanitizer diagnostics.
CPU-only caches did not discover the Toolkit.

Ten fresh native CLI processes used the exact synthetic CSV bytes (SHA-256
8dbb7c73e6ad48cb8c8c175aff6684d2a0433e5f08424ec7ea1e69037bb36210), one unit,
10/252 years, N=10000000, seeds 42/123/456/789/2026 and confidence .95/.99.
Hybrid requested batch 65535, effective 65536, 153 batches was checked separately
from full-device. All per-seed results, raw stdout/stderr, exit codes, JSONL and
CSV are retained. These are acceptance observations, not benchmark samples.

The independent auditor recalibrated the CSV and recomputed analytical references
without calling engine code. The following rows use that independent reference;
its exp-based arithmetic differs from application expm1 by about 3e-14, within
the separately documented rounding check, without changing project acceptance.

| Mode | Confidence | Five-seed mean | Independent analytical VaR | Absolute error of mean | Allowed error | Outcome |
| --- | --- | --- | --- | --- | --- | --- |
| full-device | 0.95 | 6.1433827450657184 | 6.14357693941893 | 0.00019419435321132994 | 0.0614357693941893 | Pass |
| full-device | 0.99 | 8.713878291342505 | 8.7154467162009155 | 0.0015684248584104665 | 0.087154467162009155 | Pass |
| hybrid | 0.95 | 6.1433827450657184 | 6.14357693941893 | 0.00019419435321132994 | 0.0614357693941893 | Pass |
| hybrid | 0.99 | 8.713878291342505 | 8.7154467162009155 | 0.0015684248584104665 | 0.087154467162009155 | Pass |

The criterion remains abs(mean(VaR)-analytical) <= .01*max(abs(analytical),.01*V0),
separately per mode/confidence. Matching observed native means across these two
partitions does not establish batch-size invariance or native CPU/GPU equality.
Existing f039034 large-N common-input evidence was reused after source
compatibility, pinned manifest/audit hashes and every original record hash were
verified. That campaign was not repeated; its absolute .00001*V0 bound remains.

Compute Sanitizer 2026.3.0.0 build 38855100 attached successfully on RTX 4060
Laptop, driver 610.88, SM 8.9. The separate native N=1 attachment pilot and all
44 matrix invocations passed: memcheck 12, initcheck 12, synccheck 10, racecheck 10.
Every target and tool exit status was zero; exact clean summaries were checked.
Both CUDA test executables ran under every tool. Both native modes ran at
N=65535/65536/65537/131073; memcheck/initcheck additionally ran at N=1000000.
Hybrid always requested 65535. Memcheck ran first, with leak checking/padding;
initcheck covered global/shared memory. No filters, suppressions, forced blocking
launches, TDR/registry changes or profiling were used.

This is representative dynamic memory/concurrency evidence, not sanitizer-at-
10-million coverage or proof of all global-memory race freedom. Racecheck covers
shared-memory hazards; CPU host-buffer accesses/leaks outside CUDA APIs remain
outside coverage. Source reasoning about per-index writers, atomics, stream
ordering, copy completion/reuse, host-buffer lifetime and RAII is recorded
separately in gpu-acceptance.md and sanitizer-coverage.json.

Evidence: results/gpu-acceptance-8df5f28-20261019/. The separate independent audit
passed numerical, source/build/fixture/record provenance, common-input reuse and
all sanitizer outcome/invocation checks. The manifest binds 474 output files and
44 source/build/runtime/tool artifacts. Exact-byte SHA-256:

- manifest.json: 662282694ce64120baa666c424d2920efb440123753c50f9557a67b6ce074111
- independent-audit.json: ca69dae55186b0efe9a766e5d7aea6bf692850378db3c285d6350a1317f7768e
- acceptance.json: c43193c4064d34e5ef78f5aeab2dcad116c96d58c8337530d99c5d25646bf135
- sanitizer-results.json: ae1c9b6577474d3f4f014788d764876d8773a71dbd8c1d6fcf7dc706e37c696f

Formal profiling/bandwidth reporting, CPU/GPU performance benchmarking,
convergence and final reproducibility/reporting remain separate project work.
Academic submission and live demonstration are not established as completed.
No historical-data campaign, academic document, automation or public upload was
created. Private data, AGENTS.md, output/ and historical evidence were preserved.
