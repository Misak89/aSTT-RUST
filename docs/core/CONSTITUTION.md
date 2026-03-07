# CONSTITUTION

**Cesta:** docs/core/CONSTITUTION.md
**Verze:** 1.6
**Vytvoreno:** 2026-02-15 19:28 (UTC+1)
**Posledni zmena:** 2026-03-04 16:32 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
| :--- | :--- | :--- |
| 2026-03-04 | 1.6 | Doplnen zavazny runtime startup preflight a gate poradi Privacy->Security->Stability->UX->Portability |
| 2026-02-19 | 1.5 | Pridana Sekce 8.4: Negativni testovani (Proof of Test) |
| 2026-02-19 | 1.4 | Pridana Sekce 8: AI Directive & Workflow |
| 2026-02-19 | 1.3 | Run on Save |
| 2026-02-19 | 1.2 | P0 refactoring a sjednoceni s aktualnim procesem |
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-15 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [x] P0 obsah sjednocen
- [ ] P1 rozsireni detailu po modulech

---

## Ucel

Ustava definuje zavazna pravidla projektu `aSTT-RUST`.
Vsechny navrhy, implementace a dokumentace s ni musi byt v souladu.

## 1. Uzivatel a bezpeci na prvnim miste

- Priorita je bezpecnost, soukromi a spolehlivost.
- Cilem jsou klinicke scenare pouziti.
- Diarizace (rozliseni mluvcich) je zakladni pozadavek.
- Produktove rozhodovani ma pevne poradi: `Privacy -> Security -> Stability -> User comfort -> Portability`.
- Runtime startup preflight je povinny pred aktivaci recording/STT/online source funkci.

## 2. Modularita a rozhrani

- System je modularni.
- Moduly komunikuji pres jasna rozhrani.
- Vymena jedne casti nesmi rozbit celek.

## 3. Kvalita, testy a overitelnost

- Zmeny se musi dat otestovat.
- Kriticke cesty musi mit logovani.
- Zmeny rozhrani jsou kriticke a vyzaduji dokumentacni update.

## 4. Soukromi dat (health data)

- Citliva data nesmi odchazet bez vedomeho souhlasu uzivatele.
- Default ma byt konzervativni a local-first.
- Klice a pristupy se neukladaji v prostem textu.

## 5. Dokumentace jako ridici vrstva

- `VISION.md` a `CONSTITUTION.md` jsou ridici dokumenty.
- Zmena chovani musi mit odpovidajici zmenu dokumentace.
- Dokumentace se meni jen v overenem kontextu auditu.

## 6. Technicka smernice

- Primarni desktop stack: Windows a macOS.
- ASR referencne stoji na WhisperX.
- LLM musi podporit local i cloud variantu.
- Windows cil je portable no-install slozka; macOS cil je portable `.app` varianta s explicitnim uvedenim deployment omezeni (napr. podpis/notarizace), pokud jsou vyzadovana.

## 7. Integrace a export

- Export musi byt opakovatelny a verzovany.
- API napojeni musi byt konfigurovatelne.
- Zpetna kompatibilita ma prednost, kde je to smysluplne.

## 8. AI Agent Directive & Workflow

### 8.1. Striktni dodrzovani dokumentace

- Kazdy AI agent **musi** na zacatku session precist `VISION.md` a `CONSTITUTION.md`.
- Zmena kodu **nesmi** predbehnout zmenu dokumentace (SSOT).
- Agent nesmi ignorovat quality gate (Vale, markdownlint).

### 8.2. Spec-Driven Development (Spec-Kit)

- Projekt vyuziva metodiku `docs/spec-kit/spec-driven.md`.
- Kazda nova funkce musi mit svou specifikaci predtim, nez je implementovan kod.

### 8.3. Agentic Skills (Superpowers methodology)

- Vyvoj probiha v cyklech inspirovanych frameworkem `obra/superpowers`:
  1. **Brainstorm / Analyza:** Pochopeni pozadavku a kontextu.
  2. **Plan (ADR):** Zapis rozhodnuti do Log4brains.
  3. **Implement:** Psani kodu s durazem na TDD.
  4. **Verify:** Spusteni pre-commit kontrol a overeni proti specifikaci.

### 8.4. Negativni testovani (Proof of Test)

- Pro kazdy technicky ukol **musi** AI agent nejdriv ukazat, ze test **selhal** (RED).
- Toto slouzi jako objektivni dukaz, ze testovaci nastroj (linter, pytest) ma nad danym problemem skutecnou kontrolu.
- Bez dukazu o selhani (negative test) neni vysledek (GREEN) povazovan za duveryhodny.

## Canonical source

- Canonical zdroj pro tuto ustavu: `docs/core/CONSTITUTION.md`.
- Canonical zdroj metodiky Spec-Kit: `docs/spec-kit/spec-driven.md`.
