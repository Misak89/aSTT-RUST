param(
    [string]$RootPath = "",
    [string]$TaskId = "",
    [string]$Scope = "repo",
    [switch]$SkipFastGate,
    [switch]$IncludeLinkAudit,
    [switch]$SkipMkDocsBuild,
    [switch]$SkipDocsChecks,
    [switch]$SkipNodeChecks,
    [switch]$SkipRustChecks,
    [switch]$SkipLog,
    [switch]$SkipRender,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if (-not $RootPath) {
    $RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
if (-not $TaskId) {
    $TaskId = "verify-full-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
}

$fastScript = Join-Path $PSScriptRoot "verify_fast.ps1"
$stageScript = Join-Path $PSScriptRoot "verify_stage.ps1"
$logScript = Join-Path $PSScriptRoot "log_verify_run.ps1"

if (-not (Test-Path $fastScript)) { Write-Error "Missing script: $fastScript" }
if (-not (Test-Path $stageScript)) { Write-Error "Missing script: $stageScript" }

if (-not $SkipFastGate) {
    Write-Host "Running verify_fast before verify_full (source of truth gate)." -ForegroundColor Cyan
    $fastArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $fastScript,
        "-RootPath", $RootPath,
        "-TaskId", $TaskId,
        "-Scope", $Scope
    )
    if ($IncludeLinkAudit) { $fastArgs += "-IncludeLinkAudit" }
    if ($SkipMkDocsBuild) { $fastArgs += "-SkipMkDocsBuild" }
    if ($SkipDocsChecks) { $fastArgs += "-SkipDocsChecks" }
    if ($SkipNodeChecks) { $fastArgs += "-SkipNodeChecks" }
    if ($SkipRustChecks) { $fastArgs += "-SkipRustChecks" }
    if ($SkipLog) { $fastArgs += "-SkipLog" }
    if ($SkipRender) { $fastArgs += "-SkipRender" }
    if ($DryRun) { $fastArgs += "-DryRun" }

    & pwsh @fastArgs
    $fastExit = if ($LASTEXITCODE -is [int]) { [int]$LASTEXITCODE } else { 1 }

    if ($fastExit -ne 0) {
        Write-Host "verify_full blocked: verify_fast did not PASS." -ForegroundColor Yellow

        if (-not $SkipLog -and (Test-Path $logScript)) {
            $steps = @(
                [pscustomobject][ordered]@{
                    name = "verify_fast gate"
                    tool = "verify"
                    command = "scripts/verify_fast.ps1"
                    status = "SKIP"
                    duration_ms = 0
                    exit_code = $fastExit
                }
            )
            $errors = @(
                [pscustomobject][ordered]@{
                    tool = "verify"
                    type = "gate"
                    file = "scripts/verify_fast.ps1"
                    rule = "verify_fast_required"
                    line = $null
                    step_index = 1
                    message = "verify_full skipped because verify_fast failed"
                }
            )
            $evidence = @()

            $logArgs = @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-File", $logScript,
                "-RootPath", $RootPath,
                "-TaskId", $TaskId,
                "-Stage", "full",
                "-Scope", $Scope,
                "-Status", "SKIP",
                "-StepsJson", ($steps | ConvertTo-Json -Depth 10 -Compress),
                "-ErrorsJson", ($errors | ConvertTo-Json -Depth 10 -Compress),
                "-EvidenceRefsJson", ($evidence | ConvertTo-Json -Depth 5 -Compress)
            )
            if ($SkipRender) { $logArgs += "-SkipRender" }
            & pwsh @logArgs
        }

        exit $fastExit
    }
}

$fullArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $stageScript,
    "-Stage", "full",
    "-RootPath", $RootPath,
    "-TaskId", $TaskId,
    "-Scope", $Scope
)
if ($SkipNodeChecks) { $fullArgs += "-SkipNodeChecks" }
if ($SkipRustChecks) { $fullArgs += "-SkipRustChecks" }
if ($SkipLog) { $fullArgs += "-SkipLog" }
if ($SkipRender) { $fullArgs += "-SkipRender" }
if ($DryRun) { $fullArgs += "-DryRun" }

& pwsh @fullArgs
exit $LASTEXITCODE
