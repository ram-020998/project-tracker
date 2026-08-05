# Genesis — Repository Structure

The Genesis repos + shared packages, all **built + shipped**: `genesis` (platform) + `genesis-workflows` (library) +
`genesis-core` (engine/SDK) + `kiro-agent-sdk` (ACP adapter) + `genesis-appian-parser` (Appian parser, Phase 16).
This is the layout the phase specs reference.

---

## 1. `genesis` — the platform (local web app + engine)

```
genesis/
  pyproject.toml
  genesis/
    __init__.py
    runtime/
      engine.py            # compile/run/resume a graph with checkpointer
      checkpoint.py         # SQLite checkpointer (~/.genesis/genesis.db)
      context.py            # PlatformContext handed to build()
      settings.py           # ~/.genesis paths + config
    dist/                   # Phase 3 — distribution
      gitlab.py             # GitLab REST v4 client
      catalog.py            # fetch/parse/filter registry.json + bundles.json
      install.py            # resolve/install/update/remove + lockfile
      loader.py             # META read (yaml) + genesis-core major-compat gate + spawn worker (no in-app graph import)
    config/                 # Phase 4 — configuration & secrets
      secrets.py            # SecretProvider (Plaintext v1, Keychain-ready)
      fields.py             # secret-field derivation from mcp-registry
      environments.py       # credential-free env registry
      health.py             # health checks incl. MCP literal-env probe
    runs/                   # Phase 5 — run orchestration
      lifecycle.py          # run record + state machine + start/pause/resume/cancel
      worker.py             # subprocess worker: build+run a graph; IPC; checkpoint-driven resume (ADR-012)
      stream.py             # LangGraph stream → per-run event bus (SSE/WebSocket)
      hitl.py               # gates (interrupt), state edit (update_state), fork
    api/                    # local backend HTTP API (FastAPI; embeds LangGraph as a library)
      catalog_api.py  config_api.py  runs_api.py  home_api.py  static.py
    cli/                    # developer/author CLIs
      create_workflow.py    # scaffolder (Phase 2)
      test_workflow.py      # local test harness runner (Phase 2)
      lint.py               # reliability lint (Phase 2)
    lint/
      reliability.py        # check_reliability(compiled_graph, meta)
    web/                    # Phase 7 — custom workbench (Preact + esbuild)
      webview/ ...
  tests/
```

- `genesis-core` (below) is a dependency, not vendored here.
- The app is a single FastAPI process serving `localhost` (API + web bundle);
  LangGraph is embedded as a library. During M6, `langgraph dev` can attach Studio
  to a graph against the same `genesis.db` checkpointer (debug harness, not the backend).

---

## 2. `genesis-workflows` — the shared workflow library (pulled from GitLab)

```
genesis-workflows/
  registry.json             # catalog (aggregated from workflow.yaml files) — Q4
  mcp-registry.json         # MCP server launch configs + secret keys — Q3
  cli-registry.json         # external CLI definitions
  bundles.json              # curated role bundles — Q5c
  MIGRATION.md              # traceability matrix (skill → workflow → status) — Phase 8
  .gitlab-ci.yml            # publish-time validation (contract + reliability lint + tests) — Q9/Q10
  pyproject.toml            # depends on genesis-core
  steering/                 # AUTHORING GUIDES — Q12
    01-authoring-overview.md
    02-node-taxonomy-and-reliability.md
    03-state-and-blackboard-rules.md
    04-mcp-and-cli-usage.md
    05-hitl-gates.md
    06-testing-and-publishing.md
    07-workflow-yaml-reference.md
    08-migration-runbook.md            # skill → workflow (Phase 8)
  common/                   # (or a submodule/dep) genesis_core package
  workflows/
    _template/              # scaffolder source (reliability trio pre-wired)
      workflow.yaml  graph.py  nodes.py  prompts/  tests/
    hello-appian/           # example
    erd-generation/         # reference workflow (Phase 6)
      workflow.yaml
      graph.py              # build() + META
      nodes.py              # normalize/build/parse + kiro_node prompts
      prompts/
      tests/
    <migrated workflows…>/
```

