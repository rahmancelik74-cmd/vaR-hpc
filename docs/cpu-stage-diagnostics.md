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
