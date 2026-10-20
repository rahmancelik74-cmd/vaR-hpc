# Hosted CPU public reproducibility trial, 2026-10-21

Tested source: fda3c64c891a2d9bfd7d325615fef0423a64e0f3.
Run [39500451137](https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/39500451137)
completed successfully, all three jobs, first attempt. Timestamps are UTC
2026-10-20 21:27:04 through 21:28:07, corresponding to 2026-10-21 in Istanbul.
This later evidence/documentation commit is distinct from that tested source.

## Why a workflow change was needed

Inspection started at main b3b67a42b67be7b28122ac6b31f9908536d1c03a, matching
remote main, with only AGENTS.md and output/ untracked. Root instructions and
the current acceptance/reproducibility/requirements/DRAM records were read.
The existing workflow is the authorized remote execution environment; no other
project execution host was configured in the inspected repository. No network
scan, credential search, resource provisioning or third-party contact occurred.

Previous run [39441828042](https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/39441828042)
was already a real hosted remote CPU build/test result at that exact b3b67a4
source. Its actual Linux logs show 15 Python tests per job and 7/7 OpenMP ON,
6/6 OFF CTests on hosted Ubuntu. The Windows log shows Server 2022 10.0.20348
and recorder smoke completion, but does not surface its internal per-test logs;
no extra Windows test-count claim is inferred. Those successful jobs were not
failed trials. However, checkout used fetch-depth=1 and did not invoke the
documented scripts/check-reproducibility.py public integrity entry point.
The unit tests exercise checker failure handling but do not replace that call.

The existing Linux jobs were minimally extended: fetch-depth=0, source/history/
OS/architecture/tool-version output, the unchanged public integrity command and
explicit MC_BUILD_CPU_TOOLS=OFF / BUILD_TESTING=ON. CUDA remains explicitly OFF.
The original Windows instrumentation job remains unchanged. No extra workflow,
action, job, installed dependency or uploaded executable/archive was added.

## Actual environment and results

Both Linux jobs report Hosted Compute Agent / Azure, image ubuntu-26.04 version
20261012.163.1, Ubuntu 26.04.1 LTS, X64/x86_64, kernel 7.0.0-1017-azure.
Actual tools: GNU C++ 15.2.0 (Ubuntu 15.2.0-16ubuntu1), Python 3.14.4,
CMake/CTest 4.4.4 and Git 2.55.0. OpenMP ON finds version 4.5 / -fopenmp.
The source SHA is printed; is-shallow-repository=false and git status is empty
before tests/build. These are remote hosted-runner observations, not execution
in another directory, container or VM on the project laptop. Physical host
identity, host reuse and arbitrary-machine portability are not established.

| Hosted Linux configuration | Python tests | CTests | Public selected integrity | Selected DRAM counters |
| --- | ---: | ---: | --- | --- |
| Release, OpenMP ON, CUDA/tools OFF | 15 passed | 7/7 passed | 78 files passed | 14 full-device + 307 hybrid records passed |
| Release, OpenMP OFF, CUDA/tools OFF | 15 passed | 6/6 passed | 78 files passed | 14 full-device + 307 hybrid records passed |

The existing Windows instrumentation smoke job also succeeded. No new local
CPU build was run. Tests use small synthetic software fixtures, not a formal
statistical/performance campaign. No engine source, numerical contract, native
RNG assignment, precision or quantile convention changed.

The exact commands and actual outputs are in
[ubuntu-on.excerpt.log](ubuntu-on.excerpt.log) and
[ubuntu-off.excerpt.log](ubuntu-off.excerpt.log); [trial.json](trial.json)
records source/tree, job/run URLs, metadata and parsed reports. Equivalent
public reproduction from a full-history checkout, using the runner's existing
Git/Python/CMake/C++ toolchain (repeat configure/build/CTest with OpenMP OFF):

