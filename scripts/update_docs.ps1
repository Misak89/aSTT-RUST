# scripts/update_docs.ps1
# MACHINE-OPERATED CONTROLLER (ISATM-Aware)
# Version: 3.2
# Last Updated: 2026-02-26

param (
    [string]$Reason = "Automatická údržba",
    [string]$Feature = "System",
    [string]$CodeFile = "N/A",
    [string]$DocFile = "QA_REPORT.md",
    [string]$Category = "Prostředí",
    [string]$EventTimestamp = "",
    [switch]$SkipPreflightWriteGuard,
    [int]$PreflightGuardMaxAgeMinutes = 120
)

$ErrorActionPreference = "Stop"

$root = "$PSScriptRoot\.."
$reportFile = "$root\QA_REPORT.md"
$auditFile = "$root\docs\core\AUDIT_TRAIL_Log_dashboard.md"
$projectFile = "$root\project.json"

if (-not $SkipPreflightWriteGuard.IsPresent) {
    $preflightGuardScript = Join-Path $root "scripts\assert_preflight_write_guard.ps1"
    & $preflightGuardScript -RootPath $root -MaxAgeMinutes $PreflightGuardMaxAgeMinutes -OperationName "update_docs"
    if ($LASTEXITCODE -ne 0) {
        throw "Preflight write guard failed for update_docs (exit=$LASTEXITCODE)."
    }
}

Write-Host "--- [ISATM CONTROLLER START] ---"
$timestamp = if ($EventTimestamp) { $EventTimestamp } else { Get-Date -Format "yyyy-MM-dd HH:mm" }
$timezone = [System.TimeZoneInfo]::Local.DisplayName

