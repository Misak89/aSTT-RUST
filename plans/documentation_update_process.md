# Proces aktualizace dokumentace v projektu aSTT-RUST

**Cesta:** plans/documentation_update_process.md  
**Verze:** 1.1  
**Vytvořeno:** 2026-02-17 15:54 (UTC+1)  
**Poslední změna:** 2026-02-18 03:01 (UTC+1)

---

## Přehled

Projekt využívá automatizovaný systém pro aktualizaci a validaci dokumentace založený na Git hookech a PowerShell skriptech. Celý proces je řízen pomocí [`workflow-steps.json`](workflow-steps.json) konfigurace.

## Komponenty systému

| Komponenta | Popis |
|------------|-------|
| [`workflow-steps.json`](workflow-steps.json) | Centrální konfigurace všech workflow kroků |
| [`scripts/workflow_guard.ps1`](scripts/workflow_guard.ps1) | Hlavní řídící skript pro spouštění kroků |
| [`scripts/update_metadata.ps1`](scripts/update_metadata.ps1) | Aktualizace metadat v .md souborech |
| [`scripts/update_docs.ps1`](scripts/update_docs.ps1) | Aktualizace QA_REPORT.md |
| [`.husky/pre-commit`](.husky/pre-commit) | Git hook pro pre-commit fázi |
| [`.husky/pre-push`](.husky/pre-push) | Git hook pro pre-push fázi |

---

## Diagram procesu - Ideální stav vs Současná implementace

### Ideální proces (dokumentace se aktualizuje kontinuálně)

```mermaid
flowchart TB
    subgraph DevCycle["Vývojový cyklus"]
        direction TB
        
        subgraph Step1["Krok 1: Editace kódu"]
            A1[Úprava Rust kódu]
            A2[Aktualizace ARCHITECTURE.md]
        end
        
        subgraph Step2["Krok 2: Editace UI"]
            B1[Úprava Svelte komponent]
            B2[Aktualizace dokumentace UI]
        end
        
        subgraph Step3["Krok 3: Testování"]
            C1[Spuštění testů]
            C2[Aktualizace QA_REPORT.md]
        end
        
        subgraph Step4["Krok 4: Příprava commitu"]
            D1[git add]
            D2[Validace před commitem]
        end
    end

    A1 --> A2
    A2 --> B1
    B1 --> B2
    B2 --> C1
    C1 --> C2
    C2 --> D1
    D1 --> D2
    
    style A2 fill:#90EE90
    style B2 fill:#90EE90
    style C2 fill:#90EE90
    style D2 fill:#90EE90
```

### Současná implementace (aktualizace až při commitu)

```mermaid
flowchart TB
    subgraph DevCycle["Vývojový cyklus - SOUČASNÝ STAV"]
        direction TB
        
        subgraph Step1["Krok 1: Editace kódu"]
            A1[Úprava Rust kódu]
            A2x[ARCHITECTURE.md NEAKTUALIZOVÁNA]
        end
        
        subgraph Step2["Krok 2: Editace UI"]
            B1[Úprava Svelte komponent]
            B2x[Dokumentace UI NEAKTUALIZOVÁNA]
        end
        
        subgraph Step3["Krok 3: Testování"]
            C1[Spuštění testů]
            C2x[QA_REPORT.md NEAKTUALIZOVÁNA]
        end
        
        subgraph Step4["Krok 4: Commit"]
            D1[git add]
            D2[git commit]
            D3[PRE-COMMIT: Aktualizace metadat]
        end
    end

    A1 --> A2x
    A2x --> B1
    B1 --> B2x
    B2x --> C1
    C1 --> C2x
    C2x --> D1
    D1 --> D2
    D2 --> D3
    
    style A2x fill:#FFB6C1
    style B2x fill:#FFB6C1
    style C2x fill:#FFB6C1
    style D3 fill:#FFFF99
```

---

## Detailní diagram Git workflow

