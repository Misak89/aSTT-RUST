# Verify + evidence path

Generated from `docs_control/workflow_control_plane.json`.

- `view_id`: `view.verify_evidence_path`
- `purpose`: Focused path for governance/verify execution, claim=evidence guard, control docs + diagram
  stale-checks, backlog reports, and verify run logging.
- `counts`: actors=1, nodes=25
  artifacts=17, edges=54
- `must_cover_domains`: validate, lint, log, evidence, traceability, exceptions_non_blocking

## Mermaid

```mermaid
%% Generated from docs_control/workflow_control_plane.json
%% view_id: view.verify_evidence_path
flowchart LR
  actor_user{{"User"}}
  node_verify_fast_orchestrator["verify_fast / verify_stage"]
  node_log_verify_run["log_verify_run"]
  node_markdownlint_backlog(["markdownlint backlog"])
  node_markdownlint_blocking(["markdownlint blocking"])
  node_vale_blocking(["Vale blocking"])
  node_vale_backlog(["Vale backlog no-regression"])
  node_validate_traceability(["validate_traceability"])
  node_validate_next_session(["validate_next_session JSON-first"])
  node_generate_control_docs["generate_control_docs"]
  node_stale_check_control_docs(["stale-check control docs"])
  node_mkdocs_strict(["mkdocs build --strict"])
  node_manual_review_freeze{"Manual review / freeze"}
  node_validate_workflow_alignment(["validate_workflow_alignment"])
  node_validate_workflow_control_plane(["validate_workflow_control_plane"])
  node_extract_verify_stage_manifest["extract_verify_stage_manifest"]
  node_extract_ci_manifest["extract_ci_manifest"]
  node_extract_hooks_manifest["extract_hooks_manifest"]
  node_validate_workflow_control_alignment(["validate_workflow_control_alignment (refresh observed)"])
  node_validate_capability_audit(["validate_capability_audit (tools + sources)"])
  node_preflight_state_discovery(["preflight_state_discovery (claim=evidence)"])
  node_verify_batch_status_claims(["verify_batch_status claims (claim=evidence)"])
  node_enforce_next_session_flow(["enforce_next_session_flow"])
  node_workflow_control_diagrams_generator["generate_workflow_control_diagrams"]
  node_workflow_control_diagrams_stale_check(["workflow_control_diagrams stale-check"])
  node_link_audit_lychee(["Link audit (lychee, optional)"])
  artifact_workflow_control_plane_json[( "Workflow Control Plane SSOT" )]
  artifact_verify_runs_json[( "Verify Runs Evidence Log" )]
  artifact_traceability_json[( "Traceability Registry" )]
  artifact_next_session_json[( "NEXT_SESSION Canonical JSON" )]
  artifact_task_status_json[( "Task Status Registry" )]
  artifact_capability_audit_json[( "Capability Audit Registry" )]
  artifact_preflight_state_json[( "Preflight state snapshot" )]
  artifact_batch_status_verify_summary_json[( "Batch status verify summary" )]
  artifact_capability_audit_summary_json[( "Capability audit summary" )]
  artifact_toolchain_capabilities_json[( "Toolchain capability observations" )]
  artifact_markdownlint_backlog_summary_json[( "Markdownlint backlog summary" )]
  artifact_vale_backlog_summary_json[( "Vale backlog summary" )]
  artifact_observed_verify_stage_manifest[( "Observed verify_stage manifest" )]
  artifact_observed_ci_jobs_manifest[( "Observed CI jobs manifest" )]
  artifact_observed_hooks_manifest[( "Observed pre-commit hooks manifest" )]
  artifact_workflow_control_plane_full_md[( "Workflow control plane full view" )]
  artifact_workflow_control_plane_verify_md[( "Workflow control plane verify+evidence view" )]
  node_verify_fast_orchestrator -->|on_fail / logs_to| node_log_verify_run
  node_verify_fast_orchestrator -->|always / feeds| node_markdownlint_backlog
  node_verify_fast_orchestrator -->|on_skip / feeds| node_manual_review_freeze
  node_verify_fast_orchestrator -->|on_pass / logs_to| node_log_verify_run
  node_log_verify_run -->|always / writes| artifact_verify_runs_json
  node_verify_fast_orchestrator -->|on_pass / triggers| node_validate_traceability
  node_validate_traceability -->|on_pass / triggers| node_validate_next_session
  node_validate_next_session -->|on_pass / triggers| node_generate_control_docs
  node_generate_control_docs -->|on_pass / triggers| node_stale_check_control_docs
  node_stale_check_control_docs -->|on_pass / triggers| node_markdownlint_blocking
  node_markdownlint_blocking -->|on_pass / triggers| node_vale_blocking
  node_vale_blocking -->|on_pass / triggers| node_mkdocs_strict
  node_mkdocs_strict -->|on_pass / logs_to| node_log_verify_run
  node_verify_fast_orchestrator -->|always / feeds| node_vale_backlog
  node_verify_fast_orchestrator -->|on_pass / triggers| node_validate_workflow_alignment
  node_validate_workflow_alignment -->|on_pass / triggers| node_validate_workflow_control_plane
  node_validate_workflow_control_plane -->|on_pass / triggers| node_extract_verify_stage_manifest
  node_extract_verify_stage_manifest -->|always / writes| artifact_observed_verify_stage_manifest
  node_extract_verify_stage_manifest -->|on_pass / triggers| node_extract_ci_manifest
  node_extract_ci_manifest -->|always / writes| artifact_observed_ci_jobs_manifest
  node_extract_ci_manifest -->|on_pass / triggers| node_extract_hooks_manifest
  node_extract_hooks_manifest -->|always / writes| artifact_observed_hooks_manifest
  node_extract_hooks_manifest -->|on_pass / triggers| node_validate_workflow_control_alignment
  node_validate_workflow_control_alignment -->|on_pass / triggers| node_validate_capability_audit
  node_validate_capability_audit -->|always / writes| artifact_capability_audit_summary_json
  node_preflight_state_discovery -->|always / writes| artifact_preflight_state_json
  node_validate_capability_audit -->|always / writes| artifact_toolchain_capabilities_json
  node_preflight_state_discovery -->|on_pass / triggers| node_verify_batch_status_claims
  node_validate_capability_audit -->|on_pass / triggers| node_preflight_state_discovery
  node_verify_batch_status_claims -->|always / writes| artifact_batch_status_verify_summary_json
  node_verify_batch_status_claims -->|on_pass / triggers| node_validate_traceability
  node_validate_next_session -->|on_pass / triggers| node_enforce_next_session_flow
  node_enforce_next_session_flow -->|on_pass / triggers| node_stale_check_control_docs
  actor_user -->|if_changed / triggers| node_generate_control_docs
  actor_user -->|if_changed / triggers| node_workflow_control_diagrams_generator
  node_workflow_control_diagrams_generator -->|always / writes| artifact_workflow_control_plane_full_md
  node_workflow_control_diagrams_generator -->|always / writes| artifact_workflow_control_plane_verify_md
  node_stale_check_control_docs -->|on_pass / triggers| node_workflow_control_diagrams_stale_check
  node_workflow_control_diagrams_generator -->|on_pass / triggers| node_workflow_control_diagrams_stale_check
  node_workflow_control_diagrams_stale_check -->|on_pass / triggers| node_markdownlint_blocking
  node_markdownlint_backlog -->|always / writes| artifact_markdownlint_backlog_summary_json
  node_markdownlint_blocking -->|on_pass / feeds| node_markdownlint_backlog
  node_markdownlint_backlog -->|always / feeds| node_vale_blocking
  node_vale_backlog -->|always / writes| artifact_vale_backlog_summary_json
  node_vale_backlog -->|always / feeds| node_link_audit_lychee
  node_link_audit_lychee -->|on_pass / triggers| node_mkdocs_strict
  node_link_audit_lychee -->|on_skip / triggers| node_mkdocs_strict
  node_preflight_state_discovery -->|always / reads| artifact_task_status_json
  node_verify_batch_status_claims -->|always / reads| artifact_task_status_json
  node_validate_capability_audit -->|always / reads| artifact_capability_audit_json
  node_validate_workflow_control_plane -->|always / reads| artifact_workflow_control_plane_json
  node_validate_workflow_control_alignment -->|always / reads| artifact_observed_verify_stage_manifest
  node_validate_workflow_control_alignment -->|always / reads| artifact_observed_ci_jobs_manifest
  node_validate_workflow_control_alignment -->|always / reads| artifact_observed_hooks_manifest
```

