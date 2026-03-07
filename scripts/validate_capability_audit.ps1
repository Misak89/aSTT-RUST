param(
    [string]$RootPath = ".",
    [string]$CanonicalPath = "docs_control/capability_audit.json",
    [string]$SchemaPath = "docs_control/capability_audit.schema.json",
    [string]$ToolOutputJsonPath = "logs/verify/toolchain_capabilities.json",
    [string]$SummaryOutputJsonPath = "logs/verify/capability_audit_summary.json",
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"
$script:Errors = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR","SUCCESS")]
        [string]$Level = "INFO"
    )
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    if ($DetailedOutput -or $Level -in @("WARN","ERROR","SUCCESS")) {
        Write-Host $Message -ForegroundColor $color
    }
}

function Add-Error { param([string]$Message) $script:Errors.Add($Message); Write-Log "ERROR: $Message" "ERROR" }
function Add-Warn { param([string]$Message) $script:Warnings.Add($Message); Write-Log "WARN: $Message" "WARN" }

function Resolve-RepoPath {
    param([string]$PathValue)
    return (Join-Path $RootPath $PathValue)
}

function Ensure-ParentDirectory {
    param([string]$PathValue)
    $parent = Split-Path -Parent $PathValue
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Write-JsonFile {
    param(
        [string]$PathValue,
        [object]$Value,
        [int]$Depth = 20
    )
    Ensure-ParentDirectory -PathValue $PathValue
    $json = $Value | ConvertTo-Json -Depth $Depth
    Set-Content -Path $PathValue -Value $json -Encoding UTF8
}

function To-Array {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable]) { return @($Value) }
    return @($Value)
}

function Get-Prop {
    param([object]$Obj, [string]$Name, [object]$Default = $null)
    if ($null -eq $Obj) { return $Default }
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    return $p.Value
}

function Get-String {
    param([object]$Obj, [string]$Name, [string]$Default = "")
    $value = Get-Prop -Obj $Obj -Name $Name -Default $Default
    if ($null -eq $value) { return $Default }
    return [string]$value
}

function Test-SchemaValidationAvailable {
    try {
        $cmd = Get-Command Test-Json -ErrorAction Stop
        return ($cmd.Parameters.ContainsKey("SchemaFile"))
    }
    catch {
        return $false
    }
}

function Get-FirstNonEmptyLine {
    param([string[]]$Lines)
    foreach ($line in @($Lines)) {
        $text = [string]$line
        if (-not [string]::IsNullOrWhiteSpace($text)) { return $text.Trim() }
    }
    return ""
}

function Resolve-CommandCandidate {
    param([string]$Candidate)

    $text = [string]$Candidate
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }

    $looksLikePath = ($text -match '^[A-Za-z]:[\\/]') -or $text.Contains('\') -or $text.Contains('/')
    if ($looksLikePath) {
        $full = if ([System.IO.Path]::IsPathRooted($text)) { $text } else { Join-Path $RootPath $text }
        if (Test-Path $full -PathType Leaf) {
            return (Resolve-Path $full).Path
        }
        return $null
    }

    $cmd = Get-Command $text -ErrorAction SilentlyContinue
    if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
        return $cmd.Source
    }
    return $null
}

