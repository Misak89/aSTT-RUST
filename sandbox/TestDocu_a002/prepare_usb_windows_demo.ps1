param(
    [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$UsbPath = "E:\aSTT-DEMO-A002",
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
        $resolvedUsbPath = Join-Path $PSScriptRoot "_usb_out\aSTT-DEMO-A002"
    }
    if ($resolvedUsbPath -match "^[A-Za-z]:\\") {
        $driveRoot = "$($resolvedUsbPath.Substring(0, 2))\"
        if (-not (Test-Path $driveRoot)) {
            $fallbackUsbPath = Join-Path $PSScriptRoot "_usb_out\aSTT-DEMO-A002"
            Write-Host "WARNING: Drive '$driveRoot' not found. Using fallback: $fallbackUsbPath" -ForegroundColor Yellow
            $resolvedUsbPath = $fallbackUsbPath
        }
    }

    $releaseDir = Join-Path $RootPath "src-tauri\target\release"
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
            npm run tauri build
        }
        finally {
            Pop-Location
        }
    }

    if (-not (Test-Path $releaseDir)) {
        throw "Missing release folder: $releaseDir"
    }

    $cargoTomlPath = Join-Path $RootPath "src-tauri\Cargo.toml"
    if (-not (Test-Path $cargoTomlPath)) {
        throw "Missing Cargo.toml: $cargoTomlPath"
    }
    $cargoToml = Get-Content $cargoTomlPath -Raw
    $nameMatch = [regex]::Match($cargoToml, '(?m)^\s*name\s*=\s*"([^"]+)"')
    if (-not $nameMatch.Success) {
        throw "Cannot detect package name from $cargoTomlPath"
    }
    $packageName = $nameMatch.Groups[1].Value
    $primaryExePath = Join-Path $releaseDir "$packageName.exe"
    if (-not (Test-Path $primaryExePath)) {
        throw "Expected app exe missing: $primaryExePath"
    }
    $exe = Get-Item $primaryExePath

    New-Item -ItemType Directory -Path $demoDir -Force | Out-Null
    $demoExePath = Join-Path $demoDir "aSTT-demo.exe"
    Copy-Item $exe.FullName $demoExePath -Force
    Copy-Item (Join-Path $RootPath "sandbox\TestDocu_a002\README.md") (Join-Path $demoDir "README.md") -Force
    Copy-Item (Join-Path $RootPath "sandbox\TestDocu_a002\DEMO_A002_RUNBOOK_2026-02-28.md") (Join-Path $demoDir "RUNBOOK.md") -Force

    $buildInfo = @(
        "build_time_local=$(Get-Date -Format o)",
        "build_time_utc=$((Get-Date).ToUniversalTime().ToString('o'))",
        "root_path=$RootPath",
        "selected_exe=$($exe.FullName)",
        "selected_exe_last_write_utc=$($exe.LastWriteTimeUtc.ToString('o'))",
        "build_performed=$doBuild"
    ) -join [Environment]::NewLine
    Set-Content -Path (Join-Path $demoDir "BUILD_INFO.txt") -Value $buildInfo -Encoding ASCII

    $doSmokeTest = $SmokeTest -or $doBuild
    if ($doSmokeTest) {
        $p = Start-Process -FilePath $demoExePath -PassThru
        Start-Sleep -Seconds 5
        $alive = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
        if (-not $alive) {
            throw "Smoke test failed: aSTT-demo.exe exited immediately."
        }
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }

    $runCmd = @'
@echo off
cd /d "%~dp0"
start "" "aSTT-demo.exe"
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
