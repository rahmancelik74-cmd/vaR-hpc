# Native convergence checkpoint and execution, 2026-10-20

## Pre-commit review

Base HEAD: fc0ba0c2e88eef35c0229cf21582467fce427f39, branch main, expected
origin https://github.com/rahmancelik74-cmd/vaR-hpc.git. The existing unstaged
convergence implementation was reviewed. All 611 previous implementation,
output and historical reuse artifact bindings matched their exact SHA-256
values before fixes. The previous 55-run/110-estimate dataset and all statistics
passed independent recomputation. The previous 82-check report and selected
3/3 CPU/OpenMP, 1/1 serial CTest logs are hash-bound historical evidence,
not full engine regressions. Original evidence remains unchanged.

The former OneDrive root no longer exists. The exact current repository path
is recorded in review.json and the final audit relocation records. A scoped read-only
resolver records old-to-current path mappings and verifies exact bytes.
Preflight discovery, Release regressions and focused tests now gate the missing
native runs. Required raw attempt entries are checked independently. The
original plan is retained at ../v030-convergence-preparation-20261019/plan.json;
its exact-byte SHA-256 is
84f1da88778d56a9880ef7a252243654b6cbed3cffbaf4c4b7f1c2e7fceea322.

Pre-commit focused tests passed 87 checks with mocked process output only.
review.json and review-focused-tests.json bind this review. Old preparation
source hashes describe the prior source and are not updated to hide changes.

Only the 25 planned missing processes are authorized. The 55 prior observations
will be reused, retaining serial source-to-binary=false, the missing published
OpenMP standalone cache, per-record revisions/builds and native RNG limitations.
Clean tested source and actual execution/audit findings will be appended after
those steps complete. No figure, timing campaign, profiling, optimization,
academic document, automation or push is part of this checkpoint.

The repository AGENTS.md was read and preserved. The user's current instruction
explicitly supersedes the previously supplied AGENTS instructions; no additional
root/ancestor or relevant subtree override was found. The current user task,
docs/convergence.md, preparation plan/README/verification, relevant current-state
and acceptance documentation and implementation/tests define this review.

## Clean-source execution and independent closure

Tested clean source: **b5f1a0f5b72bca8f1f21555236d938501f7faee8**.
Source tree: aa7e90ba6f99d0c95a28e694bdceffb57ef94296.
The tree stayed at that revision with no tracked changes through build, tests
and all native observations; only untracked AGENTS.md/output/ were excluded.
This later documentation/evidence change is separate from the tested source.

Fresh build: build-convergence-b5f1a0f-5c4032, Windows x64 Release,
VS 2022/MSVC 19.44.35227.0, CUDA 13.4/nvcc 13.4.92, architecture 89.
CUDA/OpenMP ON, CPU tools OFF, testing ON; CUB 300403, --fmad=false and
/Zc:preprocessor retained. Actual discovery was **16 CTests; 16/16 passed**.
The local focused suite passed **87 checks** again from clean source, with
mocked native output only. Regressions are separate from native campaign runs.

The native campaign completed exactly **25/25 new processes**, 12 full-device
and 13 hybrid, with zero failed/start-error/timeout attempts. Both values per
process were retained: **50 new VaR estimates**. The keys exactly match the
fixed missing matrix. No existing CPU, singleton GPU or 10M acceptance campaign
observation was re-executed. Regression-suite invocations are not campaign
observations and are excluded from all seed groups.

Hybrid requested batch=65535. Effective batch/count is 10000/1 at N=10000,
65536/2 at N=100000, 65536/16 at N=1000000; reused 10M metadata is 65536/153.
All native metadata was verified without coercion. Diagnostics and profiling
were OFF for the campaign; no profiler or timing campaign was launched.

Final merged coverage is **80/80 unique engine/mode-N-seed observations and
160/160 VaR estimates**, with 5 seeds in each of 32 engine/mode-N-alpha groups.
The 55 prior observations retain original source/build/executable bindings.
The recorder independent audit and a separate closure recomputation both
passed exact coverage, uniqueness, model/calibration, analytical references,
statistics, process/raw-output/binding and eight 10M acceptance checks.
All 122 original campaign-directory files remained byte-for-byte unchanged
during closure; no native process was repeated for auditing.

Actual recording window, including build/preflight:
2026-10-19T22:10:55.6868984Z through 2026-10-19T22:12:37.5522785Z
(2026-10-20 in Europe/Istanbul). The process records retain actual per-attempt
timestamps. NVIDIA query: RTX 4060 Laptop GPU, driver 610.88, reported 8188 MiB.
Power/thermal conditions and thermal equilibrium were not measured. No
performance comparison is inferred from incidental raw engine time fields.

## Complete numerical convergence summaries

The table displays rounded absolute errors of the five-seed mean, followed by
sample standard deviations across seeds (n-1). Full-precision mean, signed and
absolute error, relative error, error/V0, MAE and RMSE are in summary.csv and
analysis.json. MAE/RMSE and seed variation are descriptive, not acceptance.

