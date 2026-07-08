# Genesis — Phase 1 Implementation Record

> Detailed log of what was actually built, decided, and verified during the
> Phase 1 (Core Platform Foundation) implementation session. Companion to
> `specs/phase-01-core-platform-foundation.md` (the plan) and
> `reference/spike-findings.md` (the de-risking spike). The master `tracker.md`
> links here for detail.

**Date:** 2026-07-08 · **Milestone:** M1 (Engine works) · **Status:** ✅ COMPLETE — 20 tests green, ruff clean, all repos pushed to GitLab.

---

## 1. Summary

Phase 1 delivered the **engine + node framework** every Genesis workflow runs on:
LangGraph wiring, the node taxonomy, the small-state model, the async SQLite
checkpointer, the `RunWorkspace` blackboard, the MCP + CLI registries, and the
reliability trio — verified by a headless smoke workflow. Two repos (`genesis-core`,
`genesis`) were scaffolded, built, tested, and pushed to GitLab; the whole
dependency tree (including the transitively-pulled `kiro-agent-sdk`) is installable
with a single `pip install`.

Preceded by a **de-risking spike** (Phase 1, Task 0) that validated all
load-bearing LangGraph assumptions on `langgraph 1.2.8 / Python 3.13.3` and
surfaced two design refinements (ADR-024, ADR-025). See `reference/spike-findings.md`.

---

## 2. Repositories created & pushed

| Repo | GitLab | Branch | Tag | Purpose |
|---|---|---|---|---|
| `genesis-core` | `git@gitlab.appian-stratus.com:ramaswamy.u/genesis-core.git` | master | **v0.1.0** | Shared primitives (ADR-019) |
| `genesis` | `git@gitlab.appian-stratus.com:ramaswamy.u/genesis.git` | master | **v0.1.0** | Platform (runtime + engine) |
| `kiro-agent-sdk` | `git@gitlab.appian-stratus.com:ramaswamy.u/kiro-agent-sdk.git` | main | **v0.0.1** | Agent/ACP adapter (pre-existing; tagged this session) |
| `genesis-workflows` | (remote exists, empty) | — | — | Library — populated in **Phase 2** |

Local working copies: `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/<repo>/`.

---

## 3. What was built

### 3.1 `genesis-core` (the shared package)
```
genesis_core/
  __init__.py          # public API surface
  types.py             # PlatformContext, ValidationResult, Node, CTX_KEY,
                       #   CORE_MAJOR + check_compat (semver major-compat gate, ADR-019)
  state.py             # PlatformState + reducers (_merge, _inc_merge,
                       #   _telemetry_merge) + new_state/record_artifact/record_decision
  workspace.py         # RunWorkspace + Doc (blackboard under the configurable
                       #   artifacts root, ADR-022); default_artifacts_root()
  validators.py        # batteries-included toolkit (public: genesis_core.validators)
  nodes/
    program.py         # program_node (deterministic step)
    agent.py           # kiro_node (async ACP via kiro-agent-sdk; per-node telemetry;
                       #   set_collect_impl() stub hook for tests)
    cli.py             # cli_node
    validator.py       # validator_node (loads target artifact, routes pass/fail)
    gate.py            # hitl_gate (interrupt(); kinds approval|escalation|pre_mutation|review)
    subgraph.py        # subgraph_node (composition)
    reliability.py     # attach_reliability (the mandatory trio wiring)
  mcp/registry.py      # McpRegistry.acp_servers() — per-node injection + ${VAR} fail-fast
  clis/registry.py     # CliRegistry.ensure/run
```

**Validator toolkit (`genesis_core.validators`)** — composable one-liner checks:
`non_empty, parses_json, json_schema, required_keys, values_in_set, count_between,
first_field_is, excludes, referential_integrity, all_items_present,
matches_predicate`, plus combinators `all_of` / `any_of`. Each emits an actionable
failure message (fed into the agent prompt on retry). Appian-object validators
remain deferred to the write-path phase (reliability-standard §3.2).

**Reliability trio (`attach_reliability`)** — wires `agent → validator →
(pass→nxt | retry→agent | escalate→gate/END)`. The wrapped validator increments
`retries[agent]` on failure so the post-node router sees the updated count.
Routing rule: `retries <= retry_max → retry`, else `escalate`. For `retry_max=N`
the agent runs `N+1` times (initial + N retries) then escalates.

### 3.2 `genesis` (the platform)
```
genesis/
  runtime/
    settings.py        # state root (~/.genesis, GENESIS_STATE_DIR) + artifacts root
                       #   (GENESIS_ARTIFACTS_DIR, default ~/Genesis/runs) + db_path
    checkpoint.py      # AsyncSqliteSaver factory (async context manager) — ADR-024
    context.py         # build_context() -> PlatformContext for a run
    engine.py          # async compile/run/resume/stream; ctx injected via config;
                       #   thread_id == run_id
  testing/
    harness.py         # headless graph runner (compiles with async checkpointer,
                       #   builds ctx, runs to first stop) -> HarnessResult
```

### 3.3 Node ↔ engine contract (implementation detail worth remembering)
- Node factories return a `Node(name, fn, kind)` dataclass; `fn` is an
  `async fn(state, config)` LangGraph-callable. `g.add_node(node.name, node.fn)`.
- The `PlatformContext` is injected by the engine into `config["configurable"][CTX_KEY]`;
  nodes read it via `genesis_core.types.ctx_from_config(config)`.
- **LangGraph only injects `config` when the wrapper's second param is annotated
  `RunnableConfig`** (discovered during the smoke run — see §5). All node wrappers
  are annotated accordingly (works even with `from __future__ import annotations`).
