param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"
)

$ErrorActionPreference = "Stop"

function Resolve-PythonExe {
  param(
    [Parameter(Mandatory = $true)][string]$Root
  )

  $envPython = $env:ASTT_PYTHON_BIN
  if ($envPython -and (Test-Path $envPython)) {
    return $envPython
  }

  $venvA004 = Join-Path $Root ".venv-a004\Scripts\python.exe"
  if (Test-Path $venvA004) {
    return $venvA004
  }

  $venv = Join-Path $Root ".venv\Scripts\python.exe"
  if (Test-Path $venv) {
    return $venv
  }

  $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
  if ($pythonCmd) {
    return "python"
  }

  throw "Python runtime was not found."
}

function Run-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )
  Write-Host "=== $Title ===" -ForegroundColor Cyan
  & $Command
}

function Test-CommandExists {
  param(
    [Parameter(Mandatory = $true)][string]$Name
  )
  $exists = [bool](Get-Command $Name -ErrorAction SilentlyContinue)
  if ($exists) {
    Write-Host "[OK] $Name detected" -ForegroundColor Green
  } else {
    Write-Host "[WARN] $Name not detected" -ForegroundColor Yellow
  }
  return $exists
}

function Test-PythonModule {
  param(
    [Parameter(Mandatory = $true)][string]$PythonExe,
    [Parameter(Mandatory = $true)][string]$ModuleName
  )

  $code = "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('$ModuleName') else 1)"
  & $PythonExe -c $code
  return $LASTEXITCODE -eq 0
}

if (-not (Test-Path $RootPath)) {
  throw "RootPath not found: $RootPath"
}

Push-Location $RootPath
try {
  $pythonExe = Resolve-PythonExe -Root $RootPath
  Write-Host "Python for test: $pythonExe" -ForegroundColor Gray

  Run-Step -Title "Python sidecar syntax" -Command {
    & $pythonExe -m py_compile src-python/sidecar.py
  }

  Run-Step -Title "Frontend type/lint checks" -Command {
    npm run check
  }

  Run-Step -Title "Rust tests" -Command {
    cargo test --manifest-path src-tauri/Cargo.toml
  }

  Run-Step -Title "Frontend build" -Command {
    npm run build
  }

  Write-Host "=== Runtime tool hints ===" -ForegroundColor Cyan
  $pythonCmdOk = Test-CommandExists -Name "python"
  $ytDlpOk = Test-CommandExists -Name "yt-dlp"
  $ffmpegOk = Test-CommandExists -Name "ffmpeg"

  Write-Host "=== Python module hints ===" -ForegroundColor Cyan
  $sounddeviceOk = Test-PythonModule -PythonExe $pythonExe -ModuleName "sounddevice"
  if ($sounddeviceOk) {
    Write-Host "[OK] Python module sounddevice detected" -ForegroundColor Green
  } else {
    Write-Host "[WARN] Python module sounddevice not detected" -ForegroundColor Yellow
  }

  $whisperxOk = Test-PythonModule -PythonExe $pythonExe -ModuleName "whisperx"
  if ($whisperxOk) {
    Write-Host "[OK] Python module whisperx detected" -ForegroundColor Green
  } else {
    Write-Host "[WARN] Python module whisperx not detected" -ForegroundColor Yellow
  }

  $fasterWhisperOk = Test-PythonModule -PythonExe $pythonExe -ModuleName "faster_whisper"
  if ($fasterWhisperOk) {
    Write-Host "[OK] Python module faster_whisper detected" -ForegroundColor Green
  } else {
    Write-Host "[WARN] Python module faster_whisper not detected" -ForegroundColor Yellow
  }

  $ytDlpModuleOk = Test-PythonModule -PythonExe $pythonExe -ModuleName "yt_dlp"
  if ($ytDlpModuleOk) {
    Write-Host "[OK] Python module yt_dlp detected" -ForegroundColor Green
  } else {
    Write-Host "[WARN] Python module yt_dlp not detected" -ForegroundColor Yellow
  }

  $missing = @()
  if (-not ($ytDlpOk -or $ytDlpModuleOk)) { $missing += "yt-dlp|python:yt_dlp" }
  if (-not $ffmpegOk) { $missing += "ffmpeg" }
  if (-not $sounddeviceOk) { $missing += "python:sounddevice" }
  if (-not ($whisperxOk -or $fasterWhisperOk)) { $missing += "python:whisperx|faster_whisper" }

  if ($missing.Count -gt 0) {
    throw "A004 full runtime prerequisites are missing: $($missing -join ', ')"
  }

  Write-Host "A004 verification completed." -ForegroundColor Green
} finally {
  Pop-Location
}
