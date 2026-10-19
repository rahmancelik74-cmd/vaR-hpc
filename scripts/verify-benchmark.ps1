[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Directory)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'benchmark-common.ps1')
$root=Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $root
try {
    $dir=(Resolve-Path -LiteralPath $Directory).Path
    $audit=[ordered]@{schema_version=1;status='failed';checked_utc=[DateTime]::UtcNow.ToString('o');errors=@();
        formal_campaign=$false;bandwidth_measured=$false}
    try {
        $m=Read-GpuJson (Join-Path $dir 'manifest.json');$plan=Read-GpuJson (Join-Path $dir 'plan.json')
        $audit['manifest_sha256']=Get-GpuHash (Join-Path $dir 'manifest.json');$audit['source_revision']=$m.source_revision
        if($m.mode -cne $plan.mode -or $m.formal_campaign -ne ($plan.mode -ceq 'formal')){throw 'Wrong campaign label'}
        if((& git rev-parse ($m.source_revision+'^{tree}')).Trim() -cne $m.source_tree){throw 'Source tree mismatch'}
        $seen=@{}
        foreach($r in $m.record_hashes){
            if($r.file -cne [IO.Path]::GetFileName($r.file) -or $seen.ContainsKey($r.file)){throw 'Invalid record path'}
            Assert-GpuBoundArtifact (Join-Path $dir $r.file) $r.sha256;$seen[$r.file]=$true
        }
        foreach($f in Get-ChildItem -LiteralPath $dir -File | Where-Object {$_.Name -notin @('manifest.json','independent-audit.json')}){
            if(-not $seen.ContainsKey($f.Name)){throw 'Unbound output'}
        }
        foreach($a in $m.artifacts){Assert-GpuBoundArtifact $a.path $a.sha256}
        Assert-GpuBoundArtifact $m.executable_path $m.executable_sha256
        Assert-GpuBoundArtifact $m.probe_path $m.probe_sha256
        Assert-GpuBoundArtifact (Join-Path $dir 'source-snapshot.json') $m.source_snapshot_sha256
        foreach($s in @(Read-GpuJson (Join-Path $dir 'source-snapshot.json'))){Assert-GpuBoundArtifact (Join-Path $root $s.path) $s.sha256}
        Assert-GpuBoundArtifact (Join-Path $dir 'fixture.csv') $m.input_sha256
        Assert-GpuBoundArtifact $m.input_path $m.input_sha256
        Assert-GpuBoundArtifact (Join-Path $m.build_directory 'CMakeCache.txt') $m.build_cache_sha256
        $cache=[IO.File]::ReadAllText((Join-Path $dir 'CMakeCache.txt'))
        foreach($flag in @('MC_ENABLE_CUDA:BOOL=ON','MC_ENABLE_OPENMP:BOOL=ON','MC_BUILD_CPU_TOOLS:BOOL=ON','BUILD_TESTING:BOOL=ON')){
            if($cache -notmatch [regex]::Escape($flag)){throw 'Wrong benchmark build flags'}
        }
        foreach($id in @('ctest','test-list')){Assert-GpuProcess (Read-GpuJson (Join-Path $dir ($id+'.process.json')))}
        $tests=Read-GpuJson (Join-Path $dir 'test-list.stdout.txt')
        $log=[IO.File]::ReadAllText((Join-Path $dir 'ctest.stdout.txt'))
        if($log -notmatch ('100% tests passed, 0 tests failed out of '+@($tests.tests).Count+'\b')){throw 'Regression suite incomplete'}
        $fixture=Get-IndependentGpuFixture (Join-Path $dir 'fixture.csv')
        $runs=@(Get-Content -LiteralPath (Join-Path $dir 'runs.jsonl') -Encoding UTF8 | ForEach-Object {$_ | ConvertFrom-Json})
        Test-BenchmarkRecords $m $plan $runs $fixture
        if($m.attempted_processes -ne $runs.Count){throw 'Wrong attempt count'}
        foreach($r in $runs){
            $p=Read-GpuJson (Join-Path $dir $r.launcher_process);Assert-GpuProcess $p
            $args=@('--run-timeout','60000',$m.process_mask_hex,$m.executable_path)+@($r.arguments)
            if($p.executable -cne $m.probe_path -or (@($p.arguments) -join "`n") -cne ($args -join "`n")){throw 'Launcher invocation mismatch'}
            $raw=Read-GpuJson $p.stdout
            if((ConvertTo-Json $raw -Depth 30 -Compress) -cne (ConvertTo-Json $r.observation -Depth 30 -Compress)){throw 'Raw launcher mismatch'}
            if((Get-Item -LiteralPath $p.stderr).Length -ne 0){throw 'Launcher diagnostics on stderr'}
        }
        if($plan.mode -cne 'diagnostic'){
            $rows=@(Read-GpuJson (Join-Path $dir 'summary.json'));Test-BenchmarkSummary $plan $runs $rows
            $csv=@(Import-Csv -LiteralPath (Join-Path $dir 'summary.csv'))
            if($csv.Count -ne $rows.Count){throw 'CSV summary count'}
            for($i=0;$i -lt $rows.Count;$i++){
                foreach($f in @('mean_ms','sample_stddev_ms','scenarios_per_second','speedup_vs_serial','speedup_vs_best_openmp')){
                    Assert-GpuClose ([double]::Parse($csv[$i].$f,[Globalization.CultureInfo]::InvariantCulture)) $rows[$i].$f "CSV $f"
                }
                if($csv[$i].configuration_id -cne $rows[$i].configuration_id){throw 'CSV identity mismatch'}
            }
        }
        $b=Read-GpuJson (Join-Path $dir 'bandwidth-preparation.json')
        if($b.measured_dram_status -cne 'not-measured' -or $null -ne $b.documented_peak_gbs -or $b.permission_settings_changed){throw 'Unsupported bandwidth claim'}
        if($b.status -cnotin @('not-requested','tool-unavailable')){
            $q=Read-GpuJson (Join-Path $dir $b.discovery_process)
            $text=[IO.File]::ReadAllText($q.stdout)+[IO.File]::ReadAllText($q.stderr)
            if($b.status -cne (Test-BandwidthDiscovery $q $text)){throw 'Wrong bandwidth discovery status'}
        }
        $audit.status='passed';$audit.formal_campaign=($plan.mode -ceq 'formal')
        $audit['mode']=$plan.mode;$audit['attempted_processes']=$runs.Count;$audit['bandwidth_discovery']=$b.status
        $audit['statistics']='Independent explicit sum/two-pass sample variance and baseline selection; all rows retained'
    }catch{$audit.errors+= $_.Exception.Message}
    Write-GpuJson (Join-Path $dir 'independent-audit.json') $audit
    if($audit.status -cne 'passed'){throw ('Benchmark audit failed: '+($audit.errors -join '; '))}
    Write-Host ('Independent '+$plan.mode+' audit passed: '+$runs.Count+' processes; formal='+$audit.formal_campaign)
}finally{Pop-Location}
