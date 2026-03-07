# Logging + evidence claims

Generated from `docs_control/workflow_control_plane.json`.

- `view_id`: `view.logging_evidence_claims`
- `purpose`: Focused claim=evidence and evidence logging path around capability audit, preflight discovery,
  batch claim verification, traceability/session validators, and verify run logging.
- `counts`: actors=0, nodes=9
  artifacts=8, edges=18
- `must_cover_domains`: validate, log, evidence, traceability, manual_review

## Mermaid

```mermaid
%% Generated from docs_control/workflow_control_plane.json
%% view_id: view.logging_evidence_claims
flowchart LR
  node_verify_fast_orchestrator["verify_fast / verify_stage"]
  node_log_verify_run["log_verify_run"]
  node_validate_traceability(["validate_traceability"])
  node_validate_next_session(["validate_next_session JSON-first"])
  node_manual_review_freeze{"Manual review / freeze"}
  node_validate_capability_audit(["validate_capability_audit (tools + sources)"])
  node_preflight_state_discovery(["preflight_state_discovery (claim=evidence)"])
  node_verify_batch_status_claims(["verify_batch_status claims (claim=evidence)"])
  node_enforce_next_session_flow(["enforce_next_session_flow"])
  artifact_verify_runs_json[( "Verify Runs Evidence Log" )]
  artifact_task_status_json[( "Task Status Registry" )]
  artifact_capability_audit_json[( "Capability Audit Registry" )]
  artifact_capability_audit_schema[( "Capability Audit Schema" )]
  artifact_preflight_state_json[( "Preflight state snapshot" )]
  artifact_batch_status_verify_summary_json[( "Batch status verify summary" )]
  artifact_capability_audit_summary_json[( "Capability audit summary" )]
  artifact_toolchain_capabilities_json[( "Toolchain capability observations" )]
  node_verify_fast_orchestrator -->|on_fail / logs_to| node_log_verify_run
  node_verify_fast_orchestrator -->|on_skip / feeds| node_manual_review_freeze
  node_verify_fast_orchestrator -->|on_pass / logs_to| node_log_verify_run
  node_log_verify_run -->|always / writes| artifact_verify_runs_json
  node_verify_fast_orchestrator -->|on_pass / triggers| node_validate_traceability
  node_validate_traceability -->|on_pass / triggers| node_validate_next_session
  node_validate_capability_audit -->|always / writes| artifact_capability_audit_summary_json
  node_preflight_state_discovery -->|always / writes| artifact_preflight_state_json
  node_validate_capability_audit -->|always / writes| artifact_toolchain_capabilities_json
  node_preflight_state_discovery -->|on_pass / triggers| node_verify_batch_status_claims
  node_validate_capability_audit -->|on_pass / triggers| node_preflight_state_discovery
  node_verify_batch_status_claims -->|always / writes| artifact_batch_status_verify_summary_json
  node_verify_batch_status_claims -->|on_pass / triggers| node_validate_traceability
  node_validate_next_session -->|on_pass / triggers| node_enforce_next_session_flow
  node_preflight_state_discovery -->|always / reads| artifact_task_status_json
  node_verify_batch_status_claims -->|always / reads| artifact_task_status_json
  node_validate_capability_audit -->|always / reads| artifact_capability_audit_json
  node_validate_capability_audit -->|always / reads| artifact_capability_audit_schema
```

## Included nodes

- `node.verify_fast_orchestrator`: verify_fast / verify_stage
- `node.log_verify_run`: log_verify_run
- `node.validate_traceability`: validate_traceability
- `node.validate_next_session`: validate_next_session JSON-first
- `node.manual_review_freeze`: Manual review / freeze
- `node.validate_capability_audit`: validate_capability_audit (tools + sources)
- `node.preflight_state_discovery`: preflight_state_discovery (claim=evidence)
- `node.verify_batch_status_claims`: verify_batch_status claims (claim=evidence)
- `node.enforce_next_session_flow`: enforce_next_session_flow
