[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('first-term','final')][string]$Demo,
    [Parameter(Mandatory=$true)][string]$BuildDirectory
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [Text.UTF8Encoding]::new($false)
$clock = [Diagnostics.Stopwatch]::StartNew()
$records = New-Object 'System.Collections.Generic.List[object]'
$status = 'failed'
Push-Location -LiteralPath $root
try {
    # A new ignored directory retains partial attempts; existing files are never replaced.
    $directory = Join-Path $root ('results/live-demo-{0}-{1}-{2}' -f $Demo,
        (Get-Date -Format 'yyyyMMdd-HHmmss'), [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $directory | Out-Null
    function Invoke-DemoCommand([string]$Program, [string[]]$Arguments) {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $entry = [ordered]@{program=$Program; arguments=$Arguments; exit_code=$null;
            duration_seconds=$null; output=$null}
        $records.Add($entry)
        Write-Host ('> ' + $Program + ' ' + (($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '))
        try {
            # Capture native stderr as well as stdout, including on a nonzero exit.
            $ErrorActionPreference = 'Continue'
            $raw = @(& $Program @Arguments 2>&1)
            $code = $LASTEXITCODE
            $entry.exit_code = $code
            $entry.output = ($raw | Out-String)
            Write-Host $entry.output
        } finally {
            $watch.Stop()
            $entry.duration_seconds = $watch.Elapsed.TotalSeconds
            [IO.File]::WriteAllText((Join-Path $directory 'commands.json'),
                (ConvertTo-Json -InputObject @($records.ToArray()) -Depth 12), $utf8)
        }
        if ($null -eq $entry.exit_code -or $entry.exit_code -ne 0) {
            throw "Command failed. Retain $directory and resolve the error before retrying."
        }
        return $entry.output
    }
    $build = (Resolve-Path -LiteralPath $BuildDirectory).Path
    $exe = Join-Path $build 'Release/mc_var.exe'
    $test = Join-Path $build 'Release/mc_openmp_tests.exe'
    foreach ($path in @($exe,$test,(Join-Path $build 'CMakeCache.txt'),'data/synthetic_prices.csv')) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing prerequisite: $path" }
    }
    $cache = Get-Content -LiteralPath (Join-Path $build 'CMakeCache.txt')
    if ($cache -notcontains 'MC_ENABLE_OPENMP:BOOL=ON') { throw 'OpenMP must be enabled.' }
    if ($Demo -eq 'final' -and $cache -notcontains 'MC_ENABLE_CUDA:BOOL=ON') {
        throw 'Final live CUDA demo requires a CUDA-enabled build. No fallback was run.'
    }
    $head = Invoke-DemoCommand 'git' @('rev-parse','HEAD')
    $gitStatus = Invoke-DemoCommand 'git' @('status','--short')
    $null = Invoke-DemoCommand $exe @('--version')
    $bindings = [ordered]@{source_head=$head.Trim(); git_status=$gitStatus;
        executable_sha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash;
        test_sha256=(Get-FileHash -LiteralPath $test -Algorithm SHA256).Hash;
        cache_sha256=(Get-FileHash -LiteralPath (Join-Path $build 'CMakeCache.txt') -Algorithm SHA256).Hash;
        fixture_sha256=(Get-FileHash -LiteralPath 'data/synthetic_prices.csv' -Algorithm SHA256).Hash;
        executable_source_commit_verified=$false}
    Write-Host 'SYNTHETIC data. Computational correctness/performance; no market prediction claim.'
    Write-Host 'Double terminal GBM; loss=V0-VT; signed VaR; rank=ceil(alpha*N)-1, ascending, no interpolation.'
    Write-Host 'q=1; V0=last close; annual price drift; volatility per sqrt(year); T=10/252 years.'
    Write-Host 'LIVE illustrative demo timings only. Fresh processes; no formal benchmark or acceptance campaign.'
    $null = Invoke-DemoCommand $test @()
    $common = @('--csv','data/synthetic_prices.csv','100000','42','10','252')
    $configurations = @(
        @{name='serial'; args=@('--backend','serial')},
        @{name='openmp-1'; args=@('--backend','openmp','--threads','1')},
        @{name='openmp-4'; args=@('--backend','openmp','--threads','4')}
    )
    if ($Demo -eq 'final') {
        $configurations += @(
            @{name='full-device'; args=@('--backend','cuda','--cuda-mode','full-device')},
            @{name='hybrid'; args=@('--backend','cuda','--cuda-mode','hybrid','--batch-size','65535')}
        )
    }
    foreach ($configuration in $configurations) {
        $raw = Invoke-DemoCommand $exe ($common + $configuration.args + @('--json'))
        [IO.File]::WriteAllText((Join-Path $directory ($configuration.name + '.json')), $raw, $utf8)
        $run = $raw | ConvertFrom-Json
        if ($run.scenarios -ne 100000 -or @($run.estimates).Count -ne 2 -or
            $run.input_mode -ne 'csv_calibration') { throw 'Unexpected demo result.' }
        if ($configuration.name -eq 'hybrid') {
            if ($run.cuda.mode -ne 'hybrid' -or $run.cuda.batch_count -ne 2 -or
                $run.cuda.effective_batch_size -ne 65536) { throw 'Unexpected hybrid partition.' }
            Write-Host 'Hybrid: one global nearest-rank quantile over all scalar losses, never averaged batch VaRs.'
        }
    }
    Write-Host 'Equal native seeds are not common samples. The focused test supplied identical normals.'
    Write-Host 'Historical evidence: docs/live-demos.md. Live outputs do not replace five-seed acceptance or formal timings.'
    $status = 'rehearsed'
} finally {
    $clock.Stop()
    if (Test-Path variable:directory) {
        $summary = [ordered]@{demo=$Demo; status=$status; presented=$false; submitted=$false;
            duration_seconds=$clock.Elapsed.TotalSeconds; bindings=$null;
            timing_class='illustrative rehearsal only; not formal benchmark';
            power_thermal_conditions='Not measured; clocks, temperatures and equilibrium unknown'}
        if (Test-Path variable:bindings) { $summary.bindings = $bindings }
        [IO.File]::WriteAllText((Join-Path $directory 'summary.json'),
            (ConvertTo-Json -InputObject $summary -Depth 12), $utf8)
        Write-Host "Rehearsal log: $directory; status=$status; seconds=$($clock.Elapsed.TotalSeconds)"
    }
    Pop-Location
}
