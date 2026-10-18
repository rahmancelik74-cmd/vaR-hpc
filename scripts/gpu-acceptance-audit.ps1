Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'gpu-record-common.ps1')
function Get-IndependentGpuFixture($Csv) {
    # Independent two-pass calibration; no engine or application analytical fields.
    $rows=@(Import-Csv -LiteralPath $Csv)
    if($rows.Count -lt 3){throw 'Insufficient fixture observations'}
    $returns=@(); $previous=0.0; $lastDate=''
    foreach($row in $rows){
        if($row.date -cnotmatch '^\d{4}-\d{2}-\d{2}$' -or $row.date -cle $lastDate){throw 'Invalid fixture date ordering'}
        $null=[DateTime]::ParseExact($row.date,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)
        $price=[double]::Parse($row.close,[Globalization.CultureInfo]::InvariantCulture)
        $null=Assert-GpuFinite $price 'fixture price'; if($price -le 0){throw 'Nonpositive fixture price'}
        if($previous -gt 0){$returns+= [Math]::Log($price/$previous)}
        $previous=$price; $lastDate=$row.date
    }
    $sum=0.0; foreach($x in $returns){$sum+=$x}; $mean=$sum/$returns.Count
    $squares=0.0; foreach($x in $returns){$squares+=($x-$mean)*($x-$mean)}
    $variance=$squares/($returns.Count-1); $sigma=[Math]::Sqrt($variance*252)
    $mu=$mean*252+0.5*$sigma*$sigma
    $model=[pscustomobject]@{initial_value=$previous;drift_annual=$mu;volatility_annual=$sigma;horizon_years=10.0/252}
    # Standard-normal lower quantiles at .05 and .01, rounded to binary64.
    # Fixed for this two-confidence contract, independent of core.cpp's erfc bisection.
    $refs=@(); foreach($pair in @(@(.95,-1.6448536269514729),@(.99,-2.3263478740408408))){
        $exponent=($mu-.5*$sigma*$sigma)*$model.horizon_years+$sigma*[Math]::Sqrt($model.horizon_years)*$pair[1]
        $refs += [pscustomobject]@{confidence=$pair[0];analytical_var=$previous*(1-[Math]::Exp($exponent))}
    }
    [pscustomobject]@{model=$model;mean_log_return=$mean;sample_log_variance=$variance;observations=$rows.Count;
        returns_count=$returns.Count;date_start=$rows[0].date;date_end=$lastDate;references=$refs}
}
function Get-IndependentGpuAcceptance($Manifest,$Runs,$Fixture) {
    $seeds=@('42','123','456','789','2026'); $modes=@('full-device','hybrid')
    if(@($Manifest.seeds).Count -ne 5 -or (@($Manifest.seeds) -join ',') -cne ($seeds -join ',') -or
        (@($Manifest.modes) -join ',') -cne ($modes -join ',') -or $Manifest.scenarios -ne 10000000 -or
        (@($Manifest.confidence_levels) -join ',') -ne (@(.95,.99) -join ',') -or
        $Manifest.hybrid_requested_batch_size -ne 65535 -or $Manifest.hybrid_effective_batch_size -ne 65536){throw 'Wrong campaign configuration'}
    if(@($Runs).Count -ne 10){throw 'Incomplete or extra acceptance attempts'}
    $seen=@{}; $resultRows=@()
    foreach($record in $Runs){
        $key=$record.mode+'-'+$record.seed
        if($seen.ContainsKey($key) -or $record.mode -cnotin $modes -or $record.seed -isnot [string] -or $record.seed -cnotin $seeds){throw 'Duplicate/missing seed or mixed mode'}
        $seen[$key]=$true
        if($record.exit_code -ne 0 -or $record.timed_out -or $record.error -or $null -eq $record.result){throw 'Failed acceptance attempt'}
        foreach($field in @('input_sha256','executable_sha256','build_cache_sha256','source_revision')){
            if($record.$field -cne $Manifest.$field){throw "Changed $field"}
        }
        $r=$record.result; $c=$r.cuda
        foreach($field in @('explicit_device_bytes','allocation_budget_limit_bytes','free_before_bytes','free_with_pipeline_bytes',
            'total_vram_bytes','host_to_device_ms','device_to_host_ms','cub_temporary_bytes')){
            $value=Assert-GpuFinite $c.$field "CUDA $field"
            if($value -lt 0){throw "Negative CUDA $field"}
        }
        $budget=[Math]::Floor([double]$c.free_before_bytes/5)*4+[Math]::Floor(([double]$c.free_before_bytes%5)*4/5)
        if($c.allocation_budget_limit_bytes -ne $budget){throw 'Wrong allocation budget'}
        if($r.schema_version -ne 1 -or $r.application_version -cne '0.3.0' -or $r.backend -cne 'cuda' -or
            $r.input_mode -cne 'csv_calibration' -or $r.random_source -cne 'cuRAND/PHILOX4_32_10/normal-double' -or
            $r.scenarios -ne 10000000 -or $r.seed -cne $record.seed -or $c.mode -cne $record.mode -or
            $c.cub_version -ne 300403 -or $c.scenario_limit -ne 10000000 -or $c.normals_generated -ne 10000000 -or
            $c.explicit_device_bytes -gt $c.allocation_budget_limit_bytes){throw 'Wrong native result metadata'}
        if($record.mode -ceq 'hybrid'){
            if($c.requested_batch_size -ne 65535 -or $c.effective_batch_size -ne 65536 -or $c.batch_count -ne 153 -or
                $c.host_sorting_used -ne $true -or $c.quantile_location -cne 'host' -or $c.losses_transferred -ne 10000000 -or
                $c.host_loss_bytes -ne 80000000 -or $c.host_to_device_bytes -ne 0 -or $c.device_to_host_bytes -ne 80000612 -or
                $c.normals_allocated -ne 65536 -or $c.explicit_device_bytes -ne 1048580 -or $c.cub_temporary_bytes -ne 0){throw 'Inconsistent hybrid batches'}
        } else {
            if($c.requested_batch_size -ne 0 -or $c.effective_batch_size -ne 10000000 -or $c.batch_count -ne 1 -or
                $c.host_sorting_used -ne $false -or $c.quantile_location -cne 'device' -or $c.host_loss_bytes -ne 0 -or
                $c.losses_transferred -ne 0 -or $c.host_to_device_bytes -ne 16 -or $c.device_to_host_bytes -ne 20 -or
                $c.normals_allocated -ne 10000000){throw 'Inconsistent full-device configuration'}
            if($c.explicit_device_bytes -ne (240000036+[Math]::Max(1,[double]$c.cub_temporary_bytes))){throw 'Wrong full-device memory accounting'}
        }
        foreach($field in @('initial_value','drift_annual','volatility_annual','horizon_years')){
            Assert-GpuClose $r.model.$field $Fixture.model.$field "model $field"
        }
        foreach($field in @('mean_log_return','sample_log_variance','observations','returns_count')){
            Assert-GpuClose $r.calibration.$field $Fixture.$field "calibration $field"
        }
        if($r.calibration.date_start -cne $Fixture.date_start -or $r.calibration.date_end -cne $Fixture.date_end -or
            $r.calibration.horizon_trading_days -ne 10 -or $r.calibration.trading_days_per_year -ne 252){throw 'Wrong calibration interval'}
        $time=Assert-GpuFinite $r.end_to_end_ms 'engine time'; if($time -lt 0){throw 'Negative time'}
        if(@($r.estimates).Count -ne 2){throw 'Wrong confidence count'}
        for($i=0;$i -lt 2;$i++){
            $e=$r.estimates[$i]; $ref=$Fixture.references[$i]
            if([double]$e.confidence -ne [double]$ref.confidence){throw 'Wrong confidence'}
            $value=Assert-GpuFinite $e.mc_var 'VaR'
            Assert-GpuClose $e.analytical_var $ref.analytical_var 'analytical reference'
            Assert-GpuClose $e.signed_error ($value-[double]$e.analytical_var) 'signed error'
            $resultRows += [pscustomobject]@{mode=$record.mode;seed=$record.seed;confidence=$ref.confidence;mc_var=$value}
        }
    }
    foreach($mode in $modes){foreach($ref in $Fixture.references){
        $values=@($resultRows | Where-Object {$_.mode -ceq $mode -and $_.confidence -eq $ref.confidence})
        if($values.Count -ne 5){throw 'Missing seed/confidence'}
        $sum=0.0; foreach($v in $values){$sum+=$v.mc_var}; $mean=$sum/5.0
        $delta=[Math]::Abs($mean-$ref.analytical_var)
        $limit=.01*[Math]::Max([Math]::Abs($ref.analytical_var),.01*$Fixture.model.initial_value)
        [pscustomobject]@{mode=$mode;confidence=$ref.confidence;scenarios=10000000;seed_count=5;
            mean_var=$mean;analytical_var=$ref.analytical_var;absolute_error_of_mean=$delta;allowed_error=$limit;
            passed=($delta -le $limit);per_seed=$values}
    }}
}
function Test-GpuAcceptanceSummary($Recorded,$Expected) {
    if(@($Recorded).Count -ne 4){throw 'Wrong acceptance row count'}
    for($i=0;$i -lt 4;$i++){
        $a=$Recorded[$i];$e=$Expected[$i]
        if($a.mode -cne $e.mode -or $a.confidence -ne $e.confidence -or $a.scenarios -ne 10000000 -or
            $a.seed_count -ne 5 -or $a.passed -isnot [bool] -or $a.passed -ne $e.passed){throw 'Incorrect acceptance outcome'}
        foreach($field in @('mean_var','analytical_var','absolute_error_of_mean','allowed_error')){Assert-GpuClose $a.$field $e.$field "acceptance $field"}
        if(@($a.per_seed).Count -ne 5){throw 'Missing per-seed summary'}
        for($j=0;$j -lt 5;$j++){
            if($a.per_seed[$j].seed -cne $e.per_seed[$j].seed -or $a.per_seed[$j].mode -cne $e.mode -or
                $a.per_seed[$j].confidence -ne $e.confidence){throw 'Wrong per-seed summary'}
            Assert-GpuClose $a.per_seed[$j].mc_var $e.per_seed[$j].mc_var 'per-seed value'
        }
    }
}
