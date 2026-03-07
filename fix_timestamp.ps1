$content = @"
# Pokyny pro další Kilo Code Session

**Datum:** 2026-02-14T14:35:00Z  
**Předchozí stav:** Commit e9d34fe, 2b910a9
**Aktuální čas:** 2026-02-14T14:41:00Z

---

## 🔴 AKUTNÍ: Opravit duplicitní soubory

### Soubory s duplicitama (v Git):

| Soubor | Čas objevení | Problém | Řešení |
|--------|--------------|---------|--------|
| `src-tauri/src/rpc.rs` | 2026-02-14T12:34:00Z | 2× obsah (12768 B) | Smazat |
| `src-tauri/tests/rpc_contract_test.rs` | 2026-02-14T12:34:00Z | 2× obsah (14131 B) | Smazat |
| `CHANGE_LOG.md` | 2026-02-14T12:34:00Z | Možná duplicita | Zkontrolovat |

### Workaround:
```powershell
# Zkontroluj duplicity
Select-String -Path "src-tauri/src/rpc.rs" -Pattern "pub struct RpcRequest"

# Obnov z Git
git restore src-tauri/src/rpc.rs
```

---

## ✅ Hotovo (v commitu 2b910a9):

- **GOVERNANCE.md** - Přidány 4 skilly (2026-02-14T12:00:00Z)
- **INDEX.md** - Aktualizován datum

---

## ⚠️ ZNÁMÝ BUG (2026-02-14T12:00:00Z)

**Příznaky:**
- `write_to_file` přidává obsah na konec místo nahrazení
- `search_and_replace` přidává duplicitní obsah

**Důkazy:**
- `LOGS_AND_PROMPTS.md` - 3× obsah
- `PROMPT_HISTORY.md` - 2× obsah

**Workarounds:**
1. Používej `git restore` po každé chybě
2. Používej PowerShell přes `execute_command`

---

## 📋 Další úkoly (Spec-Kit):

1. Opravit duplicitní soubory
2. Definovat JSON-RPC kontrakt
3. Implementovat Rust-Python most
4. Spustit cargo test

---

## 🔧 Příkazy:

```bash
git status
git restore src-tauri/src/rpc.rs
```
"@

Set-Content -Path "NEXT_SESSION.md" -Value $content -NoNewline
Write-Host "Hotovo"
# Pokyny pro další Kilo Code Session

**Datum:** 2026-02-14T14:35:00Z  
**Předchozí stav:** Commit e9d34fe, 2b910a9
**Aktuální čas:** 2026-02-14T14:41:00Z

---

## 🔴 AKUTNÍ: Opravit duplicitní soubory

### Soubory s duplicitama (v Git):

| Soubor | Čas objevení | Problém | Řešení |
|--------|--------------|---------|--------|
| `src-tauri/src/rpc.rs` | 2026-02-14T12:34:00Z | 2× obsah (12768 B) | Smazat |
| `src-tauri/tests/rpc_contract_test.rs` | 2026-02-14T12:34:00Z | 2× obsah (14131 B) | Smazat |
| `CHANGE_LOG.md` | 2026-02-14T12:34:00Z | Možná duplicita | Zkontrolovat |

### Workaround:
```powershell
# Zkontroluj duplicity
Select-String -Path "src-tauri/src/rpc.rs" -Pattern "pub struct RpcRequest"

# Obnov z Git
git restore src-tauri/src/rpc.rs
```

---

## ✅ Hotovo (v commitu 2b910a9):

- **GOVERNANCE.md** - Přidány 4 skilly (2026-02-14T12:00:00Z)
- **INDEX.md** - Aktualizován datum

---

## ⚠️ ZNÁMÝ BUG (2026-02-14T12:00:00Z)

**Příznaky:**
- `write_to_file` přidává obsah na konec místo nahrazení
- `search_and_replace` přidává duplicitní obsah

**Důkazy:**
- `LOGS_AND_PROMPTS.md` - 3× obsah
- `PROMPT_HISTORY.md` - 2× obsah

**Workarounds:**
1. Používej `git restore` po každé chybě
2. Používej PowerShell přes `execute_command`

---

## 📋 Další úkoly (Spec-Kit):

1. Opravit duplicitní soubory
2. Definovat JSON-RPC kontrakt
3. Implementovat Rust-Python most
4. Spustit cargo test

---

## 🔧 Příkazy:

```bash
git status
git restore src-tauri/src/rpc.rs
```
"@

Set-Content -Path "NEXT_SESSION.md" -Value $content -NoNewline
Write-Host "Hotovo"

