param(
    [string]$RootPath = "",
    [string]$NextSessionCanonicalPath = "",
    [string]$NextSessionNotePath = "",
    [string]$TraceabilityCanonicalPath = "",
    [string]$OutputDir = "",
    [switch]$CheckOnly,
    [switch]$SkipPreflightWriteGuard,
    [int]$PreflightGuardMaxAgeMinutes = 120
)

$ErrorActionPreference = "Stop"

if (-not $RootPath) {
    $RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
if (-not $NextSessionCanonicalPath) {
    $NextSessionCanonicalPath = Join-Path $RootPath "docs_control\next_session.json"
}
if (-not $NextSessionNotePath) {
    $NextSessionNotePath = Join-Path $RootPath "docs_control\next_session_note.md"
}
if (-not $TraceabilityCanonicalPath) {
    $TraceabilityCanonicalPath = Join-Path $RootPath "docs_control\traceability.json"
}
if (-not $OutputDir) {
    $OutputDir = Join-Path $RootPath "docs\generated\control"
}

if (-not $CheckOnly.IsPresent -and -not $SkipPreflightWriteGuard.IsPresent) {
    $preflightGuardScript = Join-Path $RootPath "scripts\assert_preflight_write_guard.ps1"
    & $preflightGuardScript -RootPath $RootPath -MaxAgeMinutes $PreflightGuardMaxAgeMinutes -OperationName "generate_control_docs"
    if ($LASTEXITCODE -ne 0) {
        throw "Preflight write guard failed for generate_control_docs (exit=$LASTEXITCODE)."
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

function Add-WrappedText {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Text,
        [int]$Width = 120
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        $Lines.Add("")
        return
    }

    $remaining = ($Text -replace '\s+', ' ').Trim()
    while ($remaining.Length -gt $Width) {
        $breakAt = $remaining.LastIndexOf(" ", [Math]::Min($Width, $remaining.Length - 1))
        if ($breakAt -lt 1) {
            break
        }
        $Lines.Add($remaining.Substring(0, $breakAt).TrimEnd())
        $remaining = $remaining.Substring($breakAt + 1).TrimStart()
    }
    if ($remaining.Length -gt 0) {
        $Lines.Add($remaining)
    }
}

function Add-WrappedListItem {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Text,
        [int]$Width = 120,
        [string]$Bullet = "- ",
        [string]$ContinuationPrefix = "  "
    )

    $value = if ($null -eq $Text) { "" } else { [string]$Text }
    $remaining = ($value -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($remaining)) {
        $Lines.Add("${Bullet}_Prazdne_")
        return
    }

    $firstWidth = [Math]::Max(10, $Width - $Bullet.Length)
    $nextWidth = [Math]::Max(10, $Width - $ContinuationPrefix.Length)
    $isFirst = $true
    while ($remaining.Length -gt 0) {
        $prefix = if ($isFirst) { $Bullet } else { $ContinuationPrefix }
        $allowed = if ($isFirst) { $firstWidth } else { $nextWidth }
        if ($remaining.Length -le $allowed) {
            $Lines.Add($prefix + $remaining)
            break
        }

        $breakAt = $remaining.LastIndexOf(" ", [Math]::Min($allowed, $remaining.Length - 1))
        if ($breakAt -lt 1) {
            $Lines.Add($prefix + $remaining)
            break
        }

        $Lines.Add($prefix + $remaining.Substring(0, $breakAt).TrimEnd())
        $remaining = $remaining.Substring($breakAt + 1).TrimStart()
        $isFirst = $false
    }
}

function Get-NormalizedEmbeddedNoteLines {
    param([string]$NoteText)

    if ([string]::IsNullOrWhiteSpace($NoteText)) {
        return @()
    }

    $output = New-Object System.Collections.Generic.List[string]
    $trimmed = ($NoteText -replace "`r`n", "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return @()
    }

    $skippedTopHeading = $false
    foreach ($rawLine in ($trimmed -split "`n")) {
        $line = [string]$rawLine

        if ($line -match '^\s*$') {
            if ($output.Count -eq 0 -or [string]::IsNullOrWhiteSpace($output[$output.Count - 1])) {
                continue
            }
            $output.Add("")
            continue
        }

        if ($line -match '^(?<hashes>#{1,6})\s+(?<title>.+)$') {
            $hashCount = $matches['hashes'].Length
            $title = [string]$matches['title']
            if (-not $skippedTopHeading -and $hashCount -eq 1) {
                $skippedTopHeading = $true
                continue
            }
            $newHashCount = [Math]::Min(6, $hashCount + 1)
            $line = ('#' * $newHashCount) + " " + $title
        }

        $output.Add($line)
    }

    while ($output.Count -gt 0 -and [string]::IsNullOrWhiteSpace($output[$output.Count - 1])) {
        $output.RemoveAt($output.Count - 1)
    }

    return @($output)
}

function Load-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Missing JSON file: $Path"
    }
    $raw = Get-Content -Path $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Empty JSON file: $Path"
    }
    return ($raw | ConvertFrom-Json -Depth 100)
}

