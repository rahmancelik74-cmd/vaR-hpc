# Project state

Updated: 2026-10-15, Europe/Istanbul. Current source version: 0.2.2. Windows Release tests and smoke verified.
This dated ledger supersedes stale progress labels in initial snapshot documents.
It does not replace the supervisor's roadmap or the requirements document.

## Current agreement

Plan A is the agreed complete project. Plan B is an optional extension if
first-term delivery leaves enough capacity; it is not a fallback for failure.
Scope or schedule reductions are discussed with the supervisor. Do not quietly
drop the CUDA skeleton, validation or measurement requirements.

Explanations to the student are in Turkish. New code, identifiers, comments,
scripts and program messages use English and ASCII. Project tracking files in
this update use English as well.

## Evidence already obtained

- Windows x64 Release configuration and build succeeded in build-foundation
  with Visual Studio 2022 / MSVC 19.44.35227.0. All three CTest tests passed.
  Evidence: evidence/windows-release-ctest-20261015.log, commit 48429b5.
- The authoritative local source folder is graduation_project/gpu-montecarlo-starter.
  Git main baseline: adb49bc. The student reported a clean working tree after
  48429b5. No remote repository or successful hosted CI run is established.
- CSV input, log-return calibration, analytical GBM reference and the serial
  engine are implemented. The sample data is hand-written synthetic data.
- Statistical runs cover four scenario counts, five seeds, two confidence
  levels: 20 runs and 40 VaR estimates. The evidence CSV transcribes pasted
  terminal results; it is not an exact export of the student's original log.
- CUDA nvcc 13.4 V13.4.92 works on the student's machine. No GPU execution
  or device quantile result has been demonstrated.
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
| One authoritative local folder / Git | Verified; main branch, clean after commit 48429b5 | Baseline adb49bc; Windows test evidence committed in 48429b5 |
| Requirements and Design Document | Draft, not delivered v1.0 | At most eight pages, numbered requirements and checked conventions |
| Proposal source | Revised file located; supervisor-approved identity unconfirmed | Student identifies submitted/approved version |
| Core timing / data contract | Recorded in architecture baseline | Review against numbered requirements |
| Data provenance | Synthetic fixture only | Real source, ticker/range, reuse/adjustment policy and checksum |
| Metadata / structured result export | v0.2.2 candidate: JSON output and PowerShell runner implemented | Four Windows CTest tests and smoke passed; evidence/v022-smoke-20261015 |
| OpenMP | Not implemented | Common-input cross-check, RNG design and thread scaling |
| CI | Workflow file exists; remote execution unverified | Actual CI result when a remote repository is chosen |
| CUDA path | Compiler available; execution unverified | Device run, then required end-to-end skeleton |
| Formal benchmark | Not run | Three warm-ups, ten timed repetitions and complete metadata |

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

## v0.2.2 candidate

Adds structured JSON output and a serial experiment runner with distinct smoke,
validation and benchmark modes. Windows Release build, all four CTest tests and the serial smoke run passed. Evidence is archived in evidence/v022-smoke-20261015. The older three-test record applies to v0.2.1.
No new OpenMP, CUDA, formal benchmark or supervisor acceptance is claimed.

## Automated serial validation: 2026-10-16

Completed against clean revision 33102c4 using v0.2.2.
Four scenario counts, five seeds, 20 runs and 40 VaR estimates.
CSV and JSONL values agree; manifest configuration was checked.
Evidence: evidence/v022-validation-20261016.
At N=10000000, both confidence levels satisfy the candidate aggregate
error condition for this synthetic case. Approved proposal identity
remains pending. This campaign is not a performance benchmark.
