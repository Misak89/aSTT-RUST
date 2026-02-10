# scripts/update_docs.ps1
# MACHINE-OPERATED CONTROLLER (Track-Aware)
$ErrorActionPreference = "Stop"

$root = "$PSScriptRoot\.."
$reportFile = "$root\QA_REPORT.md"
$projectFile = "$root\project.json"

Write-Host "--- [AUTONOMOUS CONTROLLER START] ---"
$timestamp = Get-Date -Format "yyyy-MM-dd ddd HH:mm"

# 1. Integrity Watchdog (Machine Readability & Path Verification)
Write-Host "Monitoring Path Integrity..."
$criticalPaths = @(
    "$root\.specify\spec.md",
    "$root\.specify\plan.md",
    "$root\project.json",
    "$root\ARCHITECTURE.md"
)

foreach ($path in $criticalPaths) {
    if (-not (Test-Path $path)) {
        Write-Error "CRITICAL INTEGRITY FAILURE: Path missing -> $path"
        exit 1
    }
}
Write-Host "Integrity: OK"

# 2. System Analysis (Multi-Track)
$health = @{
    Rust          = if (Get-Command rustc -ErrorAction SilentlyContinue) { "OK" } else { "MISSING" }
    Node          = if (Get-Command node -ErrorAction SilentlyContinue) { "OK" } else { "MISSING" }
    SandBoxPython = if (Test-Path "$root\sandbox\portable_bench\python-embed\python.exe") { "OK" } else { "MISSING" }
    DevPython     = if (Test-Path "$root\.venv\Scripts\python.exe") { "OK" } else { "MISSING" }
}

# 3. Track Status Determination
$track1Status = if ($health.Rust -eq "OK" -and $health.Node -eq "OK") { "READY" } else { "BLOCKED (Deps Missing)" }
$track2Status = if ($health.SandBoxPython -eq "OK") { "READY" } else { "INITIALIZING (Fetch Required)" }

# 4. Update QA_REPORT.md (Dashboard)
if (Test-Path $reportFile) {
    $content = Get-Content $reportFile -Raw
    
    # Track-specific Status Insertion
    $healthTable = "
| Component | Track | Status |
| :--- | :--- | :--- |
| **Backend (Rust)** | Main | $($health.Rust) |
| **Frontend (Node)** | Main | $($health.Node) |
| **STT Sandbox (Python)** | Sandbox | $($health.SandBoxPython) |
| **Dev Environment** | Shared | $($health.DevPython) |
"
    # Unified Timestamp & Version Update
    if ($content -match "Version: (\d+\.\d+)") {
        $newVer = "{0:N1}" -f ([double]$matches[1] + 0.1)
        $content = $content -replace "Version: \d+\.\d+", "Version: $newVer"
    }
    $content = $content -replace "Last Updated: .*", "Last Updated: $timestamp"
    $content = $content -replace "(?<=## 🛠 System Health \(Agent-Monitored\)\s+)[\s\S]*?(?=---)", "`n$healthTable`n"

    $content | Out-File $reportFile -Encoding utf8
}

Write-Host "--- [CONTROLLER DONE: Track 1=$track1Status, Track 2=$track2Status] ---"
