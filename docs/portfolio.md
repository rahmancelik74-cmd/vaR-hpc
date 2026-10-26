# Optional synthetic portfolio extension

The [historical calibration extension](portfolio-calibration.md) now supplies
portfolio-v1 from validated, aligned real equity imports. Its separate PC register
does not alter engine contracts or the historical synthetic campaign criteria.
Actual local integration and delivery limitations are recorded in
[the new evidence summary](../evidence/portfolio-calibration-20261026/README.md).
Portfolio hybrid remains unsupported.

The [targeted reference precision follow-up](../evidence/portfolio-precision-20261025-v1/README.md)
completed two new fixed 80M references. All twelve reused two-asset N=10M
realized-five-seed-mean endpoint rows pass the unchanged .0005*V0 target under
the new four-interval 99% reference family. Numerical conditional integration
corroborates the intervals but is not certified error control. Original 9/18
pass, 9/18 inconclusive and all six five-identity passes remain historical and
unchanged; no combined 99% claim is made. Engines and their observations did
not change. Historical calibration and portfolio hybrid remain future work.

This extension is separate from Plan A and all existing FR-1..FR-9/NFR-1..NFR-9
criteria. No market data, advisor approval or academic delivery is implied.

The subsequent [portfolio campaign](portfolio-campaign.md) evaluates independent
native-RNG VaR/convergence and formal portfolio timing under a separately frozen
protocol. Its finite-fixture outcomes include inconclusive practical targets;
it does not establish universal portfolio VaR statistical acceptance. The initial
validation and published implementation records below remain historical.

## Contract and extension register

P-1: Validate 1..5 unique assets (2..5 for multi-asset use), positive finite
quantities/prices, finite annual price drifts, finite nonnegative volatilities,
one finite horizon T >= 0, and one explicit common valuation unit. No FX,
shorts, rebalancing, calibration, time stepping or historical alignment.

P-2: Correlation entries must be finite and in [-1,1], diagonal within 1e-12
of one, and symmetry within absolute 1e-12. Standard lower Cholesky uses the
supplied lower triangle, without changing any input entries; reconstruction
C*C^T must match every original entry within 2e-12. This comparison also
checks discrepancies accepted by the symmetry tolerance. No averaging,
regularization, clipping or diagonal replacement occurs. Every squared pivot
must exceed 1e-14: a conservative numerical-singularity guard, about 45 double
epsilons at unit scale. The 1e-12 entry tolerance allows decimal serialization
roundoff while being much smaller than meaningful model correlations. Some
positive-definite near-singular inputs are deliberately unsupported; singular
positive-semidefinite matrices can be valid statistical models but are outside
this standard-Cholesky implementation. Indefinite matrices are invalid.

P-3: R=C*C^T; Z=C*epsilon, independent standard normal epsilon. For each asset,
v_i=q_i*S_i(0), VT_i=v_i*exp((mu_i-sigma_i^2/2)*T+sigma_i*sqrt(T)*Z_i).
V0=sum(v_i), VT=sum(VT_i), loss=V0-VT. The implementation sums
-v_i*expm1(exponent) to avoid cancellation. Sort the complete scalar portfolio
loss sample ascending; rank ceil(alpha*N)-1, no interpolation or zero clipping.
Only 0.95 and 0.99 are supported (1..16 requested entries). General portfolio
analytical VaR and signed
analytical errors are explicitly unavailable/null; individual asset VaRs are
never added. The old single-asset formula and contract are unchanged.

P-4: Engine::run uses optional borrowed Request::portfolio; null preserves
single-asset behavior. Common normals are caller-owned, read-only, finite,
exactly N*A doubles, scenario-major: common[s*A+i]. They bypass native RNG.
Native serial uses mt19937_64/normal_distribution; OpenMP retains fixed 4096
scenario blocks with SplitMix64 block seeds and private generators. Assets
are consumed in input order per scenario. CUDA generates N*A normals on device
using PHILOX normal-double, padding only the final odd count. Equal seeds across
backends, modes or layouts do not imply equal samples. OpenMP native results
are invariant across thread counts within the same build.

P-5: All portfolio backends accept N=1..10000000 subject to checked allocation
and available resources. CUDA supports full-device only; hybrid is explicitly
rejected for portfolios and retained for single assets. Native CUDA allocates
no host N*A matrix; device normals, scalar losses, sorted losses and CUB scratch
are included in the existing 80%-free explicit-memory preflight. No automatic
fallback. CUB remains 3.4.3 on the reference toolchain.

