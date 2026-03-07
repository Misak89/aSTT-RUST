param(
    [string]$RootPath = "",
    [string]$ValeExePath = "",
    [string]$ValeConfigPath = "",
    [string]$BaselinePath = "",
    [string]$OutputJsonPath = "",
    [string]$RawJsonPath = "",
    [int]$TopN = 15,
    [switch]$EnforceNoRegression,
    [switch]$UpdateBaseline
)

$ErrorActionPreference = "Stop"

if (-not $RootPath) {
    $RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
    $RootPath = (Resolve-Path $RootPath).Path
}

if (-not $ValeExePath) {
    $ValeExePath = Join-Path $RootPath "tools\vale\vale.exe"
    if (-not (Test-Path $ValeExePath)) {
        $cmd = Get-Command vale -ErrorAction SilentlyContinue
        if ($null -ne $cmd) {
            $ValeExePath = $cmd.Source
        }
    }
}
if (-not $ValeConfigPath) {
    $ValeConfigPath = Join-Path $RootPath ".vale.backlog.ini"
}
if (-not $BaselinePath) {
    $BaselinePath = Join-Path $RootPath "docs_control\vale_backlog_baseline.json"
}
if (-not $OutputJsonPath) {
    $OutputJsonPath = Join-Path $RootPath "logs\verify\vale_backlog_summary.json"
}
if (-not $RawJsonPath) {
    $RawJsonPath = Join-Path $RootPath "logs\verify\vale_backlog_latest.json"
}

function Add-Count {
    param(
        [hashtable]$Map,
        [string]$Key
    )
    if (-not $Map.ContainsKey($Key)) { $Map[$Key] = 0 }
    $Map[$Key] = [int]$Map[$Key] + 1
}

function To-Array {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable]) { return @($Value) }
    return @($Value)
}

