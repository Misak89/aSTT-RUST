# Pokyny pro další Kilo Code Session

**Datum:** 2026-02-14
**Předchozí stav:** Commitnuté změny e9d34fe

---

## 🔴 AKUTNÍ: Opravit duplicitní soubory

### Soubory s duplicitama (v Git - commit e9d34fe):

| Soubor | Problém | Řešení |
|--------|----------|---------|
| `src-tauri/src/rpc.rs` | 2× obsah (12768 bytes) | Smazat nebo opravit |
| `src-tauri/tests/rpc_contract_test.rs` | 2× obsah (14131 bytes) | Smazat nebo opravit |
| `CHANGE_LOG.md` | Možná duplicita | Zkontrolovat |

### Jak opravit (workaround):
```powershell
# Zkontroluj duplicity
Select-String -Path "src-tauri/src/rpc.rs" -Pattern "pub struct RpcRequest"

# Oprav přes PowerShell (zachovej pouze první polovinu)
$lines = Get-Content "src-tauri/src/rpc.rs"
$clean = $lines[0..(polovina-1)]
Set-Content "src-tauri/src/rpc.rs" $clean
```

---

## ✅ Hotovo (v commitu):

1. **GOVERNANCE.md** - Přidány 4 skilly:
   - Code Skeptic
   - Documentation Specialist  
   - Test Engineer
   - Code Reviewer

2. **INDEX.md** - Aktualizován datum

---

## ⚠️ ZNÁMÝ BUG: Platformové nástroje

### Příznaky:
- `write_to_file` přidává obsah na konec místo nahrazení
- `search_and_replace` přidává duplicitní obsah

### Důkazy (v Git historii):
- `LOGS_AND_PROMPTS.md` - 3× obsah
- `PROMPT_HISTORY.md` - 2× obsah  
- `GOVERNANCE.md` - opakovaně poškozeno

### Workarounds:
1. Používej `git restore` po každé chybě
2. Používej PowerShell skripty přes `execute_command`
3. Nepoužívej `write_to_file` ani `search_and_replace`

---

## 📋 Další úkoly (Spec-Kit):

1. Opravit duplicitní soubory
2. Definovat JSON-RPC kontrakt  
3. Implementovat Rust-Python most
4. Spustit cargo test

---

## 🔧 Příkazy pro další session:

```bash
# Zkontroluj stav
git status

# Zkontroluj duplicity  
powershell -Command "Select-String -Path 'src-tauri/src/rpc.rs' -Pattern 'pub struct RpcRequest'"

# Obnov soubor z Git (pokud je poškozen)
git restore src-tauri/src/rpc.rs
```

**Datum:** 2026-02-14
**Předchozí stav:** Commitnuté změny e9d34fe

---

## 🔴 AKUTNÍ: Opravit duplicitní soubory

### Soubory s duplicitama (v Git - commit e9d34fe):

| Soubor | Problém | Řešení |
|--------|----------|---------|
| `src-tauri/src/rpc.rs` | 2× obsah (12768 bytes) | Smazat nebo opravit |
| `src-tauri/tests/rpc_contract_test.rs` | 2× obsah (14131 bytes) | Smazat nebo opravit |
| `CHANGE_LOG.md` | Možná duplicita | Zkontrolovat |

### Jak opravit (workaround):
```powershell
# Zkontroluj duplicity
Select-String -Path "src-tauri/src/rpc.rs" -Pattern "pub struct RpcRequest"

# Oprav přes PowerShell (zachovej pouze první polovinu)
$lines = Get-Content "src-tauri/src/rpc.rs"
$clean = $lines[0..(polovina-1)]
Set-Content "src-tauri/src/rpc.rs" $clean
```

---

## ✅ Hotovo (v commitu):

1. **GOVERNANCE.md** - Přidány 4 skilly:
   - Code Skeptic
   - Documentation Specialist  
   - Test Engineer
   - Code Reviewer

2. **INDEX.md** - Aktualizován datum

---

## ⚠️ ZNÁMÝ BUG: Platformové nástroje

### Příznaky:
- `write_to_file` přidává obsah na konec místo nahrazení
- `search_and_replace` přidává duplicitní obsah

### Důkazy (v Git historii):
- `LOGS_AND_PROMPTS.md` - 3× obsah
- `PROMPT_HISTORY.md` - 2× obsah  
- `GOVERNANCE.md` - opakovaně poškozeno

### Workarounds:
1. Používej `git restore` po každé chybě
2. Používej PowerShell skripty přes `execute_command`
3. Nepoužívej `write_to_file` ani `search_and_replace`

---

## 📋 Další úkoly (Spec-Kit):

1. Opravit duplicitní soubory
2. Definovat JSON-RPC kontrakt  
3. Implementovat Rust-Python most
4. Spustit cargo test

---

## 🔧 Příkazy pro další session:

```bash
# Zkontroluj stav
git status

# Zkontroluj duplicity  
powershell -Command "Select-String -Path 'src-tauri/src/rpc.rs' -Pattern 'pub struct RpcRequest'"

# Obnov soubor z Git (pokud je poškozen)
git restore src-tauri/src/rpc.rs
```

