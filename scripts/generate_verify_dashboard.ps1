param(
    [string]$RootPath = "",
    [string]$CanonicalPath = "",
    [string]$OutputDir = "",
    [switch]$CheckOnly,
    [switch]$SkipPreflightWriteGuard,
    [int]$PreflightGuardMaxAgeMinutes = 120
)

$ErrorActionPreference = "Stop"

if (-not $RootPath) {
    $RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
if (-not $CanonicalPath) {
    $CanonicalPath = Join-Path $RootPath "docs_control\verify_runs.json"
}
if (-not $OutputDir) {
    $OutputDir = Join-Path $RootPath "docs\generated\control"
}

if (-not $CheckOnly.IsPresent -and -not $SkipPreflightWriteGuard.IsPresent) {
    $preflightGuardScript = Join-Path $RootPath "scripts\assert_preflight_write_guard.ps1"
    & $preflightGuardScript -RootPath $RootPath -MaxAgeMinutes $PreflightGuardMaxAgeMinutes -OperationName "generate_verify_dashboard"
    if ($LASTEXITCODE -ne 0) {
        throw "Preflight write guard failed for generate_verify_dashboard (exit=$LASTEXITCODE)."
    }
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

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

function Get-Int64Value {
    param(
        [object]$Obj,
        [string]$Name,
        [Int64]$Default = 0
    )

    $raw = Get-PropValue -Obj $Obj -Name $Name -Default $null
    if ($null -eq $raw) { return $Default }
    $parsed = 0L
    if ([Int64]::TryParse([string]$raw, [ref]$parsed)) {
        return $parsed
    }
    return $Default
}

function Escape-Cell {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return "" }
    $escaped = $Text -replace "\|", "\\|"
    $escaped = $escaped -replace "\r?\n", "<br>"
    return $escaped
}

function Get-RootCauseText {
    param([object]$Run)

    $rootCause = Get-PropValue -Obj $Run -Name "root_cause" -Default $null
    if ($null -ne $rootCause) {
        $tool = Get-StringValue -Obj $rootCause -Name "tool"
        $type = Get-StringValue -Obj $rootCause -Name "type"
        $file = Get-StringValue -Obj $rootCause -Name "file"
        $rule = Get-StringValue -Obj $rootCause -Name "rule"
        $parts = @()
        foreach ($item in @($tool, $type, $file, $rule)) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                $parts += $item
            }
        }
        if ($parts.Count -gt 0) {
            return ($parts -join " | ")
        }
    }

    $errors = To-Array (Get-PropValue -Obj $Run -Name "errors" -Default @())
    if ($errors.Count -gt 0) {
        $e = $errors[0]
        $tool = Get-StringValue -Obj $e -Name "tool"
        $type = Get-StringValue -Obj $e -Name "type"
        $file = Get-StringValue -Obj $e -Name "file"
        $rule = Get-StringValue -Obj $e -Name "rule"
        $parts = @()
        foreach ($item in @($tool, $type, $file, $rule)) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                $parts += $item
            }
        }
        if ($parts.Count -gt 0) {
            return ($parts -join " | ")
        }
    }

    return ""
}

function New-RunRow {
    param([object]$Run)

    $createdRaw = Get-PropValue -Obj $Run -Name "created_at_utc" -Default ""
    $createdUtc = ""
    if ($createdRaw -is [datetime]) {
        $createdUtc = $createdRaw.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    } elseif ($null -ne $createdRaw) {
        $createdUtc = [string]$createdRaw
    }

    $commitSha = Get-StringValue -Obj $Run -Name "commit_sha" -Default "unknown"
    $commitDisplay = if ($commitSha.Length -gt 12) { $commitSha.Substring(0, 12) } else { $commitSha }

    return [pscustomobject][ordered]@{
        run_id = Get-StringValue -Obj $Run -Name "run_id"
        created_at_utc = $createdUtc
        created_at_epoch_ms = Get-Int64Value -Obj $Run -Name "created_at_epoch_ms" -Default 0
        task_id = Get-StringValue -Obj $Run -Name "task_id"
        stage = Get-StringValue -Obj $Run -Name "stage"
        scope = Get-StringValue -Obj $Run -Name "scope"
        status = Get-StringValue -Obj $Run -Name "status"
        step_count = (To-Array (Get-PropValue -Obj $Run -Name "steps" -Default @())).Count
        error_count = Get-Int64Value -Obj $Run -Name "error_count" -Default ((To-Array (Get-PropValue -Obj $Run -Name "errors" -Default @())).Count)
        root_cause_text = Get-RootCauseText -Run $Run
        commit_sha = $commitSha
        commit_display = $commitDisplay
    }
}

