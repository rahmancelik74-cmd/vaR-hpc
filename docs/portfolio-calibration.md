# Historical portfolio calibration

PC-1..PC-4 extend the portfolio register only. FR-1..FR-9/NFR-1..NFR-9 and
engine contracts are unchanged. Portfolio hybrid remains unsupported.

## Contract frozen before historical evaluation

PC-1: 2..5 equity imports produced by `import-equity-data.ps1`, one currency,
same provider, Close definition and verified adjustment policy. Each import's
raw, original metadata and converted prices must match its manifest's exact-byte
SHA-256. Import manifests are provenance records, not authenticated signatures.
The operator must verify actual rights, instrument identities and calendars.
Metadata alone cannot establish licensing or data truth.

Working dataset: Kibot MSFT and AAPL, Nasdaq US common equities, USD, inclusive
2023-01-01..2025-12-31, daily regular-session last-trade Close, explicitly
`unadjusted=1`: no split or dividend back-adjustment. Dividends are not
reinvested or included as cash flows. These are reproducible working choices,
not supervisor-approved final research decisions. The existing
[rights record](data-rights-and-calendar.md) and its correspondence authentication
limitations remain applicable. Newly obtained data must pass validation; MSFT
availability alone does not establish AAPL availability. No provider bytes or
observation-derived numerical values are selected for publication here.

PC-2: Strict common-window policy. Validate every imported row, including outside
the requested interval; reject malformed, duplicate, unsorted, nonpositive or
nonfinite observations. Explicit inclusive interval selection retains excluded
dates and counts. Each selected date sequence must equal the same bounded
exchange calendar's expected sessions, including interval edges. No intersection,
pairwise deletion, forward filling, interpolation or automatic reordering.
Calendar weekends/full closures are skipped; early closes remain sessions.
Missing trading sessions fail even when absent from every asset. No multi-session
return is annualized as a daily return. The bounded reference covers 2023..2025;
extending it requires primary-source review. Individual-security halts and price
accuracy are not established by an exchange calendar.

PC-3: Asset order is ascending ASCII ticker, independent of configuration order.
All assets use the final expected session's Close as their common valuation date.
Positive quantities are explicit; the working example uses one share each.
Use log(P[t])-log(P[t-1]), algebraically log(P[t]/P[t-1]), with a shared online
multivariate mean/covariance update, denominator n-1 for n aligned returns.
At least two returns are needed. dt=1/252 years and horizon=10/252 years are
working settings, explicit in the request. sigma=sqrt(s2/dt),
mu=mean/dt+sigma^2/2; R_ij=cov_ij/(sqrt(s2_i)*sqrt(s2_j)).
No hidden currency, quantity or horizon conversions occur.

PC-4: Reject zero variance, nonfinite/overflowed statistics, invalid correlation,
singularity and near-singularity. Match the engine's standard lower Cholesky:
each squared pivot must exceed 1e-14 and reconstruction absolute error <=2e-12.
No clipping, regularization or input matrix replacement. Some positive-definite
near-singular matrices are deliberately unsupported. A constant asset is rejected
because its estimated correlation is undefined, although manually supplied
zero-volatility portfolios remain supported by the engine.

## Predeclared checks

Calibration arithmetic tolerance: abs(actual-reference) <=
1e-12*max(1,abs(reference)), fixed before evaluation. Independent synthetic
fixtures use chosen returns with hand-derived means, n-1 covariance, positive,
negative and zero correlation. An independent real-data path re-reads original
headerless Kibot bytes using Decimal log ratios at 60-digit precision and a
two-pass covariance, then compares all parameters, covariance and correlation.
Source-byte hashes are checked separately. Tolerance is arithmetic agreement,
not a historical VaR accuracy or statistical acceptance target.

## Offline command

Python >=3.11, standard library only (including Decimal.ln for the independent
audit). CMake registers the new synthetic test when that interpreter is found.

`python -B scripts/calibrate_portfolio.py --request <private-request.json>
--output results/<new-name>`

Request paths are relative to the request file. Example schema (use actual
validated imports, keep the request under ignored data/local):

```json
{
  "start": "2023-01-01", "end": "2025-12-31",
  "calendar": "../../../data/calendars/nasdaq-us-equities-2023-2025.json",
  "frequency": "daily", "days_per_year": 252, "horizon_days": 10,
  "assets": [
    {"import": "../msft-kibot-import-1b61903", "quantity": 1},
    {"import": "../aapl-kibot-import-20261026", "quantity": 1}
  ]
}
```

The explicit common calendar declares both listings' expected session schedule.
Output is restricted to a new directory under ignored results. `portfolio.txt`
uses unchanged portfolio-v1; `calibration.json` retains source hashes, all aligned
dates, excluded dates/counts, conventions, asset order, statistics, tool hashes,
Git revision and dirty state. `request.json` and `calendar.json` retain exact
input bytes. Output is private even when source permissions allow selected
derived results. Do not stage it. Use the existing CLI, for example:

```text
mc_var --portfolio results/<new-name>/portfolio.txt 10003 42 --backend serial --json
mc_var --portfolio results/<new-name>/portfolio.txt 10003 42 --backend openmp --threads 4 --json
mc_var --portfolio results/<new-name>/portfolio.txt 10003 42 --backend cuda --cuda-mode full-device --json
```

Fresh native RNG runs are integration checks, not equal-sample comparisons,
formal timing, convergence or predictive-validity evidence. Retained common-input
engine regressions remain separate. Hosted tests use only synthetic data and no
network. Actual outcomes and delivery status are recorded in the new evidence
package and persistent private completion record.

Independent original-byte audit and optional native integration:

```text
python -B scripts/verify_portfolio_calibration.py results/<new-name> --executable build-portfolio-ninja-cuda/mc_var.exe --cuda
```

Without `--cuda`, CUDA is explicitly `not_requested`; without `--executable`,
only independent calibration is checked. The original-byte auditor supports the
explicit Kibot daily format; the calibrator accepts validated strict Close CSV
imports from the existing importer. Neither downloads data. The auditor refuses
to overwrite previous evidence. A failed native process retains its stdout/stderr
but produces no successful integration record.
