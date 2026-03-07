param(
  [int]$Tail = 40,
  [switch]$NoWait
)

$ErrorActionPreference = "Stop"

$logPath = Join-Path $env:TEMP "astt_demo_a004\sidecar.log"
Write-Host "A004 monitor" -ForegroundColor Cyan
Write-Host "Sidecar log: $logPath" -ForegroundColor Gray

Write-Host ""
Write-Host "Active app processes:" -ForegroundColor Cyan
Get-Process app_temp -ErrorAction SilentlyContinue |
  Select-Object ProcessName, Id, StartTime, MainWindowTitle |
  Format-Table -AutoSize

Write-Host ""
Write-Host "Port 1420:" -ForegroundColor Cyan
netstat -ano | Select-String ":1420"

Write-Host ""
Write-Host "Last $Tail sidecar log lines:" -ForegroundColor Cyan
if (Test-Path $logPath) {
  Get-Content $logPath -Tail $Tail
} else {
  Write-Host "Log file not found yet. Start Tauri app first." -ForegroundColor Yellow
}

Write-Host ""
if (-not $NoWait) {
  Write-Host "Live tail (Ctrl+C to stop):" -ForegroundColor Cyan
  if (Test-Path $logPath) {
    Get-Content $logPath -Tail $Tail -Wait
  } else {
    while (-not (Test-Path $logPath)) {
      Start-Sleep -Milliseconds 500
    }
    Get-Content $logPath -Tail $Tail -Wait
  }
}
