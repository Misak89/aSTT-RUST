param(
    [string]$RootPath = ".",
    [string]$CanonicalPath = "docs_control/workflow_control_plane.json",
    [string]$VerifyManifestPath = "docs_control/observed_workflow/verify_stage.json",
    [string]$CiManifestPath = "docs_control/observed_workflow/ci_jobs.json",
    [string]$HooksManifestPath = "docs_control/observed_workflow/hooks.json",
    [switch]$RefreshObserved,
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"
$script:Errors = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

function Resolve-RepoPath {
    param([string]$PathValue)
    return (Join-Path $RootPath $PathValue)
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","SUCCESS","WARN","ERROR")]
        [string]$Level = "INFO"
    )
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        default { "Cyan" }
    }
    if ($DetailedOutput -or $Level -in @("SUCCESS","WARN","ERROR")) {
        Write-Host $Message -ForegroundColor $color
    }
}

function Add-Error { param([string]$Message) $script:Errors.Add($Message); Write-Log "ERROR: $Message" "ERROR" }
function Add-Warn { param([string]$Message) $script:Warnings.Add($Message); Write-Log "WARN: $Message" "WARN" }

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
    $v = Get-Prop -Obj $Obj -Name $Name -Default $Default
    if ($null -eq $v) { return $Default }
    return [string]$v
}

function Load-JsonFile {
    param([string]$RepoRelativePath)
    $full = Resolve-RepoPath -PathValue $RepoRelativePath
    if (-not (Test-Path $full)) {
        Add-Error "Missing JSON file: $RepoRelativePath"
        return $null
    }
    try {
        return (Get-Content -Path $full -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 200)
    }
    catch {
        Add-Error "Failed to parse JSON '$RepoRelativePath': $($_.Exception.Message)"
        return $null
    }
}

function Invoke-Extractor {
    param([string]$ScriptPath)
    $full = Resolve-RepoPath -PathValue $ScriptPath
    if (-not (Test-Path $full)) {
        Add-Error "Missing extractor script: $ScriptPath"
        return
    }
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $full -RootPath $RootPath
    if ($LASTEXITCODE -ne 0) {
        Add-Error "Extractor failed: $ScriptPath (exit=$LASTEXITCODE)"
    }
}

function New-StringSet {
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    return (, $set)
}

function Add-SetValue {
    param([System.Collections.Generic.HashSet[string]]$Set, [string]$Value)
    if (-not [string]::IsNullOrWhiteSpace($Value)) { [void]$Set.Add($Value) }
}

function Build-ObservedIndex {
    param(
        [object]$VerifyManifest,
        [object]$CiManifest,
        [object]$HooksManifest
    )

    $verifyFunctions = New-StringSet
    $verifyStepNames = New-StringSet
    $verifyRules = New-StringSet
    $hookIds = New-StringSet
    $hookNames = New-StringSet
    $ciIndex = @{}

    if ($null -ne $VerifyManifest) {
        foreach ($f in (To-Array (Get-Prop -Obj $VerifyManifest -Name "functions" -Default @()))) {
            Add-SetValue -Set $verifyFunctions -Value (Get-String -Obj $f -Name "name")
        }
        foreach ($s in (To-Array (Get-Prop -Obj $VerifyManifest -Name "fast_steps" -Default @()))) {
            Add-SetValue -Set $verifyStepNames -Value (Get-String -Obj $s -Name "name")
            Add-SetValue -Set $verifyRules -Value (Get-String -Obj $s -Name "rule")
        }
    }

    if ($null -ne $CiManifest) {
        foreach ($wf in (To-Array (Get-Prop -Obj $CiManifest -Name "workflows" -Default @()))) {
            $wfPath = (Get-String -Obj $wf -Name "path").ToLowerInvariant()
            $jobIds = New-StringSet
            $stepLabels = New-StringSet
            $stepValues = New-StringSet
            foreach ($job in (To-Array (Get-Prop -Obj $wf -Name "jobs" -Default @()))) {
                Add-SetValue -Set $jobIds -Value (Get-String -Obj $job -Name "job_id")
                foreach ($step in (To-Array (Get-Prop -Obj $job -Name "steps" -Default @()))) {
                    Add-SetValue -Set $stepLabels -Value (Get-String -Obj $step -Name "label")
                    Add-SetValue -Set $stepValues -Value (Get-String -Obj $step -Name "value")
                }
            }
            $ciIndex[$wfPath] = [pscustomobject]@{
                job_ids = $jobIds
                step_labels = $stepLabels
                step_values = $stepValues
                workflow_name = (Get-String -Obj $wf -Name "workflow_name")
            }
        }
    }

    if ($null -ne $HooksManifest) {
        foreach ($hook in (To-Array (Get-Prop -Obj $HooksManifest -Name "hooks" -Default @()))) {
            Add-SetValue -Set $hookIds -Value (Get-String -Obj $hook -Name "hook_id")
            Add-SetValue -Set $hookNames -Value (Get-String -Obj $hook -Name "name")
        }
    }

    return [pscustomobject]@{
        verify = [pscustomobject]@{
            functions = $verifyFunctions
            step_names = $verifyStepNames
            rules = $verifyRules
        }
        ci = $ciIndex
        hooks = [pscustomobject]@{
            hook_ids = $hookIds
            hook_names = $hookNames
        }
    }
}

