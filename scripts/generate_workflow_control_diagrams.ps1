param(
    [string]$RootPath = ".",
    [string]$CanonicalPath = "docs_control/workflow_control_plane.json",
    [string]$GraphvizDotPath = "",
    [switch]$CheckOnly,
    [switch]$DetailedOutput,
    [switch]$SkipPreflightWriteGuard,
    [int]$PreflightGuardMaxAgeMinutes = 120
)

$ErrorActionPreference = "Stop"
$script:Errors = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:Diffs = New-Object System.Collections.Generic.List[string]
$script:Written = New-Object System.Collections.Generic.List[string]

if (-not $CheckOnly.IsPresent -and -not $SkipPreflightWriteGuard.IsPresent) {
    $preflightGuardScript = Join-Path $RootPath "scripts\assert_preflight_write_guard.ps1"
    & $preflightGuardScript -RootPath $RootPath -MaxAgeMinutes $PreflightGuardMaxAgeMinutes -OperationName "generate_workflow_control_diagrams"
    if ($LASTEXITCODE -ne 0) {
        throw "Preflight write guard failed for generate_workflow_control_diagrams (exit=$LASTEXITCODE)."
    }
}

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

function Add-Error { param([string]$Message) $script:Errors.Add($Message); Write-Log "ERROR: $Message" "ERROR" }
function Add-Warn { param([string]$Message) $script:Warnings.Add($Message); Write-Log "WARN: $Message" "WARN" }

function Resolve-RepoPath { param([string]$PathValue) (Join-Path $RootPath $PathValue) }

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

function Sort-ByOrderThenId {
    param([object[]]$Items, [string]$IdField)
    return @($Items | Sort-Object @{ Expression = { [int](Get-Prop -Obj $_ -Name "order_index" -Default 999999) } }, @{ Expression = { (Get-String -Obj $_ -Name $IdField) } })
}

function Ensure-ParentDir {
    param([string]$PathValue)
    $parent = Split-Path -Path $PathValue -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Read-FileLf {
    param([string]$PathValue)
    if (-not (Test-Path $PathValue)) { return $null }
    $text = [System.IO.File]::ReadAllText((Resolve-Path $PathValue), [System.Text.Encoding]::UTF8)
    return ($text -replace "`r`n", "`n")
}

function Write-FileLf {
    param([string]$PathValue, [string]$Content)
    Ensure-ParentDir -PathValue $PathValue
    $normalized = ($Content -replace "`r`n", "`n")
    if (-not $normalized.EndsWith("`n")) { $normalized += "`n" }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($PathValue, $normalized, $enc)
}

function Apply-Output {
    param([string]$PathValue, [string]$Content)
    $current = Read-FileLf -PathValue $PathValue
    $next = ($Content -replace "`r`n", "`n")
    if (-not $next.EndsWith("`n")) { $next += "`n" }
    if ($current -cne $next) {
        if ($CheckOnly) {
            $script:Diffs.Add($PathValue)
            Add-Error "Stale generated output: $PathValue"
        } else {
            Write-FileLf -PathValue $PathValue -Content $next
            $script:Written.Add($PathValue)
            Write-Log "WROTE: $PathValue" "SUCCESS"
        }
    } else {
        Write-Log "OK: $PathValue unchanged" "INFO"
    }
}

function Get-Map {
    param([object[]]$Items, [string]$IdField)
    $h = @{}
    foreach ($item in @($Items)) {
        $id = Get-String -Obj $item -Name $IdField
        if (-not [string]::IsNullOrWhiteSpace($id)) { $h[$id] = $item }
    }
    return $h
}

function Get-StableHashBand {
    param(
        [string]$Value,
        [int]$Modulo = 3
    )

    if ($Modulo -le 0 -or [string]::IsNullOrWhiteSpace($Value)) {
        return 0
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value.ToLowerInvariant())
        $hash = $sha.ComputeHash($bytes)
        $num = [BitConverter]::ToUInt32($hash, 0)
        return [int]($num % [uint32]$Modulo)
    }
    finally {
        $sha.Dispose()
    }
}

function Test-TagMatch {
    param([object]$Item, [string[]]$Tags)
    if (@($Tags).Count -eq 0) { return $false }
    $itemTags = To-Array (Get-Prop -Obj $Item -Name "domain_tags" -Default @())
    foreach ($t in $itemTags) {
        if ($Tags -contains [string]$t) { return $true }
    }
    return $false
}

function Select-ViewGraph {
    param(
        [object]$View,
        [object[]]$Actors,
        [object[]]$Artifacts,
        [object[]]$Nodes,
        [object[]]$Edges
    )

    $selectors = Get-Prop -Obj $View -Name "selectors" -Default ([pscustomobject]@{})
    $incNodeIds = @(To-Array (Get-Prop -Obj $selectors -Name "include_node_ids" -Default @()) | ForEach-Object { [string]$_ })
    $incArtIds = @(To-Array (Get-Prop -Obj $selectors -Name "include_artifact_ids" -Default @()) | ForEach-Object { [string]$_ })
    $incTags = @(To-Array (Get-Prop -Obj $selectors -Name "include_domain_tags" -Default @()) | ForEach-Object { [string]$_ })
    $excNodeIds = @(To-Array (Get-Prop -Obj $selectors -Name "exclude_node_ids" -Default @()) | ForEach-Object { [string]$_ })
    $excArtIds = @(To-Array (Get-Prop -Obj $selectors -Name "exclude_artifact_ids" -Default @()) | ForEach-Object { [string]$_ })
    $excTags = @(To-Array (Get-Prop -Obj $selectors -Name "exclude_domain_tags" -Default @()) | ForEach-Object { [string]$_ })

    $selectedNodes = @()
    foreach ($n in $Nodes) {
        $nid = Get-String -Obj $n -Name "node_id"
        $include = ($incNodeIds.Count -eq 0 -and $incTags.Count -eq 0) -or ($incNodeIds -contains $nid) -or (Test-TagMatch -Item $n -Tags $incTags)
        $exclude = ($excNodeIds -contains $nid) -or (Test-TagMatch -Item $n -Tags $excTags)
        if ($include -and -not $exclude) { $selectedNodes += $n }
    }

    $selectedArtifacts = @()
    foreach ($a in $Artifacts) {
        $aid = Get-String -Obj $a -Name "artifact_id"
        $include = ($incArtIds.Count -eq 0 -and $incTags.Count -eq 0) -or ($incArtIds -contains $aid) -or (Test-TagMatch -Item $a -Tags $incTags)
        $exclude = ($excArtIds -contains $aid) -or (Test-TagMatch -Item $a -Tags $excTags)
        if ($include -and -not $exclude) { $selectedArtifacts += $a }
    }

    $nonActorEndpointIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($x in $selectedArtifacts) { [void]$nonActorEndpointIds.Add((Get-String -Obj $x -Name "artifact_id")) }
    foreach ($x in $selectedNodes) { [void]$nonActorEndpointIds.Add((Get-String -Obj $x -Name "node_id")) }

    $selectedActors = @()
    foreach ($actor in $Actors) {
        $actorId = Get-String -Obj $actor -Name "actor_id"
        $exclude = (Test-TagMatch -Item $actor -Tags $excTags)
        if ($exclude) { continue }

        $include = $false
        if ($incTags.Count -gt 0) {
            $include = (Test-TagMatch -Item $actor -Tags $incTags)
        }
        else {
            # In ID-focused views, only include actors that actually connect to selected nodes/artifacts.
            foreach ($e in $Edges) {
                $from = Get-String -Obj $e -Name "from"
                $to = Get-String -Obj $e -Name "to"
                if (($from -ieq $actorId -and $nonActorEndpointIds.Contains($to)) -or
                    ($to -ieq $actorId -and $nonActorEndpointIds.Contains($from))) {
                    $include = $true
                    break
                }
            }
        }

        if ($include) { $selectedActors += $actor }
    }

    $endpointIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($x in $selectedActors) { [void]$endpointIds.Add((Get-String -Obj $x -Name "actor_id")) }
    foreach ($x in $selectedArtifacts) { [void]$endpointIds.Add((Get-String -Obj $x -Name "artifact_id")) }
    foreach ($x in $selectedNodes) { [void]$endpointIds.Add((Get-String -Obj $x -Name "node_id")) }

    $selectedEdges = @()
    foreach ($e in $Edges) {
        $from = Get-String -Obj $e -Name "from"
        $to = Get-String -Obj $e -Name "to"
        if ($endpointIds.Contains($from) -and $endpointIds.Contains($to)) { $selectedEdges += $e }
    }

    return [pscustomobject]@{
        Actors = (Sort-ByOrderThenId -Items $selectedActors -IdField "actor_id")
        Artifacts = (Sort-ByOrderThenId -Items $selectedArtifacts -IdField "artifact_id")
        Nodes = (Sort-ByOrderThenId -Items $selectedNodes -IdField "node_id")
        Edges = (Sort-ByOrderThenId -Items $selectedEdges -IdField "edge_id")
    }
}

function Convert-IdForMermaid { param([string]$Id) return (($Id -replace "[^A-Za-z0-9_]", "_")) }
function Escape-MermaidLabel { param([string]$s) return (($s -replace '"', "'")) }
function Escape-DotLabel { param([string]$s) return (($s -replace '"', '\"')) }

