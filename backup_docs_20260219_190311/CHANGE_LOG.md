# Change Log - aSTT-RUST

**Cesta:** CHANGE_LOG.md
**Verze:** 1.1
**Vytvoreno:** 2026-02-15 19:28 (UTC+1)
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
## 2026-02-14

### 20:00 - WhisperX Integration Complete
- Implemented real WhisperX transcription in `src-python/sidecar.py`
- Tested on `jfk.wav` - JFK speech correctly transcribed
- Language detection: en (0.97 confidence)
- Word-level timestamps working
- All 15 Rust tests passing (JSON-RPC contract)

### 19:00 - Rust-Python Bridge Phase 1 Complete
- Fixed `use of moved value: rx` error in `src-tauri/src/sidecar.rs`
- Created dummy sidecar binary for Tauri build
- JSON-RPC 2.0 communication functional

### 16:33 - Duplicate Files Fixed
- Fixed: src-tauri/src/rpc.rs (removed duplicate content from line 217)
- Fixed: src-tauri/tests/rpc_contract_test.rs (removed duplicate content from line 149)
- Fixed: CHANGE_LOG.md (removed duplicate content from line 39)
- Fixed: NEXT_SESSION.md (removed duplicate content from line 82)
- Added: pub mod rpc; to src-tauri/src/lib.rs
- Fixed: test_rpc_request_serialization test (ID assertion)
- Result: All 15 cargo tests passing

### 12:25 - OneDrive Restarted
- OneDrive was stopped and disabled from startup
- OneDrive has been restored to original state

### 12:24 - File Duplication Issue Investigation
- Observed: Every use of write_to_file/search_and_replace adds duplicate content to files
- Hypothesis: Tool behavior issue, not OneDrive
- Files affected: src-tauri/src/lib.rs, src-tauri/tests/rpc_contract_test.rs

### 12:19 - OneDrive Investigation
- Attempted to stop OneDrive sync to fix file duplication
- Found OneDrive process: OneDrive.Sync.Service (PID 93876)
- Removed from Windows startup registry

### 12:00 - JSON-RPC Contract Creation
- Created src-tauri/src/rpc.rs with JSON-RPC 2.0 implementation
- Contains: RpcRequest, RpcResponse, RpcError, RpcMethod enums
- Contains: parse_response() function for filtering non-JSON output

### 11:58 - lib.rs Modification
- Added: mod rpc;
- Added: use rpc::{RpcRequest, RpcResponse, RpcMethod};
- Goal: Integrate RPC module with Tauri app

### 11:49 - RPC Contract Tests
- Created src-tauri/tests/rpc_contract_test.rs
- Contains 10 test cases for JSON-RPC contract verification

---

## Notes
- Current issue: File duplication when using write_to_file
- Next step: Investigate tool behavior or find alternative approach