function Test-RuntimeRefObserved {
    param(
        [object]$RuntimeRef,
        [object]$Target,
        [object]$ObservedIndex
    )

    $kind = (Get-String -Obj $RuntimeRef -Name "kind")
    $value = (Get-String -Obj $RuntimeRef -Name "value")
    $targetKind = (Get-String -Obj $Target -Name "kind")
    $targetPath = (Get-String -Obj $Target -Name "path").ToLowerInvariant()

    switch ($targetKind) {
        "powershell_script" {
            switch ($kind) {
                "script_function" { return $ObservedIndex.verify.functions.Contains($value) }
                "verify_step_name" { return $ObservedIndex.verify.step_names.Contains($value) }
                default { return $false }
            }
        }
        "github_workflow" {
            if (-not $ObservedIndex.ci.ContainsKey($targetPath)) { return $false }
            $wf = $ObservedIndex.ci[$targetPath]
            switch ($kind) {
                "ci_job" { return $wf.job_ids.Contains($value) }
                "ci_step" {
                    return ($wf.step_labels.Contains($value) -or $wf.step_values.Contains($value))
                }
                default { return $false }
            }
        }
        "pre_commit_config" {
            switch ($kind) {
                "pre_commit_hook_id" { return $ObservedIndex.hooks.hook_ids.Contains($value) }
                "pre_commit_hook_name" {
                    if ($ObservedIndex.hooks.hook_names.Contains($value)) { return $true }
                    foreach ($name in $ObservedIndex.hooks.hook_names) {
                        if ($name -like "*$value*") { return $true }
                    }
                    return $false
                }
                default { return $false }
            }
        }
        default {
            return $false
        }
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Validate Workflow Control Alignment (D4)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if ($RefreshObserved) {
    Invoke-Extractor -ScriptPath "scripts/extract_verify_stage_manifest.ps1"
    Invoke-Extractor -ScriptPath "scripts/extract_ci_manifest.ps1"
    Invoke-Extractor -ScriptPath "scripts/extract_hooks_manifest.ps1"
    if ($script:Errors.Count -gt 0) { exit 1 }
}

$canonical = Load-JsonFile -RepoRelativePath $CanonicalPath
$verifyManifest = Load-JsonFile -RepoRelativePath $VerifyManifestPath
$ciManifest = Load-JsonFile -RepoRelativePath $CiManifestPath
$hooksManifest = Load-JsonFile -RepoRelativePath $HooksManifestPath
if ($script:Errors.Count -gt 0) { exit 1 }

$targets = To-Array (Get-Prop -Obj $canonical -Name "alignment_targets" -Default @())
$nodes = To-Array (Get-Prop -Obj $canonical -Name "nodes" -Default @())
$targetById = @{}
foreach ($t in $targets) {
    $tid = Get-String -Obj $t -Name "target_id"
    if (-not [string]::IsNullOrWhiteSpace($tid)) { $targetById[$tid] = $t }
}

$observed = Build-ObservedIndex -VerifyManifest $verifyManifest -CiManifest $ciManifest -HooksManifest $hooksManifest

# Validate target paths and required runtime refs.
foreach ($target in $targets) {
    $tid = Get-String -Obj $target -Name "target_id"
    $targetPath = Get-String -Obj $target -Name "path"
    if ([string]::IsNullOrWhiteSpace($tid)) {
        Add-Error "alignment_targets entry missing target_id"
        continue
    }
    if ([string]::IsNullOrWhiteSpace($targetPath)) {
        Add-Error "alignment_targets[$tid] missing path"
    } else {
        $full = Resolve-RepoPath -PathValue $targetPath
        if (-not (Test-Path $full)) {
            Add-Error "alignment_targets[$tid].path missing on disk: $targetPath"
        }
    }

    foreach ($rr in (To-Array (Get-Prop -Obj $target -Name "required_runtime_refs" -Default @()))) {
        if (-not (Test-RuntimeRefObserved -RuntimeRef $rr -Target $target -ObservedIndex $observed)) {
            $kind = Get-String -Obj $rr -Name "kind"
            $value = Get-String -Obj $rr -Name "value"
            Add-Error "alignment_targets[$tid] required runtime ref missing in observed manifest: $kind='$value'"
        }
    }
}

# Validate node runtime refs that are bound to alignment targets.
foreach ($node in $nodes) {
    $nodeId = Get-String -Obj $node -Name "node_id"
    foreach ($rr in (To-Array (Get-Prop -Obj $node -Name "runtime_refs" -Default @()))) {
        $targetId = Get-String -Obj $rr -Name "target_id"
        if ([string]::IsNullOrWhiteSpace($targetId)) { continue }
        if (-not $targetById.ContainsKey($targetId)) {
            Add-Error "nodes[$nodeId].runtime_refs references unknown target_id '$targetId'"
            continue
        }
        $target = $targetById[$targetId]
        if (-not (Test-RuntimeRefObserved -RuntimeRef $rr -Target $target -ObservedIndex $observed)) {
            $kind = Get-String -Obj $rr -Name "kind"
            $value = Get-String -Obj $rr -Name "value"
            Add-Error "nodes[$nodeId].runtime_ref not found in observed target '$targetId': $kind='$value'"
        }
    }
}

if ($script:Errors.Count -eq 0) {
    Write-Log -Message "PASS: workflow control alignment validated (targets=$($targets.Count), nodes=$($nodes.Count), warnings=$($script:Warnings.Count))" -Level "SUCCESS"
}

if ($script:Warnings.Count -gt 0 -and -not $DetailedOutput) {
    Write-Host "Warnings: $($script:Warnings.Count) (run with -DetailedOutput for details)" -ForegroundColor Yellow
}

if ($script:Errors.Count -gt 0) {
    Write-Host "FAIL: workflow control alignment failed with $($script:Errors.Count) error(s)." -ForegroundColor Red
    exit 1
}

exit 0
