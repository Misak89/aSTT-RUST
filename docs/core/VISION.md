# VISION

**Cesta:** docs/core/VISION.md
**Verze:** 1.2
**Vytvoreno:** 2026-02-15 19:28 (UTC+1)
**Posledni zmena:** 2026-02-19 20:25 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
| :--- | :--- | :--- |
| 2026-02-19 | 1.2 | Refaktoring pro SSOT (docs/core) |
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-15 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [x] P0 obsah sjednocen
- [ ] P1 doplneni domenovych detailu

---

## Ucel produktu

`aSTT-RUST` ma zrychlit zpracovani mluvene komunikace do pouzitelneho
textu a navaznych vystupu.

## Primarni cilovi uzivatele

- Lekari a dalsi odbornici s vysokou casovou zatezi.
- Uzivatele, kteri potrebuji presny prepis a rychle navazne kroky.

## Hlavni hodnota

- Real-time prepis reci.
- Diarizace (rozliseni mluvcich).
- Navazne LLM zpracovani po kontrole textu.
- Export do dalsich systemu.

## Produktovy smer

- Local-first jako vychozi rezim.
- Modularni architektura, aby slo casti menit bez regresi.
- Auditovatelny provoz dokumentace i kodu.

## Funkcni oblasti

1. ASR modul (WhisperX a kompatibilni alternativy).
2. LLM modul (local i cloud provideri).
3. Konfigurace promptu, slovniku a kontextu.
4. API a exportni vrstva.
5. Nastaveni, uzivatele a bezpecnost.

## Kvalita a rizeni zmen

- Kazda vetsi zmena musi projit quality gate.
- Dokumentace musi odpovidat realnemu stavu kodu.
- Pred refactoringem dokumentace je povinna inventura SW.
