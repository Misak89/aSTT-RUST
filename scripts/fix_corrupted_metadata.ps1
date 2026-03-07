# fix_corrupted_metadata.ps1
# Oprava poskozenych metadat (PowerShell interpolace bug)
# Verze: 1.0
# Vytvoreno: 2026-02-17 14:12 (UTC+1)

param(
    [string]$RootPath = ".",
    [switch]$DryRun,
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"
$script:Fixed = 0
$script:Skipped = 0
$script:Errors = @()

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

function Fix-CorruptedMetadata {
    param([string]$FilePath)
    
    $relativePath = $FilePath.Substring($RootPath.Length).TrimStart("\", "/")
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "SKIP: $relativePath (not found)" -Level "WARN"
        $script:Skipped++
        return
    }
    
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    
    # Kontrola, zda ma poskozena metadata
    # Pattern: $11.1 nebo $11.2 atd. (vzniklo chybnou interpolaci $1$newVersion)
    # Pouzit [char]36 pro $ znak, protoze PowerShell interpretuje $ v regexu
    $dollar = [char]36
    $hasCorruptedVersion = $content -match "$dollar`1\d+\.\d+"
    $hasCorruptedTimestamp = $content -match "$dollar`1\d{4}-\d{2}-\d{2}"
    
    if (-not $hasCorruptedVersion -and -not $hasCorruptedTimestamp) {
        Write-Log "SKIP: $relativePath (no corruption)" -Level "INFO"
        $script:Skipped++
        return
    }
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would fix: $relativePath" -Level "INFO"
        if ($hasCorruptedVersion) {
            Write-Log "  - Corrupted version found" -Level "WARN"
        }
        if ($hasCorruptedTimestamp) {
            Write-Log "  - Corrupted timestamp found" -Level "WARN"
        }
        $script:Fixed++
        return
    }
    
    # Opravit poskozenou verzi: $11.1 -> **Verze:** 1.1
    $content = $content -replace "\$1(\d+\.\d+)", "**Verze:** `$1"
    
    # Opravit poskozeny timestamp: $12026-02-17 -> **Posledni zmena:** 2026-02-17
    $content = $content -replace "\$1(\d{4}-\d{2}-\d{2})(?: \d{2}:\d{2})?(?: \(UTC\+\d\))?", "**Posledni zmena:** `$1 (UTC+1)"
    
    # Ulozit
    $content | Out-File $FilePath -Encoding UTF8 -NoNewline
    
    Write-Log "FIXED: $relativePath" -Level "SUCCESS"
    $script:Fixed++
}

# Hlavni logika
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Corrupted Metadata Fixer v1.0" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  Mode: DRY RUN" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Najit vsechny .md soubory s poskozenymi metadaty
$files = Get-ChildItem -Path $RootPath -Filter "*.md" -Recurse -File | 
         Where-Object { $_.FullName -notmatch "node_modules|venv|python-embed|spec-kit" }

if (-not $files) {
    Write-Host "No .md files found" -ForegroundColor Yellow
    exit 0
}

foreach ($file in $files) {
    try {
        Fix-CorruptedMetadata -FilePath $file.FullName
    }
    catch {
        Write-Log "ERROR: $($file.Name) - $_" -Level "ERROR"
        $script:Errors += @{File = $file.Name; Error = $_.ToString()}
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Fixed:   $script:Fixed" -ForegroundColor Green
Write-Host "  Skipped: $script:Skipped" -ForegroundColor Yellow
Write-Host "  Errors:  $($script:Errors.Count)" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host ""
    Write-Host "Run without -DryRun to apply fixes" -ForegroundColor Yellow
}

if ($script:Errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Errors:" -ForegroundColor Red
    foreach ($err in $script:Errors) {
        Write-Host "  - $($err.File): $($err.Error)" -ForegroundColor Red
    }
}

Write-Host ""
if ($script:Fixed -gt 0) {
    Write-Host "--- [CORRUPTED METADATA FIXED] $script:Fixed files ---" -ForegroundColor Green
} else {
    Write-Host "--- [NO CORRUPTION FOUND] ---" -ForegroundColor Green
}