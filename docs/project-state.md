# Project state

Updated: 2026-10-18, Europe/Istanbul. Current source version: 0.3.0.
Windows Release tests, CPU correctness/scaling records, the CUDA walking
skeleton on RTX 4060 and hosted CPU CI are verified. Full-scale CUDA is pending.
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
| OpenMP | Correctness and fresh serial/OpenMP scaling baseline verified | Preserve baseline limitations; sorting remains serial; later full CPU/GPU campaign pending |
| CI | CUDA-disabled Ubuntu ON/OFF and Windows CPU recorder smoke passed at 8e3a7e1; run 39161829944 | Keep tested revisions distinct; GPU evidence remains local RTX execution |
| CUDA path | Capped walking skeleton verified on RTX 4060; cuRAND and CUB device quantiles through Engine | Later full-scale memory/batching and validation; no full-scale acceptance or benchmark yet |
| Benchmark | Fresh serial and OpenMP CPU scaling archived from clean aa901a3; 180 measured processes and 54 excluded warm-ups | Later CPU/GPU comparison; package temperature/fan/power instrumentation remains unavailable in this recorder |

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
