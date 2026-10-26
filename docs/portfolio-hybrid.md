# Portfolio hybrid CUDA extension (PH)

This extension adds explicit hybrid execution to the existing portfolio engine.
It leaves FR-1..FR-9/NFR-1..NFR-9, portfolio P/PC criteria and all previous
campaigns unchanged. See the [frozen PH-1 protocol](../evidence/portfolio-hybrid-20261026/PROTOCOL.md)
and [actual execution evidence](../evidence/portfolio-hybrid-20261026/README.md).

## Commands and support

From the repository root, after a Release CUDA/OpenMP Ninja build:

```powershell
.\build-portfolio-hybrid-cuda\mc_var.exe --portfolio data/portfolio-two.txt 10003 42 --backend serial --json
.\build-portfolio-hybrid-cuda\mc_var.exe --portfolio data/portfolio-two.txt 10003 42 --backend cuda --cuda-mode full-device --json
.\build-portfolio-hybrid-cuda\mc_var.exe --portfolio data/portfolio-two.txt 10003 42 --backend cuda --cuda-mode hybrid --batch-size 257 --cuda-diagnostics --json
```

Supports 1..5 assets and 1..10000000 scenarios, subject to resources. CUDA stays
optional/default OFF. Full-device is the default CUDA mode; no failed request
switches modes. Hybrid requires an explicit --batch-size integer 1..10000000.
Full-device rejects batch size; CPU backends reject CUDA options. Duplicate,
missing and invalid CLI settings fail. B=min(requested batch,N); B=1 stays 1
for portfolios, including one-asset portfolios. Sizes greater than N give one
batch. Process min(B,N-offset) scenarios per batch, including the final partial
batch. No portfolio model, confidence or valuation limits change.

## Simulation and global sample

Prepare/validate the existing lower Cholesky factor before primary timing.
Independent normals are scenario-major, with all A assets of a scenario in the
same batch. Reuse the full-device portfolio kernel: Z=C*epsilon, ordered asset
terminal GBM contributions, then ONE scalar loss per scenario. Sum
-v_i*expm1(exponent_i), preserving the existing cancellation-resistant valuation.
Copy those scalar losses into the disjoint contiguous host range
[offset,offset+count). Exactly N host scalar losses are intentional; a native
N*A host-normal matrix is never allocated. Sort all N losses ascending once
with std::sort<double>; both .95 and .99 use ceil(alpha*N)-1, no interpolation,
clipping, individual-asset VaR addition or batch quantile averaging. Repeated
supported confidence entries retain their order. No general analytical
portfolio VaR is emitted (existing null fields remain).

Common-input validation accepts the existing read-only finite N*A vector:
common[s*A+i]. Checked offset*A and count*A select each batch slice. Native RNG
is bypassed, nothing is padded/copied beyond the logical input, and the caller
vector is preserved. Wrong dimensions/nonfinite input fail before execution.

## Native RNG and partition

One seeded CURAND_RNG_PSEUDO_PHILOX4_32_10 generator per run on the engine stream;
no per-batch reseeding, offset reset, alternate RNG or ordering override.
Each call generates count*A+(count*A)%2 doubles because normal-double requires
an even count. Only count*A entries are consumed; a padding entry is unused.
For an odd A and odd interior B, every such batch discards one padding entry.
The final partial batch obeys the same rule. Batching does not split a scenario
or shift the next scenario's asset indexing. Metadata normals_generated sums
actual padded calls; normals_allocated is the largest padded batch capacity.
Equal seed does not imply equal samples across modes, engines or batch sizes.
Exact repeated settings are checked within this build; cross-build/library or
batch-size invariance is not promised.

Single-asset non-portfolio hybrid retains its existing even scenario batch
rounding and only final total-request padding. A one-asset *portfolio* uses the
new exact scenario B convention. Common-input reduction agrees; native samples
need not agree when the API call partitions differ.

## Resources and failures

Explicit device bytes = 8*(B*A+(native ? (B*A)%2 : 0)) + 8*B + sizeof(int).
These are normals, scalar losses and the invalid-loss flag. There is no device
sorted-loss array, CUB workspace, rank array or per-scenario RNG-state buffer.
PHILOX host API owns opaque generator state; the portfolio path creates/seeds
it before cudaMemGetInfo. Already allocated generator/context/stream/events
therefore reduce free_before_bytes. Opaque allocations lazily made by cuRAND
are not advertised as known workspace bytes: the 20% free-memory reserve covers
these and competing activity conservatively, without guaranteeing success.
Reject explicit buffers above floor(4*free_before_bytes/5) before host loss
resize/device allocations. The full N-double host array is separately reported.

Check count/byte products, padded counts, offsets, vector capacity, launch grid
limits and resource budget. Host bad_alloc, cudaMalloc, cuRAND, launch, copies,
synchronization and checked successful cleanup failures propagate. No partial
Result is returned. Existing RAII synchronizes and frees on exceptional exit;
failed transfers drain the stream while host storage is alive. No deliberate
allocation exhaustion or injected API-failure coverage is claimed. Live VRAM
snapshots include allocator/library effects and other activity; they are not
measured peaks, portable capacity limits or universal OOM recovery.

## Timing, metadata and reproducibility

Primary steady-clock engine time includes context discovery/API work, per-run
host/device allocation, generator setup/generation, correlated simulation,
scalar transfers, one global host sort/quantile, synchronization and temporary
cleanup. Shared parsing/calibration/validation/Cholesky preparation and final
output stay outside. Each recorded CLI run is a fresh process; the test binary
reuses a process/context across cases. Context and JIT/driver caches are not
flushed; no thermal equilibrium is claimed. Small times are illustrative only.

Existing schema_version=1 and JSON/CSV consumers remain intact. Portfolio CUDA
adds requested_mode/effective_mode (equal, no fallback) and asset_count; existing
mode, requested/effective_batch_size, batch_count, RNG policy, transfer accounting,
host_loss_bytes, explicit_device_bytes, free-memory snapshots and timing_scope
remain available. Single-asset JSON behavior is preserved. Optional diagnostics
accumulate same-stream device Event intervals by stage and transfer direction;
host_quantile_ms is a host clock interval. Pipeline span includes host submission
gaps but excludes allocations/context/cleanup and host quantile. Stage sums,
copy sums, pipeline span and primary wall time are different quantities; do not
add overlapping spans or imply they must sum to wall time.

Reproduce the focused local checks (CUDA toolkit and existing MSVC developer
environment required; no installations):

```text
python -B scripts/check-portfolio-hybrid.py checks
python -B scripts/check-portfolio-hybrid.py statistical
python -B scripts/check-portfolio-hybrid.py historical
```

The recorder retains exact stdout/stderr bytes and command records. Successful
hash-verified records resume without executing native samples again; failed
attempts require a reviewed new label and remain preserved. Historical mode
requires the original private ignored calibration/import artifacts. Hosted CPU
CI executes synthetic CPU regressions only and does not run this CUDA recorder,
private data, sanitizer/capacity study or optional NumPy distributional check.
