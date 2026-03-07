# Deterministic Docs Concept Validation Strategy (Draft)

**Cesta:** plans/deterministic_docs_concept_validation_strategy_draft.md
**Verze:** 0.1
**Vytvoreno:** 2026-02-25 12:34 (UTC+1)
**Posledni zmena:** 2026-02-25 12:34 (UTC+1)
**Status:** DRAFT - NEOFICIALNI (prubezny dokument)

## Upozorneni

- Tento dokument je prubezny testovaci navrh.
- Neni SSOT.
- Slouzi k overeni funkčnosti konceptu pred sirsi implementaci.

## Ucel

- Oddelene otestovat, zda koncept "JSON ridici vrstva + generated MkDocs view" funguje.
- Najit slaba mista konceptu, chyby implementace a operacni rizika.
- Potvrdit (nebo vyvratit) provozni determinismus na pilotu `NEXT_SESSION`.

## Scope pilotu (P0)

- Jen `NEXT_SESSION` jako `P0 hybrid-strong`:
- ridici cast `100% JSON`
- kratka MD poznamka
- generated view pro MkDocs

## Testovaci vrstvy

### 1. Schema + canonicalization (unit)

- Valid schema -> PASS
- Invalid schema -> FAIL
- Canonicalization stabilni pri ruznem poradi klicu
- Kontrola timestamp/path formatu

### 2. Generator (golden snapshots)

- `next_session.json` + `next_session_note.md` -> `docs/generated/control/NEXT_SESSION.md`
- Porovnani proti golden snapshotu
- Deterministicka zmena view pri zmene vstupu

### 3. Validators (RED mutation tests)

Testovat umyslne rozbite scenare:

- neplatny prechod stavu
- chybejici evidence pri `IMPLEMENTED`
- neexistujici `evidence_id`
- stale generated view
- zakazany ridici obsah v MD note

### 4. Orchestrator (sequence / fail-fast)

- pevne poradi kroku
- fail-fast pri prvni kriticke chybe
- stejny vstup -> stejny exit code

### 5. MkDocs integrace

- `mkdocs build --strict`
- generated route existuje a je v nav
- lokalni HTTP 200 (pokud bezi server)

### 6. E2E replay (determinismus)

- stejny fixture snapshot spustit 2x
- porovnat hash generated artefaktu (s vyjimkou explicitne povolenych volatile poli)

## Failure Injection Matrix (minimalni P0)

| ID | Scenar | Ocekavany vysledek |
| :--- | :--- | :--- |
| RED-01 | Valid JSON + valid note + fresh generated view | PASS |
| RED-02 | JSON zmenen, generated view stary | FAIL |
| RED-03 | Neplatny prechod stavu | FAIL |
| RED-04 | Chybi evidence pro `IMPLEMENTED/HOTOVO` | FAIL |
| RED-05 | MD note obsahuje checklist/stavy | FAIL |
| RED-06 | Neexistujici `evidence_id` | FAIL |
| RED-07 | Broken MkDocs nav/link (`mkdocs build --strict`) | FAIL |
| RED-08 | Dva behy se stejnymi vstupy | Stejny hash / stejny vystup |

## Jak vyhodnocovat nalezy

### Typ A - Chyba implementace

- Specifikace je jasna, ale validator/generator/orchestrator dava spatny vysledek.

### Typ B - Slabe misto navrhu

- Pravidlo je nejednoznacne nebo nevynutitelne.

### Typ C - Slabe misto procesu

- Reseni je funkcni, ale neumerne narocne na rucni udrzbu.

### Typ D - Slabe misto operace

- Rozdilny vysledek lokal vs CI (verze, locale, cas, encoding).

## Metriky pro rozhodnuti "funguje / nefunguje"

- Zachyceni planovanych RED scenaru (kolik / kolik)
- False positives drift validatoru
- False negatives drift validatoru
- Cas behu pipeline lokalne a v CI
- Opakovatelnost replay testu (stabilita hashu)
- Srozumitelnost chybovych hlaseni (oprava bez manualniho dohledavani)

## Predbezne rizikove oblasti

- manualni udrzba traceability registru
- schema migration drift
- hranice JSON-owned vs MD-owned
- precedence `declared / observed_ci / observed_local`
- volatilni data (cas/cesty/locale/encoding)

## Vazba na hlavni draft

- Tento dokument rozpracovava testovaci cast navrhu:
- `plans/deterministic_docs_automation_plan_draft.md` (aktualne DRAFT 0.5)

## Historie zmen

| Datum | Verze | Popis zmeny |
| :--- | :--- | :--- |
| 2026-02-25 | 0.1 | Vytvoren prubezny navrh strategie validace konceptu + failure injection matrix |