function Add-WorkItemsSection {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Title,
        [object[]]$Items
    )

    $Lines.Add("### $Title")
    $Lines.Add("")
    if (@($Items).Count -eq 0) {
        $Lines.Add("- _Prazdne_")
    }
    else {
        foreach ($item in @($Items)) {
            $text = Get-StringValue -Obj $item -Name "text" -Default "(missing text)"
            Add-WrappedListItem -Lines $Lines -Text $text
        }
    }
    $Lines.Add("")
}

function Render-NextSession {
    param(
        [object]$Data,
        [string]$NoteText
    )

    $doc = Get-PropValue -Obj $Data -Name "document" -Default ([pscustomobject]@{})
    $state = Get-PropValue -Obj $Data -Name "state_realization" -Default ([pscustomobject]@{})
    $ctx = Get-PropValue -Obj $Data -Name "current_context" -Default ([pscustomobject]@{})
    $checkpoint = Get-PropValue -Obj $Data -Name "workflow_alignment_checkpoint" -Default ([pscustomobject]@{})
    $firstActions = Get-PropValue -Obj $Data -Name "first_next_session_actions" -Default ([pscustomobject]@{})

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# NEXT_SESSION (Generated Control View)")
    $lines.Add("")
    $lines.Add('Toto je generated view nad `docs_control/next_session.json` + `docs_control/next_session_note.md`.')
    $lines.Add("")
    $lines.Add(("**Cesta:** {0}" -f (Get-StringValue -Obj $doc -Name "path" -Default "docs/generated/control/NEXT_SESSION.md")))
    $lines.Add(("**Verze:** {0}" -f (Get-StringValue -Obj $doc -Name "version" -Default "unknown")))
    $lines.Add(("**Vytvoreno:** {0}" -f (Get-StringValue -Obj $doc -Name "created_at" -Default "unknown")))
    $lines.Add(("**Posledni zmena:** {0}" -f (Get-StringValue -Obj $doc -Name "updated_at" -Default "unknown")))
    $lines.Add(("**Status:** {0}" -f (Get-StringValue -Obj $doc -Name "status_text" -Default "unknown")))
    $lines.Add(("**Lifecycle state (control):** {0}" -f (Get-StringValue -Obj $Data -Name "lifecycle_state" -Default "unknown")))
    $lines.Add("")
    $lines.Add("## 0. Stav realizace")
    $lines.Add("")
    Add-WorkItemsSection -Lines $lines -Title "Neprovedeno" -Items (To-Array (Get-PropValue -Obj $state -Name "neprovedeno" -Default @()))
    Add-WorkItemsSection -Lines $lines -Title "Rozpracovane" -Items (To-Array (Get-PropValue -Obj $state -Name "rozpracovane" -Default @()))
    Add-WorkItemsSection -Lines $lines -Title "Provedeno" -Items (To-Array (Get-PropValue -Obj $state -Name "provedeno" -Default @()))
    $lines.Add("### Poznamka")
    $lines.Add("")
    Add-WrappedText -Lines $lines -Text (Get-StringValue -Obj $state -Name "poznamka" -Default "")
    $lines.Add("")
    $lines.Add("## 1. Aktualni kontext")
    $lines.Add("")
    Add-WrappedText -Lines $lines -Text (Get-StringValue -Obj $ctx -Name "summary" -Default "")
    $lines.Add("")
    $lines.Add("### Co je hotove")
    $lines.Add("")
    foreach ($row in (To-Array (Get-PropValue -Obj $ctx -Name "hotovo" -Default @()))) {
        Add-WrappedListItem -Lines $lines -Text ([string]$row)
    }
    if ((To-Array (Get-PropValue -Obj $ctx -Name "hotovo" -Default @())).Count -eq 0) {
        $lines.Add("- _Prazdne_")
    }
    $lines.Add("")
    $lines.Add("### Kriticky aktualni problem")
    $lines.Add("")
    foreach ($row in (To-Array (Get-PropValue -Obj $ctx -Name "kriticky_problem" -Default @()))) {
        Add-WrappedListItem -Lines $lines -Text ([string]$row)
    }
    if ((To-Array (Get-PropValue -Obj $ctx -Name "kriticky_problem" -Default @())).Count -eq 0) {
        $lines.Add("- _Prazdne_")
    }
    $lines.Add("")
    $lines.Add("## 2. Dalsi kroky (control)")
    $lines.Add("")
    foreach ($step in (To-Array (Get-PropValue -Obj $Data -Name "next_steps" -Default @()))) {
        $lines.Add(("### {0} [{1}]" -f (Get-StringValue -Obj $step -Name "title" -Default "Untitled"), (Get-StringValue -Obj $step -Name "priority" -Default "n/a")))
        $lines.Add("")
        foreach ($action in (To-Array (Get-PropValue -Obj $step -Name "actions" -Default @()))) {
            Add-WrappedListItem -Lines $lines -Text ([string]$action)
        }
        $acceptance = To-Array (Get-PropValue -Obj $step -Name "acceptance" -Default @())
        if ($acceptance.Count -gt 0) {
            $lines.Add("")
            $lines.Add("Akceptace:")
            $lines.Add("")
            foreach ($item in $acceptance) {
                Add-WrappedListItem -Lines $lines -Text ([string]$item)
            }
        }
        $lines.Add("")
    }
    $lines.Add("## 3. Prvni konkretni krok pristi session")
    $lines.Add("")
    $commands = To-Array (Get-PropValue -Obj $firstActions -Name "commands" -Default @())
    if ($commands.Count -gt 0) {
        $lines.Add('```powershell')
        foreach ($cmd in $commands) {
            $lines.Add([string]$cmd)
        }
        $lines.Add('```')
        $lines.Add("")
    }
    foreach ($row in (To-Array (Get-PropValue -Obj $firstActions -Name "after_commands" -Default @()))) {
        Add-WrappedListItem -Lines $lines -Text ([string]$row)
    }
    if ((To-Array (Get-PropValue -Obj $firstActions -Name "after_commands" -Default @())).Count -eq 0) {
        $lines.Add("- _Bez doplnujicich kroku_")
    }
    $lines.Add("")
    $lines.Add("## Checkpoint (workflow alignment)")
    $lines.Add("")
    $lines.Add("### Hook")
    $lines.Add("")
    foreach ($row in (To-Array (Get-PropValue -Obj $checkpoint -Name "hook" -Default @()))) {
        Add-WrappedListItem -Lines $lines -Text ([string]$row)
    }
    if ((To-Array (Get-PropValue -Obj $checkpoint -Name "hook" -Default @())).Count -eq 0) {
        $lines.Add("- _Prazdne_")
    }
    $lines.Add("")
    $lines.Add("### CI")
    $lines.Add("")
    foreach ($row in (To-Array (Get-PropValue -Obj $checkpoint -Name "ci" -Default @()))) {
        Add-WrappedListItem -Lines $lines -Text ([string]$row)
    }
    if ((To-Array (Get-PropValue -Obj $checkpoint -Name "ci" -Default @())).Count -eq 0) {
        $lines.Add("- _Prazdne_")
    }
    $lines.Add("")
    $lines.Add("### Docs")
    $lines.Add("")
    foreach ($row in (To-Array (Get-PropValue -Obj $checkpoint -Name "docs" -Default @()))) {
        Add-WrappedListItem -Lines $lines -Text ([string]$row)
    }
    if ((To-Array (Get-PropValue -Obj $checkpoint -Name "docs" -Default @())).Count -eq 0) {
        $lines.Add("- _Prazdne_")
    }
    $notes = To-Array (Get-PropValue -Obj $checkpoint -Name "notes" -Default @())
    if ($notes.Count -gt 0) {
        $lines.Add("")
        $lines.Add("Poznamky:")
        $lines.Add("")
        foreach ($row in $notes) {
            Add-WrappedListItem -Lines $lines -Text ([string]$row)
        }
    }
    $lines.Add("")
    $lines.Add("## Evidence policy")
    $lines.Add("")
    $policy = Get-PropValue -Obj $Data -Name "evidence_policy" -Default ([pscustomobject]@{})
    foreach ($row in (To-Array (Get-PropValue -Obj $policy -Name "implemented_requires" -Default @()))) {
        Add-WrappedListItem -Lines $lines -Text ("IMPLEMENTED/HOTOVO vyzaduje: {0}" -f ([string]$row))
    }
    if ((To-Array (Get-PropValue -Obj $policy -Name "implemented_requires" -Default @())).Count -eq 0) {
        $lines.Add("- _Nedefinovano_")
    }
    $lines.Add("")
    $lines.Add("## Evidence (current)")
    $lines.Add("")
    foreach ($ev in (To-Array (Get-PropValue -Obj $Data -Name "evidence" -Default @()))) {
        Add-WrappedListItem -Lines $lines -Text ('`{0}` | `{1}` | `{2}` | {3}' -f `
                (Get-StringValue -Obj $ev -Name "evidence_id" -Default "unknown"), `
                (Get-StringValue -Obj $ev -Name "result" -Default "unknown"), `
                (Get-StringValue -Obj $ev -Name "kind" -Default "unknown"), `
                (Get-StringValue -Obj $ev -Name "source" -Default "unknown"))
    }
    if ((To-Array (Get-PropValue -Obj $Data -Name "evidence" -Default @())).Count -eq 0) {
        $lines.Add("- _Bez evidence_")
    }
    $lines.Add("")
    $lines.Add("## Traceability refs (control IDs)")
    $lines.Add("")
    $refs = Get-PropValue -Obj $Data -Name "traceability_refs" -Default ([pscustomobject]@{})
    foreach ($name in @("spec_ids", "plan_ids", "task_ids", "code_ref_ids", "test_ids", "doc_ids", "log_ids", "evidence_ids")) {
        $values = To-Array (Get-PropValue -Obj $refs -Name $name -Default @())
        $lines.Add(('- `{0}`:' -f $name))
        if ($values.Count -eq 0) {
            $lines.Add("  - _empty_")
            continue
        }
        foreach ($value in $values) {
            Add-WrappedListItem -Lines $lines -Text ('`{0}`' -f ([string]$value)) -Bullet "  - " -ContinuationPrefix "    "
        }
    }
    $lines.Add("")
    $lines.Add("## Narativni poznamka (manual, non-control)")
    $lines.Add("")
    if ([string]::IsNullOrWhiteSpace($NoteText)) {
        $lines.Add("_Poznamka je prazdna._")
    }
    else {
        foreach ($line in (Get-NormalizedEmbeddedNoteLines -NoteText $NoteText)) {
            $lines.Add($line)
        }
    }
    $lines.Add("")
    $lines.Add("## Source of Truth")
    $lines.Add("")
    $lines.Add('- Canonical control data: `docs_control/next_session.json`')
    $lines.Add('- Canonical schema: `docs_control/next_session.schema.json`')
    $lines.Add('- Narrative note (manual): `docs_control/next_session_note.md`')
    $lines.Add("- This file is generated. Manual edits are forbidden.")
    return @($lines)
}

