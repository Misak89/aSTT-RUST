# 🆘 Nápověda a Příkazy (Quick Help)

Tento soubor obsahuje rychlé návody pro spuštění a údržbu projektu `aSTT-RUST`.

## 🌐 Dokumentace (MkDocs)

Web dokumentace na `http://127.0.0.1:8000/` je funkcionalita `MkDocs`.
Pomocne skripty (`scripts/update_docs.ps1`, `scripts/run_on_save*.ps1`) pripravuji obsah/logy,
ale sam web server nespousteji.

Pro lokální zobrazení dokumentace (včetně ISATM Dashboardu) na adrese [http://127.0.0.1:8000/](http://127.0.0.1:8000/):

```powershell
# 1. Musíš být v adresáři projektu
cd "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST"

# 2. Aktivace prostředí a spuštění serveru (doporučeno explicitně)
.\.venv\Scripts\Activate.ps1
.\.venv\Scripts\mkdocs.exe serve -f mkdocs.yml

# NEBO jedním příkazem odkudkoliv (Absolutní cesta):
& "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\.venv\Scripts\python.exe" -X utf8 -m mkdocs serve -f "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\mkdocs.yml"
```

*(Pokud se `mkdocs` v shellu nechová očekávaně / není v `PATH`, používej explicitně `.\.venv\Scripts\mkdocs.exe serve -f mkdocs.yml` nebo `python -m mkdocs`.)*

### Deterministicky health-check

```powershell
try { (Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/).StatusCode } catch { $_.Exception.Message }
```

- `200` = portal bezi.
- `actively refused` = server neni spusten.

---

## 🛠️ Automatizace a Kontrola

### 1. Aktualizace dokumentace a ISATM Dashboardu

Tento skript synchronizuje metriky a zapíše změnu do auditního logu.

```powershell
# Relativně
pwsh scripts/update_docs.ps1 -Reason "Popis tvé změny" -Feature "Název modulu"

# Přímé vložení (Absolutní cesta)
pwsh "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\scripts\update_docs.ps1" -Reason "ZadejDůvod" -Feature "ZadejModul"
```

### 2. Projektová inventura (SW Health Check)

Spustí kompletní kontrolu nainstalovaného softwaru a verzí.

```powershell
# Relativně
pwsh scripts/inventory_project_sw.ps1

# Přímé vložení (Absolutní cesta)
pwsh "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\scripts\inventory_project_sw.ps1"
```

### 3. Oprava metadat dokumentů

Pokud se rozbijí časová razítka nebo verze v hlavičkách souborů.

```powershell
# Relativně
pwsh scripts/fix_document_metadata.ps1

# Přímé vložení (Absolutní cesta)
pwsh "C:\Users\adamf\OneDrive\Dokumenty\aSTT-RUST\scripts\fix_document_metadata.ps1"
```

---

## 🏗️ Vývoj (Backend & UI)

### Rust Backend (Tauri)

```powershell
cd src-tauri
cargo test      # Spuštění testů
cargo tauri dev  # Spuštění vývojové verze aplikace
```

### Svelte Frontend

```powershell
npm install     # Instalace závislostí (poprvé)
npm run dev     # Spuštění vývojového serveru pro UI
```

---

## 📂 Důležité cesty

- **Audit Log:** [docs/core/AUDIT_TRAIL_Log_dashboard.md](docs/core/AUDIT_TRAIL_Log_dashboard.md)
- **Hlavní Dashboard:** [QA_REPORT.md](QA_REPORT.md)
- **Skripty:** `scripts/`

---

**Poslední aktualizace:** 2026-02-20

