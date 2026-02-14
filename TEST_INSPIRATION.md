# Testing Inspiration & Guidelines (Spec-Kit Article III & IX)

Tato příručka slouží jako inspirace pro implementaci testovací strategie v projektu **aSTT-RUST**, v souladu se zásadami **Spec-Kit**.

## 1. Test-First Imperative (Article III)
**Zásada:** Žádný kód bez testů. Testy musí být napsány dříve, než začne samotná implementace.

### Workflow: 
1. **Red Phase**: Napíšete test, který definuje očekávané chování (např. volání JSON-RPC metody). Spustíte ho a on selže.
2. **User Approval**: Ukážete test uživateli/agentovi k potvrzení, že chování je správné.
3. **Green Phase**: Napíšete minimální kód k tomu, aby test prošel.
4. **Refactor**: Optimalizujete kód při zachování funkčních testů.

---

## 2. Integration-First Testing (Article IX)
**Zásada:** Upřednostňujeme reálná prostředí před mockováním. Testujeme rozhraní mezi moduly.

### Klíčové oblasti:
- **Contract Testing (Pact/Custom)**: Ověření, že Rust (Tauri) a Python (Sidecar) mluví stejným jazykem (stejné JSON schéma).
- **USB Portable Sandbox**: Testování výkonu na CPU přímo v `sandbox/portable_bench/`.

---

## 3. Praktické příklady (Inspirace)

### A. Rust Contract Test (v `src-tauri/tests/contracts.rs`)
```rust
#[test]
fn test_sidecar_transcribe_schema() {
    let input = TranscribeRequest { audio_path: "test.wav".into() };
    let json_request = serde_json::to_string(&input).unwrap();
    
    // Očekáváme konkrétní strukturu JSON-RPC
    assert!(json_request.contains("\"method\":\"transcribe\""));
}
```

### B. Python Unit Test (v `src-python/tests/test_inference.py`)
```python
def test_whisperx_output_format():
    # Testujeme reálný výstup z knihovny na malém vzorku
    result = whisperx_wrapper.transcribe("sample.wav")
    assert "segments" in result
    assert "word_segments" in result # Důležité pro retroaktivní diarizaci
```

### C. Gherkin (Spec-Driven Example)
```gherkin
Feature: Retroactive Diarization
  Scenario: Speaker labels appear after a short delay
    Given the doctor is speaking
    When the audio segment is processed after 3 seconds
    Then the UI should update "Speaker 0" label for that text segment
```

---

## 4. Quality Gates
Každý nový "Library" modul musí projít těmito testy před sloučením (Merge):
- [ ] **Unit Tests** (pokrytí > 80 % kritické logiky)
- [ ] **Contract Tests** (mezi Rust a Python)
- [ ] **Hardware Bench** (ověření, že na CPU notebooku neběží inference déle než 1.5x délky audia)

---
*Tento dokument je živý a měl by být doplňován o konkrétní patterns podle postupu vývoje.*
