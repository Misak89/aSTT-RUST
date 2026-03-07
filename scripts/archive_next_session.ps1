# archive_next_session.ps1
# Archivace NEXT_SESSION.md s timestampem
# Verze: 2.1
# Vytvoreno: 2026-02-15 19:32 (UTC+1)
# Posledni zmena: 2026-02-28 (UTC+1)

param(
    [string]$RootPath = ".",
    [string]$NextSessionPath = "docs/core/NEXT_SESSION.md",
    [string]$ArchiveDir = "NEXT_SESSION_Archive",
    [switch]$DetailedOutput,
    [switch]$ResetAfterArchive,
    [string]$ResetConfirmA = "",
    [string]$ResetConfirmB = ""
)

$ErrorActionPreference = "Stop"
$sourceContent = $null
$requiredResetPhrase = "RESET_NEXT_SESSION_NOW"

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

function Get-SourceTimestampFromSession {
    param(
        [string]$Content,
        [datetime]$FallbackTime
    )

    # Preferujeme cas posledni zmeny NEXT_SESSION.
    if ($Content -match '(?im)^\*\*Posledni zmena:\*\*\s*(\d{4}-\d{2}-\d{2})(?:\s+(\d{2}:\d{2}))?') {
        $datePart = $Matches[1]
        $timePart = if ($Matches[2]) { $Matches[2] } else { $FallbackTime.ToString("HH:mm") }
        return "$datePart--$($timePart -replace ':','-')"
    }

    return $FallbackTime.ToString("yyyy-MM-dd--HH-mm")
}

function Get-NextSessionVersion {
    param([string]$Content)

    if ($Content -match '(?im)^\*\*Verze:\*\*\s*([0-9]+)\.([0-9]+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2] + 1
        return "$major.$minor"
    }

    return "1.0"
}

function Test-CompletionSection {
    param([string]$Content)

    $checks = @(
        '(?ms)^###\s*Neprovedeno\s*\r?\n(?:- .+\r?\n)+',
        '(?ms)^###\s*Rozpracovane\s*\r?\n(?:- .+\r?\n)+',
        '(?ms)^###\s*Provedeno\s*\r?\n(?:- .+\r?\n)+',
        '(?ms)^###\s*Poznamka\s*\r?\n.+'
    )

    foreach ($pattern in $checks) {
        if ($Content -notmatch $pattern) {
            return $false
        }
    }

    return $true
}

function Test-ExplicitResetConsent {
    param(
        [string]$ConfirmA,
        [string]$ConfirmB,
        [string]$RequiredPhrase
    )

    return (
        ($ConfirmA -ceq $RequiredPhrase) -and
        ($ConfirmB -ceq $RequiredPhrase)
    )
}

# Hlavni logika
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  NEXT_SESSION Archiver v2.1" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Kontrola existence NEXT_SESSION.md
$fullPath = Join-Path $RootPath $NextSessionPath
if (-not (Test-Path $fullPath)) {
    Write-Log "ERROR: NEXT_SESSION.md not found at $fullPath" -Level "ERROR"
    exit 1
}
$sourceItem = Get-Item $fullPath
$sourceContent = Get-Content $fullPath -Raw -Encoding UTF8

if ($ResetAfterArchive) {
    if (-not (Test-ExplicitResetConsent -ConfirmA $ResetConfirmA -ConfirmB $ResetConfirmB -RequiredPhrase $requiredResetPhrase)) {
        Write-Log "ERROR: ResetAfterArchive vyzaduje 2x explicitni potvrzeni." -Level "ERROR"
        Write-Log "Pouzij presne: -ResetAfterArchive -ResetConfirmA '$requiredResetPhrase' -ResetConfirmB '$requiredResetPhrase'" -Level "ERROR"
        exit 1
    }
}

# Vytvorit archivni adresar pokud neexistuje
$fullArchiveDir = Join-Path $RootPath $ArchiveDir
if (-not (Test-Path $fullArchiveDir)) {
    New-Item -ItemType Directory -Path $fullArchiveDir -Force | Out-Null
    Write-Log "Created archive directory: $ArchiveDir" -Level "INFO"
}

# Generovat timestamp z Posledni zmena (fallback: LastWriteTime)
$timestamp = Get-SourceTimestampFromSession -Content $sourceContent -FallbackTime $sourceItem.LastWriteTime
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($NextSessionPath)
$archiveFileName = "$baseName-$timestamp.md"
$archivePath = Join-Path $fullArchiveDir $archiveFileName

# Kontrola, zda uz existuje archiv se stejnym timestampem
if (Test-Path $archivePath) {
    Write-Log "WARN: Archive already exists: $archiveFileName" -Level "WARN"
    Write-Log "Adding suffix..." -Level "WARN"
    $archiveStamp = Get-Date -Format "yyyy-MM-dd--HH-mm"
    $archiveFileName = "$baseName-$timestamp--arch-$archiveStamp.md"
    $archivePath = Join-Path $fullArchiveDir $archiveFileName
}

# Kopirovat aktualni NEXT_SESSION.md do archivu
Copy-Item $fullPath $archivePath
Write-Log "Archived: $archiveFileName" -Level "SUCCESS"

if ($ResetAfterArchive) {
    if (-not (Test-CompletionSection -Content $sourceContent)) {
        Write-Log "ERROR: Pred vytvorenim noveho NEXT_SESSION dopln sekci Stav realizace: Neprovedeno, Rozpracovane, Provedeno, Poznamka." -Level "ERROR"
        exit 1
    }

    $newVersion = Get-NextSessionVersion -Content $sourceContent
    $nowStamp = Get-Date -Format "yyyy-MM-dd HH:mm"

    # Reset aktivniho souboru je volitelny kvuli SSOT stabilite.
    $newContent = @"
# NEXT_SESSION

**Cesta:** $NextSessionPath
**Verze:** $newVersion
**Vytvoreno:** $nowStamp (UTC+1)
**Posledni zmena:** $nowStamp (UTC+1)
**Status:** Novy

---

## 0. Stav realizace pred archivaci

### Neprovedeno
- [ ] Zadne otevrene body.

### Rozpracovane
- [ ] Zadne body v praci.

### Provedeno
- [ ] Vytvoren novy NEXT_SESSION.

### Poznamka
- Doplneno automaticky pri zalozeni nove session.

---

## 1. Cil



---

## 2. Aktualni stav

### Dokoncene ukoly:
- [ ] 

### Vytvorene soubory:
1. 

---

## 3. Rozhodnuti a duvody

| Rozhodnuti | Duvod |
|------------|-------|
|  |  |

---

## 4. Omezeni



---

## 5. Relevantni soubory

| Soubor | Popis |
|--------|-------|
|  |  |

---

## 6. Dalsi kroky (s akceptacnimi kriterii)

- [ ] 

---

## 7. Otevrene otazky

1. 

---

*Vytvoreno: $nowStamp (UTC+1)*
"@

    $newContent | Out-File $fullPath -Encoding UTF8
    Write-Log "Created new $NextSessionPath" -Level "SUCCESS"
}

# Vypis souhrnu
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Archived: $archiveFileName" -ForegroundColor Green
if ($ResetAfterArchive) {
    Write-Host "  New:      $NextSessionPath" -ForegroundColor Green
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "--- NEXT SESSION ARCHIVED ---" -ForegroundColor Green
exit 0
