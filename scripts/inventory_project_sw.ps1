param(
    [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$SkipRunOnSaveHealthCheck
)

$ErrorActionPreference = "Stop"

$docsDir = Join-Path $RootPath "docs"
$logsDir = Join-Path $RootPath "logs"
New-Item -ItemType Directory -Force -Path $docsDir | Out-Null
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

$mdOut = Join-Path $docsDir "software-inventory.md"
$jsonOut = Join-Path $logsDir "software-inventory.json"
$methodOut = Join-Path $docsDir "software-audit-method.md"
$summaryOut = Join-Path $logsDir "software-audit-last.txt"

function Get-FirstNonEmptyLine([object[]]$Lines) {
    foreach ($line in $Lines) {
        $text = [string]$line
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            return $text.Trim()
        }
    }
    return ""
}

function Get-Version([string]$Exe, [string[]]$ArgumentsList) {
    try {
        $out = & $Exe @ArgumentsList 2>&1
        $line = Get-FirstNonEmptyLine $out
        if ([string]::IsNullOrWhiteSpace($line)) { return "unknown" }
        return $line
    } catch {
        return "not available"
    }
}

function Get-PipVersion([string]$PythonPath, [string]$Package) {
    if (-not (Test-Path $PythonPath)) { return "python not found" }
    try {
        $res = & $PythonPath -m pip show $Package 2>$null
        foreach ($line in $res) {
            if ($line -like "Version:*") { return ($line -replace "Version:\s*", "").Trim() }
        }
        return "not installed"
    } catch {
        return "not installed"
    }
}

function Add-CriticalResult {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    $script:criticalChecks += [ordered]@{
        name = $Name
        ok = $Ok
        detail = $Detail
    }
}

$nowDt = Get-Date
$now = $nowDt.ToString("yyyy-MM-dd ddd HH:mm")
$python = Join-Path $RootPath ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    $python = "python"
}

$runtime = [ordered]@{
    powershell = $PSVersionTable.PSVersion.ToString()
    python_venv = Get-Version $python @("--version")
    node = Get-Version "node" @("--version")
    npm = Get-Version "npm" @("--version")
    cargo = Get-Version "cargo" @("--version")
    rustc = Get-Version "rustc" @("--version")
    mkdocs_cli = Get-Version $python @("-m", "mkdocs", "--version")
}

$pythonPackages = [ordered]@{
    mkdocs = Get-PipVersion $python "mkdocs"
    mkdocs_material = Get-PipVersion $python "mkdocs-material"
    mkdocs_awesome_pages_plugin = Get-PipVersion $python "mkdocs-awesome-pages-plugin"
    pystray = Get-PipVersion $python "pystray"
    pillow = Get-PipVersion $python "pillow"
}

$nodeDeps = [ordered]@{}
$packageJsonPath = Join-Path $RootPath "package.json"
if (Test-Path $packageJsonPath) {
    $pkg = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
    if ($pkg.dependencies) {
        foreach ($p in $pkg.dependencies.PSObject.Properties) {
            $nodeDeps[("dep:{0}" -f $p.Name)] = [string]$p.Value
        }
    }
    if ($pkg.devDependencies) {
        foreach ($p in $pkg.devDependencies.PSObject.Properties) {
            $nodeDeps[("devDep:{0}" -f $p.Name)] = [string]$p.Value
        }
    }
}

$cargoDeps = [ordered]@{}
$cargoTomlPath = Join-Path $RootPath "src-tauri\Cargo.toml"
if (Test-Path $cargoTomlPath) {
    $section = ""
    foreach ($line in Get-Content $cargoTomlPath) {
        if ($line -match "^\s*\[(.+)\]\s*$") {
            $section = $Matches[1]
            continue
        }
        if ($section -in @("dependencies", "dev-dependencies", "build-dependencies")) {
            if ($line -match "^\s*([A-Za-z0-9_-]+)\s*=\s*(.+)$") {
                $cargoDeps[("{0}:{1}" -f $section, $Matches[1])] = $Matches[2].Trim()
            }
        }
    }
}

$runOnSave = [ordered]@{
    configured = $false
    command_count = 0
    valid_command = $false
    commands = @()
}

$settingsPath = Join-Path $RootPath ".vscode\settings.json"
if (Test-Path $settingsPath) {
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if ($settings.'emeraldwalk.runonsave'.commands) {
            $runOnSave.configured = $true
            foreach ($cmd in $settings.'emeraldwalk.runonsave'.commands) {
                $text = [string]$cmd.command
                $runOnSave.commands += $text
            }
            $runOnSave.command_count = $runOnSave.commands.Count
            foreach ($c in $runOnSave.commands) {
                if ($c -match "run_on_save\.ps1" -and $c -match "\$\{file\}") {
                    $runOnSave.valid_command = $true
                }
            }
        }
    } catch {
        $runOnSave.commands += "settings parse error"
    }
}

$criticalChecks = @()
Add-CriticalResult "Root path exists" (Test-Path $RootPath) $RootPath
Add-CriticalResult "run_on_save.ps1 exists" (Test-Path (Join-Path $RootPath "scripts\run_on_save.ps1")) "scripts/run_on_save.ps1"
Add-CriticalResult "run_on_save_guard.ps1 exists" (Test-Path (Join-Path $RootPath "scripts\run_on_save_guard.ps1")) "scripts/run_on_save_guard.ps1"
Add-CriticalResult "start_doc_automation.ps1 exists" (Test-Path (Join-Path $RootPath "scripts\start_doc_automation.ps1")) "scripts/start_doc_automation.ps1"
Add-CriticalResult "RunOnSave configured" $runOnSave.configured ".vscode/settings.json"
Add-CriticalResult "RunOnSave command valid" $runOnSave.valid_command 'must include run_on_save.ps1 + ${file}'

