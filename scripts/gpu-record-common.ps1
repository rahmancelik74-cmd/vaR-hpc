Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
function Write-GpuJson($Path,$Value) {
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Value -Depth 30)+"`n",[Text.UTF8Encoding]::new($false))
}
function Read-GpuJson($Path) {
    # Explicit return enumerates JSON arrays on Windows PowerShell 5.1.
    $value=Get-Content -Encoding UTF8 -LiteralPath $Path -Raw | ConvertFrom-Json
    return $value
}
function Get-GpuRecordedAcceptance($Runs) {
    # Recorder uses Measure-Object. The independent auditor uses a separate sum.
    foreach($mode in @('full-device','hybrid')){foreach($alpha in @(.95,.99)){
        $group=@(foreach($r in $Runs){
            if($r.mode -cne $mode -or $null -eq $r.result){continue}
            foreach($e in $r.result.estimates){
                # ConvertFrom-Json may preserve 0.94999999999999996 as Decimal.
                if([double]$e.confidence -ne $alpha){continue}
                [pscustomobject]@{mode=$mode;seed=$r.seed;confidence=$alpha;mc_var=[double]$e.mc_var;
                    analytical_var=[double]$e.analytical_var;initial_value=[double]$r.result.model.initial_value}
            }
        })
        if($group.Count -ne 5){continue}
        $avg=($group | Measure-Object -Property mc_var -Average).Average
        $reference=$group[0].analytical_var; $v0=$group[0].initial_value
        $error=[Math]::Abs($avg-$reference); $limit=.01*[Math]::Max([Math]::Abs($reference),.01*$v0)
        [pscustomobject]@{mode=$mode;confidence=$alpha;scenarios=10000000;seed_count=5;mean_var=$avg;
            analytical_var=$reference;absolute_error_of_mean=$error;allowed_error=$limit;passed=($error -le $limit);
            per_seed=@($group | Select-Object mode,seed,confidence,mc_var)}
    }}
}
function Get-GpuHash($Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Assert-GpuBoundArtifact($Path,$ExpectedHash) {
    if((Get-GpuHash $Path) -cne $ExpectedHash){throw "Changed artifact bytes: $Path"}
}
function Write-GpuEstimates($Path,$Rows) {
    # Export-Csv otherwise calls culture-sensitive, non-round-trip Double.ToString().
    $invariant=[Globalization.CultureInfo]::InvariantCulture
    @($Rows | ForEach-Object {
        [pscustomobject][ordered]@{mode=$_.mode;seed=$_.seed;scenarios=([long]$_.scenarios).ToString($invariant);
            confidence=([double]$_.confidence).ToString('R',$invariant);
            mc_var=([double]$_.mc_var).ToString('R',$invariant);
            analytical_var=([double]$_.analytical_var).ToString('R',$invariant)}
    }) | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}
function Get-GpuSourceChanges {
    $s=@(& git status --porcelain --untracked-files=normal)
    if($LASTEXITCODE -ne 0){throw 'Cannot inspect Git status'}
    @($s | Where-Object {$_ -cne '?? AGENTS.md' -and $_ -cne '?? output/'})
}
function Join-GpuArguments([string[]]$Values) {
    # ProcessStartInfo uses Windows argv quoting, never shell evaluation.
    (($Values | ForEach-Object {
        if($_ -match '["\r\n]'){throw 'Embedded quotes/newlines are not supported in process arguments'}
        '"'+[regex]::Replace($_,'(\\+)$','$1$1')+'"'
    }) -join ' ')
}
function Invoke-GpuProcess($Executable,[string[]]$Arguments,$Prefix,[int]$TimeoutSeconds=600) {
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=$Executable; $info.Arguments=Join-GpuArguments $Arguments
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $info.WorkingDirectory=(Get-Location).Path
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$info
    $record=[ordered]@{executable=$Executable;arguments=$Arguments;started_utc=[DateTime]::UtcNow.ToString('o');
        stdout=$Prefix+'.stdout.txt';stderr=$Prefix+'.stderr.txt';exit_code=$null;timed_out=$false;start_error=$null}
    $stdout=$null; $stderr=$null
    try {
        $stdout=[IO.File]::Create($record.stdout); $stderr=[IO.File]::Create($record.stderr)
        if(-not $process.Start()){throw 'Process did not start'}
        $outCopy=$process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy=$process.StandardError.BaseStream.CopyToAsync($stderr)
        if(-not $process.WaitForExit($TimeoutSeconds*1000)){
            $record.timed_out=$true
            # Only the process tree created by this invocation is terminated.
            & "$env:SystemRoot/System32/taskkill.exe" /PID $process.Id /T /F | Out-Null
            $process.WaitForExit()
        }
        $null=$outCopy.GetAwaiter().GetResult(); $null=$errCopy.GetAwaiter().GetResult()
        $record.exit_code=$process.ExitCode
    } catch { $record.start_error=$_.Exception.Message }
    finally {
        if($stdout){$stdout.Dispose()}; if($stderr){$stderr.Dispose()}; $process.Dispose()
        $record['finished_utc']=[DateTime]::UtcNow.ToString('o')
        Write-GpuJson ($Prefix+'.process.json') $record
    }
    [pscustomobject]$record
}
function Assert-GpuProcess($Record) {
    if($Record.start_error -or $Record.timed_out -or $Record.exit_code -ne 0){throw "Process failed: $($Record.executable); see $($Record.stdout)"}
}
function Assert-GpuFinite($Value,$Label) {
    if($null -eq $Value -or $Value -is [string] -or $Value -is [bool]){throw "Missing/non-numeric $Label"}
    $v=[double]$Value
    if([double]::IsNaN($v) -or [double]::IsInfinity($v)){throw "Nonfinite $Label"}
    $v
}
function Assert-GpuClose($Actual,$Expected,$Label) {
    $a=Assert-GpuFinite $Actual $Label; $e=Assert-GpuFinite $Expected $Label
    if([Math]::Abs($a-$e) -gt 2e-12*[Math]::Max(1,[Math]::Abs($e))){throw "Incorrect $Label"}
}
function Get-GpuSanitizerMatrix {
    foreach($tool in @('memcheck','initcheck','synccheck','racecheck')){
        foreach($test in @('mc_cuda_tests','mc_cuda_hybrid_tests')){
            [pscustomobject]@{id="$tool-$test";tool=$tool;target=$test;mode='test-suite';n=0;seed='';batch=0}
        }
        $sizes=@(65535,65536,65537,131073)
        if($tool -in @('memcheck','initcheck')){$sizes+=1000000}
        foreach($mode in @('full-device','hybrid')){foreach($n in $sizes){
            [pscustomobject]@{id="$tool-$mode-N$n";tool=$tool;target='mc_var';mode=$mode;n=$n;seed='42';batch=$(if($mode -eq 'hybrid'){65535}else{0})}
        }}
    }
}
function Test-GpuSanitizerLog($Text) {
    # Exact, case-sensitive clean summaries avoid locale-sensitive matching (tr-TR I/i).
    # Any unexplained line remains a failed diagnostic, not a suppression.
    $header=$false; $summary=$false
    foreach($line in ($Text -split '\r?\n')){
        if([string]::IsNullOrWhiteSpace($line) -or $line -cmatch '^=========\s*$'){continue}
        if($line -cmatch '^========= COMPUTE-SANITIZER\s*$'){$header=$true;continue}
        if($line -cmatch '^========= (ERROR SUMMARY: 0 errors|RACECHECK SUMMARY: 0 hazards displayed \(0 errors, 0 warnings\))\s*$'){$summary=$true;continue}
        if($line -cmatch '^========= LEAK SUMMARY: 0 bytes leaked in 0 allocations\s*$'){continue}
        return $false
    }
    return ($header -and $summary)
}
