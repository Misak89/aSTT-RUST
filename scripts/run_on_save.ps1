# run_on_save.ps1
# Minimal, fast Run-on-Save updater for single .md file
# Version: 1.1
# Updated: 2026-02-19 00:00 (UTC+1)

param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
)

$ErrorActionPreference = "Stop"

# Always anchor paths to repo root, not current shell location
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$logPath = Join-Path $root "logs\runonsave.log"
$dateOnly = Get-Date -Format "yyyy-MM-dd"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $line = "$timestamp $Message"
    if (Test-Path $logPath) {
        Add-Content -Path $logPath -Value $line
        $lines = Get-Content -Path $logPath
        if ($lines.Count -gt 200) {
            $lines | Select-Object -Last 200 | Set-Content -Path $logPath
        }
    }
    else {
        $dir = Split-Path $logPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-Content -Path $logPath -Value $line
    }
}

function Get-LastLoggedVersion {
    param([string]$TargetPath)

    if (-not (Test-Path $logPath)) { return $null }

    $escaped = [regex]::Escape($TargetPath)
    $line = Get-Content -Path $logPath | Select-String -Pattern "UPDATED\s+$escaped\s+v(\d+\.\d+)" | Select-Object -Last 1
    if (-not $line) { return $null }
    $m = [regex]::Match($line.Line, "v(\d+\.\d+)")
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

if (-not (Test-Path $FilePath)) {
    Write-Log "SKIP not_found $FilePath"
    exit 0
}

$fullPath = (Resolve-Path $FilePath).Path

# 1. Determine Category
$category = "Prostředí"
$projectPaths = @("src-tauri", "src-ui", "src-python")
foreach ($pp in $projectPaths) {
    if ($fullPath -like "*\$pp\*") {
        $category = "Projekt"
        break
    }
}

# 2. Exclude non-relevant paths
$exclude = @("node_modules", ".git", "target", ".specify", ".agent", ".kilocode", ".venv", "logs", "site")
foreach ($ex in $exclude) {
    if ($fullPath -like "*\$ex\*") { exit 0 }
}

# 3. MD Metadata Update (only for markdown files with metadata)
$isMd = $fullPath.EndsWith(".md")
if ($isMd) {
    $content = Get-Content $fullPath -Raw -Encoding UTF8
    if ($content -match "\*\*Cesta:\*\*") {
        # Parse current file version
        $currentVersion = "0.0"
        if ($content -match "\*\*Verze:\*\*\s*(\d+)\.(\d+)") {
            $currentVersion = "$($Matches[1]).$($Matches[2])"
        }

        # Parse last logged version for this exact file and prevent version rollback
        $lastVersion = Get-LastLoggedVersion -TargetPath $fullPath
        $baseVersion = $currentVersion
        if ($lastVersion) {
            $curr = [version]($currentVersion + ".0")
            $last = [version]($lastVersion + ".0")
            if ($last -gt $curr) {
                $baseVersion = $lastVersion
            }
        }

        if ($baseVersion -match "^(\d+)\.(\d+)$") {
            $majorVersion = [int]$Matches[1]
            $minorVersion = [int]$Matches[2] + 1
            $newVersion = "$majorVersion.$minorVersion"
        }
        else {
            $newVersion = "1.1"
        }

        $timestampNow = Get-Date -Format "yyyy-MM-dd HH:mm"
        $content = $content -replace "(\*\*Verze:\*\*\s*)\d+\.\d+", "`${1}$newVersion"
        $content = $content -replace "(\*\*Posledni zmena:\*\*\s*)\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2})?(?: \(UTC\+\d\))?", "`${1}$timestampNow (UTC+1)"

        $historyEntry = "| $dateOnly | $newVersion | Run on Save |"
        if ($content -match "##\s*Historie zmen") {
            $content = $content -replace "(\|\s*Datum\s*\|\s*Verze\s*\|\s*Popis zmeny\s*\|\r?\n\|-+\|\-+\|\-+\|\r?\n)", "`$1$historyEntry`n"
        }

        $content | Out-File $fullPath -Encoding UTF8 -NoNewline
        Write-Log "UPDATED $fullPath v$newVersion ($category)"
    }
    else {
        Write-Log "MODIFIED $fullPath ($category)"
    }
}
else {
    Write-Log "MODIFIED $fullPath ($category)"
}

# 4. Global Audit Update (Call update_docs.ps1)
$fileName = Split-Path $fullPath -Leaf
& "pwsh" -NoProfile -ExecutionPolicy Bypass -File "$root\scripts\update_docs.ps1" -Reason "Změna souboru" -Feature $fileName -DocFile $fullPath -Category $category

