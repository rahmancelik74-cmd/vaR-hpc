[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Directory,[switch]$VerifyLocalArtifacts)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'cpu-benchmark-common.ps1')
function Assert-Close([double]$Actual,[double]$Expected,[string]$Label) {
    if([double]::IsNaN($Actual) -or [double]::IsInfinity($Actual) -or
        [Math]::Abs($Actual-$Expected) -gt 1e-11*[Math]::Max(1,[Math]::Abs($Expected))) {throw "Independent check failed: $Label"}
}
$dir=(Resolve-Path -LiteralPath $Directory).Path
$manifest=Get-Content -Raw -Encoding UTF8 (Join-Path $dir 'manifest.json') | ConvertFrom-Json
if($manifest.status -ne 'completed' -or -not $manifest.clean_source){throw 'Incomplete or dirty-source campaign'}
$runs=@(Get-Content -Encoding UTF8 (Join-Path $dir 'runs.jsonl') | ForEach-Object {$_ | ConvertFrom-Json})
$observations=@(Get-Content -Encoding UTF8 (Join-Path $dir 'process-observations.jsonl') | ForEach-Object {$_ | ConvertFrom-Json})
$summary=Get-Content -Raw -Encoding UTF8 (Join-Path $dir 'summary.json') | ConvertFrom-Json
$csv=@(Import-Csv -LiteralPath (Join-Path $dir 'summary.csv'))
$expectedCount=$manifest.configurations.Count*($manifest.warmups_per_configuration+$manifest.measured_repetitions_per_configuration)
if($runs.Count -ne $expectedCount -or $observations.Count -ne $runs.Count -or
    $summary.Count -ne $manifest.configurations.Count -or $csv.Count -ne $summary.Count){throw 'Campaign row counts differ'}
