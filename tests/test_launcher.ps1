param([Parameter(Mandatory=$true)][string]$Probe,[Parameter(Mandatory=$true)][string]$Child)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$inventory=(& $Probe --inventory) | ConvertFrom-Json
if($LASTEXITCODE -ne 0){throw 'Inventory failed'}
$checks=0
function Run($Mode,$Timeout=1000){
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $raw=(& $Probe --run-timeout $Timeout $inventory.process_mask_hex $Child $Mode) -join "`n"
    if($LASTEXITCODE -ne 0){throw 'Launcher failed'}
    if($watch.ElapsedMilliseconds -gt $Timeout+5000){throw 'Launcher deadline was not bounded'}
    $r=$raw | ConvertFrom-Json
    if($r.timeout_ms -ne $Timeout -or $r.priority_class -ne 32 -or $r.process_mask_hex -cne $inventory.process_mask_hex){throw 'Launcher metadata failed'}
    $script:checks++;return $r
}
$r=Run 'normal';if($r.exit_code -ne 0 -or $r.timed_out -or $r.stdout -cne 'normal-out' -or $r.stderr -cne 'normal-err'){throw 'Normal completion failed'}
$r=Run 'nonzero';if($r.exit_code -ne 7 -or $r.timed_out -or $r.stdout -cne 'partial-out' -or $r.stderr -cne 'partial-err'){throw 'Nonzero capture failed'}
$r=Run 'large' 5000;if($r.timed_out -or $r.exit_code -ne 0 -or $r.stdout.Length -ne 524288 -or $r.stderr.Length -ne 524288){throw 'Large output drain failed'}
$r=Run 'child-normal';if($r.timed_out -or $r.stdout -notmatch 'normal-out'){throw 'Normal descendant output lost'}
foreach($mode in @('hang','child','tree')){
    $r=Run $mode 200
    if(-not $r.timed_out -or -not $r.owned_job_terminated -or $r.active_processes_at_timeout -lt 1 -or
        $r.stdout -notmatch 'before-hang' -or $r.stderr -notmatch 'before-hang-err'){throw 'Timeout/partial output contract failed'}
    if($mode -ceq 'hang' -and $r.exit_code -ne 124){throw 'Termination status lost'}
    if($r.stdout -match 'child_pid=(\d+)'){
        $descendant=Get-Process -Id ([int]$Matches[1]) -ErrorAction SilentlyContinue
        if($descendant){throw 'Owned descendant survived timeout'}
    }
}
$sentinel=Start-Process -FilePath $Child -ArgumentList 'hang' -WindowStyle Hidden -PassThru
try {
    $null=Run 'tree' 200
    $sentinel.Refresh()
    if($sentinel.HasExited){throw 'An unrelated process was terminated'}
    $checks++
}finally{if(-not $sentinel.HasExited){$sentinel.Kill();$sentinel.WaitForExit()};$sentinel.Dispose()}
Write-Host "Launcher timeout checks passed: $checks"
