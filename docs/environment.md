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
| VRAM | 8 GB, reported by the student |
| NVIDIA driver | Windows DriverVersion 32.0.16.1088, Status OK |
| CUDA Toolkit / nvcc version | release 13.4, V13.4.92, from the student's nvcc output |
| C++ compiler and version | MSVC 19.44.35227; VS 17.14.32 |
| CMake version | 3.31.6-msvc6 |
| Release compiler flags | To be recorded |
| OpenMP runtime / affinity settings | To be recorded |
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
