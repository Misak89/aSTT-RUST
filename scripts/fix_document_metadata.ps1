# fix_document_metadata.ps1
# Automaticka oprava metadat v .md souborech
# Verze: 1.0
# Vytvoreno: 2026-02-15 19:10 (UTC+1)

param(
    [string]$RootPath = ".",
    [switch]$DryRun,
    [switch]$DetailedOutput,
    [array]$TargetFiles = @(
        # Projektove dokumenty
        "CONSTITUTION.md",
        "VISION.md", 
        "GOVERNANCE.md",
        "NEXT_SESSION.md",
        "QA_REPORT.md",
        "CHANGE_LOG.md",
        "ARCHITECTURE.md",
        "README.md",
        "automation_audit.md",
        "CRITICAL_ANALYSIS.md",
        "documentation_analysis.md",
        "INDEX.md",
        "LOGS_AND_PROMPTS.md",
        "ORGANIZATION.md",
        "PROMPT_HISTORY.md",
        "PROPOSED_FIXES.md",
        "SPEC_KIT_ANALYSIS.md",
        "TEST_INSPIRATION.md",
        "test-make-new-file.md",
        # Plans
        "plans/sdd_complete_workflow_diagram.md",
        "plans/documentation_automation_improvements.md",
        "plans/documentation_automation_improvements_v2.md",
        "plans/documentation_automation_diagnosis.md",
        "plans/encoding_diagnosis.md",
        "plans/next_session_analysis.md",
        "plans/workflow_execution_guard_discussion.md",
        "plans/workflow_execution_guard_proposal.md",
        "plans/workflow_execution_guard_critical_analysis.md",
        "plans/workflow_execution_guard_implementation_spec.md",
        "plans/workflow_guard_options_analysis.md",
        "plans/workflow_execution_guard_spec_v2.md",
        "plans/workflow_execution_guard_spec_v2.01.md",
        "plans/workflow_execution_guard_spec_v2.02.md",
        "plans/workflow_execution_guard_spec_v2.03.md",
        "plans/implementation_priorities.md",
        # Sandbox
        "sandbox/portable_bench/README.md",
        "sandbox/portable_bench/TEST_REPORT.md",
        "sandbox/portable_bench/FINAL_TEST_REPORT.md",
        # Logs
        "logs/README.md",
        # Archive
        "NEXT_SESSION_Archive/NEXT_SESSION-2026-02-14-1743.md",
        # Konfiguracni soubory
        ".kilocode/rules/rules.md",
        ".agent/workflows/review.md",
        ".specify/documentation_analysis.md",
        ".specify/plan.md",
        ".specify/spec.md"
    )
)

$ErrorActionPreference = "Stop"
$script:Fixed = 0
$script:Skipped = 0
$script:Errors = 0

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    if ($DetailedOutput -or $Level -in @("ERROR", "SUCCESS")) {
        Write-Host $Message -ForegroundColor $color
    }
}

function Add-Metadata {
    param([string]$FilePath)
    
    $relativePath = $FilePath.Substring($RootPath.Length).TrimStart("\", "/")
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "SKIP: $relativePath (not found)" -Level "WARN"
        $script:Skipped++
        return
    }
    
    # Pouzit datum ulozeni souboru (LastWriteTime) misto aktualniho casu
    $fileInfo = Get-Item $FilePath
    $fileDate = $fileInfo.LastWriteTime
    $timestamp = $fileDate.ToString("yyyy-MM-dd HH:mm")
    $dateOnly = $fileDate.ToString("yyyy-MM-dd")
    
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    
    # Kontrola, zda uz ma vsechna metadata
    if ($content -match "\*\*Cesta:\*\*" -and $content -match "\*\*Verze:\*\*" -and $content -match "## Historie zmen") {
        Write-Log "SKIP: $relativePath (already has metadata)" -Level "INFO"
        $script:Skipped++
        return
    }
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would fix: $relativePath" -Level "INFO"
        $script:Fixed++
        return
    }
    
    # Extrahovat nadpis
    $title = $fileName
    if ($content -match "^#\s+(.+)") {
        $title = $Matches[1].Trim()
    }
    
    # Vytvorit novou hlavicku s puvodnim datem souboru
    $newHeader = @"
# $title

**Cesta:** $relativePath
**Verze:** 1.0
**Vytvoreno:** $timestamp (UTC+1)
**Posledni zmena:** $timestamp (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| $dateOnly | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [ ] Obsah dokumentu kompletni

---

"@
    
    # Odstranit starou hlavicku (prvni nadpis a prazdne radky)
    $contentWithoutHeader = $content -replace "^#\s+.*(\r?\n)+", ""
    
    # Kombinovat
    $newContent = $newHeader + $contentWithoutHeader
    
    # Ulozit
    $newContent | Out-File $FilePath -Encoding UTF8 -NoNewline
    
    Write-Log "FIXED: $relativePath" -Level "SUCCESS"
    $script:Fixed++
}

# Hlavni logika
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Document Metadata Fixer v1.0" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  Mode: DRY RUN" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($file in $TargetFiles) {
    $fullPath = Join-Path $RootPath $file
    try {
        Add-Metadata -FilePath $fullPath
    }
    catch {
        Write-Log "ERROR: $file - $_" -Level "ERROR"
        $script:Errors++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Fixed:   $script:Fixed" -ForegroundColor Green
Write-Host "  Skipped: $script:Skipped" -ForegroundColor Yellow
Write-Host "  Errors:  $script:Errors" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host ""
    Write-Host "Run without -DryRun to apply changes" -ForegroundColor Yellow
}
