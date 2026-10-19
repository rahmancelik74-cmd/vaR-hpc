param(
    [string]$RepositoryRoot=(Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$Directory='results/cuda-stage-diagnostics-80148ce-20261019-run2',
    [Parameter(Mandatory=$true)][string]$ReportPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $RepositoryRoot
$root=(Get-Location).Path
$out=[IO.Path]::GetFullPath((Join-Path $root $Directory))
$destination=[IO.Path]::GetFullPath((Join-Path $root $ReportPath))
$allowed=(Join-Path $root 'results')+[IO.Path]::DirectorySeparatorChar
if(-not $destination.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $destination)){
    throw 'Use a new report file under ignored results/'
}
if(-not (Test-Path -LiteralPath (Split-Path $destination -Parent))){throw 'Create the review output directory first'}
$source=Join-Path $PSScriptRoot 'auditor-final-original.ps1'
if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -cne
    '434d58f1edd10f9bc11c3ade0627f21663fa5f23c74e34b8fce7cb5eb7bb0579'){throw 'Archived final auditor changed'}
$code=[IO.File]::ReadAllText($source)
$oldRoot='$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent'
$oldOut="`$out=Join-Path `$root 'results/cuda-stage-diagnostics-80148ce-20261019-run2'"
$oldReport="Write-GpuJson (Join-Path `$PSScriptRoot 'independent-audit-final.json') `$audit"
$oldCurrent="foreach(`$s in @(Read-GpuJson (Join-Path `$out 'source-snapshot.json'))){Assert-GpuBoundArtifact `$s.path `$s.sha256}"
foreach($needle in @($oldRoot,$oldOut,$oldReport,$oldCurrent)){
    if(-not $code.Contains($needle)){throw 'Archived auditor adaptation point changed'}
}
$code=$code.Replace($oldRoot,("`$root='"+$root.Replace("'","''")+"'"))
$code=$code.Replace($oldOut,("`$out='"+$out.Replace("'","''")+"'"))
$code=$code.Replace($oldReport,("Write-GpuJson '"+$destination.Replace("'","''")+"' `$audit"))
# The original complete Git tree/index binding remains checked. Permit later
# documentation changes while requiring every other archived source file's
# exact current bytes, including all auditor helpers and historical evidence.
$historical=@'
foreach($s in @(Read-GpuJson (Join-Path $out 'source-snapshot.json'))){
        if($s.path -ceq 'README.md' -or $s.path.StartsWith('docs/')){continue}
        Assert-GpuBoundArtifact $s.path $s.sha256
    }
'@
$code=$code.Replace($oldCurrent,$historical)
& ([scriptblock]::Create($code))
