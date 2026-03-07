@echo off
setlocal
cd /d "%~dp0"

set "A002_EXE=%~dp0aSTT-demo.exe"

if not exist "%A002_EXE%" (
  echo [ERROR] Missing A002 executable:
  echo         %A002_EXE%
  exit /b 1
)

tasklist /FI "IMAGENAME eq aSTT-demo.exe" | find /I "aSTT-demo.exe" >nul
if not errorlevel 1 (
  echo [INFO] aSTT-demo.exe is already running. No duplicate launch.
  exit /b 0
)

start "" "%A002_EXE%"
echo [OK] Started A002: %A002_EXE%
exit /b 0
