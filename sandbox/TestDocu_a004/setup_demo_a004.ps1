param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST",
  [switch]$InstallWhisperX
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $RootPath)) {
  throw "RootPath not found: $RootPath"
}

function Resolve-SystemPython {
  $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
  if ($pythonCmd) {
    return "python"
  }
  throw "System python was not found in PATH."
}

function Install-CoreRequirements {
  param(
    [Parameter(Mandatory = $true)][string]$PythonExe,
    [Parameter(Mandatory = $true)][string]$RequirementsFile
  )
  & $PythonExe -m pip install --upgrade pip setuptools wheel
  & $PythonExe -m pip install -r $RequirementsFile
}

Push-Location $RootPath
try {
  $systemPython = Resolve-SystemPython
  $venvDir = Join-Path $RootPath ".venv-a004"
  $venvPython = Join-Path $venvDir "Scripts\python.exe"
  $requirementsCore = Join-Path $RootPath "sandbox\TestDocu_a004\requirements-a004-core.txt"

  if (-not (Test-Path $requirementsCore)) {
    throw "Missing requirements file: $requirementsCore"
  }

  if (-not (Test-Path $venvPython)) {
    Write-Host "Creating venv: $venvDir" -ForegroundColor Cyan
    & $systemPython -m venv $venvDir
  } else {
    Write-Host "Using existing venv: $venvDir" -ForegroundColor Cyan
  }

  Write-Host "Installing A004 core python dependencies..." -ForegroundColor Cyan
  Install-CoreRequirements -PythonExe $venvPython -RequirementsFile $requirementsCore

  if ($InstallWhisperX) {
    Write-Host "Installing optional whisperx (can take longer)..." -ForegroundColor Cyan
    try {
      & $venvPython -m pip install whisperx
      Write-Host "[OK] whisperx installed" -ForegroundColor Green
    } catch {
      Write-Host "[WARN] whisperx installation failed: $($_.Exception.Message)" -ForegroundColor Yellow
      Write-Host "[WARN] A004 still works with faster-whisper fallback." -ForegroundColor Yellow
    }
  }

  Write-Host ""
  Write-Host "Setup complete." -ForegroundColor Green
  Write-Host "Use this for runtime binding:" -ForegroundColor Gray
  Write-Host "  `$env:ASTT_PYTHON_BIN = `"$venvPython`"" -ForegroundColor Gray
  Write-Host "Then run:" -ForegroundColor Gray
  Write-Host "  npm run tauri dev" -ForegroundColor Gray
} finally {
  Pop-Location
}
