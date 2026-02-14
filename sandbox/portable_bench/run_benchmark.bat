@echo off
REM run_benchmark.bat - Spuštění kompletního STT benchmark testu
echo =========================================================
echo  PORTABLE STT BENCHMARK - Complete Test Suite
echo =========================================================
echo.

set PYTHON_PATH=%~dp0python-embed\python.exe
set FFMPEG_BIN=%~dp0ffmpeg\bin

REM Najdi FFmpeg (může být ve vnořené složce)
for /r "%~dp0ffmpeg" %%i in (ffmpeg.exe) do set FFMPEG_BIN=%%~dpi

REM Přidej FFmpeg do PATH
set PATH=%FFMPEG_BIN%;%PATH%

REM Kontrola instalace
if not exist "%PYTHON_PATH%" (
    echo [ERROR] Python nenalezen! Spustte nejprve setup.ps1
    pause
    exit /b 1
)

echo [INFO] Python: %PYTHON_PATH%
echo [INFO] FFmpeg: %FFMPEG_BIN%
echo.

REM Menu
:MENU
echo =========================================================
echo  VYBERTE AKCI:
echo =========================================================
echo.
echo  1) Stáhnout audio vzorky (nutné před prvním spuštěním)
echo  2) Spustit benchmark test (HW + Audio + STT)
echo  3) Spustit pouze verify_bench (diagnostika)
echo  4) Spustit demo (live nahrávání)
echo  5) Konec
echo.
set /p CHOICE="Vaše volba (1-5): "

if "%CHOICE%"=="1" goto DOWNLOAD
if "%CHOICE%"=="2" goto BENCHMARK
if "%CHOICE%"=="3" goto VERIFY
if "%CHOICE%"=="4" goto DEMO
if "%CHOICE%"=="5" goto END
echo [ERROR] Neplatná volba!
goto MENU

:DOWNLOAD
echo.
echo === STAHOVÁNÍ AUDIO VZORKŮ ===
echo.
"%PYTHON_PATH%" download_samples.py
if errorlevel 1 (
    echo.
    echo [WARNING] Stahování selhalo. Zkontrolujte připoj ení k internetu.
    echo Případně stáhněte vzorky ručně do složky test_samples\
)
echo.
pause
goto MENU

:BENCHMARK
echo.
echo === SPOUŠTĚNÍ BENCHMARK TESTU ===
echo.
"%PYTHON_PATH%" test_samples.py
echo.
echo [INFO] Log uložen v: test_samples.log
pause
goto MENU

:VERIFY
echo.
echo === DIAGNOSTICKÝ TEST ===
echo.
"%PYTHON_PATH%" verify_bench.py
echo.
echo [INFO] Log uložen v: verify_bench.log
pause
goto MENU

:DEMO
echo.
echo === LIVE DEMO (Nahrávání z mikrofonu) ===
echo.
"%PYTHON_PATH%" demo.py --record
echo.
pause
goto MENU

:END
echo.
echo Konec.
exit /b 0