function Invoke-VersionProbe {
    param(
        [string]$Executable,
        [string[]]$Args
    )

    try {
        $raw = & $Executable @Args 2>&1
        $lines = @($raw | ForEach-Object { [string]$_ })
        return [pscustomobject]@{
            success = ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE)
            exit_code = if ($LASTEXITCODE -is [int]) { [int]$LASTEXITCODE } else { 0 }
            version_text = (Get-FirstNonEmptyLine -Lines $lines)
            output_lines = @($lines)
        }
    }
    catch {
        return [pscustomobject]@{
            success = $false
            exit_code = 1
            version_text = [string]$_.Exception.Message
            output_lines = @([string]$_.Exception.Message)
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Capability Audit Gate v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$canonicalFull = Resolve-RepoPath -PathValue $CanonicalPath
$schemaFull = Resolve-RepoPath -PathValue $SchemaPath
$toolOutputFull = Resolve-RepoPath -PathValue $ToolOutputJsonPath
$summaryOutputFull = Resolve-RepoPath -PathValue $SummaryOutputJsonPath

if (-not (Test-Path $canonicalFull)) { Add-Error "Missing capability audit registry: $CanonicalPath" }
if (-not (Test-Path $schemaFull)) { Add-Error "Missing capability audit schema: $SchemaPath" }
if ($script:Errors.Count -gt 0) { exit 1 }

$raw = Get-Content -Path $canonicalFull -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($raw)) {
    Add-Error "Capability audit registry is empty: $CanonicalPath"
    exit 1
}

if (Test-SchemaValidationAvailable) {
    try {
        $schemaOk = Test-Json -Json $raw -SchemaFile $schemaFull -ErrorAction Stop
        if ($schemaOk) {
            Write-Log -Message "PASS: capability audit JSON schema validation" -Level "SUCCESS"
        } else {
            Add-Error "JSON schema validation failed for $CanonicalPath"
        }
    }
    catch {
        Add-Error "JSON schema validation error: $($_.Exception.Message)"
    }
} else {
    Add-Warn "Test-Json -SchemaFile unavailable; schema validation skipped."
}

try {
    $data = $raw | ConvertFrom-Json -Depth 100
}
catch {
    Add-Error "Invalid JSON syntax in ${CanonicalPath}: $($_.Exception.Message)"
    exit 1
}

$schemaVersion = Get-String -Obj $data -Name "schema_version"
if ($schemaVersion -ne "1.0") { Add-Error "Unsupported schema_version '$schemaVersion' (expected 1.0)" }

$sourceOfTruth = Get-String -Obj $data -Name "source_of_truth"
if ($sourceOfTruth -ne "docs_control/capability_audit.json") {
    Add-Error "source_of_truth must be docs_control/capability_audit.json (found '$sourceOfTruth')"
}

$model = Get-Prop -Obj $data -Name "model"
$modelStatus = (Get-String -Obj $model -Name "status").ToUpperInvariant()
if ($modelStatus -notin @("DRAFT","APPROVED","DEPRECATED")) {
    Add-Error "model.status '$modelStatus' is invalid"
}

$tools = @((To-Array (Get-Prop -Obj $data -Name "tools" -Default @())) | Sort-Object @{ Expression = { [int](Get-Prop -Obj $_ -Name "order_index" -Default 0) } }, @{ Expression = { Get-String -Obj $_ -Name "tool_id" } })
$claims = @((To-Array (Get-Prop -Obj $data -Name "claims" -Default @())) | Sort-Object @{ Expression = { [int](Get-Prop -Obj $_ -Name "order_index" -Default 0) } }, @{ Expression = { Get-String -Obj $_ -Name "claim_id" } })

$toolById = @{}
$toolIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($tool in $tools) {
    $toolId = Get-String -Obj $tool -Name "tool_id"
    if ([string]::IsNullOrWhiteSpace($toolId)) { Add-Error "tools[] entry missing tool_id"; continue }
    if (-not $toolIds.Add($toolId)) { Add-Error "Duplicate tool_id '$toolId'"; continue }
    $toolById[$toolId] = $tool
}

$observedTools = @()
foreach ($tool in $tools) {
    $toolId = Get-String -Obj $tool -Name "tool_id"
    if ([string]::IsNullOrWhiteSpace($toolId)) { continue }
    $label = Get-String -Obj $tool -Name "label"
    $versionArgs = @((To-Array (Get-Prop -Obj $tool -Name "version_args" -Default @("--version"))) | ForEach-Object { [string]$_ })
    if ($versionArgs.Count -eq 0) { $versionArgs = @("--version") }
    $versionPinRegex = Get-String -Obj $tool -Name "version_pin_regex"
    $versionPinEnforcement = (Get-String -Obj $tool -Name "version_pin_enforcement" -Default "warn").ToLowerInvariant()
    if ($versionPinEnforcement -notin @("warn","error")) { $versionPinEnforcement = "warn" }

    $candidates = @((To-Array (Get-Prop -Obj $tool -Name "command_candidates" -Default @())) | ForEach-Object { [string]$_ })
    $candidateResults = @()
    $resolved = $null
    foreach ($candidate in $candidates) {
        $resolvedCandidate = Resolve-CommandCandidate -Candidate $candidate
        $candidateResults += [pscustomobject][ordered]@{
                candidate = $candidate
                found = [bool]($null -ne $resolvedCandidate)
                resolved = if ($null -ne $resolvedCandidate) { [string]$resolvedCandidate } else { $null }
            }
        if ($null -eq $resolved -and $null -ne $resolvedCandidate) {
            $resolved = [string]$resolvedCandidate
        }
    }

    $probe = $null
    if ($null -ne $resolved) {
        $probe = Invoke-VersionProbe -Executable $resolved -Args $versionArgs
    }

    if ($null -eq $resolved) {
        Add-Warn "Tool '$toolId' not found locally (capability claim may remain source-only)."
    } elseif ($null -eq $probe -or -not [bool]$probe.success) {
        Add-Warn "Tool '$toolId' found but version probe failed."
    } elseif (-not [string]::IsNullOrWhiteSpace($versionPinRegex)) {
        $probeVersionTextRaw = [string](Get-Prop -Obj $probe -Name "version_text" -Default "")
        $versionPinMatched = $false
        try {
            $versionPinMatched = ($probeVersionTextRaw -match $versionPinRegex)
        }
        catch {
            Add-Error "Tool '$toolId' has invalid version_pin_regex '$versionPinRegex'"
        }
        if (-not $versionPinMatched) {
            $msg = "Tool '$toolId' version '$probeVersionTextRaw' does not match pinned regex '$versionPinRegex'"
            if ($versionPinEnforcement -eq "error") {
                Add-Error $msg
            } else {
                Add-Warn $msg
            }
        }
    }

    $resolvedCommandValue = $null
    if ($null -ne $resolved) { $resolvedCommandValue = [string]$resolved }

    $probeExitCode = $null
    $probeSuccess = $false
    $probeVersionText = $null
    if ($null -ne $probe) {
        $probeSuccess = [bool](Get-Prop -Obj $probe -Name "success" -Default $false)
        $probeVersionText = [string](Get-Prop -Obj $probe -Name "version_text" -Default "")
        $probeExitCodeRaw = Get-Prop -Obj $probe -Name "exit_code" -Default $null
        if ($null -ne $probeExitCodeRaw) {
            $probeExitCode = [int]$probeExitCodeRaw
        }
    }

    $versionPinMatchedValue = $null
    if (-not [string]::IsNullOrWhiteSpace($versionPinRegex) -and $probeSuccess -and -not [string]::IsNullOrWhiteSpace($probeVersionText)) {
        try {
            $versionPinMatchedValue = [bool]($probeVersionText -match $versionPinRegex)
        }
        catch {
            $versionPinMatchedValue = $false
        }
    }

    $observedTools += [pscustomobject][ordered]@{
            tool_id = $toolId
            label = $label
            found = [bool]($null -ne $resolved)
            resolved_command = $resolvedCommandValue
            version_args = @($versionArgs)
            version_text = $probeVersionText
            version_probe_success = $probeSuccess
            version_probe_exit_code = $probeExitCode
            version_pin_regex = if (-not [string]::IsNullOrWhiteSpace($versionPinRegex)) { $versionPinRegex } else { $null }
            version_pin_enforcement = if (-not [string]::IsNullOrWhiteSpace($versionPinRegex)) { $versionPinEnforcement } else { $null }
            version_pin_matched = $versionPinMatchedValue
            candidates = @($candidateResults)
        }
}

$toolSnapshot = [pscustomobject][ordered]@{
    schema_version = "1.0"
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    root_path = (Resolve-Path $RootPath).Path
    source_registry = $CanonicalPath
    tools = @($observedTools)
}
Write-JsonFile -PathValue $toolOutputFull -Value $toolSnapshot -Depth 50

$officialKinds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
[void]$officialKinds.Add("official_docs")
[void]$officialKinds.Add("official_gallery")
[void]$officialKinds.Add("official_repo")

$claimIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$claimCounts = @{
    total = 0
    verified = 0
    unknown = 0
    deprecated = 0
    used_for_decisions = 0
}

foreach ($claim in $claims) {
    $claimCounts.total++
    $claimId = Get-String -Obj $claim -Name "claim_id"
    $toolId = Get-String -Obj $claim -Name "tool_id"
    $status = (Get-String -Obj $claim -Name "status").ToLowerInvariant()
    $usedForDecisions = [bool](Get-Prop -Obj $claim -Name "used_for_decisions" -Default $false)
    $localObservationRequired = [bool](Get-Prop -Obj $claim -Name "local_observation_required" -Default $false)

    if ([string]::IsNullOrWhiteSpace($claimId)) {
        Add-Error "claims[] entry missing claim_id"
        continue
    }
    if (-not $claimIds.Add($claimId)) {
        Add-Error "Duplicate claim_id '$claimId'"
        continue
    }
    if (-not $toolById.ContainsKey($toolId)) {
        Add-Error "claims[$claimId] references missing tool_id '$toolId'"
    }

    if ($claimCounts.ContainsKey($status)) {
        $claimCounts[$status] = [int]$claimCounts[$status] + 1
    }
    if ($usedForDecisions) { $claimCounts.used_for_decisions = [int]$claimCounts.used_for_decisions + 1 }

    $sources = @(To-Array (Get-Prop -Obj $claim -Name "sources" -Default @()))
    $hasOfficialSource = $false
    foreach ($source in $sources) {
        $kind = (Get-String -Obj $source -Name "kind").ToLowerInvariant()
        $url = Get-String -Obj $source -Name "url"
        if ($officialKinds.Contains($kind)) { $hasOfficialSource = $true }
        if ($kind -in @("official_docs","official_gallery","official_repo")) {
            if ([string]::IsNullOrWhiteSpace($url)) {
                Add-Error "claims[$claimId] source '$kind' missing url"
            } elseif (-not ($url -match '^https://')) {
                Add-Error "claims[$claimId] source '$kind' url must use https:// ($url)"
            }
        }
    }

    if ($status -eq "verified") {
        if ($sources.Count -eq 0) {
            Add-Error "claims[$claimId] is verified but has no sources"
        }
        if (-not $hasOfficialSource) {
            Add-Error "claims[$claimId] is verified but has no official source (docs/gallery/repo)"
        }
    }

    if ($usedForDecisions -and $status -ne "verified") {
        Add-Error "claims[$claimId] is used_for_decisions=true but status='$status' (must be verified)"
    }

    if ($usedForDecisions -and $localObservationRequired) {
        $obs = @($observedTools | Where-Object { (Get-String -Obj $_ -Name "tool_id") -eq $toolId } | Select-Object -First 1)
        if ($obs.Count -eq 0 -or -not [bool](Get-Prop -Obj $obs[0] -Name "found" -Default $false)) {
            Add-Error "claims[$claimId] requires local tool observation, but tool '$toolId' was not found"
        }
    }
}

$toolCounts = @{
    total = $observedTools.Count
    found = (@($observedTools | Where-Object { [bool](Get-Prop -Obj $_ -Name "found" -Default $false) })).Count
    missing = (@($observedTools | Where-Object { -not [bool](Get-Prop -Obj $_ -Name "found" -Default $false) })).Count
}

$summary = [pscustomobject][ordered]@{
    schema_version = "1.0"
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    root_path = (Resolve-Path $RootPath).Path
    registry_path = ($CanonicalPath -replace '\\', '/')
    schema_path = ($SchemaPath -replace '\\', '/')
    tool_observation_path = ($ToolOutputJsonPath -replace '\\', '/')
    error_count = [int]$script:Errors.Count
    warning_count = [int]$script:Warnings.Count
    model_status = $modelStatus
    tool_counts = [pscustomobject]$toolCounts
    claim_counts = [pscustomobject]$claimCounts
    errors = @($script:Errors)
    warnings = @($script:Warnings)
}
Write-JsonFile -PathValue $summaryOutputFull -Value $summary -Depth 50

if ($script:Errors.Count -eq 0) {
    Write-Log -Message ("PASS: capability audit validated (claims={0}, tools_found={1}/{2}, warnings={3})" -f $claimCounts.total, $toolCounts.found, $toolCounts.total, $script:Warnings.Count) -Level "SUCCESS"
    exit 0
}

Write-Host "FAIL: capability audit failed with $($script:Errors.Count) error(s)." -ForegroundColor Red
exit 1
