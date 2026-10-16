[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InputFile,
      [Parameter(Mandatory=$true)][string]$MetadataFile,
      [Parameter(Mandatory=$true)][string]$OutputDirectory,
      [string]$RequestedStart='2023-01-01',[string]$RequestedEnd='2025-12-31',
      [switch]$AllowReordering,
      [ValidateSet('existing_csv','kibot_daily')][string]$SourceFormat='existing_csv')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'equity-data-common.ps1')
Convert-EquityData @PSBoundParameters | ConvertTo-Json -Depth 12
