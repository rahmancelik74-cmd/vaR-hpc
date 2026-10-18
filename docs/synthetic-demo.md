# Reproducible serial/OpenMP synthetic demo

This small offline demonstration uses the existing engines, analytical
reference, JSON output and recorder. It needs no provider data, network access
or new dependency. Timing is smoke output, not a formal benchmark, speedup
claim or statistical acceptance.

## Build and check

From the repository root, use the existing Windows x64 CPU build directory:

```powershell
cmake -S . -B build-historical-cpu -DMC_ENABLE_OPENMP=ON -DMC_ENABLE_CUDA=OFF
cmake --build build-historical-cpu --config Release --parallel
ctest --test-dir build-historical-cpu -C Release --output-on-failure
```

This is a build directory in the authoritative source tree. CUDA is unnecessary
for this demo. The separate full-device CUDA path is described in cuda-skeleton.md.
A serial-only build explicitly
rejects OpenMP selection.

## Run

```powershell
./scripts/run-experiment.ps1 -Mode smoke -Executable build-historical-cpu/Release/mc_var.exe -Backend serial
./scripts/run-experiment.ps1 -Mode smoke -Executable build-historical-cpu/Release/mc_var.exe -Backend openmp -Threads 4
```

If local scripts are blocked, prefix either invocation with
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File`; no persistent policy
change is needed. Each command prints its unique ignored results directory.
Read manifest.json, runs.jsonl and estimates.csv there. Failed attempts retain
failed status and must not be presented as successful runs.

Both commands use the exact existing data/synthetic_prices.csv, N=10000,
seed 42, one unit, a ten-observation horizon and 252 observations/year. The
hand-written fixture is artificial; its dates are software labels, not an
exchange-calendar claim. No MSFT import is accessed.

The calibrated model, rounded here for readability, is V0=100.4,
annual price drift mu=0.11221749496730603, sigma=0.2037837912712771 and
T=10/252 years. Full precision remains in JSON. Calibration uses log returns,
n-1 sample variance, sigma=sqrt(s2/dt) and
mu=mean_log_return/dt+0.5*sigma*sigma.

At confidence 0.95/0.99, analytical references are approximately
6.143576939418958 and 8.715446716200948. The formula remains
V0-V0*exp((mu-0.5*sigma*sigma)*T+sigma*sqrt(T)*Phi_inverse(1-alpha)).
Simulation uses double precision and exact terminal GBM sampling; losses are
sorted ascending, rank is ceil(alpha*N)-1 without interpolation, and negative
VaR is retained. Engines and RNG assignment are unchanged.

## Interpretation and limits

Equal serial/OpenMP native seeds do not produce common samples. Compare their
shared model/reference and independently recorded estimates; do not require
native VaR equality. Same-build OpenMP estimates remain invariant across thread
requests. Requested threads and actual team size are recorded separately.

Each command starts one fresh CLI process, with no warm-up and one recorded
run. Engine time includes allocation, RNG, simulation, serial sorting, quantiles,
synchronization and cleanup; process startup, CSV/calibration and JSON/file
output are excluded. Two confidence rows share one run's time; do not add them.
Clocks, temperature and thermal equilibrium are unmeasured. No per-core pinning
is claimed. Timings vary and do not establish comparative performance.

Manifests retain exact-byte input/executable/recorder hashes, revision and dirty
state. A hash does not prove source-to-binary correspondence; the existing flag
remains false. Numerical repeatability is scoped to the same build/library.

The five-seed criterion remains, separately per engine and confidence at
N=10000000: abs(mean(VaR)-analytical) <=
0.01*max(abs(analytical),0.01*V0). Common-input cross-engine absolute difference
must remain <=0.00001*V0. This N=10000 smoke evaluates neither criterion.
Existing correctness evidence is preserved. The full CPU recorder retains its
clean-source requirement and formal warm-up/repetition policy.

## Verification

demo_recorder_tests checks smoke classification, CSV/JSON agreement, artifact
hashes, shared analytical references, OpenMP thread invariance, invalid campaign
and thread arguments, and unavailable OpenMP rejection in serial-only builds.
equity_calendar_tests remains a separate artificial-data test. Neither test
accesses provider data.