```text
git checkout --detach fda3c64c891a2d9bfd7d325615fef0423a64e0f3
git rev-parse --is-shallow-repository
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
python3 -B scripts/check-reproducibility.py
python3 -B evidence/v030-dram-baseline-20261020/verify.py
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DMC_ENABLE_OPENMP=ON -DMC_ENABLE_CUDA=OFF -DMC_BUILD_CPU_TOOLS=OFF -DBUILD_TESTING=ON
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

## What was and was not reproduced

This establishes a narrowly defined external hosted CPU source build/regression
and public-evidence verification result. The 78-file integrity path checks 22
primary, 32 stage and 24 figure artifacts, immutable inventories, figure parents
and historical Git content. It does not re-audit original raw executions or
recalculate convergence statistics. DRAM verification uses selected public
counters: local_raw_checked=false and new_gpu_processes=0. It is not a remote
profile or verification of locally ignored original .ncu-repz reports.

No CUDA device execution, fresh Windows/CUDA laptop validation, historical
binary identity/performance reproduction or figure regeneration occurred here.
The full local convergence/figure paths require ignored original raw/build
artifacts that were not supplied to runners. Provider prices, private rights
correspondence, original binaries/caches and archives were not uploaded or
replaced. Public fixture/evidence integrity is separate from current-document
validation and from exact-byte historical snapshot/Git comparisons.

Historical serial source-to-binary verification remains false; the independent
historical OpenMP CMakeCache is unavailable; convergence spans mixed revisions.
Full historical audits can still require original path layouts. Sanitizer scope
is unchanged. Formal speedups remain 9.739930524x serial (10x target unmet) and
8.307208722x best OpenMP; hybrid did not beat best OpenMP. CPU CI does not
establish CUDA execution, historical performance, academic submission or a live demo.

## Peak-bandwidth track

The previous official-source/manual search records were read first. A targeted
top-level filename-only check of existing Downloads/project-parent directories
found no OEM specification/purchase candidate; read-only allowlisted BIOS
registry fields still report G870 / SKU EXCALIBUR G870 NLXB / board NLXB 001 /
CQ111, without a commercial configuration suffix. No unrelated file contents,
serials or unique device identifiers were collected. There was no new lead for
another authoritative web search, so the same searches were not repeated and
no duplicate peak-search package was created.

The exact missing evidence is still an OEM/NVIDIA effective Gbit/s-per-pin rate
or theoretical peak with demonstrated applicability to the installed memory
configuration. Peak and percentages remain null. Existing cold-cache collected-
kernel rates 93.56973322125727 and 24.601233239555107 GB/s remain unchanged;
transfers/host costs are excluded and no new profile was run. Counter access is
not a blocker. An applicable source would permit peak_GBps=R*128/8 and
percent=100*archived_unrounded_GBps/peak_GBps; no guessed rate was used.

## Capture and preservation

Log retrieval used the connected GitHub tool after unauthenticated log-download
HTTP requests returned 403. That transport restriction was resolved; no missing
log is treated as success. Local JSON captures retain the API-decoded log text;
this is not a raw downloadable log-archive byte-equivalence claim. Published
excerpts select original timestamped OS/image/environment/check/build/test
sections with LF line endings, omitting checkout credentials plumbing, worker
identifiers and cleanup. Timestamped empty output retains its original trailing
space under a narrow log whitespace attribute. Original local capture hashes and selected exact-byte
hashes are in manifest.json. The one-off selection/verification source remains
hash-bound locally under results/hosted-reproduction-b3b67a4-20261021/.

The manifest excludes itself and current documents, pins the tested workflow
Git content separately, and preserves immutable parent inventories. It adds no
cycle to historical numerical manifests. Final publication SHA/CI are separate
post-commit facts, retained locally and reported without another documentation
commit solely to embed its own identity. Current instructions remain in
[reproducibility.md](../../docs/reproducibility.md) and the
[18-item audit](../../docs/requirements-audit.md).
