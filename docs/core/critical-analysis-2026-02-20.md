# Kriticka analyza - audit stavu projektu (2026-02-20)

## Scope
- Kontrolovan soubor `docs/core/NEXT_SESSION.md` proti realnemu stavu repozitare.
- Projity aktivni logy v `logs/` a relevantni test logy v `sandbox/portable_bench/`.
- Overena navaznost na skripty `scripts/backfill_audit.ps1`, `scripts/update_docs.ps1`, `scripts/validate_next_session.ps1`.

## Kriticka zjisteni
1. `docs/core/NEXT_SESSION.md` neni plne aktualni vuci stavu z 2026-02-20.
2. Existuji dva soubory s kontextem session (`docs/core/NEXT_SESSION.md` a root `NEXT_SESSION.md`) a obsahove si castecne odporuji.
3. `docs/core/AUDIT_TRAIL_Log_dashboard.md` je znecisteny hromadnym importem:
- obsahuje mnoho radku s absolutnimi Windows cestami,
- obsahuje opakovane duplicitni "Historicky import" zaznamy,
- stav je nekonzistentni pro MkDocs vykresleni.
4. Logy RunOnSave ukazuji nizkou aktualni aktivitu; watcher/guard PID soubory existuji, ale procesy aktualne nebyly bezici.
5. `scripts/validate_next_session.ps1` defaultne overuje root `NEXT_SESSION.md`, ne `docs/core/NEXT_SESSION.md`.

## Co rika aktualni logovy stav
1. `logs/software-audit-last.txt`: posledni audit snapshot byl OK (`Critical failed checks: 0`), ale je starsiho data.
2. `logs/software-inventory.json`: inventory snapshot je casove stejny jako audit a neni cerstvy k dnesnimu stavu.
3. `logs/runonsave.log`: posledni zaznam je zmena `help.md`; historicky import dashboardu zpusobil velke mnozstvi systemovych zaznamu.
4. `docs/core/AUDIT_TRAIL_Log_dashboard.md`: vysoky pocet radku "Historicky import" a absolutnich cest potvrzuje rozbitou import pipeline.
5. `sandbox/portable_bench/*.log`: starsi ASR testy jsou z velke casti PASS, ale nejsou zdrojem aktualniho stavu core dokumentace.

## Prioritni postup oprav (spravne poradi)
1. SSOT sjednoceni
- Potvrdit jediny kanonicky session soubor: `docs/core/NEXT_SESSION.md`.
- Root `NEXT_SESSION.md` prevest na kratky odkaz/redirect, nebo archivovat.

2. Oprava generatoru dashboardu
- Upravit `scripts/backfill_audit.ps1` a `scripts/update_docs.ps1`, aby generovaly pouze relativni cesty.
- Pridat deduplikaci (idempotentni import: stejny vstup = stejny vystup).

3. Jednorazovy rebuild dashboardu
- Vycistit `docs/core/AUDIT_TRAIL_Log_dashboard.md` od nevalidnich importu.
- Znovu vygenerovat jen validni historii.

4. Oprava validaci
- Upravit `scripts/validate_next_session.ps1` na `docs/core/NEXT_SESSION.md`.
- Pridat validaci dashboardu (zakaz absolutnich cest, kontrola duplicit).
- Pridat freshness kontrolu logu (`software-audit-last.txt`, `software-inventory.json`).

5. Zapojeni do gate
- Spoustet stejne validace lokalne i v CI.
- Zabranit merge, pokud dashboard nebo session dokument porusuji pravidla.

6. Provozni rad
- Dashboard neupravovat rucne, pouze skriptem.
- Kazdou session ukoncit aktualizaci jedineho SSOT dokumentu.
- Tydne kratky audit freshness + konzistence.

## Doporuceni k nastrojum
- Pro tento repozitar je vhodnejsi lehky interni skriptovy nastroj nez velky externi GitHub framework.
- Duvod: pravidla jsou projektove specificka (SSOT, ceske metadata, vazba na konkretni logy a Markdown struktury).
