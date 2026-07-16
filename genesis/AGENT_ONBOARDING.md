# Genesis — Agent Onboarding & Reference ("the bible")

> **Purpose.** This is the single, task-agnostic document that brings any new agent session fully up
> to speed on Genesis: what it is, how it's built, the decisions behind it, what has shipped, the
> operating rules, and how to do work of any kind. Read this end-to-end (and the linked docs/code it
> points to) and you should be able to take on *any* task in the program — a bug fix, a new feature,
> a new phase, a refactor, a release, or a question — without further ramp-up.
>
> **This document does not assign a task.** The task comes from the human in the session. Your job
> after reading is to (1) briefly restate the architecture + current state + the non-negotiables, and
> (2) do whatever work is asked, following §8's loop.
>
> **Keep this current.** When tags, architecture, ADRs, or hard-won lessons change, update §2 (state),
> §5 (ADRs), §7 (lessons), and §9 (roadmap). **Last refreshed: 2026-07-16 — genesis v0.25.0 +
> genesis-core v0.8.1 + kiro-agent-sdk v0.5.0 + genesis-workflows v0.5.3** (Phases 9 Agent-Artifact-I/O,
> 10 Chat-assistant, 11 Credit-tracking, 12 Appian Code-Review Workflow all shipped). **Phase 13 —
> Chat Copilot & Run Orchestrator — COMPLETE (13-01..13-06 shipped): the copilot slash-launches a
> workflow, confirms every mutation, supervises gates/terminals in-chat, and is safety-hardened
> (kill-switch + concurrency/rate/allow-deny + a copilot_actions audit trail); ADR-033 Accepted. The
> only remaining item is manual live-acceptance vs. real kiro-cli (can't be driven headlessly).** **NEXT
> WORK — Phase 14: Skills in Chat (SPEC DRAFTED, spike-first done, awaiting approval to implement).** Add
> **Skills** (Kiro's portable `SKILL.md` packages) as a second first-class capability beside Workflows — a
> *standalone activity* (draft a doc, build a checklist, apply a body of knowledge like GAM), owned by the
> Kiro agent, no stages/run. If your session starts Phase 14, read `specs/phase-14-skills-in-chat.md`
> (umbrella) + `phase-14-skills-in-chat/14-01..14-05` + **ADR-034** + the proving spike
> `spike/2026-07-16-kiro-skills-in-acp-and-chat.md` before touching code. Other candidates: the Phase-12/13
> live runs, or the skill-migration backlog.

---

## 0. What Genesis is (one paragraph)

Genesis is a **local, single-user web application** that lets a Solutions engineer discover, install,
run, and supervise **workflows**. A workflow is a **LangGraph** graph whose nodes are deterministic
**program** steps or narrow **agent** steps that drive **Kiro** via `kiro-agent-sdk` over ACP,
injecting only the MCP server(s) that step needs. LangGraph owns control flow + durable state; a
per-run artifacts folder (the **blackboard**) holds bulk data; workflows are pulled from the shared
`genesis-workflows` GitLab repo via selective install + a lockfile. Every agent step is wrapped by a
program **validator + retry/escalation** (hard requirement). Genesis replaces the retired
solutions-copilot, which failed by using an LLM as the orchestrator. Backend = **FastAPI embedding
LangGraph as a library** + disposable **subprocess workers**; frontend = **React + TypeScript SPA**
served by the same backend. It runs on localhost with the user's own credentials. The destination is
"enterprise-grade polish" but **still local single-user** — multi-user/hosted is an explicitly separate
future track (ADR-026); **do not build auth/multi-tenancy unless asked.**

---

## 1. How to onboard (read order — don't skip)

**A) Design + as-built docs — `/Users/ramaswamy.u/repo/project-tracker/genesis/`**
1. `README.md` — one-screen orientation.
2. `tracker.md` — the master record. **Read §6 STATUS LOG top-down** (it is the running history and
   the source of truth for "what is done"); §2 has the locked decisions Q1–Q14; §3 is the phase index.
3. `specs/00-architecture-overview.md` — layers, domain model, node taxonomy, state/blackboard rule.
4. `reference/decision-log.md` — **ADR-001…033** (the "why"). Every non-negotiable lives here.
   (Recent: ADR-031 Chat is read-only; ADR-032 credits are REAL metered data; ADR-033 **proposed** —
   the Chat copilot may operate runs at the run-management layer, human-confirmed, Phase 13.)
5. `reference/coding-standards.md` — enforcement-anchored standards. §1 is the hard floor (lints/
   typecheck/CI gates that fail the build); §2–§6 are Python/frontend/testing conventions + the
   Definition of Done. When it conflicts with an ADR, the ADR wins; if a task needs a deviation, flag it.
6. `reference/` (the rest): repo-structure, node-taxonomy-reference, state-and-data-model,
   mcp-and-cli-registry, workflow-authoring-standard, reliability-standard, hitl-design,
   security-and-secrets, testing-strategy, langgraph-capability-map, solutions-copilot-relationship,
   glossary, roadmap-and-sequencing, spike-findings.
7. `specs/` — the plan for each phase. Phases 1–6, the web-revamp (`phase-07-0N-*`), the
   `phase-07-code-review-fixes/` program (01–06), `phase-08-settings-revamp.md`, **`phase-09-agent-artifact-io.md`,
   `phase-10-chat-assistant.md` (+ `phase-10-.../10-01..07`), `phase-11-credit-usage-tracking.md`,
   `phase-12-code-review-workflow.md`** are all **shipped**. **`phase-13-copilot-orchestrator.md`
   (+ `phase-13-copilot-orchestrator/13-01..13-06`) is a DRAFT — the active next work (planning only,
   spike-first).** `specs/backlog/` holds
   deferred work (the skill-migration program).
8. `progress/` — the as-built record, one file per phase/item (`phase-01..11-*`). Read the one(s)
   relevant to the area you're touching; they cite commits, tags, CI pipelines, and decisions.
9. `spike/` — time-boxed feasibility probes (throwaway code, durable findings). Read the relevant one before
   building on its area (e.g. `spike/2026-07-16-kiro-skills-in-acp-and-chat.md` proves Kiro Skills over ACP for
   Phase 14).

**B) The code — `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`** (read before editing; §4 is the map)
- `genesis-core/genesis_core/**` — shared engine/SDK (nodes, state, registries, validators).
- `genesis/genesis/**` — the platform (runtime, dist, config, runs, api, cli, lint, db).
- `genesis/web/**` — the React+TS workbench (the shipped app; `web/static/` is the served bundle).
- `genesis-workflows/**` — the library (registries, steering, workflows, CI publish gate).
- `kiro-agent-sdk/src/kiro_agent_sdk/**` — the ACP adapter (read `client.py` + `__init__.py`).
- tests: `genesis/tests/**`, `genesis-core/tests/**`, `genesis-workflows/workflows/*/tests/**`.

**After reading, be able to restate:** the layered architecture, the reliability trio, the
state/blackboard rule, the subprocess-worker execution model, the data plane (SQLite + migrations),
and the release/versioning protocol.

---

## 2. Current state (as of genesis v0.20.2)

