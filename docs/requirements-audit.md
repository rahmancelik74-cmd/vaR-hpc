# FR/NFR evidence consistency audit, 2026-10-20

This is a technical mapping, not an academic submission or a new acceptance
contract. IDs are preserved. The populated local source is `Requirements and
Design v1.0 - GPU Monte Carlo - Review Draft.docx`, SHA-256
0cbdc1d1b90f394b22411d26675ed52730170229ac4d7b70fcdb35ba7d23ae70,
sections 3, 4 and 9 (read directly from its Word XML). It defines FR-1..FR-9
and NFR-1..NFR-9. Its title/status does not prove approval or submission.
The local `Capstone_Requirements_Design_Document_EN.docx`, SHA-256
db6ab00856387a219cd651af80241f9d9784dc3fe20f34976130cd8b71957a99,
is an incomplete template, not an alternate populated contract. Both private
documents remain outside Git. No signed/approved FR/NFR baseline was available
in the repository; administrative acceptance remains unverified.

[acceptance-source.md](acceptance-source.md) records the identified approved
proposal and roadmap sources and the unchanged numerical/performance criteria.
That numerical contract takes precedence over an obsolete status in a draft.
The matrix below transcribes the operative criteria without relaxing thresholds.
Evidence is scope-specific, not a claim all requirements are globally complete.

Evidence keys (all relative to evidence/): C = v030-convergence-windows-20261020;
F = v030-convergence-figures-20261020-v2; P = v030-primary-benchmark-windows-20261019;
D = v030-cuda-stage-diagnostics-windows-20261019; O = v030-openmp-windows-correctness-20261016;
S = v022-validation-20261016; R = v030-reproducibility-20261020;
B = [v030-dram-baseline-20261020](../evidence/v030-dram-baseline-20261020/README.md),
independently reviewed in
[v030-dram-review-20261020](../evidence/v030-dram-review-20261020/README.md).
Earlier denied-access packages are historical parents, not current blockers.
H = [v030-hosted-cpu-reproduction-20261021](../evidence/v030-hosted-cpu-reproduction-20261021/README.md),
the remote hosted CPU build/public-integrity trial with actual log excerpts.
See each README/manifest for source and limits.
GPU acceptance raw archive is results/gpu-acceptance-8df5f28-20261019;
[gpu-acceptance.md](gpu-acceptance.md) defines its coverage and tool limits.

## Functional requirements

| ID | Criterion | Implementation / checks | Evidence and status | Remaining limitation |
| --- | --- | --- | --- | --- |
| FR-1 | Import daily close CSV; reject invalid dates, ordering, fields/prices; retain valid observations and explicitly reject every documented malformed fixture | src/data.cpp; test_data.cpp, test_cli.cmake, equity import tests | Implemented; current R CPU CTests pass; local historical integration documented in historical-data.md | Public fixture is synthetic; private provider/calendar files are not in checkout; arbitrary undocumented input formats not supported |
| FR-2 | Log-return annual GBM calibration with documented scale/sample variance; controlled .01,.02,.03 returns give mean .02, variance .0001 and parameters within 1e-12 | src/data.cpp; csv_calibration_tests | Demonstrated controlled tests and C/F independent two-pass recalculation | Working horizon/data settings do not establish final historical study choice |
| FR-3 | Analytical single-asset GBM VaR at .95/.99; known quantiles/deterministic/signed cases within 1e-12; retain negative VaR | src/core.cpp; core_tests | Implemented/tested; C/F independent references | Model correctness, not predictive market validity |
| FR-4 | Both confidences through selected serial/OpenMP/CUDA; full accuracy acceptance requires NFR-5/6 | shared Engine in include/mc/core.hpp; src/core.cpp/openmp.cpp/cuda.cu | Demonstrated fixed-fixture analytical and separate common-input evidence, S/O/C and GPU acceptance | Different source/build revisions; resource-limited CUDA requests can fail explicitly |
| FR-5 | Identical normal per scenario across engines; caller data unchanged, size mismatch rejected, NFR-6 satisfied | test_core.cpp, test_openmp.cpp, test_cuda.cpp, test_cuda_hybrid.cpp | Implemented; CPU regression now; archived GPU common-input cases in GPU acceptance | Native equal seeds are not common inputs; dynamic checks cover recorded cases only |
| FR-6 | CLI input/N/seed/horizon/annual scale/backend/OpenMP threads; effective metadata matches settings; reject invalid combinations | src/main.cpp; cli_contract_tests, json_output_tests | Implemented; current R CPU tests and archived GPU configuration checks | CUDA options require CUDA build/device; unavailable selection fails, no silent fallback |
| FR-7 | Export model/seed/RNG/version/input checksum/timing scope and experiment metadata | src/output.cpp; scripts/run-experiment.ps1, gpu-record-common.ps1 and recorders | Demonstrated JSON contract plus hash-bound S/O/P/D/C manifests | Input SHA/build/dirty state belong to orchestration manifests, not a claim every direct CLI invocation archives provenance |
| FR-8 | Automate seeded statistical validation separately from repeated timing campaigns | run-convergence.ps1/analyze-convergence.ps1, convergence-audit.ps1; benchmark recorders | Implemented and demonstrated: C 80 runs/160 values/32 groups; P 3+10 per config | Reused C records span revisions; no campaign is rerun by reproducibility checks |
| FR-9 | Labelled hybrid fallback: GPU batch losses, one global quantile under device-memory constraints; never average batch VaRs | src/cuda.cu; cuda_hybrid_tests; cuda-hybrid.md | Implemented explicit hybrid selection and archived batch/common/native checks | Full-device memory preflight fails explicitly; it does not automatically change mode. Host loss storage required; no universal OOM recovery claim |

