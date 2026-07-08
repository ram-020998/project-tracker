# Phase 1 — Core Platform Foundation

> **Goal:** Stand up the engine and the node framework that every workflow runs
> on: LangGraph wiring, the node taxonomy, the state model, the SQLite
> checkpointer, the `RunWorkspace` blackboard, the MCP registry, the CLI registry,
> and the validator/retry framework. At the end of Phase 1 a trivial workflow can
> run end-to-end in code (no UI), with durable state, MCP injection, and the
> reliability trio working.

Prereq reading: `specs/00-architecture-overview.md`. Depends on: `kiro-agent-sdk`.

---

## 1. Objective & success statement

Deliver the **`genesis` platform core** (the `common/` library + runtime) such
that: (a) a `StateGraph` can be built from program + agent + validator + gate
nodes; (b) an agent node drives Kiro over ACP with per-node MCP injection; (c)
state is checkpointed to SQLite after each step and is resumable; (d) bulk data
lands in a per-run blackboard folder; (e) the reliability trio (agent → validator
→ retry/escalate) is a reusable primitive. Verified by an automated "smoke
workflow" that exercises all of the above.

---

## 2. Scope

**In scope**
- `genesis` runtime package (engine bootstrap, checkpointer, settings).
- `common/` library (node factories, `RunWorkspace`, `PlatformState`, validators, retry/escalation).
- MCP registry loader + per-node injection (built on `kiro-agent-sdk`).
- CLI registry (typed CLI invocation + output parsing).
- A code-only "smoke workflow" for verification.

**Out of scope (later phases)**
- Workflow contract/`META` loading from the library (Phase 2).
- GitLab pull / install / lockfile (Phase 3).
- Config UI / secrets UI (Phase 4).
- Run APIs / HITL surfacing / streaming to a UI (Phase 5).
- The ERD workflow itself (Phase 6).

---

## 3. Decisions applied

Q2 (per-node MCP injection), Q3 (MCP registry, no profiles), Q8 (small state +
blackboard + SQLite checkpointer), Q9 (reliability trio as a primitive), Q10
(subprocess-worker execution — validated in the spike).

---

## 4. Detailed design

### 4.1 Package layout
```
genesis/                              # platform repo
  genesis/
    __init__.py
    runtime/
      engine.py          # compile + run a graph with checkpointer wired
      checkpoint.py       # SQLite checkpointer factory (~/.genesis/genesis.db)
      settings.py         # paths (~/.genesis), config load
      context.py          # PlatformContext (handed to build())
    common/               # SHIPPED ALSO INTO genesis-workflows/common (single source; see §7)
      state.py            # PlatformState + reducers
      workspace.py        # RunWorkspace (from kiro-agent-sdk, promoted)
      nodes/
        program.py        # program_node
        agent.py          # kiro_node (ACP)
        cli.py            # cli_node
        validator.py      # validator_node + schema/checks helpers
        validators.py     # BATTERIES-INCLUDED validator toolkit (generic, composable)
        gate.py           # hitl_gate (interrupt wrapper)
        subgraph.py       # subgraph_node
        reliability.py    # attach_reliability(agent_node, validator, retry_max, on_exhaust)
      mcp/
        registry.py       # load mcp-registry.json, resolve secrets, build ACP mcp_servers
      clis/
        registry.py       # CLI registry
    testing/
      harness.py          # run a graph headless, assert on state/artifacts
  tests/
  pyproject.toml
```

### 4.2 `PlatformContext` (handed to every `build()`)
```python
@dataclass
class PlatformContext:
    run_id: str
    workspace: RunWorkspace           # per-run blackboard
    mcp: McpRegistry                  # resolve server name -> ACP mcp_servers entry (secrets applied)
    clis: CliRegistry                 # resolve + run CLIs
    secrets: SecretProvider           # scope/VAR lookups
    environments: EnvironmentRegistry # label -> {url, api_endpoint, ...}
    settings: Settings
    emit: Callable[[dict], None]      # custom stream events (Phase 5 wires to UI)
```

### 4.3 State model (`common/state.py`)
Exactly `PlatformState` from the architecture overview §5. Reducers: `errors`
appended; `decisions`/`artifacts` shallow-merged; `retries` per-key increment.
Provide `new_state(run_id, workflow_id, inputs)` and typed helpers
`record_artifact(state, name, path)`, `record_decision(state, key, value)`.

### 4.4 `RunWorkspace` (`common/workspace.py`)
Promote the existing `kiro_agent_sdk.RunWorkspace`:
- `RunWorkspace.for_run(run_id)` → `~/.genesis/runs/<run_id>/`.
- `.doc(name, create_empty=True) -> Doc`; `.read_json/.write_json/.manifest()`.
- Docs are the cross-agent handoff artifacts and bulk store.

### 4.5 Node factories

**`program_node(fn)`** — wraps `fn(state, ctx) -> dict` (partial state update).

