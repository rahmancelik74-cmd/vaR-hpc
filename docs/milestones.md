# Milestone ledger

Source: supervisor Plan A / Plan B v2.0, dated 2026-10-14; original Downloads
copies directly reviewed on 2026-10-18. File hashes and source provenance are in
[acceptance-source.md](acceptance-source.md).
Week numbers follow the academic plan, not a guessed mapping from calendar dates.
Implemented later-week code does not by itself close unfinished foundation work.

## First term shared by both plans

| Weeks | Required outcome | Current state | Completion evidence |
| --- | --- | --- | --- |
| 1-4 | Topic, proposal revision and roadmap | Roadmap records revised proposal approval; student identified the Revised file on 2026-10-16 | Source identity reconciled in acceptance-source.md; no submission receipt inferred |
| 5-6 | Conventions, hardware/toolchain inventory, CMake/repository/CI, Requirements and Design v1.0 | In progress | One repository, actual CI result, complete inventory and uploaded document |
| 7-9 | CSV/calibration, analytical reference, serial, five-seed validation | Synthetic serial acceptance archived; local historical integration/calendar verified separately | evidence/v022-validation-20261016; scoped data rights in data-rights-and-calendar.md; not historical full-scale acceptance |
| 10-11 | OpenMP, common-input validation and thread scaling | Implementation, Windows correctness and CPU scaling baseline complete; limitations recorded | v0.3.0 correctness evidence plus evidence/v030-cpu-scaling-windows-20261016 |
| 12-13 | GPU walking skeleton through all layers | Connectivity verified early on RTX 4060; capped at N=10000 | evidence/v030-cuda-skeleton-windows-20261016: CSV, device cuRAND/CUB quantile, transfer Events and initial VRAM estimate |
| 14 | CPU demonstration and interim report | Offline synthetic demo ready; live demonstration and interim delivery not verified | synthetic-demo.md and local calendar/demo test logs; no live demo or submission claim |

The 12-13 week skeleton includes host/device transfer timing and a VRAM capacity
estimate. No accuracy/performance claim or optimization is required then.
If only the skeleton is late, complete it early next term and shift the block.
If the environment cannot work at all, decide with the supervisor at week 13.

OpenMP correctness was verified early, in academic week 5, at source 05f982e.
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
This early software result does not close the unfinished weeks 5-6 or 7-9 items.

## Second term Plan A

| Weeks | Required outcome | State |
| --- | --- | --- |
| 1-5 | Grow skeleton to full scale, memory/batching, GPU quantile and hybrid fallback | Full-device and explicit bounded-memory hybrid implemented; local implementation checks remain distinct from later acceptance |
| 6-7 | Analytical and common-input GPU validation; separate memory/race checks | Pending |
| 8-10 | Full benchmark campaign against serial and best OpenMP | Pending |
| 11-12 | Error and convergence analysis | Pending |
| 13 | Reproducibility package and requirements revision | Pending |
| 14 | Final demonstration and technical report | Pending |

## Plan B and scope control

Plan B adds profiling-driven optimization with before/after evidence. The
multi-asset extension is optional, considered with the supervisor in second-term
week 11, and needs an additional validation strategy. It never replaces the
single-asset analytical benchmark. Returning to Plan A is allowed by agreement.

Plan A expressly retains the proposal's success criteria. Baseline achieved
DRAM GB/s and percentage-of-documented-peak reporting, with metric definitions
and profiling outside timed samples, remain required in term two. Plan B adds
targeted optimization and before/after evidence. Profile stage coverage and peak
basis must be specified before that later reporting; no new profiling is started
by this reconciliation. No bandwidth threshold or GFLOPS target is introduced.

## Reporting discipline

Before each meeting, report completed work, evidence, requirement IDs, blockers
and the next two weeks. Upload at least 24 hours before the meeting and prepare
approximately ten minutes of presentation, using the STIX templates.
Write the conceptual material once in the requirements document and reuse it
in the technical report. Keep results as work proceeds rather than writing
the entire report in the final two weeks.
