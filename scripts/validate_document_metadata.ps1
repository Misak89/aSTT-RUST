# validate_document_metadata.ps1
# Validace metadat vsech .md souboru v projektu
# Verze: 1.0
# Vytvoreno: 2026-02-15 18:25 (UTC+1)

param(
    [string]$RootPath = ".",
    [switch]$DetailedOutput,
    [array]$ExcludePaths = @("node_modules", ".git", "target", "docs\spec-kit", "sandbox\portable_bench\python-embed", "sandbox\portable_bench\venv-system", "sandbox\portable_bench\test_samples", ".specify", ".agent", ".claude", ".kilocode")
)

$ErrorActionPreference = "Stop"
$script:Errors = @()
$script:Warnings = @()
$script:Passed = 0
$script:Total = 0

#region Funkce

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "Cyan" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    
    if ($DetailedOutput -or $Level -in @("ERROR", "WARN", "SUCCESS")) {
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

function Test-DocumentMetadata {
    param(
        [string]$FilePath
    )
    
    $errors = @()
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    $relativePath = $FilePath.Substring($RootPath.Length).TrimStart("\", "/")
    
    # Kontrola: Nadpis (musí odpovídat názvu souboru)
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $firstLine = ($content -split "`n")[0]
    if ($firstLine -notmatch "^#\s+.+") {
        $errors += "Chybi nadpis dokumentu"
    }
    
    # Kontrola: Relativni cesta
    if ($content -notmatch "\*\*Cesta:\*\*\s*") {
        $errors += "Chybi relativni cesta (**Cesta:**)"
    }
    elseif ($content -notmatch [regex]::Escape($relativePath)) {
        $warnings += "Relativni cesta neodpovida souboru"
    }
    
    # Kontrola: Verze
    if ($content -notmatch "\*\*Verze:\*\*\s*\d+\.\d+") {
        $errors += "Chybi nebo neplatna verze (**Verze:** X.X)"
    }
    
    # Kontrola: Vytvoreno timestamp
    if ($content -notmatch "\*\*Vytvoreno:\*\*\s*\d{4}-\d{2}-\d{2}") {
        $errors += "Chybi timestamp vytvoreni (**Vytvoreno:**)"
    }
    
    # Kontrola: Posledni zmena timestamp
    if ($content -notmatch "\*\*Posledni zmena:\*\*\s*\d{4}-\d{2}-\d{2}") {
        $errors += "Chybi timestamp posledni zmeny (**Posledni zmena:**)"
    }
    
    # Kontrola: Historie zmen (volitelna, ale doporucena)
    if ($content -notmatch "##\s*Historie zmen") {
        $errors += "Chybi sekce Historie zmen"
    }
    elseif ($content -notmatch "\|\s*\d{4}-\d{2}-\d{2}\s*\|\s*\d+\.\d+\s*\|") {
        $errors += "Historie zmen neobsahuje platne zaznamy"
    }
    
    # Kontrola: Stav
    if ($content -notmatch "##\s*Stav") {
        $errors += "Chybi sekce Stav"
    }
    
    return $errors
}

#endregion

#region Hlavní logika

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Document Metadata Validator v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Definice kategorii externich souboru
$ExternalCategories = @{
    "spec-kit" = "docs\spec-kit"
    "python-embed" = "sandbox\portable_bench\python-embed"
    "venv-system" = "sandbox\portable_bench\venv-system"
    "node_modules" = "node_modules"
    "git" = ".git"
    "target" = "target"
    "config" = ".specify", ".agent", ".claude", ".kilocode"
}

# Najit vsechny .md soubory
$allMdFiles = Get-ChildItem -Path $RootPath -Filter "*.md" -Recurse -File

# Rozdelit na projektove a externi
$mdFiles = @()
$externalCounts = @{}

foreach ($file in $allMdFiles) {
    $filePath = $file.FullName -replace "/", "\"
    $isExcluded = $false
    $matchedCategory = $null
    
    foreach ($category in $ExternalCategories.Keys) {
        $paths = $ExternalCategories[$category]
        if ($paths -is [string]) { $paths = @($paths) }
        foreach ($path in $paths) {
            if ($filePath -like "*\$path\*" -or $filePath -like "*$path\*") {
                $isExcluded = $true
                $matchedCategory = $category
                break
            }
        }
        if ($isExcluded) { break }
    }
    
    if ($isExcluded) {
        if ($matchedCategory) {
            if ($externalCounts.ContainsKey($matchedCategory)) {
                $externalCounts[$matchedCategory]++
            } else {
                $externalCounts[$matchedCategory] = 1
            }
        }
    } else {
        $mdFiles += $file
    }
}

$script:Total = $mdFiles.Count
$externalCount = ($allMdFiles.Count - $mdFiles.Count)
Write-Log "Projektove soubory: $Total" -Level "INFO"
Write-Log "Externi soubory (vylouceny): $externalCount" -Level "INFO"

foreach ($file in $mdFiles) {
    $relativePath = $file.FullName.Substring($RootPath.Length).TrimStart("\", "/")
    
    $errors = Test-DocumentMetadata -FilePath $file.FullName
    
    if ($errors.Count -eq 0) {
        $script:Passed++
        Write-Log "PASS: $relativePath" -Level "SUCCESS"
    }
    else {
        Write-Log "FAIL: $relativePath" -Level "ERROR"
        foreach ($err in $errors) {
            Write-Log "  - $err" -Level "ERROR"
        }
        $script:Errors += @{
            File = $relativePath
            Errors = $errors
        }
    }
}

# Vypis souhrnu
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Projektove soubory: $Total" -ForegroundColor White
Write-Host "  Passed:             $Passed" -ForegroundColor Green
Write-Host "  Failed:             $($Total - $Passed)" -ForegroundColor Red
Write-Host ""
Write-Host "  Externi soubory (vylouceny):" -ForegroundColor Yellow
foreach ($category in $externalCounts.Keys | Sort-Object) {
    $count = $externalCounts[$category]
    Write-Host "    - $category`: $count" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($script:Errors.Count -eq 0) {
    Write-Host "--- DOCUMENT METADATA VALIDATION PASSED ---" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "--- DOCUMENT METADATA VALIDATION FAILED ---" -ForegroundColor Red
    Write-Host ""
    Write-Host "Prosim opravte chyby v nasledujicich souborech:" -ForegroundColor Yellow
    foreach ($err in $script:Errors) {
        Write-Host "  - $($err.File)" -ForegroundColor Yellow
    }
    exit 1
}

#endregion
