# Diskuze: Workflow Execution Guard - Kritické body k revizi

**Cesta:** plans\workflow_execution_guard_discussion.md
**Verze:** 1.0
**Vytvoreno:** 2026-02-15 19:28 (UTC+1)
**Posledni zmena:** 2026-02-15 19:28 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-15 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [ ] Obsah dokumentu kompletni

---
**Vytvořeno:** 2026-02-15 04:35 (UTC+1)
**Účel:** Diskuze s uživatelem před implementací

---

## Kritický bod 1: Definice povinných kroků

### Rozhodnutí uživatele
**VŠECHNY KROKY BUDOU POVINNÉ.**

### Aktualizovaný seznam povinných kroků

| Krok | Trigger | Popis | Důvod |
|------|---------|-------|-------|
| **Kontrola duplicit** | pre-commit | Detekce duplicitních řádků | Kvalita kódu |
| **Aktualizace QA_REPORT.md** | pre-commit | Stav projektu | Dokumentace |
| **Aktualizace CHANGE_LOG.md** | pre-commit | Historie změn | Dokumentace |
| **Validace timestampů** | pre-commit | Kontrola časových značek | Konzistence |
| **Linting** | pre-commit | Mega-Linter kontrola | Kvalita kódu |
| **Rust testy** | pre-push | Unit testy backendu | Funkčnost |
| **Frontend testy** | pre-push | Unit testy frontendu | Funkčnost |
| **Build sidecar** | pre-build | PyInstaller build | Produkce |
| **Integrační testy** | ci | End-to-end testy | Funkčnost |

### Otázka pro diskuzi
**Chcete přidat další povinné kroky? Jaké?**

---

## Kritický bod 2: Umístění konfigurace

### Otázka
**Kde má být konfigurace workflow umístěna?**

### Možnosti
1. **`workflow-steps.json` v kořenu** - Jednoduché, viditelné
2. **`.workflow/steps.json`** - Skryté, organizované
3. **`package.json` sekce** - Integrace s npm
4. **`.github/workflows/`** - Pouze pro CI/CD

### Doporučení
`workflow-steps.json` v kořenu projektu - snadno editovatelné, verzované.

### Váš názor?

---

## Kritický bod 3: Jazyk implementace

### Otázka
**V jakém jazyce má být hlavní skript implementován?**

### Možnosti
1. **PowerShell (.ps1)** - Původní návrh, Windows native
2. **Bash (.sh)** - Cross-platform, ale omezené na Unix
3. **Node.js (.js)** - Cross-platform, vyžaduje Node
4. **Python (.py)** - Cross-platform, vyžaduje Python
5. **Hybrid (PS1 + SH)** - Dva skripty, maximální kompatibilita

### Pro a proti
| Jazyk | Výhody | Nevýhody |
|-------|--------|----------|
| PowerShell | Již existující skripty, Windows native | Nepřenositelný |
| Bash | Standardní, cross-platform | Složitější na Windows |
| Node.js | Projekt používá Node | Další závislost |
| Python | Projekt používá Python | Další závislost |
| Hybrid | Maximální kompatibilita | Dvojí údržba |

### Váš názor?

---

## Kritický bod 4: Chování při selhání

### Rozhodnutí uživatele
**VŠECHNY KROKY JSOU POVINNÉ = BLOKOVAT PŘI SELHÁNÍ.**

### Detailní chování
```
Povinný krok selže:
  - onFailure: "block" -> Zastavit operaci (výchozí pro všechny)
  - Uživatel musí opravit problém před pokračováním
  - Možnost nouzového přeskočení s --force (varování)
```

### Otázka
**Má existovat možnost `--force` pro nouzové přeskočení?**

---

## Kritický bod 5: Integrace s existujícími hooks

### Otázka
**Jak integrovat s existujícími Husky hooks?**

### Současný stav
- `.husky/pre-commit` - Existuje, kontroluje duplicity
- `.husky/pre-push` - Neexistuje

### Možnosti
1. **Nahradit** - Workflow Guard nahradí existující hooky
2. **Přidat** - Workflow Guard bude volán před/po existujících kontrolách
3. **Paralelně** - Workflow Guard a existující kontroly paralelně

