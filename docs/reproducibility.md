# Technical reproducibility entry point

This package separates a new software build, selected historical evidence
integrity, original raw execution provenance and offline derived figures.
It does not reproduce machine timing, acquire provider prices, install packages
or establish academic submission/live-demo completion. See the
[requirements audit](requirements-audit.md) and [local trial record](../evidence/v030-reproducibility-20261020/README.md).
Run commands from the actual repository root. Use a normal full-history Git
clone of https://github.com/rahmancelik74-cmd/vaR-hpc; do not combine old source
trees or rewrite recorded absolute paths. A shallow checkout needs its history
restored before historical Git checks. No check silently uses a replacement binary.

## 1. Build and check current software

Prerequisites: Git, CMake >=3.18, C++17 compiler, CTest; an OpenMP-capable compiler
for the ON configuration. Windows also requires PowerShell 5.1, VS 2022 C++
tools and a Windows SDK. The local reference is CMake 3.31.6-msvc6, MSVC
19.44.35227.0, Windows SDK 10.0.26100.0. Python 3.11.4 was used for offline
checks; they use only its standard library unless figures are requested.
Use an existing Python executable in place of `python` if it is not on PATH.
Commands must return zero; stop at a nonzero status and retain its logs. In
PowerShell inspect `$LASTEXITCODE` after each native command. Existing build
directories are not clean-build evidence; choose new names for another trial.

Windows x64 Release, CUDA explicitly OFF (no Toolkit discovery needed):

```powershell
git status --short
git rev-parse HEAD
cmake -S . -B build-repro-on -G "Visual Studio 17 2022" -A x64 -DMC_ENABLE_OPENMP=ON -DMC_ENABLE_CUDA=OFF -DMC_BUILD_CPU_TOOLS=OFF -DBUILD_TESTING=ON
cmake --build build-repro-on --config Release --parallel
ctest --test-dir build-repro-on -C Release --show-only=json-v1
ctest --test-dir build-repro-on -C Release --output-on-failure
cmake -S . -B build-repro-off -G "Visual Studio 17 2022" -A x64 -DMC_ENABLE_OPENMP=OFF -DMC_ENABLE_CUDA=OFF -DMC_BUILD_CPU_TOOLS=OFF -DBUILD_TESTING=ON
cmake --build build-repro-off --config Release --parallel
ctest --test-dir build-repro-off -C Release --show-only=json-v1
ctest --test-dir build-repro-off -C Release --output-on-failure
python -B -m unittest discover -s tests -p "test_*.py" -v
```

Linux equivalent: omit `-G ... -A x64`, add `-DCMAKE_BUILD_TYPE=Release` to
each configure and retain explicit ON/OFF/CUDA OFF options. The Windows-only
PowerShell recorder tests are not registered there. Discover tests rather than
assuming platform-independent counts. Expected results are all discovered tests
passing, not any particular timing. CPU CTests exercise small synthetic software
cases; they are not a new acceptance, convergence or benchmark campaign.
`MC_BUILD_CPU_TOOLS=ON` is an additional Windows/OpenMP instrumentation build;
it is not required for these two portable engine builds.

## 2. Check selected public historical evidence

```text
python -B scripts/check-reproducibility.py
```

This read-only standard-library entry point verifies the primary benchmark,
stage-diagnostic and version-2 figure selected-file inventories against their
unchanged Git snapshot at b9745be08a477b3648afc8499b07fb2ae4aec165. It then
checks every selected artifact's exact bytes and the figure parent manifests.
Five release-content entries are checked against commit 35338cd, not against
later current documentation. Output is JSON with `status: passed`, individual
artifact counts and `scope: selected-public-artifact-integrity`. A missing file,
changed numerical CSV, edited old inventory, missing Git history or invalid
path fails explicitly with exit 1. This proves selected-file integrity, not
full raw-session availability, source-to-binary equivalence or renewed statistics.
The public fixture `data/synthetic_prices.csv` is hand-written test data;
benchmark/stage `fixture.csv` copies are also synthetic. No provider input is
needed for CPU regressions or synthetic convergence figures.
data/.gitattributes preserves this fixture's recorded LF bytes across Git
autocrlf settings. Its SHA-256 remains
8dbb7c73e6ad48cb8c8c175aff6684d2a0433e5f08424ec7ea1e69037bb36210;
no input value or historical hash was changed.

