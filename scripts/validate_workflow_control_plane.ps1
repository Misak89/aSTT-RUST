param(
    [string]$RootPath = ".",
    [string]$CanonicalPath = "docs_control/workflow_control_plane.json",
    [string]$SchemaPath = "docs_control/workflow_control_plane.schema.json",
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

function Register-Ids {
    param(
        [string]$EntityName,
        [string]$IdField,
        [object[]]$Items,
        [hashtable]$IdMap,
        [hashtable]$ObjectMap
    )

    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($Items)) {
        $id = Get-String -Obj $item -Name $IdField
        if ([string]::IsNullOrWhiteSpace($id)) {
            Add-Error "${EntityName}: missing $IdField"
            continue
        }
        if (-not $set.Add($id)) {
            Add-Error "${EntityName}: duplicate $IdField '$id'"
            continue
        }
        $ObjectMap[$id] = $item
    }
    $IdMap[$EntityName] = $set
}

function Assert-RefExists {
    param(
        [string]$Context,
        [string]$RefValue,
        [System.Collections.Generic.HashSet[string]]$KnownIds,
        [switch]$WarnOnly
    )
    if ([string]::IsNullOrWhiteSpace($RefValue)) {
        if ($WarnOnly) { Add-Warn "$Context is empty" } else { Add-Error "$Context is empty" }
        return
    }
    if (-not $KnownIds.Contains($RefValue)) {
        if ($WarnOnly) { Add-Warn "$Context references missing id '$RefValue'" } else { Add-Error "$Context references missing id '$RefValue'" }
    }
}

function Assert-ArrayRefsExist {
    param(
        [string]$Context,
        [object]$Values,
        [System.Collections.Generic.HashSet[string]]$KnownIds,
        [switch]$WarnOnly
    )
    foreach ($value in (To-Array $Values)) {
        Assert-RefExists -Context $Context -RefValue ([string]$value) -KnownIds $KnownIds -WarnOnly:$WarnOnly
    }
}

function Get-AllRuntimeRefStrings {
    param([object[]]$Nodes)

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($node in @($Nodes)) {
        foreach ($rr in (To-Array (Get-Prop -Obj $node -Name "runtime_refs" -Default @()))) {
            $kind = Get-String -Obj $rr -Name "kind"
            $value = Get-String -Obj $rr -Name "value"
            if (-not [string]::IsNullOrWhiteSpace($kind) -or -not [string]::IsNullOrWhiteSpace($value)) {
                $items.Add(("{0}:{1}" -f $kind.ToLowerInvariant(), $value.ToLowerInvariant()))
            }
        }
    }
    return @($items)
}

function Test-AnyNodeMatch {
    param(
        [object[]]$Nodes,
        [string[]]$Needles
    )

    foreach ($node in @($Nodes)) {
        $id = Get-String -Obj $node -Name "node_id"
        $label = Get-String -Obj $node -Name "label"
        $hay = ("{0} {1}" -f $id, $label).ToLowerInvariant()
        foreach ($needle in @($Needles)) {
            if ($hay.Contains($needle.ToLowerInvariant())) {
                return $true
            }
        }
    }
    return $false
}

function Test-RequiredMechanism {
    param(
        [string]$MechanismId,
        [object[]]$Nodes,
        [string[]]$RuntimeRefs
    )

    switch ($MechanismId) {
        "verify_fast_orchestrator" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("verify_fast", "verify_stage")) }
        "verify_stage_steps" { return ($RuntimeRefs | Where-Object { $_ -like "script_function:get-faststeps" }).Count -gt 0 }
        "capability_audit" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("validate_capability_audit", "capability audit")) }
        "control_docs_generation" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("generate_control_docs", "control docs")) }
        "stale_check" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("stale")) }
        "verify_run_logging" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("log_verify_run", "verify run")) }
        "traceability_validation" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("validate_traceability", "traceability")) }
        "next_session_validation" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("validate_next_session", "next_session")) }
        "markdownlint_blocking" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("markdownlint")) }
        "markdownlint_backlog" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("markdownlint backlog")) }
        "vale_blocking" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("vale")) }
        "vale_backlog" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("vale backlog")) }
        "mkdocs_strict" { return (Test-AnyNodeMatch -Nodes $Nodes -Needles @("mkdocs")) }
        "pre_commit_enforcement" { return ($RuntimeRefs | Where-Object { $_ -like "pre_commit_*:*" }).Count -gt 0 }
        "ci_enforcement" { return ($RuntimeRefs | Where-Object { $_ -like "ci_job:*" -or $_ -like "ci_step:*" }).Count -gt 0 }
        default { return $false }
    }
}

