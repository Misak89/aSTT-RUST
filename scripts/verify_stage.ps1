param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("fast", "full")]
    [string]$Stage,
    [string]$RootPath = "",
    [string]$TaskId = "",
    [string]$Scope = "repo",
    [switch]$IncludeLinkAudit,
    [switch]$SkipMkDocsBuild,
    [switch]$SkipDocsChecks,
    [switch]$SkipNodeChecks,
    [switch]$SkipRustChecks,
    [switch]$SkipLog,
    [switch]$SkipRender,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if (-not $RootPath) {
    $RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

if (-not $TaskId) {
    $TaskId = "verify-$Stage-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
}

function New-StepConfig {
    param(
        [string]$Name,
        [string]$Tool,
        [string]$Type,
        [string]$File,
        [string]$Rule,
        [string]$Executable,
        [string[]]$Arguments,
        [bool]$Enabled = $true,
        [string]$SkipReason = ""
    )

    return [pscustomobject][ordered]@{
        name = $Name
        tool = $Tool
        error_type = $Type
        error_file = $File
        error_rule = $Rule
        executable = $Executable
        command_args = @($Arguments)
        enabled = $Enabled
        skip_reason = $SkipReason
    }
}

function Join-CommandText {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )

    $parts = @($Executable) + @($Arguments)
    return ($parts | ForEach-Object {
            $s = [string]$_
            if ($s -match '\s') { '"' + ($s -replace '"', '\"') + '"' } else { $s }
        }) -join " "
}

