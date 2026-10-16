[CmdletBinding()]
param(
    [ValidateSet('smoke','benchmark')][string]$Mode = 'smoke',
    [string]$OutputDirectory = '',
    [string]$ConditionsFile = ''
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'cpu-benchmark-common.ps1')
$utf8 = [Text.UTF8Encoding]::new($false)
function Invoke-BuildTool($Tool, $Arguments, $LogName) {
    $capture = @(& $Tool @Arguments 2>&1); $exit = $LASTEXITCODE
    $text = ($capture | Out-String).Replace($root, '<SOURCE>').Replace($root.Replace('\','/'), '<SOURCE>')
    $text = $text.Replace($env:USERPROFILE, '<USER>').Replace($env:USERPROFILE.Replace('\','/'), '<USER>')
    if ($text -match '(?m)^\.NET Framework.*MSBuild') {
        $native = Join-Path $out ($LogName + '.native.txt')
        [IO.File]::WriteAllText($native, $text, $utf8)
        $text = 'English transcription; only localized MSBuild banner replaced. Captured log SHA-256: ' + (Get-CpuHash $native) + "`n" +
            [regex]::Replace($text, '(?m)^\.NET Framework.*MSBuild[^\r\n]*', '.NET Framework MSBuild')
    }
    [IO.File]::WriteAllText((Join-Path $out $LogName), $text, $utf8)
    if ($exit -ne 0) { throw "$Tool failed; see $LogName" }
}
function Invoke-Probe($Arguments) {
    $capture = @(& $probe @Arguments)
    if ($LASTEXITCODE -ne 0) { throw 'CPU instrumentation failed' }
    $raw = $capture -join "`n"
    return [pscustomobject]@{raw=$raw; value=($raw | ConvertFrom-Json)}
}
function Assert-Power($Snapshot) {
    if ($Mode -eq 'benchmark' -and ($Snapshot.ac_line_status -ne 1 -or
        $Snapshot.battery_saver -ne $inventory.power.battery_saver -or
        $Snapshot.active_power_scheme -cne $inventory.power.active_power_scheme)) {
        throw 'Power source, battery saver or active power scheme changed; retain this attempt and rerun consistently'
    }
}
$environmentNames = @('OMP_NUM_THREADS','OMP_DYNAMIC','OMP_NESTED','OMP_SCHEDULE','OMP_PROC_BIND','OMP_PLACES',
    'OMP_THREAD_LIMIT','OMP_WAIT_POLICY','KMP_AFFINITY','KMP_BLOCKTIME','GOMP_CPU_AFFINITY')
$oldEnvironment = @{}
Push-Location -LiteralPath $root
try {
    $revision = (& git rev-parse HEAD | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or @(& git status --porcelain).Count -ne 0) { throw 'A clean source commit is required' }
    if ($Mode -eq 'benchmark' -and -not $ConditionsFile) { throw 'Benchmark requires an English physical-conditions JSON file' }
    $conditions = if ($ConditionsFile) { Get-Content -Raw -Encoding UTF8 -LiteralPath $ConditionsFile | ConvertFrom-Json }
        else { [pscustomobject]@{purpose='Recorder smoke only; physical conditions not supplied'} }
    if (-not $OutputDirectory) { $OutputDirectory = 'results/cpu-' + $Mode + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }
    if (Test-Path -LiteralPath $OutputDirectory) { throw 'Output directory already exists' }
    $out = (New-Item -ItemType Directory -Path $OutputDirectory).FullName
    $manifest = [ordered]@{
        schema_version=1; mode=$Mode; status='running'; started_utc=[DateTime]::UtcNow.ToString('o')
        source_revision=$revision; clean_source=$true; source_to_binary='Clean-first x64 Release build in this invocation'
        application_version='0.3.0'; executable='build-cpu-scaling/Release/mc_var.exe'
        input='data/synthetic_prices.csv'; input_sha256=(Get-CpuHash 'data/synthetic_prices.csv')
        seed='42'; horizon_trading_days=10; trading_days_per_year=252
        process_lifetime='One new suspended CLI process per run; affinity set and checked before resume; no persistent engine context'
        warmup_scope='Separate processes precondition OS caches and machine; no persistent RNG/team/allocation reuse'
        timing_scope='Existing engine timer: allocation, RNG, loss generation, serial sort, quantiles, cleanup, synchronization'
        excluded='Process startup, CSV calibration, telemetry, JSON/file output, fixed inter-run delay'
        placement_policy='Same full available logical-CPU pool for every process; OS schedules workers; no per-thread pinning or physical-core-count inference'
        priority_policy='NORMAL_PRIORITY_CLASS for every CLI process'
        sorting='Serial; numerical engines unchanged'
        execution_order='All warm-up rounds first, then measured rounds; cyclic shift by 5 configurations per round, reverse odd rounds'
        inter_run_delay_ms=100; outlier_policy='Retain every successful measured run; no timing filters'
        physical_conditions=$conditions; os_version=[Environment]::OSVersion.VersionString
        cpu_model=(Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0').ProcessorNameString.Trim()
        temperature_policy='Package temperature unavailable in this recorder; frequency snapshots are OS throttle reports, not package temperature or measured turbo clocks'
        thermal_steady_state_verified=$false; common_input_validation='Separate prior correctness evidence; benchmark uses native RNG'
        native_samples='Serial and OpenMP use different streams; fixed same seed per backend and repetition'
    }
    Write-CpuJson (Join-Path $out 'manifest.json') $manifest
    try {
        Invoke-BuildTool 'cmake' @('-S','.', '-B','build-cpu-scaling','-G','Visual Studio 17 2022','-A','x64',
            '-DMC_ENABLE_OPENMP=ON','-DMC_BUILD_CPU_TOOLS=ON') 'configure.log'
        Invoke-BuildTool 'cmake' @('--build','build-cpu-scaling','--config','Release','--clean-first','--parallel') 'build.log'
        Invoke-BuildTool 'ctest' @('--test-dir','build-cpu-scaling','-C','Release','--output-on-failure','-V') 'ctest.log'
        $exe = Join-Path $root $manifest.executable
        $probe = Join-Path $root 'build-cpu-scaling/Release/mc_cpu_probe.exe'
        $manifest['executable_sha256'] = Get-CpuHash $exe
        $manifest['probe_sha256'] = Get-CpuHash $probe
        $manifest['compiler_settings'] = @(Get-Content 'build-cpu-scaling/CMakeCache.txt' | Where-Object {
            $_ -match '^(CMAKE_CXX_FLAGS[^:]*|CMAKE_GENERATOR[^:]*|OpenMP_CXX_FLAGS|OpenMP_CXX_SPEC_DATE|MC_ENABLE_OPENMP|MC_BUILD_CPU_TOOLS):'
        } | ForEach-Object { $_.ToString() })
        $compiler = Get-ChildItem 'build-cpu-scaling/CMakeFiles/*/CMakeCXXCompiler.cmake' | Select-Object -First 1
        $manifest['compiler_identification'] = @(Get-Content -LiteralPath $compiler.FullName | Where-Object {
            $_ -match '^set\(CMAKE_CXX_(COMPILER_ID|COMPILER_VERSION|SIZEOF_DATA_PTR) '
        } | ForEach-Object { $_.ToString() })
        $manifest['cmake_version'] = (& cmake --version | Select-Object -First 1).ToString()
        $manifest['powershell_version'] = $PSVersionTable.PSVersion.ToString()
        foreach ($name in $environmentNames) {
            $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
        [Environment]::SetEnvironmentVariable('OMP_DYNAMIC','FALSE','Process')
        [Environment]::SetEnvironmentVariable('OMP_NESTED','FALSE','Process')
        $manifest['original_runtime_environment'] = $oldEnvironment
        $manifest['campaign_runtime_environment'] = [ordered]@{OMP_DYNAMIC='FALSE';OMP_NESTED='FALSE';others='Unset (see environment name list in script)'}
        $inventoryCapture = Invoke-Probe @('--inventory'); $inventory = $inventoryCapture.value
        [IO.File]::WriteAllText((Join-Path $out 'inventory.json'), $inventoryCapture.raw + "`n", $utf8)
        if ($inventory.processor_groups -ne 1 -or $inventory.process_mask_hex -cne $inventory.system_mask_hex) {
            throw 'This baseline requires a single processor group and the full system CPU pool'
        }
        $mask = [string]$inventory.process_mask_hex
        $manifest['process_mask_hex'] = $mask
        $manifest['runtime'] = $inventory.runtime
        Assert-Power $inventory.power
        $affinityChecks = @()
        foreach ($binding in @('unset','requested')) {
            [Environment]::SetEnvironmentVariable('OMP_PROC_BIND',$(if($binding -eq 'requested'){'TRUE'}else{$null}),'Process')
            [Environment]::SetEnvironmentVariable('OMP_PLACES',$(if($binding -eq 'requested'){'cores'}else{$null}),'Process')
            foreach ($threads in @(1,2,4,8,10)) {
                $check = (Invoke-Probe @('--affinity',"$threads",$mask)).value
                $affinityChecks += [pscustomobject]@{binding_environment=$binding;probe=$check}
            }
        }
        [Environment]::SetEnvironmentVariable('OMP_PROC_BIND',$null,'Process')
        [Environment]::SetEnvironmentVariable('OMP_PLACES',$null,'Process')
        # One logical processor is an unambiguous negative/positive affinity control.
        $number = [Convert]::ToUInt64($mask,16); $restricted = [UInt64]1
        while (($number -band $restricted) -eq 0) { $restricted = $restricted -shl 1 }
        $restrictedHex = $restricted.ToString('x')
        $control = (Invoke-Probe @('--affinity','4',$restrictedHex)).value
        foreach ($thread in $control.threads) {
            if ($thread.allowed_mask_hex -cne $restrictedHex -or $thread.observed_mask_hex -cne $restrictedHex) {
                throw 'Windows process affinity failed its runtime worker control test'
            }
        }
        Write-CpuJson (Join-Path $out 'affinity-checks.json') @{runtime_binding_tests=$affinityChecks;restricted_process_control=$control}
        $manifest['affinity_verification'] = 'Windows process mask control verified against allowed and observed worker masks; runtime binding requests recorded separately; no binding assumption'
        $scenarioCounts = if ($Mode -eq 'benchmark') { @(100000,1000000,10000000) } else { @(10000) }
        $warmups = if ($Mode -eq 'benchmark') { 3 } else { 1 }
        $repetitions = if ($Mode -eq 'benchmark') { 10 } else { 2 }
        $configurations = @()
        foreach ($n in $scenarioCounts) {
            foreach ($threads in @(0,1,2,4,8,10)) {
                $backend = if ($threads -eq 0) { 'serial' } else { 'openmp' }
                $configurations += [pscustomobject]@{id="$backend-$threads-N$n";backend=$backend;requested_threads=$threads;scenarios=$n}
            }
        }
        $manifest['configurations'] = $configurations
        $manifest['warmups_per_configuration'] = $warmups
        $manifest['measured_repetitions_per_configuration'] = $repetitions
        Write-CpuJson (Join-Path $out 'manifest.json') $manifest
        $runs = @(); $sequence = 0
        foreach ($phase in @('warmup','measured')) {
            $rounds = if ($phase -eq 'warmup') { $warmups } else { $repetitions }
            for ($round = 1; $round -le $rounds; ++$round) {
                Write-Host "CPU $Mode phase=$phase round=$round/$rounds"
                $indices = @(0..($configurations.Count-1))
                if ($round % 2 -eq 1) { [array]::Reverse($indices) }
                for ($offset = 0; $offset -lt $indices.Count; ++$offset) {
                    $index = $indices[($offset + 5 * ($round-1)) % $indices.Count]
                    $config = $configurations[$index]
                    $cli = @('--run',$mask,$exe,'--csv','data/synthetic_prices.csv',"$($config.scenarios)",'42','10','252','--backend',$config.backend)
                    if ($config.backend -eq 'openmp') { $cli += @('--threads',"$($config.requested_threads)") }
                    $cli += '--json'
                    $started = [DateTime]::UtcNow.ToString('o')
                    $capture = Invoke-Probe $cli; $observation = $capture.value
                    $finished = [DateTime]::UtcNow.ToString('o')
                    ++$sequence
                    [IO.File]::AppendAllText((Join-Path $out 'process-observations.jsonl'), $capture.raw + "`n", $utf8)
                    if ($observation.exit_code -ne 0 -or $observation.stderr -ne '' -or
                        $observation.process_mask_hex -cne $mask -or $observation.priority_class -ne 32) { throw 'CLI process contract failed' }
                    $result = $observation.stdout | ConvertFrom-Json
                    $expectedThreads = if ($config.backend -eq 'serial') { 1 } else { $config.requested_threads }
                    if ($result.application_version -ne '0.3.0' -or $result.schema_version -ne 1 -or
                        $result.backend -ne $config.backend -or $result.scenarios -ne $config.scenarios -or
                        $result.seed -cne '42' -or $result.requested_threads -ne $config.requested_threads -or
                        $result.threads_used -ne $expectedThreads -or $result.input_mode -ne 'csv_calibration' -or
                        @($result.estimates).Count -ne 2 -or [double]$result.estimates[0].confidence -ne .95 -or
                        [double]$result.estimates[1].confidence -ne .99 -or [double]$result.end_to_end_ms -le 0 -or
                        [double]::IsNaN([double]$result.end_to_end_ms) -or [double]::IsInfinity([double]$result.end_to_end_ms)) {
                        throw 'Unexpected benchmark output'
                    }
                    $record = [pscustomobject][ordered]@{sequence=$sequence;configuration_id=$config.id;phase=$phase;repetition=$round
                        started_utc=$started;finished_utc=$finished;result=$result}
                    [IO.File]::AppendAllText((Join-Path $out 'runs.jsonl'), (ConvertTo-Json $record -Depth 10 -Compress) + "`n", $utf8)
                    $runs += $record
                    Assert-Power $observation.before; Assert-Power $observation.after
                    Start-Sleep -Milliseconds 100
                }
            }
        }
        $summary = @(Get-CpuSummary $runs)
        if ($runs.Count -ne $configurations.Count * ($warmups + $repetitions)) { throw 'Incomplete run matrix' }
        foreach ($config in $configurations) {
            if (@($runs | Where-Object { $_.configuration_id -eq $config.id -and $_.phase -eq 'warmup' }).Count -ne $warmups -or
                @($runs | Where-Object { $_.configuration_id -eq $config.id -and $_.phase -eq 'measured' }).Count -ne $repetitions) {
                throw 'Missing configuration repetitions'
            }
        }
        Write-CpuJson (Join-Path $out 'summary.json') $summary
        $invariant = [Globalization.CultureInfo]::InvariantCulture
        $summary | ForEach-Object {
            [pscustomobject][ordered]@{configuration_id=$_.configuration_id;backend=$_.backend;scenarios=$_.scenarios
                requested_threads=$_.requested_threads;actual_thread_counts=($_.actual_thread_counts -join '|')
                measured_repetitions=$_.measured_repetitions;mean_ms=$_.mean_ms.ToString('R',$invariant)
                sample_stddev_ms=$_.sample_stddev_ms.ToString('R',$invariant);scenarios_per_second=$_.scenarios_per_second.ToString('R',$invariant)
                speedup_vs_fresh_serial=$_.speedup_vs_fresh_serial.ToString('R',$invariant)
                scaling_vs_openmp_one_thread=$(if($null -eq $_.scaling_vs_openmp_one_thread){''}else{$_.scaling_vs_openmp_one_thread.ToString('R',$invariant)})}
        } | Export-Csv -LiteralPath (Join-Path $out 'summary.csv') -NoTypeInformation -Encoding UTF8
        if ((Get-CpuHash $exe) -ne $manifest.executable_sha256 -or (Get-CpuHash $probe) -ne $manifest.probe_sha256 -or
            (Get-CpuHash 'data/synthetic_prices.csv') -ne $manifest.input_sha256 -or
            (& git rev-parse HEAD).Trim() -ne $revision -or @(& git status --porcelain).Count -ne 0) { throw 'Source or artifact changed during campaign' }
        $manifest['total_runs'] = $runs.Count
        $manifest['measured_runs'] = @($runs | Where-Object { $_.phase -eq 'measured' }).Count
        $manifest['warmup_runs'] = @($runs | Where-Object { $_.phase -eq 'warmup' }).Count
        $manifest['status'] = 'completed'
    } catch {
        $manifest['status'] = 'failed'; $manifest['failure'] = $_.Exception.Message
        throw
    } finally {
        $manifest['finished_utc'] = [DateTime]::UtcNow.ToString('o')
        Write-CpuJson (Join-Path $out 'manifest.json') $manifest
        Write-Host "CPU evidence directory: $out"
    }
} finally {
    foreach ($name in $oldEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name,$oldEnvironment[$name],'Process') }
    Pop-Location
}
