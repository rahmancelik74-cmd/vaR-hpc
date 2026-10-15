# Acceptance source register

Imported on 2026-10-15 from Capstone_Project_Proposal_Form_Revised.docx,
section 8, page 4. The file was read in full from the current stored copy.
Its supervisor decision boxes are unmarked. The roadmap says a revised proposal
was approved, but does not uniquely identify this file. Therefore these are
documented candidate conditions, pending confirmation of the approved version.
Do not substitute earlier conversational suggestions for the source conditions.

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
- Report Tserial/TGPU, TOpenMP/TGPU and scenarios/s.
- 10x GPU speedup over serial at 10 million is a target, not guaranteed.
  Also report whether GPU beats the best measured OpenMP configuration.
- Primary timing excludes shared loading/calibration and includes per-run
  allocations, RNG initialization/generation, simulation, quantile, required
  transfers and synchronization. Report device stages with CUDA Events.
- Profile separately. Source text requests achieved DRAM GB/s and percentage of
  documented peak, with metric definitions; no bandwidth threshold or GFLOPS goal.

The later roadmap separates Plan B profiling-driven optimization from Plan A.
Confirm how the proposal bandwidth/profile reporting fits this distinction.
Do not remove it from the requirements without resolving the source conflict.

## Current evidence limitation

The archived serial runs cover all four N values and five seeds for one
synthetic calibration case. They do not validate OpenMP/CUDA and are not the
formal warm-up/repetition benchmark. Formal acceptance remains pending source
confirmation and complete engine evidence.