function Get-RelativePathOrOriginal {
    param(
        [string]$TargetPath,
        [string]$BasePath
    )

    try {
        $targetResolved = (Resolve-Path $TargetPath -ErrorAction Stop).Path
        $baseResolved = (Resolve-Path $BasePath -ErrorAction Stop).Path
        if ($targetResolved.StartsWith($baseResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
            return ($targetResolved.Substring($baseResolved.Length).TrimStart('\', '/') -replace '\\', '/')
        }
        return ($targetResolved -replace '\\', '/')
    }
    catch {
        return ($TargetPath -replace '\\', '/')
    }
}

function Sanitize-FilePart {
    param([string]$Text)
    if (-not $Text) { return "step" }
    return (($Text -replace '[^A-Za-z0-9._-]', '_') -replace '_+', '_').Trim('_')
}

function ConvertTo-JsonArg {
    param(
        [object]$Value,
        [int]$Depth = 20
    )

    $items = @()
    if ($null -ne $Value) {
        $items = @($Value)
    }
    if ($items.Count -eq 0) {
        return "[]"
    }

    $json = $items | ConvertTo-Json -Depth $Depth -Compress
    if ([string]::IsNullOrWhiteSpace($json)) {
        return "[]"
    }
    return [string]$json
}

function Get-FirstMeaningfulLine {
    param([string[]]$Lines)
    foreach ($line in @($Lines)) {
        $text = [string]$line
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            return $text.Trim()
        }
    }
    return ""
}

function Invoke-VerifyStep {
    param(
        [int]$Index,
        [object]$Step,
        [string]$RepoRoot,
        [string]$RawLogDir,
        [switch]$DryRunMode
    )

    $stepExe = [string]$Step.executable
    $stepArgs = @($Step.command_args)
    $commandText = Join-CommandText -Executable $stepExe -Arguments $stepArgs

    if (-not $Step.enabled) {
        return [pscustomobject][ordered]@{
            step = [pscustomobject][ordered]@{
                name = $Step.name
                tool = $Step.tool
                command = $commandText
                status = "SKIP"
                duration_ms = 0
                exit_code = $null
            }
            errors = @()
            evidence_refs = @()
            fail = $false
            skip_reason = $Step.skip_reason
            output_lines = @()
        }
    }

    if ($DryRunMode) {
        return [pscustomobject][ordered]@{
            step = [pscustomobject][ordered]@{
                name = $Step.name
                tool = $Step.tool
                command = $commandText
                status = "SKIP"
                duration_ms = 0
                exit_code = $null
            }
            errors = @()
            evidence_refs = @()
            fail = $false
            skip_reason = "dry_run"
            output_lines = @()
        }
    }

    $exeExists = (Test-Path $stepExe) -or ($null -ne (Get-Command $stepExe -ErrorAction SilentlyContinue))
    if (-not $exeExists) {
        return [pscustomobject][ordered]@{
            step = [pscustomobject][ordered]@{
                name = $Step.name
                tool = $Step.tool
                command = $commandText
                status = "SKIP"
                duration_ms = 0
                exit_code = $null
            }
            errors = @()
            evidence_refs = @()
            fail = $false
            skip_reason = "tool_missing"
            output_lines = @("Missing executable: $stepExe")
        }
    }

    $outputLines = @()
    $thrown = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host ""
    Write-Host "==> [$Stage] Step $($Index): $($Step.name)" -ForegroundColor Cyan
    Write-Host "    $commandText"

    try {
        $raw = & $stepExe @stepArgs 2>&1
        $outputLines = @($raw | ForEach-Object { [string]$_ })
    }
    catch {
        $thrown = $_
        $outputLines += [string]$_.Exception.Message
    }
    finally {
        $stopwatch.Stop()
    }

    foreach ($line in $outputLines) {
        Write-Host $line
    }

    $exitCode = if ($thrown) { 1 } elseif ($LASTEXITCODE -is [int]) { [int]$LASTEXITCODE } else { 0 }
    $status = if ($exitCode -eq 0 -and -not $thrown) { "PASS" } else { "FAIL" }

    $evidenceRefs = @()
    if ($outputLines.Count -gt 0) {
        New-Item -ItemType Directory -Path $RawLogDir -Force | Out-Null
        $fileName = "{0:00}_{1}.log" -f $Index, (Sanitize-FilePart $Step.name)
        $rawPath = Join-Path $RawLogDir $fileName
        Set-Content -Path $rawPath -Value $outputLines -Encoding UTF8
        $evidenceRefs += (Get-RelativePathOrOriginal -TargetPath $rawPath -BasePath $RepoRoot)
    }

    $errors = @()
    if ($status -eq "FAIL") {
        $msg = Get-FirstMeaningfulLine -Lines $outputLines
        if (-not $msg -and $thrown) {
            $msg = [string]$thrown.Exception.Message
        }
        if (-not $msg) {
            $msg = "Command failed"
        }
        $errors += [pscustomobject][ordered]@{
            tool = $Step.tool
            type = $Step.error_type
            file = $Step.error_file
            rule = $Step.error_rule
            line = $null
            step_index = $Index
            message = $msg
        }
    }

    return [pscustomobject][ordered]@{
        step = [pscustomobject][ordered]@{
            name = $Step.name
            tool = $Step.tool
            command = $commandText
            status = $status
            duration_ms = [int][Math]::Round($stopwatch.Elapsed.TotalMilliseconds)
            exit_code = $exitCode
        }
        errors = @($errors)
        evidence_refs = @($evidenceRefs)
        fail = ($status -eq "FAIL")
        skip_reason = ""
        output_lines = @($outputLines)
    }
}

function Get-FastSteps {
    param([string]$RepoRoot)

    $pwshExe = "pwsh"
    $preCommitExe = Join-Path $RepoRoot ".venv\Scripts\pre-commit.exe"
    $pythonExe = Join-Path $RepoRoot ".venv\Scripts\python.exe"
    $npmExe = if ($IsWindows) { "npm.cmd" } else { "npm" }

    $steps = @()

    if (-not $SkipDocsChecks) {
        $steps += New-StepConfig `
            -Name "Validate workflow alignment" `
            -Tool "pwsh" `
            -Type "governance" `
            -File "scripts/validate_workflow_alignment.ps1" `
            -Rule "validate_workflow_alignment" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\validate_workflow_alignment.ps1"))

        $steps += New-StepConfig `
            -Name "Validate workflow control plane model" `
            -Tool "pwsh" `
            -Type "governance" `
            -File "docs_control/workflow_control_plane.json" `
            -Rule "validate_workflow_control_plane" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\validate_workflow_control_plane.ps1"), "-RootPath", $RepoRoot)

        $steps += New-StepConfig `
            -Name "Validate workflow control alignment (refresh observed)" `
            -Tool "pwsh" `
            -Type "governance" `
            -File "docs_control/workflow_control_plane.json" `
            -Rule "validate_workflow_control_alignment" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\validate_workflow_control_alignment.ps1"), "-RootPath", $RepoRoot, "-RefreshObserved")

        $steps += New-StepConfig `
            -Name "Capability audit (tools + sources)" `
            -Tool "pwsh" `
            -Type "governance" `
            -File "docs_control/capability_audit.json" `
            -Rule "validate_capability_audit" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\validate_capability_audit.ps1"), "-RootPath", $RepoRoot)

        $steps += New-StepConfig `
            -Name "Preflight state discovery (claim=evidence)" `
            -Tool "pwsh" `
            -Type "governance" `
            -File "docs_control/task_status.json" `
            -Rule "preflight_state_discovery" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\preflight_state_discovery.ps1"), "-RootPath", $RepoRoot)

        $steps += New-StepConfig `
            -Name "Verify batch status claims (claim=evidence)" `
            -Tool "pwsh" `
            -Type "governance" `
            -File "docs_control/task_status.json" `
            -Rule "verify_batch_status" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\verify_batch_status.ps1"), "-RootPath", $RepoRoot)

        $steps += New-StepConfig `
            -Name "Validate traceability registry" `
            -Tool "pwsh" `
            -Type "governance" `
            -File "docs_control/traceability.json" `
            -Rule "validate_traceability" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\validate_traceability.ps1"), "-RootPath", $RepoRoot)

        $steps += New-StepConfig `
            -Name "Validate NEXT_SESSION control (JSON-first)" `
            -Tool "pwsh" `
            -Type "governance" `
            -File "docs_control/next_session.json" `
            -Rule "validate_next_session" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\validate_next_session.ps1"), "-RootPath", $RepoRoot, "-SkipGeneratedFreshnessCheck")

        $steps += New-StepConfig `
            -Name "Enforce NEXT_SESSION flow" `
            -Tool "pwsh" `
            -Type "governance" `
            -File "docs_control/next_session.json" `
            -Rule "enforce_next_session_flow" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\enforce_next_session_flow.ps1"))

        $steps += New-StepConfig `
            -Name "Control docs stale-check" `
            -Tool "pwsh" `
            -Type "governance" `
            -File "docs/generated/control/NEXT_SESSION.md" `
            -Rule "control_docs_stale_check" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\generate_control_docs.ps1"), "-RootPath", $RepoRoot, "-CheckOnly")

        $steps += New-StepConfig `
            -Name "Workflow control diagrams stale-check" `
            -Tool "pwsh" `
            -Type "governance" `
            -File "docs/generated/control/WORKFLOW_CONTROL_PLANE.md" `
            -Rule "workflow_control_diagrams_stale_check" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\generate_workflow_control_diagrams.ps1"), "-RootPath", $RepoRoot, "-CheckOnly")

        $steps += New-StepConfig `
            -Name "Markdown lint (pre-commit, blocking scope)" `
            -Tool "markdownlint-cli2" `
            -Type "lint" `
            -File "**/*.md" `
            -Rule "markdownlint-cli2" `
            -Executable $preCommitExe `
            -Arguments @("run", "markdownlint-cli2", "--all-files")

        $steps += New-StepConfig `
            -Name "Markdown lint backlog report (non-blocking)" `
            -Tool "pwsh" `
            -Type "report" `
            -File "**/*.md" `
            -Rule "markdownlint_backlog_report" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\report_markdownlint_backlog.ps1"), "-RootPath", $RepoRoot)

        $steps += New-StepConfig `
            -Name "Vale prose lint (critical blocking, pre-commit)" `
            -Tool "vale" `
            -Type "lint" `
            -File "docs/core/GOVERNANCE.md" `
            -Rule "vale_critical" `
            -Executable $preCommitExe `
            -Arguments @("run", "vale-critical", "--all-files")

        $steps += New-StepConfig `
            -Name "Vale backlog report + no-regression" `
            -Tool "vale" `
            -Type "report" `
            -File "**/*.md" `
            -Rule "vale_backlog_no_regression" `
            -Executable $pwshExe `
            -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts\report_vale_backlog.ps1"), "-RootPath", $RepoRoot, "-EnforceNoRegression")

        $steps += New-StepConfig `
            -Name "Link audit (lychee, optional)" `
            -Tool "lychee" `
            -Type "lint" `
            -File "**/*.md" `
            -Rule "lychee" `
            -Executable $preCommitExe `
            -Arguments @("run", "lychee", "--all-files") `
            -Enabled ([bool]$IncludeLinkAudit.IsPresent) `
            -SkipReason "optional_network_sensitive"

        $steps += New-StepConfig `
            -Name "MkDocs build --strict" `
            -Tool "mkdocs" `
            -Type "build" `
            -File "mkdocs.yml" `
            -Rule "mkdocs_strict" `
            -Executable $pythonExe `
            -Arguments @("-X", "utf8", "-m", "mkdocs", "build", "--strict", "-f", (Join-Path $RepoRoot "mkdocs.yml")) `
            -Enabled (-not $SkipMkDocsBuild.IsPresent) `
            -SkipReason "disabled_by_flag"
    }

    if (-not $SkipNodeChecks) {
        $steps += New-StepConfig `
            -Name "Node check (svelte-check)" `
            -Tool "npm" `
            -Type "typecheck" `
            -File "src-ui" `
            -Rule "npm_check" `
            -Executable $npmExe `
            -Arguments @("run", "check", "--if-present")
    }

    if (-not $SkipRustChecks) {
        $cargoToml = Join-Path $RepoRoot "src-tauri\Cargo.toml"
        $steps += New-StepConfig `
            -Name "Rust fmt check" `
            -Tool "cargo" `
            -Type "format" `
            -File "src-tauri" `
            -Rule "cargo_fmt_check" `
            -Executable "cargo" `
            -Arguments @("fmt", "--manifest-path", $cargoToml, "--all", "--", "--check")

        $steps += New-StepConfig `
            -Name "Rust clippy" `
            -Tool "cargo" `
            -Type "lint" `
            -File "src-tauri" `
            -Rule "cargo_clippy" `
            -Executable "cargo" `
            -Arguments @("clippy", "--manifest-path", $cargoToml, "--all-targets", "--all-features", "--", "-D", "warnings")
    }

    return @($steps)
}

function Get-FullSteps {
    param([string]$RepoRoot)

    $steps = @()
    $npmExe = if ($IsWindows) { "npm.cmd" } else { "npm" }
    if (-not $SkipNodeChecks) {
        $steps += New-StepConfig `
            -Name "Node tests" `
            -Tool "npm" `
            -Type "test" `
            -File "src-ui" `
            -Rule "npm_test" `
            -Executable $npmExe `
            -Arguments @("test", "--if-present")
    }

    if (-not $SkipRustChecks) {
        $cargoToml = Join-Path $RepoRoot "src-tauri\Cargo.toml"
        $steps += New-StepConfig `
            -Name "Rust tests" `
            -Tool "cargo" `
            -Type "test" `
            -File "src-tauri" `
            -Rule "cargo_test" `
            -Executable "cargo" `
            -Arguments @("test", "--manifest-path", $cargoToml, "--all-targets", "--all-features")
    }
    return @($steps)
}

$logsRoot = Join-Path $RootPath "logs\verify"
$attemptStamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$attemptId = "{0}-{1}-{2}" -f $attemptStamp, $Stage, ([guid]::NewGuid().ToString("N").Substring(0, 8))
$rawLogDir = Join-Path $logsRoot ("raw\" + $attemptId)

$stepsToRun = if ($Stage -eq "fast") { Get-FastSteps -RepoRoot $RootPath } else { Get-FullSteps -RepoRoot $RootPath }

$stepResults = @()
$allErrors = @()
$allEvidence = @()
$failed = $false

if ($stepsToRun.Count -eq 0) {
    $stepResults += [pscustomobject][ordered]@{
        name = "No steps configured"
        tool = "verify"
        command = "n/a"
        status = "SKIP"
        duration_ms = 0
        exit_code = $null
    }
} else {
    $idx = 0
    foreach ($step in $stepsToRun) {
        $idx++
        $result = Invoke-VerifyStep -Index $idx -Step $step -RepoRoot $RootPath -RawLogDir $rawLogDir -DryRunMode:$DryRun
        $stepResults += $result.step
        $allErrors += @($result.errors)
        $allEvidence += @($result.evidence_refs)

        if ($result.step.status -eq "SKIP" -and $result.skip_reason) {
            Write-Host "    [SKIP] $($result.skip_reason)" -ForegroundColor Yellow
        } elseif ($result.step.status -eq "PASS") {
            Write-Host "    [PASS]" -ForegroundColor Green
        } elseif ($result.step.status -eq "FAIL") {
            Write-Host "    [FAIL] exit_code=$($result.step.exit_code)" -ForegroundColor Red
        }

        if ($result.fail) {
            $failed = $true
            break
        }
    }
}

$status = if ($failed) { "FAIL" } else { "PASS" }
if ($DryRun) {
    $status = "SKIP"
}

$summary = "verify_$Stage result: $status (steps=$($stepResults.Count), errors=$($allErrors.Count), task_id=$TaskId)"
Write-Host ""
Write-Host $summary -ForegroundColor Cyan

if (-not $SkipLog) {
    $logger = Join-Path $RootPath "scripts\log_verify_run.ps1"
    if (-not (Test-Path $logger)) {
        Write-Error "Missing logger script: $logger"
    }

    $stepsJson = ConvertTo-JsonArg -Value $stepResults -Depth 20
    $errorsJson = ConvertTo-JsonArg -Value $allErrors -Depth 20
    $evidenceJson = ConvertTo-JsonArg -Value (@($allEvidence | Sort-Object -Unique)) -Depth 5

    $logArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $logger,
        "-RootPath", $RootPath,
        "-TaskId", $TaskId,
        "-Stage", $Stage,
        "-Scope", $Scope,
        "-Status", $status,
        "-StepsJson", $stepsJson,
        "-ErrorsJson", $errorsJson,
        "-EvidenceRefsJson", $evidenceJson
    )
    if ($SkipRender) { $logArgs += "-SkipRender" }

    & pwsh @logArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "log_verify_run.ps1 failed with exit code $LASTEXITCODE"
    }
}

if ($status -eq "PASS" -or $status -eq "SKIP") { exit 0 }
exit 1