## Non-functional requirements

| ID | Criterion | Implementation / checks | Evidence and status | Remaining limitation |
| --- | --- | --- | --- | --- |
| NFR-1 | Evaluate transfer-inclusive 10x GPU/serial at N=10000000 and report comparison to best measured OpenMP | Host Engine boundary; P independent statistics | Evaluated: full-device 9.739930524x serial (10x target UNMET), 8.307208722x best OpenMP; hybrid 0.967604573x best OpenMP, so did not beat it | Laptop/context/power/thermal limits; device-stage times are not replacement speedups |
| NFR-2 | 100% of documented invalid-input fixtures fail with nonzero status and explicit error | test_data/core/output/cli and recorder tests; explicit exception/exit handling | Demonstrated registered CPU cases in R, archived GPU cases | Finite fixture coverage, not all possible malformed inputs or runtime faults |
| NFR-3 | Version command/examples; 100% English ASCII code, comments and program messages | src/main.cpp --version; CLI tests; README and reproducibility.md | Version/CLI demonstrated; maintained implementation/test code is ASCII | Localized OS/compiler third-party logs and observed paths are retained faithfully; not program-message translations or a whole-history ASCII claim |
| NFR-4 | 0 personal/patient records; document every price dataset's source/range/reuse/adjustment | synthetic fixture; equity importer; historical-data.md, data-rights-and-calendar.md | Computational inputs are synthetic or market prices; provider provenance/rights documented with local hashes | Private permission correspondence is user-supplied, not independently authenticated; no redistribution of raw prices; no assertion repository metadata contains no personal names |
| NFR-5 | At N=10000000, seeds 42,123,456,789,2026 per engine: abs(mean(VaR)-analytical) <= .01*max(abs(analytical),.01*V0), separately .95/.99 | convergence-audit.ps1; F independent Python statistics | Demonstrated one nondegenerate fixed synthetic case; eight rows pass; R re-audit passes | Not per-seed acceptance, MAE, monotonic-error requirement or universal MC guarantee; serial source-to-binary=false and mixed builds remain |
| NFR-6 | Double, common nearest-rank ceil(alpha*N)-1; common-input VaR absolute difference <= .00001*V0; separate memory/race checks | CPU/GPU common-input tests and gpu-acceptance.md | Demonstrated recorded common-input cases; representative Compute Sanitizer findings archived | Sanitizer does not prove general global-memory race freedom or CPU host-buffer safety; numerical agreement is not a memory-safety proof |
| NFR-7 | N=100000,1000000,10000000; 3 excluded warm-ups + 10 measured/config; mean, sample SD (denominator 9), scenarios/s and ratios | benchmark-common.ps1, verify-benchmark.ps1; P/session auditors | Satisfied within recorded timing scope: P has 312 processes, 72 warm-ups, 240 measurements, 24 configs; all samples retained | B separately satisfies measured kernel-scope DRAM reporting for two cold-cache profiles; applicable documented peak/percentage is an evidence gap |
| NFR-8 | Exact-byte SHA-256 and Git dirty state per experiment; two same-build/input/seed/backend runs reproduce VaR excluding timing | recorder manifests; serial exact repeat test, OpenMP native invariance; archived P repeated estimates | Demonstrated recorded same-build cases; R checks all 24 P configurations' 13 pairs of VaRs are identical | Not cross-library/build/engine bitwise reproducibility. Historical serial source-to-binary=false; O has no published independent standalone cache; archives/builds ignored and not public-clone-complete |
| NFR-9 | Release build: 0 build errors, all registered tests pass, >=1 successful basic CI | CMake/CTest and .github/workflows/build.yml | Satisfied within recorded CPU build/CI scope: R Windows ON 13/13, OFF 12/12; same-machine relocation passed all 13 across initial/recheck attempts. H hosted Ubuntu ON 7/7, OFF 6/6, 15 Python tests/job and 78 public artifacts passed; exact source fda3c64c891a2d9bfd7d325615fef0423a64e0f3, run 39500451137 passed 3/3 | H is remote hosted CPU evidence, not a second Windows/CUDA laptop, arbitrary-machine or historical performance reproduction. R remains same-machine CPU-only evidence; archived CUDA binary reused without rebuilding; initial SDK failures preserved |

