# Native convergence recording and independent verification

This is preparation, not a completed convergence campaign. No new simulation
was run in this task. The bound reuse plan imports 55 native observations (110
VaR values) and explicitly retains 25 missing processes (50 values). The full
contract is 80 engine/mode-N-seed observations and 160 values. Each observation
contains alpha .95 and .99. Benchmark repeats, warm-ups, common inputs,
connectivity results, diagnostic repetitions and sanitizer outputs are excluded.

The model is the existing synthetic CSV, one unit, double precision, T=10/252,
exact terminal GBM, loss V0-VT and ascending nearest-rank ceil(alpha*N)-1.
Negative VaR is retained. No engine, RNG, quantile or CPU behavior was changed.

## Bound reuse and missing configurations

The machine-readable [plan](../evidence/v030-convergence-preparation-20261019/plan.json)
binds each selected JSON artifact and JSONL line by exact-byte SHA-256, source
revision/tree, manifest, executable and available build evidence. It also binds
the exact reviewed Git diffs and documents compatibility reasoning. Original
evidence remains in place. Paths under results/ and archived build directories
are local dependencies, not files distributed by a Git checkout.

| Engine/mode | Existing counts at N=10K / 100K / 1M / 10M | Source |
| --- | --- | --- |
| Serial | 5 / 5 / 5 / 5 | 33102c48b9251beb6317969ffb7edc03abe773b4 |
| OpenMP, requested/actual 4 threads | 5 / 5 / 5 / 5 | 05f982effc570366597fc5f13f8b3a0440b293a8 |
| CUDA full-device | 1 / 1 / 1 / 5 | f03903402ddfb3bfc591dcb092dec73603448854; 8df5f28 at 10M |
| CUDA hybrid | 0 / 1 / 1 / 5 | f03903402ddfb3bfc591dcb092dec73603448854; 8df5f28 at 10M |

All singleton GPU observations use seed 42, once each. Complete groups use
seeds 42,123,456,789,2026. Both GPU 10M groups use source
8df5f28b877b15d0d2b513b8e8786e41d4af7c05.

| Mode | N | Missing seeds | Processes | Requested/effective batch | Batch count |
| --- | --- | --- | --- | --- | --- |
| full-device | 10000 | 123,456,789,2026 | 4 | 0/10000 | 1 |
| full-device | 100000 | 123,456,789,2026 | 4 | 0/100000 | 1 |
| full-device | 1000000 | 123,456,789,2026 | 4 | 0/1000000 | 1 |
| hybrid | 10000 | 42,123,456,789,2026 | 5 | 65535/10000 | 1 |
| hybrid | 100000 | 123,456,789,2026 | 4 | 65535/65536 | 2 |
| hybrid | 1000000 | 123,456,789,2026 | 4 | 65535/65536 | 16 |

The existing hybrid 10M records request 65535, use 65536 and 153 batches.
Metadata is checked against this native contract; it is never coerced. The
batch cap at N and even rounding follow include/mc/detail/cuda_plan.hpp.
Native equal seeds do not imply equal samples across modes/backends, and call
partition is part of the CUDA RNG configuration.

Historical serial manifest explicitly sets executable_source_commit_verified
to false. The archived executable hash matches; unchanged core/data sources and
matching later seed-42 observations do not remove that limitation. OpenMP has
four actual threads; its manifest, build settings/logs, original hash inventory
and archived executable are bound. No standalone CMakeCache was published with
that correctness evidence, so its plan cache hash is null, not invented.
The relevant OpenMP implementation is unchanged. f039034 and 8df5f28 have no
src/include/fixture differences. Later CUDA changes add optional diagnostics,
with the reviewed diffs retained in the plan. Reuse spans builds and revisions;
this is not one fresh common-build campaign. Source/header metadata additions
are distinguished from unchanged numerical CPU implementations.

## Commands and outputs

