# 00 — Genesis Code Review (Phase-7 Checkpoint)

**Date:** 2026-07-11 · **Reviewer basis:** direct reads of `kiro-agent-sdk`, `genesis-core`,
`genesis` (app **v0.11.0**), and `genesis/web`, plus the planning docs (`tracker.md`, `specs/`,
`reference/decision-log.md`). **Scope:** architecture, data plane, MCP/CLI configurability, UI
completeness, standards/quality. **Posture unchanged:** local, single-user (ADR-012/023/026/027).

> Every finding below cites the file/function it was verified against. Where something was
> **not** independently re-verified (e.g. a fresh full test run), it is stated.

---

## 1. Executive summary

**The architecture is genuinely strong and the foundation is more solid than the initiating
concerns assumed.** Two of the three concerns that prompted this review rest on a misreading of
the current implementation; the third is a real, largely-unbuilt gap.

1. **"Data is stored as simple JSON files."** — **Incorrect.** Run lifecycle, the full agent
   conversation, and graph checkpoints are in **SQLite** (`~/.genesis/genesis.db`, WAL). Only
   *bulk artifacts* are files, by deliberate design (ADR-010/018). The right question is
   **SQLite vs Postgres** and whether the SQLite *implementation* is a solid foundation — it is
   functional but under-abstracted (no migrations).
2. **"We should be able to add MCP servers/CLIs from the app."** — **Correct; this is the real
   gap.** The registries are read-only manifests installed from the library; there is no
   add/edit/allowlist capability in the app.
3. **"The Overview/home screen isn't wired."** — **Correct and confirmed.** The backend
   `GET /home` exists; the frontend renders static placeholder data.

Overall grade: **strong foundation with a few sharp edges** — well above typical for the stage.

---

## 2. Architecture assessment

### 2.1 What is strong (verified)
- **Clean layering + hard isolation boundary.** `kiro-agent-sdk` (ACP transport) →
  `genesis-core` (nodes/state/registries/validators) → `genesis` (FastAPI app, run manager,
  config, dist) → `genesis-workflows` (manifest library). The **app process never imports
  workflow Python** — all graph execution happens in a subprocess `worker` supervised over
  JSONL stdout (`genesis/runs/supervisor.py`, ADR-012). Workflow crashes/hangs cannot take
  down the server; pause = kill the worker.
- **Durable-first HITL.** `RunManager.pending_gate()` (`genesis/runs/manager.py`) reads the gate
  from the durable event log, **falling back to reconstructing it from the checkpoint's pending
  interrupt** (`_gate_from_checkpoint`) when the log is cold. Approvals survive restarts.
- **Semver compat gate** (ADR-019) between core and workflows; **fork = new thread** (ADR-025).
- **Async engine** (ADR-024): `AsyncSqliteSaver` + `aiosqlite`.
- **Frontend** on a standard, enterprise-grade stack (ADR-027): React 18 + strict TS, TanStack
  Query with an `EventSource→Query` SSE bridge, React Flow, Zustand, shadcn/Radix, MSW tests,
  jest-axe.

### 2.2 Sharp edges (each has a spec in this package)
- No DB migration framework / persistence abstraction (→ `01`).
- Overview screen unwired (→ `02`).
- No MCP/CLI extensibility from the app (→ `03`).
- Dual event bus + unbounded event log (→ `04`).
- Conversation tab plain-text, non-unified thinking (→ `06`).

---

## 3. Data plane — the truth, and the real work

### 3.1 As-built (verified)
- **`genesis/runs/eventlog.py`** — `EventLog` writes a SQLite table `run_events`
  (`seq INTEGER PRIMARY KEY AUTOINCREMENT, run_id, node, kind, payload TEXT, ts`), indexed
  `ix_run_events_run (run_id, seq)`, WAL + `busy_timeout=30000`. Append-only, monotonic `seq`.
- **`genesis/runs/store.py`** — `RunStore` writes a `runs` table (lifecycle: status, cursor,
  inputs, artifacts_dir, timestamps) with a defensive transition guard `_ALLOWED`.
