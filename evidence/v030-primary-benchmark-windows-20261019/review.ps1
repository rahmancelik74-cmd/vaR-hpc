param([string]$RepositoryRoot=(Get-Location).Path,
    [string]$ReviewDirectory='results/benchmark-closure-20261019')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $RepositoryRoot
$root=(Get-Location).Path
$review=[IO.Path]::GetFullPath((Join-Path $root $ReviewDirectory))
$null=New-Item -ItemType Directory -Force -Path $review
. ./scripts/benchmark-common.ps1
$session=Join-Path $root 'results/benchmark-formal-89536e3-20261019-run2'
$first=Join-Path $root 'results/benchmark-formal-89536e3-20261019-run1'
$before=@{}
foreach($directory in @($first,$session)){
    foreach($file in Get-ChildItem -LiteralPath $directory -File -Recurse){
        $before[$file.FullName]=Get-GpuHash $file.FullName
    }
}
$counts=@{}
foreach($directory in @($first,$session)){
    $manifest=Read-GpuJson (Join-Path $directory 'session-manifest.json')
    foreach($record in $manifest.records){
        Assert-GpuBoundArtifact (Join-Path $directory $record.file) $record.sha256
    }
    $counts[(Split-Path $directory -Leaf)]=@($manifest.records).Count
}
$sm=Read-GpuJson (Join-Path $session 'session-manifest.json')
Assert-GpuBoundArtifact (Join-Path $session 'campaign/manifest.json') $sm.campaign_manifest_sha256
Assert-GpuBoundArtifact (Join-Path $session 'campaign/independent-audit.json') $sm.campaign_audit_sha256
Assert-GpuBoundArtifact (Join-Path $session 'session-independent-audit.json') $sm.session_audit_sha256
Assert-GpuBoundArtifact (Join-Path $first 'session-manifest.json') $sm.prior_incomplete_session.manifest_sha256
$failure=Read-GpuJson (Join-Path $first 'failure-diagnosis.json')
$failedProcess=Read-GpuJson (Join-Path $first 'formal-recorder.process.json')
if((Test-Path (Join-Path $first 'campaign')) -or $failure.benchmark_processes_started -ne 0 -or
    $failure.status -cne 'incomplete' -or $failedProcess.exit_code -ne 1){throw 'First invocation evidence mismatch'}

# Reuse both existing auditors, redirecting only their final report destinations.
# Never overwrite the original hash-bound audit files.
$verifierPath=Join-Path $root 'scripts/verify-benchmark.ps1'
$verifier=[IO.File]::ReadAllText($verifierPath)
$needle="Write-GpuJson (Join-Path `$dir 'independent-audit.json') `$audit"
if(-not $verifier.Contains($needle)){throw 'Verifier output statement changed'}
$verifier=$verifier.Replace($needle,"Write-GpuJson (Join-Path '$review' 'recorder-reaudit.json') `$audit")
$verifier=$verifier.Replace('$PSScriptRoot',("'"+(Join-Path $root 'scripts')+"'"))
& ([scriptblock]::Create($verifier)) -Directory (Join-Path $session 'campaign')
$supplementPath=Join-Path $session 'audit-session.ps1'
$supplement=[IO.File]::ReadAllText($supplementPath)
$needle="Write-GpuJson (Join-Path `$out 'session-independent-audit.json') `$report"
if(-not $supplement.Contains($needle)){throw 'Session auditor output statement changed'}
$supplement=$supplement.Replace($needle,"Write-GpuJson (Join-Path '$review' 'session-reaudit.json') `$report")
$supplement=$supplement.Replace('$PSScriptRoot',("'"+$session+"'"))
& ([scriptblock]::Create($supplement))
foreach($path in $before.Keys){Assert-GpuBoundArtifact $path $before[$path]}
$after=@(Get-ChildItem -LiteralPath $first,$session -File -Recurse)
if($after.Count -ne $before.Count){throw 'Original evidence file set changed'}
Write-GpuJson (Join-Path $review 'closure-audit.json') ([ordered]@{
    status='passed';checked_utc=[DateTime]::UtcNow.ToString('o');
    source_revision=$sm.source_revision;session_record_counts=$counts;
    original_files_unchanged=$before.Count;benchmark_processes_launched=0;
    first_invocation='Incomplete, path error before campaign creation, zero samples; retained unchanged';
    existing_auditors='Passed with only final report destinations redirected; original evidence unchanged';
    verifier_sha256=(Get-GpuHash $verifierPath);session_auditor_sha256=(Get-GpuHash $supplementPath);
    session_manifest_sha256=(Get-GpuHash (Join-Path $session 'session-manifest.json'));
    first_session_manifest_sha256=(Get-GpuHash (Join-Path $first 'session-manifest.json'))
})
Write-Host 'Closure audit passed; no benchmark processes launched; original evidence unchanged.'
