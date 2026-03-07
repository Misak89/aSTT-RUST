# validate_workflow_alignment.ps1
# Kontrola souladu hooks + CI + docs pro JSON-first NEXT_SESSION / traceability workflow

param(
    [string]$RootPath = "."
)

$ErrorActionPreference = "Stop"
$errors = New-Object System.Collections.Generic.List[string]

function Read-File {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        $errors.Add("Missing file: $Path")
        return ""
    }
    return Get-Content $Path -Raw -Encoding UTF8
}

function Require-Match {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$ErrorMessage
    )
    if (-not ($Text -match $Pattern)) {
        $errors.Add($ErrorMessage)
    }
}

$preCommitPath = Join-Path $RootPath ".pre-commit-config.yaml"
$ciPath = Join-Path $RootPath ".github/workflows/ci.yml"
$qualityPath = Join-Path $RootPath ".github/workflows/quality-gate.yml"
$docsWorkflowPath = Join-Path $RootPath ".github/workflows/docs.yml"
$mkdocsPath = Join-Path $RootPath "mkdocs.yml"
$govPath = Join-Path $RootPath "docs/core/GOVERNANCE.md"
$nextPath = Join-Path $RootPath "docs/generated/control/NEXT_SESSION.md"
$verifyStagePath = Join-Path $RootPath "scripts/verify_stage.ps1"
$preflightGuardPath = Join-Path $RootPath "scripts/assert_preflight_write_guard.ps1"
$generateControlDocsPath = Join-Path $RootPath "scripts/generate_control_docs.ps1"
$generateWorkflowDiagramsPath = Join-Path $RootPath "scripts/generate_workflow_control_diagrams.ps1"
$generateVerifyDashboardPath = Join-Path $RootPath "scripts/generate_verify_dashboard.ps1"
$updateDocsPath = Join-Path $RootPath "scripts/update_docs.ps1"
$logVerifyRunPath = Join-Path $RootPath "scripts/log_verify_run.ps1"

$preCommit = Read-File -Path $preCommitPath
$ci = Read-File -Path $ciPath
$quality = Read-File -Path $qualityPath
$docsWorkflow = Read-File -Path $docsWorkflowPath
$mkdocs = Read-File -Path $mkdocsPath
$gov = Read-File -Path $govPath
$next = Read-File -Path $nextPath
$verifyStage = Read-File -Path $verifyStagePath
$preflightGuard = Read-File -Path $preflightGuardPath
$generateControlDocs = Read-File -Path $generateControlDocsPath
$generateWorkflowDiagrams = Read-File -Path $generateWorkflowDiagramsPath
$generateVerifyDashboard = Read-File -Path $generateVerifyDashboardPath
$updateDocs = Read-File -Path $updateDocsPath
$logVerifyRun = Read-File -Path $logVerifyRunPath

