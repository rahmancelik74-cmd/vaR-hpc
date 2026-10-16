[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ImportDirectory,
      [Parameter(Mandatory=$true)][string]$CpuExecutable,
      [Parameter(Mandatory=$true)][string]$OutputDirectory,
      [string]$CudaExecutable='',
      [ValidateSet('serial','openmp')][string[]]$CpuBackends=@('serial','openmp'),
      [switch]$FixtureTestOnly)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'equity-data-common.ps1')
$folder=(Resolve-Path -LiteralPath $ImportDirectory).Path
$importPath=Join-Path $folder 'manifest.json';$import=Get-Content -LiteralPath $importPath -Raw | ConvertFrom-Json
if($FixtureTestOnly) {
    if($import.source.data_kind -cne 'artificial_fixture'){throw 'Fixture test mode requires explicitly artificial data'}
} elseif($import.source.data_kind -cne 'historical_provider') {
    throw 'Historical integration requires genuine provider data, not a fixture'
}
if($CpuBackends.Count -lt 1 -or @($CpuBackends | Sort-Object -Unique).Count -ne $CpuBackends.Count){throw 'Empty or duplicate CPU backend selection'}
if(-not $FixtureTestOnly -and ($CpuBackends.Count -ne 2 -or 'serial' -cnotin $CpuBackends -or 'openmp' -cnotin $CpuBackends)) {
    throw 'Historical integration requires both serial and OpenMP checks'
}
foreach($item in @(@('raw.csv','raw_sha256'),@('prices.csv','converted_sha256'),@('source-metadata.json','source_metadata_sha256'))) {
    if((Get-EquityHash (Join-Path $folder $item[0])) -cne $import.($item[1])){throw 'Imported artifact hash mismatch'}
}
$csv=Join-Path $folder 'prices.csv'
$rows=@((Read-EquityPrices ([IO.File]::ReadAllBytes($csv))).rows)
$reference=Get-EquityCalibration $rows
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$output=[IO.Path]::GetFullPath($OutputDirectory)
$prefix=(Join-Path $root 'results').TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
if(-not $output.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)) {
    throw 'Integration output must be a new directory under ignored results'
}
$cpu=(Resolve-Path -LiteralPath $CpuExecutable).Path
$configurations=@($CpuBackends | ForEach-Object {@{backend=$_;executable=$cpu}})
if($CudaExecutable -ne ''){$configurations+=@{backend='cuda';executable=(Resolve-Path -LiteralPath $CudaExecutable).Path}}
$manifest=[ordered]@{schema_version=1;purpose='Historical integration and separate CUDA connectivity smoke only'
    data_kind=$import.source.data_kind;requested_cpu_backends=$CpuBackends
    status='running';started_utc=[DateTimeOffset]::UtcNow.ToString('o');source_revision=(& git -C $root rev-parse HEAD).Trim()
    git_dirty=(@(& git -C $root status --porcelain).Count -gt 0);input_sha256=(Get-EquityHash $csv)
    import_manifest_sha256=(Get-EquityHash $importPath);executable_hashes=@($configurations | ForEach-Object {
        @{backend=$_.backend;sha256=(Get-EquityHash $_.executable)}})
    source_to_binary_verified=$false;scenario_count=10000;seed='42';working_settings=$import.working_settings
    native_samples_compared_between_engines=$false;full_scale_gpu_acceptance=$false;performance_benchmark=$false
    process_policy='One fresh process per native backend run; no timing comparisons'
    independent_method='log(price ratio), two-pass sample variance; C++ uses log difference and Welford'
    calibration_tolerance='abs(actual-reference) <= 1e-12*max(1,abs(reference))'
    cuda_smoke=($(if($CudaExecutable -eq ''){'not_requested'}else{'pending'}))}
if($FixtureTestOnly){$manifest.purpose='Artificial-fixture integration runner test; not historical observations'}
New-Item -ItemType Directory -Path $output -Force | Out-Null
try {
    Write-EquityJson (Join-Path $output 'independent-calibration.json') $reference
    $returnLines=@('date,log_return')
    for($i=0;$i -lt $reference.returns.Count;$i++){$returnLines+= $rows[$i+1].date+','+$reference.returns[$i].ToString('G17',$script:EquityCulture)}
    [IO.File]::WriteAllText((Join-Path $output 'independent-log-returns.csv'),($returnLines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    foreach($configuration in $configurations) {
        $arguments=@('--csv',$csv,'10000','42','10','252','--backend',$configuration.backend)
        if($configuration.backend -ceq 'openmp'){$arguments+=@('--threads','4')}
        $arguments+='--json'
        $raw=@(& $configuration.executable @arguments) -join "`n"
        if($LASTEXITCODE -ne 0){throw 'Historical backend execution failed'}
        $run=$raw | ConvertFrom-Json
        Write-EquityJson (Join-Path $output ($configuration.backend+'.json')) $run
        Assert-EquityCalibration $run $reference $rows
        if($run.backend -cne $configuration.backend -or $run.scenarios -ne 10000 -or $run.seed -cne '42' -or
            $run.estimates.Count -ne 2 -or [double]$run.estimates[0].confidence -ne .95 -or [double]$run.estimates[1].confidence -ne .99) {
            throw 'Historical run contract mismatch'
        }
        if($run.backend -ceq 'openmp' -and ($run.requested_threads -ne 4 -or $run.threads_used -lt 1 -or $run.threads_used -gt 4)) {
            throw 'OpenMP team metadata mismatch'
        }
        foreach($estimate in $run.estimates) {
            foreach($value in @($estimate.mc_var,$estimate.analytical_var)) {
                if([double]::IsNaN($value) -or [double]::IsInfinity($value)){throw 'Nonfinite historical estimate'}
            }
        }
        if($run.backend -ceq 'cuda') {
            if($run.cuda.scenario_limit -ne 10000 -or $run.cuda.host_sorting_used -ne $false -or $run.cuda.cub_version -ne 300403 -or
                $run.random_source -cne 'cuRAND/PHILOX4_32_10/normal-double'){throw 'CUDA skeleton metadata mismatch'}
            $manifest.cuda_smoke='passed_connectivity_only'
        }
    }
    if((Get-EquityHash $csv) -cne $manifest.input_sha256 -or (Get-EquityHash $importPath) -cne $manifest.import_manifest_sha256) {
        throw 'Input changed during integration checks'
    }
    for($i=0;$i -lt $configurations.Count;$i++) {
        if((Get-EquityHash $configurations[$i].executable) -cne $manifest.executable_hashes[$i].sha256){throw 'Executable changed during checks'}
    }
    $manifest.status='passed'
} catch {$manifest.status='failed';$manifest.error=$_.Exception.Message;throw}
finally {
    $manifest.finished_utc=[DateTimeOffset]::UtcNow.ToString('o')
    Write-EquityJson (Join-Path $output 'manifest.json') $manifest
}
if($FixtureTestOnly){Write-Output 'Artificial-fixture integration runner checks passed; no historical observations used.'}
else{Write-Output 'Historical integration checks passed; no GPU benchmark or full-scale acceptance claimed.'}
