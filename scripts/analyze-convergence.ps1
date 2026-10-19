[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Directory)
. (Join-Path $PSScriptRoot 'convergence-analysis.ps1')
$root=Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    $dir=(Resolve-Path -LiteralPath $Directory).Path
    $d=Read-GpuJson (Join-Path $dir 'dataset.json');Assert-GpuBoundArtifact $d.plan_path $d.plan_sha256
    Test-ConvergenceDataset $d
    $p=Read-GpuJson $d.plan_path;Test-ConvergencePlan $p
    $fixture=Get-RecordedConvergenceFixture $p.fixture.path
    Test-ConvergenceRecords $p @($d.records) $fixture
    foreach($r in $d.records){if($r.origin -ceq 'new-native' -and $r.plan_sha256 -cne $d.plan_sha256){throw 'Mixed plan binding'}}
    Write-GpuJson (Join-Path $dir 'analysis.json') (Get-RecordedConvergenceAnalysis @($d.records) $fixture)
    Write-Host ('Analysis recorded: '+@($d.records).Count+'/80 runs')
}finally{Pop-Location}
