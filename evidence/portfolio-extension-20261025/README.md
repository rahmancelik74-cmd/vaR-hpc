# Synthetic portfolio extension: local validation

Baseline: main 4b2040b72ba7f29f1a6e05c44537c53f4d953976. The new implementation
exists as local working-tree changes, identified by exact local-byte hashes in
[validation-summary.json](validation-summary.json). Those hashes describe local
workspace bytes, not normalized Git blobs. No new commit exists: `git add` failed
because `.git/index.lock` creation was denied. Nothing was staged or pushed and
there is no new exact-SHA hosted CI result. Git OpenSSL remote read confirmed
the baseline SHA; Schannel and GitHub CLI credentials were unavailable in this
executor. This package does not claim delivery to GitHub.

See [the contract and predeclared protocol](../../docs/portfolio.md). This is a
separate extension register; Plan A and existing FR/NFR acceptance are unchanged.
The original synthetic two/five-asset fixtures are redistributable, contain no
provider observations and use explicit common valuation unit USD.

Final Windows x64 checks:

| Configuration/check | Actual outcome |
| --- | --- |
| Serial-only, CUDA OFF | 16/16 CTests passed |
| OpenMP, CUDA OFF | 17/17 CTests passed |
| CUDA/OpenMP | 20/20 CTests passed |
| Retained Python regressions | 22 passed |
| Independent test-RNG transform/valuation moments | 33 Chebyshev/Bonferroni assertions passed; N=200000, seed 20261025, family alpha=.01 |
| Native capacity smoke | 5 assets, N=10000000, seed42, serial/OpenMP10/CUDA each completed |
| GPU memcheck, focused portfolio executable | 0 errors; 0 bytes leaked |
| GPU racecheck, same executable | 0 displayed hazards; shared-memory scope |
| MSVC AddressSanitizer, serial portfolio/core | 2/2 passed; /EHsc /fsanitize=address /Zi |
| Selected public historical evidence | Integrity passed; 22 benchmark, 32 diagnostic, 24 figure artifacts |

Common-input coverage: A=1,2,3,5; N=1,17,257,4097,10003; OpenMP
1,2,4,8,10. Includes one-asset analytical reduction, independent small-scenario
terminal prices/quantiles, C*epsilon orientation, reconstruction, deterministic
T=0/sigma=0/zero shocks, invalid matrices/parameters/dimensions, caller ownership,
odd cuRAND padding, partial final launch blocks, overflow cleanup and explicit
portfolio hybrid rejection. Existing single-asset hybrid tests also passed.

Ninja was used with the installed VS x64 developer environment after the VS
generator's SDK enumeration encountered a user-directory read restriction.
No software was installed and no permissions/settings were changed. The initial
CTest attempt was accidentally started before CUDA build completion and had
missing executables; it is retained locally and superseded by final complete
runs. The first ASan trial omitted /EHsc; only the corrected final run is counted.

Reference environment: i7-12650H from the local registry (fresh CIM denied),
10 physical cores from the existing inventory, RTX 4060 Laptop, compute 8.9,
nvcc13.4.92, CUB3.4.3, MSVC19.44.35227, CMake3.31.6-msvc6, Python3.11.4.
Detailed CUDA runtime/driver/header versions remain separate in the JSON outputs.
No core pinning, power control, thermal equilibrium or performance improvement
is asserted. Capacity and sanitizer trials are separate; 10M is not sanitizer
covered. Limited racecheck and serial ASan do not establish general race freedom
or OpenMP host-memory safety. The moment oracle tests the production transform
and valuation using a seeded test RNG, not each backend's native RNG distribution.
General portfolio VaR convergence/high-sample statistical acceptance is outside
this task. No advisor approval or academic submission occurred.

Raw logs, exact outputs, attempt history, completion note and a one-time normal
Git delivery script are retained in ignored `results/portfolio-20261025/`.
The JSON records relative paths and SHA-256 for these local artifacts and tested
executables/CMake caches; it does not imply that ignored raw logs are published.