- Nodes carry `_genesis_kind` (+`_genesis_name`) markers for the Phase-2 reliability lint.

---

## 4. Verification (evidence)

Dev venv: Python 3.13.3, editable installs of all three packages.

| Check | Result | Test / evidence |
|---|---|---|
| genesis-core unit suite | **15 passed** | `genesis-core/tests/test_core_units.py` |
| platform smoke suite | **5 passed** | `genesis/tests/test_smoke.py` |
| ruff lint (both packages) | **clean** | `ruff check` |
| Smoke workflow completes | ✓ | `test_happy_path_and_telemetry` |
| Reliability trio: retry then escalate | ✓ | `test_retry_then_escalate` (retries==3 for retry_max=2, interrupt at escalation gate) |
| Per-node **+ run-level** telemetry | ✓ | `telemetry[node]` + `telemetry["_run"]` (attempts/duration_ms/tool_calls/turns; credits=None best-effort) |
| No bulk in state | ✓ | `test_no_bulk_in_state` (10KB blob stays in the file, not the checkpoint) |
| Per-node MCP injection + `${VAR}` resolve | ✓ | `test_kiro_node_injects_per_node_mcp` |
| MCP fail-fast on unresolved var | ✓ | `test_mcp_fail_fast_on_unresolved` |
| Durable resume from checkpoint | ✓ | `test_durable_resume` (resume same run_id with a decision) |
| True kill-mid-run → resume (no re-exec) | ✓ | spike `driver_worker.py` (subprocess SIGKILL → fresh-worker resume) |
| Validator toolkit one-liners | ✓ | toolkit tests incl. cross-artifact `referential_integrity`, `all_items_present` |

### Distribution (installability) — verified in clean throwaway venvs
- `pip install "genesis-core @ git+ssh://…/genesis-core.git@v0.1.0"` → pulled
  `kiro-agent-sdk==0.0.1` transitively. ✓
- `pip install "genesis @ git+ssh://…/genesis.git@v0.1.0"` → resolved
  `genesis 0.1.0, genesis-core 0.1.0, kiro-agent-sdk 0.0.1, langgraph 1.2.8,
  langgraph-checkpoint-sqlite 3.1.0, aiosqlite 0.22.1`; imported `genesis.runtime`. ✓
  **→ end users run one `pip install`; the SDK is never downloaded separately.**

---

## 5. Decisions & findings made during implementation

- **ADR-024 (async-first engine).** `kiro_node` is async; sync `invoke()` cannot run
  an async node and the sync `SqliteSaver` throws under async. Engine uses
  `ainvoke`/`astream` + **`AsyncSqliteSaver`** (dep: `aiosqlite`). Python pinned **3.13**.
- **ADR-025 (fork = new thread).** LangGraph `update_state` on a past checkpoint
  rewinds the *same* thread; Genesis fork seeds a **new** thread (`as_node`) so the
  original run stays intact.
- **RunnableConfig annotation requirement.** LangGraph injects `config` into a node
  only if the second parameter is annotated `RunnableConfig`. All node wrappers now
  import and annotate it. (Caught by the first smoke run failing with
  `TypeError: missing 1 required positional argument`.)
- **Validator toolkit is `genesis_core.validators`** (top-level public module), not
  under `nodes/` — matches the documented public API in reliability-standard §3.1.
- **Distribution model = git-pinned dependencies (option A).** Each repo declares
  its upstream via `git+ssh://…@<tag>` with `[tool.hatch.metadata] allow-direct-references=true`.
  `kiro-agent-sdk` stays a **separate repo** (clean L1 adapter layer, independent
  versioning) and is pulled transitively — chosen over vendoring it into genesis-core.

---

## 6. Deviations from the Phase 1 spec (all forward-compatible)
- Engine/checkpointer are **async** (spec said checkpointer/engine generically; ADR-024 refined this).
- `genesis-core` is a real published-by-git package now (spec §7 said "confirm in Phase 2" — confirmed early to make the tree installable).
- Everything else matches `specs/phase-01-core-platform-foundation.md` §4–§8.

---

## 7. Not done in Phase 1 (correctly deferred)
- Workflow contract/`META` loading, scaffolder, CI reliability **lint** → **Phase 2**.
- GitLab pull / install / lockfile / loader + compat gate enforcement → **Phase 3**.
- Config UI / SecretProvider / environments / health → **Phase 4**.
- Run APIs / streaming / subprocess **worker** / full HITL surfacing → **Phase 5**.
- `genesis-workflows` repo population (registries, `_template`, `hello-appian`, steering) → **Phase 2**.
- `credits` telemetry value → pending a `kiro-agent-sdk` `TurnResult` usage enhancement (schema already present, value is `None`).

---

## 8. How to run (dev)
```
cd repo-gitlab/ramaswamy.u/genesis
python3.13 -m venv .venv
.venv/bin/pip install -e ../kiro-agent-sdk -e ../genesis-core -e ".[dev]"
.venv/bin/ruff check genesis && .venv/bin/pytest -q          # platform
(cd ../genesis-core && ../genesis/.venv/bin/pytest -q)        # genesis-core
```

---

## 9. Next: Phase 2 — Workflow Contract & Library System
Create/populate `genesis-workflows`: `build()`+`META` contract, `registry.json` /
`mcp-registry.json` / `cli-registry.json` / `bundles.json`, `_template` +
`hello-appian`, the 7 authoring steering docs, `create-workflow` + `test-workflow`
CLIs, and the CI **reliability lint** (`genesis.lint.check_reliability`) proven by a
deliberately non-compliant fixture. See `specs/phase-02-workflow-contract-and-library.md`.
