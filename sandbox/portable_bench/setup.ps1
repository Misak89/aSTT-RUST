# setup.ps1 - Portable WhisperX Benchmark (CPU Priority)
$ErrorActionPreference = "Stop"

$pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-embed-amd64.zip"
$pipUrl = "https://bootstrap.pypa.io/get-pip.py"
$ffmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
$destDir = "$PSScriptRoot\python-embed"
$ffmpegDir = "$PSScriptRoot\ffmpeg"

Write-Host "--- Portable WhisperX Setup (CPU Mode) ---" 

# 1. Download and Extract Python Embedded
if (-not (Test-Path "$destDir\python.exe")) {
    Write-Host "Downloading Python 3.10..."
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $zipPath = "$destDir\python.zip"
    Invoke-WebRequest -Uri $pythonUrl -OutFile $zipPath
    
    Write-Host "Extracting Python..."
    Expand-Archive -Path $zipPath -DestinationPath $destDir -Force
    Remove-Item $zipPath
}
else {
    Write-Host "Python already present."
}

# 2. Fix python._pth to allow Pip
$pthFile = "$destDir\python310._pth"
$content = Get-Content $pthFile
if ($content -notcontains "import site") {
    Write-Host "Patching python310._pth..."
    Add-Content -Path $pthFile -Value "import site"
}

# 3. Get Pip
$pipPath = "$destDir\get-pip.py"
if (-not (Test-Path $pipPath)) {
    Write-Host "Downloading get-pip.py..."
    Invoke-WebRequest -Uri $pipUrl -OutFile $pipPath
}

# 4. Install Pip and Dependencies
Write-Host "Installing Pip..."
& "$destDir\python.exe" "$pipPath" --no-warn-script-location

# Verify Pip
if (& "$destDir\python.exe" -m pip --version) {
    Write-Host "Pip installed successfully."
}
else {
    Write-Error "Pip installation failed."
    exit 1
}

# Note: Using --no-cache-dir to avoid disk bloat
Write-Host "Installing Libraries... (This will take a few minutes)"

# First install torch family to ensure correct CPU wheels
Write-Host "Installing PyTorch (CPU)..."
& "$destDir\python.exe" -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu --no-cache-dir --no-warn-script-location

# Then install WhisperX and other audio tools
Write-Host "Installing WhisperX and audio tools..."
& "$destDir\python.exe" -m pip install whisperx sounddevice scipy --no-cache-dir --no-warn-script-location

# Install additional tools for benchmark testing
Write-Host "Installing benchmark dependencies..."
& "$destDir\python.exe" -m pip install requests playsound pycaw comtypes pyaudiowpatch --no-cache-dir --no-warn-script-location

# Final verification of numpy and other critical libs
Write-Host "Verifying installations..."
& "$destDir\python.exe" -m pip install --upgrade numpy --no-cache-dir --no-warn-script-location

# 5. FFmpeg Setup
if (-not (Test-Path "$ffmpegDir\bin\ffmpeg.exe")) {
    Write-Host "Downloading FFmpeg Essentials..."
    New-Item -ItemType Directory -Force -Path $ffmpegDir | Out-Null
    $ffZip = "$ffmpegDir\ffmpeg.zip"
    Invoke-WebRequest -Uri $ffmpegUrl -OutFile $ffZip
    
    Write-Host "Extracting FFmpeg..."
    # Warning: Standard unzip might nest folders. We'll handle path in run.bat
    Expand-Archive -Path $ffZip -DestinationPath $ffmpegDir -Force
    Remove-Item $ffZip
}

Write-Host "--- Setup Complete ---"
Write-Host "You can now run 'run_demo.bat'"