- **`genesis/runtime/checkpoint.py`** — LangGraph `AsyncSqliteSaver` on the same `genesis.db`.
- **`genesis-core/workspace.py`** — the **blackboard**: bulk artifacts as files under
  `~/Genesis/runs/<wf>/<run>/`. State holds pointers only (`genesis-core/state.py`, ADR-010/018).

**The agent conversation is durably persisted, not just streamed.** In
`RunManager._spawn.on_event` (`manager.py`), every worker `custom` event whose `type` ∈
`_CANONICAL_CUSTOM` — `{agent.message, agent.thought, agent.tool_call, agent.tool_update,
agent.result, validator.result, retry.scheduled, telemetry}` — is written via `self._log()` →
`eventlog.append(...)`. The transcript is rows in `run_events`, replayable after restart. This
is why Run-Detail conversation survives reloads.

**Config is file-based JSON** (reasonable for config, not run data): `secrets.json` (0600,
`config/secrets.py`), `mcp-registry.json` / `cli-registry.json` (library), `installed.lock.json`,
`environments.json`.

### 3.2 The SQLite-vs-Postgres question — already partly decided
The decision log already reasoned about this: ADR-024 chose local SQLite; ADR-026/027 record
that **multi-user/hosted is a separate track** (auth/RBAC, vault secrets, hosted execution).
**Verdict:** for local single-user, **SQLite is correct** and will not be the bottleneck
(single-writer, append-only, indexed by `run_id` — its sweet spot). See `05` for the explicit
triggers that would justify Postgres (multi-user; or pgvector for transcript search/RAG).

### 3.3 The real data-layer debt (this is what `01` fixes)
1. **No migration framework — #1 foundational risk.** Persistence is **raw `sqlite3` with
   hand-written `CREATE TABLE IF NOT EXISTS` in three places** (`eventlog.py`, `store.py`,
   checkpointer). No Alembic/SQLAlchemy (confirmed absent in both `pyproject.toml`s), no schema
   version, no single owner. Any future column/index = ad-hoc `ALTER TABLE` with no rollback.
2. **No persistence abstraction.** SQL is inlined per module; a future Postgres move (or even a
   shared connection/PRAGMA policy) is a rewrite rather than a config change.
3. **Transcript-size hygiene.** Agent messages are stored inline in `payload TEXT`. Fine now;
   a chatty agent over thousands of runs bloats `run_events`.
4. **No automated event-log retention.** `EventLog.purge(run_id)` exists but nothing schedules
   it (`04`). Artifact retention is specced (ADR-022) but transcripts grow unbounded.
5. **Dual event bus = live debt.** `RunManager` runs `_buses` (legacy interim UI) + `_cbuses`
   (canonical) + the durable log. Remove `_buses` at the 07-10 cutover (`04`).

**Bottom line:** the "reliable DB" you want already exists. Redirect the energy to
**migrations + a persistence abstraction + retention** — that is what makes the DB a foundation.

---

## 4. MCP/CLI configurability — the real gap (→ `03`)

### 4.1 As-built (verified)
- **`genesis-core/mcp/registry.py`** — `McpRegistry` **loads** `mcp-registry.json` and resolves
  `${VAR}` from the `SecretProvider` at launch (per-node injection, ADR-004). It has
  `load()`/`from_dict()` but **no `save`/`add`/`write` — read-only.** Same for `CliRegistry`
  (`clis/registry.py`).
