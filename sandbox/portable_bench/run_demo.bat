@echo off
setlocal enabledelayedexpansion

echo --- Portable WhisperX Runner ---
echo Mode: CPU Priority

set "SCRIPT_DIR=%~dp0"
set "PYTHON_DIR=%SCRIPT_DIR%python-embed"
set "FFMPEG_ROOT=%SCRIPT_DIR%ffmpeg"

if not exist "%PYTHON_DIR%\python.exe" (
    echo [ERROR] Python not found. Please run setup.ps1 first.
    pause
    exit /b 1
)

echo Searching for FFmpeg...
set "FFMPEG_BIN="
for /r "%FFMPEG_ROOT%" %%f in (ffmpeg.exe) do (
    set "FFMPEG_BIN=%%~dpf"
    goto :FoundFFmpeg
)

:FoundFFmpeg
if "%FFMPEG_BIN%"=="" (
    echo [WARNING] FFmpeg.exe not found in %FFMPEG_ROOT%. 
    echo WhisperX might fail if it's not in your system PATH.
) else (
    echo Found FFmpeg at: %FFMPEG_BIN%
    set "PATH=%FFMPEG_BIN%;%PATH%"
)

echo Running Demo...
"%PYTHON_DIR%\python.exe" "%SCRIPT_DIR%demo.py"

echo.
echo Done. Press any key to exit.
pause
