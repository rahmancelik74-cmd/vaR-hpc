Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location -LiteralPath $root
. ./scripts/benchmark-common.ps1
$out=$PSScriptRoot
$audit=[ordered]@{status='failed';checked_utc=[DateTime]::UtcNow.ToString('o');errors=@();
    campaign='Separate CUDA stage diagnostic matrix';primary_benchmark=$false;profiler_enabled=$false;bandwidth_measured=$false}
try {
    $m=Read-GpuJson (Join-Path $out 'manifest.json');$plan=Read-GpuJson (Join-Path $out 'plan.json')
    $audit['manifest_sha256']=Get-GpuHash (Join-Path $out 'manifest.json')
    if($m.status -cne 'completed' -or -not $m.clean_source -or $m.attempted_processes -ne 18 -or
        $m.source_revision -cne '80148cee0ba5a52b1c67ca98a6ad4eb91e4d7817' -or $m.profiler_enabled -or $m.primary_benchmark){throw 'Incomplete/wrong campaign'}
    if((& git rev-parse ($m.source_revision+'^{tree}')).Trim() -cne $m.source_tree -or $m.end_source_revision -cne $m.source_revision -or
        @($m.end_source_changes).Count){throw 'Source revision changed'}
    $bound=@{}
    foreach($record in $m.record_hashes){
        if($record.file -cne [IO.Path]::GetFileName($record.file) -or $bound.ContainsKey($record.file)){throw 'Invalid duplicate record path'}
        Assert-GpuBoundArtifact (Join-Path $out $record.file) $record.sha256;$bound[$record.file]=$true
    }
    foreach($file in Get-ChildItem -LiteralPath $out -File){
        if($file.Name -notin @('manifest.json','independent-audit.json','report.md','delivery-manifest.json') -and -not $bound.ContainsKey($file.Name)){throw 'Unbound output'}
    }
    foreach($a in $m.artifacts){Assert-GpuBoundArtifact $a.path $a.sha256}
    foreach($t in @(Read-GpuJson (Join-Path $out 'tools.json'))){Assert-GpuBoundArtifact $t.path $t.sha256}
    Assert-GpuBoundArtifact $m.executable_path $m.executable_sha256
    Assert-GpuBoundArtifact $m.probe_path $m.probe_sha256
    Assert-GpuBoundArtifact (Join-Path $out 'source-snapshot.json') $m.source_snapshot_sha256
    Test-BenchmarkSourceBinding $m @(Read-GpuJson (Join-Path $out 'source-snapshot.json'))
    foreach($s in @(Read-GpuJson (Join-Path $out 'source-snapshot.json'))){Assert-GpuBoundArtifact $s.path $s.sha256}
    Assert-GpuBoundArtifact $m.input_path $m.input_sha256
    Assert-GpuBoundArtifact (Join-Path $out 'fixture.csv') '8dbb7c73e6ad48cb8c8c175aff6684d2a0433e5f08424ec7ea1e69037bb36210'
    Assert-GpuBoundArtifact (Join-Path $out 'CMakeCache.txt') $m.build_cache_sha256
    $cache=[IO.File]::ReadAllText((Join-Path $out 'CMakeCache.txt'))
    foreach($flag in @('MC_ENABLE_CUDA:BOOL=ON','MC_ENABLE_OPENMP:BOOL=ON','MC_BUILD_CPU_TOOLS:BOOL=ON','BUILD_TESTING:BOOL=ON',
        'CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG','CMAKE_CUDA_ARCHITECTURES:UNINITIALIZED=89')){
        if(-not $cache.Contains($flag)){throw 'Wrong build setting'}
    }
    $project=[IO.File]::ReadAllText((Join-Path $out 'mc_cuda.vcxproj'))
    if(-not $project.Contains('--fmad=false') -or -not $project.Contains('/Zc:preprocessor')){throw 'Wrong CUDA numerical flags'}
    foreach($name in @('configure','build','test-list','ctest-diagnostics','cmake-version','nvcc-version','version','inventory')){
        Assert-GpuProcess (Read-GpuJson (Join-Path $out ($name+'.process.json')))
    }
    $tests=Read-GpuJson (Join-Path $out 'test-list.stdout.txt')
    if(@($tests.tests | Where-Object {$_.name -ceq 'cuda_diagnostics_contract'}).Count -ne 1){throw 'Diagnostic regression not discovered'}
    if([IO.File]::ReadAllText((Join-Path $out 'ctest-diagnostics.stdout.txt')) -cnotmatch '100% tests passed, 0 tests failed out of 1\b'){throw 'Diagnostic preflight not passed'}
    $previous=@(Read-GpuJson (Join-Path $out 'prior-evidence-bindings.json'))
    foreach($b in $previous){Assert-GpuBoundArtifact $b.path $b.sha256}
    $null=& git diff --exit-code df34111 $m.source_revision -- src include scripts tests CMakeLists.txt
    if($LASTEXITCODE){throw 'Prior checked implementation changed'}
    $priorDir=Join-Path $root 'results/benchmark-formal-89536e3-20261019-run2/campaign'
    $priorManifest=Read-GpuJson (Join-Path $priorDir 'manifest.json')
    $priorAudit=Read-GpuJson (Join-Path $priorDir 'independent-audit.json')
    Assert-GpuBoundArtifact (Join-Path $priorDir 'manifest.json') $priorAudit.manifest_sha256
    if($priorAudit.status -cne 'passed'){throw 'Prior regression evidence incomplete'}
    $priorRuns=@(Get-Content (Join-Path $priorDir 'runs.jsonl') -Encoding UTF8 | ForEach-Object {$_ | ConvertFrom-Json})
    foreach($name in @('curand64_10.dll','cudart64_13.dll')){
        $a=@($priorManifest.artifacts | Where-Object {[IO.Path]::GetFileName($_.path) -ceq $name})[0]
        $b=@($m.artifacts | Where-Object {[IO.Path]::GetFileName($_.path) -ceq $name})[0]
        if($a.sha256 -cne $b.sha256){throw 'CUDA runtime DLL changed'}
    }
    $configs=@();foreach($n in @(100000,1000000,10000000)){foreach($mode in @('full-device','hybrid')){
        $configs+=[pscustomobject]@{id="$mode-N$n";n=$n;mode=$mode}
    }}
    if($plan.planned_processes -ne 18 -or $plan.repetitions -ne 3 -or $plan.warmups -ne 0 -or $plan.profiler -or
        -not $plan.diagnostics -or $plan.configurations.Count -ne 6 -or $plan.execution_order.Count -ne 18){throw 'Wrong requested plan'}
    foreach($c in $configs){
        $p=@($plan.configurations | Where-Object {$_.id -ceq $c.id})
        if($p.Count -ne 1 -or $p[0].scenarios -ne $c.n -or $p[0].cuda_mode -cne $c.mode){throw 'Wrong plan configurations'}
    }
    $runs=@(Get-Content (Join-Path $out 'runs.jsonl') -Encoding UTF8 | ForEach-Object {$_ | ConvertFrom-Json})
    if($runs.Count -ne 18 -or @(Get-ChildItem $out -Filter 'attempt-???.json').Count -ne 18){throw 'Missing/extra attempts'}
    $seen=@{};$lastFinish=[DateTime]::MinValue
    for($i=0;$i -lt 18;$i++){
        $r=$runs[$i];$c=@($configs | Where-Object {$_.id -ceq $r.configuration_id})
        $rep=1+[int][Math]::Floor($i/6);$indices=@(0..5);if($rep%2 -eq 1){[array]::Reverse($indices)}
        $expected=$configs[$indices[(($i%6)+5*($rep-1))%6]].id
        if($c.Count -ne 1 -or $r.configuration_id -cne $expected -or $r.sequence -ne $i+1 -or $r.repetition -ne $rep -or
            $r.phase -cne 'diagnostic' -or -not $r.diagnostics -or $r.error){throw 'Wrong/failed repetition order'}
        $c=$c[0];$key=$r.configuration_id+'-'+$r.repetition
        if($seen.ContainsKey($key)){throw 'Duplicate run'};$seen[$key]=$true
        $step=$plan.execution_order[$i]
        foreach($f in @('sequence','configuration_id','repetition','diagnostics')){if($step.$f -cne $r.$f){throw 'Plan/run mismatch'}}
        foreach($f in @('source_revision','source_snapshot_sha256','input_sha256','executable_sha256','build_cache_sha256')){
            if($r.$f -cne $m.$f){throw 'Run provenance changed'}
        }
        if([DateTime]$r.started_utc -lt $lastFinish -or [DateTime]$r.finished_utc -lt [DateTime]$r.started_utc){throw 'Invalid timestamps'}
        $lastFinish=[DateTime]$r.finished_utc
        $id='attempt-'+('{0:D3}' -f ($i+1));$saved=Read-GpuJson (Join-Path $out ($id+'.json'))
        if((ConvertTo-Json $saved -Depth 30 -Compress) -cne (ConvertTo-Json $r -Depth 30 -Compress)){throw 'Attempt/JSONL mismatch'}
        $launcher=Read-GpuJson (Join-Path $out $r.launcher_process);Assert-GpuProcess $launcher
        $o=Read-GpuJson $launcher.stdout
        if((ConvertTo-Json $o -Depth 30 -Compress) -cne (ConvertTo-Json $r.observation -Depth 30 -Compress)){throw 'Raw launcher mismatch'}
        if((Get-Item -LiteralPath $launcher.stderr).Length -ne 0 -or $o.timed_out -or $o.owned_job_terminated -or
            -not $o.owned_tree_exited -or $o.exit_code -ne 0 -or $o.stderr -cne '' -or
            $o.process_mask_hex -cne $m.process_mask_hex -or $o.priority_class -ne 32){throw 'Process/lifetime/placement failure'}
        foreach($power in @($o.before,$o.after)){
            if($power.ac_line_status -ne 1 -or $power.battery_saver -ne $m.power_reference.battery_saver -or
                $power.active_power_scheme -cne $m.power_reference.active_power_scheme){throw 'Current power condition changed'}
        }
        foreach($stream in @('stdout','stderr')){
            if([IO.File]::ReadAllText((Join-Path $out ($id+'-target.'+$stream+'.txt'))) -cne $o.$stream){throw 'Target stream extraction mismatch'}
        }
        $v=$o.stdout | ConvertFrom-Json
        if((ConvertTo-Json $v -Depth 30 -Compress) -cne (ConvertTo-Json $r.result -Depth 30 -Compress)){throw 'Raw target/result mismatch'}
        $expectedArgs=@('--csv',$m.input_path,[string]$c.n,'42','10','252','--backend','cuda','--cuda-mode',$c.mode)
        if($c.mode -ceq 'hybrid'){$expectedArgs+=@('--batch-size','65535')};$expectedArgs+=@('--cuda-diagnostics','--json')
        if((@($r.arguments) -join "`n") -cne ($expectedArgs -join "`n") -or $launcher.executable -cne $m.probe_path -or
            (@($launcher.arguments) -join "`n") -cne ((@('--run-timeout','60000',$m.process_mask_hex,$m.executable_path)+$expectedArgs) -join "`n")){
            throw 'Wrong exact diagnostic invocation'}
        if($v.schema_version -ne 1 -or $v.application_version -cne '0.3.0' -or $v.backend -cne 'cuda' -or
            $v.scenarios -ne $c.n -or $v.seed -isnot [string] -or $v.seed -cne '42' -or $v.requested_threads -ne 0 -or
            $v.threads_used -ne 1 -or $v.input_mode -cne 'csv_calibration' -or $v.random_source -cne 'cuRAND/PHILOX4_32_10/normal-double'){
            throw 'Wrong model execution configuration'}
        $fixture=Get-IndependentGpuFixture (Join-Path $out 'fixture.csv')
        foreach($f in @('initial_value','drift_annual','volatility_annual','horizon_years')){Assert-GpuClose $v.model.$f $fixture.model.$f "model $f"}
        foreach($f in @('mean_log_return','sample_log_variance','observations','returns_count')){Assert-GpuClose $v.calibration.$f $fixture.$f "calibration $f"}
        if($v.calibration.horizon_trading_days -ne 10 -or $v.calibration.trading_days_per_year -ne 252 -or
            $v.calibration.date_start -cne $fixture.date_start -or $v.calibration.date_end -cne $fixture.date_end -or $v.estimates.Count -ne 2){throw 'Calibration interval/confidence count'}
        $reference=@($priorRuns | Where-Object {$_.configuration_id -ceq $c.id})[0].result
        for($j=0;$j -lt 2;$j++){
            Assert-GpuClose $v.estimates[$j].analytical_var $fixture.references[$j].analytical_var 'Analytical reference'
            if([double]$v.estimates[$j].confidence -ne @(.95,.99)[$j] -or
                [double]$v.estimates[$j].mc_var -ne [double]$reference.estimates[$j].mc_var){throw 'Native numerical result differs from compatible prior OFF result'}
        }
        $g=$v.cuda;$d=$g.diagnostics;$hybrid=$c.mode -ceq 'hybrid'
        $batch=if($hybrid){[int][Math]::Ceiling($c.n/65536.0)}else{1}
        if($g.mode -cne $c.mode -or $g.requested_batch_size -ne $(if($hybrid){65535}else{0}) -or
            $g.effective_batch_size -ne $(if($hybrid){65536}else{$c.n}) -or $g.batch_count -ne $batch -or
            $g.normals_generated -ne $c.n -or $g.cub_version -ne 300403 -or $d.schema_version -ne 1 -or -not $d.enabled){throw 'Wrong batch/RNG/diagnostic metadata'}
        foreach($f in @('compiler_version','curand_header_version','runtime_header_version','runtime_version','curand_runtime_version','driver_api_version','device_name','compute_major','compute_minor')){
            if($g.$f -cne $reference.cuda.$f){throw "Changed tool/runtime/device metadata: $f"}
        }
        $sum=0.0
        foreach($f in @('initialization','rng','loss','cub','gather')){
            $value=Assert-GpuFinite $d.($f+'_ms') $f;if($value -lt 0){throw 'Negative stage duration'};$sum+=$value
            $count=if($f -in @('cub','gather')){if($hybrid){0}else{1}}else{$batch}
            if($d.($f+'_intervals') -ne $count -or ($count -eq 0 -and $value -ne 0)){throw 'Wrong cumulative stage interval count'}
        }
        Assert-GpuClose $d.covered_device_stage_sum_ms $sum 'Covered stage sum'
        foreach($f in @('pipeline_span_ms','host_quantile_ms')){if((Assert-GpuFinite $d.$f $f) -lt 0){throw 'Negative span/quantile'}}
        if((Assert-GpuFinite $v.end_to_end_ms 'Host time') -le 0 -or $d.pipeline_span_ms+1e-5 -lt $sum -or
            ($d.pipeline_span_ms+$d.host_quantile_ms) -gt $v.end_to_end_ms+1e-3 -or (-not $hybrid -and $d.host_quantile_ms -ne 0)){
            throw 'Invalid host/span/stage/quantile timing scopes'}
        foreach($f in @('host_to_device_ms','device_to_host_ms')){if((Assert-GpuFinite $g.$f $f) -lt 0){throw 'Negative copy interval'}}
        if($g.host_to_device_bytes -ne $(if($hybrid){0}else{16}) -or $g.device_to_host_bytes -ne $(if($hybrid){8*$c.n+4*$batch}else{20}) -or
            $g.host_sorting_used -ne $hybrid -or $g.quantile_location -cne $(if($hybrid){'host'}else{'device'}) -or
            ($hybrid -and $g.losses_transferred -ne $c.n)){throw 'Wrong transfer/global quantile accounting'}
    }
    $summary=@(Read-GpuJson (Join-Path $out 'summary.json'));$csv=@(Import-Csv (Join-Path $out 'summary.csv'))
    $fields=@('end_to_end_ms','pipeline_span_ms','initialization_ms','rng_ms','loss_ms','cub_ms','gather_ms',
        'host_quantile_ms','covered_device_stage_sum_ms','host_to_device_ms','device_to_host_ms')
    if($summary.Count -ne 66 -or $csv.Count -ne 66){throw 'Missing summary fields'}
    foreach($c in $configs){foreach($f in $fields){
        $samples=@($runs | Where-Object {$_.configuration_id -ceq $c.id})
        if($samples.Count -ne 3){throw 'Wrong repetition coverage'}
        $values=@(foreach($r in $samples){
            if($f -ceq 'end_to_end_ms'){[double]$r.result.$f}elseif($f -in @('host_to_device_ms','device_to_host_ms')){
                [double]$r.result.cuda.$f}else{[double]$r.result.cuda.diagnostics.$f}
        })
        $sum=0.0;foreach($v in $values){$sum+=$v};$mean=$sum/3
        $squares=0.0;foreach($v in $values){$squares+=($v-$mean)*($v-$mean)};$std=[Math]::Sqrt($squares/2)
        $row=@($summary | Where-Object {$_.configuration_id -ceq $c.id -and $_.field -ceq $f})
        if($row.Count -ne 1 -or $row[0].sample_count -ne 3 -or $row[0].scenarios -ne $c.n -or $row[0].cuda_mode -cne $c.mode){throw 'Wrong/duplicate summary configuration'}
        Assert-GpuClose $row[0].mean_ms $mean 'Independent mean';Assert-GpuClose $row[0].sample_stddev_ms $std 'Independent sample stddev'
    }}
    for($i=0;$i -lt 66;$i++){
        foreach($f in @('configuration_id','scenarios','cuda_mode','sample_count','field')){if([string]$csv[$i].$f -cne [string]$summary[$i].$f){throw 'CSV identity mismatch'}}
        foreach($f in @('mean_ms','sample_stddev_ms')){if([double]::Parse($csv[$i].$f,[Globalization.CultureInfo]::InvariantCulture) -ne [double]$summary[$i].$f){throw 'CSV round-trip mismatch'}}
    }
    $audit.status='passed';$audit['tested_source']=$m.source_revision;$audit['attempts']=18;$audit['configurations']=6
    $audit['repetitions_per_configuration']=3;$audit['summary_fields_per_configuration']=11
    $audit['statistics']='Explicit sum/two-pass sample variance n-1 independently matches Welford; all CSV fields checked'
    $audit['numerics']='All 36 native VaR estimates exactly match compatible prior uninstrumented same-configuration results; prior evidence not rerun'
    $audit['preflight']='Fresh diagnostic equivalence/scope CTest passed; prior full regression evidence reused after implementation/runtime compatibility checks'
    $audit['hash_bound_records']=$m.record_hashes.Count;$audit['unchanged_prior_bindings']=$previous.Count
}catch{$audit.errors+=$_.Exception.Message}
Write-GpuJson (Join-Path $out 'independent-audit.json') $audit
if($audit.status -cne 'passed'){throw ('Diagnostic audit failed: '+($audit.errors -join '; '))}
Write-Host 'Independent diagnostic audit passed: 18 processes, six configurations, 11 timing fields, exact numerical consistency and hashes.'
