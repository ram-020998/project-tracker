<!-- GENESIS BIBLE — CHUNK 02. DO NOT summarize or drop content when editing; keep it verbatim-faithful. -->
> **This file is one chunk of the Genesis bible.** The bible is split across `bible/` and indexed by
> [`../AGENT_ONBOARDING.md`](../AGENT_ONBOARDING.md). **When asked to "read the bible", read the index AND every
> chunk it lists, then follow all of it religiously.** This chunk holds: **§3 Architecture — the mental model (layers, reliability trio, state/blackboard, subprocess workers, data plane, HITL, release/versioning).**
> Section numbers (§0–§10) are the ORIGINAL bible sections and are preserved here; the §→chunk map lives in the index.

---

## 3. Architecture (the mental model)

**Layered, agents never orchestrate.** LangGraph owns all control flow (ADR-001). A workflow's graph
is deterministic; agent nodes are narrow Kiro turns.

- **`kiro-agent-sdk`** — the ACP adapter to Kiro (the only thing that talks to the agent runtime).
- **`genesis-core`** — the shared engine/SDK: node factories (program/agent/cli/validator/gate/
  subgraph/reliability), `PlatformState` + reducers, `RunWorkspace` blackboard, the MCP/CLI registries
  (two-tier), the validator toolkit, and the `PlatformContext` injected into every node. `CORE_MAJOR`
  is the compat-gate key (ADR-019).
- **`genesis`** — the platform: async engine + checkpointer, distribution (GitLab pull/install/
  lockfile/loader), config + secrets + environments + health, the run manager + subprocess supervisor,
  the `db/` persistence/migration layer, the FastAPI app (`/api` + SPA), the CLI, the lint gates
  (contract parity + reliability trio), and the React+TS web app.
- **`genesis-workflows`** — the library: `registry.json` catalog, `mcp-registry.json`/`cli-registry.json`,
  bundles, steering docs, the workflows, and the 7-gate CI publish runner.

**The reliability trio (ADR-011, CI-enforced):** every agent node is wrapped by a program **validator**
+ **retry** + **escalation-to-HITL-gate** on exhaustion. Enforced statically by `genesis/lint/reliability.py`.

**State / blackboard rule (ADR-010/018/022):** LangGraph state is small, serializable, and
human-**editable** (pointers + decisions). Bulk data lives in the per-run `RunWorkspace` blackboard
under `$GENESIS_ARTIFACTS_DIR`. Never inline bulk data in state or chat.

**Subprocess-worker execution (ADR-012):** the graph runs in a disposable subprocess worker, not the
app process. Pause = kill worker; resume = fresh worker from the checkpoint. The app process never
imports workflow Python — only the worker does (standalone `importlib` on `graph.py`).

**Data plane (SQLite):** runs, the full agent conversation, and LangGraph checkpoints live in
`~/.genesis/genesis.db` (WAL). Only bulk artifacts are files. Schema is owned by `genesis/db/` — a
`Database` connection factory + a forward-only migration runner (`schema_migrations` table). The
durable `run_events` log is the source of truth for a run's timeline/conversation; the in-memory
`EventBus` is only live fan-out (SSE). Retention can reclaim terminal runs' events + blackboard.

**HITL (all 3 modes, ADR-021/025):** (1) designed approval/escalation/pre_mutation gates via
`interrupt()`; (2) ad-hoc pause/resume anywhere; (3) mid-run state injection + fork (seed a new thread
from a past checkpoint, original untouched).

**Release/versioning (ADR-019):** git+ssh tag pins along `genesis → genesis-core → kiro-agent-sdk`;
`CORE_MAJOR` (currently 1, distinct from pip version) is the hard compat gate the loader enforces
(refuse-to-load on mismatch; additive-only within a major).

---

