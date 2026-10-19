# Convergence preparation verification, 2026-10-19

This is local recorder/analyzer/verifier preparation on top of
fc0ba0c2e88eef35c0229cf21582467fce427f39, with uncommitted source changes.
It is not a clean-source GPU campaign, benchmark, figure or academic artifact.
No new simulation processes were launched. No commit or push was performed.

## Results

- Focused historical-import/corruption/mock-recorder tests: **82 checks passed**.
  The successful mock flow emits exactly the 25 missing configurations once;
  another flow retains one success followed by a failure; four more flows test
  timeout, start failure, malformed JSON and unexpected stderr. All are synthetic
  mocked outputs, not simulation observations. Complete mocks are never imported
  into the convergence dataset. Exact test names are in focused-tests.json.
- CPU/OpenMP configuration: 13 tests discovered, only the three relevant script
  tests selected; **3/3 passed**. These include portable convergence statistics,
  the existing unified benchmark auditor (61 checks) and existing GPU recorder
  auditor (57 checks). No benchmark or GPU process is launched by these tests.
- Serial-only configuration: 12 tests discovered, portable convergence test
  selected; **1/1 passed**. Both configurations have MC_ENABLE_CUDA=OFF and no
  Toolkit/compiler discovery. These were configuration/script checks, not full
  rebuilt engine regression suites. SDK discovery was initially sandbox-denied;
  the same configurations succeeded with approved SDK access. No dependency was
  installed and no optional CUDA build was performed.
- All ten new PowerShell files parsed successfully and contain ASCII only.
  git diff --check passed. No src/ or include/ changes were made.
- Import and independent audit: **55/80 native runs, 110/160 VaR values**;
  complete=false, missing_processes=25. All 32 group rows, 110 per-seed errors
  and eight separate 10M acceptance rows were independently recomputed.

The verifier independently obtains analytical references 6.14357693941893 and
8.7154467162009155 from the exact fixture bytes, not these displayed numbers.
It recalculates sample calibration and seed statistics without calling analyzer
math or trusting its summaries. The application expm1 reference differs by
ordinary binary64 rounding; the existing 2e-12 relative arithmetic comparison
does not alter project acceptance.

## Reuse and provenance

plan.json contains the explicit 55 selections and fixed missing-run matrix,
exact artifact paths/hashes, source SHA/tree, available build bindings,
compatibility diffs and figure specification. The fixture exact-byte SHA-256 is
8dbb7c73e6ad48cb8c8c175aff6684d2a0433e5f08424ec7ea1e69037bb36210.

Verified reuse is serial 20; OpenMP requested/actual four threads 20; CUDA
full-device 8; hybrid 7. The five smaller-N GPU singleton observations are
selected once each. No benchmark repeats, common-input records, connectivity
checks, diagnostics or sanitizer observations fill missing independent seeds.

Historical serial manifest explicitly states source-to-binary verification=false.
Its archived executable hash matches; core/data sources are unchanged. A direct
comparison also confirms both N=10000, seed=42 VaRs equal the later native
cpu-serial-cuda-on.json observations under the f039034 evidence directory. This
does not prove source-to-binary correspondence. OpenMP implementation is unchanged
and four actual threads are required. Its original hash inventory was checked;
build settings/log and executable are bound. No standalone CMakeCache was
published with that OpenMP correctness evidence; the plan records null rather
than supplying an unverified cache hash.

f039034 and 8df5f28 have no src/include/fixture differences. Later reviewed GPU
changes add optional diagnostic instrumentation and CLI/output metadata.
Each record keeps its original revision/build, and native equal seeds imply no
cross-backend/mode sample equivalence. This remains reuse across revisions, not
a fresh common-build campaign. Both historical GPU independent audits report
passed, and every original manifest record hash was checked without rewriting
historical evidence.

## Local outputs and reproduction

Final import/analyzer/audit directory:
results/convergence-preparation-fc0ba0c-20261019-final/.
It contains dataset.json, analysis.json, independent-audit.json, empty
attempts.json, and captured selected CTest stdout/stderr/process records.
The earlier import directory and earlier focused test attempts remain separate.
Final focused test artifacts:
results/convergence-tests-e59ae333dc2540e4be5828008efeaf39/.
Their test-results.json is copied byte-for-byte as focused-tests.json here.
verification.json binds these output bytes and the implementation/test sources;
it does not claim source cleanliness or RTX execution.

Reproduce from the repository root using the commands in
[docs/convergence.md](../../docs/convergence.md). The portable CTest uses only
the repository fixture; the larger local test requires the exact pinned archived
builds and ignored historical results. Those local dependencies are available
here, but are not distributed by this evidence directory. The OpenMP standalone
cache limitation is explicit above; no other required evidence source was
inaccessible during this preparation.

Instructions read: repository AGENTS.md (the only applicable AGENTS/override
file found in the root/ancestor and relevant source checks). Current-state and
contract sources read: docs/project-state.md current checkpoint sections,
acceptance-source.md, requirements-design.md relevant acceptance/crosswalk,
verification.md, verification-v02.md, experiments.md, gpu-acceptance.md and
cuda-hybrid.md. Existing recorder/auditor sources read include run-experiment,
run-openmp-validation, run-cuda-skeleton, gpu-record-common, gpu-acceptance-audit,
run-gpu-acceptance and verify-gpu-acceptance, plus benchmark helpers/verifier and
focused recorder tests. Private academic documents were not needed for this
implementation; the repository acceptance register remains the scoped contract.

## Remaining work

Exactly 25 GPU processes/50 values remain: full-device seeds 123,456,789,2026 at
N=10000,100000,1000000 (12); hybrid all five seeds at 10000 and those remaining
four seeds at 100000,1000000 (13). Requested hybrid batch is 65535, effective
10000/65536/65536/65536 and counts 1/2/16/153 across the four N values.
Only a later separately authorized task may checkpoint clean source and execute
those configurations. No convergence figure has been produced. Bandwidth,
counter permissions and documented laptop peak remain separate unresolved work.
