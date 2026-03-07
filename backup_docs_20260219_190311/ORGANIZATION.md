# Project Organization & Subordination

**Cesta:** ORGANIZATION.md
**Verze:** 1.1
**Vytvoreno:** 2026-02-16 12:23 (UTC+1)
**Posledni zmena:** 2026-02-17 (UTC+1)

## Historie zmen

| Datum | Verze | Popis zmeny |
|-------|-------|-------------|
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-17 | 1.1 | Automaticka aktualizace |
| 2026-02-16 | 1.0 | Pridana metadata |

## Stav

- [x] Metadata pridana
- [ ] Obsah dokumentu kompletni

---
This document visualizes the "Chain of Command" and absolute subordination for all project documentation and technical components.

## 🌳 Strom Podřízenosti (The Unified Hierarchy Tree)
Toto je "mapa moci" celého projektu. Každý prvek je podřízen úrovni nad ním.

```text
CONSTITUTION.md (Zákon projektu - NEJVYŠŠÍ DOGMATA)
└── VISION.md (Strategické cíle - CO CHCEME DOKÁZAT?)
    ├── .specify/spec.md (Požadavky - PŘESNÉ PARAMETRY SW)
    │   ├── ARCHITECTURE.md (Blueprint - STRUKTURA A MODULY)
    │   │   ├── src-tauri/ (Rust Backend - ŘÍDÍCÍ MOZEK)
    │   │   ├── src-ui/ (Svelte Frontend - ROZHRANÍ PRO LÉKAŘE)
    │   │   └── src-python/ (WhisperX Sidecar - ML PRACOVNÍ SÍLA)
    │   └── .specify/plan.md (Plán - TAKTIKA A TIMELINE)
    │       └── sandbox/ (Pískoviště - EXPERIMENTÁLNÍ VÝZKUM HW)
    ├── GOVERNANCE.md (Dozor - KDO NA TO DÁVÁ POZOR?)
    │   ├── documentation_analysis.md (Hlídač kvality textů)
    │   ├── Dangerfile.js (Hlídač pravidel vývoje)
    │   ├── .github/workflows/ (Hlídači v cloudu - CI/CD)
    │   └── scripts/update_docs.ps1 (ADC - MÍSTNÍ watchdog)
    └── INDEX.md (Rozcestník - MAPA PRO LIDI I STROJE)
        └── QA_REPORT.md (Stav projektu - AKTUÁLNÍ VÝSLEDKY)
```

## 👑 1. Documentation Hierarchy (Hierarchy of Truth)
This tree shows the subordination of documents. Higher-level documents dictate the content of lower-level ones.

```mermaid
graph TD
    Const["1. CONSTITUTION.md (Supreme Dogmas)"]
    Vision["2. VISION.md (Strategic Goals)"]
    Spec["3. .specify/spec.md (Functional Requirements)"]
    Plan["4. .specify/plan.md (Tactical Execution)"]
    Arch["5. ARCHITECTURE.md (Structural Blueprint)"]
    Gov["6. GOVERNANCE.md (Watchdog Rules)"]
    Report["7. QA_REPORT.md (Current System State)"]
    Code["8. Implementation (Code & Scripts)"]

    Const --> Vision
    Vision --> Spec
    Spec --> Plan
    Spec --> Arch
    Plan --> Code
    Arch --> Code
    Gov --> Report
    Code --> Report
    Gov -. Monitors .-> Code
    Gov -. Validates .-> Spec
```

## 🏗️ 2. Technology Hierarchy (Chain of Command)
This tree shows which technology controls or serves which component.

```mermaid
graph TD
    Tauri["Tauri Core (Rust Engine) - THE MASTER"]
    UI["Svelte Frontend (TypeScript) - THE INTERFACE"]
    Sidecar["Python Sidecar (Inference) - THE WORKER"]
    Whisper["WhisperX (AI Core)"]
    DocWatchdog["PowerShell (Doc Controller)"]
    GitHub["GitHub Actions (Continuous Tester)"]

    Tauri --> UI
    Tauri --> Sidecar
    Sidecar --> Whisper
    Tauri -. Orchestrates .-> DocWatchdog
    GitHub -. Verifies .-> Tauri
```

## 📊 3. Role Summary

| Layer | Component | Responsibility | Boss |
| :--- | :--- | :--- | :--- |
| **Strategy** | Constitution / Vision | Defines "Why" and "What not to do". | **The User** |
| **Tactics** | Specs / Plan | Defines "What" and "How". | Strategy |
| **Execution** | Rust / Python / UI | The actual software running on HW. | Tactics |
| **Verification**| Danger / CI / ADC | The Watchdogs ensuring compliance. | Tactics |

---

## 🔍 Verification
The **[GOVERNANCE.md](./GOVERNANCE.md)** document explains how the "Watchdogs" (Layer 4) verify that the "Execution" (Layer 3) stays aligned with the "Strategy" (Layer 1).
