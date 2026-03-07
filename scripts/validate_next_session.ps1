param(
    [string]$RootPath = ".",
    [string]$CanonicalPath = "docs_control/next_session.json",
    [string]$SchemaPath = "docs_control/next_session.schema.json",
    [string]$NotePath = "docs_control/next_session_note.md",
    [string]$GeneratedViewPath = "docs/generated/control/NEXT_SESSION.md",
    [switch]$SkipGeneratedFreshnessCheck,
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"
$script:Errors = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    if ($DetailedOutput -or $Level -in @("ERROR", "WARN", "SUCCESS")) {
        Write-Host $Message -ForegroundColor $color
    }
}

function Add-Error {
    param([string]$Message)
    $script:Errors.Add($Message)
    Write-Log -Message "ERROR: $Message" -Level "ERROR"
}

function Add-Warn {
    param([string]$Message)
    $script:Warnings.Add($Message)
    Write-Log -Message "WARN: $Message" -Level "WARN"
}

function Resolve-RepoPath {
    param([string]$PathValue)
    return (Join-Path $RootPath $PathValue)
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

function To-Array {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable]) { return @($Value) }
    return @($Value)
}

function Get-PropValue {
    param(
        [object]$Obj,
        [string]$Name,
        [object]$Default = $null
    )
    if ($null -eq $Obj) { return $Default }
    $prop = $Obj.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value) { return $Default }
    return $prop.Value
}

function Get-StringValue {
    param(
        [object]$Obj,
        [string]$Name,
        [string]$Default = ""
    )
    $value = Get-PropValue -Obj $Obj -Name $Name -Default $Default
    if ($null -eq $value) { return $Default }
    return [string]$value
}

function Validate-RequiredString {
    param(
        [object]$Obj,
        [string]$FieldName,
        [string]$Context
    )
    $text = Get-StringValue -Obj $Obj -Name $FieldName
    if ([string]::IsNullOrWhiteSpace($text)) {
        Add-Error "$Context missing required string '$FieldName'"
        return $false
    }
    return $true
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  NEXT_SESSION Validator v3.0 (JSON-first)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$canonicalFull = Resolve-RepoPath -PathValue $CanonicalPath
$schemaFull = Resolve-RepoPath -PathValue $SchemaPath
$noteFull = Resolve-RepoPath -PathValue $NotePath
$generatedFull = Resolve-RepoPath -PathValue $GeneratedViewPath

foreach ($path in @(
        @{ Label = "Canonical NEXT_SESSION JSON"; Rel = $CanonicalPath; Full = $canonicalFull },
        @{ Label = "NEXT_SESSION schema"; Rel = $SchemaPath; Full = $schemaFull },
        @{ Label = "NEXT_SESSION narrative note"; Rel = $NotePath; Full = $noteFull }
    )) {
    if (-not (Test-Path $path.Full)) {
        Add-Error "Missing $($path.Label): $($path.Rel)"
    }
}
if ($script:Errors.Count -gt 0) { exit 1 }

$raw = Get-Content -Path $canonicalFull -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($raw)) {
    Add-Error "Canonical NEXT_SESSION JSON is empty: $CanonicalPath"
    exit 1
}

if (Test-SchemaValidationAvailable) {
    try {
        $schemaOk = Test-Json -Json $raw -SchemaFile $schemaFull -ErrorAction Stop
        if ($schemaOk) {
            Write-Log -Message "PASS: JSON schema validation" -Level "SUCCESS"
        }
        else {
            Add-Error "JSON schema validation failed for $CanonicalPath"
        }
    }
    catch {
        Add-Error "JSON schema validation error: $($_.Exception.Message)"
    }
}
else {
    Add-Warn "Test-Json -SchemaFile unavailable; running structural checks only."
}

try {
    $data = $raw | ConvertFrom-Json -Depth 100
}
catch {
    Add-Error "Invalid JSON syntax in ${CanonicalPath}: $($_.Exception.Message)"
    exit 1
}

$schemaVersion = Get-StringValue -Obj $data -Name "schema_version"
if ($schemaVersion -ne "1.0") {
    Add-Error "Unsupported schema_version '$schemaVersion' (expected 1.0)"
}

$sourceOfTruth = Get-StringValue -Obj $data -Name "source_of_truth"
if ($sourceOfTruth -ne "docs_control/next_session.json") {
    Add-Warn "source_of_truth is '$sourceOfTruth' (expected docs_control/next_session.json)"
}

