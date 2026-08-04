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

**Status:** Proposed (Phase 16).

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

**Status:** Proposed (Phase 16).

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

## ADR-038 — Managed native Appian MCP servers (vendored, versioned, updatable-from-source, not forked) (Phase 16)

**Status:** Proposed (Phase 16, sub-phase 16-08).

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
4. **Update sources:** the **Dev MCP** is re-fetched from **the connected environment** itself
   (`{LCP_URL}/suite/plugins/servlet/stateless/lcp-mcp-bundle`), so it always matches the site's plugin version (drift
   resolved); the **DevOps MCP** is installed from a **configured/drop-in versioned artifact** (App-Market tarball).
   Updates are versioned + reversible + sha-verified.
5. **Never modify the bundle source** — modification would break updatability. All Genesis glue (launch spec, env,
   allowlist, lockfile) lives outside the bundle.

**Alternatives considered.** (a) Fork the servers into Genesis — rejected: forking forfeits upstream updates (the exact
thing the user requires). (b) Static curated `mcp-registry.json` image lines — rejected: these are local, per-machine,
version-varying installs, not fixed images (the old `lcp` `<lcp-image>` placeholder was never a real image). (c) Docker
images — rejected: the official bundles are `uv`-run local Python, not containers; adding Docker adds a heavy prereq.
(d) `pip install` from an index — rejected: the Dev MCP ships vendored editable path deps (`lib/`/`sdk/`) and is
distributed as a site-served bundle, not a PyPI package.

**Consequences.** Genesis runs the official Dev/DevOps MCP unmodified and can pull+apply Appian's updates (Dev = from the
connected site, DevOps = from a configured artifact), versioned and reversible. New prerequisite: **`uv`** on PATH at
install time (run time uses the created venv); the Dev MCP install is sizeable and needs Python 3.13 (matches ADR-024);
playwright/browser auth stays an opt-in manual step for SSO-only sites. Read-only posture preserved via the allowlist
cap (ADR-029); write/deploy remain out of scope (Section E) until a later phase gates them behind `pre_mutation`
(ADR-021/033). Pairs with ADR-036/037 (KB internalized; environment access via these managed native MCPs).
