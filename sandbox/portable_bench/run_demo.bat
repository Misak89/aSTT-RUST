@echo off
setlocal enabledelayedexpansion

echo ====================================================
echo   aSTT-RUST Portable Benchmark (Medical STT)
echo ====================================================
echo Mode: CPU-Optimized (Ralph Wiggum Style)
echo.

set "SCRIPT_DIR=%~dp0"
set "PYTHON_EXE=%SCRIPT_DIR%python-embed\python.exe"
set "FFMPEG_ROOT=%SCRIPT_DIR%ffmpeg"

:: Safety Check
if not exist "%PYTHON_EXE%" (
    echo [ERROR] Portable Python not found at: %PYTHON_EXE%
    echo Please right-click setup.ps1 and 'Run with PowerShell' first.
    pause
    exit /b 1
)

:: Find FFmpeg in the extracted folder
set "FFMPEG_BIN="
for /r "%FFMPEG_ROOT%" %%f in (ffmpeg.exe) do (
    set "FFMPEG_BIN=%%~dpf"
    goto :FoundFFmpeg
)

:FoundFFmpeg
if "%FFMPEG_BIN%"=="" (
    echo [WARNING] FFmpeg not found locally. Using system PATH...
) else (
    echo Found FFmpeg at: %FFMPEG_BIN%
    set "PATH=%FFMPEG_BIN%;%PATH%"
)

:: Interactive Choice
echo.
echo Choose Action:
echo [1] Process EXISTING 'benchmark_input.wav'
echo [2] CAPTURE NEW Audio (Mic/Internal/External) - Unlimited duration
echo.
set /p choice="Enter choice (1 or 2): "

if "%choice%"=="2" (
    echo.
    echo --- STARTING RECORDER ---
    echo.
    "%PYTHON_EXE%" "%SCRIPT_DIR%demo.py" --record
) else (
    echo.
    echo --- PROCESSING EXISTING FILE ---
    "%PYTHON_EXE%" "%SCRIPT_DIR%demo.py"
)

echo.
echo ====================================================
echo Task Complete. 
echo Results are saved in 'benchmark_input.wav.txt'
echo Press any key to exit.
pause
