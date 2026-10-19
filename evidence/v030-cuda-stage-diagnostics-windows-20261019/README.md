# CUDA stage-diagnostic checkpoint, 2026-10-19

Clean tested source: 80148cee0ba5a52b1c67ca98a6ad4eb91e4d7817. This is a
later technical documentation/evidence archive, not a new measurement or engine
change. The separate campaign completed 18/18 processes, six configurations and
three repetitions each, diagnostics ON and profiler OFF. The original final
auditor passed again at closure without launching a measurement.

Read [all six results, scope definitions and limits](../../docs/cuda-stage-diagnostics.md).
RNG has the largest mean among covered device-stage intervals; that does not
establish the largest end-to-end cost. Hybrid host global quantile spread is
retained. These instrumented results do not revise the closed primary benchmark.

## Selected records and exact bytes

- summary.csv / summary.json: original 66 timing-field rows, eleven per
  configuration, including mean and n-1 sample standard deviation.
- six-configuration-summary.csv / .json: original six-row wide summary with all
  timing means/spreads, requested/effective batch and batch count.
- samples.csv: derived projection of every one of the 18 attempts. All 11 raw
  timing tokens, five stage counts, batch/transfer metadata, both VaRs, ordering,
  UTC timestamps and target exit codes remain. Numeric strings are copied from
  raw target JSON tokens without Decimal/binary64 conversion or filtering.
- plan.json, fixture.csv and independent-fixture.json: exact original plan,
  public hand-written synthetic fixture and independent calibration.
- independent-audit-final.json: original passed final audit.
  original-final-reaudit.json reruns it with only the output path redirected.
  closure-audit.json verifies the 289 delivery hashes, unchanged 290-file set,
  correction bindings and the zero-sample incomplete first invocation.
- auditor-final-original.ps1 is the exact original final auditor, SHA-256
  434d58f1edd10f9bc11c3ade0627f21663fa5f23c74e34b8fce7cb5eb7bb0579.
  audit-original-failed.ps1 / audit-corrected-failed.ps1, audit-failed-1.json /
  audit-failed-2.json and both audit-correction records preserve the earlier
  failures. csv-decoding-observations.json preserves all 16 one-ULP observations.
  No raw measurement or acceptance threshold changed to pass an audit.
- session-final-verification.json is the original final verification, including
  3391 unchanged primary-session hashes and exact raw-token VaR comparisons.
- first-attempt.json records the initial incomplete CMake/MSBuild SDK sandbox
  failure before any sample. Its original manifest, exit 1 and raw logs stay local.
- conditions-status.json, runtime-environment.json, current-telemetry-summary.json
  and ctest-diagnostics.log are selected original condition/preflight records.
  The CTest log retains observed local paths. Physical declarations were not
  freshly confirmed; GPU point range was 49-52 C and CPU temperature/equilibrium
  remain unknown. Old ambient declarations are not new measured conditions.
- provenance.json binds exact copies plus original local manifests, JSONL,
  source/build settings, report and initial failure captures. Raw stdout/stderr,
  launcher records, telemetry dumps and build artifacts remain in ignored results/
  and build directories. This selected archive is not the complete raw session.
- artifact-sha256.json hashes all archived files except itself; .gitattributes
  disables newline conversion. Existing CRLF/blank lines in exact copies remain.

## Reusable auditor and explicit tests

Run from the repository root with the original local evidence and builds present:

```powershell
./evidence/v030-cuda-stage-diagnostics-windows-20261019/verify.ps1 -ReportPath results/new-review/audit.json
```

Create the output parent directory first. The report must be a new ignored file;
the wrapper rejects overwrites. Optional RepositoryRoot and Directory parameters
select the repository and campaign; original absolute build/launcher bindings
still require the recorded machine paths. No executable, CTest or measurement is
launched by this auditor.

verify.ps1 pins the exact archived final auditor hash and adapts only its root,
campaign/report locations and current-document comparison. Its complete archived
Git tree/index binding remains checked. Later README.md/docs/ edits are permitted;
every other archived source file still requires its exact current bytes, including
all auditor helpers and historical evidence. This permits documentation closure
without editing the original source snapshot. Statistical, configuration,
numerical and resource-lifetime validation logic is unchanged.

The wrapper was tested against the complete original campaign before and after
documentation updates. A separate ignored synthetic copy altered a summary mean
by 1 ms and updated its CSV/JSON and manifest hashes; independent recomputation
rejected it. Existing-report overwrite protection also passed. Those tests do
not create alternative measurement evidence. reusable-auditor-tests.json and
publication-validation.json record the checks; the post-documentation passed
report is reusable-reaudit.json. Original audit failures and samples stayed intact.

The name correction uses exported nvcc_version/device instead of internal C++
names. The final numeric correction compares serialized CSV/JSON tokens using
direct invariant binary64 parsing and exact equality, avoiding PowerShell 5.1
Decimal-to-double cast shifts. Independent mean/stddev checks retain the existing
2e-12 tolerance; no model or performance acceptance was relaxed.

## Remaining scope

Host total, Event pipeline span, cumulative stage intervals, copy Event sums and
hybrid host global quantile are distinct. The covered stage sum is only a limited
transfer-excluded diagnostic; no Event copy duration is subtracted from host time.
Unmeasured allocation/context/setup/staging/cleanup costs are not assigned causes.

The primary 9.739930524x serial / 8.307208722x best-OpenMP findings remain
unchanged: the 10x target was not met and hybrid did not beat best OpenMP.
Bandwidth/counter permissions/documented peak, convergence and final
reproducibility/delivery remain open. No profiling, optimization, new acceptance
or sanitizer campaign, academic authoring or automation occurred during closure.
Hosted CPU CI must be checked against the final pushed SHA separately from RTX
diagnostic evidence.
