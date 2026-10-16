param([Parameter(Mandatory=$true)][string]$Probe,[Parameter(Mandatory=$true)][string]$Executable)
$ErrorActionPreference='Stop'
$inventory=(& $Probe --inventory) | ConvertFrom-Json
if($LASTEXITCODE -ne 0 -or $inventory.cores.Count -lt 1){throw 'Inventory failed'}
$single=([UInt64]1)
$available=[Convert]::ToUInt64($inventory.process_mask_hex,16)
while(($single -band $available) -eq 0){$single=$single -shl 1}
$mask=$single.ToString('x')
$check=(& $Probe --affinity 4 $mask) | ConvertFrom-Json
foreach($worker in $check.threads){
    if($worker.allowed_mask_hex -ne $mask -or $worker.observed_mask_hex -ne $mask){throw 'Affinity control failed'}
}
$path=(Resolve-Path -LiteralPath $Executable).Path
$wrapped=(& $Probe --run $mask $path 100 42 --backend openmp --threads 2 --json) | ConvertFrom-Json
$result=$wrapped.stdout | ConvertFrom-Json
if($LASTEXITCODE -ne 0 -or $wrapped.exit_code -ne 0 -or $wrapped.process_mask_hex -ne $mask -or
    $result.backend -ne 'openmp' -or $result.threads_used -ne 2){throw 'Suspended process launcher failed'}
$invalid=(& $Probe --run $mask $path --backend invalid) | ConvertFrom-Json
if($invalid.exit_code -eq 0 -or $invalid.stderr -notlike 'Error:*'){throw 'Child error propagation failed'}
Write-Output 'CPU probe topology, affinity, Unicode path launch and child failure tests passed.'
