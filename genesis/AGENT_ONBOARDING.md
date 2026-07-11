# Genesis — Agent Onboarding Prompt

> Paste the fenced block below as the **first message** in any new agent session that will
> work on Genesis. It makes the agent absorb the full architecture, the CURRENT state, and the
> operational rules before touching code. The final section already names the active task
> (the code-review fix program, P0 first) — swap it only if you want a different item.
>
> Keep this file updated when architecture, tags, or hard-won lessons change (append to §2 tags,
> §6 lessons, §8 backlog as the project evolves). **Last refreshed: 2026-07-11** — after the
> WEB REVAMP shipped (genesis **v0.11.0**, cutover done) and the post-checkpoint code review.

---

````
You are joining "Genesis" — an agentic SDLC platform for the Appian Solutions department.
Phases 1–7 are COMPLETE, and the WEB REVAMP (milestone M7.1, specs 07-01…07-10) is ALSO COMPLETE
and shipped (genesis v0.11.0 — the new React+TS workbench is the served app; the interim UI was
deleted at the 07-10 cutover). The app runs real workflows end-to-end with a live graph, durable
HITL, and a Kiro-conversation view. We are now executing the **CODE-REVIEW FIX PROGRAM** — a
spec-first package that hardens the foundation and adds MCP/CLI modularity (see §8). Your job this
session is the specific item in §9 AFTER you've absorbed this context. First read everything below
and the referenced docs/code, then briefly restate the architecture + current state and confirm the
non-negotiables before changing anything. Do NOT start coding until you've read the docs and can
restate the design.

════════════════════════════════════════════════════════════════════════
0. WHAT GENESIS IS (one paragraph)
════════════════════════════════════════════════════════════════════════
Genesis is a LOCAL, single-user web application that lets a Solutions engineer discover, install,
run, and supervise WORKFLOWS. A workflow is a LangGraph graph whose nodes are deterministic PROGRAM
steps or narrow AGENT steps that drive Kiro via `kiro-agent-sdk` over ACP, injecting only the MCP
server(s) that step needs. LangGraph owns control flow + durable state; a per-run artifacts folder
(blackboard) holds bulk data; workflows are pulled from the shared `genesis-workflows` GitLab repo
via selective install + lockfile. Every agent step is wrapped by a program validator +
retry/escalation (hard requirement). It replaces the retired solutions-copilot (which failed by
using an LLM as orchestrator). Backend = FastAPI embedding LangGraph as a library + disposable
subprocess workers; frontend = React+TS SPA served by the same backend. Runs on localhost with the
user's own creds. NOTE: the destination is "enterprise-grade polish" but STILL local single-user —
multi-user/hosted is explicitly a separate future track (ADR-026); do NOT build auth/multi-tenancy
unless asked.

