# Windows portable CPU distribution

Recipients download the successful `windows-portable` job's **mc-lab-portable-cpu-<SHA>**
GitHub Actions artifact ZIP, extract its complete contents to a local folder, and
double-click **Start Monte Carlo Lab.exe**. The native stop window remains open;
use **Stop application** or close that window to stop. **Open data / logs folder**
locates the per-user files. Closing the browser tab alone does not stop it.
There is no installer, background Windows service, startup registration or public
hosting. No Release/tag is created. Actions downloads may require GitHub sign-in
and expire after the configured 30-day retention period.

## Requirements and scope

Supported targets are Windows 11 x64 on an OS-supported x64 CPU and Windows
Server 2022 x64 (CI platform). The MSVC build uses its baseline x64/SSE2 target;
no AVX/native-CPU compiler flags are enabled. Built-in Windows PowerShell 5.1,
an installed supported default browser and writable LOCALAPPDATA are required.
8 GB RAM is recommended for larger requests; scenario/process/upload/storage
limits from [the application guide](local-browser.md) still apply. ARM64 and
32-bit Windows are not supported. Administrator rights and installed Python,
Anaconda, Git, CMake, Ninja, Visual Studio, CUDA Toolkit or npm are unnecessary.
Enterprise application-control restrictions remain applicable; do not disable
security protections to run the unsigned application.
Windows legacy path limits still apply to PowerShell and runtime file operations:
keep full resource and generated-data paths below 260 characters. Use the normal
Windows LOCALAPPDATA location; custom LOCALAPPDATA roots longer than 120 characters
are unsupported. Deeply nested test extraction/data roots can exceed this limit
even when spaces and Unicode are handled correctly. No OS long-path setting is changed.

The CPU edition bundles serial/OpenMP and explicitly reports CUDA unavailable.
CUDA development startup remains available from sources. No optional CUDA binary
edition is distributed because this task does not establish its redistribution
and compatibility contract. The existing UI, numerical/RNG/quantile/calibration
contracts and raw export precision are retained. Synthetic examples are original
redistributable fixtures. Local CSV/metadata contracts and the strictly bounded
Nasdaq 2023..2025 calendar remain unchanged; no live data or cloud uploads occur.
See the application guide for model/provenance limitations and a walkthrough.

## Contents, startup and shutdown

The archive includes a native C++ launcher, an app-local trimmed official CPython
3.14.9 x64 embedded runtime, the current Release CPU engine, unmodified Microsoft
x64 desktop CRT/OpenMP redistributable DLLs, existing UI/import/calibration files,
calendar, synthetic examples, START_HERE.txt, third-party notices/licenses,
package-manifest.json, integrity.sha256 and dependency-audit.json.

The parent validates file hashes before loading Python; the Python entry point
validates the manifest again before constructing the application. The manifest
records source revision, actual build-time tracked dirty state, toolset, upstream
runtime hash and per-file hashes. Runtime Git cleanliness is not invented:
portable imports use the package revision and null git_dirty. These are unsigned
integrity/provenance records, not authenticated code signatures. Redownload and
extract the complete archive if files are missing/changed.

A per-session mutex rejects repeated portable launches. The service binds IPv4
loopback on an OS-assigned free port, probes its own readiness/engine identity,
and only then asks the native parent to open that URL. It neither probes nor
opens unrelated services. The parent owns a kill-on-close Windows Job Object for
Python and all its engine/import descendants. Graceful Stop requests drain/cancel
work; a bounded fallback terminates the owned job. The parent itself is outside
that job, so user browsers and Explorer are not killed on application shutdown.
No port-owner process is terminated.

All writable state is under `%LOCALAPPDATA%/MCLabPortable`: launcher records in
`sessions`, uploads/imports/calibration/results/private raw diagnostics in
`workspace/data/local/browser-app`. Selected original files remain unchanged.
Resources beside the executable are not written. The launcher works with spaces
and Unicode extraction paths; the engine has a process-local UTF-8 codepage
manifest, without changing Windows language settings. Stop before archiving or
removing only clearly identified application-owned data; no automatic recursive
cleanup touches historical evidence or unrelated files.

