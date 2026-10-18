[CmdletBinding()]
param([string]$OutputDirectory='', [switch]$IncludeScaleChecks, [switch]$IncludeHybridChecks,
      [ValidateRange(1,10000000)][int]$HybridBatchSize=65535)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'cpu-benchmark-common.ps1')
$utf8=[Text.UTF8Encoding]::new($false)
function Get-SourceChanges {
    $status=@(& git status --porcelain --untracked-files=normal)
    if($LASTEXITCODE -ne 0){throw 'Cannot inspect source status'}
    # Only these deliberately private, untracked paths are outside the source check.
    return @($status | Where-Object {$_ -cne '?? AGENTS.md' -and $_ -cne '?? output/'})
}
function Check-Common($Common, $RequiredSizes) {
    if(-not $Common.invalid_input_and_recovery_checks_passed){throw 'Incomplete common-input checks'}
    foreach($n in $RequiredSizes){
        if(@($Common.cases | Where-Object {$_.scenarios -eq $n}).Count -eq 0){throw "Missing common-input size $n"}
    }
    foreach($case in $Common.cases){
        if(-not $case.passed -or [double]$case.absolute_difference -gt [double]$case.tolerance -or
            [double]$case.absolute_difference -gt [double]$case.project_tolerance){throw 'Common-input numerical tolerance exceeded'}
    }
}
function Tool($Command,$Arguments,$Log){
    $captured=@(& $Command @Arguments 2>&1);$code=$LASTEXITCODE
    $text=($captured | Out-String).Replace($root,'<SOURCE>').Replace($root.Replace('\','/'),'<SOURCE>')
    $text=$text.Replace($env:USERPROFILE,'<USER>').Replace($env:USERPROFILE.Replace('\','/'),'<USER>')
    if($text -match '(?m)^\.NET Framework.*MSBuild'){
        $native=Join-Path $out ($Log+'.native.txt');[IO.File]::WriteAllText($native,$text,$utf8)
        $text='English transcription: only localized MSBuild banner replaced. Capture SHA-256: '+(Get-CpuHash $native)+"`n"+
            [regex]::Replace($text,'(?m)^\.NET Framework.*MSBuild[^\r\n]*','.NET Framework MSBuild')
    }
    [IO.File]::WriteAllText((Join-Path $out $Log),$text,$utf8)
    if($code -ne 0){throw "$Command failed; see $Log"}
}
function Sample($Count,$Seed){
    $raw=@(& $exe --csv data/synthetic_prices.csv $Count $Seed 10 252 --backend cuda --json) -join "`n"
    if($LASTEXITCODE -ne 0){throw 'CUDA CSV smoke failed'}
    $run=$raw | ConvertFrom-Json
    if($run.schema_version -ne 1 -or $run.backend -ne 'cuda' -or $run.scenarios -ne $Count -or
        $run.seed -cne $Seed -or $run.input_mode -ne 'csv_calibration' -or
        $run.random_source -ne 'cuRAND/PHILOX4_32_10/normal-double' -or $run.cuda.host_sorting_used -ne $false -or
        $run.cuda.milestone -cne 'full_device_scale_up' -or $run.cuda.scenario_limit -ne 10000000 -or
        $run.cuda.explicit_device_bytes -gt $run.cuda.allocation_budget_limit_bytes -or
        $run.cuda.device -notlike '*RTX 4060 Laptop*' -or $run.cuda.cub_version -le 0 -or
        $run.cuda.curand_runtime_version -le 0 -or $run.cuda.normals_allocated -ne ($Count+$Count%2) -or
        $run.cuda.host_to_device_bytes -ne 16 -or $run.cuda.device_to_host_bytes -ne 20 -or
        @($run.estimates).Count -ne 2 -or [double]$run.estimates[0].confidence -ne .95 -or
        [double]$run.estimates[1].confidence -ne .99){throw 'Unexpected CUDA smoke metadata'}
    foreach($estimate in $run.estimates){if([double]::IsNaN([double]$estimate.mc_var) -or
        [double]::IsInfinity([double]$estimate.mc_var)){throw 'Nonfinite native quantile'}}
    [IO.File]::WriteAllText((Join-Path $out "native-N$Count.json"),$raw+"`n",$utf8)
    return $run
}
function HybridSample($Count,$Seed){
    $raw=@(& $exe --csv data/synthetic_prices.csv $Count $Seed 10 252 --backend cuda --cuda-mode hybrid --batch-size $HybridBatchSize --json) -join "`n"
    if($LASTEXITCODE -ne 0){throw 'Hybrid CUDA synthetic check failed'}
    $run=$raw | ConvertFrom-Json
    $effective=[Math]::Min($Count,$HybridBatchSize+$HybridBatchSize%2)
    $batches=[long][Math]::Ceiling($Count/[double]$effective)
    if($run.backend -cne 'cuda' -or $run.scenarios -ne $Count -or $run.seed -cne $Seed -or
        $run.input_mode -cne 'csv_calibration' -or $run.random_source -cne 'cuRAND/PHILOX4_32_10/normal-double' -or
        $run.cuda.mode -cne 'hybrid' -or $run.cuda.quantile_location -cne 'host' -or -not $run.cuda.host_sorting_used -or
        $run.cuda.requested_batch_size -ne $HybridBatchSize -or $run.cuda.effective_batch_size -ne $effective -or
        $run.cuda.batch_count -ne $batches -or $run.cuda.losses_transferred -ne $Count -or
        $run.cuda.normals_generated -ne ($Count+$Count%2) -or $run.cuda.host_to_device_bytes -ne 0 -or
        $run.cuda.device_to_host_bytes -ne (8*$Count+4*$batches) -or $run.cuda.cub_temporary_bytes -ne 0 -or
        $run.cuda.explicit_device_bytes -gt $run.cuda.allocation_budget_limit_bytes){throw 'Hybrid metadata/accounting mismatch'}
    foreach($estimate in $run.estimates){if([double]::IsNaN([double]$estimate.mc_var) -or
        [double]::IsInfinity([double]$estimate.mc_var)){throw 'Nonfinite hybrid quantile'}}
    [IO.File]::WriteAllText((Join-Path $out "hybrid-native-N$Count.json"),$raw+"`n",$utf8)
    return $run
}
function Read-DisplayDriver{
    $key=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}')
    try{
        foreach($name in $key.GetSubKeyNames()){
            if($name -notmatch '^[0-9]{4}$'){continue}
            $adapter=$key.OpenSubKey($name)
            try{
                if([string]$adapter.GetValue('ProviderName') -like '*NVIDIA*'){
                    [pscustomobject]@{DriverDesc=[string]$adapter.GetValue('DriverDesc');DriverVersion=[string]$adapter.GetValue('DriverVersion');DriverDate=[string]$adapter.GetValue('DriverDate')}
                }
            }finally{$adapter.Dispose()}
        }
    }finally{$key.Dispose()}
}
Push-Location -LiteralPath $root
try{
    $revision=(& git rev-parse HEAD | Out-String).Trim()
    if($LASTEXITCODE -ne 0 -or @(Get-SourceChanges).Count -ne 0){throw 'A clean source commit is required (only untracked AGENTS.md and output/ are excluded)'}
    if(-not $OutputDirectory){$OutputDirectory='results/cuda-skeleton-'+(Get-Date -Format 'yyyyMMdd-HHmmss')}
    if(-not [IO.Path]::IsPathRooted($OutputDirectory)){$OutputDirectory=Join-Path $root $OutputDirectory}
    $OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
    $resultsRoot=[IO.Path]::GetFullPath((Join-Path $root 'results'))+[IO.Path]::DirectorySeparatorChar
    if(-not $OutputDirectory.StartsWith($resultsRoot,[StringComparison]::OrdinalIgnoreCase)){
        throw 'Recorder output must be a new directory below ignored results/'
    }
    if(Test-Path -LiteralPath $OutputDirectory){throw 'Output directory already exists'}
    $out=(New-Item -ItemType Directory -Path $OutputDirectory).FullName
    $manifest=[ordered]@{
        schema_version=1;purpose='CUDA full-device implementation checks; no statistical acceptance or benchmark';status='running'
        source_revision=$revision;clean_source=$true;started_utc=[DateTime]::UtcNow.ToString('o')
        source_tree=(& git rev-parse 'HEAD^{tree}').Trim()
        source_status_exclusions=@('untracked AGENTS.md','untracked output/')
        source_to_binary='Clean-first Windows x64 Release rebuild in this invocation'
        input='data/synthetic_prices.csv';input_sha256=(Get-CpuHash 'data/synthetic_prices.csv')
        build='build-cuda-skeleton';cuda_architectures='89';generator='Visual Studio 17 2022';toolset='cuda=13.4'
        quantile_library='Toolkit CUB DeviceRadixSort<double> and device nearest-rank gather'
        host_sorting_used=$false;scenario_limit=10000000;common_input_and_native_runs_separate=$true
        full_scale_acceptance=$false;performance_benchmark=$false
    }
    Write-CpuJson (Join-Path $out 'manifest.json') $manifest
    try{
        Tool 'cmake' @('-S','.', '-B','build-cuda-skeleton','-G','Visual Studio 17 2022','-A','x64','-T','cuda=13.4',
            '-DMC_ENABLE_CUDA=ON','-DMC_ENABLE_OPENMP=ON','-DMC_BUILD_CPU_TOOLS=OFF','-DBUILD_TESTING=ON',
            '-DCMAKE_CUDA_ARCHITECTURES=89') 'configure-cuda.log'
        Tool 'cmake' @('--build','build-cuda-skeleton','--config','Release','--clean-first','--parallel') 'build-cuda.log'
        Tool 'ctest' @('--test-dir','build-cuda-skeleton','-C','Release','--show-only=json-v1') 'test-list-cuda.json'
        Tool 'ctest' @('--test-dir','build-cuda-skeleton','-C','Release','-V','--output-on-failure') 'ctest-cuda.log'
        foreach($openmp in @('ON','OFF')){
            $build='build-cuda-disabled-'+$openmp.ToLowerInvariant()
            Tool 'cmake' @('-S','.', '-B',$build,'-G','Visual Studio 17 2022','-A','x64',
                '-DMC_ENABLE_CUDA=OFF',"-DMC_ENABLE_OPENMP=$openmp",'-DMC_BUILD_CPU_TOOLS=OFF','-DBUILD_TESTING=ON') "configure-cpu-$openmp.log"
            Tool 'cmake' @('--build',$build,'--config','Release','--clean-first','--parallel') "build-cpu-$openmp.log"
            Tool 'ctest' @('--test-dir',$build,'-C','Release','--show-only=json-v1') "test-list-cpu-$openmp.json"
            Tool 'ctest' @('--test-dir',$build,'-C','Release','-V','--output-on-failure') "ctest-cpu-$openmp.log"
        }
        $exe=Join-Path $root 'build-cuda-skeleton/Release/mc_var.exe'
        $testExe=Join-Path $root 'build-cuda-skeleton/Release/mc_cuda_tests.exe'
        $manifest['executable_sha256']=Get-CpuHash $exe
        $manifest['test_executable_sha256']=Get-CpuHash $testExe
        $buildArtifacts=@()
        foreach($build in @('build-cuda-skeleton','build-cuda-disabled-on','build-cuda-disabled-off')){
            foreach($file in @('CMakeCache.txt','Release/mc_var.exe')){
                $path=Join-Path $build $file
                $buildArtifacts += [pscustomobject]@{path=$path;sha256=(Get-CpuHash $path)}
            }
            Copy-Item -LiteralPath (Join-Path $build 'CMakeCache.txt') -Destination (Join-Path $out ($build+'-CMakeCache.txt'))
        }
        $manifest['build_artifacts']=$buildArtifacts
        $manifest['compiler_settings']=@(Get-Content 'build-cuda-skeleton/CMakeCache.txt' | Where-Object {
            $_ -match '^(CMAKE_(CUDA|CXX)_FLAGS[^:]*|CMAKE_CUDA_ARCHITECTURES|CMAKE_GENERATOR[^:]*|MC_ENABLE_CUDA|MC_ENABLE_OPENMP):'
        } | ForEach-Object {$_.ToString()})
        $manifest['cuda_target_options']=@('--fmad=false','-Xcompiler=/Zc:preprocessor','CUDA standard 17','CUDA_RUNTIME_LIBRARY=Shared')
        $manifest['compiler_identification']=@(Get-ChildItem 'build-cuda-skeleton/CMakeFiles/*/CMake*Compiler.cmake' |
            ForEach-Object {Get-Content -LiteralPath $_.FullName} | Where-Object {
                $_ -match '^set\(CMAKE_(CUDA|CXX)_(COMPILER_ID|COMPILER_VERSION|HOST_COMPILER_ID|HOST_COMPILER_VERSION) '
            } | ForEach-Object {$_.ToString()})
        Tool 'nvcc' @('--version') 'nvcc-version.log'
        # Inspect adapter records only, not the protected class Properties key.
        $manifest['windows_driver']=@(Read-DisplayDriver)
        $libraries=@()
        foreach($dll in @('cudart64_13.dll','curand64_10.dll')){
            $path=Join-Path (Split-Path -Parent $exe) $dll
            $version=[Diagnostics.FileVersionInfo]::GetVersionInfo($path)
            $libraries += [pscustomobject]@{file=$dll;file_version=$version.FileVersion;product_version=$version.ProductVersion;sha256=(Get-CpuHash $path)}
        }
        $manifest['deployed_runtime_libraries']=$libraries
        $raw=@(& $testExe) -join "`n"
        if($LASTEXITCODE -ne 0){throw 'Common-input numerical checks failed'}
        $common=$raw | ConvertFrom-Json
        Check-Common $common @(1,5,256,257,9999,10000,10001)
        [IO.File]::WriteAllText((Join-Path $out 'common-input-checks.json'),$raw+"`n",$utf8)
        $native=Sample 10000 '42'
        $odd=Sample 5 '18446744073709551615'
        $manifest['observed_cuda_metadata']=$native.cuda
        $manifest['common_input_estimate_checks']=@($common.cases).Count
        $manifest['native_smoke_scenarios']=@(10000,5)
        if($IncludeScaleChecks){
            foreach($n in @(100000,1000000,10000000)){ $scale=Sample $n '42' }
            $manifest['native_scale_checks']=@(100000,1000000,10000000)
            $scaleRaw=@(& $testExe --scale-common) -join "`n"
            if($LASTEXITCODE -ne 0){throw 'Common-input scale checks failed'}
            $scaleCommon=$scaleRaw | ConvertFrom-Json
            Check-Common $scaleCommon @(100000,1000000,10000000)
            [IO.File]::WriteAllText((Join-Path $out 'common-input-scale-checks.json'),$scaleRaw+"`n",$utf8)
            $manifest['common_input_scale_estimate_checks']=@($scaleCommon.cases).Count
        }
        if($IncludeHybridChecks){
            $manifest['verification_modes']=@('full-device','hybrid')
            $manifest['hybrid_host_sorting_used']=$true
            $hybridTest=Join-Path $root 'build-cuda-skeleton/Release/mc_cuda_hybrid_tests.exe'
            $manifest['hybrid_test_executable_sha256']=Get-CpuHash $hybridTest
            $hybridArguments=@(); if($IncludeScaleChecks){$hybridArguments=@('--scale-common')}
            $hybridRaw=@(& $hybridTest @hybridArguments) -join "`n"
            if($LASTEXITCODE -ne 0){throw 'Hybrid common-input/native-reference checks failed'}
            $hybridChecks=$hybridRaw | ConvertFrom-Json
            if(-not $hybridChecks.native_reference_contract_passed -or -not $hybridChecks.invalid_input_and_recovery_checks_passed){
                throw 'Incomplete hybrid verification'
            }
            if($IncludeScaleChecks){foreach($n in @(100000,1000000,10000000)){
                if(@($hybridChecks.cases | Where-Object {$_.kind -ceq 'common-input' -and $_.scenarios -eq $n -and $_.passed}).Count -ne 1){
                    throw "Missing hybrid common-input scale case $n"
                }
            }}
            [IO.File]::WriteAllText((Join-Path $out 'hybrid-checks.json'),$hybridRaw+"`n",$utf8)
            $null=HybridSample 11 '42'
            if($IncludeScaleChecks){foreach($n in @(100000,1000000,10000000)){$null=HybridSample $n '42'}}
            if((Get-CpuHash $hybridTest) -cne $manifest.hybrid_test_executable_sha256){throw 'Hybrid test executable changed'}
            $manifest['hybrid_checks']=$hybridChecks
            $manifest['hybrid_requested_batch_size']=$HybridBatchSize
        }
        $manifest['runtime_version_note']='Compiler, header, DLL file version and API-returned runtime/driver values are distinct observations; no substitution'
        foreach($backend in @('serial','openmp')){
            $extra=if($backend -eq 'openmp'){@('--threads','4')}else{@()}
            $gpuBuild=(& $exe --csv data/synthetic_prices.csv 10000 42 10 --backend $backend @extra --json) | ConvertFrom-Json
            if($LASTEXITCODE -ne 0){throw 'CPU backend in CUDA-enabled build failed'}
            $cpuExe=Join-Path $root 'build-cuda-disabled-on/Release/mc_var.exe'
            $cpuBuild=(& $cpuExe --csv data/synthetic_prices.csv 10000 42 10 --backend $backend @extra --json) | ConvertFrom-Json
            if($LASTEXITCODE -ne 0){throw 'CPU-only build failed'}
            Write-CpuJson (Join-Path $out ("cpu-$backend-cuda-on.json")) $gpuBuild
            Write-CpuJson (Join-Path $out ("cpu-$backend-cuda-off.json")) $cpuBuild
            for($i=0;$i -lt 2;++$i){if($gpuBuild.estimates[$i].mc_var -ne $cpuBuild.estimates[$i].mc_var){throw 'CPU estimates changed across CUDA build setting'}}
        }
        if((Get-CpuHash $exe) -ne $manifest.executable_sha256 -or (Get-CpuHash $testExe) -ne $manifest.test_executable_sha256 -or
            (Get-CpuHash 'data/synthetic_prices.csv') -ne $manifest.input_sha256 -or (& git rev-parse HEAD).Trim() -ne $revision -or
            @(Get-SourceChanges).Count -ne 0){throw 'Source or artifacts changed during verification'}
        foreach($artifact in $buildArtifacts){
            if((Get-CpuHash $artifact.path) -cne $artifact.sha256){throw 'Build artifacts changed during verification'}
        }
        $manifest['cpu_compatibility']='Serial and OpenMP estimates match exactly between CUDA ON/OFF builds'
        $manifest['ctest_counts']=[ordered]@{
            cuda_on=@((Get-Content -LiteralPath (Join-Path $out 'test-list-cuda.json') -Raw | ConvertFrom-Json).tests).Count
            cuda_off_openmp_on=@((Get-Content -LiteralPath (Join-Path $out 'test-list-cpu-ON.json') -Raw | ConvertFrom-Json).tests).Count
            both_off=@((Get-Content -LiteralPath (Join-Path $out 'test-list-cpu-OFF.json') -Raw | ConvertFrom-Json).tests).Count
        }
        $manifest['status']='completed'
    }catch{
        $manifest['status']='failed';$manifest['failure']=$_.Exception.Message;throw
    }finally{
        $manifest['finished_utc']=[DateTime]::UtcNow.ToString('o')
        $manifest['record_hashes']=@(Get-ChildItem -LiteralPath $out -File | Where-Object {$_.Name -cne 'manifest.json'} |
            ForEach-Object {[pscustomobject]@{file=$_.Name;sha256=(Get-CpuHash $_.FullName)}})
        Write-CpuJson (Join-Path $out 'manifest.json') $manifest
        Write-Host "CUDA implementation-check evidence: $out"
    }
}finally{Pop-Location}
