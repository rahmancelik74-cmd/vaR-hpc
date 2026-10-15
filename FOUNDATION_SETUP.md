# Foundation update

Date: 2026-10-15. Compatible source baseline: mc_var 0.2.1.
This package adds project records and evidence. It contains no replacement
application code, build cache, executables or automatic Git initialization.

## Apply to the existing project

Extract this package to a temporary folder. Copy docs, evidence and this file
into the existing source root containing CMakeLists.txt. Keep the existing src,
include, tests, data and build folders. These new document names are distinct
from the earlier requirements/environment drafts. If a destination file already
exists because this update was applied earlier, compare rather than overwrite
local edits blindly.

Read docs/architecture.md for current and planned components,
docs/project-state.md for evidence, docs/milestones.md for the plan and
docs/acceptance-source.md for sourced but not yet approval-confirmed thresholds.

## Check the local source folder

Run in Developer PowerShell from the actual source root:

```powershell
Get-Location
Test-Path .\CMakeLists.txt
.\build\Release\mc_var.exe --version
git --version
git rev-parse --show-toplevel
```

Expected application version: mc_var 0.2.1 (CSV support enabled).
If the active build folder has a different name, use that verified executable
path; do not reconfigure merely to rename a working build folder.

git rev-parse is read-only. It may report that there is no repository, or reveal
an existing parent repository. Share that result before initializing anything.
Do not create a nested repository or stage unrelated parent-folder content.
Do not publish a remote or change global Git identity automatically.

Next step after the check: establish the one correct repository and its first
reviewed baseline commit, preserving all local work. Remote hosting and CI are
separate steps; a workflow file alone is not evidence of successful CI.

## Evidence

evidence/serial_validation.csv transcribes the student's pasted results.
The same per-run time appears on both confidence-level rows; do not sum those
times as if each row were a separate run. Results are validation data, not an
official performance campaign. No C++ computation was changed in this update.