function Report-CoverageGap {
    param(
        [string]$Message,
        [bool]$IsApproved
    )
    if ($IsApproved) {
        Add-Error $Message
    } else {
        Add-Warn $Message
    }
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  Workflow Control Plane Validator (D1)" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

$canonicalFull = Resolve-RepoPath -PathValue $CanonicalPath
$schemaFull = Resolve-RepoPath -PathValue $SchemaPath

if (-not (Test-Path $canonicalFull)) { Add-Error "Missing canonical workflow control plane JSON: $CanonicalPath" }
if (-not (Test-Path $schemaFull)) { Add-Error "Missing workflow control plane schema: $SchemaPath" }
if ($script:Errors.Count -gt 0) { exit 1 }

$raw = Get-Content -Path $canonicalFull -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($raw)) {
    Add-Error "Canonical JSON is empty: $CanonicalPath"
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
} else {
    Add-Warn "Test-Json -SchemaFile unavailable; schema validation skipped."
}

try {
    $data = $raw | ConvertFrom-Json -Depth 200
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
if ($sourceOfTruth -ne "docs_control/workflow_control_plane.json") {
    Add-Error "source_of_truth must be docs_control/workflow_control_plane.json (found '$sourceOfTruth')"
}

$model = Get-Prop -Obj $data -Name "model"
$modelStatus = (Get-String -Obj $model -Name "status").ToUpperInvariant()
$isApproved = $modelStatus -eq "APPROVED"

$actors = To-Array (Get-Prop -Obj $data -Name "actors" -Default @())
$artifacts = To-Array (Get-Prop -Obj $data -Name "artifacts" -Default @())
$nodes = To-Array (Get-Prop -Obj $data -Name "nodes" -Default @())
$edges = To-Array (Get-Prop -Obj $data -Name "edges" -Default @())
$views = To-Array (Get-Prop -Obj $data -Name "views" -Default @())
$targets = To-Array (Get-Prop -Obj $data -Name "alignment_targets" -Default @())
$outputs = To-Array (Get-Prop -Obj $data -Name "generated_outputs" -Default @())
$coverage = Get-Prop -Obj $data -Name "coverage_requirements"

$idSets = @{}
$objectsById = @{}
Register-Ids -EntityName "actors" -IdField "actor_id" -Items $actors -IdMap $idSets -ObjectMap $objectsById
Register-Ids -EntityName "artifacts" -IdField "artifact_id" -Items $artifacts -IdMap $idSets -ObjectMap $objectsById
Register-Ids -EntityName "nodes" -IdField "node_id" -Items $nodes -IdMap $idSets -ObjectMap $objectsById
Register-Ids -EntityName "edges" -IdField "edge_id" -Items $edges -IdMap $idSets -ObjectMap $objectsById
Register-Ids -EntityName "views" -IdField "view_id" -Items $views -IdMap $idSets -ObjectMap $objectsById
Register-Ids -EntityName "alignment_targets" -IdField "target_id" -Items $targets -IdMap $idSets -ObjectMap $objectsById
Register-Ids -EntityName "generated_outputs" -IdField "output_id" -Items $outputs -IdMap $idSets -ObjectMap $objectsById

$graphEndpointIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in @("actors", "artifacts", "nodes")) {
    if ($idSets.ContainsKey($name)) {
        foreach ($id in $idSets[$name]) { [void]$graphEndpointIds.Add($id) }
    }
}

