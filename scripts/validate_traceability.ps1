param(
    [string]$RootPath = ".",
    [string]$CanonicalPath = "docs_control/traceability.json",
    [string]$SchemaPath = "docs_control/traceability.schema.json",
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

function Get-Prop {
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

function Get-String {
    param(
        [object]$Obj,
        [string]$Name,
        [string]$Default = ""
    )
    $value = Get-Prop -Obj $Obj -Name $Name -Default $Default
    if ($null -eq $value) { return $Default }
    return [string]$value
}

function Register-EntityIds {
    param(
        [string]$EntityName,
        [string]$IdField,
        [object[]]$Items,
        [hashtable]$Target
    )

    $ids = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($Items)) {
        $id = Get-String -Obj $item -Name $IdField
        if ([string]::IsNullOrWhiteSpace($id)) {
            Add-Error "${EntityName}: missing $IdField"
            continue
        }
        if (-not $ids.Add($id)) {
            Add-Error "${EntityName}: duplicate $IdField '$id'"
            continue
        }
    }
    $Target[$EntityName] = $ids
}

function Assert-RefsExist {
    param(
        [string]$LinkId,
        [string]$FieldName,
        [object[]]$Ids,
        [System.Collections.Generic.HashSet[string]]$KnownSet
    )

    foreach ($id in @($Ids)) {
        $text = [string]$id
        if ([string]::IsNullOrWhiteSpace($text)) {
            Add-Error "links[$LinkId].$FieldName contains empty reference"
            continue
        }
        if (-not $KnownSet.Contains($text)) {
            Add-Error "links[$LinkId].$FieldName references missing id '$text'"
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Traceability Validator v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$canonicalFull = Resolve-RepoPath -PathValue $CanonicalPath
$schemaFull = Resolve-RepoPath -PathValue $SchemaPath

if (-not (Test-Path $canonicalFull)) {
    Add-Error "Missing canonical traceability JSON: $CanonicalPath"
}
if (-not (Test-Path $schemaFull)) {
    Add-Error "Missing traceability schema: $SchemaPath"
}
if ($script:Errors.Count -gt 0) { exit 1 }

$raw = Get-Content -Path $canonicalFull -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($raw)) {
    Add-Error "Canonical traceability JSON is empty: $CanonicalPath"
    exit 1
}

if (Test-SchemaValidationAvailable) {
    try {
        $schemaOk = Test-Json -Json $raw -SchemaFile $schemaFull -ErrorAction Stop
        if ($schemaOk) {
            Write-Log -Message "PASS: JSON schema validation" -Level "SUCCESS"
        } else {
            Add-Error "JSON schema validation failed for $CanonicalPath"
        }
    }
    catch {
        Add-Error "JSON schema validation error: $($_.Exception.Message)"
    }
}
else {
    Add-Warn "Test-Json -SchemaFile unavailable; running structural integrity checks only."
}

try {
    $data = $raw | ConvertFrom-Json -Depth 100
}
catch {
    Add-Error "Invalid JSON syntax in ${CanonicalPath}: $($_.Exception.Message)"
    exit 1
}

$schemaVersion = Get-String -Obj $data -Name "schema_version"
if ($schemaVersion -ne "1.0") {
    Add-Error "Unsupported schema_version '$schemaVersion' (expected 1.0)"
}

$sourceOfTruth = Get-String -Obj $data -Name "source_of_truth"
if ($sourceOfTruth -ne "docs_control/traceability.json") {
    Add-Warn "source_of_truth is '$sourceOfTruth' (expected docs_control/traceability.json)"
}

$entities = Get-Prop -Obj $data -Name "entities"
if ($null -eq $entities) {
    Add-Error "Missing top-level 'entities' object."
    exit 1
}

$idSets = @{}
Register-EntityIds -EntityName "specs" -IdField "spec_id" -Items (To-Array (Get-Prop -Obj $entities -Name "specs" -Default @())) -Target $idSets
Register-EntityIds -EntityName "plans" -IdField "plan_id" -Items (To-Array (Get-Prop -Obj $entities -Name "plans" -Default @())) -Target $idSets
Register-EntityIds -EntityName "tasks" -IdField "task_id" -Items (To-Array (Get-Prop -Obj $entities -Name "tasks" -Default @())) -Target $idSets
Register-EntityIds -EntityName "code_refs" -IdField "code_ref_id" -Items (To-Array (Get-Prop -Obj $entities -Name "code_refs" -Default @())) -Target $idSets
Register-EntityIds -EntityName "tests" -IdField "test_id" -Items (To-Array (Get-Prop -Obj $entities -Name "tests" -Default @())) -Target $idSets
Register-EntityIds -EntityName "docs" -IdField "doc_id" -Items (To-Array (Get-Prop -Obj $entities -Name "docs" -Default @())) -Target $idSets
Register-EntityIds -EntityName "logs" -IdField "log_id" -Items (To-Array (Get-Prop -Obj $entities -Name "logs" -Default @())) -Target $idSets
Register-EntityIds -EntityName "evidence" -IdField "evidence_id" -Items (To-Array (Get-Prop -Obj $entities -Name "evidence" -Default @())) -Target $idSets

$links = To-Array (Get-Prop -Obj $data -Name "links" -Default @())
if ($links.Count -eq 0) {
    Add-Error "Traceability registry has no links (P0 minimum requires at least one link)."
}

$linkIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($link in $links) {
    $linkId = Get-String -Obj $link -Name "link_id"
    if ([string]::IsNullOrWhiteSpace($linkId)) {
        Add-Error "Link entry missing link_id"
        continue
    }
    if (-not $linkIds.Add($linkId)) {
        Add-Error "Duplicate link_id '$linkId'"
    }

    $taskId = Get-String -Obj $link -Name "task_id"
    if ([string]::IsNullOrWhiteSpace($taskId)) {
        Add-Error "links[$linkId] missing task_id"
    } elseif (-not $idSets["tasks"].Contains($taskId)) {
        Add-Error "links[$linkId].task_id references missing id '$taskId'"
    }

    $singleRefs = @(
        @{ Field = "spec_id"; Set = "specs" },
        @{ Field = "plan_id"; Set = "plans" }
    )
    foreach ($ref in $singleRefs) {
        $value = Get-String -Obj $link -Name $ref.Field
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        if (-not $idSets[$ref.Set].Contains($value)) {
            Add-Error "links[$linkId].$($ref.Field) references missing id '$value'"
        }
    }

    Assert-RefsExist -LinkId $linkId -FieldName "code_ref_ids" -Ids (To-Array (Get-Prop -Obj $link -Name "code_ref_ids" -Default @())) -KnownSet $idSets["code_refs"]
    Assert-RefsExist -LinkId $linkId -FieldName "test_ids" -Ids (To-Array (Get-Prop -Obj $link -Name "test_ids" -Default @())) -KnownSet $idSets["tests"]
    Assert-RefsExist -LinkId $linkId -FieldName "doc_ids" -Ids (To-Array (Get-Prop -Obj $link -Name "doc_ids" -Default @())) -KnownSet $idSets["docs"]
    Assert-RefsExist -LinkId $linkId -FieldName "log_ids" -Ids (To-Array (Get-Prop -Obj $link -Name "log_ids" -Default @())) -KnownSet $idSets["logs"]
    Assert-RefsExist -LinkId $linkId -FieldName "evidence_ids" -Ids (To-Array (Get-Prop -Obj $link -Name "evidence_ids" -Default @())) -KnownSet $idSets["evidence"]
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ("  Entity counts: specs={0}, plans={1}, tasks={2}, code_refs={3}, tests={4}, docs={5}, logs={6}, evidence={7}" -f `
        (To-Array (Get-Prop -Obj $entities -Name "specs" -Default @())).Count, `
        (To-Array (Get-Prop -Obj $entities -Name "plans" -Default @())).Count, `
        (To-Array (Get-Prop -Obj $entities -Name "tasks" -Default @())).Count, `
        (To-Array (Get-Prop -Obj $entities -Name "code_refs" -Default @())).Count, `
        (To-Array (Get-Prop -Obj $entities -Name "tests" -Default @())).Count, `
        (To-Array (Get-Prop -Obj $entities -Name "docs" -Default @())).Count, `
        (To-Array (Get-Prop -Obj $entities -Name "logs" -Default @())).Count, `
        (To-Array (Get-Prop -Obj $entities -Name "evidence" -Default @())).Count) -ForegroundColor Cyan
Write-Host "  Links: $($links.Count)" -ForegroundColor Cyan
Write-Host "  Warnings: $($script:Warnings.Count)" -ForegroundColor Yellow
Write-Host "  Errors: $($script:Errors.Count)" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($script:Errors.Count -eq 0) {
    Write-Host "--- TRACEABILITY VALIDATION PASSED ---" -ForegroundColor Green
    exit 0
}

Write-Host "--- TRACEABILITY VALIDATION FAILED ---" -ForegroundColor Red
exit 1