Four repos at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`, all pushed to
`git@gitlab.appian-stratus.com:ramaswamy.u/<repo>.git`:

| Repo | Tag | Branch | Role |
|---|---|---|---|
| `kiro-agent-sdk` | **v0.5.0** | main | ACP adapter; `collect`/`collect_streaming`; `permission_mode`(`auto_approve`/`auto_deny`/**`ask`**)+`allow_fs_write`; **per-turn credit metering (11-01)**; **interactive permission bridge `permission_mode="ask"`+`on_permission` callback (13-01)** |
| `genesis-core` | **v0.8.1** | master | nodes/state/registries/validators; two-tier MCP/CLI registry + introspection (ADR-029); session tool-output store (Phase 9); telemetry carries **metered credits** (Phase 11); `CORE_MAJOR=1` (v0.8.1 = sdk pin→v0.5.0, no code change) |
| `genesis` | **v0.25.0** | master | runtime, dist, config, runs, **db (m0001–m0006)**, api (`/api`+SPA), cli, web SPA; **Chat** (Phase 10); **credit tracking** (Phase 11); worker loop `recursion_limit` (12-01); **Copilot: control MCP server + permission bridge + run↔session link + run-supervision bridge + slash-launch/HITL web UI + safety/audit hardening (Phase 13-01..06 COMPLETE)** |
| `genesis-workflows` | **v0.5.3** | master | registries (incl. `jarvis`+`jira` MCP), steering, `hello-appian` + `erd-generation` + **`code-review` (Phase 12; v0.5.1–v0.5.3 = live-data robustness fixes)** |

**Dependency chain** (git-pinned by tag; CI rewrites ssh→https):
`genesis (v0.25.0) → genesis-core@v0.8.1 → kiro-agent-sdk@v0.5.0`;
`genesis-workflows → genesis-core@v0.5.0 (runtime) + genesis (dev pin)`. (`code-review` needs genesis ≥ v0.20.2 at runtime for the loop.) The Phase-13 SDK `permission_mode="ask"` bridge (v0.5.0) is now pinned across genesis + genesis-core (bumped together since both pin the SDK directly).

**Tests, all green at last release:** genesis **180** pytest · genesis-core **57** · kiro-agent-sdk
**62** · genesis-workflows **~22** (incl. 13 code-review) · web **101** Vitest (incl. contract-fixture
drift tests + jest-axe). ruff clean; eslint clean (0 errors); `tsc` strict clean. CI green on all code
repos (genesis has a python `genesis` job + a `frontend` job with a stale-bundle guard; the SDK repo
has no CI — validated transitively by core+genesis installing its tag).

**Milestones (see `roadmap-and-sequencing.md`):**
- **Phases 1–6 — DONE (M1–M6):** engine + node framework + state/checkpointer/blackboard + MCP
  registry + reliability trio; workflow contract + library + scaffolder + CI enforcement; distribution;
  config + secrets + env registry + health; run orchestration + all 3 HITL modes + streaming; ERD.
- **Phase 7 WEB REVAMP + Code-Review Fix Program (01–06) — DONE + shipped.** React+TS workbench;
  persistence/migrations, Overview, Integrations Studio (ADR-029), retention, SQLite decision (ADR-030),
  conversation rich-chat.
- **Phase 8 — Settings & Integrations Revamp — SHIPPED (v0.16.0).**
- **Phase 9 — Agent Artifact I/O — SHIPPED** (sdk v0.2.0, core v0.6.0, genesis v0.17.0, workflows v0.4.0):
  a per-run tool-output store + agent `save_tool_output`/`list_tool_outputs` (save-by-reference) so large
  MCP results land in the blackboard with zero re-emission into the context window.
- **Phase 10 — Chat Assistant — SHIPPED** (sdk v0.3.0, core v0.7.0, genesis v0.19.0; ADR-031;
  m0002 migration): a read-only conversational Chat page — talk to Kiro (Atlas read MCP) + query all
  Genesis state via a read-only introspection MCP server (`genesis/mcp/introspection_server.py`).
  Follow-ups: Atlas read `tool_allowlist` (workflows v0.4.2), CRLF SSE streaming fix (v0.19.1), a UI
  polish batch (v0.19.2: breadcrumbs, list-view, collapsed nav, clickable catalog cards).
- **Phase 11 — Credit & Usage Tracking — SHIPPED** (sdk v0.4.0, core v0.8.0, genesis v0.20.0; ADR-032;
  m0003 migration): REAL metered per-turn Kiro credits surfaced everywhere — per agent node + run-total
  (Run Detail), Overview KPI (**Credits Used** replaced Tool-Calls), per chat message + session total.
  Then **v0.20.1**: chat shows the credit count in place of the "Turn complete" chip + a secrets
  atomic-write crash fix (see §7).
- **Phase 12 — Appian Code-Review Workflow — SHIPPED** (genesis v0.20.2 for 12-01; genesis-workflows
  v0.5.3 for 12-02..12-05): a deterministic port of the Jarvis code-review process (Google-Docs export
  excluded). Entry via JIRA ticket / package URL / object names; per-object review loop (diff-aware →
  `analyze_appian_code` → dynamic checklist → SQL/i18n `query_sql` → RecordType relationships) with a
  code-enforced PRE-WRITE CHECKPOINT validator; agent-proposed / program-confirmed verdict. Read-only
  by construction (per-node `@jarvis`/`@jira` allowlists; no registry cap on jarvis). 12-01 added the
  worker loop `recursion_limit` (from `META.execution.recursion_limit`, default 150). `jarvis`+`jira`
  MCP registered + connected. Live run against a real ticket still pending.
- **Backlog:** `specs/backlog/skill-migration-program.md` (45-skill migration; deferred). **Do not start
  backlog/Phase-N work unless asked.**

**What works today (verified):**
- `genesis serve` → FastAPI backend + SPA at `http://127.0.0.1:8760`. API under **`/api`**, Swagger at
  `/docs`, SPA history fallback (ADR-028).
- **Screens (all live):** Overview (metrics incl. **Credits Used** KPI + trend + active runs + integration
  health); Runs list; Run Detail (React Flow graph + inspector + turn-grouped Kiro conversation + all-3
  HITL + documents drawer + **per-node & run-total credits**); Catalog (browse/detail/launch, clickable
  cards); **Chat** (read-only assistant, persisted sessions, per-message credit footer); **Settings**
  (MCP · CLI · GitLab · Environments · General). Left nav collapsed by default.
- **Data plane:** durable SQLite (`~/.genesis/genesis.db`, WAL) via `genesis/db/` migrations
  (m0001 runs+events, m0002 chat, m0003 chat_usage, m0004 copilot [chat_sessions.mode +
  chat_run_links + chat_permissions], m0005 supervision [chat_notifications], m0006 copilot_actions [audit]; `current_version=6`); runs + full conversation +
  checkpoints + chat sessions/messages persist across restart; retention available.
- **Credits (Phase 11):** every agent turn (workflow node OR chat message) reports real credits from
  Kiro's `_kiro.dev/metadata.meteringUsage`; aggregated per-run (`eventlog.aggregate_credits` via
  `json_extract` over `agent.result`) and per-session (`chat_messages.usage`). Provenance
  `metered`/`partial`/`unavailable` — the UI shows honest "n/a", never a fabricated number.