```mermaid
flowchart TB
    subgraph Developer["Vývojář"]
        A[git add .]
        B[git commit -m message]
        C[git push]
    end

    subgraph PreCommit["Pre-commit Hook"]
        D[workflow_guard.ps1<br/>-Trigger pre-commit]
        
        D1[update-metadata<br/>Aktualizace metadat .md]
        D2[check-duplicates<br/>Kontrola duplicit]
        D3[validate-timestamps<br/>Validace timestampů]
        D4[validate-document-metadata<br/>Validace metadat]
        D5[update-docs<br/>Aktualizace QA_REPORT]
        D6[validate-constitution<br/>Kontrola souladu]
    end

    subgraph PrePush["Pre-push Hook"]
        E[workflow_guard.ps1<br/>-Trigger pre-push]
        
        E1[rust-tests<br/>Rust unit testy]
        E2[validate-next-session<br/>Kontrola NEXT_SESSION.md]
        E3[archive-next-session<br/>Archivace NEXT_SESSION.md]
    end

    subgraph CI["CI/CD - GitHub Actions"]
        F[megalinter.yml]
        
        F1[check-duplicates-ci]
        F2[validate-metadata-ci]
        F3[rust-tests-ci]
        F4[MegaLinter]
    end

    subgraph Results["Výsledky"]
        G[Commit vytvořen]
        H[Push povolen]
        I[CI proběhne]
        J[BLOCK - commit zamítnut]
        K[BLOCK - push zamítnut]
    end

    A --> B
    B --> D
    
    D --> D1
    D1 --> D2
    D2 --> D3
    D3 --> D4
    D4 --> D5
    D5 --> D6
    
    D6 -->|PASS| G
    D6 -->|FAIL| J
    
    G --> C
    C --> E
    
    E --> E1
    E1 --> E2
    E2 --> E3
    
    E3 -->|PASS| H
    E3 -->|FAIL| K
    
    H --> F
    F --> F1
    F1 --> F2
    F2 --> F3
    F3 --> F4
    F4 --> I
```

---

## Identifikované problémy současného procesu

| Problém | Dopad | Možné řešení |
|---------|-------|--------------|
| Dokumentace se aktualizuje až při commitu | Zastaralá dokumentace během vývoje | IDE File Watcher |
| Metadata nejsou ve staging area | Commit neobsahuje aktualizovaná metadata | `git add` v pre-commit hooku |
| Žádná kontinuální synchronizace | Dokumentace odrazuje od kódu | Automatizované CI/CD kontroly |

---

## Co je IDE File Watcher?

**IDE File Watcher** je funkce v editoru (např. VS Code, IntelliJ), která automaticky spouští skript při uložení souboru.

### Jak by fungoval pro aktualizaci dokumentace:

```mermaid
flowchart LR
    A[Uložení .md souboru<br/>Ctrl+S] --> B[File Watcher<br/>detekuje změnu]
    B --> C[Spustí<br/>update_metadata.ps1]
    C --> D[Metadata aktualizována<br/>okamžitě v souboru]
```

### Konfigurace ve VS Code:

1. Nainstalovat rozšíření **Run on Save** od emeraldwalk
   - Marketplace: https://marketplace.visualstudio.com/items?itemName=emeraldwalk.RunOnSave
   - ID: `emeraldwalk.RunOnSave`
    
2. Přidat do `.vscode/settings.json`:

```json
{
  "emeraldwalk.runonsave": {
    "commands": [
      {
        "match": "\\.md$",
        "cmd": "powershell -ExecutionPolicy Bypass -File ${workspaceFolder}/scripts/update_metadata.ps1 -FilePath ${file}"
      }
    ]
  }
}
```

### Komplexní konfigurace pro všechny typy souborů:

```json
{
  "emeraldwalk.runonsave": {
    "commands": [
      {
        "match": "\\.md$",
        "cmd": "powershell -ExecutionPolicy Bypass -File ${workspaceFolder}/scripts/update_metadata.ps1 -FilePath ${file} >> ${workspaceFolder}/logs/runonsave.log 2>&1",
        "isAsync": true
      },
      {
        "match": "\\.(rs|ts|svelte|py)$",
        "cmd": "python ${workspaceFolder}/scripts/gen_docs.py --source ${file} --output docs/ >> ${workspaceFolder}/logs/runonsave.log 2>&1",
        "isAsync": true
      },
      {
        "match": "\\.specify\\/.*\\.md$",
        "cmd": "python ${workspaceFolder}/scripts/gen_docs.py --spec ${file} >> ${workspaceFolder}/logs/runonsave.log 2>&1",
        "isAsync": true
      }
    ]
  }
}
```

