# Genesis — Decision Log (ADRs)

Formal record of the locked decisions (Q1–Q14 from the design walkthrough) plus
foundational technical decisions. Each entry: **Decision · Context · Alternatives
considered · Rationale · Consequences.** Status: all **Accepted** unless noted.

---

## ADR-001 — LangGraph as the orchestration engine (not an LLM orchestrator)
- **Decision:** Control flow is owned by LangGraph; agents only perform narrow steps.
- **Context:** solutions-copilot used an LLM agent to orchestrate multi-step skills; it skipped steps and didn't follow the workflow. Its own doc-19 concluded durable external orchestration was needed and named LangGraph.
- **Alternatives:** (a) keep agent-as-orchestrator with better prompts — rejected (structural failure, not prompt-fixable); (b) Temporal / OpenAI Agents SDK / Anthropic Managed — viable but LangGraph is Python-native, has first-class HITL + checkpointing + streaming, and matches our stack; (c) custom Python orchestrator (what the ERD POC was) — works but reinvents durability/HITL/branching.
- **Rationale:** Determinism of sequencing must not depend on a model. LangGraph gives durable execution, HITL, streaming, branching, subgraphs out of the box.
- **Consequences:** Workflows are Python graphs; authoring is a dev task (mitigated by scaffolder + steering + agent-assisted authoring).

## ADR-002 — Kiro via `kiro-agent-sdk` over ACP as the agent runtime
- **Decision:** Agent nodes drive Kiro through the ACP-based `kiro-agent-sdk`.
- **Context:** We need the real Kiro agent + its MCP tools callable from Python; Kiro CLI is proprietary-licensed (no fork).
- **Alternatives:** (a) headless `--no-interactive` — loses structured events + reliable completion/error signals; (b) Strands Agents SDK — a *different* agent, not Kiro's; (c) raw Bedrock — reimplement the agent loop.
- **Rationale:** ACP gives a structured event stream (tool calls, clean `end_turn`/errors), per-session MCP injection, and it's a supported public surface. Already built + validated.
- **Consequences:** One short-lived ACP session per agent node; cost/latency to watch (session-pool later if needed).

## ADR-003 (Q1) — Local web app; shared GitLab library; internal Solutions users
- **Decision:** Engine + Kiro/MCP run locally with the user's creds; workflows pulled from a shared GitLab repo; users are internal Dev/Tester/PO/UX.
- **Alternatives:** hosted shared service (server-side Kiro + API-key auth) — more infra, creds centralization; hybrid — deferred.
- **Rationale:** Uses each engineer's existing creds/MCP access; no central execution infra; matches the solutions-copilot per-user model.
- **Consequences:** Per-machine setup (config UI, secrets). No multi-user server in scope.

## ADR-004 (Q2) — Per-node MCP injection (not globally-installed agents)
- **Decision:** Each agent node opens an ACP session injecting only the MCP server(s) it needs; session closes after the step.
- **Alternatives:** globally pre-installed MCP-specific agents (context-clean but hidden global state + drift); one generic agent with all MCP (context bloat + tool-selection degradation).
- **Rationale:** Same context hygiene as per-MCP agents, but versioned with the workflow and drift-free; already proven (ERD → Atlas).
- **Consequences:** Genesis never writes a global Kiro `mcp.json` (sidesteps solutions-copilot BL-4 overwrite problem).

## ADR-005 (Q3) — Shared MCP registry, no "profiles"
- **Decision:** A shared registry defines how each MCP server launches + its secrets; nodes reference servers by name + carry their own prompt/tools. No standalone profile abstraction.
- **Context:** "Profile" conflated *server launch config* (needs one shared place) with *node usage* (prompt is workflow-specific anyway).
- **Alternatives:** blessed profile catalog; free-form per-workflow profiles.
- **Rationale:** The registry is the only necessary shared thing; a node reference *is* its configuration. YAGNI on profiles (revisit only if node configs duplicate, e.g. shared write-capable safety preamble).
- **Consequences:** Simpler; MCP secrets standardized in one registry.

## ADR-006 (Q4) — Self-contained workflow packages; selective install + lockfile
- **Decision:** Each workflow is a folder package (`workflow.yaml` + `graph.py`); a `registry.json` is the catalog; users selectively install workflows, pinned by ref in a lockfile.
- **Alternatives:** whole-repo clone (simpler, but everyone gets everything); monolithic app with built-in workflows (not pluggable).
- **Rationale:** Multiple personas need different subsets; pinning gives reproducibility + explicit updates.
- **Consequences:** Installer-style machinery (GitLab client, lockfile, update detection) — reused from solutions-copilot.

## ADR-007 (Q5) — Role = filter tag + curated bundles; cross-role picking allowed
- **Decision:** Workflows tag `roles`; catalog filters by role; bundles ("Tester set") for onboarding; no hard gating — users pick across roles.
- **Rationale:** Internal trusted team; multi-hat users; discoverability without restriction.

## ADR-008 (Q6) — Single app; LangGraph Studio interim, custom workbench later
- **Decision:** One local app bundles engine + UI; validate on Studio first, build the bespoke workbench after (Phase 7).
- **Rationale:** De-risk orchestration reliability before investing in bespoke UI; Studio gives run visualization + HITL + time-travel for free.

## ADR-009 (Q7) — All three HITL modes are required
- **Decision:** (1) designed approval gates, (2) ad-hoc pause/resume anywhere, (3) mid-run state injection — all v1.
- **Consequences:** Durable per-superstep checkpointing and an editable state model are load-bearing from day one (drives ADR-011).

## ADR-010 (Q8) — Small editable state + per-run blackboard + SQLite checkpointer
- **Decision:** LangGraph state holds only small serializable data (metadata, artifact pointers, decisions, status); bulk artifacts live in a per-run blackboard folder; checkpointer is local SQLite.
- **Context:** Learned from the ERD POC — pushing bulk data through chat/state caused failures.
- **Rationale:** Small checkpoints (fast, resumable); makes state-editing HITL usable; mirrors solutions-copilot `.kiro/analysis` handoff.

## ADR-011 (Q9) — Reliability trio is a HARD requirement (CI-enforced)
- **Decision:** Every agent node must have a program **validator** + **retry** (configurable count) + **escalation to a HITL gate**; enforced by library CI at publish time.
- **Alternatives:** convention-only (not enforced) — rejected; this is the structural fix for "agents miss steps."
- **Rationale:** The program, not the agent, decides "good enough"; retries self-correct; escalation prevents silent garbage.
- **Consequences:** More work per workflow, made default by the scaffolder.

## ADR-012 (Q10, revised) — `build()` + `META` contract; validated in CI; run in a subprocess worker
- **Decision:** Every workflow exposes a static `META` and a `build(ctx)`; the Q9
  requirement is validated in library CI. **Graph execution runs in a subprocess
  worker** (one per run, or a small pool), not in the app process.
- **Context / why revised:** The original "run in-process" plan had two flaws
  (raised in review): (1) `except ImportError` contains **only Python exceptions**
  — not `sys.exit()`/`os._exit()`, C-extension segfaults, hangs, memory/thread
  leaks, or global-state monkeypatching; "never crash the app" was overstated;
  (2) the genesis-core version-skew problem (see ADR-019).
- **Why subprocess is not "heavy" here:** the dangerous work is **already
  out-of-process** (every agent node spawns `kiro-cli acp`; MCP = docker; CLIs =
  subprocess) — only orchestration glue ran in-process. And because state is
  checkpointed after every superstep, **workers are disposable and resume is
  checkpoint-driven, not memory-driven**: pause = kill the worker; resume = spawn
  a fresh worker that `resume(thread_id)` from the shared `genesis.db`. IPC surface
  is small (events out; respond/resume in). This aligns with the durability model.
- **Trust/containment:** the worker gives a **kill switch + resource limits** and
  isolates crashes/hangs/leaks/global-state mutation from the app + UI. Workflows
  are still internal + CI-validated + pinned; the worker is defense-in-depth, not a
  security sandbox against malice.
- **Alternatives:** in-process (rejected — no crash/hang isolation, containment
  overstated); per-workflow venv subprocess (deferred — only needed if divergent
  genesis-core majors are ever allowed; see ADR-019 escape hatch).
- **Consequences:** run lifecycle (Phase 5) orchestrates workers over IPC; the
  loader (Phase 3) enforces the genesis-core major-compat gate before spawning.
  Honest containment: in-process code (the app) is protected *because* execution
  is out-of-process; a worker crash fails the run, never the app.

## ADR-013 (Q11) — solutions-copilot retired; Genesis owns its config UI
- **Decision:** Genesis fully replaces solutions-copilot and ships its own config UI (GitLab token, MCP secrets, environments), reusing the *concepts* (SecretProvider, credential-free env registry, GitLab client) as fresh implementations.

## ADR-014 (Q12) — Authoring: scaffolder + test harness + agent-assisted + steering; open contribution
- **Decision:** A `create-workflow` scaffolder (reliability trio pre-wired), a local test harness, an agent-assisted authoring workflow, and authoring **steering** in the library; any Solutions engineer can contribute.
- **Rationale:** Lower the cost of authoring Python workflows; make doing-it-right the default path.

## ADR-015 (Q13) — Build the complete app + ERD first, then migrate skills one by one
- **Decision:** Phases 1–6 = complete application + ERD reference (Studio interim). Phase 7 = custom workbench. Phase 8 = ongoing skill→workflow migration.

## ADR-016 (Q14) — Name = Genesis
- **Decision:** Platform `genesis`; library `genesis-workflows`; SDK `kiro-agent-sdk`.
- **Rationale:** Origination of Appian solutions / start of the SDLC; layers cleanly above Kiro/Atlas/Jarvis.

---

## Technical ADRs (foundational)

## ADR-017 — Python 3.11+ across platform + workflows
LangGraph + `kiro-agent-sdk` are Python; one language for engine, nodes, workflows.