- **Integrations Studio (ADR-029):** curated (MR-governed) + custom (`~/.genesis/mcp-custom.json` /
  `cli-custom.json`) tiers; per-node injection. `jarvis` (read-write-deploy) + `jira` registered.
- `hello-appian` runs GREEN end-to-end; `erd-generation` runs into the live Atlas fetch. All 3 HITL
  modes, streaming, worker isolation, checkpoint resume — implemented + tested.
- **Dev:** `npm run dev` in `genesis/web` → `http://localhost:5173/` (Vite proxies `/api` → :8760).
  Design-system gallery at `/dev`.

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

## 4. Codebase map (where things live)

```
genesis-core/genesis_core/
  types.py        PlatformContext (run_id, workspace, mcp, clis, settings, emit, secrets,
                  environments, checkpointer, extras); ValidationResult; Node(name,fn,kind);
                  CORE_MAJOR=1; CompatError; check_compat; CTX_KEY="genesis_ctx"; ctx_from_config.
  state.py        PlatformState TypedDict + reducers; new_state, record_artifact, record_decision.
  workspace.py    RunWorkspace (per-run blackboard) + Doc + default_artifacts_root.
  validators.py   toolkit: non_empty, parses_json, json_schema, required_keys, values_in_set,
                  count_between, first_field_is, excludes, referential_integrity, all_items_present,
                  matches_predicate, all_of, any_of (`_dig` dotted paths w/ []).
  mcp/registry.py   McpRegistry.acp_servers(names) -> ACP entries {name,command,args,env:[{name,value}]}
                    (env is a LIST — see §7). from_layers(curated,custom) merges the two tiers (ADR-029);
                    allowlist()/servers(). Resolve: SecretProvider → EnvironmentRegistry → os.environ.
  mcp/custom_store.py  CustomMcpStore: JSON-file CRUD + tool allowlist + validation (custom tier).
  mcp/introspect.py    direct MCP stdio client (JSON-RPC 2.0 initialize + tools/list) — agent-independent.
  clis/registry.py     CliRegistry.ensure/run + from_layers/clis; CliError.
  clis/custom_store.py CustomCliStore: JSON-file CRUD + validation.
  nodes/  program.py; agent.py (kiro_node: prompt_fn(state,ctx,out_path), output_doc, mcp=[],
          tools→trust_tools, _compute_effective_trust = node.tools ∩ server.allowlist, turn_timeout=420,
          startup_timeout=120; emits agent.message|thought|tool_call|tool_update|result; the result
          carries Phase-11 credits/context_pct/provenance from turn.usage); cli.py;
          validator.py; gate.py (hitl_gate via interrupt(); kinds approval|escalation|pre_mutation|review);
          subgraph.py; reliability.py (attach_reliability = the trio); tool_store.py + mcp/blackboard_server.py
          (Phase 9: per-run ToolOutputStore + save_tool_output/list_tool_outputs — save-by-reference).
  state.py `_telemetry_merge` sums `credits` (None never clobbers an accumulated total; Phase 11).

genesis/genesis/
  db/       database.py (Database: connection factory + PRAGMA WAL/busy_timeout/foreign_keys/row_factory
            + tx()); runner.py (Migration + migrate() + current_version/pending + contiguity guard);
            migrations/ (m0001_baseline adopts runs+run_events; m0002_chat adds chat_sessions+chat_messages;
            m0003_chat_usage adds chat_messages.usage; m0004_copilot adds chat_sessions.mode +
            chat_run_links + chat_permissions; m0005_supervision adds chat_notifications; m0006_copilot_actions adds the copilot audit trail — current_version=6). Schema is owned HERE (spec 01).
  runtime/  settings.py (Settings: state_dir ~/.genesis, artifacts_dir ~/Genesis/runs, db_path,
            library_dir, lockfile_path, secrets_path, environments_path, custom_mcp_path,
            custom_cli_path, retention_keep_last/max_age_days, retention_on_start); checkpoint.py
            (AsyncSqliteSaver); context.py (build_context); engine.py (async run/resume/get_state/stream).
  dist/     gitlab.py, local.py, catalog.py, lockfile.py, install.py, loader.py (check_compat gate,
            meta_of [yaml, no import], graph_of, installed, load_build).
  config/   secrets.py (SecretProvider/PlaintextProvider 0600; **atomic writes: temp+os.replace, and
            set/delete serialize read-modify-write under a per-path lock** — v0.20.1 crash fix), fields.py (mcp_cards/cli_cards/
            secret_fields/missing_secrets; GLOBAL_KEYS={GITLAB_TOKEN}), environments.py, retention.py
            (disk_usage, plan_prune/apply_prune [artifacts], prunable_runs + RetentionService [events +
            blackboard, spec 04]), health.py, service.py (ConfigService facade: merged registries, MCP/CLI
            CRUD, introspect, allowlist, test_server, secrets, environments, health).
  runs/     store.py (RunStore/RunRecord; statuses pending|running|awaiting_input:gate|
            awaiting_input:paused|done|failed|cancelled; TERMINAL set), eventlog.py (EventLog — durable
            run_events; append/list/last_seq/latest/purge/count/aggregate_tool_calls; **aggregate_credits/
            run_credits/credits_provenance via json_extract over agent.result — Phase 11**), steps.py
            (fold_steps → per-node summary incl. credits/context_pct), events.py (Event +
            single canonical EventBus — legacy dual bus removed in spec 04), validation.py, worker.py
            (SUBPROCESS entry; ops run|resume|get_state|update_state|fork; emits JSONL; sets the
            LangGraph `recursion_limit` from `META.execution.recursion_limit`, default 150 — 12-01), supervisor.py,
            manager.py (RunManager: start/pause/resume/cancel/respond/patch_state/fork/list/wait; writes
            canonical events to EventLog + fans out on cbus; `_CANONICAL_CUSTOM` persists agent.result &c
            with node+full payload; pending_gate [durable + checkpoint cold path]; log_events; steps).
  chat/     (Phase 10) manager.py (ChatManager/ChatSession: persistent read-only ACP client per live
            session, in-process — NOT a subprocess; stream_turn persists per-message usage + emits credits),
            store.py (ChatStore/ChatMessageStore on genesis.db: sessions + messages + usage; session_usage_total),
            events.py (map_message_to_events → canonical agent.* shapes), mcp.py (Atlas + introspection wiring
            + read-tool trust set). Read-only enforcement (ADR-031): trust_tools allowlist + permission_mode
            auto_deny + allow_fs_write=False.
  mcp/      introspection_server.py (read-only Genesis-introspection MCP server: list_runs/get_run/steps/
            events/list_failures/list_workflows/get_workflow/integration_health/platform_stats over a
            read-only genesis.db connection — Phase 10-02).
  api/      app.py (create_app FastAPI; version 0.20.1; instantiates ChatManager + registers chat routes).
            ALL routes on an APIRouter at prefix="/api" (ADR-028) + a catch-all SPA fallback. Routes:
            catalog(+available), library install|update|DELETE; workflows/{id}(+/graph); config/health,
            gitlab-token, mcp-cards, cli-cards, mcp-cards/{server}/test, secrets, environments;
            config/mcp-servers CRUD(+tools+allowlist+test), config/clis CRUD; config/retention/{plan,apply};
            artifacts/usage; home (metrics incl. **total_credits + credits_provenance**); runs (POST/GET),
            runs/{id}(+gate), runs/{id}/state (GET/PATCH), pause|resume|cancel|respond|fork,
            runs/{id}/artifacts(+/{name}(?mode)+/download), runs/{id}/events(?after,kinds,node)+/steps,
            runs/{id}/events/stream (canonical SSE); **chat/sessions CRUD + chat/sessions/{id}/messages
            (SSE turn) + /cancel (Phase 10)**. studio.py.
  cli/      main.py (genesis serve|install|list|create-workflow|test-workflow|db upgrade|db status …).
  lint/     contract.py (workflow.yaml↔META parity; YAML_ONLY_KEYS exempts UI-only keys like `graph:`),
            reliability.py (trio enforcement).
  web/      React + TS + Vite (ADR-026/027): Tailwind + Radix/shadcn-style + Zustand + React Router +
            TanStack Query + React Flow + Recharts + react-markdown/remark-gfm + mermaid (lazy) +
            CodeMirror (JSON editor) + lucide + sonner. Structure:
            src/styles/{tokens.css,index.css}; src/lib/{cn.ts, api/** [typed client PREPENDS /api +
            ApiError; resource modules], query/** [keys + client]}; src/stores/**; src/shared/ui/**
            (primitives: Button/Card/Badge/Chip/Dialog+Drawer/Tabs/SegmentedControl/Switch/Input+Field+
            Textarea/HealthDot/MetricCard/TrendChart/format/icons); src/shared/layout/** (AppShell/
            Sidebar/Topbar/SplitPane/Page); src/shared/feedback/** (Empty/Error/Loading); src/app/**
            (providers, router, RootLayout, routes); src/features/{overview,settings,catalog,runs,
            run-detail,documents,chat}/**; src/test/fixtures (golden contract fixtures); src/dev/KitchenSink.
            **static/ = the COMMITTED, built app** served by `genesis serve`.
            Settings (Phase 8): SettingsPage = Tabs shell (/settings/:tab?/:id?); components/manager/**
            (ResourceManager, ResourceFormDialog, SpecForm, ConfirmDialog — the standardized pattern);
            components/mcp/** + cli/** (tabs+detail on that framework); EnvironmentsSection/GitlabSection/
            StorageSection reused; hooks.useMcpResources/useCliResources merge cards ⋈ custom entries.
            Run-detail conversation (spec 06): conversation.ts buildTranscript + groupTurns; inspector/
            TurnView + ThinkingTimeline + AssistantAnswer + conversationParts.
            Chat (Phase 10): features/chat/** — ChatThread REUSES the run-detail Conversation via a
            `hideResultChip` prop; Composer; SessionList; lib/api/chat.ts `readSse` (CRLF SSE framing).
            Credits (Phase 11): shared/ui `formatCredits` + `CreditBadge` + `Coins`; Overview "Credits
            Used" KPI (replaced Tool-Calls); run-detail TelemetryStrip Credits stat + per-node + header
            run-total; chat per-message credit footer (in the ResultChip's old position).

genesis-workflows/
  registry.json (catalog + genesis_core_major=1), mcp-registry.json (REAL internal images:
  appian-atlas [read-only], jarvis [read-write-deploy], appian-data-generator, lcp, jira),
  cli-registry.json, bundles.json, schemas/, steering/01-07, ci/validate_library.py (7-gate publish
  runner), workflows/{_template, hello-appian, erd-generation, code-review, _fixtures/noncompliant}, MIGRATION.md.
```

