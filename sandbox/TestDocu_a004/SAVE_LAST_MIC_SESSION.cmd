@echo off
setlocal
set ROOT=C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST
pwsh -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\sandbox\TestDocu_a004\save_last_mic_session.ps1" -ProjectRoot "%ROOT%" -OpenFolder
endlocal
