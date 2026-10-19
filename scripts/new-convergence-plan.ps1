[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Path)
. (Join-Path $PSScriptRoot 'convergence-common.ps1')
$root=Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    if(Test-Path -LiteralPath $Path){throw 'Plan already exists'}
    $origins=@()
    foreach($spec in @(
        @('serial','evidence/v022-validation-20261016','build-foundation/Release/mc_var.exe','build-foundation/CMakeCache.txt'),
        @('openmp','evidence/v030-openmp-windows-correctness-20261016','build-openmp/Release/mc_var.exe',''),
        @('small-gpu','results/cuda-hybrid-f039034-clean-20261019','build-cuda-skeleton/Release/mc_var.exe','results/cuda-hybrid-f039034-clean-20261019/build-cuda-skeleton-CMakeCache.txt'),
        @('acceptance-gpu','results/gpu-acceptance-8df5f28-20261019','','results/gpu-acceptance-8df5f28-20261019/cuda-CMakeCache.txt'))){
        $id=$spec[0];$dir=$spec[1];$manifest="$dir/manifest.json";$m=Read-GpuJson $manifest
        $revision=if($id -ceq 'serial'){$m.git_commit}else{$m.source_revision}
        $exe=if($spec[2]){$spec[2]}else{$m.executable_path}
        Assert-GpuBoundArtifact $exe $m.executable_sha256
        $files=@($manifest,$exe)
        $cacheHash=$null
        if($spec[3]){
            $files+=$spec[3];$cacheHash=Get-GpuHash $spec[3]
            $expected=switch($id){'serial'{$m.cmake_cache_sha256}'small-gpu'{$m.build_artifacts[0].sha256}'acceptance-gpu'{$m.build_cache_sha256}}
            if($cacheHash -cne $expected){throw 'Archived cache mismatch'}
        }
        if($id -in @('serial','openmp')){$files+="$dir/runs.jsonl";$files+="$dir/estimates.csv"}
        if($id -ceq 'openmp'){
            $files+=@("$dir/build-settings.json","$dir/artifact-sha256.json","$dir/audit.json","$dir/build-ON.log")
            $hashes=Read-GpuJson "$dir/artifact-sha256.json"
            foreach($p in $hashes.PSObject.Properties){Assert-GpuBoundArtifact "$dir/$($p.Name)" $p.Value}
        }
        if($id -in @('small-gpu','acceptance-gpu')){$files+="$dir/independent-audit.json"}
        $limitation=switch($id){
            'serial'{'Historical manifest explicitly sets executable_source_commit_verified=false. Matching archived binary hash and unchanged core/data implementations do not prove source-to-binary correspondence.'}
            'openmp'{'Requested and actual threads=4. Build settings/log and executable are archived; no standalone CMakeCache was published with this correctness evidence.'}
            'small-gpu'{'Only five selected native singleton observations. Implementation checks are not a complete seed campaign; common-input and connectivity records are excluded.'}
            'acceptance-gpu'{'Separate five-seed 10M acceptance source/build. Later revisions add optional diagnostics; no fresh common-build convergence campaign is claimed.'}}
        $origins += [pscustomobject]@{id=$id;manifest_path=$manifest;source_revision=$revision;
            source_tree=(& git rev-parse ($revision+'^{tree}')).Trim();executable_sha256=$m.executable_sha256;
            build_cache_sha256=$cacheHash;limitation=$limitation;
            artifacts=@($files | ForEach-Object {Get-ConvergenceArtifact $_})}
    }
    $reuse=@()
    foreach($id in @('serial','openmp')){
        $o=@($origins | Where-Object {$_.id -ceq $id})[0];$p=(Split-Path $o.manifest_path)+'/runs.jsonl'
        $lines=@(Read-ConvergenceLines $p)
        for($i=0;$i -lt $lines.Count;$i++){
            $r=if($id -ceq 'serial'){$lines[$i].result}else{$lines[$i]}
            $reuse += [pscustomobject]@{key="$id/$($r.scenarios)/$($r.seed)";origin=$id;path=$p;sha256=(Get-GpuHash $p);line=($i+1)}
        }
    }
    $dir='results/cuda-hybrid-f039034-clean-20261019'
    foreach($engine in @('full-device','hybrid')){
        $sizes=if($engine -ceq 'full-device'){@(10000,100000,1000000)}else{@(100000,1000000)}
        foreach($n in $sizes){
            $name=if($engine -ceq 'full-device'){"native-N$n.json"}else{"hybrid-native-N$n.json"};$p="$dir/$name"
            $reuse += [pscustomobject]@{key="$engine/$n/42";origin='small-gpu';path=$p;sha256=(Get-GpuHash $p);line=0}
        }
    }
    $p='results/gpu-acceptance-8df5f28-20261019/runs.jsonl';$lines=@(Read-ConvergenceLines $p)
    for($i=0;$i -lt $lines.Count;$i++){
        $r=$lines[$i]
        $reuse += [pscustomobject]@{key="$($r.mode)/10000000/$($r.seed)";origin='acceptance-gpu';path=$p;sha256=(Get-GpuHash $p);line=($i+1)}
    }
    $head=(& git rev-parse HEAD).Trim();$compatibility=@()
    foreach($spec in @(
        @($origins[0].source_revision,$head,@('src/core.cpp','src/data.cpp','include/mc/core.hpp','include/mc/data.hpp')),
        @($origins[1].source_revision,$head,@('src/core.cpp','src/data.cpp','src/openmp.cpp','include/mc/openmp.hpp')),
        @($origins[2].source_revision,$origins[3].source_revision,@('src','include','data/synthetic_prices.csv')),
        @($origins[3].source_revision,$head,@('src','include','data/synthetic_prices.csv')))){
        $compatibility += [pscustomobject]@{from=$spec[0];to=$spec[1];paths=$spec[2];diff=@(& git diff --no-ext-diff $spec[0] $spec[1] -- @($spec[2]))}
    }
    $plan=[pscustomobject]@{schema_version=1;purpose='Native convergence reuse and fixed missing-run plan; no new simulation';
        contract='GBM/double/q=1/T=10/252/nearest-rank/alpha=.95,.99/native';reviewed_revision=$head;
        fixture=(Get-ConvergenceArtifact 'data/synthetic_prices.csv');expected_runs=80;expected_values=160;
        origins=$origins;compatibility=$compatibility;
        compatibility_reasoning='core.cpp/data.cpp and OpenMP implementation unchanged; serial header additions are metadata. f039034 to 8df5f28 has no src/include/fixture differences. Later GPU changes add optional diagnostic instrumentation and CLI/output metadata. Equal native seeds do not establish equal samples across engines/modes. Reuse spans source/build revisions.';
        reuse=$reuse;missing=@(Get-ConvergenceGrid | Where-Object {$_.key -cnotin $reuse.key});
        figure_spec=[ordered]@{status='specification-only';panels=@('absolute error of mean vs N by engine/mode and alpha','per-seed signed error and seed sample standard deviation vs N');
            x='N, logarithmic';error_y='logarithmic for positive absolute errors; separate zero-error markers at labeled zero strip';
            seed_y='linear signed error with zero reference line';zero_policy='Preserve raw zeros; never substitute epsilon';
            incomplete_policy='Mark partial groups with seed count; no fitted rate, monotonicity requirement or universal guarantee'}}
    Test-ConvergencePlan $plan
    Write-GpuJson $Path $plan
    Write-Host 'Plan bound: 55 reused runs, 25 missing processes, 50 missing VaR values'
} finally {Pop-Location}
