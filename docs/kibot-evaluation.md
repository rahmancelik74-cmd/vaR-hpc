# Local Kibot historical-data evaluation

Date: 2026-10-17, Europe/Istanbul. This continues the source search recorded
in historical-data.md; it does not erase the earlier acquisition failures.
The workflow evaluates CSV integration on genuine data without changing any
numerical engine or requirement ID. One share, ten trading days and 252
observations/year remain working settings.

Permission update, 2026-10-18: user-supplied provider correspondence now permits
retention and final academic experiments for the user's internal use on their
two normally used computers, and sharing derived statistics, calibration
parameters, VaR estimates and charts without raw data in academic/public
deliverables and outside reviews. Raw prices may not be resold or redistributed.
Acquisition methods, guest requests and scripts may be described without price
data; attribution is optional. The original mailbox export is archived outside
the repository, without independent authentication. Scope, provenance and
restrictions are recorded in [data-rights-and-calendar.md](data-rights-and-calendar.md).
This update supersedes the historical permission-pending conclusion below;
local data/results are not automatically selected for publication.

## Access and scope

[Kibot's API overview](https://www.kibot.com/api/api-overview.html) documents
free public guest access to daily US equity data for evaluation. No personal
account, payment, subscription or access workaround is required by this path.
The downloader performs the documented guest login and one HTTPS history request:

```text
https://api.kibot.com/?action=history&symbol=MSFT&interval=daily&startdate=01/01/2023&enddate=12/31/2025&unadjusted=1
```

The [history specification](https://www.kibot.com/api/history-request.html)
defines inclusive dates and unadjusted=1 as no split/dividend back-adjustment.
No default-adjusted response is substituted if that request fails. The
[format reference](https://www.kibot.com/file-format/data-format-reference.html)
defines a headerless daily record in Date,Open,High,Low,Close,Volume order with
MM/DD/YYYY dates. Close means the last regular-session trade, which may differ
from the official closing auction price. This is a documented price convention,
not a claim of equivalence to every other provider's daily Close.

MSFT here identifies the US-listed equity, denominated in USD, as also stated
on its [currency-labelled instrument page](https://finance.yahoo.com/quote/MSFT/history/).
The CSV contains no currency field; metadata distinguishes that external currency
basis from values actually returned by the endpoint. No currency conversion occurs.

## Historical license and publication boundary: 2026-10-17

The [Kibot license](https://www.kibot.com/license.html) permits internal use and
archival copies and prohibits resale/redistribution, including related/derived
information in its Data definition. Guest access is for evaluation, not a blanket
production/research publication grant. All provider bytes, complete downloaded
policy pages with notices, hashes, dates/counts, calibration values and numerical
results stay in ignored data/local or results. No provider observations or
derived numerical evidence are copied into the public repository.

This resolves local pipeline evaluation access. It does not approve a final
public study dataset, supervisor redistribution, published derived tables or
full research use beyond guest evaluation. Those purposes need suitable rights
or a different source. The API provides data without a completeness guarantee.
The subsequent local session-date audit and refreshed rights decision are
recorded in [data-rights-and-calendar.md](data-rights-and-calendar.md); its
provider-derived details remain private and do not grant research/sharing rights.

## Reproduction

Windows PowerShell 5.1, Git, existing Release executables and ordinary HTTPS
access suffice. Run from the repository root with new directory names:

```powershell
./scripts/download-kibot-evaluation.ps1 `
  -OutputDirectory data/local/msft-kibot-download-unique
./scripts/import-equity-data.ps1 `
  -InputFile data/local/msft-kibot-download-unique/raw.txt `
  -MetadataFile data/local/msft-kibot-download-unique/source-metadata.json `
  -OutputDirectory data/local/msft-kibot-import-unique `
  -SourceFormat kibot_daily
./scripts/check-equity-integration.ps1 `
  -ImportDirectory data/local/msft-kibot-import-unique `
  -CpuExecutable build-historical-cuda/Release/mc_var.exe `
  -CudaExecutable build-historical-cuda/Release/mc_var.exe `
  -OutputDirectory results/msft-kibot-integration-unique
```

The downloader archives source/policy URLs, actual UTC retrieval timestamps,
complete response bytes and hashes locally. Failed attempts retain failed status;
HTML/error bodies are rejected. The explicit kibot_daily adapter converts dates
and supplies the documented schema without discarding a headerless first row.
All rows and unused OHLCV fields are validated before date-window selection.
Default existing_csv parsing still rejects headerless files: format detection
is never guessed. The import manifest records the adapter and transformations.

The integration runner checks independent log-ratio/two-pass calibration against
the existing C++ log-difference/Welford result. Serial and four-thread-request
OpenMP native execution are separate from CUDA native connectivity at N=10000.
Equal native seeds do not imply equal samples. No GPU benchmark, timing speedup
or full-scale GPU acceptance follows from these checks. Build provenance and
runtime output remain local; the runner does not itself assert source-to-binary
correspondence. Existing synthetic evidence is retained unchanged.

## Converter verification

The artificial test set now also checks headerless row preservation, explicit
format selection, MM/DD/YYYY conversion, duplicate/invalid dates, malformed
prices, blank rows and extra fields. Provider observations are never embedded
in tests or CI. Live network acquisition is not part of hosted tests.

Local verification completed at code source 1b61903: clean-first Windows x64
Release CUDA build passed all eight CTests; CPU ON/OFF configurations passed
seven/six. The importer has 46 artificial checks. Genuine local calibration and
serial/OpenMP integration passed, followed by separate capped native CUDA smoke.
All source/build/runtime and numerical records remain ignored locally. These
are connectivity/calibration checks, not full-scale Monte Carlo acceptance.

The first exploratory acquisition occurred before the adapter commit; its raw
bytes and retrieval record remain intact. The reviewed import and integration
were repeated at the committed adapter revision. An additional local provenance
binding distinguishes acquisition, converter and rebuilt executable revisions;
it records the pre-existing untracked submission folder rather than claiming an
entirely empty Git status. Later downloader records also retain dirty state and
script hashes directly.
