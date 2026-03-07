param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $RootPath)) {
  throw "RootPath not found: $RootPath"
}

$venvPython = Join-Path $RootPath ".venv-a004\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
  throw "Missing python runtime: $venvPython. Run setup_demo_a004.ps1 first."
}

Push-Location $RootPath
try {
  $env:ASTT_PYTHON_BIN = $venvPython
  Write-Host "ASTT_PYTHON_BIN=$venvPython" -ForegroundColor Gray
  npm run tauri dev
} finally {
  Pop-Location
}