## 3. Recalculate selected convergence statistics with local archive bindings

```text
python -B scripts/check-reproducibility.py --local-convergence
```

This calls the unchanged version-2 independent validator: calibration from
fixture log returns/sample variance, analytical references, 160 seed values,
32 complete groups, normalization, MAE/RMSE/sample SD and eight separate 10M
error-of-mean acceptance rows. It also verifies the 22 original delivery
entries. Two historical documents use exact raw snapshots plus content at
390ffa670960f83a0de4fb0b9cd595cb03cdbc8e; the other bindings remain strict.
This path requires the original ignored convergence recorder/tool captures
listed in delivery-manifest.json. Missing local artifacts fail with an action
to restore their exact hash-bound archive. No private download or new executable
can replace them. Current status documents are not numerical dependencies.

For deeper original-attempt/build/reuse provenance, use the existing PowerShell
auditor functions read-only, retaining a new report rather than running a writer
over its original independent-audit.json:

```powershell
. ./scripts/convergence-audit.ps1
$d = Read-GpuJson 'results/convergence-b5f1a0f-20261020-run1/dataset.json'
Test-ConvergenceDataset $d
$p = Read-GpuJson $d.plan_path
Test-ConvergencePlan $p
$f = Get-IndependentGpuFixture $p.fixture.path
Test-ConvergenceRecords $p @($d.records) $f
Test-ConvergenceAttemptInventory 'results/convergence-b5f1a0f-20261020-run1' @($d.records)
$a = Get-IndependentConvergenceAnalysis @($d.records) $f
Test-ConvergenceAnalysis (Read-GpuJson 'results/convergence-b5f1a0f-20261020-run1/analysis.json') $a
```

The exact plan includes original serial/OpenMP manifests, executable hashes,
GPU source/build revisions, source-diff compatibility and historical local
artifacts. Only the explicitly recorded old repository prefix can relocate to
the current root. Missing artifacts are not searched for in arbitrary trees.
Original benchmark `review.ps1` and stage `verify.ps1` entry points, documented
in their evidence READMEs, similarly require their complete ignored archives
and historical builds; these selected public packages are not full raw exports.

Important original local dependencies include build-foundation (serial binary
and cache), build-openmp (binary; no independent published cache),
build-cuda-skeleton and results/cuda-hybrid-f039034-clean-20261019,
build-gpu-8df5f28-edcf3e-cuda and results/gpu-acceptance-8df5f28-20261019,
and build-convergence-b5f1a0f-5c4032. The plan and native-run manifest, not these
directory names alone, define the required bytes. Benchmark raw evidence is
results/benchmark-formal-89536e3-20261019-run2 (and preserved run1 failure);
stage evidence is results/cuda-stage-diagnostics-80148ce-20261019-run2.
The current PowerShell old-root resolver derives its former prefix from
USERPROFILE: a different account/layout is not a generally supported relocation.
Such a local full-archive audit may fail explicitly on another machine, even
when public integrity and CPU builds work. Do not rewrite old paths or weaken
hashes to pass it. Python figure validation resolves its recorded root separately.

## 4. Regenerate derived figures without starting an engine

Prerequisites: complete section-3 local bindings, Git history, existing Python
with Matplotlib (reference 3.7.1) and Pillow (reference installed 9.4.0).
No installation is implied. Choose a new ignored output directory:

```text
python -B evidence/v030-convergence-figures-20261020-v2/convergence_figures.py --repository . --output results/repro-figures-new
```

Expected: `status: passed`, 160 values, 32 groups, eight acceptance rows, four
PNG/SVG figure families, combined four-page PDF, plotted-data.json,
verification.json and a new figure-manifest.json. Existing output directories
are rejected. Compare exact plotted values with the selected validated package
using this standard-library snippet (PowerShell):

```powershell
@'
import json
from pathlib import Path
read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))
assert read('results/repro-figures-new/plotted-data.json') == read('evidence/v030-convergence-figures-20261020-v2/plotted-data.json')
print('Exact plotted data matches: 96 curve points, 160 signed seed points, 8 acceptance rows')
'@ | python -B -
```

