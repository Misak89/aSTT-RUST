param(
    [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$CheckSeconds = 15,
    [int]$HeartbeatMaxAgeSeconds = 45
)

$ErrorActionPreference = "Stop"

$logsDir = Join-Path $RootPath "logs"
$guardLog = Join-Path $logsDir "runonsave-guard.log"
$guardPidFile = Join-Path $logsDir "runonsave-guard.pid"
$watchPidFile = Join-Path $logsDir "runonsave-watcher.pid"
$watchHeartbeat = Join-Path $logsDir "runonsave-watcher.heartbeat"
$watchScript = Join-Path $PSScriptRoot "watch_docs.ps1"

if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

function Write-GuardLog {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $guardLog -Value "$ts $Message"
}

function Show-Alert {
    param([string]$Text)
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show($Text, "Run on Save Guard") | Out-Null
    } catch {
    }
}

function Is-WatcherAlive {
    if (-not (Test-Path $watchPidFile)) { return $false }
    $watchProcId = Get-Content $watchPidFile -ErrorAction SilentlyContinue
    if (-not $watchProcId) { return $false }
    try {
        $p = Get-Process -Id ([int]$watchProcId) -ErrorAction Stop
        if (-not $p) { return $false }
        if (-not (Test-Path $watchHeartbeat)) { return $false }
        $hb = Get-Content $watchHeartbeat -ErrorAction SilentlyContinue
        if (-not $hb) { return $false }
        $last = [datetime]::Parse($hb)
        $age = (New-TimeSpan -Start $last -End (Get-Date)).TotalSeconds
        return ($age -le $HeartbeatMaxAgeSeconds)
    } catch {
        return $false
    }
}

function Start-Watcher {
    Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$watchScript`"" -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 1
}

Set-Content -Path $guardPidFile -Value $PID
Write-GuardLog "GUARD_START pid=$PID"

$alerted = $false

try {
    while ($true) {
        if (-not (Is-WatcherAlive)) {
            Write-GuardLog "WATCHER_DOWN restart"
            Start-Watcher
            if (-not $alerted) {
                Show-Alert "Run on Save watcher nebyl aktivni. Guard ho restartoval."
                $alerted = $true
            }
        } else {
            $alerted = $false
        }
        Start-Sleep -Seconds $CheckSeconds
    }
}
finally {
    Write-GuardLog "GUARD_STOP pid=$PID"
    Remove-Item $guardPidFile -ErrorAction SilentlyContinue
}

