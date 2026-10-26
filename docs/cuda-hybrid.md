# Explicit hybrid CUDA batching

This page describes the retained single-asset convention. Portfolio support is
a separate [PH extension](portfolio-hybrid.md): exact scenario batches, N*A
scenario-major inputs and per-call odd-normal padding. Earlier evidence below
remains historical.

The default CUDA mode remains full-device, with one global CUB 3.4.3 sort and
device rank gather. Hybrid is selected explicitly; allocation failure never
switches modes or reduces N. Both modes support 1 <= N <= 10000000 and 1 through
16 confidence levels. Batching is an implementation step, separate from formal
five-seed GPU acceptance, memory/race checking and performance benchmarking.

## Selection and ownership

```powershell
.\build-cuda-hybrid\Release\mc_var.exe 1000000 42 --backend cuda --cuda-mode hybrid --batch-size 65535 --json
```

--batch-size is mandatory with --cuda-mode hybrid and rejected in full-device
mode. CUDA options are rejected for CPU backends. Requested batch size must be
an integer from 1 through 10000000; a size greater than N is supported. CUDA
remains optional/default OFF and unavailable selection fails explicitly.

CudaEngine(CudaMode::Hybrid, batch_size) uses the unchanged Engine::run boundary.
The caller retains its request and optional common_normals vector. The engine
owns one N-double host loss vector, device batch normals/losses, an error flag,
generator, stream and events. Native production mode does not create or transfer
a host normal vector. CPU engines and their sorting/RNG assignments are unchanged.

Every batch writes its losses to the contiguous host range [offset, offset+count).
Offset advances by count, including a partial final batch. The engine checks that
exactly N losses were transferred. It sorts the complete host vector once with
std::sort, then calls the existing sorted_quantile utility for each confidence:
ascending zero-based rank ceil(alpha*N)-1, no interpolation. No batch VaRs are
computed or averaged. Loss is V0-VT via the existing double expm1 expression;
negative VaR is retained.

## RNG and batch boundaries

Native mode creates and seeds one CURAND_RNG_PSEUDO_PHILOX4_32_10 generator per
request, sets its stream once and repeatedly calls curandGenerateNormalDouble.
There is no batch reseeding, offset reset, alternate RNG or ordering override.
The requested native batch size is rounded up to even, then capped at N. Thus
requested 1 uses effective 2 when N > 1, and requested 65535 uses effective
65536 when N permits. Interior calls consume even counts with no discarded
normal. Only an odd total request has one final padding normal, generated but
not simulated or copied as a loss. Total native normals generated is N+N%2.

This is continuous generator state under a documented sequence of API calls.
Call partition is part of the native RNG configuration: batch-size invariance
and equality with a one-shot full-device sample are not promised. Repeating the
same request/partition in the same build is tested. Independent native-reference
tests concatenate raw cuRAND outputs for explicitly specified call payloads,
then compare CPU losses/global quantiles with hybrid. A one-batch hybrid is also
compared with the full-device native path in small fixtures. These checks do not
establish cross-build/library reproducibility. Equal native CPU/GPU seeds do not
imply equal samples.

Common-input mode bypasses cuRAND and retains requested batch size exactly,
capped at N. It copies each caller normal once without mutation or padding.
Common-input numerical agreement is checked separately from native stream tests.

## Memory and failures

Let B be effective payload capacity. Native normal capacity is B+B%2; common
capacity is B. Explicit device bytes are

normal_capacity*sizeof(double) + B*sizeof(double) + sizeof(int).

There are three cudaMalloc buffers; no device sorted array, CUB workspace or
device rank/result arrays are allocated in hybrid mode. The compiled CUB version
is still reported for the build, but quantile_location=host and the quantile
library label identifies std::sort plus sorted_quantile.

After context discovery and stream/event creation, before host loss resize or
device buffer allocation, cudaMemGetInfo supplies free_before_bytes. The engine
rejects explicit device bytes exceeding floor(4*free_before_bytes/5). This is the
same 80%-free guard as the full-device path, applied to actual batch buffers.
It excludes the N-double host array, opaque library/context allocations and
competing GPU activity. cuRAND creation follows preflight. The reserve and later
live-memory snapshot are not capacity guarantees or measured peaks.

