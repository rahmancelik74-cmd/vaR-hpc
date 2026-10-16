# Milestone ledger

Source: supervisor Plan A / Plan B v2.0, dated 2026-10-14.
Week numbers follow the academic plan, not a guessed mapping from calendar dates.
Implemented later-week code does not by itself close unfinished foundation work.

## First term shared by both plans

| Weeks | Required outcome | Current state | Completion evidence |
| --- | --- | --- | --- |
| 1-4 | Topic, proposal revision and roadmap | Roadmap records revised proposal approval | Identify the exact approved proposal file |
| 5-6 | Conventions, hardware/toolchain inventory, CMake/repository/CI, Requirements and Design v1.0 | In progress | One repository, actual CI result, complete inventory and uploaded document |
| 7-9 | CSV/calibration, analytical reference, serial, five-seed validation | Software and synthetic runs available; milestone not closed | Data provenance, acceptance-source confirmation and archived validation evidence |
| 10-11 | OpenMP, common-input validation and thread scaling | Implementation, Windows correctness and CPU scaling baseline complete; limitations recorded | v0.3.0 correctness evidence plus evidence/v030-cpu-scaling-windows-20261016 |
| 12-13 | GPU walking skeleton through all layers | Not started | CSV to VaR using cuRAND/device quantile and shared interface, N=10000 |
| 14 | CPU demonstration and interim report | Not started | Live validated CPU demo, timing output and interim report |

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
The GPU walking skeleton remains a later milestone; it was not started here.
This early software result does not close the unfinished weeks 5-6 or 7-9 items.

## Second term Plan A

| Weeks | Required outcome | State |
| --- | --- | --- |
| 1-5 | Grow skeleton to full scale, memory/batching, GPU quantile and hybrid fallback | Pending |
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

The revised proposal also names profiling and DRAM bandwidth reporting. Its
relationship to the later Plan A/B split needs explicit reconciliation; do not
erase proposal success conditions or silently make Plan B mandatory.

## Reporting discipline

Before each meeting, report completed work, evidence, requirement IDs, blockers
and the next two weeks. Upload at least 24 hours before the meeting and prepare
approximately ten minutes of presentation, using the STIX templates.
Write the conceptual material once in the requirements document and reuse it
in the technical report. Keep results as work proceeds rather than writing
the entire report in the final two weeks.
