# Windows OpenMP correctness evidence, 2026-10-16

Application 0.3.0, clean source 05f982effc570366597fc5f13f8b3a0440b293a8.
The separate evidence commit changes documentation and archived artifacts only.
Historical serial and CUDA-probe evidence is unchanged.

This is correctness evidence using the synthetic CSV fixture, not a formal
performance benchmark or a claim of real-market predictive validity.

## Reproduction and provenance

From the recorded clean source commit in Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run-openmp-validation.ps1
```

The script configures explicit Visual Studio 2022 x64 builds, rebuilds Release
with --clean-first for ON and OFF, and runs verbose CTest. It checks a parsed
OpenMP CSV JSON smoke result, serial default JSON, native thread invariance,
and all 20 native-RNG statistical runs. No preexisting executable is reused.
Source cleanliness, revision and input/executable hashes are checked before
marking the campaign complete. See manifest.json for flags and timestamps.

The six ON and five OFF CTests all passed. The four original CTests remain.
openmp_tests covers exactly shared read-only inputs, block boundaries and
partial blocks, deterministic edge cases, seed boundaries, repeatability,
invalid inputs and worker exception propagation/recovery. CLI tests cover
old positional commands, final --json, invalid/duplicate/missing options,
exact uint64 seeds and unavailable OpenMP in the OFF build.

## Files and interpretation

- manifest.json: source revision, clean rebuild policy, input/executable
  SHA-256, compiler flags/version, environment and actual campaign team size.
- build-settings.json: Release x64 compile/link properties extracted from
  the generated MSVC projects; source-directory prefixes redacted.
- configure-ON/OFF.log, build-ON/OFF.log, ctest-ON/OFF.log: Windows build/test
  records. Source/user directory prefixes are redacted. The two build logs
  explicitly identify their English transcription of the localized MSBuild
  banner and give SHA-256 of the corresponding locally retained redacted
  native-language capture. Numeric and test output is unchanged. Those native
  captures remain under ignored results/openmp-correctness-05f982e locally.
- smoke.json and serial-smoke.json: raw application JSON for the CSV fixture;
  application version, input mode, backend, RNG and thread metadata checked.
- native-thread-invariance.json: native estimates unchanged across requested
  and actual threads 1,2,4,8,10 at N=10000 and 100000. These are not scaling
  measurements. Common-input correctness evidence is in ctest-ON.log.
- runs.jsonl: raw application JSON from the 20 native-RNG runs, with requested
  and actual threads 4; four N values and seeds 42,123,456,789,2026.
- estimates.csv: the same 40 confidence estimates; numbers use decimal dots.
- acceptance.json: at N=10000000, each confidence uses error of the five-seed
  mean. Both pass abs(mean(VaR)-analytical) <=
  0.01*max(abs(analytical),0.01*initial_value). No per-seed acceptance is imposed.
- audit.json: independent configuration/CSV/JSON/hash and explicit-sum checks.
- hosted-ci.json and hosted-ctest-ON/OFF.log: successful source-commit GitHub
  CPU CI jobs and contiguous CTest excerpts; six ON and five OFF tests passed.
- artifact-sha256.json: exact-byte hashes of archived files, excluding itself.
  Local .gitattributes disables newline conversion for this evidence folder.

At 95% confidence, mean VaR=6.142451880525334; absolute mean error
0.001125058893624242 <= 0.06143576939418959. At 99%, mean
VaR=8.712967414933399; error 0.002479301267548806 <= 0.08715446716200948.
Initial value=100.4. Sorting remains serial. Thread placement, power/thermal
conditions and repeated performance scaling remain future work.

Before the final clean-source campaign, recorder defects were fixed in focused
commits: PowerShell Decimal parsing, provider metadata serialization and an
automatic variable name collision. Earlier interrupted/failed local attempts
remain under ignored results/ and are not counted as completed evidence here.
