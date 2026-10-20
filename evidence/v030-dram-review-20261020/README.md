# Independent DRAM review and peak-source follow-up, 2026-10-20

Inspection base: main 7e792047fd4db2aafc8351fe87d8d4098db9a50f, independently
matched to remote main. Its push run [39433346433](https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/39433346433)
was confirmed successful at that exact SHA: cpu (ON), cpu (OFF) and
windows-instrumentation. This review adds no engine, simulation, profiling,
benchmark, convergence, build or convergence-figure execution. Existing untracked
AGENTS.md and output/ remain untouched. Publication CI is a later separate fact.

## Independent result

The unchanged [baseline verifier](../v030-dram-baseline-20261020/verify.py) passes
with all selected and original local records, including both .ncu-repz hashes
and reprojected raw CSVs. A separate one-off Decimal/integer-sum review, without
importing that verifier, additionally checks raw process/device/context/stream
identity, launch IDs against stdout, exact argv and historical workload matches.
[audit.json](audit.json) retains the result; its local script is hash-bound in
manifest.json. No new reusable parser/calculation code or test contract was added.

| Mode | Kernel instances | Read + write bytes | Duration ns | Decimal GB/s |
| --- | ---: | ---: | ---: | ---: |
| Full-device | 14 | 1535283200 | 16407904 | 93.56973322125727 |
| Hybrid | 307 | 258276736 | 10498528 | 24.601233239555107 |

GB/s is sum(dram__bytes_read.sum + dram__bytes_write.sum) divided by
sum(gpu__time_duration.sum) over the identical launch IDs, each once. Byte/ns
equals decimal GB/s because both unit conversions use 10^9. All ten original
stage/aggregate rows reproduce exactly as binary64, with exact integer totals.
The .avg/.min/.max siblings are not added. Seven distinct full-device names
represent 14 launches, including eight Onesweep sort launches; three hybrid
names represent 307 launches, including 153 RNG and 153 simulation batches.
Names are not deduplicated or treated as replay counts.

Full-device raw PID 37916 and hybrid raw PID 25152 each have one context (1),
stream (13), device index (0), compute capability 8.9 and RTX 4060 Laptop name.
Each matches its connected/disconnected process stdout. Raw IDs are exactly
0..13 and 0..306. The recorded commands request kernel replay, cache-control all,
clock-control none, and only the three desired .sum metrics. Each result has
profiler__replayer_passes=1, warmup=0 and one matching stdout pass: one collection
pass per launch, zero additional replay/warmup passes. These are not application
replays, benchmark warm-ups or 307 repetitions of the whole hybrid workload.

The validated primary source 89536e38b01230fce3b4667096c29dde56795c23/tree,
archived source snapshot/manifest and ten original primary artifact bindings
verify. Five binary/cache/project/runtime files and 14 numerical source/input
files match their original hashes and Git blobs. Executable SHA-256 remains
3c5c7e47ed870fb99ad733326ebbd9c8edf88558909b9905c1b2d5faa647d255.
Both profiles use N=10000000, seed 42, the synthetic CSV, T=10/252, double
PHILOX/GBM and diagnostics OFF. Hybrid requests 65535, uses 65536 and 153
batches with one global host quantile; full-device uses one batch/device CUB.
Model, calibration, RNG and both VaRs match all 13 original primary result
pairs per mode. Timing is deliberately excluded from that equality check.

No material ambiguity requires a new diagnostic. The ordinary baseline verifier
checks normalized counters/IDs/stages/units but does not independently inspect
raw process/device identity or re-establish binary provenance. Those extra checks
here require the hash-bound original local records. Public counter verification
alone remains narrower than this local review.

## Scope and interpretation

