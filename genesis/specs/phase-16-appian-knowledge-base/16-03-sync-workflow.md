# Phase 16-03 — Sync workflow (`sync-application`, baseline path)

> **Status:** ✅ **SHIPPED** (genesis v0.29.1 + genesis-workflows v0.8.2) · **Repos:** genesis-workflows (+ genesis) · **Depends on:** 16-01 (parser), 16-02 (KbStore)
> **Goal:** A **LangGraph workflow** that exports an application package from the **dev-tagged** environment (16-08 §2.0)
> via the Appian
> **Deployment REST API** (deterministic program node — no agent, no credits), parses it with `genesis-appian-parser`,
> and applies the result into the KB via `KbStore` — all run-tracked, retryable, and error-surfacing like any Genesis
> run. This sub-phase delivers the **baseline (full)** path; delta is 16-07. Also registers the native **Dev MCP** +
> **DevOps MCP** as curated servers (for agent use elsewhere).

---

## 1. Current state (grounded)
- Workflow anatomy (`genesis-workflows/workflows/design-doc/`): `workflow.yaml` (id/name/version/roles/summary,
  `inputs_schema`, `required_mcp`/`required_cli`, `hitl_points`, `auto_approve`, `retry_defaults`, `artifacts`,
  `editable`, and a UI-only `graph:` topology) + a self-contained `graph.py` with a static `META` (mirrors
  `workflow.yaml`; contract-parity lint) and `build(ctx: PlatformContext) -> CompiledStateGraph` compiled with
  `ctx.checkpointer`.
- Node factories (`genesis-core/genesis_core/nodes/`): `program_node(name, fn)` where `fn(state, ctx) -> partial
  update`; `cli_node(name, cmd_fn, parse_fn)`; `validator_node(name, check_fn, target_artifact=)`; `kiro_node(...)`
  (agent); `hitl_gate(...)`; `attach_reliability(...)` (mandatory trio on agent nodes; CI-enforced by
  `genesis/lint/reliability.py`).
- `PlatformContext` (genesis-core `types.py`) gives a node: `run_id`, `workspace` (RunWorkspace blackboard), `mcp`,
  `clis`, `settings`, `emit`, `secrets`, `environments`, `checkpointer`, `extras`.
- Run wiring: `RunManager.start(workflow_id, inputs, environment=<label>)` (`runs/manager.py`) validates inputs +
  spawns a **subprocess worker** (`runs/worker.py`) — the ONLY place workflow Python is imported (ADR-012). The worker
  `set_active(active_env)`, builds registries + context, `compiled = build(ctx)`, sets `recursion_limit` from
  `META.execution.recursion_limit` (default 150), and `astream`s events (JSONL). Errors → canonical `error`/`run.final`
  via `RunManager._finalize`.
- Env/secret resolution at launch: SecretProvider → EnvironmentRegistry (public URL vars) → os.environ
  (`genesis-core/mcp/registry.py`); MCP `env` is a **LIST** of `{name,value}`.
- Bulk data rule (ADR-010/018): the export zip + parser intermediate → **RunWorkspace blackboard**; only pointers →
  state; only metadata → `kb_*`.

## 2. Design

### 2.1 The workflow package `genesis-workflows/workflows/sync-application/`
`workflow.yaml` + `graph.py` (self-contained; no sibling imports — loaded standalone via importlib). `META` mirrors the
yaml. `inputs_schema`: `{app_uuid (string, required), app_name (string), mode (enum baseline|delta, default baseline),
package_uuid (string, optional — a named package to export; else full-app export)}`. `required_mcp: []` (export is REST,
not MCP; Dev/DevOps MCP are registered globally for agent use but this pipeline doesn't need them injected).
`graph:` topology declared for the Run-Detail preview.

### 2.2 Graph (baseline/full path)
```
resolve_inputs (program)   # normalize inputs; resolve env domain + API key; pick package/app target
  → export_package (program)  # Appian Deployment REST API: export → poll → download zip → RunWorkspace
      → v_export (validator, target=uploads/package.zip)   # present, non-empty, looks like an Appian package
  → parse_package (program)   # genesis_appian_parser.parse(zip_bytes) → KbParseResult → result.json in blackboard
      → v_parse (validator, target=result.json)            # objects>0, no fatal errors, expected app_uuid
  → write_kb (program)        # KbStore.begin_sync → apply(mode=baseline) → recompute+store bundles → finish_sync
      → v_kb (validator)                                   # kb_syncs succeeded; counts reconcile with result stats
  → present (program)         # sync summary (counts, duration, coverage) → report.json
```
- **No agent nodes** ⇒ no reliability trio needed; the `v_*` validators are the correctness gates (each with retry via
  `retry_defaults`). No `pre_mutation` gate — Appian access is **read-only** (export) and the only write is the local
  KB (§umbrella §15 ADR-021 note).

### 2.3 Deterministic REST export (`export_package` program node)
Ports `sync_packages.py`'s approach into a program node, using the **Appian Deployment REST API** (v2) rather than a
bespoke package-repo webapi:
- Resolve the **domain** from the **dev-tagged** environment (`EnvironmentRegistry.dev_environment()`; the run is
  launched with `environment=<dev env label>` — see 16-08 §2.0 and 16-04) and the **API key** from the SecretProvider (a designated scope, e.g. `appian-devops/APPIAN_API_KEY`; wiring
  detail — decide whether this is a global key or a server-scoped secret the program node reads). No secret value is
  ever emitted into events/state (reference by key name only).
- Flow (async httpx): `export_package` (POST → deployment UUID) → `poll_deployment_status` (GET results until terminal)
  → `download_exported_package` (GET zip) → write bytes to the **RunWorkspace** at `uploads/package.zip`. Optionally
  `get_application_packages(app_uuid)` first to resolve a package to export when `package_uuid` isn't given. (Exact
  endpoint paths pinned at implementation time against the Deployment REST API docs; the DevOps MCP tool names map 1:1
  to these endpoints and are the reference.)
