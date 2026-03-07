# scripts/backfill_audit.ps1
# Rebuild dashboard entries from runonsave logs (last N days)

param(
    [int]$DaysBack = 10,
    [switch]$ArchiveAndClean = $true
)

$ErrorActionPreference = "Stop"

$root = "$PSScriptRoot\.."
$logPath = "$root\logs\runonsave.log"
$auditFile = "$root\docs\core\AUDIT_TRAIL_Log_dashboard.md"
$archiveDir = "$root\logs\archive"

if (-not (Test-Path $logPath)) { Write-Error "runonsave.log not found"; exit 1 }
if (-not (Test-Path $auditFile)) { Write-Error "AUDIT_TRAIL_Log_dashboard.md not found"; exit 1 }

if ($ArchiveAndClean) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    $stamp = Get-Date -Format "yyyy-MM-dd--HH-mm"
    $archivePath = Join-Path $archiveDir "AUDIT_TRAIL_Log_dashboard-before-clean-$stamp.md"
    Copy-Item $auditFile $archivePath -Force

    $full = Get-Content $auditFile -Raw -Encoding UTF8
    $lines = $full -split "`r?`n"
    $kept = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -match "^\|\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\s+\|") {
            continue
        }
        $kept.Add($line)
    }

    $cleaned = ($kept -join "`r`n")
    $cleaned | Out-File $auditFile -Encoding UTF8
    Write-Host "Archived old dashboard to: $archivePath"
    Write-Host "Cleared existing matrix rows."
}

$startDate = (Get-Date).AddDays(-$DaysBack)
$logs = Get-Content $logPath -Encoding UTF8

function Normalize-Category {
    param([string]$Value)
    if (-not $Value) { return "Prostredi" }
    if ($Value -match "Projekt") { return "Projekt" }
    if ($Value -match "Prost") { return "Prostredi" }
    return $Value
}

foreach ($line in $logs) {
    if ($line -match "^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})\s+UPDATED\s+(.*?)\s+v([\d\.]+)(?:\s+\((.*?)\))?$") {
        $ts = [datetime]::ParseExact($Matches[1], "yyyy-MM-dd HH:mm", [System.Globalization.CultureInfo]::InvariantCulture)
        if ($ts -lt $startDate) { continue }

        $timestamp = $Matches[1]
        $file = $Matches[2].Trim()
        $fileName = Split-Path $file -Leaf
        $rawCategory = if ($Matches[4]) { $Matches[4].Trim() } else { "Prostredi" }
        $category = Normalize-Category $rawCategory

        & "pwsh" -NoProfile -ExecutionPolicy Bypass -File "$root\scripts\update_docs.ps1" `
            -Reason "Historicky import" `
            -Feature $fileName `
            -DocFile $file `
            -Category $category `
            -EventTimestamp $timestamp
        continue
    }

    if ($line -match "^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})\s+MODIFIED\s+(.*?)(?:\s+\((.*?)\))?$") {
        $ts = [datetime]::ParseExact($Matches[1], "yyyy-MM-dd HH:mm", [System.Globalization.CultureInfo]::InvariantCulture)
        if ($ts -lt $startDate) { continue }

        $timestamp = $Matches[1]
        $file = $Matches[2].Trim()
        $fileName = Split-Path $file -Leaf
        $rawCategory = if ($Matches[3]) { $Matches[3].Trim() } else { "Prostredi" }
        $category = Normalize-Category $rawCategory

        & "pwsh" -NoProfile -ExecutionPolicy Bypass -File "$root\scripts\update_docs.ps1" `
            -Reason "Historicky import" `
            -Feature $fileName `
            -DocFile $file `
            -Category $category `
            -EventTimestamp $timestamp
    }
}

Write-Host "Backfill completed for last $DaysBack days."
