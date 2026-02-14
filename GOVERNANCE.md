# Project Governance: The Watchdog System

This document defines how the aSTT-RUST project ensures permanent quality, security, and integrity through automated "Watchdog" systems.

## 🛡️ Governance Matrix

| Pillíř | Watchdog (SW) | Mechanismus | Trigger | Zdroj pravdy |
| :--- | :--- | :--- | :--- | :--- |
| **Data Privacy** | **Danger JS** | Kontrola nepovolených síťových volání nebo porušení local-first pravidel. | Pull Request | [CONSTITUTION.md](./CONSTITUTION.md) |
| **Code Review** | **Review Workflow**| `/review`: Manuální/AI audit pro Spec-Kit a **Ralph Wiggum style**. | Pre-Commit / PR | [.agent/workflows/review.md](./.agent/workflows/review.md) |
| **Documentation** | **Autonomous Doc Controller** | `update_docs.ps1`: Verifikace cest, křížových odkazů a strojové čitelnosti. | Lokální | [INDEX.md](./INDEX.md) |
| **Code Integrity** | **GitHub CI** | `ci.yml`: Runs `cargo test` and `vitest` to prevent breaking changes. | Push / PR | [.specify/spec.md](./.specify/spec.md) |
| **Release Quality**| **Release-Please**| Automates CHANGELOG and versioning based on Conventional Commits. | Merge to Master | [package.json](./package.json) |
| **Doc Standards** | **MegaLinter** | Enforces Markdown formatting and link validity (preventing "rot"). | Push / PR | [documentation_analysis.md](./documentation_analysis.md) |
| **System Health** | **QA Report** | Aggregates all test logs into a machine-readable report. | Continuous | [QA_REPORT.md](./QA_REPORT.md) |

## 🕹️ Watchdog Responsibilities

### 1. Danger JS (The Policy Enforcer)
- **What it does**: Watches the *relationship* between code and documentation.
- **Example**: If I change `src-tauri/main.rs` but don't touch `.specify/spec.md`, Danger will block the PR.
- **Pillar**: Consistency and Privacy.

### 2. Autonomous Documentation Controller (The Local Watchdog)
- **What it does**: A PowerShell script (`update_docs.ps1`) that runs on the dev machine.
- **Example**: It checks if the Python Sidecar is reachable and if the required models are present in `sandbox/`.
- **Pillar**: Local Environment Health.

### 3. GitHub CI (The Permanent Tester)
- **What it does**: A cloud-based runner that compiles the project from scratch.
- **Example**: If a change works on my PC but fails on a clean environment, CI will catch it.
- **Pillar**: Cross-Platform Stability.

### 4. MegaLinter (The Quality Gate)
- **What it does**: Scans all 100+ document formats for errors.
- **Example**: Checks if all internal links in `ARCHITECTURE.md` are valid.
- **Pillar**: Documentation Professionalism.

### 5. Review Workflow (The Spec-Kit Guardian)
- **What it does**: Vynucuje **Nine Articles of Development** a **Ralph Wiggum style** (minimalismus, přímost, žádné „yapping“).
- **Pillar**: Architektonická integrita.

---

## 🔍 How to Verify?
To see the current status of all watchdogs, visit the **[QA_REPORT.md](./QA_REPORT.md)** or the **[GitHub Actions Tab](https://github.com/Misak89/aSTT-RUST/actions)**.

## 🤖 Agent Skills

| Skill | Description | Use Case |
| :--- | :--- | :--- |
| **Code Skeptic** | Critical analysis, bug investigation | Debugging, verifying claims |
| **Documentation Specialist** | Technical writing, markdown | README, ARCHITECTURE updates |
| **Test Engineer** | TDD, unit tests | Writing failing tests first |
| **Code Reviewer** | PR review, code quality | Pre-commit reviews