Require-Match -Text $preCommit -Pattern "id:\s*enforce-next-session-flow" -ErrorMessage "pre-commit: missing enforce-next-session-flow hook id."
Require-Match -Text $preCommit -Pattern "scripts/enforce_next_session_flow\.ps1" -ErrorMessage "pre-commit: missing scripts/enforce_next_session_flow.ps1 entry."
Require-Match -Text $preCommit -Pattern "docs_control/.+next_session" -ErrorMessage "pre-commit: NEXT_SESSION canonical JSON is not covered by local hook files pattern."
Require-Match -Text $preCommit -Pattern "docs_control/.+traceability" -ErrorMessage "pre-commit: traceability canonical JSON is not covered by local hook files pattern."
Require-Match -Text $preCommit -Pattern "docs_control/.+task_status" -ErrorMessage "pre-commit: task_status canonical JSON is not covered by local hook files pattern."
Require-Match -Text $preCommit -Pattern "id:\s*vale-critical" -ErrorMessage "pre-commit: missing vale-critical hook id."
Require-Match -Text $preCommit -Pattern "id:\s*vale(\r?\n|\s)" -ErrorMessage "pre-commit: missing changed-file vale hook id."
Require-Match -Text $preCommit -Pattern "preflight_state_discovery" -ErrorMessage "pre-commit: validate-workflow-alignment files pattern must include preflight_state_discovery."
Require-Match -Text $preCommit -Pattern "verify_batch_status" -ErrorMessage "pre-commit: validate-workflow-alignment files pattern must include verify_batch_status."
Require-Match -Text $preCommit -Pattern "capability_audit" -ErrorMessage "pre-commit: validate-workflow-alignment files pattern must include capability_audit SSOT/schema."
Require-Match -Text $preCommit -Pattern "workflow_control_plane" -ErrorMessage "pre-commit: validate-workflow-alignment files pattern must include workflow_control_plane SSOT/schema/note."
Require-Match -Text $preCommit -Pattern "validate_capability_audit" -ErrorMessage "pre-commit: validate-workflow-alignment files pattern must include validate_capability_audit script."
Require-Match -Text $preCommit -Pattern "validate_workflow_control_plane" -ErrorMessage "pre-commit: validate-workflow-alignment files pattern must include validate_workflow_control_plane script."
Require-Match -Text $preCommit -Pattern "validate_workflow_control_alignment" -ErrorMessage "pre-commit: validate-workflow-alignment files pattern must include validate_workflow_control_alignment script."
Require-Match -Text $preCommit -Pattern "generate_workflow_control_diagrams" -ErrorMessage "pre-commit: validate-workflow-alignment files pattern must include generate_workflow_control_diagrams script."
Require-Match -Text $preCommit -Pattern "assert_preflight_write_guard" -ErrorMessage "pre-commit: validate-workflow-alignment files pattern must include assert_preflight_write_guard script."

foreach ($pair in @(
        @{ Name = "ci.yml"; Text = $ci },
        @{ Name = "quality-gate.yml"; Text = $quality },
        @{ Name = "docs.yml"; Text = $docsWorkflow }
    )) {
    Require-Match -Text $pair.Text -Pattern "preflight_state_discovery\.ps1" -ErrorMessage "$($pair.Name): missing preflight_state_discovery.ps1."
    Require-Match -Text $pair.Text -Pattern "verify_batch_status\.ps1" -ErrorMessage "$($pair.Name): missing verify_batch_status.ps1."
    Require-Match -Text $pair.Text -Pattern "validate_capability_audit\.ps1" -ErrorMessage "$($pair.Name): missing validate_capability_audit.ps1."
    Require-Match -Text $pair.Text -Pattern "validate_traceability\.ps1" -ErrorMessage "$($pair.Name): missing validate_traceability.ps1."
    Require-Match -Text $pair.Text -Pattern "validate_next_session\.ps1" -ErrorMessage "$($pair.Name): missing validate_next_session.ps1."
    Require-Match -Text $pair.Text -Pattern "generate_control_docs\.ps1" -ErrorMessage "$($pair.Name): missing generate_control_docs.ps1 stale-check."
    Require-Match -Text $pair.Text -Pattern "generate_verify_dashboard\.ps1" -ErrorMessage "$($pair.Name): missing generate_verify_dashboard.ps1 stale-check."
    Require-Match -Text $pair.Text -Pattern "validate_workflow_control_plane\.ps1" -ErrorMessage "$($pair.Name): missing validate_workflow_control_plane.ps1."
    Require-Match -Text $pair.Text -Pattern "validate_workflow_control_alignment\.ps1" -ErrorMessage "$($pair.Name): missing validate_workflow_control_alignment.ps1."
    Require-Match -Text $pair.Text -Pattern "generate_workflow_control_diagrams\.ps1" -ErrorMessage "$($pair.Name): missing generate_workflow_control_diagrams.ps1 stale-check."
    Require-Match -Text $pair.Text -Pattern "enforce_next_session_flow\.ps1" -ErrorMessage "$($pair.Name): missing enforce_next_session_flow.ps1."
}

