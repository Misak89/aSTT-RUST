# scripts/fix_duplicates.ps1
# Automatická oprava duplicitních bloku
# Autor: Kilo Code
# Datum: 2026-02-14

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    
    [switch]$WhatIf  # Pouze zobraz co by se opravilo
)

$ErrorActionPreference = "Stop"

# Preved na absolutni cestu pokud je relativni
if (-not [System.IO.Path]::IsPathRooted($FilePath)) {
    $FilePath = Join-Path $PSScriptRoot/.. $FilePath
}

if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

Write-Host "--- [FIX DUPLICATES START] ---"
Write-Host "File: $FilePath"

# Nacti obsah
$content = Get-Content $FilePath
$totalLines = $content.Count

# Odstran duplicity (zachova poradi prvniho vyskytu)
$seen = @{}
$unique = @()

foreach ($line in $content) {
    if (-not $seen.ContainsKey($line)) {
        $seen[$line] = $true
        $unique += $line
    }
}

$uniqueLines = $unique.Count
$removedLines = $totalLines - $uniqueLines

if ($removedLines -eq 0) {
    Write-Host "OK: No duplicates found" -ForegroundColor Green
    Write-Host "--- [FIX DUPLICATES END] ---"
    exit 0
}

Write-Host "Found: $removedLines duplicate lines" -ForegroundColor Yellow

if ($WhatIf) {
    Write-Host "`n[WhatIf] Would remove $removedLines lines:" -ForegroundColor Cyan
    Write-Host "  Before: $totalLines lines"
    Write-Host "  After:  $uniqueLines lines"
} else {
    # Opravit soubor
    $unique | Set-Content $FilePath -Encoding UTF8
    Write-Host "Fixed: Removed $removedLines duplicate lines" -ForegroundColor Green
    Write-Host "  Before: $totalLines lines"
    Write-Host "  After:  $uniqueLines lines"
}

Write-Host "--- [FIX DUPLICATES END] ---"
exit 0