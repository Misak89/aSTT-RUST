param(
    [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$runOnSaveScript = Join-Path $PSScriptRoot "run_on_save.ps1"
$logsDir = Join-Path $RootPath "logs"
$watchLog = Join-Path $logsDir "runonsave-watch.log"
$pidFile = Join-Path $logsDir "runonsave-watcher.pid"
$heartbeatFile = Join-Path $logsDir "runonsave-watcher.heartbeat"

if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

function Write-WatchLog {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $watchLog -Value "$ts $Message"
}

function Should-SkipFile {
    param([string]$Path)
    if (-not $Path.ToLower().EndsWith(".md")) { return $true }
    $skipParts = @("\.git\", "\node_modules\", "\target\", "\.specify\", "\.agent\", "\.kilocode\", "\.venv\", "\logs\")
    foreach ($p in $skipParts) {
        if ($Path.ToLower().Contains($p)) { return $true }
    }
    return $false
}

Set-Content -Path $pidFile -Value $PID
Set-Content -Path $heartbeatFile -Value (Get-Date -Format "o")
Write-WatchLog "WATCHER_START pid=$PID root=$RootPath"

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $RootPath
$watcher.Filter = "*.md"
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite, CreationTime'
$watcher.EnableRaisingEvents = $true

$lastEventByFile = @{}
$debounceMs = 1200

$action = {
    $path = $Event.SourceEventArgs.FullPath
    if (Should-SkipFile -Path $path) { return }

    $now = Get-Date
    $key = $path.ToLower()
    if ($lastEventByFile.ContainsKey($key)) {
        $delta = ($now - $lastEventByFile[$key]).TotalMilliseconds
        if ($delta -lt $debounceMs) { return }
    }
    $lastEventByFile[$key] = $now

    try {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $runOnSaveScript -FilePath $path
        Write-WatchLog "UPDATED path=$path"
    } catch {
        Write-WatchLog "ERROR path=$path msg=$($_.Exception.Message)"
    }
}

$subChanged = Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action
$subCreated = Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action
$subRenamed = Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action

try {
    while ($true) {
        Set-Content -Path $heartbeatFile -Value (Get-Date -Format "o")
        Start-Sleep -Seconds 10
    }
}
finally {
    Write-WatchLog "WATCHER_STOP pid=$PID"
    Unregister-Event -SubscriptionId $subChanged.Id -ErrorAction SilentlyContinue
    Unregister-Event -SubscriptionId $subCreated.Id -ErrorAction SilentlyContinue
    Unregister-Event -SubscriptionId $subRenamed.Id -ErrorAction SilentlyContinue
    $watcher.Dispose()
    Remove-Item $pidFile -ErrorAction SilentlyContinue
}

