# Historical data rights and session-date audit

Reviewed: 2026-10-17, Europe/Istanbul. The genuine MSFT local integration is
already complete. This follow-up neither repeats acquisition/integration nor
approves a final research dataset.

## Rights decision

The current [Kibot license](https://www.kibot.com/license.html) restricts data
to internal use, prohibits redistribution and transfer, and includes related
or derived information in its Data definition. The
[API overview](https://www.kibot.com/api/api-overview.html) describes guest
access as evaluation rather than production. These published terms establish
the existing local evaluation boundary; they do not establish permission for
sharing the dataset or derived research tables with a supervisor or the public.

Final research/publication approval remains unresolved. The next decision is
explicit provider permission covering the intended research, academic delivery
and publication uses, or selection of a source with suitable documented rights.
Do not infer permission from free access, anonymization or aggregation. No
provider contact, account creation, purchase or dataset substitution is performed
by this workflow. A pending permission response does not establish approval.
Complete current license/access snapshots and their exact-byte hashes remain
under ignored data/local. A direct calendar-page download encountered a 403;
it was not bypassed. Primary calendar text was reviewed through web access.

## Calendar definition

The explicit reference is
`data/calendars/nasdaq-us-equities-2023-2025.json`. It describes Nasdaq US cash
equity session dates in America/New_York for the requested historical years.
Weekends and full exchange closures are excluded. Early closes remain expected
daily observations. Federal banking holidays are not a substitute.

The reference records Nasdaq's annual calendar URLs. Regular holiday and early
close dates were cross-checked against the primary
[ICE/NYSE historical cash-equity schedule](https://ir.theice.com/press/news-details/2022/NYSE-Group-Announces-2023-2024-and-2025-Holiday-and-Early-Closings-Calendar/default.aspx).
That table is explicitly a cross-check from another US equity venue, not a
claim that MSFT is NYSE-listed. The additional January 9, 2025 mourning closure
is established by [Nasdaq ETA2025-1](https://www.nasdaqtrader.com/TraderNews.aspx?id=ETA2025-1).
The reference has bounded coverage and must be reviewed before extending it.

## Read-only local audit

```powershell
./scripts/check-equity-calendar.ps1 `
  -ImportDirectory data/local/msft-kibot-import-1b61903 `
  -OutputDirectory results/msft-calendar-audit-unique
```

The offline checker verifies the import's exact-byte raw, metadata and price
hashes, validates the imported date order, interval and coverage metadata, and
compares date sets over the entire requested interval, including its edges.
The report lists missing and unexpected dates separately and retains annual
counts, early-close session flags, calendar/source references, script hashes
and input hashes. A discrepancy produces a useful error and nonzero exit code
after writing the private report. Invalid inputs fail without a success report.

Outputs must use a new directory below ignored results. Neither rows nor
prices are added, deleted, reordered or overwritten. The original import
manifest is immutable; its earlier calendar status remains historical evidence.
The separate audit does not validate prices, intraday completeness, corporate
actions or individual-security halts, and never grants publication rights.
Reports and session comparisons derived from provider data remain local.

## Verification and continuation

The existing import was audited locally; all observation-derived details and
the audit conclusion remain in ignored results. No data or model settings
changed, so no calibration or backend integration rerun was required. The
previous verified integration and historical evidence are preserved.

Thirteen artificial checks cover early closes, weekends, the exceptional closure,
missing/unexpected sessions, hash tampering, coverage metadata, calendar
conflicts/duplicates, output restrictions, PowerShell-relative paths and standalone CLI execution. The
new Windows `equity_calendar_tests` CTest passed in the existing CPU build.
No C++ engine or CUDA configuration changed; the N <= 10000 guard remains.
Full-scale CUDA, benchmarks and academic authoring are outside this follow-up.
