param(
    [string]$RootPath = ".",
    [string[]]$SourcePaths = @(
        ".github/workflows/ci.yml",
        ".github/workflows/quality-gate.yml",
        ".github/workflows/determinism.yml",
        ".github/workflows/clean-clone-smoke.yml"
    ),
    [string]$OutputPath = "docs_control/observed_workflow/ci_jobs.json",
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

function ConvertTo-CanonicalJson {
    param([object]$Object)
    return (($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n").TrimEnd() + "`n"
}

function New-StepRecord {
    param(
        [int]$OrderIndex,
        [int]$Line,
        [string]$Kind,
        [string]$Value
    )
    $label = switch ($Kind) {
        "name" { $Value }
        "uses" { "uses: $Value" }
        "run" { "run" }
        default { $Value }
    }
    return [ordered]@{
        order_index = $OrderIndex
        line = $Line
        step_kind = $Kind
        label = $label
        value = $Value
    }
}

function Parse-WorkflowFile {
    param(
        [string]$RepoRelativePath,
        [string]$FullPath
    )

    $lines = Get-Content -Path $FullPath -Encoding UTF8
    $workflowName = ""
    $jobs = New-Object System.Collections.Generic.List[object]

    $inJobs = $false
    $currentJob = $null

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if (-not $workflowName -and $line -match '^name:\s*(.+?)\s*$') {
            $workflowName = $Matches[1].Trim()
            continue
        }

        if ($line -match '^jobs:\s*$') {
            $inJobs = $true
            continue
        }

        if (-not $inJobs) { continue }

        if ($line -match '^  ([A-Za-z0-9_-]+):\s*$') {
            if ($null -ne $currentJob) {
                $jobs.Add([pscustomobject]$currentJob)
            }
            $currentJob = [ordered]@{
                order_index = [int]($jobs.Count + 1)
                line = [int]($i + 1)
                job_id = $Matches[1]
                name = ""
                runs_on = ""
                steps = @()
            }
            continue
        }

        if ($null -eq $currentJob) { continue }

        if ($line -match '^    name:\s*(.+?)\s*$') {
            $currentJob.name = $Matches[1].Trim()
            continue
        }
        if ($line -match '^    runs-on:\s*(.+?)\s*$') {
            $currentJob.runs_on = $Matches[1].Trim()
            continue
        }

        if ($line -match '^\s{6}-\s+name:\s*(.+?)\s*$') {
            $step = New-StepRecord -OrderIndex ([int]($currentJob.steps.Count + 1)) -Line ([int]($i + 1)) -Kind "name" -Value ($Matches[1].Trim())
            $currentJob.steps += [pscustomobject]$step
            continue
        }
        if ($line -match '^\s{6}-\s+uses:\s*(.+?)\s*$') {
            $step = New-StepRecord -OrderIndex ([int]($currentJob.steps.Count + 1)) -Line ([int]($i + 1)) -Kind "uses" -Value ($Matches[1].Trim())
            $currentJob.steps += [pscustomobject]$step
            continue
        }
        if ($line -match '^\s{6}-\s+run:\s*(.+?)\s*$') {
            $step = New-StepRecord -OrderIndex ([int]($currentJob.steps.Count + 1)) -Line ([int]($i + 1)) -Kind "run" -Value ($Matches[1].Trim())
            $currentJob.steps += [pscustomobject]$step
            continue
        }
    }

    if ($null -ne $currentJob) {
        $jobs.Add([pscustomobject]$currentJob)
    }

    return [ordered]@{
        order_index = 0
        path = ($RepoRelativePath -replace "\\","/")
        workflow_name = $workflowName
        jobs = @($jobs | Sort-Object order_index, line, job_id)
    }
}

Write-Host ""
Write-Host "===============================" -ForegroundColor Cyan
Write-Host "  Extract CI observed manifest" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

$workflows = New-Object System.Collections.Generic.List[object]
foreach ($src in $SourcePaths) {
    $full = Resolve-RepoPath -PathValue $src
    if (-not (Test-Path $full)) {
        Write-Host "Missing CI workflow file: $src" -ForegroundColor Red
        exit 1
    }
    $wf = Parse-WorkflowFile -RepoRelativePath $src -FullPath $full
    $wf.order_index = [int]($workflows.Count + 1)
    $workflows.Add([pscustomobject]$wf)
}

$manifest = [ordered]@{
    schema_version = "1.0"
    manifest_type = "observed_ci_jobs"
    source_paths = @($SourcePaths | ForEach-Object { $_ -replace "\\","/" })
    workflows = @($workflows | Sort-Object order_index, path)
}

$outputFull = Resolve-RepoPath -PathValue $OutputPath
$outDir = Split-Path -Path $outputFull -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outputFull, (ConvertTo-CanonicalJson -Object $manifest), $enc)

$jobCount = 0
foreach ($wf in $workflows) { $jobCount += @($wf.jobs).Count }
Write-Log -Message "PASS: wrote observed CI manifest -> $OutputPath (workflows=$($workflows.Count), jobs=$jobCount)" -Level "SUCCESS"
exit 0