function Render-TraceabilitySummary {
    param([object]$Data)

    $entities = Get-PropValue -Obj $Data -Name "entities" -Default ([pscustomobject]@{})
    $links = To-Array (Get-PropValue -Obj $Data -Name "links" -Default @())

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Traceability Summary (Generated)")
    $lines.Add("")
    $lines.Add('Toto je generated view nad `docs_control/traceability.json`.')
    $lines.Add("")
    $lines.Add("- Canonical source of truth: docs_control/traceability.json")
    $lines.Add("- Canonical schema: docs_control/traceability.schema.json")
    $lines.Add("- This file is generated. Manual edits are forbidden.")
    $lines.Add("")
    $lines.Add("## Summary")
    $lines.Add("")
    foreach ($name in @("specs", "plans", "tasks", "code_refs", "tests", "docs", "logs", "evidence")) {
        $count = (To-Array (Get-PropValue -Obj $entities -Name $name -Default @())).Count
        $lines.Add("- ${name}: $count")
    }
    $lines.Add("- links: $($links.Count)")
    $lines.Add("")
    $lines.Add("## Links")
    $lines.Add("")
    $lines.Add("| Link ID | Spec | Plan | Task | Code refs | Tests | Docs | Logs | Evidence |")
    $lines.Add("| :--- | :--- | :--- | :--- | ---: | ---: | ---: | ---: | ---: |")
    if ($links.Count -eq 0) {
        $lines.Add("| _No data_ | - | - | - | 0 | 0 | 0 | 0 | 0 |")
    }
    else {
        foreach ($link in $links) {
            $lines.Add(('| `{0}` | `{1}` | `{2}` | `{3}` | {4} | {5} | {6} | {7} | {8} |' -f `
                    (Get-StringValue -Obj $link -Name "link_id" -Default ""), `
                    (Get-StringValue -Obj $link -Name "spec_id" -Default "-"), `
                    (Get-StringValue -Obj $link -Name "plan_id" -Default "-"), `
                    (Get-StringValue -Obj $link -Name "task_id" -Default "-"), `
                    (To-Array (Get-PropValue -Obj $link -Name "code_ref_ids" -Default @())).Count, `
                    (To-Array (Get-PropValue -Obj $link -Name "test_ids" -Default @())).Count, `
                    (To-Array (Get-PropValue -Obj $link -Name "doc_ids" -Default @())).Count, `
                    (To-Array (Get-PropValue -Obj $link -Name "log_ids" -Default @())).Count, `
                    (To-Array (Get-PropValue -Obj $link -Name "evidence_ids" -Default @())).Count))
        }
    }
    return @($lines)
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
    $joined = ($normalized -join "`n")
    return $joined.TrimEnd("`r", "`n")
}

function Check-Or-WriteFile {
    param(
        [string]$Path,
        [string[]]$RenderedLines,
        [switch]$OnlyCheck
    )

    $desired = Join-Lines -Lines $RenderedLines
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

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$nextData = Load-JsonFile -Path $NextSessionCanonicalPath
$noteText = if (Test-Path $NextSessionNotePath) { Get-Content -Path $NextSessionNotePath -Raw -Encoding UTF8 } else { "" }
$traceData = Load-JsonFile -Path $TraceabilityCanonicalPath

$nextLines = Render-NextSession -Data $nextData -NoteText $noteText
$traceLines = Render-TraceabilitySummary -Data $traceData

$nextTarget = Join-Path $OutputDir "NEXT_SESSION.md"
$traceTarget = Join-Path $OutputDir "TRACEABILITY_SUMMARY.md"

$allFresh = $true
$allFresh = (Check-Or-WriteFile -Path $nextTarget -RenderedLines $nextLines -OnlyCheck:$CheckOnly) -and $allFresh
$allFresh = (Check-Or-WriteFile -Path $traceTarget -RenderedLines $traceLines -OnlyCheck:$CheckOnly) -and $allFresh

if ($CheckOnly) {
    if ($allFresh) {
        Write-Host "Control docs stale-check PASS" -ForegroundColor Green
        exit 0
    }
    Write-Host "Control docs stale-check FAIL" -ForegroundColor Red
    exit 1
}

Write-Host "Control docs generation completed." -ForegroundColor Green
exit 0