$health = [ordered]@{ executed = $false; ok = $false; output = @() }
if ($SkipRunOnSaveHealthCheck) {
    $health.executed = $false
    $health.ok = $true
    $health.output = @("skipped")
} else {
    $healthScript = Join-Path $RootPath "scripts\run_on_save_health_check.ps1"
    if (Test-Path $healthScript) {
        $health.executed = $true
        try {
            $healthOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $healthScript 2>&1
            $health.output = @($healthOutput | ForEach-Object { [string]$_ })
            if ($LASTEXITCODE -eq 0) { $health.ok = $true }
        } catch {
            $health.output = @("health check failed to execute")
        }
    } else {
        $health.output = @("health check script not found")
    }
}
Add-CriticalResult "run_on_save_health_check" $health.ok "exit code 0 required"

$criticalFailCount = @($criticalChecks | Where-Object { -not $_.ok }).Count

$data = [ordered]@{
    generated_at = $now
    project_root = $RootPath
    runtime = $runtime
    python_packages = $pythonPackages
    run_on_save = $runOnSave
    critical_checks = $criticalChecks
    run_on_save_health = $health
    node_dependencies = $nodeDeps
    cargo_dependencies = $cargoDeps
}
$data | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonOut -Encoding UTF8

$lines = @()
$lines += "Document Name: Software Inventory"
$lines += "Version: 0.3"
$lines += ("Timestamp: {0}" -f $now)
$lines += ""
$lines += "# Software Inventory"
$lines += ""
$lines += "## Runtime"
foreach ($k in $runtime.Keys) { $lines += ("- {0}: {1}" -f $k, $runtime[$k]) }
$lines += ""
$lines += "## Python Packages"
foreach ($k in $pythonPackages.Keys) { $lines += ("- {0}: {1}" -f $k, $pythonPackages[$k]) }
$lines += ""
$lines += "## Run on Save"
$lines += ("- configured: {0}" -f $runOnSave.configured)
$lines += ("- command_count: {0}" -f $runOnSave.command_count)
$lines += ("- valid_command: {0}" -f $runOnSave.valid_command)
foreach ($c in $runOnSave.commands) { $lines += ("- command: {0}" -f $c) }
$lines += ""
$lines += "## Critical Checks"
foreach ($check in $criticalChecks) {
    $state = if ($check.ok) { "OK" } else { "FAIL" }
    $lines += ("- [{0}] {1} - {2}" -f $state, $check.name, $check.detail)
}
$lines += ("- failed_checks: {0}" -f $criticalFailCount)
$lines += ""
$lines += "## Health Check Output"
foreach ($h in $health.output) { $lines += ("- {0}" -f $h) }
$lines += ""
$lines += "## Outputs"
$lines += "- JSON: logs/software-inventory.json"
$lines += "- Text summary: logs/software-audit-last.txt"
$lines += "- This report: docs/software-inventory.md"
$lines += ""
$lines += "Previous Versions:"
$lines += "- 0.2 - critical checks added"
Set-Content -Path $mdOut -Value $lines -Encoding UTF8

$summary = @()
$summary += ("Timestamp: {0}" -f $now)
$summary += ("Critical failed checks: {0}" -f $criticalFailCount)
foreach ($check in $criticalChecks) {
    $state = if ($check.ok) { "OK" } else { "FAIL" }
    $summary += ("[{0}] {1}" -f $state, $check.name)
}
Set-Content -Path $summaryOut -Value $summary -Encoding UTF8

$method = @()
$method += "Document Name: Software Audit Method"
$method += "Version: 0.3"
$method += ("Timestamp: {0}" -f $now)
$method += ""
$method += "# Software Audit Method"
$method += ""
$method += "## What the audit does"
$method += "- Reads runtime versions (PowerShell, Python, Node, npm, cargo, rustc, mkdocs)."
$method += "- Reads Python package versions from .venv."
$method += "- Reads dependencies from package.json and src-tauri/Cargo.toml."
$method += "- Verifies Run on Save config in .vscode/settings.json."
$method += "- Runs run_on_save_health_check.ps1 as critical validation."
$method += "- Stores outputs to docs/software-inventory.md and logs/software-inventory.json."
$method += ""
$method += "## Daily automation"
$method += "- Register scheduled task with scripts/register_daily_audit_task.ps1."
$method += "- Task writes latest summary to logs/software-audit-last.txt."
$method += ""
$method += "## Run manually"
$method += "- pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/inventory_project_sw.ps1"
$method += "- CI mode: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/inventory_project_sw.ps1 -SkipRunOnSaveHealthCheck"
$method += ""
$method += "Previous Versions:"
$method += "- 0.2 - added critical checks"
Set-Content -Path $methodOut -Value $method -Encoding UTF8

Write-Host "Saved: $mdOut"
Write-Host "Saved: $jsonOut"
Write-Host "Saved: $methodOut"
Write-Host "Saved: $summaryOut"
if ($criticalFailCount -gt 0) { exit 2 }
exit 0
