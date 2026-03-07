param(
    [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$TaskName = "aSTT-RUST-Daily-Software-Audit",
    [string]$StartTime = "08:00"
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $RootPath "scripts\inventory_project_sw.ps1"
$logPath = Join-Path $RootPath "logs\daily-audit-task.log"

if (-not (Test-Path $scriptPath)) {
    throw "Missing script: $scriptPath"
}

$taskCommand = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" *> `"$logPath`""

schtasks /Create /SC DAILY /TN $TaskName /TR $taskCommand /ST $StartTime /F | Out-Host
Write-Host "Registered task: $TaskName ($StartTime daily)"
Write-Host "Task command: $taskCommand"
