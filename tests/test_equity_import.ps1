param([Parameter(Mandatory=$true)][string]$Executable,
      [string]$OpenMPEnabled='ON',[string]$CudaEnabled='OFF')
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/equity-data-common.ps1')
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testRoot=Join-Path $root ('data/local/test-import-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
$metadata=[pscustomobject]@{source_name='Artificial converter fixture';source_url='https://example.invalid/fixture.csv'
    symbol='TEST';currency='USD';retrieved_utc='2020-01-01T00:00:00Z';download_method='Generated artificial fixture, no provider observations'
    price_adjustment_policy='unadjusted';price_policy_url='https://example.invalid/policy';local_reuse_conditions='Project-generated fixture'
    reuse_policy_url='https://example.invalid/policy';local_use_verified=$true;redistribution_permission='verified';data_kind='artificial_fixture'}
$metadataFile=Join-Path $testRoot 'metadata.json';Write-EquityJson $metadataFile $metadata
$rawFile=Join-Path $testRoot 'input.csv'
$good="Date,Open,High,Low,Close,Adj Close,Volume`n2023-01-03,100,101,99,100,50,10`n2023-01-04,110,111,109,110,55,11`n2023-01-05,99,100,98,99,49.5,12`n2023-01-06,118.8,120,118,118.8,59.4,13`n"
[IO.File]::WriteAllText($rawFile,$good,$utf8)
$manifest=Convert-EquityData $rawFile $metadataFile (Join-Path $testRoot 'valid') '2023-01-01' '2025-12-31'
$converted=Join-Path $testRoot 'valid/prices.csv'
$expected="date,close`n2023-01-03,100`n2023-01-04,110`n2023-01-05,99`n2023-01-06,118.8`n"
if([IO.File]::ReadAllText($converted) -cne $expected -or $manifest.row_count -ne 4 -or $manifest.reordered -or
    $manifest.raw_sha256 -cne (Get-EquityHash $rawFile) -or $manifest.selected_price_field -cne 'Close' -or
    $manifest.publication_allowed_by_importer -or $manifest.calendar_completeness_verified){throw 'Conversion/provenance regression'}
$rows=@((Read-EquityPrices ([IO.File]::ReadAllBytes($converted))).rows)
$reference=Get-EquityCalibration $rows
$known=@([Math]::Log(1.1),[Math]::Log(.9),[Math]::Log(1.2))
for($i=0;$i -lt 3;$i++){if([Math]::Abs($reference.returns[$i]-$known[$i]) -gt 1e-15){throw 'Independent log return regression'}}
$raw=@(& $Executable --csv $converted 100 42 10 252 --backend serial --json) -join "`n"
if($LASTEXITCODE -ne 0){throw 'C++ converted-fixture integration failed'}
$run=$raw | ConvertFrom-Json;Assert-EquityCalibration $run $reference $rows
$bad=$raw | ConvertFrom-Json;$bad.model.drift_annual+=.001
$caught=$false;try{Assert-EquityCalibration $bad $reference $rows}catch{$caught=$true}
if(-not $caught){throw 'Calibration checker accepted perturbed C++ output'}
$script:checks=4
function Rejects([string]$Text,[string]$Message) {
    $caught=$false
    try{Read-EquityPrices ($utf8.GetBytes($Text)) | Out-Null}catch{
        if($_.Exception.Message -notmatch $Message){throw};$caught=$true
    }
    if(-not $caught){throw "Invalid fixture accepted: $Message"};$script:checks++
}
Rejects ($good.Replace('2023-01-04','2023-01-03')) 'Duplicate date'
Rejects ($good.Replace('2023-01-04','2023-02-29')) 'Invalid date'
Rejects ($good.Replace(',110,55,',',NaN,55,')) 'Invalid numeric'
Rejects ($good.Replace(',110,55,',',0,55,')) 'Invalid numeric'
Rejects ($good.Replace(',110,55,',',-1,55,')) 'Invalid numeric'
Rejects ($good.Replace(',110,55,',',1e999,55,')) 'Invalid numeric'
Rejects ($good.Replace(',110,55,',',,55,')) 'Invalid numeric'
Rejects ($good.Replace(',110,55,',',110oops,55,')) 'Invalid numeric'
Rejects ($good.Replace(',55,11',',55,-1')) 'Invalid numeric'
Rejects ($good.Replace(',55,11',',55,1.2')) 'Volume must'
Rejects ($good.Replace(',55,11',',null,11')) 'Invalid numeric'
Rejects ($good.Replace(',111,109,',',100,109,')) 'Inconsistent OHLC'
Rejects ($good.Replace("2023-01-04,110",'"2023-01-04",110')) 'quoting'
Rejects ($good+"`n") 'blank record'
Rejects ($good.Replace(',55,11',',55,11,12')) 'field count'
Rejects ($good.Replace('Close,Adj Close','Price,Adj Close')) 'explicit Close'
Rejects ($good.Replace("`n","`r")) 'bare CR'
Rejects "date,close`n2023-01-01,1`n2023-01-02,2`n" 'three price'
$caught=$false;try{Read-EquityPrices ([byte[]]@(255,254,255)) | Out-Null}catch{
    if($_.Exception.Message -cne 'Invalid UTF-8 source CSV'){throw};$caught=$true}
if(-not $caught){throw 'Invalid UTF-8 accepted'};$script:checks++
# UTF-8 BOM and CRLF are normalized; original bytes are retained exactly.
$bom=[byte[]](@(239,187,191)+$utf8.GetBytes($good.Replace("`n","`r`n")))
[IO.File]::WriteAllBytes($rawFile,$bom)
$bomResult=Convert-EquityData $rawFile $metadataFile (Join-Path $testRoot 'bom') '2023-01-01' '2025-12-31'
if((Get-EquityHash (Join-Path $testRoot 'bom/raw.csv')) -cne (Get-EquityHash $rawFile) -or
    [IO.File]::ReadAllText((Join-Path $testRoot 'bom/prices.csv')) -cne $expected){throw 'BOM/raw preservation regression'}
$script:checks++
# Explicit reordering, interval selection and validation outside the interval.
$lines=@($expected.TrimEnd("`n").Split("`n"));[array]::Reverse($lines,1,4)
[IO.File]::WriteAllText($rawFile,($lines -join "`n")+"`n",$utf8)
$caught=$false;try{Convert-EquityData $rawFile $metadataFile (Join-Path $testRoot 'unordered') '2023-01-01' '2025-12-31' | Out-Null}catch{
    if($_.Exception.Message -notmatch 'AllowReordering'){throw};$caught=$true}
if(-not $caught){throw 'Implicit reordering accepted'}
$sorted=Convert-EquityData $rawFile $metadataFile (Join-Path $testRoot 'sorted') '2023-01-04' '2023-01-06' -AllowReordering
if(-not $sorted.reordered -or $sorted.source_order -cne 'descending' -or $sorted.row_count -ne 3 -or
    $sorted.excluded_outside_requested_range -ne 1 -or $sorted.actual_date_start -cne '2023-01-04'){throw 'Explicit reordering/window regression'}
$script:checks+=2
$badOutside=$expected+"2022-01-01,0`n";[IO.File]::WriteAllText($rawFile,$badOutside,$utf8)
$caught=$false;try{Convert-EquityData $rawFile $metadataFile (Join-Path $testRoot 'bad-outside') '2023-01-01' '2025-12-31' -AllowReordering | Out-Null}catch{
    if($_.Exception.Message -notmatch 'Invalid numeric'){throw};$caught=$true}
if(-not $caught){throw 'Invalid row outside interval was silently discarded'};$script:checks++
# Metadata is evidence supplied by the operator, never inferred from column names.
foreach($field in @('price_adjustment_policy','local_use_verified','retrieved_utc','source_url','currency')) {
    $copy=$metadata | ConvertTo-Json | ConvertFrom-Json
    switch($field){
        'price_adjustment_policy' {$copy.$field='unknown'}
        'local_use_verified' {$copy.$field=$false}
        'retrieved_utc' {$copy.$field='2023-01-01'}
        'source_url' {$copy.$field='https://example.invalid/?apikey=secret'}
        'currency' {$copy.$field='unknown'}
    }
    $caught=$false;try{Assert-EquityMetadata $copy}catch{$caught=$true}
    if(-not $caught){throw "Invalid metadata accepted: $field"};$script:checks++
}
# Deterministic conversion across locales; binary hashes and CLI calibration match.
[IO.File]::WriteAllText($rawFile,$good,$utf8)
$saved=[Threading.Thread]::CurrentThread.CurrentCulture
try{
    [Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo('tr-TR')
    $locale=Convert-EquityData $rawFile $metadataFile (Join-Path $testRoot 'locale') '2023-01-01' '2025-12-31'
    if($locale.converted_sha256 -cne $manifest.converted_sha256){throw 'Locale-dependent conversion'}
    $script:checks++
}finally{[Threading.Thread]::CurrentThread.CurrentCulture=$saved}
$caught=$false;try{Convert-EquityData $rawFile $metadataFile (Join-Path $testRoot 'valid') '2023-01-01' '2025-12-31' | Out-Null}catch{
    if($_.Exception.Message -notmatch 'already exists'){throw};$caught=$true}
if(-not $caught){throw 'Existing import overwritten'};$script:checks++
# Exercise the public entry point with its default requested interval.
$entry=Join-Path $root 'scripts/import-equity-data.ps1'
$public=@(& $entry -InputFile $rawFile -MetadataFile $metadataFile -OutputDirectory (Join-Path $testRoot 'public')) -join "`n"
$publicResult=$public | ConvertFrom-Json
if($publicResult.requested_date_start -cne '2023-01-01' -or $publicResult.requested_date_end -cne '2025-12-31' -or
    $publicResult.converted_sha256 -cne $manifest.converted_sha256){throw 'Public entry-point defaults failed'}
$script:checks++
# The historical runner must reject artificial data before any backend execution.
$caught=$false
$guardArguments=@{ImportDirectory=(Join-Path $testRoot 'valid');CpuExecutable=$Executable
    OutputDirectory=(Join-Path $root 'results/never-created-equity-fixture')}
try{& (Join-Path $root 'scripts/check-equity-integration.ps1') @guardArguments | Out-Null}catch{
    if($_.Exception.Message -notmatch 'genuine provider data'){throw};$caught=$true}
if(-not $caught){throw 'Artificial data accepted as historical integration'};$script:checks++
$fixtureOutput=Join-Path $root ('results/equity-runner-fixture-'+[guid]::NewGuid().ToString('N'))
$fixtureArguments=@{ImportDirectory=(Join-Path $testRoot 'valid');CpuExecutable=$Executable
    OutputDirectory=$fixtureOutput;FixtureTestOnly=$true;CpuBackends=@('serial')}
if($OpenMPEnabled -ceq 'ON'){$fixtureArguments.CpuBackends=@('serial','openmp')}
if($CudaEnabled -ceq 'ON'){$fixtureArguments.CudaExecutable=$Executable}
& (Join-Path $root 'scripts/check-equity-integration.ps1') @fixtureArguments | Out-Null
$fixtureManifest=Get-Content -LiteralPath (Join-Path $fixtureOutput 'manifest.json') -Raw | ConvertFrom-Json
if($fixtureManifest.status -cne 'passed' -or $fixtureManifest.data_kind -cne 'artificial_fixture' -or
    $fixtureManifest.purpose -notlike 'Artificial-fixture*' -or $fixtureManifest.performance_benchmark -or
    $fixtureManifest.full_scale_gpu_acceptance){throw 'Fixture integration recording regression'}
if($CudaEnabled -ceq 'OFF' -and $fixtureManifest.cuda_smoke -cne 'not_requested'){throw 'Unexecuted CUDA smoke reported as passed'}
$script:checks++
# Input tampering must fail before producing a successful integration record.
[IO.File]::AppendAllText($converted,"2023-01-09,120`n",$utf8)
$caught=$false;try{& (Join-Path $root 'scripts/check-equity-integration.ps1') @guardArguments -FixtureTestOnly | Out-Null}catch{
    if($_.Exception.Message -notmatch 'hash mismatch'){throw};$caught=$true}
if(-not $caught){throw 'Modified imported data accepted'};$script:checks++
# Explicit provider dialect; no inference and no silently discarded first row.
$kibot="01/03/2023,100,101,99,100,10`n01/04/2023,110,111,109,110,11`n01/05/2023,99,100,98,99,12`n01/06/2023,118.8,120,118,118.8,13`n"
[IO.File]::WriteAllText($rawFile,$kibot,$utf8)
$kibotResult=Convert-EquityData -InputFile $rawFile -MetadataFile $metadataFile -OutputDirectory (Join-Path $testRoot 'kibot') -SourceFormat kibot_daily
if($kibotResult.row_count -ne 4 -or $kibotResult.source_format -cne 'kibot_daily' -or
    $kibotResult.actual_date_start -cne '2023-01-03' -or $kibotResult.raw_sha256 -cne (Get-EquityHash $rawFile) -or
    [IO.File]::ReadAllText((Join-Path $testRoot 'kibot/prices.csv')) -cne $expected){throw 'Kibot explicit conversion regression'}
$script:checks++
Rejects $kibot 'explicit Close'
foreach($case in @(@($kibot.Replace('01/04/2023','01/03/2023'),'Duplicate date'),
    @($kibot.Replace('01/04/2023','02/29/2023'),'Invalid Kibot'),
    @($kibot.Replace('01/04/2023','2023-01-04'),'Invalid Kibot'),
    @($kibot.Replace(',110,11',',NaN,11'),'Invalid numeric'),
    @($kibot+"`n",'six headerless fields'),
    @($kibot.Replace(',110,11',',110,11,12'),'six headerless fields'))) {
    $caught=$false;try{Read-EquityPrices ($utf8.GetBytes($case[0])) 'kibot_daily' | Out-Null}catch{
        if($_.Exception.Message -notmatch $case[1]){throw};$caught=$true}
    if(-not $caught){throw 'Malformed Kibot fixture accepted'};$script:checks++
}
Write-Output "Equity conversion and independent C++ calibration checks passed: $script:checks checks (artificial data only)."
