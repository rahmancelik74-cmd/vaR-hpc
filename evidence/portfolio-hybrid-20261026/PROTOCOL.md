# Portfolio hybrid protocol PH-1 (frozen before execution)

Separate extension; FR-1..FR-9/NFR-1..NFR-9 and old evidence unchanged.
Common-input absolute tolerance is 1e-10*portfolio V0 (unchanged P-T1),
stricter than 1e-5*V0. No threshold changes or seed search after execution.
Matrix A=1,2,3,5; N=1,11,12,255,256,257; B=1,2,3,4,11,256,999.
Compare serial/full-device/hybrid with deterministic finite independent normals;
check all metadata/accounting and caller preservation. Extra rho=-0.3 for A=3,
T=0, sigma=0 with negative VaR, repeated .95/.99, one-asset reduction,
explicit independent terminal-price oracle and a 100-scenario global-quantile
trap. Invalid counts, batches, common dimensions/nonfinite, overflow and
recovery; checked arithmetic/resource guard exercised without forced exhaustion.
Native repeated identical settings must be exact within the same build.
Test-only independent cuRAND payload concatenation validates padding/indexing
against CPU valuation; it is not a distributional oracle.

Bounded native distributional check: original synthetic two-positive and
two-negative fixtures from evidence/portfolio-campaign-20261025/fixtures.
N=1000000, hybrid B=65535, native seeds 2026102601/2026102602 respectively.
Independent NumPy PCG64DXSM standard-normal reference N=1000000, seeds
2026102691/2026102692 respectively; use existing portfolio_campaign.fixture
and terminal (explicit two-dimensional transform and terminal-price valuation).
No old random reference acceptance is reused. At each native .95/.99 VaR,
compare reference empirical loss CDF to alpha: absolute difference <=
2*sqrt(log(2/.0025)/(2*1000000))+1/1000000.
Four uniform DKW events (two native and two reference empirical CDFs), each
failure probability .0025, give >=99% family coverage under ideal iid assumptions,
including both alpha values without further spending; reference thresholds may
be data-dependent because the reference bound is uniform. PRNG independence
is assumed. This tests bounded native distributional consistency only; no
.0005*V0 practical target, universal acceptance or convergence study.
One attempt per fixture; keep failures, no adaptive N/seeds/tolerances.

Run actual local serial/OpenMP/CUDA CTests, focused memcheck/racecheck on the
portfolio hybrid executable (small matrix, not capacity/statistical modes).
Run native five-asset N=10000000 B=65535 seed=42 once, diagnostics enabled;
capacity/integration only, no benchmark. Record explicit allocation bytes and
live free-memory snapshots (not peaks). Private existing historical calibration
reuse after exact original inventory hash checks, N=10003 seed=42 B=257;
verify asset order, unit, model metadata and mode, keep private values ignored.
All timings illustrative. Fresh CLI processes include context setup; primary
wall time includes allocation/RNG/simulation/transfers/global sort/sync/cleanup,
excludes shared calibration/Cholesky and final output. No academic artifact.
