param(
    [string]$RootPath = "."
)

$ErrorActionPreference = "Stop"
Push-Location $RootPath
try {
    npm run check
    npm run build
    node --check electron/main.cjs
    node --check electron/preload.cjs
    node --check electron/commands.cjs
    node --check electron/sidecar-manager.cjs
    node --check electron/dev-runner.mjs
    node --check electron/launch-main.mjs
    node --check electron/pack-offline.mjs
    npm run electron:pack
    Write-Host "DEMO_A003_TEST_PASS" -ForegroundColor Green
}
finally {
    Pop-Location
}
