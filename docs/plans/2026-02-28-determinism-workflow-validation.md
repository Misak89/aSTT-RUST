# Determinism Workflow Validation (2026-02-28)

## Scope

Validation and hardening of new CI workflows:

- `.github/workflows/determinism.yml`
- `.github/workflows/clean-clone-smoke.yml`

Goals:

1. Verify CI-like reproducibility (clean state, stale checks, deterministic regeneration).
2. Verify negative stale-check behavior (intentional drift must fail).
3. Remove false positives and unclear failure points found during local simulation.

## What Was Tested

Tests were run in an isolated clone snapshot (separate temp repository), not in the working tree.

### Baseline gates

- `scripts/validate_workflow_alignment.ps1`
- `scripts/validate_workflow_control_plane.ps1`
- `scripts/validate_workflow_control_alignment.ps1 -RefreshObserved`
- `scripts/generate_control_docs.ps1 -CheckOnly`
- `scripts/generate_verify_dashboard.ps1 -CheckOnly`
- `scripts/generate_workflow_control_diagrams.ps1 -CheckOnly`

### Determinism checks

Two consecutive regenerate passes were executed:

- `generate_control_docs.ps1 -SkipPreflightWriteGuard`
- `generate_verify_dashboard.ps1 -SkipPreflightWriteGuard`
- `generate_workflow_control_diagrams.ps1 -SkipPreflightWriteGuard`

Then SHA256 snapshots of `docs/generated/control/*` were compared between pass #1 and pass #2.

Result: hashes matched (deterministic output in tested environment).

### Negative stale-check

Intentional mutation:

- `docs_control/next_session.json` -> changed `document.updated_at`

Expected behavior:

- `generate_control_docs.ps1 -CheckOnly` must fail.

Result:

- stale-check failed as expected, then passed after restoring original JSON.

## Issues Found During Validation

1. `docs/spec-kit` may appear as dirty path (`git status`), while repo metadata
   may not support full submodule cleanup in all states.
1. `validate_workflow_control_alignment.ps1 -RefreshObserved` can refresh
   `docs_control/observed_workflow/*.json`, but failure was only visible later.

## Fixes Applied

1. **Robust clean-state checks in workflows**

- Added known-path ignore for `docs/spec-kit` in clean assertions (both workflows), so unrelated false-positive dirt does not mask real drift.

1. **Explicit manifest drift gate**

- Added immediate check after `-RefreshObserved`:
  - fail if `docs_control/observed_workflow/*.json` changed and are not committed.
  - gives direct, actionable failure cause.

1. **Workflow logic revalidated end-to-end**

- Sequence passes in CI-like isolated clone after above fixes.

## Remaining Limitation

Local validation cannot fully replace one real GitHub Actions run.

Still recommended:

1. Run both workflows once on a test branch in GitHub.
1. Mark them as required checks in branch protection.

## Branch Protection Required Checks (Full Workflow Coverage)

For stable branch protection, use this single check:

- `Project Unified / project-required-check`

The `determinism-required-check` job is an aggregator over the full matrix
(`ubuntu/windows x node20/22`), so one required check still enforces the whole determinism workflow.

`Project Unified` orchestrates:

- CI
- quality gate
- docs checks
- determinism
- clean-clone smoke
- sandbox docs checks (`sandbox/TestDocu_a001/**/*.md`)

Important: do not require checks from workflows with `paths` filters (e.g. `Documentation Check`),
because skipped workflows can block merges by never reporting a required status.
