flowchart TB
    subgraph Ridici_dokumentace
        WD[workflow-steps.json]
        WS[workflow-steps.schema.json]
        CON[CONSTITUTION.md]
        GOV[GOVERNANCE.md]
        ARCH[ARCHITECTURE.md]
    end

    subgraph Vyvoj
        V1[editace kodu]
        V2[editace dokumentace]
    end

    subgraph Git_hooks
        PC[.husky/pre-commit]
        PP[.husky/pre-push]
        GP[git push]
    end

    subgraph Workflow_guard
        WG[scripts/workflow_guard.ps1]
    end

    subgraph Pre_commit_kroky
        UM[scripts/update_metadata.ps1]
        CD[scripts/check_duplicates.ps1]
        VT[scripts/validate_timestamps.ps1]
        VDM[scripts/validate_document_metadata.ps1]
        UD[scripts/update_docs.ps1]
        VC[scripts/validate_constitution.ps1]
    end

    subgraph Pre_push_kroky
        RT[cargo test]
        VNS[scripts/validate_next_session.ps1]
        ANS[scripts/archive_next_session.ps1]
    end

    subgraph Logovani
        EL[logs/execution-log.json]
        FA[logs/force-audit.log]
    end

    subgraph CI_CD
        GHA[.github/workflows/megalinter.yml]
        ML[.mega-linter.yml]
        CDCHECK[scripts/check_duplicates.ps1]
        CDMETA[scripts/validate_document_metadata.ps1]
        CDRUST[cargo test]
    end

    subgraph Vystupy
        QA[QA_REPORT.md]
        CL[CHANGE_LOG.md]
        NS[NEXT_SESSION.md]
        NSA[NEXT_SESSION_Archive]
    end

    WD --> WG
    WS --> WG
    GOV --> WG
    ARCH --> WG
    CON --> VC

    V1 --> PC
    V2 --> PC

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

    NS --> ANS
    ANS --> NSA
    ANS --> NS

    UD --> QA
    UD --> CL

    PP --> GP
    GP --> GHA
    GHA --> ML
    GHA --> CDCHECK
    GHA --> CDMETA
    GHA --> CDRUST
