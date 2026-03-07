# Deterministic Docs Automation Plan (Draft)

**Cesta:** plans/deterministic_docs_automation_plan_draft.md
**Verze:** 0.6
**Vytvoreno:** 2026-02-25 07:21 (UTC+1)
**Posledni zmena:** 2026-02-25 20:37 (UTC+1)
**Status:** DRAFT - NEOFICIALNI (ceka na pripominky)

## Upozorneni

- Tento soubor je navrh.
- Neni SSOT.
- Po zapracovani pripominek muze byt povysen do `docs/core/`.

## Cile navrhu

- Definovat postup pro automaticky system rizeni aktualizace dokumentace.
- Zajistit, aby dokumentace prubezne zrcadlila kod, plany, cile, logy a testy.
- Udrzet proces operacne deterministicky i pri pouziti LLM (vibe coding).

## Co znamena "operacne deterministicky"

- LLM generuje navrhy (text/kod), ale neridi finalni stav projektu.
- Finalni rozhodnuti dela deterministicky orchestrator (skripty + hooks + CI + validatory).
- Stav `IMPLEMENTED/HOTOVO` je povolen jen po PASS dukazech.
- Stejne vstupy + stejne prostredi + stejny orchestrator => stejny vysledek gate.

## Terminologie (sjednoceni pojmu)

- `SSOT` = single source of truth (v dane vrstve / pro dany typ dat)
- `ridici vrstva` = strojove validovatelna data + pravidla + evidence
- `view` = Markdown/HTML zobrazeni ridicich dat (narativ / prezentace)
- `canonical` = autoritativni fyzicke umisteni source dat
- `generated` = odvozene artefakty vytvorene skriptem (nesmi se rucne editovat)
- `source_of_truth` (pole v JSON) = odkaz na deklarovany autoritativni soubor/pole

## Ridici vrstva: JSON jako source of truth (zpracovana pripominka)

- Ridici cast procesu ma byt strojove validovatelna a schema-driven.
- Markdown nema byt automaticky povazovan za source of truth.
- Rozhodnuty model (P0):
- JSON = ridici data (stav, vazby, pravidla, evidence)
- Markdown = view / narativ / vysvetleni (podle rizikovosti)

### Umisteni canonical JSON a publikace do MkDocs (rozhodnuti pro 0.4)

- `canonical` ridici JSON bude mimo `docs/` v `docs_control/`
- publikovane view pro MkDocs bude v `docs/generated/control/`
- MkDocs zobrazuje pouze `docs/generated/...` (view vrstva)
- `docs/generated/*` jsou generovane artefakty a nesmi se rucne upravovat

Prakticky model:
- `docs_control/*.json` = source of truth
- `scripts/generate_control_docs.*` = generator (`docs_control` -> `docs/generated/control`)
- `mkdocs.yml` nav = odkazuje na `docs/generated/control/*.md` (nebo raw JSON kopie)
- gate FAIL, pokud generated view neodpovida canonical JSON

### Co ma byt v JSON (ridici vrstva)

- Traceability registry: `spec -> plan -> task -> code_paths -> tests -> docs -> logs`
- Drift rules: povinne aktualizace docs/spec/plan pri zmene API/schema/config/workflow
- State machine: stavy, prechody, podminky, pozadovana PASS evidence
- Normalizovane artefakty: test/log/build reporty jako jednotne JSON vystupy
- Prompt governance metadata: verze sablony/policy, hash, vazba na evidence

### Verze a tooling v JSON (explicitne)

Terminologie:
- `runtime version` != `quality/development tooling version`
- priklad: `Python 3.x` je runtime, ale `pre-commit/ruff/nox` jsou Python tooling stack
- priklad: `TypeScript/Node` runtime/toolchain je oddeleny od `lefthook/commitlint` (workflow tooling)

Doporucene rozdeleni v JSON:
- `runtime_versions`
  - `python`
  - `node`
  - `rust`
  - `tauri`
  - `mkdocs`
