param(
    [string]$RootPath = "",
    [string]$PreCommitConfigPath = "",
    [string]$OutputJsonPath = "",
    [string]$RawLogPath = "",
    [int]$TopN = 15
)

$ErrorActionPreference = "Stop"

if (-not $RootPath) {
    $RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
if (-not $PreCommitConfigPath) {
    $PreCommitConfigPath = Join-Path $RootPath ".pre-commit-config.markdownlint-backlog.yaml"
}
if (-not $OutputJsonPath) {
    $OutputJsonPath = Join-Path $RootPath "logs\verify\markdownlint_backlog_summary.json"
}
if (-not $RawLogPath) {
    $RawLogPath = Join-Path $RootPath "logs\verify\markdownlint_backlog_latest.log"
}

function To-Array {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable]) { return @($Value) }
    return @($Value)
}

function Add-Count {
    param(
        [hashtable]$Map,
        [string]$Key
    )
    if (-not $Map.ContainsKey($Key)) { $Map[$Key] = 0 }
    $Map[$Key] = [int]$Map[$Key] + 1
}

if (-not (Test-Path $PreCommitConfigPath)) {
    Write-Host "Markdownlint backlog config not found: $PreCommitConfigPath" -ForegroundColor Yellow
    exit 0
}

$preCommitExe = Join-Path $RootPath ".venv\Scripts\pre-commit.exe"
if (-not (Test-Path $preCommitExe)) {
    $cmd = Get-Command pre-commit -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        $preCommitExe = $cmd.Source
    }
}
if (-not (Test-Path $preCommitExe)) {
    Write-Host "pre-commit not found; skipping markdownlint backlog report." -ForegroundColor Yellow
    exit 0
}

New-Item -ItemType Directory -Path (Split-Path $OutputJsonPath -Parent) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $RawLogPath -Parent) -Force | Out-Null

$args = @(
    "run",
    "-c", $PreCommitConfigPath,
    "markdownlint-cli2",
    "--all-files"
)

Write-Host "Running markdownlint backlog scan (non-blocking)..." -ForegroundColor Cyan
$rawOutput = @()
try {
    $rawOutput = & $preCommitExe @args 2>&1 | ForEach-Object { [string]$_ }
}
catch {
    $rawOutput += [string]$_.Exception.Message
}
$exitCode = if ($LASTEXITCODE -is [int]) { [int]$LASTEXITCODE } else { 0 }

Set-Content -Path $RawLogPath -Value $rawOutput -Encoding UTF8

$ansiRegex = [regex]"`e\[[0-9;]*m"
$cleanLines = @($rawOutput | ForEach-Object { $ansiRegex.Replace($_, "") })
$errorLines = @($cleanLines | Where-Object { $_ -match '^[^:]+:\d+(?::\d+)?\s+MD\d+' })

$byRule = @{}
$byFile = @{}
$byTopDir = @{}

foreach ($line in $errorLines) {
    if ($line -match '^(?<file>[^:]+):\d+(?::\d+)?\s+(?<rule>MD\d+)') {
        $file = [string]$matches['file']
        $rule = [string]$matches['rule']
        Add-Count -Map $byRule -Key $rule
        Add-Count -Map $byFile -Key $file
        $top = if ($file -match '^[^\\/]+[\\/]') { ($file -split '[\\/]')[0] } else { "(root)" }
        Add-Count -Map $byTopDir -Key $top
    }
}

$summary = [ordered]@{
    schema_version = "1.0"
    source_of_truth = "logs/verify/markdownlint_backlog_summary.json"
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    command = ((@($preCommitExe) + $args) -join " ")
    runner = "pre-commit"
    non_blocking = $true
    pre_commit_exit_code = $exitCode
    error_count = $errorLines.Count
    top_rules = @(
        $byRule.GetEnumerator() |
            Sort-Object `
                @{ Expression = { [int]$_.Value }; Descending = $true }, `
                @{ Expression = { [string]$_.Key }; Descending = $false } |
            Select-Object -First $TopN |
            ForEach-Object { [ordered]@{ rule = $_.Key; count = [int]$_.Value } }
    )
    top_dirs = @(
        $byTopDir.GetEnumerator() |
            Sort-Object `
                @{ Expression = { [int]$_.Value }; Descending = $true }, `
                @{ Expression = { [string]$_.Key }; Descending = $false } |
            Select-Object -First $TopN |
            ForEach-Object { [ordered]@{ dir = $_.Key; count = [int]$_.Value } }
    )
    top_files = @(
        $byFile.GetEnumerator() |
            Sort-Object `
                @{ Expression = { [int]$_.Value }; Descending = $true }, `
                @{ Expression = { [string]$_.Key }; Descending = $false } |
            Select-Object -First $TopN |
            ForEach-Object { [ordered]@{ file = $_.Key; count = [int]$_.Value } }
    )
    raw_log_path = ($RawLogPath.Substring($RootPath.Length).TrimStart('\', '/') -replace '\\', '/')
}

($summary | ConvertTo-Json -Depth 20) | Set-Content -Path $OutputJsonPath -Encoding UTF8

Write-Host "Markdownlint backlog report (non-blocking):" -ForegroundColor Cyan
Write-Host ("  pre-commit exit code: {0}" -f $exitCode) -ForegroundColor Cyan
Write-Host ("  markdownlint errors: {0}" -f $errorLines.Count) -ForegroundColor Cyan
Write-Host ("  summary json: {0}" -f ($summary.source_of_truth)) -ForegroundColor Cyan
Write-Host ("  raw log: {0}" -f ($summary.raw_log_path)) -ForegroundColor Cyan

if ($summary.top_rules.Count -gt 0) {
    Write-Host "  top rules:" -ForegroundColor Cyan
    foreach ($row in (To-Array $summary.top_rules)) {
        Write-Host ("    - {0}: {1}" -f $row.rule, $row.count) -ForegroundColor Cyan
    }
}

exit 0