**`kiro_node(...)`** — the core agent step:
```python
def kiro_node(*, name, prompt_fn, output_doc: str, mcp: list[str] = (),
              tools: list[str] | None = None, model: str | None = None,
              turn_timeout: float = 420) -> Node:
    async def run(state, ctx):
        servers = ctx.mcp.acp_servers(mcp)             # resolve + inject
        opts = KiroAgentOptions(cwd=..., trust_all_tools=True,
                                mcp_servers=servers, tools=tools, model=model,
                                turn_timeout=turn_timeout)
        doc = ctx.workspace.doc(output_doc)
        prompt = prompt_fn(state, ctx, out_path=doc.path)
        turn = await collect(prompt, opts)             # kiro-agent-sdk
        # do NOT parse bulk from chat; the node WROTE output_doc
        return {"artifacts": {output_doc: str(doc.path)},
                "_last_turn": {"stop_reason": turn.stop_reason, "error": turn.error}}
```
Design rules baked in (lessons from `kiro-agent-sdk`): agent writes to a
pre-created blackboard doc (never returns bulk via chat); short one-shot session;
64 MB ACP stream buffer already handled by the SDK.

**`cli_node(cmd_fn, parse_fn)`** — build argv from state, run via `ctx.clis`, parse stdout to a state update; nonzero exit → raise (caught by reliability wrapper if wrapped).

**`validator_node(...)`** — deterministic check of an artifact/decision:
```python
def validator_node(*, name, check_fn, target_artifact: str) -> Node:
    # check_fn(data, state, ctx) -> ValidationResult(ok: bool, message: str, normalized: Any|None)
```
Returns a routing key `pass`/`fail` and (on pass) may write a normalized artifact.

**`hitl_gate(kind)`** — see Phase 5; here we implement the primitive using
LangGraph `interrupt(payload)` and resume via `Command(resume=...)`.

**`subgraph_node(workflow_id)`** — compile another workflow's graph and embed it.

### 4.6 Reliability trio (`common/nodes/reliability.py`) — Q9
Helper that wires the mandatory pattern into a graph builder:
```python
def attach_reliability(g, *, agent, validator, retry_max: int,
                       on_exhaust_gate: str | None):
    g.add_node(agent.name, agent); g.add_node(validator.name, validator)
    g.add_edge(agent.name, validator.name)
    def route(state):
        v = state["_validation"][validator.name]
        if v["ok"]: return "pass"
        if state["retries"].get(agent.name, 0) < retry_max: return "retry"
        return "escalate"
    g.add_conditional_edges(validator.name, route, {
        "pass": <next>, "retry": agent.name,            # re-run with feedback
        "escalate": on_exhaust_gate or END,
    })
```
On `retry`, the agent's `prompt_fn` receives the validator message
(`state["_validation"][...]["message"]`) to self-correct. `retry_max` comes from
`workflow.yaml` (Q9: configurable per workflow).

### 4.7 MCP registry (`common/mcp/registry.py`) — Q3
- Loads `mcp-registry.json` (schema in Phase 2 §4.3, but the loader lives here).
- `acp_servers(names) -> list[dict]`: for each server name, take its launch
  config, resolve `${VAR}` from `SecretProvider` + environment, and emit the ACP
  `session/new` `mcpServers` entry (reuse `kiro_agent_sdk.load_mcp_servers` logic,
  generalized to read from the registry object rather than a raw `mcp.json`).
- Reports unresolved vars (fail fast before spawning Kiro).

### 4.8 CLI registry (`common/clis/registry.py`)
- `cli-registry.json`: name → {binary, install_hint, version_check}.
- `ensure(name)` (verify present, optional install hint), `run(name, argv) -> CompletedProcess`.
- Mirrors the ERD `erd-gen` preflight/parse pattern.

### 4.9 Engine (`runtime/engine.py`) — async-first (ADR-024)
- `compile(graph) -> CompiledStateGraph` with the async SQLite checkpointer.
- `async run(compiled, inputs, thread_id)` and `async resume(thread_id, command)` using `ainvoke`/`astream` (agent nodes are async → sync `invoke` cannot bridge them; verified in the spike).
- Threads = runs; `thread_id == run_id`.

### 4.10 Checkpointer (`runtime/checkpoint.py`) — async (ADR-024)
- `AsyncSqliteSaver` (dependency: `aiosqlite`) at `~/.genesis/genesis.db`; per-superstep snapshots (durability=full for HITL correctness). The sync `SqliteSaver` is not used — it raises `NotImplementedError` under async execution.

---

## 5. Task breakdown

