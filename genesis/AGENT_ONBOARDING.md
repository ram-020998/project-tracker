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
> §5 (ADRs), §7 (lessons), and §9 (roadmap). **Last refreshed: 2026-07-13 — genesis v0.16.0**
> (code-review fix program 01–06 done; Phase 8 Settings Revamp shipped).

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
4. `reference/decision-log.md` — **ADR-001…030** (the "why"). Every non-negotiable lives here.
5. `reference/coding-standards.md` — enforcement-anchored standards. §1 is the hard floor (lints/
   typecheck/CI gates that fail the build); §2–§6 are Python/frontend/testing conventions + the
   Definition of Done. When it conflicts with an ADR, the ADR wins; if a task needs a deviation, flag it.
6. `reference/` (the rest): repo-structure, node-taxonomy-reference, state-and-data-model,
   mcp-and-cli-registry, workflow-authoring-standard, reliability-standard, hitl-design,
   security-and-secrets, testing-strategy, langgraph-capability-map, solutions-copilot-relationship,
   glossary, roadmap-and-sequencing, spike-findings.
7. `specs/` — the plan for each phase. Phases 1–6, the web-revamp (`phase-07-0N-*`), the
   `phase-07-code-review-fixes/` program (01–06), and `phase-08-settings-revamp.md` are all **shipped**.
   `specs/backlog/` holds deferred work (the skill-migration program).
8. `progress/` — the as-built record, one file per phase/item (`phase-01..08-*`). Read the one(s)
   relevant to the area you're touching; they cite commits, tags, CI pipelines, and decisions.

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

## 2. Current state (as of genesis v0.16.0)

Four repos at `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`, all pushed to
`git@gitlab.appian-stratus.com:ramaswamy.u/<repo>.git`:

| Repo | Tag | Branch | Role |
|---|---|---|---|
| `kiro-agent-sdk` | **v0.1.0** | main | ACP adapter; `collect` + `collect_streaming` for live conversation |
| `genesis-core` | **v0.5.0** | master | nodes/state/registries/validators; `kiro_node` streams `agent.*`; two-tier MCP/CLI registry + introspection (ADR-029); `CORE_MAJOR=1` |
| `genesis` | **v0.16.0** | master | runtime, dist, config, runs, **db (migrations)**, api (`/api` + SPA fallback), cli, web (the shipped SPA) |
| `genesis-workflows` | **v0.3.1** | master | registries, steering, `hello-appian` + `erd-generation` (with `graph:` topology), noncompliant fixture |

**Dependency chain** (git-pinned by tag; CI rewrites ssh→https):
`genesis (v0.16.0) → genesis-core@v0.5.0 → kiro-agent-sdk@v0.1.0`;
`genesis-workflows → genesis-core@v0.5.0 (runtime) + genesis (dev pin)`.

**Tests, all green at last release:** genesis **83** pytest · genesis-core **45** · genesis-workflows
**~9** · web **67** Vitest (incl. contract-fixture drift tests + jest-axe). ruff clean; eslint clean
(0 errors); `tsc` strict clean. CI green on all repos (genesis has a python `genesis` job + a
`frontend` job with a stale-bundle guard).

**Milestones (see `roadmap-and-sequencing.md`):**
- **Phases 1–6 — DONE (M1–M6):** engine + node framework + state/checkpointer/blackboard + MCP
  registry + reliability trio; workflow contract + library + scaffolder + CI enforcement; distribution
  (GitLab pull/install/lockfile/loader); config + secrets + env registry + health; run orchestration +
  all 3 HITL modes + streaming; the ERD reference workflow.
- **Phase 7 WEB REVAMP (M7.1) — DONE + shipped:** the React+TS workbench (specs 07-01…07-10). The
  07-10 cutover is complete; the interim UI was deleted; `genesis serve` serves only the new SPA.
- **Code-Review Fix Program (M7.2) — DONE:** `specs/phase-07-code-review-fixes/` 01–06 —
  01 persistence & migrations (`genesis/db/`), 02 Overview dashboard (live), 03 Integrations Studio
  (two-tier registry + ADR-029), 04 event-log retention + bus consolidation, 05 persistence-scale
  decision (ADR-030: stay on SQLite), 06 conversation rich-chat.
- **Phase 8 — Settings & Integrations Revamp — SHIPPED (v0.16.0):** tabbed Settings workspace + one
  standardized master-detail + add/edit pattern for all integration types.
- **Backlog:** `specs/backlog/skill-migration-program.md` (the 45-skill migration; deferred). A few
  more enterprise-polish phases are anticipated before it resumes. **Do not start backlog/Phase-N work
  unless asked.**

