# Pravidla projektu aSTT-RUST

**Cesta:** .kilocode\rules\rules.md
**Verze:** 1.1
**Vytvoreno:** 2026-02-15 04:59 (UTC+1)
**Posledni zmena:** 2026-02-17 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-15 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [ ] Obsah dokumentu kompletni

---
## Pravidla pro přepínání módu

- **VŽDY** se zeptej uživatele před přepnutím do jiného módu
- **NIKDY** nepoužívej `switch_mode` bez explicitního souhlasu uživatele
- Při potřebě přepnutí módu nejprve použij `ask_followup_question` s možností "Ano, přepni do [mód]" a "Ne, zůstaň v aktuálním módu"

## Pravidla pro úpravu kontextu

- **NEZHUSTUJ** kontext bez výslovného požadavku uživatele
- **VŽDY** zachovej kompletní informace při přenosu mezi sessions
- Při vytvoření nových session souborů používej plnou šablonu s:
  - Cílem
  - Aktuálním stavem
  - Rozhodnutími a důvody
  - Omezeními
  - Relevantními soubory
  - Otevřenými otázkami
  - Dalšími kroky s akceptačními kritérii

## Komunikace

- Preferuj češtinu pro komunikaci s uživatelem
- Vysvětluj své kroky před jejich provedením
- Pokud si nejsi jistý, zeptej se

---
*Vytvořeno: 2026-02-15 03:57 (UTC+1)*
