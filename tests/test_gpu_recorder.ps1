Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts/gpu-acceptance-audit.ps1')
function Clone($Value) { ConvertFrom-Json (ConvertTo-Json -InputObject $Value -Depth 30) }
function Rejects($Label,[scriptblock]$Action) {
    $rejected=$false;try {& $Action | Out-Null}catch{$rejected=$true}
    if(-not $rejected){throw "Corrupted record accepted: $Label"}
    $script:checks++
}
$checks=0
$fixture=Get-IndependentGpuFixture (Join-Path $root 'data/synthetic_prices.csv')
Assert-GpuClose $fixture.model.initial_value 100.4 'known initial value'
Assert-GpuClose $fixture.model.drift_annual .11221749496730603 'known drift'
Assert-GpuClose $fixture.model.volatility_annual .2037837912712771 'known volatility'
Assert-GpuClose $fixture.references[0].analytical_var 6.143576939418958 'known analytical 95'
Assert-GpuClose $fixture.references[1].analytical_var 8.715446716200948 'known analytical 99'
$m=[pscustomobject]@{seeds=@('42','123','456','789','2026');modes=@('full-device','hybrid');confidence_levels=@(.95,.99);
    scenarios=10000000;hybrid_requested_batch_size=65535;hybrid_effective_batch_size=65536;
    input_sha256='fixture-input';executable_sha256='fixture-exe';build_cache_sha256='fixture-cache';source_revision='fixture-source'}