### Rozsah zpracování:

| Typ souboru | Akce | Výstup |
|-------------|------|--------|
| `*.md` | Aktualizace metadat | Stejný soubor |
| `*.rs, *.ts, *.svelte, *.py` | Generování dokumentace | `docs/` složka |
| `.specify/*.md` | Generování ze specifikací | `docs/` složka |

---

## Kompletní architektura automatické správy dokumentace po implementaci

```mermaid
flowchart TB
    subgraph IDE["VS Code / Cursor IDE"]
        A[Uložení souboru<br/>Ctrl+S]
        B[Run on Save<br/>emeraldwalk.RunOnSave]
    end

    subgraph RunOnSave["Run on Save Actions"]
        C1[.md soubory<br/>update_metadata.ps1]
        C2[Kódové soubory<br/>gen_docs.py]
        C3[Specifikace<br/>gen_docs.py --spec]
    end

    subgraph Logging["Logování"]
        L[logs/runonsave.log]
    end

    subgraph GitHooks["Git Hooks - existující"]
        D[Pre-commit Hook<br/>workflow_guard.ps1]
        E[Pre-push Hook<br/>workflow_guard.ps1]
    end

    subgraph Validation["Validace - existující"]
        F1[check-duplicates]
        F2[validate-timestamps]
        F3[validate-document-metadata]
        F4[update-docs]
        F5[validate-constitution]
    end

    subgraph CI["CI/CD - existující"]
        G[GitHub Actions<br/>MegaLinter]
    end

    subgraph Output["Výstupy"]
        H1[Aktualizované .md]
        H2[docs/ generovaná dokumentace]
        H3[QA_REPORT.md]
    end

    A --> B
    B --> C1
    B --> C2
    B --> C3
    
    C1 --> L
    C2 --> L
    C3 --> L
    
    C1 --> H1
    C2 --> H2
    C3 --> H2

    D --> F1
    D --> F2
    D --> F3
    D --> F4
    D --> F5
    
    F4 --> H3
    
    E --> G

    style B fill:#90EE90
    style L fill:#87CEEB
    style D fill:#FFD700
    style E fill:#FFD700
```

---

## Jak bude systém fungovat - detailní tok

```mermaid
sequenceDiagram
    participant Dev as Vývojář
    participant IDE as VS Code
    participant RoS as Run on Save
    participant Script as Skripty
    participant Log as runonsave.log
    participant Git as Git Hooks
    participant CI as CI/CD

    Dev->>IDE: Uložení souboru Ctrl+S
    IDE->>RoS: Detekce změny
    RoS->>Script: Spuštění příslušného skriptu
    Script->>Script: Zpracování souboru
    Script->>Log: Zápis logu
    Script-->>IDE: Dokončeno
    
    Note over Dev,CI: Později při commitu
    
    Dev->>Git: git commit
    Git->>Git: Pre-commit validace
    Git-->>Dev: Commit povolen/zamítnut
    
    Dev->>Git: git push
    Git->>CI: GitHub Actions
    CI-->>Dev: CI výsledek
```

---

## Integrace se současným systémem

| Komponenta | Současný stav | Po implementaci |
|------------|---------------|-----------------|
| **Run on Save** | Není | Nová vrstva - okamžitá aktualizace |
| **Pre-commit hook** | Primární | Fallback + validace |
| **Pre-push hook** | Testy + archivace | Beze změny |
| **CI/CD** | MegaLinter | Beze změny |
| **Logování** | logs/execution-log.json | + logs/runonsave.log |

### Princip fungování:

1. **Run on Save (NOVÉ)** - Okamžitá reakce na uložení
   - Aktualizuje metadata v .md souborech
   - Generuje dokumentaci z kódu
   - Loguje do `logs/runonsave.log`

