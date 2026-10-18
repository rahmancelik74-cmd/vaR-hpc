[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Directory)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'gpu-acceptance-audit.ps1')
$root=Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $root
try {
    $dir=(Resolve-Path -LiteralPath $Directory).Path
    $audit=[ordered]@{schema_version=1;purpose='Independent GPU campaign audit';status='failed';
        checked_utc=[DateTime]::UtcNow.ToString('o');numerical_acceptance='not-audited';sanitizer='not-audited';
        errors=@();acceptance=@()}
    try {
        $manifestPath=Join-Path $dir 'manifest.json'; $m=Get-Content -Encoding UTF8 -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $audit['manifest_sha256']=Get-GpuHash $manifestPath; $audit['source_revision']=$m.source_revision
        if($m.status -cne 'completed' -or -not $m.clean_source -or $m.end_source_revision -cne $m.source_revision -or
            @($m.end_source_changes).Count -ne 0){throw 'Incomplete campaign or changed source'}
        $tree=(& git rev-parse ($m.source_revision+'^{tree}')).Trim()
        if($LASTEXITCODE -ne 0 -or $tree -cne $m.source_tree){throw 'Incorrect source tree binding'}
        $seen=@{}
        foreach($r in $m.record_hashes){
            if($r.file -cne [IO.Path]::GetFileName($r.file) -or $seen.ContainsKey($r.file)){throw 'Invalid/duplicate record path'}
            $seen[$r.file]=$true
            if((Get-GpuHash (Join-Path $dir $r.file)) -cne $r.sha256){throw "Changed record bytes: $($r.file)"}
        }
        foreach($file in Get-ChildItem -LiteralPath $dir -File | Where-Object {$_.Name -notin @('manifest.json','independent-audit.json')}){
            if(-not $seen.ContainsKey($file.Name)){throw "Unbound output: $($file.Name)"}
        }
        foreach($a in $m.artifacts){Assert-GpuBoundArtifact $a.path $a.sha256}
        $cudaBuild=@($m.builds | Where-Object {$_.configuration -ceq 'cuda'})
        if($cudaBuild.Count -ne 1){throw 'Missing acceptance build'}
        Assert-GpuBoundArtifact (Join-Path $cudaBuild[0].path 'CMakeCache.txt') $m.build_cache_sha256
        if((Get-GpuHash (Join-Path $dir 'fixture.csv')) -cne $m.input_sha256 -or
            (Get-GpuHash $m.input_path) -cne $m.input_sha256 -or (Get-GpuHash $m.executable_path) -cne $m.executable_sha256){throw 'Changed fixture or executable'}
        $fixture=Get-IndependentGpuFixture (Join-Path $dir 'fixture.csv')
        $audit['independent_fixture']=$fixture
        $runs=@(Get-Content -Encoding UTF8 (Join-Path $dir 'runs.jsonl') | ForEach-Object {$_ | ConvertFrom-Json})
        foreach($r in $runs){
            if($r.process_record -cne ($r.id+'.process.json')){throw 'Wrong process record binding'}
            $p=Get-Content -Encoding UTF8 (Join-Path $dir $r.process_record) -Raw | ConvertFrom-Json
            Assert-GpuProcess $p
            if($p.exit_code -ne $r.exit_code -or (Get-Item -LiteralPath $p.stderr).Length -ne 0){throw 'Target exit/stderr mismatch'}
            $raw=Get-Content -Encoding UTF8 -LiteralPath $p.stdout -Raw | ConvertFrom-Json
            if((ConvertTo-Json $raw -Depth 30 -Compress) -cne (ConvertTo-Json $r.result -Depth 30 -Compress)){throw 'Raw/result mismatch'}
            $expected=@('--csv',$m.input_path,'10000000',$r.seed,'10','252','--backend','cuda','--cuda-mode',$r.mode)
            if($r.mode -ceq 'hybrid'){$expected+=@('--batch-size','65535')};$expected+='--json'
            if($p.executable -cne $m.executable_path -or (@($p.arguments) -join "`n") -cne ($expected -join "`n")){throw 'Wrong acceptance invocation'}
        }
        $expected=@(Get-IndependentGpuAcceptance $m $runs $fixture)
        $summary=@(Read-GpuJson (Join-Path $dir 'acceptance.json'))
        Test-GpuAcceptanceSummary $summary $expected
        $csv=@(Import-Csv (Join-Path $dir 'estimates.csv'));if($csv.Count -ne 20){throw 'Wrong CSV count'}
        $keys=@{}
        foreach($row in $csv){
            $key=$row.mode+'-'+$row.seed+'-'+$row.confidence
            if($keys.ContainsKey($key)){throw 'Duplicate CSV estimate'};$keys[$key]=$true
            $match=@($runs | Where-Object {$_.mode -ceq $row.mode -and $_.seed -ceq $row.seed})
            if($match.Count -ne 1 -or $row.scenarios -ne '10000000'){throw 'Wrong CSV configuration'}
            $alpha=[double]::Parse($row.confidence,[Globalization.CultureInfo]::InvariantCulture)
            $e=@($match[0].result.estimates | Where-Object {[double]$_.confidence -eq $alpha})
            if($e.Count -ne 1){throw 'Wrong CSV confidence'}
            foreach($field in @('mc_var','analytical_var')){
                Assert-GpuClose ([double]::Parse($row.$field,[Globalization.CultureInfo]::InvariantCulture)) $e[0].$field "CSV $field"
            }
        }
        $audit.acceptance=$expected
        $audit.numerical_acceptance=if(@($expected | Where-Object {-not $_.passed}).Count){'failed'}else{'passed'}
        foreach($build in $m.builds){
            foreach($phase in @('configure','build','test-list','ctest')){
                $process=Get-Content -Encoding UTF8 (Join-Path $dir ($phase+'-'+$build.configuration+'.process.json')) -Raw | ConvertFrom-Json
                Assert-GpuProcess $process
            }
            $list=Get-Content -Encoding UTF8 (Join-Path $dir ('test-list-'+$build.configuration+'.stdout.txt')) -Raw | ConvertFrom-Json
            if(@($list.tests).Count -ne $build.test_count -or $build.test_count -lt 1){throw 'CTest discovery mismatch'}
            $log=Get-Content -Encoding UTF8 (Join-Path $dir ('ctest-'+$build.configuration+'.stdout.txt')) -Raw
            if($log -notmatch ('100% tests passed, 0 tests failed out of '+$build.test_count+'\b')){throw 'CTest did not pass'}
            $cache=Get-Content -Encoding UTF8 (Join-Path $dir ($build.configuration+'-CMakeCache.txt')) -Raw
            if($cache -notmatch 'MC_BUILD_CPU_TOOLS:BOOL=OFF' -or $cache -notmatch 'BUILD_TESTING:BOOL=ON'){throw 'Wrong testing configuration'}
            if($build.cuda){
                if($cache -notmatch 'MC_ENABLE_CUDA:BOOL=ON' -or $cache -notmatch 'CMAKE_CUDA_ARCHITECTURES:UNINITIALIZED=89'){throw 'Wrong CUDA configuration'}
                if($build.configuration -ceq 'sanitizer' -and $cache -notmatch 'CMAKE_CUDA_FLAGS:STRING=-lineinfo'){throw 'Missing line information'}
                $project=Get-Content -Encoding UTF8 (Join-Path $dir ($build.configuration+'-mc_cuda.vcxproj')) -Raw
                if($project -cnotmatch '--fmad=false' -or $project -cnotmatch '/Zc:preprocessor'){throw 'Missing numerical/compiler flags'}
            } elseif($cache -match '(?m)^(CUDAToolkit|CMAKE_CUDA_COMPILER|MC_CUB_INCLUDE_DIR|CUDA_cudart_LIBRARY)[:_]'){
                throw 'CPU-only build discovered CUDA'
            }
            $flag=if($build.openmp){'ON'}else{'OFF'}
            if($cache -notmatch ('MC_ENABLE_OPENMP:BOOL='+$flag)){throw 'Wrong OpenMP setting'}
        }
        if((@($m.builds.configuration) -join ',') -cne 'cuda,cpu-openmp,cpu-serial,sanitizer'){throw 'Incomplete build matrix'}
        $reuse=Get-Content -Encoding UTF8 (Join-Path $dir 'reused-common-input.json') -Raw | ConvertFrom-Json
        if($reuse.manifest_sha256 -cne '4352958e62f77d0b059d7362056fb66b09d6dcfae95cc352bcdd61d84149d9b8' -or
            $reuse.independent_audit_sha256 -cne 'b91d0df65d4347d8bee42601f9bd30ac02dcab92502705d3b23a6ca96d632af3' -or
            (Get-GpuHash $reuse.manifest_path) -cne $reuse.manifest_sha256 -or
            (Get-GpuHash $reuse.independent_audit_path) -cne $reuse.independent_audit_sha256){throw 'Unverified prior evidence'}
        $prior=Get-Content -Encoding UTF8 $reuse.manifest_path -Raw | ConvertFrom-Json
        $priorDir=Split-Path $reuse.manifest_path -Parent
        foreach($r in $prior.record_hashes){if((Get-GpuHash (Join-Path $priorDir $r.file)) -cne $r.sha256){throw 'Prior record bytes changed'}}
        $paths=@('src','include','data/synthetic_prices.csv','tests/test_cuda.cpp','tests/test_cuda_hybrid.cpp')
        $null=& git diff --exit-code $prior.source_revision $m.source_revision -- @paths
        if($LASTEXITCODE -ne 0){throw 'Incompatible common-input source'}
        $common=Get-Content -Encoding UTF8 (Join-Path $priorDir 'hybrid-checks.json') -Raw | ConvertFrom-Json
        foreach($n in @(100000,1000000,10000000)){
            $case=@($common.cases | Where-Object {$_.kind -ceq 'common-input' -and $_.scenarios -eq $n})
            if($case.Count -ne 1 -or -not $case[0].passed -or $case[0].requested_batch_size -ne 65535 -or
                $case[0].maximum_difference -gt $case[0].project_tolerance){throw 'Incomplete reusable common-input coverage'}
        }
        $audit['reused_common_input']='source-compatible; all exact-byte hashes rechecked; no new large-N run'
        $san=@(Read-GpuJson (Join-Path $dir 'sanitizer-results.json'))
        $matrix=@([pscustomobject]@{id='attachment-memcheck';tool='memcheck';target='mc_var';mode='full-device';n=1;batch=0})+@(Get-GpuSanitizerMatrix)
        if($san.Count -ne $matrix.Count){throw 'Incomplete sanitizer matrix'}
        $allSanPassed=$true
        for($i=0;$i -lt $matrix.Count;$i++){
            $a=$san[$i];$e=$matrix[$i]
            if($a.id -cne $e.id -or $a.tool -cne $e.tool -or $a.target -cne $e.target -or $a.mode -cne $e.mode -or
                $a.scenarios -ne $e.n -or $a.requested_batch_size -ne $e.batch){throw 'Changed/reordered sanitizer matrix'}
            $p=Get-Content -Encoding UTF8 (Join-Path $dir $a.process_record) -Raw | ConvertFrom-Json
            $targetPath=Join-Path $dir $a.target_process_record
            $target=$null;if(Test-Path $targetPath){$target=Get-Content -Encoding UTF8 $targetPath -Raw | ConvertFrom-Json}
            $log=Get-Content -Encoding UTF8 (Join-Path $dir $a.log) -Raw
            $options=@('--tool',$e.tool,'--error-exitcode','99','--target-processes','all','--require-cuda-init','yes','--print-limit','0','--log-file',(Join-Path $dir $a.log))
            switch($e.tool){
                'memcheck' {$options+=@('--leak-check','full','--padding','32')}
                'initcheck' {$options+=@('--initcheck-address-space','all')}
                'racecheck' {$options+=@('--racecheck-report','all','--racecheck-detect-level','info','--print-level','info')}
            }
            $options+=@('powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'scripts/invoke-gpu-sanitizer-target.ps1'),'-SpecPath',(Join-Path $dir ($e.id+'.spec.json')))
            if((@($p.arguments) -join "`n") -cne ($options -join "`n")){throw 'Wrong sanitizer options'}
            $spec=Get-Content -Encoding UTF8 (Join-Path $dir ($e.id+'.spec.json')) -Raw | ConvertFrom-Json
            $build=@($m.builds | Where-Object {$_.configuration -ceq 'sanitizer'})[0]
            $exe=[IO.Path]::GetFullPath((Join-Path $build.path ('Release/'+$e.target+'.exe')))
            $args=@();if($e.target -ceq 'mc_var'){
                $args=@('--csv',$m.input_path,[string]$e.n,'42','10','252','--backend','cuda','--cuda-mode',$e.mode)
                if($e.mode -ceq 'hybrid'){$args+=@('--batch-size','65535')};$args+='--json'
            }
            if($spec.executable -cne $exe -or (@($spec.arguments) -join "`n") -cne ($args -join "`n")){throw 'Wrong sanitizer target'}
            if($null -ne $target -and ($target.executable -cne $spec.executable -or
                (@($target.arguments) -join "`n") -cne ($args -join "`n"))){throw 'Target status/invocation mismatch'}
            $pass=($null -ne $target -and -not $p.start_error -and -not $p.timed_out -and $p.exit_code -eq 0 -and
                -not $target.start_error -and -not $target.timed_out -and $target.exit_code -eq 0 -and
                (Get-Item -LiteralPath $target.stderr).Length -eq 0 -and (Get-Item -LiteralPath $p.stderr).Length -eq 0 -and
                (Test-GpuSanitizerLog $log))
            if($a.tool_exit_code -ne $p.exit_code -or ($null -ne $target -and $a.target_exit_code -ne $target.exit_code) -or $a.passed -ne $pass){throw 'Incorrect sanitizer outcome'}
            if(-not $pass){$allSanPassed=$false}
        }
        $audit.sanitizer=if($allSanPassed){'passed'}else{'failed'}
        $audit['sanitizer_attempts']=$san.Count
        $audit['limitations']=@('Representative sanitizer sizes only; no N=10000000 sanitizer claim',
            'Racecheck is shared-memory hazard checking, not general global-memory race freedom',
            'CPU host-buffer accesses/leaks outside CUDA API remain outside tool coverage')
        if($audit.numerical_acceptance -cne 'passed' -or -not $allSanPassed){throw 'Numerical acceptance or sanitizer checks failed'}
        if($m.acceptance_status -cne $audit.numerical_acceptance -or $m.sanitizer_status -cne $audit.sanitizer){throw 'Manifest outcome mismatch'}
        $audit.status='passed'
    } catch { $audit.errors+= $_.Exception.Message }
    Write-GpuJson (Join-Path $dir 'independent-audit.json') $audit
    if($audit.status -cne 'passed'){throw ('Independent audit failed: '+($audit.errors -join '; '))}
    Write-Host ('Independent audit passed: '+$dir)
} finally { Pop-Location }