Require-Match -Text $verifyStage -Pattern "Preflight state discovery \(claim=evidence\)" -ErrorMessage "verify_stage.ps1: missing preflight state discovery step."
Require-Match -Text $verifyStage -Pattern "Verify batch status claims \(claim=evidence\)" -ErrorMessage "verify_stage.ps1: missing batch status verification step."
Require-Match -Text $verifyStage -Pattern "scripts\\preflight_state_discovery\.ps1" -ErrorMessage "verify_stage.ps1: missing scripts/preflight_state_discovery.ps1 invocation."
Require-Match -Text $verifyStage -Pattern "scripts\\verify_batch_status\.ps1" -ErrorMessage "verify_stage.ps1: missing scripts/verify_batch_status.ps1 invocation."
Require-Match -Text $verifyStage -Pattern "Validate workflow control plane model" -ErrorMessage "verify_stage.ps1: missing workflow control plane model validation step."
Require-Match -Text $verifyStage -Pattern "Validate workflow control alignment \(refresh observed\)" -ErrorMessage "verify_stage.ps1: missing workflow control alignment step."
Require-Match -Text $verifyStage -Pattern "Capability audit \(tools \+ sources\)" -ErrorMessage "verify_stage.ps1: missing capability audit step."
Require-Match -Text $verifyStage -Pattern "Workflow control diagrams stale-check" -ErrorMessage "verify_stage.ps1: missing workflow control diagrams stale-check step."
Require-Match -Text $verifyStage -Pattern "scripts\\validate_capability_audit\.ps1" -ErrorMessage "verify_stage.ps1: missing scripts/validate_capability_audit.ps1 invocation."
Require-Match -Text $verifyStage -Pattern "scripts\\validate_workflow_control_plane\.ps1" -ErrorMessage "verify_stage.ps1: missing scripts/validate_workflow_control_plane.ps1 invocation."
Require-Match -Text $verifyStage -Pattern "scripts\\validate_workflow_control_alignment\.ps1" -ErrorMessage "verify_stage.ps1: missing scripts/validate_workflow_control_alignment.ps1 invocation."
Require-Match -Text $verifyStage -Pattern "scripts\\generate_workflow_control_diagrams\.ps1" -ErrorMessage "verify_stage.ps1: missing scripts/generate_workflow_control_diagrams.ps1 invocation."

Require-Match -Text $mkdocs -Pattern "Next Session:\s*generated/control/NEXT_SESSION\.md" -ErrorMessage "mkdocs.yml: Next Session nav must point to generated/control/NEXT_SESSION.md."
Require-Match -Text $mkdocs -Pattern "Traceability Summary:\s*generated/control/TRACEABILITY_SUMMARY\.md" -ErrorMessage "mkdocs.yml: missing Traceability Summary generated page in nav."
Require-Match -Text $mkdocs -Pattern "Workflow Control Plane:\s*generated/control/WORKFLOW_CONTROL_PLANE\.md" -ErrorMessage "mkdocs.yml: missing Workflow Control Plane generated page in nav."
Require-Match -Text $mkdocs -Pattern "Workflow Verify\+Evidence View:\s*generated/control/workflow_control_plane\.verify_evidence_path\.md" -ErrorMessage "mkdocs.yml: missing workflow verify/evidence generated page in nav."

