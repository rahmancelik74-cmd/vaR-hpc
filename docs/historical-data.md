# Historical equity import

Working candidate: MSFT daily closing prices, requested inclusive interval
2023-01-01 through 2025-12-31. One share, ten trading days and 252 observations
per year remain **working settings**, not final study decisions. Expected
currency is USD; confirm it in the selected provider's documentation. No
currency conversion, adjustment or return normalisation is performed.

Continuation on 2026-10-17: a documented free Kibot guest evaluation path is
accessible. The dated acquisition blocker below is retained as history, not the
latest availability claim. See [Kibot evaluation](kibot-evaluation.md) for the
explicit unadjusted format, restricted license and local-only workflow.

Subsequent verified state: genuine local integration is complete. The current
rights review and separate session-date audit are documented in
[data-rights-and-calendar.md](data-rights-and-calendar.md). As of 2026-10-18,
user-supplied provider correspondence permits final academic experiments for
internal use on the user's two normally used computers and sharing derived
results without raw data. Raw-price resale/redistribution remains prohibited.
The original mailbox export and sender/date metadata are archived outside the
repository; the correspondence is not independently authenticated. The linked
rights record defines the scope and supersedes earlier permission-pending
statements. Existing manifests and ignored outputs are preserved; no derived
results are automatically staged. The older acquisition blocker below is history.

## Acquisition and policy status on 2026-10-16

No provider dataset has been approved or imported. Genuine coverage, row
count, hashes and historical calibration values are unavailable. The code is
verified with explicitly artificial fixtures only. The existing synthetic
campaigns remain historical evidence and are not relabelled as MSFT results.

Stooq was evaluated as a free daily-CSV candidate:

- Candidate download: <https://stooq.com/q/d/l/?s=msft.us&i=d&d1=20230101&d2=20251231>.
- Historical download information: <https://stooq.com/db/h/>.
- Terms candidate: <https://stooq.com/t/>.
- Ordinary HTTPS requests to all three returned HTTP 200 with an HTML
  JavaScript browser-verification page, not CSV or readable policy text.
  No challenge was solved, headers impersonated or access control bypassed.
  The converter rejects that HTML. No genuine price bytes were obtained.
- Local reuse conditions, redistribution permission and the precise adjustment
  policy could not be verified from these primary pages. In particular, a
  column named Close is not evidence that prices are unadjusted. Do not label
  Stooq Close as unadjusted or use it as a silent substitute for another series.

