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
