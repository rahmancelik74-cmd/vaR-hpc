# Local browser application

A local Windows interface for the existing C++17 engines. It uses Python 3.11+
standard-library HTTP/process handling and buildless HTML/CSS/JavaScript. There
are no pip/npm runtime dependencies, accounts, network data requests or telemetry.
The application is separate from formal benchmark and acceptance workflows.

## Start

From the repository root, in PowerShell:

```powershell
python -B scripts/start_local.py
```

Open **http://127.0.0.1:8765**. Use a real Python 3.11+ installation on PATH (not
an unconfigured Windows Store alias). On the development computer the equivalent
command is `C:/Users/rahma/anaconda3/python.exe -B scripts/start_local.py`.
Prerequisites: Windows PowerShell 5.1, Git, Visual Studio 2022 C++ build tools
(including its Windows SDK), CMake >=3.24 and Ninja available on PATH. The launcher
loads the installed Visual Studio x64 developer environment in its child only,
configures a dedicated ignored build directory, and builds current Release
sources. It never changes global settings. CPU startup uses CUDA OFF and does
not discover the Toolkit. Compiler/build failures stop startup without fallback.

Optional explicit configurations:

```powershell
python -B scripts/start_local.py --cuda
python -B scripts/start_local.py --serial-only --port 8766
```

CUDA requires a compatible installed Toolkit/driver and NVIDIA GPU. The CUDA
launcher compiles for the local native GPU architecture, avoiding reliance on
newer PTX JIT support in an older driver. Moving that binary to a different GPU
requires rebuilding. GPU availability is established by a real startup execution,
not merely Toolkit presence; a failed probe disables that backend with its actual
error. Every analysis failure remains a failure; modes never fall back.

`--executable <path>` is an operator-only startup option, never a browser input.
It requires the build's `local-app-build.json` Release/source/executable SHA-256
fingerprints to match. Prefer the default rebuilding command. This is local
staleness detection, not signed build provenance. Ctrl+C stops the service and
cancels an active child. Closing a browser tab does not cancel a job; use Cancel.

## Examples and local data

Click **Try an example**, then **Run analysis**. Choose a single asset or the
two-asset portfolio. `local_app/examples` contains original redistributable
artificial prices and metadata, deliberately aligned to five actual session
dates. They are not market observations. Their example.invalid URLs label
artificial provenance, not fetched or independently verified sources.

For user files choose **Use my data**, add 1..5 assets, and select both a price
file and the original source metadata JSON for each asset. Set each positive
quantity, the inclusive date interval and the explicit session calendar. Click
**Validate files** before running. The browser uploads only selected file bytes;
server filesystem paths and executable commands cannot be supplied through it.

Supported UTF-8 (optional BOM), unquoted comma-separated CSV dialects, LF/CRLF:

- `date,close`, with ISO YYYY-MM-DD dates.
- `Date,Open,High,Low,Close,Volume` or
  `Date,Open,High,Low,Close,Adj Close,Volume`, with ISO dates. Explicit Close is
  used; Adj Close is never substituted. All numeric fields are validated.
- Explicit **Kibot daily**: headerless MM/DD/YYYY,Open,High,Low,Close,Volume.

XLSX, arbitrary column mappings, other date formats, quoted records, intraday
prices, FX conversion and missing/duplicate/unsorted records are unsupported.
Every original row is validated, even outside the selected interval. The existing
`scripts/import-equity-data.ps1` performs conversion and explicit inclusive
filtering, recording excluded counts and transformations. Reordering is never
enabled. Original CSV and metadata bytes are retained unchanged with SHA-256.
The preview shows actual selected prices, a short table and import hash.

Metadata follows `data/source-metadata.example.json`, with two additional required
fields, `currency_basis_url` and `close_definition`. Replace every placeholder
with the actual source details. Required declarations are source_name,
source_url, symbol, currency, retrieved_utc (original valid nonfuture UTC time),
download_method, price_adjustment_policy, price_policy_url,
local_reuse_conditions, reuse_policy_url, local_use_verified=true,
redistribution_permission, data_kind, currency_basis_url, close_definition.
Adjustment must explicitly be unadjusted, split_adjusted, or
split_and_dividend_adjusted; a Close header alone establishes none of these.
Source/price/reuse URLs must be HTTPS without credentials. Do not include API
keys or secrets. The importer validates declarations; it does not authenticate
provider identity, rights, prices or the operator's verification assertion.
The UI explicitly distinguishes declarations from locally checked hashes/session
sequences. See [data rights](data-rights-and-calendar.md) before using provider
files. Nothing in this application grants redistribution or publication rights.