- The registry file is **installed from `genesis-workflows`**; governance is ADR-005 ("shared
  registry") + "adding a server = editing the registry via MR — no platform code change" +
  ADR-020 ("no global Kiro mutation").
- **Settings UI (07-04)** only renders cards for servers **required by installed workflows**,
  lets you **set their secrets** (`config/service.py::set_secret`), and runs a **readiness
  probe** (`test_server` — checks "secret present + docker on PATH", explicitly *not* a live
  handshake). The API (`genesis/api/app.py`) has **no** add/edit/delete-server route (full route
  list verified).
- **Tool allow-listing exists only at authoring time**: `kiro_node(tools=[...])`
  (`genesis-core/nodes/agent.py`) → the SDK's `trust_tools`/`trust_all_tools`
  (`KiroAgentOptions`). There is **no** UI to see a server's tools or mark which are allowed, and
  **no tool introspection** anywhere.

### 4.2 The gap vs the vision
None of the four asks exist: (1) add a custom server from the frontend, (2) a JSON-config code
editor, (3) per-server secrets for arbitrary servers, (4) see-and-allowlist a server's tools.

### 4.3 The tension to resolve
The vision **revises ADR-005/020**: today's registry is a curated, MR-governed, reproducible
artifact — deliberately *not* user-editable. The clean reconciliation (specced in `03`) is a
**two-tier registry**: Tier-1 curated (read-only, from the library) + Tier-2 custom
(user-writable, local, edited from the UI), resolved by name across both. This preserves ADR-005
for shared workflows while enabling local modularity.

---

## 5. UI completeness

- **Overview/home — unwired (confirmed).** `web/src/app/routes/Overview.tsx` renders **static
  placeholder data** (hardcoded `TREND`, `"—"` metrics, "work in progress" empty state) and its
  own comment says "Real data wiring (GET /home) lands with the Overview spec work." The backend
  `GET /home` **exists** (`app.py`, returns `{installed, recent_runs, health}`). The screen was
  *defined* in spec `07-01 §7` but its implementation slipped when the sub-series went 07-03 →
  07-10. **High-value quick win** (→ `02`): endpoint, design, and components already exist.
- **MCP readiness test is not a live handshake** (`config/service.py::test_server`) — upgraded in `03`.
- **Otherwise complete:** Runs, Run-Detail (graph + HITL + conversation + documents), Catalog,
  Settings all appear fully built per their progress docs + file structure. *Not independently
  re-run this session* — reporting structure + code, not a fresh green test run.

---

## 6. Standards & quality

**Good:** strict TS + `noUnusedLocals`; `ruff` + custom contract/reliability lints
(`genesis/lint/`); MSW + jest-axe frontend tests; disciplined secret model (values never leave
`ConfigService`; only key names/booleans surface; 0600 file); fail-fast MCP var resolution before
spawning Kiro; telemetry schema present from day one with `credits` honestly marked best-effort.

**Debt register (prioritized):**

| # | Item | Where | Severity | Spec |
|---|------|-------|----------|------|
| 1 | No DB migration framework / schema owner | `runs/*.py` raw DDL ×3 | **High** | 01 |
| 2 | No frontend MCP/CLI extensibility | `config/*`, `mcp/registry.py`, Settings | **High** | 03 |
| 3 | Overview unwired to `/home` | `app/routes/Overview.tsx` | Medium | 02 |
| 4 | Dual event bus (`_buses` + `_cbuses`) | `manager.py` | Medium | 04 |
| 5 | No automated `run_events` retention | `eventlog.py` | Medium | 04 |
| 6 | MCP `/test` is readiness-only | `config/service.py` | Low/Med | 03 |
| 7 | Conversation plain-text, scattered thoughts | `run-detail/components/inspector/Conversation.tsx` | Medium (UX) | 06 |
| 8 | Secrets are plaintext JSON (Keychain roadmap) | `secrets.py` | Low (acceptable local) | — |
| 9 | `.DS_Store` committed | multiple repos | Trivial | — (gitignore) |

---

## 7. Prioritized roadmap

- **P0 — foundation hardening (before piling on features):** `01` persistence/migrations; `02`
  wire Overview.
- **P1 — capability:** `03` Integrations Studio (the modularity vision); `06` conversation rich
  chat (self-contained frontend win).
- **P2 — hardening/decision:** `04` retention + bus cleanup; `05` Postgres/pgvector decision
  (only when a trigger fires).

Each item has a dedicated, implementation-ready spec in this package.

---

## 8. Non-goals (whole program)
- No authentication/authorization/multi-tenancy (ADR-026 unchanged).
- No change to the execution model (subprocess worker, ADR-012), secrets posture (ADR-013), or
  the small-state + blackboard rule (ADR-010/018).
- No migration to Postgres in this program (only the decision framework in `05`).
