# enforce_next_session_flow.ps1
# Vynuceni toku zmen pro JSON-first / hybrid-strong NEXT_SESSION a traceability

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

function Invoke-RequiredCheck {
    param(
        [string]$Name,
        [string]$Script,
        [string[]]$Args = @()
    )
    Write-Host "Running required check: $Name" -ForegroundColor Cyan
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $Script @Args
    $exitCode = if ($LASTEXITCODE -is [int]) { [int]$LASTEXITCODE } else { 1 }
    if ($exitCode -ne 0) {
        Write-Host "ERROR: Required check failed: $Name" -ForegroundColor Red
        exit 1
    }
}

# 1) Validace traceability + NEXT_SESSION control dat musi projit.
Invoke-RequiredCheck -Name "Traceability validation" -Script "scripts/validate_traceability.ps1"
Invoke-RequiredCheck -Name "NEXT_SESSION validation" -Script "scripts/validate_next_session.ps1" -Args @("-SkipGeneratedFreshnessCheck")

# 2) Generated control docs musi byt aktualni.
Invoke-RequiredCheck -Name "Control docs stale-check" -Script "scripts/generate_control_docs.ps1" -Args @("-CheckOnly")

# 3) Pri zmenach canonical JSON/note musi byt ve stejnem commitu i generated view.
$staged = @(git diff --cached --name-only)
if ($staged.Count -eq 0) {
    exit 0
}

$nextInputsChanged = @($staged | Where-Object { $_ -in @("docs_control/next_session.json", "docs_control/next_session_note.md") }).Count -gt 0
$traceChanged = @($staged | Where-Object { $_ -eq "docs_control/traceability.json" }).Count -gt 0
$nextGeneratedChanged = @($staged | Where-Object { $_ -eq "docs/generated/control/NEXT_SESSION.md" }).Count -gt 0
$traceGeneratedChanged = @($staged | Where-Object { $_ -eq "docs/generated/control/TRACEABILITY_SUMMARY.md" }).Count -gt 0

if ($nextInputsChanged -and -not $nextGeneratedChanged) {
    Write-Host "ERROR: Zmena docs_control/next_session.json nebo docs_control/next_session_note.md vyzaduje staged update docs/generated/control/NEXT_SESSION.md." -ForegroundColor Red
    Write-Host "Spust: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/generate_control_docs.ps1" -ForegroundColor Yellow
    exit 1
}

if ($traceChanged -and -not $traceGeneratedChanged) {
    Write-Host "ERROR: Zmena docs_control/traceability.json vyzaduje staged update docs/generated/control/TRACEABILITY_SUMMARY.md." -ForegroundColor Red
    Write-Host "Spust: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/generate_control_docs.ps1" -ForegroundColor Yellow
    exit 1
}

exit 0