$doc = Get-PropValue -Obj $data -Name "document" -Default $null
if ($null -eq $doc) {
    Add-Error "Missing 'document' object"
}
else {
    foreach ($field in @("title", "path", "version", "created_at", "updated_at", "status_text")) {
        [void](Validate-RequiredString -Obj $doc -FieldName $field -Context "document")
    }
}

$lifecycleState = Get-StringValue -Obj $data -Name "lifecycle_state"
$allowedStates = @("NEPROVEDENO", "ROZPRACOVANE", "PLANNED", "IMPLEMENTED", "HOTOVO", "DOKONCENO")
if ($allowedStates -notcontains $lifecycleState) {
    Add-Error "Invalid lifecycle_state '$lifecycleState'"
}
else {
    Write-Log -Message "PASS: lifecycle_state = $lifecycleState" -Level "SUCCESS"
}

$state = Get-PropValue -Obj $data -Name "state_realization" -Default $null
if ($null -eq $state) {
    Add-Error "Missing 'state_realization' object"
}
else {
    foreach ($name in @("neprovedeno", "rozpracovane", "provedeno")) {
        $items = To-Array (Get-PropValue -Obj $state -Name $name -Default @())
        foreach ($item in $items) {
            [void](Validate-RequiredString -Obj $item -FieldName "item_id" -Context "state_realization.$name[]")
            [void](Validate-RequiredString -Obj $item -FieldName "text" -Context "state_realization.$name[]")
        }
    }
    [void](Validate-RequiredString -Obj $state -FieldName "poznamka" -Context "state_realization")
}

$ctx = Get-PropValue -Obj $data -Name "current_context" -Default $null
if ($null -eq $ctx) {
    Add-Error "Missing 'current_context' object"
}
else {
    [void](Validate-RequiredString -Obj $ctx -FieldName "summary" -Context "current_context")
    if ((To-Array (Get-PropValue -Obj $ctx -Name "hotovo" -Default @())).Count -eq 0) {
        Add-Warn "current_context.hotovo is empty"
    }
    if ((To-Array (Get-PropValue -Obj $ctx -Name "kriticky_problem" -Default @())).Count -eq 0) {
        Add-Warn "current_context.kriticky_problem is empty"
    }
}

$nextSteps = To-Array (Get-PropValue -Obj $data -Name "next_steps" -Default @())
if ($nextSteps.Count -eq 0) {
    Add-Error "next_steps must contain at least one step"
}
else {
    $ids = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($step in $nextSteps) {
        $stepId = Get-StringValue -Obj $step -Name "step_id"
        $title = Get-StringValue -Obj $step -Name "title"
        $actions = To-Array (Get-PropValue -Obj $step -Name "actions" -Default @())
        if ([string]::IsNullOrWhiteSpace($stepId)) { Add-Error "next_steps[] missing step_id" }
        elseif (-not $ids.Add($stepId)) { Add-Error "next_steps duplicate step_id '$stepId'" }
        if ([string]::IsNullOrWhiteSpace($title)) { Add-Error "next_steps[$stepId] missing title" }
        if ($actions.Count -eq 0) { Add-Error "next_steps[$stepId] must have at least one action" }
    }
}

$checkpoint = Get-PropValue -Obj $data -Name "workflow_alignment_checkpoint" -Default $null
if ($null -eq $checkpoint) {
    Add-Error "Missing 'workflow_alignment_checkpoint' object"
}
else {
    foreach ($field in @("hook", "ci", "docs")) {
        $values = To-Array (Get-PropValue -Obj $checkpoint -Name $field -Default @())
        if ($values.Count -eq 0) {
            Add-Error "workflow_alignment_checkpoint.$field must not be empty"
        }
    }
}

$policy = Get-PropValue -Obj $data -Name "evidence_policy" -Default ([pscustomobject]@{})
$requiredEvidenceForImplemented = To-Array (Get-PropValue -Obj $policy -Name "implemented_requires" -Default @())
$evidence = To-Array (Get-PropValue -Obj $data -Name "evidence" -Default @())

$evidenceIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($ev in $evidence) {
    $id = Get-StringValue -Obj $ev -Name "evidence_id"
    if ([string]::IsNullOrWhiteSpace($id)) {
        Add-Error "evidence[] missing evidence_id"
        continue
    }
    if (-not $evidenceIds.Add($id)) {
        Add-Error "Duplicate evidence_id '$id'"
    }
    [void](Validate-RequiredString -Obj $ev -FieldName "kind" -Context "evidence[$id]")
    [void](Validate-RequiredString -Obj $ev -FieldName "result" -Context "evidence[$id]")
    [void](Validate-RequiredString -Obj $ev -FieldName "source" -Context "evidence[$id]")
}

