[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ImportDirectory,
      [Parameter(Mandatory=$true)][string]$OutputDirectory,
      [string]$CalendarFile='')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'equity-data-common.ps1')
if($CalendarFile -eq ''){$CalendarFile=Join-Path $PSScriptRoot '../data/calendars/nasdaq-us-equities-2023-2025.json'}
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$output=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
$prefix=(Join-Path $root 'results').TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
if(-not $output.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)) {
    throw 'Calendar output requires a new directory under ignored results'
}
$folder=(Resolve-Path -LiteralPath $ImportDirectory).Path
$manifestPath=Join-Path $folder 'manifest.json'
$manifestHash=Get-EquityHash $manifestPath
$import=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$calendarPath=(Resolve-Path -LiteralPath $CalendarFile).Path
$calendarHash=Get-EquityHash $calendarPath
$calendar=Get-Content -LiteralPath $calendarPath -Raw | ConvertFrom-Json
if($calendar.schema_version -ne 1 -or $calendar.market -cne 'Nasdaq US cash equities' -or
   $calendar.date_basis -cne 'America/New_York session date' -or @($calendar.sources).Count -lt 1) {
    throw 'Unsupported or undocumented calendar'
}
foreach($date in @($calendar.coverage_start,$calendar.coverage_end,$import.requested_date_start,$import.requested_date_end)) {
    Assert-EquityDate $date
}
if($calendar.coverage_start -cgt $calendar.coverage_end -or
   $import.requested_date_start -cgt $import.requested_date_end -or
   $import.requested_date_start -clt $calendar.coverage_start -or
   $import.requested_date_end -cgt $calendar.coverage_end) {throw 'Requested interval is outside calendar coverage or reversed'}
$closed=[Collections.Generic.HashSet[string]]::new()
$early=[Collections.Generic.HashSet[string]]::new()
foreach($kind in @('full_closures','early_closes')) {
    if($kind -ceq 'full_closures'){$set=$closed}else{$set=$early}
    foreach($date in $calendar.$kind) {
        Assert-EquityDate $date
        $day=[datetime]::ParseExact($date,'yyyy-MM-dd',$script:EquityCulture)
        if($date -clt $calendar.coverage_start -or $date -cgt $calendar.coverage_end -or
           $day.DayOfWeek -in @([DayOfWeek]::Saturday,[DayOfWeek]::Sunday) -or -not $set.Add($date)) {
            throw 'Invalid or duplicate calendar exception'
        }
    }
}
foreach($date in $early){if($closed.Contains($date)){throw 'Early close conflicts with full closure'}}
$artifacts=@(@('raw.csv','raw_sha256'),@('prices.csv','converted_sha256'),@('source-metadata.json','source_metadata_sha256'))
foreach($item in $artifacts) {
    if((Get-EquityHash (Join-Path $folder $item[0])) -cne $import.($item[1])){throw 'Imported artifact hash mismatch'}
}
$rows=@((Read-EquityPrices ([IO.File]::ReadAllBytes((Join-Path $folder 'prices.csv')))).rows)
$observed=[Collections.Generic.HashSet[string]]::new()
$previous=''
foreach($row in $rows) {
    if($row.date -cle $previous -or $row.date -clt $import.requested_date_start -or
       $row.date -cgt $import.requested_date_end -or -not $observed.Add($row.date)){throw 'Invalid imported date order or interval'}
    $previous=$row.date
}
if($rows.Count -ne $import.row_count -or $rows[0].date -cne $import.actual_date_start -or
   $rows[-1].date -cne $import.actual_date_end){throw 'Import coverage metadata mismatch'}
$expected=[Collections.Generic.HashSet[string]]::new()
$sessions=[Collections.Generic.List[object]]::new()
$day=[datetime]::ParseExact($import.requested_date_start,'yyyy-MM-dd',$script:EquityCulture)
$end=[datetime]::ParseExact($import.requested_date_end,'yyyy-MM-dd',$script:EquityCulture)
for(;$day -le $end;$day=$day.AddDays(1)) {
    $date=$day.ToString('yyyy-MM-dd',$script:EquityCulture)
    if($day.DayOfWeek -notin @([DayOfWeek]::Saturday,[DayOfWeek]::Sunday) -and -not $closed.Contains($date)) {
        [void]$expected.Add($date)
        $sessions.Add([pscustomobject]@{date=$date;early_close=$early.Contains($date);observed=$observed.Contains($date)})
    }
}
$missing=@($expected | Where-Object {-not $observed.Contains($_)} | Sort-Object)
$unexpected=@($observed | Where-Object {-not $expected.Contains($_)} | Sort-Object)
$matched=$missing.Count -eq 0 -and $unexpected.Count -eq 0
# The audit never modifies the import manifest or treats matching dates as publication rights.
$report=[ordered]@{schema_version=1;purpose='Private local session-date completeness audit, not price validation or research approval'
    checked_utc=[DateTimeOffset]::UtcNow.ToString('o');status=($(if($matched){'matched'}else{'discrepancies'}))
    data_kind=$import.source.data_kind;source_revision=(& git -C $root rev-parse HEAD).Trim()
    git_dirty=(@(& git -C $root status --porcelain).Count -gt 0);audit_script_sha256=(Get-EquityHash $PSCommandPath)
    parser_sha256=(Get-EquityHash (Join-Path $PSScriptRoot 'equity-data-common.ps1'))
    import_manifest_sha256=$manifestHash;input_sha256=$import.converted_sha256;calendar_sha256=$calendarHash
    calendar=$calendar;requested_start=$import.requested_date_start;requested_end=$import.requested_date_end
    expected_sessions=$expected.Count;observed_rows=$rows.Count;missing_dates=$missing;unexpected_dates=$unexpected
    observations_filled=0;rows_removed=0;publication_authorized=$false;price_accuracy_verified=$false
    limitation='Date-set equality only; no intraday coverage, price, corporate-action or individual-security halt validation'
    yearly=@(([int]$import.requested_date_start.Substring(0,4))..([int]$import.requested_date_end.Substring(0,4)) | ForEach-Object {
        $year=[string]$_
        [ordered]@{year=$_;expected=@($expected | Where-Object {$_.StartsWith($year)}).Count
            observed=@($observed | Where-Object {$_.StartsWith($year)}).Count
            missing=@($missing | Where-Object {$_.StartsWith($year)}).Count
            unexpected=@($unexpected | Where-Object {$_.StartsWith($year)}).Count}
    })}
foreach($item in $artifacts) {
    if((Get-EquityHash (Join-Path $folder $item[0])) -cne $import.($item[1])){throw 'Input changed during calendar audit'}
}
if((Get-EquityHash $manifestPath) -cne $manifestHash -or (Get-EquityHash $calendarPath) -cne $calendarHash) {
    throw 'Manifest or calendar changed during audit'
}
New-Item -ItemType Directory -Path $output | Out-Null
Write-EquityJson (Join-Path $output 'calendar-audit.json') $report
$sessions | Export-Csv -LiteralPath (Join-Path $output 'expected-sessions.csv') -NoTypeInformation -Encoding UTF8
Write-Output 'Calendar audit saved locally; input bytes preserved and publication remains unauthorized.'
if(-not $matched){throw 'Calendar discrepancies found; review the private audit before changing any data'}
