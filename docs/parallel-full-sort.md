# Bounded parallel CPU full sorting

`--backend openmp --threads G --sort-threads S` enables full sorting with
S bounded OpenMP workers (1 through 10), independently of generation workers G.
Omitting `--sort-threads` preserves the original OpenMP plus serial std::sort.
The serial backend and CUDA paths are unchanged. No partial selection is used.

The implementation uses the existing OpenMP runtime, disjoint std::sort runs
and level-wise std::merge into an additional N-double scratch buffer. Teams
join between generation, sorting and merge levels. Merge parallelism decreases
at later levels; the final merge is one job. S is an upper team bound, not a
claim that S cores are busy throughout. OMP_DYNAMIC=FALSE is required by the
study; no affinity or per-core pinning claim is made. Allocation and cleanup
are included in engine wall time. Existing MSVC OpenMP linking is sufficient.

std::execution::par is deliberately not used: its MSVC Windows thread-pool
scheduler does not provide an OMP_NUM_THREADS concurrency contract. The bounded
implementation needs no new dependency and has no nested parallel regions.

Reproduction: `scripts/run_matched_sort_study.py`, after Release builds and
CTest. The recorder fixes order before launching, preserves all observations,
uses the existing process probe and synthetic fixture, and separates Event
diagnostics from primary wall timings. See its manifest for source/executable
hashes, context policy and environmental limits.