$seen=@{}; $measuredStarted=$false; $lastFinished=[DateTime]::MinValue
for($i=0;$i -lt $runs.Count;++$i){
    $record=$runs[$i]; $r=$record.result; $obs=$observations[$i]
    $key=$record.configuration_id+'-'+$record.phase+'-'+$record.repetition
    if($seen.ContainsKey($key) -or $record.sequence -ne $i+1){throw 'Duplicate run or incorrect execution order'}
    $seen[$key]=$true
    if($record.phase -eq 'measured'){$measuredStarted=$true}
    elseif($record.phase -ne 'warmup' -or $measuredStarted){throw 'Warm-up phase ordering failed'}
    if([DateTime]$record.started_utc -lt $lastFinished -or [DateTime]$record.finished_utc -lt [DateTime]$record.started_utc){throw 'Overlapping or reversed process timestamps'}
    $lastFinished=[DateTime]$record.finished_utc
    if($obs.exit_code -ne 0 -or $obs.stderr -ne '' -or $obs.priority_class -ne 32 -or
        $obs.process_mask_hex -cne $manifest.process_mask_hex){throw 'Process contract failed'}
    $rawResult=$obs.stdout | ConvertFrom-Json
    Assert-Close ([double]$r.end_to_end_ms) ([double]$rawResult.end_to_end_ms) 'raw process timing'
    if($r.seed -isnot [string] -or $r.seed -cne '42' -or @($r.estimates).Count -ne 2 -or
        [double]$r.estimates[0].confidence -ne .95 -or [double]$r.estimates[1].confidence -ne .99){throw 'Wrong seed or confidences'}
    foreach($snapshot in @($obs.before,$obs.after)){
        if($manifest.mode -eq 'benchmark' -and ($snapshot.ac_line_status -ne 1 -or
            $snapshot.active_power_scheme -cne $observations[0].before.active_power_scheme -or
            $snapshot.battery_saver -ne $observations[0].before.battery_saver)){throw 'Inconsistent power conditions'}
    }
}
$recomputed=@{}
foreach($config in $manifest.configurations){
    $all=@($runs | Where-Object {$_.configuration_id -eq $config.id})
    $samples=@($all | Where-Object {$_.phase -eq 'measured'})
    if($samples.Count -ne $manifest.measured_repetitions_per_configuration -or
        @($all | Where-Object {$_.phase -eq 'warmup'}).Count -ne $manifest.warmups_per_configuration){throw 'Incorrect repetition count'}
    $sum=0.0
    foreach($sample in $samples){$sum += [double]$sample.result.end_to_end_ms}
    $mean=$sum/$samples.Count; $squared=0.0
    foreach($sample in $samples){$difference=[double]$sample.result.end_to_end_ms-$mean;$squared += $difference*$difference}
    $std=[Math]::Sqrt($squared/($samples.Count-1))
    $expectedThreads=if($config.backend -eq 'serial'){1}else{$config.requested_threads}
    foreach($record in $all){
        $r=$record.result
        if($r.scenarios -ne $config.scenarios -or $r.backend -ne $config.backend -or
            $r.requested_threads -ne $config.requested_threads -or $r.threads_used -ne $expectedThreads){throw 'Configuration metadata failed'}
        for($j=0;$j -lt 2;++$j){
            if($r.estimates[$j].mc_var -ne $all[0].result.estimates[$j].mc_var){throw 'Repeated native estimates changed'}
        }
    }
    $row=@($summary | Where-Object {$_.configuration_id -eq $config.id})
    if($row.Count -ne 1 -or $row[0].measured_repetitions -ne $samples.Count){throw 'Missing summary row'}
    Assert-Close ([double]$row[0].mean_ms) $mean 'mean'
    Assert-Close ([double]$row[0].sample_stddev_ms) $std 'sample standard deviation'
    Assert-Close ([double]$row[0].scenarios_per_second) (1000.0*$config.scenarios/$mean) 'throughput'
    $recomputed[$config.id]=[pscustomobject]@{mean=$mean;row=$row[0];scenarios=$config.scenarios;threads=$config.requested_threads;backend=$config.backend}
}
foreach($entry in $recomputed.Values){
    $serial=$recomputed['serial-0-N'+$entry.scenarios]
    $one=$recomputed['openmp-1-N'+$entry.scenarios]
    Assert-Close ([double]$entry.row.speedup_vs_fresh_serial) ($serial.mean/$entry.mean) 'fresh serial speedup'
    if($entry.backend -eq 'openmp'){
        Assert-Close ([double]$entry.row.scaling_vs_openmp_one_thread) ($one.mean/$entry.mean) 'one-thread OpenMP scaling'
    }
    $csvRow=@($csv | Where-Object {$_.configuration_id -eq $entry.row.configuration_id})
    if($csvRow.Count -ne 1){throw 'Missing CSV summary'}
    foreach($field in @('mean_ms','sample_stddev_ms','scenarios_per_second','speedup_vs_fresh_serial')){
        Assert-Close ([double]::Parse($csvRow[0].$field,[Globalization.CultureInfo]::InvariantCulture)) ([double]$entry.row.$field) 'CSV/JSON summary'
    }
}
if($VerifyLocalArtifacts){
    $root=Split-Path -Parent $PSScriptRoot
    if((Get-CpuHash (Join-Path $root $manifest.executable)) -ne $manifest.executable_sha256 -or
        (Get-CpuHash (Join-Path $root $manifest.input)) -ne $manifest.input_sha256 -or
        (Get-CpuHash (Join-Path $root 'build-cpu-scaling/Release/mc_cpu_probe.exe')) -ne $manifest.probe_sha256){throw 'Local artifact hash mismatch'}
}
$audit=[ordered]@{
    status='passed';source_revision=$manifest.source_revision;mode=$manifest.mode
    total_runs=$runs.Count;measured_runs=@($runs | Where-Object {$_.phase -eq 'measured'}).Count
    warmup_runs=@($runs | Where-Object {$_.phase -eq 'warmup'}).Count;summary_rows=$summary.Count
    independent_method='Explicit sum and two-pass sample variance; recorder uses Welford'
    one_record_per_process=$true;duplicate_run_check='passed';power_consistency='passed for available fields'
    actual_thread_counts='Every run matches its requested OpenMP team; serial uses one'
    native_repeatability='passed per configuration';csv_json_agreement='passed';slow_samples_filtered=0
    local_input_executable_probe_hashes_checked=[bool]$VerifyLocalArtifacts
}
Write-CpuJson (Join-Path $dir 'independent-audit.json') $audit
Write-Output "Independent CPU benchmark audit passed: $($runs.Count) processes, $($summary.Count) summary rows."
