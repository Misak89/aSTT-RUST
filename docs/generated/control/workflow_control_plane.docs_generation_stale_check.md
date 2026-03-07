# Docs generation + stale-check

Generated from `docs_control/workflow_control_plane.json`.

- `view_id`: `view.docs_generation_stale_check`
- `purpose`: Focused control-doc and diagram generation path, stale-check gates, docs-quality sequence, and
  non-blocking backlog reports.
- `counts`: actors=1, nodes=13
  artifacts=9, edges=28
- `must_cover_domains`: generate, docs_publish, validate, lint, exceptions_non_blocking

## Mermaid

```mermaid
%% Generated from docs_control/workflow_control_plane.json
%% view_id: view.docs_generation_stale_check
flowchart LR
  actor_user{{"User"}}
  node_verify_fast_orchestrator["verify_fast / verify_stage"]
  node_markdownlint_backlog(["markdownlint backlog"])
  node_markdownlint_blocking(["markdownlint blocking"])
  node_vale_blocking(["Vale blocking"])
  node_vale_backlog(["Vale backlog no-regression"])
  node_validate_next_session(["validate_next_session JSON-first"])
  node_generate_control_docs["generate_control_docs"]
  node_stale_check_control_docs(["stale-check control docs"])
  node_mkdocs_strict(["mkdocs build --strict"])
  node_enforce_next_session_flow(["enforce_next_session_flow"])
  node_workflow_control_diagrams_generator["generate_workflow_control_diagrams"]
  node_workflow_control_diagrams_stale_check(["workflow_control_diagrams stale-check"])
  node_link_audit_lychee(["Link audit (lychee, optional)"])
  artifact_generated_next_session_md[( "Generated NEXT_SESSION View" )]
  artifact_generated_traceability_md[( "Generated Traceability View" )]
  artifact_markdownlint_backlog_summary_json[( "Markdownlint backlog summary" )]
  artifact_vale_backlog_summary_json[( "Vale backlog summary" )]
  artifact_workflow_control_plane_full_md[( "Workflow control plane full view" )]
  artifact_workflow_control_plane_verify_md[( "Workflow control plane verify+evidence view" )]
  artifact_workflow_control_plane_full_mmd[( "Workflow control plane full Mermaid" )]
  artifact_workflow_control_plane_full_dot[( "Workflow control plane full DOT" )]
  artifact_workflow_control_plane_full_svg[( "Workflow control plane full SVG" )]
  node_verify_fast_orchestrator -->|always / feeds| node_markdownlint_backlog
  node_validate_next_session -->|on_pass / triggers| node_generate_control_docs
  node_generate_control_docs -->|on_pass / triggers| node_stale_check_control_docs
  node_stale_check_control_docs -->|on_pass / triggers| node_markdownlint_blocking
  node_markdownlint_blocking -->|on_pass / triggers| node_vale_blocking
  node_vale_blocking -->|on_pass / triggers| node_mkdocs_strict
  node_verify_fast_orchestrator -->|always / feeds| node_vale_backlog
  node_validate_next_session -->|on_pass / triggers| node_enforce_next_session_flow
  node_enforce_next_session_flow -->|on_pass / triggers| node_stale_check_control_docs
  actor_user -->|if_changed / triggers| node_generate_control_docs
  node_generate_control_docs -->|always / writes| artifact_generated_next_session_md
  node_generate_control_docs -->|always / writes| artifact_generated_traceability_md
  actor_user -->|if_changed / triggers| node_workflow_control_diagrams_generator
  node_workflow_control_diagrams_generator -->|always / writes| artifact_workflow_control_plane_full_mmd
  node_workflow_control_diagrams_generator -->|always / writes| artifact_workflow_control_plane_full_dot
  node_workflow_control_diagrams_generator -->|always / writes| artifact_workflow_control_plane_full_svg
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
```

## Included nodes

- `node.verify_fast_orchestrator`: verify_fast / verify_stage
- `node.markdownlint_backlog`: markdownlint backlog
- `node.markdownlint_blocking`: markdownlint blocking
- `node.vale_blocking`: Vale blocking
- `node.vale_backlog`: Vale backlog no-regression
- `node.validate_next_session`: validate_next_session JSON-first
- `node.generate_control_docs`: generate_control_docs
- `node.stale_check_control_docs`: stale-check control docs
- `node.mkdocs_strict`: mkdocs build --strict
- `node.enforce_next_session_flow`: enforce_next_session_flow
- `node.workflow_control_diagrams_generator`: generate_workflow_control_diagrams
- `node.workflow_control_diagrams_stale_check`: workflow_control_diagrams stale-check
- `node.link_audit_lychee`: Link audit (lychee, optional)
