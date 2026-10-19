. (Join-Path $PSScriptRoot 'convergence-common.ps1')
. (Join-Path $PSScriptRoot 'gpu-acceptance-audit.ps1')
. (Join-Path $PSScriptRoot 'convergence-paths.ps1')
function Invoke-ConvergenceMissing($Plan,$Records,$BindingPath,$Directory) {
    $binding=Read-GpuJson $BindingPath;$bindingHash=Get-GpuHash $BindingPath
    $all=@($Records);$attempts=@();$sequence=0
    foreach($g in @(Get-ConvergenceMissing $all)){
        if($g.key -cnotin $Plan.missing.key){throw 'Execution outside missing matrix'}
        $sequence++;$prefix=Join-Path $Directory ('attempt-{0:D3}' -f $sequence)
        if(Test-Path -LiteralPath ($prefix+'.json')){throw 'Attempt overwrite refused'}
        $a=[ordered]@{key=$g.key;status='running';error=$null;binding_path=$BindingPath;binding_sha256=$bindingHash;
            process_path=$prefix+'.process.json';artifacts=@()}
        Write-GpuJson ($prefix+'.json') $a
        try {
            foreach($f in $binding.artifacts){Assert-GpuBoundArtifact $f.path $f.sha256}
            $process=Invoke-GpuProcess $binding.executable_path @(Get-ConvergenceArguments $g $binding.fixture_path) $prefix
            Assert-GpuProcess $process
            if((Get-Item -LiteralPath $process.stderr).Length){throw 'Unexpected native stderr'}
            $result=Read-GpuJson $process.stdout
            # Validate immediately; failed/malformed attempts never become observations.
            Test-ConvergenceResult $result $g (Get-IndependentGpuFixture $binding.fixture_path)
            foreach($f in $binding.artifacts){Assert-GpuBoundArtifact $f.path $f.sha256}
            if((& git rev-parse HEAD).Trim() -cne $binding.source_revision -or @(Get-GpuSourceChanges).Count){throw 'Source changed during recording'}
            $a.status='succeeded'
        }catch{$a.status='failed';$a.error=$_.Exception.Message}
        finally {
            foreach($suffix in @('.stdout.txt','.stderr.txt','.process.json')){
                if(Test-Path -LiteralPath ($prefix+$suffix)){$a.artifacts+=Get-ConvergenceArtifact ($prefix+$suffix)}
            }
            Write-GpuJson ($prefix+'.json') $a;$attempts+=Get-ConvergenceArtifact ($prefix+'.json')
            Write-GpuJson (Join-Path $Directory 'attempts.json') $attempts
        }
        if($a.status -ceq 'succeeded'){
            $all += [pscustomobject]@{key=$g.key;origin='new-native';source_revision=$binding.source_revision;
                input_sha256=$binding.input_sha256;executable_sha256=$binding.executable_sha256;build_cache_sha256=$binding.build_cache_sha256;
                attempt_path=$prefix+'.json';attempt_sha256=(Get-GpuHash ($prefix+'.json'));plan_sha256=$binding.plan_sha256;result=$result}
        }
        Write-GpuJson (Join-Path $Directory 'dataset.json') (New-ConvergenceDataset $binding.plan_path $all)
        # Stop on first failure; keep all files, including a completed partial dataset.
        if($a.status -cne 'succeeded'){throw ('Native attempt failed; retained at '+$prefix+': '+$a.error)}
    }
    return $all
}
