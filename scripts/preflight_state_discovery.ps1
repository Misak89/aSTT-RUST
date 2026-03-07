param(
    [string]$RootPath = ".",
    [string]$OutputJsonPath = "logs/verify/preflight_state.json",
    [string[]]$BatchId = @()
)

$ErrorActionPreference = "Stop"

$verifyScript = Join-Path $PSScriptRoot "verify_batch_status.ps1"
if (-not (Test-Path $verifyScript)) {
    Write-Error "Missing script: $verifyScript"
}

$args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $verifyScript,
    "-RootPath", $RootPath,
    "-OutputJsonPath", $OutputJsonPath,
    "-ReportOnly"
)

foreach ($id in @($BatchId)) {
    if (-not [string]::IsNullOrWhiteSpace([string]$id)) {
        $args += @("-BatchId", [string]$id)
    }
}

& pwsh @args
exit $LASTEXITCODE
