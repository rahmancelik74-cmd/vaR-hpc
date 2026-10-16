# Initial verification

2026-10-14: software checks for this initial package only.

- Core, CLI and test executables compiled with GCC 13.3.0, C++17.
- No compiler warnings with `-O2 -Wall -Wextra -Wpedantic`.
- Deterministic core tests passed: known normal quantiles, nearest-rank,
  zero horizon, zero volatility, negative VaR, common inputs, seed repeatability
  within the same build and rejection of invalid inputs.
- Fixed synthetic demo ran with N=10000, seed=42, producing 95%/99% VaR.
- Tests passed with UndefinedBehaviorSanitizer. The combined AddressSanitizer/
  UndefinedBehaviorSanitizer run could not complete because LeakSanitizer could
  not access /proc in the execution environment; leak checking was not counted
  as passed.
- Neither the CMake executable nor the Python cmake module was available in
  that environment, so CMake/CTest were not run. Sources were checked directly
  with g++. Local CMake/CTest and subsequent CI required separate verification.
- nvcc and nvidia-smi were unavailable there; CUDA compatibility and execution
  were not verified.
- The student's target hardware was not measured; no performance claim is made.
- The five-seed / 10-million-scenario acceptance campaign had not yet been run.

These checks establish the mathematical/programming foundation. They do not
establish that all correctness and performance success conditions in the
approved proposal have been met.
