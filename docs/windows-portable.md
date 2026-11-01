# Windows portable CPU distribution

Recipients download the runnable ZIP from the
[Windows portable CPU preview release](https://github.com/rahmancelik74-cmd/vaR-hpc/releases/tag/portable-cpu-v1-preview),
extract its complete contents to a local folder, and
double-click **Start Monte Carlo Lab.exe**. The native stop window remains open;
use **Stop application** or close that window to stop. **Open data / logs folder**
locates the per-user files. Closing the browser tab alone does not stop it.
There is no installer, background Windows service, startup registration or public
hosting. The release asset is the sharing link; GitHub's generated source
archives are not the runnable application. Actions artifacts remain an alternative
that may require GitHub sign-in and expire after 30 days. The release ZIP is
8,634,588 bytes, built from ab184ae913e52d9b41deadc9b0df316a4b189b55;
SHA-256: 3e6836f8c50936b87480b9488559d5326bfc5872d49fc8d06a9248c4c40b3b77.

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
consumer installation. At the original packaging checkpoint, no disposable
consumer VM or browser surface was available to that executor; packaged rendering
and native Stop clicking were then unverified visually. These historical limits
are superseded only for the specific later VM observations below. Automated
checks, direct GUI observations and user reports remain distinct evidence.

## Windows VM follow-up (2026-11-01)

The unchanged published CPU ZIP was exercised in a Windows 11 VM after the
user completed Windows/browser setup. Direct GUI observations covered extracted
package startup, synthetic single-asset and two-asset serial/OpenMP analyses,
JSON/CSV contents, concise missing-file rejection, valid-analysis recovery and
invalidation of prior results/download controls after a rejected replacement.
The native Stop application button closed the launcher; reloading the actual
former application endpoint returned connection refused. This is an endpoint
observation, not a new complete OS process-tree inspection.

The controlled example runs used 100000 scenarios, seed 42 and a 10-trading-day
horizon; the comparison used four OpenMP threads. Initial values were 101 USD
and 265 USD. Export inspection retained unrounded values, negative portfolio
VaR and unavailable general-portfolio analytical references. These bounded GUI
checks are not formal benchmarks or statistical acceptance campaigns.

The user separately reported requesting cancellation during an approximately
2.4-second run: no completed result or JSON/CSV buttons remained, and a new
100000-scenario analysis subsequently produced a result table. These are
user-reported observations, not executor-observed cancellation timing or OS
cleanup. The user did not see a cancellation message. The controller contains
a cancellation notice in the page-level notice area, which may be outside the
current viewport; notice visibility in that reported interaction remains a
usability limitation. Do not infer the exact terminal job state from the empty
results panel alone.

The user reported that Anaconda was absent from Windows Installed apps. A
Start-menu shortcut alone does not establish an installed runtime. This is not
a complete development-tool inventory: the prepared private guest inventory
and automated clean-system harness were not run. Therefore the VM follow-up
does not establish all clean-consumer acceptance checks. Full responsive,
keyboard and assistive-technology coverage is also not claimed. Intermittent
VM display/input stalls were observed without an established root cause.

The archive remains a preview with its documented platform, path, calendar,
model and security-policy limits. The original unsigned ZIP and checksum are
unchanged; no private VM files, provider data or academic artifacts are included.

## Primary redistribution/implementation references

- [Official CPython embedded distribution](https://docs.python.org/3.14/using/windows.html#the-embeddable-package) and [PSF/incorporated licenses](https://docs.python.org/3.14/license.html).
- [Visual Studio 2022 Distributable Code list](https://learn.microsoft.com/en-us/visualstudio/releases/2022/redistribution) and [application-local DLL guidance](https://learn.microsoft.com/en-us/cpp/windows/determining-which-dlls-to-redistribute?view=msvc-170). Redistribution is conditional on the builder's valid Visual Studio license; debug/nonredist folders are excluded.
- [Windows Job Objects and inherited child membership](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).
- [PowerShell execution policy behavior](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1).

## License and signing preparation: 2026-11-01

The repository now uses the [MIT License](../LICENSE) for project code and
original synthetic fixtures. New builds include that license and consistent
Windows product/version resources in the two project-owned EXEs. Upstream
component licenses and uploaded provider-data rights remain separate.
See the [Code signing policy](code-signing.md) for privacy, proposed roles and
activation requirements. SignPath acceptance and signing are still pending.
The previously published ab184ae preview ZIP is unchanged; it has not acquired
a signature or these newly added packaged files retroactively.

Local verification of the changed build passed on the developer Windows host:
verbatim project-license inclusion, both owned EXEs' product/version/original-name
resources, extracted-package startup and real serial/OpenMP CLI equality,
precise exports, rejection/recovery, cancellation, owned-process shutdown and
missing/modified-asset rejection. Retained CPU/OpenMP CTests passed 19/19.
The host PowerShell module path was sanitized for these test processes only;
the unrelated already-running preview was stopped through its normal stop request.
This is not a new clean-VM, browser-visual or signed-package validation.
