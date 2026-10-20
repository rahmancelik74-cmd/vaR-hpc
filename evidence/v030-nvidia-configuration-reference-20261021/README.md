# NVIDIA App configuration-bandwidth reference, 2026-10-21

Inspection source: main 945394aa9715d246a9f27f3aad542931eeafdc87. Initially
only AGENTS.md and output/ were untracked; both were preserved. After the user
explicitly resumed Computer Use, the actual installed NVIDIA App was inspected
through its supported UI, without changing settings. No profiling, simulation,
local build, installation or generic peak-specification search was repeated.

## Authentic local report and privacy

The observed route was System > My Rig > View More System Details > Copy Text
(the installed UI is Turkish). The full copied text identifies RTX 4060 Laptop,
the same 610.88 driver and i7-12650H as the project records. The actual UI and
copied report agree on all five GPU/driver/memory fields below. App version is
also present in the copied report and installed executable product metadata.

| Report item | Exact reported value |
| --- | --- |
| Generation timestamp, as written | 10/21/2026 00:56:05 |
| NVIDIA App version | 11.0.9.565 |
| GPU | NVIDIA GeForce RTX 4060 Laptop GPU |
| Driver version (parsed; original line in extract) | 610.88 |
| Memory data rate | 16.00 Gbps |
| Memory interface | 128-bit |
| Memory bandwidth | 256.032 GB/saniye |

The timestamp does not include a timezone. The host's separately observed
timezone was Turkey Standard Time / UTC+03:00; it is not inserted into the
original report. GB/saniye is the localized GB/second unit, not GiB/s.
[report-extract.json](report-extract.json) retains each exact original Turkish
field label, value and source line through ASCII JSON Unicode escapes, with
English metadata. No label transliteration is substituted for the source text.

The original complete Copy Text output is stored ONLY under ignored
results/nvidia-system-information-945394a-20261021/nvidia-system-information.full.txt.
It was read from the clipboard after the observed Copy Text action, validated
against the visible report, and saved as UTF-8 without BOM, preserving line
breaks. Its SHA-256 is
7d6d55a090d3a0616ad29252a47ddd12c05025b379632ff95eb9029f4c21b220.
This identifies the captured copied-text bytes, not an unobserved native Save
export. The private accessibility capture and provenance record remain local.
The public extract deliberately excludes unnecessary system/hardware identifiers
and sections. It is sanitised, not the exact-byte complete original.

[NVIDIA's guide](https://images.nvidia.com/content/Solutions/data-center/deployment-guide-vgpu-software-citrix-apps-desktops-citrix-hypervisor.pdf),
section 8.6, demonstrates the System Information reporting facility. Its vGPU
example values and hardware are not used as this laptop's specifications.
The actual local app/report, not the guide's screenshot or an unrelated forum
report, supplies the configuration fields here.

## Evidence classification and criterion boundary

| Class | Meaning | This checkpoint |
| --- | --- | --- |
| A | Published OEM/NVIDIA specification applicable to this configuration | Not located; historical search finding remains unchanged |
| B | First-party NVIDIA software reporting this installed configuration | Obtained through the local NVIDIA App UI and Copy Text |
| C | Observed runtime clock telemetry | Earlier MHz snapshots are not used as rated/effective capability |
| D | Assumed/generic GPU specification | Not substituted |

The reference below is class B: **NVIDIA App System Information-reported
configuration bandwidth**. No undocumented API or export switch was used and
no claim is made about the app's internal data source. It is not promoted to
class A, a measured sustainable peak, or observed workload clocks.

The authoritative acceptance register requests achieved DRAM GB/s and percentage
of "documented GPU peak". It does not explicitly decide whether a device-report
reference satisfies that wording. This supplement does not resolve that
interpretation by fiat, change the criterion or mark baseline peak-percentage
acceptance complete. The applicable published-specification gap remains open.
The separately labelled class-B comparison is now available for technical use.

## Calculation and rounding

The displayed rate is already an effective data rate. Decimal units give:

```text
16.00 Gbit/s per pin * 128 bits / 8 bits per byte = 256.00 GB/s
```

No extra DDR factor, assumed GDDR clock multiplier or runtime MHz conversion is
used. NVIDIA separately reports 256.032 GB/s, a 0.032 GB/s (0.0125%) difference.
That value implies 16.002 Gbit/s per pin algebraically, which rounds to 16.00
at the rate field's two decimal places. Thus the displayed fields are compatible
with rounding. This is not proof of the exact undisplayed rate or the app's
internal rounding implementation. The denominator below is the directly
reported **256.032 GB/s**, not the 256.00 result from the rounded rate display.

The original public integer counters are reused through the unchanged baseline
summarizer; numerator/duration scope remains identical. Decimal arithmetic at
50 significant digits uses total bytes and ns, never rounded displayed GB/s.

| Mode | Kernel records | Total DRAM bytes | Duration ns | GB/s, shown rounded | Percentage of NVIDIA App-reported configuration bandwidth |
| --- | ---: | ---: | ---: | ---: | ---: |
| Full-device | 14 | 1535283200 | 16407904 | 93.56973322125727 | 36.54610877595663% |
| Hybrid | 307 | 258276736 | 10498528 | 24.60123323955511 | 9.60865565224468% |

[calculation.json](calculation.json) retains the unrounded-input calculation
and full Decimal strings. It explicitly records that the published-specification
gap is not closed. The reports were collected on different dates: this new
configuration reference is not contemporaneous performance telemetry for the
2026-10-20 profiles, although device name and driver agree.

These are N=10000000/seed42 cold-cache sum(bytes)/sum(matching kernel durations),
one collection pass per kernel and no additional replay. Transfers, host gaps,
allocation/cleanup and hybrid host quantile are excluded. Shared-resource DRAM
contamination remains possible; original caveats and zero hybrid write counters
remain intact. Percentages are not whole-application utilisation or sustainable
peak efficiency and do not rank the two modes' end-to-end performance.

## Verification and preservation

```text
python -B evidence/v030-nvidia-configuration-reference-20261021/calculate.py --check
python -B -m unittest discover -s tests -p test_nvidia_configuration_reference.py -v
```

The public read-only calculation verifies its exact selected-file and immutable
parent bindings, then reuses the original per-launch/stage validation and exact
integer totals. It requires no GPU, clipboard or private report. Focused stdlib
tests compare the percentages to independent Fraction arithmetic, reject clock/
binary-unit substitutions and incompatible fields, check display rounding and
prevent class-B results from silently claiming class-A acceptance. Existing CPU
CI discovers these tests automatically; no new workflow or automation is added.

The original baseline verifier also passed with local raw records, including
original .ncu-repz hashes and raw CSV projection. No raw report/profiler archive,
historical manifest or source numerical value was changed. The new manifest
excludes itself and current documents and keeps private exact-byte bindings
separate from the public sanitised selection. Current FR/NFR criterion cells
are checked separately from historical snapshots/Git content.

Full-device 9.739930524x serial remains below the 10x target; versus best OpenMP
it is 8.307208722x. Hybrid did not beat best OpenMP. Historical serial provenance,
missing independent historical OpenMP cache, mixed convergence revisions and
sanitizer coverage limits remain. CPU CI is not GPU execution evidence.
Academic submission/live demonstration and overall completion are not claimed.
