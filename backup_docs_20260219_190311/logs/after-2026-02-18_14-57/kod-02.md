flowchart TB
    subgraph ŘídícíDokumentace["📋 ŘÍDÍCÍ DOKUMENTACE"]
        WD["workflow-steps.json<br>Konfigurace kroků"]
        WS["workflow-steps.schema.json<br>JSON Schema validace"]
        CON["CONSTITUTION.md<br>Pravidla projektu"]
        GOV["GOVERNANCE.md<br>Správa projektu"]
        ARCH["ARCHITECTURE.md<br>Architektura systému"]
    end

    subgraph IDE["💻 VS Code / Cursor"]
        VSC["Editor"]
        ROS["emeraldwalk.RunOnSave<br>Plugin pro automatické spouštění"]
        VSCS[".vscode/settings.json<br>Konfigurace Run on Save"]
        EXC["RunOnSave EXCLUDES<br>docs/**, QA_REPORT.md,<br>CHANGE_LOG.md, logs/**<br>+ write-only-if-changed"]
        PSH["Pozn.: PS1 skripty na macOS<br>přes pwsh PowerShell 7+<br>nebo přepsat do Python"]
    end

    subgraph RunOnSave["✅ RUN ON SAVE - VRSTVA po Ctrl+S"]
        R1["Detekce uložení Ctrl+S"]
        R2{"Typ souboru?"}
        R5["scripts/gen_docs.py --spec<br>pro .specify/*.md<br>PRIORITA 1"]
        R3["scripts/update_metadata.ps1<br>pro .md soubory<br>PRIORITA 2"]
        R4["scripts/gen_docs.py<br>pro kódové soubory<br>PRIORITA 3"]
    end

    subgraph Vývoj["🔧 VÝVOJ"]
        V1["Editace .rs .ts .svelte .py"]
        V2["Editace .md souborů"]
        V3["Editace .specify/*.md"]
    end

    subgraph OkamžitéVýstupy["✅ OKAMŽITÉ VÝSTUPY průběžně"]
        O1["Metadata aktualizována"]
        O2["Dokumentace generována"]
        O3["Specifikace synchronizována"]
    end

    subgraph GitHooks["🔗 GIT HOOKS"]
        PC[".husky/pre-commit<br>Fallback + Validace"]
        PP[".husky/pre-push"]
        GP["git push"]
    end

    subgraph WorkflowGuard["🛡️ WORKFLOW GUARD"]
        WG["scripts/workflow_guard.ps1<br>Řídící skript"]
    end

    subgraph PreCommitScripts["📜 PRE-COMMIT SKRIPITY"]
        UM["scripts/update_metadata.ps1<br>FALLBACK"]
        CD["scripts/check_duplicates.ps1"]
        VT["scripts/validate_timestamps.ps1"]
        VDM["scripts/validate_document_metadata.ps1"]
        UD["scripts/update_docs.ps1"]
        VC["scripts/validate_constitution.ps1"]
    end

    subgraph PrePushScripts["📜 PRE-PUSH SKRIPITY"]
        RT["cargo test<br>Rust testy"]
        VNS["scripts/validate_next_session.ps1"]
        ANS["scripts/archive_next_session.ps1"]
    end

    subgraph OpravnéSkripty["🔧 OPRAVNÉ SKRIPITY"]
        FCM1["scripts/fix_corrupted_metadata.ps1"]
        FCM2["scripts/fix_corrupted_metadata.py"]
        FDM["scripts/fix_document_metadata.ps1"]
        FD["scripts/fix_duplicates.ps1"]
    end

    subgraph PomocnéSkripty["⚙️ POMOCNÉ SKRIPITY"]
        GWD["scripts/generate_workflow_diagram.ps1"]
        SRP["scripts/setup_rust_path.ps1"]
    end

    subgraph Logování["📊 LOGOVÁNÍ"]
        EL["logs/execution-log.json<br>Log spuštění"]
        FA["logs/force-audit.log<br>Audit log"]
        RL["logs/runonsave.log<br>Log Run on Save"]
    end

    subgraph CI["☁️ CI/CD - GitHub Actions REMOTE"]
        GHA[".github/workflows/megalinter.yml"]
        ML[".mega-linter.yml<br>MegaLinter config"]
    end

    subgraph Výstupy["📄 VÝSTUPY"]
        QA["QA_REPORT.md"]
        CL["CHANGE_LOG.md"]
        NS["NEXT_SESSION.md"]
        NSA["NEXT_SESSION_Archive/"]
        DOCS["docs/<br>Generovaná dokumentace"]
    end

    WD --> WG
    WS --> WG
    CON --> VC
    VSCS --> ROS
    ROS --> EXC

    VSC --> V1
    VSC --> V2
    VSC --> V3

    V1 --> R1
    V2 --> R1
    V3 --> R1

    R1 --> R2
    R2 -->|".specify/*.md"| R5
    R2 -->|".md mimo .specify"| R3
    R2 -->|".rs .ts .svelte .py"| R4

    R3 --> RL
    R4 --> RL
    R5 --> RL

    R3 --> O1
    R4 --> O2
    R5 --> O3

    R4 --> DOCS
    R5 --> DOCS

    PC --> WG
    WG --> UM
    UM --> CD
    CD --> VT
    VT --> VDM
    VDM --> UD
    UD --> VC

    UM --> EL
    CD --> EL
    VT --> EL
    VDM --> EL
    UD --> EL
    VC --> EL

    VC --> PP
    PP --> RT
    RT --> VNS
    VNS --> ANS

    RT --> EL
    VNS --> EL
    ANS --> EL

    PP --> GP
    GP --> GHA
    GHA --> ML

    NS --> ANS
    ANS --> NSA

    UD --> QA
    UD --> CL

    FCM1 -.->|oprava| VDM
    FCM2 -.->|oprava| VDM
    FDM -.->|oprava| VDM
    FD -.->|oprava| CD

    style R1 fill:#90EE90
    style R2 fill:#90EE90
    style R3 fill:#90EE90
    style R4 fill:#90EE90
    style R5 fill:#90EE90
    style RL fill:#87CEEB
    style O1 fill:#90EE90
    style O2 fill:#90EE90
    style O3 fill:#90EE90
    style DOCS fill:#90EE90
    style EXC fill:#FFD700
    style WD fill:#FFD700
    style WS fill:#FFD700
    style CON fill:#FFD700
    style WG fill:#87CEEB
    style ROS fill:#90EE90
