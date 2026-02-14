# NÁVRH OPRAV DOKUMENTACE

**Datum:** 2026-02-14
**Status:** ČEKÁ NA SCHVÁLENÍ

---

## SEZNAM CHYB K OPRAVĚ

### 1. Špatná cesta v ARCHITECTURE.md

| Lokace | Aktuální | Správně |
|--------|----------|----------|
| Řádek 24 | `src-python/` | Odstranit (neexistuje) |
| Řádek 68 | `tests/portable_bench/` | `sandbox/portable_bench/` |
| Řádek 78 | `src-python/` | Poznámka o odkladu |

**Proč:** Adresář `src-python/` nebyl vytvořen - Python sidecar je validován v sandboxu.

---

### 2. Špatná cesta v .specify/plan.md

| Lokace | Aktuální | Správně |
|--------|----------|----------|
| Řádek 23 | `tests/portable_bench/` | `sandbox/portable_bench/` |

---

### 3. Odkaz na neexistující soubor v GOVERNANCE.md

| Lokace | Aktuální | Status |
|--------|----------|--------|
| Řádek 10 | `.agent/workflows/review.md` | Neexistuje |

**Možnosti:**
- A) Vytvořit soubor
- B) Odebrat odkaz

---

### 4. Odkaz na neexistující soubor v CONSTITUTION.md

| Lokace | Aktuální | Status |
|--------|----------|--------|
| Řádek 72 | `.specify/memory/constitution.md` | Neexistuje |

**Možnosti:**
- A) Vytvořit adresář .specify/memory/ a přesunout CONSTITUTION.md
- B) Odebrat odkaz

---

## NAVRHOVANÉ ŘEŠENÍ

### Možnost A: Přesun s vysvětlením (Doporučeno)

Vytvořit nový dokument `ARCHIVED_REFERENCES.md` který bude obsahovat:
- Staré odkazy s vysvětlením proč už neplatí
- Nové správné odkazy

### Možnost B: Pouze opravit

Opravit každý odkaz individuálně bez vysvětlení.

---

## ČEKÁM NA SCHVÁLENÍ
**Datum:** 2026-02-14
**Status:** ČEKÁ NA SCHVÁLENÍ

---

## SEZNAM CHYB K OPRAVĚ

### 1. Špatná cesta v ARCHITECTURE.md

| Lokace | Aktuální | Správně |
|--------|----------|----------|
| Řádek 24 | `src-python/` | Odstranit (neexistuje) |
| Řádek 68 | `tests/portable_bench/` | `sandbox/portable_bench/` |
| Řádek 78 | `src-python/` | Poznámka o odkladu |

**Proč:** Adresář `src-python/` nebyl vytvořen - Python sidecar je validován v sandboxu.

---

### 2. Špatná cesta v .specify/plan.md

| Lokace | Aktuální | Správně |
|--------|----------|----------|
| Řádek 23 | `tests/portable_bench/` | `sandbox/portable_bench/` |

---

### 3. Odkaz na neexistující soubor v GOVERNANCE.md

| Lokace | Aktuální | Status |
|--------|----------|--------|
| Řádek 10 | `.agent/workflows/review.md` | Neexistuje |

**Možnosti:**
- A) Vytvořit soubor
- B) Odebrat odkaz

---

### 4. Odkaz na neexistující soubor v CONSTITUTION.md

| Lokace | Aktuální | Status |
|--------|----------|--------|
| Řádek 72 | `.specify/memory/constitution.md` | Neexistuje |

**Možnosti:**
- A) Vytvořit adresář .specify/memory/ a přesunout CONSTITUTION.md
- B) Odebrat odkaz

---

## NAVRHOVANÉ ŘEŠENÍ

### Možnost A: Přesun s vysvětlením (Doporučeno)

Vytvořit nový dokument `ARCHIVED_REFERENCES.md` který bude obsahovat:
- Staré odkazy s vysvětlením proč už neplatí
- Nové správné odkazy

### Možnost B: Pouze opravit

Opravit každý odkaz individuálně bez vysvětlení.

---

## ČEKÁM NA SCHVÁLENÍ
