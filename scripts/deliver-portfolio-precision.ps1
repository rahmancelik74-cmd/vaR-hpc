param(
    [switch]$VerifyOnly,
    [string]$Python = 'C:/Users/rahma/anaconda3/python.exe',
    [ValidateRange(60,1800)][int]$CiTimeoutSeconds = 1200
)
$ErrorActionPreference = 'Stop'
$env:GIT_PAGER = 'cat'
$env:PAGER = 'cat'
$env:GIT_TERMINAL_PROMPT = '0'
$env:GH_PROMPT_DISABLED = 'true'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$Baseline = 'e0fc594f14bd1814856c668132e21808d1826083'
$Repository = 'rahmancelik74-cmd/vaR-hpc'
$Package = 'evidence/portfolio-precision-20261025-v1'

function Invoke-Git([string[]]$Arguments) {
    $value = & git --no-pager @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed ($LASTEXITCODE): $($Arguments -join ' ')" }
    return $value
}
function Invoke-Gh([string[]]$Arguments) {
    $value = & gh @Arguments
    if ($LASTEXITCODE -ne 0) { throw "GitHub CLI failed ($LASTEXITCODE): $($Arguments -join ' ')" }
    return $value
}
function Invoke-Python([string[]]$Arguments) {
    & $Python -B @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Python check failed ($LASTEXITCODE)" }
}

# Explicit task scope, independent of any pre-existing staging or manifest input.
$EvidenceNames = @('.gitattributes','README.md','protocol-v1.json','freeze-v1.json',
    'reference.json','numerical.json','reassessment.csv','completion.json',
    'comparison.png','figure-data.json','verification.json','delivery.json',
    'artifact-sha256.json','delivery-files.json')
$TaskFiles = @('.github/workflows/build.yml','docs/portfolio.md','docs/portfolio-campaign.md',
    'docs/project-state.md','scripts/.gitattributes','scripts/portfolio_precision.py',
    'scripts/verify_portfolio_precision.py','scripts/plot_portfolio_precision.py',
    'scripts/audit_portfolio_precision.py','scripts/deliver-portfolio-precision.ps1',
    'tests/test_portfolio_precision.py','tests/test_portfolio_precision_integrity.py')
