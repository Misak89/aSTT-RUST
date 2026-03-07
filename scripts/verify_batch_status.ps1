param(
    [string]$RootPath = ".",
    [string]$RegistryPath = "docs_control/task_status.json",
    [string]$SchemaPath = "docs_control/task_status.schema.json",
    [string]$VerifyRunsPath = "docs_control/verify_runs.json",
    [string]$OutputJsonPath = "logs/verify/batch_status_verify_summary.json",
    [string[]]$BatchId = @(),
    [switch]$ApplyAutoDowngrade,
    [switch]$ReportOnly,
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"
$script:Errors = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:AutoDowngradedBatches = New-Object System.Collections.Generic.List[string]

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

function Get-IsoUtcString {
    param(
        [object]$Obj,
        [string]$Name
    )

    $value = Get-Prop -Obj $Obj -Name $Name -Default $null
    if ($null -eq $value) { return "" }

    if ($value -is [datetime]) {
        return $value.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }

    $text = [string]$value
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    try {
        return ([datetime]::Parse($text).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))
    }
    catch {
        return $text
    }
}

function Resolve-RepoPath {
    param([string]$PathValue)
    return (Join-Path $RootPath $PathValue)
}

function Get-RepoRelativePath {
    param([string]$PathValue)
    try {
        $full = (Resolve-Path (Resolve-RepoPath -PathValue $PathValue) -ErrorAction Stop).Path
        $base = (Resolve-Path $RootPath -ErrorAction Stop).Path
        if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
            return ($full.Substring($base.Length).TrimStart('\', '/') -replace '\\', '/')
        }
        return ($full -replace '\\', '/')
    }
    catch {
        return ($PathValue -replace '\\', '/')
    }
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

function Get-StatusRank {
    param([string]$Status)
    switch ($Status) {
        "UNKNOWN" { return 0 }
        "EXISTS_UNVERIFIED" { return 1 }
        "IMPLEMENTED_UNVERIFIED" { return 2 }
        "VERIFIED_LOCAL" { return 3 }
        "VERIFIED_CI" { return 4 }
        "LEGACY_EXEMPT" { return -1 }
        default { return -99 }
    }
}

function Test-ArtifactCheck {
    param(
        [object]$Artifact,
        [string]$RepoRoot
    )

    $pathValue = Get-String -Obj $Artifact -Name "path"
    $kind = (Get-String -Obj $Artifact -Name "kind" -Default "file").ToLowerInvariant()
    if ($kind -ne "directory") { $kind = "file" }
    $optional = [bool](Get-Prop -Obj $Artifact -Name "optional" -Default $false)
    $containsAll = @((To-Array (Get-Prop -Obj $Artifact -Name "contains_all" -Default @())) | ForEach-Object { [string]$_ })
    $notContains = @((To-Array (Get-Prop -Obj $Artifact -Name "not_contains" -Default @())) | ForEach-Object { [string]$_ })

    $fullPath = Join-Path $RepoRoot $pathValue
    $exists = if ($kind -eq "directory") { Test-Path $fullPath -PathType Container } else { Test-Path $fullPath -PathType Leaf }

    $markerFailures = New-Object System.Collections.Generic.List[string]
    $markerPassCount = 0
    $rawText = ""

    if ($exists -and $kind -eq "file" -and (($containsAll.Count -gt 0) -or ($notContains.Count -gt 0))) {
        try {
            $rawText = Get-Content -Path $fullPath -Raw -Encoding UTF8
        }
        catch {
            $markerFailures.Add("Unable to read file for marker checks: $($_.Exception.Message)")
        }
    }

    foreach ($marker in $containsAll) {
        if (-not $exists) { break }
        if ([string]::IsNullOrEmpty($rawText)) {
            $markerFailures.Add("Missing required marker '$marker' (file unreadable or empty)")
            continue
        }
        if ($rawText -notmatch [regex]::Escape($marker)) {
            $markerFailures.Add("Missing required marker '$marker'")
        } else {
            $markerPassCount++
        }
    }

    foreach ($marker in $notContains) {
        if (-not $exists) { break }
        if (-not [string]::IsNullOrEmpty($rawText) -and $rawText -match [regex]::Escape($marker)) {
            $markerFailures.Add("Forbidden marker present '$marker'")
        } else {
            $markerPassCount++
        }
    }

    $status = "PASS"
    if (-not $exists) {
        $status = if ($optional) { "SKIP_OPTIONAL_MISSING" } else { "FAIL_MISSING" }
    } elseif ($markerFailures.Count -gt 0) {
        $status = "FAIL_MARKER"
    }

    return [pscustomobject][ordered]@{
        path = ($pathValue -replace '\\', '/')
        kind = $kind
        optional = $optional
        exists = [bool]$exists
        status = $status
        marker_pass_count = [int]$markerPassCount
        marker_failures = @($markerFailures)
    }
}

function Get-RunStepsByName {
    param([object]$Run)
    $map = @{}
    foreach ($step in (To-Array (Get-Prop -Obj $Run -Name "steps" -Default @()))) {
        $name = Get-String -Obj $step -Name "name"
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $map[$name] = $step
    }
    return $map
}

function Test-RunHasRequiredPassingSteps {
    param(
        [object]$Run,
        [string[]]$RequiredStepNames
    )

    $map = Get-RunStepsByName -Run $Run
    $missing = New-Object System.Collections.Generic.List[string]
    $nonPass = New-Object System.Collections.Generic.List[string]

    foreach ($requiredName in @($RequiredStepNames)) {
        if (-not $map.ContainsKey($requiredName)) {
            $missing.Add($requiredName)
            continue
        }
        $step = $map[$requiredName]
        $stepStatus = (Get-String -Obj $step -Name "status").ToUpperInvariant()
        if ($stepStatus -ne "PASS") {
            $nonPass.Add(("{0}={1}" -f $requiredName, $stepStatus))
        }
    }

    return [pscustomobject][ordered]@{
        ok = (($missing.Count -eq 0) -and ($nonPass.Count -eq 0))
        missing_steps = @($missing)
        non_pass_steps = @($nonPass)
    }
}

function Find-LatestMatchingRun {
    param(
        [object[]]$Runs,
        [string]$Stage,
        [string[]]$RequiredStepNames
    )

    foreach ($run in @($Runs)) {
        $runStage = Get-String -Obj $run -Name "stage"
        if (-not [string]::IsNullOrWhiteSpace($Stage) -and $runStage -ne $Stage) {
            continue
        }
        $result = Test-RunHasRequiredPassingSteps -Run $run -RequiredStepNames $RequiredStepNames
        if ($result.ok) {
            return [pscustomobject][ordered]@{
                found = $true
                run = $run
                test = $result
            }
        }
    }

    return [pscustomobject][ordered]@{
        found = $false
        run = $null
        test = $null
    }
}

function Get-GitDirtyInfo {
    param(
        [string]$RepoRoot,
        [string[]]$Paths
    )

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $gitCmd) {
        return [pscustomobject][ordered]@{
            available = $false
            paths = @()
            message = "git not available"
        }
    }

    $normalizedPaths = @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ -replace '\\', '/' } | Select-Object -Unique)
    if ($normalizedPaths.Count -eq 0) {
        return [pscustomobject][ordered]@{
            available = $true
            paths = @()
            message = ""
        }
    }

    $raw = @()
    $thrown = $null
    try {
        Push-Location $RepoRoot
        $raw = @( & git status --porcelain -- @normalizedPaths 2>$null )
    }
    catch {
        $thrown = $_
    }
    finally {
        Pop-Location
    }

    if ($thrown) {
        return [pscustomobject][ordered]@{
            available = $false
            paths = @()
            message = [string]$thrown.Exception.Message
        }
    }

    $dirtyPaths = @()
    foreach ($line in @($raw)) {
        $text = [string]$line
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        if ($text.Length -ge 4) {
            $dirtyPaths += (($text.Substring(3)).Trim() -replace '\\', '/')
        } else {
            $dirtyPaths += ($text.Trim() -replace '\\', '/')
        }
    }

    return [pscustomobject][ordered]@{
        available = $true
        paths = @($dirtyPaths | Select-Object -Unique)
        message = ""
    }
}