Host storage bytes and vector capacity, padding, byte products/sums, offsets,
counts and launch dimensions are checked before use. Host allocation failure
reports a hybrid host loss allocation error; CUDA/cuRAND failures retain useful
operation labels. Invalid/nonfinite normals and nonfinite losses reject the
request before incorporating that batch. No partial Result is returned. RAII
releases resources on failures; successful cleanup errors propagate. A failed
transfer drains its stream while host storage is alive, preserving the original
exception if cleanup also fails. No deliberate host/GPU exhaustion test is used.

## Metadata and timing

The backend remains cuda; mode=hybrid, milestone=hybrid_batching,
quantile_location=host and host_sorting_used=true distinguish the execution path.
requested_batch_size, effective_batch_size and batch_count record partitioning.
normals_allocated is batch normal capacity; normals_generated is the total native
count (zero for common input). host_loss_bytes and losses_transferred record host
storage and completed scalar-loss transfers. Full-device reports mode=full-device,
one batch of N, zero host loss bytes and zero loss-vector transfers.

Primary steady-clock timing includes context/API work, host/device allocation,
generator setup/generation, simulation, every transfer, synchronization, global
host sorting/quantile and temporary host/device cleanup. Shared input/calibration
and output are excluded. CLI checks use fresh processes/contexts. Multi-case test
executables retain one process but create per-request resources.

Transfer CUDA Event milliseconds and byte counters sum all copy intervals on the
engine stream. Native H2D bytes are zero; common H2D bytes are N*sizeof(double).
Hybrid D2H bytes are N*sizeof(double)+batch_count*sizeof(int), including one error
flag per batch. Pageable staging is included in host time but need not appear
fully in Event intervals. Event totals exclude host quantile and are not complete
device-pipeline timings, benchmarks or speedup figures.

## Reproduction and checks

Configure Windows x64 Release with MC_ENABLE_CUDA=ON, MC_ENABLE_OPENMP=ON,
MC_BUILD_CPU_TOOLS=OFF, BUILD_TESTING=ON, CUDA toolset 13.4 and architecture 89.
Query the actual CTest list. cuda_hybrid_tests covers common inputs, all ranks
of small fixtures, signed/tied losses, negative VaR, one/multiple/partial batches,
odd/even counts and batch requests, oversized batches, native cuRAND reference,
invalid inputs and recovery. cuda_plan_tests also covers synthetic budget rejection,
host vector limits and arithmetic overflow without requiring CUDA. Run
mc_cuda_hybrid_tests --scale-common for three-way CPU/full-device/hybrid checks
at N=100000/1000000/10000000 with forced common batches of 65535.

From a clean source commit, the existing recorder supports:

```powershell
./scripts/run-cuda-skeleton.ps1 -OutputDirectory results/hybrid-verification-unique -IncludeHybridChecks -IncludeScaleChecks -HybridBatchSize 65535
```

It records native synthetic-CSV hybrid checks, common-input/native-reference test
results, configuration, exact-byte input/executable/record hashes and source SHA.
It retains its clean-source requirement (only untracked AGENTS.md/output/ are
excluded). Working-tree implementation checks must instead identify the base SHA,
source hashes and dirty status explicitly. See project-state.md for the current
local evidence and limitations. Historical records are not relabeled or replaced.

## Verified source checkpoint

The complete clean-source recorder with both verification switches and requested
batch size 65535 passed for f03903402ddfb3bfc591dcb092dec73603448854 on the
Windows RTX 4060. Local evidence is under ignored
results/cuda-hybrid-f039034-clean-20261019/, including manifest.json and a separate
independent-audit.json. CUDA/OpenMP ON passed 12/12 tests; CPU-only OpenMP ON and
OFF passed 10/10 and 9/9. Native target sizes used 2/16/153 batches with effective
65536 and 1048580 explicit device bytes. Separate common-input scale checks used
effective 65535. The independent native cuRAND reference and one-batch full-device
comparisons passed; no batch-size invariance is claimed. The default full-device
native results also matched the earlier e4ae788 clean-source records exactly at
N=10000/100000/1000000/10000000. These are implementation checks, not acceptance
or benchmark results. The later documentation commit is distinct from the tested
source; detailed source/hash/timing bindings are in project-state.md.

The later clean source 8df5f28 passes five-seed analytical acceptance separately
for full-device and hybrid (requested batch 65535, native effective 65536), plus
the representative sanitizer matrix. See gpu-acceptance.md and project-state.md
for source/provenance bindings, four outcomes and memory/concurrency limitations.
The earlier implementation evidence above remains unchanged.
