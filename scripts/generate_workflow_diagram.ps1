# generate_workflow_diagram.ps1
# Generuje vizualni diagram workflow z workflow-steps.json

param(
    [string]$ConfigPath = "workflow-steps.json",
    [string]$OutputPath = "docs/workflow-diagram.svg",
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "=== Workflow Diagram Generator ===" -ForegroundColor Cyan
Write-Host ""

# Zjistime koren projektu (2 uroven nad scripts/)
$scriptDir = Split-Path $PSScriptRoot -Parent
$projectRoot = $scriptDir

# Hledame Graphviz - nejprve portable verze, pak systemova
$dotExe = $null
$portablePaths = @(
    Join-Path $projectRoot "tools\graphviz\Graphviz-14.1.2-win64\bin\dot.exe"
    Join-Path $projectRoot "tools\graphviz\bin\dot.exe"
)

foreach ($path in $portablePaths) {
    if (Test-Path $path) {
        $dotExe = $path
        break
    }
}

# Pokud neni portable, zkusime systemovou instalaci
if (-not $dotExe) {
    $systemDot = Get-Command "dot" -ErrorAction SilentlyContinue
    if ($systemDot) {
        $dotExe = $systemDot.Source
    }
}

if (-not $dotExe) {
    Write-Host "WARNING: Graphviz is not installed!" -ForegroundColor Yellow
    Write-Host "Diagram generation will be skipped." -ForegroundColor Yellow
    Write-Host "Download from: https://graphviz.org/download/" -ForegroundColor Yellow
    Write-Host "Or install portable to: tools/graphviz/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "ERROR: Graphviz is required for diagram generation!" -ForegroundColor Red
    exit 1
}

if ($Verbose) {
    Write-Host "Graphviz found: $dotExe" -ForegroundColor Green
}

# Kontrola existence konfigurace
if (-not (Test-Path $ConfigPath)) {
    Write-Host "ERROR: Configuration file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

# Nacteni konfigurace
try {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($Verbose) {
        Write-Host "Loaded configuration: $($config.steps.Count) steps" -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR: Failed to parse configuration: $_" -ForegroundColor Red
    exit 1
}

# Vytvoreni adresare docs pokud neexistuje
$docsDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $docsDir)) {
    New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
    if ($Verbose) {
        Write-Host "Created directory: $docsDir" -ForegroundColor Green
    }
}

# Generovani DOT formatu
$dotContent = @"
digraph ProjectUnifiedWorkflow {
    rankdir=TB;
    node [shape=box, style="rounded,filled", fontname="Arial"];
    edge [fontname="Arial"];

    entry [label="Push / Pull Request (master)", shape=oval, fillcolor=lightgreen];
    unified [label="Project Unified workflow", fillcolor=lightblue];

    subgraph cluster_checks {
        label="Unified checks";
        style=filled;
        color=lightyellow;

        ci [label="ci (reusable)", fillcolor=white];
        qg [label="quality-gate (reusable)", fillcolor=white];
        docs [label="docs (reusable)", fillcolor=white];
        det [label="determinism (reusable)", fillcolor=white];
        smoke [label="clean-clone-smoke (reusable)", fillcolor=white];
        sandbox [label="sandbox-docs\\nsandbox/TestDocu_a001/**/*.md", fillcolor=white];
    }

    gate [label="project-required-check", shape=octagon, fillcolor=lightcyan];
    merge_ok [label="Merge allowed", shape=oval, fillcolor=lightgreen];
    blocked [label="Merge blocked", shape=oval, fillcolor=lightcoral];

    entry -> unified;
    unified -> ci;
    unified -> qg;
    unified -> docs;
    unified -> det;
    unified -> smoke;
    unified -> sandbox;

    ci -> gate [label="PASS"];
    qg -> gate [label="PASS"];
    docs -> gate [label="PASS"];
    det -> gate [label="PASS"];
    smoke -> gate [label="PASS"];
    sandbox -> gate [label="PASS"];

    ci -> blocked [label="FAIL", color=red];
    qg -> blocked [label="FAIL", color=red];
    docs -> blocked [label="FAIL", color=red];
    det -> blocked [label="FAIL", color=red];
    smoke -> blocked [label="FAIL", color=red];
    sandbox -> blocked [label="FAIL", color=red];

    gate -> merge_ok [label="all PASS"];
}
"@

# Ulozeni DOT souboru (bez BOM)
$dotPath = "docs/workflow-diagram.dot"
try {
    # Pouzijeme System.IO.File pro zapis bez BOM
    [System.IO.File]::WriteAllText($dotPath, $dotContent, [System.Text.UTF8Encoding]::new($false))
    if ($Verbose) {
        Write-Host "DOT file created: $dotPath" -ForegroundColor Cyan
    }
} catch {
    Write-Host "ERROR: Failed to create DOT file: $_" -ForegroundColor Red
    exit 1
}

# Generovani SVG
try {
    $dotArgs = @("-Tsvg", $dotPath, "-o", $OutputPath)
    & $dotExe $dotArgs 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "--- WORKFLOW DIAGRAM GENERATED ---" -ForegroundColor Green
        Write-Host "Output: $OutputPath" -ForegroundColor Cyan
        exit 0
    } else {
        Write-Host "ERROR: Failed to generate diagram (exit code: $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERROR: Failed to run Graphviz: $_" -ForegroundColor Red
    exit 1
}