2. **Pre-commit hook (EXISTUJÍCÍ)** - Validace před commitem
   - Kontrola duplicit
   - Validace timestampů a metadat
   - Aktualizace QA_REPORT.md
   - Kontrola souladu s CONSTITUTION.md

3. **Pre-push hook (EXISTUJÍCÍ)** - Testy před pushem
   - Rust testy
   - Validace NEXT_SESSION.md
   - Archivace session souborů

4. **CI/CD (EXISTUJÍCÍ)** - Finální kontrola v cloudu
   - MegaLinter
   - Rust testy v CI prostředí

### Výhody implementace do workflow:

| Výhoda | Popis |
|--------|-------|
| **Okamžitá aktualizace** | Metadata se aktualizují při každém uložení - dokumentace je vždy aktuální během vývoje |
| **Méně konfliktů** | Změny jsou malé a časté - snižuje riziko konfliktů při merge |
| **Žádné čekání na commit** | Není třeba čekat na pre-commit hook - změny jsou provedeny okamžitě |
| **Lepší DX** | Vývojář vidí aktuální metadata hned po uložení |
| **Méně chybových stavů** | Validace probíhá postupně - snadnější opravy |
| **Oddělené změny** | Každá změna je zaznamenána s timestampem - lepší audit trail |

### Nevýhody implementace do workflow:

| Nevýhoda | Popis | Mitigace |
|----------|-------|----------|
| **Hluk v git historii** | Časté malé změny metadat zanášejí historii | Použít squash merge nebo conventional commits |
| **Závislost na IDE** | Funguje jen pokud je VS Code s pluginem | Zachovat pre-commit hook jako fallback |
| **Možné zpoždění** | Při rychlém ukládání více souborů může dojít k zpoždění | Použít `isAsync: true` v konfiguraci |
| **Konflikty při paralelní práci** | Dva vývojáři na stejném souboru mohou způsobit konflikt | Git standardní řešení konfliktů |
| **Zátěž systému** | Časté spouštění PowerShell skriptů | Skript je jednoduchý a rychlý |
| **Nemožnost vypnout** | Pokud je v .vscode/settings.json, platí pro všechny | Přidat glob ignorování nebo podmínky |

### Doporučení pro implementaci:

```mermaid
flowchart TB
    A[Rozhodnutí o implementaci] --> B{Je tým používá VS Code?}
    B -->|Ano| C[Implementovat Run on Save]
    B -->|Ne| D[Zachovat pouze pre-commit hook]
    
    C --> E[Přidat .vscode/settings.json do repozitáře]
    E --> F[Zachovat pre-commit hook jako fallback]
    F --> G[Dokumentovat v CONTRIBUTING.md]
    
    D --> H[Spouštět manuálně před commitem]
```

### Kombinované řešení (doporučeno):

Implementovat **obojí** - Run on Save pro okamžitou aktualizaci + pre-commit hook jako fallback:

1. **Run on Save** - aktualizuje metadata při uložení (primární)
2. **Pre-commit hook** - validuje a doplní metadata pokud Run on Save nefunguje (fallback)
3. **CI/CD** - finální kontrola v cloudovém prostředí (garance)

---

## Návrh ideálního procesu

```mermaid
flowchart LR
    subgraph Triggers["Aktivační body aktualizace"]
        T1[Uložení souboru v IDE]
        T2[git add]
        T3[git commit]
        T4[git push]
    end
    
    subgraph Actions["Akce aktualizace"]
        A1[File Watcher:<br/>update_metadata.ps1]
        A2[Pre-commit:<br/>validace + git add]
        A3[Pre-push:<br/>testy + archivace]
        A4[CI/CD:<br/>kompletní kontrola]
    end
    
    T1 --> A1
    T2 --> A2
    T3 --> A2
    T4 --> A3
    A3 --> A4
```

---

## Detailní popis fází

### Fáze 1: Pre-commit

Spouští se před každým commitem. Zahrnuje 6 kroků:

| Krok | Skript | Popis | Při selhání |
|------|--------|-------|-------------|
| update-metadata | [`update_metadata.ps1`](scripts/update_metadata.ps1) | Automaticky aktualizuje verzi a timestamp ve změněných .md souborech | warn (pouze varování) |
| check-duplicates | [`check_duplicates.ps1`](scripts/check_duplicates.ps1) | Detekuje duplicitní řádky v souborech | block (zablokuje commit) |
| validate-timestamps | [`validate_timestamps.ps1`](scripts/validate_timestamps.ps1) | Kontroluje aktuálnost timestampů | block |
| validate-document-metadata | [`validate_document_metadata.ps1`](scripts/validate_document_metadata.ps1) | Validuje verzi, timestamp a historii změn | block |
| update-docs | [`update_docs.ps1`](scripts/update_docs.ps1) | Aktualizuje QA_REPORT.md a CHANGE_LOG.md | block |
| validate-constitution | [`validate_constitution.ps1`](scripts/validate_constitution.ps1) | Ověřuje soulad s CONSTITUTION.md | block |

### Fáze 2: Pre-push

Spouští se před každým pushem do remote repository:

| Krok | Popis | Při selhání |
|------|-------|-------------|
| rust-tests | Spustí Rust unit testy (`cargo test`) | block |
| validate-next-session | Ověří aktuálnost NEXT_SESSION.md | block |
| archive-next-session | Archivuje NEXT_SESSION.md s timestampem | block |

### Fáze 3: CI/CD

Spouští se na GitHub Actions po pushi do main/develop větví:

| Krok | Popis |
|------|-------|
| check-duplicates-ci | Kontrola duplicit v CI prostředí |
| validate-metadata-ci | Validace metadat v CI prostředí |
| rust-tests-ci | Rust testy v CI prostředí |
| MegaLinter | Komplexní linting celého projektu |

---

## Formát metadat dokumentů

Každý .md soubor by měl obsahovat metadata v tomto formátu:

```markdown
**Cesta:** relative/path/to/file.md  
**Verze:** 1.0  
**Vytvořeno:** 2026-02-17 15:54 (UTC+1)  
**Poslední změna:** 2026-02-17 15:54 (UTC+1)

## Historie změn

| Datum | Verze | Popis změny |
|-------|-------|-------------|
| 2026-02-17 | 1.0 | Vytvoření dokumentu |
```

---

## Workflow Execution Guard

Hlavní řídící skript [`workflow_guard.ps1`](scripts/workflow_guard.ps1) zajišťuje:

1. **Načtení konfigurace** z `workflow-steps.json`
2. **Validaci JSON schématu**
3. **Sekvenční spouštění kroků** podle triggeru
4. **Zaznamenávání výsledků** do logu
5. **Retry logiku** pro nestabilní kroky (např. rust-tests)

### Příklad volání:

```powershell
# Pre-commit fáze
powershell -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger pre-commit

# Pre-push fáze
powershell -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger pre-push

# Dry run (pouze simulace)
powershell -ExecutionPolicy Bypass -File scripts/workflow_guard.ps1 -Trigger pre-commit -DryRun
```

---

## Zpracování chyb

```mermaid
flowchart LR
    subgraph OnFailure["Akce při selhání"]
        A[block] --> B[Zastavit a vrátit chybu]
        C[warn] --> D[Pokračovat s varováním]
        E[ignore] --> F[Pokračovat bez upozornění]
    end
    
    G[Krok selhal] --> A
    G --> C
    G --> E
```

---

## Komplexní analýza procesu aktualizace dokumentace

### Analýza PŘED implementací Run on Save

#### Současný tok dat:

```mermaid
flowchart TB
    subgraph Vývoj["Vývojová fáze"]
        V1[Editace kódu<br/>.rs .ts .svelte .py]
        V2[Editace dokumentace<br/>.md soubory]
        V3[Testování<br/>cargo test]
    end

    subgraph Problémy["IDENTIFIKOVANÉ PROBLÉMY"]
        P1[❌ Dokumentace NEAKTUALIZOVÁNA<br/>během vývoje]
        P2[❌ Metadata NEAKTUALIZOVÁNA<br/>při uložení]
        P3[❌ Specifikace NESYNCHRONIZOVÁNA<br/>s implementací]
    end

    subgraph GitCommit["Git Commit fáze"]
        G1[git add]
        G2[git commit]
        G3[Pre-commit Hook<br/>workflow_guard.ps1]
    end

    subgraph CommitActions["Commit akce"]
        C1[update-metadata<br/>Aktualizace metadat]
        C2[check-duplicates]
        C3[validate-timestamps]
        C4[validate-document-metadata]
        C5[update-docs<br/>QA_REPORT.md]
        C6[validate-constitution]
    end

    subgraph GitPush["Git Push fáze"]
        H1[git push]
        H2[Pre-push Hook]
        H3[rust-tests]
        H4[validate-next-session]
        H5[archive-next-session]
    end

    subgraph CI["CI/CD fáze"]
        I1[GitHub Actions]
        I2[MegaLinter]
        I3[CI validace]
    end

    V1 --> V2
    V2 --> V3
    V3 --> P1
    V3 --> P2
    V3 --> P3
    
    P1 --> G1
    P2 --> G1
    P3 --> G1
    
    G1 --> G2
    G2 --> G3
    
    G3 --> C1
    C1 --> C2
    C2 --> C3
    C3 --> C4
    C4 --> C5
    C5 --> C6
    
    C6 -->|PASS| H1
    C6 -->|FAIL| X[BLOCK commit]
    
    H1 --> H2
    H2 --> H3
    H3 --> H4
    H4 --> H5
    
    H5 -->|PASS| I1
    H5 -->|FAIL| Y[BLOCK push]
    
    I1 --> I2
    I2 --> I3

    style P1 fill:#FFB6C1
    style P2 fill:#FFB6C1
    style P3 fill:#FFB6C1
    style X fill:#FF6B6B
    style Y fill:#FF6B6B
```

#### Problémy současného stavu:

| Problém | Dopad | Kdy se projeví |
|---------|-------|----------------|
| Dokumentace se aktualizuje až při commitu | Zastaralá dokumentace během vývoje | Během celé vývojové fáze |
| Metadata nejsou ve staging area | Commit neobsahuje aktualizovaná metadata | Při commitu |
| Žádná kontinuální synchronizace | Dokumentace odrazuje od kódu | Při review |
| Specifikace nesynchronizována | Rozdíl mezi spec a implementací | Při merge |
| Žádné logování během vývoje | Nelze diagnostikovat problémy | Celý proces |

---

### Analýza PO implementaci Run on Save

#### Nový tok dat:

```mermaid
flowchart TB
    subgraph Vývoj["Vývojová fáze"]
        V1[Editace kódu<br/>.rs .ts .svelte .py]
        V2[Editace dokumentace<br/>.md soubory]
        V3[Testování<br/>cargo test]
    end

    subgraph RunOnSave["Run on Save - NOVÁ VRSTVA"]
        R1[Detekce uložení<br/>Ctrl+S]
        R2{Typ souboru?}
        R3[update_metadata.ps1<br/>pro .md soubory]
        R4[gen_docs.py<br/>pro kódové soubory]
        R5[gen_docs.py --spec<br/>pro specifikace]
        R6[logs/runonsave.log<br/>Logování]
    end

    subgraph Výstupy["Okamžité výstupy"]
        O1[✅ Metadata aktualizována]
        O2[✅ Dokumentace generována]
        O3[✅ Specifikace synchronizována]
    end

    subgraph GitCommit["Git Commit fáze"]
        G1[git add]
        G2[git commit]
        G3[Pre-commit Hook<br/>FALLBACK + Validace]
    end

    subgraph CommitActions["Commit akce"]
        C1[update-metadata<br/>FALLBACK]
        C2[check-duplicates]
        C3[validate-timestamps]
        C4[validate-document-metadata]
        C5[update-docs]
        C6[validate-constitution]
    end

    subgraph GitPush["Git Push fáze"]
        H1[git push]
        H2[Pre-push Hook]
        H3[rust-tests]
        H4[validate-next-session]
        H5[archive-next-session]
    end

    subgraph CI["CI/CD fáze"]
        I1[GitHub Actions]
        I2[MegaLinter]
        I3[CI validace]
    end

    V1 --> R1
    V2 --> R1
    V3 --> R1
    
    R1 --> R2
    R2 -->|.md| R3
    R2 -->|.rs .ts .svelte .py| R4
    R2 -->|.specify/*.md| R5
    
    R3 --> R6
    R4 --> R6
    R5 --> R6
    
    R3 --> O1
    R4 --> O2
    R5 --> O3
    
    O1 --> G1
    O2 --> G1
    O3 --> G1
    
    G1 --> G2
    G2 --> G3
    
    G3 --> C1
    C1 --> C2
    C2 --> C3
    C3 --> C4
    C4 --> C5
    C5 --> C6
    
    C6 -->|PASS| H1
    C6 -->|FAIL| X[BLOCK commit]
    
    H1 --> H2
    H2 --> H3
    H3 --> H4
    H4 --> H5
    
    H5 -->|PASS| I1
    H5 -->|FAIL| Y[BLOCK push]
    
    I1 --> I2
    I2 --> I3

    style R1 fill:#90EE90
    style R6 fill:#87CEEB
    style O1 fill:#90EE90
    style O2 fill:#90EE90
    style O3 fill:#90EE90
    style X fill:#FF6B6B
    style Y fill:#FF6B6B
```