function Normalize-RepoRelativePath {
    param(
        [string]$PathInput,
        [string]$RepoRoot
    )

    if (-not $PathInput) { return $null }
    if ($PathInput -eq "N/A") { return "N/A" }

    $candidate = $PathInput
    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $candidate = Join-Path $RepoRoot $candidate
    }

    try {
        $resolved = (Resolve-Path $candidate -ErrorAction Stop).Path
    }
    catch {
        $leaf = [System.IO.Path]::GetFileName($PathInput)
        $repoResolvedCatch = (Resolve-Path $RepoRoot).Path
        $coreCandidate = Join-Path $RepoRoot ("docs\core\" + $leaf)
        if ($leaf -and (Test-Path $coreCandidate)) {
            $coreResolved = (Resolve-Path $coreCandidate).Path
            if ($coreResolved.StartsWith($repoResolvedCatch, [System.StringComparison]::OrdinalIgnoreCase)) {
                return (($coreResolved.Substring($repoResolvedCatch.Length).TrimStart("\", "/")) -replace "\\", "/")
            }
            return ($coreResolved -replace "\\", "/")
        }

        $rootLeaf = Join-Path $RepoRoot $leaf
        if ($leaf -and (Test-Path $rootLeaf)) {
            $rootResolved = (Resolve-Path $rootLeaf).Path
            if ($rootResolved.StartsWith($repoResolvedCatch, [System.StringComparison]::OrdinalIgnoreCase)) {
                return (($rootResolved.Substring($repoResolvedCatch.Length).TrimStart("\", "/")) -replace "\\", "/")
            }
            return ($rootResolved -replace "\\", "/")
        }

        return ($PathInput -replace "\\", "/")
    }

    $repoResolved = (Resolve-Path $RepoRoot).Path
    if ($resolved.StartsWith($repoResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $resolved.Substring($repoResolved.Length).TrimStart("\", "/")
        return ($relative -replace "\\", "/")
    }

    return ($resolved -replace "\\", "/")
}

function To-AuditRelativeLink {
    param(
        [string]$RepoRelativePath
    )

    if (-not $RepoRelativePath -or $RepoRelativePath -eq "N/A") {
        return "N/A"
    }

    $normalized = ($RepoRelativePath -replace "\\", "/")
    switch -Regex ($normalized) {
        '^(docs/core/)?NEXT_SESSION\.md$' {
            $normalized = "docs/generated/control/NEXT_SESSION.md"
            break
        }
    }

    $auditDir = Join-Path $root "docs\core"
    $docsRoot = (Resolve-Path (Join-Path $root "docs")).Path
    $targetAbs = Join-Path $root ($normalized -replace "/", "\")
    if (-not (Test-Path $targetAbs)) {
        return "``$normalized``"
    }

    $resolvedTarget = (Resolve-Path $targetAbs).Path
    if (-not $resolvedTarget.StartsWith($docsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return "``$normalized``"
    }

    $uriAudit = [System.Uri]::new((Resolve-Path $auditDir).Path + [System.IO.Path]::DirectorySeparatorChar)
    $uriTarget = [System.Uri]::new($resolvedTarget)
    $relative = $uriAudit.MakeRelativeUri($uriTarget).ToString()
    return "[$([System.IO.Path]::GetFileName($normalized))]($relative)"
}

# 1. Integrity Watchdog
Write-Host "Monitoring Path Integrity..."
$criticalPaths = @(
    "$root\docs\core\ARCHITECTURE.md",
    "$root\docs\core\GOVERNANCE.md",
    "$root\docs\core\ORGANIZATION.md",
    $auditFile
)

$missingPaths = @()
foreach ($path in $criticalPaths) {
    if (-not (Test-Path $path)) { $missingPaths += $path }
}

if ($missingPaths.Count -gt 0) {
    Write-Host "WARNING: Missing paths:" -ForegroundColor Yellow
    $missingPaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}
else {
    Write-Host "Integrity: OK" -ForegroundColor Green
}

# 2. System Analysis (Simplified for Log)
$health = @{
    Rust = if (Get-Command rustc -ErrorAction SilentlyContinue) { "OK" } else { "MISSING" }
}

# 3. Documentation Metrics
$docMetrics = @{
    TotalMDFiles = (Get-ChildItem -Path $root -Filter "*.md" -Recurse | Where-Object { $_.FullName -notmatch "node_modules|target|.git" }).Count
    TotalScripts = (Get-ChildItem -Path "$root\scripts" -Filter "*.ps1" -ErrorAction SilentlyContinue).Count
}

# 4. Update AUDIT_TRAIL_Log_dashboard.md (ISATM)
if (Test-Path $auditFile) {
    Write-Host "Updating ISATM Audit Trail..."
    $auditContent = Get-Content $auditFile -Raw
    
    # Pre-process links for MkDocs
    $normalizedCode = Normalize-RepoRelativePath -PathInput $CodeFile -RepoRoot $root
    $normalizedDoc = Normalize-RepoRelativePath -PathInput $DocFile -RepoRoot $root

    $codeLink = if ($normalizedCode -ne "N/A") {
        "``$normalizedCode``"
    }
    else { "N/A" }

    $docLink = To-AuditRelativeLink -RepoRelativePath $normalizedDoc
    
    $statusEmoji = if ($health.Rust -eq "OK") { "✅" } else { "⚠️" }
    $newRow = "| $timestamp | $Category | $Feature | $Reason | $codeLink | $docLink | $statusEmoji | ``logs/runonsave.log`` | "
    
    # Insert at top of rows (immediately after ROW_START line)
    $lines = $auditContent -split "`r?`n"
    $rowStartIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "ROW_START") {
            $rowStartIndex = $i
            break
        }
    }

    if ($rowStartIndex -ge 0) {
        $newLines = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $newLines.Add($lines[$i])
            if ($i -eq $rowStartIndex) {
                $newLines.Add($newRow)
            }
        }
        ($newLines -join "`r`n") | Out-File $auditFile -Encoding utf8
    }
    else {
        Write-Host "WARNING: ROW_START marker not found in dashboard." -ForegroundColor Yellow
    }
}

# 5. Update QA_REPORT.md (Legacy Support)
if (Test-Path $reportFile) {
    $content = Get-Content $reportFile -Raw
    $content = $content -replace "Last Updated:.*", "Last Updated: $timestamp ($timezone)"
    $content | Out-File $reportFile -Encoding utf8
}

Write-Host "`n--- [ISATM DONE] ---" -ForegroundColor Cyan
