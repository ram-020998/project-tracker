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

## Open decisions (to resolve early — see tracker §5)
- **OD-1:** Does LCP MCP reliably author Appian objects? (Unblocks write-path/flagship workflows — Phase 8 spike.)
- **OD-2:** Does ACP honor `KIRO_API_KEY` for headless/CI contexts?
- **OD-3:** Session-pooling for many one-shot ACP sessions (perf) — measure first.
