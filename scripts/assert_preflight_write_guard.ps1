param(
    [string]$RootPath = ".",
    [int]$MaxAgeMinutes = 120,
    [string]$OperationName = "write operation"
)

$ErrorActionPreference = "Stop"

function Read-JsonFile {
    param([string]$PathValue)
    if (-not (Test-Path $PathValue)) {
        throw "Missing required file: $PathValue"
    }
    $raw = Get-Content -Path $PathValue -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Empty JSON file: $PathValue"
    }
    return ($raw | ConvertFrom-Json -Depth 100)
}

function Normalize-PathText {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    return (($Value -replace "\\", "/").TrimEnd("/"))
}

$repoRoot = (Resolve-Path $RootPath).Path
$repoRootNorm = Normalize-PathText -Value $repoRoot

$preflightPath = Join-Path $repoRoot "logs\verify\preflight_state.json"
$batchSummaryPath = Join-Path $repoRoot "logs\verify\batch_status_verify_summary.json"
$capabilitySummaryPath = Join-Path $repoRoot "logs\verify\capability_audit_summary.json"
$verifyManifestPath = Join-Path $repoRoot "docs_control\observed_workflow\verify_stage.json"
$ciManifestPath = Join-Path $repoRoot "docs_control\observed_workflow\ci_jobs.json"
$hooksManifestPath = Join-Path $repoRoot "docs_control\observed_workflow\hooks.json"

$preflight = Read-JsonFile -PathValue $preflightPath
$batch = Read-JsonFile -PathValue $batchSummaryPath
$capability = Read-JsonFile -PathValue $capabilitySummaryPath

$nowUtc = [DateTimeOffset]::UtcNow
$preflightMtime = ([DateTimeOffset](Get-Item $preflightPath).LastWriteTimeUtc).ToUniversalTime()
$batchMtime = ([DateTimeOffset](Get-Item $batchSummaryPath).LastWriteTimeUtc).ToUniversalTime()
$capabilityMtime = ([DateTimeOffset](Get-Item $capabilitySummaryPath).LastWriteTimeUtc).ToUniversalTime()

if ([int]$preflight.error_count -ne 0) {
    throw "Preflight guard failed: preflight_state.json has error_count=$($preflight.error_count). Run scripts/preflight_state_discovery.ps1 first."
}
if ([int]$batch.error_count -ne 0) {
    throw "Preflight guard failed: batch_status_verify_summary.json has error_count=$($batch.error_count). Run scripts/verify_batch_status.ps1 first."
}
if ([int]$capability.error_count -ne 0) {
    throw "Preflight guard failed: capability_audit_summary.json has error_count=$($capability.error_count). Run scripts/validate_capability_audit.ps1 first."
}

$preflightRootNorm = Normalize-PathText -Value ([string]$preflight.root_path)
$batchRootNorm = Normalize-PathText -Value ([string]$batch.root_path)
$capabilityRootNorm = Normalize-PathText -Value ([string]$capability.root_path)
if ($preflightRootNorm -and $preflightRootNorm -ne $repoRootNorm) {
    throw "Preflight guard failed: preflight root_path '$($preflight.root_path)' does not match current repo root '$repoRoot'."
}
if ($batchRootNorm -and $batchRootNorm -ne $repoRootNorm) {
    throw "Preflight guard failed: batch summary root_path '$($batch.root_path)' does not match current repo root '$repoRoot'."
}
if ($capabilityRootNorm -and $capabilityRootNorm -ne $repoRootNorm) {
    throw "Preflight guard failed: capability audit root_path '$($capability.root_path)' does not match current repo root '$repoRoot'."
}

$preflightAge = ($nowUtc - $preflightMtime).TotalMinutes
$batchAge = ($nowUtc - $batchMtime).TotalMinutes
$capabilityAge = ($nowUtc - $capabilityMtime).TotalMinutes
if ($preflightAge -gt $MaxAgeMinutes) {
    throw "Preflight guard failed: preflight_state.json is stale (${preflightAge:N1} min > $MaxAgeMinutes min). Run preflight again before $OperationName."
}
if ($batchAge -gt $MaxAgeMinutes) {
    throw "Preflight guard failed: batch_status_verify_summary.json is stale (${batchAge:N1} min > $MaxAgeMinutes min). Run batch status verify again before $OperationName."
}
if ($capabilityAge -gt $MaxAgeMinutes) {
    throw "Preflight guard failed: capability_audit_summary.json is stale (${capabilityAge:N1} min > $MaxAgeMinutes min). Run capability audit again before $OperationName."
}

if ($batchMtime -lt $preflightMtime) {
    throw "Preflight guard failed: batch_status_verify_summary.json is older than preflight_state.json. Expected order: preflight -> batch verify -> $OperationName."
}
if ($capabilityMtime -gt $preflightMtime) {
    throw "Preflight guard failed: capability_audit_summary.json is newer than preflight_state.json. Expected order: capability audit -> preflight -> batch verify -> $OperationName."
}

$manifestPaths = @($verifyManifestPath, $ciManifestPath, $hooksManifestPath)
$latestManifestTime = [DateTimeOffset]::MinValue
foreach ($manifest in $manifestPaths) {
    if (-not (Test-Path $manifest)) {
        throw "Preflight guard failed: missing observed manifest '$manifest'. Run workflow control alignment refresh first."
    }
    $mtime = ([DateTimeOffset](Get-Item $manifest).LastWriteTimeUtc).ToUniversalTime()
    if ($mtime -gt $latestManifestTime) { $latestManifestTime = $mtime }
    $manifestAge = ($nowUtc - $mtime).TotalMinutes
    if ($manifestAge -gt $MaxAgeMinutes) {
        throw "Preflight guard failed: observed manifest '$manifest' is stale (${manifestAge:N1} min > $MaxAgeMinutes min). Run workflow control alignment refresh first."
    }
}

$allowedSkewMinutes = 5
if ($preflightMtime -lt $latestManifestTime.AddMinutes(-$allowedSkewMinutes)) {
    throw "Preflight guard failed: preflight is older than observed manifests (sequence drift). Expected indexation/alignment before preflight."
}
if ($capabilityMtime -lt $latestManifestTime.AddMinutes(-$allowedSkewMinutes)) {
    throw "Preflight guard failed: capability audit is older than observed manifests (sequence drift). Expected indexation/alignment before capability audit."
}

Write-Host "PASS: preflight write guard ($OperationName) [max_age=${MaxAgeMinutes}m]" -ForegroundColor Green
exit 0