- `quality_tooling_versions`
  - `python`: `pre_commit`, `ruff`, `nox`
  - `ts_js`: `lefthook`, `commitlint` (pripadne `eslint`, `prettier`)
  - `docs`: `markdownlint`, `vale`, `lychee`

Minimalni pozadavek pro determinismus:
- u kazde polozky ukladat nejen `version`, ale i `source_of_truth`
- priklad `source_of_truth`: `pyproject.toml`, `package.json`, `.pre-commit-config.yaml`, workflow file, lock file

### Precedence policy zdroju verzi (rozhodnuti pro 0.4)

Misto nejednoznacneho "A nebo B" se pouziji 3 vrstvy:

- `declared` = co repo deklaruje (config / lock / workflow)
- `observed_ci` = co realne bezelo v CI
- `observed_local` = co realne bezi lokalne

Rozhodovaci pravidla:

- `policy truth` = `declared`
- `gate truth` = `observed_ci` musi odpovidat `declared`
- `observed_local` = informacni (warning), nebo strict mode volitelne

Precedence poradi (pri hodnoceni):

- `declared_locked`
- `declared_unlocked`
- `observed_ci`
- `observed_local`

Pri konfliktu se verze "nehada", ale zapisuje se `mismatch` a validator vraci `FAIL`/`WARN` dle pravidla.

Priklad struktury (navrh):

```json
{
  "runtime_versions": {
    "python": {
      "declared": { "version": "3.11.x", "source_of_truth": ".github/workflows/*.yml" },
      "observed_ci": { "version": "3.11.x", "evidence_ref": "ci:job/runtime" },
      "observed_local": { "version": "3.11.x", "evidence_ref": "log:inventory/python" }
    },
    "node": {
      "declared": { "version": "20.x", "source_of_truth": ".github/workflows/*.yml" },
      "observed_ci": { "version": "20.x", "evidence_ref": "ci:job/runtime" }
    },
    "rust": {
      "declared": { "version": "stable", "source_of_truth": ".github/workflows/*.yml" },
      "observed_ci": { "version": "stable", "evidence_ref": "ci:job/runtime" }
    },
    "tauri": {
      "declared": { "version": "from package/cargo", "source_of_truth": "package.json + Cargo.toml" }
    },
    "mkdocs": {
      "declared": { "version": "locked/managed", "source_of_truth": "requirements/uv lock/pyproject" },
      "observed_local": { "version": "1.6.1", "evidence_ref": "log:inventory/mkdocs" }
    }
  },
  "quality_tooling_versions": {
    "python": {
      "pre_commit": { "version": "...", "source_of_truth": ".pre-commit-config.yaml" },
      "ruff": { "version": "...", "source_of_truth": "pyproject.toml" },
      "nox": { "version": "...", "source_of_truth": "pyproject.toml" }
    },
    "ts_js": {
      "lefthook": { "version": "...", "source_of_truth": "package.json" },
      "commitlint": { "version": "...", "source_of_truth": "package.json" }
    },
    "docs": {
      "markdownlint": { "version": "...", "source_of_truth": ".pre-commit-config.yaml" },
      "vale": { "version": "...", "source_of_truth": "tools/vale + CI workflow (split fields in real schema)" },
      "lychee": { "version": "...", "source_of_truth": ".pre-commit-config.yaml + CI workflow (split fields in real schema)" }
    }
  }
}
```

### Co neni nutne mit v JSON (nizke riziko driftu)

- `CHANGELOG.md` / `RELEASE_NOTES.md` (historicky narativ; staci format + konzistence)
- `FAQ.md` pouze pokud neobsahuje interni technicka tvrzeni
- `ADR/*.md` pouze jako odduvodneni rozhodnuti + odkazy na commit/PR/issue

### Co je rizikove (typicky driftuje) a nesmi byt "jen text"

