# First-term CUDA walking-skeleton evidence, Windows RTX 4060

Date: 2026-10-16. Clean source: 89512365186698278d0f79688d200e9039276415.
This archive proves end-to-end connectivity at N=10000, not full-scale GPU
acceptance, optimization or performance benchmarking. CPU numerical engines
and all historical evidence are preserved. No requirement IDs were changed.

## Verified path

CSV -> shared calibration -> Engine::run -> device cuRAND PHILOX normal-double
generation -> double terminal losses -> CUB device double radix sort -> device
nearest-rank gather -> two scalar VaRs. No host sorting is used. CUB 3.4.3
(compiled CUB_VERSION=300403) is the intended quantile library for the later
full implementation. Native RNG samples are not expected to match CPU seeds.

The clean-source recorder scripts/run-cuda-skeleton.ps1 rebuilt Windows x64
Release, explicit CUDA architecture 89, with CUDA enabled and then disabled
for OpenMP ON/OFF. All 7/6/5 CTests passed. The seven CUDA-enabled tests retain
the six CPU tests and add common-input/device-error checks. CPU-only CLI tests
verify unavailable CUDA selection fails clearly. CUDA defaults OFF in CMake.
Fresh serial/OpenMP estimates agreed exactly between CUDA ON/OFF builds.

## Evidence files

- manifest.json: clean source/build policy, exact input/executable/test hashes,
  compiler settings, DLL versions/hashes, Windows driver and observed CUDA
  metadata. Target options include --fmad=false and MSVC /Zc:preprocessor;
  the latter is required by installed CCCL. CPU target flags are unchanged.
- configure/build/ctest logs: seven CUDA tests, six CUDA-disabled OpenMP tests,
  five serial-only tests. Paths are redacted. Build logs explicitly label the
  English transcription of the MSBuild banner and provide capture hashes;
  redacted native-language captures remain locally under ignored
  results/cuda-skeleton-8951236. Numerical/test output is not translated.
- common-input-checks.json: 32 numerical comparisons with identical read-only
  caller normals, including partial blocks, signed/tied/zero losses, nearest
  ranks, deterministic models and shared CSV calibration. Nonfinite inputs,
  overflow, invalid requests and recovery were also checked. Maximum absolute
  CPU/GPU difference: 7.105427357601002e-15, below the fixed
  1e-10*max(1,abs(serial_var)) tolerance. This is not native-RNG acceptance.
- native-N10000.json: independent native cuRAND CSV smoke, seed 42, 95%/99% VaR.
  Native estimates are 6.159886901343543 and 8.715234403518073. Analytical
  comparisons in the application JSON are descriptive, not a pass/fail test.
- native-N5.json: a separate odd-count plumbing smoke, exact uint64 maximum
  seed string; six normals generated, five consumed. No large GPU run occurred.
- independent-audit.json: recomputed common-input differences, explicit memory
  accounting, capacity formula, transfer byte counts, padding and input/exe hashes.
- artifact-sha256.json: exact-byte hashes, excluding itself. This folder's
  .gitattributes preserves bytes without newline normalization.
- hosted-cpu-ci.json and hosted-cpu-*.log: all three existing CPU CI jobs passed
  for the verified source with CUDA disabled. Linux CTest and Windows recorder
  progress excerpts are retained; Windows CTest logs are runner-local and test
  errors fail that job. These are CPU regressions, not hosted GPU execution.

## Actual versions

RTX 4060 Laptop GPU, compute capability 8.9, reported VRAM 8585216000 bytes
(8187 MiB). nvcc 13.4.92; host MSVC 19.44.35227.0. Windows NVIDIA driver package
32.0.16.1088. Driver API returned 13030; runtime API also returned 13030 while
the compiled runtime header is 13040. These are distinct recorded observations,
not replaced with the nvcc version. Copied cudart64_13.dll file version is
6,14,11,13040; curand64_10.dll file version is 6,14,11,1044. cuRAND header
10.4.4.72; curandGetVersion returned 10404. CUB is header-only and reports
300403. The runtime API/header discrepancy remains explicit; no unsupported
explanation or inferred installation change is claimed.

## Transfer timing and initial VRAM estimate

The primary engine timer includes CUDA context/API work, allocation, cuRAND,
loss generation, CUB query/storage/sort, gather, copies, synchronization and
resource cleanup. CSV/calibration and JSON output are outside. Every CLI smoke
uses a fresh process; these diagnostic timings are not a performance campaign.
H2D/D2H copies are separately timed with CUDA Events on the engine stream.
Native mode transfers 16 rank-index bytes H2D and 20 bytes D2H (error flag plus
two doubles). Common-input records include the additional N normal doubles H2D.
Pageable host staging is fully inside primary wall time but may not be fully
represented by device event intervals. See native JSON for exact event values.

For the N=10000 native smoke, explicit device allocation was 331939 bytes,
including 91903 bytes of queried CUB temporary storage, normals, both double
sort buffers, indices, quantiles and error flag. Free VRAM before allocations
was 7451181056 bytes and with the completed pipeline live 7442792448 bytes.
The 8388608-byte observed decrease also reflects opaque library/context effects
and allocation granularity; the explicit budget is not a complete VRAM ledger.
The initial linear 80%-free extrapolation is 179579526 scenarios. This is
**not a tested capacity**: opaque allocations, nonlinear workspace scaling and
other GPU activity prevent that conclusion. The hard implementation cap remains
10000. No capacity-sized allocation, full-scale statistical campaign or GPU
benchmark was attempted.

Protocol, library decision and primary API references:
[docs/cuda-skeleton.md](../../docs/cuda-skeleton.md).