## Included nodes

- `node.verify_fast_orchestrator`: verify_fast / verify_stage
- `node.log_verify_run`: log_verify_run
- `node.markdownlint_backlog`: markdownlint backlog
- `node.markdownlint_blocking`: markdownlint blocking
- `node.vale_blocking`: Vale blocking
- `node.vale_backlog`: Vale backlog no-regression
- `node.validate_traceability`: validate_traceability
- `node.validate_next_session`: validate_next_session JSON-first
- `node.generate_control_docs`: generate_control_docs
- `node.stale_check_control_docs`: stale-check control docs
- `node.mkdocs_strict`: mkdocs build --strict
- `node.manual_review_freeze`: Manual review / freeze
- `node.validate_workflow_alignment`: validate_workflow_alignment
- `node.validate_workflow_control_plane`: validate_workflow_control_plane
- `node.extract_verify_stage_manifest`: extract_verify_stage_manifest
- `node.extract_ci_manifest`: extract_ci_manifest
- `node.extract_hooks_manifest`: extract_hooks_manifest
- `node.validate_workflow_control_alignment`: validate_workflow_control_alignment (refresh observed)
- `node.validate_capability_audit`: validate_capability_audit (tools + sources)
- `node.preflight_state_discovery`: preflight_state_discovery (claim=evidence)
- `node.verify_batch_status_claims`: verify_batch_status claims (claim=evidence)
- `node.enforce_next_session_flow`: enforce_next_session_flow
- `node.workflow_control_diagrams_generator`: generate_workflow_control_diagrams
- `node.workflow_control_diagrams_stale_check`: workflow_control_diagrams stale-check
- `node.link_audit_lychee`: Link audit (lychee, optional)
