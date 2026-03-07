flowchart TB
    subgraph ŘídícíDokumentace["📋 ŘÍDÍCÍ DOKUMENTACE"]
        WD[workflow-steps.json<br/>Konfigurace kroků]
        WS[workflow-steps.schema.json<br/>JSON Schema validace]
        CON[CONSTITUTION.md<br/>Pravidla projektu]
        GOV[GOVERNANCE.md<br/>Správa projektu]
        ARCH[ARCHITECTURE.md<br/>Architektura systému]
    end

    subgraph IDE["💻 VS Code / Cursor"]
        VSC[Editor]
    end

    subgraph Vývoj["🔧 VÝVOJ"]
        V1[Editace .rs .ts .svelte .py]
        V2[Editace .md souborů]
        V3[Editace .specify/*.md]
    end

    subgraph Problémy["❌ PROBLÉMY"]
        P1[Dokumentace NEAKTUALIZOVÁNA]
        P2[Metadata NEAKTUALIZOVÁNA]
        P3[Specifikace NESYNCHRONIZOVÁNA]
    end

    subgraph GitHooks["🔗 GIT HOOKS"]
        PC[.husky/pre-commit]
        PP[.husky/pre-push]
    end

    subgraph WorkflowGuard["🛡️ WORKFLOW GUARD"]
        WG[scripts/workflow_guard.ps1<br/>Řídící skript]
    end

    subgraph PreCommitScripts["📜 PRE-COMMIT SKRIPITY"]
        UM[scripts/update_metadata.ps1<br/>Aktualizace metadat]
        CD[scripts/check_duplicates.ps1<br/>Kontrola duplicit]
        VT[scripts/validate_timestamps.ps1<br/>Validace timestampů]
        VDM[scripts/validate_document_metadata.ps1<br/>Validace metadat dokumentů]
        UD[scripts/update_docs.ps1<br/>Aktualizace QA_REPORT.md]
        VC[scripts/validate_constitution.ps1<br/>Kontrola souladu]
    end

    subgraph PrePushScripts["📜 PRE-PUSH SKRIPITY"]
        RT[cargo test<br/>Rust testy]
        VNS[scripts/validate_next_session.ps1<br/>Validace NEXT_SESSION.md]
        ANS[scripts/archive_next_session.ps1<br/>Archivace NEXT_SESSION.md]
    end

    subgraph OpravnéSkripty["🔧 OPRAVNÉ SKRIPITY"]
        FCM1[scripts/fix_corrupted_metadata.ps1]
        FCM2[scripts/fix_corrupted_metadata.py]
        FDM[scripts/fix_document_metadata.ps1]
        FD[scripts/fix_duplicates.ps1]
    end

    subgraph PomocnéSkripty["⚙️ POMOCNÉ SKRIPITY"]
        GWD[scripts/generate_workflow_diagram.ps1]
        SRP[scripts/setup_rust_path.ps1]
    end

    subgraph Logování["📊 LOGOVÁNÍ"]
        EL[logs/execution-log.json<br/>Log spuštění]
        FA[logs/force-audit.log<br/>Audit log]
    end

    subgraph CI["☁️ CI/CD - GitHub Actions"]
        GHA[.github/workflows/megalinter.yml]
        ML[.mega-linter.yml<br/>MegaLinter config]
    end

    subgraph Výstupy["📄 VÝSTUPY"]
        QA[QA_REPORT.md]
        CL[CHANGE_LOG.md]
        NS[NEXT_SESSION.md]
        NSA[NEXT_SESSION_Archive/]
    end

    WD --> WG
    WS --> WG
    CON --> VC
    
    VSC --> V1
    VSC --> V2
    VSC --> V3
    
    V1 --> P1
    V2 --> P2
    V3 --> P3
    
    P1 --> PC
    P2 --> PC
    P3 --> PC
    
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
    ANS --> NSA
    
    UD --> QA
    UD --> CL
    ANS --> NS
    
    PP --> GHA
    GHA --> ML
    
    FCM1 -.->|oprava| VDM
    FCM2 -.->|oprava| VDM
    FDM -.->|oprava| VDM
    FD -.->|oprava| CD

    style P1 fill:#FFB6C1
    style P2 fill:#FFB6C1
    style P3 fill:#FFB6C1
    style WD fill:#FFD700
    style WS fill:#FFD700
    style CON fill:#FFD700
    style WG fill:#87CEEB
