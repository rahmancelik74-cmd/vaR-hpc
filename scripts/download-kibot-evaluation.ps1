[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputDirectory,
      [string]$RequestedStart='2023-01-01',[string]$RequestedEnd='2025-12-31')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'equity-data-common.ps1')
Assert-EquityDate $RequestedStart;Assert-EquityDate $RequestedEnd
if($RequestedStart -cgt $RequestedEnd){throw 'Requested date range is reversed'}
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$output=[IO.Path]::GetFullPath($OutputDirectory)
$prefix=(Join-Path $root 'data/local').TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
if(-not $output.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)) {
    throw 'Download requires a new directory under ignored data/local'
}
$start=[datetime]::ParseExact($RequestedStart,'yyyy-MM-dd',$script:EquityCulture).ToString('MM/dd/yyyy',$script:EquityCulture)
$end=[datetime]::ParseExact($RequestedEnd,'yyyy-MM-dd',$script:EquityCulture).ToString('MM/dd/yyyy',$script:EquityCulture)
$url='https://api.kibot.com/?action=history&symbol=MSFT&interval=daily&startdate='+$start+'&enddate='+$end+'&unadjusted=1'
New-Item -ItemType Directory -Path $output -Force | Out-Null
$record=[ordered]@{purpose='Local MSFT provider evaluation; not a final public research dataset'
    status='started';requested_date_start=$RequestedStart;requested_date_end=$RequestedEnd;source_url=$url
    source_revision=(& git -C $root rev-parse HEAD).Trim()
    git_dirty=(@(& git -C $root status --porcelain).Count -gt 0)
    downloader_sha256=(Get-EquityHash $PSCommandPath)
    parser_sha256=(Get-EquityHash (Join-Path $PSScriptRoot 'equity-data-common.ps1'));policy_snapshots=@()}
try {
    # Retain complete policy pages with their notices locally, never in Git.
    $policies=@(@('license','https://www.kibot.com/license.html'),
        @('access','https://www.kibot.com/api/api-overview.html'),
        @('history','https://www.kibot.com/api/history-request.html'),
        @('format','https://www.kibot.com/file-format/data-format-reference.html'))
    foreach($policy in $policies) {
        $path=Join-Path $output ($policy[0]+'.html')
        $retrieved=[DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fff'Z'")
        Invoke-WebRequest -Uri $policy[1] -UseBasicParsing -TimeoutSec 30 -OutFile $path
        $record.policy_snapshots+=@{url=$policy[1];file=($policy[0]+'.html');retrieved_utc=$retrieved;sha256=(Get-EquityHash $path)}
    }
    $session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
    # These are the provider's documented public evaluation credentials.
    $login=Invoke-WebRequest -Uri 'https://api.kibot.com/?action=login&user=guest&password=guest' -WebSession $session -UseBasicParsing -TimeoutSec 30
    if($login.StatusCode -ne 200){throw 'Documented Kibot guest login failed'}
    $raw=Join-Path $output 'raw.txt'
    $retrieved=[DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fff'Z'")
    Invoke-WebRequest -Uri $url -WebSession $session -UseBasicParsing -TimeoutSec 30 -OutFile $raw
    $record.retrieved_utc=$retrieved;$record.completed_utc=[DateTimeOffset]::UtcNow.ToString('o')
    $record.raw_sha256=Get-EquityHash $raw
    # A successful HTTP status is insufficient: errors/HTML must fail parsing.
    $parsed=Read-EquityPrices ([IO.File]::ReadAllBytes($raw)) 'kibot_daily'
    $record.received_rows=@($parsed.rows).Count
    $metadata=[ordered]@{source_name='Kibot public guest daily evaluation';source_url=$url;symbol='MSFT';currency='USD'
        currency_basis_url='https://finance.yahoo.com/quote/MSFT/history/'
        currency_basis='USD denomination of the NASDAQ-listed MSFT equity; not a currency field returned by the CSV'
        retrieved_utc=$retrieved;download_method='Documented HTTPS guest login then one daily history request with unadjusted=1'
        price_adjustment_policy='unadjusted';price_policy_url='https://www.kibot.com/api/history-request.html'
        close_definition='Last regular-session trade, not necessarily the official closing auction price'
        local_reuse_conditions='Guest access for evaluation; license permits internal use and archival copies, prohibits redistribution including related/derived data'
        reuse_policy_url='https://www.kibot.com/license.html';local_use_verified=$true
        redistribution_permission='prohibited';data_kind='historical_provider';usage_scope='Local pipeline evaluation only'
        final_study_dataset_approved=$false;policy_reviewed_local_date='2026-10-17'
        policy_review_note='Evaluation/internal-use scope reviewed for this milestone; re-review changed terms before later use'}
    Write-EquityJson (Join-Path $output 'source-metadata.json') $metadata
    $record.status='downloaded_and_parsed'
} catch {$record.status='failed';$record.error=$_.Exception.Message;throw}
finally{Write-EquityJson (Join-Path $output 'retrieval.json') $record}
Write-Output 'MSFT evaluation response preserved locally; redistribution is prohibited. Convert explicitly with -SourceFormat kibot_daily.'
