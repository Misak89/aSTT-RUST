# Portable WhisperX Bench

This folder contains a standalone, no-install test environment for WhisperX.
It is configured to run on **CPU** (for office notebooks) but can use NVIDIA GPU if available and drivers are installed.

## How to Use

### Step 1: Setup (Run Once)
1.  Right-click `setup.ps1` and select **Run with PowerShell**.
2.  Wait for it to download Python (Embed), FFmpeg, and install dependencies (approx 1-2 GB).
3.  When it says "Setup Complete", close the window.

### Step 2: Run Demo
1.  Double-click `run_demo.bat`.
2.  It will download a sample audio file (`jfk.wav`) if missing.
3.  It will transcribe the file using the `tiny` model on CPU.
4.  Check `jfk.wav.txt` for the result.

## Notes
- **No System Changes**: Everything is installed into `python-embed` and `ffmpeg` folders inside this directory. Delete this folder to uninstall.
- **Performance**: On CPU, the `tiny` model is fast. Larger models (medium/large) will be very slow without a GPU.
