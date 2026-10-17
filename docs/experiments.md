# Experiment recording v0.2.2

## CLI output contract

Existing positional CLI commands retain their text output. Append `--json`
as the final argument to emit one JSON object on stdout. Failures return a
nonzero exit code and an English error on stderr. No partial JSON is emitted
if result serialization fails. `--version` remains a separate command.

Example:

```powershell
.\build-foundation\Release\mc_var.exe --csv .\data\synthetic_prices.csv 10000 42 10 --json
```

Schema version 1 includes the model, input mode, optional CSV calibration,
backend and RNG labels, N, seed, both VaR estimates and their analytical errors,
and engine time. The uint64 seed is a decimal string so JSON consumers cannot
round it. Doubles use 17 significant digits and a decimal dot independent of
locale. File paths and exact-byte hashes belong in the experiment manifest,
not in the application result. No market-prediction claim is made.

## PowerShell runner

Requires Windows PowerShell 5.1 or later, Git, and a built v0.2.2 or v0.3.0 executable.
It uses only built-in PowerShell/.NET facilities. Default mode is a small smoke
run, which is not a benchmark or acceptance decision. Run from the project root:

```powershell
& .\scripts\run-experiment.ps1 -Mode smoke
& .\scripts\run-experiment.ps1 -Mode validation
& .\scripts\run-experiment.ps1 -Mode benchmark
```

If local script execution is blocked, invoke the file with a process-scoped
policy, without changing a persistent machine/user setting:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-experiment.ps1 -Mode smoke
```

Validation defaults: N=10000,100000,1000000,10000000 and seeds
42,123,456,789,2026, one run per pair. It records observations; it does not
approve proposal identity or decide supervisor acceptance. Benchmark defaults:
N=100000,1000000,10000000, seed 42, three warm-ups and ten measured runs per
configuration, native backend RNG. Each repetition uses the same seed to keep
that workload fixed; these timing repeats are not independent statistical seeds.
`-ScenarioCounts` and `-Seeds` allow explicitly recorded custom campaigns.
The CSV path, executable and trading-day scale can also be supplied as parameters.
Serial remains the default for all modes. Smoke also accepts `-Backend openmp`
and `-Threads 4` with an OpenMP-enabled v0.3.0 executable. Explicit threads
require OpenMP; OpenMP validation/benchmark requests fail before execution.
Serial CLI arguments retain v0.2.2 compatibility. See the small
[synthetic demo](synthetic-demo.md) for paired commands and interpretation.
OpenMP correctness recording uses
the separate scripts/run-openmp-validation.ps1; see [openmp.md](openmp.md).
Fresh serial/OpenMP performance scaling uses scripts/run-cpu-benchmark.ps1
and its independent verifier; see [cpu-benchmark.md](cpu-benchmark.md). It uses
its own fresh serial reference and does not repurpose historical serial timings.
Schema 1 now also includes requested_threads, threads_used and openmp_version.

Every run starts a new CLI process. The reported timer is inside the engine;
process startup, loading/calibration and export are excluded. This is the
current documented timing boundary. It does not measure a future persistent
GPU session. Future GPU process/context and initialization policies must be
specified explicitly before comparing backends.

A unique directory under ignored `results/` contains:

- `manifest.json`: mode/status, commit/dirty state, executable/input exact-byte
  SHA-256, configuration, environment basics and timestamps.
- `runs.jsonl`: full application results, run identifiers and phases, including
  warm-ups. Written after every successful run to retain partial evidence.
- `estimates.csv`: one row per confidence per run, with phase and run ID.
- `timing-summary.csv`: benchmark-only statistics using measured runs once each,
  excluding warm-ups. Sample standard deviation uses denominator repetitions-1;
  throughput is N divided by mean engine seconds. No speedup is invented.
- `CMakeCache.txt`, when located next to the expected Release build directory.

The time in each estimate row is the time of the entire shared run. Never sum
it over confidence levels. Use run IDs or timing-summary.csv for timing analysis.
Failed experiments keep status=failed and must not be treated as complete.
Input/executable hash changes or a Git revision change fail the experiment.

The manifest records a dirty tree instead of hiding it. A commit plus an
executable hash does not prove source-to-binary correspondence; that remains
explicitly unverified. For publishable benchmarks build the exact recorded
clean revision in Release, preserve the compiler settings, and record laptop
power, thermal and placement conditions. Defaults alone do not make an
experiment a completed project acceptance or a comparison of all engines.
Partial output and local paths stay under ignored results/. Curated evidence
is copied into evidence/ only after review. Hosted CI and CUDA execution are
separate evidence requirements.