function Convert-ToDotAttrString {
    param([hashtable]$Attrs)
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($key in @($Attrs.Keys | Sort-Object)) {
        $value = $Attrs[$key]
        if ($null -eq $value) { continue }
        $text = if ($value -is [bool]) { if ($value) { "true" } else { "false" } } else { [string]$value }
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $parts.Add($key + "=`"" + (Escape-DotLabel $text) + "`"")
    }
    if ($parts.Count -eq 0) { return "" }
    return "[" + ($parts -join ", ") + "]"
}

function Get-ItemTags {
    param([object]$Item)
    return @(To-Array (Get-Prop -Obj $Item -Name "domain_tags" -Default @()) | ForEach-Object { [string]$_ })
}

function Get-PrimaryDomainTag {
    param([object]$Item)
    $tags = Get-ItemTags -Item $Item
    foreach ($preferred in @(
            "ci",
            "hooks",
            "docs_publish",
            "generate",
            "traceability",
            "validate",
            "lint",
            "test",
            "log",
            "evidence",
            "manual_review",
            "exceptions_non_blocking",
            "update"
        )) {
        if ($tags -contains $preferred) { return $preferred }
    }
    if ($tags.Count -gt 0) { return $tags[0] }
    return "default"
}

function Get-DomainPalette {
    param([string]$Tag)
    switch ($Tag) {
        "validate" { return @{ Fill = "#E8F1FF"; Stroke = "#1D4ED8"; Font = "#1E3A8A" } }
        "generate" { return @{ Fill = "#E6FFFB"; Stroke = "#0F766E"; Font = "#134E4A" } }
        "lint" { return @{ Fill = "#FFF7E6"; Stroke = "#B45309"; Font = "#7C2D12" } }
        "test" { return @{ Fill = "#ECFDF3"; Stroke = "#15803D"; Font = "#14532D" } }
        "log" { return @{ Fill = "#ECFEFF"; Stroke = "#0E7490"; Font = "#164E63" } }
        "evidence" { return @{ Fill = "#ECFEFF"; Stroke = "#0891B2"; Font = "#164E63" } }
        "traceability" { return @{ Fill = "#F1F5F9"; Stroke = "#475569"; Font = "#334155" } }
        "hooks" { return @{ Fill = "#EEF2FF"; Stroke = "#4338CA"; Font = "#312E81" } }
        "ci" { return @{ Fill = "#EEF2FF"; Stroke = "#3730A3"; Font = "#312E81" } }
        "docs_publish" { return @{ Fill = "#F5F3FF"; Stroke = "#6D28D9"; Font = "#4C1D95" } }
        "manual_review" { return @{ Fill = "#FFF1F2"; Stroke = "#BE123C"; Font = "#881337" } }
        "exceptions_non_blocking" { return @{ Fill = "#FFF7ED"; Stroke = "#C2410C"; Font = "#9A3412" } }
        "update" { return @{ Fill = "#EFF6FF"; Stroke = "#0369A1"; Font = "#0C4A6E" } }
        default { return @{ Fill = "#FFFFFF"; Stroke = "#6B7280"; Font = "#111827" } }
    }
}

function Get-NodeBucketKey {
    param([object]$Node)
    $kind = Get-String -Obj $Node -Name "kind"
    switch ($kind) {
        "ci_job" { return "ci_jobs" }
        "ci_step" { return "ci_jobs" }
        "hook" { return "entry_and_hooks" }
        "generator" { return "generators_extractors" }
        "linter" { return "quality_checks" }
        "test" { return "quality_checks" }
        "log_sink" { return "evidence_and_logs" }
        "evidence_sink" { return "evidence_and_logs" }
        "validator" { return "orchestration_and_guards" }
        "gate" { return "orchestration_and_guards" }
        "script" { return "orchestration_and_guards" }
        "decision" { return "orchestration_and_guards" }
        "manual_action" { return "orchestration_and_guards" }
        default { return "orchestration_and_guards" }
    }
}

function Get-DotWrappedLabel {
    param([string]$Text, [int]$MaxLen = 28)
    if ([string]::IsNullOrWhiteSpace($Text) -or $Text.Length -le $MaxLen) { return $Text }
    $words = @($Text -split '\s+' | Where-Object { $_ -ne "" })
    if ($words.Count -le 1) { return $Text }
    $lines = New-Object System.Collections.Generic.List[string]
    $current = ""
    foreach ($w in $words) {
        $candidate = if ([string]::IsNullOrWhiteSpace($current)) { $w } else { "$current $w" }
        if ($candidate.Length -gt $MaxLen -and -not [string]::IsNullOrWhiteSpace($current)) {
            $lines.Add($current)
            $current = $w
        }
        else {
            $current = $candidate
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($current)) { $lines.Add($current) }
    if ($lines.Count -eq 0) { return $Text }
    return ($lines -join '\n')
}

function Get-DotStackedWordLabel {
    param(
        [string]$Text,
        [int]$MinLengthToStack = 16
    )
    if ([string]::IsNullOrWhiteSpace($Text)) { return $Text }
    $words = @($Text -split '\s+' | Where-Object { $_ -ne "" })
    if ($words.Count -le 1 -or $Text.Length -lt $MinLengthToStack) { return $Text }
    return ($words -join '\n')
}

function Get-ArtifactVisualTag {
    param([object]$Artifact)
    $kind = Get-String -Obj $Artifact -Name "kind"
    $tags = Get-ItemTags -Item $Artifact
    if ($kind -in @("log", "evidence")) {
        return "evidence"
    }
    elseif ($kind -eq "observed_manifest") {
        return "generate"
    }
    elseif ($kind -eq "schema") {
        return "traceability"
    }
    elseif ($kind -in @("generated_doc", "generated_diagram")) {
        if ($tags -contains "docs_publish") { return "docs_publish" }
        return "generate"
    }
    return (Get-PrimaryDomainTag -Item $Artifact)
}

function Get-MermaidContent {
    param([object]$View, [object]$Graph)
    $layout = Get-String -Obj $View -Name "layout"
    $dir = if ($layout -eq "flow_lr") { "LR" } else { "TB" }
    $lines = New-Object System.Collections.Generic.List[string]
    $viewId = Get-String -Obj $View -Name "view_id"
    $lines.Add("%% Generated from docs_control/workflow_control_plane.json")
    $lines.Add("%% view_id: $viewId")
    $lines.Add("flowchart $dir")

    foreach ($a in $Graph.Actors) {
        $id = Get-String -Obj $a -Name "actor_id"
        $label = Escape-MermaidLabel (Get-String -Obj $a -Name "label")
        $mid = Convert-IdForMermaid $id
        $lines.Add("  $mid{{`"$label`"}}")
    }
    foreach ($n in $Graph.Nodes) {
        $id = Get-String -Obj $n -Name "node_id"
        $label = Escape-MermaidLabel (Get-String -Obj $n -Name "label")
        $mid = Convert-IdForMermaid $id
        $kind = Get-String -Obj $n -Name "kind"
        if ($kind -eq "decision") {
            $lines.Add("  $mid{`"$label`"}")
        } elseif ($kind -in @("gate","validator","linter","test","hook","ci_job","ci_step")) {
            $lines.Add("  $mid([`"$label`"])")
        } else {
            $lines.Add("  $mid[`"$label`"]")
        }
    }
    foreach ($a in $Graph.Artifacts) {
        $id = Get-String -Obj $a -Name "artifact_id"
        $label = Escape-MermaidLabel (Get-String -Obj $a -Name "label")
        $mid = Convert-IdForMermaid $id
        $lines.Add("  $mid[( `"$label`" )]")
    }
    foreach ($e in $Graph.Edges) {
        $from = Convert-IdForMermaid (Get-String -Obj $e -Name "from")
        $to = Convert-IdForMermaid (Get-String -Obj $e -Name "to")
        $relation = Get-String -Obj $e -Name "relation"
        $condition = Get-String -Obj $e -Name "condition"
        $label = Escape-MermaidLabel ("$condition / $relation")
        $lines.Add("  $from -->|$label| $to")
    }
    return ($lines -join "`n")
}