$runs=@()
foreach($mode in $m.modes){foreach($seed in $m.seeds){
    # Synthetic unit records only; never written as GPU execution evidence.
    $c=[pscustomobject]@{mode=$mode;cub_version=300403;scenario_limit=10000000;normals_generated=10000000;
        explicit_device_bytes=240000037;allocation_budget_limit_bytes=400000000;requested_batch_size=0;
        effective_batch_size=10000000;batch_count=1;host_sorting_used=$false;quantile_location='device';
        host_loss_bytes=0;losses_transferred=0;host_to_device_bytes=16;device_to_host_bytes=20;
        normals_allocated=10000000;cub_temporary_bytes=0;free_before_bytes=500000000;free_with_pipeline_bytes=100000000;
        total_vram_bytes=1000000000;host_to_device_ms=1.0;device_to_host_ms=1.0}
    if($mode -ceq 'hybrid'){
        $c.requested_batch_size=65535;$c.effective_batch_size=65536;$c.batch_count=153;$c.host_sorting_used=$true;
        $c.quantile_location='host';$c.host_loss_bytes=80000000;$c.losses_transferred=10000000;
        $c.host_to_device_bytes=0;$c.device_to_host_bytes=80000612;$c.normals_allocated=65536
        $c.explicit_device_bytes=1048580
    }
    $cal=[pscustomobject]@{observations=$fixture.observations;returns_count=$fixture.returns_count;date_start=$fixture.date_start;
        date_end=$fixture.date_end;mean_log_return=$fixture.mean_log_return;sample_log_variance=$fixture.sample_log_variance;
        horizon_trading_days=10;trading_days_per_year=252}
    $est=@();foreach($ref in $fixture.references){$est+=[pscustomobject]@{confidence=$ref.confidence;mc_var=$ref.analytical_var;
        analytical_var=$ref.analytical_var;signed_error=0.0}}
    $runs+=[pscustomobject]@{mode=$mode;seed=$seed;exit_code=0;timed_out=$false;error=$null;
        input_sha256=$m.input_sha256;executable_sha256=$m.executable_sha256;build_cache_sha256=$m.build_cache_sha256;source_revision=$m.source_revision;
        result=[pscustomobject]@{schema_version=1;application_version='0.3.0';backend='cuda';input_mode='csv_calibration';
            random_source='cuRAND/PHILOX4_32_10/normal-double';scenarios=10000000;seed=$seed;cuda=$c;
            model=(Clone $fixture.model);calibration=$cal;estimates=$est;end_to_end_ms=1.0}}
}}
$expected=@(Get-IndependentGpuAcceptance $m $runs $fixture)
Test-GpuAcceptanceSummary $expected $expected
if($expected.Count -ne 4 -or @($expected | Where-Object {-not $_.passed}).Count){throw 'Positive records failed'}
$checks++
Rejects 'missing seed' {Get-IndependentGpuAcceptance $m $runs[0..8] $fixture}
Rejects 'duplicate seed' {$r=Clone $runs;$r[1]=$r[0];Get-IndependentGpuAcceptance $m $r $fixture}
Rejects 'mixed modes' {$r=Clone $runs;$r[0].result.cuda.mode='hybrid';Get-IndependentGpuAcceptance $m $r $fixture}
Rejects 'unexpected mode' {$r=Clone $runs;$r[0].mode='serial';Get-IndependentGpuAcceptance $m $r $fixture}
foreach($field in @('input_sha256','executable_sha256','build_cache_sha256','source_revision')){
    Rejects $field {$r=Clone $runs;$r[0].$field='changed';Get-IndependentGpuAcceptance $m $r $fixture}
}
foreach($field in @('initial_value','drift_annual','volatility_annual','horizon_years')){
    Rejects $field {$r=Clone $runs;$r[0].result.model.$field+=.1;Get-IndependentGpuAcceptance $m $r $fixture}
}
foreach($field in @('requested_batch_size','effective_batch_size','batch_count','losses_transferred','normals_generated','host_loss_bytes','device_to_host_bytes')){
    Rejects $field {$r=Clone $runs;$r[5].result.cuda.$field++;Get-IndependentGpuAcceptance $m $r $fixture}
}
Rejects 'nonfinite VaR' {$r=Clone $runs;$r[0].result.estimates[0].mc_var=[double]::NaN;Get-IndependentGpuAcceptance $m $r $fixture}
Rejects 'infinite analytic' {$r=Clone $runs;$r[0].result.estimates[0].analytical_var=[double]::PositiveInfinity;Get-IndependentGpuAcceptance $m $r $fixture}
Rejects 'missing numeric value' {$r=Clone $runs;$r[0].result.estimates[0].mc_var=$null;Get-IndependentGpuAcceptance $m $r $fixture}
Rejects 'changed calibration' {$r=Clone $runs;$r[0].result.calibration.sample_log_variance+=.01;Get-IndependentGpuAcceptance $m $r $fixture}
Rejects 'false analytical reference' {$r=Clone $runs;$r[0].result.estimates[0].analytical_var+=1;Get-IndependentGpuAcceptance $m $r $fixture}
Rejects 'failed attempt' {$r=Clone $runs;$r[0].exit_code=1;Get-IndependentGpuAcceptance $m $r $fixture}
Rejects 'extra attempt' {Get-IndependentGpuAcceptance $m ($runs+@($runs[0])) $fixture}
Rejects 'changed seed configuration' {$a=Clone $m;$a.seeds[4]='42';Get-IndependentGpuAcceptance $a $runs $fixture}
foreach($field in @('mean_var','analytical_var','absolute_error_of_mean','allowed_error')){
    Rejects ('summary '+$field) {$a=Clone $expected;$a[0].$field+=1;Test-GpuAcceptanceSummary $a $expected}
}
Rejects 'false pass' {$a=Clone $expected;$a[0].passed=$false;Test-GpuAcceptanceSummary $a $expected}
Rejects 'missing per seed' {$a=Clone $expected;$a[0].per_seed=@();Test-GpuAcceptanceSummary $a $expected}
# Errors may cancel in a mean. Per-seed rejection/mean absolute error must not replace this criterion.
$cancel=Clone $runs
for($i=0;$i -lt 5;$i++){
    $delta=@(1.0,-1.0,0.0,0.0,0.0)[$i]
    $cancel[$i].result.estimates[0].mc_var+=$delta;$cancel[$i].result.estimates[0].signed_error=$delta
}
$cancellation=@(Get-IndependentGpuAcceptance $m $cancel $fixture)
if(-not $cancellation[0].passed){throw 'Incorrect individual-seed or mean-absolute-error acceptance'};$checks++
$fail=Clone $runs
foreach($r in $fail){foreach($e in $r.result.estimates){$e.mc_var+=1;$e.signed_error=1.0}}
$failed=@(Get-IndependentGpuAcceptance $m $fail $fixture)
if(@($failed | Where-Object {$_.passed}).Count){throw 'Incorrect aggregate pass'};$checks++
$clean="========= COMPUTE-SANITIZER`n========= ERROR SUMMARY: 0 errors`n"
if(-not (Test-GpuSanitizerLog $clean)){throw 'Clean sanitizer log rejected'};$checks++
$race="========= COMPUTE-SANITIZER`n========= RACECHECK SUMMARY: 0 hazards displayed (0 errors, 0 warnings)`n"
if(-not (Test-GpuSanitizerLog $race)){throw 'Clean racecheck log rejected'};$checks++
if(Test-GpuSanitizerLog ($race.Replace('0 warnings','1 warnings'))){throw 'Racecheck warning accepted'};$checks++
if(Test-GpuSanitizerLog ($clean+'unexplained diagnostic')){throw 'Unexplained diagnostic accepted'};$checks++
foreach($diagnostic in @('Warning: hazard','unsupported instrumentation','skipped kernel','attachment failed','launch timeout','Internal Error: tracking')){
    if(Test-GpuSanitizerLog ($clean+$diagnostic)){throw "Bad sanitizer diagnostic accepted: $diagnostic"};$checks++
}
if(Test-GpuSanitizerLog 'no CUDA attachment'){throw 'Missing attachment accepted'};$checks++
if(@(Get-GpuSanitizerMatrix).Count -ne 44){throw 'Incorrect sanitizer matrix'};$checks++
$temp=Join-Path $root ('results/gpu-recorder-unit-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$file=Join-Path $temp 'bytes.txt'
[IO.File]::WriteAllBytes($file,[byte[]]@(65,13,10));$hash=Get-GpuHash $file
Assert-GpuBoundArtifact $file $hash;$checks++
[IO.File]::WriteAllBytes($file,[byte[]]@(65,10))
Rejects 'exact-byte LF/CRLF corruption' {Assert-GpuBoundArtifact $file $hash}
$process=Invoke-GpuProcess 'powershell.exe' @('-NoProfile','-Command',"[Console]::Out.Write('unit-out'); [Console]::Error.Write('unit-err'); exit 7") (Join-Path $temp 'capture') 15
if($process.exit_code -ne 7 -or [IO.File]::ReadAllText($process.stdout) -cne 'unit-out' -or
    [IO.File]::ReadAllText($process.stderr) -cne 'unit-err' -or $process -is [array]){throw 'Raw process capture/status failed'};$checks++
Rejects 'failed process' {Assert-GpuProcess $process}
$csvPath=Join-Path $temp 'roundtrip.csv'
$priorCulture=[Threading.Thread]::CurrentThread.CurrentCulture
try {
    [Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo('tr-TR')
    $value=6.144657330828541
    Write-GpuEstimates $csvPath @([pscustomobject]@{mode='full-device';seed='42';scenarios=10000000;
        confidence=.95;mc_var=$value;analytical_var=6.143576939418958})
    $row=Import-Csv -LiteralPath $csvPath
    if($row.confidence -cne '0.95' -or [double]::Parse($row.mc_var,[Globalization.CultureInfo]::InvariantCulture) -ne $value){
        throw 'CSV is not culture-independent binary64 round-trip'
    };$checks++
} finally {[Threading.Thread]::CurrentThread.CurrentCulture=$priorCulture}
Write-Host "GPU recorder/auditor corruption checks passed: $checks"
