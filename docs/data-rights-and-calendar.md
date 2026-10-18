# Historical data rights and session-date audit

Updated: 2026-10-18, Europe/Istanbul. The genuine MSFT local integration is
already complete. No acquisition, calibration, model or engine setting changed.

## Current permission scope: user-supplied correspondence, 2026-10-18

The user supplied a Kibot reply permitting the following project-specific uses.
Its contents were also read through the connected Gmail mailbox and match the
supplied scope. This is provider correspondence supplied by the user, not an
independently authenticated email or a general change to the published license.

- Guest-downloaded data may be retained and used for final academic experiments
  for the user's own internal use on the two computers normally used.
- Raw prices may not be resold or redistributed. Raw and converted observations
  remain private in ignored data/local; no price dataset is included in Git.
- Derived statistics, calibration parameters, VaR estimates and charts may be
  shared in reports, supervisor/committee copies, submissions, public thesis
  or project documentation and outside reviews, provided they contain no raw
  data. Charts must not reproduce raw price observations.
- Acquisition methods, guest API requests and download scripts may be described
  publicly without publishing price data. Attribution is optional.

The reply was exported from Gmail in raw RFC 2822 form, including its headers
and attachment bytes, to the private location outside this repository:
`../private-evidence/kibot-permission-20261018/provider-reply.eml`.
`archive-metadata.json` alongside it records the observed sender/date headers,
export time and exact-byte SHA-256. The archive is a mailbox export; sender
identity and authority were not independently authenticated. No complete email,
personal contact details or private archive bytes are published in this repository.

This scoped permission supersedes the permission-pending conclusion below and
earlier pending statements in project records. It does not authorize raw-data
sharing or use outside the stated scope. Derived local outputs stay ignored and
are not automatically selected for Git: any future publication must select only
permitted material containing no raw data. Existing raw bytes, metadata, hashes
and import/integration manifests remain unchanged as historical provenance;
their earlier evaluation-only flags describe the acquisition-time decision.
No final study settings or computational acceptance results follow from permission.

## Historical rights decision: 2026-10-17

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
