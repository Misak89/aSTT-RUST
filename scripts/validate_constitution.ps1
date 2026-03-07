# validate_constitution.ps1
# Validace souladu zmen s CONSTITUTION.md
# Verze: 1.0
# Vytvoreno: 2026-02-15 19:30 (UTC+1)

param(
    [string]$RootPath = ".",
    [string]$ConstitutionPath = "CONSTITUTION.md",
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"
$script:Errors = @()
$script:Warnings = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    if ($DetailedOutput -or $Level -in @("ERROR", "WARN", "SUCCESS")) {
        Write-Host $Message -ForegroundColor $color
    }
}

# Hlavni logika
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Constitution Validator v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Kontrola existence CONSTITUTION.md
$fullConstitutionPath = Join-Path $RootPath $ConstitutionPath
if (-not (Test-Path $fullConstitutionPath)) {
    Write-Log "ERROR: CONSTITUTION.md not found at $fullConstitutionPath" -Level "ERROR"
    exit 1
}

$constitution = Get-Content $fullConstitutionPath -Raw -Encoding UTF8

# Základní kontroly
$checks = @(
    @{
        Name = "Library-First (Article I)"
        Pattern = "Library-First|knihovna|library"
        Description = "Nova logika v samostatne knihovne"
    },
    @{
        Name = "CLI Interface (Article II)"
        Pattern = "CLI|Command Line|sidecar"
        Description = "Python sidecar funkcni jako standalone CLI"
    },
    @{
        Name = "Test-First (Article III)"
        Pattern = "Test-First|TDD|test"
        Description = "Testy doprovazi implementaci"
    },
    @{
        Name = "Privacy (Article VIII)"
        Pattern = "Privacy|soukromi|citlive"
        Description = "Zadne uniky citlivych dat"
    },
    @{
        Name = "Performance (Article IX)"
        Pattern = "Performance|vykon|CPU"
        Description = "CPU-only, bez GPU pozadavku"
    }
)

$passedChecks = 0
foreach ($check in $checks) {
    if ($constitution -match $check.Pattern) {
        Write-Log "PASS: $($check.Name)" -Level "SUCCESS"
        $passedChecks++
    }
    else {
        Write-Log "WARN: $($check.Name) - not found in CONSTITUTION" -Level "WARN"
        $script:Warnings += $check.Name
    }
}

# Kontrola, ze CONSTITUTION.md ma metadata
if ($constitution -match "\*\*Verze:\*\*") {
    Write-Log "PASS: CONSTITUTION has metadata" -Level "SUCCESS"
}
else {
    Write-Log "ERROR: CONSTITUTION.md missing metadata" -Level "ERROR"
    $script:Errors += "Missing metadata"
}

# Vypis souhrnu
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Checks passed: $passedChecks / $($checks.Count)" -ForegroundColor Green
Write-Host "  Warnings: $($script:Warnings.Count)" -ForegroundColor Yellow
Write-Host "  Errors: $($script:Errors.Count)" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($script:Errors.Count -eq 0) {
    Write-Host "--- CONSTITUTION VALIDATION PASSED ---" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "--- CONSTITUTION VALIDATION FAILED ---" -ForegroundColor Red
    exit 1
}
