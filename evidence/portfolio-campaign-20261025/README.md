# Portfolio campaign evidence: primary selection

The frozen v1 statistical protocol and original reference/native validation are retained here.
The **primary formal benchmark** is the complete
[benchmark-replacement-v1 dataset](benchmark-replacement-v1/README.md).

The first 546-process timing attempt overlapped an executor metadata serialization
which unexpectedly consumed CPU. Its entire timing interpretation was invalidated;
no individual slow row was removed or replaced. The single complete replacement
allowed by protocol v1 ran the same binary, fixtures, N grid, seed42, configurations
and 3 warm-up/10 measured policy in a new directory. No further replacements ran.

The original 20M reference runs and 135 native validation processes completed
before the interference and are reused unchanged. Their 270 comparisons rejected
no native quantile under the calibrated consistency test; at N=10M the realized
five-seed mean practical decisions remain 9 passed / 9 inconclusive / 0 failed.
No general portfolio VaR statistical acceptance is claimed.

- [Frozen prose protocol](PROTOCOL-v1.md), [matrix](protocol-v1.json), [initial freeze hashes](freeze-v1.json).
- [Reference and uncertainty](reference.json), [oracle checks](oracle-checks.json), [original native CSV](validation-raw.csv), [convergence](convergence.csv).
- [Primary timing summary](benchmark-replacement-v1/benchmark-summary.csv), [all primary raw samples](benchmark-replacement-v1/benchmark-raw.csv).
- [Primary figures](benchmark-replacement-v1/figures/runtime.png), [speedup](benchmark-replacement-v1/figures/speedup.png), [convergence](benchmark-replacement-v1/figures/convergence.png).
- [Attempt validity explanation](attempt-validity.json), [machine-readable primary selection](primary-selection.json).
- Retained invalidated first timing: [raw CSV](benchmark-raw.csv), [summary](benchmark-summary.csv), [original preparation record](attempt1-README.md), [original hashes](attempt1-artifact-sha256.json), [tooling snapshots](attempt1-tooling/portfolio_campaign.py).
- [Technical runbook](../../docs/portfolio-campaign.md).

There were 1092 timing processes in total across both complete attempts (252
warm-ups and 840 measured); only the second attempt, 546 processes / 126 warm-ups
/ 420 measured across 42 cells, supplies primary performance ratios. Native
statistical validation was not repeated. All first-attempt raw bytes and original
figures remain retained, with no evidence deletion or protocol-limit revision.

`python -B scripts/verify_portfolio_campaign.py` selects the primary dataset and
also checks retained first-attempt file hashes. `--local` additionally checks
full launch records, original reference arrays and binary bindings. Source/build
baseline is b33f061a75c17e579ce27bcc9915284e6d9d7812, with explicit uncommitted
new tooling. Existing single-asset requirements/campaigns and the initial
portfolio package are unchanged. No market prediction, advisor approval,
academic delivery or general race-freedom claim is made.
