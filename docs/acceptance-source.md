# Acceptance source register

Imported on 2026-10-15 from Capstone_Project_Proposal_Form_Revised.docx,
section 8, page 4. The file was read in full from the current stored copy.
The initial approval-identity uncertainty was resolved by the student's
2026-10-16 identification of this file as the approved proposal, recorded in
project-state.md. Its supervisor decision boxes remain unmarked; no signed
approval or submission receipt is inferred from that identification.

On 2026-10-18, the proposal and both v2.0 roadmaps dated 2026-10-14 were read
directly from the existing Downloads copies, including document-body tables.
This comparison uses those sources, not just the repository summaries. Exact-byte
SHA-256 values identify the reviewed private files; the documents remain outside Git:

| Source filename | SHA-256 |
| --- | --- |
| Capstone_Project_Proposal_Form_Revised.docx | 82719610500f74bab3d954a6da385678c8987e7ec864a9161f1fcd10b01bf7f9 |
| Roadmap_Abdurrahman_Celik_GPU_MonteCarlo_PlanA.docx | e9babe946e866049270abcb8f694460bf39a15db7a937fbddf547402440b3197 |
| Roadmap_Abdurrahman_Celik_GPU_MonteCarlo_PlanB.docx | 19121d399982438a86a91090fd7c85ef3f814f8b2992099c6f2030b717e82517 |

Proposal sections 5, 8 and 9 define inventory, acceptance and fallback conditions.
Plan A sets the revised schedule and explicitly retains proposal success/risk
conditions. Approval identity is reported history; source contents were inspected
in this audit. Do not substitute conversational suggestions for source conditions.

## Statistical correctness

For each engine, a non-degenerate documented single-asset GBM case, N=10000000,
five independent seeds, at alpha=0.95 and alpha=0.99:

abs(mean(VaR_estimates) - analytical_VaR)
<= 0.01 * max(abs(analytical_VaR), 0.01 * initial_value).

Report per-seed values and convergence as N increases. This is a project target,
not a universal Monte Carlo error guarantee. It is not a requirement that each
individual seed pass the same threshold, and not mean(abs(error)).

## Cross-engine numerical validation

Common pre-generated normal samples, double precision and identical quantile
convention: absolute VaR difference <= 0.00001 * initial_value.
Check memory/concurrency separately; matching a quantile does not prove no race.

## Performance experiment

- N=100000,1000000,10000000, identical model and precision.
- OpenMP sweep 1,2,4,... up to physical-core count, including that count.
  On the current 10-core CPU start with 1,2,4,8,10; record placement.
- Three warm-ups, ten timed repetitions/configuration; mean and standard deviation.
- Report Tserial/TGPU, Tbest-measured-OpenMP/TGPU and scenarios/s, at each N.
- 10x GPU speedup over serial at 10 million is a target, not guaranteed.
  Also report whether GPU beats the best measured OpenMP configuration.
- Primary timing excludes shared loading/calibration and includes per-run
  allocations, RNG initialization/generation, simulation, quantile, required
  transfers and synchronization. The implemented engine boundary also includes
  temporary-resource cleanup. Report device stages with CUDA Events, separately
  from primary host wall time. Plan A also requests transfer-excluded figures;
  label their device-stage scope rather than treating them as end-to-end speedup.
- Profile separately. Source text requests achieved DRAM GB/s and percentage of
  documented peak, with metric definitions; no bandwidth threshold or GFLOPS goal.

Plan A retains the proposal's baseline reporting: achieved DRAM GB/s and
percentage of documented GPU peak, with profiler metric definitions, collected
outside timed repetitions. Plan B adds targeted profiling-driven optimization
and before/after evidence. The latter remains optional; baseline reporting is
not removed. Before term-two measurements, specify the profiled stages,
aggregation and documented peak basis. These reporting details do not authorize
an optimization campaign or impose a bandwidth/GFLOPS acceptance threshold.

## Established numerical and timing conventions

The proposal requires consistent documented conventions, rather than specifying
every formula below. The implemented contract uses double precision, positive
long holding V0=q*S0, exact terminal GBM, loss V0-VT and retained negative VaR.
Ascending loss rank is ceil(alpha*N)-1, zero-based, without interpolation.
The analytical terminal-price quantile is 1-alpha. With log-return mean m,
sample variance s2 (n-1 denominator) and observation interval dt in years,
sigma=sqrt(s2/dt) and annual price drift mu=m/dt+0.5*sigma*sigma.

Per-run host timing excludes shared input/calibration and output but includes
allocation, RNG, simulation, global quantile, necessary transfers,
synchronization and cleanup. Current CLI samples are fresh processes; the CUDA
skeleton includes context/API initialization. Future comparison campaigns must
state context policy. Warm-ups are excluded and do not establish thermal equilibrium.

## Current evidence limitation

Serial evidence at 33102c4 covers four N values and five seeds for one synthetic
calibration case (evidence/v022-validation-20261016). Separate OpenMP correctness
evidence at 05f982e includes five-seed error-of-mean acceptance and common inputs
(evidence/v030-openmp-windows-correctness-20261016). The CPU scaling baseline at
aa901a3 is separate performance evidence (evidence/v030-cpu-scaling-windows-20261016).
CUDA evidence at 8951236 is capped connectivity/common-input smoke, not full-scale
five-seed acceptance (evidence/v030-cuda-skeleton-windows-20261016). Later clean
source 8df5f28 separately passes both full-device and fixed-partition hybrid
five-seed analytical acceptance, reuses compatible f039034 large common-input
evidence, and passes representative sanitizer checks. Exact records and coverage
limits are in project-state.md and gpu-acceptance.md; numerical acceptance does
not establish general global-memory race freedom or performance. Full project
acceptance still needs bandwidth reporting, convergence and later delivery
evidence. Separate stage diagnostics at 80148ce are closed in
cuda-stage-diagnostics.md with their limited transfer-excluded scope. The formal
primary CPU/GPU benchmark at 89536e3 is complete;
its full-device serial speedup at N=10000000 is 9.7399305240447234x, below the
unchanged 10x target. See cpu-gpu-benchmark.md for all rows and limits. Proposal
identity is no longer pending. None establishes market predictive validity.
