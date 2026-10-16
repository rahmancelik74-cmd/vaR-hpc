$ErrorActionPreference='Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/cpu-benchmark-common.ps1')
$runs=@()
foreach($config in @(@('serial',0,@(2.0,6.0)),@('openmp',1,@(6.0,10.0)),@('openmp',2,@(1.0,3.0)))) {
    foreach($time in $config[2]) {
        $runs += [pscustomobject]@{configuration_id=($config[0]+$config[1]);phase='measured'
            result=[pscustomobject]@{backend=$config[0];requested_threads=$config[1];threads_used=[Math]::Max(1,$config[1]);scenarios=100;end_to_end_ms=$time;estimates=@(1,2)}}
    }
    $runs += [pscustomobject]@{configuration_id=($config[0]+$config[1]);phase='warmup'
        result=[pscustomobject]@{end_to_end_ms=999999}}
}
$summary=@(Get-CpuSummary $runs)
$two=@($summary | Where-Object {$_.requested_threads -eq 2})[0]
$serial=@($summary | Where-Object {$_.backend -eq 'serial'})[0]
if($summary.Count -ne 3 -or $two.measured_repetitions -ne 2 -or $two.mean_ms -ne 2 -or
    [Math]::Abs($two.sample_stddev_ms-[Math]::Sqrt(2)) -gt 1e-12 -or
    $two.scenarios_per_second -ne 50000 -or $two.speedup_vs_fresh_serial -ne 2 -or
    $two.scaling_vs_openmp_one_thread -ne 4 -or $serial.mean_ms -ne 4) {throw 'Recorder summary regression'}
# Slow measurements must remain, and a missing fresh reference must fail.
if($serial.sample_stddev_ms -lt 2.8){throw 'Slow sample filtered'}
$rejected=$false
try {Get-CpuSummary @($runs | Where-Object {$_.configuration_id -ne 'serial0'}) | Out-Null}
catch {$rejected=$true}
if(-not $rejected){throw 'Missing serial reference accepted'}
Write-Output 'CPU recorder statistics tests passed.'
