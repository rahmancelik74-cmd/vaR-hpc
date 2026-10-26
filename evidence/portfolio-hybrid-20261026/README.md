# Portfolio hybrid CUDA: local PH-1 evidence

Prepared on 2026-10-26 from main ca6bb72725115dc7f143cef3b5eda2649985d1c3.
This is a separate portfolio extension, not a change to existing FR/NFR or
single-asset acceptance criteria. [Contract and commands](../../docs/portfolio-hybrid.md).
The [protocol](PROTOCOL.md) and fixture hashes in [freeze.json](freeze.json)
were saved before GPU validation; numerical thresholds/seeds/N were not changed.

## Actual results

- Final Windows CUDA/OpenMP Release CTest: 22/22; serial-only: 17/17;
  CUDA OFF/OpenMP: 18/18. After extra independent-oracle/CLI assertions,
  affected serial/OpenMP contracts passed 2/2 each and all CUDA tests passed
  again. 28 portfolio Python regressions and selected retained public evidence
  integrity passed. Hosted CPU CI has not run this local CUDA study.
- 168 common-input cases and 96 native payload/determinism cases passed.
  A=1,2,3,5; N=1,11,12,255,256,257; common B=1,2,3,4,11,256,999;
  native B=1,3,256,999. Maximum serial/hybrid common difference
  2.8421709430404007e-14; unchanged absolute tolerance 1e-10*portfolio V0.
  Full-device/hybrid use the same common inputs and unchanged tolerance.
  Negative correlation, T=0, zero sigma/negative VaR, repeated confidence,
  caller preservation, invalid inputs, arithmetic guards, overflow and recovery
  passed. The independent 100-loss trap gives global 95%=0 and 99%=80;
  averaging the two batch 95% VaRs would incorrectly give 40. Extra independent
  two-asset terminal-price oracles passed at four hybrid batch sizes.
- Bounded native distributional consistency: two pre-existing synthetic
  positive/negative-correlation fixtures, 1M scenarios each, fixed native and
  independent PCG64DXSM reference seeds. All four alpha comparisons passed:
  CDF errors .000422, .000215, .000017 and .000055 against .0036573948713638487.
  Four uniform DKW events yield >=99% simultaneous coverage under ideal iid
  assumptions. See [statistical.json](statistical.json) for exact observations.
  This evaluates this finite native hybrid path, not a practical .0005*V0
  target, universal acceptance, forecasting, a new reference/convergence campaign
  or previously published full-device conclusions.
- Compute Sanitizer 2026.3.0.0 full 264-case memcheck: 0 errors, 0 leaked bytes.
  Broad racecheck exceeded its 600s bound and was stopped; no passed result is
  claimed. New focused selection: A=1,2,3,5, N=17, common B=3,4,99 and native
  B=3,4 (20 cases), plus the retained deterministic/global-rank/error checks.
  Focused racecheck: 0 hazards displayed (0 errors/warnings); focused memcheck:
  0 errors, 0 leaked bytes. Shared-memory racechecking does not prove global
  race freedom, CPU host safety, arbitrary API-failure safety or 10M safety.
- Native capacity/integration completed: five assets, N=10000000, seed 42,
  B=65535, 153 batches, final partial batch 38680. 50000152 generated normals
  include per-call padding; no host normal transfers. Exactly 10000000 scalar
  losses transferred, host array 80000000 bytes, explicit device buffers
  3145692 bytes. Free VRAM before buffers 7451181056 bytes; live pipeline
  snapshot 7438598144 bytes (difference 12582912 bytes). The latter includes
  opaque allocator/library effects and other activity, not a measured peak.
  Preflight limit 5960944844 bytes (80% of free); 20% reserve is not universal
  OOM recovery or extrapolated capacity. This is not statistical acceptance,
  sanitizer coverage, a benchmark or speedup evidence.
- Existing permitted private AAPL/MSFT calibration was reused unchanged after
  original-byte/Decimal audit. N=10003, seed 42, B=257 hybrid integration passed
  asset order/unit/model serialization and null analytical-field checks.
  Observations, dataset hashes, calibrated values and outputs remain ignored
  under results/portfolio-hybrid-20261026 and original private directories.
  No reacquisition/recalibration, synthetic target transfer or forecasting claim.

