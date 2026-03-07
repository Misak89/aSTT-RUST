# Refactor Batch C: Architecture & Organization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Clean up and align `ARCHITECTURE.md` and `ORGANIZATION.md` with the new SSOT structure and fix all high-severity lint errors.

**Architecture:** SSOT (Single Source of Truth) documentation as code.

**Tech Stack:** Markdown, Vale, markdownlint-cli2.

---

## Task 1: Refactor ARCHITECTURE.md

**Files:**
- Modify: `docs/core/ARCHITECTURE.md`

**Step 1: Update metadata and history**
Update version to 1.2, fix duplicate 1.1 entries in history.

**Step 2: Sync directory structure**
Update Section 5 (Directory Structure) to reflect correctly `docs/core/` and other moves.

**Step 3: Fix lint errors**
Fix capitalization in headings, line lengths (MD013) and quotes (Google.Quotes).

**Step 4: Verify**
Run: `.\.venv\Scripts\python.exe -m pre_commit run --files docs/core/ARCHITECTURE.md`
Expected: PASS or only warnings.

---

## Task 2: Refactor ORGANIZATION.md

**Files:**
- Modify: `docs/core/ORGANIZATION.md`

**Step 1: Update hierarchy trees**
Update Section 2 (Hierarchy Trees) to reflect the new paths (e.g., `docs/core/CONSTITUTION.md`).

**Step 2: Fix lint errors**
Fix capitalization in headings and quote punctuation.

**Step 3: Verify**
Run: `.\.venv\Scripts\python.exe -m pre_commit run --files docs/core/ORGANIZATION.md`
Expected: PASS or only warnings.

---

## Task 3: Final Verification & Commit

**Step 1: Run all checks**
Run: `.\.venv\Scripts\python.exe -m pre_commit run --all-files`

**Step 2: Build MkDocs**
Run: `.\.venv\Scripts\python.exe -m mkdocs build`
