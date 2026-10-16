Set-StrictMode -Version 2.0
$script:EquityCulture=[Globalization.CultureInfo]::InvariantCulture
function Get-EquityHash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Write-EquityJson([string]$Path,$Value) {
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Value -Depth 12)+"`n",[Text.UTF8Encoding]::new($false))
}
function Assert-EquityDate([string]$Value) {
    $parsed=[datetime]::MinValue
    if($Value -cnotmatch '^\d{4}-\d{2}-\d{2}$' -or -not [datetime]::TryParseExact(
        $Value,'yyyy-MM-dd',$script:EquityCulture,[Globalization.DateTimeStyles]::None,[ref]$parsed)) {
        throw 'Invalid date; expected a valid YYYY-MM-DD'
    }
}
function Get-EquityNumber([string]$Value,[bool]$Positive=$true) {
    $number=0.0
    if($Value -cnotmatch '^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$' -or
        -not [double]::TryParse($Value,[Globalization.NumberStyles]::Float,$script:EquityCulture,[ref]$number) -or
        [double]::IsNaN($number) -or [double]::IsInfinity($number) -or
        ($Positive -and $number -le 0) -or (-not $Positive -and $number -lt 0)) {
        throw 'Invalid numeric field; expected a finite positive price or nonnegative volume'
    }
    return $number
}
function Read-EquityPrices([byte[]]$Bytes) {
    # Narrow dialect: UTF-8, optional BOM, LF/CRLF, unquoted comma-separated fields.
    try{$text=[Text.UTF8Encoding]::new($false,$true).GetString($Bytes)}catch{throw 'Invalid UTF-8 source CSV'}
    if($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF){$text=$text.Substring(1)}
    if($text.Contains('"') -or $text -match '[^\x09\x0A\x0D\x20-\x7E]') {throw 'Unsupported CSV encoding or quoting'}
    if($text -match '\r(?!\n)'){throw 'Unsupported bare CR line ending'}
    $lines=@($text -split '\r?\n')
    if($lines.Count -gt 0 -and $lines[-1] -eq ''){$lines=$lines[0..($lines.Count-2)]}
    if($lines.Count -lt 4){throw 'At least three price rows are required'}
    $header=$lines[0]
    if($header -ceq 'date,close'){$dateIndex=0;$closeIndex=1}
    elseif($header -ceq 'Date,Open,High,Low,Close,Volume' -or
           $header -ceq 'Date,Open,High,Low,Close,Adj Close,Volume'){$dateIndex=0;$closeIndex=4}
    else {throw 'Unsupported CSV header; an explicit Close field is required (never Adj Close fallback)'}
    $columns=@($header.Split(','));$seen=[Collections.Generic.HashSet[string]]::new()
    $rows=[Collections.Generic.List[object]]::new()
    for($i=1;$i -lt $lines.Count;$i++) {
        try {
            $fields=@($lines[$i].Split(','))
            if($fields.Count -ne $columns.Count -or $lines[$i] -eq ''){throw 'Wrong field count or blank record'}
            $date=$fields[$dateIndex];Assert-EquityDate $date
            if(-not $seen.Add($date)){throw 'Duplicate date'}
            $values=@()
            for($j=1;$j -lt $fields.Count;$j++) {
                $volume=$columns[$j] -ceq 'Volume'
                $value=Get-EquityNumber $fields[$j] (-not $volume)
                if($volume -and $fields[$j] -cnotmatch '^\d+$'){throw 'Volume must be a nonnegative integer'}
                $values+=,$value
            }
            if($columns.Count -gt 2 -and ($values[2] -gt $values[0] -or $values[2] -gt $values[3] -or
                $values[1] -lt $values[0] -or $values[1] -lt $values[3] -or $values[2] -gt $values[1])) {
                throw 'Inconsistent OHLC range'
            }
            $rows.Add([pscustomobject]@{date=$date;close=(Get-EquityNumber $fields[$closeIndex]);close_text=$fields[$closeIndex]})
        } catch {throw "CSV line $($i+1): $($_.Exception.Message)"}
    }
    return [pscustomobject]@{rows=$rows.ToArray();selected_price_field=$columns[$closeIndex];header=$header}
}
function Assert-EquityMetadata($Metadata) {
    foreach($name in @('source_name','source_url','symbol','currency','retrieved_utc','download_method',
        'price_adjustment_policy','price_policy_url','local_reuse_conditions','reuse_policy_url','local_use_verified',
        'redistribution_permission','data_kind')) {
        if($name -cnotin $Metadata.PSObject.Properties.Name -or $null -eq $Metadata.$name -or
            [string]::IsNullOrWhiteSpace([string]$Metadata.$name)){throw "Missing source metadata: $name"}
        if($name -cne 'local_use_verified' -and $Metadata.$name -isnot [string]){throw "Source metadata must be text: $name"}
    }
    foreach($name in @('source_url','price_policy_url','reuse_policy_url')) {
        $uri=$null
        if(-not [uri]::TryCreate([string]$Metadata.$name,[UriKind]::Absolute,[ref]$uri) -or
            $uri.Scheme -cne 'https' -or $uri.UserInfo -ne '' -or $uri.Fragment -ne '' -or
            $uri.Query -match '(?i)(api.?key|token|secret|password|crumb)=') {throw 'Source/policy URLs must be HTTPS without credentials'}
    }
    if($Metadata.local_use_verified -isnot [bool] -or -not $Metadata.local_use_verified){throw 'Verified local-use conditions are required'}
    if($Metadata.redistribution_permission -cnotin @('unverified','prohibited','verified')){throw 'Invalid redistribution permission status'}
    if($Metadata.data_kind -cnotin @('historical_provider','artificial_fixture')){throw 'Invalid data kind'}
    if($Metadata.price_adjustment_policy -cnotin @('unadjusted','split_adjusted','split_and_dividend_adjusted')) {
        throw 'An explicit verified price-adjustment policy is required; unknown is not accepted'
    }
    if($Metadata.symbol -cnotmatch '^[A-Z0-9.\-]{1,24}$' -or $Metadata.currency -cnotmatch '^[A-Z]{3}$'){throw 'Invalid symbol or currency code'}
    $timestamp=[DateTimeOffset]::MinValue
    if([string]$Metadata.retrieved_utc -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$' -or
        -not [DateTimeOffset]::TryParse([string]$Metadata.retrieved_utc,$script:EquityCulture,
            [Globalization.DateTimeStyles]::None,[ref]$timestamp) -or $timestamp -gt [DateTimeOffset]::UtcNow) {
        throw 'Invalid or future original retrieval timestamp; expected UTC ISO 8601'
    }
}
function Convert-EquityData {
    param([string]$InputFile,[string]$MetadataFile,[string]$OutputDirectory,
          [string]$RequestedStart='2023-01-01',[string]$RequestedEnd='2025-12-31',[switch]$AllowReordering)
    Assert-EquityDate $RequestedStart;Assert-EquityDate $RequestedEnd
    if($RequestedStart -cgt $RequestedEnd){throw 'Requested date range is reversed'}
    $inputPath=(Resolve-Path -LiteralPath $InputFile).Path
    $metadataPath=(Resolve-Path -LiteralPath $MetadataFile).Path
    $bytes=[IO.File]::ReadAllBytes($inputPath)
    $metadataBytes=[IO.File]::ReadAllBytes($metadataPath)
    try{$metadata=[Text.UTF8Encoding]::new($false,$true).GetString($metadataBytes) | ConvertFrom-Json}
    catch{throw 'Invalid UTF-8 source metadata JSON'}
    Assert-EquityMetadata $metadata
    $parsed=Read-EquityPrices $bytes
    $rows=@($parsed.rows);$ascending=$true;$descending=$true
    for($i=1;$i -lt $rows.Count;$i++) {
        if($rows[$i].date -clt $rows[$i-1].date){$ascending=$false}else{$descending=$false}
    }
    $sourceOrder='mixed';if($ascending){$sourceOrder='ascending'}elseif($descending){$sourceOrder='descending'}
    if(-not $ascending -and -not $AllowReordering){throw 'Dates are not increasing; explicit -AllowReordering is required'}
    $sorted=@($rows | Sort-Object date)
    $selected=@($sorted | Where-Object {$_.date -cge $RequestedStart -and $_.date -cle $RequestedEnd})
    if($selected.Count -lt 3){throw 'Requested interval contains fewer than three observations'}
    $output=[IO.Path]::GetFullPath($OutputDirectory)
    $root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $localRoot=Join-Path $root 'data/local'
    $prefix=[IO.Path]::GetFullPath($localRoot).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if(-not $output.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Output must be a new subdirectory under ignored data/local'}
    if(Test-Path -LiteralPath $output){throw 'Output directory already exists; original records are never overwritten'}
    # Validate every source row before interval selection, including unused fields.
    # Preserve numeric lexemes; output only changes the schema/order/date window/newlines.
    $csv="date,close`n"+(@($selected | ForEach-Object {$_.date+','+$_.close_text}) -join "`n")+"`n"
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $output 'raw.csv'),$bytes)
    [IO.File]::WriteAllBytes((Join-Path $output 'source-metadata.json'),$metadataBytes)
    [IO.File]::WriteAllText((Join-Path $output 'prices.csv'),$csv,[Text.UTF8Encoding]::new($false))
    $transformations=@('Validate every source row and reject duplicates before selection',
        'Select inclusive requested date interval; excluded rows are counted',
        'Select explicit Close/close field; never substitute Adj Close',
        'Write date,close UTF-8 without BOM and LF newlines; preserve price text')
    if(-not $ascending){$transformations+='Explicitly reorder unique observations by ascending ISO date'}
    $revision=(& git -C $root rev-parse HEAD);if($LASTEXITCODE -ne 0){throw 'Cannot read source revision'}
    $dirty=@(& git -C $root status --porcelain --untracked-files=normal);if($LASTEXITCODE -ne 0){throw 'Cannot read source status'}
    $manifest=[ordered]@{
        schema_version=1;purpose='Local equity import; not benchmark or statistical acceptance'
        source=$metadata;converted_utc=[DateTimeOffset]::UtcNow.ToString('o');source_revision=$revision.Trim();git_dirty=($dirty.Count -gt 0)
        requested_date_start=$RequestedStart;requested_date_end=$RequestedEnd
        actual_date_start=$selected[0].date;actual_date_end=$selected[-1].date
        source_date_start=$sorted[0].date;source_date_end=$sorted[-1].date
        source_row_count=$rows.Count;row_count=$selected.Count;excluded_outside_requested_range=($rows.Count-$selected.Count)
        source_order=$sourceOrder;reordered=(-not $ascending);selected_price_field=$parsed.selected_price_field
        transformations=$transformations;invalid_rows_discarded=0;observations_filled=0
        calendar_completeness_verified=$false;publication_allowed_by_importer=$false
        working_settings=@{units=1;horizon_trading_days=10;trading_observations_per_year=252;status='Working settings, not final study choices'}
        raw_sha256=(Get-EquityHash (Join-Path $output 'raw.csv'))
        converted_sha256=(Get-EquityHash (Join-Path $output 'prices.csv'))
        source_metadata_sha256=(Get-EquityHash (Join-Path $output 'source-metadata.json'))
        importer_sha256=(Get-EquityHash $PSCommandPath)
    }
    Write-EquityJson (Join-Path $output 'manifest.json') $manifest
    return [pscustomobject]$manifest
}
function Get-EquityCalibration([object[]]$Rows) {
    # Independent reference: log of a price ratio and two-pass sample variance.
    # C++ instead uses log differences and Welford's online algorithm.
    $returns=@()
    for($i=1;$i -lt $Rows.Count;$i++){$returns+=,[Math]::Log($Rows[$i].close/$Rows[$i-1].close)}
    $sum=0.0;foreach($value in $returns){$sum+=$value};$mean=$sum/$returns.Count
    $squares=0.0;foreach($value in $returns){$squares+=($value-$mean)*($value-$mean)}
    $variance=$squares/($returns.Count-1)
    foreach($value in @($mean,$variance)){if([double]::IsNaN($value) -or [double]::IsInfinity($value)){throw 'Independent calibration is nonfinite'}}
    return [pscustomobject]@{returns=$returns;returns_count=$returns.Count;mean_log_return=$mean;sample_log_variance=$variance
        initial_value=$Rows[-1].close;drift_annual=252*$mean+0.5*252*$variance
        volatility_annual=[Math]::Sqrt(252*$variance);horizon_years=10.0/252}
}
function Assert-EquityCalibration($Run,$Reference,[object[]]$Rows) {
    if($Run.application_version -cne '0.3.0' -or $Run.schema_version -ne 1 -or $Run.input_mode -cne 'csv_calibration' -or
        $Run.calibration.observations -ne $Rows.Count -or $Run.calibration.returns_count -ne $Reference.returns_count -or
        $Run.calibration.date_start -cne $Rows[0].date -or $Run.calibration.date_end -cne $Rows[-1].date -or
        $Run.calibration.horizon_trading_days -ne 10 -or $Run.calibration.trading_days_per_year -ne 252) {
        throw 'C++ calibration metadata mismatch'
    }
    foreach($name in @('mean_log_return','sample_log_variance','initial_value','drift_annual','volatility_annual','horizon_years')) {
        if($name -in @('mean_log_return','sample_log_variance')){$actual=[double]$Run.calibration.$name}else{$actual=[double]$Run.model.$name}
        $expected=[double]$Reference.$name
        if([double]::IsNaN($actual) -or [double]::IsInfinity($actual) -or
            [Math]::Abs($actual-$expected) -gt 1e-12*[Math]::Max(1.0,[Math]::Abs($expected))) {
            throw "Independent calibration mismatch: $name"
        }
    }
}
