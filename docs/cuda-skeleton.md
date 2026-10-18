# CUDA full-device scale-up

The first-term walking skeleton has been extended to support 1 through
10000000 scenarios and 1 through 16 confidence levels, subject to device-memory
preflight and checked allocations. Application version remains 0.3.0; source
revision and CUDA milestone metadata identify this change. The Engine interface,
CPU numerical engines, native PHILOX stream and double precision are preserved.
Batching and hybrid fallback are the next separate step. This does not complete
Plan A's memory/batching milestone, statistical acceptance or benchmarking.

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

**CUB remains the quantile library for the full-device implementation.**
Every run sorts all N losses once globally; no batch VaRs are computed.
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

## Timing and allocation preflight

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

Explicit device storage is padded_normals*sizeof(double) + 2*N*sizeof(double)
+ K*sizeof(double) (values) + K*sizeof(size_t) (indices) + sizeof(int) (error
flag) + max(1, queried CUB workspace bytes). Native odd-N padding is included;
common-input mode allocates exactly N normals. The two loss arrays are distinct.
CUB workspace is queried for the actual N with typed null data pointers in
storage-query mode, before allocating any pipeline buffer.

After device/context discovery, stream/event creation and the CUB storage query,
cudaMemGetInfo records free_before_bytes immediately before pipeline allocation.
The preflight rejects explicit_device_bytes > floor(4*free_before_bytes/5).
Integer arithmetic computes that limit without overflow or floating-point rounding.
The budget includes all seven explicit cudaMalloc buffers. It excludes opaque
context, stream, event and library allocations, host memory and competing GPU
activity. Existing context/stream/event costs already affect the free snapshot;
cuRAND generator creation follows preflight. This reserve is a guard, not a
capacity guarantee. Every actual allocation and API call remains checked.
free_with_pipeline_bytes is a later snapshot with resources live, not peak usage.

All size additions, multiplications, native padding and byte totals are checked.
Counts are checked before narrowing to int; launch dimensions are checked against
device properties, and the largest launched index must fit int. The gather's
32-thread block is covered by the stronger 256-thread loss-launch requirement.
Every rank is validated before conversion and use. Zero or unsupported N fails
before device work. Allocation/API/device-data errors throw without returning a
partial Result, switching backend or reducing N. RAII releases resources on
failure; cleanup errors do not replace an active exception. Successful-path
cleanup errors are propagated before a Result can return.

Current JSON reports milestone=full_device_scale_up, scenario_limit=10000000 and
allocation_budget_limit_bytes. The old capacity_linear_estimate_80pct field is
retired; historical JSON retains its original bytes and interpretation. The outer
schema remains 1. A successful scale check establishes execution for that request,
not a guaranteed maximum capacity.

## Checks and evidence

Query the current CTest registration after configuring; counts depend on build
options and platform. CPU-only builds also run cuda_plan_tests, without CUDA
headers or Toolkit discovery, covering arithmetic overflow, narrowing, padding,
exact budgets, synthetic free-memory rejection, launch limits and rank boundaries.
No test intentionally exhausts GPU memory. Common tests check signed losses, ties,
nearest ranks, sizes 1/5/256/257/9999/10000/10001, zero horizon/volatility, all-zero losses,
shared CSV calibration, unchanged caller inputs, invalid values/requests and
recovery after device rejection, 16 confidence levels and rejection of 17,
N=0 and N>10000000. Quantiles retain the strict regression tolerance
1e-10*max(1,abs(serial_var)) and also enforce the project absolute bound
0.00001*V0. Neither replaces analytical five-seed GPU acceptance. Native smoke runs
are archived separately and never compare CPU/GPU samples from equal seeds.

The legacy-named scripts/run-cuda-skeleton.ps1 requires a clean source commit,
allowing only the deliberately untracked AGENTS.md and output/ paths. Tracked
changes and any other untracked paths are rejected before and after verification;
those exclusions are recorded in the manifest. Outputs must use a new directory
below ignored results/.
It rebuilds the CUDA path and CUDA-disabled OpenMP ON/OFF configurations, records
current CTest lists/counts instead of assuming historical counts, and records
common-input JSON, native CSV smoke N=10000 plus an odd-count N=5 plumbing
check, library/compiler/runtime/driver versions, exact-byte hashes and transfer/
memory diagnostics. It checks fresh CPU ON/OFF-build estimates agree exactly.
Its optional -IncludeScaleChecks adds one native seed-42 check at each of
N=100000/1000000/10000000 using the existing synthetic CSV, plus focused
common-input scale checks at those sizes. These are not statistical acceptance
or benchmarks. The manifest binds the exact source commit/tree, CUDA/CPU build
caches and executables, synthetic input and output record hashes. CPU ON/OFF
comparison records and exact build caches remain in the local evidence directory.
For focused common-input scale verification, run mc_cuda_tests --scale-common;
it compares serial/GPU at those same N values and retains edge/recovery checks.
CTest itself keeps the smaller regression sizes. The recorder's historical clean
source requirement remains; working-tree verification must identify its base
revision and dirty source hashes separately rather than claim clean-commit testing.
The Windows driver package version, driver API version, nvcc, runtime header,
API-returned runtime and DLL file versions remain distinct observations.
Hosted CPU CI leaves CUDA disabled; local RTX execution is the GPU evidence.

The first-term evidence under evidence/v030-cuda-skeleton-windows-20261016 is
unchanged and remains capped connectivity evidence, with its historical test
counts and linear capacity estimate. Current scale-up verification is recorded
separately in project-state.md. No formal five-seed GPU acceptance, sanitizer
memory/race checks or formal CPU/GPU benchmark is implied. The unchanged five-seed
and common-input criteria are in acceptance-source.md. Later benchmarking retains
three excluded warm-ups, ten measured repetitions and native backend RNG. Profiling
is outside timed samples; bandwidth reporting remains required separately.

## Primary references

- [CUB device radix sorting](https://github.com/NVIDIA/cccl/blob/main/cub/cub/device/device_radix_sort.cuh)
- [cuRAND host API and normal-double requirements](https://docs.nvidia.com/cuda/archive/13.4.2/curand/curand/group__HOST.html)
