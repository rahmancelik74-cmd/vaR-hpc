Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/benchmark-common.ps1')
$checks=0
function Clone($v){ConvertFrom-Json (ConvertTo-Json -InputObject $v -Depth 30)}
function Rejects($Label,[scriptblock]$Action){
    $rejected=$false;try{& $Action | Out-Null}catch{$rejected=$true}
    if(-not $rejected){throw "Corrupted record accepted: $Label"};$script:checks++
}
$formal=New-BenchmarkPlan 'formal'
if($formal.planned_processes -ne 312 -or @($formal.execution_order | Where-Object {$_.phase -ceq 'warmup'}).Count -ne 72 -or
    @($formal.execution_order | Where-Object {$_.phase -ceq 'measured'}).Count -ne 240 -or $formal.configurations.Count -ne 24){throw 'Formal matrix failed'};$checks++
foreach($mode in @('smoke','diagnostic','formal')){
    $p=New-BenchmarkPlan $mode;$again=New-BenchmarkPlan $mode
    if((ConvertTo-Json $p -Depth 20 -Compress) -cne (ConvertTo-Json $again -Depth 20 -Compress)){throw 'Nondeterministic plan'};$checks++
    $seen=@{}
    foreach($s in $p.execution_order){$k=$s.configuration_id+'-'+$s.phase+'-'+$s.repetition;if($seen.ContainsKey($k)){throw 'Duplicate planned sample'};$seen[$k]=$true}
    foreach($c in $p.configurations){
        foreach($phase in @($p.execution_order.phase | Sort-Object -Unique)){
            $count=@($p.execution_order | Where-Object {$_.configuration_id -ceq $c.id -and $_.phase -ceq $phase}).Count
            $expected=if($phase -ceq 'warmup'){$p.warmups_per_configuration}else{$p.measured_repetitions_per_configuration}
            if($count -ne $expected){throw 'Incomplete plan coverage'}
        }
    };$checks++
}
$plan=New-BenchmarkPlan 'smoke'
if(($plan.execution_order[0..7].configuration_id -join ',') -cne (($plan.configurations[7..0].id) -join ',')){throw 'Odd-round reversal failed'};$checks++
# The second measured round is forward, rotated by five.
if($plan.execution_order[16].configuration_id -cne $plan.configurations[5].id){throw 'Round rotation failed'};$checks++
$fixture=Get-IndependentGpuFixture (Join-Path (Split-Path -Parent $PSScriptRoot) 'data/synthetic_prices.csv')
$manifest=[pscustomobject]@{schema_version=1;status='completed';clean_source=$true;input_path='unit-fixture';source_revision='unit-source';
    input_sha256='unit-input';executable_sha256='unit-executable';source_snapshot_sha256='unit-snapshot';build_cache_sha256='unit-cache';
    process_mask_hex='ffff';power_reference=[pscustomobject]@{ac_line_status=1;battery_saver=0;active_power_scheme='unit-scheme'}}
