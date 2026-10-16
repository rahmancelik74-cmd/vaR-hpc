# First-term CUDA walking skeleton

This is an end-to-end connectivity milestone, limited explicitly to 1 through
10000 scenarios and at most 16 confidence levels. It is not full-scale
statistical acceptance, optimization or a performance benchmark. CPU engines
retain their existing numerical code. Application version remains 0.3.0;
the source revision and additive CUDA metadata identify this extension.

## Device path and quantile library decision

CudaEngine implements the existing Engine::run interface in the separate
mc_cuda library. The CLI loads CSV and calibrates the shared GBM model once.
Native mode uses a device cuRAND generator (CURAND_RNG_PSEUDO_PHILOX4_32_10,
curandGenerateNormalDouble). Each CUDA thread computes one double terminal
loss with the existing formula -V0*expm1((mu-0.5*sigma^2)*T+sigma*sqrt(T)*z).
The initial GPU quantile implementation is Toolkit CUB
DeviceRadixSort::SortKeys<double>, ascending across all 64 bits, followed by a
device gather at min(ceil(confidence*N)-1,N-1). Only scalar quantiles and an
error flag return to the host. No loss vector returns for host sorting.

**CUB is the intended quantile library for the later full implementation.**
This milestone validates double sorting/rank selection on the actual RTX 4060.
It does not validate CUB's full-scale memory use, batching or throughput.
Any later library change must be explicit. The device library is header-only;
its compiled CUB_VERSION is recorded, not inferred from the nvcc version.

Native CPU/GPU RNG streams differ even for equal seeds. Odd native N allocates
and generates N+1 normals to satisfy the normal-double even-count requirement;
only the first N are consumed. Common-input mode reads exactly N caller-owned
normals, copies them unchanged to the device and bypasses cuRAND generation.
Invalid/nonfinite inputs or device loss overflow set an atomic error flag;
the host rejects the run before sorting invalid losses. CUDA, cuRAND, launch,
synchronization and successful-path cleanup errors are checked. Failure paths
release resources through RAII without returning a partial Result.

## Build and optional CLI

MC_ENABLE_CUDA defaults OFF. CPU-only configurations do not enable the CUDA
language or discover its Toolkit and reject --backend cuda explicitly.
--threads remains an OpenMP-only option. Existing positional and final --json
commands continue to work. On the target Windows machine:

The existing threads_used=1 field describes the host orchestration thread for
CUDA, not the GPU worker count. The loss kernel uses blocks of 256 threads;
the scalar gather uses one block of 32. These are initial launch parameters,
not an occupancy or performance claim.

```powershell
cmake -S . -B build-cuda-skeleton -G "Visual Studio 17 2022" -A x64 -T cuda=13.4 -DMC_ENABLE_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89
cmake --build build-cuda-skeleton --config Release --parallel
ctest --test-dir build-cuda-skeleton -C Release --output-on-failure
.\build-cuda-skeleton\Release\mc_var.exe --csv data/synthetic_prices.csv 10000 42 10 --backend cuda --json
```

CMake FindCUDAToolkit supplies CUDA::cudart and CUDA::curand. CUB includes come
from the installed Toolkit (include/cccl on this installation). CCCL requires
the MSVC conforming preprocessor: the CUDA target alone passes
-Xcompiler=/Zc:preprocessor. --fmad=false makes the intended arithmetic steps
explicit without changing the CPU targets. The build selects sm_89/compute_89
for this GPU. On Windows the Toolkit cudart/curand DLLs are copied next to the
executables, and their versions/hashes are recorded. No binaries are committed.

## Timing and initial capacity estimate

The primary steady-clock engine timer begins after request validation/shared
CSV calibration, before CUDA discovery/context work. It includes context/API
initialization, allocations, generator setup/generation, simulation, CUB workspace
query/allocation/sort, device gather, transfers, synchronization, diagnostics and
cleanup. It stops after temporary buffers/resources are released. Process/DLL
loading before the engine call, input parsing/calibration and output are excluded.
Each CLI run is a fresh process; no context is reused across smoke invocations.

CUDA Events on the same stream measure H2D and D2H copy intervals separately.
H2D includes rank indices and, in common mode, normals; native mode does not
transfer a host normal sample. D2H includes the error flag and scalar estimates.
Event totals are not the full pipeline or host time. Host buffers are pageable;
any host staging overhead is included in primary wall time, not guaranteed to
be represented by the event interval. These one-run times are diagnostics only.

Explicit device storage is padded_normals*8 + 2*N*8 + K*8 (values) +
K*sizeof(size_t) (indices) + sizeof(int) (error flag) + queried CUB workspace
(at least one byte allocated). Both input/output sort arrays and temporary
storage are counted. cudaMemGetInfo records total/free memory before pipeline
allocation and free memory with the completed pipeline/resources still live.
Opaque cuRAND/context allocations and other GPU activity may affect the latter
snapshot; it is not an exact allocation ledger or a measured peak.

The initial capacity figure is floor(0.8*free_before*N/explicit_device_bytes),
a rough linear extrapolation at N=10000 with a 20% free-memory reserve. It is
not a tested maximum: workspace may scale nonlinearly, library allocations are
opaque and other processes use VRAM. The hard scenario cap remains 10000
regardless of this estimate. No large GPU allocation or full-scale run is made.

## Checks and evidence

The seven CUDA-enabled CTests retain all six CPU/OpenMP tests and add
cuda_common_input_tests. Common tests separately check signed losses, ties,
nearest ranks, sizes 1/5/257/9999/10000, zero horizon/volatility, all-zero losses,
shared CSV calibration, unchanged caller inputs, invalid values/requests and
recovery after device rejection. Quantiles use a fixed tolerance
1e-10*max(1,abs(serial_var)) for CPU/GPU math-library differences. This small
numerical check is not analytical five-seed GPU acceptance. Native smoke runs
are archived separately and never compare CPU/GPU samples from equal seeds.

scripts/run-cuda-skeleton.ps1 requires a clean source commit, rebuilds the CUDA
path and CUDA-disabled OpenMP ON/OFF configurations (7/6/5 CTests), records
common-input JSON, native CSV smoke N=10000 plus an odd-count N=5 plumbing
check, library/compiler/runtime/driver versions, exact-byte hashes and transfer/
memory diagnostics. It checks fresh CPU ON/OFF-build estimates agree exactly.
The Windows driver package version, driver API version, nvcc, runtime header,
API-returned runtime and DLL file versions remain distinct observations.
Hosted CPU CI leaves CUDA disabled; local RTX execution is the GPU evidence.

## Primary references

- [CUB device radix sorting](https://github.com/NVIDIA/cccl/blob/main/cub/cub/device/device_radix_sort.cuh)
- [cuRAND host API and normal-double requirements](https://docs.nvidia.com/cuda/archive/13.4.2/curand/curand/group__HOST.html)
