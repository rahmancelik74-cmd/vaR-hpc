[CmdletBinding()]
param(
    [ValidateSet('smoke', 'validation', 'benchmark')]
    [string]$Mode = 'smoke',
    [string]$Executable = 'build-foundation/Release/mc_var.exe',
    [string]$InputCsv = 'data/synthetic_prices.csv',
    [long[]]$ScenarioCounts,
    [UInt64[]]$Seeds,
    [ValidateRange(1, 1000000)][int]$HorizonTradingDays = 10,
    [ValidateRange(1, 1000000)][int]$TradingDaysPerYear = 252
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Write-JsonFile($Path, $Value) {
    $text = ConvertTo-Json -InputObject $Value -Depth 12
    [System.IO.File]::WriteAllText($Path, $text + "`n", $utf8)
}
function Format-Number([double]$Value) {
    return $Value.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
}
function Get-Sha256($Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Invoke-Sample($ScenarioCount, $Seed, $Phase, $Index) {
    $runId = '{0}-{1}-{2}-{3}' -f $ScenarioCount, $Seed, $Phase, $Index
    $errorPath = Join-Path $outputDirectory ($runId + '.stderr.txt')
    $cliArgs = @('--csv', $csvPath, [string]$ScenarioCount, [string]$Seed,
        [string]$HorizonTradingDays, [string]$TradingDaysPerYear, '--json')
    $raw = @(& $exePath @cliArgs 2> $errorPath)
    if ($LASTEXITCODE -ne 0) {
        throw "Application failed for $runId. See $errorPath"
    }
    $run = ($raw -join "`n") | ConvertFrom-Json
    if ($run.schema_version -ne 1 -or $run.application_version -ne '0.2.2' -or
        $run.backend -ne 'serial' -or $run.scenarios -ne $ScenarioCount -or
        [string]$run.seed -ne [string]$Seed -or $run.input_mode -ne 'csv_calibration' -or
        @($run.estimates).Count -ne 2 -or $run.end_to_end_ms -lt 0) {
        throw "Unexpected application output for $runId"
    }
    $record = [ordered]@{run_id=$runId; phase=$Phase; index=$Index; result=$run}
    $line = ConvertTo-Json -InputObject $record -Depth 12 -Compress
    [System.IO.File]::AppendAllText((Join-Path $outputDirectory 'runs.jsonl'), $line + "`n", $utf8)
    if ((Get-Item -LiteralPath $errorPath).Length -eq 0) {
        Remove-Item -LiteralPath $errorPath
    }
    foreach ($estimate in $run.estimates) {
        $row = [pscustomobject][ordered]@{
            run_id=$runId; phase=$Phase; index=$Index; backend=$run.backend
            scenarios=$ScenarioCount; seed=[string]$Seed
            confidence=(Format-Number $estimate.confidence); mc_var=(Format-Number $estimate.mc_var)
            analytical_var=(Format-Number $estimate.analytical_var)
            signed_error=(Format-Number $estimate.signed_error)
            end_to_end_ms=(Format-Number $run.end_to_end_ms)
        }
        $row | Export-Csv -LiteralPath (Join-Path $outputDirectory 'estimates.csv') `
            -NoTypeInformation -Encoding UTF8 -Append
    }
    return $run
}

Push-Location -LiteralPath $projectRoot
try {
    if ($null -eq $ScenarioCounts -or $ScenarioCounts.Count -eq 0) {
        if ($Mode -eq 'validation') { $ScenarioCounts = @(10000, 100000, 1000000, 10000000) }
        elseif ($Mode -eq 'benchmark') { $ScenarioCounts = @(100000, 1000000, 10000000) }
        else { $ScenarioCounts = @(10000) }
    }
    if ($null -eq $Seeds -or $Seeds.Count -eq 0) {
        if ($Mode -eq 'validation') { $Seeds = @(42, 123, 456, 789, 2026) }
        else { $Seeds = @(42) }
    }
    foreach ($n in $ScenarioCounts) {
        if ($n -le 0) { throw 'Scenario counts must be positive.' }
    }
    if (@($ScenarioCounts | Select-Object -Unique).Count -ne $ScenarioCounts.Count -or
        @($Seeds | Select-Object -Unique).Count -ne $Seeds.Count) {
        throw 'Duplicate configurations are not allowed.'
    }
    $exePath = (Resolve-Path -LiteralPath $Executable).Path
    $csvPath = (Resolve-Path -LiteralPath $InputCsv).Path
    $commit = (& git rev-parse HEAD | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Run this script from a Git working tree.' }
    $gitStatus = @(& git status --porcelain)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read Git working tree status.' }
    $version = (& $exePath --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $version -notlike 'mc_var 0.2.2 *') {
        throw 'Build mc_var 0.2.2 before running experiments.'
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $suffix = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $outputDirectory = Join-Path $projectRoot "results/$Mode-$stamp-$suffix"
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
    $warmups = 0
    $repetitions = 1
    if ($Mode -eq 'benchmark') { $warmups = 3; $repetitions = 10 }
    $manifest = [ordered]@{
        schema_version=1; mode=$Mode; status='running'
        started_utc=[DateTime]::UtcNow.ToString('o')
        git_commit=$commit; working_tree_dirty=($gitStatus.Count -gt 0)
        git_status=$gitStatus; executable_path=$exePath
        executable_sha256=(Get-Sha256 $exePath); application_version=$version
        input_path=$csvPath; input_sha256=(Get-Sha256 $csvPath)
        input_hash_policy='SHA-256 of exact bytes, no newline normalization'
        scenario_counts=$ScenarioCounts; seeds=@($Seeds | ForEach-Object { [string]$_ })
        horizon_trading_days=$HorizonTradingDays; trading_days_per_year=$TradingDaysPerYear
        backend='serial'; warmups=$warmups; measured_repetitions=$repetitions
        process_policy='New CLI process for every run; engine time only'
        timing_scope='Excludes process startup, CSV calibration, serialization and file I/O'
        repetitions_use_same_seed=($Mode -eq 'benchmark')
        benchmark_campaign_completed=$false
        supervisor_acceptance_evaluated=$false
        os_version=[Environment]::OSVersion.VersionString
        logical_processors=[Environment]::ProcessorCount
        powershell_version=$PSVersionTable.PSVersion.ToString()
        hardware_and_power_conditions='See docs/environment.md; record power/thermal conditions separately'
        executable_source_commit_verified=$false
    }
    # A commit hash alone does not prove that the executable was built from it.
    $cachePath = Join-Path (Split-Path -Parent (Split-Path -Parent $exePath)) 'CMakeCache.txt'
    if (Test-Path -LiteralPath $cachePath) {
        Copy-Item -LiteralPath $cachePath -Destination (Join-Path $outputDirectory 'CMakeCache.txt')
        $manifest['cmake_cache_sha256'] = Get-Sha256 $cachePath
    }
    $manifestPath = Join-Path $outputDirectory 'manifest.json'
    Write-JsonFile $manifestPath $manifest
    $summary = New-Object 'System.Collections.Generic.List[object]'
    try {
        foreach ($n in $ScenarioCounts) {
            foreach ($seed in $Seeds) {
                Write-Host "Running mode=$Mode N=$n seed=$seed"
                for ($i = 1; $i -le $warmups; $i++) {
                    $null = Invoke-Sample $n $seed 'warmup' $i
                }
                $times = New-Object 'System.Collections.Generic.List[double]'
                for ($i = 1; $i -le $repetitions; $i++) {
                    $phase = $Mode
                    $run = Invoke-Sample $n $seed $phase $i
                    $times.Add([double]$run.end_to_end_ms)
                }
                if ($Mode -eq 'benchmark') {
                    $mean = ($times | Measure-Object -Average).Average
                    $squared = 0.0
                    foreach ($time in $times) { $squared += ($time - $mean) * ($time - $mean) }
                    $std = [Math]::Sqrt($squared / ($times.Count - 1))
                    $throughput = $null
                    if ($mean -gt 0) { $throughput = 1000.0 * $n / $mean }
                    $summary.Add([pscustomobject][ordered]@{
                        backend='serial'; scenarios=$n; seed=[string]$seed
                        warmups=$warmups; repetitions=$times.Count
                        mean_ms=(Format-Number $mean); sample_stddev_ms=(Format-Number $std)
                        scenarios_per_second=$(if ($null -eq $throughput) { '' } else { Format-Number $throughput })
                    })
                }
            }
        }
        if ((Get-Sha256 $csvPath) -ne $manifest.input_sha256 -or
            (Get-Sha256 $exePath) -ne $manifest.executable_sha256) {
            throw 'Input or executable bytes changed during the experiment.'
        }
        $endCommit = (& git rev-parse HEAD | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $endCommit -ne $commit) {
            throw 'Git revision changed during the experiment.'
        }
        if ($Mode -eq 'benchmark') {
            $summary | Export-Csv -LiteralPath (Join-Path $outputDirectory 'timing-summary.csv') `
                -NoTypeInformation -Encoding UTF8
            $manifest['benchmark_campaign_completed'] = $true
        }
        $manifest['status'] = 'completed'
    } catch {
        $manifest['status'] = 'failed'
        $manifest['error'] = $_.Exception.Message
        throw
    } finally {
        $manifest['finished_utc'] = [DateTime]::UtcNow.ToString('o')
        Write-JsonFile $manifestPath $manifest
        Write-Host "Results directory: $outputDirectory"
    }
} finally {
    Pop-Location
}
