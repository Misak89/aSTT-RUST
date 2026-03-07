# Restart Context - STT Pilot a001 (Draft)

**Cesta:** sandbox/TestDocu_a001/RESTART_CONTEXT_STT_PILOT_a001.md
**Verze:** 0.1
**Vytvoreno:** 2026-02-25 13:47 (UTC+1)
**Posledni zmena:** 2026-02-25 13:47 (UTC+1)
**Status:** DRAFT - NEOFICIALNI (restart handoff)

## Ucel

- Kontext pro navazani po restartu kodovaciho SW.
- Fokus: testovaci STT projekt (WhisperX, CPU only) oddeleny od minulých pokusu.

## Co je uz ulozeno (relevantni drafty)

- `plans/deterministic_docs_automation_plan_draft.md` (`Verze 0.5`) - hlavni draft deterministicke dokumentacni automatizace
- `plans/deterministic_docs_concept_validation_strategy_draft.md` (`Verze 0.1`) - prubezny testovaci draft konceptu
- `sandbox/TestDocu_a001/deterministic_docs_automation_plan_draft__sandbox_copy.md` (`Verze 0.5`) - sandbox kopie hlavniho draftu

## Stav lokalni docs webu (MkDocs)

- MkDocs lokalni web byl funkcni (`http://127.0.0.1:8000/` -> HTTP 200) pri poslednim overeni.
- Byl zapnut user toggle light/dark v Material theme.
- Byl ztlumen text/logo v horni liste v dark mode (`docs/stylesheets/extra.css`).

## STT pilot - co uz bylo zjisteno (investigate before speculating)

### 1) Existujici predchozi pokus

- V repo uz existuje `sandbox/portable_bench/` (WhisperX CPU benchmark).
- Obsahuje:
- `demo.py`, `run_tests.py`, `verify_bench.py`, `test_samples.py`
- `sounddevice`, `whisperx`, `pyaudiowpatch`/WASAPI pokusy
- test reporty/logy

### 2) Interni audio bez mikrofonu (loopback)

- V predchozich logach je videt, ze loopback byl zkousen.
- Na testovanem stroji se objevil stav typu:
- loopback device nenalezen / doporuceno Stereo Mix
- Zaver: funkce muze byt podminena Windows audio konfiguraci (WASAPI loopback / Stereo Mix / virtual driver).

### 3) File-based STT

- To je standardni a nejmene rizikovy use-case pro pilot.
- WhisperX CPU + `ffmpeg` je pro audio/video soubor realisticky P0 cil.

### 4) Mic capture

- Predchozi benchmark uz ma mic recording pres `sounddevice` + nasledny WhisperX prepis.
- Lze znovu pouzit jako inspiraci, ale novy pilot ma byt oddeleny.

### 5) Jazyk (CS/EN)

- EN je standardni use-case.
- CS je realne podporitelna cesta (WhisperX alignment list obsahuje `cs` model), ale kvalitu je nutne otestovat na realnych datech.

## Doporucene umisteni noveho test projektu (oddeleni od starych pokusu)

- `sandbox/TestDocu_a001/stt_whisperx_cpu_pilot_a001/`

Duvod:
- jasne oddeleno od `sandbox/portable_bench/`
- drzi se sandbox testovaciho boxu `TestDocu_a001`
- pujde navazat dokumentaci a testy bokem bez zasahu do core

## Co uzivatel chce otestovat (zadani)

1. Interni zvuk bez mic (napr. bezi video) - pokud to neni prilis slozite
2. Zvuk z prolinkovaneho audio/video souboru
3. Zvuk z mikrofonu

Dalsi podminky:
- CPU only (bez CUDA)
- cestina, idealne i anglictina
- WhisperX reference:
- `https://github.com/m-bain/whisperX`
- `https://github.com/m-bain/whisperX/blob/main/README.md`
- `https://github.com/m-bain/whisperX/blob/main/EXAMPLES.md`

## Otevrene otazky od uzivatele (nutne k finalnimu planu)

1. Jaky OS a verze Windows (10/11)?
2. Co presne znamena "naprosto funkcni" (CLI only vs i jednoduche UI; vystup txt/json/srt)?
3. Interni audio:
- ma byt pozadovan WASAPI loopback bez dalsiho driveru?
- je prijatelny fallback (Stereo Mix / virtual audio cable)?
4. "Prolinkovany audio/video soubor":
- lokalni soubor, nebo URL?
- pokud URL: je povoleno `yt-dlp` + `ffmpeg`?
5. Mikrofon:
- batch (`record -> stop -> prepis`) nebo live prubezny prepis?
6. Jazyk:
- `cs` default + `en` volitelne, nebo `auto/cs/en`?
7. Rozsah WhisperX:
- STT + timestamps
- STT + alignment
- STT + alignment + diarizace (CPU narocnejsi)
8. Vykonnostni cil:
- funkcnost bez padu, nebo i casovy limit?
9. Co pripravit v dalsim kroku:
- jen DRAFT plan + dokumentaci + strukturu
- nebo i implementacni plan po fazich

## Doporuceny dalsi krok po restartu

1. Uzivatel odpovi na otevrene otazky 1-9.
2. Vytvorit DRAFT specifikaci a plan test projektu v:
- `sandbox/TestDocu_a001/stt_whisperx_cpu_pilot_a001/`
3. Teprve po schvaleni DRAFT zacit implementaci.

## Poznamka k determinismu (dulezite)

- LLM muze navrhovat plan a dokumentaci.
- Finalni stav test projektu ma menit az deterministicky orchestrator/testy/validatory.
- Pro pilot STT je vhodne od zacatku vest logy + test matrix oddelene od core SSOT.

## Historie zmen

| Datum | Verze | Popis zmeny |
| :--- | :--- | :--- |
| 2026-02-25 | 0.1 | Vytvoren restart handoff kontext pro STT pilot a001 (WhisperX CPU) |