Use Windows PowerShell 5.1 or later from the repository root. No dependencies
are installed. Default recording is import-only:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run-convergence.ps1 -Plan evidence/v030-convergence-preparation-20261019/plan.json -OutputDirectory results/convergence-new-import
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/analyze-convergence.ps1 -Directory results/convergence-new-import
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-convergence.ps1 -Directory results/convergence-new-import
```

The output directory must be new and under ignored results/. dataset.json binds
the plan and full per-record provenance/result and explicitly labels coverage.
analysis.json retains per-seed values/errors, all 32 engine-N-alpha groups,
the missing matrix and eight separate 10M acceptance rows. independent-audit.json
binds plan/dataset/analysis hashes and reports verification separately from
completeness. JSON uses invariant number serialization and binary64 values;
there is no rounded CSV serving as an authoritative input. Existing exact-byte
hash, UTF-8 and redirected process capture helpers are reused.

Only a later separately authorized task may use -ExecuteMissing. That switch
requires a clean committed tree (only untracked AGENTS.md/output/ excluded),
unchanged reviewed src/include/fixture, a fresh unique Windows x64 Release CUDA
build with OpenMP, architecture 89, Toolkit 13.4 and diagnostics OFF. The recorder
captures configure/build processes, cache, executable, runtime DLLs, scripts,
fixture and source SHA/tree; it does not install tools or run benchmarks.
It executes the missing keys once in fixed grid order, with a fresh process and
CUDA context each. Each attempt is written before launch; raw stdout/stderr,
argv, exit/timeout/start error and immutable artifact bindings remain afterward.
Malformed output, nonzero exits, diagnostics or changed bindings stop execution.
Failed attempts never enter the dataset. Session status and partial coverage
remain explicit. Build failures retain their session and process logs.

Use -PreviousDirectory with a retained prior dataset to import its validated
successes and retain references to all prior attempts, including failures. Only
still-missing keys are attempted in the new directory. Successful duplicate
keys, omitted reusable records, unlisted attempts, changed files and incompatible
bindings fail validation. An interrupted attempt with an inconsistent inventory
requires review; it is not silently counted or overwritten. Clean-source
checkpointing and the actual missing GPU runs were not authorized here.

## Statistics and acceptance

The analyzer recalibrates the CSV using Welford sample variance. The independent
verifier uses the existing separately implemented two-pass log-return calibration
and fixed binary64 lower normal quantiles, then independently calculates all
statistics using explicit sums and two-pass seed sample variance. Neither uses
engine calibration/reference fields as authoritative inputs. Original fields
are checked within 2e-12*max(1,abs(expected)), a rounding-only tolerance.

Per seed, record raw VaR, signed error, absolute error, absolute relative error
and signed error/V0. Per group, record mean VaR, signed/absolute error of the
mean and sample standard deviation (n-1). MAE and RMSE are descriptive only.
Singleton standard deviation is null; empty statistics are null. Partial group
statistics remain labeled incomplete with the actual seed count.

Relative error divides absolute error by abs(analytical reference). When
abs(reference)<.01*V0, it is null with an explicit N/A status; error/V0 remains
available. Raw zeros and negative values are preserved. The 10M acceptance is
calculated only for five complete seeds, separately per engine/mode and alpha:

```text
abs(mean(VaR)-analytical_VaR) <= .01*max(abs(analytical_VaR),.01*V0)
```

Incomplete 10M groups have passed=null. MAE, RMSE and individual seed errors
cannot substitute for this calculation. No monotonically decreasing error,
universal guarantee, predictive market validity or fitted rate is inferred.

The plan records a figure specification only: error of mean versus N, seed
signed errors and seed standard deviation; log N; positive absolute errors on
log axes; labeled separate zero-error markers without epsilon substitution.
Partial groups must display seed counts. No figure was produced.

## Focused verification

tests/test_convergence_statistics.ps1 is a portable fixture-only test registered
as convergence_statistics_contract in Windows CTest; it needs no archived
results, executable or GPU. tests/test_convergence.ps1 additionally requires the
local pinned historical artifacts and exercises import bindings and mocked
recording. Mock results are synthetic test data under ignored results/, never
convergence observations. It checks corrupt bytes, source/build/input/model
changes, duplicate/missing seeds, modes/batches, nonfinite values, wrong
statistics, cancellation, negative VaR, near-zero normalization, false coverage,
acceptance substitution, exact missing execution, no rerun, failures and resume.

See the [preparation evidence](../evidence/v030-convergence-preparation-20261019/README.md)
for exact outcomes and local result paths. Engine campaigns, performance,
profiling, bandwidth and academic deliverables remain separate.

## Clean-source execution gate and relocation, 2026-10-20

The separately authorized checkpoint/run task now adds a mandatory preflight:
actual CTest JSON discovery, all discovered Release regressions and the local
focused convergence tests must pass before any missing native GPU observation.
Their process records and raw logs are bound with the fresh build artifacts.
The independent attempt verifier also requires raw stdout/stderr/process entries
and rechecks the preflight count and successful logs. This gate is separate
from the 25 native convergence processes, not a timing campaign.

The repository moved from the recorded OneDrive location to the current
repository root. convergence-paths.ps1 resolves only descendants of that exact
former root to matching descendants of the current root, rejects traversal,
requires the file to exist and retains the recorded path in raw JSON. Hash
verification still uses the exact original bytes. The audit lists each resolved
path explicitly. No historical manifest, executable, cache or process record is
rewritten, and no unrelated location is searched as a fallback. The original
plan remains byte-for-byte unchanged and its evidence directory disables Git
newline conversion so a clean checkout can retain its exact-byte hash.

The earlier preparation snapshots and verification.json describe their original
uncommitted implementation. Later fixes have separate review and execution
records; old source hashes are not relabeled as hashes of the fixed source.

## Completed fixed-fixture checkpoint, 2026-10-20

The separately authorized clean-source run at
b5f1a0f5b72bca8f1f21555236d938501f7faee8 completed exactly the 25 missing GPU
observations after 16/16 Release CTests and 87 focused checks passed. The merged
80-run/160-value dataset and all statistics passed two independent audits.
The preparation and missing-matrix descriptions above remain dated history;
the selected complete data and numerical findings are in
[evidence/v030-convergence-windows-20261020](../evidence/v030-convergence-windows-20261020/README.md).
No figure, additional campaign, optimization, profiler or push was performed.
Historical provenance limitations remain unchanged. A clean-source execution
must continue to reject duplicate or already-covered configurations.
