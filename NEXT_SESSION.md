# Pokyny pro další Kilo Code Session

**Datum:** 2026-02-14
**Poslední aktualizace:** 16:34 (UTC+1)

---

## ✅ DOKONČENO (2026-02-14 16:33)

### Opravené duplicitní soubory:
| Soubor | Původní řádky | Opraveno na |
|--------|---------------|-------------|
| `src-tauri/src/rpc.rs` | 260 | 216 |
| `src-tauri/tests/rpc_contract_test.rs` | 443 | 148 |
| `CHANGE_LOG.md` | 74 | 38 |
| `NEXT_SESSION.md` | 162 | 81 |

### Další změny:
- Přidáno `pub mod rpc;` do `src-tauri/src/lib.rs`
- Opraven test `test_rpc_request_serialization` (ID assertion)
- **Všechny 15 cargo testů prošly**

---

## 📋 Další úkoly (Fáze 1: Core Prototype)

1. **Definovat JSON-RPC kontrakt** - Částečně hotovo (rpc.rs)
2. **Implementovat Rust-Python most** - Sidecar management
3. **Vytvořit Python sidecar** - WhisperX integration
4. **UI pro Start/Stop logiku** - Svelte frontend

---

## ⚠️ ZNÁMÝ BUG: Platformové nástroje

### Příznaky:
- `write_to_file` přidává obsah na konec místo nahrazení
- `search_and_replace` přidává duplicitní obsah

### Workarounds:
1. Používej `git restore` po každé chybě
2. Používej PowerShell skripty přes `execute_command`
3. Pro .rs soubory používej `edit_file` opatrně

---

## 🔧 Příkazy pro další session:

```powershell
# Spusť testy
cd src-tauri && C:\Users\adamf\.rustup\toolchains\stable-x86_64-pc-windows-msvc\bin\cargo.exe test

# Zkontroluj stav
git status

# Obnov soubor z Git (pokud je poškozen)
git restore <file>
```

---

## 📍 Aktuální stav projektu

- **Fáze 0: Portable Bench** - IN PROGRESS (validace HW)
- **Fáze 1: Core Prototype** - READY TO START
  - JSON-RPC kontrakt definován
  - Rust strana připravena
  - Čeká na Python sidecar implementaci
