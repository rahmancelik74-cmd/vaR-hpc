[CmdletBinding()]
param([ValidateSet('smoke','diagnostic','formal')][string]$Mode='smoke',
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$BuildDirectory='build-benchmark-preparation',[string]$ConditionsFile='',
    [switch]$AllowDirtySource,[switch]$UseExistingBuild,[switch]$DiscoverBandwidth)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'benchmark-common.ps1')
$root=Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $root
$savedEnvironment=@{}
try {
    $changes=@(Get-GpuSourceChanges)
    if($changes.Count -and ($Mode -ceq 'formal' -or -not $AllowDirtySource)){throw 'Clean source required; dirty development smoke requires -AllowDirtySource'}
    if($Mode -ceq 'formal' -and -not $ConditionsFile){throw 'Formal campaign requires a conditions file; unknown/unmeasured fields are allowed'}
    $out=[IO.Path]::GetFullPath((Join-Path $root $OutputDirectory))
    $allowed=[IO.Path]::GetFullPath((Join-Path $root 'results'))+[IO.Path]::DirectorySeparatorChar
    if(-not $out.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $out)){throw 'Use a new directory below ignored results/'}
    $build=[IO.Path]::GetFullPath((Join-Path $root $BuildDirectory))
    if(-not $build.StartsWith(($root+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path $build -Leaf) -notlike 'build-*'){throw 'Use a dedicated build-* directory inside the repository'}
    $null=New-Item -ItemType Directory -Path $out
    $plan=New-BenchmarkPlan $Mode
    # Written before configure/build/tests or any sample execution.
    Write-GpuJson (Join-Path $out 'plan.json') $plan
    Write-GpuJson (Join-Path $out 'source-snapshot.json') @(Get-BenchmarkSourceSnapshot)
    $conditions=if($ConditionsFile){Get-Content -LiteralPath $ConditionsFile -Raw -Encoding UTF8 | ConvertFrom-Json}else{
        [pscustomobject]@{charger='unknown';surface_and_ventilation='unknown';cooling_pad='unknown';vendor_performance_mode='unknown';
            vendor_fan_mode='unknown';ambient_temperature=@{status='unmeasured';value_c=$null};competing_applications='unknown'}
    }
    Write-GpuJson (Join-Path $out 'user-conditions.json') $conditions
    $manifest=[ordered]@{schema_version=1;purpose='Unified native CPU/GPU benchmark infrastructure';mode=$Mode;status='running';
        formal_campaign=$false;clean_source=($changes.Count -eq 0);source_changes=$changes;
        source_revision=(& git rev-parse HEAD).Trim();source_tree=(& git rev-parse 'HEAD^{tree}').Trim();
        source_snapshot_sha256=(Get-GpuHash (Join-Path $out 'source-snapshot.json'));
        started_utc=[DateTime]::UtcNow.ToString('o');input_path=[IO.Path]::GetFullPath('data/synthetic_prices.csv');
        input_sha256=(Get-GpuHash 'data/synthetic_prices.csv');build_directory=$build;
        conditions_policy='User declarations separate from telemetry; unknown/unmeasured allowed; no machine settings changed';
        process_policy='Fresh suspended CLI per attempt; owned Job Object; same full allowed CPU pool; normal priority; no per-core pinning; fresh CUDA context';
        timing_policy='Existing end_to_end_ms includes engine allocation/RNG/simulation/global quantile/transfers/synchronization/cleanup and initial CUDA context/API work; excludes process startup/shared calibration/output/telemetry/delays';
        thermal_equilibrium_verified=$false;cpu_package_temperature='unmeasured';
        artifacts=@();record_hashes=@();errors=@()}
    $manifestPath=Join-Path $out 'manifest.json';Write-GpuJson $manifestPath $manifest
    function Required-Tool($Id,$Executable,$Arguments){
        $p=Invoke-GpuProcess $Executable $Arguments (Join-Path $out $Id) 600
        Assert-GpuProcess $p;return $p
    }
    function Gpu-Observation($Id){
        $p=Invoke-GpuProcess 'nvidia-smi.exe' @('--query-gpu=name,driver_version,temperature.gpu,power.draw,power.limit,clocks.current.graphics,clocks.current.memory,pstate','--format=csv') (Join-Path $out $Id) 15
        [pscustomobject]@{process_record=($Id+'.process.json');available=(-not $p.start_error -and -not $p.timed_out -and $p.exit_code -eq 0);
            note='Point observations only; N/A stays unavailable; not CPU temperature or proof of no throttling'}
    }
    $runs=@()
    try {
        [IO.File]::Copy($manifest.input_path,(Join-Path $out 'fixture.csv'))
        $fixture=Get-IndependentGpuFixture (Join-Path $out 'fixture.csv');Write-GpuJson (Join-Path $out 'independent-fixture.json') $fixture
        $bindingPath=Join-Path $build 'benchmark-build-binding.json'
        if($UseExistingBuild){
            $binding=Read-GpuJson $bindingPath
            if($binding.source_snapshot_sha256 -cne $manifest.source_snapshot_sha256){throw 'Existing build does not bind this source snapshot'}
            foreach($a in $binding.artifacts){Assert-GpuBoundArtifact $a.path $a.sha256}
        }else{
            $null=Required-Tool 'configure' 'cmake.exe' @('-S','.', '-B',$build,'-G','Visual Studio 17 2022','-A','x64','-T','cuda=13.4',
                '-DMC_ENABLE_CUDA=ON','-DMC_ENABLE_OPENMP=ON','-DMC_BUILD_CPU_TOOLS=ON','-DBUILD_TESTING=ON','-DCMAKE_CUDA_ARCHITECTURES=89')
            $null=Required-Tool 'build' 'cmake.exe' @('--build',$build,'--config','Release','--clean-first','--parallel')
            $binding=[pscustomobject]@{source_snapshot_sha256=$manifest.source_snapshot_sha256;artifacts=@()}
            foreach($p in @((Join-Path $build 'CMakeCache.txt'),(Join-Path $build 'mc_cuda.vcxproj'))+
                @(Get-ChildItem (Join-Path $build 'Release') -File | Where-Object {$_.Extension -in @('.exe','.dll')} | ForEach-Object {$_.FullName})){
                $binding.artifacts+=[pscustomobject]@{path=$p;sha256=(Get-GpuHash $p)}
            }
            Write-GpuJson $bindingPath $binding
        }
        $manifest.artifacts=$binding.artifacts
        Copy-Item -LiteralPath $bindingPath -Destination (Join-Path $out 'build-binding.json')
        Copy-Item -LiteralPath (Join-Path $build 'CMakeCache.txt') -Destination (Join-Path $out 'CMakeCache.txt')
        Copy-Item -LiteralPath (Join-Path $build 'mc_cuda.vcxproj') -Destination (Join-Path $out 'mc_cuda.vcxproj')
        $null=Required-Tool 'test-list' 'ctest.exe' @('--test-dir',$build,'-C','Release','--show-only=json-v1')
        $null=Required-Tool 'ctest' 'ctest.exe' @('--test-dir',$build,'-C','Release','--output-on-failure')
        $exe=Join-Path $build 'Release/mc_var.exe';$probe=Join-Path $build 'Release/mc_cpu_probe.exe'
        $manifest['executable_path']=$exe;$manifest['executable_sha256']=Get-GpuHash $exe
        $manifest['probe_path']=$probe;$manifest['probe_sha256']=Get-GpuHash $probe
        $manifest['build_cache_sha256']=Get-GpuHash (Join-Path $build 'CMakeCache.txt')
        foreach($name in @('OMP_NUM_THREADS','OMP_DYNAMIC','OMP_NESTED','OMP_SCHEDULE','OMP_PROC_BIND','OMP_PLACES',
            'OMP_THREAD_LIMIT','OMP_WAIT_POLICY','KMP_AFFINITY','KMP_BLOCKTIME','GOMP_CPU_AFFINITY')){
            $savedEnvironment[$name]=[Environment]::GetEnvironmentVariable($name)
            [Environment]::SetEnvironmentVariable($name,$null,'Process')
        }
        [Environment]::SetEnvironmentVariable('OMP_DYNAMIC','FALSE','Process');[Environment]::SetEnvironmentVariable('OMP_NESTED','FALSE','Process')
        Write-GpuJson (Join-Path $out 'runtime-environment.json') @{original=$savedEnvironment;campaign=@{OMP_DYNAMIC='FALSE';OMP_NESTED='FALSE';others='unset'}}
        $p=Required-Tool 'inventory' $probe @('--inventory')
        $inventory=Read-GpuJson $p.stdout;$mask=$inventory.process_mask_hex
        $manifest['process_mask_hex']=$mask;$manifest['power_reference']=$inventory.power
        foreach($t in @(1,2,4,8,10)){$null=Required-Tool ('affinity-'+$t) $probe @('--affinity',[string]$t,$mask)}
        $manifest['gpu_before']=Gpu-Observation 'gpu-initial'
        $null=Required-Tool 'nvcc-version' 'nvcc.exe' @('--version')
        $bandwidth=[ordered]@{status='not-requested';measured_dram_status='not-measured';documented_peak_gbs=$null;
            peak_source_status='unverified for exact laptop configuration';profiling_orchestration='unverified; not implemented as a campaign';
            permission_settings_changed=$false;metrics=@('dram__bytes_read.sum','dram__bytes_write.sum','gpu__time_duration.sum');
            note='Discovery is separate from samples; exit zero alone is not success; effective bytes are not measured DRAM traffic'}
        if($DiscoverBandwidth){
            $ncu=Get-ChildItem 'C:/Program Files/NVIDIA Corporation/Nsight Compute */target/windows-desktop-win7-x64/ncu.exe' | Sort-Object FullName -Descending | Select-Object -First 1
            if($ncu){
                $section=Join-Path (Split-Path (Split-Path (Split-Path $ncu.FullName))) 'sections'
                $v=Invoke-GpuProcess $ncu.FullName @('--version') (Join-Path $out 'ncu-version') 15
                $q=Invoke-GpuProcess $ncu.FullName @('--section-folder',$section,'--query-metrics','--query-metrics-mode','suffix',
                    '--metrics','dram__bytes_read,dram__bytes_write,gpu__time_duration') (Join-Path $out 'ncu-discovery') 30
                $text=[IO.File]::ReadAllText($q.stdout)+[IO.File]::ReadAllText($q.stderr)
                $bandwidth.status=Test-BandwidthDiscovery $q $text
                $bandwidth['tool_path']=$ncu.FullName;$bandwidth['tool_sha256']=Get-GpuHash $ncu.FullName
                $bandwidth['version_process']='ncu-version.process.json';$bandwidth['discovery_process']='ncu-discovery.process.json'
            }else{$bandwidth.status='tool-unavailable'}
        }
        Write-GpuJson (Join-Path $out 'bandwidth-preparation.json') $bandwidth
        Write-GpuJson $manifestPath $manifest
        foreach($step in $plan.execution_order){
            $config=@($plan.configurations | Where-Object {$_.id -ceq $step.configuration_id})[0]
            $id='attempt-'+('{0:D3}' -f $step.sequence)
            $record=[ordered]@{sequence=$step.sequence;configuration_id=$step.configuration_id;phase=$step.phase;repetition=$step.repetition;
                diagnostics=$step.diagnostics;source_revision=$manifest.source_revision;source_snapshot_sha256=$manifest.source_snapshot_sha256;
                input_sha256=$manifest.input_sha256;executable_sha256=$manifest.executable_sha256;build_cache_sha256=$manifest.build_cache_sha256;
                started_utc=[DateTime]::UtcNow.ToString('o');finished_utc=$null;arguments=@(Get-BenchmarkArguments $config $step.diagnostics $manifest.input_path);
                observation=$null;result=$null;error=$null;launcher_process=($id+'.process.json');gpu_before=(Gpu-Observation ($id+'-gpu-before'));gpu_after=$null}
            try {
                $args=@('--run-timeout','60000',$mask,$exe)+$record.arguments
                $p=Invoke-GpuProcess $probe $args (Join-Path $out $id) 75
                Assert-GpuProcess $p
                $record.observation=Read-GpuJson $p.stdout
                if($record.observation.exit_code -ne 0 -or $record.observation.timed_out -or $record.observation.stderr -cne ''){throw 'Target failed or timed out'}
                $record.result=$record.observation.stdout | ConvertFrom-Json
            }catch{$record.error=$_.Exception.Message}
            finally {
                $record.gpu_after=Gpu-Observation ($id+'-gpu-after');$record.finished_utc=[DateTime]::UtcNow.ToString('o')
                $r=[pscustomobject]$record;$runs+=$r
                Write-GpuJson (Join-Path $out ($id+'.json')) $r
                [IO.File]::AppendAllText((Join-Path $out 'runs.jsonl'),(ConvertTo-Json $r -Depth 30 -Compress)+"`n",[Text.UTF8Encoding]::new($false))
            }
            if($record.error){throw $record.error}
            # Check each prefix immediately: no later run after a detected power/configuration change.
            # Whole-matrix validation follows below; pre/post power is enforced here too.
            foreach($s in @($record.observation.before,$record.observation.after)){
                if($s.ac_line_status -ne $inventory.power.ac_line_status -or $s.battery_saver -ne $inventory.power.battery_saver -or
                    $s.active_power_scheme -cne $inventory.power.active_power_scheme -or ($Mode -ceq 'formal' -and $s.ac_line_status -ne 1)){throw 'Power conditions changed'}
            }
            Start-Sleep -Milliseconds $plan.inter_run_delay_ms
        }
        $manifest.status='completed'
        Test-BenchmarkRecords ([pscustomobject]$manifest) $plan $runs $fixture
        if($Mode -cne 'diagnostic'){
            $summary=@(Get-BenchmarkSummary $runs);Test-BenchmarkSummary $plan $runs $summary
            Write-GpuJson (Join-Path $out 'summary.json') $summary;Write-BenchmarkSummaryCsv (Join-Path $out 'summary.csv') $summary
        }
        $manifest.formal_campaign=($Mode -ceq 'formal')
        foreach($a in $manifest.artifacts){Assert-GpuBoundArtifact $a.path $a.sha256}
        $snapshot=@(Get-BenchmarkSourceSnapshot)
        $recordedSnapshot=@(Read-GpuJson (Join-Path $out 'source-snapshot.json'))
        if((ConvertTo-Json $snapshot -Depth 20 -Compress) -cne (ConvertTo-Json $recordedSnapshot -Depth 20 -Compress) -or
            (& git rev-parse HEAD).Trim() -cne $manifest.source_revision){throw 'Source changed during run'}
        if($manifest.clean_source -and @(Get-GpuSourceChanges).Count){throw 'Clean source status changed during run'}
    }catch{$manifest.status='failed';$manifest.formal_campaign=$false;$manifest.errors+= $_.Exception.Message}
    finally{
        $manifest['end_source_revision']=(& git rev-parse HEAD).Trim()
        $manifest['end_source_changes']=@(Get-GpuSourceChanges)
        $manifest['attempted_processes']=$runs.Count;$manifest['finished_utc']=[DateTime]::UtcNow.ToString('o')
        $manifest.record_hashes=@(Get-ChildItem -LiteralPath $out -File | Where-Object {$_.Name -cne 'manifest.json'} |
            ForEach-Object {[pscustomobject]@{file=$_.Name;sha256=(Get-GpuHash $_.FullName)}})
        Write-GpuJson $manifestPath $manifest
    }
    & (Join-Path $PSScriptRoot 'verify-benchmark.ps1') -Directory $out
    if($manifest.status -cne 'completed'){throw ('Incomplete campaign: '+($manifest.errors -join '; '))}
    Write-Host ('Completed '+$Mode+' infrastructure check: '+$runs.Count+' processes; '+$out)
}finally{
    foreach($name in $savedEnvironment.Keys){[Environment]::SetEnvironmentVariable($name,$savedEnvironment[$name],'Process')}
    Pop-Location
}