Alpha Vantage is a second evaluated source, not an acquired dataset:
[official API documentation](https://www.alphavantage.co/documentation/)
defines TIME_SERIES_DAILY as raw as-traded OHLCV. Its free compact output is
limited to the latest 100 observations; full history requires a premium key.
That cannot supply the requested three-year range under the no-paid-service
constraint. No account, key or subscription was introduced. The
[official terms](https://www.alphavantage.co/terms_of_service/) describe
personal non-commercial use subject to their agreement. This review does not
establish redistribution permission or approval for public project datasets.

Nasdaq's public MSFT historical page was also inspected; its accessible page
did not establish a usable complete dataset plus verified adjustment/reuse
policy. No undocumented endpoint or access workaround was used.

**Remaining inputs:** a lawfully obtained provider CSV covering the requested
MSFT interval, and a completed source metadata JSON identifying the actual
download URL/time, USD currency, Close-field adjustment definition, local reuse
conditions and primary policy URLs. A provider file alone does not resolve an
unknown price policy. The example metadata intentionally fails validation until
its placeholders and policy status are resolved. Do not invent retrieval times
or assert permission based only on public accessibility. The importer records
the operator's documented policy verification; it cannot establish legal rights.

## Reproducible offline conversion

Windows PowerShell 5.1 and built-in .NET are sufficient. No network request is
made by the importer. Download manually through an authorized provider method,
preserve the original bytes, and make a local copy of
`data/source-metadata.example.json` with genuine provenance. Keep both local.

```powershell
./scripts/import-equity-data.ps1 `
  -InputFile C:/path/to/original-msft.csv `
  -MetadataFile C:/path/to/source-metadata.json `
  -OutputDirectory data/local/msft-20230101-20251231
```

Use `-AllowReordering` only when explicit ascending reordering is intended.
The source order (ascending/descending/mixed) and transformation are recorded.
Use a new output directory for every import; existing records are not overwritten.
All output must be below ignored `data/local/`, even if metadata claims verified
redistribution permission. Publication requires a separate review; this code
never promotes provider data into tracked files.

Accepted exact headers:

```text
date,close
Date,Open,High,Low,Close,Volume
Date,Open,High,Low,Close,Adj Close,Volume
```

The selected field is always explicit Close/close, never Adj Close. The latter,
if present, is validated but unused. Adjustment policy must explicitly be
unadjusted, split_adjusted or split_and_dividend_adjusted, supported by the
provider's price definition. Selecting a provider-adjusted Close does not turn
it into unadjusted prices; the manifest preserves the declared policy.

The narrow source dialect supports UTF-8 with optional BOM and LF/CRLF. Quoting,
currency symbols, thousands separators, whitespace-padded fields and other
headers/dialects fail explicitly. All source rows are validated before interval
selection: valid ISO dates, unique dates, exact field counts, finite positive
prices (including unused OHLC/Adj Close), consistent OHLC ranges and nonnegative
integer volumes. Blank records, nulls and malformed UTF-8 are errors. Reordering
without the flag is an error; duplicate dates always fail, including outside
the selected interval. No bad rows are skipped and no missing observations are
filled. The interval filter counts valid out-of-range rows separately.

Output contains `raw.csv` (exact source bytes), `source-metadata.json` (exact
provided metadata bytes), strict `prices.csv` and `manifest.json`. The converted
CSV uses date,close, increasing dates, unchanged Close numeric text, LF and no
BOM. The manifest records requested/actual/source date ranges, source/selected
row counts, outside-range exclusions, source order, transformations, original
retrieval time, conversion time, SHA-256 hashes, converter revision/hash and Git
dirty state. The interval boundaries need not be trading days. Returned rows
alone do not prove exchange-calendar completeness; that remains unverified.

The one-share initial value is the latest selected Close. Corporate actions,
dividends and missing trading sessions need explicit interpretation when choosing
the final study dataset. This model study makes no market-prediction claim.

## Independent calibration and integration

The independent PowerShell calculation uses log(P[i]/P[i-1]) and a two-pass
sample variance. C++ uses log(P[i])-log(P[i-1]) and Welford's online update.
Tests verify known fixture returns log(1.1), log(0.9), log(1.2), then compare
return count, mean, sample variance and all calibrated model fields against
actual C++ JSON. An intentionally perturbed C++ result must fail. Comparison
tolerance is abs(actual-reference) <= 1e-12*max(1,abs(reference)); this calibration
test tolerance does not change any project acceptance condition.

After genuine data and policy verification become available, build Release
from the intended revision, run CTest, then run:

```powershell
./scripts/check-equity-integration.ps1 `
  -ImportDirectory data/local/msft-20230101-20251231 `
  -CpuExecutable build-openmp/Release/mc_var.exe `
  -CudaExecutable build-cuda-skeleton/Release/mc_var.exe `
  -OutputDirectory results/msft-integration-unique-name
```

This performs fresh serial/OpenMP native runs and a separately labelled CUDA
native smoke, all at N=10000, seed 42, both confidence levels, working 10/252
settings and OpenMP request 4. It verifies calibration and backend metadata;
it does not compare unrelated native RNG estimates for numerical equality.
Independent log returns, calibration, raw backend JSON and hashes remain under
ignored results. CUDA can be omitted explicitly; its status is then not_requested,
never passed. Artificial imports are rejected by the historical runner.
An explicit `-FixtureTestOnly` mode is reserved for artificial-fixture tests;
it requires artificial metadata and labels every manifest as a fixture test,
never as a historical campaign. Tests exercise available backend branches and
the hash-tampering rejection without creating fictional provider observations.

The supplied executable hash is recorded, but source-to-binary correspondence
is not asserted by this runner. Keep the Release build log externally when
running a genuine campaign. One process per backend includes the existing
engine timing boundary; these are connectivity checks, not benchmarks or
full-scale GPU statistical acceptance. GPU N remains capped at 10000. At the
2026-10-16 preparation stage, genuine historical integration was blocked; the
later Kibot evaluation completed local integration as recorded above.

## Verification and publication

`equity_import_tests` runs on Windows in CTest, including hosted Windows CI.
It uses generated artificial fixtures and the built C++ CLI, requires no provider
network access, and leaves local artifacts under ignored data/local/test-import-*.
Linux CPU tests retain their existing configuration without a PowerShell dependency.
Only code, this protocol and non-data example metadata are suitable for commit.
Do not stage provider bytes, converted data, calibration outputs, academic
documents, or previous local submission copies.

Local verification on 2026-10-16: MSVC 19.44.35227.0 Windows x64 Release;
OpenMP ON/CUDA OFF passed all 7 CTests, serial-only passed all 6, and CUDA ON
passed all 8 on the RTX 4060 Laptop GPU (nvcc 13.4.92, architecture 89).
The converter test contains 38 artificial-data checks, including the integration
runner's available backend branches. These counts include existing engine
regressions and are not historical equity-data acceptance evidence.
