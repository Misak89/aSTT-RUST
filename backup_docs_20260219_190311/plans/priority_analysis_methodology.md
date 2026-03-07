# Metodika analýzy a plánování priorit

**Cesta:** plans/priority_analysis_methodology.md
**Verze:** 1.0
**Vytvoreno:** 2026-02-17 06:29 (UTC+1)
**Posledni zmena:** 2026-02-17 06:29 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-17 | 1.0 | Vytvoření metodiky |

## Stav

- [x] Metodika definována
- [ ] Aplikována na aktuální projekt

---

## 1. Cíl

Poskytnout obecně použitelný postup pro analýzu a vytvoření kompletního plánu priorit automatizace a kvality kódu.

---

## 2. Krok 1: Inventarizace existujících nástrojů

### 2.1 Identifikace automatizačních nástrojů

```mermaid
flowchart TD
    A[Inventarizace] --> B[Git Hooks]
    A --> C[CI/CD Workflows]
    A --> D[Linting nástroje]
    A --> E[Testovací frameworky]
    A --> F[Generátory dokumentace]
    
    B --> B1[pre-commit]
    B --> B2[pre-push]
    B --> B3[pre-build]
    
    C --> C1[GitHub Actions]
    C --> C2[GitLab CI]
    C --> C3[Jenkins]
    
    D --> D1[ESLint/Prettier]
    D --> D2[rustfmt/clippy]
    D --> D3[MegaLinter]
    
    E --> E1[Unit testy]
    E --> E2[Integrační testy]
    E --> E3[E2E testy]
```

### 2.2 Kontrolní seznam

| Kategorie | Nástroj | Stav | Poznámka |
|-----------|---------|------|----------|
| Git Hooks | Husky | ✅/❌ | |
| CI/CD | GitHub Actions | ✅/❌ | |
| Linting | ESLint | ✅/❌ | |
| Linting | Prettier | ✅/❌ | |
| Linting | rustfmt | ✅/❌ | |
| Linting | MegaLinter | ✅/❌ | |
| Testování | Jest/Vitest | ✅/❌ | |
| Testování | cargo test | ✅/❌ | |
| Dokumentace | Automatický update | ✅/❌ | |

---

## 3. Krok 2: Analýza mezer (Gap Analysis)

### 3.1 Matice pokrytí

```mermaid
flowchart LR
    subgraph "Pre-commit"
        P1[Validace]
        P2[Linting]
        P3[Formátování]
        P4[Metadata]
    end
    
    subgraph "Pre-push"
        PP1[Unit testy]
        PP2[Integrační testy]
        PP3[Build]
    end
    
    subgraph "CI/CD"
        C1[Linting]
        C2[Testy]
        C3[Build]
        C4[Deploy]
    end
    
    P1 -->|pokrytí| P2
    P2 -->|pokrytí| P3
    P3 -->|pokrytí| P4
    PP1 -->|pokrytí| PP2
    PP2 -->|pokrytí| PP3
    C1 -->|pokrytí| C2
    C2 -->|pokrytí| C3
    C3 -->|pokrytí| C4
```

### 3.2 Identifikace chybějících kontrol

| Fáze | Požadovaná kontrola | Existuje? | Priorita |
|------|---------------------|-----------|----------|
| pre-commit | Kontrola duplicit | ✅ | - |
| pre-commit | Linting (ESLint) | ❌ | P0 |
| pre-commit | Formátování (Prettier) | ❌ | P0 |
| pre-commit | Metadata dokumentů | ✅ | - |
| pre-push | Unit testy | ✅ | - |
| pre-push | Integrační testy | ❌ | P1 |
| CI | MegaLinter | ❌ | P0 |
| CI | Test coverage | ❌ | P1 |

---

## 4. Krok 3: Prioritizace

### 4.1 Matice závažnosti

```mermaid
flowchart TD
    subgraph "P0 - Kritické"
        P0A[Blokuje vývoj]
        P0B[Způsobuje chyby v produkci]
        P0C[Chybí zcela]
    end
    
    subgraph "P1 - Střední"
        P1A[Částečně implementováno]
        P1B[Zlepšuje kvalitu]
        P1C[Automatizuje manuální práci]
    end
    
    subgraph "P2 - Nízké"
        P2A[Nice-to-have]
        P2B[Optimalizace]
        P2C[Cross-platform]
    end
```

### 4.2 Kritéria pro prioritizaci

| Kritérium | Váha | P0 | P1 | P2 |
|-----------|------|-----|-----|-----|
| Blokuje vývoj | 5 | Ano | Částečně | Ne |
| Způsobuje chyby | 4 | Často | Občas | Zřídka |
| Úsilí implementace | 3 | Nízké | Střední | Vysoké |
| Dopad na kvalitu | 3 | Vysoký | Střední | Nízký |
| Frekvence použití | 2 | Každý commit | Každý push | Občas |

---

## 5. Krok 4: Vytvoření sprintů

### 5.1 Šablona sprintu

