# Genesis — Architecture Overview (00)

> Shared reference for every phase spec. Defines the layered architecture, the
> core domain model, the node taxonomy, the state/blackboard split, the runtime
> topology, and the cross-cutting standards. Read this before any phase spec.

---

## 1. One-paragraph thesis

Genesis is a **local web application** that lets a Solutions engineer discover,
install, run, and supervise **workflows**. A workflow is a **LangGraph graph**
whose nodes are either deterministic **program steps** or narrow **agent steps**
that drive **Kiro** through `kiro-agent-sdk` over **ACP**, injecting only the MCP
server(s) that step needs. LangGraph owns control flow, durable state, and
human-in-the-loop; a per-run **artifacts folder** (blackboard) holds bulk data;
workflows are pulled from the shared **`genesis-workflows`** GitLab repo via a
**selective install + lockfile** mechanism. Every agent step is wrapped by a
**program validator + retry/escalation** (hard requirement).

---

## 2. Layered architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│ L5  SURFACES        Custom Web Workbench (Phase 7)  ·  LangGraph Studio (interim) │
├───────────────────────────────────────────────────────────────────────────┤
│ L4  APP SERVICES    Catalog · Install/Update · Run Control · Config/Secrets · HITL │
├───────────────────────────────────────────────────────────────────────────┤
│ L3  WORKFLOWS       genesis-workflows library (pulled)  →  compiled StateGraphs    │
├───────────────────────────────────────────────────────────────────────────┤
│ L2  COMMON LIB      node factories · RunWorkspace(blackboard) · base state · validators │
├───────────────────────────────────────────────────────────────────────────┤
│ L1  ADAPTERS        kiro-agent-sdk (ACP) · MCP registry · CLI registry · GitLab client │
├───────────────────────────────────────────────────────────────────────────┤
│ L0  RUNTIME         LangGraph engine · SQLite checkpointer · Store · SecretProvider │
└───────────────────────────────────────────────────────────────────────────┘
```

- **L0 Runtime** — LangGraph engine; SQLite checkpointer (per-superstep snapshots); optional Store (cross-run memory); SecretProvider (local secret store).
- **L1 Adapters** — the only integration points: `kiro-agent-sdk` (Kiro via ACP), MCP registry (server launch configs + secrets), CLI registry (external CLIs), GitLab REST client (library pull).
- **L2 Common library** — shipped inside `genesis-workflows/common/`: node factories (`kiro_node`, `program_node`, `cli_node`), `RunWorkspace`, base `PlatformState`, validator/retry helpers.
- **L3 Workflows** — the pluggable content; each a compiled `StateGraph`.
- **L4 App services** — catalog, install/update, run control, config/secrets, HITL — the local backend of the web app.
- **L5 Surfaces** — LangGraph Studio interim, custom workbench later.

---

## 3. Core domain model

```
Library (genesis-workflows repo)
 ├── registry.json            # catalog of all workflows (source of truth)
 ├── mcp-registry.json        # MCP server launch configs + secret keys
 ├── bundles.json             # curated role bundles (Q5c)
 ├── common/                  # shared node lib + base state + RunWorkspace
 ├── steering/                # authoring guides (how to build a workflow)
 └── workflows/<id>/
      ├── workflow.yaml        # META (name, version, roles, inputs, required_mcp/cli, hitl_points, retry defaults)
      ├── graph.py             # build(ctx) -> CompiledStateGraph
      ├── nodes.py, prompts/   # implementation
      └── tests/               # local test harness cases

Installation (per user machine)
 ├── ~/.genesis/            # STATE root (small, stable): config, secrets, genesis.db, lockfile, library
 │   ├── config/  secrets.json(0600)  environments.json  installed.lock.json  genesis.db
 │   └── library/           # pulled workflow packages (pinned)
 └── $GENESIS_ARTIFACTS_DIR (default ~/Genesis/runs/)   # ARTIFACTS root (unbounded bulk; ADR-022)
      └── <workflow_id>/<run_id>/   # per-run blackboard + handoff docs (retention-managed)
