# Pokyny pro dalsi Kilo Code Session

**Datum:** 2026-02-14
**Posledni aktualizace:** 18:08 (UTC+1)

---

## DOKONCENO (2026-02-14)

### Opravene duplicitni soubory:
| Soubor | Puvodni radky | Opraveno na |
|--------|---------------|-------------|
| `src-tauri/src/rpc.rs` | 260 | 216 |
| `src-tauri/tests/rpc_contract_test.rs` | 443 | 148 |
| `CHANGE_LOG.md` | 74 | 38 |
| `NEXT_SESSION.md` | 162 | 81 |

### Dalsi zmeny:
- Pridano `pub mod rpc;` do `src-tauri/src/lib.rs`
- Opraven test `test_rpc_request_serialization` (ID assertion)
- **Vsechny 15 cargo testu prosly**

### Nove skripty (2026-02-14 18:08):
- `scripts/check_duplicates.ps1` - Detekce duplicitnich radku
- `scripts/fix_duplicates.ps1` - Automaticka oprava duplicit
- `scripts/validate_timestamps.ps1` - Validace timestampu

---

## Dalsi ukoly (Faze 1: Core Prototype)

1. **Definovat JSON-RPC kontrakt** - Castecne hotovo (rpc.rs)
2. **Implementovat Rust-Python most** - Sidecar management
3. **Vytvorit Python sidecar** - WhisperX integration
4. **UI pro Start/Stop logiku** - Svelte frontend

---

## ZNAMY BUG: Platformove nastroje

### Priznaky:
- `write_to_file` pridava obsah na konec misto nahrazeni
- `search_and_replace` pridava duplicitni obsah

### Workarounds:
1. Pouzivej `git restore` po kazde chybe
2. Pouzivej PowerShell skripty pres `execute_command`
3. Pro .rs soubory pouzivej `edit_file` opatrne

---

## Prikazy pro dalsi session:

```powershell
# Spust testy
cd src-tauri && C:\Users\adamf\.rustup\toolchains\stable-x86_64-pc-windows-msvc\bin\cargo.exe test

# Zkontroluj stav
git status

# Obnov soubor z Git (pokud je poskozen)
git restore <file>

# Kontrola duplicit
powershell -ExecutionPolicy Bypass -File scripts/check_duplicates.ps1
```

---

## Aktualni stav projektu

- **Faze 0: Portable Bench** - IN PROGRESS (validace HW)
- **Faze 1: Core Prototype** - READY TO START
  - JSON-RPC kontrakt definovan
  - Rust strana pripravena
  - Ceka na Python sidecar implementaci

---

*Posledni aktualizace: 2026-02-14 18:08 (UTC+1)*