function Get-RunSortKey {
    param([object]$Run)
    $epoch = Get-Prop -Obj $Run -Name "created_at_epoch_ms" -Default $null
    if ($null -ne $epoch) {
        try { return [double]$epoch } catch { }
    }
    $utcText = Get-String -Obj $Run -Name "created_at_utc"
    try { return [double]([datetime]::Parse($utcText).ToUniversalTime() - [datetime]'1970-01-01').TotalMilliseconds } catch { }
    return 0
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Batch Status Verifier v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($ApplyAutoDowngrade -and $ReportOnly) {
    Add-Error "Invalid parameter combination: -ApplyAutoDowngrade cannot be used with -ReportOnly."
    exit 1
}

$RootPath = (Resolve-Path $RootPath).Path
$registryFull = Resolve-RepoPath -PathValue $RegistryPath
$schemaFull = Resolve-RepoPath -PathValue $SchemaPath
$verifyRunsFull = Resolve-RepoPath -PathValue $VerifyRunsPath
$outputFull = Resolve-RepoPath -PathValue $OutputJsonPath

foreach ($required in @(
        @{ Path = $registryFull; Name = "task status registry"; Relative = $RegistryPath },
        @{ Path = $schemaFull; Name = "task status schema"; Relative = $SchemaPath },
        @{ Path = $verifyRunsFull; Name = "verify runs log"; Relative = $VerifyRunsPath }
    )) {
    if (-not (Test-Path $required.Path)) {
        Add-Error "Missing $($required.Name): $($required.Relative)"
    }
}
if ($script:Errors.Count -gt 0) {
    if ($ReportOnly) { exit 0 }
    exit 1
}

$registryRaw = Get-Content -Path $registryFull -Raw -Encoding UTF8
$verifyRunsRaw = Get-Content -Path $verifyRunsFull -Raw -Encoding UTF8

if (Test-SchemaValidationAvailable) {
    try {
        $schemaOk = Test-Json -Json $registryRaw -SchemaFile $schemaFull -ErrorAction Stop
        if ($schemaOk) {
            Write-Log -Message "PASS: task_status JSON schema validation" -Level "SUCCESS"
        } else {
            Add-Error "JSON schema validation failed for $RegistryPath"
        }
    }
    catch {
        Add-Error "task_status schema validation error: $($_.Exception.Message)"
    }
} else {
    Add-Warn "Test-Json -SchemaFile unavailable; using structural checks only."
}

try {
    $registry = $registryRaw | ConvertFrom-Json -Depth 100
}
catch {
    Add-Error "Invalid JSON syntax in ${RegistryPath}: $($_.Exception.Message)"
    if ($ReportOnly) { exit 0 } else { exit 1 }
}

try {
    $verifyRunsDoc = $verifyRunsRaw | ConvertFrom-Json -Depth 100
}
catch {
    Add-Error "Invalid JSON syntax in ${VerifyRunsPath}: $($_.Exception.Message)"
    if ($ReportOnly) { exit 0 } else { exit 1 }
}

$registrySchemaVersion = Get-String -Obj $registry -Name "schema_version"
if ($registrySchemaVersion -ne "1.0") {
    Add-Error "Unsupported task_status schema_version '$registrySchemaVersion' (expected 1.0)"
}
$registrySource = Get-String -Obj $registry -Name "source_of_truth"
if ($registrySource -ne "docs_control/task_status.json") {
    Add-Warn "task_status source_of_truth is '$registrySource' (expected docs_control/task_status.json)"
}

$allBatches = @(To-Array (Get-Prop -Obj $registry -Name "batches" -Default @()))
if ($allBatches.Count -eq 0) {
    Add-Error "task_status registry has no batches."
}

$batchIdSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($batch in $allBatches) {
    $id = Get-String -Obj $batch -Name "batch_id"
    if ([string]::IsNullOrWhiteSpace($id)) {
        Add-Error "Batch entry missing batch_id"
        continue
    }
    if (-not $batchIdSet.Add($id)) {
        Add-Error "Duplicate batch_id '$id'"
    }
}

$selectedBatches = @($allBatches)
if ($BatchId.Count -gt 0) {
    $wanted = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($id in $BatchId) { [void]$wanted.Add([string]$id) }
    $selectedBatches = @($allBatches | Where-Object { $wanted.Contains((Get-String -Obj $_ -Name "batch_id")) })
    foreach ($id in $wanted) {
        if (-not (@($selectedBatches | ForEach-Object { Get-String -Obj $_ -Name "batch_id" }) -contains $id)) {
            Add-Error "Requested BatchId not found in registry: $id"
        }
    }
}

$runs = @(To-Array (Get-Prop -Obj $verifyRunsDoc -Name "runs" -Default @()))
$sortedRuns = @($runs | Sort-Object @{ Expression = { Get-RunSortKey -Run $_ }; Descending = $true })
$runsById = @{}
foreach ($run in $sortedRuns) {
    $runId = Get-String -Obj $run -Name "run_id"
    if (-not [string]::IsNullOrWhiteSpace($runId)) {
        $runsById[$runId] = $run
    }
}
$latestFastRun = @($sortedRuns | Where-Object { (Get-String -Obj $_ -Name "stage") -eq "fast" } | Select-Object -First 1)
$latestFastRun = if ($latestFastRun.Count -gt 0) { $latestFastRun[0] } else { $null }

$batchSummaries = @()

foreach ($batch in $selectedBatches) {
    $batchIdValue = Get-String -Obj $batch -Name "batch_id"
    $title = Get-String -Obj $batch -Name "title"
    $claimedStatus = (Get-String -Obj $batch -Name "status").ToUpperInvariant()
    $verification = Get-Prop -Obj $batch -Name "verification"

    if ($null -eq $verification) {
        Add-Error "batch[$batchIdValue]: missing verification object"
        continue
    }

    $verifyStage = (Get-String -Obj $verification -Name "verify_stage").ToLowerInvariant()
    if ($verifyStage -notin @("fast", "full")) {
        Add-Error "batch[$batchIdValue]: invalid verification.verify_stage '$verifyStage'"
        $verifyStage = "fast"
    }

    $requiredStepNames = @((To-Array (Get-Prop -Obj $verification -Name "required_step_names" -Default @())) | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($requiredStepNames.Count -eq 0) {
        Add-Error "batch[$batchIdValue]: verification.required_step_names must not be empty"
    }

    $artifactDefs = @(To-Array (Get-Prop -Obj $verification -Name "required_artifacts" -Default @()))
    if ($artifactDefs.Count -eq 0) {
        Add-Error "batch[$batchIdValue]: verification.required_artifacts must not be empty"
    }

    $artifactResults = @()
    foreach ($artifactDef in $artifactDefs) {
        $artifactResults += Test-ArtifactCheck -Artifact $artifactDef -RepoRoot $RootPath
    }

    $missingRequiredArtifactCount = @($artifactResults | Where-Object { (-not $_.optional) -and (-not $_.exists) }).Count
    $markerFailureCount = @($artifactResults | Where-Object { $_.status -eq "FAIL_MARKER" }).Count
    $artifactPass = (($missingRequiredArtifactCount -eq 0) -and ($markerFailureCount -eq 0))

    $artifactOnlyObservedStatus = if ($missingRequiredArtifactCount -gt 0) {
        "UNKNOWN"
    } elseif ($markerFailureCount -gt 0) {
        "EXISTS_UNVERIFIED"
    } else {
        "IMPLEMENTED_UNVERIFIED"
    }

    $match = Find-LatestMatchingRun -Runs $sortedRuns -Stage $verifyStage -RequiredStepNames $requiredStepNames
    $latestMatchingRun = if ($match.found) { $match.run } else { $null }
    $latestMatchingRunId = if ($null -ne $latestMatchingRun) { Get-String -Obj $latestMatchingRun -Name "run_id" } else { "" }

    $observedStatus = $artifactOnlyObservedStatus
    if ($artifactPass -and $latestMatchingRun) {
        $observedStatus = "VERIFIED_LOCAL"
    }

    $lastVerified = Get-Prop -Obj $batch -Name "last_verified"
    $lastVerifiedRunId = Get-String -Obj $lastVerified -Name "run_id"
    $lastVerifiedRun = $null
    $lastVerifiedRunValid = $false
    $lastVerifiedRunProblems = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($lastVerifiedRunId)) {
        if (-not $runsById.ContainsKey($lastVerifiedRunId)) {
            $lastVerifiedRunProblems.Add("run_id '$lastVerifiedRunId' not found in verify_runs")
        } else {
            $lastVerifiedRun = $runsById[$lastVerifiedRunId]
            $lastVerifiedStage = Get-String -Obj $lastVerifiedRun -Name "stage"
            if ($lastVerifiedStage -ne $verifyStage) {
                $lastVerifiedRunProblems.Add("run_id '$lastVerifiedRunId' has stage '$lastVerifiedStage' (expected '$verifyStage')")
            }

            $runTest = Test-RunHasRequiredPassingSteps -Run $lastVerifiedRun -RequiredStepNames $requiredStepNames
            if (-not $runTest.ok) {
                foreach ($m in $runTest.missing_steps) {
                    $lastVerifiedRunProblems.Add("run_id '$lastVerifiedRunId' missing required step '$m'")
                }
                foreach ($np in $runTest.non_pass_steps) {
                    $lastVerifiedRunProblems.Add("run_id '$lastVerifiedRunId' non-pass step: $np")
                }
            } else {
                $lastVerifiedRunValid = $true
            }
        }
    }

    if ($claimedStatus -in @("VERIFIED_LOCAL", "VERIFIED_CI")) {
        if ([string]::IsNullOrWhiteSpace($lastVerifiedRunId)) {
            Add-Error "batch[$batchIdValue]: status '$claimedStatus' requires last_verified.run_id"
        }
        if (-not $lastVerifiedRunValid) {
            foreach ($problem in $lastVerifiedRunProblems) {
                Add-Error "batch[$batchIdValue]: $problem"
            }
            if ($lastVerifiedRunProblems.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($lastVerifiedRunId)) {
                Add-Error "batch[$batchIdValue]: last_verified.run_id '$lastVerifiedRunId' is not valid evidence"
            }
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($lastVerifiedRunId) -and -not $lastVerifiedRunValid) {
        foreach ($problem in $lastVerifiedRunProblems) {
            Add-Warn "batch[$batchIdValue]: $problem"
        }
    }

    if ($latestMatchingRun -and -not [string]::IsNullOrWhiteSpace($lastVerifiedRunId) -and ($latestMatchingRunId -ne $lastVerifiedRunId)) {
        Add-Warn "batch[$batchIdValue]: latest matching run is '$latestMatchingRunId' but registry last_verified.run_id is '$lastVerifiedRunId'"
    }

    $artifactPathList = @($artifactResults | ForEach-Object { [string]$_.path })
    $dirtyInfo = Get-GitDirtyInfo -RepoRoot $RootPath -Paths $artifactPathList
    $requireCleanForVerified = [bool](Get-Prop -Obj $verification -Name "require_clean_worktree_for_verified" -Default $false)

    $dirtyBlocksVerified = ($requireCleanForVerified -and $dirtyInfo.available -and ($dirtyInfo.paths.Count -gt 0))
    if ($ApplyAutoDowngrade -and $dirtyBlocksVerified -and ($claimedStatus -in @("VERIFIED_LOCAL", "VERIFIED_CI"))) {
        $batch.status = "IMPLEMENTED_UNVERIFIED"
        $script:AutoDowngradedBatches.Add($batchIdValue)
        Write-Log -Message "INFO: auto-downgraded batch[$batchIdValue] from $claimedStatus to IMPLEMENTED_UNVERIFIED (dirty required artifacts)." -Level "INFO"
        $claimedStatus = "IMPLEMENTED_UNVERIFIED"
    }

    if ($dirtyBlocksVerified -and ($observedStatus -in @("VERIFIED_LOCAL", "VERIFIED_CI"))) {
        $observedStatus = "IMPLEMENTED_UNVERIFIED"
    }

    if ($dirtyInfo.available -and $dirtyInfo.paths.Count -gt 0) {
        $msg = "batch[$batchIdValue]: required artifacts have uncommitted changes: " + (($dirtyInfo.paths | Select-Object -First 5) -join ", ")
        if ($claimedStatus -in @("VERIFIED_LOCAL", "VERIFIED_CI") -and $requireCleanForVerified) {
            Add-Error $msg
        } else {
            Add-Warn $msg
        }
    } elseif (-not $dirtyInfo.available -and $DetailedOutput) {
        Add-Warn "batch[$batchIdValue]: git dirty check unavailable ($($dirtyInfo.message))"
    }

    $claimRank = Get-StatusRank -Status $claimedStatus
    $observedRank = Get-StatusRank -Status $observedStatus
    if ($claimRank -eq -99) {
        Add-Error "batch[$batchIdValue]: unknown claimed status '$claimedStatus'"
    } elseif ($claimedStatus -ne "LEGACY_EXEMPT" -and $claimRank -gt $observedRank) {
        Add-Error "batch[$batchIdValue]: claim status '$claimedStatus' exceeds observed status '$observedStatus'"
    }

    $batchSummaries += [pscustomobject][ordered]@{
        batch_id = $batchIdValue
        title = $title
        claimed_status = $claimedStatus
        observed_status = $observedStatus
        artifact_only_observed_status = $artifactOnlyObservedStatus
        artifact_checks = [pscustomobject][ordered]@{
            total = [int]$artifactResults.Count
            missing_required = [int]$missingRequiredArtifactCount
            marker_failures = [int]$markerFailureCount
            pass = [bool]$artifactPass
            details = @($artifactResults)
        }
        evidence_checks = [pscustomobject][ordered]@{
            verify_stage = $verifyStage
            required_step_names = @($requiredStepNames)
            latest_matching_run_id = $latestMatchingRunId
            latest_matching_run_created_at_utc = if ($latestMatchingRun) { Get-IsoUtcString -Obj $latestMatchingRun -Name "created_at_utc" } else { "" }
            last_verified_run_id = $lastVerifiedRunId
            last_verified_run_valid = [bool]$lastVerifiedRunValid
            last_verified_run_status = if ($lastVerifiedRun) { Get-String -Obj $lastVerifiedRun -Name "status" } else { "" }
        }
        dirty_worktree = [pscustomobject][ordered]@{
            check_available = [bool]$dirtyInfo.available
            dirty_paths = @($dirtyInfo.paths)
            require_clean_for_verified = [bool]$requireCleanForVerified
        }
    }
}

$outputDir = Split-Path $outputFull -Parent
if ($outputDir) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

if ($ApplyAutoDowngrade -and $script:AutoDowngradedBatches.Count -gt 0) {
    ($registry | ConvertTo-Json -Depth 100) | Set-Content -Path $registryFull -Encoding UTF8
    Write-Host ("Auto-downgraded batch claims written to: {0}" -f ($RegistryPath -replace '\\', '/')) -ForegroundColor Cyan
}

$summary = [ordered]@{
    schema_version = "1.0"
    source_of_truth = ($OutputJsonPath -replace '\\', '/')
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    root_path = ($RootPath -replace '\\', '/')
    registry_path = ($RegistryPath -replace '\\', '/')
    schema_path = ($SchemaPath -replace '\\', '/')
    verify_runs_path = ($VerifyRunsPath -replace '\\', '/')
    auto_downgrade_requested = [bool]$ApplyAutoDowngrade.IsPresent
    auto_downgrade_applied_count = [int]$script:AutoDowngradedBatches.Count
    auto_downgraded_batches = @($script:AutoDowngradedBatches)
    report_only = [bool]$ReportOnly.IsPresent
    selected_batch_count = [int]$batchSummaries.Count
    latest_fast_run = if ($latestFastRun) {
        [ordered]@{
            run_id = (Get-String -Obj $latestFastRun -Name "run_id")
            created_at_utc = (Get-IsoUtcString -Obj $latestFastRun -Name "created_at_utc")
            status = (Get-String -Obj $latestFastRun -Name "status")
            task_id = (Get-String -Obj $latestFastRun -Name "task_id")
        }
    } else {
        $null
    }
    error_count = [int]$script:Errors.Count
    warning_count = [int]$script:Warnings.Count
    errors = @($script:Errors)
    warnings = @($script:Warnings)
    batches = @($batchSummaries)
}

($summary | ConvertTo-Json -Depth 100) | Set-Content -Path $outputFull -Encoding UTF8

Write-Host "Batch status verification summary:" -ForegroundColor Cyan
Write-Host ("  batches: {0}" -f $summary.selected_batch_count) -ForegroundColor Cyan
Write-Host ("  errors: {0}" -f $summary.error_count) -ForegroundColor Cyan
Write-Host ("  warnings: {0}" -f $summary.warning_count) -ForegroundColor Cyan
Write-Host ("  summary json: {0}" -f $summary.source_of_truth) -ForegroundColor Cyan

if ($script:Errors.Count -eq 0) {
    Write-Host "--- BATCH STATUS VERIFICATION PASSED ---" -ForegroundColor Green
    exit 0
}

if ($ReportOnly) {
    Write-Host "--- BATCH STATUS VERIFICATION REPORT-ONLY (errors recorded, non-blocking) ---" -ForegroundColor Yellow
    exit 0
}

Write-Host "--- BATCH STATUS VERIFICATION FAILED ---" -ForegroundColor Red
exit 1
