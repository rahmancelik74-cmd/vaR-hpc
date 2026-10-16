# Project state

Updated: 2026-10-16, Europe/Istanbul. Current source version: 0.2.2.
Windows Release tests, serial validation/benchmark records, standalone CUDA
execution and hosted CPU CI are verified.
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
  reported VRAM: 8187 MiB. No Monte Carlo CUDA engine, cuRAND pipeline or
  device quantile result has yet been demonstrated.
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
| One authoritative local folder / Git | Verified; main synchronized with origin/main, clean after 31fe206 | Continue in the existing repository |
| Requirements and Design Document | Draft, not delivered v1.0 | At most eight pages, numbered requirements and checked conventions |
| Proposal source | Student confirmed Capstone_Project_Proposal_Form_Revised.docx as the approved file on 2026-10-16 | Reconcile the older candidate wording in acceptance-source.md when updating that register |
| Core timing / data contract | Recorded in architecture baseline | Review against numbered requirements |
| Data provenance | Synthetic fixture only | Real source, ticker/range, reuse/adjustment policy and checksum |
| Metadata / structured result export | v0.2.2 JSON output and PowerShell runner verified | Preserve the existing four-test, smoke and campaign evidence |
| OpenMP | Not implemented | Common-input cross-check, RNG design and thread scaling |
| CI | Hosted Ubuntu CPU build/test passed; checkout@v6, latest reported run after 31fe206 | Keep CI passing for subsequent changes |
| CUDA path | Compiler and standalone GPU execution verified | cuRAND/device quantile and the required end-to-end skeleton |
| Benchmark | Serial campaign archived and statistics verified; full cross-engine comparison pending | OpenMP/CUDA measurements and complete power/thermal/placement metadata |

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
CMake generator and remaining settings. The next implementation task is the
OpenMP backend through the existing Engine contract, with common-input
validation before thread scaling. This advances work from the weeks 10-11
block without marking unfinished earlier milestones as complete.