- `README.md`
- `docs/core/ARCHITECTURE.md`
- `docs/core/GOVERNANCE.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `docs/core/NEXT_SESSION.md`

Pravidlo:
- bud presunout ridici casti do JSON a z MD udelat view,
- nebo zavest drift-validator navazany na Traceability Registry.

### Doporuceni pro `NEXT_SESSION.md`

- `P0 hybrid-strong` (rozhodnuti):
- ridici cast `NEXT_SESSION` bude 100% v JSON
- Markdown cast bude jen kratka, oddelena poznamka (narativ)
- MkDocs bude zobrazovat generovany view (JSON data + dole kratka MD poznamka)

Doporucena struktura:
- `docs_control/next_session.json` (canonical SSOT pro ridici cast)
- `docs_control/next_session_note.md` (kratka rucni poznamka; bez ridicich stavu)
- `docs/generated/control/NEXT_SESSION.md` (generovany view pro MkDocs)

Pravidla:
- V Markdown ponechat pouze poznamky, kontext a narrativ.
- Stavy, checklisty, gating pravidla a vazby na evidence presunout do JSON.
- `NEXT_SESSION.md` v docs vrstve vest jako view nad JSON daty (ne jako zdroj pravdy).
- Rucni edit ridicich poli v generated view je zakazan.

## Schema versioning a migrace (doplnene po kritickem hodnoceni)

- Kazdy canonical JSON musi mit `schema_version`.
- Zmeny schema musi mit migracni strategii:
- `backward-compatible` (minor)
- `breaking` (major + migracni skript)
- Validator musi hlasit:
- verzi schema
- podporovany rozsah verzi
- navrzeny migracni krok (pokud je znamy)

Minimalni soucasti:
- `traceability.schema.json`
- `state_machine.schema.json`
- `scripts/validate_*.ps1`
- `scripts/migrate_*.ps1` (pri breaking zmene)

## Traceability ID model a referencni integrita (doplnene po kritickem hodnoceni)

Kazda entita v traceability registru musi mit stabilni ID:

- `spec_id`
- `plan_id`
- `task_id`
- `code_ref_id`
- `test_id`
- `doc_id`
- `log_id`
- `evidence_id`

Pravidla integrity:

- vsechny reference musi smerovat na existujici ID (`referential integrity`)
- ID jsou immutable (nemenit zpetne; pri zmene vytvorit novou entitu / revizi)
- mutable jsou pouze stavove a observačni atributy (napr. status, evidence state)
- diff validator musi umet odlisit:
- legitimni evoluci entity
- neplatne prepsani identity

## Priority (navrh poradi)

### P0 - Nutne pro ridici dokumentaci (nejvyssi priorita)

1. Traceability registry (strojove citelny registr vazeb)
- mapovani: `spec -> plan -> task -> code_paths -> tests -> docs -> logs`
- format: preferovane `JSON` + schema
- pouziti pro drift-check a audit

2. Docs-vs-code drift validator
- overuje, ze klicova tvrzeni v docs odpovidaji realite v kodu/config/CI
- fail-fast pri nesouladu

3. Minimalni state machine (P0 kvuli `NEXT_SESSION`)
- formalni stavy a prechody pro ridici cast session
- PASS evidence jako podminka prechodu
- `NEXT_SESSION` ridici cast 100% JSON (`P0 hybrid-strong`)

4. Normalizovane artefakty testu a logu
- testy/logy primarne do JSON (stabilni schema)
- markdown reporty generovat z JSON (view vrstva)

5. Jeden orchestrator ("control plane" entrypoint)
- lokal + CI + agent spousti stejny skript a stejne poradi kroku
- bez paralelnich "tajnych" cest

6. Povinna gate pro docs build
- `mkdocs build --strict` jako povinna kontrola

7. JSON placement/publishing model
- canonical JSON v `docs_control/`
- generated view v `docs/generated/control/`
- generator + stale-check gate pro MkDocs

8. Precedence policy zdroju verzi
- `declared`, `observed_ci`, `observed_local`
- fail/warn pravidla pri mismatch

9. Minimalni bezpecna migrace ridici vrstvy do JSON (P0 postup)
- 1) `docs_control/traceability.json` + `traceability.schema.json`
- 2) `scripts/validate_traceability.*` + gate lokalne i v CI
- 3) teprve potom dalsi ridici casti (drift rules, state machine), vzdy se schematem + kanonizaci

10. Schema versioning + migrace + kanonizace
- `schema_version`, kompatibilita, migracni skripty, formatter

11. Traceability ID model + referencni integrita
- stabilni ID + immutable identita + integrity validator

### P1 - Stabilita a reprodukovatelnost

1. Rozsireny stavovy automat procesu
- rozsireni mimo `NEXT_SESSION` (globalni workflow / release / module-level stavy)
- prechody vynucene skriptem a navazane na traceability evidence

2. Deterministicke prostredi
- pinning verzi (Python/Node/Rust/MkDocs/plugins/linters)
- timezone/locale/encoding policy
- oddeleni runtime verzi vs quality tooling verzi v ridicich datech (JSON)

3. Prompt governance (verze + audit)
- verze prompt sablon
- hash promptu / ucel / vstupy / vystupy (s privacy pravidly)

### P2 - Rozsireni pro full autonomous vibe workflow

1. Auto-generovane dashboards z traceability registru
2. Evidence-based release gates (spec coverage, docs coverage, test coverage)
3. "What changed / what is stale" analyza pro dalsi session

## Checklist (prubezne odskrtavani)

### Faze 0 - Navrh a pripominky

- [x] Vytvoren navrh planu (draft mimo SSOT).
- [x] Zapracovat prvni sadu pripominek uzivatele (JSON ridici vrstva vs MD view).
- [x] Zapracovat kriticke hodnoceni (nalezy 1-8) do draftu 0.4.
- [ ] Schvalit, co bude povazovano za "deterministicke minimum" (P0 scope).
- [ ] Potvrdit seznam "rizikovych docs" a "nizkorizikovych docs" pro JSON migraci.
- [ ] Zafixovat terminologii pro finalni verzi (SSOT/ridici vrstva/view/canonical/generated).

### Faze 1 - Control plane zaklad

- [ ] Navrhnout schema traceability registru.
- [ ] Vytvorit validator schema + integrity check.
- [ ] Vytvorit prvni verzi drift validatoru (docs vs code/config/CI).
- [ ] Pridat `mkdocs build --strict` do lokalniho i CI gate.
- [ ] Definovat kanonizaci JSON (stabilni razeni klicu/format).
- [ ] Definovat JSON sekce `runtime_versions` a `quality_tooling_versions` + zdroje pravdy.
- [ ] Zafixovat JSON placement/publishing model (`docs_control` -> `docs/generated/control`).
- [ ] Zafixovat precedence policy (`declared` / `observed_ci` / `observed_local`).
- [ ] Dopsat `schema_version` + kompatibilitu + migracni pravidla.
- [ ] Definovat Traceability ID model + pravidla referencni integrity.
- [ ] Implementovat `NEXT_SESSION` P0 hybrid-strong (ridici cast 100% JSON + kratka MD poznamka).

### Faze 2 - Test/log ingestion

- [ ] Definovat jednotne JSON schema pro test artefakty.
- [ ] Definovat jednotne JSON schema pro log artefakty.
- [ ] Prevest report generovani na "JSON -> Markdown view".
- [ ] Pridat MkDocs zobrazeni JSON (raw view / build-time generated view).

### Faze 3 - Stavovy automat a governance enforcement

- [ ] Formalizovat minimalni stavy a prechody pro `NEXT_SESSION` do skriptu/validatoru (P0).
- [ ] Rozsirit stavovy automat na globalni workflow (P1).
- [ ] Zapsat pravidla do governance po schvaleni (ne drive).
- [ ] Napojit vse do hooks + CI + docs alignment checker.

### Faze 4 - Testovani konceptu (oddeleny pilot)

- [ ] Vytvorit pilot fixture jen pro `NEXT_SESSION` (`P0 hybrid-strong`).
- [ ] Dopsat schema/canonicalization unit testy.
- [ ] Dopsat generator snapshot (golden) testy.
- [ ] Dopsat validator mutation testy (RED scenare).
- [ ] Dopsat orchestrator sekvencni/fail-fast testy.
- [ ] Dopsat MkDocs integration test (`mkdocs build --strict` + route check).
- [ ] Dopsat E2E replay test (2 behy -> stejny hash/output mimo povolene volatile polozky).

## Acceptance criteria (navrh)

- Zmena v `code/config/workflow` vyvola deterministicky FAIL, pokud chybi odpovidajici update docs/spec/plan.
- Zmena v ridici docs vyvola FAIL, pokud neodpovida realnym skriptum/CI.
- Vsechny gate pouzivaji stejny orchestrator lokalne i v CI.
- Reporty jsou generovane z normalizovanych artefaktu (JSON), ne z manualnich poznamek.
- Stav `IMPLEMENTED/HOTOVO` nelze zapsat bez PASS evidence.
- Rizikove dokumenty nemaji ridici data pouze v Markdownu bez validace.
- JSON ridici data maji schema validator + kanonizaci.
- Runtime verze a quality tooling verze jsou oddelene a strojove dohledatelne ze zdroju pravdy.

### Executable acceptance criteria (P0 minimum)

- `scripts/validate_traceability.*` vraci `exit code 0` pouze pokud:
- JSON odpovida schema
- reference smeruji na existujici ID
- `schema_version` je podporovana
- `scripts/validate_docs_code_drift.*` vraci `exit code 0` pouze pokud:
- rizikove docs odpovidaji kodu/config/CI podle definovanych drift rules
- `scripts/generate_control_docs.*` + stale-check vrati `exit code 0` pouze pokud:
- `docs/generated/control/*` odpovida canonical JSON po kanonizaci
- `mkdocs build --strict` vrati `exit code 0`
- `NEXT_SESSION` validator vrati `exit code 0` pouze pokud:
- ridici cast je validni v JSON
- generated view je aktualni
- MD poznamka neobsahuje zakazane ridici sekce/pole

## Rizika a otevrene body

- "100% determinismus" LLM samotneho modelu neni realisticky; cil je deterministicky proces kolem LLM.
- Je potreba rozhodnout rozsah ukladani promptu (privacy, velikost logu, citlive udaje).
- Je potreba rozhodnout, co vsechno je SSOT vs co je report/view.
- `NEXT_SESSION` je rozhodnut jako `P0 hybrid-strong`; dodelat zbyva implementacni detaily generatoru/validatoru a napojeni gate.

## Zobrazeni JSON v MkDocs (prakticky pristup)

### Minimalni bezpecna varianta (doporučeno)

- JSON zustava source of truth.
- MkDocs zobrazuje JSON jako:
- "raw view" (pretty-print kodovy blok), nebo
- build-time generovany view (Markdown/HTML) z JSON.

### Co se vyhnout (v P0)

- Runtime nacitani JSON v prohlizeci s vlastni JS logikou pro ridici rozhodovani.
- Nedeterministicke transformace bez schema + formatteru.

## Test Strategy & Failure Injection Matrix (prubezny navrh pro 0.5)

### Cile testovani konceptu

- Overit, ze koncept je funkcni jako oddeleny pilot (bez globalni migrace).
- Zmerit, kde ma koncept slaba mista (navrh/proces) vs chyby implementace.
- Overit determinismus pipeline opakovanym behem.

### Testovat po vrstvach (oddelene)

1. Schema + canonicalization tests (unit)
- validni JSON -> PASS
- nevalidni JSON -> FAIL
- stejne hodnoty / jine poradi klicu -> po kanonizaci stejny vystup

2. Generator tests (golden snapshots)
- `next_session.json` + `next_session_note.md` -> `docs/generated/control/NEXT_SESSION.md`
- porovnani se snapshotem (golden file)
- zmena vstupu -> deterministicka zmena view

3. Validator tests (mutation / RED)
- umyslne rozbit vstup a overit spravny FAIL
- neplatny prechod stavu
- chybejici evidence
- stale generated view
- zakazane ridici sekce v MD poznamce
- neexistujici reference ID

4. Orchestrator tests (sequence / fail-fast)
- poradi kroku je pevne
- chyba v jednom kroku blokuje zmenu stavu
- stejny vstup vraci stejny exit code

5. MkDocs integration tests
- `mkdocs build --strict`
- generated route existuje a je v nav
- lokalni route vraci HTTP 200 (pokud server bezi)

6. E2E replay tests (duvera v determinismus)
- stejny fixture snapshot + 2 behy
- shodne artefakty/hash (krome explicitne povolenych volatile poli)

### Jak odlisit chybu vs slabe misto

- Chyba implementace:
- specifikace je jasna, ale kod/generator/validator dava spatny vysledek

- Slabe misto navrhu:
- pravidlo je nejednoznacne nebo nevynutitelne (napr. nejasna precedence zdroju)

- Slabe misto procesu:
- system je funkcni, ale provozne drahy / prilis rucni (napr. traceability maintenance)

- Slabe misto operace:
- lokal a CI davaji rozdilne vysledky kvuli prostredi/verzim/locale

### Pravdepodobna slaba mista (predbezna analyza)

- udrzba traceability registru (manualni stale mapy)
- schema evolution + migrace
- hranice JSON-owned vs MD-owned obsahu
- false positives drift validatoru
- rozdily `declared` vs `observed_ci` vs `observed_local`
- volatilni data (cas, cesty, locale, encoding)

### Minimalni P0 test matrix (navrh)

1. Valid JSON + valid note + fresh generated view -> PASS
2. JSON zmenen, generated view stary -> FAIL
3. Neplatny prechod stavu -> FAIL
4. Chybi evidence pro `IMPLEMENTED/HOTOVO` -> FAIL
5. MD note obsahuje zakazany checklist/stavy -> FAIL
6. Neexistujici `evidence_id` reference -> FAIL
7. `mkdocs build --strict` fail (broken nav/link) -> FAIL
8. Dva behy se stejnymi vstupy -> stejny hash generated view

### Metriky (pro rozhodnuti, zda koncept funguje)

- pocet RED scenaru zachycenych validatori (coverage proti planovanym scenarum)
- false positives / false negatives drift validatoru
- cas behu pipeline (lokal / CI)
- srozumitelnost chybovych hlaseni (opravitelnost bez manualniho dohledavani)
- stabilita replay testu (kolik opakovani bez rozdilu)

## Stav dokumentace strategie test/log/eval vs `ERROR LOOP` (doplneni 0.6)

### Co uz je v tomto draftu popsano

- testovaci strategie konceptu po vrstvach (schema/generator/validator/orchestrator/MkDocs/E2E replay)
- failure injection matrix a minimalni P0 test matrix
- metriky pro vyhodnoceni funkce konceptu
- princip deterministickeho orchestratoru a PASS evidence

### Co chybi proti pozadovanemu `ERROR LOOP`

- explicitni `verify_fast` vs `verify_full` kontrakt (nazvy, scope, poradi kroku)
- jednotny JSON log verify behu (`task_id`, `commit_sha`, `verify_status`, `errors`)
- deterministicky error clustering (`type + file + rule`) a `root_cause = first failing error`
- pravidlo "docs update az pri opakovani >= 3x" navazane na fingerprint historii
- MkDocs view pro "co proslo jakym testem a s jakym vysledkem" z canonical JSON (ne z volneho logu)
- asc/desc razeni jako build-time generovane view (bez krehke runtime JS logiky)

### P0 doplneni planu (minimalni implementace bez overengineeringu)

1. Zalozit canonical verify log v `docs_control/verify_runs.json` (+ schema)
- JSON jako SSOT pro verify vysledky (ne Markdown tabulka)
- pole pro `runs[]`, `errors[]`, `fingerprints[]`, `root_cause`

2. Pridat generator `JSON -> MkDocs view`
- `scripts/generate_verify_dashboard.ps1`
- vystupy do `docs/generated/control/`:
- `VERIFY_STATUS.md` (posledni stav po scope/stage)
- `VERIFY_RUNS_DESC.md` (globalni historie desc)
- `VERIFY_RUNS_ASC.md` (globalni historie asc)

3. Pridat minimalisticky logger verify behu
- `scripts/log_verify_run.ps1`
- umi zapsat `PASS/FAIL`, kroky, chyby a fingerprinty do canonical JSON
- bez parseru vsech nastroju v P0 (manual/skriptovy vstup je akceptovatelny)

4. Propojit MkDocs nav na generated verify view
- MkDocs zobrazuje generated MD, neprimy zapis do dashboardu
- `mkdocs build --strict` jako kontrola publikace

5. Dopsat navazujici P1 (az po P0)
- wrappery `verify_fast.ps1` / `verify_full.ps1`
- parsery stderr/stdout -> normalizovane `errors[]`
- pravidlo docs update pri opakovani fingerprintu >= 3x

### Deterministicka pravidla pro `ERROR LOOP` (P0/P1)

- `verify_fast` je source of truth pro rychly fail-fast; `verify_full` se spousti az po PASS `verify_fast`.
- `root_cause` = prvni chyba po deterministickem serazeni (stage order -> tool -> file -> rule -> line).
- fingerprint = stabilni hash normalizovaneho tuple (`type|file|rule`), bez volatilnich textu/casovych udaju.
- Markdown dashboard je pouze generated view; canonical stav je JSON.
- Razeni v MkDocs se resi build-time generovanim samostatnych stranek (`ASC`/`DESC`), ne runtime sortem.

## Odchylky od planu

- Zadne zatim (draft faze).

## Zapracovane body z kritickeho hodnoceni (0.4)

1. Konflikt canonical JSON vs MkDocs publikace
- doplnen `docs_control/` -> `docs/generated/control/` placement/publishing model + stale-check gate

2. Nejednoznacny `source_of_truth`
- doplnena precedence policy `declared / observed_ci / observed_local` + mismatch pravidla

3. `NEXT_SESSION` zavisly na state machine az v P1
- presunuty minimalni state machine do P0 (`P0 hybrid-strong`)

4. Drift v prikladu JSON (`tauri` chybel)
- opraven ukazkovy JSON o `tauri`

5. Nevykonatelne acceptance criteria
- doplnena sekce `Executable acceptance criteria (P0 minimum)` s validator/exit code logikou

6. Chybelo schema versioning + migrace
- doplnena sekce `Schema versioning a migrace`

7. Chybel ID model a referencni integrita
- doplnena sekce `Traceability ID model a referencni integrita`

8. Terminologicka nekonzistence
- doplnena sekce `Terminologie (sjednoceni pojmu)` + checklist bod pro finalizaci terminologie

## Historie zmen

| Datum | Verze | Popis zmeny |
| :--- | :--- | :--- |
| 2026-02-25 | 0.6 | Doplnen gap mezi test/log/eval strategii a `ERROR LOOP`; pridany P0/P1 kroky pro verify JSON log + MkDocs generated view + deterministicka pravidla |
| 2026-02-25 | 0.5 | Doplnena testovaci strategie konceptu, failure injection matrix a metriky; ulozen samostatny prubezny testovaci draft |
| 2026-02-25 | 0.4 | Zapracovano kriticke hodnoceni (1-8), rozhodnuti 0.4 (placement/publishing, precedence, schema/ID model), `NEXT_SESSION` jako P0 hybrid-strong |
| 2026-02-25 | 0.3 | Doplnene explicitni rozdeleni runtime_versions vs quality_tooling_versions (Python/TS/Docs tooling) |
| 2026-02-25 | 0.2 | Zapracovany pripominky: JSON ridici vrstva, rizikove docs, NEXT_SESSION jako view, minimalni migrace P0 |
| 2026-02-25 | 0.1 | Vytvoren navrh deterministickeho planu automatizace dokumentace (DRAFT) |