## Input and commands

Whitespace-delimited ASCII, no comments or trailing tokens:

```text
portfolio-v1 USD 1.0 2
ALPHA 2 100 0.05 0.20
BETA 3 80 0.03 0.30
1 0.6
0.6 1
```

Header: version, common unit, horizon years, asset count. Then ordered rows:
ID, quantity, initial price, annual price drift, annual volatility. Finally A*A
correlations in exactly that asset order, row major. Tokens for IDs/unit contain
only ASCII letters, digits, underscore, period or hyphen. Fixtures are original
synthetic redistributable examples, not historical observations.

```powershell
.\build-portfolio-ninja-cuda\mc_var.exe --portfolio data/portfolio-two.txt 100003 42 --backend serial --json
.\build-portfolio-ninja-cuda\mc_var.exe --portfolio data/portfolio-two.txt 100003 42 --backend openmp --threads 10 --json
.\build-portfolio-ninja-cuda\mc_var.exe --portfolio data/portfolio-two.txt 100003 42 --backend cuda --cuda-mode full-device --cuda-diagnostics --json
```

Build as in reproducibility.md with new build directories; CUDA reference:
`cmake -S . -B build-portfolio-cuda -G "Visual Studio 17 2022" -A x64 -T cuda=13.4 -DMC_ENABLE_CUDA=ON -DMC_ENABLE_OPENMP=ON -DCMAKE_CUDA_ARCHITECTURES=89`.
Then `cmake --build build-portfolio-cuda --config Release --parallel` and
`ctest --test-dir build-portfolio-cuda -C Release --output-on-failure`.

The actual local validation used Ninja from an existing VS x64 developer
environment because VS generator SDK enumeration hit a user-directory access
restriction. No permission or SDK configuration was changed. Equivalent configure:
`cmake -S . -B build-portfolio-ninja-cuda -G Ninja -DCMAKE_BUILD_TYPE=Release -DMC_ENABLE_CUDA=ON -DMC_ENABLE_OPENMP=ON -DCMAKE_CUDA_ARCHITECTURES=89`;
then `cmake --build build-portfolio-ninja-cuda --parallel 4` and
`ctest --test-dir build-portfolio-ninja-cuda --output-on-failure`.
The independent moment test needs Python 3; CMake registers it when an interpreter
is found. Use `-DPython3_EXECUTABLE=<existing-python-path>` when needed and inspect
the test list. There is no new runtime dependency for the application.

JSON records the input asset order/parameters/unit, matrix and factor convention,
backend/RNG/seed/N, thread metadata, CUDA resource and stage metadata. Shared
parsing, validation and Cholesky preparation are outside primary engine timing;
allocation, native RNG, simulation, global quantile, transfers, synchronization
and cleanup are inside. Fresh CLI processes use the existing process/context
policy; diagnostic Events are separate from primary wall time. Illustrative
timings are not formal benchmarks.

## Predeclared validation protocol

P-T1 structural tests: known C=[[1,0],[0.6,0.8]], reconstruction, wrong-transpose
sensitivity, invalid dimensions/identities/parameters, nonfinite entries,
asymmetry, nonunit diagonal, bounds, singular and indefinite matrices.
Deterministic T=0 and sigma=0, zero shocks, overflow and common ownership/count.
One-asset common-input reduction also compares the established analytical VaR.
Small explicit 2-asset losses use independently calculated terminal prices.
Common-input backend tolerance: absolute 1e-10*portfolio V0 for each quantile
(and independent small scenario losses). This allows CPU/GPU exp rounding,
is stricter than the unchanged single-asset 1e-5*V0 criterion, and is not a
statistical error bound. Exercise A=1,2,3,5, N=1,17,257,4097,10003; OpenMP
threads 1,2,4,8,10; CUDA odd-normal padding and partial final launch blocks.
Native capacity smoke: A=5, N=10000000, each backend, not statistical acceptance.

