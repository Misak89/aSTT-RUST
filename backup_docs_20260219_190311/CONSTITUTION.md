# CONSTITUTION

**Cesta:** CONSTITUTION.md
**Verze:** 1.3
**Vytvoreno:** 2026-02-15 19:28 (UTC+1)
**Posledni zmena:** 2026-02-19 09:39 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
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

## 7. Integrace a export

- Export musi byt opakovatelny a verzovany.
- API napojeni musi byt konfigurovatelne.
- Zpetna kompatibilita ma prednost, kde je to smysluplne.

## Canonical source

- Canonical zdroj pro Spec-Kit: `.specify/memory/constitution.md`.