```

---

## 4. Node taxonomy (L2)

Every workflow is assembled from a fixed set of node factories so all workflows
look the same and the Q9 hard-requirement is the default.

| Factory | Purpose | Determinism | MCP |
|---|---|---|---|
| `program_node(fn)` | Pure Python step (transform, assemble, parse) | deterministic | none |
| `kiro_node(prompt_fn, output_doc, mcp=[...], tools=[...])` | One narrow agent turn via ACP `collect()` | non-deterministic | injected per node |
| `cli_node(cmd_fn, parse_fn)` | Wrap an external CLI | deterministic | none |
| `validator_node(schema/checks)` | Deterministic check of a prior artifact; routes pass/fail | deterministic | none |
| `hitl_gate(kind)` | Designed approval / feedback pause via `interrupt()` | — | none |
| `subgraph_node(workflow_id)` | Compose another workflow | mixed | — |

**Mandatory pairing (Q9):** every `kiro_node` is immediately followed by a
`validator_node`; on failure a conditional edge retries the `kiro_node` (feeding
the validator's message back) up to `retry_max`; on exhaustion it routes to a
`hitl_gate`. The scaffolder generates this trio by default.

---

## 5. State vs. blackboard (the load-bearing rule — Q8)

- **LangGraph state (`PlatformState`)** — small, serializable, human-readable, **editable**:
  ```python
  class PlatformState(TypedDict):
      run_id: str
      workflow_id: str
      inputs: dict                      # validated trigger inputs
      artifacts: dict[str, str]         # name -> path in the run's blackboard
      decisions: dict                   # small agent outputs (domain map, choices)
      status: str                       # running | awaiting_input | failed | done
      cursor: str                       # current node (for resume/inspection)
      errors: Annotated[list, add]      # appended via reducer
      retries: dict[str, int]           # per-node retry counters
  ```
- **Blackboard (`RunWorkspace`, `~/.genesis/runs/<id>/`)** — bulk artifacts: raw MCP dumps, normalized data, generated SQL/docs, cross-agent handoff files. Referenced from state by path, never inlined.

Rationale: keeps checkpoints small/fast, makes state-editing HITL usable (edit a
compact object, not a 75 KB blob), and mirrors solutions-copilot's `.kiro/analysis`
handoff. This rule directly resolved the failures found while building the SDK.

---

## 6. Runtime topology

- **Single local app** (Q6): a **FastAPI** backend embedding LangGraph as a library,
  hosting app services + serving a local web UI on `localhost`. Interim debug view =
  LangGraph Studio via `langgraph dev` against the shared checkpointer (ADR-023).
- **Graph execution runs in a subprocess worker** (ADR-012), not in the app process:
  one disposable worker per run; the app supervises it over IPC. A worker crash/hang/
  exit fails only that run; resume spawns a fresh worker from the last checkpoint.
- **Kiro execution** is local: each `kiro_node` (inside the worker) spawns `kiro-cli acp`
  (one short session per node) with per-node MCP injection, using the user's local creds.
- **Checkpointer** = SQLite at `~/.genesis/genesis.db` (per-superstep snapshots) — makes workers disposable and resume checkpoint-driven.
- **All three HITL modes** rely on the checkpointer: gates (`interrupt()`),
  pause/resume (stop + resume from last checkpoint), and state injection (edit
  the checkpointed state, then resume).

---

## 7. Cross-cutting standards

1. **Reliability trio (HARD, Q9):** narrow agent node → validator → retry/escalate. Enforced in library CI.
2. **State small, bulk in blackboard (Q8).**
3. **MCP referenced by name from the shared registry (Q3);** secrets resolved at run time via SecretProvider.
4. **Contract-first (Q10):** every workflow exposes `build()` + `META`; the app never hard-codes a workflow.
5. **Determinism belongs to the graph, judgment to the agent.** If a step can be a program, it must be.
6. **No secrets in state, in the env registry, in git, or echoed to logs.**
7. **Pinned refs (Q10):** installed workflows are version-pinned; updates are explicit.

---

## 8. Technology choices (proposed; confirm in Phase 1)

| Concern | Choice | Notes |
|---|---|---|
| Language (platform + workflows) | **Python 3.13** (pin) | Spike-verified; langgraph 1.2.8 runs on 3.13 & 3.14, 3.13 chosen for wheel-ecosystem support (ADR-024) |
| Engine | LangGraph v1 (`langgraph` 1.2.8) | graph API + checkpointer + interrupts + streaming; **async execution** (ADR-024) |
| Checkpointer | `AsyncSqliteSaver` (`langgraph-checkpoint-sqlite` + `aiosqlite`) | local durable state; async (agent nodes are async — ADR-024) |
| Backend/API | FastAPI (embeds LangGraph as a library) | serves local web UI + run/catalog/config APIs; NOT a LangGraph Server (ADR-023) |
| Interim UI | LangGraph Studio | Phase 5 |
| Custom UI (Phase 7) | Preact + esbuild (reuse solutions-copilot webview stack) or React | local web app |
| Agent runtime | `kiro-agent-sdk` (ACP) | per-node sessions |
| Secrets | SecretProvider (plaintext 0600 → keychain) | reused concept |
| Distribution | GitLab REST v4 + lockfile | reused concept |

---

## 9. Glossary

- **Workflow** — a LangGraph package that automates one SDLC task (former "skill").
- **Node** — a step; program / agent / cli / validator / hitl_gate / subgraph.
- **Agent node** — a narrow Kiro turn over ACP with injected MCP.
- **Blackboard** — the per-run artifacts folder for bulk data + handoff.
- **MCP registry** — shared file mapping server name → launch config + secret keys.
- **Catalog** — the projected, user-facing list of installable workflows.
- **Lockfile** — installed workflows + pinned refs on a machine.
- **HITL** — human-in-the-loop; gates, pause/resume, state injection.
- **Reliability trio** — agent node + validator + retry/escalation.
