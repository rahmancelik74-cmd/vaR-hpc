# CPU stage diagnostics

The optional `--cpu-diagnostics --json` flag records host stages in serial and
OpenMP runs. It rejects CUDA selection, duplicate flags and text-only output.
Without the flag, the JSON schema omits `cpu_diagnostics`. RNG streams, loss
calculation, serial std::sort, nearest-rank rule and the existing primary timing
boundary are preserved. Diagnostics are not an optimization or a new primary
CPU/GPU benchmark.

| Field | Measured scope |
| --- | --- |
| setup_ms | Result metadata, zero-initialized loss allocation; serial generator setup |
| generation_ms | Native RNG and loss calculation; OpenMP team creation/join and exception check |
| sorting_ms | Serial std::sort over all scalar losses |
| quantile_ms | Nearest-rank lookup and appending both estimates |
| cleanup_ms | Destruction of temporary buffers and generators |

These are contiguous steady-clock intervals within end_to_end_ms; their sum
must match that total within floating-point reporting tolerance. Extra clock
overhead is included. CSV calibration, output and process startup remain outside
the primary boundary. Generation and quantile are different scopes: the
nearest-rank lookup is cheap after sorting, but sorting itself can dominate.

## Reproduction

Build on Windows with Visual Studio 2022, then use a clean tracked source revision:

```powershell
cmake -S . -B build-cpu-stage -G "Visual Studio 17 2022" -A x64 -DMC_ENABLE_CUDA=OFF -DMC_ENABLE_OPENMP=ON -DMC_BUILD_CPU_TOOLS=ON -DBUILD_TESTING=ON
cmake --build build-cpu-stage --config Release --parallel 4
ctest --test-dir build-cpu-stage -C Release --output-on-failure
python -B scripts/run_cpu_stages.py --exe build-cpu-stage/Release/mc_var.exe --probe build-cpu-stage/Release/mc_cpu_probe.exe --output results/cpu-stages-unique
```

The recorder uses the public synthetic fixture, seed 42, 10/252 horizon,
N=100000/1000000/10000000, serial and OpenMP 1/2/4/8/10, three excluded warm-ups
and ten retained samples per configuration. It records 234 processes, exact raw
launcher/result records, per-sample power observations, actual teams, verified
affinity pool and normal priority, source/build/input hashes and all sample SDs.
It never changes the power plan or discards slow samples. AC or power-policy
changes stop the attempt; failed evidence is retained. Interactive applications,
CPU temperatures, cooling and thermal equilibrium are not controlled or inferred.

For Amdahl interpretation use OpenMP 1 as the same-algorithm reference. A
serial/OpenMP ratio also includes different native RNG streams. An effective
serial fraction inferred from speedup is not a measured sorting fraction.
Hybrid GPU host sorting and full-device CUDA diagnostics have separate scopes.
Do not combine these new CPU diagnostic samples with old GPU campaign times
to claim a fresh speedup or retrospectively revise the October CPU table.

## Recorded follow-up: 2026-11-01

Source e06c53acdaaccfb6cc2b5a0d17b03f3192d755ce, Windows x64, Intel
Core i7-12650H, MSVC 19.44 Release /O2, ten physical/16 logical processors.
This separate diagnostic retained 234 processes across 18 configurations:
54 excluded warm-ups and 180 measurements. Every configured run completed;
no slow sample was removed. Full stage means/SDs and raw records are retained
privately; this public page contains aggregate results only.

The table covers N=10000000; each row has ten measured processes. Setup and
cleanup are included in total time but omitted from this compact table.

| Backend / workers | Generation mean ms | Sorting mean ms | Rank lookup mean ms | Total mean ms | Total sample SD ms | Sort share |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Serial | 231.37693 | 843.92291 | 0.00406 | 1094.29371 | 8.86439 | 77.120% |
| OpenMP 1 | 228.31902 | 840.45743 | 0.00382 | 1088.11640 | 12.22755 | 77.240% |
| OpenMP 2 | 117.50103 | 840.46045 | 0.00428 | 976.96958 | 14.47359 | 86.027% |
| OpenMP 4 | 73.07110 | 848.80410 | 0.00406 | 942.74788 | 24.33601 | 90.035% |
| OpenMP 8 | 53.68361 | 852.84625 | 0.00403 | 926.57915 | 18.78312 | 92.042% |
| OpenMP 10 | 47.99057 | 862.65182 | 0.00654 | 929.58113 | 19.66414 | 92.800% |

Generation scaled 4.75758x from one to ten OpenMP workers, while total time
scaled 1.17054x. Serial sorting dominated: 92.800% of the ten-worker total.
The nearest-rank lookup/appends after sorting took only 0.00654 ms. This is a
measured stage attribution, unlike an Amdahl fraction inferred from speedup.
The 4/8/10 total means are close relative to sample variability; eight workers
had the lowest mean here, not a universally established optimum.

Each suspended child had its full process affinity pool verified and normal
priority. There was no per-worker physical-core pinning. AC, battery-saver and
power-scheme observations stayed consistent. No system settings were changed.
Other interactive applications were not controlled; browser/VM activity may
have remained. Temperatures, cooling, actual turbo clocks and thermal equilibrium
were not measured or established. Diagnostic clock overhead remains included.

An independent local audit recomputed all stage sums, means/sample SDs, CSV
values, phase/repetition coverage, native OpenMP thread invariance and exact-byte
hashes. Local CPU/probe CTests passed 23/23. The source commit's
[exact-SHA CI](https://github.com/rahmancelik74-cmd/vaR-hpc/actions/runs/41348052308)
passed 4/4; hosted CI validates contracts/builds, not these laptop timings.

These diagnostic samples do not replace historical primary timings. No sorting
optimization or new GPU benchmark ran. Do not combine this CPU table with old
GPU times to claim a new speedup. No raw local logs or academic documents are
included in this aggregate update.
