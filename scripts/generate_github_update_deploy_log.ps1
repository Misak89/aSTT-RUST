param(
    [string]$RootPath = ".",
    [string]$OutputPath = "docs/generated/control/GITHUB_UPDATE_DEPLOY_LOG.md"
)

$ErrorActionPreference = "Stop"

function Get-GitOutput {
    param([string[]]$GitArgs)
    $out = & git @GitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return "" }
    return ($out | Out-String).Trim()
}

function Parse-CommitLine {
    param([string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
    $parts = $Line -split "\|", 4
    if ($parts.Count -lt 4) { return $null }
    $dateObj = $null
    try { $dateObj = [DateTimeOffset]::Parse($parts[1]) } catch { $dateObj = $null }
    return [pscustomobject]@{
        Sha = $parts[0]
        DateRaw = $parts[1]
        Date = $dateObj
        Author = $parts[2]
        Subject = $parts[3]
    }
}

function Get-BranchCommit {
    param([string]$RefName)
    $line = Get-GitOutput -GitArgs @("log", $RefName, "-n", "1", "--date=iso-strict", "--pretty=format:%H|%ad|%an|%s")
    return (Parse-CommitLine -Line $line)
}

function Get-AgeDaysText {
    param([DateTimeOffset]$When, [DateTimeOffset]$NowUtc)
    if ($null -eq $When) { return "unknown" }
    $delta = $NowUtc - $When.ToUniversalTime()
    return ("{0:N1}" -f $delta.TotalDays)
}

function Test-WorkflowDeploySignal {
    param([string]$RepoRoot)
    $wfDir = Join-Path $RepoRoot ".github/workflows"
    if (-not (Test-Path $wfDir)) { return $false }
    $hits = Get-ChildItem -Path $wfDir -File | ForEach-Object {
        Select-String -Path $_.FullName -Pattern "deploy-pages|upload-pages-artifact|gh-pages|mkdocs gh-deploy|pages" -SimpleMatch -ErrorAction SilentlyContinue
    }
    return ($hits | Measure-Object).Count -gt 0
}

$repoRoot = (Resolve-Path $RootPath).Path
$nowUtc = [DateTimeOffset]::UtcNow

$currentBranch = Get-GitOutput -GitArgs @("branch", "--show-current")
$masterCommit = Get-BranchCommit -RefName "origin/master"
$verifyCommit = Get-BranchCommit -RefName "origin/test/verify-danger"

$aheadBehind = ""
if (-not [string]::IsNullOrWhiteSpace($currentBranch)) {
    $abRaw = Get-GitOutput -GitArgs @("rev-list", "--left-right", "--count", "origin/$currentBranch...$currentBranch")
    if (-not [string]::IsNullOrWhiteSpace($abRaw)) {
        $abParts = $abRaw -split "\s+"
        if ($abParts.Count -ge 2) {
            $aheadBehind = "behind=$($abParts[0]), ahead=$($abParts[1])"
        }
    }
}

$masterAge = if ($masterCommit) { [double](Get-AgeDaysText -When $masterCommit.Date -NowUtc $nowUtc) } else { 9999.0 }
$verifyAge = if ($verifyCommit) { [double](Get-AgeDaysText -When $verifyCommit.Date -NowUtc $nowUtc) } else { 9999.0 }
$isOlderThanWeek = (($masterAge -gt 7.0) -or ($verifyAge -gt 7.0))
$hasDeploySignal = Test-WorkflowDeploySignal -RepoRoot $repoRoot

$conclusion = if ($isOlderThanWeek) {
    "ZAVER: posledni update na GitHub je starsi nez 7 dni -> stav je STALE a v dokumentaci chybi primo log GitHub update/deploy."
} else {
    "ZAVER: posledni update na GitHub je v poslednich 7 dnech."
}

$deployLine = if ($hasDeploySignal) {
    "Deploy workflow signal: nalezen (obsahuje pages/deploy klicova slova)."
} else {
    "Deploy workflow signal: nenalezen."
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# GitHub Update+Deploy Log (Generated)")
$lines.Add("")
$lines.Add("- Generated at (UTC): " + $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ"))
$lines.Add('- Repo root: `' + ($repoRoot -replace '\\', '/') + '`')
$lines.Add('- GitHub update/deploy log page existed before: `NO`')
$lines.Add("")
$lines.Add("## Last Remote Updates")
$lines.Add("")
$lines.Add("| Remote branch | Last commit UTC | Age (days) | Author | Commit | Subject |")
$lines.Add("| :--- | :--- | ---: | :--- | :--- | :--- |")
if ($masterCommit) {
    $shaShort = $masterCommit.Sha.Substring(0, 12)
    $lines.Add('| origin/master | ' + $masterCommit.Date.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") + ' | ' + (Get-AgeDaysText -When $masterCommit.Date -NowUtc $nowUtc) + ' | ' + $masterCommit.Author + ' | `' + $shaShort + '` | ' + $masterCommit.Subject + ' |')
} else {
    $lines.Add("| origin/master | - | - | - | - | - |")
}
if ($verifyCommit) {
    $shaShort = $verifyCommit.Sha.Substring(0, 12)
    $lines.Add('| origin/test/verify-danger | ' + $verifyCommit.Date.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") + ' | ' + (Get-AgeDaysText -When $verifyCommit.Date -NowUtc $nowUtc) + ' | ' + $verifyCommit.Author + ' | `' + $shaShort + '` | ' + $verifyCommit.Subject + ' |')
} else {
    $lines.Add("| origin/test/verify-danger | - | - | - | - | - |")
}
$lines.Add("")
$lines.Add("## Local Branch Sync")
$lines.Add("")
$lines.Add('- Current local branch: `' + $currentBranch + '`')
if (-not [string]::IsNullOrWhiteSpace($aheadBehind)) {
    $lines.Add('- Sync vs origin/' + $currentBranch + ': `' + $aheadBehind + '`')
}
$lines.Add("")
$lines.Add("## Deploy Signal")
$lines.Add("")
$lines.Add("- " + $deployLine)
$lines.Add("")
$lines.Add("## Analysis")
$lines.Add("")
$lines.Add("- " + $conclusion)
if ($isOlderThanWeek) {
    $lines.Add("- Doporuceni: pushnout lokalni dokumentacni commity na GitHub a nasledne sledovat Actions/Commits.")
}

$content = ($lines -join "`n") + "`n"
$target = Join-Path $repoRoot $OutputPath
$parent = Split-Path -Path $target -Parent
if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
[System.IO.File]::WriteAllText($target, $content, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "WROTE: $OutputPath" -ForegroundColor Green
