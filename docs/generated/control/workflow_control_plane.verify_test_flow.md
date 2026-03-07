# Verify + test flow

Generated from `docs_control/workflow_control_plane.json`.

- `view_id`: `view.verify_test_flow`
- `purpose`: Focused local verify runtime path from pre-commit into blocking docs/test checks and verify run
  logging, excluding CI fanout and backlog branches.
- `counts`: actors=1, nodes=11
  artifacts=1, edges=15
- `must_cover_domains`: hooks, validate, lint, test, log, evidence, manual_review

## Mermaid

```mermaid
%% Generated from docs_control/workflow_control_plane.json
%% view_id: view.verify_test_flow
flowchart LR
  actor_user{{"User"}}
  node_verify_fast_orchestrator["verify_fast / verify_stage"]
  node_log_verify_run["log_verify_run"]
  node_pre_commit_enforcement(["pre-commit enforcement"])
  node_markdownlint_blocking(["markdownlint blocking"])
  node_vale_blocking(["Vale blocking"])
  node_mkdocs_strict(["mkdocs build --strict"])
  node_manual_review_freeze{"Manual review / freeze"}
  node_link_audit_lychee(["Link audit (lychee, optional)"])
  node_node_check_svelte(["Node check (svelte-check)"])
  node_rust_fmt_check(["Rust fmt check"])
  node_rust_clippy(["Rust clippy"])
  artifact_verify_runs_json[( "Verify Runs Evidence Log" )]
  node_verify_fast_orchestrator -->|on_fail / logs_to| node_log_verify_run
  node_verify_fast_orchestrator -->|on_skip / feeds| node_manual_review_freeze
  node_verify_fast_orchestrator -->|on_pass / logs_to| node_log_verify_run
  node_log_verify_run -->|always / writes| artifact_verify_runs_json
  actor_user -->|if_changed / triggers| node_pre_commit_enforcement
  node_pre_commit_enforcement -->|on_pass / triggers| node_verify_fast_orchestrator
  node_markdownlint_blocking -->|on_pass / triggers| node_vale_blocking
  node_vale_blocking -->|on_pass / triggers| node_mkdocs_strict
  node_mkdocs_strict -->|on_pass / logs_to| node_log_verify_run
  node_link_audit_lychee -->|on_pass / triggers| node_mkdocs_strict
  node_link_audit_lychee -->|on_skip / triggers| node_mkdocs_strict
  node_mkdocs_strict -->|on_pass / triggers| node_node_check_svelte
  node_node_check_svelte -->|on_pass / triggers| node_rust_fmt_check
  node_rust_fmt_check -->|on_pass / triggers| node_rust_clippy
  node_rust_clippy -->|on_pass / logs_to| node_log_verify_run
```

## Included nodes

- `node.verify_fast_orchestrator`: verify_fast / verify_stage
- `node.log_verify_run`: log_verify_run
- `node.pre_commit_enforcement`: pre-commit enforcement
- `node.markdownlint_blocking`: markdownlint blocking
- `node.vale_blocking`: Vale blocking
- `node.mkdocs_strict`: mkdocs build --strict
- `node.manual_review_freeze`: Manual review / freeze
- `node.link_audit_lychee`: Link audit (lychee, optional)
- `node.node_check_svelte`: Node check (svelte-check)
- `node.rust_fmt_check`: Rust fmt check
- `node.rust_clippy`: Rust clippy
