# scripts/setup_rust_path.ps1
# Setup Rust PATH for the project
# Autor: Kilo Code
# Datum: 2026-02-14

param(
    [switch]$Permanent,  # Pridat trvale do uzivatelskeho profilu
    [switch]$Test        # Pouze otestovat
)

$rustPath = "C:\Users\adamf\.rustup\toolchains\stable-x86_64-pc-windows-msvc\bin"
$cargoPath = "C:\Users\adamf\.cargo\bin"

Write-Host "--- [RUST PATH SETUP] ---" -ForegroundColor Cyan

# Moznost 1: Dočasná úprava PATH (pouze pro aktuální session)
if (-not $Permanent -and -not $Test) {
    Write-Host "`nMoznosti nastaveni Rust PATH:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. DOCASNE (pouze aktualni session)" -ForegroundColor White
    Write-Host "   Vyhody: Rychle, bez zasahu do systemu" -ForegroundColor Green
    Write-Host "   Nevyhody: Musi se opakovat po restartu terminalu" -ForegroundColor Red
    Write-Host ""
    Write-Host "2. TRVALE (do uzivatelskeho profilu)" -ForegroundColor White
    Write-Host "   Vyhody: Nastavi se automaticky po restartu" -ForegroundColor Green
    Write-Host "   Nevyhody: Zmena registry/profilu" -ForegroundColor Red
    Write-Host ""
    Write-Host "3. PROJEKTOVE (alias v PowerShell profilu)" -ForegroundColor White
    Write-Host "   Vyhody: Nezasahuje do systemu, snadna sprava" -ForegroundColor Green
    Write-Host "   Nevyhody: Funguje jen v PowerShell" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host "Vyberte moznost (1/2/3)"
    
    switch ($choice) {
        "1" {
            $env:PATH += ";$rustPath;$cargoPath"
            Write-Host "`nRust PATH pridan docasne." -ForegroundColor Green
        }
        "2" {
            # Trvale pridat do uzivatelske PATH
            $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
            if ($currentPath -notlike "*$rustPath*") {
                [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$rustPath;$cargoPath", "User")
                Write-Host "`nRust PATH trvale pridan do uzivatelskeho profilu." -ForegroundColor Green
                Write-Host "Restartujte terminal pro aplikaci zmen." -ForegroundColor Yellow
            } else {
                Write-Host "`nRust PATH jiz je v uzivatelskem profilu." -ForegroundColor Green
            }
        }
        "3" {
            # Pridat alias do PowerShell profilu
            $profilePath = $PROFILE.CurrentUserCurrentHost
            $aliasContent = @"

# Rust aliases (added by aSTT setup)
function cargo { & "$rustPath\cargo.exe" @args }
function rustc { & "$rustPath\rustc.exe" @args }
function rustup { & "C:\Users\adamf\.rustup\rustup.exe" @args }
"@
            if (Test-Path $profilePath) {
                $profileContent = Get-Content $profilePath -Raw
                if ($profileContent -notlike "*Rust aliases*") {
                    Add-Content $profilePath $aliasContent
                    Write-Host "`nRust alias pridan do PowerShell profilu: $profilePath" -ForegroundColor Green
                } else {
                    Write-Host "`nRust alias jiz existuje v profilu." -ForegroundColor Green
                }
            } else {
                New-Item -Path $profilePath -ItemType File -Force | Out-Null
                Set-Content $profilePath $aliasContent
                Write-Host "`nPowerShell profil vytvoren a Rust alias pridan: $profilePath" -ForegroundColor Green
            }
            Write-Host "Restartujte terminal pro aplikaci zmen." -ForegroundColor Yellow
        }
        default {
            Write-Host "`nNeplatna volba." -ForegroundColor Red
            exit 1
        }
    }
}

# Test mode
if ($Test) {
    Write-Host "`nTest Rust PATH:" -ForegroundColor Yellow
    
    $env:PATH += ";$rustPath;$cargoPath"
    
    Write-Host "  cargo: " -NoNewline
    try {
        $cargoVersion = & cargo --version 2>&1
        Write-Host $cargoVersion -ForegroundColor Green
    } catch {
        Write-Host "NOT FOUND" -ForegroundColor Red
    }
    
    Write-Host "  rustc: " -NoNewline
    try {
        $rustcVersion = & rustc --version 2>&1
        Write-Host $rustcVersion -ForegroundColor Green
    } catch {
        Write-Host "NOT FOUND" -ForegroundColor Red
    }
    
    Write-Host "`nRust PATH: $rustPath" -ForegroundColor Cyan
    Write-Host "Cargo PATH: $cargoPath" -ForegroundColor Cyan
}

# Permanent mode (bez interakce)
if ($Permanent) {
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$rustPath*") {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$rustPath;$cargoPath", "User")
        Write-Host "Rust PATH trvale pridan do uzivatelskeho profilu." -ForegroundColor Green
    } else {
        Write-Host "Rust PATH jiz je v uzivatelskem profilu." -ForegroundColor Green
    }
}

Write-Host "`n--- [DONE] ---" -ForegroundColor Cyan
