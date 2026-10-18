# GPU acceptance and memory/concurrency verification

Run `scripts/run-gpu-acceptance.ps1 -OutputDirectory results/gpu-acceptance-unique`
from a clean committed source. Only untracked AGENTS.md and output/ are excluded.
The directory must be new; failed attempts are retained, never overwritten or
selectively replaced. The recorder does not commit or push. Windows x64 Release,
VS 2022, CUDA toolset 13.4, architecture 89 and CUB 3.4.3 follow existing practice.
No engine, RNG, quantile, CPU behavior or timing boundary changes are introduced.

## Numerical acceptance

The exact bytes of data/synthetic_prices.csv are copied and hashed. One unit,
10/252 years, N=10000000, seeds 42/123/456/789/2026 and confidence .95/.99 form
one non-degenerate synthetic GBM fixture. Each native mode has its own five-seed
group. Hybrid requested batch is 65535, effective native batch 65536, 153 batches.
Call partition is part of the RNG configuration; no equality across native modes,
backends, batch sizes or library versions is assumed.

Four rows apply exactly:

`abs(mean(VaR)-analytical) <= .01*max(abs(analytical),.01*V0)`.

Per-seed estimates remain available. Error of the mean is not mean absolute error
or an individual-seed rule. Signed losses, negative VaR, double precision, exact
terminal GBM and ascending nearest-rank ceil(alpha*N)-1 remain unchanged.
Fresh CLI processes create fresh CUDA contexts; recorded engine times are not
benchmark samples. No warm-up, convergence or performance campaign is performed.

The independent auditor recalibrates log returns with a separate two-pass sample
variance (n-1), sigma=sqrt(s2*252), mu=mean*252+sigma^2/2. It uses independently
stored binary64 normal quantiles -1.6448536269514729 and -2.3263478740408408 for
the fixed lower probabilities .05/.01 and computes V0*(1-exp(exponent)), instead
of calling the engine's erfc bisection/expm1 implementation. Arithmetic comparison
tolerance 2e-12*max(1,abs(expected)) accommodates binary64 rounding; this does not
change either project acceptance threshold. Raw process output, JSONL, CSV and
acceptance summaries are cross-checked. Incomplete, duplicate, mixed, nonfinite,
changed-source/input/build/model/batch and incorrectly calculated records fail.

The pinned f039034 common-input evidence in
results/cuda-hybrid-f039034-clean-20261019 is reused after exact-byte manifest,
independent-audit and every recorded output hash is checked. Git comparisons of
src/, include/, the fixture and both CUDA test sources establish compatibility.
That evidence already covers N=100000/1000000/10000000 and partial batches.
Common-input absolute VaR difference <=.00001*V0 remains separate from native
statistical acceptance and memory/concurrency verification.

## Builds and provenance

New separate build directories contain CUDA/OpenMP, CUDA OFF/OpenMP ON,
serial-only and sanitizer configurations, with testing ON and CPU tools OFF.
All use clean-first Release builds and actual CTest JSON discovery. CPU-only
configurations must not discover the Toolkit. The sanitizer build adds -lineinfo,
preserving --fmad=false and /Zc:preprocessor. Hashes bind source SHA/tree/status,
scripts, caches, executables, deployed DLLs, CUDA project options, fixture and
output bytes. Runtime DLL file/product versions and tool versions are recorded.
CSV numbers use invariant-culture round-trip formatting, including under tr-TR.

Raw stdout/stderr are copied from redirected process byte streams. Arguments are
passed through ProcessStartInfo, never evaluated by a command shell. JSON files
are explicitly decoded as UTF-8 on Windows PowerShell. Tool summaries use exact
ASCII matching, independent of the Windows locale. A child wrapper preserves the
actual target exit code separately from Compute Sanitizer's exit code. A timeout
terminates only that invocation's process tree and remains failed evidence.

## Sanitizer matrix

First verify installed options and successful child-process attachment using a
native N=1 memcheck pilot. Do not start the matrix if this fails. Then:

| Tool | Existing test executables | Native cases per mode |
| --- | --- | --- |
| memcheck | mc_cuda_tests, mc_cuda_hybrid_tests | 65535,65536,65537,131073,1000000 |
| initcheck, global and shared | Both | 65535,65536,65537,131073,1000000 |
| synccheck | Both | 65535,65536,65537,131073 |
| racecheck | Both | 65535,65536,65537,131073 |

There are 44 matrix invocations plus the separate attachment pilot. All memcheck
cases precede other tools. Hybrid always requests batch 65535. Partial final
batches and odd native padding are exercised. Existing small suites retain
common-input edge, failure/recovery, all-rank and native-reference checks.
No large common-input rerun is requested. Reduced instrumented sizes limit
instrumentation/TDR costs; no sanitizer-at-10-million claim is made.

Common options are --error-exitcode 99 --target-processes all
--require-cuda-init yes --print-limit 0 --log-file UNIQUE. Memcheck also uses
--leak-check full --padding 32; initcheck uses --initcheck-address-space all;
racecheck uses --racecheck-report all --racecheck-detect-level info
--print-level info. No kernel filters, suppressions, forced blocking launches,
registry/TDR changes or machine-wide settings are used. Every invocation records
its exact argv, unique raw logs, target and tool statuses, and coverage.

Missing/failed attachment, timeout, instrumentation failure, skipped kernels,
nonzero statuses and unexplained diagnostics are failed/incomplete evidence.
Only exact clean tool summaries are accepted, including racecheck's distinct
zero-hazard summary. Zero exit alone is insufficient. Temperatures and thermal
equilibrium are not measured or inferred. Sanitizer execution is separate from
all uninstrumented acceptance runs.

## Coverage limits and source reasoning

Memcheck detects invalid/misaligned device accesses, CUDA allocation leaks and
API errors. Initcheck checks uninitialized global/shared device reads. Synccheck
checks supported thread synchronization primitives. Racecheck checks shared-memory
hazards; a clean result does not establish general global-memory race freedom.
CPU host-buffer accesses/leaks outside CUDA APIs are not checked by this suite.
Instrumented executions are representative observations, not an exhaustive proof.

Separate source review checks one writer per loss/result index, atomic error
updates, validated ranks and launch bounds, per-request resources, and one stream
ordering RNG, simulation and transfers. Synchronized copies precede device-buffer
reuse and host sorting. Copy exceptions drain pending DMA while host storage is
alive. RAII handles failures and successful-path cleanup errors propagate. Hybrid
offsets cover all N losses before one global host quantile; no batch VaR averaging.
These arguments remain separate from dynamic tool findings.

## Evidence and auditing

The new ignored directory contains manifest.json, fixture.csv, runs.jsonl,
estimates.csv, acceptance.json, sanitizer-results.json, sanitizer-coverage.json,
reused-common-input.json, build/discovery/test logs, raw per-attempt process and
tool outputs, and independent-audit.json. Run the independent audit again with
`scripts/verify-gpu-acceptance.ps1 -Directory results/gpu-acceptance-unique`.
An audit output is not included in its own hash manifest; it records the exact
manifest hash. Source fixes require separate commits and new evidence directories.
No incompatible source revisions may be combined.

References: [NVIDIA Compute Sanitizer manual](https://docs.nvidia.com/compute-sanitizer/ComputeSanitizer/index.html)
and [release notes and limitations](https://docs.nvidia.com/compute-sanitizer/ReleaseNotes/index.html).
The installed tool's --help/version and actual attachment remain authoritative
for invocation support on this Windows machine.