```markdown
### Sprint X: [Název] (P0/P1/P2)

**Cíl:** [Jasný cíl sprintu]

**Úkoly:**
- [ ] Úkol 1
- [ ] Úkol 2
- [ ] Úkol 3

**Akceptační kritéria:**
- [ ] Kritérium 1
- [ ] Kritérium 2

**Závislosti:**
- Sprint Y musí být dokončen

**Odhad:** [nízký/střední/vysoký]
```

### 5.2 Pořadí sprintů

1. **P0 sprinty** - kritické problémy
2. **P1 sprinty** - vylepšení kvality
3. **P2 sprinty** - nice-to-have

---

## 6. Krok 5: Validace plánu

### 6.1 Kontrolní seznam

- [ ] Všechny P0 problémy mají sprint
- [ ] Závislosti mezi sprinty jsou definovány
- [ ] Akceptační kritéria jsou měřitelná
- [ ] Plán je aktualizován v NEXT_SESSION.md

### 6.2 Mermaid diagram plánu

```mermaid
flowchart LR
    S8[Sprint 8: CI kroky] --> S9[Sprint 9: Kvalita]
    S9 --> S10[Sprint 10: Cross-platform]
    S9 --> S11[Sprint 11: MegaLinter]
    S11 --> S12[Sprint 12: Auto metadata]
```

---

## 7. Opakovaně použitelný checklist

### 7.1 Inventarizace
- [ ] Seznam všech existujících nástrojů
- [ ] Seznam všech existujících workflow
- [ ] Seznam všech existujících skriptů

### 7.2 Gap Analysis
- [ ] Matice pokrytí pre-commit
- [ ] Matice pokrytí pre-push
- [ ] Matice pokrytí CI/CD
- [ ] Seznam chybějících kontrol

### 7.3 Prioritizace
- [ ] Klasifikace P0/P1/P2
- [ ] Vážení podle kritérií
- [ ] Seřazení podle priority

### 7.4 Plánování
- [ ] Definice sprintů
- [ ] Akceptační kritéria
- [ ] Závislosti
- [ ] Aktualizace NEXT_SESSION.md

---

## 8. Návrh logiky procesů a provázaností

### 8.1 Základní principy

```mermaid
flowchart TD
    subgraph "Princip 1: Oddělení vstupů/výstupů"
        A[Vstup] --> B[Proces]
        B --> C[Výstup]
        C --> D[Validace výstupu]
    end
    
    subgraph "Princip 2: Idempotence"
        E[Proces] --> F{Výsledek}
        F -->|Úspěch| G[Konec]
        F -->|Selhání| H[Retry]
        H --> E
    end
    
    subgraph "Princip 3: Kaskádové selhání"
        I[Proces A] --> J[Proces B]
        J --> K[Proces C]
        I -->|selhání| L[STOP]
        J -->|selhání| L
    end
```

### 8.2 Kompletní architektura automatizace

```mermaid
flowchart TB
    subgraph "Vývojář"
        DEV[git commit/push]
    end
    
    subgraph "Lokální úroveň"
        subgraph "pre-commit"
            PC1[Validace metadat]
            PC2[Kontrola duplicit]
            PC3[Linting]
            PC4[Formátování]
            PC5[Aktualizace docs]
        end
        
        subgraph "pre-push"
            PP1[Unit testy]
            PP2[Integrační testy]
            PP3[Build check]
        end
    end
    
    subgraph "CI/CD úroveň"
        subgraph "GitHub Actions"
            CI1[Checkout]
            CI2[Setup prostředí]
            CI3[MegaLinter]
            CI4[Testy]
            CI5[Build]
            CI6[Deploy]
        end
    end
    
    subgraph "Výstupy"
        OUT1[Execution log]
        OUT2[Coverage report]
        OUT3[Artifacts]
        OUT4[PR comment]
    end
    
    DEV --> PC1
    PC1 --> PC2 --> PC3 --> PC4 --> PC5
    PC5 --> PP1
    PP1 --> PP2 --> PP3
    PP3 --> CI1
    CI1 --> CI2 --> CI3 --> CI4 --> CI5 --> CI6
    CI3 --> OUT1
    CI4 --> OUT2
    CI5 --> OUT3
    CI6 --> OUT4
```

### 8.3 Datové toky mezi procesy

```mermaid
flowchart LR
    subgraph "Vstupy"
        V1[git diff]
        V2[Změněné soubory]
        V3[Konfigurace]
    end
    
    subgraph "Zpracování"
        Z1[Filtr souborů]
        Z2[Validace]
        Z3[Transformace]
    end
    
    subgraph "Výstupy"
        W1[Log výsledků]
        W2[Aktualizované soubory]
        W3[Notifikace]
    end
    
    V1 --> Z1
    V2 --> Z1
    V3 --> Z2
    Z1 --> Z2 --> Z3
    Z3 --> W1
    Z3 --> W2
    Z3 --> W3
```

### 8.4 Matice závislostí procesů

