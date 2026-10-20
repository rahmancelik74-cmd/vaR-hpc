# Read-only checkpoint validation; no diagnostic or engine is launched.
param([switch]$IncludeLocal, [switch]$CheckCurrentDocuments)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$groups = @('selected_files', 'parents')
if ($IncludeLocal) { $groups += 'local_files' }
if ($CheckCurrentDocuments) { $groups += 'current_documents' }
$count = 0
foreach ($group in $groups) {
    foreach ($entry in $manifest.$group) {
        $path = Join-Path $root $entry.path
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne $entry.sha256) { throw "Changed checkpoint artifact: $($entry.path)" }
        $count++
    }
}
# Later current documents may advance; their optional check is distinct from
# immutable evidence validation. Never rewrite this manifest to accept changes.
$diagnostic = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'counter-discovery.stdout.txt') -Raw
if ($diagnostic -notmatch 'ERR_NVGPUCTRPERM') { throw 'Missing recorded permission denial' }
if ($null -ne $manifest.measured_dram_GBps -or $null -ne $manifest.documented_peak_GBps -or $null -ne $manifest.percent_of_documented_peak) {
    throw 'Blocked checkpoint must not claim bandwidth values'
}
[pscustomobject]@{status='passed';exact_byte_bindings=$count;local_checked=[bool]$IncludeLocal;current_documents_checked=[bool]$CheckCurrentDocuments;counter_access='denied';new_engine_processes=0} | ConvertTo-Json