function Normalize-RepoRelativePath {
    param(
        [string]$PathValue,
        [string]$RepoRoot
    )
    if (-not $PathValue) { return "" }
    $normalized = ($PathValue -replace "\\", "/")
    try {
        $candidate = $PathValue
        if (-not ([System.IO.Path]::IsPathRooted($candidate))) {
            $candidate = Join-Path $RepoRoot $candidate
        }
        $resolved = (Resolve-Path $candidate -ErrorAction Stop).Path
        $repoResolved = (Resolve-Path $RepoRoot -ErrorAction Stop).Path
        if ($resolved.StartsWith($repoResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
            return ($resolved.Substring($repoResolved.Length).TrimStart('\', '/') -replace "\\", "/")
        }
        return ($resolved -replace "\\", "/")
    }
    catch {
        return $normalized
    }
}

function Get-TopDir {
    param([string]$RepoRelativePath)
    if ($RepoRelativePath -match '^[^/]+/') {
        return (($RepoRelativePath -split '/')[0])
    }
    return "(root)"
}

function Should-IgnorePath {
    param([string]$RepoRelativePath)
    $p = ($RepoRelativePath -replace "\\", "/")
    foreach ($pattern in @(
            '^site/',
            '^backup_docs_[^/]+/',
            '^NEXT_SESSION_Archive/',
            '^src-tauri/binaries/build/',
            '^tools/vale/',
            '^\.venv/'
        )) {
        if ($p -match $pattern) { return $true }
    }
    return $false
}

if (-not (Test-Path $ValeExePath)) {
    $msg = "Vale executable not found: $ValeExePath"
    if ($EnforceNoRegression) {
        Write-Host $msg -ForegroundColor Red
        exit 1
    }
    Write-Host "$msg (skipping Vale backlog report)." -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path $ValeConfigPath)) {
    $msg = "Vale backlog config not found: $ValeConfigPath"
    if ($EnforceNoRegression) {
        Write-Host $msg -ForegroundColor Red
        exit 1
    }
    Write-Host "$msg (skipping Vale backlog report)." -ForegroundColor Yellow
    exit 0
}

New-Item -ItemType Directory -Path (Split-Path $OutputJsonPath -Parent) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $RawJsonPath -Parent) -Force | Out-Null

$args = @(
    "--output=JSON",
    "--config=$ValeConfigPath",
    "."
)

Write-Host "Running Vale backlog scan (repo-wide, non-blocking report)..." -ForegroundColor Cyan

$stderrPath = [System.IO.Path]::GetTempFileName()
$rawJson = ""
try {
    $rawJson = (& $ValeExePath @args 2> $stderrPath | Out-String)
}
finally {
    $valeExitCode = if ($LASTEXITCODE -is [int]) { [int]$LASTEXITCODE } else { 0 }
}
$stderrLines = if (Test-Path $stderrPath) { @(Get-Content $stderrPath -Encoding UTF8) } else { @() }
Remove-Item $stderrPath -ErrorAction SilentlyContinue

if ([string]::IsNullOrWhiteSpace($rawJson)) {
    $rawJson = "{}"
}

Set-Content -Path $RawJsonPath -Value $rawJson -Encoding UTF8

$parsed = $null
try {
    $parsed = $rawJson | ConvertFrom-Json -Depth 100
}
catch {
    Write-Host "Vale backlog report parse failed (invalid JSON output)." -ForegroundColor Red
    if ($stderrLines.Count -gt 0) {
        foreach ($line in $stderrLines) {
            Write-Host $line -ForegroundColor Yellow
        }
    }
    if ($EnforceNoRegression) { exit 1 }
    exit 0
}

$countsBySeverity = @{ error = 0; warning = 0; suggestion = 0 }
$byRule = @{}
$byFile = @{}
$byTopDir = @{}
$bySeverity = @{}
$totalAlerts = 0

foreach ($prop in @($parsed.PSObject.Properties)) {
    $filePath = Normalize-RepoRelativePath -PathValue ([string]$prop.Name) -RepoRoot $RootPath
    if (Should-IgnorePath -RepoRelativePath $filePath) {
        continue
    }
    foreach ($alert in (To-Array $prop.Value)) {
        if ($null -eq $alert) { continue }
        $severity = [string]$alert.Severity
        if ([string]::IsNullOrWhiteSpace($severity)) { $severity = "unknown" }
        $severity = $severity.ToLowerInvariant()
        if (-not $countsBySeverity.ContainsKey($severity)) {
            $countsBySeverity[$severity] = 0
        }
        $countsBySeverity[$severity] = [int]$countsBySeverity[$severity] + 1
        Add-Count -Map $bySeverity -Key $severity
        Add-Count -Map $byRule -Key ([string]$alert.Check)
        Add-Count -Map $byFile -Key $filePath
        Add-Count -Map $byTopDir -Key (Get-TopDir -RepoRelativePath $filePath)
        $totalAlerts++
    }
}

$summary = [ordered]@{
    schema_version = "1.0"
    source_of_truth = "logs/verify/vale_backlog_summary.json"
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    command = ((@($ValeExePath) + $args) -join " ")
    runner = "vale"
    config_path = (Normalize-RepoRelativePath -PathValue $ValeConfigPath -RepoRoot $RootPath)
    scope = "repo-wide markdown backlog (non-blocking report)"
    non_blocking_report = $true
    vale_exit_code = $valeExitCode
    total_alerts = [int]$totalAlerts
    error_count = [int]$countsBySeverity['error']
    warning_count = [int]$countsBySeverity['warning']
    suggestion_count = [int]$countsBySeverity['suggestion']
    top_severities = @(
        $bySeverity.GetEnumerator() |
            Sort-Object @{ Expression = { [int]$_.Value }; Descending = $true }, @{ Expression = { [string]$_.Key }; Descending = $false } |
            Select-Object -First $TopN |
            ForEach-Object { [ordered]@{ severity = $_.Key; count = [int]$_.Value } }
    )
    top_rules = @(
        $byRule.GetEnumerator() |
            Sort-Object @{ Expression = { [int]$_.Value }; Descending = $true }, @{ Expression = { [string]$_.Key }; Descending = $false } |
            Select-Object -First $TopN |
            ForEach-Object { [ordered]@{ rule = $_.Key; count = [int]$_.Value } }
    )
    top_dirs = @(
        $byTopDir.GetEnumerator() |
            Sort-Object @{ Expression = { [int]$_.Value }; Descending = $true }, @{ Expression = { [string]$_.Key }; Descending = $false } |
            Select-Object -First $TopN |
            ForEach-Object { [ordered]@{ dir = $_.Key; count = [int]$_.Value } }
    )
    top_files = @(
        $byFile.GetEnumerator() |
            Sort-Object @{ Expression = { [int]$_.Value }; Descending = $true }, @{ Expression = { [string]$_.Key }; Descending = $false } |
            Select-Object -First $TopN |
            ForEach-Object { [ordered]@{ file = $_.Key; count = [int]$_.Value } }
    )
    raw_json_path = (Normalize-RepoRelativePath -PathValue $RawJsonPath -RepoRoot $RootPath)
}

$regressionDetected = $false
$regressionMessages = New-Object System.Collections.Generic.List[string]

if ((Test-Path $BaselinePath) -and ($EnforceNoRegression -or $UpdateBaseline)) {
    try {
        $baseline = Get-Content -Path $BaselinePath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 50
    }
    catch {
        $baseline = $null
        if ($EnforceNoRegression) {
            $regressionMessages.Add("Failed to parse baseline JSON: $BaselinePath")
            $regressionDetected = $true
        }
    }

    if ($null -ne $baseline) {
        $baselineError = [int]($baseline.error_count)
        $baselineWarning = [int]($baseline.warning_count)
        $baselineSuggestion = [int]($baseline.suggestion_count)
        $baselineTotal = [int]($baseline.total_alerts)
        $summary["baseline_path"] = (Normalize-RepoRelativePath -PathValue $BaselinePath -RepoRoot $RootPath)
        $summary["baseline"] = [ordered]@{
            total_alerts = $baselineTotal
            error_count = $baselineError
            warning_count = $baselineWarning
            suggestion_count = $baselineSuggestion
        }
        $summary["delta"] = [ordered]@{
            total_alerts = ([int]$summary.total_alerts - $baselineTotal)
            error_count = ([int]$summary.error_count - $baselineError)
            warning_count = ([int]$summary.warning_count - $baselineWarning)
            suggestion_count = ([int]$summary.suggestion_count - $baselineSuggestion)
        }

        foreach ($check in @(
                @{ Name = "error_count"; Current = [int]$summary.error_count; Baseline = $baselineError },
                @{ Name = "warning_count"; Current = [int]$summary.warning_count; Baseline = $baselineWarning },
                @{ Name = "suggestion_count"; Current = [int]$summary.suggestion_count; Baseline = $baselineSuggestion },
                @{ Name = "total_alerts"; Current = [int]$summary.total_alerts; Baseline = $baselineTotal }
            )) {
            if ($check.Current -gt $check.Baseline) {
                $regressionDetected = $true
                $regressionMessages.Add(("{0} regressed: baseline={1}, current={2}" -f $check.Name, $check.Baseline, $check.Current))
            }
        }
    }
}
elseif ($EnforceNoRegression) {
    $regressionDetected = $true
    $regressionMessages.Add("Vale backlog baseline not found: $BaselinePath")
}

$summary["no_regression_enforced"] = [bool]$EnforceNoRegression.IsPresent
$summary["regression_detected"] = [bool]$regressionDetected
$summary["regression_messages"] = @($regressionMessages)

($summary | ConvertTo-Json -Depth 50) | Set-Content -Path $OutputJsonPath -Encoding UTF8

if ($UpdateBaseline) {
    $baselineDoc = [ordered]@{
        schema_version = "1.0"
        source_of_truth = "docs_control/vale_backlog_baseline.json"
        generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        source_summary_path = (Normalize-RepoRelativePath -PathValue $OutputJsonPath -RepoRoot $RootPath)
        config_path = (Normalize-RepoRelativePath -PathValue $ValeConfigPath -RepoRoot $RootPath)
        total_alerts = [int]$summary.total_alerts
        error_count = [int]$summary.error_count
        warning_count = [int]$summary.warning_count
        suggestion_count = [int]$summary.suggestion_count
        top_rules = $summary.top_rules
        top_files = $summary.top_files
        top_dirs = $summary.top_dirs
    }
    ($baselineDoc | ConvertTo-Json -Depth 50) | Set-Content -Path $BaselinePath -Encoding UTF8
    Write-Host ("Vale backlog baseline updated: {0}" -f (Normalize-RepoRelativePath -PathValue $BaselinePath -RepoRoot $RootPath)) -ForegroundColor Cyan
}

Write-Host "Vale backlog report:" -ForegroundColor Cyan
Write-Host ("  total alerts: {0}" -f $summary.total_alerts) -ForegroundColor Cyan
Write-Host ("  errors: {0}, warnings: {1}, suggestions: {2}" -f $summary.error_count, $summary.warning_count, $summary.suggestion_count) -ForegroundColor Cyan
Write-Host ("  summary json: {0}" -f $summary.source_of_truth) -ForegroundColor Cyan
Write-Host ("  raw json: {0}" -f $summary.raw_json_path) -ForegroundColor Cyan

if ($EnforceNoRegression) {
    if ($regressionDetected) {
        Write-Host "  no-regression: FAIL" -ForegroundColor Red
        foreach ($msg in $regressionMessages) {
            Write-Host ("    - {0}" -f $msg) -ForegroundColor Yellow
        }
        exit 1
    }
    Write-Host "  no-regression: PASS" -ForegroundColor Green
}

exit 0