**What works today (verified):**
- `genesis serve` → FastAPI backend + the SPA at `http://127.0.0.1:8760`. API under **`/api`**
  (e.g. `/api/config/mcp-cards`, `/api/runs`, `/api/home`), Swagger at `/docs`; a catch-all serves
  `index.html` for non-`/api`,`/assets` paths (SPA history fallback, ADR-028).
- **Screens (all live):** Overview dashboard (metrics/trend/active-runs/integration health, wired to
  `/api/home`); Runs list; Run Detail (React Flow live graph + node inspector + turn-grouped Kiro
  conversation with markdown + all-3-mode HITL + documents drawer/preview); Catalog (browse/detail/
  launch); **Settings — a tabbed workspace: MCP · CLI · GitLab · Environments · General** (Storage +
  retention), with a standardized master-detail + add/edit/delete for custom MCP servers and CLIs
  (curated tier read-only), secrets, tool introspection + allowlist, and a readiness/handshake test.
- **Data plane:** durable SQLite (`~/.genesis/genesis.db`, WAL) via the `genesis/db/` migration layer;
  runs + full agent conversation + checkpoints persist across restart; gate/approval derives from
  durable state; canonical event log + single live `EventBus` (legacy dual bus removed in spec 04);
  event-log/blackboard **retention** (plan + reclaim) available.
- **Integrations Studio (ADR-029):** curated (library, MR-governed, read-only) + custom (user-writable,
  `~/.genesis/mcp-custom.json` / `cli-custom.json`) tiers; per-node injection unchanged.
- `hello-appian` runs GREEN end-to-end; `erd-generation` runs into the live Atlas fetch. All three HITL
  modes, streaming, worker isolation, checkpoint resume — implemented + tested.
- **Dev:** `npm run dev` in `genesis/web` → `http://localhost:5173/` (Vite proxies `/api` → :8760).
  Dev needs BOTH `npm run dev` and `genesis serve`. Design-system gallery at `/dev`.

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
          startup_timeout=120; emits agent.message|thought|tool_call|tool_update|result); cli.py;
          validator.py; gate.py (hitl_gate via interrupt(); kinds approval|escalation|pre_mutation|review);
          subgraph.py; reliability.py (attach_reliability = the trio).