## ADR-018 — Blackboard handoff over inline data
Cross-agent/step data moves via files in the run's blackboard folder, referenced
by path in state. (Directly fixes the ERD POC's truncation/parse failures.)

## ADR-019 (revised) — `genesis-core` shared package + semver major-compat gate
- **Decision:** The node factories + validator toolkit + `RunWorkspace` + base
  state + `PlatformContext` are published as **`genesis-core`**, depended on by
  both the platform and every workflow (clean dependency direction; avoids drift;
  enables laptop authoring/testing without the full app).
- **Version policy:** `genesis-core` follows **semver**; **additive-only within a
  major** (API-stability contract). The platform pins an exact `genesis-core`; the
  library CI tests against that major.
- **Hard major-compat gate:** at runtime there is exactly one `genesis_core` (all
  workflows + the platform share it), so this is a **version-skew**, not an
  unsolvable coexistence, problem. The installed library ref declares the
  `genesis_core` **major** it targets; the loader (Phase 3) **refuses to load** any
  workflow/library ref whose major ≠ the platform's, with a clear message.
  Detection alone is insufficient — refuse-to-load turns skew into a safe failure.
- **Escape hatch (deferred):** if divergent `genesis-core` majors across workflows
  are ever required *simultaneously* (the true diamond), the only answer is
  per-workflow venv subprocess isolation. Not built now; documented as future.
- **Consequences:** lockfile records the `genesis-core` version/major; the loader
  gates on it before spawning a worker (ADR-012).

## ADR-020 — No global Kiro mutation
Genesis never installs global Kiro agents or writes a global `mcp.json`; all Kiro
interaction is per-node ACP sessions with injected MCP. (Consequence of ADR-004.)

## ADR-021 — `auto_approve` default posture for HITL- **Decision:** `META.auto_approve = true` by default — validated steps auto-advance; a run pauses **only** at three sanctioned classes: (a) author approval gates (`hitl_points`), (b) escalations (retry exhaustion), (c) pre-mutation (before write/deploy — **required**).
- **Context:** "keep gates rare" as advice is not enough; authors accidentally create approver fatigue (solutions-copilot doc-19 warning).
- **Alternatives:** confirm-every-step (fatigue); no default (inconsistent).
- **Rationale:** Make the safe posture the *system default*, enforced by the HITL lint (Phase 2), not author discipline.
- **Consequences:** Gates outside (a)/(b)/(c) fail CI; `pre_mutation` gates are mandatory before mutating MCP usage; `auto_approve=false` needs a documented reason.

## ADR-022 — Dedicated, configurable artifacts root + retention
- **Decision:** Bulk run artifacts live in a **dedicated, user-configurable artifacts root** (default `~/Genesis/runs/`, override via `GENESIS_ARTIFACTS_DIR`/config), **separate from `~/.genesis/`** (which keeps only small stable state: config, secrets, checkpoint DB, lockfile, library). Layout `<root>/<workflow_id>/<run_id>/`. Each run record stores its **absolute** `artifacts_dir`.
- **Context:** Per-run artifacts grow unbounded; bundling them in the app dir bloats it, risks filling the home partition, and complicates backup/relocation.
- **Alternatives:** keep under `~/.genesis/runs/` (rejected — mixes small state with unbounded data); no retention (unbounded growth).
- **Rationale:** Separate concerns; let users place bulk data on a big/external disk; enable safe pruning.
- **Consequences / rules:**
  - **Retention only prunes terminal runs** (done/failed/cancelled) — never running/paused/awaiting (state references those paths; resume would break).
  - Configurable policy: keep-last-N per workflow and/or delete-after-X-days; `intermediate` artifacts prunable sooner than `final` (roles in `META.artifacts`).
  - Disk usage tracked per run + root (soft cap + warning); manual purge from the workbench.
  - Relocation-safe via absolute `artifacts_dir` per run.

## ADR-023 — FastAPI backend embedding LangGraph; Studio is a dev harness only
- **Decision:** The Genesis local backend is a **FastAPI app** that embeds
  LangGraph as a **library** (compile/run graphs against the SQLite checkpointer)
  and exposes all run/stream/HITL/catalog/config APIs. Genesis is **not** built on
  a LangGraph Server. **LangGraph Studio** is used only as an interim
  developer/debug harness via `langgraph dev` pointed at the shared `genesis.db`.
- **Context:** Genesis is far more than a graph server — it has catalog, install/
  lockfile, config/secrets, environments, artifacts/retention, health. LangGraph
  Server is built to *serve graphs* and is opinionated; it can't host those concerns.
- **Alternatives:** LangGraph Server as the backend (rejected — can't own the
  non-graph concerns; too opinionated); no Studio at all (lose free visualization during M6).
- **Rationale:** FastAPI owns the app; LangGraph is a library dependency; Studio
  is a cheap debugging convenience we get because we're on LangGraph — not an
  architectural dependency. Phase 7's custom UI supersedes Studio.
- **Consequences:** We implement run/stream/HITL endpoints ourselves (already
  planned in Phase 5). Studio attaches via `langgraph dev` sharing the checkpointer.

> Naming note: the shared primitives package (ADR-019) is **`genesis-core`**
> (Python `genesis_core`), renamed from the earlier working name `genesis-common`.

---

## ADR-024 — Async-first engine (`AsyncSqliteSaver` + `aiosqlite`); Python 3.13 pin
- **Decision:** Genesis executes graphs via the LangGraph **async API**
  (`ainvoke`/`astream`) with the **`AsyncSqliteSaver`** checkpointer (dependency:
  **`aiosqlite`**). The subprocess worker (ADR-012) is an async entrypoint.
- **Context (spike, 2026-07-08):** `kiro_node` is async (`kiro-agent-sdk.collect()`
  is a coroutine). The Phase-1 spike proved (i) sync `invoke()` **cannot** run an
  async node (`TypeError: No synchronous function provided`), and (ii) the sync
  `SqliteSaver` raises `NotImplementedError` under async execution. So a
  consistent async execution path + async checkpointer is required, not optional.
- **Version pin:** **Python 3.13** (langgraph 1.2.8 verified on 3.13 and 3.14;
  3.13 chosen for full wheel-ecosystem support — FastAPI/uvicorn/native deps).
  Refines the "3.11+" placeholder in ADR-017.
- **Alternatives:** wrap `collect()` in `asyncio.run()` inside a sync node +
  sync saver (rejected — blocks the loop, fights LangGraph's async streaming,
  loses concurrency for `Send` fan-out).
- **Consequences:** `runtime/checkpoint.py` builds `AsyncSqliteSaver`;
  `runtime/engine.py` exposes `async run()/resume()`; add `aiosqlite` to deps.

## ADR-025 — Fork = seed a NEW thread (not in-thread time-travel)
- **Decision:** Genesis "fork from a past checkpoint" creates an **independent
  run (new `thread_id`)** by copying the chosen checkpoint's `values` into a new
  thread via `update_state(new_cfg, values, as_node="<producing_node>")`, then
  resuming it. The original run is left untouched.
- **Context (spike):** `update_state()` on a *past* checkpoint of a thread
  **branches within that same thread** (LangGraph time-travel rewinds the head) —
  which does not satisfy the spec's "original intact." The new-thread seeding
  pattern was validated in the spike.
- **Consequences:** `hitl-design.md` Mode 3 fork + Phase 5 `runs/hitl.py` `/fork`
  implement new-thread seeding; the run record links `forked_from={run_id, checkpoint}`.

---

## Open decisions (to resolve early — see tracker §5)
- **OD-1:** Does LCP MCP reliably author Appian objects? (Unblocks write-path/flagship workflows — Phase 8 spike.)
- **OD-2:** Does ACP honor `KIRO_API_KEY` for headless/CI contexts?
- **OD-3:** Session-pooling for many one-shot ACP sessions (perf) — measure first.

---

## ADR-026 — Web workbench stack: React + TypeScript (supersedes the Preact default)

**Status:** Accepted (2026-07-09) · **Context:** Phase 7.

**Decision.** Build the Phase-7 web workbench with **React + TypeScript** (Vite,
Vitest), not Preact as originally written in `specs/phase-07` §4.1.

**Why.** The product destination was clarified as **enterprise-grade** (while
remaining **local, single-user** — Q1/ADR-012/ADR-023 unchanged). React+TS gives a
larger enterprise ecosystem (component/data-grid/auth libraries), a bigger hiring
pool, first-class typing, and a cleaner path if a hosted/multi-user track is ever
opened. Preact remains technically capable but its `compat` shim adds friction with
heavy enterprise React libraries.

**Scope.** Frontend only. The backend stays a local FastAPI app driving
disposable subprocess workers against `~/.genesis/genesis.db`. No change to the
execution model, secrets, or auth posture. Bundle is built with Vite and the
compiled assets are committed so runtime needs no Node; `genesis serve` launches
the app.

**Consequences.** If enterprise **multi-user/hosted** is later pursued, that is a
separate architecture track (auth/RBAC, vault-based secrets, hosted execution) and
must re-open ADR-012/ADR-023 — the framework choice here does not, by itself,
deliver it.


## ADR-027 — Web revamp frontend stack (Tailwind + shadcn/ui + React Router + TanStack Query + React Flow)

**Status:** Accepted (2026-07-10). Extends ADR-026 (React+TS). Governs the Phase-7
web-revamp sub-series (`specs/phase-07-0N-*`).

**Decision.** Rebuild the web workbench on a standard, expandable React stack:
**Vite + React 18 + TypeScript (strict)**; **React Router v6** (data router) for
routing; **TanStack Query v5** for server-state (caching/polling/invalidation) with a
typed **`EventSource`→Query** bridge for live SSE; **Zustand** for client/UI state;
**Tailwind CSS + shadcn/ui** (Radix primitives, source owned in-repo) for the design
system; **React Flow (`@xyflow/react`)** for the workflow graph; **react-hook-form +
zod** for schema-driven forms; **react-markdown + mermaid + shiki** for document
preview; **Recharts** for telemetry; **lucide-react** for icons; **Vitest + RTL +
MSW** and **Playwright** for tests. The interim hand-rolled `web/` (hash router, raw
fetch, `theme.css`) is fully replaced.

**Why.** The interim workbench proved the API contract but is not an enterprise
foundation (no design system, no server-state cache, no route model, no component
library, shallow tests) and cannot absorb the planned features. The chosen libraries
are the boring, widely-adopted, TypeScript-first standards; shadcn/ui gives a bespoke
"Overcut-class" look while keeping component source in-repo (no kit lock-in); React
Flow is the standard for interactive DAG visualization (the run-detail centerpiece);
TanStack Query removes the manual effect/poll code that caused the SSE reconnect bug.

**Scope.** Frontend only. Backend stays a local FastAPI app driving disposable
subprocess workers (ADR-012/023/024). **Local single-user only** — no auth/RBAC/
multi-tenancy (ADR-026 unchanged); the UI may reserve a user-menu slot but must not
implement auth. The production bundle is built with Vite and **committed** to
`web/static/` so runtime needs no Node.

**Consequences.** Larger frontend dependency surface (managed via the frontend CI
job: lint + typecheck + test + build + stale-bundle guard). The revamp is **full-
stack**: the run-detail vision (live Kiro conversation, live graph, document preview,
durable HITL gates) requires backend/core/SDK data-plane work (`specs/phase-07-02`) —
persistent event log, gate-from-checkpoint, ACP conversation streaming, topology and
artifact-content endpoints. If hosted/multi-user is ever pursued, that remains a
separate track re-opening ADR-012/023.
### ADR-027 addendum (2026-07-10) — Overcut visual study

After a first-hand study of the Overcut app (19 screenshots of dashboard/executions/
mcp/skills/agent-roles/workflow-builder/audit screens), the visual direction was made
concrete in `specs/phase-07-03a-visual-language-reference.md`. Genesis **adopts
Overcut's vocabulary** (near-black calm surface, metric cards with oversized display
numerals + date-range/group-by/auto-refresh, master-detail config, category-chip card
catalogs, node-card canvases, status pills/dots, tool chips, grouped sidebar) and
**innovates on top** where Genesis is stronger: the **live run is the hero** (live
node-status graph + timeline), a **per-node Kiro conversation** inspector (vs.
Overcut's single global chat), first-class **HITL controls**, and a **document preview
drawer**. Genesis remains local single-user (no projects/billing/agent-role authoring).
Stack (ADR-027 body) is unchanged; this addendum only fixes the visual language.


### ADR-028 (2026-07-11) — Backend API namespaced under `/api` + SPA history fallback

**Status:** Accepted · **Context:** phase-07-04 bring-up (M7.1).

**Context.** The revamped web app uses a **browser (history) router** (ADR-027), so its
client-side routes are real URL paths: `/runs`, `/catalog`, `/settings`, `/runs/:id`, …
The Phase-5 backend served its REST API at those same root paths (`GET /runs`,
`GET /catalog`, `GET /config/*`, …). This is a direct **path collision**: a browser
request to `/runs` is ambiguous between "the SPA route" and "the API endpoint". It broke
two ways during 07-04 dev: (a) the Vite dev server (`:5173`) has no reason to forward
`/config/*` to the backend (`:8760`), so a relative `fetch` hit the SPA fallback and got
HTML instead of JSON; (b) even with a proxy, proxying `/runs`/`/catalog` would shadow the
client routes and break full-page refreshes on them.

**Decision.**
1. **Namespace the entire backend API under `/api`.** All endpoints move onto a FastAPI
   `APIRouter` included with `prefix="/api"` (`/api/config/*`, `/api/runs/*`,
   `/api/workflows/*`, `/api/catalog`, `/api/home`, `/api/artifacts/*`, incl. the SSE
   streams). `/docs` + `/openapi.json` are unaffected.
2. **SPA history fallback.** A catch-all `GET /{full_path:path}` serves `index.html` for
   any non-`/api`, non-`/assets` path (returning 404 for unknown `api/`/`assets/` paths),
   so browser-router deep links and refreshes resolve to the SPA shell — in production,
   same-origin, no server config needed.
3. **Frontend** talks to `/api` centrally: the typed client prepends the base once; the
   Vite dev proxy forwards a single `/api` → `:8760`. Same-origin preserved (ADR-026).

**Consequences.**
- The **interim served bundle** (`genesis serve` → the committed `web/static/`) calls the
  old root paths and therefore **no longer reaches the API** after this change. This is
  accepted: the interim UI is already superseded and is **retired at the 07-10 cutover**;
  the new app is developed via `npm run dev` + a running `genesis serve` backend. The API
  itself (and `/docs`) is fully functional at `/api`.
- Released in **genesis v0.9.0**. Purely a path move for our own single-user client — no
  external consumers. Regression tests: `test_spa_history_fallback` +
  `/api`-prefixed call-sites across the API test suites.
- This also de-risks the 07-10 cutover: production static-serving already resolves client
  routes via the fallback.

---

### ADR-029 — Two-Tier MCP/CLI Registry (revises ADR-005/020)

**Status:** Accepted (2026-07-11) · **Revises:** ADR-005 (shared registry), ADR-020 (no global mcp.json)

**Context:** Genesis resolves MCP servers and CLIs from a single read-only manifest installed from
the `genesis-workflows` library. Users cannot add custom integrations from the app — they must MR
into the shared library. This blocks experimentation and per-user MCP servers (e.g. local dev tools,
team-specific APIs).

**Decision:** Genesis resolves integrations from **two layers**:
- **Curated (Tier-1):** the library's `mcp-registry.json` / `cli-registry.json` — reproducible,
  MR-governed, **read-only in the app**. Preserves ADR-005 for shared workflows.
- **Custom (Tier-2):** a **user-writable** local store (`~/.genesis/mcp-custom.json`,
  `~/.genesis/cli-custom.json`). Editable from the Settings UI via CRUD API.

Resolution merges by name; a custom entry with the same name **overrides** the curated one (with a
visible "overrides curated" flag in the UI). ADR-020 is preserved: Genesis still never writes a
global Kiro `mcp.json` — custom servers are injected per-node via `acp_servers`, exactly like
curated ones.

**Tool allowlist (new):** Each server may declare a `tool_allowlist` (list of tool names). At
runtime, effective trust = `node.tools ∩ server.allowlist` — the server allowlist is a hard cap
a workflow node cannot exceed. This is a safety improvement over the pre-029 model (node-only trust).

**Tool introspection (new):** `genesis-core/mcp/introspect.py` speaks MCP JSON-RPC 2.0 directly
(stdio) to discover tools from a server without Kiro. The upgraded `test_server` uses this for a
real handshake.

**Security:** A custom MCP server is an arbitrary local command run with the user's privileges.
This is acceptable for a local single-user tool but is surfaced in the UI with a warning. Secret
values flow through the existing `SecretProvider` (0600, scope/VAR) — never exposed by any API.

**Consequences:**
- `McpRegistry.from_layers(curated, custom)` replaces `McpRegistry.load()` in the config layer.
- Custom servers appear in cards, health, and per-node injection automatically.
- `missing_secrets()` and `health()` remain scoped to *installed* (workflow-required) servers.
- The `CustomMcpStore`/`CustomCliStore` interface is the seam for a future DB migration (spec 05).
- stdio transport only in v1; HTTP/remote MCP is a documented follow-on.

---

## ADR-030 — Persistence engine: SQLite now, Postgres/pgvector only on an explicit trigger

**Status:** Accepted (2026-07-13) · **Formalizes:** spec `05-p2-persistence-scale-decision.md` ·
**Relates:** ADR-010 (small state + blackboard), ADR-024 (async SQLite saver), ADR-026 (local
single-user posture), ADR-012/023 (embedded engine + subprocess worker).

**Context:** Run lifecycle, the full agent conversation (`run_events`), and LangGraph checkpoints
live in a single local `~/.genesis/genesis.db` (SQLite, WAL). Bulk artifacts are files; config is
JSON files. Spec 01 refactored the repositories onto a `genesis/db/` layer with **DB-agnostic
signatures** + a migration runner. The recurring question — "should we move to Postgres/pgvector?"
— needs an answer anchored in triggers, not vibes.

**Decision:** **Remain on SQLite.** For a local, single-user app this is the correct zero-ops
choice: the access pattern (single writer; append-only `run_events`; reads by `run_id`) is SQLite's
sweet spot and scales to millions of rows. Do **not** adopt Postgres "to be safe" — premature
adoption imposes ops cost with no single-user return. Re-open this decision only when one of the
triggers below fires, and write the adoption ADR **at that point**.

**Triggers (any one re-opens the decision):**
1. **Multi-user / hosted / concurrent writers** — SQLite's single-writer model is the wall. This is
   a whole track (auth/RBAC, secrets vault, hosted execution) that re-opens ADR-012/023/026, not a
   mere DB swap.
2. **Semantic search / RAG over transcripts & runs** — the most probable, lowest-drama trigger.
   `pgvector` is the durable home for embeddings; this is the likeliest reason to adopt Postgres.
3. **Heavy cross-run analytics** beyond the bounded `/home` aggregates (spec 02) — large JSONB
   querying, concurrent dashboards, reporting.

**Migration path (when a trigger fires):** (a) re-home repositories onto SQLAlchemy Core + Alembic
(portability + autogenerate); (b) swap `runtime/checkpoint.py`'s `AsyncSqliteSaver` →
`langgraph-checkpoint-postgres` (isolated behind one factory); (c) one-shot export/import
(runs + run_events) via a `genesis db migrate-to-postgres` command — the append-only shape makes
this straightforward; (d) for trigger 2, add a pgvector `embeddings` table keyed by
`(run_id, node, seq)` + a retrieval API (specced separately as a feature); (e) revisit the secret
store (Keychain/vault) as part of the hosted track.

**Consequences:**
- Repository return values stay **DB-agnostic** (no SQLite-only types leak to callers) so the seam
  spec 01 created remains cheap to cross.
- Estimated effort if trigger 1-sans-search fires: ~2–4 days (Core/Alembic re-home + checkpointer
  swap + data migration + CI Postgres service), low risk if the abstraction held. pgvector search
  and hosted/multi-user are each separate, larger initiatives.
- No code changes result from this ADR today — it records the standing decision and the guardrail.

---

## ADR-031 — Chat is a read-only conversational assistant (never orchestrates)

**Status:** Accepted (Phase 10). **Context:** Genesis gains a **Chat** page — a persistent, multi-turn
Kiro conversation that (1) answers using the `appian-atlas` read MCP and (2) answers about the
platform's own state (runs, failures, progress, workflows, health) via a new read-only
Genesis-introspection MCP server. A free-form chat agent is the same shape that sank the retired
solutions-copilot (LLM-as-orchestrator, ADR-001), so the boundary must be explicit and **enforced**.

**Decision.** Chat is an **assistant / observability co-pilot, not a controller**: it **observes and
answers**, it never drives or mutates anything. LangGraph still owns all *workflow* control flow
(ADR-001 intact); Chat is a parallel **read-only** surface that cannot influence it.

**Hard boundary (enforced, not merely prompted):** no run control (start/pause/resume/cancel/fork/
respond-to-gate), no config/secret/workflow mutation, no fs writes, no terminal, no CLI, no deploy;
tools limited to the Atlas **read** allowlist + the read-only introspection tools.

**Enforcement (defense in depth), priority order:**
1. **Capability restriction** — the ACP session runs with `trust_all_tools=False` and a `trust_tools`
   allowlist of read tools only. *Spike finding (10-01): kiro-cli matches MCP tools by the namespaced
   name `@<server>/<tool>`* — so the allowlist is built as `@appian-atlas/<tool>` + `@genesis/<tool>`.
2. **Permission auto-deny** — the SDK runs with the new `permission_mode="auto_deny"` (10-01), so any
   non-trusted tool the agent attempts (which triggers `session/request_permission`) is denied, not
   auto-approved (the default). Validated live against kiro-cli 2.12.1.
3. **No fs-write capability** — `allow_fs_write=False` refuses `fs/write_text_file` and advertises
   `clientCapabilities.fs.writeTextFile=false`.
4. **Read-only data source** — the introspection server opens `genesis.db` with a read-only
   connection (`file:…?mode=ro`) and exposes only SELECT-backed tools; secret-looking values redacted.
5. **Steering** — a chat persona reiterating the read-only contract (secondary reinforcement only).

**Execution model.** Chat runs **in-process** (an async `ChatManager` holding one persistent
`KiroACPClient` per live session). ADR-012's subprocess isolation exists to keep *workflow Python*
out of the app process; Chat executes no workflow code, and the agent is already isolated as the
kiro-cli subprocess the SDK spawns. A bespoke chat "worker" would add complexity with no isolation
benefit.

**Persistence.** Sessions + transcripts persist in `genesis.db` (migration m0002: `chat_sessions` +
`chat_messages`, FK cascade on delete). Kiro conversation state lives in the (ephemeral) kiro-cli
subprocess; on a cold client (app restart / idle-reap) a bounded transcript **preamble** is replayed
to recover context (best-effort). Single-user/local (ADR-026); Atlas-only MCP for v1.

**Consequences.** If Chat is ever given a mutating action, this ADR must be revisited — that would
re-open the copilot-orchestrator failure mode ADR-001 exists to prevent. Live-verified end to end
(real kiro-cli): Genesis questions answered via introspection tools; a "cancel the run" request was
refused.

---

## ADR-032 — Credit usage is REAL metered data from Kiro ACP (not estimated)

**Status:** Accepted (Phase 11). **Context:** Genesis needs to show users how many credits an agent
invocation and a whole run consume (and each chat message). The initial assumption — from ACP/Kiro
docs and GitHub issues (ACP "end-turn token usage" RFD has no stable shape; Kiro#8524 "export
per-session credits" is an open request; dashboard shows only a monthly cumulative) — was that
per-turn credits were **not** programmatically available, implying Genesis would have to *estimate*.

**Spike (decisive).** A raw JSON-RPC ACP spike against **kiro-cli 2.12.1** disproved that: Kiro emits
a custom notification **`_kiro.dev/metadata`**, and the final one of each turn carries
`meteringUsage: [{value, unit: "credit", unitPlural: "credits"}]` plus `contextUsagePercentage` and
`turnDurationMs`. Verified **per-turn, not cumulative** (two turns in one persistent session reported
0.184 then 0.113 credits independently).

**Decision.** Surface **real, metered per-turn credits**; there is **no estimation/pricing engine**
(the draft's `CreditModel`/`credit-pricing.json` were dropped). The SDK captures the metered value
into `ResultMessage.usage`/`TurnResult.usage`; genesis-core writes it to node telemetry + the
`_run` aggregate + the `agent.result` event; genesis aggregates it from `run_events`
(`aggregate_credits` via `json_extract`) + folds per-node (`fold_steps`); chat persists it on the
assistant message (`m0003`). Every figure carries a **`provenance`** — `metered` (real), or
`unavailable`/`partial` when an older kiro-cli omits metering — so the UI shows honest "n/a" gaps and
never a fabricated number.

**Alternatives considered.** (a) Estimate from tokens/tool-calls via a configurable pricing model —
rejected as unnecessary and less honest once real data was found; kept only as a mental fallback if a
future kiro-cli drops metering. (b) A new credits table — rejected (ADR-030: derive from
`run_events`; chat needs only one additive column).

**Consequences.** Credits are exact to what Kiro bills, at zero estimation risk. The capture is
tolerant (matches `_kiro.dev/metadata`, sums `unit=="credit"`) and degrades to `unavailable` rather
than crashing if the shape changes across kiro-cli versions — pinned by an SDK fixture test. Reducer
hardened so a `None` (unavailable) turn never clobbers an accumulated credit total. Shipped:
kiro-agent-sdk v0.4.0, genesis-core v0.8.0, genesis v0.20.0.


## ADR-033 — The Chat copilot may operate runs (human-confirmed, run-management layer only), never owns control flow

**Status:** **Accepted** (Phase 13 — SHIPPED, 13-01..13-06; genesis v0.24.0 + kiro-agent-sdk v0.5.0).
**Context:** Phase 10 made Chat strictly read-only
(ADR-031). Users want a **copilot** that starts workflows from chat and supervises them (sensing HITL
gates, relaying decisions). This appears to collide with **ADR-001** (LangGraph owns control flow;
agents never orchestrate) and **ADR-031** (chat is read-only).

**Decision.** Distinguish two layers. **Workflow control flow** (which node runs next, gates, retries,
loops) stays owned by **LangGraph** (ADR-001, unchanged). **Run management** (start a run, read its
status, answer its gates, cancel) is the **operator layer** — what a human already does in the Runs UI.
The chat copilot becomes a **second operator client** at that layer, via a write-capable **Genesis
Control MCP server** that *proxies the existing `RunManager` API* (it adds no run logic; `RunManager`
stays the single source of truth). Constraints:
1. **Run-management layer only** — start / read status / read + answer gates / cancel. The copilot never
   alters graph edges, node order, retries, or gate placement; it cannot bypass or auto-approve a
   workflow's own HITL gate — it only **relays** the human's decision to it.
2. **Every mutation is human-confirmed** — `start_run` via the schema-driven launch dialog; `respond_to_gate`
   / `cancel_run` via a per-call confirm card. This uses ACP's native `session/request_permission`: mutating
   control tools are left **untrusted**, so each call prompts; a new SDK `permission_mode="ask"` bridge
   routes the prompt to the chat UI (fail-closed on timeout). No dependence on MCP elicitation.
3. **No config / secrets / registry / workflow-definition / deploy access** — the control tool set excludes
   all of these (ADR-029 authority-by-tool-set).
4. **Auditable** — every agent-initiated action is logged with its confirming user decision.
5. **Read-only default** — a session is read-only until the user launches/toggles copilot; a global
   kill-switch reverts everything to read-only.

**Alternatives considered.** (a) Let the chat agent be the orchestrator (drive workflow steps itself) —
rejected: violates ADR-001, discards LangGraph's durability/checkpointing, and is the exact
solutions-copilot anti-pattern Genesis exists to replace. (b) UI-mediated pending-action confirmation
(mutating tool returns "pending", the UI confirms, a release endpoint executes) — kept as the **fallback**
if the 13-01 spike shows kiro-cli does not fire `request_permission` for untrusted MCP tools. (c) MCP
elicitation for confirmation — rejected (kiro-cli client support unconfirmed; the ACP permission
mechanism already exists).

**Consequences.** ADR-031 is **refined** (chat is read-write at the run-management layer, human-gated),
ADR-001 is **preserved** (agent ≠ workflow engine — it calls the same durable API a human clicks). The
copilot is a *supervised operator*, not an autonomous agent. Matches the industry-standard "agents
orchestrate; a durable engine executes" pattern. Planned: kiro-agent-sdk (permission bridge) → genesis
(control server + copilot mode + supervision bridge + web).

**As-built (SHIPPED).** All six sub-phases delivered: 13-01 SDK `permission_mode="ask"` + `on_permission`
bridge (kiro-agent-sdk v0.5.0, spike-confirmed); 13-02 Genesis Control MCP server (thin proxy over
`/api`, run-management tools only); 13-03 copilot chat mode + run↔session link (`m0004`) + the
permission→chat bridge; 13-04 `ChatRunSupervisor` (gate/terminal → durable notifications `m0005` +
per-session SSE + system nudge, level-triggered reconcile + SLA); 13-05 the slash-launch/HITL web UI;
13-06 the safety/audit hardening — global kill-switch + per-session concurrency/rate limits + workflow
allow/deny (enforced app-side, gated on the control token; browser Runs-UI unaffected), the
`copilot_actions` audit trail (`m0006`, proposal→confirmation→outcome), and the structural guarantee
that `pre_mutation`/any gate is never auto-approved (the copilot only relays via the always-confirmed,
never-trusted `respond_to_gate`). The R1 fallback (UI-mediated pending-action confirmation) was NOT
needed — the spike confirmed kiro-cli fires `request_permission` for untrusted MCP tools. Live
acceptance against real kiro-cli remains a manual step (can't be driven headlessly).


---

## ADR-034 — Skills are first-class "standalone activities", chat-invoked and filesystem-provisioned (Phase 14)

**Status:** Accepted — SHIPPED (Phase 14, 14-01..14-05: kiro-agent-sdk v0.6.0 + genesis-workflows v0.6.0 +
genesis v0.26.1). **Context:** Genesis has one unit of packaged capability today — the
**workflow** (a LangGraph graph with stages, gates, reliability). But many valuable tasks are **single, standalone
activities** with no backend orchestration: "produce this document in our house format", "build a checklist for X",
"answer using the GAM (Government Acquisition Management) body of knowledge + templates". Forcing those into a
LangGraph workflow is overkill. Kiro natively supports **Agent Skills** (https://kiro.dev/docs/skills/, the open
[Agent Skills standard](https://agentskills.io)): portable `SKILL.md` instruction packages (+ optional
`scripts/`/`references/`/`assets/`) that the agent activates on demand. A spike (2026-07-16,
`spike/2026-07-16-kiro-skills-in-acp-and-chat.md`) confirmed skills load + activate over **ACP** — the exact channel
Genesis Chat uses.

**Decision.** Introduce **Skills** as a **second first-class capability concept** alongside Workflows, and surface
them **in Chat**:
1. **Two concepts, clear boundary.** A **Workflow** = an activity that needs *stages / a backend process* (e.g.
   code-review: pull the JIRA ticket → fetch environment data → review) — owned by LangGraph (ADR-001). A **Skill** =
   a *standalone activity* with no stages and no orchestration (e.g. draft a document from a template, apply a body of
   knowledge) — owned by the **Kiro agent**, driven by its `SKILL.md`. Skills never start runs; workflows never live
   in `.kiro/skills/`.
2. **Filesystem-provisioned, not wire-injected.** Unlike MCP servers (pushed over ACP `session/new.mcpServers`),
   skills are **discovered from disk**. Genesis provisions them into a **managed Kiro workspace at
   `~/.genesis/.kiro/skills/`** — which is exactly the Chat session's `cwd` (`state_dir`), so kiro-cli auto-discovers
   them (workspace scope). Genesis does **not** set `KIRO_HOME` (that would hide the user's personal `~/.kiro`
   agents/sessions/settings). The user's own global `~/.kiro/skills/` remain active too; workspace wins on name
   conflict (Kiro's rule).
3. **Two acquisition paths.** (a) **Install from the library** — `genesis-workflows` gains a `skills/` folder + a
   skills registry, and Genesis pulls + installs a selected skill into the managed workspace (mirrors the workflow
   install/lockfile path). (b) **Author in-flight** — the user creates a skill in the app (name + description +
   `SKILL.md` body, plus optional `scripts/`/`references/`/`assets/` uploads); it is written into the managed
   workspace and is immediately usable.
4. **Chat is the invocation surface (priority 1).** In Chat, a skill activates **automatically** when the request
   matches its `description`, and can be invoked **explicitly** via the `/` command palette (which today lists
   workflows — it becomes a unified command menu that also lists installed skills). Both paths are spike-proven over
   ACP.
5. **Catalog gets Workflows | Skills sub-tabs.** The Catalog page splits into two standard sub-tabs; Skills lists
   installed + library skills with install/remove and a **"New skill"** authoring entry.
6. **Safety + a scoped output sandbox.** Skills are *instruction/context* packages — they carry no inherent
   authority; any tool a skill asks the agent to use is still gated by the session's trust/permission model
   (ADR-031/033). A skill **may produce documents**, but writes are confined to a **per-session skill-output
   sandbox** at `~/.genesis/skill-output/<session_id>/` (never the runs folder, never arbitrary paths), enabled by a
   small additive **kiro-agent-sdk `fs_write_root`** option: chat runs with `allow_fs_write=True` **only** against
   that sandbox root — any `fs/write_text_file` outside it is rejected by the SDK. So chat still cannot write config,
   secrets, the registry, workflow definitions, or anywhere else on disk. **Executing bundled `scripts/` remains
   deferred** (a separate future fs/exec-policy decision); authored/imported skills are validated (`SKILL.md` schema,
   name rules, size caps) and imported `scripts/` are treated as untrusted. Session skill-outputs are surfaced
   (list/preview/download) reusing the Documents renderers.

**Alternatives considered.** (a) Model every standalone activity as a trivial one-node workflow — rejected: heavy,
and it wouldn't leverage Kiro's native progressive-disclosure skill activation. (b) Inject skill text as steering —
rejected: steering is always-on (context bloat) and not portable/sharable; skills load on-demand and follow an open
standard. (c) Wire skills over ACP like MCP — impossible: ACP defines no skills channel; skills are filesystem-based
(confirmed by spike + kiro-cli).

**Consequences.** Genesis becomes a two-concept platform — **Workflows (orchestrated) + Skills (standalone)** — both
discoverable in the Catalog and usable from Chat. Preserves ADR-001 (skills don't orchestrate; LangGraph still owns
workflow control flow), refines ADR-031/033 (Chat/copilot gains a new *instruction* capability, still no unsanctioned
mutation). New surface area: a managed skills workspace, a `genesis-workflows` skills library, a skills
install/author backend + API, Catalog sub-tabs, and the chat command palette. Delivered per the Phase 14 sub-phase
specs; this ADR flips to Accepted when Phase 14 ships.


---

## ADR-035 — Run input file attachments (bounded, sanitized, provisioned into the blackboard) (Phase 15)

**Status:** Accepted (Phase 15, sub-phase 15-01).

**Context.** The design-doc workflow (Phase 15) accepts an optional **mockup** the agent reads to
extract i18n strings. Workflow inputs are JSON (validated against `META.inputs_schema`), but a mockup
is a *file*. We need a way to attach a file at launch without Google Workspace, without letting a
workflow read arbitrary host paths, and without changing the subprocess-worker isolation model
(ADR-012).

**Decision.** A workflow input property may declare **`format: "file"`**. Such inputs are provisioned
at launch, not passed inline:
1. **New multipart endpoint `POST /api/runs/upload`** (browser launch only — no copilot control token;
   the JSON `POST /api/runs` is unchanged for tokened/copilot starts). Body = a JSON `payload` part
   (`{workflow_id, inputs, environment}`) + file parts keyed by the input property name.
2. **`RunManager.start(..., files=…)`** writes each uploaded file into the new run's **blackboard**
   under `uploads/<sanitized-filename>` **before** the graph starts, then rewrites the matching input
   to the **blackboard-relative path** (`uploads/<name>`). Schema validation runs *after* the rewrite,
   so the input validates as the string path it becomes.
3. **Guards:** size cap (10 MB), extension allowlist (`.txt .md .html .htm .csv .png .jpg .jpeg`),
   filename sanitization (basename only, no path traversal), and target check (the field must be a
   declared `format:"file"` property) — violations raise `FileUploadError` → HTTP 400 at launch.
4. **The worker just reads a file already in its own workspace** — no new host-path access, ADR-012
   isolation intact. Uploaded files are **read-only inputs, never executed** (mirrors the Phase-14
   skill `scripts/` "stored, not run" posture).
5. **Web:** the schema-driven launch form (07-05) renders a `FileDropList` control for `format:"file"`
   inputs and submits via multipart when a file is attached (reusing the Phase-14 upload plumbing).

**Alternatives considered.** (a) Base64-inline the file in the JSON inputs — rejected: bloats state,
violates the "no bulk in state" rule (ADR-010/018), and breaks the editable-state model. (b) A generic
"upload to a temp dir, pass the host path" — rejected: leaks host paths into workflow inputs and
widens the worker's file access. (c) Keep Google Workspace ingestion — rejected per the Phase-15
decision (no Google dependency).

**Consequences.** Runs gain a bounded, auditable file-attachment channel that lands in the blackboard
like any other artifact. Preserves ADR-012 (worker isolation) and ADR-010/018 (bulk → blackboard,
never inline). Enables the Phase-15 mockup → i18n branch (15-05) and any future workflow that needs a
document at launch. Delivered in 15-01 (genesis backend + launch-form control + tests).

---

## ADR-036 — Internalized Appian Knowledge Base (Genesis owns the parser + KB, fed by the single dev-tagged environment) (Phase 16)

**Status:** Accepted (Phase 16) — implemented: the code-free KB (`KbStore` / m0007, 16-02) + the deterministic
`sync-application` baseline (16-03) + the Applications surface (16-04); the external-Atlas cutover completes in 16-05.

**Context.** Today Genesis reaches an **external** knowledge base for Appian application intelligence:
the **Atlas** MCP (a GitLab-served, pre-parsed KB produced by a standalone daily pipeline — Appian API
→ `sync_packages.py` → the Atlas parser → a GitLab KB repo → an MCP that reads GitLab over the API) and
**Jarvis** (an in-Appian KB queried live). The external chain has four moving parts, a **daily**
freshness ceiling (Atlas parses once/day), and a network round-trip for every query; it is also not
shaped for Genesis's needs (it stores object source code, has no cross-app query surface tuned to
Genesis, and lives outside Genesis's own SQLite data plane). Genesis is evolving into an agentic Appian
development environment, and the KB is its foundation.

**Decision.** Genesis **owns** the Appian KB. Phase 16 internalizes the whole loop:
1. A **Genesis-native parser** (`genesis-appian-parser`, a new pinned repo) — the Atlas parser's
   front-half (unzip → type-detect → 15 object parsers → UUID/URN reference resolution → dependency
   graph → entry-point bundles → content diff-hash) ported into a Genesis-owned, stdlib-only package
   that emits an **in-memory structured result**, not files.
2. A **local KB in `genesis.db`** (migration m0007, `kb_*` tables) — cross-app queryable.
3. An **`Applications` container model + page** — the user selects apps from the **dev-tagged
   environment** and adds the ones a team works on, on demand. The Environments registry may hold
   **many** environments; a single **`is_dev` toggle** (single-select — at most one env tagged dev)
   designates the Appian environment Phase 16 authenticates against, and that env supplies the URL +
   credentials for **all** Phase-16 connectivity (REST export, Dev MCP, DevOps MCP, changed-objects API).
   See 16-08 §2.0.
4. A **`sync-application` LangGraph workflow** that **exports the package via the Appian Deployment
   REST API deterministically** (a program node, no agent, no credits — ADR-001), parses it, and
   applies it to the KB. Run-tracked, retryable, error-surfacing.
5. A read-only **`genesis-kb` MCP server** (the internal counterpart of the Atlas MCP) that serves the
   KB to agents, with **chat / erd-generation / design-doc cut over** from the external `appian-atlas`.
The native Appian **Dev MCP** (read-only here) and **DevOps/Deployment MCP** (export) become curated,
first-class environment connectors.

**Alternatives considered.** (a) Keep calling the external Atlas MCP — rejected: external moving parts,
daily-freshness ceiling, network round-trip, not Genesis-shaped. (b) Adopt Jarvis's in-Appian KB —
rejected: no release history and couples the KB store to Appian. (c) A separate `kb.db` file — rejected
in favor of `genesis.db` (one `Database` + migration runner; ADR-030 alignment; `kb_*` namespaced +
table-scoped rebuild). (d) An agent-driven export (DevOps MCP tool calls inside the sync) — rejected
for the pipeline: exporting is a mechanical deterministic sequence; an LLM turn burns credits and is
non-deterministic (ADR-001). The DevOps MCP is still **registered** for interactive/agent use.

**Consequences.** Genesis gains direct local KB access (no GitLab round-trip), on-demand + delta
freshness under its control, and a KB tuned to its needs (code-free, temporal, cross-app) — matching
the local single-user, one-environment, own-data-plane posture (ADR-023/026/030). External Atlas/Jarvis
are **retired as the KB source** (Atlas remains the design inspiration + the interim source until the
16-05 cutover). Requires a properly configured environment (External Deployments enabled, a
service-account API key, the Dev MCP plug-in, and the new changed-objects API for delta) — accepted as
a Genesis operating prerequisite. Preserves ADR-001 (sync is a deterministic workflow, not an
orchestrating agent). Pairs with **ADR-037** (code-free temporal KB). Read/deploy authoring stays out
of scope this phase (Dev MCP used read-only).

---

## ADR-037 — Code-free temporal KB + live code via the Dev MCP (Phase 16)

**Status:** Accepted (Phase 16) — implemented: the code-free temporal `kb_*` SCD-2 store (16-02) + the baseline sync
(16-03); live code via the Dev MCP wires in 16-05; the version-comparison tools stay 16-06 backlog (gated on Dev-MCP
AP-62096, 26.8 GA).

**Context.** An Appian application has 4,000–6,000+ objects across many releases. Storing every
object's SAIL source across every version (as Atlas does) is heavy and redundant when the environment
already retains object versions — and the connected environment is the source of truth for code. We
want a **lightweight but intelligent** KB and always-accurate code.

**Decision.** The KB stores **only** metadata / structure / dependency graph / bundles — **never**
object source code. The parser still reads SAIL to extract dependency references and descriptions, but
the SAIL string is **never persisted**. All code — **current and historical** — is fetched **live**
from the connected environment through the **Appian Dev MCP** (version-parameterized:
`get_object_code(object_uuid, version?)`). Object history is a **temporal (SCD-2) model** in `genesis.db`
(`kb_objects`/`kb_dependencies` rows carry `valid_from_sync`/`valid_to_sync`; a change closes the old
row and opens a new one), so any point in time is reconstructable. **Releases are user-tagged in
Genesis** ("Mark released → v1.0") and recorded in `kb_releases` as a named pointer to a sync
(`sync_id`) plus an `env_version_ref` — the handle the Dev MCP uses to fetch code at that release.
Bundles are recomputed in full per sync (global BFS is seconds at 6k objects) and snapshotted per
release. Deletions (from the delta API) close SCD-2 rows. `kb_*` is namespaced and pruned/rebuilt
**table-scoped** (never touching runs/chat tables).

**Alternatives considered.** (a) Store code + history in the KB (Atlas's model) — rejected: redundant
with the environment, heavy, and the env is the source of truth. (b) Store code deltas only for history
— rejected: unnecessary once the Dev MCP exposes versioned reads (planned + imminent). (c) Per-version
full snapshots of the metadata graph — rejected in favor of continuous SCD-2 validity ranges (any point
reconstructable, far less storage). (d) A separate `kb.db` — see ADR-036 (folded into `genesis.db`).

**Consequences.** The KB stays lightweight (~5–8 MB/app, ~50–150 MB for ~10 apps × ~10 releases; well
within SQLite) and always-fresh for code. Code reads couple to environment availability / latency /
auth — accepted as a known mechanism; `genesis-kb` degrades honestly ("code unavailable", never
fabricated). **Point-in-time code** depends on the Dev MCP's version support (planned + imminent);
metadata history + current code do not depend on it, so phases 16-01…16-05 are unblocked and only
16-06's historical-code view waits on it. Refines ADR-030 (SQLite `kb_*` tables; semantic/RAG search
over parsed content would be a future pgvector trigger + its own ADR) and ADR-010/018 (the export zip +
parser intermediate live in the run blackboard; only compact metadata reaches `kb_*`, only pointers
reach LangGraph state). Pairs with ADR-036.

---

## ADR-038 — Managed native Appian MCP servers (vendored, versioned, replaceable via manual drop-in, not forked) (Phase 16)

**Status:** Accepted (Phase 16, sub-phase 16-08) — SHIPPED: the managed-native installer + `McpRegistry`
managed-reference resolution + the `appian-dev`/`appian-devops` registry entries (genesis-core v0.9.1 + genesis
v0.31.1 + genesis-workflows v0.8.4).

**Context.** Genesis internalizes the Appian *knowledge base* (ADR-036/037) but must still make *environment* calls —
read live object SAIL, evaluate SAIL, query SQL, read env info, list applications, and export packages. Per the Phase-16
scope decision (2026-08-04), these go through the **out-of-the-box Appian Dev MCP (`lcp-mcp-server`)** and **DevOps MCP
(`appian-deployment-mcp`)**, retiring Atlas/Jarvis as services. Both are local `uv`-managed Python MCP servers (the Dev
MCP bundles vendored `lib/`+`sdk/` packages and pulls playwright; the DevOps MCP is a PyPI-only, `uv.lock`-ed package).
They are third-party artifacts Appian releases on its own cadence, so Genesis must run them **and** be able to **take a
newer Appian release and apply it** — without diverging from upstream.

**Decision.** Treat the native MCP servers as **managed, versioned, opaque, replaceable artifacts** — a third MCP tier
beside curated (ADR-005/029) and user-custom:
1. **Install** each into `~/.genesis/mcp-servers/<id>/versions/<version>/` (unpacked bundle + a per-server `.venv` from
   `uv sync`); a lockfile records `{active_version, versions:[{version,source,sha256,installed_at,entry}]}`; the
   previous version is retained for **rollback**.
2. **Launch** from the per-server venv (`.venv/bin/appian-deployment`; `.venv/bin/python -m lcp_mcp_server`) — so `uv` is
   only needed at install time — with env `${VAR}` resolved via the existing SecretProvider → EnvironmentRegistry →
   os.environ chain (Dev MCP Basic auth as the headless default; browser/SSO is an opt-in manual step).
3. **Register** as a **managed reference**: a curated `mcp-registry.json` entry supplies identity + a **read-only
   `tool_allowlist`** (governance preserved; write/deploy excluded, Section E), but the launch spec is resolved at
   runtime from the active install (`McpRegistry.acp_servers` → `NativeMcpInstaller.active_launch_spec`). Updating the
   binary needs **no registry edit**.
4. **Updates = manual drop-in (2026-08-05 decision), no auto-fetch source.** New Dev/DevOps MCP releases are integrated
   by the operator placing a new bundle and re-installing it (`install(id, bundle_path)`); Genesis versions it, records
   the sha256, atomic-switches `current`, and keeps the prior version for `rollback`. (The earlier auto-fetch idea — Dev
   from the connected-site `lcp-mcp-bundle` servlet, DevOps from a configured mirror — was dropped by the user.)
5. **Never modify the bundle source** — modification would break updatability. All Genesis glue (launch spec, env,
   allowlist, lockfile) lives outside the bundle.

**Alternatives considered.** (a) Fork the servers into Genesis — rejected: forking forfeits upstream updates (the exact
thing the user requires). (b) Static curated `mcp-registry.json` image lines — rejected: these are local, per-machine,
version-varying installs, not fixed images (the old `lcp` `<lcp-image>` placeholder was never a real image). (c) Docker
images — rejected: the official bundles are `uv`-run local Python, not containers; adding Docker adds a heavy prereq.
(d) `pip install` from an index — rejected: the Dev MCP ships vendored editable path deps (`lib/`/`sdk/`) and is
distributed as a site-served bundle, not a PyPI package.

**Consequences.** Genesis runs the official Dev/DevOps MCP unmodified and can apply Appian's updates by **manual drop-in**
(the operator installs a new bundle → Genesis versions it + swaps `current`; prior kept for rollback), versioned and
reversible; there is **no auto-fetch update source**. New prerequisite: **`uv`** on PATH at
install time (run time uses the created venv); the Dev MCP install is sizeable and needs Python 3.13 (matches ADR-024);
playwright/browser auth stays an opt-in manual step for SSO-only sites. Read-only posture preserved via the allowlist
cap (ADR-029); write/deploy remain out of scope (Section E) until a later phase gates them behind `pre_mutation`
(ADR-021/033). Pairs with ADR-036/037 (KB internalized; environment access via these managed native MCPs).

---

## ADR-039 — Business understanding is an agent-synthesized, evidence-grounded artifact (the Business Application Map) (Phase 17)

**Status:** Proposed (Phase 17) — spec only (`specs/phase-17-business-application-map.md` + `business-model-contract.md` +
sub-phases 17-01..17-06); awaiting approval to implement.

**Context.** Phase 16 internalized a **technical, code-free** Appian knowledge base (objects, dependencies, entry-point
bundles with process flows). That is what agents and MCP tools need, but it does not answer a human's question: *"what does
this application do for the business, end to end?"* A business-level picture is required — a clean, high-level, business-
language map (an end-to-end **value stream** + a **capability constellation**) with **no** objects/bundles/pages/properties
vocabulary. Critically, "business meaning" is **not a field in the KB**: turning record types into business entities,
entry-point processes/actions into business activities, and the dependency graph into an end-to-end journey is an act of
**interpretation**, not a mechanical projection. The risk of any agent-authored diagram is a confident but wrong story.

**Decision.** Model business understanding as a **derived, agent-synthesized, evidence-grounded artifact** produced by a
**deterministic workflow**, persisted, and rendered — never a hand-render of the parse, never stored in Appian:
1. **Agent synthesizes, program grounds.** A new deterministic LangGraph workflow `generate-business-map` reads the **local
   KB only** (via the read-only `genesis-kb` MCP + `KbStore`); **narrow agent nodes interpret** the technical evidence into
   business concepts (ADR-001 preserved — LangGraph owns control flow, agents never orchestrate), and **every agent node is
   wrapped by the reliability trio** (validator + retry + escalation, ADR-011).
2. **Evidence-grounding is mandatory (anti-hallucination).** Every business element (entity, capability, actor, value-stream
   stage) cites the **real KB object UUIDs** it was inferred from; a program validator rejects any element referencing an
   object not in the KB, enforces a minimum **coverage** of the app's significant objects, and enforces a **business-language
   guard** (banned technical tokens). Exhausted retries escalate to a **human review gate** (ADR-021).
3. **A versioned contract.** The artifact is `BusinessModel v1` (`business-model-contract.md`) — summary, domain, entities,
   capabilities (+ relations), actors, and value streams (ordered stages with branches) — the single source of truth for
   producer (workflow), storage, and consumer (web).
4. **Persisted + point-in-time.** The model is generated from a specific sync (`source_sync_id`) and stored in `genesis.db`
   (migration **m0008** `kb_business_maps`), so it is instant to view and honestly labeled ("based on sync #N · {credits}
   credits · {coverage}% covered"); a newer sync marks it **stale**; regeneration is on demand and costs **real metered
   credits** (ADR-032). Release snapshots are schema-ready for later.
5. **Business-only, code-free, read-only.** Output is business language exclusively; it stores **no** SAIL (ADR-037); it reads
   only the local KB (no environment round-trip, no writes to Appian). A *technical* visualization is a separate, later
   effort — explicitly out of scope.

**Alternatives considered.** (a) **Direct/heuristic render of the KB** (cluster objects by name/dependency, show
sites→pages→objects) — rejected: it reproduces the technical environment in a UI (exactly what the user does not want) and
cannot produce a coherent *business* narrative. (b) **A one-shot chat/skill that draws a diagram** — rejected: not
deterministic, not persisted, no reliability trio, no evidence guarantees, hard to trust or regenerate reproducibly.
(c) **Store business meaning in the parser/KB** — rejected: the parser is deterministic and business-agnostic; baking
interpretation into it couples a stable technical layer to a subjective one. (d) **Store the map in Appian** — rejected for
the same reasons as ADR-036 (query shape, read-only posture, keep it Genesis-owned). (e) **No persistence (generate on every
view)** — rejected: agent generation costs credits and time; the map is naturally point-in-time (tied to a sync), so persist +
stale-mark + regenerate-on-demand.

**Consequences.** Genesis gains a trustworthy, business-facing explanation of an application, produced by the same
deterministic-workflow machinery as everything else and grounded so it can't fabricate. Cost: a new workflow, a migration
(m0008), a business-model contract to maintain, and agent credits per generation. The map is only as current as its source
sync (mitigated by the stale hook). Quality is bounded by KB richness + naming (mitigated by the coverage gate, the human
review gate, and 17-06 acceptance against the real app). Preserves ADR-001 (control flow), ADR-011 (reliability trio),
ADR-037 (code-free), ADR-030/032 (SQLite persistence + real credits), ADR-026 (local single-user). Pairs with ADR-036/037
(the KB it interprets).

---

## ADR-040 — Managed-native CLI connector (`gws` installed/versioned/authenticated inside Genesis, standard OAuth) (Phase 19)

**Status:** **ACCEPTED (Phase 19 — SHIPPED)** — genesis-core **v0.9.2** (managed-native `CliRegistry` launch resolution) +
genesis **v0.44.0** (native-CLI installer/lockfile + `gws` seam + login URL-capture + `api/native_cli.py` + `genesis cli`
subcommands + Settings→CLI connector card) + genesis-workflows **v0.9.3** (`gws` managed-native `cli-registry.json` entry);
spec `specs/phase-19-document-library.md` + `phase-19-document-library/19-01..19-02`; 19-01 spike + a live isolated-mode
`gws auth login` + read-only Drive read verified end-to-end.

**Context.** Phase 19 (the Document Library) must read business documents out of **Google Drive**. The organization's standard
tool for talking to Google is the **Google Workspace CLI (`gws`)** — a single self-contained binary that builds its surface
from Google's Discovery API and emits structured JSON. The user's requirement: `gws` should be **integrated natively inside
Genesis** (like the managed native Appian Dev/DevOps MCP servers, ADR-038) — installed and configured from Genesis, **not** a
per-user terminal install — and authenticated with `gws`'s **standard OAuth** (the same auth approach the org's `dotfiles`
setup uses: a shared OAuth client + browser login), not a bespoke scheme. Today `CliRegistry` is **PATH-only**
(`ensure()` = `shutil.which`), so there is no managed-CLI concept to hang this on.

**Decision.** Introduce a **managed-native CLI tier** parallel to ADR-038, plus point `gws` at a Genesis-owned config for its
standard OAuth:
1. **`NativeCliInstaller`** — a lighter cousin of `NativeMcpInstaller`. Because `gws` is a **single static binary** there is no
   `uv`/venv: install a drop-in binary under `~/.genesis/cli-tools/<id>/versions/<version>/`, `chmod +x`, sha256 + an atomic
   `NativeCliLockfile`, atomic-switch `current`, keep the prior for **rollback**; **no auto-fetch** (manual drop-in, per
   ADR-038's rule). `active_launch_spec(id)` returns the binary path.
2. **`CliRegistry` managed resolution** (genesis-core, additive, `CORE_MAJOR` stays 1) — a `cli-registry.json` entry may carry
   `{"managed":"<id>"}`; `ensure()`/`run()` resolve the binary via an injected `launch_provider`, falling back to `shutil.which`
   for unmanaged CLIs. Env `${VAR}` still resolves via SecretProvider → EnvironmentRegistry → os.environ (the installer never
   touches secrets — same launch-vs-env boundary as ADR-038).
3. **Standard OAuth, Genesis-hosted config, client read from dotfiles output.** Genesis drives `gws`'s own `gws auth login`
   (browser OAuth) with `GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.genesis/cli-tools/gws/config` + `KEYRING_BACKEND=file`. **Genesis
   ships no OAuth client/token.** The org **`dotfiles` setup is a documented prerequisite** — it provisions the shared OAuth
   client (from Secret Manager in `peng-os`, via gcloud/ADC — dotfiles owns that) to **`~/.config/gws/client_secret.json`**
   (a Desktop-app client with an `http://localhost` loopback redirect). Genesis **reads** `client_id`/`client_secret` from
   that file (path overridable) and injects them as `GOOGLE_WORKSPACE_CLI_CLIENT_ID`/`CLIENT_SECRET` for its `gws` calls; it
   never runs gcloud itself, never ships a token, and fails clearly if the file is absent ("complete the dotfiles setup
   first"). The user then approves a captured sign-in URL surfaced in Settings → CLI; the localhost callback completes on the
   same machine. **The user's Google tokens live in `gws`'s encrypted config dir; Genesis stores only nothing persistent of
   its own and never logs tokens.** Verified end-to-end on a real machine (2026-08-11): client file present, standard OAuth
   login, read-only `gws drive files list` returning the sync fingerprint. Spike (19-01) confirmed the browser-OAuth completes
   under a spawned subprocess (fallback: `gws auth export` → `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE`).
4. **Read-only by construction.** Request only read-only Drive/Docs/Sheets/Slides OAuth scopes, and enforce a
   read-only, drive/docs/sheets/slides-only **allowlist at a single `gws` access seam** (`gws_client`) — no Gmail/Calendar/
   Admin/write (defense in depth, mirrors ADR-031/037 + the ADR-038 read-only allowlist).

**Alternatives considered.** (a) **Register `gws` in the existing PATH-based CLI registry with an install hint** — rejected:
requires a per-user terminal install (exactly what the user doesn't want) and gives Genesis no version/rollback control.
(b) **Wrap Google Drive via a custom MCP server** — rejected: `gws` is the org standard and already agent/JSON-friendly;
re-implementing Drive access is wasteful and diverges from the org. (c) **Bespoke OAuth in Genesis** — rejected: the user
wants the *standard* `gws`/dotfiles auth, and re-implementing OAuth + token storage duplicates what `gws` already does
securely. (d) **Service account** — rejected: can't read a user's personal Drive without domain-wide delegation; per-user
OAuth is required.

**Consequences.** Genesis gains a managed, versioned, rollback-able **CLI** tier (generalizes the native-connector idea beyond
MCP servers) and a first non-Appian native integration. New prerequisite: the shared org OAuth client (Desktop-app type,
localhost redirect) provisioned into Genesis secrets; a small install bundle for the `gws` binary (manual drop-in, no
auto-update). The browser-OAuth-under-subprocess mechanism is the one load-bearing risk, de-risked by the 19-01 spike with a
documented `auth export` fallback. Preserves ADR-005/029 (registry governance; read-only allowlist cap), ADR-026 (local
single-user — one gws identity per instance). Pairs with ADR-041 (the document library this connector feeds).

---

## ADR-041 — Documents are a global first-class store linked into applications (dedup; untrack unlinks, never deletes) (Phase 19)

**Status:** **ACCEPTED (Phase 19 — SHIPPED)** — genesis **v0.44.0**: m0009 (`kb_documents`/`kb_document_links`/
`kb_document_sections`) + `DocumentStore` (global dedup store; untrack unlinks, never deletes) + the parsing pipeline +
`DocumentSyncEngine` + `api/documents.py` + `genesis-kb` document tools + `build_evidence_pack` extension + the web surface;
the `sync-documents` workflow ships in genesis-workflows **v0.9.3**.

**Context.** Users want to attach business documents (PDF/Word/Excel/Google Docs) to an application and keep them in Genesis
for spec generation / design discussion. But the **same document is often relevant to multiple applications**, and the user
explicitly does **not** want to maintain the same document separately per app. Meanwhile the existing `kb_*` store is strictly
**per-application**: every `kb_*` table is app-scoped and **untrack is table-scoped by `app_uuid`** (untracking an app deletes
its rows). A shared document store breaks that invariant.

**Decision.** Model documents as a **global, first-class store** with an **app-link table**, stored **once** and **linked**:
1. **`kb_documents` is app-independent** — one row per **unique** document (dedup identity = Drive **file-id** for `gdrive`
   docs, **content-hash** for uploads), with its parsed content kept as a **single latest-version** Markdown artifact on disk
   (+ JSON tables for spreadsheets), pointers/hash/sync-fingerprint in `genesis.db` (m0009).
2. **`kb_document_links(document_id, app_uuid)`** associates a document with one or more apps. **Adding = upsert into the
   library (dedup) + create a link;** picking an existing library document = just a link. Sync runs **once per document**, not
   per app.
3. **Untrack an app unlinks, never deletes.** Untracking an application removes its `kb_document_links` rows (FK cascade) but
   **never deletes a shared document**; a document with zero links remains a first-class library citizen. This is a
   **deliberate departure** from the per-app table-scoped untrack model (ADR-036/16-02) and is scoped to the document tables.
4. **Latest-version-only.** Sync **overwrites** the single on-disk artifact; no historical content is retained (only the
   change-detection fingerprint). Upstream-deleted Drive files are flagged `source_missing` (last content kept), never dropped
   silently.
5. **Read-only user content, consumed alongside the KB.** Documents are grounding context surfaced via the `genesis-kb` MCP
   (`list/get/search_documents`) and `KbStore.build_evidence_pack`; workflows read but never mutate them. Semantic/pgvector
   search over `kb_document_sections` is a future ADR-030 trigger, not this phase.

**Alternatives considered.** (a) **Per-app document tables (app-scoped, duplicated)** — rejected: the user explicitly rejected
maintaining the same doc per app; wastes storage and forces N syncs of one Drive file. (b) **Documents as `kb_*` rows under
each app with a shared-content pointer** — rejected: still couples lifecycle to a single app's untrack; the link table is
cleaner. (c) **Store documents inside the business map / evidence pack only** — rejected: documents must be independently
listed, synced, and reused across apps and consumers. (d) **Keep full version history on disk** — rejected: the user wants
latest-only; history adds storage + complexity for no stated need.

**Consequences.** Genesis gets a reusable, deduplicated document library that multiple apps (and multiple consumers) share,
with single-source sync. Cost: a new cross-app concern that intentionally sits outside the per-app untrack sweep — untrack
logic and any "rebuild app" flow must be **link-aware** (drop links, keep documents), and an optional cleanup path handles
truly orphaned (zero-link) documents by user action, not automatically. Preserves ADR-010/018 (bulk → files, pointers → db),
ADR-030 (SQLite; pgvector deferred), ADR-037 spirit (we store parsed/derived content; the *original* is retained because it is
**user content**, unlike Appian SAIL). Pairs with ADR-040 (the `gws` connector that pulls/syncs the Drive-sourced documents).

## ADR-042 — Features & Specs are first-class sub-entities of an application (Chat-authored, HTML-authoritative) (Phase 20)

**Status:** **ACCEPTED (Phase 20 — SHIPPED)** — genesis **v0.45.0**: m0010 `kb_features`/`kb_feature_specs`/
`kb_feature_spec_revisions` + `FeatureStore` + `api/features.py` (feature CRUD + spec create/context/milestone/status) +
the Chat `feature_spec` mode + the web Features surface.

- **Decision:** An Appian application gains a first-class **Feature** (the unit of work an engineer develops), and a Feature
  owns authored **artifacts** — the first being a **Spec**. Specifically:
  1. **Features** (`kb_features`, FK → `kb_applications ON DELETE CASCADE`) are **intrinsic to their app** — untracking the app
     cascade-deletes its features and their specs (unlike Phase-19 shared documents, which unlink-not-delete). Surfaced as a
     **Features** tab on the app + a full-page **feature page** (`/applications/:uuid/features/:featureId`).
  2. **A spec is authored conversationally, not orchestrated.** The spec's authoring surface is a **Chat session** (reuse of
     Phase 10, ADR-031/034 lineage) bound to the feature — **LangGraph is not involved (ADR-001 preserved)**; there is no new
     workflow, gate, or engine capability. The `genesis-kb` MCP (already in chat, 16-05) gives the agent the app's KB, and the
     app's **linked business artifacts** (Phase-19 `kb_document_links`) can be injected as context via the existing
     `build_evidence_pack` document mechanism.
  3. **The HTML artifact is authoritative;** Markdown is a **derived export** produced on demand. The agent authors the spec
     HTML into its per-session **`fs_write_root` sandbox** (Phase 14 — no new write authority). Bulk HTML + milestone snapshots
     live on disk (ADR-010/018); pointers/status/hash in `genesis.db` (ADR-030).
  4. **Lifecycle:** a spec carries a status **draft → in-progress → in-review → completed** (user-set; the agent may suggest a
     transition but does not set it), and is snapshotted at explicit **milestones** (`kb_feature_spec_revisions`) — the user
     asks to save; the agent is instructed to remind + never snapshots silently. **One spec per feature** in v1 (the FK model
     already allows many for later phases).
- **Context.** Phases 16/17/19 gave Genesis knowledge *about* an application (technical KB, business map, human documents).
  There was no place to *produce new work* on top of that knowledge. Engineers work feature-by-feature and begin with a spec;
  the spec is a discussion, and the user wants to review it visually (annotate an HTML rendering) rather than describe edits in
  prose.
- **Alternatives considered.** (a) **Spec authoring as a LangGraph workflow** (auto-research → draft → review gate) — rejected
  for v1: the user described an open-ended *conversation* where the spec forms in parallel, which is Chat, not a staged graph;
  a staged pipeline can be added later as its own workflow + ADR without disturbing this. (b) **Markdown as the authoritative
  artifact** — rejected: the user wants a rich, visually-reviewable HTML surface while editing (annotate-in-place), with MD as
  an export. (c) **Features as a generic tag/label on runs or documents** — rejected: a feature is a durable first-class
  workspace that will own multiple artifacts (design docs, user stories) over later phases. (d) **A brand-new chat stack for
  specs** — rejected: reuse the Phase-10 Chat (sessions/messages/usage/genesis-kb/fs-sandbox) and just type the session.
- **Consequences.** A small additive data model (m0010) + one new page + wiring; no engine/core change; ADR-001/023/026 intact.
  The feature page is built to grow (design docs / user stories are later phases). The spec's conversation *is* a
  `chat_sessions` row (a new `mode`/type), so chat capabilities (credits, persistence, KB) come for free. Pairs with ADR-043
  (the embedded annotation surface) and reuses ADR-041 (documents as injectable context).

## ADR-043 — Embed the Lavish annotation SDK (vendored, MIT) for in-app HTML review (Phase 20)

**Status:** **ACCEPTED (Phase 20 — SHIPPED)** — genesis **v0.45.0**: the vendored Lavish SDK (`artifact-sdk.js` +
`mermaid-node.js`, MIT @ `899747a`, Genesis-themed) lives in `genesis/api/assets/lavish/` (esbuild-built `sdk.js`), served
same-origin with the artifact via `api/features.py`; `SpecWorkspace` hosts the sandboxed iframe + the postMessage
annotation→chat bridge.

- **Decision:** Provide the annotate-the-HTML-and-feed-the-agent experience by **vendoring the browser SDK** of
  **`kunchenguid/lavish-axi` (MIT)** — `artifact-sdk.js` (+ its `mermaid-node.js` helper) and the `injectLavishSdk` transform —
  and hosting the spec artifact in a **same-origin, sandboxed `<iframe>`** whose **host is our own React chrome** listening on
  `window` `message` events. Genesis does **not** run Lavish's Express **server**, its **CLI**, its **long-poll** transport,
  its **export**, or its **ht-ml.app sharing**. The SDK emits `lavish:queuePrompt` / `lavish:sendQueuedPrompts` / `reviewState`
  / … over `parent.postMessage`; our host formats each queued annotation (anchored text/element + comment) into a single chat
  message sent into the spec's session. Upstream is **tracked manually** (pinned commit); attribution lives in genesis
  `THIRD-PARTY-NOTICES.md`.
- **Context.** The user explicitly does not want to reinvent an annotation editor and pointed at Lavish. Investigation
  (spec 20-01 + source reading) established the load-bearing facts: the injected SDK makes **no** server calls
  (no fetch/XHR/WebSocket) and communicates **only** via `parent.postMessage`; it does precise **text-range anchoring**
  (`getRangeAt` + durable `rangeBoundary`); it is **plain browser ESM (MIT)** bundlable by our existing Vite on Node 20. So the
  SDK is **host-agnostic** — Lavish's own `chrome-client.js` is just one host.
- **Alternatives considered.** (a) **Adopt Lavish whole as a managed-native CLI tool** (the ADR-040 `gws` pattern): the agent
  runs `lavish-axi <file>` + `lavish-axi poll`, the user reviews in **Lavish's own browser window** on `:4387` — rejected for
  v1 because it fights the user's "inside the feature page" UX (a second window), needs a CLI-poll bridge that mismatches
  Genesis's **in-process** ChatManager (not a terminal agent), adds a **Node ≥22** runtime + an unauthenticated local server,
  and pulls in export/ht-ml.app surface we don't want. (b) **Greenfield annotation layer** — rejected: range-anchoring is
  precisely the hard, already-solved part; the user asked not to rebuild. (c) **Depend on the `lavish-axi` npm package at
  runtime** — rejected: we only need the browser SDK; vendoring the two source files avoids a runtime Node/npm dependency and
  the whole server/CLI surface, at the cost of manual upstream tracking (acceptable, and recorded).
- **Consequences.** The annotation experience lives **inside the Genesis SPA** (single pane, reuses the in-process chat), with
  no second window, no `:4387` server, no Node-22 runtime, no external sharing — resolving the security + Node concerns raised
  during evaluation. The spec HTML is **agent-generated and executes scripts**, so it is served **same-origin from a scoped
  route** and rendered in a **sandboxed iframe** (`allow-scripts` **without** `allow-same-origin`/top-navigation); local
  single-user (ADR-026) bounds the blast radius. We own upstream drift (a golden `postMessage`-schema fixture fails a test if
  the vendored SDK changes shape — the "stub hid the contract" lesson). The Mermaid-as-Excalidraw whiteboard (Lavish's heavier,
  `@excalidraw/*` feature) is **deferred** — text/element annotation ships first. Pairs with ADR-042.

## ADR-044 — A Feature is a workspace of sequential artifact stages (Phase 21)

**Status:** **ACCEPTED (Phase 21 — SHIPPED)** — genesis **v0.46.0**: the feature page (`FeaturePage`) is an **artifact
pipeline** (`ArtifactPipeline`) — Spec functional, Design/Breakdown disabled placeholders; the Spec card opens the builder
(Edit) or a read-only preview (View, `artifact?annotate=0`); the Features tab's feature card no longer shows spec status.

- **Decision.** A **Feature** is a workspace whose content is a **sequence of artifact stages** (Spec → Design → Breakdown →
  …), each artifact carrying **its own** status. The **feature itself has no status derived from any single artifact**
  (feature-level status is a separate, later concept). Artifacts open in two modes: **Edit** (author — e.g. the spec builder at
  `…/features/:id/spec`) and **View** (read-only preview). Landing on a feature shows the pipeline, not the builder.
- **Context.** Phase-20 dropped the user straight into the spec builder and showed the *spec's* status on the *feature* card —
  the user's feedback: a spec's status is not the feature's, and a feature should be a workspace of stages (spec, design,
  breakdown) with the later ones gated. **Sequential unlock-on-completion is part of the model but deferred** until ≥2
  artifacts exist (Design/Breakdown ship as disabled "coming soon" placeholders now).
- **Consequences.** The feature page is built to grow (each future artifact is a card + a route). The read-only preview reuses
  the spec artifact route with the annotation SDK omitted (`annotate=0`). No schema change (placeholders carry no data).

## ADR-045 — The reused chat mirrors the Kiro CLI/ACP surface; refines ADR-031 (Phase 21)

**Status:** **ACCEPTED (Phase 21 — SHIPPED)** — genesis **v0.46.0** + **kiro-agent-sdk v0.7.0** + genesis-core **v0.9.3**
(SDK pin): model selection at creation, a slash-command palette + client-side autocomplete, a context-usage + compaction
indicator, clear/compact, and image attachments — in **both** the main chat and the spec builder.

- **Decision.** Genesis adopts the ACP extension surface (`session/set_model` + the models advertised on `session/new`,
  `_kiro.dev/commands/{available,options,execute}`, `_kiro.dev/{compaction,clear}/status`, image prompt content) so the in-app
  chat offers the Kiro CLI's model/commands/context capabilities. This **refines ADR-031's "Chat is read-only"**: the chat
  surface is **no longer categorically read-only**, but **write-capable actions remain human-confirmed** via the existing
  `permission_mode="ask"` + `on_permission` bridge (ADR-033) — **not** blanket-denied; **safe introspection** commands
  (`/context`, `/usage`, `/tools`, `/help`) run freely. Model choice is **at creation** (persisted in `m0011
  chat_sessions.model`); mid-conversation switch is deferred.
- **Context.** After Phase-20 the user noted the hand-built chat had lost the native CLI features (model switching, slash
  commands, context views). The 21-01 spike verified the surface against kiro-cli 2.16.2: models + agents come free on
  `session/new`; the command catalog arrives as a notification (autocomplete is client-side — the per-command `optionsMethod`
  isn't wired in 2.16.2); `execute` streams (panel commands may not return a terminal result headlessly → the prompt-path is
  the fallback); `contextUsagePercentage` + `promptCapabilities.image` are present.
- **Alternatives considered.** (a) Keep chat strictly read-only and expose nothing — rejected: the user explicitly wants the
  full CLI surface in both places. (b) Blanket-trust all tools when exposing commands — rejected: it would erase the Phase-13
  human-confirm guarantee; instead the permission bridge stays the backstop. (c) Multipart image upload — rejected for v1:
  base64 in the existing JSON SSE body is simpler and the SDK gates images on capability.
- **Consequences.** Bounded by **local single-user** (ADR-026). The SDK extensions are additive/backward-compatible
  (kiro-agent-sdk v0.7.0). A `chat_sessions.model` column (`m0011`) persists the choice. Applies uniformly to the main chat and
  the spec builder (the shared `ChatThread`/`Composer`). Refines ADR-031 (and ADR-033/034 lineage).

## ADR-046 — Genesis ships as a local, browser-based app via clone + git-tag self-update (Phase 22)

- **Status.** ACCEPTED — SHIPPED (Phase 22, genesis v0.47.0).
- **Context.** Genesis had only a *developer* setup (editable sibling installs) + a release protocol (tag + push) + CI that
  only tests — no way to ship to internal users. The requirement: a standard, working, **browser-based** install (no Mac app),
  local single-user.
- **Decision.** Ship as a **clone of the `genesis` repo + venv + `pip install .`** (the three internal deps resolve from their
  `git+ssh` tag pins → the user clones only `genesis`; `genesis-workflows` is pulled at runtime), launched by **`genesis up`**
  (backgrounds `genesis serve`, waits for health, opens the default browser at `http://127.0.0.1:8760`), and **updated in place
  from release tags** (`git fetch --tags` → on-tracked-branch guard → checkout `vX.Y.Z` → `pip install .` → `genesis db upgrade`
  → detached restart), surfaced as a one-click in-app banner. Modeled on `appian/prod/friday`'s clone+tag installer, **minus the
  native `.app`** (browser-only) since Genesis serves the SPA+API on one port. Add **in-app Kiro sign-in** (`kiro-cli` is the
  engine) and a **first-run preflight** checklist. Reuse existing pieces (`genesisctl.sh` → thin wrapper, `genesis db upgrade`,
  committed `web/static`, `/api/config/health`) and the SSH access users already have — **no package index / per-user token**.
- **Alternatives.** **Wheel + package-index** (GitLab/Artifactory) — "more standard packaging" but ~2.5–4 days one-time (4
  wheels incl. bundling `web/static`, convert git+ssh pins → version specifiers, publish CI, per-user index auth); **deferred**
  as a phase-2 transport (the launcher/updater/preflight/Kiro-login are transport-agnostic). **Docker** — poor fit (drives the
  host's kiro-cli + native-MCP `uv` + `gws` creds); out. **Native desktop app** — out (browser-only, per the requirement).
- **Consequences.** genesis-only, no schema. New surface: `scripts/install.sh`, `runtime/{launcher,updater,kiro_auth,preflight}
  .py`, `api/system.py`, web `features/system` + Settings Kiro sign-in, a `clean-install` CI job, `docs/INSTALL.md`. Tracked
  branch = **`master`**. Preserves ADR-026 (local single-user, localhost-only, no auth — must not be network-exposed) and
  ADR-031/045 (the `api/system` surface is local introspection + **local** process/install control only). Live acceptance
  (device-flow login + detached restart) is manual — headless-undrivable.

## ADR-047 — Genesis runs fixed, backend-defined scheduled maintenance syncs (Phase 23)

- **Status.** ACCEPTED — SHIPPED (Phase 23, genesis v0.48.0, CI green #6588951; migration m0012).
- **Context.** The Appian application sync was **not re-runnable** (the API rejected any non-baseline mode; re-running
  baseline errored), and a **true incremental delta** needs an Appian changed-objects API Genesis doesn't have — yet the KB +
  Document Library must stay fresh **daily**. Two needs: (1) a re-runnable **full-package refresh** of an application; (2)
  **scheduled** application syncs (all apps, each morning) + document-library syncs (every 4h during daytime), maintained in
  the backend now, user-configurable later.
- **Decision.** (1) **Expose the already-built full-package refresh** — the shipped `sync-application` `mode=delta` (16-07
  Option A) *is* a **full re-export → parse → diff the DB by `diff_hash` → write only the changes** (open new / close+reopen
  modified / close removed / diff edges / recompute bundles); unblock it at the API (`_resolve_mode`: auto-pick baseline↔delta;
  `refresh` alias), add a **per-app already-running 409** guard (the Appian Deployment export is serialized → HTTP 409), and a
  web **Refresh** action. It is **not** an environment delta-patch (that remains deferred, and is unnecessary for daily
  freshness). (2) A **lightweight in-process asyncio scheduler** (`runtime/scheduler.py`, started with `genesis serve`) ticks
  each minute and fires due jobs as their own tasks. Two jobs seeded in a DB table (**m0012 `scheduled_jobs`**, the seam for
  later user config): **`application-sync`** (all tracked apps, weekday **07:00 IST**, **serialized** — one export at a time,
  per-app mode-pick, skip an app already syncing, skip the job if no dev env / workflow uninstalled) and
  **`document-library-sync`** (weekday **08:00/12:00/16:00/20:00 IST**, one `sync-documents` `scope=library` run, skip if `gws`
  not connected / workflow uninstalled). Scheduling is **TZ-aware (IST), weekdays only, daytime slots**, and **restart-safe**
  (a persisted `last_fired_slot` embedding the local date → within-day catch-up, no cross-day re-fire; the slot is marked
  before the work so a long job can't double-fire). A read-only `GET /api/system/schedules` exposes state; **no write/config
  surface this phase**.
- **Alternatives.** *True incremental delta* (export only changed objects) — deferred (no Appian changed-objects API; backlog
  §1.3). *APScheduler / cron* — unnecessary now; a minute-tick + `daily_times` needs no new dependency (APScheduler is the
  documented fallback if cron strings are wanted). *A JSON marker for last-run* — rejected in favor of a **DB table** so the
  schedule is inspectable + user-configurable later. *Firing app syncs in parallel* — rejected: the Appian export is
  one-at-a-time (409), so the morning job runs apps **serially**.
- **Consequences.** genesis-only + **m0012** (`current_version` 11→12). New: `api/applications.py` mode-resolution + 409
  guard, `runtime/{scheduler,schedule_store,sync_jobs}.py`, `api/schedules.py`, `db/migrations/m0012_scheduled_jobs.py`, and a
  web Refresh action. Scheduled jobs are **read-only against Appian** (Deployment REST export) + local KB/document writes,
  **`auto_approve`, no HITL gates**, calling the same `RunManager.start` a human clicks — preserving **ADR-001** (LangGraph
  owns each sync's control flow) and extending the **ADR-033** "operator at the run-management layer" posture to a
  **non-interactive** actor; bounded by local single-user (ADR-026), no network exposure. Sync writes are SCD-2 (reversible
  history), not destructive. Live acceptance of the real morning/4-hourly firing is observed over time (fake-clock unit tests +
  a forced-slot manual run are the pre-release evidence).


## ADR-048 — Core Appian-MCP credentials are environment-scoped (entered on the environment, resolved from the dev env only)

**Status:** Accepted (2026-08-18; 24-01 shipped — genesis v0.48.5 + genesis-workflows v0.9.5, CI green). **Context:** the `appian-dev`/`appian-devops` creds (`LCP_USERNAME`/`LCP_PASSWORD`/
`LCP_API_PATH`, `APPIAN_API_KEY`) were entered on each MCP card and stored server-scoped in the SecretProvider
(`appian-dev/…`), split from the Environments tab that holds the same target's URL/dev-tag. **Decision:** for the two
**core** Appian MCPs ONLY, credentials are entered on the **environment** form and stored per-environment in the
SecretProvider under a new **`env:<label>`** scope; the Dev/DevOps MCPs resolve their creds **only** from the **dev-tagged**
env's scope (no server-scope/global lookup for these two). `LCP_API_PATH` becomes a **public** env field (in
`environments.json`, like `url`/`api_endpoint`); `LCP_URL`/`APPIAN_DOMAIN` stay **auto-derived** from the env's `url` and are
no longer surfaced as fields. All cred fields are optional. **Invariant preserved:** true secrets stay in the SecretProvider
(0600 + atomic, ADR/​v0.20.1 lesson) — never in `environments.json`. **Back-compat:** a one-time, non-destructive migration
copies legacy server-scoped creds into the dev env's scope (originals untouched, no longer consulted) — existing users
re-enter nothing. **Scope:** ONLY `appian-dev`/`appian-devops`; every other MCP keeps its own card. API exposes only
`is_set` booleans for creds, never values. **Localization:** genesis-core `McpRegistry` is untouched — a thin genesis-side
SecretProvider adapter (in `ConfigService`) maps these two servers' lookups to `env:<label>`. Spec:
`specs/phase-24-ux-revamp-and-environment-credentials/24-01-environment-credentials.md`.

## ADR-049 — Applications-first IA: primary nav is Applications · Chat · Runs · Documents; Overview + Catalog live under Settings

**Status:** Accepted (2026-08-18; shipped — genesis v0.48.6, CI green). **Context:** user feedback that the 6-destination primary nav (Overview, Chat, Runs,
Applications, Documents, Catalog) is too broad and the landing should be work-focused. **Decision:** **Applications** is the
landing page (index route) and first primary tab; the primary sidebar is reduced to **Applications · Chat · Runs ·
Documents**. **Overview** (metrics) and **Catalog** (Workflows | Skills browse/launch) move into the **Settings** workspace as
tabs (two zones — Workspace: Overview, Catalog; Configuration: MCP, CLI, GitLab, Environments, General), with **Overview as
the default Settings tab**. The `/catalog/:workflowId[/launch]` deep-link routes are retained (the Copilot launch flow uses
them); only the sidebar entry is dropped. `/` renders Applications (no redirect). Kept the container name "Settings" (Option
A); a later rename to "Manage"/"System" (Option B) is noted as optional follow-up since Overview/Catalog are not strictly
config. Frontend-only; still ships a genesis release (committed `web/static`). Spec:
`specs/phase-24-ux-revamp-and-environment-credentials/24-02-nav-and-ia-revamp.md`.

**Amendment (2026-08-24, Phase 27-11, shipped in genesis v0.53.0):** the landing is refined into a **Home
dashboard**. The primary nav item **"Applications" is relabeled "Home"** (home icon; the route stays `/applications`,
`/` still redirects there). The **at-a-glance metrics + run trend** (the reused `OverviewSection`) **move from the
Settings → Overview tab onto the Home page**, rendered above the tracked-applications grid. Consequently the Settings
**"Overview" tab is removed**; the remaining system-observability panel (`MetricsSection`, 25-13) becomes a lean
**"Metrics"** tab, and the **default Settings tab is now Catalog**. This partially reverses the original "Overview lives
in Settings" decision (user feedback: metrics belong on the landing, and this matches the approved 27-03 mockup's
Dashboard concept). The standalone `OverviewPage`/`/overview` route is retained for deep links. Frontend-only. **Refined same day (user):** Settings is now **configuration-only** — the **Catalog and Metrics tabs are removed** too. Catalog is reached via its top-level nav; the system-metrics breakdown (`MetricsSection`) is **relocated onto the Home dashboard** (below the at-a-glance band) so no observability is lost. Settings = MCP · CLI · GitLab · Environments · General (**default MCP**); the Workspace/Configuration zone split is dropped.


## ADR-050 — Typed SDLC domain + single-authority LifecycleService (Phase 25-01)

**Status:** Accepted (2026-08-18; shipped — genesis v0.49.0, CI green). **Context:** the code-review flagged SDLC lifecycle
status as loose strings mutated last-write-wins from route handlers (any→any possible; no audit; validation scattered).
**Decision:** model the SDLC domain as typed objects (`genesis/domain/`: `enums`/`entities`/`transitions`/`lifecycle`/
`events`/`errors`) and route **every** status change through one authority — `LifecycleService.transition(kind, id, action)`.
It resolves `(state, action)` against a declarative transition table (a missing pair → `IllegalTransitionError`; a legal pair
with an unmet precondition → `PreconditionFailedError`), persists via injected store accessors, and emits a `LifecycleEvent`
recorded append-only to **m0013 `lifecycle_transitions`** (`LifecycleAuditStore`). API becomes action-based:
`POST /features/{id}/spec/actions/{action}` + `GET .../spec/allowed` (illegal/precondition → **409** with the allowed set);
the any-status `PATCH .../spec/status` is deprecated. The web replaces its status `<select>` with allowed-action buttons. The
service is store-agnostic + unit-testable without a DB. Extended in 25-08 with a state-CAS so concurrent transitions can't both
win. Spec: `specs/phase-25-architectural-foundation-hardening/25-01-typed-domain-and-lifecycle.md`.

## ADR-051 — AgentProvider interface over the agent runtime (Phase 25-05)

**Status:** Accepted (2026-08-18; shipped — genesis-core v0.9.4, CI green). **Context:** `nodes/agent` bound the workflow-agent
turn directly to the Kiro/ACP loader, making the runtime hard to swap or mock and coupling the engine to one agent backend.
**Decision:** introduce an `AgentProvider` Protocol (`genesis_core/agents/`) with `KiroAcpProvider` as the default (wrapping the
existing `_load_real` resolver), injected via `get/set_agent_provider`; `nodes/agent._run` drives turns through the provider.
Behavior-preserving (the `set_collect_impl` test seam still works); additive, `CORE_MAJOR` unchanged. This is the seam a future
non-Kiro provider or a chat session-provider plugs into (the chat session-provider is deferred). Its sibling **ADR-052
DocumentProvider** (25-09) remains **Proposed** — not yet built. Spec:
`specs/phase-25-architectural-foundation-hardening/25-05-agent-provider-interface.md`.

- **ADR-053 (ACCEPTED — Phase 26, SHIPPED genesis v0.52.0 + genesis-workflows v0.10.0)** — the **Genesis Agentic
  Memory Layer**: personal (named-user) vs shared (entity-anchored, traversable) memory × semantic/episodic/procedural,
  bi-temporal; a nightly `memory-consolidation` + a periodic `memory-maintenance` ("dreaming") workflow; a read-only
  `genesis-memory` MCP (hybrid retrieval) as the ONLY injection path (steered, no auto-prefetch); a browser-only curation
  API + `/memory` UI where human edits are authoritative + exempt from maintenance. Deferred (seams built): multi-user ACL,
  auto-prefetch, hard-delete, agentic-node MCP injection. Specs: `specs/phase-26-agentic-memory-layer.md` + `26-01..26-08`.
- **ADR-054 (ACCEPTED — Phase 26, SHIPPED genesis v0.52.0)** — memory **store/infra + local embedder**: a separate
  `~/.genesis/memory.db` (`mm0001`; bi-temporal graph + FTS5 + `sqlite-vec`) behind DB-agnostic seams (`MemoryStore`/
  `GraphStore`/`VectorIndex`/`Embedder`) for a future Postgres+pgvector re-home; a small LOCAL embedder (model2vec default)
  loaded only in the worker/MCP subprocess, degrading to NullEmbedder when absent. `genesis db upgrade` covers both DBs.


## ADR-052 — DocumentProvider interface for document sourcing (Phase 25-09)

**Status:** Accepted (2026-08-19; shipped — genesis v0.50.0, CI green). **Context:** the `gws` Google-Drive
connector was reasonably isolated (`integrations/gws/`, `DocumentSyncEngine` via `ctx.extras`) but there was
**no `DocumentProvider` interface** — a second source (SharePoint) would mean a sibling adapter wired through
`DocumentSyncEngine` with branches (review §F/§19/§20). **Decision:** document *sourcing* (resolve metadata +
change-fingerprint, fetch bytes) sits behind a thin Protocol (`genesis/integrations/documents/`:
`DocumentProvider` + provider-neutral `DocRef`/`DocMeta` + `DocumentProviderError`), with `GoogleDriveProvider`
as the first implementation (wrapping the read-only `gws` connector; `resolve`=get_file+fingerprint,
`fetch`=export[native]/download[binary]). `DocumentSyncEngine` depends on the interface, not `GwsClient`; the
`gws_provider` ctor arg stays back-compat (auto-builds the default registry), and `runtime/context.py` injects
`build_document_providers()` at the composition root. A second source is now an **additive adapter + one
registry entry**. The fingerprint (Drive revision/md5) drives stale-detection (§21). **Constrained scope
(§36):** define capability interfaces only where a 2nd implementation is plausibly on the roadmap — documents
qualify; the **Appian Deployment REST export stays concrete** until a second deploy target exists. Uploads
remain a built-in local path. Spec: `specs/phase-25-architectural-foundation-hardening/25-09-document-provider-interface.md`.

## ADR-026 amendment (Phase 25-04) — localhost-bind guardrail

**Status:** Accepted (2026-08-19; shipped — genesis v0.49.0). Amends ADR-026's local-single-user posture: since
Genesis ships **no authentication**, `genesis serve`/`up` **refuse a non-loopback bind** (e.g. `0.0.0.0`/`::`)
unless the operator explicitly opts in via `--i-understand-no-auth` / `GENESIS_ALLOW_NON_LOOPBACK=1`. This
prevents accidentally exposing an unauthenticated app on the network while keeping the intended localhost use
frictionless. Implemented in `runtime/launcher.py` + the `serve`/`up` CLI handlers. Spec:
`specs/phase-25-architectural-foundation-hardening/25-04-network-exposure-guardrail.md`.


## ADR-055 — UI/UX design language + light-first theming (Phase 27) — **Accepted**
- **Status:** **Accepted** (2026-08-21, with the user, in Phase 27 sub-phase **27-01**; findings: `specs/phase-27-ui-ux-revamp/27-01-findings.md`).
- **Decision:** Modernize the entire web UI to a **light-first** (light is the hard default; dark stays a first-class, persisted, toggleable theme — the toggle already exists in Settings→General→AppearanceSection) **modern, future-looking** design language using **MUI / Material Design 3 as the visual/UX north star**. **Evolve the existing token + Tailwind + shadcn-style primitive system to a MUI-inspired language** — **do NOT** adopt `@mui/material` as a dependency. Hi-fi mockups are **coded in the `/dev` KitchenSink** (double as the 27-04 foundation).
- **Context:** The app grew dark-default across Phases 7–26 and reads as "outdated" (user, 2026-08-21). Theming is **already token-driven** (`web/src/styles/tokens.css` `:root/.theme-dark` + a full `.theme-light`; `tailwind.config.ts` maps colors → `var(--*)`), so a light-first default is a palette refinement + default flip + persisted toggle + reconciling the one hardcoded-hex surface (`memory/MemoryGraph.tsx`, v0.52.1), not a rewrite. Reference: https://github.com/mui.
- **Alternatives:** (a) **Adopt `@mui/material`** — best OOTB Material-3 + a11y, but a large migration off the proven Tailwind/token system, heavier bundle, and divergence from the existing gate discipline; (b) **Evolve the existing primitives** to a MUI-*inspired* language — lower risk, keeps tokens/gates/`/dev` gallery, more bespoke work (**recommended**); (c) keep dark-default / cosmetic-only re-skin — rejected (doesn't meet the ask).
- **Rationale (for evolve):** the token/Tailwind foundation already makes theme-switching a pure variable swap and already carries jest-axe + build gates; evolving it delivers the modern light-first language with the least regression risk and no framework churn (ADR-027 stack respected).
- **Consequences:** Phase 27 is **frontend-only (genesis)**, behaviour-preserving; per-phase `web/static` rebuilds + releases. If the user instead chooses to adopt MUI, a follow-on ADR-056 (component-library adoption + migration/bundle plan) is required before 27-04. Light becomes the default theme (dark parity maintained). Final medium for mockups (coded-in-`/dev` vs static) is set in 27-01 (umbrella §6).


## ADR-056 — The Genesis Feature Workspace (parallel, plug-in stages) (Phase 28) — **Accepted**
- **Status:** **Accepted** (2026-08-25, Phase 28; final design: `specs/phase-28-feature-revamp/28-03-final-design.md`; **built 28-04**, **independent review 28-05 = SHIP**). Ships in the **28-06** genesis release.
- **Decision:** A **Feature is a workspace** of **parallel, independently-advanceable, plug-in stage containers** (Spec, UX Design, Technical Design, Feature Breakdown) over a shared **artifact + version/provenance + activity + lifecycle** substrate. Each stage is governed by its **own `LifecycleService` machine** (ADR-050; m0013 audit), addressed per **(feature, stage)**. Primary UX = a **command-center Overview + peer stage cards** with a **non-gating** progress indicator (no stepper/wizard); opening a stage routes to a **dedicated full-bleed stage workspace** (its own URL, deep-linkable) with an **Expand → immersive** toggle. Overall feature status is **derived** (roll-up) from stage states with an explicit **Blocked/Cancelled** override. **Single-user** — no assignment/roles/permissions/lenses/My-Work (ADR-026). **Read-only-now** — story execution (implementation/code-review/deploy/verify), the git/branch model, and environment promotion are **reserved plug-points** (future program, own ADRs; ADR-021/033). **Stories** are a **reserved first-class slot** for a later phase. Reuses the Phase-27 design language (ADR-055) + Phase-20/21 spec authoring + versioning.
- **Context:** ADR-044 modeled a feature as a **sequential** artifact pipeline (unlock-on-completion; Design/Breakdown as disabled placeholders). Real usage wants **parallel, any-order** work, and Genesis needs a durable frame future capabilities plug into. The `domain/` layer (ADR-050) is already generic — `ArtifactKind` (SPEC/UX_DESIGN/TECHNICAL_DESIGN/BREAKDOWN…) + a forward story-stage machine already exist — so this is mostly **composition + UX** + a generalized per-stage artifact model (28-01 findings).
- **Alternatives:** (a) keep the sequential pipeline — rejected (doesn't match usage); (b) **stages-as-tabs** — rejected (hides peers; no at-a-glance parallel view; crowds as Stories/Artifacts/Activity are added); (c) a **stepper/wizard** — rejected (implies gating, the opposite of the goal).
- **Consequences:** **Supersedes ADR-044's sequential unlock-on-completion clause** (the feature-as-workspace + per-artifact-status core of ADR-044 stands). A **small additive migration** (`m0015` — a `kb_feature_stages` table, or a `stage`-column refinement of `kb_feature_specs`) may be introduced (ADR-030/019 respected; `CORE_MAJOR` unchanged; bump `current_version` tests). Each future stage ships as **"inner surface + one transition row + one `ArtifactKind` + one `StageDescriptor`"** with **no** shell/Overview/rail changes. Frontend-heavy genesis release at 28-06 (other repos expected unchanged).

## ADR-057 — The UX Design stage: grounded mockup→implementation analysis (Phase 29) — **Accepted**
- **Status:** **Accepted** (2026-08-28, Phase 29; specs `specs/phase-29-ux-design-stage.md` + `phase-29-ux-design-stage/29-01..29-06`). Refines ADR-056 (the first `available:true` stage after Spec). **Component reuse (user directive, finalized 29-03):** the UX stage renders through the **same, generalized Spec-page components** — `SpecWorkspace`→`StageArtifactWorkspace`, `PreviewDialog`→`AnnotatablePreviewDialog`, `SpecBuilderPage`→`StageBuilderPage`, the reused `ChatThread`, and stage-scoped hooks — for an identical UX; Spec keeps working (regressions green), enabled by the m0015 model making Spec + UX the same shape. Drafted 29-01, finalized 29-03 (`29-03-final-design.md`), **built + Accepted at 29-04; **released 29-06** (kiro-agent-sdk v0.7.1 · genesis-core v0.9.6 · genesis v0.55.0 · genesis-workflows v0.12.0; CI green). Added a StageFinalizer (RunManager observer) that bridges a completed run into the stage (opens the ux_design completion chat + copies analysis.html + sets in-review); the worker resolves the internal `genesis-kb` as a managed MCP so workflow nodes can inject it.
- **Decision:** A Feature's **UX Design** stage ingests an uploaded **PDF** mockup deck and produces a single **"UX Implementation Analysis"** HTML artifact via a deterministic **`ux-design-analysis`** LangGraph workflow (ADR-001): program nodes render/route/persist; narrow **multimodal** Kiro agent nodes (reliability trio each, ADR-011) do judgment; a **grounded verification (critic)** node re-checks the doc before it is presented. The analysis is **grounded** in three sources reconciled **per screen**: the mockup page images + the feature's **Spec** (authoritative text) + the **live Appian environment** — **structure/dependency/impact from the internal `genesis-kb`**, and the **actual interface code from the `appian-dev` MCP** (heavy reliance). Output stays **intent-level** (screen/interaction + an explicit affected-objects list), NOT object-level SAIL design (that is the later Technical Design stage). It includes a **blind-spot / ripple-effect** section (a KB dependency/impact query on affected objects) + **Open Questions**. A bound **`ux_design` completion chat** (a `ChatModeProfile`, reusing the Phase-20/21 sandbox + annotatable Lavish review) then walks the open questions, editing the HTML live as the user answers (with genesis-kb + appian-dev **read** tools for on-demand re-checks), until the stage is marked **completed**.
- **Context:** Phase 28 (ADR-056) shipped the Feature Workspace framework with UX Design as a first-class `not-available` plug-point. The real SDLC hands developers a mockup PDF/deck with comments; a developer manually reads it screen-by-screen, cross-references the spec, opens the live app, and writes up what must change + asks the open questions. This automates that **analysis** (not mockup *creation*, which is a later roadmap item). The SDK already supports image prompt parts (gated on `promptCapabilities.image`) and chat uses them, but `genesis-core`'s `kiro_node` had no image path; `doc_parsing` is text-only; ADR-056 reserved an additive `m0015` per-stage artifact model.
- **Alternatives:** (a) one-shot multimodal turn over the whole deck — rejected (multimodal models reproduce layout but miss data-binding/interaction/structural consistency and are weak at holistic UI reasoning; per-screen decomposition + grounding is far more reliable); (b) an ungrounded self-critic — rejected (documented "progress mirage"/self-evaluation bias; the critic must be externally grounded in the images + spec + live notes); (c) native PPTX ingestion in v1 — rejected (no pure-Python renderer; adds a LibreOffice system prerequisite — PDF-only, PPTX deferred); (d) object-level UX→SAIL output — rejected (overlaps the future Technical Design stage).
- **Consequences:** Enablers — additive **image support in `kiro_node`** (thread blackboard image files → `client.prompt(images=…)`, gated on the capability, graceful no-op when absent; `CORE_MAJOR` unchanged); **PyMuPDF** (pinned) for PDF→PNG rendering off the event loop; the ADR-056-reserved **`m0015`** generalized per-`(feature, stage)` artifact/lifecycle model + a `ux_design` `LifecycleService` machine (ADR-050; m0013 audit; `current_version` → 15, additive). The UX stage becomes the **first `available:true` stage after Spec**, plugging into the ADR-056 framework via a `STAGE_DEFS` row + a `stage-registry` entry + an inner workspace — **no shell edits**. **Read-only** against Appian (ADR-036/037; appian-dev read allowlist; the completion chat's only write authority is the fs sandbox HTML edit — ADR-031/045). **Re-upload replaces** (deletes prior page images + supersedes the artifact) and re-runs. **Multi-repo** release (core → genesis → genesis-workflows; keep the pin chain consistent — §7). Reuses ADR-035 (file upload), ADR-042/043 (HTML-authoritative artifact + Lavish review). **Spec-model decision A (locked 2026-08-28):** the existing **Spec** stage is fully migrated + repointed onto `kb_feature_stages`/StageStore (m0015 copies the data); `kb_feature_specs` is **NOT dropped** — kept as a dead table for rollback safety, retired later. **Safe for existing (single-user, local) installs**: the copy runs at the offline `genesis db upgrade`, preserving absolute `html_path` pointers + `chat_session_id`; no data loss.
