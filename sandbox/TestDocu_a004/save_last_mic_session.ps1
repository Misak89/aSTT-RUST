param(
  [string]$ProjectRoot = "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST",
  [string]$OutputRoot = "",
  [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $ProjectRoot "sandbox\TestDocu_a004\session_exports"
}

$tempRoot = [System.IO.Path]::GetTempPath()
$recording = Get-ChildItem -Path $tempRoot -Filter "astt_recording_*.wav" -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $recording) {
  throw "No MIC recording found in TEMP (pattern astt_recording_*.wav)."
}

$sidecarLog = Join-Path $tempRoot "astt_demo_a004\sidecar.log"
if (-not (Test-Path $sidecarLog)) {
  throw "Sidecar log not found: $sidecarLog"
}

$sessionStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$sessionDir = Join-Path $OutputRoot "mic_session_$sessionStamp"
New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null

$recordingCopy = Join-Path $sessionDir $recording.Name
$logCopy = Join-Path $sessionDir "sidecar.log"
$excerptFile = Join-Path $sessionDir "session_log_excerpt.txt"
$metaFile = Join-Path $sessionDir "session_meta.json"

Copy-Item -Path $recording.FullName -Destination $recordingCopy -Force
Copy-Item -Path $sidecarLog -Destination $logCopy -Force

$patterns = @(
  [regex]::Escape($recording.Name),
  "Starting recording with params",
  "Stopping recording with params",
  "Transcribe request options",
  "Transcribing source:"
)

$excerptLines = Get-Content $sidecarLog -ErrorAction Stop |
  Select-String -Pattern $patterns |
  ForEach-Object { $_.Line }

if ($excerptLines.Count -eq 0) {
  $excerptLines = @("No matching lines found. See full sidecar.log.")
}

$excerptLines | Set-Content -Path $excerptFile -Encoding UTF8

$meta = [ordered]@{
  export_time_local = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  recording_source = $recording.FullName
  recording_copy = $recordingCopy
  sidecar_log_source = $sidecarLog
  sidecar_log_copy = $logCopy
  excerpt_file = $excerptFile
  recording_sha256 = (Get-FileHash -Path $recordingCopy -Algorithm SHA256).Hash
  sidecar_log_sha256 = (Get-FileHash -Path $logCopy -Algorithm SHA256).Hash
}

$meta | ConvertTo-Json -Depth 4 | Set-Content -Path $metaFile -Encoding UTF8

Write-Host "Saved MIC session export:" -ForegroundColor Green
Write-Host "  $sessionDir"
Write-Host "Files:"
Write-Host "  - $recordingCopy"
Write-Host "  - $logCopy"
Write-Host "  - $excerptFile"
Write-Host "  - $metaFile"

if ($OpenFolder) {
  Start-Process explorer.exe $sessionDir | Out-Null
}
