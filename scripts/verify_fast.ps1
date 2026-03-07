param(
    [string]$RootPath = "",
    [string]$TaskId = "",
    [string]$Scope = "repo",
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

$stageScript = Join-Path $PSScriptRoot "verify_stage.ps1"
if (-not (Test-Path $stageScript)) {
    Write-Error "Missing script: $stageScript"
}

$args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $stageScript,
    "-Stage", "fast"
)
if ($RootPath) { $args += @("-RootPath", $RootPath) }
if ($TaskId) { $args += @("-TaskId", $TaskId) }
if ($Scope) { $args += @("-Scope", $Scope) }
if ($IncludeLinkAudit) { $args += "-IncludeLinkAudit" }
if ($SkipMkDocsBuild) { $args += "-SkipMkDocsBuild" }
if ($SkipDocsChecks) { $args += "-SkipDocsChecks" }
if ($SkipNodeChecks) { $args += "-SkipNodeChecks" }
if ($SkipRustChecks) { $args += "-SkipRustChecks" }
if ($SkipLog) { $args += "-SkipLog" }
if ($SkipRender) { $args += "-SkipRender" }
if ($DryRun) { $args += "-DryRun" }

& pwsh @args
exit $LASTEXITCODE