foreach ($edge in $edges) {
    $edgeId = Get-String -Obj $edge -Name "edge_id"
    $from = Get-String -Obj $edge -Name "from"
    $to = Get-String -Obj $edge -Name "to"
    Assert-RefExists -Context "edges[$edgeId].from" -RefValue $from -KnownIds $graphEndpointIds
    Assert-RefExists -Context "edges[$edgeId].to" -RefValue $to -KnownIds $graphEndpointIds
}

$artifactIds = $idSets["artifacts"]
foreach ($node in $nodes) {
    $nodeId = Get-String -Obj $node -Name "node_id"
    Assert-ArrayRefsExist -Context "nodes[$nodeId].inputs[]" -Values (Get-Prop -Obj $node -Name "inputs" -Default @()) -KnownIds $artifactIds
    Assert-ArrayRefsExist -Context "nodes[$nodeId].outputs[]" -Values (Get-Prop -Obj $node -Name "outputs" -Default @()) -KnownIds $artifactIds

    foreach ($rr in (To-Array (Get-Prop -Obj $node -Name "runtime_refs" -Default @()))) {
        $targetId = Get-String -Obj $rr -Name "target_id"
        if (-not [string]::IsNullOrWhiteSpace($targetId)) {
            Assert-RefExists -Context "nodes[$nodeId].runtime_refs[].target_id" -RefValue $targetId -KnownIds $idSets["alignment_targets"]
        }
    }
}

$outputIds = $idSets["generated_outputs"]
$viewIds = $idSets["views"]
foreach ($view in $views) {
    $viewId = Get-String -Obj $view -Name "view_id"
    Assert-ArrayRefsExist -Context "views[$viewId].output_ids[]" -Values (Get-Prop -Obj $view -Name "output_ids" -Default @()) -KnownIds $outputIds

    $selectors = Get-Prop -Obj $view -Name "selectors"
    if ($null -ne $selectors) {
        Assert-ArrayRefsExist -Context "views[$viewId].selectors.include_node_ids[]" -Values (Get-Prop -Obj $selectors -Name "include_node_ids" -Default @()) -KnownIds $idSets["nodes"]
        Assert-ArrayRefsExist -Context "views[$viewId].selectors.exclude_node_ids[]" -Values (Get-Prop -Obj $selectors -Name "exclude_node_ids" -Default @()) -KnownIds $idSets["nodes"]
        Assert-ArrayRefsExist -Context "views[$viewId].selectors.include_artifact_ids[]" -Values (Get-Prop -Obj $selectors -Name "include_artifact_ids" -Default @()) -KnownIds $artifactIds
        Assert-ArrayRefsExist -Context "views[$viewId].selectors.exclude_artifact_ids[]" -Values (Get-Prop -Obj $selectors -Name "exclude_artifact_ids" -Default @()) -KnownIds $artifactIds
    }
}

foreach ($output in $outputs) {
    $outputId = Get-String -Obj $output -Name "output_id"
    $viewId = Get-String -Obj $output -Name "view_id"
    Assert-RefExists -Context "generated_outputs[$outputId].view_id" -RefValue $viewId -KnownIds $viewIds

    $generatorScript = Get-String -Obj $output -Name "generator_script"
    if (-not [string]::IsNullOrWhiteSpace($generatorScript)) {
        $generatorFull = Resolve-RepoPath -PathValue $generatorScript
        if (-not (Test-Path $generatorFull)) {
            Report-CoverageGap -Message "Planned generator script missing (expected in later batch): $generatorScript" -IsApproved $isApproved
        }
    }
}

foreach ($target in $targets) {
    $targetId = Get-String -Obj $target -Name "target_id"
    $path = Get-String -Obj $target -Name "path"
    if (-not [string]::IsNullOrWhiteSpace($path)) {
        $full = Resolve-RepoPath -PathValue $path
        if (-not (Test-Path $full)) {
            Add-Error "alignment_targets[$targetId].path missing: $path"
        }
    }
}