function New-CanonicalFallback {
    return [pscustomobject][ordered]@{
        schema_version = "1.0"
        source_of_truth = "docs_control/verify_runs.json"
        notes = @("Canonical verify run log for deterministic ERROR LOOP / MkDocs generated views.")
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

function Join-Lines {
    param([string[]]$Lines)

    $normalized = New-Object System.Collections.Generic.List[string]
    foreach ($line in @($Lines)) {
        $normalized.Add([string]$line)
    }
    while ($normalized.Count -gt 0 -and [string]::IsNullOrWhiteSpace($normalized[$normalized.Count - 1])) {
        $normalized.RemoveAt($normalized.Count - 1)
    }

    $text = $normalized -join "`n"
    return $text.TrimEnd("`r", "`n")
}

function Check-Or-WriteMarkdownFile {
    param(
        [string]$Path,
        [string[]]$Lines,
        [switch]$OnlyCheck
    )

    $desired = Join-Lines -Lines $Lines
    $exists = Test-Path $Path
    $current = if ($exists) { Get-Content -Path $Path -Raw -Encoding UTF8 } else { $null }

    $normalize = {
        param([string]$Text)
        if ($null -eq $Text) { return $null }
        $t = $Text -replace "`r`n", "`n"
        if ($t.EndsWith("`n")) {
            $t = $t.Substring(0, $t.Length - 1)
        }
        return $t
    }

    $desiredNorm = & $normalize $desired
    $currentNorm = & $normalize $current

    if ($OnlyCheck) {
        if (-not $exists) {
            Write-Host "STALE: missing generated file $Path" -ForegroundColor Yellow
            return $false
        }
        if ($currentNorm -cne $desiredNorm) {
            Write-Host "STALE: generated file differs from canonical inputs -> $Path" -ForegroundColor Yellow
            return $false
        }
        Write-Host "FRESH: $Path" -ForegroundColor Green
        return $true
    }

    if ((-not $exists) -or ($currentNorm -cne $desiredNorm)) {
        Set-Content -Path $Path -Value $desired -Encoding UTF8
        Write-Host "Generated: $Path" -ForegroundColor Green
    }
    else {
        Write-Host "Unchanged: $Path" -ForegroundColor Cyan
    }

    return $true
}

function Get-RunTableLines {
    param(
        [object[]]$Rows,
        [switch]$Compact
    )

    $lines = New-Object System.Collections.Generic.List[string]

    if ($Compact) {
        $lines.Add("| Timestamp (UTC) | Stage | Result | Errors | Root cause | Task ID | Commit |")
        $lines.Add("| :--- | :--- | :--- | ---: | :--- | :--- | :--- |")
        if ($Rows.Count -eq 0) {
            $lines.Add("| - | - | - | 0 | - | - | - |")
            return @($lines)
        }
        foreach ($row in $Rows) {
            $rootCause = if ([string]::IsNullOrWhiteSpace($row.root_cause_text)) { "-" } else { Escape-Cell $row.root_cause_text }
            $lines.Add("| $(Escape-Cell $row.created_at_utc) | $(Escape-Cell $row.stage) | $(Escape-Cell $row.status) | $($row.error_count) | $rootCause | $(Escape-Cell $row.task_id) | $(Escape-Cell $row.commit_display) |")
        }
        return @($lines)
    }

    $lines.Add("| Timestamp (UTC) | Stage | Scope | Result | Steps | Errors | Root cause | Task ID | Commit |")
    $lines.Add("| :--- | :--- | :--- | :--- | ---: | ---: | :--- | :--- | :--- |")
    if ($Rows.Count -eq 0) {
        $lines.Add("| _No data_ | - | - | - | 0 | 0 | - | - | - |")
        return @($lines)
    }
    foreach ($row in $Rows) {
        $rootCause = if ([string]::IsNullOrWhiteSpace($row.root_cause_text)) { "-" } else { Escape-Cell $row.root_cause_text }
        $lines.Add("| $(Escape-Cell $row.created_at_utc) | $(Escape-Cell $row.stage) | $(Escape-Cell $row.scope) | $(Escape-Cell $row.status) | $($row.step_count) | $($row.error_count) | $rootCause | $(Escape-Cell $row.task_id) | $(Escape-Cell $row.commit_display) |")
    }
    return @($lines)
}

$data = Load-CanonicalData -Path $CanonicalPath
$runs = To-Array (Get-PropValue -Obj $data -Name "runs" -Default @())
$rows = @()
foreach ($run in $runs) {
    $rows += (New-RunRow -Run $run)
}

$rowsDesc = @($rows | Sort-Object `
    @{ Expression = { [Int64]$_.created_at_epoch_ms }; Descending = $true }, `
    @{ Expression = { [string]$_.run_id }; Descending = $false })
$rowsAsc = @($rows | Sort-Object `
    @{ Expression = { [Int64]$_.created_at_epoch_ms }; Descending = $false }, `
    @{ Expression = { [string]$_.run_id }; Descending = $false })

$statusMap = @{}
foreach ($row in $rowsDesc) {
    $key = "$($row.scope)|$($row.stage)"
    if (-not $statusMap.ContainsKey($key)) {
        $statusMap[$key] = $row
    }
}
$statusRows = @($statusMap.Values | Sort-Object scope, stage)

$passCount = @($rows | Where-Object { $_.status -eq "PASS" }).Count
$failCount = @($rows | Where-Object { $_.status -eq "FAIL" }).Count
$skipCount = @($rows | Where-Object { $_.status -eq "SKIP" }).Count

$statusLines = New-Object System.Collections.Generic.List[string]
$statusLines.Add("# Verify Status (Generated)")
$statusLines.Add("")
$statusLines.Add("Toto je generated view nad docs_control/verify_runs.json.")
$statusLines.Add("")
$statusLines.Add("- Canonical source of truth: docs_control/verify_runs.json")
$statusLines.Add("- Render target: docs/generated/control/VERIFY_STATUS.md")
$statusLines.Add("- Rezim razeni: posledni zaznam po (scope, stage) (DESC podle casu)")
$statusLines.Add("")
$statusLines.Add("## Summary")
$statusLines.Add("")
$statusLines.Add("- Total runs: $($rows.Count)")
$statusLines.Add("- PASS: $passCount")
$statusLines.Add("- FAIL: $failCount")
$statusLines.Add("- SKIP: $skipCount")
$statusLines.Add("")
$statusLines.Add("## Latest Status By Scope + Stage")
$statusLines.Add("")
$statusLines.Add("| Scope | Stage | Result | Timestamp (UTC) | Errors | Root cause | Task ID | Commit |")
$statusLines.Add("| :--- | :--- | :--- | :--- | ---: | :--- | :--- | :--- |")
if ($statusRows.Count -eq 0) {
    $statusLines.Add("| _No data_ | - | - | - | 0 | - | - | - |")
} else {
    foreach ($row in $statusRows) {
        $rootCause = if ([string]::IsNullOrWhiteSpace($row.root_cause_text)) { "-" } else { Escape-Cell $row.root_cause_text }
        $statusLines.Add("| $(Escape-Cell $row.scope) | $(Escape-Cell $row.stage) | $(Escape-Cell $row.status) | $(Escape-Cell $row.created_at_utc) | $($row.error_count) | $rootCause | $(Escape-Cell $row.task_id) | $(Escape-Cell $row.commit_display) |")
    }
}
$statusLines.Add("")
$statusLines.Add("## Notes")
$statusLines.Add("")
$statusLines.Add("- Tato stranka je pouze view vrstva.")
$statusLines.Add("- Realne PASS/FAIL vysledky se maji zapisovat do canonical JSON a teprve potom renderovat do MkDocs.")

$descLines = New-Object System.Collections.Generic.List[string]
$descLines.Add("# Verify Runs (DESC, Generated)")
$descLines.Add("")
$descLines.Add("Toto je generated view nad docs_control/verify_runs.json.")
$descLines.Add("")
$descLines.Add("- Razeni: globalne sestupne podle created_at_epoch_ms, potom run_id")
$descLines.Add("")
$descLines.Add("## Runs")
$descLines.Add("")
foreach ($line in (Get-RunTableLines -Rows $rowsDesc)) { $descLines.Add($line) }

$ascLines = New-Object System.Collections.Generic.List[string]
$ascLines.Add("# Verify Runs (ASC, Generated)")
$ascLines.Add("")
$ascLines.Add("Toto je generated view nad docs_control/verify_runs.json.")
$ascLines.Add("")
$ascLines.Add("- Razeni: globalne vzestupne podle created_at_epoch_ms, potom run_id")
$ascLines.Add("")
$ascLines.Add("## Runs")
$ascLines.Add("")
foreach ($line in (Get-RunTableLines -Rows $rowsAsc)) { $ascLines.Add($line) }

$byScopeLines = New-Object System.Collections.Generic.List[string]
$byScopeLines.Add("# Verify Runs By Scope (Generated)")
$byScopeLines.Add("")
$byScopeLines.Add("Toto je generated view nad docs_control/verify_runs.json.")
$byScopeLines.Add("")
$byScopeLines.Add("- Skupinovani: scope")
$byScopeLines.Add("- V ramci skupiny: DESC podle casu")
$byScopeLines.Add("")

$scopeGroups = @($rowsDesc | Group-Object -Property scope | Sort-Object Name)
if ($scopeGroups.Count -eq 0) {
    $byScopeLines.Add("## Scope: _No data_")
    $byScopeLines.Add("")
    foreach ($line in (Get-RunTableLines -Rows @() -Compact)) { $byScopeLines.Add($line) }
} else {
    foreach ($group in $scopeGroups) {
        $scopeName = if ([string]::IsNullOrWhiteSpace([string]$group.Name)) { "_empty_" } else { [string]$group.Name }
        $byScopeLines.Add("## Scope: $(Escape-Cell $scopeName)")
        $byScopeLines.Add("")
        foreach ($line in (Get-RunTableLines -Rows @($group.Group) -Compact)) { $byScopeLines.Add($line) }
        $byScopeLines.Add("")
    }
}

$allFresh = $true
$allFresh = (Check-Or-WriteMarkdownFile -Path (Join-Path $OutputDir "VERIFY_STATUS.md") -Lines @($statusLines) -OnlyCheck:$CheckOnly) -and $allFresh
$allFresh = (Check-Or-WriteMarkdownFile -Path (Join-Path $OutputDir "VERIFY_RUNS_DESC.md") -Lines @($descLines) -OnlyCheck:$CheckOnly) -and $allFresh
$allFresh = (Check-Or-WriteMarkdownFile -Path (Join-Path $OutputDir "VERIFY_RUNS_ASC.md") -Lines @($ascLines) -OnlyCheck:$CheckOnly) -and $allFresh
$allFresh = (Check-Or-WriteMarkdownFile -Path (Join-Path $OutputDir "VERIFY_RUNS_BY_SCOPE.md") -Lines @($byScopeLines) -OnlyCheck:$CheckOnly) -and $allFresh

if ($CheckOnly) {
    if ($allFresh) {
        Write-Host "Verify dashboard stale-check PASS" -ForegroundColor Green
        exit 0
    }
    Write-Host "Verify dashboard stale-check FAIL" -ForegroundColor Red
    exit 1
}

Write-Host "Generated verify dashboard pages in: $OutputDir"
exit 0
