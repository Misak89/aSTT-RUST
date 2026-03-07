# ISATM: AUDIT TRAIL & Log Dashboard

Tento dashboard slouží k interaktivnímu sledování a auditu synchronizace mezi kódem a dokumentací projektu `aSTT-RUST`.

## 🔄 Code-Doc Sync Flow

```mermaid
graph TD
    subgraph "Vývoj (Code)"
        C[Změna Kódu / Logic] --> |Trigger: Save/Push| S[update_docs.ps1]
    end
    
    subgraph "Audit & Docs"
        S --> |Update| M[Metadata & Metrics]
        S --> |Log| A[AUDIT_TRAIL_Log_dashboard.md]
        S --> |Verify| Q[QA_REPORT.md]
    end

    style A fill:#f9f,stroke:#333,stroke-width:4px
```

## 📋 Unified Traceability Matrix

| Timestamp | Kategorie | Funkce / Modul | Účel / Důvod Změny | Zdroj (Code) | Dokumentace (MD) | Stav | Důkaz |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| <!-- ROW_START --> | | | | | | | |
| 2026-02-20 13:55 | Prostredi | help.md | Historicky import | N/A | `help.md` | ✅ | `logs/runonsave.log` | 
| 2026-02-19 10:31 | Prostredi | NEXT_SESSION.md | Historicky import | N/A | [NEXT_SESSION.md](../generated/control/NEXT_SESSION.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:39 | Prostredi | NEXT_SESSION.md | Historicky import | N/A | [NEXT_SESSION.md](../generated/control/NEXT_SESSION.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:39 | Prostredi | VISION.md | Historicky import | N/A | [VISION.md](VISION.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:39 | Prostredi | CONSTITUTION.md | Historicky import | N/A | [CONSTITUTION.md](CONSTITUTION.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:35 | Prostredi | NEXT_SESSION.md | Historicky import | N/A | [NEXT_SESSION.md](../generated/control/NEXT_SESSION.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:35 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:33 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:33 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:28 | Prostredi | NEXT_SESSION.md | Historicky import | N/A | [NEXT_SESSION.md](../generated/control/NEXT_SESSION.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:27 | Prostredi | NEXT_SESSION-2026-02-17--14-44.md | Historicky import | N/A | `NEXT_SESSION_Archive/NEXT_SESSION-2026-02-17--14-44.md` | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:27 | Prostredi | NEXT_SESSION.md | Historicky import | N/A | [NEXT_SESSION.md](NEXT_SESSION.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:16 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:15 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:14 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:13 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:12 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:11 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:10 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:09 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:08 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | INDEX.md | Historicky import | N/A | [INDEX.md](index.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | GOVERNANCE.md | Historicky import | N/A | [GOVERNANCE.md](GOVERNANCE.md) | ✅ | `logs/runonsave.log` | 
| 2026-02-19 09:07 | Prostredi | inventory-refactor-playbook.md | Historicky import | N/A | [inventory-refactor-playbook.md](../inventory-refactor-playbook.md) | ✅ | `logs/runonsave.log` | 

---

## 👨‍🏫 Jak to funguje (Pro laiky)

Tento systém zajišťuje, že dokumentace nikdy "nezestárne". Kdykoliv programátor nebo AI změní kód, spustí se automatický hlídač (**skript**), který:
1. Zkontroluje, zda jsou všechny důležité soubory na svém místě.
2. Aktualizuje statistiky (počet souborů, stav testů).
3. Zapíše o tom záznam do této tabulky, abyste měli přehled o historii projektu.

**Technické detaily:**
- **Skript:** `scripts/update_docs.ps1`
- **Spuštění:** Automaticky při uložení nebo ručně přes terminál.

## 🚀 Možnosti rozšíření
- [ ] **Notifikace:** Zasílání upozornění na Slack/Discord při kritické chybě v dokumentaci.

- [ ] **Log Rotation:** Automatické odsouvání starých záznamů do archivu (`logs/archive/`).

- [ ] **PDF Export:** Generování měsíčních auditních reportů pro stakeholdery.

- [ ] **Git Hook Integration:** Blokování "push" do repozitáře, pokud dokumentace není synchronizovaná.

---
*Poslední aktualizace: 2026-02-20*
















































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































