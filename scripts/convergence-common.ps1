Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'gpu-record-common.ps1')
. (Join-Path $PSScriptRoot 'convergence-paths.ps1')

function Get-ConvergenceGrid {
    foreach($engine in @('serial','openmp','full-device','hybrid')){
        foreach($n in @(10000,100000,1000000,10000000)){foreach($seed in @('42','123','456','789','2026')){
            [pscustomobject]@{key="$engine/$n/$seed";engine=$engine;scenarios=$n;seed=$seed;
                requested_batch=$(if($engine -ceq 'hybrid'){65535}else{0});
                effective_batch=$(if($engine -ceq 'hybrid'){[Math]::Min($n,65536)}elseif($engine -ceq 'full-device'){$n}else{0});
                batch_count=$(if($engine -ceq 'hybrid'){[int][Math]::Ceiling($n/65536.0)}elseif($engine -ceq 'full-device'){1}else{0})}
        }}
    }
}
function Get-ConvergenceArtifact($Path) {
    [pscustomobject]@{path=$Path.Replace('\','/');sha256=(Get-GpuHash $Path)}
}
function Read-ConvergenceLines($Path) {
    @(Get-Content -LiteralPath (Resolve-ConvergenceRecordedPath $Path) -Encoding UTF8 | ForEach-Object {if($_.Trim()){$_ | ConvertFrom-Json}})
}
function Assert-ConvergenceJson($Actual,$Expected,$Label) {
    if((ConvertTo-Json -InputObject $Actual -Depth 30 -Compress) -cne
       (ConvertTo-Json -InputObject $Expected -Depth 30 -Compress)){throw "Changed $Label"}
}
function Test-ConvergencePlan($Plan) {
    if($Plan.schema_version -ne 1 -or $Plan.expected_runs -ne 80 -or $Plan.expected_values -ne 160 -or
        $Plan.fixture.sha256 -cne '8dbb7c73e6ad48cb8c8c175aff6684d2a0433e5f08424ec7ea1e69037bb36210' -or
        $Plan.contract -cne 'GBM/double/q=1/T=10/252/nearest-rank/alpha=.95,.99/native') {throw 'Wrong convergence contract'}
    Assert-GpuBoundArtifact $Plan.fixture.path $Plan.fixture.sha256
    $ids=@{}
    foreach($o in $Plan.origins){
        if($ids.ContainsKey($o.id)){throw 'Duplicate origin'};$ids[$o.id]=$o
        foreach($a in $o.artifacts){Assert-GpuBoundArtifact $a.path $a.sha256}
        $m=Read-GpuJson $o.manifest_path
        $revision=if($o.id -ceq 'serial'){$m.git_commit}else{$m.source_revision}
        if($revision -cne $o.source_revision -or $m.status -cne 'completed' -or
            $m.input_sha256 -cne $Plan.fixture.sha256 -or $m.executable_sha256 -cne $o.executable_sha256){throw 'Incompatible origin binding'}
        if((& git rev-parse ($revision+'^{tree}')).Trim() -cne $o.source_tree){throw 'Wrong source tree'}
        if($o.id -in @('small-gpu','acceptance-gpu')){
            foreach($a in $m.record_hashes){
                if($a.file -cne [IO.Path]::GetFileName($a.file)){throw 'Invalid historical artifact path'}
                Assert-GpuBoundArtifact (Join-Path (Split-Path $o.manifest_path) $a.file) $a.sha256
            }
        }
    }
    # Exact reviewed source-to-source comparisons, including additive headers/diagnostics.
    foreach($comparison in $Plan.compatibility){
        $diff=@(& git diff --no-ext-diff $comparison.from $comparison.to -- @($comparison.paths))
        if($LASTEXITCODE -ne 0){throw 'Cannot compare source revisions'}
        Assert-ConvergenceJson $diff @($comparison.diff) 'compatibility diff'
    }
    $grid=@(Get-ConvergenceGrid);$seen=@{}
    foreach($s in $Plan.reuse){
        if($seen.ContainsKey($s.key) -or $s.key -cnotin $grid.key -or -not $ids.ContainsKey($s.origin)){throw 'Duplicate or invalid reuse selection'}
        $seen[$s.key]=$true
        Assert-GpuBoundArtifact $s.path $s.sha256
    }
    $missing=@($grid | Where-Object {-not $seen.ContainsKey($_.key)})
    Assert-ConvergenceJson @($Plan.missing) $missing 'missing matrix'
    if($Plan.reuse.Count -ne 55 -or $missing.Count -ne 25){throw 'Wrong reuse coverage'}
}
function Get-ConvergenceSelectedResult($Selection) {
    if($Selection.line -gt 0){
        $rows=@(Read-ConvergenceLines $Selection.path)
        if($Selection.line -gt $rows.Count){throw 'Missing selected line'}
        $row=$rows[$Selection.line-1]
        if($Selection.origin -ceq 'serial'){
            if($row.phase -cne 'validation' -or $row.index -ne 1){throw 'Non-native validation selection'}
            return $row.result
        }
        if($Selection.origin -ceq 'acceptance-gpu'){
            if($row.exit_code -ne 0 -or $row.timed_out -or $row.error){throw 'Failed historical attempt'}
            return $row.result
        }
        return $row
    }
    Read-GpuJson $Selection.path
}
function Test-ConvergenceResult($Result,$Configuration,$Fixture) {
    $r=$Result;$g=$Configuration
    $backend=if($g.engine -in @('full-device','hybrid')){'cuda'}else{$g.engine}
    $rng=switch($backend){'serial'{'mt19937_64/std::normal_distribution'}
        'openmp'{'block4096/splitmix64/mt19937_64/std::normal_distribution'}
        'cuda'{'cuRAND/PHILOX4_32_10/normal-double'}}
    if($r.schema_version -ne 1 -or $r.application_version -cnotin @('0.2.2','0.3.0') -or
        $r.backend -cne $backend -or $r.random_source -cne $rng -or $r.input_mode -cne 'csv_calibration' -or
        $r.scenarios -ne $g.scenarios -or $r.seed -isnot [string] -or $r.seed -cne $g.seed){throw 'Incompatible native result'}
    if($backend -cne 'serial' -and $r.application_version -cne '0.3.0'){throw 'Wrong native application version'}
    if($backend -ceq 'openmp' -and ($r.requested_threads -ne 4 -or $r.threads_used -ne 4)){throw 'Mixed OpenMP team'}
    if($backend -ceq 'cuda'){
        $c=$r.cuda
        if($c.mode -cne $g.engine -or $c.requested_batch_size -ne $g.requested_batch -or
            $c.effective_batch_size -ne $g.effective_batch -or $c.batch_count -ne $g.batch_count -or
            $c.normals_generated -ne $g.scenarios -or $c.cub_version -ne 300403 -or
            $c.curand_runtime_version -ne 10404 -or $c.nvcc_version -cne '13.4.92' -or
            $c.PSObject.Properties['diagnostics']){throw 'Mixed CUDA mode/batch/library/diagnostics'}
        $hybrid=$g.engine -ceq 'hybrid'
        if($c.host_sorting_used -ne $hybrid -or $c.quantile_location -cne $(if($hybrid){'host'}else{'device'}) -or
            $c.losses_transferred -ne $(if($hybrid){$g.scenarios}else{0}) -or
            $c.host_loss_bytes -ne $(if($hybrid){8*$g.scenarios}else{0})){throw 'Wrong global quantile metadata'}
        if($c.scenario_limit -ne 10000000 -or $c.normals_allocated -ne $g.effective_batch -or
            $c.host_to_device_bytes -ne $(if($hybrid){0}else{16}) -or
            $c.device_to_host_bytes -ne $(if($hybrid){8*$g.scenarios+4*$g.batch_count}else{20})){throw 'Wrong native buffer/transfer accounting'}
        $temporary=Assert-GpuFinite $c.cub_temporary_bytes 'CUB bytes'
        $explicit=Assert-GpuFinite $c.explicit_device_bytes 'device bytes'
        if($temporary -lt 0 -or ($hybrid -and $temporary -ne 0) -or
            $explicit -ne $(if($hybrid){16*$g.effective_batch+4}else{24*$g.scenarios+36+[Math]::Max(1,$temporary)})){throw 'Wrong native allocation accounting'}
    }
    foreach($f in @('initial_value','drift_annual','volatility_annual','horizon_years')){Assert-GpuClose $r.model.$f $Fixture.model.$f "model $f"}
    foreach($f in @('mean_log_return','sample_log_variance','observations','returns_count')){Assert-GpuClose $r.calibration.$f $Fixture.$f "calibration $f"}
    if($r.calibration.date_start -cne $Fixture.date_start -or $r.calibration.date_end -cne $Fixture.date_end -or
        $r.calibration.horizon_trading_days -ne 10 -or $r.calibration.trading_days_per_year -ne 252){throw 'Wrong calibration interval'}
    $time=Assert-GpuFinite $r.end_to_end_ms 'time';if($time -lt 0){throw 'Negative time'}
    if(@($r.estimates).Count -ne 2){throw 'Missing confidence'}
    for($i=0;$i -lt 2;$i++){
        $e=$r.estimates[$i];$ref=$Fixture.references[$i]
        if([double]$e.confidence -ne [double]$ref.confidence){throw 'Wrong confidence'}
        $v=Assert-GpuFinite $e.mc_var 'VaR'
        Assert-GpuClose $e.analytical_var $ref.analytical_var 'reference'
        Assert-GpuClose $e.signed_error ($v-[double]$e.analytical_var) 'raw signed error'
    }
}
function Get-ConvergenceImports($Plan) {
    $origins=@{};foreach($o in $Plan.origins){$origins[$o.id]=$o}
    foreach($s in $Plan.reuse){
        $o=$origins[$s.origin];$r=Get-ConvergenceSelectedResult $s
        if($s.origin -ceq 'acceptance-gpu'){
            $row=@(Read-ConvergenceLines $s.path)[$s.line-1]
            foreach($f in @('source_revision','input_sha256','executable_sha256','build_cache_sha256')){
                $expected=if($f -ceq 'input_sha256'){$Plan.fixture.sha256}else{$o.$f}
                if($row.$f -cne $expected){throw "Historical row binding: $f"}
            }
            $p=Read-GpuJson (Join-Path (Split-Path $s.path) $row.process_record);Assert-GpuProcess $p
            Assert-ConvergenceJson (Read-GpuJson $p.stdout) $r 'historical stdout'
        }
        [pscustomobject]@{key=$s.key;origin=$s.origin;source_revision=$o.source_revision;
            input_sha256=$Plan.fixture.sha256;executable_sha256=$o.executable_sha256;build_cache_sha256=$o.build_cache_sha256;
            selection=$s;result=$r}
    }
}
function Test-ConvergenceRecords($Plan,$Records,$Fixture) {
    $grid=@{};foreach($g in Get-ConvergenceGrid){$grid[$g.key]=$g};$seen=@{}
    $imports=@{};foreach($r in Get-ConvergenceImports $Plan){$imports[$r.key]=$r}
    foreach($r in $Records){
        if($seen.ContainsKey($r.key) -or -not $grid.ContainsKey($r.key)){throw 'Duplicate or extra seed/configuration'};$seen[$r.key]=$true
        if($r.input_sha256 -cne $Plan.fixture.sha256){throw 'Mixed input binding'}
        if($imports.ContainsKey($r.key)){Assert-ConvergenceJson $r $imports[$r.key] 'import provenance/result'}
        else {
            if($r.origin -cne 'new-native' -or $r.key -cnotin $Plan.missing.key){throw 'Unplanned native run'}
            Test-ConvergenceAttempt $r $Plan
        }
        Test-ConvergenceResult $r.result $grid[$r.key] $Fixture
    }
    foreach($key in $imports.Keys){if(-not $seen.ContainsKey($key)){throw 'Missing reusable record'}}
}
function Get-ConvergenceMissing($Records) {
    $keys=@($Records | ForEach-Object {$_.key})
    @(Get-ConvergenceGrid | Where-Object {$_.key -cnotin $keys})
}
function New-ConvergenceDataset($PlanPath,$Records) {
    [pscustomobject]@{schema_version=1;plan_path=$PlanPath;plan_sha256=(Get-GpuHash $PlanPath);
        complete=(@($Records).Count -eq 80);run_count=@($Records).Count;value_count=2*@($Records).Count;records=@($Records)}
}
function Test-ConvergenceDataset($Dataset) {
    if($Dataset.schema_version -ne 1 -or $Dataset.complete -isnot [bool] -or
        $Dataset.complete -ne (@($Dataset.records).Count -eq 80) -or $Dataset.run_count -ne @($Dataset.records).Count -or
        $Dataset.value_count -ne 2*@($Dataset.records).Count){throw 'Incorrect dataset coverage label'}
}
function Get-ConvergenceArguments($Configuration,$FixturePath) {
    $g=$Configuration
    $a=@('--csv',$FixturePath,[string]$g.scenarios,$g.seed,'10','252','--backend','cuda','--cuda-mode',$g.engine)
    if($g.engine -ceq 'hybrid'){$a+=@('--batch-size','65535')};$a+='--json';return $a
}
function Test-ConvergenceAttempt($Record,$Plan) {
    $r=$Record;Assert-GpuBoundArtifact $r.attempt_path $r.attempt_sha256
    $a=Read-GpuJson $r.attempt_path;$b=Read-GpuJson $a.binding_path
    Assert-GpuBoundArtifact $a.binding_path $a.binding_sha256
    Assert-GpuBoundArtifact $b.plan_path $b.plan_sha256
    Assert-ConvergenceJson (Read-GpuJson $b.plan_path) $Plan 'attempt plan'
    if($b.plan_sha256 -cne $r.plan_sha256 -or $b.input_sha256 -cne $Plan.fixture.sha256 -or $r.input_sha256 -cne $b.input_sha256 -or
        $b.source_revision -cne $r.source_revision -or $b.executable_sha256 -cne $r.executable_sha256 -or
        $b.build_cache_sha256 -cne $r.build_cache_sha256 -or $a.key -cne $r.key){throw 'Incompatible new source/build binding'}
    if((& git rev-parse ($b.source_revision+'^{tree}')).Trim() -cne $b.source_tree){throw 'Wrong new source tree'}
    $null=& git diff --exit-code $Plan.reviewed_revision $b.source_revision -- src include data/synthetic_prices.csv
    if($LASTEXITCODE -ne 0){throw 'Unreviewed engine changes'}
    foreach($f in $b.artifacts){Assert-GpuBoundArtifact $f.path $f.sha256}
    Assert-GpuBoundArtifact $b.executable_path $b.executable_sha256
    Assert-GpuBoundArtifact (Join-Path $b.build_directory 'CMakeCache.txt') $b.build_cache_sha256
    Assert-GpuBoundArtifact $b.fixture_path $b.input_sha256
    if($b.clean_source -ne $true){throw 'Unverified new clean source'}
    Test-ConvergencePreflight $b.preflight $b.build_directory
    foreach($path in @($b.configure_process,$b.build_process)){Assert-GpuProcess (Read-GpuJson $path)}
    $configure=Read-GpuJson $b.configure_process
    Assert-ConvergenceJson @($configure.arguments) @('-S','.', '-B',$b.build_directory,'-G','Visual Studio 17 2022','-A','x64','-T','cuda=13.4',
        '-DMC_ENABLE_CUDA=ON','-DMC_ENABLE_OPENMP=ON','-DMC_BUILD_CPU_TOOLS=OFF','-DBUILD_TESTING=ON','-DCMAKE_CUDA_ARCHITECTURES=89') 'configure invocation'
    $build=Read-GpuJson $b.build_process
    Assert-ConvergenceJson @($build.arguments) @('--build',$b.build_directory,'--config','Release','--clean-first','--parallel') 'clean rebuild'
    $cache=[IO.File]::ReadAllText((Join-Path $b.build_directory 'CMakeCache.txt'))
    foreach($flag in @('MC_ENABLE_CUDA:BOOL=ON','MC_ENABLE_OPENMP:BOOL=ON','MC_BUILD_CPU_TOOLS:BOOL=OFF','BUILD_TESTING:BOOL=ON')){
        if($cache -notmatch [regex]::Escape($flag)){throw 'Wrong convergence build flags'}
    }
    foreach($required in @($b.executable_path,(Join-Path $b.build_directory 'CMakeCache.txt'),$b.fixture_path,$b.configure_process,$b.build_process)){
        $full=[IO.Path]::GetFullPath($required)
        if($full -cnotin @($b.artifacts | ForEach-Object {[IO.Path]::GetFullPath($_.path)})){throw 'Unbound required build artifact'}
    }
    foreach($f in $a.artifacts){Assert-GpuBoundArtifact $f.path $f.sha256}
    $requiredAttemptPaths=@($a.process_path,(Read-GpuJson $a.process_path).stdout,(Read-GpuJson $a.process_path).stderr)
    foreach($required in $requiredAttemptPaths){
        if([IO.Path]::GetFullPath($required) -cnotin @($a.artifacts | ForEach-Object {[IO.Path]::GetFullPath($_.path)})){throw 'Unbound required attempt artifact'}
    }
    $p=Read-GpuJson $a.process_path;Assert-GpuProcess $p
    if($a.status -cne 'succeeded' -or $a.error -or $p.executable -cne $b.executable_path -or (Get-Item -LiteralPath $p.stderr).Length -ne 0){throw 'Failed native attempt'}
    $g=@($Plan.missing | Where-Object {$_.key -ceq $r.key})[0]
    Assert-ConvergenceJson @($p.arguments) @(Get-ConvergenceArguments $g $b.fixture_path) 'native argv'
    Assert-ConvergenceJson (Read-GpuJson $p.stdout) $r.result 'native stdout'
}
function Test-ConvergenceAttemptInventory($Directory,$Records) {
    $path=Join-Path $Directory 'attempts.json'
    $attempts=@(Read-GpuJson $path);$seen=@{};$successful=@{}
    foreach($f in $attempts){
        $absolute=[IO.Path]::GetFullPath($f.path)
        if($seen.ContainsKey($absolute)){throw 'Duplicate attempt inventory'};$seen[$absolute]=$true
        Assert-GpuBoundArtifact $f.path $f.sha256;$a=Read-GpuJson $f.path
        foreach($artifact in $a.artifacts){Assert-GpuBoundArtifact $artifact.path $artifact.sha256}
        if($a.status -cnotin @('succeeded','failed','running')){throw 'Invalid attempt status'}
        if($a.status -ceq 'succeeded'){
            if($successful.ContainsKey($a.key)){throw 'Duplicate successful attempts'};$successful[$a.key]=$absolute
        }
    }
    foreach($f in Get-ChildItem -LiteralPath $Directory -File | Where-Object {$_.Name -cmatch '^attempt-\d+\.json$'}){
        if(-not $seen.ContainsKey($f.FullName)){throw 'Unlisted local attempt'}
    }
    foreach($r in $Records){
        if($r.origin -cne 'new-native'){continue}
        if(-not $successful.ContainsKey($r.key) -or $successful[$r.key] -cne [IO.Path]::GetFullPath($r.attempt_path)){throw 'Missing successful attempt'}
        $successful.Remove($r.key)
    }
    if($successful.Count){throw 'Successful attempt omitted from dataset'}
}
function Test-ConvergencePreflight($Preflight,$BuildDirectory) {
    $list=Read-GpuJson $Preflight.discovery_process;Assert-GpuProcess $list
    $regression=Read-GpuJson $Preflight.regression_process;Assert-GpuProcess $regression
    $focused=Read-GpuJson $Preflight.focused_process;Assert-GpuProcess $focused
    $tests=Read-GpuJson $list.stdout
    $count=@($tests.tests).Count
    if($count -lt 1 -or $Preflight.test_count -ne $count){throw 'Wrong discovered regression count'}
    Assert-ConvergenceJson @($list.arguments) @('--test-dir',$BuildDirectory,'-C','Release','--show-only=json-v1') 'test discovery argv'
    Assert-ConvergenceJson @($regression.arguments) @('--test-dir',$BuildDirectory,'-C','Release','--output-on-failure','-V') 'regression argv'
    $log=[IO.File]::ReadAllText((Resolve-ConvergenceRecordedPath $regression.stdout))
    if($log -notmatch ('100% tests passed, 0 tests failed out of '+$count+'\b')){throw 'Regression suite did not pass'}
    $log=[IO.File]::ReadAllText((Resolve-ConvergenceRecordedPath $focused.stdout))
    if($log -notmatch 'Convergence focused tests passed: [1-9][0-9]* checks; no simulation processes'){throw 'Focused suite did not pass'}
}
