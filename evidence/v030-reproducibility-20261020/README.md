# Technical reproducibility and requirements checkpoint

Inspection base: main at b9745be08a477b3648afc8499b07fb2ae4aec165,
origin https://github.com/rahmancelik74-cmd/vaR-hpc.git. Initially tracked/staged
files were clean; only AGENTS.md and output/ were untracked. Root AGENTS.md
was read; no ancestor/relevant subtree override was found. Current project,
acceptance, convergence, requirements draft, architecture, data rights,
benchmark, stage-diagnostic and bandwidth documentation and their relevant
evidence manifests/READMEs were inspected. The populated private review draft
and incomplete template were read for FR/NFR identity; their hashes are in
requirements-audit.md. Proposal/roadmap exact bytes still match the acceptance
register. No required public source was inaccessible. Approved/submitted FR/NFR
document identity is unavailable; no approval is inferred from a review draft.

## Package and scope

- [Entry point](../../docs/reproducibility.md): prerequisites and exact commands
  for current CPU builds, public integrity, local numerical/raw evidence and
  offline figure reproduction. Explicit private/archive/history dependencies.
- [FR/NFR audit](../../docs/requirements-audit.md): all 18 IDs, criteria,
  implementation, scoped evidence and limitations; preserved R01-R14/B01-B02
  labels with a newly identified correspondence rather than invented history.
- scripts/check-reproducibility.py reuses the unchanged version-2 validator
  and published inventories. It starts no engine, downloads nothing and writes
  no original audit. Public integrity success is explicitly narrower than local
  numerical validation. Missing local artifacts, corrupt CSVs or inventories
  fail rather than receiving a success fallback.
- data/.gitattributes protects only synthetic_prices.csv from checkout newline
  conversion. Before this task it had no text attribute, despite a strict
  LF-byte fixture hash. Working and historical Git bytes already matched; this
  closes a fresh Windows autocrlf portability risk without changing either.
- manifest.json has explicit immutable parent relationships, selected safe raw
  check records, local exact-byte artifact bindings and current Git content
  attestation. It excludes itself; changing status documents are not numerical
  dependencies. The final commit/CI are separate post-commit facts.

## Actual checks

This was an original-machine clean-build trial in new build directories, not a
fresh-machine trial. CMake 3.31.6-msvc6, VS2022/MSVC 19.44.35227.0, Windows SDK
10.0.26100.0, x64 Release, testing ON, CUDA OFF, CPU tools OFF:

| Configuration | Actual discovery | Result |
| --- | --- | --- |
| OpenMP ON | 13 CTests | 13/13 passed, 15.89 s |
| OpenMP OFF | 12 CTests | 12/12 passed, 11.45 s |

Initial configure attempts failed because sandboxed MSBuild could not read the
user-local Microsoft SDK directory (MSB4184/access denied). Those logs and build
directories remain. Separately authorized application-level access allowed new
attempt-2 directories to configure/build/test. No driver, permissions or system
settings were modified. No engine/RNG/quantile/CPU implementation was changed.
CPU tests include small software fixtures; they are not new campaign observations.
No CUDA rebuild or GPU execution was performed for this package.

Python 3.11.4, Matplotlib 3.7.1, Pillow 9.4.0 (already installed):

- 15 focused tests pass: 11 existing provenance/normalization tests plus four
  entry-point tests. Real numerical CSV corruption still fails; later current
  documentation changes use the correct historical snapshot distinction.
  New cases cover traversal, missing-local actionable failure, corruption not
  misclassified as absence, and pinned inventory/CSV rejection.
- Public selected inventories verify 22 primary, 32 stage and 24 figure files,
  plus figure parent manifests and historical release content.
- Existing Python independent recalculation passes 160 values, 32 groups and
  eight separate acceptance rows with all 22 delivery entries checked.
- Existing PowerShell independent raw-attempt/reuse/build audit functions pass
  80 unique runs/160 values, complete coverage and all statistics. Their original
  output reports/manifests were not rewritten.
- Figure regeneration uses only existing data and unchanged version-2 plotting
  code. All 96 curve points, 160 signed seed points and eight acceptance points
  exactly match selected plotted data; four PNGs are pixel-identical to the
  previous verified final figures. No new PDF rasterization or visual-review
  claim: the existing four-page review and unchanged graphic hashes remain.
- All 24 primary configurations have 13 archived pairs of VaRs (warm-ups plus
  measurements), identical within each configuration; no timing was compared
  for equality or rerun. This supports scoped same-build repeatability.
- 63 current implementation/script/test text files were checked as ASCII.
  New technical relative links and appropriate whitespace checks pass. Exact
  archived outputs keep their original bytes, including localized tool logs.

Raw process/build logs are retained under results/reproducibility-b9745be-20261020,
fresh builds under build-repro-b9745be-{on,off}-20261020-attempt2 and regenerated
figures under results/repro-figures-b9745be-20261020. These ignored directories
are not indiscriminately published. Public selections contain no provider prices
or private correspondence. Initial failed configuration attempts remain separate.

## Open findings and limits

10x serial target remains unmet: 9.739930524x; full-device versus best measured
OpenMP is 8.307208722x. Hybrid at 10M did not beat best OpenMP. Recorded sanitizer
cases do not prove general race freedom or host-buffer safety. ERR_NVGPUCTRPERM,
applicable laptop peak, measured DRAM GB/s and percentage of peak remain open.
The next baseline measurement requires external administrator counter access and
an applicable documented memory data rate/peak; no system change occurred here.

Serial source-to-binary verification=false, missing published independent
OpenMP CMakeCache and mixed-revision convergence provenance remain explicit.
Native equal seeds do not imply equal samples across modes/engines. The public
checkout does not include original binaries/caches/full raw archives or private
licensed historical inputs. Restoring exact authorized originals is required
for those paths; rebuilding does not repair historical provenance limitations.
Academic baseline approval/submission, reports and live demo remain unverified.
This technical package does not claim overall project completion or authorize
optimization/new measurements. Deferred planning narrative remains preserved.