0. **De-risking spike (do first).** Validate the load-bearing assumptions on the pinned LangGraph version before building: (a) SQLite checkpointer per-superstep snapshots; (b) `interrupt()` + resume via `Command`; (c) `update_state` edit + resume + fork (time-travel); (d) an **async** node runs cleanly; (e) **subprocess worker** boundary — run a graph in a child process against the shared checkpointer, kill it mid-run, and **resume from a fresh worker**; (f) a `sys.exit()`/hang in the worker does not take down the parent; (g) sketch the genesis-core **major-compat gate** (refuse-to-load on major mismatch). Record findings; adjust the phase if any assumption fails.
1. Scaffold `genesis` repo (**Python 3.13**), `pyproject.toml`, deps (`langgraph`, `langgraph-checkpoint-sqlite`, `aiosqlite`, `kiro-agent-sdk`, `genesis-core`), tooling (pytest, ruff). Engine is async-first (ADR-024).
2. `runtime/settings.py` — `~/.genesis` (state root) path resolution + **`artifacts_dir`** (dedicated bulk root; default `~/Genesis/runs/`, override via `GENESIS_ARTIFACTS_DIR`/config) + `Settings`.
3. `runtime/checkpoint.py` — SQLite checkpointer factory.
4. `common/state.py` — `PlatformState`, reducers, helpers + tests.
5. Promote `RunWorkspace`/`Doc` into `common/workspace.py` (from `kiro-agent-sdk`) — `for_run(run_id, workflow_id)` resolves under the configured **artifacts root** (`<GENESIS_ARTIFACTS_DIR>/<workflow_id>/<run_id>/`), `manifest()` reports `total_bytes` — + tests.
6. `common/mcp/registry.py` — registry loader + `acp_servers()` + unresolved-var reporting + tests (offline).
7. `common/clis/registry.py` — CLI registry + `ensure/run` + tests.
8. `common/nodes/program.py`, `cli.py` — factories + tests.
9. `common/nodes/agent.py` — `kiro_node` (ACP via `collect`) + unit test with a stubbed transport. **Capture per-node telemetry** (`attempts/duration_ms/tool_calls/turns/credits/retries`) into `state.telemetry[node]` + run aggregate; `_last_turn` extended. `credits` best-effort pending SDK usage exposure.
10. `common/nodes/validator.py` — `validator_node` + `ValidationResult` + JSON-schema helper + tests.
10a. `common/nodes/validators.py` — **batteries-included validator toolkit** (generic composable validators + `all_of`/`any_of`); each emits an actionable failure message; extensive unit tests. Appian-object validators explicitly deferred (see reliability-standard §3.2).
11. `common/nodes/gate.py` — `hitl_gate` primitive over `interrupt()` (full UX in Phase 5).
12. `common/nodes/reliability.py` — `attach_reliability` + tests (pass / retry / escalate routing).
13. `runtime/engine.py` + `runtime/context.py` — compile/run/resume + `PlatformContext`.
14. `testing/harness.py` — headless runner + assertions.
15. **Smoke workflow** (in `tests/`): program → kiro_node(generic, no MCP) → validator → (retry) → program; assert artifacts + state + a forced-fail path that escalates.
16. CI (platform repo): lint + unit tests.

---

## 6. Acceptance criteria

- [ ] A smoke workflow runs via `testing/harness.py` and completes with expected state + artifacts.
- [ ] Killing the process mid-run and re-running with the same `thread_id` **resumes** from the last checkpoint (no re-execution of completed nodes).
- [ ] `kiro_node` spawns an ACP session with injected MCP (verified against a real MCP, e.g. `appian-atlas`, or a stub) and writes to its blackboard doc.
- [ ] Reliability trio: a deliberately-failing validator triggers exactly `retry_max` retries then routes to escalation.
- [ ] The validator toolkit (`validators.py`) covers the common cases as one-liners (non_empty, parses_json, json_schema, required_keys, values_in_set, count_between, first_field_is, excludes, referential_integrity, all_items_present, matches_predicate, all_of/any_of); each produces an actionable failure message.
- [ ] MCP registry reports unresolved `${VAR}` before spawning Kiro (fail fast).
- [ ] Bulk data never appears in `PlatformState`; only paths/decisions do (asserted in the smoke test).
- [ ] Every agent node records telemetry into `state.telemetry[node]` (`attempts/duration_ms/tool_calls/turns/retries`, `credits` best-effort) and updates the run aggregate; retries accumulate correctly.
- [ ] All unit tests pass in CI.

---

## 7. Notes & risks

- **`common/` duplication:** `common/` is authored in the platform but must also
  be importable by workflows in `genesis-workflows`. Decision: publish `common`
  as an installable package (`genesis-core`) that both the platform and the
  library depend on — avoids copy drift. (Confirm in Phase 2.)
- **Async in LangGraph:** `kiro_node` is async; ensure the engine runs the graph
  in an event loop consistently (LangGraph supports async nodes).
- **Checkpoint size:** enforce the state-small rule in `program_node`/`kiro_node`
  return validation (reject large blobs into state in dev mode).
- **ACP session cost:** one session per agent node; acceptable for Phase 1;
  revisit pooling if the smoke tests show high latency.
- **Telemetry / credits dependency:** capturing `credits` requires
  `kiro-agent-sdk` to expose usage in `TurnResult` (ACP usage events). Track as a
  dependency; capture `duration_ms/tool_calls/turns/retries` regardless. The
  telemetry schema ships now so credits slot in without retrofit.

---

## 8. Deliverables

- `genesis` repo with `runtime/` + `common/` + `testing/` + tests + CI.
- `genesis-core` package boundary defined.
- A passing smoke workflow proving engine + nodes + checkpointer + MCP injection + reliability trio.
