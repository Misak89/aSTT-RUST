@echo off
setlocal

set SCRIPT_DIR=%~dp0
for %%I in ("%SCRIPT_DIR%..\..") do set ROOT_PATH=%%~fI
set DEFAULT_USB=E:\aSTT-DEMO-A002
if not exist E:\ set DEFAULT_USB=%SCRIPT_DIR%_usb_out\aSTT-DEMO-A002
set LOG_PATH=%SCRIPT_DIR%prepare_usb_windows_demo_last.log

echo [aSTT DEMO A002] USB prepare
echo Root : %ROOT_PATH%
echo.
set /p USB_PATH=USB target path [%DEFAULT_USB%]:
if "%USB_PATH%"=="" set USB_PATH=%DEFAULT_USB%

echo USB  : %USB_PATH%
echo Log  : %LOG_PATH%
echo.

pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%prepare_usb_windows_demo.ps1" -RootPath "%ROOT_PATH%" -UsbPath "%USB_PATH%" -BuildFirst > "%LOG_PATH%" 2>&1
set EXIT_CODE=%ERRORLEVEL%

type "%LOG_PATH%"
echo.
echo Exit code: %EXIT_CODE%
if not "%EXIT_CODE%"=="0" (
  echo FAILED. Fix the error above, then run again.
) else (
  echo SUCCESS.
)
echo.
pause
exit /b %EXIT_CODE%