| Engine/mode | N | Abs mean error .95 | Abs mean error .99 | Seed SD .95 | Seed SD .99 |
| --- | --- | --- | --- | --- | --- |
| serial | 10000 | 0.083904651 | 0.060047033 | 0.044579885 | 0.12237962 |
| serial | 100000 | 0.015659385 | 0.016590206 | 0.01244432 | 0.024209917 |
| serial | 1000000 | 0.0037610767 | 0.00089651644 | 0.0023824271 | 0.0086321523 |
| serial | 10000000 | 0.00026016023 | 0.0021369944 | 0.0015488797 | 0.0036040007 |
| openmp | 10000 | 0.012272041 | 0.0042581844 | 0.07678795 | 0.13130307 |
| openmp | 100000 | 0.0032803124 | 0.011606854 | 0.012540646 | 0.048394345 |
| openmp | 1000000 | 0.0029270075 | 0.0080410336 | 0.0090504776 | 0.0087692413 |
| openmp | 10000000 | 0.0011250589 | 0.0024793013 | 0.0022102457 | 0.0023640752 |
| full-device | 10000 | 0.0056767259 | 0.020510012 | 0.036768151 | 0.035875881 |
| full-device | 100000 | 0.0061968702 | 0.01491098 | 0.031653396 | 0.040985703 |
| full-device | 1000000 | 0.0029513327 | 0.0010704893 | 0.0078614679 | 0.0097042736 |
| full-device | 10000000 | 0.00019419435 | 0.0015684249 | 0.0014705789 | 0.0042701085 |
| hybrid | 10000 | 0.0056767259 | 0.020510012 | 0.036768151 | 0.035875881 |
| hybrid | 100000 | 0.0061968702 | 0.01491098 | 0.031653396 | 0.040985703 |
| hybrid | 1000000 | 0.0029513327 | 0.0010704893 | 0.0078614679 | 0.0097042736 |
| hybrid | 10000000 | 0.00019419435 | 0.0015684249 | 0.0014705789 | 0.0042701085 |

GPU .95 error increases from 10K to 100K, and .99 error increases from 1M to
10M in this fixture. Other nonmonotonic changes are also retained. Five seeds
and one synthetic fixture do not establish a universal/fitted convergence rate
or predictive market validity. Observed paired native GPU mode values match
here; no native sample equality or batch-invariance guarantee is inferred.

References are independently recalculated as 6.14357693941893 and
8.7154467162009155; displayed constants are not authoritative inputs. Both
absolute references exceed .01*V0 (approximately 1.004), so relative error is
available for this case. The tested near-zero policy remains N/A plus error/V0;
raw zeros and negative VaR are preserved. No figures were produced.

## Separate existing 10M acceptance

All eight engine/mode-alpha rows pass the unchanged criterion:

```text
abs(mean(VaR)-analytical_VaR) <= .01*max(abs(analytical_VaR),.01*V0)
```

Limits are 0.0614357693941893 at .95 and 0.087154467162009155 at .99.
Per-engine absolute errors at 10M are retained in the table above and in
acceptance-10m.csv. These rows reuse existing 10M observations; they are not
new 10M runs. Individual seed error, MAE or RMSE was never substituted.

## Deliverables and remaining limits

- per-seed.csv: all 160 estimates with signed/absolute/relative errors and
  source/build/executable/input provenance. Invariant round-trip numbers were
  parsed back and matched exact binary64 values for every exported metric.
- summary.csv: all 32 complete groups; acceptance-10m.csv: 8 separate rows.
- analysis.json and independent-audit.json: byte-identical copies of recorder
  outputs; closure-audit.json: separate independent recomputation and hashes of
  all 122 original campaign files.
- clean-source-focused-tests.json: exact retained clean-source 87-check report.
- delivery-manifest.json: selected output and raw hardware/recorder log hashes.

Local raw evidence remains in results/convergence-b5f1a0f-20261020-run1/,
including every attempt, raw stdout/stderr, argv/exit records, fixture, build
and source bindings. Archived builds and original ignored evidence are local
dependencies, not distributed by these selected exports. The actual source
revision is distinct from the later evidence/documentation commit.

Historical serial source-to-binary verification remains false. OpenMP lacks a
published standalone CMakeCache; the manifest/settings/build log/binary bindings
and limitation remain. Reuse spans source/build revisions and native equal
seeds imply no cross-engine/mode sample equivalence. The old preparation
82-check and selected-test reports remain historical snapshots.

There were no native failures or numerical discrepancies. The whitespace check
initially flagged preserved CRLF evidence as trailing CR; checking with
cr-at-eol passed without normalizing evidence. The obsolete OneDrive working
directory prevented the first shell launch; the actual repository and all 611
prior byte bindings were verified before source changes. No raw archive was
rewritten. AGENTS.md, output/, private data and prior evidence were preserved.

The numerical convergence checkpoint is complete for this fixed fixture.
Final figures were explicitly deferred. Bandwidth/counter permissions and the
documented laptop peak remain separate unresolved work. No push, optimization,
academic authoring or automation was performed.
