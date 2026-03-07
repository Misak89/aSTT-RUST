# scripts/check_duplicates.ps1
# Detekce duplicitnich radku v souborech
# Autor: Kilo Code
# Datum: 2026-02-14

param(
    [string]$Path = "$PSScriptRoot/..",
    [double]$Threshold = 1.5,  # Pomer celkovych/unikatnich radku (zvyseno)
    [switch]$IgnoreEmptyLines  # Ignorovat prazdne radky
)

$ErrorActionPreference = "Stop"

Write-Host "--- [DUPLICATE CHECK START] ---"

# Konfigurace prahu pro jednotlive typy souboru
$fileThresholds = @{
    ".rs" = 2.0   # Rust kod ma prirozene vice duplicit (prazdne radky, makra)
    ".md" = 1.5   # Markdown muze mit prazdne radky pro formatovani
    ".yml" = 1.3  # YAML by mel byt vice unikatni
    ".json" = 1.2 # JSON by nemel mit duplicity
}

$targetFiles = @(
    "CHANGE_LOG.md",
    "NEXT_SESSION.md",
    "QA_REPORT.md",
    ".mega-linter.yml",
    "src-tauri/src/rpc.rs",
    "src-tauri/tests/rpc_contract_test.rs"
)

$errors = @()
$warnings = @()

foreach ($file in $targetFiles) {
    $fullPath = Join-Path $Path $file
    if (-not (Test-Path $fullPath)) {
        $warnings += "SKIP: $file not found"
        continue
    }
    
    $content = Get-Content $fullPath
    
    # Volitelne odstraneni prazdnych radku
    if ($IgnoreEmptyLines) {
        $content = $content | Where-Object { $_.Trim() -ne "" }
    }
    
    $totalLines = $content.Count
    $uniqueLines = ($content | Select-Object -Unique).Count
    
    if ($uniqueLines -eq 0) { continue }
    
    # Zjisteni pripony a prislusneho prahu
    $extension = [System.IO.Path]::GetExtension($file)
    $fileThreshold = if ($fileThresholds.ContainsKey($extension)) { $fileThresholds[$extension] } else { $Threshold }
    
    $ratio = [math]::Round($totalLines / $uniqueLines, 2)
    
    if ($ratio -gt $fileThreshold) {
        $errors += "DUPLICATE: $file - Total: $totalLines, Unique: $uniqueLines, Ratio: $ratio (threshold: $fileThreshold)"
    } else {
        Write-Host "OK: $file - Ratio: $ratio (threshold: $fileThreshold)"
    }
}

# Vypis varovani
if ($warnings.Count -gt 0) {
    Write-Host "`nWarnings:" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}

# Vypis chyb
if ($errors.Count -gt 0) {
    Write-Host "`nErrors:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "`n--- [DUPLICATE CHECK FAILED] ---" -ForegroundColor Red
    exit 1
}

Write-Host "`n--- [DUPLICATE CHECK PASSED] ---" -ForegroundColor Green
exit 0