## Identities, timing and preservation

RTX 4060 Laptop GPU, compute 8.9, driver 610.88, nvcc 13.4.92,
MSVC 19.44.35227, cuRAND 10.4.4.72, CUB 3.4.3; Release Ninja builds,
CUDA architecture 89, --fmad=false. Exact [identities](identities.json), cache
copies and *.process.json record source/build hashes, commands, time of execution,
exit status and exact-byte log hashes. Final artifact hashes identify the final
rebuild. Early statistical/private integration executable hashes were not captured
before a same-production-source relink; no binary equivalence proof is claimed.
Sanitizer's original target/source binding and original test snapshot are retained.

Fresh CLI processes include context work inside primary engine wall time; the
test matrix shares one context. No context/cache flushing or thermal equilibrium
is claimed. The focused device snapshot is not run-wide telemetry. No explicit
CPU affinity/pinning was set/measured; inherited placement, Office power scheme;
new CIM host topology query was denied. Full system/process inventory is private.
Primary timing includes per-run host/device allocations, native RNG, simulation,
scalar copies, global host quantile, synchronization and cleanup. Shared input,
calibration/Cholesky and final output are excluded. Events accumulate stages;
copy events, pipeline span and host_quantile_ms have distinct scopes and do not
automatically sum to primary wall time. No formal timing repetitions were run.

All 355 earlier tracked evidence files retain their exact local bytes, recorded
in prior-evidence-inventory.json and rechecked at completion. All match HEAD
under their existing filters. 341 match raw Git blobs; 14 have existing checkout
newline forms, also preserved without normalization. Earlier package contents
and claims were not overwritten. Current docs explicitly supersede the former
portfolio hybrid rejection; historical statements stay historical.

## Attempts and coverage limits

The first build recorder failed due to cmd quoting; -v2 used a local .cmd file
and succeeded. One later link attempt hit the active sanitizer executable's
Windows file lock; after that job ended, final-build-cuda-v2 succeeded. Both
failed build logs remain. A statistics reader initially used the wrong output
key; analysis resumed the exact successful native sample instead of rerunning
or changing a seed. First PowerShell redirect captures are retained alongside
proper byte/process-recorded v2 checks. The broad racecheck timeout wrapper did
not retain partial stdout; racecheck-matrix-timeout.json records the missing
coverage and the verified cleanup of only its two expired processes. Focused
sanitizer runs use the real .exe directly. No forced allocation exhaustion,
injected CUDA failures, host ASan/race detector or full-capacity sanitizer run
was performed. Checked allocation/API errors and RAII remain implemented.

## Reproduction and delivery

Build/CTest and direct sanitizer command lines are in each *.process.json.
The focused executable is `build-portfolio-hybrid-cuda/mc_portfolio_hybrid_tests.exe --focused`;
without the flag it executes all 264 common/native cases plus extra checks.
The exact serial/full-device/hybrid examples are recorded in example-*.process.json.
The [recorder](../../scripts/check-portfolio-hybrid.py) resumes successful
hash-verified output records without rerunning native samples. Direct commands
can be run into a new ignored location to obtain new observations; do not
rewrite this frozen package. NumPy is analysis-only, not a runtime dependency.

At preparation, .git/index.lock creation is denied in this executor and the
existing gh authentication returns HTTP 401. No new commit/push/exact-SHA CI
is claimed. The sole authorized destination remains rahmancelik74-cmd/vaR-hpc.
The NEW [delivery script](../../scripts/deliver-portfolio-hybrid.py) is bound to
ca6bb727, an explicit path/hash allowlist, UTF-8 subprocesses, exact-byte evidence,
CRLF-aware review, account/remote checks and bounded resumable exact-SHA CI.
It never changes credentials/accounts/global configuration/permissions.

One remaining manual step, from an ordinary authorized session with working
existing authentication:

```text
C:/Users/rahma/anaconda3/python.exe -B scripts/deliver-portfolio-hybrid.py
```

Preparation completion: completion.json; private persistent delivery state:
results/portfolio-hybrid-delivery-20261026/state.json. Future successful script
execution records actual commit/push/CI there, keeping frozen evidence intact.
Hosted CI proves its CPU/synthetic jobs only, not local RTX/private-data execution.
No academic artifact or submission was created.
