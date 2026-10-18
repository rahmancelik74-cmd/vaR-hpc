[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputDirectory)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'gpu-record-common.ps1')
function Run-Required($Id,$Executable,$Arguments) {
    $p=Invoke-GpuProcess $Executable $Arguments (Join-Path $out $Id)
    Assert-GpuProcess $p
    return $p
}
function Capture-Artifact($Path) {
    [pscustomobject]@{path=[IO.Path]::GetFullPath($Path);sha256=(Get-GpuHash $Path)}
}
Push-Location -LiteralPath $root
try {
    if(@(Get-GpuSourceChanges).Count){throw 'Clean committed source required; only untracked AGENTS.md/output/ excluded'}
    $revision=(& git rev-parse HEAD).Trim(); $tree=(& git rev-parse 'HEAD^{tree}').Trim()
    $OutputDirectory=[IO.Path]::GetFullPath((Join-Path $root $OutputDirectory))
    $allowed=[IO.Path]::GetFullPath((Join-Path $root 'results'))+[IO.Path]::DirectorySeparatorChar
    if(-not $OutputDirectory.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $OutputDirectory)){throw 'Output must be a new directory below ignored results/'}
    $out=(New-Item -ItemType Directory -Path $OutputDirectory).FullName
    $tag='build-gpu-'+$revision.Substring(0,7)+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)
    $manifest=[ordered]@{schema_version=1;purpose='GPU analytical acceptance and separate memory/concurrency verification';
        status='running';source_revision=$revision;source_tree=$tree;clean_source=$true;
        source_status_exclusions=@('untracked AGENTS.md','untracked output/');started_utc=[DateTime]::UtcNow.ToString('o');
        seeds=@('42','123','456','789','2026');modes=@('full-device','hybrid');confidence_levels=@(.95,.99);scenarios=10000000;
        hybrid_requested_batch_size=65535;hybrid_effective_batch_size=65536;
        input_path=[IO.Path]::GetFullPath('data/synthetic_prices.csv');input_sha256=(Get-GpuHash 'data/synthetic_prices.csv');
        process_policy='Fresh CLI process and CUDA context per acceptance/boundary run; suites retain one process with per-request resources';
        timing_policy='Acceptance only; engine times are not benchmark samples; sanitizer runs separate';
        numerical_contract='double; exact terminal GBM; signed loss/negative VaR; ascending ceil(alpha*N)-1; no interpolation';
        criterion='abs(mean(VaR)-analytical) <= 0.01*max(abs(analytical),0.01*V0)';
        os_version=[Environment]::OSVersion.VersionString;powershell_version=$PSVersionTable.PSVersion.ToString();
        thermal_conditions='Not measured; no thermal-equilibrium claim';formal_benchmark=$false;
        artifacts=@();builds=@();acceptance_status='not-run';sanitizer_status='not-run'}
    $manifestPath=Join-Path $out 'manifest.json'
    Write-GpuJson $manifestPath $manifest
    try {
        $fixture=Join-Path $out 'fixture.csv'; [IO.File]::Copy($manifest.input_path,$fixture)
        foreach($file in @('scripts/run-gpu-acceptance.ps1','scripts/gpu-record-common.ps1','scripts/gpu-acceptance-audit.ps1',
            'scripts/verify-gpu-acceptance.ps1','scripts/invoke-gpu-sanitizer-target.ps1','tests/test_gpu_recorder.ps1')){
            $manifest.artifacts+=Capture-Artifact $file
        }
        foreach($config in @('cuda','cpu-openmp','cpu-serial','sanitizer')){
            $build=$tag+'-'+$config; $cuda=$config -in @('cuda','sanitizer'); $omp=$config -ne 'cpu-serial'
            $args=@('-S','.', '-B',$build,'-G','Visual Studio 17 2022','-A','x64',
                ('-DMC_ENABLE_CUDA='+$(if($cuda){'ON'}else{'OFF'})),
                ('-DMC_ENABLE_OPENMP='+$(if($omp){'ON'}else{'OFF'})),'-DMC_BUILD_CPU_TOOLS=OFF','-DBUILD_TESTING=ON')
            if($cuda){$args+=@('-T','cuda=13.4','-DCMAKE_CUDA_ARCHITECTURES=89')}
            if($config -eq 'sanitizer'){$args+='-DCMAKE_CUDA_FLAGS=-lineinfo'}
            $null=Run-Required ('configure-'+$config) 'cmake.exe' $args
            $null=Run-Required ('build-'+$config) 'cmake.exe' @('--build',$build,'--config','Release','--clean-first','--parallel')
            $list=Run-Required ('test-list-'+$config) 'ctest.exe' @('--test-dir',$build,'-C','Release','--show-only=json-v1')
            $tests=Get-Content -Encoding UTF8 -LiteralPath $list.stdout -Raw | ConvertFrom-Json
            $null=Run-Required ('ctest-'+$config) 'ctest.exe' @('--test-dir',$build,'-C','Release','-V','--output-on-failure')
            $manifest.builds += [pscustomobject]@{configuration=$config;path=$build;test_count=@($tests.tests).Count;cuda=$cuda;openmp=$omp}
            $manifest.artifacts+=Capture-Artifact (Join-Path $build 'CMakeCache.txt')
            foreach($f in Get-ChildItem (Join-Path $build 'Release') -File | Where-Object {$_.Extension -in @('.exe','.dll')}){
                $manifest.artifacts+=Capture-Artifact $f.FullName
            }
            if($cuda){
                Copy-Item -LiteralPath (Join-Path $build 'mc_cuda.vcxproj') -Destination (Join-Path $out ($config+'-mc_cuda.vcxproj'))
                $manifest.artifacts+=Capture-Artifact (Join-Path $build 'mc_cuda.vcxproj')
            }
            Copy-Item -LiteralPath (Join-Path $build 'CMakeCache.txt') -Destination (Join-Path $out ($config+'-CMakeCache.txt'))
            foreach($file in Get-ChildItem (Join-Path $build 'CMakeFiles/*/CMake*Compiler.cmake')){
                Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $out ($config+'-'+$file.Name))
            }
        }
        $cudaBuild=$tag+'-cuda'; $sanBuild=$tag+'-sanitizer'
        $exe=[IO.Path]::GetFullPath((Join-Path $cudaBuild 'Release/mc_var.exe'))
        $manifest['executable_path']=$exe; $manifest['executable_sha256']=Get-GpuHash $exe
        $manifest['build_cache_sha256']=Get-GpuHash (Join-Path $cudaBuild 'CMakeCache.txt')
        $manifest['runtime_libraries']=@(foreach($config in @('cuda','sanitizer')){
            foreach($dll in @('cudart64_13.dll','curand64_10.dll')){
                $path=Join-Path ($tag+'-'+$config) ('Release/'+$dll)
                $v=[Diagnostics.FileVersionInfo]::GetVersionInfo([IO.Path]::GetFullPath($path))
                [pscustomobject]@{configuration=$config;file=$dll;file_version=$v.FileVersion;product_version=$v.ProductVersion;sha256=(Get-GpuHash $path)}
            }
        })
        # Keep exact bytes of previous evidence; do not rerun large common-input cases.
        $old='results/cuda-hybrid-f039034-clean-20261019'
        $oldManifest=Join-Path $old 'manifest.json'; $oldAudit=Join-Path $old 'independent-audit.json'
        if((Get-GpuHash $oldManifest) -cne '4352958e62f77d0b059d7362056fb66b09d6dcfae95cc352bcdd61d84149d9b8' -or
            (Get-GpuHash $oldAudit) -cne 'b91d0df65d4347d8bee42601f9bd30ac02dcab92502705d3b23a6ca96d632af3'){throw 'Prior common evidence changed'}
        $oldData=Get-Content -Encoding UTF8 $oldManifest -Raw | ConvertFrom-Json
        foreach($r in $oldData.record_hashes){if((Get-GpuHash (Join-Path $old $r.file)) -cne $r.sha256){throw 'Prior record hash mismatch'}}
        $compatible=@('src','include','data/synthetic_prices.csv','tests/test_cuda.cpp','tests/test_cuda_hybrid.cpp')
        $null=& git diff --exit-code $oldData.source_revision $revision -- @compatible
        if($LASTEXITCODE -ne 0){throw 'Old common-input evidence is not source-compatible'}
        Write-GpuJson (Join-Path $out 'reused-common-input.json') ([ordered]@{source_revision=$oldData.source_revision;
            manifest_path=[IO.Path]::GetFullPath($oldManifest);manifest_sha256=(Get-GpuHash $oldManifest);
            independent_audit_path=[IO.Path]::GetFullPath($oldAudit);independent_audit_sha256=(Get-GpuHash $oldAudit);
            compatible_paths=$compatible;all_record_hashes_verified=$true;large_common_campaign_repeated=$false})
        $runs=@(); $rows=@(); $summary=@(); $failures=@()
        foreach($mode in $manifest.modes){foreach($seed in $manifest.seeds){
            $id='acceptance-'+$mode+'-'+$seed; Write-Host $id
            $args=@('--csv',$manifest.input_path,'10000000',$seed,'10','252','--backend','cuda','--cuda-mode',$mode)
            if($mode -ceq 'hybrid'){$args+=@('--batch-size','65535')}; $args+='--json'
            $p=Invoke-GpuProcess $exe $args (Join-Path $out $id)
            $record=[ordered]@{id=$id;mode=$mode;seed=$seed;exit_code=$p.exit_code;timed_out=$p.timed_out;
                process_record=$id+'.process.json';error=$p.start_error;result=$null;source_revision=$revision;
                input_sha256=(Get-GpuHash $manifest.input_path);executable_sha256=(Get-GpuHash $exe);
                build_cache_sha256=(Get-GpuHash (Join-Path $cudaBuild 'CMakeCache.txt'))}
            try {
                Assert-GpuProcess $p
                if((Get-Item $p.stderr).Length -ne 0){throw 'Nonempty acceptance stderr'}
                $record.result=Get-Content -Encoding UTF8 -LiteralPath $p.stdout -Raw | ConvertFrom-Json
                foreach($e in $record.result.estimates){
                    $rows += [pscustomobject]@{mode=$mode;seed=$seed;scenarios=10000000;confidence=$e.confidence;
                        mc_var=$e.mc_var;analytical_var=$e.analytical_var}
                }
            } catch { $record.error=$_.Exception.Message; $failures+=$id }
            $runs += [pscustomobject]$record
            [IO.File]::AppendAllText((Join-Path $out 'runs.jsonl'),(ConvertTo-Json $record -Depth 30 -Compress)+"`n",[Text.UTF8Encoding]::new($false))
        }}
        $rows | Export-Csv (Join-Path $out 'estimates.csv') -NoTypeInformation -Encoding UTF8
        # Recorder calculation is deliberately separate from the independent auditor.
        foreach($mode in $manifest.modes){foreach($alpha in @(.95,.99)){
            $group=@($rows | Where-Object {$_.mode -ceq $mode -and $_.confidence -eq $alpha})
            if($group.Count -ne 5){continue}
            $avg=($group | Measure-Object -Property mc_var -Average).Average
            $reference=[double]$group[0].analytical_var
            $validModeRun=@($runs | Where-Object {$_.mode -ceq $mode -and $null -ne $_.result})[0]
            $v0=[double]$validModeRun.result.model.initial_value
            $error=[Math]::Abs($avg-$reference);$limit=.01*[Math]::Max([Math]::Abs($reference),.01*$v0)
            $summary += [pscustomobject]@{mode=$mode;confidence=$alpha;scenarios=10000000;seed_count=5;
                mean_var=$avg;analytical_var=$reference;absolute_error_of_mean=$error;allowed_error=$limit;passed=($error -le $limit);
                per_seed=@($group | Select-Object mode,seed,confidence,mc_var)}
        }}
        Write-GpuJson (Join-Path $out 'acceptance.json') $summary
        $manifest.acceptance_status=if($failures.Count -eq 0 -and $summary.Count -eq 4 -and @($summary | Where-Object {-not $_.passed}).Count -eq 0){'passed'}else{'failed'}
        # Verify installed options and actual child-process attachment before matrix.
        $san=(Join-Path (Split-Path (Get-Command nvcc.exe).Source -Parent) '../compute-sanitizer/compute-sanitizer.exe')
        $san=[IO.Path]::GetFullPath($san); $manifest.artifacts+=Capture-Artifact $san
        $null=Run-Required 'sanitizer-version' $san @('--version')
        $help=Run-Required 'sanitizer-help' $san @('--help')
        $text=Get-Content -Encoding UTF8 $help.stdout -Raw
        foreach($option in @('error-exitcode','target-processes','initcheck-address-space','racecheck-detect-level','print-level','leak-check','padding','require-cuda-init')){
            if($text -notmatch [regex]::Escape('--'+$option)){throw "Missing sanitizer option $option"}
        }
        $null=Run-Required 'nvcc-version' 'nvcc.exe' @('--version')
        $null=Run-Required 'gpu-version' 'nvidia-smi.exe' @('--query-gpu=name,driver_version,compute_cap,memory.total','--format=csv')
        $reg=Get-ItemProperty -LiteralPath 'HKLM:/SOFTWARE/NVIDIA Corporation/GPUDebugger'
        Write-GpuJson (Join-Path $out 'debugger-interface.json') @{EnableInterface=$reg.EnableInterface;settings_changed=$false}
        if($reg.EnableInterface -ne 1){throw 'NVIDIA debugger interface is not enabled'}
        $matrix=@([pscustomobject]@{id='attachment-memcheck';tool='memcheck';target='mc_var';mode='full-device';n=1;seed='42';batch=0})+@(Get-GpuSanitizerMatrix)
        $sanRows=@();$attached=$false
        foreach($case in $matrix){
            Write-Host ('sanitizer '+$case.id)
            $prefix=Join-Path $out $case.id
            $target=[IO.Path]::GetFullPath((Join-Path $sanBuild ('Release/'+$case.target+'.exe')))
            $targetArgs=@()
            if($case.target -ceq 'mc_var'){
                $targetArgs=@('--csv',$manifest.input_path,[string]$case.n,$case.seed,'10','252','--backend','cuda','--cuda-mode',$case.mode)
                if($case.mode -ceq 'hybrid'){$targetArgs+=@('--batch-size','65535')};$targetArgs+='--json'
            }
            $spec=$prefix+'.spec.json'; Write-GpuJson $spec @{executable=$target;arguments=$targetArgs;prefix=($prefix+'.target');timeout_seconds=240}
            $log=$prefix+'.sanitizer.log'
            $options=@('--tool',$case.tool,'--error-exitcode','99','--target-processes','all','--require-cuda-init','yes','--print-limit','0','--log-file',$log)
            switch($case.tool){
                'memcheck' {$options+=@('--leak-check','full','--padding','32')}
                'initcheck' {$options+=@('--initcheck-address-space','all')}
                'racecheck' {$options+=@('--racecheck-report','all','--racecheck-detect-level','info','--print-level','info')}
            }
            $options+=@('powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'scripts/invoke-gpu-sanitizer-target.ps1'),'-SpecPath',$spec)
            $p=Invoke-GpuProcess $san $options $prefix 300
            $targetStatus=$null; $targetPath=$prefix+'.target.process.json'
            if(Test-Path -LiteralPath $targetPath){$targetStatus=Get-Content -Encoding UTF8 -LiteralPath $targetPath -Raw | ConvertFrom-Json}
            $logText=if(Test-Path -LiteralPath $log){Get-Content -Encoding UTF8 -LiteralPath $log -Raw}else{''}
            $ok=(-not $p.start_error -and -not $p.timed_out -and $p.exit_code -eq 0 -and $null -ne $targetStatus -and
                $targetStatus.exit_code -eq 0 -and -not $targetStatus.timed_out -and -not $targetStatus.start_error -and
                (Get-Item -LiteralPath $targetStatus.stderr).Length -eq 0 -and
                (Get-Item -LiteralPath $p.stderr).Length -eq 0 -and (Test-GpuSanitizerLog $logText))
            $sanRows += [pscustomobject]@{id=$case.id;tool=$case.tool;target=$case.target;mode=$case.mode;scenarios=$case.n;
                requested_batch_size=$case.batch;tool_exit_code=$p.exit_code;target_exit_code=$(if($targetStatus){$targetStatus.exit_code}else{$null});
                timed_out=$p.timed_out;passed=$ok;log=([IO.Path]::GetFileName($log));process_record=($case.id+'.process.json');
                target_process_record=($case.id+'.target.process.json')}
            Write-GpuJson (Join-Path $out 'sanitizer-results.json') $sanRows
            if($case.id -ceq 'attachment-memcheck'){
                if(-not $ok){throw 'Sanitizer attachment pilot failed; matrix not started'}
                $attached=$true
            }
        }
        $manifest.sanitizer_status=if($attached -and @($sanRows | Where-Object {-not $_.passed}).Count -eq 0){'passed'}else{'failed'}
        Write-GpuJson (Join-Path $out 'sanitizer-coverage.json') @{matrix=@(Get-GpuSanitizerMatrix);attachment_pilot=$attached;
            limitations=@('racecheck checks shared-memory hazards, not general global-memory race freedom',
                'CPU host-buffer accesses/leaks outside CUDA API are not checked','No sanitizer N=10000000 claim',
                'Reduced cases limit instrumentation/TDR cost; no TDR/registry changes',
                'No filters, suppressions, forced blocking launches, profiling or benchmark');
            source_reasoning='Per-index single writers; atomic error flag; per-request resources; one ordered stream for RNG/kernel/copies; synchronized copy before reuse; exception drain before host storage destruction; RAII release and checked successful cleanup'}
        $manifest.status='completed'
    } catch {
        $manifest.status='failed';$manifest['error']=$_.Exception.Message
        Write-Host ('Campaign failed: '+$_.Exception.Message)
    } finally {
        $manifest['finished_utc']=[DateTime]::UtcNow.ToString('o')
        $manifest['end_source_revision']=(& git rev-parse HEAD).Trim()
        $manifest['end_source_changes']=@(Get-GpuSourceChanges)
        $manifest['record_hashes']=@(Get-ChildItem -LiteralPath $out -File | Where-Object {$_.Name -cne 'manifest.json'} |
            ForEach-Object {[pscustomobject]@{file=$_.Name;sha256=(Get-GpuHash $_.FullName)}})
        Write-GpuJson $manifestPath $manifest
    }
    & (Join-Path $PSScriptRoot 'verify-gpu-acceptance.ps1') -Directory $out
    if($manifest.status -cne 'completed'){throw 'Campaign incomplete; preserved evidence must not be overwritten'}
} finally { Pop-Location }
