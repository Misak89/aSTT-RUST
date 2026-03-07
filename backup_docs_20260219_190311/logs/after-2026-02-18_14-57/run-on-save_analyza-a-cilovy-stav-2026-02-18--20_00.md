# Analýza a cílový stav pro „Run on Save“ (nebo vhodnější alternativu)

## Co je na diagramu (a kódu) problematické

1. **Nejednoznačné spouštění „na uložení“**
   Diagram neobsahuje žádný uzel typu *Run on Save / file watcher* (jen `V1/V2 -> pre-commit`),
   takže „automatická aktualizace dokumentace po každém uložení“ se ve skutečnosti neděje.

2. **Přetížení pre-commit hooku**
   V pre-commit řetězu máte i kroky, které typicky:
   - jsou pomalé (`update_docs` může být drahé),
   - nebo mění soubory (`update_metadata`, `update_docs`) → to dělá z pre-commit hooku
     „autogenerátor“, který často vytváří tření (a může vést k re-commit loopu).

3. **Chybí „gating“ logika pro rychlost**
   Vše se spouští sekvenčně bez „jen když se změnilo X“. Typicky chcete:
   - rychlé kontroly vždy,
   - těžké kroky jen při relevantní změně,
   - a některé pouze manuálně / v CI.

4. **Nejasné napojení CI kroků**
   `GHA --> ML --> CDCHECK/CDMETA/CDRUST` je podezřelé: MegaLinter obvykle sám běží jako job/step;
   validace duplicit/metadat/testy jsou typicky samostatné joby/stepy v workflow, ne „pod“
   MegaLinterem. (V diagramu to působí jako závislost, která nemusí odpovídat realitě.)

5. **Rizikový cyklus kolem NEXT_SESSION archivace**
   `ANS --> NS` a zároveň `NS --> ANS` + `ANS --> NS` působí jako logický cyklus.
   Správně má být: *validace → (pokud push) archivace → vytvoření/obnovení NEXT_SESSION*, ale bez
   „zpětného přepisování“ v cyklu.

6. **Logování jen jako výstup, ale bez „force-audit“ vazeb**
   `FA[logs/force-audit.log]` není nikam připojeno. Pokud má audit log význam, měl by být explicitně
   plněn kroky, které něco „vynucují“ nebo opravují.

## Jak by měl vypadat „správný a kvalitní stav“ po implementaci Run on Save
(nebo vhodnější alternativy)

1. **Rozdělit na 3 vrstvy:**
   - **On Save (lokálně, rychlé a idempotentní)**: formátování, metadata, základní validace metadat,
     rychlá kontrola duplicit jen nad dotčenými soubory.
   - **Pre-commit (lokálně, gating kvality)**: *pouze* rychlé kontroly + zajištění, že workspace je
     čistý (žádné necommitnuté auto-změny).
   - **Pre-push / CI (těžké, autoritativní)**: testy (`cargo test`), plná validace, MegaLinter, build.

2. **Princip: „hooky nemají měnit soubory“ (nebo jen výjimečně)**
   Nejčistší praxe:
   - **On Save** smí upravit soubory (protože to uživatel čeká při uložení).
   - **Pre-commit** ideálně *jen failne* s jasnou hláškou: „Spusť fix: …“ nebo „Ulož soubory
     (On Save)“.

3. **Přidat explicitní „File Watcher / Run on Save“ uzel**
   V diagramu musí být vrstva mezi `V1/V2` a `Git_hooks`, která dělá:
   - update metadata,
   - update docs (jen pokud relevantní),
   - rychlou validaci.

4. **Gating podle změněných souborů (rychlost)**
   - Změna `*.rs` → formát, lint, (volitelně) rychlé testy.
   - Změna `*.md` / `workflow-steps.json` → metadata + validace dokumentů.
   - Změna `NEXT_SESSION.md` → jen next-session validace (ne archivace).

5. **NEXT_SESSION: odstranit cyklus, jasně definovat tok**
   Doporučení:
   - `pre-push`: validace `NEXT_SESSION.md`, pak archivace do `NEXT_SESSION_Archive/…`, pak
     regenerace prázdné šablony `NEXT_SESSION.md` (volitelně) – ale jednosměrně.

6. **CI: zobrazit jako paralelní joby (a lokálně to jen před-filtrovat)**
   CI je „zdroj pravdy“: co neprojde v CI, to se nesmí mergnout. Lokální vrstvy mají jen zkrátit
   feedback loop.

## Návrh „správného“ Mermaid diagramu (kvalitní cílový stav)