$refs = Get-PropValue -Obj $data -Name "traceability_refs" -Default ([pscustomobject]@{})
$refEvidenceIds = To-Array (Get-PropValue -Obj $refs -Name "evidence_ids" -Default @())
foreach ($id in $refEvidenceIds) {
    $idText = [string]$id
    if ([string]::IsNullOrWhiteSpace($idText)) {
        Add-Error "traceability_refs.evidence_ids contains empty item"
        continue
    }
    if (-not $evidenceIds.Contains($idText)) {
        Add-Error "traceability_refs.evidence_ids references missing evidence_id '$idText'"
    }
}

$terminalStates = @("IMPLEMENTED", "HOTOVO", "DOKONCENO")
if ($terminalStates -contains $lifecycleState) {
    if ($requiredEvidenceForImplemented.Count -eq 0) {
        Add-Error "Terminal lifecycle_state '$lifecycleState' requires evidence_policy.implemented_requires"
    }
    foreach ($req in $requiredEvidenceForImplemented) {
        $reqText = [string]$req
        $match = @($evidence | Where-Object {
                (Get-StringValue -Obj $_ -Name "requirement_id") -eq $reqText -and (Get-StringValue -Obj $_ -Name "result") -eq "PASS"
            })
        if ($match.Count -eq 0) {
            Add-Error "Terminal lifecycle_state '$lifecycleState' missing PASS evidence for requirement '$reqText'"
        }
    }
}

$noteText = Get-Content -Path $noteFull -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($noteText)) {
    Add-Warn "Narrative note is empty: $NotePath"
}

$forbiddenPatterns = @(
    @{ Name = "Checkbox checklist"; Pattern = "(?m)^\s*-\s*\[[ xX]\]" },
    @{ Name = "Stav realizace section"; Pattern = "(?im)^##\s*.*Stav realizace" },
    @{ Name = "Neprovedeno subsection"; Pattern = "(?im)^###\s*Neprovedeno" },
    @{ Name = "Rozpracovane subsection"; Pattern = "(?im)^###\s*Rozpracovane" },
    @{ Name = "Provedeno subsection"; Pattern = "(?im)^###\s*Provedeno" },
    @{ Name = "Control metadata fields"; Pattern = "\*\*(Cesta|Verze|Vytvoreno|Posledni zmena|Status):\*\*" }
)
foreach ($rule in $forbiddenPatterns) {
    if ($noteText -match $rule.Pattern) {
        Add-Error "Narrative note contains forbidden control content: $($rule.Name)"
    }
}

if (-not (Test-Path $generatedFull)) {
    Add-Error "Missing generated NEXT_SESSION view: $GeneratedViewPath"
}
else {
    $generatedText = Get-Content -Path $generatedFull -Raw -Encoding UTF8
    if (-not ($generatedText -match "Checkpoint \(workflow alignment\)")) {
        Add-Error "Generated NEXT_SESSION view missing 'Checkpoint (workflow alignment)' section"
    }
    if (-not ($generatedText -match 'generated view nad .*next_session\.json')) {
        Add-Error "Generated NEXT_SESSION view missing source-of-truth marker for next_session.json"
    }
}

if (-not $SkipGeneratedFreshnessCheck) {
    $generator = Join-Path $RootPath "scripts\generate_control_docs.ps1"
    if (-not (Test-Path $generator)) {
        Add-Error "Missing generator script for freshness check: scripts/generate_control_docs.ps1"
    }
    else {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $generator -RootPath $RootPath -CheckOnly
        $genExit = if ($LASTEXITCODE -is [int]) { [int]$LASTEXITCODE } else { 1 }
        if ($genExit -ne 0) {
            Add-Error "Generated control docs are stale (generate_control_docs.ps1 -CheckOnly failed)."
        }
        else {
            Write-Log -Message "PASS: generated control docs freshness" -Level "SUCCESS"
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Warnings: $($script:Warnings.Count)" -ForegroundColor Yellow
Write-Host "  Errors: $($script:Errors.Count)" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($script:Errors.Count -eq 0) {
    Write-Host "--- NEXT_SESSION VALIDATION PASSED ---" -ForegroundColor Green
    exit 0
}

Write-Host "--- NEXT_SESSION VALIDATION FAILED ---" -ForegroundColor Red
exit 1
