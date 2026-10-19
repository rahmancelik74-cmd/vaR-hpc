# Read-only relocation for the former repository root; raw evidence is unchanged.
$script:ConvergenceCurrentRoot=Split-Path -Parent $PSScriptRoot
$script:ConvergenceFormerRoot=Join-Path $env:USERPROFILE ('OneDrive\Masa'+[char]0xfc+'st'+[char]0xfc+'\graduation_project\gpu-montecarlo-starter')
if(-not (Get-Variable ConvergenceRelocations -Scope Script -ErrorAction SilentlyContinue)){$script:ConvergenceRelocations=@{}}
function Resolve-ConvergenceRecordedPath([string]$Path) {
    $normalized=$Path.Replace('/','\')
    $oldPrefix=$script:ConvergenceFormerRoot+'\'
    if($normalized.StartsWith($oldPrefix,[StringComparison]::OrdinalIgnoreCase)){
        $suffix=$normalized.Substring($oldPrefix.Length)
        $candidate=[IO.Path]::GetFullPath((Join-Path $script:ConvergenceCurrentRoot $suffix))
        $currentPrefix=[IO.Path]::GetFullPath($script:ConvergenceCurrentRoot)+'\'
        if(-not $candidate.StartsWith($currentPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Recorded path escapes repository'}
        if(-not(Test-Path -LiteralPath $candidate)){throw "Missing relocated artifact: $Path -> $candidate"}
        $script:ConvergenceRelocations[$Path]=[pscustomobject]@{recorded_path=$Path;resolved_path=$candidate}
        return $candidate
    }
    return $Path
}
function Get-GpuHash($Path) {
    (Get-FileHash -LiteralPath (Resolve-ConvergenceRecordedPath $Path) -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Read-GpuJson($Path) {
    $value=Get-Content -Encoding UTF8 -LiteralPath (Resolve-ConvergenceRecordedPath $Path) -Raw | ConvertFrom-Json
    return $value
}
function Get-ConvergenceRelocations {
    @($script:ConvergenceRelocations.Values | Sort-Object recorded_path)
}
