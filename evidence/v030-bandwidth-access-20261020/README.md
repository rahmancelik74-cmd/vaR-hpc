# Baseline bandwidth investigation, 2026-10-20

Status: blocked, not bandwidth closure. Inspection base is main at
35338cdc462aea88b37ed07a7d2b759138480f96. Only three diagnostic processes ran:
Nsight version, metric discovery and a read-only nvidia-smi inventory. No engine,
simulation, benchmark, kernel profiling or permission/system change was run.

## Observed identity and access

Nsight Compute 2026.3.1.0 build 38829034 is installed. Its executable SHA-256 is
1f6fffa8f45372d5bf7073c2e4bc751449715f5d8f98ab714112b6a972f1e72b,
matching the historical preparation tool. Current discovery identifies AD107 /
NVIDIA GeForce RTX 4060 Laptop GPU and emits ERR_NVGPUCTRPERM, despite exit 0.
This is a permission denial, not successful collection or tool absence.
Current nvidia-smi reports driver 610.88 and 8188 MiB. Its single point memory
clock is 7001 MHz; reported maximum is 8001 MHz. Neither is an OEM effective
memory data-rate specification or evidence of sustained workload clocks.

Read-only HKLM/HARDWARE/DESCRIPTION/System/BIOS values identify manufacturer
CASPER BILGISAYAR SISTEMLERI, EXCALIBUR G870, family EXCALIBUR, SKU EXCALIBUR
G870 NLXB, board NLXB 001, BIOS CQ111. No serial, UUID or machine name is included.
CIM inventory queries initially failed with HRESULT 0x80041003 (Access denied);
the registry is the actual identity source, not a successful CIM query. The full
commercial configuration suffix and installed memory-chip data rate remain unknown.

The exact historical discovery, process status and bandwidth-preparation.json in
results/benchmark-prep-df34111-clean-20261019-smoke remain unchanged. New process
records, argv, timestamps and raw stdout/stderr are retained under
results/bandwidth-investigation-35338cd-20261020-attempt1. Selected safe raw
outputs are copied here exactly; manifest.json binds both selected and local
records. It excludes itself and attests no achieved-bandwidth measurement.

The discovery command was ncu.exe with arguments:

```text
--section-folder <Nsight Compute 2026.3.1>/sections --query-metrics
--query-metrics-mode suffix
--metrics dram__bytes_read,dram__bytes_write,gpu__time_duration
```

No target executable was launched. Offline metric enumeration would not prove
collection access; here discovery already returns the explicit permission error.

## Official remedy; administrator action remains external

[NVIDIA's counter-permission instructions](https://developer.nvidia.com/ERR_NVGPUCTRPERM)
were checked on 2026-10-20. On Windows, an administrator can run the diagnostic
from an Administrator command prompt. To permit this ordinary-user workflow,
the administrator can instead use NVIDIA App (11.0.6 or newer), System >
Advanced > Developer > Manage GPU Performance Counters and allow counter access
for non-admin users. The installed App version/UI was not verified here.
NVIDIA also documents the older Control Panel Developer settings route, deprecated
from R610. No administrator launch or setting change was attempted by this task.
Recheck access after the administrator chooses an appropriate permission policy;
do not treat a metric-discovery exit code alone as success.

## Documented peak: still unresolved

[NVIDIA's RTX 40 laptop table](https://www.nvidia.com/en-me/geforce/laptops/compare/)
specifies 8 GB GDDR6 and a 128-bit interface for RTX 4060 Laptop GPU. It does
not establish this unit's effective memory data rate.
[Casper's current G870 specifications](https://www.casper.com.tr/excalibur-g870-p-137)
also list RTX4060 8GB 128Bit GDDR6, but cover multiple configurations and do not
give that rate. An older i7-12650H/RTX4060 product URL redirects to this family
page; it cannot identify the exact purchased suffix or original memory rate.
Both sources were checked on 2026-10-20. Targeted official-site searches for
G870/4060 data rate (Gbps or 14000) found no applicable rate document. This is a
bounded unsuccessful search, not proof no OEM document exists. Retailer/forum
estimates and other OEM models are not used as authoritative specifications.

If an applicable effective rate R in Gbit/s per pin is obtained, decimal
theoretical peak = R * 128 / 8 GB/s. Percentage of documented peak would be
100 * measured_GBps / documented_peak_GBps. R is unknown, so both peak and
percentage remain null. No multiplier is applied to the runtime MHz values.
An OEM specification tied to this G870/NLXB unit's memory configuration, or an
equivalently applicable NVIDIA specification, is still needed independently of
counter permission.

## Scope for the remaining measurement

No DRAM bytes, kernel durations or GB/s were collected. The candidate metrics
remain dram__bytes_read.sum, dram__bytes_write.sum (bytes) and
gpu__time_duration.sum (ns), subject to supported-metric and attachment validation.
For the same collected kernel instances, stage GB/s must be
sum(read_bytes + write_bytes) / (sum(duration_ns) * 1e-9) / 1e9.
This is kernel-scope traffic per kernel duration, excluding copies, host quantile
and gaps; it is not end-to-end host bandwidth or a mean of kernel rates.
Record every relevant instance/batch, replay/cache/clock policies and overhead;
do not substitute allocations, scalar-loss counts or transfer sizes for DRAM.
Nsight's pct_of_peak_sustained_elapsed uses a different denominator from an OEM
documented theoretical peak. Profiling cannot replace formal timing results.
Existing stage diagnostics do not establish RNG as the dominant end-to-end cost.

## Verification and preservation

Eleven existing provenance/normalization tests pass, including rejection of a
real numerical-input mutation and acceptance of a legitimate later document
change. Read-only independent convergence validation passes 160 values, 32 groups
and eight separate acceptance rows; all 22 parent delivery entries verify with
historical documents checked against their recorded snapshots. No figure or
simulation was regenerated. The version-2 figure inventory is checked at its
recorded 35338cd Git snapshot for release documents; numerical inputs remain
strictly bound to actual bytes. No old manifest/hash was edited. Historical
serial source-to-binary=false, OpenMP standalone-cache limitations and mixed
source/build provenance remain unchanged; native equal seeds do not imply equal
samples across engines. CPU CI, if published, is a separate gate.

Local check harness mistakes (inline Windows quoting, then JSON serialization
of the validator's tuple rather than its final report) did not change data;
the corrected read-only harness and process logs are retained separately.
