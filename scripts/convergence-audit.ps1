. (Join-Path $PSScriptRoot 'convergence-common.ps1')
. (Join-Path $PSScriptRoot 'gpu-acceptance-audit.ps1')
. (Join-Path $PSScriptRoot 'convergence-paths.ps1')
function Get-IndependentConvergenceAnalysis($Records,$Fixture) {
    # No analyzer routines: explicit summation and two-pass sample statistics.
    $seeds=@();$groups=@();$acceptance=@();$v0=[double]$Fixture.model.initial_value
    foreach($engine in @('serial','openmp','full-device','hybrid')){foreach($n in @(10000,100000,1000000,10000000)){
        foreach($ref in $Fixture.references){
            $reference=[double]$ref.analytical_var;$near=[Math]::Abs($reference) -lt .01*$v0
            $values=@();$sum=0.0;$absoluteSum=0.0;$squaredSum=0.0
            foreach($r in $Records){
                if($r.result.scenarios -ne $n -or ($r.key -split '/')[0] -cne $engine){continue}
                foreach($e in $r.result.estimates){
                    if([double]$e.confidence -ne [double]$ref.confidence){continue}
                    $x=Assert-GpuFinite $e.mc_var 'independent VaR';$delta=$x-$reference
                    $values+=$x;$sum+=$x;$absoluteSum+=[Math]::Abs($delta);$squaredSum+=$delta*$delta
                    $seeds += [pscustomobject]@{key=$r.key;confidence=$ref.confidence;mc_var=$x;analytical_var=$reference;
                        signed_error=$delta;absolute_error=[Math]::Abs($delta);relative_error=$(if(-not $near){[Math]::Abs($delta)/[Math]::Abs($reference)}else{$null});
                        error_over_v0=$delta/$v0;relative_status=$(if($near){'N/A: near-zero reference'}else{'available'})}
                }
            }
            $count=$values.Count;$mean=$null;$signed=$null;$absolute=$null;$sd=$null;$mae=$null;$rmse=$null
            if($count -gt 0){
                $mean=$sum/$count;$signed=$mean-$reference;$absolute=[Math]::Abs($signed)
                $varianceSum=0.0;foreach($x in $values){$d=$x-$mean;$varianceSum+=$d*$d}
                if($count -gt 1){$sd=[Math]::Sqrt($varianceSum/($count-1))}
                $mae=$absoluteSum/$count;$rmse=[Math]::Sqrt($squaredSum/$count)
            }
            $groups += [pscustomobject]@{engine=$engine;scenarios=$n;confidence=$ref.confidence;seed_count=$count;complete=($count -eq 5);
                mean_var=$mean;analytical_var=$reference;signed_error_of_mean=$signed;absolute_error_of_mean=$absolute;
                sample_stddev=$sd;descriptive_mae=$mae;descriptive_rmse=$rmse;
                relative_error=$(if(-not $near -and $count){$absolute/[Math]::Abs($reference)}else{$null});
                error_over_v0=$(if($count){$signed/$v0}else{$null});relative_status=$(if($near){'N/A: near-zero reference'}else{'available'})}
            if($n -eq 10000000){
                $allowed=.01*[Math]::Max([Math]::Abs($reference),.01*$v0)
                $acceptance += [pscustomobject]@{engine=$engine;confidence=$ref.confidence;scenarios=$n;seed_count=$count;
                    status=$(if($count -eq 5){'evaluated'}else{'incomplete'});allowed_error=$allowed;
                    absolute_error_of_mean=$absolute;passed=$(if($count -eq 5){$absolute -le $allowed}else{$null})}
            }
        }
    }}
    # Enumerate all expected keys independently, rather than trusting coverage summaries.
    $missing=@()
    foreach($engine in @('serial','openmp','full-device','hybrid')){foreach($n in @(10000,100000,1000000,10000000)){
        foreach($seed in @('42','123','456','789','2026')){
            if("$engine/$n/$seed" -cin @($Records.key)){continue}
            $effective=0;$batches=0;$requested=0
            if($engine -ceq 'full-device'){$effective=$n;$batches=1}
            if($engine -ceq 'hybrid'){$requested=65535;$effective=[Math]::Min(65536,$n);$batches=[int][Math]::Ceiling($n/[double]$effective)}
            $missing += [pscustomobject]@{key="$engine/$n/$seed";engine=$engine;scenarios=$n;seed=$seed;
                requested_batch=$requested;effective_batch=$effective;batch_count=$batches}
        }
    }}
    [pscustomobject]@{schema_version=1;complete=($missing.Count -eq 0);run_count=@($Records).Count;value_count=$seeds.Count;
        missing=$missing;fixture=$Fixture;per_seed=$seeds;groups=$groups;acceptance_10m=$acceptance}
}
function Test-ConvergenceAnalysis($Actual,$Expected) {
    # Recursive structure/null/bool checks; numeric tolerance is rounding-only,
    # never a replacement for the separately calculated acceptance threshold.
    function Compare-ConvergenceValue($a,$e,$label) {
        if($null -eq $e){if($null -ne $a){throw "Expected N/A: $label"};return}
        if($e -is [bool]){if($a -isnot [bool] -or $a -ne $e){throw "Incorrect boolean: $label"};return}
        if($e -is [string]){if($a -isnot [string] -or $a -cne $e){throw "Incorrect label: $label"};return}
        if($e -is [ValueType]){Assert-GpuClose $a $e $label;return}
        if($e -is [array]){
            if($a -isnot [array] -or $a.Count -ne $e.Count){throw "Incorrect array: $label"}
            for($i=0;$i -lt $e.Count;$i++){Compare-ConvergenceValue $a[$i] $e[$i] "$label/$i"};return
        }
        if($null -eq $a -or (@($a.PSObject.Properties.Name) -join ',') -cne (@($e.PSObject.Properties.Name) -join ',')){throw "Incorrect fields: $label"}
        foreach($f in $e.PSObject.Properties.Name){Compare-ConvergenceValue $a.$f $e.$f "$label/$f"}
    }
    Compare-ConvergenceValue $Actual $Expected 'analysis'
}
