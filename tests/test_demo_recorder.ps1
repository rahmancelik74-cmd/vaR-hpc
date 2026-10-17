param([Parameter(Mandatory=$true)][string]$Executable,[string]$OpenMPEnabled='ON')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runner=Join-Path $root 'scripts/run-experiment.ps1'
function Record-Smoke([string]$Backend,[int]$Threads=0) {
    $arguments=@{Mode='smoke';Executable=$Executable;Backend=$Backend}
    if($Threads -gt 0){$arguments.Threads=$Threads}
    $capture=(& $runner @arguments 6>&1 | Out-String -Width 4096)
    if($capture -notmatch 'Results directory: ([^\r\n]+)'){throw 'Missing recorder output location'}
    $folder=$Matches[1].Trim()
    $manifest=Get-Content -LiteralPath (Join-Path $folder 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $records=@(Get-Content -LiteralPath (Join-Path $folder 'runs.jsonl') -Encoding UTF8 | ForEach-Object {$_ | ConvertFrom-Json})
    $csv=@(Import-Csv -LiteralPath (Join-Path $folder 'estimates.csv'))
    if($manifest.status -cne 'completed' -or $manifest.mode -cne 'smoke' -or $manifest.backend -cne $Backend -or
       $manifest.benchmark_campaign_completed -or $manifest.supervisor_acceptance_evaluated -or
       $records.Count -ne 1 -or $csv.Count -ne 2 -or $manifest.warmups -ne 0 -or $manifest.measured_repetitions -ne 1) {
        throw 'Smoke classification or record count mismatch'
    }
    $run=$records[0].result
    if($run.backend -cne $Backend -or $run.scenarios -ne 10000 -or $run.seed -cne '42' -or
       [Math]::Abs($run.model.initial_value-100.4) -gt 1e-12 -or $run.calibration.horizon_trading_days -ne 10 -or
       $run.calibration.trading_days_per_year -ne 252){throw 'Synthetic smoke parameters changed'}
    for($i=0;$i -lt 2;$i++) {
        if($csv[$i].backend -cne $Backend -or [double]$csv[$i].mc_var -ne [double]$run.estimates[$i].mc_var -or
           [double]$csv[$i].analytical_var -ne [double]$run.estimates[$i].analytical_var -or
           [double]$csv[$i].end_to_end_ms -ne [double]$run.end_to_end_ms){throw 'CSV and JSON recorder outputs disagree'}
    }
    if($manifest.input_sha256 -cne (Get-FileHash -LiteralPath $manifest.input_path -Algorithm SHA256).Hash.ToLowerInvariant() -or
       $manifest.executable_sha256 -cne (Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash.ToLowerInvariant()) {
        throw 'Recorder artifact hashes disagree'
    }
    return $run
}
$serial=Record-Smoke 'serial'
if($OpenMPEnabled -ceq 'ON') {
    $one=Record-Smoke 'openmp' 1
    $four=Record-Smoke 'openmp' 4
    if($one.requested_threads -ne 1 -or $four.requested_threads -ne 4 -or $four.threads_used -lt 1 -or $four.threads_used -gt 4) {
        throw 'OpenMP team recording failed'
    }
    for($i=0;$i -lt 2;$i++) {
        if($one.estimates[$i].mc_var -ne $four.estimates[$i].mc_var -or
           $one.estimates[$i].analytical_var -ne $serial.estimates[$i].analytical_var) {
            throw 'Thread-invariant native estimates or shared analytical reference changed'
        }
    }
} else {
    $caught=$false
    try{Record-Smoke 'openmp' 4 | Out-Null}catch {
        if($_.Exception.Message -notmatch 'Application failed|OpenMP backend unavailable'){throw};$caught=$true
    }
    if(-not $caught){throw 'Unavailable OpenMP silently succeeded'}
}
foreach($mode in @('validation','benchmark')) {
    $caught=$false
    try{& $runner -Mode $mode -Executable $Executable -Backend openmp | Out-Null}catch {
        if($_.Exception.Message -notmatch 'smoke-only'){throw};$caught=$true
    }
    if(-not $caught){throw 'OpenMP campaign unexpectedly enabled'}
}
$caught=$false
try{& $runner -Mode smoke -Executable $Executable -Backend serial -Threads 4 | Out-Null}catch {
    if($_.Exception.Message -notmatch 'Threads requires'){throw};$caught=$true
}
if(-not $caught){throw 'Serial thread argument silently ignored'}
Write-Output 'Synthetic demo recorder checks passed; timing is smoke-only and acceptance is not evaluated.'
