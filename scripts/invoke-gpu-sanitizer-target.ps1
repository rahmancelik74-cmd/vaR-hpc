param([Parameter(Mandatory=$true)][string]$SpecPath)
# Child wrapper preserves the target exit status separately from the sanitizer status.
. (Join-Path $PSScriptRoot 'gpu-record-common.ps1')
try {
    $spec=Get-Content -Encoding UTF8 -LiteralPath $SpecPath -Raw | ConvertFrom-Json
    $r=Invoke-GpuProcess $spec.executable @($spec.arguments) $spec.prefix $spec.timeout_seconds
    if($r.start_error -or $r.timed_out){exit 98}
    exit $r.exit_code
} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 97 }
