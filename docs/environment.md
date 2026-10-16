# Target machine inventory

These values describe the student's project computer. Hardware on the
assistant's execution server is not used as the benchmark hardware.

| Field | Value |
| --- | --- |
| Operating system and version | Windows 11; build number pending |
| Full CPU model | 12th Gen Intel Core i7-12650H |
| Physical cores / logical threads | 10 / 16, from the student's CIM output |
| RAM | 16 GB, reported by the student |
| Full NVIDIA GPU model | NVIDIA GeForce RTX 4060 Laptop GPU |
| VRAM | 8187 MiB reported by the CUDA runtime probe; nominal 8 GB |
| NVIDIA driver | Windows DriverVersion 32.0.16.1088, Status OK |
| CUDA Toolkit / nvcc version | release 13.4, V13.4.92, from the student's nvcc output |
| C++ compiler and version | MSVC 19.44.35227; VS 17.14.32 |
| CMake version | 3.31.6-msvc6 |
| Common C++ compiler flags | `/DWIN32 /D_WINDOWS /GR /EHsc`, from build-foundation/CMakeCache.txt |
| Release compiler flags | `/O2 /Ob2 /DNDEBUG`, from build-foundation/CMakeCache.txt |
| CMake generator | Visual Studio 17 2022; cached generator platform is empty |
| OpenMP runtime / affinity settings | MSVC -openmp, OpenMP 2.0 (_OPENMP=200203); runtime DLL version not inventoried; affinity variables unset in correctness campaign |
| GPU quantile library / version | To be recorded |

Initial inventory commands in Windows PowerShell:

```powershell
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors
Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory
nvidia-smi
nvcc --version
cmake --version
```

If a command is unavailable, record the error rather than assuming installation.
The CUDA field in `nvidia-smi` is not the installed Toolkit version; record
`nvcc --version` separately for the Toolkit. Do not publish machine names,
serial numbers or personal file paths in the public repository.

Initial checks: do the CPU build/CTest work? Are the NVIDIA device and nvcc
accessible? Actual CUDA/cuRAND and quantile-library smoke tests provide the
next evidence.

2026-10-14: the student confirmed a successful v0.1 x64 CMake build/CTest and
serial demo. The raw test log was not included in that package. Windows v0.2
testing was pending at that date. `nvcc --version` proves compiler installation,
not GPU kernel execution. The thread sweep for the 10-core CPU will use
1,2,4,8,10 threads; placement across different core types and power conditions
will be recorded separately during benchmarking.

## Verified foundation update: 2026-10-15

The later verification supersedes the older pending v0.2 test status above.
Windows x64 Release configure/build succeeded in build-foundation using
Visual Studio 17 2022 and MSVC 19.44.35227.0. All three CTest tests passed
(core_tests, csv_calibration_tests, csv_cli_smoke; 0.23 seconds total).
The log is committed as evidence/windows-release-ctest-20261015.log in 48429b5.
CMake selected Windows SDK 10.0.26100.0 and target version 10.0.26200; these
version strings alone are not a separate verification of the OS edition.
At that verification date, compiler optimization flags, hosted CI and GPU
runtime execution remained open. This CPU verification is not a formal
performance benchmark.

## Verified CUDA, CI and compiler settings: 2026-10-16

The standalone CUDA probe compiled with NVIDIA nvcc 13.4.92 and host compiler
MSVC 19.44.35227.0. It ran on the RTX 4060 Laptop GPU, reported compute
capability 8.9 and 8187 MiB VRAM, and verified all 1024 GPU results. Allocation,
host-to-device copy, kernel execution, synchronization, device-to-host copy
and cleanup succeeded. Evidence: evidence/cuda-probe-20261016, commit 1acfee3.

The probe reported driver API version 13030 and runtime version 13030. These
are the values returned by the executed probe; they are not substituted for
the separately observed nvcc 13.4.92 compiler version. Runtime-library selection
has not yet been investigated. The nvidia-smi command was unavailable in PATH
and in the two checked standard locations; Windows CIM identified the NVIDIA
device and reported driver version 32.0.16.1088.

The local serial Release build uses the common and Release flags recorded in
the table above. The student supplied these CMakeCache.txt values and reported
a clean working tree after 31fe206. The empty generator-platform cache value
is recorded as observed, not filled with an assumed value. The successful
CUDA-probe build explicitly selected x64; its build settings are separate
from the serial benchmark configuration.

Repository: https://github.com/rahmancelik74-cmd/vaR-hpc.
The student reported successful hosted CPU build/test execution after 31fe206,
with all four CTest tests passing. The workflow runs on ubuntu-latest and uses
actions/checkout@v6. This is CPU CI evidence, not hosted GPU execution.

GPU quantile-library compatibility, full engine CUDA execution and laptop
power/thermal conditions remain to be recorded.

## Verified OpenMP Windows correctness: 2026-10-16

Clean source 05f982e was rebuilt in build-openmp using the Visual Studio 17
2022 generator with explicit platform x64 and Release configuration.
MSVC 19.44.35227.0; CMake 3.31.6-msvc6; Windows version 10.0.26200.0.
Common flags: /DWIN32 /D_WINDOWS /GR /EHsc; Release: /O2 /Ob2 /DNDEBUG;
mc_core and mc_openmp use /W4; FindOpenMP supplied -openmp. All six ON tests
and five OFF tests passed. The OFF build is in build-openmp-off.

The 20 native statistical runs requested and used four threads. Separate
native invariance checks requested and used 1,2,4,8,10 threads. OMP_NUM_THREADS,
OMP_DYNAMIC, OMP_THREAD_LIMIT, OMP_PROC_BIND and OMP_PLACES were unset.
This records observed team sizes without asserting a core placement policy.
The compiler's _OPENMP macro was 200203; this is not a runtime DLL version.
CPU model was read from the local hardware registry; the process reported
16 logical processors. Detailed topology remains the previously recorded
inventory. No power/thermal measurements or formal scaling benchmark are claimed.
Manifest, exact-byte hashes, compiler flags and test logs are archived in
evidence/v030-openmp-windows-correctness-20261016.
