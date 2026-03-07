param(
    [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$TargetFile = "test/runonsave-test.md",
    [int]$HeartbeatMaxAgeSeconds = 60
)

$ErrorActionPreference = "Stop"

$settingsPath = Join-Path $RootPath ".vscode/settings.json"
$guardPidPath = Join-Path $RootPath "logs/runonsave-guard.pid"
$watcherPidPath = Join-Path $RootPath "logs/runonsave-watcher.pid"
$heartbeatPath = Join-Path $RootPath "logs/runonsave-watcher.heartbeat"
$watchLogPath = Join-Path $RootPath "logs/runonsave-watch.log"
$runLogPath = Join-Path $RootPath "logs/runonsave.log"
$targetPath = Join-Path $RootPath $TargetFile

$failures = @()

function Add-Failure {
    param([string]$Message)
    $script:failures += $Message
}

function Test-ProcessAlive {
    param([string]$PidFile)
    if (-not (Test-Path $PidFile)) { return $false }
    $procId = Get-Content $PidFile -ErrorAction SilentlyContinue
    if (-not $procId) { return $false }
    try {
        $p = Get-Process -Id ([int]$procId) -ErrorAction Stop
        return [bool]$p
    } catch {
        return $false
    }
}

if (-not (Test-Path $settingsPath)) {
    Add-Failure "Missing settings file: .vscode/settings.json"
} else {
    $settingsRaw = Get-Content $settingsPath -Raw
    if ($settingsRaw -notmatch "emeraldwalk\.runonsave") {
        Add-Failure "Missing emeraldwalk.runonsave config in .vscode/settings.json"
    }
    if ($settingsRaw -notmatch "run_on_save\.ps1") {
        Add-Failure "run_on_save.ps1 command not configured in .vscode/settings.json"
    }
}

if (-not (Test-ProcessAlive -PidFile $guardPidPath)) {
    Add-Failure "Guard process is not running (logs/runonsave-guard.pid)"
}

if (-not (Test-ProcessAlive -PidFile $watcherPidPath)) {
    Add-Failure "Watcher process is not running (logs/runonsave-watcher.pid)"
}

if (-not (Test-Path $heartbeatPath)) {
    Add-Failure "Missing watcher heartbeat file (logs/runonsave-watcher.heartbeat)"
} else {
    $hbRaw = Get-Content $heartbeatPath -ErrorAction SilentlyContinue
    if (-not $hbRaw) {
        Add-Failure "Watcher heartbeat file is empty"
    } else {
        try {
            $hb = [datetime]::Parse($hbRaw)
            $age = (New-TimeSpan -Start $hb -End (Get-Date)).TotalSeconds
            if ($age -gt $HeartbeatMaxAgeSeconds) {
                Add-Failure "Watcher heartbeat is stale (${age}s old)"
            }
        } catch {
            Add-Failure "Watcher heartbeat has invalid datetime format"
        }
    }
}

if (-not (Test-Path $watchLogPath)) {
    Add-Failure "Missing watch log (logs/runonsave-watch.log)"
}

if (-not (Test-Path $runLogPath)) {
    Add-Failure "Missing run-on-save log (logs/runonsave.log)"
} else {
    $lastRunLine = Get-Content $runLogPath | Select-Object -Last 1
    if ($lastRunLine -notmatch "UPDATED .* v\d+\.\d+") {
        Add-Failure "Latest run log line is not a valid UPDATED record"
    }
}

if (-not (Test-Path $targetPath)) {
    Add-Failure "Target file not found: $TargetFile"
} else {
    $content = Get-Content $targetPath -Raw
    if ($content -notmatch "\*\*Cesta:\*\*") { Add-Failure "Target file missing **Cesta:** metadata" }
    if ($content -notmatch "\*\*Verze:\*\*\s*\d+\.\d+") { Add-Failure "Target file missing valid **Verze:** metadata" }
    if ($content -notmatch "\*\*Posledni zmena:\*\*\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\s+\(UTC\+\d\)") {
        Add-Failure "Target file missing valid **Posledni zmena:** metadata"
    }
}

Write-Host ""
Write-Host "Run on Save Health Check" -ForegroundColor Cyan
Write-Host "Root: $RootPath" -ForegroundColor Cyan
Write-Host "Target: $TargetFile" -ForegroundColor Cyan
Write-Host ""

if ($failures.Count -eq 0) {
    Write-Host "PASS: Run on Save automation is healthy." -ForegroundColor Green
    exit 0
}

Write-Host "FAIL: Detected issues:" -ForegroundColor Red
foreach ($f in $failures) {
    Write-Host " - $f" -ForegroundColor Yellow
}
exit 1
