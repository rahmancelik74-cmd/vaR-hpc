Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/convergence-analysis.ps1')
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/convergence-audit.ps1')
$root=Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    $fixture=Get-IndependentGpuFixture 'data/synthetic_prices.csv'
    $fixture.model.initial_value=100.0;$fixture.references[0].analytical_var=10.0;$fixture.references[1].analytical_var=0.0
    $runs=@();$index=0
    foreach($seed in @('42','123','456','789','2026')){
        $runs += [pscustomobject]@{key="serial/10000000/$seed";result=[pscustomobject]@{scenarios=10000000;estimates=@(
            [pscustomobject]@{confidence=.95;mc_var=(8.0+$index)},[pscustomobject]@{confidence=.99;mc_var=0.0})}};$index++
    }
    $actual=Get-RecordedConvergenceAnalysis $runs $fixture
    $expected=Get-IndependentConvergenceAnalysis $runs $fixture
    Test-ConvergenceAnalysis $actual $expected
    Assert-GpuClose $actual.groups[6].sample_stddev ([Math]::Sqrt(2.5)) 'known sample deviation'
    if($actual.groups[6].absolute_error_of_mean -ne 0 -or $actual.groups[6].descriptive_mae -ne 1.2 -or
        $null -ne $actual.groups[7].relative_error -or $actual.groups[7].error_over_v0 -ne 0 -or
        $actual.acceptance_10m[1].allowed_error -ne .01 -or -not $actual.acceptance_10m[0].passed -or $actual.complete){throw 'Incorrect known statistics'}
    $actual.acceptance_10m[0].absolute_error_of_mean=1.2
    $rejected=$false;try{Test-ConvergenceAnalysis $actual $expected}catch{$rejected=$true}
    if(-not $rejected){throw 'Acceptance formula substitution was accepted'}
    Write-Host 'Portable convergence statistics passed: independent math, cancellation, sample variance, near-zero normalization, incomplete coverage and acceptance substitution'
}finally{Pop-Location}