P-T2 independent uncertainty checks (declared before execution): N=200000,
seed 20261025, identity and equicorrelations +0.6/-0.3 for three assets.
The independent oracle uses the multivariate lognormal MGF, without production
Cholesky/valuation. A C++ test probe feeds its seeded mt19937_64 standard normals
through the production transform and valuation and reports sample moments.
This tests the transform/valuation, not moments of each native backend RNG.
Normal mean and second/cross moments
are tested with Chebyshev bounds at family alpha=0.01, Bonferroni over all
33 predeclared assertions. For Gaussian shocks Var(Z_i)=1, Var(Z_i^2)=2,
Var(Z_i*Z_j)=1+rho^2. These check standardized shock covariance/correlation
structure, not terminal-price correlation. Portfolio E[VT] and E[VT^2] use
the exact multivariate lognormal raw-moment formula. Uncertainty is computed
from exact moments through order four: Var(VT) and Var(VT^2). Chebyshev bounds
remain valid for the skewed distribution without assuming asymptotic normality.
Deterministic zero variance uses direct numerical comparison. These bounds are
conservative; they are structural/moment checks, not universal portfolio VaR
accuracy or a high-sample convergence acceptance campaign. Existing single-asset
five-seed acceptance is not applied to general portfolios.

The oracle independently expands exact lognormal moments. In particular:

```text
E[VT] = sum_i v_i*exp(mu_i*T)
Var(VT) = sum_i sum_j v_i*v_j*exp((mu_i+mu_j)*T)
          * (exp(R_ij*sigma_i*sigma_j*T)-1)
```

The checker also reports sample Pearson shock correlations and unbiased terminal
portfolio variance with conservative bounds derived from the same simultaneous
33 events, without extra confidence spending. These derived bounds introduce no
new acceptance threshold. Arithmetic overflow, underflow to a zero initial
holding, unavailable backends and unsupported modes fail explicitly.

Actual local outcomes and tool coverage are recorded separately after execution.

## Local outcome: 2026-10-25

Windows x64 Ninja Release: serial-only 16/16 CTests, CPU/OpenMP 17/17, and
CUDA/OpenMP 20/20 passed on the final source. CPU-only configurations kept CUDA
OFF and did not discover a Toolkit. Independent 33 moment assertions passed;
22 retained Python regressions and selected historical evidence integrity passed.
Common-input checks covered A=1/2/3/5 and the declared scenario/thread sweep.
Each native backend also completed the original five-asset fixture at N=10000000,
seed 42. CUDA used 50000000 device-generated normals and 642676259 explicit
device bytes, including CUB workspace. This is a capacity smoke, not statistical
acceptance or a benchmark. No general portfolio VaR convergence guarantee follows.

Compute Sanitizer 2026.3.0.0 memcheck on the focused portfolio test executable
reported 0 errors and 0 leaked bytes; racecheck reported 0 displayed hazards.
Coverage includes small native/common paths, odd counts, partial launch blocks,
overflow/error cleanup and all declared asset counts. Racecheck concerns shared
memory hazards; no general global-memory race-freedom claim follows. Serial
MSVC AddressSanitizer portfolio/core checks passed 2/2 with /EHsc enabled.
No OpenMP host race detector or 10M sanitizer coverage is claimed. Hardware,
toolchain, exact-byte source/binary/cache/log hashes and actual output are in the
[extension evidence](../evidence/portfolio-extension-20261025/README.md).

## Published implementation and hosted CI

The implementation was subsequently committed and published as
[f0b887819976ff0b579acc1a308991177f05aeda](https://github.com/rahmancelik74-cmd/vaR-hpc/commit/f0b887819976ff0b579acc1a308991177f05aeda).
Its [exact-SHA CI run 40136758943](https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/40136758943)
completed successfully. The actual hosted jobs were `cpu (OFF)` and `cpu (ON)`
on Ubuntu, plus `windows-instrumentation` on Windows. The Ubuntu jobs built and
ran CTest with CUDA disabled, with OpenMP OFF/ON respectively, and ran offline
provenance/integrity checks. The Windows job ran CPU recorder smoke,
instrumentation and retained engine tests. Hosted CI did not execute CUDA.
The Windows/OpenMP/RTX results above remain separate local validation evidence.

The unchanged [original evidence package](../evidence/portfolio-extension-20261025/README.md)
and its [validation summary](../evidence/portfolio-extension-20261025/validation-summary.json)
describe their preparation time, when the executor could not create
`.git/index.lock` and delivery was blocked. Their failure records, raw logs and
hashes are preserved; those historical statements are superseded for current
delivery status by the published commit and CI links above. Publication and
CPU CI do not establish general portfolio VaR statistical acceptance, a formal
performance result, wider sanitizer coverage, advisor approval or academic delivery.