function Samples($Plan){
    # Fabricated unit data only, never execution/profiling evidence.
    foreach($step in $Plan.execution_order){
        $c=@($Plan.configurations | Where-Object {$_.id -ceq $step.configuration_id})[0]
        $base=if($c.backend -ceq 'serial'){10}elseif($c.backend -ceq 'cuda'){if($c.cuda_mode -ceq 'full-device'){1}else{2}}else{
            switch($c.requested_threads){1{8}2{6}4{4}8{5}10{7}}
        }
        $time=if($step.phase -ceq 'warmup'){9999.0}else{[double]$base+2*($step.repetition-1)}
        $est=@(foreach($ref in $fixture.references){[pscustomobject]@{confidence=$ref.confidence;mc_var=$ref.analytical_var;analytical_var=$ref.analytical_var}})
        $cal=[pscustomobject]@{observations=$fixture.observations;returns_count=$fixture.returns_count;date_start=$fixture.date_start;date_end=$fixture.date_end;
            mean_log_return=$fixture.mean_log_return;sample_log_variance=$fixture.sample_log_variance;horizon_trading_days=10;trading_days_per_year=252}
        $gpu=$null
        if($c.backend -ceq 'cuda'){
            $hybrid=$c.cuda_mode -ceq 'hybrid';$b=if($hybrid){[int][Math]::Ceiling($c.scenarios/[double]$c.effective_batch_size)}else{1}
            $gpu=[pscustomobject]@{mode=$c.cuda_mode;requested_batch_size=$c.requested_batch_size;effective_batch_size=$c.effective_batch_size;
                batch_count=$b;normals_generated=$c.scenarios;cub_version=300403;host_sorting_used=$hybrid;quantile_location=$(if($hybrid){'host'}else{'device'});
                host_to_device_ms=0.0;device_to_host_ms=0.0;host_to_device_bytes=$(if($hybrid){0}else{16});device_to_host_bytes=$(if($hybrid){8*$c.scenarios+4*$b}else{20})}
            if($step.diagnostics){
                $gpu | Add-Member NoteProperty diagnostics ([pscustomobject]@{schema_version=1;enabled=$true;initialization_ms=.1;rng_ms=.2;loss_ms=.3;
                    cub_ms=$(if($hybrid){0.0}else{.1});gather_ms=$(if($hybrid){0.0}else{.1});pipeline_span_ms=1.0;host_quantile_ms=$(if($hybrid){.2}else{0.0});
                    covered_device_stage_sum_ms=$(if($hybrid){.6}else{.8});initialization_intervals=$b;rng_intervals=$b;loss_intervals=$b;
                    cub_intervals=$(if($hybrid){0}else{1});gather_intervals=$(if($hybrid){0}else{1})})
            }
        }
        $v=[pscustomobject]@{schema_version=1;application_version='0.3.0';scenarios=$c.scenarios;seed='42';backend=$c.backend;requested_threads=$c.requested_threads;
            threads_used=$(if($c.backend -ceq 'openmp'){$c.requested_threads}else{1});input_mode='csv_calibration';end_to_end_ms=$time;
            random_source=$(if($gpu){'cuRAND/PHILOX4_32_10/normal-double'}elseif($c.backend -ceq 'serial'){'mt19937_64/std::normal_distribution'}else{
                'block4096/splitmix64/mt19937_64/std::normal_distribution'});model=(Clone $fixture.model);calibration=$cal;estimates=$est;cuda=$gpu}
        $obs=[pscustomobject]@{exit_code=0;timed_out=$false;owned_job_terminated=$false;stderr='';stdout=(ConvertTo-Json $v -Depth 20 -Compress);
            process_mask_hex='ffff';priority_class=32;before=(Clone $manifest.power_reference);after=(Clone $manifest.power_reference)}
        $timeStamp=([DateTime]'2026-01-01T00:00:00Z').AddSeconds($step.sequence).ToString('o')
        [pscustomobject]@{sequence=$step.sequence;configuration_id=$step.configuration_id;phase=$step.phase;repetition=$step.repetition;diagnostics=$step.diagnostics;
            input_sha256=$manifest.input_sha256;executable_sha256=$manifest.executable_sha256;source_revision=$manifest.source_revision;
            source_snapshot_sha256=$manifest.source_snapshot_sha256;build_cache_sha256=$manifest.build_cache_sha256;started_utc=$timeStamp;finished_utc=$timeStamp;
            arguments=@(Get-BenchmarkArguments $c $step.diagnostics $manifest.input_path);error=$null;observation=$obs;result=$v}
    }
}
$runs=@(Samples $plan);Test-BenchmarkRecords $manifest $plan $runs $fixture;$checks++
$rows=@(Get-BenchmarkSummary $runs);Test-BenchmarkSummary $plan $runs $rows;$checks++
$serial=@($rows | Where-Object {$_.backend -ceq 'serial'})[0]
$full=@($rows | Where-Object {$_.cuda_mode -ceq 'full-device'})[0]
Assert-GpuClose $serial.mean_ms 11 'known mean';Assert-GpuClose $serial.sample_stddev_ms ([Math]::Sqrt(2)) 'known sample stddev'
Assert-GpuClose $full.speedup_vs_serial 5.5 'known serial ratio';Assert-GpuClose $full.speedup_vs_best_openmp 2.5 'known OpenMP ratio'
if($full.best_openmp_threads -ne 4 -or $rows.Count -ne 8){throw 'Best team/all rows failed'};$checks++
$slow=Clone $runs;$sample=@($slow | Where-Object {$_.phase -ceq 'measured' -and $_.result.backend -ceq 'serial'})[0];$sample.result.end_to_end_ms=1000.0
$slowRow=@(Get-BenchmarkSummary $slow | Where-Object {$_.backend -ceq 'serial'})[0];Assert-GpuClose $slowRow.mean_ms 506 'slow sample retained';$checks++
function Check($r){foreach($a in $r){$a.observation.stdout=ConvertTo-Json $a.result -Depth 20 -Compress};Test-BenchmarkRecords $manifest $plan $r $fixture}
Rejects 'missing attempt' {Check $runs[0..22]}
Rejects 'extra attempt' {Check ($runs+@($runs[0]))}
Rejects 'duplicate attempt' {$r=Clone $runs;$r[1]=$r[0];Check $r}
Rejects 'phase contamination' {$r=Clone $runs;$r[0].phase='measured';Check $r}
Rejects 'repetition contamination' {$r=Clone $runs;$r[0].repetition=2;Check $r}
Rejects 'changed plan' {$p=Clone $plan;$p.execution_order[0].diagnostics=$true;Test-BenchmarkRecords $manifest $p $runs $fixture}
Rejects 'failed campaign' {$m=Clone $manifest;$m.status='failed';Test-BenchmarkRecords $m $plan $runs $fixture}
foreach($field in @('input_sha256','executable_sha256','source_revision','source_snapshot_sha256','build_cache_sha256')){
    Rejects $field {$r=Clone $runs;$r[0].$field='wrong';Check $r}
}
foreach($value in @(0.0,-1.0,[double]::NaN,[double]::PositiveInfinity,$null,'1')){
    Rejects 'invalid time' {$r=Clone $runs;$r[0].result.end_to_end_ms=$value;Check $r}
}
Rejects 'actual teams' {$r=Clone $runs;$r[3].result.threads_used=99;Check $r}
Rejects 'wrong model' {$r=Clone $runs;$r[0].result.model.drift_annual+=1;Check $r}
Rejects 'wrong batch' {$r=Clone $runs;$r[0].result.cuda.effective_batch_size=1;Check $r}
Rejects 'diagnostics on primary' {$r=Clone $runs;$r[0].result.cuda | Add-Member NoteProperty diagnostics @{};Check $r}
Rejects 'timeout' {$r=Clone $runs;$r[0].observation.timed_out=$true;Check $r}
Rejects 'nonzero exit' {$r=Clone $runs;$r[0].observation.exit_code=7;Check $r}
Rejects 'power change' {$r=Clone $runs;$r[0].observation.after.ac_line_status=0;Check $r}
Rejects 'raw mismatch' {$r=Clone $runs;$r[0].observation.stdout='{}';Test-BenchmarkRecords $manifest $plan $r $fixture}
foreach($field in @('mean_ms','sample_stddev_ms','scenarios_per_second','speedup_vs_serial','speedup_vs_best_openmp','best_openmp_threads','sample_count')){
    Rejects $field {$s=Clone $rows;$s[0].$field+=1;Test-BenchmarkSummary $plan $runs $s}
}
Rejects 'summary missing row' {Test-BenchmarkSummary $plan $runs $rows[0..6]}
Rejects 'summary duplicate' {$s=Clone $rows;$s[1]=$s[0];Test-BenchmarkSummary $plan $runs $s}
$dp=New-BenchmarkPlan 'diagnostic';$dr=@(Samples $dp);Test-BenchmarkRecords $manifest $dp $dr $fixture;$checks++
Rejects 'diagnostic result drift' {$r=Clone $dr;$r[2].result.estimates[0].mc_var+=1;$r[2].observation.stdout=ConvertTo-Json $r[2].result -Depth 20 -Compress;Test-BenchmarkRecords $manifest $dp $r $fixture}
Rejects 'incorrect stage sum' {$r=Clone $dr;$r[2].result.cuda.diagnostics.covered_device_stage_sum_ms=9;$r[2].observation.stdout=ConvertTo-Json $r[2].result -Depth 20 -Compress;Test-BenchmarkRecords $manifest $dp $r $fixture}
$process=[pscustomobject]@{start_error=$null;timed_out=$false;exit_code=0}
if((Test-BandwidthDiscovery $process '==ERROR== ERR_NVGPUCTRPERM') -cne 'counter-permission-denied'){throw 'Zero-exit permission failure accepted'};$checks++
if((Test-BandwidthDiscovery $process '==ERROR== fatal') -cne 'tool-error'){throw 'Fatal diagnostic accepted'};$checks++
if((Test-BandwidthDiscovery $process 'nothing') -cne 'metrics-unverified'){throw 'Missing metric accepted'};$checks++
$formalRuns=@(Samples $formal);Test-BenchmarkRecords $manifest $formal $formalRuns $fixture
$formalRows=@(Get-BenchmarkSummary $formalRuns);Test-BenchmarkSummary $formal $formalRuns $formalRows;$checks++
Rejects 'false 10x claim' {$s=Clone $formalRows;foreach($a in $s){if($a.backend -ceq 'cuda' -and $a.scenarios -eq 10000000){$a.serial_target_10x=$true}};Test-BenchmarkSummary $formal $formalRuns $s}
Rejects 'dirty formal' {$m=Clone $manifest;$m.clean_source=$false;Test-BenchmarkRecords $m $formal $formalRuns $fixture}
Write-Host "Unified benchmark plan/auditor checks passed: $checks"