genesis/genesis/
  db/       database.py (Database: connection factory + PRAGMA WAL/busy_timeout/foreign_keys/row_factory
            + tx()); runner.py (Migration + migrate() + current_version/pending + contiguity guard);
            migrations/ (m0001_baseline adopts runs + run_events). Schema is owned HERE (spec 01).
  runtime/  settings.py (Settings: state_dir ~/.genesis, artifacts_dir ~/Genesis/runs, db_path,
            library_dir, lockfile_path, secrets_path, environments_path, custom_mcp_path,
            custom_cli_path, retention_keep_last/max_age_days, retention_on_start); checkpoint.py
            (AsyncSqliteSaver); context.py (build_context); engine.py (async run/resume/get_state/stream).
  dist/     gitlab.py, local.py, catalog.py, lockfile.py, install.py, loader.py (check_compat gate,
            meta_of [yaml, no import], graph_of, installed, load_build).
  config/   secrets.py (SecretProvider/PlaintextProvider 0600), fields.py (mcp_cards/cli_cards/
            secret_fields/missing_secrets; GLOBAL_KEYS={GITLAB_TOKEN}), environments.py, retention.py
            (disk_usage, plan_prune/apply_prune [artifacts], prunable_runs + RetentionService [events +
            blackboard, spec 04]), health.py, service.py (ConfigService facade: merged registries, MCP/CLI
            CRUD, introspect, allowlist, test_server, secrets, environments, health).
  runs/     store.py (RunStore/RunRecord; statuses pending|running|awaiting_input:gate|
            awaiting_input:paused|done|failed|cancelled; TERMINAL set), eventlog.py (EventLog — durable
            run_events; append/list/last_seq/latest/purge/count/aggregate_tool_calls), events.py (Event +
            single canonical EventBus — legacy dual bus removed in spec 04), validation.py, worker.py
            (SUBPROCESS entry; ops run|resume|get_state|update_state|fork; emits JSONL), supervisor.py,
            manager.py (RunManager: start/pause/resume/cancel/respond/patch_state/fork/list/wait; writes
            canonical events to EventLog + fans out on cbus; pending_gate [durable + checkpoint cold path];
            log_events; steps; opt-in retention purge at init).
  api/      app.py (create_app FastAPI; version 0.16.0). ALL routes on an APIRouter at prefix="/api"
            (ADR-028) + a catch-all SPA fallback. Routes: catalog(+available), library install|update|
            DELETE; workflows/{id}(+/graph); config/health, gitlab-token, mcp-cards, cli-cards,
            mcp-cards/{server}/test, secrets, environments; config/mcp-servers CRUD(+tools+allowlist+test),
            config/clis CRUD; config/retention/{plan,apply}; artifacts/usage; home; runs (POST/GET),
            runs/{id}(+gate), runs/{id}/state (GET/PATCH), pause|resume|cancel|respond|fork,
            runs/{id}/artifacts(+/{name}(?mode)+/download), runs/{id}/events(?after,kinds,node)+/steps,
            runs/{id}/events/stream (canonical SSE; the legacy /stream was removed in spec 04). studio.py.
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
            run-detail,documents}/**; src/test/fixtures (golden contract fixtures); src/dev/KitchenSink.
            **static/ = the COMMITTED, built app** served by `genesis serve`.
            Settings (Phase 8): SettingsPage = Tabs shell (/settings/:tab?/:id?); components/manager/**
            (ResourceManager, ResourceFormDialog, SpecForm, ConfirmDialog — the standardized pattern);
            components/mcp/** + cli/** (tabs+detail on that framework); EnvironmentsSection/GitlabSection/
            StorageSection reused; hooks.useMcpResources/useCliResources merge cards ⋈ custom entries.
            Run-detail conversation (spec 06): conversation.ts buildTranscript + groupTurns; inspector/
            TurnView + ThinkingTimeline + AssistantAnswer + conversationParts.

genesis-workflows/
  registry.json (catalog + genesis_core_major=1), mcp-registry.json (REAL internal images),
  cli-registry.json, bundles.json, schemas/, steering/01-07, ci/validate_library.py (7-gate publish
  runner), workflows/{_template, hello-appian, erd-generation, _fixtures/noncompliant}, MIGRATION.md.
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

---

## 8. How to work on ANY task (the loop)

1. **Understand + restate.** State your understanding of the task, which layer(s)/repo(s)/files it touches, and any ADR that applies. Read the relevant spec's "current state" citations and the cited code FIRST — don't guess. For a broad investigation, delegate to a sub-agent to preserve context.
2. **Verify against real code.** For a bug, write a failing test/repro first. For a feature, confirm the backend/API/types already support it (or plan the additions).
3. **Change in the smallest correct scope.** Match existing style/patterns and reuse existing primitives. Don't refactor unrelated code.
4. **Test.** pytest for backend/core; Vitest for web. For bugs, add a regression test that would have caught it — and if a stub hid the bug, fix the stub to mirror reality. Add jest-axe for new interactive UI.
5. **Run all affected gates until green:** backend `pytest` + `ruff`; web `lint` + `tsc` + `vitest`. For web changes, also `npm run build` and **commit the updated `web/static/`** (the stale-bundle guard requires it).
6. **Release (if a code repo changed):** bump version(s) + tag + push + update dependent pins; verify CI green via `glab`. Frontend-only genesis changes still ship a genesis release.
7. **Document:** update `tracker.md` §6 + a `progress/` doc (and the spec/README status tables); push project-tracker.
8. **Report with cited evidence** (test output, run ids, CI pipeline ids, file diffs). Be honest about what you verified vs. couldn't — live Kiro/MCP/browser steps can't be driven headlessly; say so and give the manual check.

**When the task is planning/analysis** (not "make this change"): respond with the plan/analysis and, if asked, write it as a spec + update the phase docs — but do NOT start implementing until asked.

---

## 9. Roadmap & backlog (what's next — context, not an assignment)

- **Shipped:** Phases 1–6, the web revamp (7.1), the code-review fix program (01–06), Phase 8 (settings revamp). See `tracker.md` §3/§6 and `reference/roadmap-and-sequencing.md`.
- **Anticipated:** a few more **enterprise-polish** phases (TBD) before coverage work resumes.
- **Backlog (`specs/backlog/`):** the **skill → workflow migration program** (the 45 solutions-copilot skills, waves A–D) — deferred; the methodology is intact and resumes when scheduled.
- **Open follow-ups (may be assigned):** full ERD dry-run parity check (~37 tables / 174 rels) once the two agent turns complete; **rotate the shared `GITLAB_PUSH_TOKEN`** + refresh the expired Artifactory npm token; the `lcp` MCP image placeholder (`<lcp-image>`) in `mcp-registry.json`.

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
