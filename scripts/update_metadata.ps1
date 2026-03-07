# update_metadata.ps1
# Automaticka aktualizace metadat ve zmenenych .md souborech
# Verze: 1.0
# Vytvoreno: 2026-02-17 11:18 (UTC+1)

param(
    [string]$RootPath = ".",
    [switch]$DryRun,
    [switch]$All,
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"
$script:Updated = 0
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

function Update-Metadata {
    param([string]$FilePath)
    
    $relativePath = $FilePath.Substring($RootPath.Length).TrimStart("\", "/")
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "SKIP: $relativePath (not found)" -Level "WARN"
        $script:Skipped++
        return
    }
    
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    
    # Kontrola, zda ma metadata
    if ($content -notmatch "\*\*Cesta:\*\*") {
        Write-Log "SKIP: $relativePath (no metadata)" -Level "WARN"
        $script:Skipped++
        return
    }
    
    # Ziskat aktualni verzi
    $versionMatch = $content -match "\*\*Verze:\*\*\s*(\d+)\.(\d+)"
    if ($versionMatch) {
        $majorVersion = [int]$Matches[1]
        $minorVersion = [int]$Matches[2] + 1
        $newVersion = "$majorVersion.$minorVersion"
    } else {
        $newVersion = "1.1"
    }
    
    # Aktualni timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $dateOnly = Get-Date -Format "yyyy-MM-dd"
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would update: $relativePath to version $newVersion" -Level "INFO"
        $script:Updated++
        return
    }
    
    # Aktualizovat verzi
    $content = $content -replace "(\*\*Verze:\*\*\s*)\d+\.\d+", "`${1}$newVersion"
    
    # Aktualizovat posledni zmenu
    $content = $content -replace "(\*\*Posledni zmena:\*\*\s*)\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2})?(?: \(UTC\+\d\))?", "`${1}$timestamp (UTC+1)"
    
    # Pridat zaznam do historie zmen
    $historyEntry = "| $dateOnly | $newVersion | Automaticka aktualizace |"
    
    if ($content -match "##\s*Historie zmen") {
        # Najit konec hlavicky tabulky a pridat radek
        $content = $content -replace "(\|\s*Datum\s*\|\s*Verze\s*\|\s*Popis zmeny\s*\|\r?\n\|-+\|\-+\|\-+\|\r?\n)", "`$1$historyEntry`n"
    }
    
    # Ulozit
    $content | Out-File $FilePath -Encoding UTF8 -NoNewline
    
    Write-Log "UPDATED: $relativePath (v$newVersion)" -Level "SUCCESS"
    $script:Updated++
}

# Hlavni logika
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Document Metadata Updater v1.0" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  Mode: DRY RUN" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Ziskat zmenene .md soubory
if ($All) {
    $files = git ls-files '*.md' 2>$null
} else {
    $files = git diff --cached --name-only --diff-filter=ACM '*.md' 2>$null
}

if (-not $files) {
    Write-Host "No .md files to update" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "--- [METADATA UPDATED] 0 files ---" -ForegroundColor Green
    exit 0
}

foreach ($file in $files) {
    $fullPath = Join-Path $RootPath $file
    try {
        Update-Metadata -FilePath $fullPath
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
Write-Host "  Updated: $script:Updated" -ForegroundColor Green
Write-Host "  Skipped: $script:Skipped" -ForegroundColor Yellow
Write-Host "  Errors:  $script:Errors" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host ""
    Write-Host "Run without -DryRun to apply changes" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "--- [METADATA UPDATED] $script:Updated files ---" -ForegroundColor Green
