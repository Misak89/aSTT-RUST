param(
    [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$UsbPath = "E:\aSTT-DEMO-A003",
    [switch]$SkipBuild,
    [switch]$BuildFirst,
    [switch]$SmokeTest,
    [switch]$PromptAtEnd
)

$ErrorActionPreference = "Stop"

$exitCode = 0
$autoPromptAtEnd = $false

function Get-ParentProcessName {
    try {
        $current = Get-CimInstance Win32_Process -Filter "ProcessId = $PID"
        if ($current -and $current.ParentProcessId) {
            return (Get-Process -Id $current.ParentProcessId -ErrorAction Stop).ProcessName
        }
    }
    catch {
        return $null
    }
    return $null
}

try {
    $parentProcessName = Get-ParentProcessName
    if ($parentProcessName -eq "explorer") {
        $autoPromptAtEnd = $true
    }

    $resolvedUsbPath = $UsbPath
    if ([string]::IsNullOrWhiteSpace($resolvedUsbPath)) {
        $resolvedUsbPath = Join-Path $PSScriptRoot "_usb_out\aSTT-DEMO-A003"
    }
    if ($resolvedUsbPath -match "^[A-Za-z]:\\") {
        $driveRoot = "$($resolvedUsbPath.Substring(0, 2))\"
        if (-not (Test-Path $driveRoot)) {
            $fallbackUsbPath = Join-Path $PSScriptRoot "_usb_out\aSTT-DEMO-A003"
            Write-Host "WARNING: Drive '$driveRoot' not found. Using fallback: $fallbackUsbPath" -ForegroundColor Yellow
            $resolvedUsbPath = $fallbackUsbPath
        }
    }

    $distDir = Join-Path $RootPath "dist-electron"
    $packedDir = Join-Path $distDir "win-unpacked"
    $demoDir = Join-Path $resolvedUsbPath "windows-demo"

    # Compatibility: historical -BuildFirst is accepted, but build is now default.
    $doBuild = -not $SkipBuild
    if ($BuildFirst) {
        $doBuild = $true
    }

    if ($doBuild) {
        Push-Location $RootPath
        try {
            npm run check
            npm run build
            npm run electron:pack
        }
        finally {
            Pop-Location
        }
    }

    if (-not (Test-Path $packedDir)) {
        throw "Missing packed folder: $packedDir"
    }

    $packedExe = Join-Path $packedDir "aSTT-demo-electron.exe"
    if (-not (Test-Path $packedExe)) {
        throw "Missing packed exe: $packedExe"
    }

    New-Item -ItemType Directory -Path $demoDir -Force | Out-Null
    $demoAppDir = Join-Path $demoDir "app"
    if (Test-Path $demoAppDir) {
        Remove-Item $demoAppDir -Recurse -Force
    }
    Copy-Item $packedDir $demoAppDir -Recurse -Force
    Copy-Item (Join-Path $RootPath "sandbox\TestDocu_a003\README.md") (Join-Path $demoDir "README.md") -Force
    Copy-Item (Join-Path $RootPath "sandbox\TestDocu_a003\DEMO_A003_ELECTRON_RUNBOOK_2026-03-04.md") (Join-Path $demoDir "RUNBOOK.md") -Force

    $buildInfo = @(
        "build_time_local=$(Get-Date -Format o)",
        "build_time_utc=$((Get-Date).ToUniversalTime().ToString('o'))",
        "root_path=$RootPath",
        "selected_pack_dir=$packedDir",
        "selected_pack_exe=$packedExe",
        "selected_pack_exe_last_write_utc=$((Get-Item $packedExe).LastWriteTimeUtc.ToString('o'))",
        "build_performed=$doBuild"
    ) -join [Environment]::NewLine
    Set-Content -Path (Join-Path $demoDir "BUILD_INFO.txt") -Value $buildInfo -Encoding ASCII

    $doSmokeTest = $SmokeTest -or $doBuild
    if ($doSmokeTest) {
        $demoExePath = Join-Path $demoAppDir "aSTT-demo-electron.exe"
        if (-not (Test-Path $demoExePath)) {
            throw "Smoke test failed: missing exe in copied app folder ($demoExePath)."
        }
        $previousRunAsNode = $env:ELECTRON_RUN_AS_NODE
        Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
        $p = $null
        try {
            $p = Start-Process -FilePath $demoExePath -PassThru
        }
        finally {
            if ($null -eq $previousRunAsNode) {
                Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
            }
            else {
                $env:ELECTRON_RUN_AS_NODE = $previousRunAsNode
            }
        }
        Start-Sleep -Seconds 5
        $alive = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
        if (-not $alive) {
            throw "Smoke test failed: aSTT-demo-electron.exe exited immediately."
        }
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }

    $runCmd = @'
@echo off
set "ELECTRON_RUN_AS_NODE="
cd /d "%~dp0"
start "" ".\app\aSTT-demo-electron.exe"
'@

    Set-Content -Path (Join-Path $demoDir "RUN_FROM_USB.cmd") -Value $runCmd -Encoding ASCII

    Write-Host "USB demo prepared:" -ForegroundColor Green
    Write-Host $demoDir -ForegroundColor Green
    Write-Host "Run: RUN_FROM_USB.cmd" -ForegroundColor Green
    Write-Host "Build info: BUILD_INFO.txt" -ForegroundColor Green
}
catch {
    $exitCode = 1
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($PromptAtEnd -or $autoPromptAtEnd) {
        [void](Read-Host "Press Enter to close")
    }
}

exit $exitCode
