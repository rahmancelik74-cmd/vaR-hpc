[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Directory)
. (Join-Path $PSScriptRoot 'convergence-audit.ps1')
$root=Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    $dir=(Resolve-Path -LiteralPath $Directory).Path
    $audit=[ordered]@{schema_version=1;status='failed';complete=$false;errors=@();new_simulation_claimed=$false}
    try {
        $datasetPath=Join-Path $dir 'dataset.json';$analysisPath=Join-Path $dir 'analysis.json'
        $d=Read-GpuJson $datasetPath;Assert-GpuBoundArtifact $d.plan_path $d.plan_sha256
        Test-ConvergenceDataset $d
        $p=Read-GpuJson $d.plan_path;Test-ConvergencePlan $p
        $fixture=Get-IndependentGpuFixture $p.fixture.path
        Test-ConvergenceRecords $p @($d.records) $fixture
        Test-ConvergenceAttemptInventory $dir @($d.records)
        foreach($r in $d.records){if($r.origin -ceq 'new-native' -and $r.plan_sha256 -cne $d.plan_sha256){throw 'Mixed plan binding'}}
        $expected=Get-IndependentConvergenceAnalysis @($d.records) $fixture
        Test-ConvergenceAnalysis (Read-GpuJson $analysisPath) $expected
        $audit.status='passed';$audit.complete=$expected.complete
        $audit['run_count']=$expected.run_count;$audit['value_count']=$expected.value_count;$audit['missing_processes']=$expected.missing.Count
        $audit['plan_sha256']=$d.plan_sha256;$audit['dataset_sha256']=Get-GpuHash $datasetPath;$audit['analysis_sha256']=Get-GpuHash $analysisPath
        $audit['recorded_path_relocations']=@(Get-ConvergenceRelocations)
        $audit['statistics']='Independent fixture calibration, analytical reference, per-seed errors, explicit sums, two-pass seed variance and exact 10M acceptance'
        $audit['limitations']=@($p.origins | ForEach-Object {$_.limitation})
        $audit.new_simulation_claimed=(@($d.records|Where-Object {$_.origin -ceq 'new-native'}).Count -gt 0)
    }catch{$audit.errors+= $_.Exception.Message}
    Write-GpuJson (Join-Path $dir 'independent-audit.json') $audit
    if($audit.status -cne 'passed'){throw ('Convergence audit failed: '+($audit.errors -join '; '))}
    Write-Host ("Independent convergence audit passed: $($audit.run_count)/80 runs; complete=$($audit.complete)")
}finally{Pop-Location}
