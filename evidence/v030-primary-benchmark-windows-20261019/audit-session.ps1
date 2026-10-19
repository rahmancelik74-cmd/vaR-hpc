Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location -LiteralPath $root
. ./scripts/benchmark-common.ps1
$out=$PSScriptRoot;$dir=Join-Path $out 'campaign'
$report=[ordered]@{purpose='Supplemental independent session, telemetry and full CSV audit';status='failed';
    checked_utc=[DateTime]::UtcNow.ToString('o');errors=@();bandwidth_measured=$false}
try {
    $session=Read-GpuJson (Join-Path $out 'session-status.json')
    $m=Read-GpuJson (Join-Path $dir 'manifest.json');$a=Read-GpuJson (Join-Path $dir 'independent-audit.json')
    if($session.status -cne 'completed' -or $m.status -cne 'completed' -or $a.status -cne 'passed' -or
        $session.campaign_invocations -ne 1 -or $session.automatic_retry){throw 'Session or campaign incomplete'}
    Assert-GpuBoundArtifact (Join-Path $dir 'manifest.json') $a.manifest_sha256
    foreach($r in $m.record_hashes){Assert-GpuBoundArtifact (Join-Path $dir $r.file) $r.sha256}
    foreach($r in $m.artifacts){Assert-GpuBoundArtifact $r.path $r.sha256}
    $plan=Read-GpuJson (Join-Path $dir 'plan.json')
    $runs=@(Get-Content (Join-Path $dir 'runs.jsonl') -Encoding UTF8 | ForEach-Object {$_ | ConvertFrom-Json})
    $summary=@(Read-GpuJson (Join-Path $dir 'summary.json'));$csv=@(Import-Csv (Join-Path $dir 'summary.csv'))
    Test-BenchmarkRecords $m $plan $runs (Get-IndependentGpuFixture (Join-Path $dir 'fixture.csv'))
    Test-BenchmarkSummary $plan $runs $summary
    if($runs.Count -ne 312 -or @($runs | Where-Object {$_.phase -ceq 'warmup'}).Count -ne 72 -or
        @($runs | Where-Object {$_.phase -ceq 'measured'}).Count -ne 240 -or $summary.Count -ne 24 -or $csv.Count -ne 24){throw 'Wrong complete matrix'}
    for($i=0;$i -lt $summary.Count;$i++){
        if((@($csv[$i].PSObject.Properties.Name) -join ',') -cne (@($summary[$i].PSObject.Properties.Name) -join ',')){throw 'CSV schema mismatch'}
        foreach($p in $summary[$i].PSObject.Properties){
            $text=$csv[$i].($p.Name)
            if($null -eq $p.Value){if($text -cne ''){throw 'CSV null mismatch'}}
            elseif($p.Value -is [bool]){if($text -cne $p.Value.ToString()){throw 'CSV boolean mismatch'}}
            elseif($p.Value -is [string]){if($text -cne $p.Value){throw 'CSV text mismatch'}}
            else{Assert-GpuClose ([double]::Parse($text,[Globalization.CultureInfo]::InvariantCulture)) $p.Value ('CSV '+$p.Name)}
        }
    }
    $decl=Read-GpuJson (Join-Path $out 'conditions.json');$copy=Read-GpuJson (Join-Path $dir 'user-conditions.json')
    if((ConvertTo-Json $decl -Depth 20 -Compress) -cne (ConvertTo-Json $copy -Depth 20 -Compress) -or
        $copy.record_type -cne 'USER_DECLARATIONS' -or $copy.ambient_temperature.value_c -ne 15 -or
        -not $copy.ambient_temperature.approximate -or $copy.ambient_temperature.instrument_measured -or
        $copy.vendor_performance_mode -cne 'unknown' -or $copy.vendor_fan_mode -cne 'unknown'){throw 'Declaration/telemetry separation failed'}
    $gpuRows=@();$windows=@()
    foreach($phase in @('pre','post')){
        $window=Read-GpuJson (Join-Path $out ($phase+'-observations.json'))
        $seconds=if($phase -ceq 'pre'){120}else{30};$count=1+$seconds/5
        if($window.requested_duration_seconds -ne $seconds -or $window.interval_seconds -ne 5 -or
            $window.observations.Count -ne $count -or $window.observations[-1].elapsed_ms -lt 1000*$seconds){throw 'Observation window incomplete'}
        $intervals=@()
        for($i=0;$i -lt $count;$i++){
            $r=$window.observations[$i]
            if($r.index -ne $i -or $r.scheduled_offset_seconds -ne 5*$i -or -not $r.power_stable){throw 'Observation order/power changed'}
            if($i -gt 0){$intervals+=([DateTime]$r.observed_utc-[DateTime]$window.observations[$i-1].observed_utc).TotalSeconds}
            $powerProcess=Read-GpuJson (Join-Path $out $r.power_process_record);Assert-GpuProcess $powerProcess
            $power=Read-GpuJson $powerProcess.stdout
            if($power.power.ac_line_status -ne 1 -or $power.power.battery_saver -ne $m.power_reference.battery_saver -or
                $power.power.active_power_scheme -cne $m.power_reference.active_power_scheme){throw 'Window/campaign power mismatch'}
            $gpuRows+=[pscustomobject]@{phase=$phase;process=(Read-GpuJson (Join-Path $out $r.gpu_process_record));declared_available=$r.gpu_available}
        }
        $windows+=[pscustomobject]@{phase=$phase;points=$count;requested_span_seconds=$seconds;
            actual_point_span_seconds=([DateTime]$window.observations[-1].observed_utc-[DateTime]$window.observations[0].observed_utc).TotalSeconds;
            minimum_actual_interval_seconds=($intervals | Measure-Object -Minimum).Minimum;
            maximum_actual_interval_seconds=($intervals | Measure-Object -Maximum).Maximum}
    }
    foreach($r in $runs){foreach($p in @($r.gpu_before,$r.gpu_after)){
        $gpuRows+=[pscustomobject]@{phase='campaign';process=(Read-GpuJson (Join-Path $dir $p.process_record));declared_available=$p.available}
    }}
    $gpuRows+=[pscustomobject]@{phase='campaign-initial';process=(Read-GpuJson (Join-Path $dir $m.gpu_before.process_record));declared_available=$m.gpu_before.available}
    $available=0;$unavailable=0;$names=@{};$drivers=@{};$temperatures=@();$unsupported=@{}
    foreach($r in $gpuRows){
        $p=$r.process;$valid=(-not $p.start_error -and -not $p.timed_out -and $p.exit_code -eq 0)
        if($r.declared_available -ne $valid){throw 'Telemetry availability mismatch'}
        if(-not $valid){$unavailable++;continue};$available++
        $values=@(Import-Csv -LiteralPath $p.stdout)
        if($values.Count -ne 1){throw 'Unexpected GPU telemetry count'}
        foreach($v in $values[0].PSObject.Properties){
            $name=$v.Name.Trim();$value=([string]$v.Value).Trim()
            if($value -in @('N/A','[N/A]','Not Supported','[Not Supported]')){
                if(-not $unsupported.ContainsKey($name)){$unsupported[$name]=0};$unsupported[$name]++
            }
            if($name -ceq 'name'){$names[$value]=$true}
            if($name -ceq 'driver_version'){$drivers[$value]=$true}
            if($name -ceq 'temperature.gpu' -and $value -match '^\d+(\.\d+)?$'){$temperatures+=[double]::Parse($value,[Globalization.CultureInfo]::InvariantCulture)}
        }
    }
    if($names.Count -ne 1 -or $drivers.Count -ne 1){throw 'GPU identity/driver changed or unavailable'}
    $pre=Read-GpuJson (Join-Path $out 'pre-observations.json');$post=Read-GpuJson (Join-Path $out 'post-observations.json')
    $report.status='passed';$report['source_revision']=$m.source_revision
    $report['campaign_manifest_sha256']=Get-GpuHash (Join-Path $dir 'manifest.json')
    $report['campaign_audit_sha256']=Get-GpuHash (Join-Path $dir 'independent-audit.json')
    $report['process_counts']=@{all=312;warmups_excluded=72;measured=240;summary_rows=24;filtered_or_replaced_samples=0}
    $report['observation_windows']=$windows
    $report['pre_window_end_to_first_attempt_seconds']=([DateTime]$runs[0].started_utc-[DateTime]$session.pre_observation_finished_utc).TotalSeconds
    $report['last_attempt_to_post_first_point_seconds']=([DateTime]$post.observations[0].observed_utc-[DateTime]$runs[-1].finished_utc).TotalSeconds
    $report['telemetry']=@{available_queries=$available;unavailable_queries=$unavailable;gpu_names=@($names.Keys);driver_versions=@($drivers.Keys);
        observed_gpu_temperature_min_c=($temperatures | Measure-Object -Minimum).Minimum;observed_gpu_temperature_max_c=($temperatures | Measure-Object -Maximum).Maximum;
        unsupported_field_counts=$unsupported;cpu_temperature='unmeasured';fan_mode='unknown';thermal_equilibrium='not-established';throttling_absence='not-established'}
    $report['conditions']='User declarations copied consistently; approximate ambient estimate and unknown modes preserved separately from telemetry'
    $report['csv']='Every numeric/text/boolean/null summary field cross-checked against JSON'
}catch{$report.errors+=$_.Exception.Message}
Write-GpuJson (Join-Path $out 'session-independent-audit.json') $report
if($report.status -cne 'passed'){throw ('Session independent audit failed: '+($report.errors -join '; '))}
Write-Host 'Supplemental independent session audit passed: 312 processes, full CSV, user declarations and observation/telemetry records.'