| Proces | Závisí na | Poskytuje pro | Vstup | Výstup |
|--------|-----------|---------------|-------|--------|
| check-duplicates | - | validate-metadata | Seznam souborů | Pass/Fail |
| validate-metadata | check-duplicates | update-docs | .md soubory | Pass/Fail |
| update-docs | validate-metadata | validate-constitution | QA_REPORT.md | Aktualizovaný soubor |
| validate-constitution | update-docs | - | CONSTITUTION.md | Pass/Fail |
| rust-tests | - | - | src-tauri/ | Pass/Fail |
| MegaLinter | - | - | Celý projekt | Lint report |

### 8.5 Pravidla pro návrh procesů

#### 8.5.1 Single Responsibility
```
Každý proces má jednu odpovědnost:
- check-duplicates: pouze kontrola duplicit
- validate-metadata: pouze validace metadat
- update-docs: pouze aktualizace dokumentace
```

#### 8.5.2 Fail Fast
```
Procesy selžou co nejdříve:
1. Validace vstupů
2. Zpracování
3. Validace výstupů
```

#### 8.5.3 Graceful Degradation
```
Při selhání:
- Povinné kroky: block (zastavit)
- Volitelné kroky: warn (pokračovat s varováním)
- Informační kroky: ignore (pokračovat bez varování)
```

### 8.6 Konfigurace závislostí

```json
{
  "steps": [
    {
      "id": "validate-metadata",
      "dependsOn": ["check-duplicates"],
      "onFailure": "block"
    },
    {
      "id": "update-docs",
      "dependsOn": ["validate-metadata"],
      "onFailure": "block"
    },
    {
      "id": "rust-tests",
      "dependsOn": [],
      "onFailure": "block"
    }
  ]
}
```

### 8.7 Diagram rozhodování

```mermaid
flowchart TD
    START[Start] --> TRIGGER{Trigger?}
    
    TRIGGER -->|pre-commit| PC[Pre-commit flow]
    TRIGGER -->|pre-push| PP[Pre-push flow]
    TRIGGER -->|ci| CI[CI flow]
    
    PC --> PC1[Validace]
    PC1 --> PC2{Vše OK?}
    PC2 -->|Ano| PC3[Aktualizace docs]
    PC2 -->|Ne| FAIL[Block commit]
    PC3 --> SUCCESS[Allow commit]
    
    PP --> PP1[Testy]
    PP1 --> PP2{Vše OK?}
    PP2 -->|Ano| PP3[Archivace]
    PP2 -->|Ne| FAIL2[Block push]
    PP3 --> SUCCESS2[Allow push]
    
    CI --> CI1[Setup]
    CI1 --> CI2[Lint]
    CI2 --> CI3[Test]
    CI3 --> CI4[Build]
    CI4 --> CI5{Vše OK?}
    CI5 -->|Ano| CI6[Deploy]
    CI5 -->|Ne| CI7[Report failure]
```

### 8.8 Šablona pro dokumentaci procesu

```markdown
## Proces: [Název]

### Základní informace
- **ID:** [identifikátor]
- **Trigger:** [pre-commit/pre-push/ci]
- **Priorita:** [P0/P1/P2]

### Vstupy
- Vstup 1: [popis]
- Vstup 2: [popis]

### Výstupy
- Výstup 1: [popis]
- Výstup 2: [popis]

### Závislosti
- Závisí na: [seznam procesů]
- Poskytuje pro: [seznam procesů]

### Chování při selhání
- onFailure: [block/warn/ignore]

### Příklad konfigurace
\`\`\`json
{
  "id": "...",
  "command": "...",
  "expectedOutput": "..."
}
\`\`\`
```

---

## 9. Příklad aplikace na aktuální projekt

### 8.1 Inventarizace (hotovo)

| Nástroj | Stav |
|---------|------|
| Husky | ✅ |
| pre-commit hooks | ✅ |
| pre-push hooks | ✅ |
| GitHub Actions | ✅ |
| MegaLinter config | ✅ (ale není v CI) |
| ESLint | ❌ |
| Prettier | ❌ |
| rustfmt | ❌ |

### 8.2 Gap Analysis (hotovo)

| Fáze | Chybějící kontrola | Priorita |
|------|-------------------|----------|
| CI | MegaLinter | P0 |
| pre-commit | Automatická metadata | P0 |
| pre-commit | Linting | P0 |
| pre-commit | CHANGE_LOG.md update | P1 |

### 8.3 Výsledné sprinty

- **Sprint 11:** MegaLinter integrace (P0)
- **Sprint 12:** Automatická aktualizace metadat (P0)
- **Sprint 13:** Linting integrace (P0)
- **Sprint 14:** CHANGE_LOG.md automatizace (P1)

---

## Historie změn

| Datum | Verze | Popis změny |
|-------|-------|-------------|
| 2026-02-17 | 1.0 | Vytvoření metodiky |

---

*Vytvořeno: 2026-02-17 06:29 (UTC+1)*
