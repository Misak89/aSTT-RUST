# scripts/update_docs.ps1
# MACHINE-OPERATED CONTROLLER (Track-Aware)
# Version: 2.0
# Last Updated: 2026-02-14

$ErrorActionPreference = "Stop"

$root = "$PSScriptRoot\.."
$reportFile = "$root\QA_REPORT.md"
$projectFile = "$root\project.json"

Write-Host "--- [AUTONOMOUS CONTROLLER START] ---"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$timezone = [System.TimeZoneInfo]::Local.DisplayName -replace '.*?\((.+)\)', '$1'

# 1. Integrity Watchdog (Machine Readability & Path Verification)
Write-Host "Monitoring Path Integrity..."
$criticalPaths = @(
    "$root\.specify\spec.md",
    "$root\.specify\plan.md",
    "$root\project.json",
    "$root\ARCHITECTURE.md",
    "$root\GOVERNANCE.md",
    "$root\ORGANIZATION.md"
)

$missingPaths = @()
foreach ($path in $criticalPaths) {
    if (-not (Test-Path $path)) {
        $missingPaths += $path
    }
}

if ($missingPaths.Count -gt 0) {
    Write-Host "WARNING: Missing paths:" -ForegroundColor Yellow
    $missingPaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
} else {
    Write-Host "Integrity: OK" -ForegroundColor Green
}

# 2. System Analysis (Multi-Track)
$health = @{
    Rust          = if (Get-Command rustc -ErrorAction SilentlyContinue) { "OK" } else { "MISSING" }
    Node          = if (Get-Command node -ErrorAction SilentlyContinue) { "OK" } else { "MISSING" }
    SandBoxPython = if (Test-Path "$root\sandbox\portable_bench\python-embed\python.exe") { "OK" } else { "MISSING" }
    DevPython     = if (Test-Path "$root\.venv\Scripts\python.exe") { "OK" } else { "MISSING" }
    Git           = if (Get-Command git -ErrorAction SilentlyContinue) { "OK" } else { "MISSING" }
}

# 3. Duplicate Check Metrics
Write-Host "Checking documentation metrics..."
$docMetrics = @{
    TotalMDFiles = (Get-ChildItem -Path $root -Filter "*.md" -Recurse | Where-Object { $_.FullName -notmatch "node_modules|target|.git" }).Count
    TotalScripts = (Get-ChildItem -Path "$root\scripts" -Filter "*.ps1" -ErrorAction SilentlyContinue).Count
    TotalWorkflows = (Get-ChildItem -Path "$root\.github\workflows" -Filter "*.yml" -ErrorAction SilentlyContinue).Count
}

# 4. Rust Test Status (if available)
$rustTestStatus = "N/A"
if ($health.Rust -eq "OK") {
    Write-Host "Checking Rust tests..."
    try {
        Push-Location "$root\src-tauri"
        $rustOutput = & cargo test --no-run 2>&1
        if ($LASTEXITCODE -eq 0) {
            $rustTestStatus = "READY"
        } else {
            $rustTestStatus = "ERROR"
        }
        Pop-Location
    } catch {
        $rustTestStatus = "ERROR"
    }
}

# 5. Track Status Determination
$track1Status = if ($health.Rust -eq "OK" -and $health.Node -eq "OK") { "READY" } else { "BLOCKED" }
$track2Status = if ($health.SandBoxPython -eq "OK") { "READY" } else { "INITIALIZING" }

# 6. Generate Dashboard Section
$dashboardSection = @"
## Documentation Metrics (Auto-Generated)

| Metric | Value |
| :--- | :--- |
| **MD Files** | $($docMetrics.TotalMDFiles) |
| **Scripts** | $($docMetrics.TotalScripts) |
| **Workflows** | $($docMetrics.TotalWorkflows) |
| **Rust Tests** | $rustTestStatus |

---

## System Health (Agent-Monitored)

| Component | Track | Status |
| :--- | :--- | :--- |
| **Backend (Rust)** | Main | $($health.Rust) |
| **Frontend (Node)** | Main | $($health.Node) |
| **STT Sandbox (Python)** | Sandbox | $($health.SandBoxPython) |
| **Dev Environment** | Shared | $($health.DevPython) |
| **Git** | Shared | $($health.Git) |
"@

# 7. Update QA_REPORT.md
if (Test-Path $reportFile) {
    $content = Get-Content $reportFile -Raw
    
    # Update timestamp
    $content = $content -replace "Last Updated:.*", "Last Updated: $timestamp ($timezone)"
    
    # Replace or add dashboard section
    if ($content -match "## Documentation Metrics") {
        $content = $content -replace "(?s)(## Documentation Metrics.*?)(?=\n## )", "$dashboardSection`n`n"
    } else {
        # Add before first ## heading after the header
        $content = $content -replace "(---\n)", "`$1$dashboardSection`n`n---`n"
    }
    
    $content | Out-File $reportFile -Encoding utf8
    Write-Host "QA_REPORT.md updated" -ForegroundColor Green
}

Write-Host "`n--- [CONTROLLER DONE] ---" -ForegroundColor Cyan
Write-Host "Track 1 (Main): $track1Status" -ForegroundColor $(if ($track1Status -eq "READY") { "Green" } else { "Yellow" })
Write-Host "Track 2 (Sandbox): $track2Status" -ForegroundColor $(if ($track2Status -eq "READY") { "Green" } else { "Yellow" })
