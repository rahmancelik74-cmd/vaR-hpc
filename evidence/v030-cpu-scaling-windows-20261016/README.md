# Windows serial/OpenMP scaling baseline, 2026-10-16

Clean source revision: aa901a38b0d903d73a817aaf16c2a3743413b6af.
Application 0.3.0. Numerical engines, RNG design and serial sorting are unchanged
from the preceding correctness milestone. This archive is a separate evidence
commit, not a source change. Historical measurements are preserved.

## Procedure and review

The smoke campaign was completed and independently audited before the full
campaign. Both were built from the same clean source revision. Each campaign
performed its own clean-first MSVC x64 Release build; within the full campaign,
every serial and OpenMP run used the SAME executable and exact input bytes.
The full campaign's fresh serial runs are the reference, never v0.2.2 timings.
Manifest files contain the individual input/executable/probe hashes, compiler
flags, runtime version, source revision, timestamps and conditions.

Reproduction commands and interpretation: [CPU recorder documentation](../../docs/cpu-benchmark.md).
Use an English physical-conditions JSON file for a full campaign.

- smoke/: 18 processes, six configurations, one warm-up and two measured runs
  each at N=10000. Eight CTests and independent audit passed.
- benchmark/: 234 processes, 18 configurations; N=100000,1000000,10000000;
  seed 42; serial and OpenMP requested threads 1,2,4,8,10; three warm-ups and
  ten measured runs per configuration. Eight CTests and independent audit passed.
- benchmark/summary.json and summary.csv: all means, sample standard deviations,
  scenarios/second, speedups against fresh serial and scaling against one-thread
  OpenMP. Each measured process is counted once; neither confidence duplicates
  its timer. No slow result was removed; all ten measured runs remain per row.
- runs.jsonl: execution sequence, phase, repetition, UTC start/finish and result.
  process-observations.jsonl: matching raw launcher records in the same order,
  with unmodified application stdout plus pre/post power/frequency snapshots.
- inventory.json: physical/logical topology, affinity masks, runtime and power.
  affinity-checks.json: binding requests and a restricted-process control.
- independent-audit.json: explicit-sum/two-pass statistics cross-checks against
  the recorder's Welford calculation, raw timings, actual teams, CSV/JSON,
  repetition coverage, unique sequence, available power fields and local hashes.
- configure/build/ctest logs: source/user directory prefixes redacted. Build
  logs explicitly label the English transcription of the localized MSBuild
  banner and include the locally retained redacted native capture's SHA-256.
  Native captures remain under ignored results/cpu-*-aa901a3 locally.
- artifact-sha256.json: exact-byte SHA-256 for all archived artifacts except
  itself. This folder disables Git newline conversion to preserve those bytes.
- hosted-ci.json and hosted-*.log: successful source-commit Ubuntu ON/OFF jobs
  and Windows instrumentation/recorder smoke. Linux CTest and Windows progress
  excerpts are retained. Windows CTest output is runner-local, captured by the
  recorder; the job fails on any test error. The source defines eight Windows
  CTests, six Ubuntu ON tests and five OFF tests.

## Placement and physical conditions

Windows reports one processor group, 10 physical cores and 16 logical CPUs:
six SMT cores at efficiency class 1 (masks 3,c,30,c0,300,c00), plus four
single-logical cores at class 0 (1000,2000,4000,8000). Every benchmark process
uses the same allowed mask ffff with normal priority, verified while suspended
before its first instruction. The OS schedules threads inside that pool; an
OpenMP team of ten does not establish one worker per physical core.

The installed probe runtime is vcomp140.dll 14.50.35719.0, compiler OpenMP
date 200203. OMP_PROC_BIND=TRUE / OMP_PLACES=cores did not keep workers on
individual cores: all 25 workers across the five requested-team probes were
observed on more than one physical core, and all allowed masks remained ffff.
The restricted-process control constrained four workers to mask 1 in both
allowed and observed CPU masks. The benchmark uses verified process-pool
affinity, leaves runtime binding variables unset and fixes OMP_DYNAMIC=FALSE
and OMP_NESTED=FALSE. Probe observations are separate from timed runs; engine
per-thread migration histories were not traced.

The user reported charger connection, heavy applications closed and comfortable
room temperature, without a numeric temperature. Surface/cooling and vendor fan
mode were not specified. Across all 468 pre/post benchmark observations, Windows
reported AC connected, battery 100%, battery saver off and the same active power
scheme GUID 5da85d85-eb0c-4710-a805-6da8bbcf1f02. The recorder did not change the
power plan. OS frequency/throttle reports are archived, not treated as measured
turbo clocks. CPU package temperature, fan speed, package power and thermal
throttling events were not measured; thermal equilibrium is not established.
Unobserved in-place power-plan/vendor setting changes cannot be excluded.

Each sample uses a fresh process and runtime context. Warm-ups precondition
the OS/machine rather than an engine retained between runs. They are excluded
from statistics. The existing engine timer includes allocation, RNG, simulation,
serial sorting, quantiles, cleanup and synchronization. Process startup, shared
CSV calibration, telemetry, output and the fixed 100 ms inter-run delay are
outside that timer. Deterministic rotating/reversing order spreads temporal
bias across configurations; it does not eliminate scheduler/thermal variation.

## Results and limits

All actual OpenMP team sizes matched their requests; serial used one thread.
The table below covers N=10000000. Full results for all 18 configurations,
including slower small-workload cases, are in benchmark/summary.csv.

| Backend / threads | Mean ms | Sample stddev ms | Scenarios/s | Speedup vs fresh serial | Scaling vs OpenMP 1 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Serial | 1088.13644 | 9.85657 | 9190024 | 1.00000 | N/A |
| OpenMP 1 | 1080.41351 | 8.37749 | 9255715 | 1.00715 | 1.00000 |
| OpenMP 2 | 970.26161 | 9.01923 | 10306499 | 1.12149 | 1.11353 |
| OpenMP 4 | 919.27712 | 11.50793 | 10878113 | 1.18369 | 1.17529 |
| OpenMP 8 | 919.96022 | 12.96122 | 10870035 | 1.18281 | 1.17441 |
| OpenMP 10 | 915.65387 | 10.74795 | 10921157 | 1.18837 | 1.17994 |

The lowest observed mean at N=100000 was OpenMP 1 (9.23815 ms, 1.13861x
fresh-serial speedup); at N=1000000 it was OpenMP 2 (86.22850 ms, 1.15583x).
At N=10000000, OpenMP 10 had the lowest observed mean, but 4/8/10-thread
differences are small relative to sample variability and do not establish a
universally best team size. Higher thread counts were slower than serial for
some smaller workloads, including OpenMP 10 at N=100000 (17.86813 ms versus
10.51866 ms serial). These results are retained without filtering.

Sorting remains serial and native RNG streams differ between engines. This
measures the complete native CPU pipeline under the recorded OS placement
policy; it does not isolate simulation scaling, prove a bottleneck, establish
thermal stability or constitute the later CPU/GPU comparison. No stage profiling,
engine optimization, CUDA work or supervisor submission was started.