```mermaid
flowchart TB
  %% =========================
  %% 1) Řídící dokumentace
  %% =========================
  subgraph RD["Řídící dokumentace"]
    WD[workflow-steps.json]
    WS[workflow-steps.schema.json]
    CON[CONSTITUTION.md]
    GOV[GOVERNANCE.md]
    ARCH[ARCHITECTURE.md]
  end

  %% =========================
  %% 2) Vývoj
  %% =========================
  subgraph DEV["Vývoj"]
    V1[editace kódu]
    V2[editace dokumentace]
  end

  %% =========================
  %% 3) On Save vrstva (File watcher)
  %% =========================
  subgraph ONSAVE["On Save (File Watcher / Run on Save)"]
    OS_GUARD[scripts/workflow_guard.ps1]
    OS_META[scripts/update_metadata.ps1]
    OS_DOCS[scripts/update_docs.ps1]
    OS_VDM[scripts/validate_document_metadata.ps1]
    OS_DUP[scripts/check_duplicates.ps1]
    OS_LOG[logs/execution-log.json]
  end

  %% =========================
  %% 4) Git hooky
  %% =========================
  subgraph HOOKS["Git hooks"]
    PC[.husky/pre-commit]
    PP[.husky/pre-push]
    GP[git push]
  end

  %% =========================
  %% 5) Pre-commit (rychlé gating)
  %% =========================
  subgraph PRECOMMIT["Pre-commit (rychlé kontroly, bez auto-změn)"]
    PC_GUARD[scripts/workflow_guard.ps1]
    PC_VDM[scripts/validate_document_metadata.ps1]
    PC_DUP[scripts/check_duplicates.ps1]
    PC_VC[scripts/validate_constitution.ps1]
    PC_FAIL[fail s instrukcí "ulož/spusť fix"]
  end

  %% =========================
  %% 6) Pre-push (těžší + NEXT_SESSION)
  %% =========================
  subgraph PREPUSH["Pre-push (těžší kontroly)"]
    RT[cargo test]
    VNS[scripts/validate_next_session.ps1]
    ANS[scripts/archive_next_session.ps1]
    NSA[NEXT_SESSION_Archive/…]
  end

  %% =========================
  %% 7) CI/CD
  %% =========================
  subgraph CI["CI/CD (.github/workflows)"]
    GHA[GitHub Actions workflow]
    ML[MegaLinter]
    CI_DUP[check_duplicates]
    CI_META[validate_document_metadata]
    CI_TEST[cargo test]
  end

  %% =========================
  %% 8) Výstupy
  %% =========================
  subgraph OUT["Výstupy"]
    QA[QA_REPORT.md]
    CL[CHANGE_LOG.md]
    NS[NEXT_SESSION.md]
  end

  %% ---- vstupy do On Save
  V1 --> ONSAVE
  V2 --> ONSAVE

  WD --> OS_GUARD
  WS --> OS_GUARD
  GOV --> OS_GUARD
  ARCH --> OS_GUARD
  CON --> OS_GUARD

  %% ---- On Save pipeline (rychlé + idempotentní)
  OS_GUARD --> OS_META --> OS_VDM --> OS_DUP --> OS_DOCS
  OS_META --> OS_LOG
  OS_VDM --> OS_LOG
  OS_DUP --> OS_LOG
  OS_DOCS --> OS_LOG
  OS_DOCS --> QA
  OS_DOCS --> CL

  %% ---- Git hooky: commit/push
  V1 --> PC
  V2 --> PC

  %% ---- Pre-commit: jen kontrola, žádné přepisování souborů
  PC --> PRECOMMIT
  PC_GUARD --> PC_VDM --> PC_DUP --> PC_VC
  PC_VC --> PC_FAIL

  %% ---- Pre-push: test + NEXT_SESSION flow (bez cyklů)
  PP --> PREPUSH
  RT --> VNS --> ANS --> NSA

  %% ---- push -> CI
  PP --> GP --> GHA
  GHA --> ML
  GHA --> CI_DUP
  GHA --> CI_META
  GHA --> CI_TEST
```

## Závěr (co přesně změnit)

1. **Doplnit On Save vrstvu** mezi editací a hooky; tam patří auto-fix kroky (`update_*`).
2. **Pre-commit zjednodušit** na rychlé kontroly a ideálně *bez* změn souborů (jen fail s
instrukcí).
3. **Zavést gating podle změn** (aby `update_docs` neběželo zbytečně).
4. **Opravit tok NEXT_SESSION** na jednosměrný (validace → archivace → archiv), bez cyklu `ANS <->
NS`.
5. **CI zobrazit jako autoritativní paralelní joby** (MegaLinter není „nadřízený“ krokům, spíš
   souběžný job/step).
6. **Logování a audit připojit explicitně** ke krokům, které opravují nebo vynucují změny (ať
   `force-audit.log` není „sirotek“).