Packaged startup performs no build, installation, Git access or network download.
The existing PowerShell importer implementation is bundled verbatim as fixed
integrity-checked command text; structured app-owned JSON supplies its inputs.
It runs with `-NoProfile -NonInteractive -Command`, without ExecutionPolicy flags,
policy changes or arbitrary browser-supplied commands. Existing enterprise
PowerShell application-control/language policies remain in force. This avoids
depending on a source checkout or executing downloaded script files directly.

## Build, audit and verification

From a licensed Windows Visual Studio 2022 C++ build environment with Python
3.11+, CMake >=3.24 and Ninja on PATH:

```powershell
python -B scripts/build_portable.py --output results/portable-my-new-build
python -B scripts/check_portable.py results/portable-my-new-build/mc-lab-portable-cpu-v1-<revision-prefix>.zip --output results/portable-my-new-check
```

Both output directories must be new and under ignored results. No global Python
package is installed: the builder uses the standard library, an isolated official
runtime download cache and dedicated existing CPU CMake build directory. It
clears compiler flag overrides in its own process, builds CUDA OFF/OpenMP ON,
compiles the static-CRT launcher and embeds the engine's UTF-8 manifest. An explicit
allowlist constructs the new staging tree. No private data, results/data-local
contents, evidence folders, credentials, .git, AGENTS.md, development caches or
academic files are selected. Generated ZIPs/binaries are never committed.

The runtime ZIP URL and SHA-256 are pinned in the builder; a mismatch fails.
The unmodified upstream license and the appropriate Visual Studio edition's
license document are retained. Rebuilding is reproducible by command, not a claim
of bit-identical output across toolsets, timestamps or upstream license-document
updates. Each produced archive gets an exact checksum. GitHub's artifact wrapper
places the staged package files directly at its ZIP root; locally built ZIPs add
one enclosing folder. The same checker supports both layouts. GitHub artifact
digests and a checksum computed after download identify the actual delivered ZIP.

Every packaged EXE/DLL/PYD is inspected with dumpbin. The dependency audit rejects
unbundled Python/VC/OpenMP/non-OS libraries; only supported Windows system/API-set
imports may resolve from the OS. No libraries are copied from System32. This is
stronger than a successful launch on a machine with developer runtimes, but is
not a clean consumer installation test.

Actual extracted-package checks use paths containing spaces and non-ASCII
characters, including a separate writable user-data path. PATH contains only
Windows system tools; Python/Conda environment settings are removed. Checks cover
startup/repeated launch, single/portfolio serial/OpenMP and direct CLI equality,
synthetic uploads/calibration, invalid data and recovery, cancelled calculations,
raw JSON/CSV precision, missing/tampered assets, graceful shutdown during work,
and forced-launcher-exit cleanup with OS process inspection. Owned test requests
are bounded and are not research campaigns. The Windows CI job repeats these
checks and retained CPU regressions, then uploads only the portable resources.
A hosted Windows Server runner is a different execution host, not a fresh
consumer installation. No disposable clean Windows VM is available through the
current executor. A default-browser dispatch check is distinct from seeing the
page: current browser automation has no enabled surface and IAB is unavailable,
so packaged UI rendering and clicking the native stop button remain unverified
visually. Existing application browser observations do not substitute for this.

## Primary redistribution/implementation references

- [Official CPython embedded distribution](https://docs.python.org/3.14/using/windows.html#the-embeddable-package) and [PSF/incorporated licenses](https://docs.python.org/3.14/license.html).
- [Visual Studio 2022 Distributable Code list](https://learn.microsoft.com/en-us/visualstudio/releases/2022/redistribution) and [application-local DLL guidance](https://learn.microsoft.com/en-us/cpp/windows/determining-which-dlls-to-redistribute?view=msvc-170). Redistribution is conditional on the builder's valid Visual Studio license; debug/nonredist folders are excluded.
- [Windows Job Objects and inherited child membership](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).
- [PowerShell execution policy behavior](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1).
