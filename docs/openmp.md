# OpenMP backend v0.3.0

OpenMPEngine implements the existing Engine::run contract in the separate
mc_openmp library. MC_ENABLE_OPENMP defaults to ON and requires CMake
FindOpenMP / OpenMP::OpenMP_CXX. Set it OFF for a serial-only build; selecting
OpenMP then fails explicitly. The serial calculation, RNG, nearest-rank
quantile and timing boundary are unchanged.

Only scenario loss generation is parallel. Sorting remains serial, using
double losses and the same nearest-rank quantile helper. Allocation, block RNG
initialization/generation, simulation, sorting, synchronization and temporary
buffer destruction are inside engine time. CSV/calibration and output are not.

## Random streams and common inputs

Scenario indices are divided into fixed blocks of 4096, including a partial
last block. Each block owns mt19937_64 and normal_distribution<double>(0,1).
For zero-based block b, add 0x9e3779b97f4a7c15 * (b+1) to the run seed modulo
2^64, then apply the SplitMix64 xor/shift/multiply finalizer (shifts 30, 27, 31;
multipliers 0xbf58476d1ce4e5b9 and 0x94d049bb133111eb). This is seed mixing,
not a proof of independence between streams. No mutable RNG is shared.
Scheduling and requested thread count do not change native estimates within
the same build. Serial and OpenMP native samples differ. Standard-library
normal distributions do not guarantee identical output across toolchains.

Common-input mode reads exactly N caller-owned normals by scenario index and
does not modify them. Common-input tests compare serial and OpenMP estimates
exactly, including partial blocks and deterministic cases. They are separate
from native-RNG analytical statistical validation. Worker exceptions are caught
inside the parallel region, the first captured exception is rethrown after
the team completes, and no partial result is returned. If several blocks fail,
which exception is first is unspecified. The backend uses MSVC-compatible
OpenMP parallel/single/for/critical constructs with a signed canonical loop.

## CLI and metadata

Serial is the default. Existing positional commands and final --json remain:

```powershell
cmake -S . -B build-openmp -G "Visual Studio 17 2022" -A x64 -DMC_ENABLE_OPENMP=ON
cmake --build build-openmp --config Release --parallel
ctest --test-dir build-openmp -C Release --output-on-failure
.\build-openmp\Release\mc_var.exe --csv data/synthetic_prices.csv 10000 42 10 --backend openmp --threads 4 --json
```

--backend accepts serial or openmp once. --threads accepts a positive int once
and requires openmp. Omitted threads use omp_get_max_threads(); the runtime may
use fewer threads than requested. Duplicate, missing and unknown options fail.
--version is a separate command. Version 0.3.0 retains JSON schema 1 and adds
requested_threads (0 for runtime default or serial), threads_used (actual team
size, 1 for serial), and openmp_version (_OPENMP date macro, 0 for serial).
Seeds remain exact decimal strings; JSON numbers use the classic locale.
The _OPENMP value describes compiler support, not a runtime DLL version.

## Correctness evidence

The four prior CTests remain. OpenMP ON also runs openmp_tests and
cli_contract_tests; OFF runs the four prior tests and cli_contract_tests.
CI covers ON and OFF. Tests include block boundaries, read-only common inputs,
thread requests 1,2,4,8,10, repeatability, invalid requests, NaN/overflow worker
propagation and recovery. Exact common-input checks are not statistical tests.

scripts/run-openmp-validation.ps1 rebuilds a clean source commit in Windows
x64 Release, checks both configurations, parses a CSV JSON smoke result and
records native thread invariance separately. It runs 20 native-RNG CSV cases:
N=10000,100000,1000000,10000000; seeds=42,123,456,789,2026; requested threads=4.
At N=10000000, for each of 0.95 and 0.99 it evaluates
abs(mean(five estimates) - analytical) <=
0.01 * max(abs(analytical), 0.01 * initial_value).
This is error of the mean, not mean absolute error or a per-seed criterion.
Runs are correctness evidence for a synthetic fixture, not a performance
benchmark or a claim of real-market validity. Thread scaling with placement,
power and thermal metadata was subsequently recorded, with explicit sensor
limitations, in evidence/v030-cpu-scaling-windows-20261016. See cpu-benchmark.md.
The existing run-experiment.ps1 retains serial recording for versions 0.2.2
and 0.3.0 and now supports OpenMP in smoke mode with v0.3.0. It does not
replace this correctness campaign or the CPU benchmark recorder. See
[synthetic-demo.md](synthetic-demo.md).