#### Vylepšení po implementaci:

| Vylepšení | Dopad | Kdy se projeví |
|-----------|-------|----------------|
| Okamžitá aktualizace metadat | Dokumentace vždy aktuální | Při každém uložení |
| Generování dokumentace z kódu | Synchronizace kód-dokumentace | Při uložení kódu |
| Synchronizace specifikací | Spec odpovídá implementaci | Při uložení spec |
| Logování do runonsave.log | Diagnostika problémů | Celý proces |
| Pre-commit jako fallback | Garance při selhání Run on Save | Při commitu |

---

### Srovnání PŘED vs PO

```mermaid
flowchart LR
    subgraph PŘED["PŘED implementací"]
        direction TB
        A1[Editace] --> A2[Žádná aktualizace]
        A2 --> A3[Commit]
        A3 --> A4[Aktualizace při commitu]
        A4 --> A5[Push]
        A5 --> A6[CI/CD]
    end

    subgraph PO["PO implementaci"]
        direction TB
        B1[Editace] --> B2[Run on Save<br/>Okamžitá aktualizace]
        B2 --> B3[Commit]
        B3 --> B4[Validace + Fallback]
        B4 --> B5[Push]
        B5 --> B6[CI/CD]
    end

    PŘED -->|Implementace| PO

    style A2 fill:#FFB6C1
    style A4 fill:#FFFF99
    style B2 fill:#90EE90
    style B4 fill:#90EE90
```

---

### Detailní srovnávací tabulka

| Aspekt | PŘED | PO |
|--------|------|-----|
| **Kdy se aktualizuje dokumentace** | Při commitu | Při uložení (Ctrl+S) |
| **Kdy se aktualizují metadata** | Při commitu | Při uložení |
| **Synchronizace specifikací** | Manuální | Automatická |
| **Logování během vývoje** | Žádné | logs/runonsave.log |
| **Pre-commit hook role** | Primární | Fallback + validace |
| **DX (Developer Experience)** | Čekání na commit | Okamžitá zpětná vazba |
| **Riziko zastaralé dokumentace** | Vysoké | Nízké |
| **Diagnostika problémů** | Obtížná | Snadná (log) |

---

## Shrnutí

Proces aktualizace dokumentace je plně automatizovaný a probíhá ve čtyřech fázích:

1. **Run on Save (NOVÉ)** - Okamžitá aktualizace při uložení
2. **Pre-commit** - Validace a fallback
3. **Pre-push** - Testy a archivace session souborů
4. **CI/CD** - Komplexní kontrola v cloudovém prostředí

Tento systém zajišťuje konzistenci dokumentace, aktuálnost metadat a kvalitu kódu před každým commitem a pushem.

---

*Vytvořeno: 2026-02-17 15:54 (UTC+1)*