function Get-DotContent {
    param(
        [object]$View,
        [object]$Graph,
        [ValidateSet("default", "full_compact", "full_literal")]
        [string]$RenderProfile = "default"
    )
    $layout = Get-String -Obj $View -Name "layout"
    $rankdir = if ($layout -eq "flow_lr") { "LR" } else { "TB" }
    $lines = New-Object System.Collections.Generic.List[string]
    $viewId = Get-String -Obj $View -Name "view_id"
    $viewLabel = Get-String -Obj $View -Name "label"
    $viewPurpose = Get-String -Obj $View -Name "purpose"
    $isFullView = ($viewId -eq "view.full_control_plane")
    $isCompactFull = ($isFullView -and $RenderProfile -eq "full_compact")
    $isLiteralFull = ($isFullView -and $RenderProfile -eq "full_literal")
    $metaLabelSuffix = ""
    if ($isFullView) {
        $metaParts = New-Object System.Collections.Generic.List[string]
        if (-not [string]::IsNullOrWhiteSpace($script:ModelVersion)) { $metaParts.Add("v$($script:ModelVersion)") }
        if (-not [string]::IsNullOrWhiteSpace($script:ModelUpdatedUtc)) { $metaParts.Add("data=$($script:ModelUpdatedUtc)") }
        if ($metaParts.Count -gt 0) {
            $metaLabelSuffix = '\n' + ($metaParts -join ' | ')
        }
    }
    $baseGraphLabel = if ($isCompactFull) { "$viewLabel (compact)" } elseif ($isLiteralFull) { "$viewLabel (literal-rotated)" } else { $viewLabel }
    $lines.Add("digraph `"$viewId`" {")
    $lines.Add("  rankdir=$rankdir;")
    $graphAttrs = @{
        fontname = "Arial"
        labelloc = "t"
        labeljust = "l"
        label = ($baseGraphLabel + $metaLabelSuffix)
        tooltip = $viewPurpose
        splines = $(if ($isLiteralFull) { "ortho" } else { "polyline" })
        overlap = "false"
        compound = $true
        newrank = $true
        ordering = "out"
        outputorder = "edgesfirst"
        forcelabels = $true
        ranksep = $(if ($isLiteralFull) { "1.45" } elseif ($isCompactFull) { "1.2" } elseif ($isFullView) { "0.95" } else { "0.8" })
        nodesep = $(if ($isLiteralFull) { "0.25" } elseif ($isCompactFull) { "0.55" } elseif ($isFullView) { "0.4" } else { "0.5" })
        pad = "0.25"
        bgcolor = "#FFFFFF"
    }
    if (-not $isFullView) { $graphAttrs["concentrate"] = $true }
    if ($isCompactFull) { $graphAttrs["label"] = "$viewLabel (compact / less wide)$metaLabelSuffix" }
    if ($isLiteralFull) { $graphAttrs["label"] = "$viewLabel (literal / rotated artifacts)$metaLabelSuffix" }
    $lines.Add("  graph " + (Convert-ToDotAttrString -Attrs $graphAttrs) + ";")
    $lines.Add("  node " + (Convert-ToDotAttrString -Attrs @{
                fontname = "Arial"
                shape = "box"
                style = "rounded,filled"
                fillcolor = "#FFFFFF"
                color = "#6B7280"
                fontcolor = "#111827"
                penwidth = "1.2"
                margin = "0.10,0.06"
                fontsize = "10"
            }) + ";")
    $lines.Add("  edge " + (Convert-ToDotAttrString -Attrs @{
                fontname = "Arial"
                color = "#64748B"
                fontcolor = "#475569"
                penwidth = "1.1"
                arrowsize = "0.7"
                fontsize = "9"
            }) + ";")

    $artifactMap = Get-Map -Items $Graph.Artifacts -IdField "artifact_id"

    $nodeBucketDefs = [ordered]@{
        "entry_and_hooks" = @{
            Label = "Entry + Hooks"
            Border = "#C7D2FE"
            Fill = "#F5F3FF"
            Nodes = (New-Object System.Collections.Generic.List[object])
        }
        "orchestration_and_guards" = @{
            Label = "Orchestration + Guards"
            Border = "#BFDBFE"
            Fill = "#EFF6FF"
            Nodes = (New-Object System.Collections.Generic.List[object])
        }
        "generators_extractors" = @{
            Label = "Generators + Extractors"
            Border = "#99F6E4"
            Fill = "#F0FDFA"
            Nodes = (New-Object System.Collections.Generic.List[object])
        }
        "quality_checks" = @{
            Label = "Quality Checks"
            Border = "#FDE68A"
            Fill = "#FFFBEB"
            Nodes = (New-Object System.Collections.Generic.List[object])
        }
        "ci_jobs" = @{
            Label = "CI Jobs"
            Border = "#C7D2FE"
            Fill = "#EEF2FF"
            Nodes = (New-Object System.Collections.Generic.List[object])
        }
        "evidence_and_logs" = @{
            Label = "Logging + Evidence Sinks"
            Border = "#A5F3FC"
            Fill = "#ECFEFF"
            Nodes = (New-Object System.Collections.Generic.List[object])
        }
    }
    foreach ($n in $Graph.Nodes) {
        $bucketKey = Get-NodeBucketKey -Node $n
        if (-not $nodeBucketDefs.Contains($bucketKey)) { $bucketKey = "orchestration_and_guards" }
        [void]$nodeBucketDefs[$bucketKey].Nodes.Add($n)
    }

    if ($Graph.Actors.Count -gt 0) {
        $lines.Add("  subgraph cluster_actors {")
        $lines.Add("    graph " + (Convert-ToDotAttrString -Attrs @{
                    label = "Actors"
                    color = "#CBD5E1"
                    fillcolor = "#F8FAFC"
                    style = "rounded,filled"
                    fontcolor = "#334155"
                    fontsize = "12"
                }) + ";")
        if ($rankdir -eq "TB") {
            $lines.Add("    rank=`"source`";")
        }
        else {
            $lines.Add("    rank=`"same`";")
        }
        foreach ($a in $Graph.Actors) {
            $id = Get-String -Obj $a -Name "actor_id"
            $labelRaw = Get-String -Obj $a -Name "label"
            $label = Get-DotWrappedLabel -Text $labelRaw -MaxLen 20
            $tags = Get-ItemTags -Item $a
            $classParts = @("actor", "kind-" + (Get-String -Obj $a -Name "kind"))
            foreach ($t in $tags) { $classParts += ("domain-" + ($t -replace "[^a-zA-Z0-9_-]", "-")) }
            $attrs = @{
                id = $id
                class = ($classParts -join " ")
                label = $label
                shape = "hexagon"
                style = "filled"
                fillcolor = "#F8FAFC"
                color = "#64748B"
                fontcolor = "#0F172A"
                penwidth = "1.4"
                margin = "0.12,0.07"
                tooltip = "$labelRaw [$id]"
            }
            $lines.Add("    `"$id`" " + (Convert-ToDotAttrString -Attrs $attrs) + ";")
        }
        $lines.Add("  }")
    }

    foreach ($bucketKey in $nodeBucketDefs.Keys) {
        $bucket = $nodeBucketDefs[$bucketKey]
        if ($bucket.Nodes.Count -eq 0) { continue }
        $clusterName = "cluster_nodes_" + $bucketKey
        $lines.Add("  subgraph $clusterName {")
        $lines.Add("    graph " + (Convert-ToDotAttrString -Attrs @{
                    label = [string]$bucket.Label
                    color = [string]$bucket.Border
                    fillcolor = [string]$bucket.Fill
                    style = "rounded,filled"
                    fontcolor = "#334155"
                    fontsize = "12"
                }) + ";")
        foreach ($n in $bucket.Nodes) {
            $id = Get-String -Obj $n -Name "node_id"
            $labelRaw = Get-String -Obj $n -Name "label"
            $label = Get-DotWrappedLabel -Text $labelRaw -MaxLen 28
            $kind = Get-String -Obj $n -Name "kind"
            $tags = Get-ItemTags -Item $n
            $blockingMode = Get-String -Obj $n -Name "blocking_mode"

            $shape = switch ($kind) {
                "decision" { "diamond" }
                "log_sink" { "cylinder" }
                "evidence_sink" { "cylinder" }
                "gate" { "octagon" }
                "hook" { "tab" }
                "generator" { "component" }
                "ci_job" { if ($isCompactFull) { "box" } else { "box3d" } }
                "ci_step" { if ($isCompactFull) { "box" } else { "box3d" } }
                "manual_action" { "parallelogram" }
                default { "box" }
            }

            $visualTag = $null
            if ($kind -in @("ci_job", "ci_step")) { $visualTag = "ci" }
            elseif ($kind -eq "hook") { $visualTag = "hooks" }
            elseif ($kind -eq "linter") { $visualTag = "lint" }
            elseif ($kind -eq "test") { $visualTag = "test" }
            elseif ($kind -in @("log_sink", "evidence_sink")) { $visualTag = "evidence" }
            elseif ($kind -eq "decision" -and ($tags -contains "manual_review")) { $visualTag = "manual_review" }
            if ([string]::IsNullOrWhiteSpace($visualTag)) { $visualTag = Get-PrimaryDomainTag -Item $n }
            $palette = Get-DomainPalette -Tag $visualTag

            $classParts = @("node", "kind-$kind", "bucket-$bucketKey", "blocking-$blockingMode")
            foreach ($t in $tags) { $classParts += ("domain-" + ($t -replace "[^a-zA-Z0-9_-]", "-")) }

            $tooltipBits = @(
                "$labelRaw [$id]",
                "kind=$kind",
                "blocking=$blockingMode",
                "tags=" + (($tags | Sort-Object) -join ",")
            )
            $attrs = @{
                id = $id
                class = ($classParts -join " ")
                label = $label
                shape = $shape
                style = $(if ($shape -in @("diamond", "cylinder", "box3d")) { "filled" } elseif ($isCompactFull -and $shape -eq "octagon") { "filled" } else { "rounded,filled" })
                fillcolor = [string]$palette.Fill
                color = [string]$palette.Stroke
                fontcolor = [string]$palette.Font
                penwidth = $(if ($blockingMode -eq "blocking") { "1.9" } elseif ($blockingMode -eq "conditional") { "1.5" } else { "1.1" })
                peripheries = $(if ($isCompactFull -or $isLiteralFull) { "1" } elseif ($blockingMode -eq "blocking") { "2" } else { "1" })
                tooltip = ($tooltipBits -join " | ")
            }
            $lines.Add("    `"$id`" " + (Convert-ToDotAttrString -Attrs $attrs) + ";")
        }
        $lines.Add("  }")
    }

    if ($Graph.Artifacts.Count -gt 0) {
        $emitArtifactNode = {
            param(
                [object]$Artifact,
                [string]$Indent = "    "
            )
            $id = Get-String -Obj $Artifact -Name "artifact_id"
            $labelRaw = Get-String -Obj $Artifact -Name "label"
            $kind = Get-String -Obj $Artifact -Name "kind"
            $tags = Get-ItemTags -Item $Artifact
            $canonicality = Get-String -Obj $Artifact -Name "canonicality"
            $path = Get-String -Obj $Artifact -Name "path"

            $label = if ($isCompactFull -or $isLiteralFull) {
                $wrapped = Get-DotWrappedLabel -Text $labelRaw -MaxLen 14
                Get-DotStackedWordLabel -Text $wrapped -MinLengthToStack 14
            } else {
                Get-DotWrappedLabel -Text $labelRaw -MaxLen 30
            }

            $visualTag = Get-ArtifactVisualTag -Artifact $Artifact
            $palette = Get-DomainPalette -Tag $visualTag

            $classParts = @("artifact", "kind-$kind", "canonicality-$canonicality")
            foreach ($t in $tags) { $classParts += ("domain-" + ($t -replace "[^a-zA-Z0-9_-]", "-")) }

            $tooltip = if ([string]::IsNullOrWhiteSpace($path)) {
                "$labelRaw [$id]"
            } else {
                "$labelRaw [$id] | path=$path"
            }

            $attrs = @{
                id = $id
                class = ($classParts -join " ")
                label = $label
                shape = $(if ($isLiteralFull) { "box" } else { "note" })
                style = "filled"
                fillcolor = $(if ($canonicality -eq "generated" -and -not ($isCompactFull -or $isLiteralFull)) { "#FFFFFF" } else { [string]$palette.Fill })
                color = [string]$palette.Stroke
                fontcolor = [string]$palette.Font
                penwidth = $(if ($canonicality -eq "canonical") { "1.4" } else { "1.1" })
                margin = $(if ($isLiteralFull) { "0.04,0.03" } else { $null })
                tooltip = $tooltip
            }
            if ($canonicality -eq "generated") {
                $attrs["style"] = $(if ($isCompactFull -or $isLiteralFull) { "filled" } else { "dashed,filled" })
            }
            $lines.Add("$Indent`"$id`" " + (Convert-ToDotAttrString -Attrs $attrs) + ";")
        }

        $lines.Add("  subgraph cluster_artifacts {")
        $lines.Add("    graph " + (Convert-ToDotAttrString -Attrs @{
                    label = "Artifacts / Registries / Outputs"
                    color = "#CBD5E1"
                    fillcolor = "#F8FAFC"
                    style = "rounded,filled"
                    fontcolor = "#334155"
                    fontsize = "12"
                }) + ";")
        if (-not ($isCompactFull -or $isLiteralFull)) {
            $lines.Add("    rank=`"sink`";")
            foreach ($a in $Graph.Artifacts) {
                & $emitArtifactNode $a "    "
            }
        }
        else {
            $tagOrder = @{
                "validate" = 10
                "generate" = 20
                "hooks" = 30
                "ci" = 40
                "docs_publish" = 50
                "traceability" = 60
                "evidence" = 70
                "manual_review" = 80
                "exceptions_non_blocking" = 90
                "update" = 100
            }
            $compactArtifacts = @(
                $Graph.Artifacts | Sort-Object `
                    @{ Expression = {
                            $tag = Get-ArtifactVisualTag -Artifact $_
                            if ($tagOrder.ContainsKey($tag)) { [int]$tagOrder[$tag] } else { 999 }
                        } }, `
                    @{ Expression = { [int](Get-Prop -Obj $_ -Name "order_index" -Default 999999) } }, `
                    @{ Expression = { (Get-String -Obj $_ -Name "artifact_id") } }
            )

            $rowSize = if ($isLiteralFull) { 4 } else { 6 }
            $rowFirstIds = New-Object System.Collections.Generic.List[string]
            $rowIndex = 0
            for ($i = 0; $i -lt $compactArtifacts.Count; $i += $rowSize) {
                $rowIndex++
                $rowItems = @($compactArtifacts | Select-Object -Skip $i -First $rowSize)
                if ($rowItems.Count -eq 0) { continue }
                $lines.Add("    subgraph artifacts_row_$rowIndex {")
                $lines.Add("      rank=`"same`";")
                foreach ($a in $rowItems) {
                    & $emitArtifactNode $a "      "
                }
                for ($j = 0; $j -lt ($rowItems.Count - 1); $j++) {
                    $leftId = Get-String -Obj $rowItems[$j] -Name "artifact_id"
                    $rightId = Get-String -Obj $rowItems[$j + 1] -Name "artifact_id"
                    $lines.Add("      `"$leftId`" -> `"$rightId`" " + (Convert-ToDotAttrString -Attrs @{
                                style = "invis"
                                weight = "40"
                                minlen = "1"
                            }) + ";")
                }
                $lines.Add("    }")
                [void]$rowFirstIds.Add((Get-String -Obj $rowItems[0] -Name "artifact_id"))
            }
            for ($r = 0; $r -lt ($rowFirstIds.Count - 1); $r++) {
                $topId = $rowFirstIds[$r]
                $nextId = $rowFirstIds[$r + 1]
                $lines.Add("    `"$topId`" -> `"$nextId`" " + (Convert-ToDotAttrString -Attrs @{
                            style = "invis"
                            weight = "50"
                            minlen = $(if ($isLiteralFull) { "3" } else { "2" })
                        }) + ";")
            }
        }
        $lines.Add("  }")
    }

    foreach ($e in $Graph.Edges) {
        $edgeId = Get-String -Obj $e -Name "edge_id"
        $from = Escape-DotLabel (Get-String -Obj $e -Name "from")
        $to = Escape-DotLabel (Get-String -Obj $e -Name "to")
        $relation = Get-String -Obj $e -Name "relation"
        $condition = Get-String -Obj $e -Name "condition"
        $blockingEffect = Get-String -Obj $e -Name "blocking_effect"
        $evidenceRequired = [bool](Get-Prop -Obj $e -Name "evidence_required" -Default $false)
        $touchesArtifact = ($from.StartsWith("artifact.")) -or ($to.StartsWith("artifact."))
        $nodeToNode = ($from.StartsWith("node.")) -and ($to.StartsWith("node."))

        $edgeColor = "#64748B"
        $edgeFontColor = "#475569"
        $edgeStyle = "solid"
        $edgePenWidth = "1.1"
        $edgeConstraint = $true
        $edgeWeight = "1"
        $edgeMinLen = "1"
        $arrowhead = "normal"

        switch ($relation) {
            "triggers" { $edgeColor = "#1D4ED8"; $edgeWeight = if ($nodeToNode) { "6" } else { "3" }; if ($nodeToNode) { $edgePenWidth = "1.6" } }
            "reads" { $edgeColor = "#64748B"; $edgeStyle = "dashed"; $edgeConstraint = $false; $edgeWeight = "0"; $arrowhead = "vee" }
            "writes" { $edgeColor = "#0F766E"; $edgeStyle = "dashed"; $edgeConstraint = $false; $edgeWeight = "0" }
            "generates" { $edgeColor = "#0F766E"; $edgeStyle = "dashed"; $edgeConstraint = $false; $edgeWeight = "0" }
            "logs_to" { $edgeColor = "#0891B2"; $edgeStyle = "dotted"; $edgeConstraint = $false; $edgeWeight = "0" }
            "produces_evidence" { $edgeColor = "#0891B2"; $edgeStyle = "dotted"; $edgeConstraint = $false; $edgeWeight = "0" }
            "feeds" { $edgeColor = "#D97706"; $edgeStyle = "dashed"; $edgeConstraint = $false; $edgeWeight = "0"; $edgeMinLen = "2" }
            "validates" { $edgeColor = "#2563EB"; $edgeStyle = "solid"; $edgeWeight = "2" }
            "blocks" { $edgeColor = "#B91C1C"; $edgeStyle = "bold"; $edgePenWidth = "2.0"; $edgeWeight = "3"; $arrowhead = "tee" }
            "publishes" { $edgeColor = "#6D28D9"; $edgeStyle = "dashed"; $edgeConstraint = $false; $edgeWeight = "0" }
            "syncs" { $edgeColor = "#475569"; $edgeStyle = "dashed"; $edgeConstraint = $false; $edgeWeight = "0" }
            default { }
        }

        switch ($condition) {
            "always" { }
            "on_pass" { if ($relation -eq "triggers" -and $nodeToNode) { $edgePenWidth = "1.8"; $edgeWeight = "7" } }
            "on_fail" { $edgeColor = "#B91C1C"; $edgeFontColor = "#991B1B"; $edgeStyle = "bold"; $edgePenWidth = "2.0" }
            "on_skip" { $edgeStyle = "dashed" }
            "if_enabled" { $edgeStyle = "dashed"; $edgeMinLen = "2" }
            "if_changed" { $edgeStyle = "dashed" }
            default { }
        }

        if ($touchesArtifact) {
            $edgeConstraint = $false
            if ($relation -in @("triggers", "validates")) { $edgeWeight = "1" }
            if ($isCompactFull) {
                $edgeMinLen = "2"
            }
            if ($isLiteralFull) {
                $edgeMinLen = "3"
                if ($edgePenWidth -eq "1.1") { $edgePenWidth = "1.3" }
            }
        }

        if (($isCompactFull -or $isLiteralFull) -and $touchesArtifact) {
            $artifactEndpointId = if ($from.StartsWith("artifact.")) { $from } else { $to }
            if ($artifactMap.ContainsKey($artifactEndpointId)) {
                $artifactObj = $artifactMap[$artifactEndpointId]
                $artifactPalette = Get-DomainPalette -Tag (Get-ArtifactVisualTag -Artifact $artifactObj)
                $edgeColor = [string]$artifactPalette.Stroke
                $edgeFontColor = [string]$artifactPalette.Font

                if ($relation -in @("writes", "generates", "reads", "logs_to", "produces_evidence")) {
                    $hashBand = Get-StableHashBand -Value ([string]$artifactEndpointId) -Modulo 3
                    if ($relation -eq "reads") {
                        $edgeStyle = @("dashed", "dotted", "solid")[$hashBand]
                        $arrowhead = "vee"
                    }
                    elseif ($relation -in @("logs_to", "produces_evidence")) {
                        $edgeStyle = @("dotted", "dashed", "solid")[$hashBand]
                    }
                    else {
                        $edgeStyle = @("solid", "dashed", "dotted")[$hashBand]
                    }
                    if ($edgePenWidth -eq "1.1") { $edgePenWidth = "1.2" }
                }
            }
        }

        if ($blockingEffect -ne "none") {
            $edgePenWidth = "2.2"
            if ($edgeColor -eq "#64748B") { $edgeColor = "#B91C1C"; $edgeFontColor = "#991B1B" }
        }

        if ($evidenceRequired -and $relation -eq "triggers") {
            $edgeStyle = "bold"
            $edgePenWidth = "2.0"
        }

        $relationLabel = ($relation -replace "_", " ")
        $conditionLabel = ($condition -replace "_", " ")
        $visibleLabel = if ($condition -eq "always") { $relationLabel } else { "$conditionLabel / $relationLabel" }
        if ($relation -eq "triggers" -and $condition -eq "on_pass" -and $nodeToNode -and $isFullView) {
            $visibleLabel = "on pass"
        }
        if ($touchesArtifact -and $isFullView -and $condition -eq "always") {
            $visibleLabel = ""
        }

        $edgeClasses = @(
            "edge",
            "relation-" + ($relation -replace "[^a-zA-Z0-9_-]", "-"),
            "condition-" + ($condition -replace "[^a-zA-Z0-9_-]", "-"),
            "blocking-" + ($blockingEffect -replace "[^a-zA-Z0-9_-]", "-")
        )
        if ($evidenceRequired) { $edgeClasses += "evidence-required" }

        $edgeTooltip = "$edgeId | $conditionLabel / $relationLabel | blocking=$blockingEffect"
        $edgeAttrs = @{
            id = $edgeId
            class = ($edgeClasses -join " ")
            color = $edgeColor
            fontcolor = $edgeFontColor
            style = $edgeStyle
            penwidth = $edgePenWidth
            minlen = $edgeMinLen
            weight = $edgeWeight
            constraint = $edgeConstraint
            arrowhead = $arrowhead
            tooltip = $edgeTooltip
        }
        if ($isLiteralFull -and $touchesArtifact) {
            if ($to.StartsWith("artifact.")) {
                $edgeAttrs["headport"] = "w"
            }
            elseif ($from.StartsWith("artifact.")) {
                $edgeAttrs["tailport"] = "e"
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($visibleLabel)) {
            $edgeAttrs["xlabel"] = $visibleLabel
        }
        $lines.Add("  `"$from`" -> `"$to`" " + (Convert-ToDotAttrString -Attrs $edgeAttrs) + ";")
    }
    $lines.Add("}")
    return ($lines -join "`n")
}

function Get-MarkdownContent {
    param([object]$View, [object]$Graph, [string]$MermaidContent)
    $label = Get-String -Obj $View -Name "label"
    $viewId = Get-String -Obj $View -Name "view_id"
    $purpose = Get-String -Obj $View -Name "purpose"
    $mustDomains = @(To-Array (Get-Prop -Obj $View -Name "must_cover_domains" -Default @()))
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# $label")
    $lines.Add("")
    $lines.Add('Generated from `docs_control/workflow_control_plane.json`.')
    $lines.Add("")
    $lines.Add('- `view_id`: `' + $viewId + '`')
    if ($purpose.Length -gt 110) {
        $words = $purpose -split '\s+'
        $current = ''
        $wrapped = New-Object System.Collections.Generic.List[string]
        foreach ($w in $words) {
            $candidate = if ($current) { "$current $w" } else { $w }
            if ($candidate.Length -gt 95 -and $current) {
                $wrapped.Add($current)
                $current = $w
            } else {
                $current = $candidate
            }
        }
        if ($current) { $wrapped.Add($current) }
        if ($wrapped.Count -gt 0) {
            $lines.Add('- `purpose`: ' + $wrapped[0])
            for ($i = 1; $i -lt $wrapped.Count; $i++) {
                $lines.Add('  ' + $wrapped[$i])
            }
        }
    } else {
        $lines.Add('- `purpose`: ' + $purpose)
    }
    $lines.Add('- `counts`: actors=' + $Graph.Actors.Count + ', nodes=' + $Graph.Nodes.Count)
    $lines.Add('  artifacts=' + $Graph.Artifacts.Count + ', edges=' + $Graph.Edges.Count)
    if ($mustDomains.Count -gt 0) {
        $joinedDomains = ($mustDomains -join ", ")
        if ($joinedDomains.Length -gt 100) {
            $lines.Add('- `must_cover_domains`:')
            $chunk = ''
            foreach ($d in $mustDomains) {
                $candidate = if ($chunk) { "$chunk, $d" } else { $d }
                if ($candidate.Length -gt 95 -and $chunk) {
                    $lines.Add('  ' + $chunk)
                    $chunk = $d
                } else {
                    $chunk = $candidate
                }
            }
            if ($chunk) { $lines.Add('  ' + $chunk) }
        } else {
            $lines.Add('- `must_cover_domains`: ' + $joinedDomains)
        }
    }
    $lines.Add("")
    $lines.Add("## Mermaid")
    $lines.Add("")
    $lines.Add('```mermaid')
    foreach ($line in @($MermaidContent -split "`n")) {
        $lines.Add([string]$line)
    }
    $lines.Add('```')
    $lines.Add("")
    $lines.Add("## Included nodes")
    $lines.Add("")
    foreach ($n in $Graph.Nodes) {
        $lines.Add('- `' + (Get-String -Obj $n -Name "node_id") + '`: ' + (Get-String -Obj $n -Name "label"))
    }
    return ($lines -join "`n")
}

function Get-InteractiveSvgMarkdownContent {
    param(
        [object]$View,
        [string]$SvgFileName,
        [string]$SourcePath = "docs_control/workflow_control_plane.json",
        [string]$ModelId = "workflow-control-plane",
        [string]$ModelVersion = "",
        [string]$ModelUpdatedUtc = ""
    )
    $label = Get-String -Obj $View -Name "label"
    $viewId = Get-String -Obj $View -Name "view_id"
    $viewerId = "svg_viewer_full_literal"
    $componentMeta = "$ModelId v$ModelVersion"
    if (-not [string]::IsNullOrWhiteSpace($ModelUpdatedUtc)) {
        $componentMeta += " | data $ModelUpdatedUtc"
    }
    $componentMetaJs = $componentMeta -replace "'", "\\'"
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# $label - Literal Interactive Viewer")
    $lines.Add("")
    $lines.Add("## Legend (for non-experts)")
    $lines.Add("")
    $lines.Add("- **Rounded boxes** = workflow steps (validation, generation, test/lint, CI/hooks, gates).")
    $lines.Add("- **Rotated top boxes** = artifacts/files (JSON/YAML/MD/SVG) read or written by steps.")
    $lines.Add("- **Arrows** = control/data flow; arrow direction = dependency direction.")
    $lines.Add("- **Arrow colors** = workflow domains (validate/test/log/evidence/docs/CI/hooks).")
    $lines.Add("- **Overall logic** = source state + observed manifests + verify outputs pass through guards and generators to produce status/evidence and generated docs.")
    $lines.Add("")
    $lines.Add("<style>")
    $lines.Add("#$viewerId { max-width: 95vw; margin: 0 auto; }")
    $lines.Add("#$viewerId .toolbar { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; margin: 6px 0 10px; }")
    $lines.Add("#$viewerId .toolbar button { border: 1px solid #94a3b8; background: #ffffff; color: #0f172a; border-radius: 6px; padding: 4px 10px; cursor: pointer; }")
    $lines.Add("#$viewerId .toolbar input[type='range'] { width: 220px; }")
    $lines.Add("#$viewerId .viewport { width: 95vw; height: 88vh; border: 1px solid #cbd5e1; border-radius: 8px; overflow: auto; background: #f8fafc; cursor: grab; position: relative; }")
    $lines.Add("#$viewerId .viewport.dragging { cursor: grabbing; }")
    $lines.Add("#$viewerId .stage { position: relative; min-width: 100%; min-height: 100%; }")
    $lines.Add("#$viewerId .canvas { position: absolute; display: block; }")
    $lines.Add("#$viewerId .canvas img { display: block; user-select: none; -webkit-user-drag: none; max-width: none; width: auto; height: auto; }")
    $lines.Add("#$viewerId .overlay-meta { position: sticky; top: 8px; left: 8px; z-index: 5; display: inline-block; padding: 2px 8px; border-radius: 6px; border: 1px solid #cbd5e1; background: rgba(255,255,255,0.90); color: #334155; font-size: 0.78rem; }")
    $lines.Add("#$viewerId .hint { color: #94a3b8; font-size: 0.90rem; margin-top: 8px; font-style: italic; }")
    $lines.Add("#$viewerId .hint-cz-panel { color: #64748b; font-size: 0.90rem; margin-top: 8px; padding: 0; border: 0; border-radius: 0; background: transparent; }")
    $lines.Add("#$viewerId .hint-cz-panel p { margin: 0 0 6px; }")
    $lines.Add("#$viewerId .hint-cz-panel ol { margin: 4px 0 6px 20px; padding: 0; }")
    $lines.Add("#$viewerId .hint-cz-panel li { margin: 2px 0; }")
    $lines.Add("#$viewerId .hint-cz-panel a { color: #0369a1; text-decoration: underline; }")
    $lines.Add("</style>")
    $lines.Add("")
    $lines.Add("<div id=`"$viewerId`">")
    $lines.Add("  <div class=`"toolbar`">")
    $lines.Add("    <button type=`"button`" data-action=`"zoom-out`">-</button>")
    $lines.Add("    <input type=`"range`" min=`"5`" max=`"800`" step=`"5`" value=`"100`" data-role=`"zoom-slider`" />")
    $lines.Add("    <button type=`"button`" data-action=`"zoom-in`">+</button>")
    $lines.Add("    <button type=`"button`" data-action=`"reset`">Reset</button>")
    $lines.Add("    <span data-role=`"zoom-value`">100%</span>")
    $lines.Add("  </div>")
    $lines.Add("  <div class=`"viewport`" data-role=`"viewport`" tabindex=`"0`">")
    $lines.Add("    <div class=`"overlay-meta`" data-role=`"overlay-meta`">$componentMeta | generated svg: loading...</div>")
    $lines.Add("    <div class=`"stage`" data-role=`"stage`">")
    $lines.Add("      <div class=`"canvas`" data-role=`"canvas`">")
    $lines.Add("        <img src=`"$SvgFileName`" alt=`"Workflow control plane literal rotated SVG`" draggable=`"false`" data-role=`"image`" />")
    $lines.Add("      </div>")
    $lines.Add("    </div>")
    $lines.Add("  </div>")
    $lines.Add("  <div class=`"hint`">Mouse wheel = zoom, left-button drag = pan, scrollbars remain available.</div>")
    $lines.Add("  <div class=`"hint`">Mode: zoom + pan (scrollbars + mouse drag), range 5-800%.</div>")
    $lines.Add("  <div class=`"hint-cz-panel`">")
    $lines.Add("    <p><strong>Component:</strong> <code>$componentMeta</code></p>")
    $lines.Add("    <p><strong>SVG timestamp (Last-Modified or server Date):</strong> <span data-role=`"generated-at`">loading...</span></p>")
    $lines.Add("    <p><strong>CZ data source:</strong> <code>$SourcePath</code></p>")
    $lines.Add("    <p><strong>Aktualizace dat:</strong></p>")
    $lines.Add("    <ol>")
    $lines.Add("      <li>upravte SSOT,</li>")
    $lines.Add("      <li>spusťte <code>validate_workflow_control_alignment -RefreshObserved</code> + <code>validate_capability_audit</code> + <code>preflight_state_discovery</code> + <code>verify_batch_status</code>,</li>")
    $lines.Add("      <li>spusťte <code>generate_workflow_control_diagrams</code>,</li>")
    $lines.Add("      <li>restart <code>mkdocs serve</code>.</li>")
    $lines.Add("    </ol>")
    $lines.Add("    <p><strong>Pro laika:</strong> po změně vstupního JSON stačí udělat 4 kroky výše; systém nejdřív zkontroluje stav a pak bezpečně přegeneruje všechny diagramy.</p>")
    $lines.Add("    <p>Web links: <a href=`"/generated/control/workflow_control_plane.full.literal.svg`">literal.svg</a> | <a href=`"/generated/control/workflow_control_plane.full.compact.fit.svg`">compact.fit.svg</a> | <a href=`"/generated/control/workflow_control_plane.full.svg`">full.svg</a> | <a href=`"/generated/control/WORKFLOW_CONTROL_PLANE/`">workflow note</a></p>")
    $lines.Add("  </div>")
    $lines.Add("</div>")
    $lines.Add("")
    $lines.Add("<script>")
    $lines.Add("(function () {")
    $lines.Add("  var root = document.getElementById('$viewerId');")
    $lines.Add("  if (!root) return;")
    $lines.Add("  var viewport = root.querySelector('[data-role=`"viewport`"]');")
    $lines.Add("  var stage = root.querySelector('[data-role=`"stage`"]');")
    $lines.Add("  var canvas = root.querySelector('[data-role=`"canvas`"]');")
    $lines.Add("  var image = root.querySelector('[data-role=`"image`"]');")
    $lines.Add("  var slider = root.querySelector('[data-role=`"zoom-slider`"]');")
    $lines.Add("  var zoomValue = root.querySelector('[data-role=`"zoom-value`"]');")
    $lines.Add("  var generatedAt = root.querySelector('[data-role=`"generated-at`"]');")
    $lines.Add("  var overlayMeta = root.querySelector('[data-role=`"overlay-meta`"]');")
    $lines.Add("  var zoom = 1;")
    $lines.Add("  var minZoom = 0.05;")
    $lines.Add("  var maxZoom = 8.0;")
    $lines.Add("  var panPadding = 12000;")
    $lines.Add("  var componentMeta = '$componentMetaJs';")
    $lines.Add("  var baseWidth = 0;")
    $lines.Add("  var baseHeight = 0;")
    $lines.Add("  var dragging = false;")
    $lines.Add("  var dragStartX = 0;")
    $lines.Add("  var dragStartY = 0;")
    $lines.Add("  var scrollStartLeft = 0;")
    $lines.Add("  var scrollStartTop = 0;")
    $lines.Add("")
    $lines.Add("  function clamp(v, min, max) { return Math.max(min, Math.min(max, v)); }")
    $lines.Add("  function ensureBaseSize() {")
    $lines.Add("    if (baseWidth > 0 && baseHeight > 0) return true;")
    $lines.Add("    var w = image.naturalWidth || image.width;")
    $lines.Add("    var h = image.naturalHeight || image.height;")
    $lines.Add("    if (!w || !h) return false;")
    $lines.Add("    baseWidth = w;")
    $lines.Add("    baseHeight = h;")
    $lines.Add("    return true;")
    $lines.Add("  }")
    $lines.Add("")
    $lines.Add("  function formatDate(value) {")
    $lines.Add("    if (!value) return 'unknown';")
    $lines.Add("    var dt = new Date(value);")
    $lines.Add("    if (Number.isNaN(dt.getTime())) return String(value);")
    $lines.Add("    return dt.toISOString().replace('T', ' ').replace('Z', ' UTC');")
    $lines.Add("  }")
    $lines.Add("")
    $lines.Add("  function setGeneratedText(text) {")
    $lines.Add("    var val = text || 'unknown';")
    $lines.Add("    generatedAt.textContent = val;")
    $lines.Add("    overlayMeta.textContent = componentMeta + ' | generated svg: ' + val;")
    $lines.Add("  }")
    $lines.Add("")
    $lines.Add("  function loadGeneratedTimestamp() {")
    $lines.Add("    var src = image.getAttribute('src');")
    $lines.Add("    fetch(src, { method: 'HEAD', cache: 'no-store' })")
    $lines.Add("      .then(function (resp) {")
    $lines.Add("        var lm = resp.headers.get('last-modified') || resp.headers.get('date');")
    $lines.Add("        if (!lm) { setGeneratedText('unknown'); return; }")
    $lines.Add("        setGeneratedText(formatDate(lm));")
    $lines.Add("      })")
    $lines.Add("      .catch(function () { setGeneratedText('unknown'); });")
    $lines.Add("  }")
    $lines.Add("")
    $lines.Add("  function applyScaledSize() {")
    $lines.Add("    var scaledWidth = Math.max(1, Math.round(baseWidth * zoom));")
    $lines.Add("    var scaledHeight = Math.max(1, Math.round(baseHeight * zoom));")
    $lines.Add("    var stageWidth = Math.max(viewport.clientWidth, scaledWidth + (panPadding * 2));")
    $lines.Add("    var stageHeight = Math.max(viewport.clientHeight, scaledHeight + (panPadding * 2));")
    $lines.Add("    stage.style.width = stageWidth + 'px';")
    $lines.Add("    stage.style.height = stageHeight + 'px';")
    $lines.Add("    canvas.style.left = panPadding + 'px';")
    $lines.Add("    canvas.style.top = panPadding + 'px';")
    $lines.Add("    canvas.style.width = scaledWidth + 'px';")
    $lines.Add("    canvas.style.height = scaledHeight + 'px';")
    $lines.Add("    image.style.width = scaledWidth + 'px';")
    $lines.Add("    image.style.height = scaledHeight + 'px';")
    $lines.Add("  }")
    $lines.Add("")
    $lines.Add("  function setZoom(next, focusX, focusY) {")
    $lines.Add("    if (!ensureBaseSize()) return;")
    $lines.Add("    var prevZoom = zoom;")
    $lines.Add("    var localFocusX = (typeof focusX === 'number') ? focusX : (viewport.clientWidth / 2);")
    $lines.Add("    var localFocusY = (typeof focusY === 'number') ? focusY : (viewport.clientHeight / 2);")
    $lines.Add("    var worldX = (viewport.scrollLeft - panPadding + localFocusX) / prevZoom;")
    $lines.Add("    var worldY = (viewport.scrollTop - panPadding + localFocusY) / prevZoom;")
    $lines.Add("    zoom = clamp(next, minZoom, maxZoom);")
    $lines.Add("    applyScaledSize();")
    $lines.Add("    var maxLeft = Math.max(0, viewport.scrollWidth - viewport.clientWidth);")
    $lines.Add("    var maxTop = Math.max(0, viewport.scrollHeight - viewport.clientHeight);")
    $lines.Add("    viewport.scrollLeft = clamp(panPadding + (worldX * zoom) - localFocusX, 0, maxLeft);")
    $lines.Add("    viewport.scrollTop = clamp(panPadding + (worldY * zoom) - localFocusY, 0, maxTop);")
    $lines.Add("    var pct = Math.round(zoom * 100);")
    $lines.Add("    slider.value = String(pct);")
    $lines.Add("    zoomValue.textContent = pct + '%';")
    $lines.Add("  }")
    $lines.Add("")
    $lines.Add("  function resetView() {")
    $lines.Add("    setZoom(1);")
    $lines.Add("    viewport.scrollLeft = panPadding;")
    $lines.Add("    viewport.scrollTop = panPadding;")
    $lines.Add("  }")
    $lines.Add("")
    $lines.Add("  root.querySelector('[data-action=`"zoom-in`"]').addEventListener('click', function () { setZoom(zoom + 0.1); });")
    $lines.Add("  root.querySelector('[data-action=`"zoom-out`"]').addEventListener('click', function () { setZoom(zoom - 0.1); });")
    $lines.Add("  root.querySelector('[data-action=`"reset`"]').addEventListener('click', resetView);")
    $lines.Add("")
    $lines.Add("  slider.addEventListener('input', function () { setZoom(Number(slider.value) / 100); });")
    $lines.Add("")
    $lines.Add("  viewport.addEventListener('wheel', function (ev) {")
    $lines.Add("    if (!ev.ctrlKey && !ev.altKey && !ev.shiftKey) {")
    $lines.Add("      ev.preventDefault();")
    $lines.Add("      var rect = viewport.getBoundingClientRect();")
    $lines.Add("      var focusX = ev.clientX - rect.left;")
    $lines.Add("      var focusY = ev.clientY - rect.top;")
    $lines.Add("      var delta = ev.deltaY < 0 ? 0.08 : -0.08;")
    $lines.Add("      setZoom(zoom + delta, focusX, focusY);")
    $lines.Add("    }")
    $lines.Add("  }, { passive: false });")
    $lines.Add("")
    $lines.Add("  viewport.addEventListener('mousedown', function (ev) {")
    $lines.Add("    if (ev.button !== 0) return;")
    $lines.Add("    dragging = true;")
    $lines.Add("    dragStartX = ev.clientX;")
    $lines.Add("    dragStartY = ev.clientY;")
    $lines.Add("    scrollStartLeft = viewport.scrollLeft;")
    $lines.Add("    scrollStartTop = viewport.scrollTop;")
    $lines.Add("    viewport.classList.add('dragging');")
    $lines.Add("    ev.preventDefault();")
    $lines.Add("  });")
    $lines.Add("")
    $lines.Add("  window.addEventListener('mousemove', function (ev) {")
    $lines.Add("    if (!dragging) return;")
    $lines.Add("    var panGain = Math.max(1, Math.sqrt(zoom));")
    $lines.Add("    viewport.scrollLeft = scrollStartLeft - ((ev.clientX - dragStartX) * panGain);")
    $lines.Add("    viewport.scrollTop = scrollStartTop - ((ev.clientY - dragStartY) * panGain);")
    $lines.Add("  });")
    $lines.Add("")
    $lines.Add("  window.addEventListener('mouseup', function () {")
    $lines.Add("    if (!dragging) return;")
    $lines.Add("    dragging = false;")
    $lines.Add("    viewport.classList.remove('dragging');")
    $lines.Add("  });")
    $lines.Add("")
    $lines.Add("  viewport.addEventListener('keydown', function (ev) {")
    $lines.Add("    var panX = Math.max(80, Math.round(viewport.clientWidth * 1.0));")
    $lines.Add("    var panY = Math.max(80, Math.round(viewport.clientHeight * 1.0));")
    $lines.Add("    var handled = true;")
    $lines.Add("    switch (ev.key) {")
    $lines.Add("      case 'ArrowLeft': viewport.scrollLeft -= panX; break;")
    $lines.Add("      case 'ArrowRight': viewport.scrollLeft += panX; break;")
    $lines.Add("      case 'ArrowUp': viewport.scrollTop -= panY; break;")
    $lines.Add("      case 'ArrowDown': viewport.scrollTop += panY; break;")
    $lines.Add("      case 'PageUp': viewport.scrollTop -= panY; break;")
    $lines.Add("      case 'PageDown': viewport.scrollTop += panY; break;")
    $lines.Add("      case 'Home': viewport.scrollLeft = 0; viewport.scrollTop = 0; break;")
    $lines.Add("      case 'End': viewport.scrollLeft = viewport.scrollWidth; viewport.scrollTop = viewport.scrollHeight; break;")
    $lines.Add("      default: handled = false;")
    $lines.Add("    }")
    $lines.Add("    if (handled) ev.preventDefault();")
    $lines.Add("  });")
    $lines.Add("")
    $lines.Add("  window.addEventListener('resize', function () {")
    $lines.Add("    if (!ensureBaseSize()) return;")
    $lines.Add("    setZoom(zoom);")
    $lines.Add("  });")
    $lines.Add("")
    $lines.Add("  if (image.complete) {")
    $lines.Add("    resetView();")
    $lines.Add("    loadGeneratedTimestamp();")
    $lines.Add("  } else {")
    $lines.Add("    image.addEventListener('load', function () { resetView(); loadGeneratedTimestamp(); });")
    $lines.Add("  }")
    $lines.Add("})();")
    $lines.Add("</script>")

    return ($lines -join "`n")
}

function Get-SvgContent {
    param([object]$View, [string]$DotContent)

    $candidatePaths = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($GraphvizDotPath)) {
        $candidatePaths.Add($GraphvizDotPath)
    }

    $dotCmd = Get-Command dot -ErrorAction SilentlyContinue
    if ($null -ne $dotCmd -and -not [string]::IsNullOrWhiteSpace($dotCmd.Source)) {
        $candidatePaths.Add($dotCmd.Source)
    }

    foreach ($p in @(
            "C:\Program Files\Graphviz\bin\dot.exe",
            "C:\Program Files (x86)\Graphviz\bin\dot.exe"
        )) {
        $candidatePaths.Add($p)
    }

    $resolvedDot = $null
    foreach ($candidate in $candidatePaths) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if (Test-Path $candidate) {
            $resolvedDot = (Resolve-Path $candidate).Path
            break
        }
    }

    if ($null -eq $resolvedDot) {
        Add-Warn "Graphviz 'dot' not available. Writing placeholder SVG for view $(Get-String -Obj $View -Name 'view_id')."
        $msg = "Graphviz dot is not available. Placeholder SVG generated by scripts/generate_workflow_control_diagrams.ps1."
        return @"
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="120">
  <rect width="100%" height="100%" fill="#fff8dc" stroke="#cc9900"/>
  <text x="16" y="40" font-family="Arial, sans-serif" font-size="18" fill="#663300">Workflow Control Plane Diagram Placeholder</text>
  <text x="16" y="74" font-family="Arial, sans-serif" font-size="14" fill="#663300">$msg</text>
</svg>
"@.TrimEnd()
    }

    $tmpIn = Join-Path ([System.IO.Path]::GetTempPath()) ("wcp_" + [System.Guid]::NewGuid().ToString("N") + ".dot")
    $tmpOut = Join-Path ([System.IO.Path]::GetTempPath()) ("wcp_" + [System.Guid]::NewGuid().ToString("N") + ".svg")
    try {
        Write-FileLf -PathValue $tmpIn -Content $DotContent
        & $resolvedDot -Tsvg $tmpIn -o $tmpOut | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tmpOut)) {
            throw "Graphviz dot failed to render SVG (exit=$LASTEXITCODE)."
        }
        return (Read-FileLf -PathValue $tmpOut)
    }
    finally {
        if (Test-Path $tmpIn) { Remove-Item $tmpIn -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tmpOut) { Remove-Item $tmpOut -Force -ErrorAction SilentlyContinue }
    }
}

function Set-SvgViewportPresentation {
    param(
        [string]$SvgContent,
        [ValidateSet("raw", "viewport_fit")]
        [string]$Mode = "raw"
    )

    if ([string]::IsNullOrWhiteSpace($SvgContent) -or $Mode -eq "raw") {
        return $SvgContent
    }

    $match = [regex]::Match($SvgContent, '(?is)<svg\b(?<attrs>[^>]*)>')
    if (-not $match.Success) {
        Add-Warn "Unable to post-process SVG root tag for viewport-fit mode."
        return $SvgContent
    }

    $attrs = $match.Groups["attrs"].Value
    $attrs = [regex]::Replace(
        $attrs,
        '\s+(width|height|preserveAspectRatio|style)\s*=\s*"[^"]*"',
        "",
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $attrs = $attrs.Trim()

    $fitStyle = "display:block;width:100vw;height:100vh;max-width:100vw;max-height:100vh;background:#ffffff"
    $attrSuffix = if ([string]::IsNullOrWhiteSpace($attrs)) { "" } else { " " + $attrs }
    $newRoot = "<svg width=`"100%`" height=`"100%`" preserveAspectRatio=`"xMidYMid meet`" style=`"$fitStyle`"$attrSuffix>"

    return ($SvgContent.Substring(0, $match.Index) + $newRoot + $SvgContent.Substring($match.Index + $match.Length))
}

function Rotate-SvgArtifactNodes {
    param(
        [string]$SvgContent,
        [double]$Angle = -90
    )

    if ([string]::IsNullOrWhiteSpace($SvgContent)) { return $SvgContent }
    $ci = [System.Globalization.CultureInfo]::InvariantCulture
    $blockPattern = '(?is)<g id="artifact\.[^"]+" class="node artifact[^"]*">.*?</g>\s*</g>'

    $result = [regex]::Replace($SvgContent, $blockPattern, {
            param($m)
            $block = [string]$m.Value
            $startMatch = [regex]::Match($block, '^(?is)<g id="artifact\.[^"]+" class="node artifact[^"]*">')
            if (-not $startMatch.Success) { return $block }
            $startTag = [string]$startMatch.Value
            if ($startTag -match '\stransform=') { return $block }

            $polyMatch = [regex]::Match($block, '(?is)<polygon[^>]*points="(?<pts>[^"]+)"')
            if (-not $polyMatch.Success) { return $block }
            $pts = [string]$polyMatch.Groups["pts"].Value

            $coordMatches = [regex]::Matches($pts, '(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)')
            if ($coordMatches.Count -eq 0) { return $block }

            $minX = [double]::PositiveInfinity
            $maxX = [double]::NegativeInfinity
            $minY = [double]::PositiveInfinity
            $maxY = [double]::NegativeInfinity
            foreach ($cm in $coordMatches) {
                $x = [double]::Parse($cm.Groups[1].Value, $ci)
                $y = [double]::Parse($cm.Groups[2].Value, $ci)
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
            if ([double]::IsInfinity($minX) -or [double]::IsInfinity($minY)) { return $block }

            $cx = ($minX + $maxX) / 2.0
            $cy = ($minY + $maxY) / 2.0
            $cxText = [string]::Format($ci, "{0:0.###}", $cx)
            $cyText = [string]::Format($ci, "{0:0.###}", $cy)
            $angleText = [string]::Format($ci, "{0:0.###}", $Angle)
            $newStartTag = $startTag.TrimEnd('>') + " transform=`"rotate($angleText $cxText $cyText)`">"

            return ($newStartTag + $block.Substring($startTag.Length))
        })

    return $result
}

function Get-SvgPresentationMode {
    param([string]$ViewId, [string]$OutputPath)

    if ($OutputPath -match '\.fit\.svg$') { return "viewport_fit" }
    if ($ViewId -ne "view.full_control_plane") { return "viewport_fit" }
    return "raw"
}

function Get-DotRenderProfile {
    param([string]$ViewId, [string]$OutputPath, [string]$Kind)

    if ($ViewId -eq "view.full_control_plane" -and $Kind -eq "svg" -and $OutputPath -match '\.literal(\.fit)?\.svg$') {
        return "full_literal"
    }
    if ($ViewId -eq "view.full_control_plane" -and $Kind -eq "svg" -and $OutputPath -match '\.compact(\.fit)?\.svg$') {
        return "full_compact"
    }
    return "default"
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Generate Workflow Control Diagrams (D1/D5-lite)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

$canonicalFull = Resolve-RepoPath -PathValue $CanonicalPath
if (-not (Test-Path $canonicalFull)) { Add-Error "Missing canonical JSON: $CanonicalPath"; exit 1 }

try {
    $data = (Get-Content -Path $canonicalFull -Raw -Encoding UTF8) | ConvertFrom-Json -Depth 200
}
catch {
    Add-Error "Failed to parse canonical JSON: $($_.Exception.Message)"
    exit 1
}

$modelMeta = Get-Prop -Obj $data -Name "model" -Default ([pscustomobject]@{})
$script:ModelId = Get-String -Obj $modelMeta -Name "model_id" -Default "workflow-control-plane"
$script:ModelVersion = Get-String -Obj $modelMeta -Name "model_version" -Default ""
$modelUpdatedRaw = Get-Prop -Obj $modelMeta -Name "updated_at_utc" -Default ""
if ($modelUpdatedRaw -is [DateTime]) {
    $script:ModelUpdatedUtc = ([DateTime]$modelUpdatedRaw).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ", [System.Globalization.CultureInfo]::InvariantCulture)
}
elseif ($modelUpdatedRaw -is [DateTimeOffset]) {
    $script:ModelUpdatedUtc = ([DateTimeOffset]$modelUpdatedRaw).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ", [System.Globalization.CultureInfo]::InvariantCulture)
}
else {
    $script:ModelUpdatedUtc = [string]$modelUpdatedRaw
}

$actors = Sort-ByOrderThenId -Items (To-Array (Get-Prop -Obj $data -Name "actors" -Default @())) -IdField "actor_id"
$artifacts = Sort-ByOrderThenId -Items (To-Array (Get-Prop -Obj $data -Name "artifacts" -Default @())) -IdField "artifact_id"
$nodes = Sort-ByOrderThenId -Items (To-Array (Get-Prop -Obj $data -Name "nodes" -Default @())) -IdField "node_id"
$edges = Sort-ByOrderThenId -Items (To-Array (Get-Prop -Obj $data -Name "edges" -Default @())) -IdField "edge_id"
$views = Sort-ByOrderThenId -Items (To-Array (Get-Prop -Obj $data -Name "views" -Default @())) -IdField "view_id"
$outputs = Sort-ByOrderThenId -Items (To-Array (Get-Prop -Obj $data -Name "generated_outputs" -Default @())) -IdField "output_id"

$viewById = Get-Map -Items $views -IdField "view_id"
$renderCache = @{}

foreach ($output in $outputs) {
    $outId = Get-String -Obj $output -Name "output_id"
    $viewId = Get-String -Obj $output -Name "view_id"
    $path = Get-String -Obj $output -Name "path"
    $kind = Get-String -Obj $output -Name "kind"

    if (-not $viewById.ContainsKey($viewId)) {
        Add-Error "generated_outputs[$outId] references missing view '$viewId'"
        continue
    }

    $view = $viewById[$viewId]
    $cacheKey = "view::$viewId"
    if (-not $renderCache.ContainsKey($cacheKey)) {
        $graph = Select-ViewGraph -View $view -Actors $actors -Artifacts $artifacts -Nodes $nodes -Edges $edges
        $mermaid = Get-MermaidContent -View $view -Graph $graph
        $dot = Get-DotContent -View $view -Graph $graph
        $markdown = Get-MarkdownContent -View $view -Graph $graph -MermaidContent $mermaid
        $renderCache[$cacheKey] = [pscustomobject]@{
            Graph = $graph
            Mermaid = $mermaid
            Dot = $dot
            Markdown = $markdown
        }
    }
    $bundle = $renderCache[$cacheKey]
    $dotRenderProfile = Get-DotRenderProfile -ViewId $viewId -OutputPath $path -Kind $kind

    $content = switch ($kind) {
        "mermaid" { $bundle.Mermaid }
        "dot" {
            if ($dotRenderProfile -eq "default") { $bundle.Dot }
            else { Get-DotContent -View $view -Graph $bundle.Graph -RenderProfile $dotRenderProfile }
        }
        "markdown" {
            if ($path -match 'workflow_control_plane\.full\.literal\.interactive\.md$') {
                Get-InteractiveSvgMarkdownContent `
                    -View $view `
                    -SvgFileName "/generated/control/workflow_control_plane.full.literal.svg" `
                    -SourcePath $CanonicalPath `
                    -ModelId $script:ModelId `
                    -ModelVersion $script:ModelVersion `
                    -ModelUpdatedUtc $script:ModelUpdatedUtc
            }
            else {
                $bundle.Markdown
            }
        }
        "svg" {
            $dotForSvg = if ($dotRenderProfile -eq "default") {
                $bundle.Dot
            } else {
                Get-DotContent -View $view -Graph $bundle.Graph -RenderProfile $dotRenderProfile
            }
            $rawSvg = Get-SvgContent -View $view -DotContent $dotForSvg
            $svgMode = Get-SvgPresentationMode -ViewId $viewId -OutputPath $path
            $postSvg = Set-SvgViewportPresentation -SvgContent $rawSvg -Mode $svgMode
            if ($dotRenderProfile -eq "full_literal") {
                Rotate-SvgArtifactNodes -SvgContent $postSvg -Angle -90
            } else {
                $postSvg
            }
        }
        default {
            Add-Error "Unsupported output kind '$kind' in $outId"
            $null
        }
    }

    if ($null -ne $content) {
        Apply-Output -PathValue (Resolve-RepoPath -PathValue $path) -Content $content
    }
}

if ($script:Errors.Count -eq 0) {
    if ($CheckOnly) {
        Write-Log -Message "PASS: workflow control diagrams stale-check passed" -Level "SUCCESS"
    } else {
        Write-Log -Message "PASS: workflow control diagrams generated (written=$($script:Written.Count), warnings=$($script:Warnings.Count))" -Level "SUCCESS"
    }
}

if ($script:Errors.Count -gt 0) {
    Write-Host "FAIL: workflow control diagram generation failed with $($script:Errors.Count) error(s)." -ForegroundColor Red
    exit 1
}

exit 0