Baseline achieved DRAM GB/s is now demonstrated for two single N=10000000
cold-cache profiles: full-device 93.56973322125727 and hybrid 24.601233239555107,
using compatible kernel bytes/durations. See the
[baseline and portability record](../evidence/v030-dram-baseline-20261020/README.md).
Counter access succeeded; no new administrator action is required for that session.
The independent raw review checks all 321 launch IDs, per-process/device/context/
stream identity, ten stage/aggregate sums and 13 primary result pairs per mode.
The OEM manual catalog adds two inspected G870 manuals; neither technical table
documents an applicable effective memory rate. Applicable peak/percentage remain
an evidence gap, not an access-permission limitation. NFR-1 is a measured target
not met; demonstrated checks elsewhere are satisfied only within their recorded
scope. Missing historical provenance remains an evidence gap. H now establishes
remote hosted CPU source build/tests and selected public integrity. Independent
Windows/CUDA laptop validation remains optional future validation. Academic
approval/submission and live delivery remain external/unverified.
No bandwidth threshold or inferred peak is introduced. Public relocation checks
passed on the same machine; H adds a separate hosted Ubuntu trial. Historical
full-session archive/layout dependencies and the untested independent Windows/
CUDA laptop path remain explicit. No FR/NFR ID or
numerical/performance acceptance criterion changed.
RNG's largest covered device-stage mean does not establish the dominant
end-to-end cost. Optimization is optional
and was not started. Academic requirements/report submission, final report and
live demonstration remain unverified/outside this technical package.

## Preserved older-label crosswalk

The repository's requirements-design.md retains the original R01-R14/B01-B02
definitions and initial statuses. No historical explicit FR crosswalk was found
in tracked files. The following is a newly documented many-to-many technical
correspondence, not a renumbering or assertion it appeared in the old draft.

| Older ID | Correspondence |
| --- | --- |
| R01 | Scope/model limitations across FR-3/4; market validity excluded |
| R02 | FR-3/5, NFR-6; units/sign/quantile/double |
| R03 | NFR-7/8/9 environment records |
| R04 | NFR-9 build/CTest/CI |
| R05 | FR-4/5 shared Engine contract |
| R06 | FR-1/2, NFR-4 CSV/calibration/provenance |
| R07 | FR-3 analytical reference |
| R08 | FR-4/8, NFR-5 serial analytical validation |
| R09 | FR-4/5/6/8, NFR-1/6/7 OpenMP correctness/scaling |
| R10 | FR-4/5 capped connectivity subset only |
| R11 | FR-4/9, NFR-6 full-scale CUDA/memory checks |
| R12 | FR-5/8, NFR-5/6 complete scoped engine validation |
| R13 | FR-8, NFR-1/5/7 benchmark/convergence |
| R14 | FR-7/8, NFR-8/9 technical reproducibility; academic reporting separate |
| B01 | Optional optimization, not started; baseline peak-percentage evidence still required |
| B02 | Optional multi-asset work, outside scope |
