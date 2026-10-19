. (Join-Path $PSScriptRoot 'convergence-common.ps1')
function Get-RecordedConvergenceFixture($Path) {
    # Welford calibration, separate from the verifier's two-pass calibration.
    $rows=@(Import-Csv -LiteralPath $Path);$mean=0.0;$m2=0.0;$count=0;$previous=0.0
    foreach($row in $rows){
        $price=[double]::Parse($row.close,[Globalization.CultureInfo]::InvariantCulture)
        if($previous -gt 0){$x=[Math]::Log($price/$previous);$count++;$delta=$x-$mean;$mean+=$delta/$count;$m2+=$delta*($x-$mean)}
        $previous=$price
    }
    $variance=$m2/($count-1);$sigma=[Math]::Sqrt($variance*252);$mu=$mean*252+.5*$sigma*$sigma
    $model=[pscustomobject]@{initial_value=$previous;drift_annual=$mu;volatility_annual=$sigma;horizon_years=10.0/252}
    $refs=@(foreach($pair in @(@(.95,-1.6448536269514729),@(.99,-2.3263478740408408))){
        [pscustomobject]@{confidence=$pair[0];analytical_var=$previous*(1-[Math]::Exp(($mu-.5*$sigma*$sigma)*$model.horizon_years+$sigma*[Math]::Sqrt($model.horizon_years)*$pair[1]))}
    })
    [pscustomobject]@{model=$model;mean_log_return=$mean;sample_log_variance=$variance;observations=$rows.Count;returns_count=$count;
        date_start=$rows[0].date;date_end=$rows[-1].date;references=$refs}
}
function Get-RecordedConvergenceAnalysis($Records,$Fixture) {
    $perSeed=@();$groups=@();$acceptance=@();$v0=$Fixture.model.initial_value
    foreach($engine in @('serial','openmp','full-device','hybrid')){foreach($n in @(10000,100000,1000000,10000000)){
        $runs=@($Records | Where-Object {$_.key -clike "$engine/$n/*"})
        foreach($ref in $Fixture.references){
            $reference=[double]$ref.analytical_var;$eligible=[Math]::Abs($reference) -ge .01*$v0
            $values=@();$errors=@()
            foreach($run in $runs){
                $e=@($run.result.estimates | Where-Object {[double]$_.confidence -eq [double]$ref.confidence})[0]
                $value=[double]$e.mc_var;$error=$value-$reference;$values+=$value;$errors+=$error
                $perSeed += [pscustomobject]@{key=$run.key;confidence=$ref.confidence;mc_var=$value;analytical_var=$reference;
                    signed_error=$error;absolute_error=[Math]::Abs($error);relative_error=$(if($eligible){[Math]::Abs($error)/[Math]::Abs($reference)}else{$null});
                    error_over_v0=$error/$v0;relative_status=$(if($eligible){'available'}else{'N/A: near-zero reference'})}
            }
            $mean=$null;$signed=$null;$absolute=$null;$std=$null;$mae=$null;$rmse=$null
            if($values.Count){
                $mean=($values|Measure-Object -Average).Average;$signed=$mean-$reference;$absolute=[Math]::Abs($signed)
                $sum2=0.0;$absSum=0.0;$err2=0.0
                for($i=0;$i -lt $values.Count;$i++){$sum2+=[Math]::Pow($values[$i]-$mean,2);$absSum+=[Math]::Abs($errors[$i]);$err2+=$errors[$i]*$errors[$i]}
                if($values.Count -gt 1){$std=[Math]::Sqrt($sum2/($values.Count-1))};$mae=$absSum/$values.Count;$rmse=[Math]::Sqrt($err2/$values.Count)
            }
            $groups += [pscustomobject]@{engine=$engine;scenarios=$n;confidence=$ref.confidence;seed_count=$values.Count;complete=($values.Count -eq 5);
                mean_var=$mean;analytical_var=$reference;signed_error_of_mean=$signed;absolute_error_of_mean=$absolute;
                sample_stddev=$std;descriptive_mae=$mae;descriptive_rmse=$rmse;
                relative_error=$(if($eligible -and $values.Count){$absolute/[Math]::Abs($reference)}else{$null});
                error_over_v0=$(if($values.Count){$signed/$v0}else{$null});relative_status=$(if($eligible){'available'}else{'N/A: near-zero reference'})}
            if($n -eq 10000000){
                $limit=.01*[Math]::Max([Math]::Abs($reference),.01*$v0)
                $acceptance += [pscustomobject]@{engine=$engine;confidence=$ref.confidence;scenarios=$n;seed_count=$values.Count;
                    status=$(if($values.Count -eq 5){'evaluated'}else{'incomplete'});allowed_error=$limit;
                    absolute_error_of_mean=$absolute;passed=$(if($values.Count -eq 5){$absolute -le $limit}else{$null})}
            }
        }
    }}
    [pscustomobject]@{schema_version=1;complete=($Records.Count -eq 80);run_count=$Records.Count;value_count=$perSeed.Count;
        missing=@(Get-ConvergenceMissing $Records);fixture=$Fixture;per_seed=$perSeed;groups=$groups;acceptance_10m=$acceptance}
}
