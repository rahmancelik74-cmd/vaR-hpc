Set-StrictMode -Version 2.0
function Write-CpuJson($Path, $Value) {
    [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 12) + "`n", [Text.UTF8Encoding]::new($false))
}
function Get-CpuHash($Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-CpuSummary($Runs) {
    $groups = @($Runs | Where-Object { $_.phase -eq 'measured' } | Group-Object configuration_id)
    $summary = @()
    foreach ($group in $groups) {
        $count = 0; $mean = 0.0; $m2 = 0.0
        foreach ($run in $group.Group) {
            $value = [double]$run.result.end_to_end_ms
            if ([double]::IsNaN($value) -or [double]::IsInfinity($value) -or $value -le 0) {
                throw 'Invalid engine time'
            }
            # Welford sample variance. Each process contributes once, not per confidence.
            ++$count; $delta = $value - $mean; $mean += $delta / $count
            $m2 += $delta * ($value - $mean)
        }
        if ($count -lt 2) { throw 'At least two measured repetitions required' }
        $first = $group.Group[0].result
        $summary += [pscustomobject][ordered]@{
            configuration_id=$group.Name; backend=$first.backend; scenarios=[long]$first.scenarios
            requested_threads=[int]$first.requested_threads
            actual_thread_counts=@($group.Group | ForEach-Object { $_.result.threads_used } | Sort-Object -Unique)
            measured_repetitions=$count; mean_ms=$mean; sample_stddev_ms=[Math]::Sqrt($m2 / ($count - 1))
            scenarios_per_second=(1000.0 * $first.scenarios / $mean)
            speedup_vs_fresh_serial=0.0; scaling_vs_openmp_one_thread=$null
        }
    }
    foreach ($row in $summary) {
        $serial = @($summary | Where-Object { $_.scenarios -eq $row.scenarios -and $_.backend -eq 'serial' })
        $one = @($summary | Where-Object { $_.scenarios -eq $row.scenarios -and $_.backend -eq 'openmp' -and $_.requested_threads -eq 1 })
        if ($serial.Count -ne 1 -or $one.Count -ne 1) { throw 'Fresh serial and one-thread OpenMP references required' }
        $row.speedup_vs_fresh_serial = $serial[0].mean_ms / $row.mean_ms
        if ($row.backend -eq 'openmp') { $row.scaling_vs_openmp_one_thread = $one[0].mean_ms / $row.mean_ms }
    }
    return $summary
}