### Návrh
Workflow Guard bude jediný bod vstupu, všechny kontroly budou definovány v `workflow-steps.json`.

### Váš názor?

---

## Kritický bod 6: Výkon a rychlost

### Otázka
**Jak dlouho může trvat pre-commit kontrola?**

### Omezení
- Pre-commit by měl být rychlý (< 30s)
- Pre-push může trvat déle (< 120s)
- CI/CD může trvat nejdéle

### Optimalizace
1. **Paralelní provádění** - Spouštění nezávislých kroků současně
2. **Caching** - Cache výsledků testů
3. **Inkrementální** - Pouze změněné soubory

### Váš názor na přijatelnou dobu?

---

## Kritický bod 7: Logování a audit

### Otázka
**Co a jak moc logovat?**

### Možnosti
1. **Minimalistické** - Pouze pass/fail
2. **Standardní** - Pass/fail + doba trvání
3. **Detailní** - Výstup každého kroku
4. **Ultra-detailní** - Výstup + stderr + environment

### Umístění logů
- `logs/execution-log.json` - Lokální logy
- GitHub Actions artifacts - CI/CD logy
- QA_REPORT.md - Přehled pro uživatele

### Váš názor?

---

## Kritický bod 8: Bezpečnost

### Otázka
**Jak řešit bezpečnostní rizika?**

### Identifikovaná rizika
1. **Command injection** - Příkazy z JSON souboru
2. **Citlivé údaje** - V logu mohou být hesla, tokeny
3. **Manipulace konfigurace** - Útočník může upravit steps

### Možná řešení
1. **Whitelist příkazů** - Povolit pouze předdefinované
2. **Sanitizace logů** - Odstranit citlivé vzory
3. **Integrita konfigurace** - SHA256 hash
4. **.gitignore pro logy** - Logy nebudou v gitu

### Váš názor?

---

## Kritický bod 9: Rollback a nouzové řešení

### Otázka
**Jak řešit situace, kdy Workflow Guard blokuje práci?**

### Možnosti
1. **`--force` flag** - Přeskočit kontroly (nebezpečné)
2. **`--skip <step>`** - Přeskočit konkrétní krok
3. **`--dry-run`** - Pouze simulace
4. **`git commit --no-verify`** - Přeskočit vše (standardní git)

### Návrh
- `--dry-run` pro testování
- `--skip <step-id>` pro přeskočení konkrétního kroku
- `--force` pouze s varováním
- `git commit --no-verify` jako fallback

### Váš názor?

---

## Kritický bod 10: Priorita implementace

### Otázka
**Co implementovat nejdříve?**

### Fáze
1. **Fáze 1: Základ** - workflow-steps.json + workflow_guard.ps1
2. **Fáze 2: Hooks** - Integrace s Husky
3. **Fáze 3: CI/CD** - GitHub Actions
4. **Fáze 4: Reporting** - Dashboard v QA_REPORT.md

### Váš názor na prioritu?

---

## Shrnutí rozhodnutí

| Bod | Rozhodnutí | Status |
|-----|------------|--------|
| 1. Povinné kroky | **VŠECHNY POVINNÉ** | Rozhodnuto |
| 2. Umístění konfigurace | ? | Čeká na odpověď |
| 3. Jazyk implementace | ? | Čeká na odpověď |
| 4. Chování při selhání | **BLOKOVAT** | Rozhodnuto |
| 5. Integrace s hooks | ? | Čeká na odpověď |
| 6. Výkon | ? | Čeká na odpověď |
| 7. Logování | ? | Čeká na odpověď |
| 8. Bezpečnost | ? | Čeká na odpověď |
| 9. Rollback | ? | Čeká na odpověď |
| 10. Priorita | ? | Čeká na odpověď |

---

## Vaše odpovědi

Prosím, odpovězte na zbývající kritické body (2, 3, 5, 6, 7, 8, 9, 10).

Můžete použít tento formát:
```
Bod 2: [Vaše odpověď]
Bod 3: [Vaše odpověď]
...
```

---

*Dokument aktualizován: 2026-02-15 04:35 (UTC+1)*
