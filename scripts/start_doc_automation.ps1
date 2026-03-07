$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$logsDir = Join-Path $root "logs"
$guardPidFile = Join-Path $logsDir "runonsave-guard.pid"
$guardScript = Join-Path $PSScriptRoot "run_on_save_guard.ps1"

if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

function Guard-Running {
    if (-not (Test-Path $guardPidFile)) { return $false }
    $guardPid = Get-Content $guardPidFile -ErrorAction SilentlyContinue
    if (-not $guardPid) { return $false }
    try {
        $p = Get-Process -Id ([int]$guardPid) -ErrorAction Stop
        return [bool]$p
    } catch {
        return $false
    }
}

if (Guard-Running) {
    Write-Host "Run on Save automation already running."
    exit 0
}

Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$guardScript`"" -WindowStyle Hidden | Out-Null
Start-Sleep -Seconds 1
Write-Host "Run on Save automation started (guard + watcher)."