Only the existing bounded **Nasdaq US cash equities 2023..2025** calendar is
supported. Requested dates outside that coverage fail. Every asset must exactly
match the same expected sessions, including interval edges, with at least three
observations. Early closes are sessions. No intersection, filling, interpolation
or multi-session daily return substitution occurs. No upload can replace or
extend the calendar. A calendar is not proof of individual-security coverage.

All assets must share currency (the explicit common valuation unit), source,
adjustment policy, Close definition and data kind, with unique symbols. There
is no currency conversion. Single-asset calibration invokes the existing C++
`--csv` tool; its new optional `--quantity` scales only initial holding value
before Engine::run (default 1, CSV only). Portfolio calibration calls the existing
`calibrate_portfolio.calibrate` function and serializes unchanged portfolio-v1;
asset order is ascending ASCII ticker. No calibration mathematics are duplicated.
Portfolio correlation/Cholesky checks and unsupported near-singular cases remain
unchanged. No general analytical portfolio VaR is manufactured.

## Analysis, limits and timing

Select one or several available engines for sequential comparison. Scenarios:
1..10,000,000; seed: uint64, kept as text to preserve every bit; horizon:
1..2520 trading days, at 252 observations/year. OpenMP threads:
1..min(32, logical CPU count). CUDA full-device rejects batch settings; explicit
hybrid requires 1..10,000,000 batch scenarios. The service independently validates
settings and incompatible backend options. There is one active operation,
including import/validation, and at most four sequential engine configurations.
A startup probe cannot guarantee future GPU memory availability.

Results use the actual engine JSON: 95%/99% nearest-rank VaR, V0, unit, N, seed,
model/horizon, backend/mode and engine wall time. Negative VaR is retained;
general portfolio analytical fields remain null. The engine timing boundary is
unchanged: allocation, RNG, simulation, quantile, necessary transfers,
synchronization and cleanup, excluding shared calibration and output. Application
elapsed time additionally includes settings validation, calibration, process
startup, output handling and sequential runs. Each selected engine uses a fresh
process; context/driver caches are not flushed. Timings are illustrative, not
formal benchmarks or statistical acceptance. Equal seeds across engines, modes
and batch partitions do not imply equal samples. No loss distribution is drawn.

Jobs expose running, completed, failed and cancelled states with elapsed time;
there is no fabricated percentage. Cancellation is a request until worker cleanup
finishes. Windows taskkill /T /F terminates the owned child tree; no arbitrary PID
is accepted by HTTP. Process timeouts are 120 seconds per child with a 180-second
job deadline checked during child execution. Small bounded Python validation/
serialization steps finish cooperatively. Failed/cancelled comparisons do not
produce downloadable completed results. Successful JSON/CSV downloads require
an explicit button click and include settings, provenance (including selected
input prices), hashes and build identity. Treat downloads as private when source
rights require it; do not publish them automatically.

Network/request limits: bind IPv4 loopback only; explicit localhost/127.0.0.1
Host allowlist, same-origin JSON POSTs, cross-site rejection, no CORS, no-store,
CSP and fixed static routes. Each file <=1 MiB; JSON request <=8 MiB (base64
included), at most 12 simultaneous HTTP handlers with 10-second socket timeout.
At most 12 validated datasets and 60 jobs per server session. A 512 MiB aggregate
app-storage admission limit reserves one maximum request; derived bounded
artifacts may add a small overhead. There is no arbitrary filesystem API.

Uploads, imports, settings, calibration artifacts, exact engine JSON and job
records stay under ignored `data/local/browser-app/<random-session>/`. Original
user files are never modified. Restarting drops in-memory session/job IDs but
preserves these files. No automatic recursive deletion runs. To free space,
stop the service and archive/remove only the identified browser-app session
folders; do not remove other `data/local` evidence. Port conflicts fail startup.
This is a local research tool, not a hardened public multiuser server.

## Verification

