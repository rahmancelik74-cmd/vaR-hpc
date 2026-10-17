$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/equity-data-common.ps1')
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testRoot=Join-Path $root ('data/local/test-calendar-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
$metadata=[pscustomobject]@{source_name='Artificial calendar fixture';source_url='https://example.invalid/fixture.csv'
    symbol='TEST';currency='USD';retrieved_utc='2020-01-01T00:00:00Z';download_method='Generated fixture'
    price_adjustment_policy='unadjusted';price_policy_url='https://example.invalid/policy';local_reuse_conditions='Project fixture'
    reuse_policy_url='https://example.invalid/policy';local_use_verified=$true;redistribution_permission='verified';data_kind='artificial_fixture'}
$metadataFile=Join-Path $testRoot 'metadata.json';Write-EquityJson $metadataFile $metadata
$checker=Join-Path $root 'scripts/check-equity-calendar.ps1'
$script:checks=0
function Audit-Fixture([string]$Name,[string[]]$Dates,[string]$Start,[string]$End,[bool]$Pass) {
    $inputFile=Join-Path $testRoot ($Name+'.csv')
    $text="date,close`n"+(@($Dates | ForEach-Object {$_+',100'}) -join "`n")+"`n"
    [IO.File]::WriteAllText($inputFile,$text,$utf8)
    $importFolder=Join-Path $testRoot $Name
    Convert-EquityData $inputFile $metadataFile $importFolder $Start $End | Out-Null
    $output=Join-Path $root ('results/calendar-fixture-'+[guid]::NewGuid().ToString('N'))
    $before=Get-EquityHash (Join-Path $importFolder 'prices.csv')
    $caught=$false
    try{& $checker -ImportDirectory $importFolder -OutputDirectory $output | Out-Null}catch {
        if($_.Exception.Message -notmatch 'Calendar discrepancies'){throw};$caught=$true
    }
    if($caught -eq $Pass){throw "Calendar fixture status mismatch: $Name"}
    $report=Get-Content -LiteralPath (Join-Path $output 'calendar-audit.json') -Raw | ConvertFrom-Json
    if((Get-EquityHash (Join-Path $importFolder 'prices.csv')) -cne $before -or
       $report.observations_filled -ne 0 -or $report.rows_removed -ne 0 -or $report.publication_authorized) {
        throw 'Audit mutated data or granted publication'
    }
    $script:checks++
    return [pscustomobject]@{report=$report;import=$importFolder;output=$output}
}
# Early closes are expected sessions; weekends, holidays and the special mourning closure are not.
$early=Audit-Fixture 'early' @('2024-12-23','2024-12-24','2024-12-26') '2024-12-21' '2024-12-26' $true
if($early.report.expected_sessions -ne 3){throw 'Early-close session was excluded'}
$standalone=Join-Path $root ('results/calendar-fixture-'+[guid]::NewGuid().ToString('N'))
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -ImportDirectory $early.import -OutputDirectory $standalone | Out-Null
if($LASTEXITCODE -ne 0){throw 'Standalone calendar CLI failed'};$script:checks++
# Relative outputs follow the PowerShell location even when the process directory differs.
$relativeOutput='results/calendar-fixture-'+[guid]::NewGuid().ToString('N')
$processDirectory=[Environment]::CurrentDirectory
Push-Location -LiteralPath $root
try {
    [Environment]::CurrentDirectory=$testRoot
    & $checker -ImportDirectory $early.import -OutputDirectory $relativeOutput | Out-Null
    if(-not (Test-Path -LiteralPath (Join-Path $root ($relativeOutput+'/calendar-audit.json')))) {
        throw 'Relative output did not follow the PowerShell location'
    }
    $script:checks++
} finally {
    [Environment]::CurrentDirectory=$processDirectory
    Pop-Location
}
$special=Audit-Fixture 'mourning' @('2025-01-06','2025-01-07','2025-01-08','2025-01-10') '2025-01-06' '2025-01-12' $true
if($special.report.expected_sessions -ne 4){throw 'Special closure was treated as an open session'}
$missing=Audit-Fixture 'missing' @('2024-12-23','2024-12-26','2024-12-27') '2024-12-23' '2024-12-27' $false
if(@($missing.report.missing_dates).Count -ne 1 -or $missing.report.missing_dates[0] -cne '2024-12-24') {throw 'Missing early close not reported'}
$extra=Audit-Fixture 'extra' @('2025-01-06','2025-01-07','2025-01-08','2025-01-09','2025-01-10','2025-01-11') '2025-01-06' '2025-01-12' $false
if(@($extra.report.unexpected_dates).Count -ne 2){throw 'Unexpected closure/weekend rows not reported'}
function Must-Reject([scriptblock]$Action,[string]$Pattern) {
    $caught=$false;try{& $Action | Out-Null}catch{if($_.Exception.Message -notmatch $Pattern){throw};$caught=$true}
    if(-not $caught){throw "Invalid audit accepted: $Pattern"};$script:checks++
}
Must-Reject {& $checker -ImportDirectory $early.import -OutputDirectory $early.output} 'new directory'
Must-Reject {& $checker -ImportDirectory $early.import -OutputDirectory (Join-Path $root 'output/calendar-forbidden')} 'ignored results'
$calendar=Get-Content (Join-Path $root 'data/calendars/nasdaq-us-equities-2023-2025.json') -Raw | ConvertFrom-Json
$calendar.full_closures+=@('2024-12-24')
$calendarFile=Join-Path $testRoot 'conflicting-calendar.json';Write-EquityJson $calendarFile $calendar
Must-Reject {& $checker -ImportDirectory $early.import -OutputDirectory (Join-Path $root 'results/calendar-invalid') -CalendarFile $calendarFile} 'conflicts'
$calendar.full_closures+=@('2024-12-24');Write-EquityJson $calendarFile $calendar
Must-Reject {& $checker -ImportDirectory $early.import -OutputDirectory (Join-Path $root 'results/calendar-invalid') -CalendarFile $calendarFile} 'duplicate'
$manifestFile=Join-Path $early.import 'manifest.json'
$manifest=Get-Content $manifestFile -Raw | ConvertFrom-Json
$manifest.requested_date_start='2022-12-31';Write-EquityJson $manifestFile $manifest
Must-Reject {& $checker -ImportDirectory $early.import -OutputDirectory (Join-Path $root 'results/calendar-invalid')} 'outside calendar'
$manifest.requested_date_start='2024-12-21';$manifest.row_count=999;Write-EquityJson $manifestFile $manifest
Must-Reject {& $checker -ImportDirectory $early.import -OutputDirectory (Join-Path $root 'results/calendar-invalid')} 'coverage metadata'
$manifest.row_count=3;Write-EquityJson $manifestFile $manifest
[IO.File]::AppendAllText((Join-Path $early.import 'prices.csv'),"`n",$utf8)
Must-Reject {& $checker -ImportDirectory $early.import -OutputDirectory (Join-Path $root 'results/calendar-invalid')} 'hash mismatch'
Write-Output "Calendar audit: $script:checks artificial checks passed; no provider observations used."
