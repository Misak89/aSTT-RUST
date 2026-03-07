param(
    [string]$RootPath = ".",
    [string]$SourcePath = ".pre-commit-config.yaml",
    [string]$OutputPath = "docs_control/observed_workflow/hooks.json",
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"

function Resolve-RepoPath {
    param([string]$PathValue)
    return (Join-Path $RootPath $PathValue)
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","SUCCESS","WARN","ERROR")]
        [string]$Level = "INFO"
    )
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        default { "Cyan" }
    }
    if ($DetailedOutput -or $Level -in @("SUCCESS","WARN","ERROR")) {
        Write-Host $Message -ForegroundColor $color
    }
}

function ConvertTo-CanonicalJson {
    param([object]$Object)
    return (($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n").TrimEnd() + "`n"
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Extract pre-commit observed hooks" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$sourceFull = Resolve-RepoPath -PathValue $SourcePath
$outputFull = Resolve-RepoPath -PathValue $OutputPath
if (-not (Test-Path $sourceFull)) {
    Write-Host "Missing source file: $SourcePath" -ForegroundColor Red
    exit 1
}

$lines = Get-Content -Path $sourceFull -Encoding UTF8
$currentRepo = ""
$hooks = New-Object System.Collections.Generic.List[object]
$currentHook = $null

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    if ($line -match '^\s*-\s*repo:\s*(.+?)\s*$') {
        $currentRepo = $Matches[1].Trim()
        continue
    }

    if ($line -match '^\s*-\s*id:\s*([^\s#]+)\s*$') {
        if ($null -ne $currentHook) {
            $hooks.Add([pscustomobject]$currentHook)
        }
        $currentHook = [ordered]@{
            order_index = [int]($hooks.Count + 1)
            line = [int]($i + 1)
            repo = $currentRepo
            hook_id = $Matches[1].Trim()
            name = ""
            entry = ""
            files = ""
            exclude = ""
            always_run = $null
            pass_filenames = $null
        }
        continue
    }

    if ($null -eq $currentHook) { continue }

    if ($line -match '^\s*name:\s*(.+?)\s*$') { $currentHook.name = $Matches[1].Trim(); continue }
    if ($line -match '^\s*entry:\s*(.+?)\s*$') { $currentHook.entry = $Matches[1].Trim(); continue }
    if ($line -match '^\s*files:\s*(.+?)\s*$') { $currentHook.files = $Matches[1].Trim(); continue }
    if ($line -match '^\s*exclude:\s*(.+?)\s*$') { $currentHook.exclude = $Matches[1].Trim(); continue }
    if ($line -match '^\s*always_run:\s*(true|false)\s*$') { $currentHook.always_run = ([bool]::Parse($Matches[1])); continue }
    if ($line -match '^\s*pass_filenames:\s*(true|false)\s*$') { $currentHook.pass_filenames = ([bool]::Parse($Matches[1])); continue }
}

if ($null -ne $currentHook) {
    $hooks.Add([pscustomobject]$currentHook)
}

$manifest = [ordered]@{
    schema_version = "1.0"
    manifest_type = "observed_pre_commit_hooks"
    source_path = ($SourcePath -replace "\\","/")
    hooks = @($hooks | Sort-Object order_index, line, hook_id)
}

$json = ConvertTo-CanonicalJson -Object $manifest
$outDir = Split-Path -Path $outputFull -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outputFull, $json, $enc)

Write-Log -Message "PASS: wrote observed hooks manifest -> $OutputPath (hooks=$($hooks.Count))" -Level "SUCCESS"
exit 0