`ctest --test-dir build-local-app --output-on-failure` runs the registered current
engine regressions and the browser-service adapter tests. The latter compare
HTTP results against direct CLI JSON for identical artificial requests, exercise
single/portfolio and available engines/modes, downloads, malformed input,
missing metadata/calendar/sessions, invalid parameters, unavailable backend,
process failure/timeout, cancellation and request/file size guards. Tests use
Windows PowerShell for imports; those integration cases skip explicitly on
non-Windows hosts. Python >=3.11 is required for registration. Hosted CPU builds
remain CUDA OFF. Synthetic GPU checks are connectivity/regression checks, not
new campaigns, profiling or sanitizer studies.

## Presentation follow-up and verification boundary (2026-10-30)

Visible application elapsed milliseconds and engine wall milliseconds now use
exactly two decimal places. The running-state seconds already use one decimal
place. These are display-only formats: raw engine values, timing definitions,
JSON/CSV precision and VaR formatting are unchanged.

Starting a replacement analysis invalidates the previous download identity before
the request is sent. Thus an immediately rejected request, failed/cancelled job,
or replacement dataset cannot keep exporting the previous result as current.
Controller tests cover this lifecycle and unchanged result data, using explicitly
labelled test doubles; they are not browser evidence.

The follow-up attempted supported browser access again: the browser inventory
was empty and the Chrome browser surface reported unavailable. The Windows
Computer Use surface could discover Chrome, but stopped before navigation because
it could not determine the current URL confidently enough for policy checks.
No security bypass was attempted. No new browser flow or visual layout was
verified in this follow-up. In particular, UI hybrid selection, file selection/
preview/errors, cancellation/recovery, download clicks, desktop/narrow layouts
and focus/accessibility inspection remain unverified by this executor. The
reported observations from a separate chat are context, not new execution here.

Independent checks exercise real HTTP-to-C++ hybrid portfolio N=10003, batch=257
(39 batches, final payload 237), strict synthetic upload errors, cancellation and
recovery. JSON/CSV response parsing checks settings, estimates and raw engine
milliseconds. These checks do not establish browser download behavior or visual
presentation. No private provider data or formal campaign is involved.

The remaining manual action is to open the local URL and perform the listed UI
flows, including a narrow viewport and parsing files saved by the download
buttons. Browser-tool access must be restored before automated visual claims.


## Public errors and private diagnostics

Expected importer validation guards now attach explicit error codes. The optional
`-ErrorReportFile` importer parameter writes a schema_version=1 sidecar containing
only that code; existing invocations keep their success JSON and nonzero failure
behavior. The browser adapter accepts only known codes and uses authored English
messages. It never parses PowerShell stack text to infer a cause. Unknown child
failures identify the operation and suggest retrying/reviewing private diagnostics
without claiming an unknown cause. The public job keeps its compatible `error`
string and adds `error_code`; exception traces, paths and commands are excluded.

Each child stdout/stderr stream is stored verbatim as `.stdout.bin`/`.stderr.bin`
under the private app session/job directory. Sibling `.process.json` records keep
argv, operation, return code and encoding policy; Python exception chains are
stored in private `*-exception.txt` files. None has an HTTP download route.
Importer children invoked with the sidecar option explicitly select UTF-8 for
redirected console output within that child only. Other stderr encodings are
not guessed: original bytes are authoritative. No console/Git setting is changed
globally, and diagnostic bytes are never normalized or substituted.

Error notices use alert semantics; successful notices use status semantics.
Status and notice containers allow wrapping within narrow widths. Controller
regressions cover failed/cancelled/replaced-result invalidation. Focused real
Windows HTTP/importer checks cover insufficient rows, nonnumeric price with
sufficient rows, missing sessions, missing metadata, unexpected process failure,
private exact-byte capture, UTF-8 non-ASCII output and valid-analysis recovery.
The registered local-browser CTest includes these focused checks.

For this error follow-up, the supplied private observation record and screenshot
were read as third-party observations and were not copied into the repository.
Direct browser inspection was attempted: no enabled browser appeared in the
executor inventory, and creating an IAB tab returned Browser is not available.
Desktop/narrow visual and assistive-technology presentation therefore still
require manual inspection at the local URL. HTTP/controller tests are not
browser verification. No previously completed research campaign was repeated.
