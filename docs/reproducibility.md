# Technical reproducibility entry point

Portfolio hybrid CUDA has a separate [contract and local reproduction commands](portfolio-hybrid.md).
Its [PH-1 evidence](../evidence/portfolio-hybrid-20261026/README.md) is separate
from hosted CPU CI, prior reference studies and private historical outputs.

Historical portfolio calibration is documented separately in
[portfolio-calibration.md](portfolio-calibration.md). Its Python >=3.11 synthetic
tests run offline without provider data; private original-byte auditing and local
CUDA integration are separate from hosted CI. No historical download is added
to the checks below.

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
best OpenMP 8.307208722x; hybrid at 10M did not beat best OpenMP. The new
[DRAM baseline](../evidence/v030-dram-baseline-20261020/README.md) verifies counter
access and kernel-scope rates for two N=10M profiles. The current
[acceptance interpretation](acceptance-source.md#documented-peak-interpretation-audit-2026-10-21)
records bandwidth reporting as satisfied using the documented NVIDIA App
configuration reference; no separately published applicable OEM specification
was located, and obtaining one is optional corroboration. Profiled timings do not
replace formal results. Historical denied-access records remain unchanged.
A remote hosted CPU trial is recorded below. It does not establish a second
Windows/CUDA laptop trial, market predictive validity, general race freedom,
academic delivery or live-demo completion.

## Isolated public portability check, 2026-10-20

At inspection SHA 663fcc3086c1d752cb2f18218cf73ca188832847, a full-history
local clone with --no-hardlinks was made under ignored results/, with spaces
in both checkout and new build paths. Only tracked files and Git history were
copied; no original build/results tree, private input, AGENTS.md or output/.
Public integrity succeeded from outside the clone, and 15 Python tests passed.
The exact synthetic fixture hash survived core.autocrlf=true. A single new
VS2022 x64 Release CPU/OpenMP ON build with CUDA/tools OFF succeeded without
Toolkit discovery. Ten CTests passed first; three failed due to Git ownership
trust between sandbox clone creation and SDK-access execution accounts. Only
those three were repeated with process-local trust for the exact known clone;
all passed. No persistent configuration or source changes were needed.
Use the same owning account for normal clone/build/test work. This environment
condition is not evidence of an engine or path-handling defect.

Equivalent supported isolation procedure (choose a new ignored directory):

```powershell
git -c core.autocrlf=true clone --no-hardlinks . 'results/portable-check/clean checkout'
# Run section 1 with -S pointing at that checkout and a new sibling -B directory.
# From any cwd, invoke the cloned scripts/check-reproducibility.py by its full path.
```

The clone must have the full history used in sections 2 and 3. A source-only
archive export cannot run the historical Git checks. The optional local
convergence command correctly rejected absent original archives, with no
fallback to this primary checkout's files. Tests can create ignored synthetic
fixtures under data/local; this does not make provider data a prerequisite.
The new baseline's stdlib verify.py also supports public selected-counter
verification without GPU or original reports; its optional --local-records
reprojects hash-bound raw exports. Commands and local log hashes are in the
baseline record. The later [independent DRAM review](../evidence/v030-dram-review-20261020/README.md)
adds raw process/device/launch and primary-workload comparisons, with no new GPU
execution, plus a bounded OEM manual search that leaves peak/percentage unresolved.
This is same-machine relocation evidence, not a fresh-machine
trial, historical campaign reproduction or removal of original full-audit
binary/cache/archive/path dependencies described above.

## Hosted remote CPU reproduction, 2026-10-21

The authorized GitHub Actions hosted environment now exercises sections 1 and 2
and selected public DRAM verification from a full-history clean checkout.
Tested source: fda3c64c891a2d9bfd7d325615fef0423a64e0f3; successful first-attempt
[run 39500451137](https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/39500451137).
[Actual logs and source/environment/result record](../evidence/v030-hosted-cpu-reproduction-20261021/README.md)
show Ubuntu 26.04.1 LTS X64/x86_64, hosted image ubuntu-26.04 version
20261012.163.1, GNU C++ 15.2.0, Python 3.14.4, CMake/CTest 4.4.4, Git 2.55.0.
OpenMP ON passes 7/7 CTests; OFF passes 6/6. Each job passes 15 Python tests,
78-file selected historical integrity and the 14/307 selected DRAM records.
CUDA and CPU instrumentation tools are explicitly OFF for those two jobs.
The retained Windows instrumentation smoke job also succeeds; it is separate.

The previous b3b67a4 CI was already a remote hosted CPU build/test result, but
its shallow checkout and omitted public integrity invocation left that portion
unexercised. The existing jobs now use fetch-depth=0 and log source/history,
empty initial git status, OS/architecture and tool versions before the unchanged
public checks. Dependencies come from the hosted image; no installation or
artifact upload was added. No separate local CPU rebuild was repeated.

This is a remote hosted-runner CPU reproduction result, not evidence of a
specific second physical host, a second Windows/CUDA laptop or arbitrary-machine
portability. Sections 3 and 4 were not executed remotely: their ignored original
binary/cache/raw/archive dependencies were not supplied. Selected figure hashes
are checked, but no figures or historical numerical/performance campaign were
regenerated. CPU success does not repair serial source-to-binary=false, the
unavailable independent historical OpenMP cache or mixed-revision convergence.
Private provider inputs remain excluded. The earlier same-machine clone remains
dated relocation evidence; it is not relabelled as this remote trial.

The evidence pins the tested source and workflow content. Later documentation
commits have their own exact-SHA publication CI, avoiding a manifest that tries
to contain its own commit/run identity. No external transfer package or separate
execution host was needed for this completed public CPU path.

For peak bandwidth, local allowlisted identity/targeted OEM-document checks did
not produce a new commercial configuration lead. Prior official searches were
not repeated. An applicable documented effective VRAM rate/peak remains needed;
theoretical peak and percentages remain unresolved independently of this trial.

## Supplementary NVIDIA configuration reference, 2026-10-21

A later authentic local NVIDIA App System Information report now supplies a
class-B installed-configuration reference, separately from the unresolved
published-specification route described above. The complete supported Copy Text
capture stays ignored/private; a sanitised exact-label extract, provenance and
read-only calculation are in the
[reference record](../evidence/v030-nvidia-configuration-reference-20261021/README.md).
Its 256.032 GB/s field is the denominator for archived cold-cache collected-
kernel ratios, 36.54610877595663% and 9.60865565224468%. No original profiling,
simulation, local CPU build or figure rendering was repeated. This does not alter
the earlier remote-trial scope. The later acceptance interpretation below
supersedes only the earlier unresolved reporting status.

```text
python -B evidence/v030-nvidia-configuration-reference-20261021/calculate.py --check
python -B -m unittest discover -s tests -p test_nvidia_configuration_reference.py -v
```

The stdlib calculation checks selected/parent hashes and reuses the unchanged
baseline integer-counter validation; public checking needs no clipboard/GPU or
private full report. A provenance holder can separately verify the full local
capture's exact bytes against the new manifest. The sanitised public extract is
not represented as the original full report. Existing numerical/raw manifests
and historical snapshot/Git checks remain strict and unchanged.

## Current bandwidth reporting interpretation, 2026-10-21

The [source/authority audit](acceptance-source.md#documented-peak-interpretation-audit-2026-10-21)
records the existing reporting clause as satisfied within the archived kernel
scope. Use the precise label "percentage of NVIDIA App-reported configuration
bandwidth" with the documented theoretical/configuration reference 256.032 GB/s:
full-device 36.54610877595663%, hybrid 9.60865565224468%. The existing commands
above verify original integer totals, exact-byte parents and the calculation;
no new GPU run or software rebuild is needed for this interpretation.

The immutable reference README, calculation flags indicating that no published
specification was established, and older search/trial sections retain historical
truth. They do not override the current acceptance interpretation. No historical
manifest/hash is refreshed. No separate published OEM document was located;
this is a retained limitation, not a transfer/run prerequisite or blocking task.
No private source/report is copied into Git. The report is class B, not class A
or runtime clocks. Cold-cache aggregation, excluded transfer/host costs, the
later configuration-report date, shared-resource caveats and unknown sustainable
peak remain. This does not reproduce historical binaries/performance or expand
hosted CPU validation to independent Windows/CUDA execution or academic delivery.