---

## 5. Non-negotiable constraints (ADRs — do not violate; flag + confirm if a task requires it)

- **ADR-001** — LangGraph owns control flow; agents never orchestrate.
- **ADR-002/004/020** — agent steps = narrow Kiro turns over ACP, **per-node MCP injection**; NO global Kiro `mcp.json`.
- **ADR-005 (+ ADR-029)** — the shared MCP/CLI registry lives in the library (curated tier, changed via MR). ADR-029 adds a **user-writable custom tier** on top; the curated tier stays MR-governed. Effective tool trust = `node.tools ∩ server.allowlist` (a hard cap).
- **ADR-010/018/022** — state is small/serializable/**editable** (pointers + decisions); bulk lives in the `RunWorkspace` blackboard under `$GENESIS_ARTIFACTS_DIR`; never inline bulk in state/chat.
- **ADR-011** — reliability trio (validator + retry + escalation) MANDATORY on every agent node; CI-enforced.
- **ADR-012** — graph execution runs in a disposable **subprocess worker**, not the app; pause=kill, resume=fresh worker from checkpoint; the app never imports workflow Python.
- **ADR-019** — genesis-core semver; `CORE_MAJOR` (=1, distinct from pip version) is the compat-gate key; the loader refuses a library whose declared `genesis_core_major != CORE_MAJOR` (additive-only within a major).
- **ADR-021** — `META.auto_approve=true` default; pause only at 3 sanctioned gate classes (approval|escalation|pre_mutation); `pre_mutation` REQUIRED before any write/deploy/data MCP node.
- **ADR-023** — backend is FastAPI **embedding** LangGraph (NOT a LangGraph Server); Studio is interim debug only.
- **ADR-024** — engine is **async-first** (ainvoke/astream + AsyncSqliteSaver + aiosqlite); Python pinned 3.13.
- **ADR-025** — "fork" = seed a NEW thread from a past checkpoint; the original is untouched.
- **ADR-026** — web UI = React+TS (local single-user); multi-user/hosted would re-open ADR-012/023 (separate track).
- **ADR-027** — the web stack (Tailwind + shadcn/Radix + React Router + TanStack Query + React Flow + react-hook-form/zod + react-markdown/mermaid/shiki + Recharts + Vitest/RTL/MSW) and the Overcut visual language (07-03a). **Reuse existing primitives; use design tokens, not raw palette colors.**
- **ADR-028** — ALL backend endpoints under `/api` (APIRouter) + SPA history fallback; the web client prepends `/api` centrally (never hard-code it in components); the Vite dev proxy is a single `/api` → :8760.
- **ADR-029** — two-tier MCP/CLI registry (curated read-only + custom writable) + tool allowlist + direct-stdio introspection.
- **ADR-030** — persistence stays **SQLite**; move to Postgres/pgvector only on an explicit trigger (multi-user, transcript RAG, or heavy analytics). Repositories keep DB-agnostic signatures so the seam stays cheap.
- **ADR-031** — **Chat is a read-only assistant** (never orchestrates): it observes/answers, never drives or mutates. Enforced (defense in depth): `trust_tools` allowlist of read tools only + SDK `permission_mode="auto_deny"` + `allow_fs_write=False` + a read-only `genesis.db` connection in the introspection server. kiro-cli matches MCP tools by the **namespaced** `@server/tool` name — build allowlists as `@server/<tool>`. Chat runs in-process (no subprocess worker; ADR-012 is about workflow Python).
- **ADR-032** — **credit usage is REAL metered data from Kiro ACP** (`_kiro.dev/metadata.meteringUsage`, verified per-turn not cumulative), NOT estimated — there is no pricing engine. SDK captures it → telemetry + `agent.result` + `run_events`/`chat_messages.usage`. Every figure carries `provenance` (`metered`/`partial`/`unavailable`); the UI shows honest "n/a", never a fabricated number.
- **ADR-033 (ACCEPTED — Phase 13, SHIPPED)** — the **Chat copilot may operate runs** (start / read status / answer gates / cancel) at the **run-management layer only**, but (a) LangGraph still owns each workflow's control flow (ADR-001 intact — the copilot calls the same `RunManager` API a human clicks, it is NOT the workflow engine), (b) **every mutation is human-confirmed** (launch dialog for `start_run`; per-call confirm card for `respond_to_gate`/`cancel_run`, via the untrusted-tool → `session/request_permission` → SDK `permission_mode="ask"` bridge), (c) it can NEVER auto-approve/bypass a workflow's own HITL gate — only relay the human's decision, (d) NO config/secret/registry/workflow-definition/deploy tools, (e) read-only default + global kill-switch + per-session concurrency/rate/allow-deny limits (13-06, enforced app-side on `POST /api/runs` gated on the control token) + a `copilot_actions` audit trail. Refines ADR-031; preserves ADR-001. Delivered 13-01..13-06 (genesis v0.25.0 + sdk v0.5.0).
- **ADR-034 (PROPOSED — Phase 14)** — **Skills are a first-class "standalone activity" concept beside Workflows, chat-invoked + filesystem-provisioned.** A **Skill** = a single standalone activity (draft a document, build a checklist, apply a body of knowledge like GAM) owned by the **Kiro agent** (its `SKILL.md`), no stages/run; a **Workflow** = a staged/orchestrated activity owned by **LangGraph** (ADR-001 preserved — a skill never starts a run). Skills are **filesystem-discovered** (NOT an ACP wire param like MCP): Genesis provisions them into a managed Kiro workspace **`~/.genesis/.kiro/skills/`** (= the chat `cwd`; **spike-proven** over ACP — auto-activation by `description` + explicit `/skill-name`). Two acquisition paths: install from a new `skills/` library in `genesis-workflows` (mirrors the workflow install/lockfile path) OR author in-flight (SKILL.md + scripts/references/assets). Catalog gains **Workflows | Skills** sub-tabs; Chat's `/` palette becomes a unified workflows+skills menu (skills also work in read-only chat). **Safety:** a skill may write documents **only** into a per-session **skill-output sandbox** `~/.genesis/skill-output/<session_id>/` (via a small additive SDK **`fs_write_root`** option — writes elsewhere rejected); executing bundled `scripts/` stays deferred. Refines ADR-031/033 (chat gains bounded sandboxed document output, no other write authority). Not yet accepted — implement per the Phase 14 specs.

**Key implementation contracts:**
- Node fns are `async fn(state, config: RunnableConfig)`. LangGraph injects `config` only when the param is annotated `RunnableConfig`; nodes read ctx via `ctx_from_config(config)`.
- `build(ctx) -> CompiledStateGraph` compiled with `ctx.checkpointer`. `META` is a static dict importable with NO side effects. `workflow.yaml` MUST mirror `META` (parity lint; UI-only keys like `graph:` are exempt via `YAML_ONLY_KEYS`).
- Workflow `graph.py` is loaded standalone (importlib on the file) — keep it self-contained (no sibling-package imports); put pure functions in `graph.py`.
- ACP MCP entries: `env` is a **LIST** of `{name,value}` (NOT a dict). See §7.

---

## 6. Environment, dev loop, release, CI

- **OS** macOS; **Python** 3.13; **node** 20 + npm + vite. Use non-interactive shell flags (`rm -f`, etc.).
- **Dev venv (use for all Python):** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/.venv` — editable installs of kiro-agent-sdk, genesis-core, genesis (+ pytest, pytest-asyncio, ruff, pyyaml, requests, jsonschema, aiosqlite, fastapi, sse-starlette, uvicorn, httpx). Python edits are live for the CLI and freshly-spawned workers — **but restart a running `genesis serve`** to pick up server-process changes (it has already imported `api/app.py` + `manager.py`).
- **Run tests:**
  - genesis: `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` (+ `ruff check genesis`)
  - genesis-core: `cd genesis-core && ../genesis/.venv/bin/python -m pytest -q -p no:warnings` (+ `ruff check genesis_core`)
  - genesis-workflows: `../genesis/.venv/bin/python ci/validate_library.py` and `../genesis/.venv/bin/python -m pytest -q workflows --ignore=workflows/_fixtures`
  - web: `cd genesis/web && npm run lint && npm run typecheck && npm test`
- **Frontend build (the current, post-cutover rule):** the new app IS the served app; `web/static/` is the **committed** production bundle. `npm run build` (= `tsc --noEmit && vite build`) writes `web/static/`. **After ANY `web/src` change, run `npm run build` and COMMIT the updated `web/static/`.** CI's `frontend` job runs lint → typecheck → test → build → a **stale-bundle guard** (`git diff --quiet -- static`) that fails if the committed bundle differs from a fresh build. (If an older spec's DoD says "web/static/ untouched", treat it as "rebuild + commit" — those specs predate the cutover.)
- **NPM registry:** local `~/.npmrc` points at Appian Artifactory with an EXPIRED token (E401 on new installs). Use `--registry=https://registry.npmjs.org/` for local installs (do NOT edit global `~/.npmrc`). CI's node:20 resolves the lockfile's public-npm URLs fine.
- **Run the app:** `.venv/bin/genesis serve` (→ http://127.0.0.1:8760, `/docs`). Install workflows: `genesis install --from ../genesis-workflows` (or `genesis install` for GitLab pull). `genesis list`. `genesis db status|upgrade`.
- **Distribution/versioning:** pyproject deps are git+ssh. When you change a repo: bump `[project].version`, commit + tag `vX.Y.Z` + push, and bump dependent pins (genesis pins genesis-core; genesis-workflows pins both). Release order core → genesis → genesis-workflows so tags exist. **Frontend-only changes still ship a genesis release** because `static/` is committed. Commits: `git -c user.name=Genesis -c user.email=genesis@local commit -m "..."` (do NOT change git config).
- **CI:** each `.gitlab-ci.yml` rewrites ssh→https via the `GITLAB_PUSH_TOKEN` CI/CD var (set on all 3 code repos — should be rotated; it was shared in chat). `glab` is authed for READS (`glab ci list/trace`) but its token lacks `api` scope → cannot `glab ci run`/`variable set`; **trigger pipelines by pushing.** Verify: `glab ci list -R ramaswamy.u/<repo>`.
- **Gitignore lesson:** build-artifact ignores are anchored (`/dist/`, `/build/`, `web/node_modules/`) so they don't swallow tracked source/served dirs (`genesis/web/static/` IS tracked). After adding a source dir, verify `git check-ignore <path>` says NOT ignored and `git ls-files` lists it.
- **project-tracker repo** (github, branch `main`) is SEPARATE from the code repos; after meaningful work, update `tracker.md` §6 + a `progress/` doc and push it (`git pull --rebase` then push).

---

## 7. Hard-won lessons (do not regress these)

- **ACP MCP env MUST be a list of `{name,value}`** (`McpRegistry.acp_servers`). A dict silently drops env in kiro-cli acp → the MCP container runs without secrets and hangs to timeout. This broke erd-generation. When stubbing an external contract, mirror its REAL schema (a permissive stub hid this).
- **`kiro_node` builds the real `KiroAgentOptions`** (cwd, trust_all_tools, trust_tools, agent, model, agent_engine, kiro_cli_path, extra_args, mcp_servers, startup_timeout, turn_timeout, stream_limit_bytes, debug). There is NO `tools` field (map an allowlist to `trust_tools`). turn_timeout=420, startup_timeout=120 for heavy MCP.
- **SSE streaming:** the per-run bus stays open until the run is TERMINAL (so gate pause/resume keeps streaming); the client dedupes replayed history and CLOSES the EventSource on terminal final/error (else it auto-reconnects and re-replays forever — the "repeated activity" bug). The server sends NAMED SSE events (`event: <kind>`); the client registers a handler per kind.
- **Data plane is SQLite, not JSON** (`~/.genesis/genesis.db`, WAL): runs + full conversation + checkpoints. Only bulk artifacts are files. Schema is owned by `genesis/db/` migrations (spec 01) — never hand-write DDL in the repositories; add a migration. Gate/approval controls MUST derive from durable state (`GET /runs/{id}.gate` via `manager.pending_gate`), NEVER from a transient event.
- **Canonical event kinds:** `run.started` / `node.completed` / `agent.message|thought|tool_call|tool_update|result` / `validator.result` / `retry.scheduled` / `gate.awaiting|resolved` / `run.final` / `error`. There is NO `node.started`/`node.failed` — "running" = `run.cursor`; failure is attributed to the cursor on a failed run. The single live `EventBus` + durable `EventLog` are the whole event model (the legacy dual bus was removed in spec 04).
- **Run Detail resilience:** if a workflow declares no `graph:` topology, the UI derives a fallback from `/steps` (or events) so the graph is never blank. Workflows SHOULD still declare `graph:` (the catalog preview needs it; node ids must match LangGraph node names).
- **Conversation (spec 06):** `buildTranscript` folds `agent.*` events → items; `groupTurns` groups them into turns (validator/retry notes attach to the just-closed turn). The Thinking panel auto-expands while live and collapses on the turn's `result`. Markdown answers reuse the 07-09 renderers (no new deps).
- **Worker error reporting:** a generic `worker_exit` must NOT clobber a specific `error` event; empty-message exceptions report their type + a hint. For MCP-server logs, run the container standalone (Genesis hides them in the ACP subprocess).
- **LangGraph specifics:** sync `invoke` can't run async nodes; sync `SqliteSaver` fails under async (use `AsyncSqliteSaver`). `Command(resume=...)` needs a checkpointer-compiled graph. Fork seeds a NEW thread.
- **API namespacing (ADR-028):** browser routes (`/runs`, `/catalog`, `/settings`) are real client paths; ALL backend endpoints live under `/api`; the client prepends `/api` centrally and REJECTS non-JSON (throws `ApiError` → `ErrorState`). Uniform 500s on `/api/*` in the browser usually means the BACKEND ISN'T RUNNING (the Vite proxy 500s on connection-refused) — `curl http://127.0.0.1:8760/api/config/mcp-cards` first.
- **Frontend contract fixtures:** mirror the 07-02 event/GateDescriptor/topology/steps shapes in `web/src/types` + the golden fixtures in `web/src/test/fixtures`; a drift must fail a test (`contract.test.ts` feeds the golden log through the real folds). The "stub hid the contract" lesson applies.
- **Settings data (Phase 8):** MCP/CLI detail needs BOTH the merged card view (`mcp-cards`/`cli-cards`: status + secret fields) AND the custom entry (`mcp-servers`/`clis`: raw spec + allowlist + source) — joined by name in `useMcpResources`/`useCliResources`. Curated tier is read-only; custom is editable/deletable through the standardized `ResourceFormDialog`/`ConfirmDialog`. Use `HealthDot` + tokens, not raw colors.
- **`workflow.yaml`** may carry UI-only keys (e.g. `graph:` topology) — the parity lint exempts them via `YAML_ONLY_KEYS`.
- **jest-axe (v9)** ships no types: ambient `declare module` + the vitest matcher augmentation live in `web/src/types/jest-axe.d.ts` + `web/src/vitest-axe.d.ts` (keep them pure ambient / module-aug); the matcher is extended globally in `web/src/test-setup.ts`.
- **mermaid + Recharts are heavy;** mermaid is dynamic-imported (lazy chunk). Keep new heavy libs lazy.
- **Credits are REAL, not estimated (Phase 11 / ADR-032).** Kiro reports per-turn credits via the
  `_kiro.dev/metadata` notification: the final one of a turn carries `meteringUsage:[{value,unit:"credit"}]`
  + `contextUsagePercentage` + `turnDurationMs`. Verified **per-turn, not cumulative** (spike: 0.184 then
  0.113 in one session). The SDK captures it into `ResultMessage.usage`/`TurnResult.usage`; agent.py puts
  it on the `agent.result` event; `manager._CANONICAL_CUSTOM` persists that payload verbatim into
  `run_events`, so `aggregate_credits` (json_extract) + `fold_steps` + SSE all get it for free. The
  `_telemetry_merge` reducer must NOT let a None (unavailable) credits value clobber an accumulated sum.
- **Chat read-only (Phase 10 / ADR-031):** trust is fail-CLOSED — never trust-all; build the allowlist
  with the namespaced `@server/tool` form (kiro-cli matches that way). A curated server with NO registry
  `tool_allowlist` (e.g. `jarvis`, which is read-write-deploy) means the ONLY cap is the node's `tools=`
  list — a read-only workflow MUST set an explicit read-only `tools=` allowlist on every agent node
  (effective trust = node.tools ∩ server.allowlist).
- **SSE framing is CRLF:** sse-starlette frames events with `\r\n\r\n`. A client reader that splits on
  `\n\n` never parses a frame (the "stuck on Thinking…" chat bug, fixed v0.19.1). `readSse` splits on
  `/\r?\n\r?\n/`. Don't let a LF-only test fixture hide it.
- **Secret writes must be atomic + serialized (v0.20.1 crash fix).** FastAPI runs sync route handlers in
  a threadpool, so two secret-set requests (e.g. two fields of one MCP server) run concurrently. A plain
  `write_text` isn't atomic → concurrent writers corrupt `secrets.json` (a valid object + leftover tail =
  "Extra data"), which 500s `/api/config/mcp-cards` and crashes the UI. Fix: temp-file + `os.replace`
  (atomic) + a per-path lock around read-modify-write. The other JSON stores (mcp-custom/cli-custom/
  environments) share the old non-atomic pattern — harden them the same way if touched.
- **Looping workflows (Phase 12 note):** LangGraph's default `recursion_limit` is **25 supersteps** and
  the worker doesn't raise it, so a per-item loop dies after ~6 items — a looping workflow needs the
  worker to set a higher limit (from META). Also, `attach_reliability` keys retries by agent NODE NAME, so
  a re-entered loop node must RESET `retries[node]=0` each iteration or later items get no retry budget.
- **Phase 9 save-by-reference:** a huge MCP result (e.g. a 3000-line process model) must not re-enter the
  context window — the agent calls `save_tool_output(ref, document=...)` to persist it to the blackboard
  by reference (the per-run ToolOutputStore records every tool result). Prompts instruct "never paste
  tool output into your reply — save it BY REFERENCE".
- **Workflow graph.py with custom reducer state keys must NOT use `from __future__ import annotations`.**
  The loader imports graph.py standalone (`spec_from_file_location` → not registered in `sys.modules`),
  so LangGraph's `get_type_hints()` can't re-resolve stringized annotations — a `class MyState(PlatformState):
  reviewed: Annotated[list, add]` dies with `NameError: Annotated`. Eager (non-`__future__`) evaluation
  stores real `Annotated` objects and works. (erd-generation's state has no reducer keys, so it never hit
  this; the code-review workflow did.) Also: quote YAML flow-scalars containing `?`/`:` (e.g. `label: "Stale?"`).
- **Parse saved MCP tool outputs DEFENSIVELY — real shapes vary per tool (Phase 12 live-run lesson).**
  `save_tool_output` persists a tool's result verbatim, and jarvis tools are inconsistent: some wrap
  JSON in a human-readable preamble (`get_package_contents_from_url` → `Package Contents from URL:\n\n[…]`;
  `get_application_info` → `Application Info:\n{…}`), others return clean JSON (`get_jira_issue`,
  `get_review_checklist`). Shapes also differ from the obvious guess: object `type` is a QName
  (`{http://…/types/2009}Interface`) with a separate `typeId`; `get_review_checklist` is **3-level
  nested** (`parentCategory→categories→checkListItems`) with `applicableObjectTypes` as display names
  ("Expression Rule", not "ExpressionRule"); `jarvis_config` nests `appUuid`/`kbFolderId` under
  `applications[].appConfig` with `globalSettings` a list. The code-review workflow added `_coerce_json`
  (strip preamble), `flatten_checklist`, and normalized type matching. **Systemic gotcha:** a
  `validator_node`'s `check_fn(data,…)` receives `data` from a plain `json.loads` that falls back to
  raw text on failure — so any JSON-consuming validator must coerce `data` itself (don't assume it's a
  dict). Stubbed tests won't catch these; validate against real captured artifacts under
  `~/Genesis/runs/<wf>/<run>/`.
- **Kiro Skills load over ACP from the filesystem, NOT the wire (Phase 14 spike, 2026-07-16).** kiro-cli
  auto-discovers **skills** from `<cwd>/.kiro/skills/` (workspace) + `~/.kiro/skills/` (global) — there is **no
  `skills` param on `session/new`** the way there is `mcpServers`. A real-ACP spike proved a `SKILL.md` in the chat
  session's `cwd` (`~/.genesis`) both **auto-activates** (by `description` match) and is **explicitly invocable**
  via `/skill-name` in the prompt text. So to give the agent a skill you **write files** into a Kiro workspace, you
  don't inject it over the wire. `--help` doesn't list skills (they're a convention, not a flag) — the binary's
  changelog strings + the spike are the evidence. Do NOT set `KIRO_HOME` to relocate skills (it also relocates the
  user's agents/sessions/settings/auth). See `spike/2026-07-16-kiro-skills-in-acp-and-chat.md` + ADR-034.

---

## 8. How to work on ANY task (the loop)

1. **Understand + restate.** State your understanding of the task, which layer(s)/repo(s)/files it touches, and any ADR that applies. Read the relevant spec's "current state" citations and the cited code FIRST — don't guess. For a broad investigation, delegate to a sub-agent to preserve context.
2. **Verify against real code.** For a bug, write a failing test/repro first. For a feature, confirm the backend/API/types already support it (or plan the additions).
3. **Change in the smallest correct scope.** Match existing style/patterns and reuse existing primitives. Don't refactor unrelated code.
4. **Test.** pytest for backend/core; Vitest for web. For bugs, add a regression test that would have caught it — and if a stub hid the bug, fix the stub to mirror reality. Add jest-axe for new interactive UI.
5. **Run all affected gates until green:** backend `pytest` + `ruff`; web `lint` + `tsc` + `vitest`. For web changes, also `npm run build` and **commit the updated `web/static/`** (the stale-bundle guard requires it).
6. **Release (if a code repo changed):** bump version(s) + tag + push + update dependent pins; verify CI green via `glab`. Frontend-only genesis changes still ship a genesis release.
7. **Document:** update `tracker.md` §6 + a `progress/` doc (and the spec/README status tables); push
   project-tracker. **Also refresh THIS doc (`AGENT_ONBOARDING.md`)** when tags/architecture/ADRs/
   hard-won lessons change — §2 (state + tag table + test counts), §4 (map), §5 (ADRs), §7 (lessons),
   §9 (roadmap), and the "Last refreshed" header. Keeping the bible current is part of Definition of Done.
8. **Report with cited evidence** (test output, run ids, CI pipeline ids, file diffs). Be honest about what you verified vs. couldn't — live Kiro/MCP/browser steps can't be driven headlessly; say so and give the manual check.

**When the task is planning/analysis** (not "make this change"): respond with the plan/analysis and, if asked, write it as a spec + update the phase docs — but do NOT start implementing until asked.

---

## 9. Roadmap & backlog (what's next — context, not an assignment)

- **Shipped:** Phases 1–6, the web revamp (7.1), the code-review fix program (01–06), Phase 8 (settings
  revamp), **Phase 9 (agent artifact I/O), Phase 10 (chat assistant), Phase 11 (credit tracking),
  Phase 12 (Appian code-review workflow), Phase 13 (Chat Copilot & Run Orchestrator — 13-01..13-06)**.
  See `tracker.md` §3/§6 and `reference/roadmap-and-sequencing.md`.
- **Phase 13: Chat Copilot & Run Orchestrator — COMPLETE (13-01..13-06 shipped; ADR-033 Accepted).**
  Read `specs/phase-13-copilot-orchestrator.md` (umbrella) + `phase-13-copilot-orchestrator/13-01..13-06`
  + **ADR-033** + `progress/phase-13-copilot-orchestrator.md` if you touch the copilot. **Delivered:** type `/`
  in chat → pick a workflow → schema-driven inputs → the Kiro agent **starts the run** and **supervises**
  it (senses HITL gates, presents options, relays the user's decision, reports outcomes) without staying
  alive. **Architecture (decided, code-grounded):**
  - **Genesis Control MCP server** (`genesis/mcp/control_server.py`) — a write-capable sibling of the
    read-only `introspection_server`, but a **thin MCP→HTTP facade over `/api`** (`POST /api/runs`, `GET
    /api/runs/{id}`(+`.gate`), `/respond`, `/cancel`, `/api/catalog`, `GET /api/workflows/{id}`) so
    `RunManager` stays the single source of truth. Tools: `list_launchable_workflows`,
    `get_workflow_inputs_schema`, `check_launch_readiness`, `start_run`, `get_run_status`, `get_run_steps`,
    `get_pending_gate`, `respond_to_gate`, `cancel_run`, `list_session_runs`. NO config/secret/registry/deploy tools.
  - **Human-confirmed mutations via ACP's native permission mechanism** — the SDK permission model is binary
    (`auto_approve`/`auto_deny`) and *trusted tools skip the prompt*. So keep **read tools trusted (silent)**
    and leave **mutating tools UNTRUSTED** → kiro-cli fires `session/request_permission` per call → a new SDK
    **`permission_mode="ask"`** + async `on_permission` callback (13-01) routes it to a **chat confirm card**
    (fail-closed on timeout). **Load-bearing spike (13-01, do FIRST):** prove kiro-cli actually fires
    `request_permission` for untrusted MCP tools; if not, use the ADR-033 fallback (UI-mediated pending-action confirm).
  - **Event-driven supervision** — a `ChatRunSupervisor` (app process) subscribes to `RunManager`'s EventBus
    for **session-linked runs** (`m0004 chat_run_links`); on `gate.awaiting`/`run.final` it emits a notification
    + a proactive **nudge turn** so the copilot surfaces the gate + options; **level-triggered reconcile** from
    durable state (`pending_gate` + `EventLog`) on restart (don't rely on the live subscription). Nudges queue
    behind the session lock + de-dup by `(run_id, gate_node, raised_at)`.
  - **Slash UX** — Composer `/` palette from the catalog; **reuse the 07-05 launch form** for schema inputs;
    on submit the UI hands the agent the `start_run` action (agent is the actor) → confirm card → run linked +
    supervised. In-chat cards: permission-confirm, gate, terminal; a supervised-runs strip.
  - **ADR-033 reconciliation:** ADR-001 preserved (LangGraph still owns each workflow's control flow; copilot
    = operator at the run-management layer = what a human does in the Runs UI); ADR-031 refined (read-write at
    that layer, every mutation human-confirmed, no config/secret/deploy, read-only default + kill-switch).
  - **Sub-phase order + release chain:** **13-01 SDK permission bridge — SHIPPED (kiro-agent-sdk v0.5.0;
    spike confirmed; genesis/core pin bump deferred to 13-03)** → **13-02 control server + ADR-033 —
    BUILT (genesis/mcp/control_server.py on master `b6edf7c`; requests not httpx; token gating deferred to
    13-06)** → **13-03 copilot chat mode + run↔session link (`m0004`) + coordinated sdk-v0.5.0 pin bump —
    SHIPPED (genesis v0.21.0 + genesis-core v0.8.1; the 13-02 control server ships here, now live)** → **13-04
    run-supervision bridge — SHIPPED (genesis v0.22.0: ChatRunSupervisor observes gate/terminal for linked
    runs → durable notifications [m0005] + per-session SSE + deterministic system nudge; level-triggered
    reconcile + SLA)** → **13-05 slash launch + in-chat HITL/confirm UI — SHIPPED (genesis v0.23.0: Composer
    `/` palette → LaunchDialog → start_run intent turn → PermissionCard/GateCard/TerminalCard + SupervisedRunsStrip;
    frontend-only release)** → **13-06 safety/audit/advanced-gate + release — SHIPPED (genesis v0.24.0:
    persisted kill-switch + per-session concurrency/rate/allow-deny enforced app-side on POST /api/runs
    gated on the control token; `copilot_actions` audit trail [m0006]; pre_mutation never auto-approved;
    Settings→Copilot section + activity; ADR-033 → Accepted)**. **PHASE 13 COMPLETE.** `genesis-core`
    unchanged. After any `web/src` change: `npm run build` + commit `web/static`. Remaining: manual
    live-acceptance vs. real kiro-cli (headless-undrivable).
- **NEXT PLANNED WORK — Phase 14: Skills in Chat (SPEC DRAFTED, spike-first done, not started).** Read
  `specs/phase-14-skills-in-chat.md` (umbrella) + `phase-14-skills-in-chat/14-01..14-05` + **ADR-034** + the proving
  spike `spike/2026-07-16-kiro-skills-in-acp-and-chat.md` before touching code. **Goal:** add **Skills** — Kiro's
  portable `SKILL.md` instruction packages — as a **second first-class capability beside Workflows**, usable from
  **Chat** (priority 1). **Concept boundary:** a *Skill* = standalone activity (draft a doc, build a checklist, apply
  a body of knowledge like GAM), no stages/run, owned by the Kiro agent; a *Workflow* = staged/orchestrated, owned by
  LangGraph. **Architecture (spike-proven, code-grounded):** skills are **filesystem-discovered** (`.kiro/skills/`),
  NOT an ACP wire param like MCP — Genesis writes them into a managed workspace **`~/.genesis/.kiro/skills/`** (= the
  chat `cwd`); kiro-cli auto-discovers them (auto-activation by `description` + explicit `/skill-name`, both proven).
  Two acquisition paths: **install from a `genesis-workflows` `skills/` library** (parallel of the workflow install +
  a separate `skills-registry.json`) or **author in-flight** (SKILL.md + scripts/references/assets uploads). **Catalog**
  → Workflows | Skills sub-tabs; **Chat** `/` palette → unified workflows+skills menu (skills also in read-only chat).
  **Safety:** skills may write documents **only** into a per-session **skill-output sandbox**
  `~/.genesis/skill-output/<session_id>/` via a small additive SDK **`fs_write_root`** option (writes elsewhere
  rejected); executing bundled scripts stays deferred. **Sub-phases:** 14-01 foundation + chat discovery → 14-02
  skills library + install-from-repo → 14-03 Catalog Skills tab + in-flight authoring → 14-04 chat skills invocation →
  14-05 safety (skill-output sandbox) / lifecycle / release. **Release chain:** kiro-agent-sdk (`fs_write_root`) →
  genesis-workflows (skills library) → genesis; genesis-core unchanged. **Spec-only; spike-first done; awaiting
  approval to implement.**
- **Backlog (`specs/backlog/`):** the **skill → workflow migration program** (the 45 solutions-copilot
  skills, waves A–D) — deferred; the methodology is intact and resumes when scheduled.
- **Open follow-ups (may be assigned):** the Phase-12 **live run** against a real GAMS ticket/package
  (needs a `genesis serve` restart on ≥ v0.20.2 + the connected jarvis/jira secrets) to confirm per-object
  findings, checklist coverage, SQL checks, the diff baseline rule, and metered credits; restart the
  running `genesis serve` to load v0.20.x; harden the other JSON stores' writes to be atomic (like
  secrets); **rotate the shared `GITLAB_PUSH_TOKEN`** + refresh the expired Artifactory npm token; the
  `lcp` MCP image placeholder (`<lcp-image>`) in `mcp-registry.json`.

**Do not start backlog or a new phase unless explicitly asked.**

---

## 10. Working agreements (how the human wants you to operate)

- **Honest pushback** — correct the human when they're wrong; flag any ADR deviation and confirm before proceeding.
- **Ask before destructive/irreversible actions** (force push, history rewrite, deleting data, anything "prod").
- **Don't push to shared repos beyond the normal Genesis release flow;** never commit secrets; reference secrets by key name only.
- **If stuck twice on the same error,** stop and diagnose the root cause; try a fundamentally different approach.
- **Keep changes scoped** to the task; don't refactor unrelated code.
- **Prefer dedicated tools** (file read/edit/search) over shell equivalents; make independent tool calls in parallel.
- **This document assigns no task** — after restating the architecture + current state + non-negotiables, do the work the human gives you.
