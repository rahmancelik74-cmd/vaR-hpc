Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts/convergence-analysis.ps1')
. (Join-Path $root 'scripts/convergence-audit.ps1')
. (Join-Path $root 'scripts/convergence-record.ps1')
$script:checks=0;$script:names=@()
function Check($Name,[scriptblock]$Body){& $Body;$script:checks++;$script:names+=$Name}
function Reject($Name,[scriptblock]$Body){
    $rejected=$false;try{& $Body}catch{$rejected=$true}
    if(-not $rejected){throw "Expected rejection: $Name"};$script:checks++;$script:names+=$Name
}
function Copy-Value($Value){ConvertFrom-Json (ConvertTo-Json -InputObject $Value -Depth 30)}
function Require($Condition,$Label){if(-not $Condition){throw $Label}}
Push-Location $root
try {
    $plan=Read-GpuJson 'evidence/v030-convergence-preparation-20261019/plan.json'
    $fixture=Get-IndependentGpuFixture $plan.fixture.path
    $runs=@(Get-ConvergenceImports $plan)
    Check 'bound plan and all historical record bytes' {Test-ConvergencePlan $plan}
    Check '55 native imports and exact missing matrix' {
        Test-ConvergenceRecords $plan $runs $fixture
        $missing=@(Get-ConvergenceMissing $runs)
        Require ($runs.Count -eq 55 -and $missing.Count -eq 25) 'Wrong coverage'
        Require (@($missing|Where-Object {$_.engine -ceq 'full-device'}).Count -eq 12) 'Full-device matrix'
        Require (@($missing|Where-Object {$_.engine -ceq 'hybrid'}).Count -eq 13) 'Hybrid matrix'
    }
    Check 'independent statistics and calibration on historical imports' {
        $script:a=Get-RecordedConvergenceAnalysis $runs (Get-RecordedConvergenceFixture $plan.fixture.path)
        $script:e=Get-IndependentConvergenceAnalysis $runs $fixture;Test-ConvergenceAnalysis $a $e
        Require (-not $a.complete -and $a.value_count -eq 110 -and $a.acceptance_10m.Count -eq 8) 'False completeness'
    }
    Reject 'missing reusable seed' {Test-ConvergenceRecords $plan @($runs|Select-Object -Skip 1) $fixture}
    Reject 'duplicate seed' {Test-ConvergenceRecords $plan @($runs+$runs[0]) $fixture}
    foreach($field in @('source_revision','input_sha256','executable_sha256','build_cache_sha256')){
        $bad=Copy-Value $runs;$bad[0].$field='changed'
        Reject "incompatible $field" {Test-ConvergenceRecords $plan $bad $fixture}
    }
    $g=@(Get-ConvergenceGrid|Where-Object {$_.key -ceq 'hybrid/100000/42'})[0]
    $native=@($runs|Where-Object {$_.key -ceq $g.key})[0].result
    foreach($change in @(@('mode','full-device'),@('requested_batch_size',65536),@('effective_batch_size',65535),@('batch_count',3),
        @('normals_generated',99999),@('cub_version',300402),@('host_sorting_used',$false),@('losses_transferred',0),@('curand_runtime_version',1),
        @('normals_allocated',65535),@('device_to_host_bytes',0),@('explicit_device_bytes',0),@('cub_temporary_bytes',1))){
        $bad=Copy-Value $native;$bad.cuda.($change[0])=$change[1]
        Reject ('mixed CUDA '+$change[0]) {Test-ConvergenceResult $bad $g $fixture}
    }
    foreach($value in @([double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity,'6.1',$null)){
        $bad=Copy-Value $native;$bad.estimates[0].mc_var=$value
        Reject 'nonfinite or nonnumeric VaR' {Test-ConvergenceResult $bad $g $fixture}
    }
    foreach($field in @('initial_value','drift_annual','volatility_annual','horizon_years')){
        $bad=Copy-Value $native;$bad.model.$field+=.1
        Reject "incompatible model $field" {Test-ConvergenceResult $bad $g $fixture}
    }
    $bad=Copy-Value $native;$bad.random_source='common-input'
    Reject 'common-input excluded' {Test-ConvergenceResult $bad $g $fixture}
    $bad=Copy-Value $native;$bad.estimates=@($bad.estimates[0])
    Reject 'missing confidence' {Test-ConvergenceResult $bad $g $fixture}
    $bad=Copy-Value $native;$bad.estimates[0].signed_error+=1
    Reject 'incorrect raw signed error' {Test-ConvergenceResult $bad $g $fixture}
    $bad=Copy-Value $native;$bad.cuda|Add-Member diagnostics ([pscustomobject]@{enabled=$true})
    Reject 'diagnostic records excluded' {Test-ConvergenceResult $bad $g $fixture}
    $omp=@($runs|Where-Object {$_.key -ceq 'openmp/10000/42'})[0].result
    $bad=Copy-Value $omp;$bad.threads_used=2
    Reject 'mixed OpenMP team' {Test-ConvergenceResult $bad @(Get-ConvergenceGrid)[20] $fixture}
    foreach($field in @('complete','run_count','value_count')){
        $bad=Copy-Value $a
        if($field -ceq 'complete'){$bad.$field=$true}else{$bad.$field++}
        Reject "fabricated $field" {Test-ConvergenceAnalysis $bad $e}
    }
    foreach($field in @('mean_var','signed_error_of_mean','absolute_error_of_mean','sample_stddev','descriptive_mae','descriptive_rmse','relative_error','error_over_v0')){
        $bad=Copy-Value $a;$bad.groups[0].$field+=1
        Reject "incorrect statistic $field" {Test-ConvergenceAnalysis $bad $e}
    }
    $bad=Copy-Value $a;$bad.acceptance_10m[0].allowed_error*=2
    Reject 'acceptance threshold substitution' {Test-ConvergenceAnalysis $bad $e}
    $bad=Copy-Value $a;$bad.acceptance_10m[0].absolute_error_of_mean=$a.groups[6].descriptive_mae
    Reject 'MAE substituted for error of mean' {Test-ConvergenceAnalysis $bad $e}
    $knownFixture=Copy-Value $fixture;$knownFixture.model.initial_value=100.0
    $knownFixture.references[0].analytical_var=10.0;$knownFixture.references[1].analytical_var=0.0
    $known=@();$index=0
    foreach($seed in @('42','123','456','789','2026')){
        $value=@(8.0,9.0,10.0,11.0,12.0)[$index];$index++
        $known += [pscustomobject]@{key="serial/10000000/$seed";result=[pscustomobject]@{scenarios=10000000;estimates=@(
            [pscustomobject]@{confidence=.95;mc_var=$value},[pscustomobject]@{confidence=.99;mc_var=0.0})}}
    }
    Check 'known cancellation, sample variance, MAE and RMSE' {
        $script:k=Get-RecordedConvergenceAnalysis $known $knownFixture
        $ke=Get-IndependentConvergenceAnalysis $known $knownFixture;Test-ConvergenceAnalysis $k $ke
        $s=$k.groups[6]
        Require ($s.mean_var -eq 10 -and $s.absolute_error_of_mean -eq 0 -and $s.descriptive_mae -eq 1.2) 'Cancellation'
        Assert-GpuClose $s.sample_stddev ([Math]::Sqrt(2.5)) 'sample stddev'
        Assert-GpuClose $s.descriptive_rmse ([Math]::Sqrt(2)) 'RMSE'
        Require ($k.acceptance_10m[0].passed -and $s.descriptive_mae -gt $k.acceptance_10m[0].allowed_error) 'Wrong acceptance formula'
    }
    Check 'near-zero reference N/A, raw zero, V0 error and acceptance floor' {
        Require ($null -eq $k.groups[7].relative_error -and $k.groups[7].error_over_v0 -eq 0) 'Near-zero normalization'
        Require ($k.per_seed[5].mc_var -eq 0 -and $k.per_seed[5].absolute_error -eq 0) 'Raw zero changed'
        Require ($k.acceptance_10m[1].allowed_error -eq .01) 'Acceptance floor'
    }
    Check 'singleton standard deviation and incomplete acceptance are N/A' {
        $single=Get-RecordedConvergenceAnalysis @($known[0]) $knownFixture
        Require ($null -eq $single.groups[6].sample_stddev -and $null -eq $single.acceptance_10m[0].passed -and
            $single.acceptance_10m[0].status -ceq 'incomplete' -and -not $single.complete) 'Partial coverage'
    }
    Check 'negative reference and VaR remain signed; normalization uses absolute reference' {
        $negative=Copy-Value $known;$negativeFixture=Copy-Value $knownFixture
        $negativeFixture.references[0].analytical_var=-10.0
        foreach($r in $negative){$r.result.estimates[0].mc_var=-$r.result.estimates[0].mc_var}
        $result=Get-RecordedConvergenceAnalysis $negative $negativeFixture
        Test-ConvergenceAnalysis $result (Get-IndependentConvergenceAnalysis $negative $negativeFixture)
        Require ($result.groups[6].mean_var -eq -10 -and $result.per_seed[0].mc_var -eq -8 -and $result.per_seed[0].relative_error -eq .2) 'Negative VaR changed'
    }
    $dataset=New-ConvergenceDataset 'evidence/v030-convergence-preparation-20261019/plan.json' $runs
    Check 'dataset explicitly labels incomplete coverage' {Test-ConvergenceDataset $dataset;Require (-not $dataset.complete) 'False dataset label'}
    $bad=Copy-Value $dataset;$bad.complete=$true
    Reject 'fabricated dataset completeness' {Test-ConvergenceDataset $bad}
    $tmp=Join-Path $root ('results/convergence-tests-'+[Guid]::NewGuid().ToString('N'))
    $null=New-Item -ItemType Directory -Path $tmp
    [IO.File]::WriteAllText((Join-Path $tmp 'bytes.txt'),"line`r`n")
    $hash=Get-GpuHash (Join-Path $tmp 'bytes.txt')
    [IO.File]::WriteAllText((Join-Path $tmp 'bytes.txt'),"line`n")
    Reject 'exact-byte CRLF corruption' {Assert-GpuBoundArtifact (Join-Path $tmp 'bytes.txt') $hash}
    $bad=Copy-Value $plan;$bad.origins[0].source_revision=$plan.origins[1].source_revision
    Reject 'incompatible plan source' {Test-ConvergencePlan $bad}
    $bad=Copy-Value $plan;$bad.missing=$bad.missing|Select-Object -Skip 1
    Reject 'missing matrix tampering' {Test-ConvergencePlan $bad}
    $bad=Copy-Value $plan;$bad.reuse+= $bad.reuse[0]
    Reject 'duplicate imports in plan' {Test-ConvergencePlan $bad}
    $bad=Copy-Value $plan;$bad.origins[0].artifacts[0].sha256='bad'
    Reject 'corrupted historical artifact' {Test-ConvergencePlan $bad}
    # Fake processes emit JSON only. No simulation executable is invoked.
    $script:launched=@();$script:failAt=0;$script:failureKind='exit'
    function Get-GpuSourceChanges { @() }
    function Invoke-GpuProcess($Executable,[string[]]$Arguments,$Prefix,[int]$TimeoutSeconds=600){
        $script:launched+= ,$Arguments
        $n=[int]$Arguments[2];$seed=$Arguments[3];$mode=$Arguments[9]
        $result=Copy-Value $native;$result.scenarios=$n;$result.seed=$seed;$result.cuda.mode=$mode
        $result.cuda.requested_batch_size=$(if($mode -ceq 'hybrid'){65535}else{0})
        $result.cuda.effective_batch_size=$(if($mode -ceq 'hybrid'){[Math]::Min(65536,$n)}else{$n})
        $result.cuda.batch_count=$(if($mode -ceq 'hybrid'){[int][Math]::Ceiling($n/65536.0)}else{1})
        $result.cuda.normals_generated=$n;$result.cuda.host_sorting_used=($mode -ceq 'hybrid')
        $result.cuda.quantile_location=$(if($mode -ceq 'hybrid'){'host'}else{'device'})
        $result.cuda.host_loss_bytes=$(if($mode -ceq 'hybrid'){8*$n}else{0})
        $result.cuda.losses_transferred=$(if($mode -ceq 'hybrid'){$n}else{0})
        $result.cuda.normals_allocated=$result.cuda.effective_batch_size
        $result.cuda.host_to_device_bytes=$(if($mode -ceq 'hybrid'){0}else{16})
        $result.cuda.device_to_host_bytes=$(if($mode -ceq 'hybrid'){8*$n+4*$result.cuda.batch_count}else{20})
        $result.cuda.cub_temporary_bytes=$(if($mode -ceq 'hybrid'){0}else{1})
        $result.cuda.explicit_device_bytes=$(if($mode -ceq 'hybrid'){16*$result.cuda.effective_batch_size+4}else{24*$n+37})
        Write-GpuJson ($Prefix+'.stdout.txt') $result;[IO.File]::WriteAllText(($Prefix+'.stderr.txt'),'')
        $fail=$script:failAt -eq $script:launched.Count
        if($fail -and $script:failureKind -ceq 'malformed'){[IO.File]::WriteAllText(($Prefix+'.stdout.txt'),'invalid JSON')}
        if($fail -and $script:failureKind -ceq 'stderr'){[IO.File]::WriteAllText(($Prefix+'.stderr.txt'),'unexpected diagnostics')}
        $process=[pscustomobject]@{executable=$Executable;arguments=$Arguments;stdout=$Prefix+'.stdout.txt';stderr=$Prefix+'.stderr.txt';
            exit_code=$(if($fail -and $script:failureKind -ceq 'exit'){7}else{0});
            timed_out=($fail -and $script:failureKind -ceq 'timeout');start_error=$(if($fail -and $script:failureKind -ceq 'start'){'Mock start failure'}else{$null})}
        Write-GpuJson ($Prefix+'.process.json') $process;return $process
    }
    $mockBuild=Join-Path $tmp 'mock-build';$null=New-Item -ItemType Directory -Path $mockBuild
    $mockExe=Join-Path $mockBuild 'mock-only.txt';[IO.File]::WriteAllText($mockExe,'Mock only; never executed')
    $mockCache=Join-Path $mockBuild 'CMakeCache.txt'
    [IO.File]::WriteAllText($mockCache,"MC_ENABLE_CUDA:BOOL=ON`nMC_ENABLE_OPENMP:BOOL=ON`nMC_BUILD_CPU_TOOLS:BOOL=OFF`nBUILD_TESTING:BOOL=ON`n")
    foreach($step in @('configure','build')){
        $argv=if($step -ceq 'build'){@('--build',$mockBuild,'--config','Release','--clean-first','--parallel')}else{
            @('-S','.', '-B',$mockBuild,'-G','Visual Studio 17 2022','-A','x64','-T','cuda=13.4',
                '-DMC_ENABLE_CUDA=ON','-DMC_ENABLE_OPENMP=ON','-DMC_BUILD_CPU_TOOLS=OFF','-DBUILD_TESTING=ON','-DCMAKE_CUDA_ARCHITECTURES=89')}
        Write-GpuJson (Join-Path $mockBuild ($step+'.process.json')) ([pscustomobject]@{executable='mock-cmake';arguments=$argv;exit_code=0;timed_out=$false;start_error=$null})
    }
    $b=[pscustomobject]@{executable_path=$mockExe;fixture_path=(Resolve-Path $plan.fixture.path).Path;source_revision=(& git rev-parse HEAD).Trim();
        source_tree=(& git rev-parse 'HEAD^{tree}').Trim();clean_source=$true;build_directory=$mockBuild;
        configure_process=(Join-Path $mockBuild 'configure.process.json');build_process=(Join-Path $mockBuild 'build.process.json');
        input_sha256=$plan.fixture.sha256;executable_sha256=(Get-GpuHash $mockExe);build_cache_sha256=(Get-GpuHash $mockCache);
        plan_path='evidence/v030-convergence-preparation-20261019/plan.json';
        plan_sha256=(Get-GpuHash 'evidence/v030-convergence-preparation-20261019/plan.json');artifacts=@()}
    $b.artifacts=@(@($mockExe,$mockCache,$b.fixture_path,$b.configure_process,$b.build_process)|ForEach-Object {Get-ConvergenceArtifact $_})
    foreach($step in @('test-list','ctest','focused')){
        $prefix=Join-Path $mockBuild $step
        $argv=if($step -ceq 'test-list'){@('--test-dir',$mockBuild,'-C','Release','--show-only=json-v1')}elseif($step -ceq 'ctest'){@('--test-dir',$mockBuild,'-C','Release','--output-on-failure','-V')}else{@()}
        $log=switch($step){'test-list'{'{"tests":[{"name":"mock-unit"}]}'}'ctest'{'100% tests passed, 0 tests failed out of 1'}'focused'{'Convergence focused tests passed: 1 checks; no simulation processes'}}
        [IO.File]::WriteAllText(($prefix+'.stdout.txt'),$log)
        [IO.File]::WriteAllText(($prefix+'.stderr.txt'),'')
        Write-GpuJson ($prefix+'.process.json') ([pscustomobject]@{executable='mock-preflight';arguments=$argv;
            stdout=$prefix+'.stdout.txt';stderr=$prefix+'.stderr.txt';exit_code=0;timed_out=$false;start_error=$null})
    }
    $b|Add-Member preflight ([pscustomobject]@{test_count=1;discovery_process=(Join-Path $mockBuild 'test-list.process.json');
        regression_process=(Join-Path $mockBuild 'ctest.process.json');focused_process=(Join-Path $mockBuild 'focused.process.json')})
    $b.artifacts+=@(Get-ChildItem -LiteralPath $mockBuild -File|Where-Object {$_.Name -match '^(test-list|ctest|focused)\.'}|ForEach-Object {Get-ConvergenceArtifact $_.FullName})
    Write-GpuJson (Join-Path $tmp 'binding.json') $b
    Check 'mock recorder executes exactly 25 missing configurations once each' {
        $script:completed=@(Invoke-ConvergenceMissing $plan $runs (Join-Path $tmp 'binding.json') $tmp)
        Require ($completed.Count -eq 80 -and $script:launched.Count -eq 25) 'Execution coverage'
        $keys=@($completed|ForEach-Object {$_.key}|Sort-Object -Unique);Require ($keys.Count -eq 80) 'Duplicate mock runs'
        Test-ConvergenceAttemptInventory $tmp $completed
        $final=Get-RecordedConvergenceAnalysis $completed $fixture;Require ($final.complete -and $final.value_count -eq 160) 'Complete coverage'
    }
    Check 'complete dataset launches zero further processes' {
        $again=@(Invoke-ConvergenceMissing $plan $completed (Join-Path $tmp 'binding.json') $tmp)
        Require ($again.Count -eq 80 -and $script:launched.Count -eq 25) 'Unexpected rerun'
    }
    Check 'mock successful attempt independently binds raw stdout, argv, source, build and input' {
        Test-ConvergenceAttempt $completed[55] $plan
    }
    foreach($field in @('source_revision','input_sha256','executable_sha256','build_cache_sha256','plan_sha256')){
        $bad=Copy-Value $completed[55];$bad.$field='changed'
        Reject "new attempt incompatible $field" {Test-ConvergenceAttempt $bad $plan}
    }
    $rawPath=(Read-GpuJson (Read-GpuJson $completed[55].attempt_path).process_path).stdout
    $rawBytes=[IO.File]::ReadAllBytes($rawPath);[IO.File]::AppendAllText($rawPath,'corrupted')
    Reject 'new raw output corruption' {Test-ConvergenceAttempt $completed[55] $plan}
    [IO.File]::WriteAllBytes($rawPath,$rawBytes)
    $originalBindingBytes=[IO.File]::ReadAllBytes((Join-Path $tmp 'binding.json'))
    foreach($field in @('source_tree','clean_source')){
        $changed=Copy-Value $b
        if($field -ceq 'clean_source'){$changed.$field=$false}else{$changed.$field='bad'}
        Write-GpuJson (Join-Path $tmp 'binding.json') $changed
        $changedAttempt=Read-GpuJson $completed[55].attempt_path;$changedAttempt.binding_sha256=Get-GpuHash (Join-Path $tmp 'binding.json')
        $testAttempt=Join-Path $tmp 'changed-attempt.json';Write-GpuJson $testAttempt $changedAttempt
        $changedRecord=Copy-Value $completed[55];$changedRecord.attempt_path=$testAttempt;$changedRecord.attempt_sha256=Get-GpuHash $testAttempt
        Reject "new build $field" {Test-ConvergenceAttempt $changedRecord $plan}
    }
    [IO.File]::WriteAllBytes((Join-Path $tmp 'binding.json'),$originalBindingBytes)
    $failedDir=Join-Path $tmp 'failure';$null=New-Item -ItemType Directory -Path $failedDir
    $script:launched=@();$script:failAt=2
    Reject 'mock nonzero exit stops recorder' {Invoke-ConvergenceMissing $plan $runs (Join-Path $tmp 'binding.json') $failedDir}
    Check 'failed attempt and prior success retained; remaining matrix shrinks by one' {
        $script:partial=Read-GpuJson (Join-Path $failedDir 'dataset.json')
        Require ($partial.records.Count -eq 56 -and $script:launched.Count -eq 2) 'Failure flow'
        Test-ConvergenceAttemptInventory $failedDir @($partial.records)
        Require (@(Get-ConvergenceMissing $partial.records).Count -eq 24) 'Resume matrix'
        Require ((Read-GpuJson (Join-Path $failedDir 'attempt-002.json')).status -ceq 'failed') 'Lost failure'
    }
    [IO.File]::WriteAllText((Join-Path $failedDir 'attempt-003.json'),'{}')
    Reject 'unlisted attempt rejected' {Test-ConvergenceAttemptInventory $failedDir @($partial.records)}
    foreach($kind in @('timeout','start','malformed','stderr')){
        $script:launched=@();$script:failAt=1;$script:failureKind=$kind
        $failure=Join-Path $tmp $kind;$null=New-Item -ItemType Directory -Path $failure
        Reject "mock $kind attempt stops and retains failure" {Invoke-ConvergenceMissing $plan $runs (Join-Path $tmp 'binding.json') $failure}
        $d=Read-GpuJson (Join-Path $failure 'dataset.json')
        Check "mock $kind does not count as observation" {
            Require ($d.run_count -eq 55 -and -not $d.complete -and $script:launched.Count -eq 1) 'Failed process counted'
            Test-ConvergenceAttemptInventory $failure @($d.records)
        }
    }
    Check 'legacy paths resolve under current root without modifying plan bytes' {
        $legacy=$script:ConvergenceFormerRoot+'\data\synthetic_prices.csv'
        Require ((Resolve-ConvergenceRecordedPath $legacy) -ceq (Join-Path $root 'data\synthetic_prices.csv')) 'Wrong relocation'
        Require ((Get-GpuHash $legacy) -ceq $plan.fixture.sha256) 'Wrong relocated fixture bytes'
    }
    Reject 'legacy path traversal rejected' {Resolve-ConvergenceRecordedPath ($script:ConvergenceFormerRoot+'\..\outside.txt')}
    Reject 'wrong preflight discovery count rejected' {
        $bad=Copy-Value $b.preflight;$bad.test_count=2;Test-ConvergencePreflight $bad $mockBuild
    }
    $preflightLog=Join-Path $mockBuild 'ctest.stdout.txt';$saved=[IO.File]::ReadAllBytes($preflightLog)
    [IO.File]::WriteAllText($preflightLog,'0% tests passed, 1 tests failed out of 1')
    Reject 'failed regressions prevent native acceptance' {Test-ConvergencePreflight $b.preflight $mockBuild}
    [IO.File]::WriteAllBytes($preflightLog,$saved)
    $bad=Copy-Value $completed[55];$at=Read-GpuJson $bad.attempt_path;$at.artifacts=@()
    $unbound=Join-Path $tmp 'unbound-attempt.json';Write-GpuJson $unbound $at;$bad.attempt_path=$unbound;$bad.attempt_sha256=Get-GpuHash $unbound
    Reject 'unbound raw attempt outputs rejected' {Test-ConvergenceAttempt $bad $plan}
    $report=[pscustomobject]@{status='passed';checks=$script:checks;test_names=$script:names;
        simulation_processes=0;mock_success_processes=25;mock_failure_flow_processes=6;artifacts=$tmp}
    Write-GpuJson (Join-Path $tmp 'test-results.json') $report
    Write-Host ("Convergence focused tests passed: $($script:checks) checks; no simulation processes; $tmp")
}finally{Pop-Location}
