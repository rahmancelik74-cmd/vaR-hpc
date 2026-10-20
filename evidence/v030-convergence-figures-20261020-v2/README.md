# Verified convergence figures and provenance correction, version 2

This package closes offline figure verification for the existing synthetic
80-run/160-estimate dataset, 32 groups and eight separate 10M acceptance rows.
No simulation, measurement, timing campaign, profiler or optimization ran.
Engine-tested source: b5f1a0f5b72bca8f1f21555236d938501f7faee8.
Numerical evidence commit: 390ffa670960f83a0de4fb0b9cd595cb03cdbc8e, an
ancestor of this closure. Reused records retain their individual revisions.

## Root cause and historical integrity

The original figure reproduction script verified every artifact of the numerical
delivery manifest against the current working tree. That historical manifest
also inventories docs/project-state.md and docs/convergence.md. Figure/status
documentation legitimately changed both files; the first failure was the
project-state.md entry, expected raw SHA-256
3c42f203acf2c9c7b73c91ff74a8ad47f5edaf11393f557e28ed333cbf238c02.
The failure concerned a historical delivery snapshot, not plotted input values,
engine compatibility or figure rendering. The captured exception and process
record are preserved as original-failure.*. The earlier failed output directory
and all prior figure drafts remain untouched under ignored results/.

The original [figure selection](../v030-convergence-figures-20261020/selection-manifest.json)
and the numerical delivery manifest are unmodified. The original figure package
is a frozen version-1 snapshot; its reproduction command has this known failure.
Use the version-2 command below for current reproduction.

provenance-policy.json pins the exact original numerical manifest and commit.
Only the two explicit historical document entries are verified against the raw
snapshots in historical-documents/. Their SHA-256 values must match the original
manifest. All other 20 entries, including numerical inputs and local raw runtime
evidence, must still match actual file bytes. Missing data, changed CSVs or
modified manifests fail. No broad hash exception was introduced.

The historical project-state raw file contains mixed CRLF/LF bytes and therefore
has a different SHA-256 from its LF Git blob. Its exact raw snapshot was recovered
from the unchanged historical suffix still present in the working file, with
the original header bytes. The result matches the old recorded SHA-256 exactly.
The raw snapshot is also compared, separately, with Git content at 390ffa6 after
Git's CRLF text conversion. No normalized bytes are substituted for an evidence
hash. Historical convergence.md matches its Git blob directly.

Current documentation is a separate release-content attestation in
selection-manifest.v2.json. It is not an input to numerical figure regeneration.
Git blob content hashes are used for that attestation so checkout line endings
are not confused with historical raw-byte hashes. A later documentation edit
requires a later release attestation; it does not corrupt these measurements.

## Figures and interpretation

1. [Error versus N](01_error_vs_scenarios.svg): absolute error of the five-seed
   mean and descriptive MAE, separate panels for .95/.99.
2. [Signed seed errors](02_seed_signed_errors.svg): all 160 errors, separate
   engine/mode and alpha panels; symlog linear region |error| <= .001 is labeled.
3. [Seed variation](03_seed_standard_deviation.svg): sample SD using n-1, not a
   confidence interval or an acceptance metric.
4. [Separate 10M acceptance](04_separate_10m_acceptance.svg): error of the mean
   divided by .01*max(abs(reference),.01*V0). All eight original rows pass.

[Combined four-page PDF](convergence_figures.pdf) contains these same figures.
All four PNG figures and all four Poppler-rendered PDF pages were visually
inspected: labels/captions are English, readable and unclipped; no unintended
overlap was found. GPU curves overlap exactly, disclosed in captions and shown
with distinct solid/filled versus dashed/hollow markers, without jitter.
The regenerated PNG pixels match the original final figures exactly.

Positive log axes mark exact zeros separately without epsilon replacement;
the raw data stays unchanged. No group metric is zero in this fixture. The
zero branch is tested with a deliberate zero and invalid log values. Relative
error remains N/A when abs(reference)<.01*V0, with signed error/V0 available.
The original near-zero status spelling is now checked consistently.

Error is nonmonotonic. No fitted/universal rate, predictive market validity,
confidence interval or performance conclusion is inferred. MAE/RMSE and seed
variation remain descriptive; they never replace error-of-mean acceptance.
Serial source-to-binary=false, the missing published standalone OpenMP cache,
mixed source/build reuse and native seed/sample limitations remain explicit.
This is not one fresh common-build campaign.

## Verification and reproduction

- numerical-reaudit.json: read-only independent PowerShell recalibration,
  references/statistics and raw bindings passed for 80/160, 32 groups, 8/8
  acceptance rows and all 122 original campaign files; original audits untouched.
- verification.json: independent Python fixture/statistics checks and 22
  delivery entries, with historical/current roles and relocation resolutions.
- plotted-data.json and plotted-data-check.json: all 96 curve points, 160
  signed seed points and eight acceptance ratios match verified CSV values
  exactly as binary64; verify-plotted-data.py is the independent comparison source.
- focused-tests.*: 11 stdlib tests passed, including a changed real numerical
  CSV that must fail and later documentation changes that legitimately pass
  historical verification. Linux CPU CI also runs these tests without plotting
  dependencies or the ignored raw GPU archive.
- visual-check.json: all four figures and four rendered PDF pages inspected.

Using the existing Python 3.11.4 / Matplotlib 3.7.1 environment, from repo root:

```text
C:/Users/rahma/anaconda3/python.exe -B evidence/v030-convergence-figures-20261020-v2/convergence_figures.py --repository . --output results/convergence-figures-new-reproduction
C:/Users/rahma/anaconda3/python.exe -B -m unittest discover -s tests -p test_convergence_figures.py -v
```

Use an equivalent existing Python environment if its executable differs. No
dependency installation is implied. Regeneration requires Git history including
390ffa6 and the exact local archived raw/build artifacts. It rejects existing
output directories and never starts an engine. Recorded paths remain unchanged;
only the recorded repository prefix is resolved to the supplied repository root.

figure-manifest.json attests the generated full local package before selection,
excluding itself and disposable Matplotlib cache. selection-manifest.v2.json
binds this selected package, code, policy, historical snapshots, plotted data,
tests, current document content and both immutable parent manifests, excluding
itself. Current document hashes do not participate in numerical regeneration.
PDF/SVG timestamps and SVG IDs can differ on regeneration; data equality and
pixel equality are checked rather than requiring metadata-identical graphics.

The original full package remains in results/convergence-figures-390ffa6-20261020-final/;
the corrected full package is in results/convergence-figure-closure-20261020-v2-final/.
PDF review renders remain in results/convergence-figure-closure-pdf-review-20261020/.
Original result directories, manifests, failed-check evidence, AGENTS.md,
output/ and private data were preserved.

GitHub Actions for the exact final pushed SHA is a separate publication gate,
not established by these offline checks. The exact-SHA CI response is retained
under ignored results/ after publication to avoid a self-referential commit.
CPU CI is distinct from RTX execution evidence and visual verification.
Counter permissions/documented laptop peak bandwidth and final reproducibility,
requirements/delivery work remain open; this is not full project completion.
