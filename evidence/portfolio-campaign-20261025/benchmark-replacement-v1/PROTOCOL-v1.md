# Portfolio statistical validation and benchmark protocol v1

Frozen before observing any campaign results; protocol-v1.json is the executable
matrix and contains exact fixture hashes. The freeze ledger records exact-byte
SHA-256 of both protocol files, UTC time, baseline and fixture hashes. No pilot.
This separate P-V1/P-V2/P-V3/P-B1 register is an extension experiment, not a
supervisor requirement or modification of FR-1..FR-9/NFR-1..NFR-9.

## Independent reference and checks

Original two-asset (+0.6 correlation) and five-asset (identity) fixtures, plus
two-asset -0.6 correlation; original quantities/parameters/horizons preserved.
Independent CPU Python uses installed NumPy/SciPy, PCG64DXSM seeds disjoint from
production settings, explicit two-dimensional factor or identity, and terminal
prices summed before subtracting from V0. No production Cholesky, RNG, loss or
quantile helper is called. All arrays use float64. A checked 20M-double file
per fixture stores scalar losses; chunks of 250000 bound transient memory.
Sort the entire loss file and use NumPy quantile(method='inverted_cdf'). Never
average chunk VaRs. Maximum scalar storage is 160 MB/fixture, 480 MB total on
disk; no full reference N*A matrix. No escalation beyond 20M: inadequate
reference precision is inconclusive, not justification for indefinite runs.

Validate the oracle before confirmatory runs: one-asset analytical GBM quantile,
zero horizon/volatility and negative VaR, hand-derived small two-asset terminal
scenarios, reconstruction of the known factor, and exact portfolio first/second
moments. Reference raw moments through fourth order independently expand the
multivariate lognormal MGF. Moment smoke uses disjoint seed 778899, N=100000,
Chebyshev/Bonferroni family .01 over six mean/second-moment checks. It is an
oracle prerequisite, not native engine statistical acceptance.

## Uncertainty, multiplicity and decisions

For continuous losses and ideal iid standard normals, F(X_(k)) has distribution
Beta(k,N+1-k), k=ceil(alpha*N). Every production seed uses its actual native RNG.
As usual, PRNG outputs model iid samples; seeds are fixed settings, not a theorem
of physical randomness. Streams may be related across N for the same seed;
Bonferroni bounds do not require comparisons to be independent.

Total simultaneous error budget .01: .0025 for six reference quantile intervals,
.0025 for three reference uniform empirical CDF bounds, .005 for 270 native
order statistics (3 fixtures * 3 engines * 3 N * 5 seeds * 2 confidence levels).
For each reference quantile let delta=.0025/6 and B~Binomial(M,alpha). Lower
one-based rank is max(1,binom.ppf(delta/2,M,alpha)); upper is
min(M,binom.ppf(1-delta/2,M,alpha)+1). Report actual binomial coverage. Thus
uncertainty in the high-N reference is retained rather than treated as zero.

Uniform reference CDF error is epsilon=sqrt(log(2/(.0025/3))/(2*M)) by the
two-sided DKW-Massart inequality. For any native quantile qhat, compare the
reference empirical CDF at qhat to the Beta central bounds with per-comparison
tails .005/(2*270), expanded by epsilon. An outside value rejects distributional
consistency; inside means **not rejected**, not equivalence or correctness proof.
This is a calibrated probability-scale test, not overlap of two value intervals.

Separately, practical numerical target is 5 basis points of initial capital:
t=.0005*V0, chosen as an absolute loss-valuation resolution for these examples,
not the old 1%-of-single-asset-VaR condition. For each realized five-seed mean m
and reference interval [L,U], worst error=max(|m-L|,|m-U|). Pass if worst<=t;
fail if distance(m,[L,U])>t; otherwise inconclusive. If interval half-width>t/2,
force reference-precision inconclusive. This bounds the error of the **observed
five-seed mean**, not the expectation of the estimator across unobserved seeds.
N=10M is the confirmatory practical endpoint; lower N results are diagnostics.
Report every seed, signed/absolute error, sample SD, reference CI and outcomes.
No monotonicity requirement or universal rate is inferred from three N values.

## Formal portfolio timing

Only original two/five-asset fixtures. N=100000/1000000/10000000; serial,
OpenMP 1/2/4/8/10 and CUDA full-device. No hybrid. Each cell has 3 excluded
fresh-process warm-ups and 10 measured fresh processes: 546 total, 420 measured.
Warm-ups precondition machine/OS caches; they do not reuse CUDA contexts.
Use the exact existing engine timer with scope/process/order/power policies in
protocol-v1.json. No profiling, reference computation or sanitizer work overlaps
timed runs. Record all successful slow values. On interruption/resource/condition
failure stop, preserve attempts; one complete new-directory replacement maximum,
with reason. Never replace isolated inconvenient samples. Unobserved physical
conditions and CPU temperature remain unknown. Do not alter power settings.

Report all 42 rows, mean, sample SD, scenarios/s, Tserial/Tconfig and
TbestOpenMP/Tconfig. Select best OpenMP separately for each fixture/N. Two and
five assets do different work per scenario; compare only like workloads. No 10x
portfolio goal, performance improvement or historical single-asset ratio reuse.

## Sources and reproduction

Installed runtime identities and exact source/build/input hashes are recorded
before execution. Production source remains unchanged; tooling dirty state is
explicit. Fresh build trace is an observed provenance binding, not an independent
binary reproducibility proof. Local exact-byte hashes and Git-normalized blob
hashes are labelled separately.

Reference methods: [NumPy quantile](https://numpy.org/doc/1.24/reference/generated/numpy.quantile.html),
[PCG64DXSM](https://numpy.org/doc/1.24/reference/random/bit_generators/pcg64dxsm.html),
[SciPy beta](https://docs.scipy.org/doc/scipy-1.10.1/reference/generated/scipy.stats.beta.html),
[SciPy binomial](https://docs.scipy.org/doc/scipy-1.10.1/reference/generated/scipy.stats.binom.html),
and [Massart (1990), two-sided DKW bound](https://doi.org/10.1214/aop/1176990746).
Order-statistic beta/binomial statements follow by counting observations below
the population quantile. Fixed statistical allocations above precede outcomes.