Require-Match -Text $gov -Pattern "Workflow enforcement \(hooks \+ CI \+ docs\)" -ErrorMessage "GOVERNANCE.md: missing Workflow enforcement section."
Require-Match -Text $gov -Pattern "drift.*blokujici chyba \(P0\)" -ErrorMessage "GOVERNANCE.md: missing P0 drift rule."
Require-Match -Text $gov -Pattern "docs_control/next_session\.json" -ErrorMessage "GOVERNANCE.md: missing canonical NEXT_SESSION JSON reference."
Require-Match -Text $gov -Pattern "Vale scope policy" -ErrorMessage "GOVERNANCE.md: missing Vale scope policy section."
Require-Match -Text $gov -Pattern "docs_control/vale_backlog_baseline\.json" -ErrorMessage "GOVERNANCE.md: missing Vale backlog baseline reference."
Require-Match -Text $gov -Pattern "Claim=evidence" -ErrorMessage "GOVERNANCE.md: missing claim=evidence governance section."
Require-Match -Text $gov -Pattern "Capability audit gate" -ErrorMessage "GOVERNANCE.md: missing capability audit governance section."
Require-Match -Text $gov -Pattern "docs_control/capability_audit\.json" -ErrorMessage "GOVERNANCE.md: missing capability audit SSOT reference."
Require-Match -Text $gov -Pattern "scripts/validate_capability_audit\.ps1" -ErrorMessage "GOVERNANCE.md: missing validate_capability_audit script reference."
Require-Match -Text $gov -Pattern "docs_control/task_status\.json" -ErrorMessage "GOVERNANCE.md: missing task_status registry reference."
Require-Match -Text $gov -Pattern "scripts/preflight_state_discovery\.ps1" -ErrorMessage "GOVERNANCE.md: missing preflight_state_discovery script reference."
Require-Match -Text $gov -Pattern "scripts/verify_batch_status\.ps1" -ErrorMessage "GOVERNANCE.md: missing verify_batch_status script reference."
Require-Match -Text $gov -Pattern "indexace/preflight\s*->\s*rozhodnuti\s*->\s*zmena" -ErrorMessage "GOVERNANCE.md: missing strict order rule (indexace/preflight -> rozhodnuti -> zmena)."
Require-Match -Text $gov -Pattern "assert_preflight_write_guard\.ps1" -ErrorMessage "GOVERNANCE.md: missing assert_preflight_write_guard script reference."
Require-Match -Text $gov -Pattern "workflow_control_plane\.json" -ErrorMessage "GOVERNANCE.md: missing workflow_control_plane JSON SSOT reference."
Require-Match -Text $gov -Pattern "generate_workflow_control_diagrams\.ps1" -ErrorMessage "GOVERNANCE.md: missing workflow control diagram generator reference."

Require-Match -Text $next -Pattern "Checkpoint \(workflow alignment\)" -ErrorMessage "Generated NEXT_SESSION view: missing workflow alignment checkpoint."
Require-Match -Text $next -Pattern "docs_control/next_session\.json" -ErrorMessage "Generated NEXT_SESSION view: missing source-of-truth marker."

Require-Match -Text $preflightGuard -Pattern "preflight_state\.json" -ErrorMessage "assert_preflight_write_guard.ps1: missing preflight_state.json requirement."
Require-Match -Text $preflightGuard -Pattern "batch_status_verify_summary\.json" -ErrorMessage "assert_preflight_write_guard.ps1: missing batch_status_verify_summary.json requirement."
Require-Match -Text $preflightGuard -Pattern "capability_audit_summary\.json" -ErrorMessage "assert_preflight_write_guard.ps1: missing capability_audit_summary.json requirement."
Require-Match -Text $preflightGuard -Pattern "observed_workflow\\verify_stage\.json" -ErrorMessage "assert_preflight_write_guard.ps1: missing observed verify_stage manifest requirement."
Require-Match -Text $preflightGuard -Pattern "Expected order: capability audit -> preflight -> batch verify" -ErrorMessage "assert_preflight_write_guard.ps1: missing strict order error message."

foreach ($scriptPair in @(
        @{ Name = "generate_control_docs.ps1"; Text = $generateControlDocs },
        @{ Name = "generate_workflow_control_diagrams.ps1"; Text = $generateWorkflowDiagrams },
        @{ Name = "generate_verify_dashboard.ps1"; Text = $generateVerifyDashboard },
        @{ Name = "update_docs.ps1"; Text = $updateDocs }
    )) {
    Require-Match -Text $scriptPair.Text -Pattern "assert_preflight_write_guard\.ps1" -ErrorMessage "$($scriptPair.Name): missing preflight write guard invocation."
    Require-Match -Text $scriptPair.Text -Pattern "SkipPreflightWriteGuard" -ErrorMessage "$($scriptPair.Name): missing explicit SkipPreflightWriteGuard override parameter."
}

Require-Match -Text $logVerifyRun -Pattern "generate_verify_dashboard\.ps1" -ErrorMessage "log_verify_run.ps1: missing generate_verify_dashboard invocation."
Require-Match -Text $logVerifyRun -Pattern "SkipPreflightWriteGuard" -ErrorMessage "log_verify_run.ps1: must pass -SkipPreflightWriteGuard to preserve evidence logging on early verify failures."

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "WORKFLOW ALIGNMENT FAILED" -ForegroundColor Red
    Write-Host "------------------------" -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host "- $e" -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "WORKFLOW ALIGNMENT PASSED" -ForegroundColor Green
exit 0
