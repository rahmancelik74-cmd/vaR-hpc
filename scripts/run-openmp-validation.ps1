[CmdletBinding()]
param([string]$OutputDirectory = '')
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [Text.UTF8Encoding]::new($false)
$invariant = [Globalization.CultureInfo]::InvariantCulture
function Write-Json($Path, $Value) {
    [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 15) + "`n", $utf8)
}
function Hash($Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Run-Tool($Tool, $Arguments, $LogName) {
    $lines = @(& $Tool @Arguments 2>&1)
    $code = $LASTEXITCODE
    $text = ($lines | Out-String).Replace($root, '<SOURCE>').Replace($root.Replace('\', '/'), '<SOURCE>')
    $text = $text.Replace($env:USERPROFILE, '<USER>').Replace($env:USERPROFILE.Replace('\', '/'), '<USER>')
    # MSBuild's banner can use the OS language even with PreferredUILang.
    # Retain the captured bytes locally and label the English transcription.
    if ($text -match '(?m)^\.NET Framework.*MSBuild.*$') {
        $rawPath = Join-Path $out ($LogName + '.native.txt')
        [IO.File]::WriteAllText($rawPath, $text, $utf8)
        $digest = Hash $rawPath
        $text = [regex]::Replace($text, '(?m)^\.NET Framework.*MSBuild[^\r\n]*',
            '.NET Framework MSBuild (localized banner transcribed in English)')
        $text = "English transcription: only the localized MSBuild banner was replaced.`nCaptured log SHA-256: $digest`n" + $text
    }
    [IO.File]::WriteAllText((Join-Path $out $LogName), $text, $utf8)
    if ($code -ne 0) { throw "$Tool failed with exit $code; see $LogName" }
}
function Sample($N, $Seed, $Threads) {
    $raw = @(& $exe --csv data/synthetic_prices.csv $N $Seed 10 252 --backend openmp --threads $Threads --json)
    if ($LASTEXITCODE -ne 0) { throw 'OpenMP CLI execution failed' }
    $line = $raw -join "`n"
    $run = $line | ConvertFrom-Json
    if ($run.application_version -ne '0.3.0' -or $run.schema_version -ne 1 -or
        $run.backend -ne 'openmp' -or $run.requested_threads -ne $Threads -or
        $run.threads_used -lt 1 -or $run.threads_used -gt $Threads -or $run.openmp_version -le 0 -or
        $run.scenarios -ne $N -or [string]$run.seed -cne [string]$Seed -or
        $run.input_mode -ne 'csv_calibration' -or $run.random_source -ne
        'block4096/splitmix64/mt19937_64/std::normal_distribution' -or
        @($run.estimates).Count -ne 2 -or $run.end_to_end_ms -lt 0 -or
        [double]$run.estimates[0].confidence -ne .95 -or [double]$run.estimates[1].confidence -ne .99) {
        throw 'Unexpected OpenMP JSON metadata'
    }
    foreach ($e in $run.estimates) {
        if ([double]::IsNaN($e.mc_var) -or [double]::IsInfinity($e.mc_var) -or
            [double]::IsNaN($e.analytical_var) -or [double]::IsInfinity($e.analytical_var)) {
            throw 'Nonfinite estimate'
        }
    }
    return [pscustomobject]@{raw=$line; result=$run}
}
Push-Location -LiteralPath $root
try {
    $revision = (& git rev-parse HEAD | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or @(& git status --porcelain).Count -ne 0) {
        throw 'A clean committed source tree is required'
    }
    if (-not $OutputDirectory) { $OutputDirectory = 'results/openmp-correctness-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }
    if (Test-Path -LiteralPath $OutputDirectory) { throw 'Output directory already exists' }
    $out = (New-Item -ItemType Directory -Path $OutputDirectory).FullName
    $manifest = [ordered]@{
        schema_version=1; purpose='Windows OpenMP correctness; not a performance benchmark'
        status='running'; started_utc=[DateTime]::UtcNow.ToString('o')
        source_revision=$revision; source_tree_clean_at_start=$true
        source_to_binary_policy='Clean-first Release rebuild from the recorded clean commit in this invocation'
        application_version='0.3.0'; backend='openmp'; requested_threads=4
        scenarios=@(10000,100000,1000000,10000000); seeds=@('42','123','456','789','2026')
        confidence_levels=@(.95,.99); input='data/synthetic_prices.csv'
        input_sha256=(Hash 'data/synthetic_prices.csv'); horizon_trading_days=10; trading_days_per_year=252
        generator='Visual Studio 17 2022'; platform='x64'; configuration='Release'
        target_compile_options=@('mc_core: /W4','mc_openmp: /W4; OpenMP::OpenMP_CXX')
        os_version=[Environment]::OSVersion.VersionString
        logical_processors=[Environment]::ProcessorCount
        powershell_version=$PSVersionTable.PSVersion.ToString()
        omp_environment=[ordered]@{}
        log_policy='Captured tool output; source and user directory prefixes redacted; no numerical edits'
        common_input_evidence='openmp_tests in ctest-on.log; separate from native runs.jsonl'
        formal_performance_benchmark=$false
    }
    foreach ($name in @('OMP_NUM_THREADS','OMP_DYNAMIC','OMP_THREAD_LIMIT','OMP_PROC_BIND','OMP_PLACES')) {
        $manifest.omp_environment[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    Write-Json (Join-Path $out 'manifest.json') $manifest
    try {
        foreach ($setting in @('ON','OFF')) {
            $build = if ($setting -eq 'ON') { 'build-openmp' } else { 'build-openmp-off' }
            Run-Tool 'cmake' @('-S','.', '-B',$build,'-G','Visual Studio 17 2022','-A','x64',"-DMC_ENABLE_OPENMP=$setting") "configure-$setting.log"
            Run-Tool 'cmake' @('--build',$build,'--config','Release','--clean-first','--parallel','--','/nologo','/p:PreferredUILang=en-US') "build-$setting.log"
            Run-Tool 'ctest' @('--test-dir',$build,'-C','Release','--output-on-failure','-V') "ctest-$setting.log"
        }
        $exe = Join-Path $root 'build-openmp/Release/mc_var.exe'
        $manifest['executable'] = 'build-openmp/Release/mc_var.exe'
        $manifest['executable_sha256'] = Hash $exe
        $manifest['cmake_version'] = (& cmake --version | Select-Object -First 1)
        $manifest['version_output'] = (& $exe --version | Out-String).Trim()
        $manifest['compiler_settings'] = @(Get-Content 'build-openmp/CMakeCache.txt' | Where-Object {
            $_ -match '^(CMAKE_CXX_FLAGS[^:]*|CMAKE_GENERATOR[^:]*|OpenMP_CXX_FLAGS|OpenMP_CXX_SPEC_DATE|MC_ENABLE_OPENMP):'
        } | ForEach-Object { $_.ToString() })
        $compiler = Get-ChildItem 'build-openmp/CMakeFiles/*/CMakeCXXCompiler.cmake' | Select-Object -First 1
        $manifest['compiler_identification'] = @(Get-Content -LiteralPath $compiler.FullName | Where-Object {
            $_ -match '^set\(CMAKE_CXX_(COMPILER_ID|COMPILER_VERSION|SIMULATE_ID|SIMULATE_VERSION|SIZEOF_DATA_PTR) '
        } | ForEach-Object { $_.ToString() })
        # Avoid an unbounded WMI inventory query; topology is documented separately.
        $manifest['cpu_model'] = (Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0').ProcessorNameString.Trim()
        $smoke = Sample 10000 '42' 4
        [IO.File]::WriteAllText((Join-Path $out 'smoke.json'), $smoke.raw + "`n", $utf8)
        $serialRaw = (& $exe --csv data/synthetic_prices.csv 10000 42 10 --json | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Serial JSON smoke failed' }
        $serial = $serialRaw | ConvertFrom-Json
        if ($serial.backend -ne 'serial' -or $serial.threads_used -ne 1 -or $serial.openmp_version -ne 0) {
            throw 'Serial default backend metadata changed'
        }
        [IO.File]::WriteAllText((Join-Path $out 'serial-smoke.json'), $serialRaw + "`n", $utf8)
        $threadChecks = @()
        foreach ($n in @(10000,100000)) {
            $reference = $null
            foreach ($threads in @(1,2,4,8,10)) {
                $sample = Sample $n '42' $threads
                $values = @($sample.result.estimates | ForEach-Object { [double]$_.mc_var })
                if ($null -eq $reference) { $reference = $values }
                if ($values[0] -ne $reference[0] -or $values[1] -ne $reference[1]) {
                    throw 'Native estimates changed across requested thread counts'
                }
                $threadChecks += $sample.result
            }
        }
        Write-Json (Join-Path $out 'native-thread-invariance.json') $threadChecks
        $runs = @(); $rows = @()
        foreach ($n in $manifest.scenarios) {
            foreach ($seed in $manifest.seeds) {
                Write-Host "OpenMP correctness N=$n seed=$seed threads=4"
                $sample = Sample $n $seed 4
                [IO.File]::AppendAllText((Join-Path $out 'runs.jsonl'), $sample.raw + "`n", $utf8)
                $runs += $sample.result
                foreach ($e in $sample.result.estimates) {
                    $rows += [pscustomobject][ordered]@{
                        scenarios=$n; seed=$seed; confidence=([double]$e.confidence).ToString('R',$invariant)
                        mc_var=([double]$e.mc_var).ToString('R',$invariant)
                        analytical_var=([double]$e.analytical_var).ToString('R',$invariant)
                        requested_threads=4; threads_used=$sample.result.threads_used
                    }
                }
            }
        }
        $rows | Export-Csv -LiteralPath (Join-Path $out 'estimates.csv') -NoTypeInformation -Encoding UTF8
        $acceptance = @()
        foreach ($c in @(.95,.99)) {
            $tail = @($runs | Where-Object { $_.scenarios -eq 10000000 })
            if ($tail.Count -ne 5 -or $runs.Count -ne 20) { throw 'Incomplete campaign' }
            $estimates = @($tail | ForEach-Object { $_.estimates | Where-Object { [double]$_.confidence -eq $c } })
            $mean = ($estimates | Measure-Object -Property mc_var -Average).Average
            $analytical = [double]$estimates[0].analytical_var
            $initial = [double]$tail[0].model.initial_value
            $absoluteMeanError = [Math]::Abs($mean - $analytical)
            $limit = .01 * [Math]::Max([Math]::Abs($analytical), .01 * $initial)
            $acceptance += [pscustomobject][ordered]@{
                confidence=$c; scenarios=10000000; seed_count=5; mean_var=$mean
                analytical_var=$analytical; initial_value=$initial
                absolute_error_of_mean=$absoluteMeanError; allowed_error=$limit; passed=($absoluteMeanError -le $limit)
                criterion='abs(mean(VaR)-analytical) <= 0.01*max(abs(analytical),0.01*initial_value)'
            }
        }
        Write-Json (Join-Path $out 'acceptance.json') $acceptance
        if (@($acceptance | Where-Object { -not $_.passed }).Count -gt 0) { throw 'Statistical acceptance failed' }
        if ((Hash $exe) -ne $manifest.executable_sha256 -or
            (Hash 'data/synthetic_prices.csv') -ne $manifest.input_sha256 -or
            (& git rev-parse HEAD).Trim() -ne $revision -or @(& git status --porcelain).Count -ne 0) {
            throw 'Source, input or executable changed during campaign'
        }
        $manifest['actual_thread_counts'] = @($runs.threads_used | Sort-Object -Unique)
        $manifest['native_runs'] = $runs.Count
        $manifest['ctest_on_count'] = 6; $manifest['ctest_off_count'] = 5
        $manifest['status'] = 'completed'
    } catch {
        $manifest['status'] = 'failed'; $manifest['error'] = $_.Exception.Message
        throw
    } finally {
        $manifest['finished_utc'] = [DateTime]::UtcNow.ToString('o')
        Write-Json (Join-Path $out 'manifest.json') $manifest
        Write-Host "Evidence directory: $out"
    }
} finally { Pop-Location }