**Single source of truth:** each workflow's `workflow.yaml` is authoritative;
`registry.json` is the aggregated projection (CI regenerates/validates it),
mirroring solutions-copilot's manifest→catalog.

---

## 3. `genesis-core` — the shared package (ADR-019)

Published/installable; depended on by **both** the platform and the library so
node code doesn't drift between them.

```
genesis_core/
  state.py                 # PlatformState + reducers + helpers
  workspace.py             # RunWorkspace + Doc (blackboard) — promoted from kiro-agent-sdk
  nodes/
    program.py  agent.py  cli.py  validator.py  gate.py  subgraph.py  reliability.py
  mcp/registry.py          # McpRegistry.acp_servers() (per-node injection)
  clis/registry.py         # CliRegistry.ensure/run
  types.py                 # PlatformContext, ValidationResult, Node markers
```

- `nodes/agent.py` wraps `kiro-agent-sdk` (`collect`, `KiroAgentOptions`, `load_mcp_servers`).
- `nodes/*` carry a `_genesis_kind` marker so the reliability lint can identify agent nodes.

---

## 4. Per-machine runtime layout

Small/stable **state** and unbounded **artifacts** are kept in **separate roots**
so bulk data never bloats the app dir and can live on a big disk (ADR-022).

**State root — `~/.genesis/` (small, stable, back-uppable):**
```
~/.genesis/
  config/                  # non-secret settings (library ref, artifacts_dir, retention, prefs)
  secrets.json  (0600)     # SecretProvider store: {"scope/VAR": "…"}
  environments.json        # credential-free Appian env registry
  installed.lock.json      # installed workflows + pinned refs
  genesis.db               # SQLite checkpointer + run records (references artifact paths)
  library/                 # pulled workflow packages (pinned)
    common/  workflows/<id>/…  registry.json  mcp-registry.json  cli-registry.json
```

**Artifacts root — dedicated & configurable (unbounded bulk data):**
```
$GENESIS_ARTIFACTS_DIR   (default: ~/Genesis/runs/)
  <workflow_id>/<run_id>/     # the per-run blackboard
    raw_schema.json  schema.json  enriched.json  report.md  …
    _run.json                 # run manifest: status, sizes, artifact roles, created/updated
```
- Location set via `GENESIS_ARTIFACTS_DIR` env or `config/` setting; default `~/Genesis/runs/`. Point it at an external/large disk if desired.
- Each **run record** in `genesis.db` stores its **absolute `artifacts_dir`**, so relocating the default never orphans old runs.
- **Never checkpointed** into `genesis.db`; state holds only *paths* into here.

**Retention (configurable; safety-bounded):**
- Only **terminal** runs (done/failed/cancelled) are eligible for pruning — never
  a running/paused/awaiting run (would break resume, since state references these paths).
- Policy options: keep-last-N per workflow and/or delete-after-X-days; optionally
  prune *intermediate* artifacts sooner than *final deliverables* (roles declared in `META.artifacts`).
- Manual purge (per run / all completed) from the workbench; disk usage tracked per run + root with an optional soft cap + warning.

Everything under both roots is user-local and never committed.

---

## 5. Dependency directions (no cycles)

```
genesis (platform)  ─depends─▶ genesis-core ◀─depends─  genesis-workflows (each workflow)
genesis (platform)  ─pulls/loads──────────────────────▶  genesis-workflows (installed copy)
genesis-core      ─depends─▶ kiro-agent-sdk, langgraph
```

The platform never imports a workflow at build time; it loads installed workflows
dynamically via `dist/loader.py`, which reads `META` and spawns a subprocess worker to build/run the graph (Q10 / ADR-012).
