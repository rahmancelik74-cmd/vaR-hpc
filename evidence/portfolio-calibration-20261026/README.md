# Real historical portfolio calibration: local technical evidence

Starting source: main c21efc1258898aabe26d065de7c50961b79e94e0. Source changes
are local and uncommitted. The private provenance manifest binds current local
source bytes, baseline, actual build caches/executables and input/output bytes.
Exact local-byte hashes differ conceptually from normalized Git blob identities.
No earlier evidence was overwritten or relabelled.

## Result and boundaries

REAL two-asset calibration completed locally using existing MSFT and a newly
acquired AAPL Kibot guest daily dataset, USD, requested inclusive
2023-01-01..2025-12-31. Tickers and requested interval are working selections,
not supervisor-approved final research decisions. Shared Nasdaq calendar sessions
must match exactly for both assets. All sample covariances use the same aligned
return rows with n-1 denominator. Valuation uses the final common session;
one positive share per asset, 252 sessions/year and 10-session horizon are explicit.
Asset order is ASCII ticker order. See [PC-1..PC-4](../../docs/portfolio-calibration.md)
for the contract, predeclared 1e-12 scaled arithmetic tolerance and singularity
guard; no tolerance was loosened after testing.

The provider's [history specification](https://www.kibot.com/api/history-request.html)
defines `unadjusted=1` as no split/dividend back-adjustment. The
[format reference](https://www.kibot.com/file-format/data-format-reference.html)
defines Close as last regular-session trade, potentially different from the
official closing auction. No dividends are reinvested or added as cash flows.
[Guest access](https://www.kibot.com/api/api-overview.html) was checked for
additional US-stock daily access; no account, purchase, key or bypass occurred.
Apple's [issuer release](https://www.apple.com/newsroom/2025/07/apple-reports-third-quarter-results/)
and the Nasdaq instrument page support AAPL identity/currency; the CSV itself
does not encode currency. Calendar identities were matched to the US Nasdaq
listings and the existing bounded primary-source calendar.

The [Kibot license](https://www.kibot.com/license.html) restricts internal use
and redistribution. The existing [project rights record](../../docs/data-rights-and-calendar.md)
retains user-supplied project permission for internal academic experiments and
selected derived publication, with its independent-authentication limitation.
This task conservatively publishes no actual provider prices, numerical dataset
statistics, calibration values, dataset hashes, VaR results or correspondence.
Metadata assertions are not legal rights verification or email authentication.

## Actual verification

The production path reuses validated import manifests and converted prices.
The independent path re-reads retained original headerless Kibot bytes, checks
their exact hashes and original-to-converted date/Close equivalence, reconstructs
the full session sequence, then uses 60-digit Decimal log ratios and two-pass
mean/covariance. All mean/covariance/correlation/drift/volatility/horizon comparisons
passed the predeclared arithmetic tolerance. Actual numerical differences remain
in private `independent-audit.json`; this public statement contains no restricted
derived values. No synthetic VaR reference or campaign target was used.

The regenerated current CUDA Release executable ran one fresh native process
per backend at N=10003, seed 42, confidence .95/.99: serial, OpenMP request 4,
CUDA explicitly full-device. All passed ordered asset/quantity/price/drift/
volatility/correlation/unit/horizon/seed/backend checks. CUDA metadata confirmed
device quantile, CUB 300403, no host sorting and the RTX 4060 Laptop device.
No native CPU/GPU VaR equality is asserted. Existing common-input tests passed
separately, including ownership checks and the stricter portfolio numerical
bound. This task does not add new memory/race certification or formal timing.

Windows x64 Release builds/checks: CUDA/OpenMP 21/21 CTests; CUDA OFF/OpenMP
18/18; CUDA OFF/OpenMP OFF 17/17. Relevant caches preserve CUDA optional/default
OFF behavior, architecture 89 for the CUDA build, --fmad=false and CUB 3.4.3.
The Python synthetic suite covers known positive/negative/near-zero correlations,
independent annualization, 2..5 assets, ordering, malformed/duplicate dates,
missing sessions (including shared missing dates), incompatible calendars,
currency/adjustment/Close mismatches, insufficient rows, zero variance,
singular/near-singular matrices, invalid prices/nonfinite/overflow, exact-byte
tampering, excluded dates, common valuation and independent-auditor corruption.
CLI success/output hashes/no-overwrite are exercised without provider data.
All 50 Python regressions passed, including 17 focused calibration/auditor tests.
The new tests are registered in CTest and existing hosted Python discovery.

No engine sources changed. The existing CUDA build was regenerated/rebuilt
from the baseline engine sources plus current CMake registration; CPU builds
regenerated successfully and required no C++ recompilation. Their caches and
actual executables are bound privately. These are incremental builds, not a
claim of fresh empty-directory builds. Unmeasured temperatures, clocks, power
and thermal equilibrium remain unknown. No performance ratio is reported.

## Retained attempts and private locations

- `data/local/aapl-kibot-download-20261026/`: failed PowerShell HTTPS attempt.
  Python urllib with normal certificate verification succeeded; no TLS validation
  was disabled. The generalized PowerShell experiment was reverted, preserving
  the original single-asset downloader behavior.
- `data/local/aapl-kibot-python-20261026/`: exact successful response bytes,
  complete policy/identity snapshots, retrieval timestamps, private acquisition
  script, original metadata and separate canonical-wording metadata.
- `data/local/aapl-kibot-import-20261026/`: first valid import; retained.
  `aapl-kibot-import-canonical-20261026/`: new import with Close-definition wording
  matching MSFT; meaning and source prices are unchanged. Original metadata was
  not overwritten. Existing `msft-kibot-import-1b61903/` remains unchanged.
- `data/local/portfolio-calibration-20261026/request.json`: explicit private
  reproducible request and importer log.
- `results/portfolio-historical-20261026-v1/`: initial successful integration;
  preserved after adding provenance/accounting checks. `-v2/` retains the next
  successful run. `-v3/` adds exact RNG-label, initial-value and finite VaR output
  checks. Final `-v4/` additionally retains explicit top-level historical versus
  artificial source labels in calibration/audit/integration records. These modest
  checks are not a measurement campaign.
- `results/portfolio-calibration-20261026/`: final source/build/output provenance
  and persistent completion record under `final-v4/`; the earlier v3 record is
  preserved separately. Regression logs/test inventories are retained
  under `results/portfolio-calibration-*-20261026.*`.
- Existing `../private-evidence/kibot-permission-20261018/` remains outside Git.

Two initial synthetic test expectations were corrected: two returns necessarily
give a rank-deficient two-asset covariance, and large annualization alone did not
overflow the originally selected small-return fixture. The exclusion fixture now
has enough returns; the overflow fixture uses genuinely overflowing values.
The declared numerical tolerance and matrix guard did not change.

## Delivery and limitations

No new commit, push or hosted CI result exists in this executor. An actual
`git add -- CMakeLists.txt` failed creating `.git/index.lock` (permission denied);
`gh auth status` reported the existing token invalid. Neither was retried
unchanged. A command-local OpenSSL remote read confirmed main still at the
starting SHA. Existing baseline successful CI is historical only:
[run 40317798314](https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/40317798314).

The new [delivery script](../../scripts/deliver-portfolio-calibration.py) uses a
reviewed explicit allowlist and local-byte manifest, UTF-8 native output,
noninteractive/bounded Git and credentials, unchanged main-parent checks,
CRLF-aware whitespace checking, no force push, persistent commit/push state,
remote SHA verification and bounded exact-SHA CI job validation. It cannot fix
permissions or authentication. One manual step: execute it in an ordinary
authorized session with existing working GitHub authentication. A partial
commit/push can be resumed using its private saved state.

GBM's constant parameters and normal log increments do not establish market
prediction or investment suitability. Calendar agreement does not certify prices,
corporate actions, individual-security halts or provider completeness beyond
the checked session set. Standard Cholesky rejects some near-singular valid
statistical models. Portfolio hybrid is explicitly unsupported; single-asset
hybrid behavior is preserved. No academic deliverable or submission occurred.
