# Formal primary CPU/GPU benchmark, 2026-10-19

Tested clean source: 89536e38b01230fce3b4667096c29dde56795c23. This archive
is a later documentation/evidence checkpoint, not a new implementation or run.
The primary campaign is complete: 312 processes, 72 excluded warm-ups, 240
measurements and 24 summary rows. Fresh Windows Release preflight passed 18/18.
Both existing independent auditors passed again during closure; no benchmark
process was launched. The 10x serial target at N=10000000 was NOT met:
full-device reached 9.7399305240447234x serial and 8.30720872221534x best
OpenMP. Hybrid reached 1.1344847146209416x and 0.96760457307711611x.

See [the technical interpretation and full limitations](../../docs/cpu-gpu-benchmark.md#formal-primary-result-2026-10-19).

## Selected publication and exact bytes

- summary.csv / summary.json preserve every full-precision configuration row.
- samples.csv is a derived round-trip projection of all 312 original JSONL
  records: sequence, phase, repetition, primary timer, teams and both estimates.
  Warm-ups and slow samples remain present. It is not a raw launcher dump.
- plan.json preserves the complete fixed configuration/order/repetition plan.
  fixture.csv is the existing public hand-written synthetic fixture, not
  provider data; independent-fixture.json records its separate calibration.
- recorder-audit.json and session-audit.json are exact copies of original passed
  audits. recorder-reaudit.json and session-reaudit.json are the closure reruns.
- closure-audit.json verifies 3391 run2 and 226 run1 hash-bound records and
  confirms all 3619 original files stayed unchanged, including the manifests.
- review.ps1 reuses the existing auditors with only their final report paths
  redirected. Run from repository root with the original ignored evidence and
  builds available, invoking review.ps1 with
  `-ReviewDirectory results/benchmark-closure-new-review`. It launches no benchmark
  samples. audit-session.ps1 is the unchanged original supplemental auditor;
  it is copied for inspection, not intended to run from this curated folder.
- session-report.md is the unchanged original session report, including the
  readable complete 24-row table. Its statements about no commit/push refer to
  that measurement session, before this publication commit. Its original trailing
  space is retained for exact-byte provenance; it is not normalized for lint.
- user-conditions.json, runtime-environment.json and ctest.log preserve selected
  original condition/preflight records. ctest.log contains actual local paths.
- first-invocation-failure.json preserves the incomplete run1 diagnosis: caller
  path error before campaign creation, zero samples. run1 remains unchanged.
- provenance.json binds source/tree/input/executable/cache, original local
  manifests and JSONL hashes, and each selected exact copy. Original manifests,
  raw JSONL, launcher records, telemetry, build captures and private/unrelated
  outputs stay local in their designated ignored directories. This subset is
  not a self-contained copy of the full raw-session archive. The existing full
  auditors require those local records/build artifacts.
- artifact-sha256.json hashes every published artifact except itself; local
  .gitattributes disables newline conversion to preserve exact bytes.
- publication-validation.json records the exact-copy, lossless projection,
  independent statistics, relative-link and published-script ASCII checks.

## Scope of closure

Existing auditor logic independently recomputed explicit-sum/two-pass sample
variance (n-1), throughput, per-N best OpenMP selection and both speedup ratios,
with raw/summary/model/configuration/hash and diagnostic-OFF bindings. The
supplemental audit rechecked every CSV field and observation/condition records.
Publication validation also recomputed the curated sample projection against
original JSONL and verified all 24 summary rows. Original evidence was not edited.
Only stale current documentation status was corrected; historical records remain.

Fresh process/context policy and inclusive host timer apply. Diagnostics and
profiling were off. The actual pre/post observation gaps (16.6744291 s and
27.3165226 s), estimated ambient 15 C, GPU point range 44-51 C, unknown fan/vendor
modes, open GPT/Codex and unestablished CPU temperature/equilibrium/no-throttling
remain explicit limitations. No predictive market-validity claim is made.

Stage/transfer-excluded diagnostics, achieved DRAM bandwidth/peak reporting,
profiler orchestration, convergence and final reproducibility remain separate.
ERR_NVGPUCTRPERM and unavailable exact-laptop peak are unresolved. Plan B
optimization is optional; no optimization or academic authoring occurred here.
Academic submission and live demonstration are not verified. Hosted CPU CI must
be checked against the exact final pushed SHA separately from local RTX evidence.
