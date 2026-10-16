# Release verification v0.2.1

2026-10-15. Added `--version` to distinguish source and executable versions.
The CSV model and calibration method were unchanged.

A local copy of the shared v0.2 ZIP was inspected: it contained a CSV-enabled
main.cpp and a CMakeLists.txt registering three tests. In the student's output
on 2026-10-15, main.cpp lacked the CSV branch and CMake created only core_tests.
It is unknown when the Windows sources diverged. Changing the cache cannot
resolve this mismatch; mutually consistent source files must be used together.

v0.2.1 was prepared as a separate package. Verification consisted of extracting
the ZIP, compiling the core and data tests from its sources, and checking the
CLI version and CSV pipeline. This verification concerned GCC/Linux; the
MSVC/Windows CMake test was to be performed on the student's computer.
