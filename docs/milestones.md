# Milestone ledger

The staged implementation separates the computational baseline, validation,
performance analysis and optional extensions. Acceptance conditions are defined
in [acceptance-source.md](acceptance-source.md). The entries below retain their
original technical checkpoint status; they are not current completion claims.

## Foundation and CPU validation

| Required outcome | Recorded state | Completion evidence |
| --- | --- | --- |
| CSV/calibration, analytical reference, serial, five-seed validation | Synthetic serial acceptance archived; local historical integration/calendar verified separately | evidence/v022-validation-20261016; scoped data rights in data-rights-and-calendar.md; not historical full-scale acceptance |
| OpenMP, common-input validation and thread scaling | Implementation, Windows correctness and CPU scaling baseline complete; limitations recorded | v0.3.0 correctness evidence plus evidence/v030-cpu-scaling-windows-20261016 |
| GPU walking skeleton through all layers | Connectivity verified early on RTX 4060; capped at N=10000 | evidence/v030-cuda-skeleton-windows-20261016: CSV, device cuRAND/CUB quantile, transfer Events and initial VRAM estimate |

The initial connectivity prototype includes host/device transfer timing and a
VRAM capacity estimate. Its scope does not establish full-scale accuracy or
performance acceptance.

OpenMP correctness was verified at source 05f982e.
Six Windows ON tests, five OFF tests, common-input agreement and 20 native
five-seed statistical runs passed. Native thread invariance checks are not
performance scaling measurements. A subsequent fresh CPU scaling campaign
at clean aa901a3 recorded all 234 processes, actual teams, verified process
affinity, topology and available power/frequency observations. Package thermal
measurements remained unavailable and are explicitly qualified. All 180 measured
runs, including slow results, remain in the baseline. The independent audit passed.
At that CPU baseline, the GPU walking skeleton had not yet started. It was
subsequently verified at clean source 8951236: all seven CUDA-on tests passed,
with 32 common-input numerical comparisons and separately labeled native
cuRAND smoke. CUB 3.4.3 is selected for the intended later GPU quantile path.
H2D/D2H Event measurements and a qualified scratch-inclusive VRAM estimate are
archived. This closes the requested connectivity task, not full-scale GPU
acceptance, profiling or performance benchmarking. That historical version retained
the N=10000 cap; the later full-device scale-up is described in cuda-skeleton.md.

## GPU evaluation and reproducibility

| Required outcome | Recorded state |
| --- | --- |
| Grow skeleton to full scale, memory/batching, GPU quantile and hybrid fallback | Implementation complete; full-device and explicit bounded-memory hybrid verified from clean source f039034; later acceptance remains separate |
| Analytical and common-input GPU validation; separate memory/race checks | Both native modes pass five-seed analytical acceptance at 8df5f28; compatible large common-input evidence reused; representative sanitizer matrix passed with documented limits (project-state.md) |
| Full benchmark campaign against serial and best OpenMP | Primary complete at 89536e3: 312 processes, 24 rows; 10x serial target not met. Separate 18-process stage diagnostics closed at 80148ce; cold-cache kernel-scope DRAM measured and independently audited; documented peak/percentage remains an evidence gap (requirements-audit.md) |
| Error and convergence analysis | Complete for the fixed synthetic fixture: 80 native observations, 160 estimates, 32 groups; version-2 figures, reproduction, historical/current provenance correction and separate 10M acceptance verified in convergence.md. Five-seed and historical provenance limits remain |
| Reproducibility package and requirements revision | Technical entry point and 18-item evidence audit verified in reproducibility.md / requirements-audit.md; local/archive/environment limitations explicit; academic baseline approval/submission unverified |

## Extensions and scope control

Profiling-driven optimization requires before/after evidence and revalidation.
Multi-asset valuation is a separate extension with an additional validation
strategy. Neither extension replaces the single-asset analytical benchmark.

Baseline reporting includes achieved DRAM GB/s and percentage of documented
GPU configuration bandwidth, with explicit metric definitions and profiling
outside timed samples. The profiled stages, aggregation and denominator must
be stated. No bandwidth-utilization threshold or GFLOPS target is imposed.

## Technical reporting

Results are associated with requirement IDs, source revisions, input checksums,
measurement scope and reproducible commands. Implementation, validation,
performance evidence and outstanding limitations are reported separately.
