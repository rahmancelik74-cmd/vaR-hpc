# Target machine inventory

Read-only registry inventory on 2026-10-20 additionally identifies Casper
Excalibur G870, SKU EXCALIBUR G870 NLXB, board NLXB 001 and BIOS CQ111.
[Bandwidth investigation evidence](../evidence/v030-bandwidth-access-20261020/README.md)
records the identity source, current driver/tool observations and unresolved
OEM memory data rate. This does not identify a full commercial configuration
suffix or establish documented peak bandwidth. Earlier inventory below remains
dated evidence.

These values describe the student's project computer. Hardware on the
assistant's execution server is not used as the benchmark hardware.

| Field | Value |
| --- | --- |
| Operating system and version | Windows 11 reported by student; archived process OS version 10.0.26200.0 in CPU correctness/scaling records |
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
| CMake generator | Visual Studio 17 2022; scaling/skeleton builds explicitly x64; initial foundation cache had an empty platform field |
| OpenMP runtime / affinity settings | MSVC -openmp, _OPENMP=200203; scaling probe vcomp140.dll 14.50.35719.0; process pool mask ffff, no per-core pinning; campaign-specific variables below |
| GPU quantile library / version | CUB 3.4.3 (CUB_VERSION=300403), RTX-verified walking skeleton; intended later library |
| CUDA runtime / driver API | Both returned 13030 in the archived skeleton; compiled runtime header 13040; discrepancy unexplained |
| Deployed CUDA runtime DLL | cudart64_13.dll file version 6,14,11,13040; hash in skeleton manifest |
| cuRAND | Header 10.4.4.72; runtime query 10404; curand64_10.dll file version 6,14,11,1044 |

Table reconciled against archived evidence on 2026-10-18; it is not a new machine
measurement. RAM remains a student-reported nominal 16 GB, not a newly verified
byte count. Later campaign-specific evidence below supersedes the initial pending
inventory statements without rewriting their historical context. The runtime/API
version discrepancy, unmeasured temperature and absent per-core pinning do not
establish failure of the archived results. Preserve these limits in later comparisons.

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

## CPU scaling environment: 2026-10-16

The fresh baseline at clean source aa901a3 uses build-cpu-scaling with the
same Visual Studio 2022 x64 Release compiler/optimization settings as the
correctness milestone. MC_BUILD_CPU_TOOLS=ON adds only a separate Windows
instrumentation executable and recorder tests. Eight CTests passed.

GetLogicalProcessorInformationEx reports 10 physical core records / 16 logical
processors in one group. Six SMT core masks (3,c,30,c0,300,c00) have reported
efficiency class 1; four non-SMT masks (1000,2000,4000,8000) have class 0.
The observed probe runtime is vcomp140.dll 14.50.35719.0, _OPENMP=200203.
Requested OMP_PROC_BIND=TRUE / OMP_PLACES=cores did not constrain the worker
group masks or keep them within single physical cores. The separate one-CPU
process-affinity control succeeded. Benchmark process affinity was ffff for
every fresh serial/OpenMP process, checked before resume, with normal priority.
Actual teams matched requested 1,2,4,8,10; serial used one. Windows scheduled
workers within the pool; this is not per-core pinning. OMP_DYNAMIC and OMP_NESTED
were FALSE; the recorder's other listed affinity/runtime controls were unset.

All 468 pre/post snapshots reported AC connected, battery 100%, battery saver
off and power scheme 5da85d85-eb0c-4710-a805-6da8bbcf1f02. The plan was not
changed. The user reported charger connection, heavy applications closed and
comfortable room temperature without a numerical reading. Surface/cooling and
vendor fan mode were not specified. No package-temperature, fan-speed, package-
power or throttling-event sensor was configured; these were not measured.
ProcessorInformation values are OS frequency/throttle reports, not actual turbo
clock measurements. Thermal equilibrium and unobserved vendor settings are
unverified. These are explicit baseline limits, not silently assumed conditions.
Evidence: evidence/v030-cpu-scaling-windows-20261016; protocol: cpu-benchmark.md.

## Verified CUDA walking skeleton: 2026-10-16

Clean source 8951236, Windows x64 Release, Visual Studio 2022, explicit CUDA
toolset 13.4 and architecture 89. nvcc reports 13.4.92; host MSVC reports
19.44.35227.0. CCCL requires /Zc:preprocessor for the CUDA target; --fmad=false
is explicit. CPU numerical source and compiler options remain unchanged.
CUDA defaults OFF; seven CUDA-on tests, six CUDA-off/OpenMP-on tests and five
serial-only tests passed locally. Hosted CPU CI continues with CUDA disabled.

Actual device: RTX 4060 Laptop GPU, compute capability 8.9, total VRAM
8585216000 bytes. Windows NVIDIA driver package: 32.0.16.1088. Driver API
returns 13030. Runtime API returns 13030, while compiled CUDART_VERSION=13040
and the deployed cudart64_13.dll file version is 6,14,11,13040. These distinct
version observations are preserved without equating them to nvcc or claiming
an explanation for the API/header discrepancy. DLL hashes are archived.
cuRAND header version: 10.4.4.72; runtime query: 10404; curand64_10.dll file
version: 6,14,11,1044. CUB_VERSION=300403 (3.4.3), from Toolkit headers.

N=10000 native explicit allocation: 331939 bytes, including queried CUB scratch
91903 bytes. Pre-allocation free memory: 7451181056 bytes; live pipeline free
memory: 7442792448 bytes. Opaque library allocations and granularity prevent
equating that delta with the explicit buffer budget. The 80%-free linear
estimate was 179579526 scenarios, not tested capacity; that source was capped at
10000. The current full-device limit and actual-request preflight are documented
in cuda-skeleton.md; this archived inventory is not a new scale measurement.
CUDA Events measured H2D 0.0235520005 ms / 16 bytes and D2H 0.0706879981 ms /
20 bytes in the archived native smoke. These are copy diagnostics, not a GPU
performance benchmark. Primary wall time includes the complete engine boundary.
Evidence: evidence/v030-cuda-skeleton-windows-20261016; protocol: cuda-skeleton.md.
