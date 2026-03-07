param(
    [string]$RootPath = ".",
    [string]$SourcePath = "scripts/verify_stage.ps1",
    [string]$OutputPath = "docs_control/observed_workflow/verify_stage.json",
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"

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

function Get-LineValue {
    param(
        [string]$Line,
        [string]$Flag
    )
    $pattern = [regex]::Escape($Flag) + '\s+"([^"]+)"'
    $m = [regex]::Match($Line, $pattern)
    if ($m.Success) { return $m.Groups[1].Value }
    return ""
}

function ConvertTo-CanonicalJson {
    param([object]$Object)
    $json = $Object | ConvertTo-Json -Depth 100
    return ($json -replace "`r`n", "`n").TrimEnd() + "`n"
}

function Write-Utf8NoBom {
    param([string]$PathValue, [string]$Content)
    $dir = Split-Path -Path $PathValue -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Resolve-Path -LiteralPath (Split-Path -Path $PathValue -Parent) -ErrorAction SilentlyContinue ?? $dir), "", $enc) | Out-Null
    [System.IO.File]::WriteAllText($PathValue, $Content, $enc)
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Extract verify_stage observed manifest" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$sourceFull = Resolve-RepoPath -PathValue $SourcePath
$outputFull = Resolve-RepoPath -PathValue $OutputPath

if (-not (Test-Path $sourceFull)) {
    Write-Host "Missing source file: $SourcePath" -ForegroundColor Red
    exit 1
}

$lines = Get-Content -Path $sourceFull -Encoding UTF8
$functions = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*function\s+([A-Za-z0-9_-]+)\s*\{') {
        $functions.Add([ordered]@{
                name = $Matches[1]
                line = [int]($i + 1)
            })
    }
}

$fastStart = -1
$fullStart = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($fastStart -lt 0 -and $lines[$i] -match '^\s*function\s+Get-FastSteps\s*\{') { $fastStart = $i }
    if ($fullStart -lt 0 -and $lines[$i] -match '^\s*function\s+Get-FullSteps\s*\{') { $fullStart = $i }
}

$fastSteps = New-Object System.Collections.Generic.List[object]
if ($fastStart -ge 0) {
    $endIndex = if ($fullStart -gt $fastStart) { $fullStart - 1 } else { $lines.Count - 1 }
    $current = $null
    for ($i = $fastStart; $i -le $endIndex; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*\$steps\s*\+=\s*New-StepConfig\b') {
            if ($null -ne $current) {
                $fastSteps.Add([pscustomobject]$current)
            }
            $current = [ordered]@{
                order_index = [int]($fastSteps.Count + 1)
                line = [int]($i + 1)
                name = ""
                rule = ""
                tool = ""
                type = ""
                file = ""
                enabled_condition = ""
                skip_reason = ""
            }
            continue
        }

        if ($null -eq $current) { continue }

        foreach ($flag in @("-Name", "-Rule", "-Tool", "-Type", "-File", "-SkipReason")) {
            $val = Get-LineValue -Line $line -Flag $flag
            if ($val) {
                switch ($flag) {
                    "-Name" { $current.name = $val }
                    "-Rule" { $current.rule = $val }
                    "-Tool" { $current.tool = $val }
                    "-Type" { $current.type = $val }
                    "-File" { $current.file = $val }
                    "-SkipReason" { $current.skip_reason = $val }
                }
            }
        }

        if ($line -match '\s-Enabled\s+(.+?)(\s+`)?$') {
            $expr = $Matches[1].Trim()
            if ($expr) { $current.enabled_condition = $expr }
        }
    }
    if ($null -ne $current) {
        $fastSteps.Add([pscustomobject]$current)
    }
}

$manifest = [ordered]@{
    schema_version = "1.0"
    manifest_type = "observed_verify_stage"
    source_path = ($SourcePath -replace "\\","/")
    functions = @($functions | Sort-Object line, name)
    fast_steps = @($fastSteps | Sort-Object order_index, line)
}

$json = ConvertTo-CanonicalJson -Object $manifest

$outDir = Split-Path -Path $outputFull -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outputFull, $json, $enc)

Write-Log -Message "PASS: wrote observed verify_stage manifest -> $OutputPath (functions=$($functions.Count), fast_steps=$($fastSteps.Count))" -Level "SUCCESS"
exit 0
