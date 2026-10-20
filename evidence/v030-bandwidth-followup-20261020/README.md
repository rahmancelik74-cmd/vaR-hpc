# Baseline bandwidth follow-up, 2026-10-20

Status: blocked for collection; documented theoretical peak unresolved.
Inspection base: main at 13f913ad3a2b125d3e8de2439e9f81d65ee6d622, matching
remote main. GitHub run 39353122091 was independently checked through its API:
that exact SHA passed cpu (ON), cpu (OFF) and windows-instrumentation. This is
CPU CI evidence, separate from GPU execution. Initially only AGENTS.md and
output/ were untracked; both were preserved. Root instructions were read.

## Current access and identity

One small Nsight metric-discovery process, outside benchmark timing and without
a target executable, returned ERR_NVGPUCTRPERM. Its exit code was 0; the explicit
denial is authoritative. No unchanged permission retry, elevation, settings or
driver change was attempted. No engine, simulation or kernel profiling ran.

Nsight Compute is 2026.3.1.0 build 38829034. tool-identity.json binds its exact
executable bytes, matching the earlier investigation. Read-only nvidia-smi
reports RTX 4060 Laptop GPU, driver 610.88 and 8188 MiB; Nsight identifies AD107.
The restricted registry inventory again identifies Casper G870 / NLXB 001,
SKU EXCALIBUR G870 NLXB and BIOS CQ111. The commercial configuration suffix is
still unknown. No serial, UUID or machine name was collected for publication.
Current memory clock 405 MHz and reported maximum 8001 MHz are telemetry only,
not documented effective memory data rate or evidence of workload clocks.

Exact argv, timestamps, exit status and raw stdout/stderr are selected here.
Original process records and check logs remain under
results/bandwidth-followup-13f913a-20261020. The discovery command was:

```powershell
& 'C:/Program Files/NVIDIA Corporation/Nsight Compute 2026.3.1/target/windows-desktop-win7-x64/ncu.exe' --section-folder 'C:/Program Files/NVIDIA Corporation/Nsight Compute 2026.3.1/sections' --query-metrics --query-metrics-mode suffix --metrics dram__bytes_read,dram__bytes_write,gpu__time_duration
```

Discovery without a denial would still require collection validation before
claiming access to a profiled workload. Here the denial already blocks that step.

## Authoritative source investigation

The [NVIDIA laptop comparison](https://www.nvidia.com/en-me/geforce/laptops/compare/)
still specifies 8 GB GDDR6 / 128-bit for RTX 4060 Laptop, without an applicable
effective memory data rate. The [Casper family page](https://www.casper.com.tr/excalibur-g870-p-137)
retrieved during this follow-up lists newer configurations; it cannot identify
this installed unit. The older i7-12650H/RTX4060 product URL again redirects to
that family page. Earlier family-page observations remain historical evidence;
different retrieved variants are not proof of a dated product specification.

source-review.json records URLs, bounded search queries and applicability
decisions as review notes, not raw webpage snapshots. No applicable official
effective rate was established. Third-party database/retailer numbers, another
OEM's laptop, desktop RTX4060 specifications, generic laptop rates and runtime
MHz are not substituted. This does not prove that no OEM specification exists.

For a documented effective rate R in Gbit/s per pin, theoretical decimal
peak_GBps = R * 128 / 8. One GB = 10^9 bytes. The rate must apply to this unit's
memory configuration. R, theoretical peak and percentage of peak remain null.
The remaining source requirement is an OEM/NVIDIA rate or peak specification
whose applicability to this G870/NLXB configuration can be demonstrated.

## Collection and peak are independent prerequisites

No read/write DRAM bytes, kernel duration or measured GB/s were obtained.
Counter access alone can unblock measured GB/s; a missing documented peak
blocks only the supported percentage calculation. Neither obligation is waived.

The existing candidate metrics are dram__bytes_read.sum and
dram__bytes_write.sum (bytes), with gpu__time_duration.sum (ns), subject to
supported-metric/collection verification. For identical collected kernel
instances, stage GB/s = sum(read_bytes + write_bytes) / sum(duration_ns).
The numerical cancellation uses 10^9 ns/s and 10^9 bytes/GB. Report each stage
and its instances/batches, replay/cache/clock policies and any aggregate scope.
Do not combine kernel bytes with host end-to-end duration, infer traffic from
allocation sizes or average individual kernel rates. Copies, host quantile and
gaps are outside this kernel aggregate. The profiler's sustained-peak percentage
is distinct from 100 * measured_GBps / documented_theoretical_peak_GBps.

After access is supplied, inspect the existing validated workload and verify
source/binary/cache/runtime identities before narrowly scoped profiling. Use
fresh profiling records outside primary timing; no optimization or new benchmark
or convergence campaign is required. The formal benchmark remains unchanged.

## Required external action

[NVIDIA's official Windows guidance](https://developer.nvidia.com/nvidia-development-tools-solutions-err_nvgpuctrperm-permission-issue-performance-counters)
supports running the full diagnostic from an Administrator command prompt.
For this ordinary-user workflow, an administrator can instead open NVIDIA App
11.0.6+ > System > Advanced > Developer > Manage GPU Performance Counters and
permit non-admin profiling. The installed App version/UI was not inspected.
Control Panel support is deprecated starting with R610. No permission policy
was changed here. Recheck once after external access changes, then collect.

## Verification and preservation

The existing read-only check-reproducibility.py --local-convergence passed:
22 primary, 32 stage and 24 figure selected artifacts; 22 convergence delivery
bindings; 160 values, 32 groups and eight separately checked acceptance rows.
Historical documents are checked against their original raw snapshots/Git
content, independently of current documents. Numerical-input/raw hashes remain
strict. No figures, builds or simulations were regenerated. manifest.json binds
selected exact copies, local process records, immutable historical parents and
current documents separately, excluding itself. validate.ps1 checks these
bindings without launching an engine or rerunning the denied diagnostic:

```powershell
./evidence/v030-bandwidth-followup-20261020/validate.ps1 -IncludeLocal -CheckCurrentDocuments
```

The local option requires the original ignored records. Current documents have
their own optional exact-byte check for this checkpoint; omit that option after
legitimate documentation advances and compare their checkpoint Git versions
separately. Historical evidence checks do not depend on current document bytes.

Unchanged conclusions: full-device speedup 9.739930524x serial (10x unmet),
8.307208722x best OpenMP; hybrid at 10M did not beat best OpenMP. RNG's largest
covered device-stage mean does not establish the largest end-to-end cost.
Recorded sanitizer limits, historical serial source-to-binary=false, missing
independent historical OpenMP cache and mixed-revision convergence remain.
Native equal seeds do not imply equal samples across engines/modes/batches.
Numerical contracts and FR/NFR IDs are unchanged. No fresh-machine reproduction,
predictive market validity, academic delivery or overall completion is claimed.