════════════════════════════════════════════════════════════════════════
1. READ THESE FIRST (in order) — do not skip
════════════════════════════════════════════════════════════════════════
A) Design + as-built docs — /Users/ramaswamy.u/repo/project-tracker/genesis/
   1. README.md
   2. tracker.md — locked decisions Q1–Q14, phase index (§3a), and §6 STATUS LOG. READ §6 fully
      (top-down) — it is the running history incl. the whole web revamp AND the post-revamp code
      review; the most recent entries are the source of truth for "what is done".
   3. specs/00-architecture-overview.md — layers, domain model, node taxonomy, state/blackboard rule.
   4. reference/decision-log.md — ADR-001..028 (the "why"). Key: 010 (small state + blackboard),
      011 (reliability trio), 012 (subprocess worker), 019 (core semver gate), 023/024 (FastAPI +
      async engine), 026 (React+TS), 027 (web-revamp stack + Overcut study), 028 (/api namespacing).
   4b. **reference/coding-standards.md — the enforcement-anchored coding standards (READ + FOLLOW).**
       §1 is the hard floor (lints/typecheck/CI gates that fail your build); §2–§6 are the Python/
       frontend/testing/cross-cutting conventions + the Definition of Done. Do not deviate; if a task
       needs to, flag it. When it conflicts with an ADR, the ADR wins.
   5. reference/ (all): repo-structure, node-taxonomy-reference, state-and-data-model,
      mcp-and-cli-registry, workflow-authoring-standard, reliability-standard, hitl-design,
      security-and-secrets, testing-strategy, langgraph-capability-map,
      solutions-copilot-relationship, glossary, roadmap-and-sequencing, spike-findings.
   6. **THE ACTIVE PROGRAM — specs/phase-07-code-review-fixes/ (read the whole package):**
      - README.md — the program index, dependency graph, sequencing, status.
      - 00-code-review.md — the definitive, code-grounded review (architecture verdict, the data-
        plane truth [it's SQLite, not JSON], the MCP/CLI gap, the unwired Overview, debt register).
      - 01-p0-persistence-and-migrations.md — P0 (start here).
      - 02-p0-overview-dashboard.md — P0.
      - 03-p1-integrations-studio.md — P1 (MCP/CLI modularity; proposes ADR-029).
      - 06-conversation-rich-chat.md — P1 (Run-Detail Conversation UX upgrade).
      - 04-p2-eventlog-retention-and-bus-consolidation.md · 05-p2-persistence-scale-decision.md — P2.
   7. The WEB REVAMP specs — specs/phase-07-0N-* (ALL DONE; read for as-built context of the screen
      you touch): 07-01 program/architecture, 07-02 backend data plane, 07-03 + 07-03a design system,
      07-04 settings, 07-05 catalog, 07-06 runs, 07-07 run-detail graph, 07-08 node inspection +
      conversation + HITL, 07-09 documents, 07-10 testing/CI/rollout.
   8. progress/ — as-built records: phase-01..07-implementation.md, phase-07-01-revamp-kickoff.md,
      phase-07-02..07-10-implementation.md (one per shipped screen). Read the ones relevant to your item.
   9. specs/phase-08-skill-migration-program.md — what comes AFTER this program (context only; don't start).

B) The code — /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/  (read before editing; §3 is the map)
   - genesis-core/genesis_core/**   (shared engine/SDK)
   - genesis/genesis/**             (platform: runtime, dist, config, runs, api, cli, lint)
   - genesis/web/**                 (React+TS workbench — the SHIPPED new app)
   - genesis-workflows/**           (library: registries, steering, workflows, CI)
   - kiro-agent-sdk/src/kiro_agent_sdk/**  (ACP adapter — read client.py + __init__.py)
   - genesis/tests/**, genesis-core/tests/**, genesis-workflows/workflows/*/tests/**

After reading, restate: the layered architecture, the reliability trio, the state/blackboard rule,
the subprocess-worker execution model, and the release/versioning protocol. Then proceed with §9.

════════════════════════════════════════════════════════════════════════
2. CURRENT STATE + latest tags
════════════════════════════════════════════════════════════════════════
Four repos at /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/, all pushed to
git@gitlab.appian-stratus.com:ramaswamy.u/<repo>.git:
  - kiro-agent-sdk    tag v0.1.0   branch main    (ACP adapter; collect + collect_streaming for live conversation)
  - genesis-core      tag v0.4.0   branch master  (nodes/state/registries; kiro_node streams agent.* events; hitl_gate=GateDescriptor; CORE_MAJOR=1)
  - genesis           tag v0.11.0  branch master  (runtime, dist, config, runs, api, cli, web; data plane 07-02; /api + SPA fallback ADR-028; install lifecycle; the SHIPPED new web app)
  - genesis-workflows tag v0.3.1   branch master  (registries, steering, hello-appian + erd-generation [with graph: topology], noncompliant fixture)

Dependency chain (git-pinned by tag; CI rewrites ssh→https):
  genesis (v0.11.0) → genesis-core@v0.4.0 → kiro-agent-sdk@v0.1.0 ;
  genesis-workflows → genesis-core@v0.4.0 (runtime) + genesis (dev pin).

Tests (all green at last release): genesis ~54 pytest · genesis-core ~17 · genesis-workflows ~9 ·
web ~59 Vitest (incl. 6 contract-fixture drift tests). ruff clean; eslint clean; tsc strict clean.
CI green on all repos (genesis has a python `genesis` job + a `frontend` job).

MILESTONE STATUS:
  - Phases 1–6 (platform, contract/library, distribution, config/secrets, run orchestration + HITL,
    ERD reference workflow) — DONE.
  - Phase 7 WEB REVAMP (M7.1), specs 07-01…07-10 — **DONE + shipped** (genesis v0.11.0). The 07-10
    CUTOVER is complete: the new React+TS app is built into web/static/ and served by `genesis serve`;
    the interim workbench (App.tsx/surfaces/run/components/api/types/theme.css) was DELETED.
  - **ACTIVE: the CODE-REVIEW FIX PROGRAM** (specs/phase-07-code-review-fixes/) — P0 persistence/
    migrations + Overview dashboard; P1 Integrations Studio + Conversation rich-chat; P2 retention/
    bus + Postgres decision. NOT yet implemented — this is your work (§9).

What works TODAY (verified):
  - `genesis serve` → FastAPI backend + the SHIPPED new SPA at http://127.0.0.1:8760. API is under
    **/api** (e.g. `/api/config/mcp-cards`, `/api/runs`, `/api/home`), Swagger at `/docs`; a catch-all
    serves index.html for non-/api,/assets paths (SPA history fallback, ADR-028).
  - Screens live: Runs list, Run Detail (React Flow live graph + node inspector + Kiro conversation +
    all-3-mode HITL + documents drawer/preview), Catalog (browse/detail/launch), Settings/Integrations
    (MCP master-detail + secrets + readiness test, CLI cards, GitLab token, environments, storage).
  - KNOWN GAP (your P0 item 02): the **Overview/home** landing screen is still a STATIC PLACEHOLDER —
    `GET /api/home` exists but `web/src/app/routes/Overview.tsx` renders hardcoded data and never calls it.
  - Data plane (07-02): durable SQLite event log survives restart; gate reachable from durable state
    (the approval bug is fixed); Kiro conversation persisted + streamed as agent.* events; /workflows/{id}/
    graph, /runs/{id}/events(+/stream), /steps, artifact content/download all live.
  - hello-appian runs GREEN end-to-end; erd-generation runs into the live Atlas fetch.
  - All three HITL modes, streaming, worker isolation, checkpoint resume — implemented + tested.
  - DEV: `npm run dev` in genesis/web → the app at http://localhost:5173/ (Vite proxies /api → :8760).
    Dev needs BOTH `npm run dev` (:5173) AND `genesis serve` (:8760). Design-system gallery at /dev.

════════════════════════════════════════════════════════════════════════
3. CODEBASE MAP (where things live — so you can navigate edits)
════════════════════════════════════════════════════════════════════════
genesis-core/genesis_core/
  types.py       PlatformContext (run_id, workspace, mcp, clis, settings, emit, secrets,
                 environments, checkpointer, extras); ValidationResult; Node(name,fn,kind);
                 CORE_MAJOR=1; CompatError; check_compat; CTX_KEY="genesis_ctx"; ctx_from_config.
  state.py       PlatformState TypedDict + reducers (_merge, _inc_merge, _telemetry_merge);
                 new_state, record_artifact, record_decision.
  workspace.py   RunWorkspace (per-run blackboard) + Doc + default_artifacts_root.
  validators.py  toolkit: non_empty, parses_json, json_schema, required_keys, values_in_set,
                 count_between, first_field_is, excludes, referential_integrity, all_items_present,
                 matches_predicate, all_of, any_of. (`_dig` dotted paths w/ []).
  mcp/registry.py  McpRegistry.acp_servers(names) -> ACP entries {name,command,args,env:[{name,value}]}
                 (env is a LIST — see §6). Resolve: SecretProvider.resolve(var,server→global) →
                 EnvironmentRegistry.resolve_var → os.environ; unresolved required var raises
                 McpResolutionError (fail-fast). READ-ONLY today (spec 03 adds a writable custom tier).
  clis/registry.py CliRegistry.ensure/run; CliError. Also read-only today (spec 03 adds custom CLIs).
  nodes/  program.py (fn(state,ctx)); agent.py (kiro_node: prompt_fn(state,ctx,out_path), output_doc,
                 mcp=[], tools→trust_tools, turn_timeout=420, startup_timeout=120; set_collect_impl for
                 tests; emits agent.message|thought|tool_call|tool_update|result); cli.py; validator.py;
                 gate.py (hitl_gate via interrupt(); kinds approval|escalation|pre_mutation|review;
                 resume decision → decisions[<gate>.outcome]/.feedback); subgraph.py; reliability.py
                 (attach_reliability(g,agent,validator,retry_max,on_exhaust_gate,nxt) = the trio).
genesis/genesis/
  runtime/  settings.py (Settings: state_dir ~/.genesis [GENESIS_STATE_DIR], artifacts_dir
                 [GENESIS_ARTIFACTS_DIR, default ~/Genesis/runs], db_path, library_dir, lockfile_path,
                 secrets_path, environments_path, retention_keep_last/max_age_days); checkpoint.py
                 (AsyncSqliteSaver async ctx mgr); context.py (build_context — wires PlaintextProvider +
                 EnvironmentRegistry); engine.py (async run/resume/get_state/stream; injects ctx via
                 config["configurable"][CTX_KEY]).
  dist/    gitlab.py (GitLabClient/GitLabConfig REST v4), local.py (LocalSource), catalog.py (Catalog:
                 filter/bundles/cross-role/prereqs), lockfile.py (Lockfile, InstalledWorkflow,
                 GenesisCorePin), install.py (Installer), loader.py (Loader: check_compat gate, meta_of
                 [yaml, no import], installed, load_build [imports graph.py]).
  config/  secrets.py (SecretProvider/PlaintextProvider 0600, scope/VAR, make_key/split_key),
                 fields.py (mcp_cards/cli_cards/secret_fields/missing_secrets; GLOBAL_KEYS={GITLAB_TOKEN};
                 scope_for), environments.py (EnvironmentRegistry credential-free + resolve_var),
                 retention.py (disk_usage, plan_prune, apply_prune, RunInfo), health.py (checks +
                 mcp_literal_env_probe [stubbable] + run_all/all_ok), service.py (ConfigService facade —
                 mcp_registry/cli_registry/mcp_cards/cli_cards/set_secret/test_server/environments/health).
  runs/    store.py (RunStore/RunRecord; statuses pending|running|awaiting_input:gate|
                 awaiting_input:paused|done|failed|cancelled; TERMINAL set), eventlog.py (EventLog —
                 DURABLE run_events table; append/list/last_seq/latest/purge), events.py (Event +
                 in-memory EventBus; legacy _buses + canonical _cbuses — spec 04 consolidates), validation.py
                 (validate_inputs, check_editable, merge_patch), worker.py (SUBPROCESS entry; ops
                 run|resume|get_state|update_state|fork; emits JSONL), supervisor.py, manager.py (RunManager:
                 start/pause/resume/cancel/respond/patch_state/fork/list/wait; writes canonical events to
                 EventLog + fans out; pending_gate [durable fast + checkpoint cold path]; log_events; steps).
  api/     app.py (create_app FastAPI; version 0.11.0). ALL routes on an APIRouter at prefix="/api"
                 (ADR-028) + a catch-all SPA fallback serving web/static/index.html. Routes: catalog +
                 catalog/available, library/install|update, DELETE library/{id}; workflows/{id}(+/graph);
                 config/health, config/gitlab-token (GET/POST), config/mcp-cards, config/cli-cards,
                 config/mcp-cards/{server}/test, config/secrets, config/environments (GET/POST/DELETE);
                 artifacts/usage; home; runs (POST/GET), runs/{id}(+gate), runs/{id}/state (GET/PATCH),
                 pause|resume|cancel|respond|fork, runs/{id}/artifacts(+/{name}(?mode)+/download),
                 runs/{id}/events(?after,kinds,node), /steps, /stream (legacy) + /events/stream (canonical).
                 studio.py (langgraph dev graph).
  cli/     main.py (genesis serve|install|list|create-workflow|test-workflow …), install.py, create_workflow.py.
  lint/    contract.py (workflow.yaml↔META parity; YAML_ONLY_KEYS exempts UI-only keys like `graph:`),
                 reliability.py (trio enforcement).
  web/     React + TS + Vite — the SHIPPED app (ADR-026/027 stack): Tailwind + Radix/shadcn-style +
                 Zustand + React Router (data router) + TanStack Query + Recharts + react-markdown +
                 remark-gfm + mermaid (lazy) + lucide + sonner. Structure:
                 src/styles/{tokens.css,index.css} (Overcut-derived palette); src/lib/{cn.ts, api/**
                 [typed client that PREPENDS /api + ApiError; resource modules], query/** [TanStack keys+
                 client]}; src/stores/** (theme, run-view); src/shared/ui/** (primitives + patterns incl.
                 MetricCard/SegmentedControl/TrendChart/StatusPill/KindBadge/Dialog+Drawer/format/icons);
                 src/shared/layout/** (AppShell/Sidebar/Topbar/SplitPane/Page); src/shared/feedback/**
                 (Empty/Error/Loading); src/app/** (providers, router, RootLayout, routes/Overview
                 [STILL A PLACEHOLDER — spec 02] + ComingSoon); src/features/{overview[to-build],settings,
                 catalog,runs,run-detail,documents}/**; src/test/fixtures (golden contract fixtures);
                 src/dev/KitchenSink.tsx (/dev gallery). main.tsx → app. **static/ = the COMMITTED,
                 built new app** (served by `genesis serve`). The interim app files were DELETED at cutover.
  langgraph.json, docs/debug-in-studio.md.
genesis-workflows/
  registry.json (catalog + genesis_core_major=1), mcp-registry.json (REAL internal images),
  cli-registry.json, bundles.json, schemas/, steering/01-07, ci/validate_library.py (the 7-gate publish
  runner), workflows/{_template, hello-appian, erd-generation, _fixtures/noncompliant}, MIGRATION.md.

════════════════════════════════════════════════════════════════════════
4. NON-NEGOTIABLE CONSTRAINTS (ADRs — do not violate; flag + confirm if a task requires it)
════════════════════════════════════════════════════════════════════════
- ADR-001: LangGraph owns control flow; agents never orchestrate.
- ADR-002/004/020: agent steps = narrow Kiro turns over ACP, per-node MCP injection; NO global Kiro mcp.json.
- ADR-005: shared MCP/CLI registry lives in the library (changed via MR). NOTE: spec 03 (Integrations
  Studio) PROPOSES ADR-029 to add a user-writable CUSTOM tier ON TOP — curated tier stays governed.
- ADR-010/018/022: state is small/serializable/EDITABLE (pointers + decisions); BULK lives in the
  RunWorkspace blackboard under $GENESIS_ARTIFACTS_DIR; never inline bulk in state/chat.
- ADR-011: reliability trio (validator + retry + escalation) MANDATORY on every agent node; CI-enforced.
- ADR-012: workflow graph execution runs in a disposable SUBPROCESS WORKER, not the app process;
  pause=kill worker, resume=fresh worker from checkpoint; app never imports workflow Python (only the worker).
- ADR-019: genesis-core semver; CORE_MAJOR (=1, distinct from pip version) is the compat-gate key; the
  loader REFUSES a library whose declared genesis_core_major != CORE_MAJOR (additive-only within a major).
- ADR-021: META.auto_approve=true default; pause only at 3 sanctioned classes (approval|escalation|
  pre_mutation); pre_mutation REQUIRED before any write/deploy/data MCP node.
- ADR-023: backend is FastAPI embedding LangGraph (NOT a LangGraph Server); Studio is interim debug only.
- ADR-024: engine is ASYNC-first (ainvoke/astream + AsyncSqliteSaver + aiosqlite); Python pinned 3.13.
- ADR-025: "fork" = seed a NEW thread from a past checkpoint; original untouched.
- ADR-026: web UI = React+TS (local single-user); multi-user/hosted would re-open ADR-012/023 (separate track).
- ADR-027: web-revamp stack (Tailwind + shadcn/Radix + React Router + TanStack Query + React Flow +
  react-hook-form/zod + react-markdown/mermaid/shiki + Recharts + Vitest/RTL/MSW). Overcut visual language (07-03a).
- ADR-028: ALL backend endpoints under /api (APIRouter) + SPA history fallback; the web client prepends
  /api centrally (never hard-code it in components); Vite dev proxy is a single /api → :8760.

Key implementation contracts:
- Node fns are `async fn(state, config: RunnableConfig)`. LangGraph injects `config` ONLY when the param
  is annotated `RunnableConfig`. Nodes read ctx via ctx_from_config(config).
- build(ctx) -> CompiledStateGraph compiled with ctx.checkpointer. META is a static dict importable with
  NO side effects. workflow.yaml MUST mirror META (parity lint; UI-only keys like `graph:` are exempt).
- Workflow graph.py is loaded STANDALONE (importlib on the file) — keep it self-contained (no sibling-package
  imports); put pure functions in graph.py.
- ACP MCP entries: env is a LIST of {name,value} (NOT a dict). See §6.

════════════════════════════════════════════════════════════════════════
5. ENVIRONMENT, DEV LOOP, RELEASE, CI  (POST-CUTOVER — read carefully)
════════════════════════════════════════════════════════════════════════
- OS macOS; Python 3.13; node 20 + npm + vite available. Non-interactive shell flags (rm -f, etc.).
- Dev venv (USE THIS for all Python): /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/.venv
  Editable installs of kiro-agent-sdk, genesis-core, genesis (+ pytest, pytest-asyncio, ruff, pyyaml,
  requests, jsonschema, aiosqlite, fastapi, sse-starlette, uvicorn, httpx). Python edits are LIVE for the
  CLI and freshly-spawned subprocess workers — BUT a running `genesis serve` has already imported
  api/app.py + manager.py, so RESTART the server to pick up server-process changes.
- Run tests:
    genesis:           cd genesis && .venv/bin/python -m pytest -q -p no:warnings   (+ ruff check genesis)
    genesis-core:      cd genesis-core && ../genesis/.venv/bin/python -m pytest -q -p no:warnings  (+ ruff check genesis_core)
    genesis-workflows: cd genesis-workflows && ../genesis/.venv/bin/python ci/validate_library.py
                       and  ../genesis/.venv/bin/python -m pytest -q workflows --ignore=workflows/_fixtures
    web (frontend):    cd genesis/web && npm ci && npm run lint && npm run typecheck && npm test
- FRONTEND BUILD (CHANGED at the 07-10 cutover — this is the CURRENT rule):
  * The new app IS the served app. `web/static/` is the COMMITTED production bundle.
  * `npm run build` (= `tsc --noEmit && vite build`) writes `web/static/`. **After ANY web/src change,
    run `npm run build` and COMMIT the updated `web/static/`.** CI's `frontend` job runs
    lint → typecheck → test → build → a **STALE-BUNDLE GUARD** (`git diff --quiet -- static`) that FAILS
    if the committed bundle differs from a fresh build. (This SUPERSEDES the old "build-alongside / do NOT
    commit static/" rule — that era ended at cutover. If any code-review-fix spec's DoD still says
    "web/static/ untouched", treat it as "rebuild + commit web/static/" — the specs predate this note.)
  * Dev loop unchanged: `npm run dev` (:5173) + `genesis serve` (:8760); Vite proxies /api → :8760.
    Data access goes through src/lib/api + src/lib/query; NEVER hard-code URLs or the /api prefix.
- NPM REGISTRY: the local ~/.npmrc points at Appian Artifactory with an EXPIRED token (E401 on new
  installs). Install with `--registry=https://registry.npmjs.org/` for local dev (do NOT edit global
  ~/.npmrc). CI's node:20 has no ~/.npmrc and resolves the lockfile's public-npm URLs fine.
- Run the app:  .venv/bin/genesis serve   (→ http://127.0.0.1:8760, /docs for Swagger)
  Install workflows:  .venv/bin/genesis install --from ../genesis-workflows   (or `genesis install` for GitLab pull)
  List installed:     .venv/bin/genesis list
- Distribution/versioning: pyproject deps are git+ssh. When you change a repo: bump [project].version,
  git commit + tag vX.Y.Z + push, and bump dependent PINS (genesis pins genesis-core; genesis-workflows
  pins both). Order releases core → genesis → genesis-workflows so dependency tags exist. Commits use:
  git -c user.name=Genesis -c user.email=genesis@local commit -m "..."  (do NOT change git config).
- CI: each .gitlab-ci.yml rewrites ssh→https via the `GITLAB_PUSH_TOKEN` CI/CD var (set on all 3 code
  repos — SHOULD BE ROTATED; it was shared in chat). genesis has a `frontend` job (node:20; lint+typecheck+
  test+build+stale-bundle guard) + the python `genesis` job. glab is authed for READS (glab ci list/trace)
  but its token LACKS `api` scope → cannot `glab ci run`/`variable set`; trigger pipelines by PUSHING.
  Verify green: `glab ci list -R ramaswamy.u/<repo>`.
- GITIGNORE LESSON: build-artifact ignores are anchored (`/dist/`, `/build/`, `web/node_modules/`) so they
  don't swallow SOURCE/served packages (e.g. genesis/web/static/ is TRACKED). After adding a source dir,
  verify: `git check-ignore <path>` says NOT ignored and `git ls-files` lists it.
- project-tracker repo (github, branch main) is SEPARATE from the code repos; after meaningful work,
  update tracker.md §6 + a progress/ doc and push it too (git -c user.name=Genesis … ; git pull --rebase; push).

════════════════════════════════════════════════════════════════════════
6. HARD-WON LESSONS / RECENT FIXES (do not regress these)
════════════════════════════════════════════════════════════════════════
- ACP MCP env MUST be a list of {name,value} (McpRegistry.acp_servers). A dict silently drops env in
  kiro-cli acp → the MCP container runs without secrets and hangs to timeout. THE bug that broke
  erd-generation. When stubbing an external contract, mirror its REAL schema (a permissive stub hid this).
- kiro_node builds the REAL KiroAgentOptions (cwd, trust_all_tools, trust_tools, agent, model, agent_engine,
  kiro_cli_path, extra_args, mcp_servers, startup_timeout, turn_timeout, stream_limit_bytes, debug). There is
  NO `tools` field (map an allowlist to trust_tools). turn_timeout=420, startup_timeout=120 for heavy MCP.
- Streaming (SSE): the per-run bus stays open until the run is TERMINAL (so gate pause/resume keeps
  streaming); the client dedupes replayed history and CLOSES the EventSource on terminal final/error —
  else EventSource auto-reconnects and re-replays forever (the "repeated activity" bug). The server sends
  NAMED SSE events (event: <kind>) — the client registers a handler per kind, not just "message".
- Data plane (07-02): the durable EventLog (run_events, SQLite) is the source of truth for a run's
  timeline/conversation; the in-memory EventBus is only live fan-out. Gate/approval controls MUST derive
  from durable state (`GET /runs/{id}.gate` via manager.pending_gate), NEVER from a transient event (that
  ephemerality was the original "can't approve from UI" bug). Canonical event kinds: run.started/
  node.completed/agent.message|thought|tool_call|tool_update|result/validator.result/retry.scheduled/
  gate.awaiting|resolved/run.final/error. There is NO node.started/node.failed — "running"=run.cursor,
  failure is attributed to the cursor on a failed run (see run-detail deriveNodeStates + the steps fold).
- Run Detail resilience: if a workflow declares no `graph:` topology, the UI derives a fallback topology
  from /steps (or events) so the graph/list is never blank. Workflows SHOULD still declare `graph:` (the
  catalog preview needs it; node ids must match LangGraph node names).
- Worker error reporting: a generic worker_exit must NOT clobber a specific 'error' event; empty-message
  exceptions report their type + a hint. For MCP-server logs, run the container standalone (Genesis hides
  them in the ACP subprocess).
- LangGraph specifics: sync invoke can't run async nodes; sync SqliteSaver fails under async (use
  AsyncSqliteSaver). Command(resume=...) needs a checkpointer-compiled graph. Fork seeds a NEW thread.
- Loader compat gate: lockfile genesis_core.major vs CORE_MAJOR — refuse-to-load on mismatch.
- API namespacing (ADR-028): the browser router's client routes (/runs, /catalog, /settings) are real
  paths; ALL backend endpoints live under /api and a catch-all serves index.html otherwise. The client
  prepends /api centrally and REJECTS non-JSON (throws ApiError → ErrorState); there is a route error
  boundary. Uniform 500s on /api/* in the browser usually means the BACKEND ISN'T RUNNING (the Vite proxy
  500s on connection-refused) — `curl http://127.0.0.1:8760/api/config/mcp-cards` first.
- Frontend contract: mirror the 07-02 event/GateDescriptor/topology/steps shapes in web/src/types +
  the golden fixtures in web/src/test/fixtures; a drift must fail a test (contract.test.ts feeds the golden
  log through the real buildTranscript/deriveNodeStates folds). The "stub hid the contract" lesson applies.
- workflow.yaml may carry UI-only keys (e.g. `graph:` topology) — the parity lint exempts them via
  YAML_ONLY_KEYS in genesis/lint/contract.py.
- jest-axe (v9) ships no types: ambient declare module + the vitest matcher augmentation live in
  web/src/types/jest-axe.d.ts + web/src/vitest-axe.d.ts. Keep them PURE ambient / module-aug files.
- mermaid + Recharts are heavy; mermaid is dynamic-imported (lazy chunk). Keep new heavy libs lazy.
- DATA PLANE IS SQLite (code-review finding): runs, the full agent conversation, and checkpoints live in
  ~/.genesis/genesis.db (WAL) — NOT JSON files. Only bulk artifacts are files (blackboard). Persistence is
  currently raw sqlite3 with hand-written DDL in EventLog/RunStore + no migration framework — spec 01 fixes this.

════════════════════════════════════════════════════════════════════════
7. HOW TO WORK ON A FIX/ENHANCEMENT ITEM (the loop I want you to follow)
════════════════════════════════════════════════════════════════════════
1. Restate your understanding of the item + which layer/repo/files it touches; note any ADR that applies.
   Read the spec's "current state" citations and the cited code FIRST (don't guess).
2. Reproduce/verify against the real code. For a bug, write a failing test/repro first.
3. Make the change in the smallest correct scope. Match existing style/patterns.
4. Add/adjust tests (pytest for backend/core; Vitest for web). For bugs, add a regression test that would
   have caught it — and if a stub hid the bug, fix the stub to mirror reality.
5. Run ALL affected suites until green: backend pytest + ruff; web lint + tsc + vitest. For web changes,
   also `npm run build` and COMMIT the updated web/static/ (the CI stale-bundle guard requires it).
6. Release (if a code repo changed): bump version(s) + tag + push + update dependent pins; verify CI green
   via glab. (Frontend-only changes to genesis still ship in a genesis release because static/ is committed.)
7. Update project-tracker (tracker.md §6 status log + a progress/ doc) and push it.
8. Report with CITED evidence (test output, run ids, file diffs). Be honest about what you verified vs.
   couldn't (live Kiro/MCP/browser steps can't be driven headlessly — say so and give the manual check).

════════════════════════════════════════════════════════════════════════
8. BACKLOG — the code-review fix program + other open items
════════════════════════════════════════════════════════════════════════
THE ACTIVE PROGRAM — specs/phase-07-code-review-fixes/ (implement lowest-priority-number first):
  - P0 · 01 Persistence & migrations — genesis/db/ layer + minimal migrator + baseline migration
    adopting the existing runs/run_events tables (zero data loss); refactor EventLog/RunStore. Backend only.
  - P0 · 02 Overview dashboard — extend GET /home (metrics/trend/active-runs/integrations) + wire the
    static Overview.tsx to it. Backend + web.
  - P1 · 03 Integrations Studio — two-tier MCP/CLI registry (curated read-only + custom writable),
    CRUD API, JSON code editor, secrets, tool introspection + per-server allowlist, real handshake test;
    proposes ADR-029. sdk(none)/core/genesis/web. The big one (mini-phase).
  - P1 · 06 Conversation rich-chat — Run-Detail Conversation upgrade (unified auto Thinking timeline +
    markdown + streaming affordances), keeping the durable event-fold engine. Web only.
  - P2 · 04 Event-log retention + bus consolidation (remove legacy _buses). Backend only.
  - P2 · 05 Persistence scale decision (SQLite→Postgres/pgvector triggers) — decision doc; no code yet.

Other open follow-ups (may be assigned):
  - Full ERD dry-run parity check (~37 tables / 174 rels) once the two agent turns complete; record it.
  - Rotate the shared GITLAB_PUSH_TOKEN; refresh the expired Artifactory npm token.
  - lcp MCP image placeholder (<lcp-image>) in mcp-registry.json.
  - THEN Phase 8 (skill migration) — do NOT start unless asked.

════════════════════════════════════════════════════════════════════════
9. RULES OF ENGAGEMENT + THIS SESSION'S TASK
════════════════════════════════════════════════════════════════════════
- Give honest pushback; correct me when I'm wrong. Flag any ADR deviation and confirm before proceeding.
- Ask before destructive/irreversible actions (force push, history rewrite, deleting data, prod anything).
- Don't push directly to shared repos beyond the normal Genesis release flow; never commit secrets; reference
  secrets by key name only.
- If stuck twice on the same error, stop and diagnose root cause; try a different approach.
- Keep changes scoped to the item; don't refactor unrelated code. Do NOT start Phase 8 unless asked.

Now: read the docs/code in §1, restate the architecture + current state + the non-negotiables, then
PROCEED (you don't need to wait for me). My task for this session is:

**Implement the code-review fix program in `specs/phase-07-code-review-fixes/`, lowest-priority-number
first — START with P0 `01-p0-persistence-and-migrations.md`** (introduce the `genesis/db/` layer + a
minimal migration framework + a baseline migration that adopts the existing `runs`/`run_events` tables
with ZERO data loss; refactor `EventLog`/`RunStore` onto it; add tests incl. the data-safety adoption
test). Then **`02-p0-overview-dashboard.md`** (extend `GET /home` + wire the static `Overview.tsx`).
Then P1 (`03` Integrations Studio, `06` Conversation rich-chat) and P2 (`04`, `05`). Follow the §7 loop
end-to-end and autonomously: read the spec's current-state citations, flag any real scope/architecture
decision for sign-off, implement, add tests, run all suites (backend pytest+ruff / web lint+tsc+vitest+
build), rebuild + COMMIT web/static/ if web changed, release the affected repo(s) + verify CI green via
glab, then update tracker §6 + a progress/ doc and push project-tracker. One spec item per session unless
I say otherwise.
````
