param(
    [string]$RootPath = "",
    [string]$CanonicalPath = "",
    [Parameter(Mandatory = $true)]
    [string]$TaskId,
    [Parameter(Mandatory = $true)]
    [string]$Stage,
    [Parameter(Mandatory = $true)]
    [string]$Scope,
    [Parameter(Mandatory = $true)]
    [ValidateSet("PASS", "FAIL", "SKIP")]
    [string]$Status,
    [string]$CommitSha = "",
    [string]$CreatedAtUtc = "",
    [string]$StepsJson = "[]",
    [string]$ErrorsJson = "[]",
    [string]$EvidenceRefsJson = "[]",
    [switch]$SkipRender
)

$ErrorActionPreference = "Stop"

if (-not $RootPath) {
    $RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
if (-not $CanonicalPath) {
    $CanonicalPath = Join-Path $RootPath "docs_control\verify_runs.json"
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
    if ($null -eq $prop) { return $Default }
    if ($null -eq $prop.Value) { return $Default }
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

function Get-NullableInt {
    param(
        [object]$Obj,
        [string]$Name
    )
    $raw = Get-PropValue -Obj $Obj -Name $Name -Default $null
    if ($null -eq $raw) { return $null }
    $parsed = 0
    if ([int]::TryParse([string]$raw, [ref]$parsed)) {
        return $parsed
    }
    return $null
}

function Get-IntOrDefault {
    param(
        [object]$Obj,
        [string]$Name,
        [int]$Default = [int]::MaxValue
    )
    $value = Get-NullableInt -Obj $Obj -Name $Name
    if ($null -eq $value) { return $Default }
    return [int]$value
}

function Get-Sha256Hex {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)
        return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
        $sha.Dispose()
    }
}

function Parse-JsonArray {
    param(
        [string]$JsonText,
        [string]$Name
    )
    if ([string]::IsNullOrWhiteSpace($JsonText)) { return @() }
    try {
        $parsed = $JsonText | ConvertFrom-Json -Depth 100
        return @(To-Array $parsed)
    }
    catch {
        throw "Invalid JSON in $Name. Expected array/object JSON."
    }
}

function New-CanonicalFallback {
    return [pscustomobject][ordered]@{
        schema_version = "1.0"
        source_of_truth = "docs_control/verify_runs.json"
        notes = @(
            "Canonical verify run log for deterministic ERROR LOOP / MkDocs generated views.",
            "Markdown pages in docs/generated/control are generated views only."
        )
        runs = @()
    }
}

function Load-CanonicalData {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return (New-CanonicalFallback)
    }
    $raw = Get-Content -Path $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return (New-CanonicalFallback)
    }
    return ($raw | ConvertFrom-Json -Depth 100)
}

function Normalize-Error {
    param([object]$Err)

    $lineValue = Get-NullableInt -Obj $Err -Name "line"
    $normalized = [ordered]@{
        tool = (Get-StringValue -Obj $Err -Name "tool")
        type = (Get-StringValue -Obj $Err -Name "type")
        file = (Get-StringValue -Obj $Err -Name "file")
        rule = (Get-StringValue -Obj $Err -Name "rule")
        line = $lineValue
        step_index = (Get-NullableInt -Obj $Err -Name "step_index")
        message = (Get-StringValue -Obj $Err -Name "message")
    }
    return [pscustomobject]$normalized
}

function Normalize-Step {
    param([object]$Step)
    $duration = Get-NullableInt -Obj $Step -Name "duration_ms"
    $exitCode = Get-NullableInt -Obj $Step -Name "exit_code"
    return [pscustomobject][ordered]@{
        name = (Get-StringValue -Obj $Step -Name "name")
        tool = (Get-StringValue -Obj $Step -Name "tool")
        command = (Get-StringValue -Obj $Step -Name "command")
        status = (Get-StringValue -Obj $Step -Name "status")
        duration_ms = $duration
        exit_code = $exitCode
    }
}

function Get-LineSortValue {
    param([object]$Err)
    $line = Get-PropValue -Obj $Err -Name "line" -Default $null
    if ($null -eq $line) { return [int]::MaxValue }
    return [int]$line
}

function New-FingerprintObjects {
    param(
        [object[]]$NormalizedErrors,
        [hashtable]$HistoryCounts
    )

    $sep = [char]31
    $groups = @{}
    foreach ($err in $NormalizedErrors) {
        $key = "$($err.type)$sep$($err.file)$sep$($err.rule)"
        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = New-Object System.Collections.Generic.List[object]
        }
        $groups[$key].Add($err)
    }

    $fingerprints = @()
    foreach ($entry in ($groups.GetEnumerator() | Sort-Object Key)) {
        $parts = ([string]$entry.Key).Split(@([char]$sep))
        $type = if ($parts.Length -gt 0) { $parts[0] } else { "" }
        $file = if ($parts.Length -gt 1) { $parts[1] } else { "" }
        $rule = if ($parts.Length -gt 2) { $parts[2] } else { "" }
        $displayKey = "$type|$file|$rule"
        $fpId = (Get-Sha256Hex -Text $displayKey).Substring(0, 12)
        $count = [int]$entry.Value.Count
        $historicalBefore = if ($HistoryCounts.ContainsKey($fpId)) { [int]$HistoryCounts[$fpId] } else { 0 }
        $historicalTotal = $historicalBefore + $count

        $fingerprints += [pscustomobject][ordered]@{
            fingerprint = $fpId
            key = $displayKey
            type = $type
            file = $file
            rule = $rule
            count = $count
            historical_count_before = $historicalBefore
            historical_count_total = $historicalTotal
            docs_rule_candidate = ($historicalTotal -ge 3)
        }
    }

    return @($fingerprints)
}