- Guards: honor the ≤300s export window (node timeout > 300s); surface HTTP 401/403/404/409 with actionable messages
  (mirror the DevOps MCP troubleshooting: 403 ⇒ External Deployments not enabled / service-account perms; 409 ⇒
  concurrency). Retryable via the validator/retry loop.
- **Why REST not MCP (ADR-001):** exporting is a mechanical, deterministic sequence; using an LLM turn would burn
  credits and be non-deterministic. The DevOps MCP remains **registered** for interactive/agent use (2.5).

### 2.4 `parse_package` + `write_kb` (program nodes)
- `parse_package`: read the zip from the blackboard, call `genesis_appian_parser.parse(bytes)`, serialize the
  `KbParseResult` (as JSON, **no code**) to `result.json` in the blackboard, return counts/pointers to state (small).
- `write_kb`: `KbStore.begin_sync(app_uuid, kind='baseline', run_id=ctx.run_id)` → `apply(sync_id, result,
  mode='baseline')` → `finish_sync(...)`. Reconcile counts in `v_kb`. `genesis` exposes `KbStore` to the worker via the
  context (a `ctx.extras['kb_store']` or a direct `KbStore(Database(settings.db_path))` in the node — decide the wiring;
  the node runs in the subprocess worker with `settings` available).

### 2.5 Register the native MCPs (managed native — installed + updatable by 16-08)
The Dev/DevOps MCP servers are **installed and kept updatable by 16-08** (managed, versioned, `uv`-installed under
`~/.genesis/mcp-servers/`, launched from the per-server venv; **ADR-038**). This sub-phase just references them
(agent-facing; this pipeline's own export is deterministic REST, so it does not inject them):
- `appian-dev` (Dev MCP / `lcp-mcp-server`) — **read-only tool_allowlist** (list/read design objects; version-aware
  read when AP-62096 ships). Resolves the old `lcp` `<lcp-image>` placeholder.
- `appian-devops` (Deployment MCP) — **read/export-only tool_allowlist** (export + status + download; deploy tools
  excluded while write is out of scope).
- Registered as a **managed reference** (identity + allowlist curated; launch spec resolved at runtime from the 16-08
  install), NOT a static image. `env` as a **LIST** of `{name,value}`; `${APPIAN_...}`/`${LCP_...}` resolved from
  Secrets/Env at launch. **Depends on 16-08.**

## 3. Files & tests
- New: `genesis-workflows/workflows/sync-application/{workflow.yaml, graph.py, README.md, tests/}`; registry entries in
  `mcp-registry.json` (+ `registry.json` catalog entry, roles e.g. `Dev`); `genesis` pins `genesis-appian-parser` and
  exposes `KbStore` to the worker.
- Tests (`genesis-workflows/workflows/sync-application/tests/` + genesis integration):
  - **stubbed export** (a fake Deployment REST endpoint or a local zip fixture) → parse → KbStore apply → assert a
    baseline sync populates `kb_*` with the expected counts (reuse 16-01's real-package fixture end-to-end).
  - validator behavior: empty/short zip fails `v_export`; zero objects fails `v_parse`; count mismatch fails `v_kb`;
    each retries then surfaces a clear error.
  - `validate_library.py` 7-gate + contract-parity (yaml↔META) + reliability lint (no agent nodes ⇒ passes) green.
  - a genesis-side test that `RunManager.start("sync-application", {...}, environment=<label>)` runs the graph in a
    worker to completion on the fixture (like the existing program-only workflow run tests).
- **Live acceptance (manual, recorded in progress/):** a real export against the connected env → parse → KB populated;
  can't be driven headlessly.

## 4. Acceptance criteria
1. `sync-application` installs + validates (7-gate, parity, reliability, ruff); appears in the catalog.
2. A baseline run **exports (deterministic REST) → parses → writes the KB**, tracked as a normal run with per-node
   status + retry + error surfacing; the zip + `result.json` live in the blackboard, not state.
3. `kb_*` is populated correctly for a real captured package (counts reconcile; no code stored).
4. `appian-dev` + `appian-devops` are registered curated MCPs (read/export-only allowlists); the `lcp` placeholder is
   resolved.
5. No `pre_mutation` gate (read-only Appian); no agent nodes; secrets referenced by key name only.

## 5. Out of scope
- Delta path + the changed-objects API (16-07) — this sub-phase is baseline/full only.
- The Applications page/API that *launches* this workflow (16-04).
- The `genesis-kb` MCP + cutover (16-05); version tagging (16-06).
- Any Appian **write/deploy** (deploy tools excluded from the curated allowlist).
