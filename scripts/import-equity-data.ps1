[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InputFile,
      [Parameter(Mandatory=$true)][string]$MetadataFile,
      [Parameter(Mandatory=$true)][string]$OutputDirectory,
      [string]$RequestedStart='2023-01-01',[string]$RequestedEnd='2025-12-31',
      [switch]$AllowReordering,[string]$ErrorReportFile,
      [ValidateSet('existing_csv','kibot_daily')][string]$SourceFormat='existing_csv')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'equity-data-common.ps1')
if($ErrorReportFile) {
    # Deliberate per-child redirected output encoding; no global console change.
    [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
    $PSBoundParameters.Remove('ErrorReportFile') | Out-Null
}
try { Convert-EquityData @PSBoundParameters | ConvertTo-Json -Depth 12 }
catch {
    if($ErrorReportFile) {
        Write-EquityJson $ErrorReportFile @{schema_version=1;code=$_.Exception.Data['validation_code']}
    }
    throw
}