function Get-CurrentCommitSha {
    param([string]$RepoRoot)
    try {
        $sha = (git -C $RepoRoot rev-parse HEAD 2>$null | Select-Object -First 1)
        if ($sha) {
            return ([string]$sha).Trim()
        }
    }
    catch {
    }
    return "unknown"
}

$stepsInput = Parse-JsonArray -JsonText $StepsJson -Name "StepsJson"
$errorsInput = Parse-JsonArray -JsonText $ErrorsJson -Name "ErrorsJson"
$evidenceRefs = Parse-JsonArray -JsonText $EvidenceRefsJson -Name "EvidenceRefsJson"

$normalizedSteps = @()
foreach ($step in $stepsInput) {
    $normalizedSteps += (Normalize-Step -Step $step)
}

$normalizedErrors = @()
foreach ($err in $errorsInput) {
    $normalizedErrors += (Normalize-Error -Err $err)
}

$canonicalDir = Split-Path $CanonicalPath -Parent
if (-not (Test-Path $canonicalDir)) {
    New-Item -ItemType Directory -Path $canonicalDir -Force | Out-Null
}

$data = Load-CanonicalData -Path $CanonicalPath
$existingRuns = @(To-Array (Get-PropValue -Obj $data -Name "runs" -Default @()))

$historyCounts = @{}
foreach ($existingRun in $existingRuns) {
    $fps = @(To-Array (Get-PropValue -Obj $existingRun -Name "fingerprints" -Default @()))
    foreach ($fp in $fps) {
        $fpId = Get-StringValue -Obj $fp -Name "fingerprint"
        if ([string]::IsNullOrWhiteSpace($fpId)) { continue }
        $countRaw = Get-PropValue -Obj $fp -Name "count" -Default 1
        $countParsed = 1
        [void][int]::TryParse([string]$countRaw, [ref]$countParsed)
        if (-not $historyCounts.ContainsKey($fpId)) {
            $historyCounts[$fpId] = 0
        }
        $historyCounts[$fpId] = [int]$historyCounts[$fpId] + $countParsed
    }
}

$fingerprints = New-FingerprintObjects -NormalizedErrors $normalizedErrors -HistoryCounts $historyCounts

$rootCause = $null
if ($normalizedErrors.Count -gt 0) {
    $root = @($normalizedErrors | Sort-Object `
        @{ Expression = { Get-IntOrDefault -Obj $_ -Name "step_index" }; Descending = $false }, `
        @{ Expression = { [string]$_.tool }; Descending = $false }, `
        @{ Expression = { [string]$_.file }; Descending = $false }, `
        @{ Expression = { [string]$_.rule }; Descending = $false }, `
        @{ Expression = { Get-LineSortValue $_ }; Descending = $false }, `
        @{ Expression = { [string]$_.type }; Descending = $false }) | Select-Object -First 1

    if ($root.Count -gt 0) {
        $r = $root[0]
        $rootCause = [pscustomobject][ordered]@{
            tool = $r.tool
            type = $r.type
            file = $r.file
            rule = $r.rule
            line = $r.line
            step_index = $r.step_index
            message = $r.message
        }
    }
}

$createdDt = if ($CreatedAtUtc) {
    [datetime]::Parse($CreatedAtUtc, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
} else {
    [datetime]::UtcNow
}
$epochStart = [datetime]"1970-01-01T00:00:00Z"
$epochMs = [Int64][Math]::Floor(($createdDt - $epochStart).TotalMilliseconds)
$createdAtIso = $createdDt.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

if (-not $CommitSha) {
    $CommitSha = Get-CurrentCommitSha -RepoRoot $RootPath
}

$runId = "vr-" + ([guid]::NewGuid().ToString("N"))

$newRun = [pscustomobject][ordered]@{
    run_id = $runId
    created_at_utc = $createdAtIso
    created_at_epoch_ms = $epochMs
    task_id = $TaskId
    commit_sha = $CommitSha
    stage = $Stage
    scope = $Scope
    status = $Status
    steps = @($normalizedSteps)
    errors = @($normalizedErrors)
    error_count = $normalizedErrors.Count
    fingerprints = @($fingerprints)
    root_cause = $rootCause
    evidence_refs = @($evidenceRefs | ForEach-Object { [string]$_ })
}

$allRuns = @($existingRuns + $newRun)
$sortedRuns = @($allRuns | Sort-Object `
    @{ Expression = { [Int64](Get-PropValue -Obj $_ -Name "created_at_epoch_ms" -Default 0) }; Descending = $true }, `
    @{ Expression = { [string](Get-StringValue -Obj $_ -Name "run_id") }; Descending = $false })

$schemaVersion = Get-StringValue -Obj $data -Name "schema_version" -Default "1.0"
$sourceOfTruth = Get-StringValue -Obj $data -Name "source_of_truth" -Default "docs_control/verify_runs.json"
$notes = @(To-Array (Get-PropValue -Obj $data -Name "notes" -Default @()))

$outRoot = [ordered]@{
    schema_version = $schemaVersion
    source_of_truth = $sourceOfTruth
    notes = @($notes)
    runs = @($sortedRuns)
}

($outRoot | ConvertTo-Json -Depth 100) | Set-Content -Path $CanonicalPath -Encoding UTF8
Write-Host "Logged verify run: $runId ($Status $Stage $Scope)"
Write-Host "Saved canonical log: $CanonicalPath"

if (-not $SkipRender) {
    $generator = Join-Path $RootPath "scripts\generate_verify_dashboard.ps1"
    if (Test-Path $generator) {
        # Logging evidence must still render dashboard even when verify failed before preflight.
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $generator -RootPath $RootPath -CanonicalPath $CanonicalPath -SkipPreflightWriteGuard
    }
}
