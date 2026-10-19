Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'gpu-acceptance-audit.ps1')
. (Join-Path $PSScriptRoot 'cpu-benchmark-common.ps1')

function New-BenchmarkPlan([string]$Mode) {
    if($Mode -cnotin @('smoke','diagnostic','formal')){throw 'Unknown benchmark mode'}
    $sizes=if($Mode -ceq 'formal'){@(100000,1000000,10000000)}else{@(100000)}
    $warmups=if($Mode -ceq 'formal'){3}elseif($Mode -ceq 'smoke'){1}else{0}
    $repetitions=if($Mode -ceq 'formal'){10}elseif($Mode -ceq 'smoke'){2}else{1}
    $configs=@()
    foreach($n in $sizes){
        foreach($name in @('serial','openmp-1','openmp-2','openmp-4','openmp-8','openmp-10','full-device','hybrid')){
            $backend=if($name -ceq 'serial'){'serial'}elseif($name.StartsWith('openmp-')){'openmp'}else{'cuda'}
            if($Mode -ceq 'diagnostic' -and $backend -cne 'cuda'){continue}
            $threads=if($backend -ceq 'openmp'){[int]$name.Substring(7)}else{0}
            $batch=if($name -ceq 'hybrid'){65535}else{0}
            $effective=if($name -ceq 'hybrid'){[Math]::Min($n,65536)}elseif($backend -ceq 'cuda'){$n}else{0}
            $configs+=[pscustomobject][ordered]@{id="$name-N$n";backend=$backend;cuda_mode=$(if($backend -ceq 'cuda'){$name}else{''});
                scenarios=$n;requested_threads=$threads;requested_batch_size=$batch;effective_batch_size=$effective}
        }
    }
    $order=@();$sequence=0
    $phases=if($Mode -ceq 'diagnostic'){@('baseline','diagnostic')}else{@('warmup','measured')}
    foreach($phase in $phases){
        $rounds=if($phase -ceq 'warmup'){$warmups}else{$repetitions}
        for($round=1;$round -le $rounds;$round++){
            $indices=@(0..($configs.Count-1));if($round%2 -eq 1){[array]::Reverse($indices)}
            for($offset=0;$offset -lt $indices.Count;$offset++){
                $index=$indices[($offset+5*($round-1))%$indices.Count];$sequence++
                $order+=[pscustomobject][ordered]@{sequence=$sequence;configuration_id=$configs[$index].id;phase=$phase;
                    repetition=$round;diagnostics=($phase -ceq 'diagnostic')}
            }
        }
    }
    [pscustomobject][ordered]@{schema_version=1;mode=$Mode;seed='42';confidence_levels=@(.95,.99);
        warmups_per_configuration=$warmups;measured_repetitions_per_configuration=$repetitions;
        configurations=$configs;execution_order=$order;planned_processes=$order.Count;
        ordering='Reverse odd rounds; cyclic shift by 5 positions per round; all warm-ups first; serial processes';
        inter_run_delay_ms=100;formal_campaign=($Mode -ceq 'formal')}
}
function Get-BenchmarkArguments($Config,[bool]$Diagnostics,[string]$InputPath) {
    $values=@('--csv',$InputPath,[string]$Config.scenarios,'42','10','252','--backend',$Config.backend)
    if($Config.backend -ceq 'openmp'){$values+=@('--threads',[string]$Config.requested_threads)}
    if($Config.backend -ceq 'cuda'){
        $values+=@('--cuda-mode',$Config.cuda_mode)
        if($Config.cuda_mode -ceq 'hybrid'){$values+=@('--batch-size',[string]$Config.requested_batch_size)}
        if($Diagnostics){$values+='--cuda-diagnostics'}
    }
    $values+='--json';return $values
}
function Get-BenchmarkSourceSnapshot {
    $paths=@(& git ls-files --cached --others --exclude-standard)
    if($LASTEXITCODE -ne 0){throw 'Cannot enumerate source'}
    foreach($p in ($paths | Sort-Object -Unique)){
        if($p -ceq 'AGENTS.md' -or $p.StartsWith('output/')){continue}
        if(-not (Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing source: $p"}
        [pscustomobject]@{path=$p;sha256=(Get-GpuHash $p)}
    }
}
function Get-BenchmarkSummary($Runs) {
    # Welford, deliberately distinct from the independent audit's two-pass sums.
    $rows=@()
    foreach($group in @($Runs | Where-Object {$_.phase -ceq 'measured'} | Group-Object configuration_id)){
        $count=0;$mean=0.0;$m2=0.0
        foreach($r in $group.Group){$x=Assert-GpuFinite $r.result.end_to_end_ms 'time';if($x -le 0){throw 'Nonpositive time'}
            $count++;$delta=$x-$mean;$mean+=$delta/$count;$m2+=$delta*($x-$mean)}
        if($count -lt 2){throw 'Insufficient measured repetitions'}
        $r=$group.Group[0].result
        $rows+=[pscustomobject][ordered]@{configuration_id=$group.Name;backend=$r.backend;scenarios=$r.scenarios;
            requested_threads=$r.requested_threads;cuda_mode=$(if($r.cuda){$r.cuda.mode}else{''});sample_count=$count;
            mean_ms=$mean;sample_stddev_ms=[Math]::Sqrt($m2/($count-1));scenarios_per_second=1000.0*$r.scenarios/$mean;
            best_openmp_threads=0;speedup_vs_serial=0.0;speedup_vs_best_openmp=0.0;serial_target_10x=$null}
    }
    foreach($row in $rows){
        $serial=@($rows | Where-Object {$_.scenarios -eq $row.scenarios -and $_.backend -ceq 'serial'})
        $best=@($rows | Where-Object {$_.scenarios -eq $row.scenarios -and $_.backend -ceq 'openmp'} |
            Sort-Object mean_ms,requested_threads)[0]
        if($serial.Count -ne 1){throw 'Missing fresh serial reference'}
        $row.best_openmp_threads=$best.requested_threads
        $row.speedup_vs_serial=$serial[0].mean_ms/$row.mean_ms
        $row.speedup_vs_best_openmp=$best.mean_ms/$row.mean_ms
        if($row.backend -ceq 'cuda' -and $row.scenarios -eq 10000000){$row.serial_target_10x=($row.speedup_vs_serial -ge 10)}
    }
    return $rows
}
function Write-BenchmarkSummaryCsv($Path,$Rows) {
    $culture=[Globalization.CultureInfo]::InvariantCulture
    @($Rows | ForEach-Object {
        $record=[ordered]@{}
        foreach($p in $_.PSObject.Properties){
            $record[$p.Name]=if($p.Value -is [double]){$p.Value.ToString('R',$culture)}else{$p.Value}
        }
        [pscustomobject]$record
    }) | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}
function Test-BandwidthDiscovery($Process,[string]$Text) {
    # Metric discovery can exit zero despite a fatal counter permission error.
    if($Text -match 'ERR_NVGPUCTRPERM'){return 'counter-permission-denied'}
    if($Process.start_error -or $Process.timed_out -or $Process.exit_code -ne 0 -or
        $Text -match '(?i)==ERROR==|fatal|unsupported|failed'){return 'tool-error'}
    if($Text -notmatch 'dram__bytes_read.sum' -or $Text -notmatch 'gpu__time_duration.sum'){return 'metrics-unverified'}
    return 'discovery-only-no-profile'
}
function Test-BenchmarkRecords($Manifest,$Plan,$Runs,$Fixture) {
    if($Manifest.status -cne 'completed' -or $Manifest.schema_version -ne 1 -or
        ($Plan.mode -ceq 'formal' -and -not $Manifest.clean_source)){throw 'Incomplete/dirty formal campaign'}
    $canonical=New-BenchmarkPlan $Plan.mode
    if((ConvertTo-Json $Plan -Depth 20 -Compress) -cne (ConvertTo-Json $canonical -Depth 20 -Compress)){throw 'Changed plan'}
    if(@($Runs).Count -ne $Plan.planned_processes){throw 'Missing/extra attempts'}
    $seen=@{};$lastFinish=[DateTime]::MinValue;$native=@{}
    for($i=0;$i -lt $Runs.Count;$i++){
        $r=$Runs[$i];$step=$Plan.execution_order[$i]
        foreach($field in @('sequence','configuration_id','phase','repetition','diagnostics')){
            if($r.$field -cne $step.$field){throw "Changed execution order: $field"}
        }
        $key=$r.configuration_id+'-'+$r.phase+'-'+$r.repetition
        if($seen.ContainsKey($key)){throw 'Duplicate attempt'};$seen[$key]=$true
        foreach($field in @('input_sha256','executable_sha256','source_revision','source_snapshot_sha256','build_cache_sha256')){
            if($r.$field -cne $Manifest.$field){throw "Changed provenance: $field"}
        }
        if($r.error -or $null -eq $r.result -or [DateTime]$r.started_utc -lt $lastFinish -or
            [DateTime]$r.finished_utc -lt [DateTime]$r.started_utc){throw 'Failed attempt or invalid timestamps'}
        $lastFinish=[DateTime]$r.finished_utc
        $o=$r.observation
        if($o.timed_out -or $o.owned_job_terminated -or $o.exit_code -ne 0 -or $o.stderr -cne '' -or
            $o.process_mask_hex -cne $Manifest.process_mask_hex -or $o.priority_class -ne 32){throw 'Process contract failed'}
        foreach($s in @($o.before,$o.after)){
            if($s.ac_line_status -ne $Manifest.power_reference.ac_line_status -or
                $s.battery_saver -ne $Manifest.power_reference.battery_saver -or
                $s.active_power_scheme -cne $Manifest.power_reference.active_power_scheme){throw 'Power conditions changed'}
            if($Plan.mode -ceq 'formal' -and $s.ac_line_status -ne 1){throw 'Formal campaign requires AC'}
        }
        $v=$r.result;$raw=$o.stdout | ConvertFrom-Json
        if((ConvertTo-Json $raw -Depth 20 -Compress) -cne (ConvertTo-Json $v -Depth 20 -Compress)){throw 'Raw/result mismatch'}
        $c=@($Plan.configurations | Where-Object {$_.id -ceq $r.configuration_id})[0]
        $expectedArgs=@(Get-BenchmarkArguments $c $step.diagnostics $Manifest.input_path)
        if((@($r.arguments) -join "`n") -cne ($expectedArgs -join "`n")){throw 'Wrong invocation'}
        $expectedThreads=if($c.backend -ceq 'openmp'){$c.requested_threads}else{1}
        if($v.schema_version -ne 1 -or $v.application_version -cne '0.3.0' -or $v.scenarios -ne $c.scenarios -or
            $v.backend -cne $c.backend -or $v.requested_threads -ne $c.requested_threads -or $v.threads_used -ne $expectedThreads -or
            $v.seed -isnot [string] -or $v.seed -cne '42' -or $v.input_mode -cne 'csv_calibration'){throw 'Wrong run configuration'}
        $time=Assert-GpuFinite $v.end_to_end_ms 'host time';if($time -le 0){throw 'Nonpositive time'}
        $rng=if($c.backend -ceq 'serial'){'mt19937_64/std::normal_distribution'}elseif($c.backend -ceq 'openmp'){
            'block4096/splitmix64/mt19937_64/std::normal_distribution'}else{'cuRAND/PHILOX4_32_10/normal-double'}
        if($v.random_source -cne $rng){throw 'Wrong native RNG'}
        foreach($f in @('initial_value','drift_annual','volatility_annual','horizon_years')){Assert-GpuClose $v.model.$f $Fixture.model.$f "model $f"}
        foreach($f in @('mean_log_return','sample_log_variance','observations','returns_count')){Assert-GpuClose $v.calibration.$f $Fixture.$f "calibration $f"}
        if($v.calibration.date_start -cne $Fixture.date_start -or $v.calibration.date_end -cne $Fixture.date_end -or
            $v.calibration.horizon_trading_days -ne 10 -or $v.calibration.trading_days_per_year -ne 252){throw 'Wrong calibration interval'}
        if(@($v.estimates).Count -ne 2){throw 'Wrong confidence count'}
        $values=@()
        for($j=0;$j -lt 2;$j++){
            $e=$v.estimates[$j];if((Assert-GpuFinite $e.confidence 'confidence') -ne [double]$Fixture.references[$j].confidence){throw 'Wrong confidence'}
            $values+=Assert-GpuFinite $e.mc_var 'VaR'
            Assert-GpuClose $e.analytical_var $Fixture.references[$j].analytical_var 'analytical reference'
        }
        $signature=($values | ForEach-Object {$_.ToString('R',[Globalization.CultureInfo]::InvariantCulture)}) -join ','
        if($native.ContainsKey($c.id) -and $native[$c.id] -cne $signature){throw 'Native estimates changed within configuration'}
        $native[$c.id]=$signature
        if($c.backend -ceq 'cuda'){
            $g=$v.cuda
            if($g.mode -cne $c.cuda_mode -or $g.requested_batch_size -ne $c.requested_batch_size -or
                $g.effective_batch_size -ne $c.effective_batch_size -or $g.cub_version -ne 300403 -or
                $v.random_source -cne 'cuRAND/PHILOX4_32_10/normal-double'){throw 'Wrong CUDA configuration'}
            $b=if($c.cuda_mode -ceq 'hybrid'){[int][Math]::Ceiling($c.scenarios/[double]$c.effective_batch_size)}else{1}
            if($g.batch_count -ne $b -or $g.normals_generated -ne $c.scenarios){throw 'Wrong batch/normal accounting'}
            $hasDiagnostics=$null -ne $g.PSObject.Properties['diagnostics']
            if($hasDiagnostics -ne $step.diagnostics){throw 'Wrong diagnostics status'}
            if($hasDiagnostics){
                $d=$g.diagnostics
                if($d.enabled -ne $true -or $d.schema_version -ne 1){throw 'Wrong diagnostic schema'}
                $sum=0.0
                foreach($f in @('initialization','rng','loss','cub','gather')){
                    $x=Assert-GpuFinite $d.($f+'_ms') $f;if($x -lt 0){throw 'Negative diagnostic time'};$sum+=$x
                    $expectedCount=if($f -in @('cub','gather')){if($c.cuda_mode -ceq 'full-device'){1}else{0}}else{$b}
                    if($d.($f+'_intervals') -ne $expectedCount){throw 'Wrong diagnostic interval count'}
                    if($expectedCount -eq 0 -and $x -ne 0){throw 'Time reported for inapplicable stage'}
                }
                Assert-GpuClose $d.covered_device_stage_sum_ms $sum 'stage sum'
                foreach($f in @('pipeline_span_ms','host_quantile_ms')){if((Assert-GpuFinite $d.$f $f) -lt 0){throw 'Negative diagnostic time'}}
                if($d.pipeline_span_ms+1e-5 -lt $sum -or ($c.cuda_mode -ceq 'full-device' -and $d.host_quantile_ms -ne 0)){throw 'Invalid diagnostic scope'}
            }
            foreach($f in @('host_to_device_ms','device_to_host_ms')){if((Assert-GpuFinite $g.$f $f) -lt 0){throw 'Negative copy time'}}
            $hybrid=$c.cuda_mode -ceq 'hybrid'
            $expectedD2H=if($hybrid){8*$c.scenarios+4*$b}else{20}
            $expectedH2D=if($hybrid){0}else{16}
            if($g.host_sorting_used -ne $hybrid -or $g.quantile_location -cne $(if($hybrid){'host'}else{'device'}) -or
                $g.host_to_device_bytes -ne $expectedH2D -or $g.device_to_host_bytes -ne $expectedD2H){throw 'Wrong transfer/quantile metadata'}
        } elseif($null -ne $v.cuda){throw 'CPU run contains CUDA metadata'}
    }
}
function Test-BenchmarkSummary($Plan,$Runs,$Rows) {
    if(@($Rows).Count -ne $Plan.configurations.Count){throw 'Wrong summary count'}
    $means=@{};$stds=@{}
    foreach($c in $Plan.configurations){
        $samples=@($Runs | Where-Object {$_.configuration_id -ceq $c.id -and $_.phase -ceq 'measured'})
        if($samples.Count -ne $Plan.measured_repetitions_per_configuration){throw 'Wrong measured count'}
        $sum=0.0;foreach($r in $samples){$sum+=[double]$r.result.end_to_end_ms};$mean=$sum/$samples.Count
        $ss=0.0;foreach($r in $samples){$ss+=([double]$r.result.end_to_end_ms-$mean)*([double]$r.result.end_to_end_ms-$mean)}
        $means[$c.id]=$mean;$stds[$c.id]=[Math]::Sqrt($ss/($samples.Count-1))
    }
    $seen=@{}
    foreach($row in $Rows){
        if($seen.ContainsKey($row.configuration_id) -or -not $means.ContainsKey($row.configuration_id)){throw 'Duplicate/unknown summary'};$seen[$row.configuration_id]=$true
        $c=@($Plan.configurations | Where-Object {$_.id -ceq $row.configuration_id})[0]
        $best=$null
        foreach($candidate in $Plan.configurations){
            if($candidate.scenarios -ne $c.scenarios -or $candidate.backend -cne 'openmp'){continue}
            if($null -eq $best -or $means[$candidate.id] -lt $means[$best.id] -or
                ($means[$candidate.id] -eq $means[$best.id] -and $candidate.requested_threads -lt $best.requested_threads)){$best=$candidate}
        }
        $mean=$means[$c.id];$speed=$means['serial-N'+$c.scenarios]/$mean
        if($row.backend -cne $c.backend -or $row.scenarios -ne $c.scenarios -or $row.requested_threads -ne $c.requested_threads -or
            $row.cuda_mode -cne $c.cuda_mode -or $row.sample_count -ne $Plan.measured_repetitions_per_configuration -or
            $row.best_openmp_threads -ne $best.requested_threads){throw 'Wrong summary configuration/baseline'}
        Assert-GpuClose $row.mean_ms $mean 'mean';Assert-GpuClose $row.sample_stddev_ms $stds[$c.id] 'sample stddev'
        Assert-GpuClose $row.scenarios_per_second (1000.0*$c.scenarios/$mean) 'throughput'
        Assert-GpuClose $row.speedup_vs_serial $speed 'serial speedup'
        Assert-GpuClose $row.speedup_vs_best_openmp ($means[$best.id]/$mean) 'best OpenMP speedup'
        $target=if($c.backend -ceq 'cuda' -and $c.scenarios -eq 10000000){$speed -ge 10}else{$null}
        if($row.serial_target_10x -cne $target){throw 'Incorrect 10x verdict'}
    }
}