$TaskFiles += @($EvidenceNames | ForEach-Object { "$Package/$_" })
$ManifestPath = "$Package/delivery-files.json"
$Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
if ($Manifest.baseline -cne $Baseline) { throw 'Delivery manifest baseline mismatch' }
if ((Invoke-Git @('rev-parse','--show-toplevel')).Replace('\','/') -ine $Root.Replace('\','/')) { throw 'Wrong repository root' }
if ((Invoke-Git @('branch','--show-current')) -cne 'main') { throw 'Expected main branch' }
if ((Invoke-Git @('rev-parse','HEAD')) -cne $Baseline) { throw 'HEAD changed; review new work, do not reset or reuse this guard' }
foreach ($kind in @('--get-url','--push')) {
    $remoteArgs = if ($kind -eq '--push') { @('remote','get-url','--push','origin') } else { @('remote','get-url','origin') }
    $url = Invoke-Git $remoteArgs
    if ($url -cnotin @('https://github.com/rahmancelik74-cmd/vaR-hpc','https://github.com/rahmancelik74-cmd/vaR-hpc.git')) { throw 'Unauthorized remote URL' }
}

# Validate staging scope BEFORE accepting existing staging or adding anything.
$staged = @(Invoke-Git @('diff','--cached','--name-only'))
foreach ($path in $staged) {
    if ($path -cnotin $TaskFiles) { throw "Unrelated staged file: $path" }
}
$changed = @(Invoke-Git @('diff','HEAD','--name-only'))
foreach ($path in $changed) {
    if ($path -cnotin $TaskFiles) { throw "Unrelated tracked changes require separate review: $path" }
}
$expected = @($TaskFiles | Where-Object { $_ -cne $ManifestPath } | Sort-Object)
$listed = @($Manifest.files.PSObject.Properties.Name | Sort-Object)
if (@(Compare-Object $expected $listed -CaseSensitive).Count) { throw 'Task manifest file scope mismatch' }
foreach ($entry in $Manifest.files.PSObject.Properties) {
    $actual = (Get-FileHash -LiteralPath $entry.Name -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $entry.Value) { throw "Task-file exact-byte hash mismatch: $($entry.Name)" }
}
Invoke-Python @('scripts/verify_portfolio_precision.py')
Invoke-Python @('scripts/verify_portfolio_campaign.py')
Invoke-Python @('-m','unittest','discover','-s','tests','-p','test_portfolio_precision*.py','-v')

# Frozen generated evidence uses exact-byte hash checks, not whitespace rewriting.
$sourceFiles = @($TaskFiles | Where-Object { -not $_.StartsWith('evidence/') })
Invoke-Git (@('-c','core.whitespace=cr-at-eol','diff','--check','HEAD','--') + $sourceFiles)
$whitespaceCheck = @'
import pathlib,sys
for name in sys.argv[1:]:
    data=pathlib.Path(name).read_bytes()
    for number,line in enumerate(data.splitlines(),1):
        assert line==line.rstrip(b' \t'), 'Trailing whitespace: %s:%s'%(name,number)
print('CRLF-aware source/current-document whitespace checks passed; frozen evidence checked by hashes')
'@
Invoke-Python (@('-c',$whitespaceCheck) + $sourceFiles)
if ($VerifyOnly) {
    Write-Output 'Delivery preflight passed; verify-only did not stage, commit, push or query credentials.'
    exit 0
}

# Fail authentication/remote checks before mutating the index or committing.
Invoke-Gh @('auth','status')
$remoteLine = Invoke-Git @('ls-remote','origin','refs/heads/main')
if (($remoteLine -split '\s+')[0] -cne $Baseline) { throw 'Remote main advanced; preserve newer work and review' }
Invoke-Git (@('add','--') + $TaskFiles)
$staged = @(Invoke-Git @('diff','--cached','--name-only'))
if (@(Compare-Object @($TaskFiles | Sort-Object) @($staged | Sort-Object) -CaseSensitive).Count) { throw 'Unexpected staged task file set' }
foreach ($path in $TaskFiles) {
    # hash-object applies the same per-path Git filters; no global setting changes.
    $expectedBlob = Invoke-Git @('hash-object',"--path=$path",'--',$path)
    $indexBlob = Invoke-Git @('rev-parse',":$path")
    if ($expectedBlob -cne $indexBlob) { throw "Index differs from validated file: $path" }
}
$byteCheck = @'
import hashlib,json,pathlib,subprocess
root=pathlib.Path.cwd()
m=json.loads((root/'evidence/portfolio-precision-20261025-v1/delivery-files.json').read_text())
for name,digest in m['files'].items():
    if name.startswith('evidence/') or name in ('scripts/portfolio_precision.py','scripts/verify_portfolio_precision.py','scripts/plot_portfolio_precision.py','scripts/audit_portfolio_precision.py','scripts/deliver-portfolio-precision.ps1'):
        blob=subprocess.check_output(['git','show',':'+name])
        assert hashlib.sha256(blob).hexdigest()==digest, 'Frozen staged bytes changed: '+name
print('Frozen index byte hashes passed; source/document Git normalization kept separate')
'@
Invoke-Python @('-c',$byteCheck)
Invoke-Git (@('-c','core.whitespace=cr-at-eol','diff','--cached','--check','--') + $sourceFiles)
Invoke-Git @('commit','-m','Add targeted two-asset portfolio reference precision follow-up')
$sha = Invoke-Git @('rev-parse','HEAD')
if ((Invoke-Git @('rev-parse','HEAD^')) -cne $Baseline) { throw 'Unexpected commit parent; do not push' }
$committed = @(Invoke-Git @('diff-tree','--no-commit-id','--name-only','-r',$sha))
if (@(Compare-Object @($TaskFiles | Sort-Object) @($committed | Sort-Object) -CaseSensitive).Count) { throw 'Commit scope mismatch; do not push' }
$resultPath = 'results/portfolio-precision-20261025-v1/delivery-result.json'
$record = [ordered]@{ sha=$sha; remote_sha=$null; pushed=$false; ci='not_started'; url=$null; observed_utc=[DateTime]::UtcNow.ToString('o') }
$record | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding ASCII
Invoke-Git @('push','origin','HEAD:refs/heads/main')
$remoteLine = Invoke-Git @('ls-remote','origin','refs/heads/main')
if (($remoteLine -split '\s+')[0] -cne $sha) { throw 'Remote SHA does not match delivered commit' }

$record.remote_sha=$sha; $record.pushed=$true; $record.ci='pending'
$record | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding ASCII
$deadline = [DateTime]::UtcNow.AddSeconds($CiTimeoutSeconds)
while ([DateTime]::UtcNow -lt $deadline) {
    $response = (Invoke-Gh @('api',"repos/$Repository/actions/runs?head_sha=$sha&event=push&per_page=20")) -join "`n" | ConvertFrom-Json
    $runs = @($response.workflow_runs | Where-Object { $_.head_sha -ceq $sha -and $_.name -ceq 'CPU build and tests' })
    if ($runs.Count -gt 1) { throw 'Multiple matching runs require explicit review' }
    if ($runs.Count -eq 1 -and $runs[0].status -ceq 'completed') {
        $run = $runs[0]
        $record.ci=$run.conclusion; $record.url=$run.html_url
        $record.observed_utc=[DateTime]::UtcNow.ToString('o')
        $record | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding ASCII
        if ($run.conclusion -cne 'success') { throw "Exact-SHA CI $($run.conclusion): $($run.html_url)" }
        $jobs = (Invoke-Gh @('api',"repos/$Repository/actions/runs/$($run.id)/jobs?per_page=100")) -join "`n" | ConvertFrom-Json
        if ($jobs.total_count -ne 3 -or @($jobs.jobs | Where-Object { $_.conclusion -cne 'success' }).Count) { throw 'Expected three successful CI jobs' }
        Write-Output "DELIVERED SHA=$sha CI=$($run.html_url) conclusion=success"
        Write-Output "Persistent exact-SHA delivery record: $resultPath"
        exit 0
    }
    Start-Sleep -Seconds 20
}
throw "Bounded CI wait expired for $sha. Pushed commit retained; inspect exact-SHA run, do not rerun delivery."