# Coverage checks (DRAFT = warn, APPROVED = fail)
$coveredDomains = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($collection in @($actors, $artifacts, $nodes)) {
    foreach ($item in @($collection)) {
        foreach ($tag in (To-Array (Get-Prop -Obj $item -Name "domain_tags" -Default @()))) {
            if (-not [string]::IsNullOrWhiteSpace([string]$tag)) {
                [void]$coveredDomains.Add([string]$tag)
            }
        }
    }
}

$requiredDomains = To-Array (Get-Prop -Obj $coverage -Name "required_domains" -Default @())
foreach ($d in $requiredDomains) {
    $domain = [string]$d
    if (-not $coveredDomains.Contains($domain)) {
        Report-CoverageGap -Message "Coverage gap: required domain '$domain' is not represented in current model graph." -IsApproved $isApproved
    }
}

$requiredNodeIds = To-Array (Get-Prop -Obj $coverage -Name "required_node_ids" -Default @())
foreach ($nid in $requiredNodeIds) {
    Assert-RefExists -Context "coverage_requirements.required_node_ids[]" -RefValue ([string]$nid) -KnownIds $idSets["nodes"] -WarnOnly:(-not $isApproved)
}

$requiredArtifactIds = To-Array (Get-Prop -Obj $coverage -Name "required_artifact_ids" -Default @())
foreach ($aid in $requiredArtifactIds) {
    Assert-RefExists -Context "coverage_requirements.required_artifact_ids[]" -RefValue ([string]$aid) -KnownIds $artifactIds -WarnOnly:(-not $isApproved)
}

$pathCoverage = @{
    pass_path = ($edges | Where-Object { (Get-String -Obj $_ -Name "condition") -eq "on_pass" }).Count -gt 0
    fail_fast_path = ($edges | Where-Object { (Get-String -Obj $_ -Name "condition") -eq "on_fail" }).Count -gt 0
    non_blocking_backlog_path = ($nodes | Where-Object { (Get-String -Obj $_ -Name "blocking_mode") -eq "non_blocking" }).Count -gt 0
    skip_optional_path = ($edges | Where-Object { (Get-String -Obj $_ -Name "condition") -eq "on_skip" }).Count -gt 0
}
$requiredPaths = To-Array (Get-Prop -Obj $coverage -Name "required_paths" -Default @())
foreach ($rp in $requiredPaths) {
    $rpKey = [string]$rp
    if (-not $pathCoverage.ContainsKey($rpKey) -or -not $pathCoverage[$rpKey]) {
        Report-CoverageGap -Message "Coverage gap: required path '$rpKey' is not represented in current graph." -IsApproved $isApproved
    }
}

$runtimeRefStrings = Get-AllRuntimeRefStrings -Nodes $nodes
$requiredMechanisms = To-Array (Get-Prop -Obj $coverage -Name "required_mechanisms" -Default @())
foreach ($m in $requiredMechanisms) {
    $mechanism = [string]$m
    if (-not (Test-RequiredMechanism -MechanismId $mechanism -Nodes $nodes -RuntimeRefs $runtimeRefStrings)) {
        Report-CoverageGap -Message "Coverage gap: required mechanism '$mechanism' is not yet represented in current model graph." -IsApproved $isApproved
    }
}

if ($script:Errors.Count -eq 0) {
    Write-Log -Message "PASS: Workflow control plane validator completed (errors=0, warnings=$($script:Warnings.Count))" -Level "SUCCESS"
}

if ($script:Warnings.Count -gt 0 -and -not $DetailedOutput) {
    Write-Host "Warnings: $($script:Warnings.Count) (run with -DetailedOutput for details)" -ForegroundColor Yellow
}

if ($script:Errors.Count -gt 0) {
    Write-Host "FAIL: workflow control plane validation failed with $($script:Errors.Count) error(s)." -ForegroundColor Red
    exit 1
}

exit 0
