# Project state

Updated: 2026-10-16, Europe/Istanbul. Current source version: 0.3.0.
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
| Proposal source | Student confirmed Capstone_Project_Proposal_Form_Revised.docx as the approved file on 2026-10-16 | Reconcile the older candidate wording in acceptance-source.md when updating that register |
| Core timing / data contract | Recorded in architecture baseline | Review against numbered requirements |
| Data provenance | Offline importer and artificial-fixture checks available; genuine MSFT acquisition/policy blocked | Provider CSV for 2023-01-01 through 2025-12-31 plus verified Close adjustment and local reuse policy; see historical-data.md |
| Metadata / structured result export | v0.3.0 retains schema 1 and adds requested/actual threads and OpenMP version; existing recorder remains serial-only | Preserve v0.2.2 evidence; use the separate OpenMP correctness recorder |
| OpenMP | Correctness and fresh serial/OpenMP scaling baseline verified | Preserve baseline limitations; sorting remains serial; later full CPU/GPU campaign pending |
| CI | CUDA-disabled Ubuntu ON/OFF and Windows CPU recorder smoke passed at 8951236; run 38934437451 | Keep all three CPU jobs passing; GPU evidence remains local RTX execution |
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
