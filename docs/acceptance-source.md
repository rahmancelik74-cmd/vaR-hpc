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

The checkpoint statements in this section and the supplementary section below
are retained history. The current reporting status is established by the
[interpretation audit](#documented-peak-interpretation-audit-2026-10-21).

Current 2026-10-20 supplement: fixed-fixture convergence and version-2 figures
are complete; technical reproducibility paths and FR/NFR consistency are audited
in [reproducibility.md](reproducibility.md) and
[requirements-audit.md](requirements-audit.md). The dated scope descriptions
below remain historical. Kernel-scope DRAM GB/s is now measured in the
[baseline record](../evidence/v030-dram-baseline-20261020/README.md); applicable
laptop peak and percentage remain unresolved. The unmet 10x serial target and
academic/live delivery are not closed by this technical package. No numerical criterion has changed.

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
not establish general global-memory race freedom or performance. At that
GPU-acceptance checkpoint, bandwidth reporting, convergence and
later delivery remained open. Convergence/figures and measured kernel-scope DRAM
reporting are now evidenced separately above; applicable documented peak and its
percentage remain an evidence gap. Later academic/live delivery is unverified.
Separate stage diagnostics at 80148ce are closed in
cuda-stage-diagnostics.md with their limited transfer-excluded scope. The formal
primary CPU/GPU benchmark at 89536e3 is complete;
its full-device serial speedup at N=10000000 is 9.7399305240447234x, below the
unchanged 10x target. See cpu-gpu-benchmark.md for all rows and limits. Proposal
identity is no longer pending. None establishes market predictive validity.

## Supplementary installed-device reference, 2026-10-21

The operative source wording above remains achieved DRAM GB/s and percentage
of documented GPU peak. It does not expressly settle whether first-party
software reporting an installed configuration satisfies that phrase. The new
[NVIDIA App report/reference](../evidence/v030-nvidia-configuration-reference-20261021/README.md)
therefore provides a separately labelled class-B comparison, without changing
the source criterion or asserting its peak-reporting acceptance is complete.
The actual device report gives 16.00 Gbps, 128-bit and 256.032 GB/s. Against
the last value, archived kernel-scope rates are 36.54610877595663% full-device
and 9.60865565224468% hybrid. The displayed effective rate yields 256.00 GB/s;
the 0.032 difference is compatible with rate-display rounding, not proof of an
exact hidden rate. No extra DDR factor is applied. These are configuration-
reference ratios, not sustainable peak or end-to-end utilisation. The historical
failure to locate an applicable published OEM/NVIDIA rate specification remains
unchanged; that gap and the acceptance interpretation remain open.

## Documented-peak interpretation audit, 2026-10-21

This current interpretation supersedes the unresolved acceptance status in the
dated sections above and in the immutable NVIDIA reference README published at
4a4730d0b505cc2ab31574ca96b4fc5841a3fc21. Their historical findings, original
report, calculations and hash-bound manifests remain unchanged.

The continuation reference APPROVED_PROPOSAL_SOURCE_TEXT_EN.txt was independently
read in full from the user-specified private advisor-sources directory, outside
Git. Exact-byte SHA-256:
4ae7ecae948892d08aabeb5fa21f5a473632cf90281d87b63ddfd5cc1ca46a57.
Its section 8, page 4, lines 157-158 agrees with this register's performance
criterion. The exact operative clause is:

> report achieved DRAM bandwidth in GB/s and as a percentage of the documented GPU peak, with profiler metric definitions. No fixed bandwidth utilization threshold or GFLOPS target is imposed.

The inspected extraction contains no separate published OEM datasheet condition.
It is an extracted continuation reference, not a newly authenticated signed
proposal; the earlier private DOCX identification/hashes above remain distinct.
The tracked requirements definitions, all 18 audit criterion cells and relevant
Git history likewise provide no stricter supervisor decision. No supervisor
approval of this interpretation is claimed, and uninspected correspondence is
not asserted to contain none.

The authority trail separates evidence acquisition from acceptance:

| Record | Role and finding |
| --- | --- |
| Approved proposal section 8 and this register | Documented GPU peak and profiler definitions; no publication-channel restriction |
| b9745be / 663fcc3 | Derived status/search records sought applicable OEM/NVIDIA rate evidence and correctly rejected runtime clocks; they do not add supervisor authority |
| 7e79204 / b3b67a4 | Baseline/review retained the unsuccessful published-specification search as the then-missing denominator |
| Earlier user continuation tasks | Explicitly constrained those investigations to published applicable specifications and required the class-B report to remain supplementary; task restrictions were real, but were not evidence of a supervisor amendment |
| 4a4730d | Conservatively retained an unresolved interpretation even after the authentic report was captured; that status is corrected here |

The installed-device NVIDIA report supports a documented theoretical/configuration
reference: its explicit effective rate and interface give 16.00 * 128 / 8 =
256.00 decimal GB/s without an additional DDR factor, and its directly reported
bandwidth is 256.032 GB/s. Their small difference is compatible with display
rounding. The exact hidden rate and the app's internal data source are not known.
This is a reasoned technical interpretation of the existing reporting clause,
not a change to its wording or a claim of independently certified OEM capability.
[NVIDIA's CUDA Best Practices Guide, section 9.2.1](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html#theoretical-bandwidth-calculation)
explains rate/interface theoretical bandwidth and consistent decimal units; its
example device values are not used for this laptop. Its product-literature
example does not impose a new acceptance-source restriction on this project.

Status: **satisfied within the recorded kernel scope**, using 256.032 GB/s as
the documented NVIDIA App-reported theoretical/configuration reference. The
precise comparison label is **percentage of NVIDIA App-reported configuration
bandwidth**. From archived unrounded byte/duration totals, full-device is
93.56973322125727 GB/s and 36.54610877595663%; hybrid is 24.60123323955511 GB/s
and 9.60865565224468%. Metric definitions, 14/307 launches, matching numerator/
denominator scope and original validation remain in the
[DRAM review](../evidence/v030-dram-review-20261020/README.md) and
[NVIDIA reference](../evidence/v030-nvidia-configuration-reference-20261021/README.md).

These are cold-cache N=10000000/seed42 aggregate collected-kernel measurements,
excluding transfers and host costs. The reference report postdates the profiles;
it is not contemporaneous workload clock telemetry. Shared-resource traffic and
zero hybrid write-counter caveats remain. No sustainable peak, end-to-end
utilisation, universal capability or bandwidth threshold is claimed. No separate
applicable published OEM specification was located; that historical search
limitation remains, but obtaining one is optional corroboration rather than a
mandatory blocker under the inspected criterion. All numerical criteria, unmet
performance targets, provenance/sanitizer limits and unverified academic/live
delivery remain unchanged.