PDF/SVG metadata and IDs may vary; raw graphics hash equality is not the data
criterion. Previous visual review is retained, not silently repeated. With
unchanged plotting code/selected figures and verified hashes, no new PDF render
is needed. New plotting changes require new visual QA. Zero-log markers never
replace raw zeros with epsilon; MAE/SD are descriptive and do not replace the
separate error-of-mean criterion. Original version 1 and failed checks remain.
Its fixed-local-path verify-plotted-data.py is a historical audit artifact;
use the comparison above for a new output location.

## Historical source/build and environment boundary

| Purpose | Exact source / dependency | Limit |
| --- | --- | --- |
| Serial reuse | 33102c48b9251beb6317969ffb7edc03abe773b4; evidence/v022-validation-20261016 | source-to-binary verification=false remains |
| OpenMP reuse | 05f982effc570366597fc5f13f8b3a0440b293a8; four-thread records | No published independent standalone CMakeCache; manifest/settings/log/binary bindings remain |
| GPU common-input/smaller N | f03903402ddfb3bfc591dcb092dec73603448854 | Native seeds are not common samples |
| GPU acceptance | 8df5f28b877b15d0d2b513b8e8786e41d4af7c05; original acceptance build/raw archive | Representative sanitizer coverage only |
| Formal primary benchmark | 89536e38b01230fce3b4667096c29dde56795c23 | Original executable/cache/DLLs/telemetry and raw logs stay local |
| Stage diagnostics | 80148cee0ba5a52b1c67ca98a6ad4eb91e4d7817 | Instrumented times do not replace primary timings |
| 25 missing GPU convergence runs | b5f1a0f5b72bca8f1f21555236d938501f7faee8 | Reused 55 records retain their distinct earlier builds |
| Numerical publication | 390ffa670960f83a0de4fb0b9cd595cb03cdbc8e | Historical raw document snapshots preserved |
| Figure closure | 35338cdc462aea88b37ed07a7d2b759138480f96 | Version 2 separates historical/current documentation |

CUDA rebuild capability additionally needs supported NVIDIA GPU/driver, nvcc,
CUDA runtime/cuRAND and CUB. The recorded machine used RTX4060 Laptop sm_89,
CUDA 13.4 / nvcc 13.4.92, CUB 3.4.3 (300403), VS2022 x64 Release,
`--fmad=false` and `/Zc:preprocessor`. Explicit configure options were
`-DMC_ENABLE_CUDA=ON -DMC_ENABLE_OPENMP=ON -DMC_BUILD_CPU_TOOLS=OFF
-DBUILD_TESTING=ON -DCMAKE_CUDA_ARCHITECTURES=89 -T cuda=13.4` with the VS2022
x64 generator. DLL selection/hashes and API/header discrepancy are recorded in
environment.md and each original manifest. A later tool/library/GPU combination
needs its own validation; recompilation cannot establish historical binary
identity. No CUDA rebuild or execution is required by this package trial.
CUDA remains default OFF; unavailable backend selection fails explicitly.

Private MSFT inputs under data/local and provider correspondence outside Git
are not distributed. Historical integration cannot be rerun from this checkout
alone: an authorized holder needs the exact original raw/converted CSV,
metadata and session-calendar inputs plus applicable rights. Missing file errors
require restoring those approved artifacts, not downloading a substitute series
or treating synthetic data as historical prices. See historical-data.md and
data-rights-and-calendar.md; rights do not permit raw redistribution.

Current limitations: 10x serial target unmet (9.739930524x); full-device versus
best OpenMP 8.307208722x; hybrid at 10M did not beat best OpenMP. Counter access
still returns ERR_NVGPUCTRPERM; exact-laptop peak, measured DRAM GB/s and its
percentage remain open. No new-machine trial, market predictive validity,
general race freedom, academic delivery or live-demo completion is claimed.

[The bandwidth follow-up](../evidence/v030-bandwidth-followup-20261020/README.md)
rechecks access and official source applicability separately. Administrator
counter access is needed for measured DRAM GB/s; an applicable documented peak
is needed for percentage of peak, not for measured GB/s itself. These diagnostic
records do not replace the historical primary benchmark or require its rerun.
