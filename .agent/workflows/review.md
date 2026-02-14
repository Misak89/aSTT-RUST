---
description: Review pending Git changes as a senior engineer, ensuring Spec-Kit compliance and release safety.
---

# aSTT-RUST Spec-Driven Code Review

Review pending Git changes as a senior software engineer for the **aSTT-RUST** project. 
This workflow strictly enforces the **Project Constitution** and the **Nine Articles of Development (Spec-Kit)**.

## Steps

### 1. Get Pending Changes

```bash
git status
git diff --stat
```

If no pending changes exist, inform the user and stop.

**Filter the results:** Focus on:
- Rust (`.rs`)
- Python (`.py`)
- Svelte/TypeScript (`.svelte`, `.ts`)
- Config/Specs (`.md`, `project.json`, `tauri.conf.json`)

Ignore: `logs/`, `target/`, `node_modules/`, `.venv/`.

### 2. Analyze Each Changed File

For each code/spec file in pending changes:
1. **Read the current file content**
2. **Read the diff** to see specifically what changed:
```bash
git diff <filepath>
```

### 3. Conduct the Review (The Spec-Kit Gates)

Review all changes against these criteria:

#### A. Spec-Kit Compliance (NON-NEGOTIABLE)
- [ ] **Spec Alignment**: Do the changes fulfill a requirement in `.specify/spec.md`? Are they reflected in `.specify/plan.md`?
- [ ] **Article I (Library-First)**: Is the new logic encapsulated in a standalone library (`src-python/` or `src-tauri/libs/`)?
- [ ] **Article III (Test-First)**: Do tests accompany the implementation? If this is the initial phase, are the tests confirmed to FAIL (Red phase)?
- [ ] **Article II (CLI Interface)**: If the Python sidecar was changed, is it still functional as a standalone CLI?

#### B. IPC & Schema Integrity
- [ ] **JSON-RPC Contract**: If parameters changed, are both Rust (`Serde`) and Python (`Pydantic`) schemas updated?
- [ ] **Strictness**: Is all communication through the sidecar strictly JSON-RPC over stdio?

#### C. Performance & Security (Article IX)
- [ ] **CPU/RAM Gate**: Will this change impact our goal to run on 4-5 year old office notebooks (CPU-only)?
- [ ] **Privacy**: Is there any risk of sensitive physician/patient data leaking outside the local machine?
- [ ] **Secrets**: Check for API keys or credentials in plaintext.

#### D. Data Compatibility (CRITICAL)
- [ ] **Breaking changes** to local SQLite schema or JSON config structures?
- [ ] **Migration required?** Will existing user settings or transcripts be corrupted?

#### E. Code Quality (SOLID/DRY)
- [ ] **SOLID**: Does each new module have a single responsibility?
- [ ] **Clean Swiss Style**: Does UI code follow the high-contrast, distraction-free aesthetic?

---

### 4. Provide Feedback

Present your findings in this format:

```md
## Code Review Summary (Spec-Kit Compliance)

**Files Reviewed:**
- [filepath] (added/modified/deleted)

**Overall Assessment:** ✅ Approved / ⚠️ Approved with Comments / ❌ Needs Changes (Spec Violation)

### Findings

#### 🔴 Critical Issues (Spec-Kit / Security)
- [Issue description with reference to specific Article I-IX or Spec FR-XX]

#### ⚠️ Coordination Required
- [Changes to IPC Schemas, Data migrations, or Documentation updates needed]

#### 🟡 Suggestions & DX
- [Performance optimizations or maintainability improvements]

#### 🟢 Best Practices Observed
- [Modular design, TDD follow-through, etc.]

### Commit Recommendation
**Title:** <imperative verb> <what changed> (e.g., "Refactor: extract asr library per Art. I")
**Description:**
- Traces back to Spec requirement: [FR-XX]
- Test status: [Pass/Fail/Pending]
```

### 5. Implementation Policy
- **Never auto-commit.** Always wait for human approval.
- **Spec Violations are BLOCKERS.** If code deviates from `spec.md` without an update to the spec, do not approve.
- **Hardware limit is a BLOCKER.** If a change requires an NVIDIA GPU where CPU was expected, flag as CRITICAL.

---
**Version**: 1.0 (Spec-Kit Integrated) | **Status**: Active