The observed metrics are bytes read/written across DRAM unit instances and
duration in ns, as described by the archived successful metric discovery. The
[NVIDIA guide](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html#cache-control)
explains cache flushing before passes; the same guide's replay, profiler-metric
and range/precision sections describe pass counts and shared-resource effects.
The documented version-specific /2026.3/ web path was inaccessible; the current
official guide and locally archived 2026.3.1 discovery/configuration were used.

These are two single cold-cache collected-kernel observations with unlocked
clocks. They exclude explicit transfers/copy-engine intervals, host gaps,
allocation, cache-flush overhead, cleanup and hybrid host quantile. DRAM can
include asynchronous shared-resource traffic during collection; exclusive
workload traffic is not proven. Zero hybrid writes are observed counter values,
not proof of absent stores/transfers or a demonstrated cache-residency cause.
The rates are not end-to-end bandwidth, sustainable peak or repeated-sample means.
Different kernel scopes do not rank end-to-end mode performance.

Formal benchmark selected hashes, raw runs.jsonl and original manifest/cache/
source-snapshot bindings remain unchanged. Host/Event values produced under the
profiler do not replace primary timing or separate stage diagnostics. The
9.739930524x serial target remains below 10x; full-device versus best OpenMP is
8.307208722x, and hybrid did not beat best OpenMP. RNG's largest covered stage
mean does not identify the largest end-to-end cost. Historical provenance,
mixed-build convergence and recorded sanitizer limitations are unchanged.

## New authoritative avenue: OEM manual catalog

The earlier source-review records were read first. Beyond the previously
reviewed product-family page, the public
[OEM manual catalog](https://www.casper.com.tr/kullanim-kilavuzlari) was followed
through its category=5 / series=137 (Excalibur G870) read-only endpoints. Two
actual PDFs were downloaded privately and their relevant technical tables
rendered and visually inspected using existing bundled Poppler. No installation,
firmware dump, unique device identifier or system setting change was needed.

[source-review.json](source-review.json) records exact retrieval links, filenames,
PDF SHA-256s, physical/printed pages and applicability decisions. The older
28-page manual's technical table (PDF page 19, printed 18) lists generic NVIDIA
RTX/GTX graphics, not an effective memory rate. The newer RTX5000-named 25-page
manual's table (PDF page 18, printed 18) likewise lists generic GeForce graphics;
it cannot establish the installed RTX4060 rate. Both warn of model-dependent
differences. PDF metadata has a G770 title; it is not independent model identity.
Raw PDFs/catalog HTML/renders remain ignored, not redistributed.

[NVIDIA's laptop comparison](https://www.nvidia.com/en-me/geforce/laptops/compare/)
supports 8 GB GDDR6 / 128-bit, and the separate
[40-series specifications](https://www.nvidia.com/en-us/geforce/laptops/40-series/)
list memory type/size but no applicable effective rate. Targeted official-site
PDF/support/model queries found no directly applicable rate document. Indexed
retailer PCMark reports for other G870/NLXB configurations are measurements,
not applicable OEM capability specifications, and were not used. Other OEMs,
desktop specs, chip capability guesses, runtime clocks and Nsight peak models
are not substituted. No third party was contacted. This bounded unsuccessful
investigation is not proof that no appropriate document exists.

Exact remaining evidence: an OEM/NVIDIA effective Gbit/s-per-pin rate or peak
specification demonstrably applicable to this installed G870/NLXB memory
configuration. If rate R is established, theoretical peak_GBps=R*128/8 and
percent=100*measured_GBps/peak_GBps for the disclosed kernel scope. R, peak and
percentage remain null. Counter access already succeeded; administrator counter
action is not required for the recorded session. The reporting requirement is
not waived, and no bandwidth threshold is introduced.

## Preservation and verification

Original evidence and manifests were not edited. manifest.json binds this
small review, immutable parent manifests and the one-off local review source,
raw OEM downloads/catalog and check outputs; it excludes itself and all current
documents. No circular/current-document dependency is added. The original
mixed-newline project-state suffix is preserved byte-for-byte when prepending
this checkpoint. A one-off script initially selected a nonexistent cuda-N key;
using the actual full-device-N key corrected the harness before report creation.
That was not a counter or historical-data defect.

Existing paths exercised, with raw outputs retained in
results/closure-audit-7e79204-20261020/:

```text
python -B evidence/v030-dram-baseline-20261020/verify.py --local-records results/bandwidth-baseline-663fcc3-20261020
python -B scripts/check-reproducibility.py --local-convergence
```

The latter passes 78 selected files, 22 delivery bindings, 160 values, 32 groups
and eight acceptance rows, keeping exact historical raw snapshots/Git checks
separate from current documentation. No CPU build or convergence figure was
repeated. Same-machine relocation evidence remains distinct from a fresh-machine
trial; full historical audits retain original binary/cache/archive/path needs.
The current [18-item requirements audit](../../docs/requirements-audit.md) is the
status entry point. Academic approval/submission and live demo remain unverified;
this is not an overall completion claim or authorization for optimization.
