[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Plan,[Parameter(Mandatory=$true)][string]$OutputDirectory,
    [switch]$ExecuteMissing,[string]$PreviousDirectory='')
. (Join-Path $PSScriptRoot 'convergence-record.ps1')

$root=Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    $planPath=(Resolve-Path -LiteralPath $Plan).Path;$p=Read-GpuJson $planPath;Test-ConvergencePlan $p
    $records=@(Get-ConvergenceImports $p);$priorAttempts=@()
    if($PreviousDirectory){
        $old=Read-GpuJson (Join-Path $PreviousDirectory 'dataset.json')
        Test-ConvergenceDataset $old
        if($old.plan_sha256 -cne (Get-GpuHash $planPath)){throw 'Previous dataset uses another plan'}
        Test-ConvergenceRecords $p @($old.records) (Get-IndependentGpuFixture $p.fixture.path)
        Test-ConvergenceAttemptInventory $PreviousDirectory @($old.records)
        $records=@($old.records)
        $priorAttempts=@(Read-GpuJson (Join-Path $PreviousDirectory 'attempts.json'))
        foreach($a in $priorAttempts){Assert-GpuBoundArtifact $a.path $a.sha256}
    }
    $out=[IO.Path]::GetFullPath($OutputDirectory)
    $allowed=[IO.Path]::GetFullPath('results')+[IO.Path]::DirectorySeparatorChar
    if(-not $out.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $out)){throw 'Use a new directory under ignored results/'}
    if($ExecuteMissing -and @(Get-GpuSourceChanges).Count){throw 'Clean committed source required before native execution'}
    $null=New-Item -ItemType Directory -Path $out
    Write-GpuJson (Join-Path $out 'attempts.json') $priorAttempts
    $d=New-ConvergenceDataset $planPath $records
    Write-GpuJson (Join-Path $out 'dataset.json') $d
    if($ExecuteMissing){
        $revision=(& git rev-parse HEAD).Trim()
        $null=& git diff --exit-code $p.reviewed_revision $revision -- src include data/synthetic_prices.csv
        if($LASTEXITCODE -ne 0){throw 'Engine changes require an explicit compatibility review/new plan'}
        $build='build-convergence-'+$revision.Substring(0,7)+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)
        $session=[ordered]@{status='building';source_revision=$revision;plan_sha256=$d.plan_sha256;attempted_native_configurations=0;error=$null;started_utc=[DateTime]::UtcNow.ToString('o')}
        Write-GpuJson (Join-Path $out 'session.json') $session
        try {
            foreach($step in @(
                @('configure','cmake.exe',@('-S','.', '-B',$build,'-G','Visual Studio 17 2022','-A','x64','-T','cuda=13.4',
                    '-DMC_ENABLE_CUDA=ON','-DMC_ENABLE_OPENMP=ON','-DMC_BUILD_CPU_TOOLS=OFF','-DBUILD_TESTING=ON','-DCMAKE_CUDA_ARCHITECTURES=89')),
                @('build','cmake.exe',@('--build',$build,'--config','Release','--clean-first','--parallel')))){
                $process=Invoke-GpuProcess $step[1] $step[2] (Join-Path $out $step[0])
                Assert-GpuProcess $process
            }
            foreach($step in @(
                @('test-list','ctest.exe',@('--test-dir',$build,'-C','Release','--show-only=json-v1')),
                @('ctest','ctest.exe',@('--test-dir',$build,'-C','Release','--output-on-failure','-V')),
                @('focused','powershell.exe',@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'tests/test_convergence.ps1'))))){
                $process=Invoke-GpuProcess $step[1] $step[2] (Join-Path $out $step[0])
                Assert-GpuProcess $process
            }
            $discovery=Read-GpuJson (Join-Path $out 'test-list.stdout.txt')
            $preflight=[pscustomobject]@{test_count=@($discovery.tests).Count;
                discovery_process=(Join-Path $out 'test-list.process.json');regression_process=(Join-Path $out 'ctest.process.json');
                focused_process=(Join-Path $out 'focused.process.json')}
            Test-ConvergencePreflight $preflight $build
            if((& git rev-parse HEAD).Trim() -cne $revision -or @(Get-GpuSourceChanges).Count){throw 'Source changed during build'}
            $fixture=Join-Path $out 'fixture.csv';[IO.File]::Copy((Resolve-Path $p.fixture.path).Path,$fixture)
            $exe=[IO.Path]::GetFullPath("$build/Release/mc_var.exe");$cache="$build/CMakeCache.txt"
            $files=@($exe,$cache,$fixture,$planPath)+@(Get-ChildItem "$build/Release/*.dll" | ForEach-Object {$_.FullName})+
                @(Get-ChildItem (Join-Path $PSScriptRoot '*convergence*.ps1') | ForEach-Object {$_.FullName})+
                @('scripts/gpu-record-common.ps1','scripts/gpu-acceptance-audit.ps1','tests/test_convergence.ps1','tests/test_convergence_statistics.ps1',"$build/mc_cuda.vcxproj")+
                @(Get-ChildItem -LiteralPath $out -File | Where-Object {$_.Name -match '^(configure|build|test-list|ctest|focused)\.'} | ForEach-Object {$_.FullName})
            $b=[pscustomobject]@{source_revision=$revision;source_tree=(& git rev-parse 'HEAD^{tree}').Trim();clean_source=$true;
                source_to_binary='Clean-first Windows x64 Release rebuild in this invocation';plan_path=$planPath;plan_sha256=$d.plan_sha256;
                fixture_path=$fixture;input_sha256=$p.fixture.sha256;executable_path=$exe;executable_sha256=(Get-GpuHash $exe);
                build_cache_sha256=(Get-GpuHash $cache);artifacts=@($files|ForEach-Object {Get-ConvergenceArtifact $_});
                preflight=$preflight;cuda_project_path="$build/mc_cuda.vcxproj";
                build_directory=$build;configure_process=(Join-Path $out 'configure.process.json');build_process=(Join-Path $out 'build.process.json');
                process_policy='Fresh CLI process/CUDA context per native observation; diagnostics OFF; no benchmark';
                conditions='Not measured; no thermal equilibrium claim'}
            $bindingPath=Join-Path $out 'binding.json';Write-GpuJson $bindingPath $b
            $session.status='recording'
            $records=@(Invoke-ConvergenceMissing $p $records $bindingPath $out)
            $session.status='completed'
        }catch{$session.status='failed';$session.error=$_.Exception.Message;throw}
        finally {
            $newAttempts=@(Get-ChildItem -LiteralPath $out -File | Where-Object {$_.Name -match '^attempt-\d+\.json$'} | ForEach-Object {Get-ConvergenceArtifact $_.FullName})
            Write-GpuJson (Join-Path $out 'attempts.json') @($priorAttempts+$newAttempts)
            $session.attempted_native_configurations=$newAttempts.Count
            $session['finished_utc']=[DateTime]::UtcNow.ToString('o')
            Write-GpuJson (Join-Path $out 'session.json') $session
        }
    }
    & (Join-Path $PSScriptRoot 'analyze-convergence.ps1') -Directory $out
    & (Join-Path $PSScriptRoot 'verify-convergence.ps1') -Directory $out
    Write-Host "Convergence output: $out"
}finally{Pop-Location}
