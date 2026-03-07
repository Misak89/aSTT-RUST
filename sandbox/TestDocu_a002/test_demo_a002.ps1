param(
    [string]$RootPath = "."
)

$ErrorActionPreference = "Stop"
Push-Location $RootPath
try {
    npm run check
    npm run build
    Write-Host "DEMO_A002_TEST_PASS" -ForegroundColor Green
}
finally {
    Pop-Location
}
