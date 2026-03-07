@echo off
setlocal
cd /d "%~dp0"

set "A002_EXE=%~dp0aSTT-demo.exe"
set "A003_EXE=%~dp0..\..\..\TestDocu_a003\_launch_now\windows-demo\app\aSTT-demo-electron.exe"

echo [INFO] Safe launch: A002 + A003
echo.

if exist "%A002_EXE%" (
  tasklist /FI "IMAGENAME eq aSTT-demo.exe" | find /I "aSTT-demo.exe" >nul
  if errorlevel 1 (
    start "" "%A002_EXE%"
    echo [OK] Started A002: %A002_EXE%
  ) else (
    echo [INFO] A002 already running, skipped duplicate launch.
  )
) else (
  echo [WARN] A002 executable not found:
  echo        %A002_EXE%
)

if exist "%A003_EXE%" (
  tasklist /FI "IMAGENAME eq aSTT-demo-electron.exe" | find /I "aSTT-demo-electron.exe" >nul
  if errorlevel 1 (
    start "" "%A003_EXE%"
    echo [OK] Started A003: %A003_EXE%
  ) else (
    echo [INFO] A003 already running, skipped duplicate launch.
  )
) else (
  echo [WARN] A003 executable not found:
  echo        %A003_EXE%
)

echo.
echo [DONE] Launch sequence complete.
exit /b 0
