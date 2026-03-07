# scripts/validate_timestamps.ps1
# Validace timestampu v dokumentaci
# Autor: Kilo Code
# Datum: 2026-02-14

param(
    [string]$Path = "$PSScriptRoot/.."
)

$ErrorActionPreference = "Stop"

Write-Host "--- [TIMESTAMP VALIDATION START] ---"

# Spravny format: 2026-02-14 18:00 (UTC+1) nebo 2026-02-14T18:00:00
$validPatterns = @(
    '\d{4}-\d{2}-\d{2}\s+\d{1,2}:\d{2}\s*\(UTC[+-]\d+:\d{0,2}\)',  # 2026-02-14 18:00 (UTC+1)
    '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}',                          # ISO 8601
    '\d{4}-\d{2}-\d{2}\s+\d{1,2}:\d{2}',                            # 2026-02-14 18:00
    '\d{4}-\d{2}-\d{2}\s+\w{3}\s+\d{1,2}:\d{2}'                     # 2026-02-14 Fri 18:00
)

$targetFiles = @(
    "QA_REPORT.md",
    "CHANGE_LOG.md",
    "NEXT_SESSION.md",
    "NEXT_SESSION-2026-02-14-1743.md",
    "plans/documentation_automation_improvements.md",
    "plans/documentation_automation_improvements_v2.md"
)

$errors = @()
$validCount = 0

foreach ($file in $targetFiles) {
    $fullPath = Join-Path $Path $file
    if (-not (Test-Path $fullPath)) { continue }
    
    $content = Get-Content $fullPath -Raw
    $lines = Get-Content $fullPath
    
    foreach ($line in $lines) {
        # Hledej timestampy v radku
        if ($line -match '\d{4}-\d{2}-\d{2}') {
            $isValid = $false
            foreach ($pattern in $validPatterns) {
                if ($line -match $pattern) {
                    $isValid = $true
                    break
                }
            }
            
            if (-not $isValid -and $line -match '\d{4}-\d{2}-\d{2}') {
                # Mozny chybny format
                $errors += "INVALID TIMESTAMP in $file`: $line".Trim()
            } else {
                $validCount++
            }
        }
    }
}

# Vypis vysledky
Write-Host "Valid timestamps found: $validCount" -ForegroundColor Green

if ($errors.Count -gt 0) {
    Write-Host "`nInvalid timestamps:" -ForegroundColor Yellow
    $errors | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    
    if ($errors.Count -gt 5) {
        Write-Host "  ... and $($errors.Count - 5) more" -ForegroundColor Yellow
    }
    
    Write-Host "`n--- [TIMESTAMP VALIDATION WARNINGS] ---" -ForegroundColor Yellow
    exit 0  # Varovani, ne chyba
}

Write-Host "`n--- [TIMESTAMP VALIDATION PASSED] ---" -ForegroundColor Green
exit 0