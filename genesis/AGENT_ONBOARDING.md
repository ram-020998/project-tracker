# Genesis — Agent Onboarding Prompt

> Paste the fenced block below as the **first message** in any new agent session that will
> work on Genesis fixes/enhancements. Swap the final line with the specific item(s) for that
> session. The prompt makes the agent absorb the full architecture, current state, and
> operational rules before touching code.
>
> Keep this file updated when the architecture, tags, or hard-won lessons change (append to
> §2 tags, §6 lessons, and §8 follow-ups as the project evolves).

---

````
You are joining "Genesis" — an agentic SDLC platform for the Appian Solutions department.
Phases 1–7 are COMPLETE and the app runs real workflows end-to-end. We are now executing the
**WEB REVAMP program (milestone M7.1)** — a spec-first, full rebuild of the web workbench into
an enterprise-grade, Overcut-inspired app. The backend data plane (07-02) and the frontend
design system (07-03/07-03a) are DONE; the remaining work is the **screen specs 07-04 → 07-10**.
Your job this session is the specific spec/item I give you AFTER you've absorbed this context.
First read everything below and the referenced docs/code, then briefly restate the architecture
+ current state and confirm the non-negotiables before changing anything. Do NOT start coding
until you've read the docs and can restate the design.

════════════════════════════════════════════════════════════════════════
0. WHAT GENESIS IS (one paragraph)
════════════════════════════════════════════════════════════════════════
Genesis is a LOCAL, single-user web application that lets a Solutions engineer discover,
install, run, and supervise WORKFLOWS. A workflow is a LangGraph graph whose nodes are
deterministic PROGRAM steps or narrow AGENT steps that drive Kiro via `kiro-agent-sdk` over
ACP, injecting only the MCP server(s) that step needs. LangGraph owns control flow + durable
state; a per-run artifacts folder (blackboard) holds bulk data; workflows are pulled from the
shared `genesis-workflows` GitLab repo via selective install + lockfile. Every agent step is
wrapped by a program validator + retry/escalation (hard requirement). It replaces the retired
solutions-copilot (which failed by using an LLM as orchestrator). Backend = FastAPI embedding
LangGraph as a library + subprocess workers; frontend = React+TS SPA. Runs on localhost with
the user's own creds. NOTE: the destination is "enterprise-grade polish" but STILL local
single-user — multi-user/hosted is explicitly a separate future track (see ADR-026), do not
build auth/multi-tenancy unless asked.

════════════════════════════════════════════════════════════════════════
1. READ THESE FIRST (in order) — do not skip
════════════════════════════════════════════════════════════════════════
A) Design + as-built docs — /Users/ramaswamy.u/repo/project-tracker/genesis/
   1. README.md
   2. tracker.md  — locked decisions Q1–Q14, phase index (§3a), and §6 STATUS LOG
      (READ §6 fully — it is the running history incl. every post-Phase-7 fix).
   3. specs/00-architecture-overview.md  — layers, domain model, node taxonomy, state/blackboard rule.
   4. reference/decision-log.md — ADR-001..027 (the "why"; 026 = React+TS, 027 = web-revamp stack + Overcut study).
   5. reference/ (all): repo-structure, node-taxonomy-reference, state-and-data-model,
      mcp-and-cli-registry, workflow-authoring-standard, reliability-standard, hitl-design,
      security-and-secrets, testing-strategy, langgraph-capability-map,
      solutions-copilot-relationship, glossary, roadmap-and-sequencing, spike-findings.
   6. **WEB REVAMP specs (the active program) — specs/phase-07-0N-*:**
      - 07-01 program overview & frontend architecture (ANCHOR: stack, folder structure, routing, sequencing)
      - 07-02 backend & core data plane (DONE — persistent event log, gate-from-checkpoint, ACP conversation streaming, topology/steps/artifact APIs)
      - 07-03 design system + 07-03a visual-language reference (DONE — the Overcut study; tokens/components)
      - 07-04 settings · 07-05 catalog · 07-06 runs list · 07-07 run-detail graph ·
        07-08 node inspection + Kiro conversation + HITL · 07-09 documents · 07-10 testing/CI/rollout (REMAINING)
   7. progress/phase-01..07-implementation.md + phase-07-01-revamp-kickoff.md +
      phase-07-02-implementation.md + phase-07-03-implementation.md — as-built records.
   8. specs/phase-08-skill-migration-program.md — what comes AFTER the web revamp (context only).

B) The code — /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/  (read before editing; §3 is the map)
   - genesis-core/genesis_core/**   (shared SDK)
   - genesis/genesis/**             (platform: runtime, dist, config, runs, api, cli, lint, web)
   - genesis/web/**                 (React+TS workbench)
   - genesis-workflows/**           (library: registries, steering, workflows, CI)
   - kiro-agent-sdk/src/kiro_agent_sdk/**  (ACP adapter — read client.py + __init__.py)
   - genesis/tests/**, genesis-core/tests/**, genesis-workflows/workflows/*/tests/**

After reading, restate: the layered architecture, the reliability trio, the state/blackboard
rule, the subprocess-worker execution model, and the release/versioning protocol. Then wait
for / proceed with my task.

════════════════════════════════════════════════════════════════════════
2. CURRENT STATE (post-Phase-7) + latest tags
════════════════════════════════════════════════════════════════════════
Four repos at /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/, all pushed to
git@gitlab.appian-stratus.com:ramaswamy.u/<repo>.git:
  - kiro-agent-sdk    tag v0.1.0   branch main    (ACP adapter; + collect_streaming for live conversation)
  - genesis-core      tag v0.4.0   branch master  (nodes/state/registries; kiro_node streams agent.* events; hitl_gate = GateDescriptor; CORE_MAJOR still 1)
  - genesis           tag v0.10.0  branch master  (runtime, dist, config, runs, api, cli, web; data plane 07-02; API under /api + SPA fallback — ADR-028; install-lifecycle API — 07-05)
  - genesis-workflows tag v0.3.1   branch master  (registries, steering, hello-appian + erd-generation [+ graph: topology], fixture)

Dependency chain (git-pinned by tag; CI rewrites ssh→https):
  genesis (v0.10.0) → genesis-core@v0.4.0 → kiro-agent-sdk@v0.1.0 ;
  genesis-workflows → genesis-core@v0.4.0 (runtime) + genesis@v0.7.0 (dev).

Tests (all green): genesis 48 · genesis-core 17 · genesis-workflows 9 · web (Vitest) 14. ruff clean. CI green (frontend + python jobs).

WEB REVAMP status (M7.1 — the active program):
  - 07-01 (program/architecture), 07-02 (backend data plane), 07-03 + 07-03a (design system + Overcut visual language) — DONE, released, CI-green.
  - 07-04 (Settings) — DONE (genesis v0.9.0; incl. /api namespacing). 07-05 (Catalog) — DONE (v0.10.0). 07-06 (Runs) — DONE. 07-07 (Run Detail graph) — DONE (React Flow live graph; frontend-only). 07-08..07-10 (node conversation + HITL, Documents, testing/rollout) — REMAINING. Build these next.

What works TODAY (verified):
  - `genesis serve` → FastAPI backend at http://127.0.0.1:8760; **API under /api** (e.g. `/api/config/mcp-cards`), Swagger at `/docs`. It also serves the committed `static/` bundle at `/` with a **SPA history fallback** — but that bundle is the OLD interim app which calls root paths, so its UI no longer reaches the API (retired at the 07-10 cutover). Use it as the BACKEND for the new dev app.
  - `npm run dev` in genesis/web → the NEW app at http://localhost:5173/ (grouped shell + placeholder Overview; Settings is live; screens land at their routes as built). Dev needs BOTH `npm run dev` (:5173) AND `genesis serve` (:8760) running — Vite proxies `/api` → :8760. Design-system gallery at /dev (and /dev.html).
  - Data plane (07-02): durable event log survives restart; gate reachable from durable state (approval bug fixed); Kiro conversation streamed as agent.* events; /workflows/{id}/graph, /runs/{id}/events(+/stream), /steps, artifact content/download all live.
  - hello-appian runs GREEN end-to-end; erd-generation past MCP init into the live Atlas fetch.
  - All three HITL modes, streaming, worker isolation, checkpoint resume — implemented + tested.

════════════════════════════════════════════════════════════════════════
3. CODEBASE MAP (where things live — so you can navigate edits)
════════════════════════════════════════════════════════════════════════
genesis-core/genesis_core/
  types.py       PlatformContext (run_id, workspace, mcp, clis, settings, emit, secrets,
                 environments, checkpointer, extras); ValidationResult; Node(name,fn,kind)
                 (__post_init__ stamps _genesis_kind/_genesis_name); CORE_MAJOR=1; CompatError;
                 check_compat; CTX_KEY="genesis_ctx"; ctx_from_config(config).
  state.py       PlatformState TypedDict + reducers (_merge, _inc_merge, _telemetry_merge);
                 new_state, record_artifact, record_decision.
  workspace.py   RunWorkspace (per-run blackboard) + Doc + default_artifacts_root.
  validators.py  toolkit: non_empty, parses_json, json_schema, required_keys, values_in_set,
                 count_between, first_field_is, excludes, referential_integrity,
                 all_items_present, matches_predicate, all_of, any_of. (`_dig` dotted paths w/ []).
  mcp/registry.py  McpRegistry.acp_servers(names) -> ACP entries {name,command,args,
                 env:[{name,value}]} (env is a LIST — see §6 lesson). Resolve order:
                 SecretProvider.resolve(var,server→global) → EnvironmentRegistry.resolve_var → os.environ;
                 unresolved required var raises McpResolutionError (fail-fast).
  clis/registry.py CliRegistry.ensure/run; CliError.
  nodes/  program.py (fn(state,ctx)); agent.py (kiro_node: prompt_fn(state,ctx,out_path),
                 output_doc, mcp=[], tools→trust_tools, turn_timeout=420, startup_timeout=120;
                 set_collect_impl for tests); cli.py; validator.py; gate.py (hitl_gate via
                 interrupt(); kinds approval|escalation|pre_mutation|review; resume decision →
                 decisions[<gate>.outcome]/.feedback); subgraph.py; reliability.py
                 (attach_reliability(g,agent,validator,retry_max,on_exhaust_gate,nxt) = the trio).
genesis/genesis/
  runtime/  settings.py (Settings: state_dir ~/.genesis [GENESIS_STATE_DIR], artifacts_dir
                 [GENESIS_ARTIFACTS_DIR, default ~/Genesis/runs], db_path, library_dir,
                 lockfile_path, secrets_path, environments_path, retention_keep_last/max_age_days);
                 checkpoint.py (AsyncSqliteSaver async ctx mgr); context.py (build_context —
                 default-wires PlaintextProvider + EnvironmentRegistry); engine.py (async
                 run/resume/get_state/stream; injects ctx via config["configurable"][CTX_KEY]).
  dist/    gitlab.py (GitLabClient/GitLabConfig REST v4), local.py (LocalSource), catalog.py
                 (Catalog: filter/bundles/cross-role/prereqs), lockfile.py (Lockfile,
                 InstalledWorkflow, GenesisCorePin), install.py (Installer), loader.py (Loader:
                 check_compat gate, meta_of [yaml, no import], installed, load_build [imports graph.py]).
  config/  secrets.py (SecretProvider/PlaintextProvider 0600, scope/VAR, make_key/split_key),
                 fields.py (mcp_cards/secret_fields/missing_secrets; GLOBAL_KEYS={GITLAB_TOKEN};
                 scope_for), environments.py (EnvironmentRegistry credential-free + resolve_var
                 active-env hook), retention.py (disk_usage, plan_prune, apply_prune, RunInfo),
                 health.py (checks + mcp_literal_env_probe [stubbable] + run_all/all_ok),
                 service.py (ConfigService facade).
  runs/    store.py (RunStore/RunRecord; statuses pending|running|awaiting_input:gate|
                 awaiting_input:paused|done|failed|cancelled; TERMINAL set), eventlog.py
                 (EventLog — DURABLE run_events table; append/list/last_seq/latest/purge — 07-02),
                 events.py (Event, in-memory EventBus + canonical bus), validation.py
                 (validate_inputs, check_editable, merge_patch), worker.py (SUBPROCESS entry;
                 ops run|resume|get_state|update_state|fork; emits JSONL), supervisor.py, manager.py
                 (RunManager: start/pause/resume/cancel/respond/patch_state/fork/list/wait; writes
                 canonical events to EventLog + fans out; pending_gate [durable fast + checkpoint cold
                 path]; log_events; steps; GateResponseError).
  api/     app.py (create_app FastAPI). Data-plane endpoints (07-02): GET /runs/{id} (+gate),
                 /runs/{id}/events(?after,kinds,node), /runs/{id}/events/stream (canonical replay+live),
                 /runs/{id}/steps, /workflows/{id}/graph, /runs/{id}/artifacts + /{name}(?mode) + /download,
                 mcp-cards (+status), cli-cards, mcp-cards/{server}/test (readiness probe);
                 catalog/available + library/install|update + DELETE library/{id} (install lifecycle via
                 Installer, source_factory-injectable — 07-05); plus the
                 Phase-5 run-control + config endpoints. ALL routes are on an APIRouter mounted at
                 **prefix="/api"** (ADR-028); a catch-all serves index.html for non-/api,/assets paths
                 (SPA history fallback). Serves the committed static/ SPA at "/". studio.py (langgraph dev graph).
  ...
  web/     React + TS + Vite. NEW app (phase-07-03, ADR-027 stack): Tailwind + Radix/shadcn-style +
                 Zustand + React Router + TanStack Query (screens) + Recharts + sonner + lucide.
                 Structure: src/styles/{tokens.css,index.css} (Overcut-derived dark/light palette);
                 src/lib/cn.ts; src/stores/theme.ts; src/shared/ui/** (primitives + patterns:
                 Button/Card/Input/Badge+StatusPill/StatusDot/KindBadge/Switch/Tooltip/Tabs/Dialog+Drawer/
                 MetricCard/SegmentedControl/chips/HealthDot/TrendChart/format/toast/icons); src/shared/
                 layout/** (AppShell/Sidebar[grouped nav]/Topbar/SplitPane/Page); src/shared/feedback/**
                 (Empty/Error/Loading); src/app/** (providers, router, RootLayout, routes/Overview
                 [placeholder] + ComingSoon); src/dev/KitchenSink.tsx (gallery at /dev + /dev.html);
                 main.tsx → new app. INTERIM app (App.tsx, surfaces.tsx, run.tsx, components.tsx,
                 theme.css, api.ts, types.ts) is RETAINED but unreferenced — deleted at cutover (07-10).
                 static/ = the COMMITTED bundle still serving the INTERIM app (do NOT rebuild/commit it
                 until cutover). Feature dirs src/features/{settings,catalog,runs,run-detail,documents}
                 are created as 07-04..09 land.
  langgraph.json, docs/debug-in-studio.md.
genesis-workflows/
  registry.json (catalog + genesis_core_major=1), mcp-registry.json (REAL internal images),
  cli-registry.json, bundles.json, schemas/, steering/01-07, ci/validate_library.py (the 7-gate
  publish runner), workflows/{_template, hello-appian, erd-generation, _fixtures/noncompliant},
  MIGRATION.md.

════════════════════════════════════════════════════════════════════════
4. NON-NEGOTIABLE CONSTRAINTS (ADRs — do not violate; flag + confirm if a task requires it)
════════════════════════════════════════════════════════════════════════
- ADR-001: LangGraph owns control flow; agents never orchestrate.
- ADR-002/004/020: agent steps = narrow Kiro turns over ACP, per-node MCP injection; NO global Kiro mcp.json.
- ADR-010/018/022: state is small/serializable/EDITABLE (pointers + decisions); BULK lives in the
  RunWorkspace blackboard under $GENESIS_ARTIFACTS_DIR; never inline bulk in state/chat.
- ADR-011: reliability trio (validator + retry + escalation) MANDATORY on every agent node; CI-enforced.
- ADR-012: workflow graph execution runs in a disposable SUBPROCESS WORKER, not the app process;
  pause=kill worker, resume=fresh worker from checkpoint; app never imports workflow Python (only the worker does).
- ADR-019: genesis-core semver; CORE_MAJOR (=1, distinct from pip version) is the compat-gate key;
  the loader REFUSES a library whose declared genesis_core_major != CORE_MAJOR (additive-only within a major).
- ADR-021: META.auto_approve=true default; pause only at 3 sanctioned classes (approval|escalation|pre_mutation);
  pre_mutation REQUIRED before any write/deploy/data MCP node.
- ADR-023: backend is FastAPI embedding LangGraph (NOT a LangGraph Server); Studio is interim debug only.
- ADR-024: engine is ASYNC-first (ainvoke/astream + AsyncSqliteSaver + aiosqlite); Python pinned 3.13.
- ADR-025: "fork" = seed a NEW thread from a past checkpoint; original untouched.
- ADR-026: web UI = React+TS (local single-user); multi-user/hosted would re-open ADR-012/023 (separate track).

Key implementation contracts:
- Node fns are `async fn(state, config: RunnableConfig)`. LangGraph injects `config` ONLY when the
  param is annotated `RunnableConfig` (from langchain_core.runnables). Nodes read ctx via ctx_from_config(config).
- build(ctx) -> CompiledStateGraph, compiled with ctx.checkpointer. META is a static dict importable
  with NO side effects (load_meta reads it without calling build). workflow.yaml MUST mirror META (parity lint).
- Workflow graph.py is loaded STANDALONE by the loader (importlib on the file) — keep it self-contained
  (no sibling-package imports); put pure functions in graph.py (see hello-appian / erd-generation).
- ACP MCP entries: env is a LIST of {name,value} (NOT a dict). See §6.

════════════════════════════════════════════════════════════════════════
5. ENVIRONMENT, DEV LOOP, RELEASE, CI
════════════════════════════════════════════════════════════════════════
- OS macOS; Python 3.13; node 20 + npm + esbuild/vite available. Non-interactive shell flags (rm -f, etc.).
- Dev venv (USE THIS for all Python): /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/.venv
  Editable installs of kiro-agent-sdk, genesis-core, genesis (+ pytest, pytest-asyncio, ruff, pyyaml,
  requests, jsonschema, aiosqlite, fastapi, sse-starlette, uvicorn, httpx). Because installs are editable,
  Python source edits are LIVE for the CLI and for freshly-spawned subprocess workers — BUT a running
  `genesis serve` (uvicorn) has already imported api/app.py + manager.py into memory, so RESTART the
  server to pick up server-process changes. Reinstall entry points with `pip install -e . --no-deps`.
- Run tests:
    genesis:           cd genesis && .venv/bin/python -m pytest -q -p no:warnings   (+ ruff check genesis)
    genesis-core:      cd genesis-core && ../genesis/.venv/bin/python -m pytest -q -p no:warnings  (+ ruff check genesis_core)
    genesis-workflows: cd genesis-workflows && ../genesis/.venv/bin/python ci/validate_library.py
                       and  ../genesis/.venv/bin/python -m pytest -q workflows --ignore=workflows/_fixtures
    web (frontend):    cd genesis/web && npm ci && npx tsc --noEmit && npx vitest run
                       (VERIFY a build with `npx vite build --outDir /tmp/verify --emptyOutDir` —
                        do NOT run `npm run build`, which writes to static/ and would clobber the
                        committed INTERIM bundle before cutover.)
- Frontend (WEB REVAMP, build-alongside per 07-10): the NEW app is the dev root — `npm run dev`
  → http://localhost:5173/ (screens), /dev = design-system gallery. **Dev needs BOTH servers up:**
  `npm run dev` (:5173) AND `genesis serve` (:8760); Vite proxies **`/api` → :8760** (single prefix —
  the API is namespaced under /api, ADR-028). Data-access goes through `src/lib/api` (typed client that
  prepends `/api` + `ApiError`) + `src/lib/query` (TanStack Query keys/client); NEVER hard-code URLs or
  the /api prefix in components. The committed genesis/web/static bundle STILL serves the INTERIM app
  (via `genesis serve` on :8760) but it calls root paths so its UI is now API-broken; **do NOT rebuild or
  commit static/ until the 07-10 cutover.** New screens go under src/features/** + src/app/router.tsx and
  compose from src/shared/** (the design system). Keep interim App.tsx/etc. untouched until cutover.
- NPM REGISTRY: the local ~/.npmrc points at Appian Artifactory with an EXPIRED token (E401 on new
  installs). Install with `--registry=https://registry.npmjs.org/` for local dev (do NOT edit the
  global ~/.npmrc). CI's node:20 has no ~/.npmrc and resolves the lockfile's public-npm URLs fine.
- Run the app:  .venv/bin/genesis serve   (→ http://127.0.0.1:8760, /docs for Swagger)
  Install workflows:  .venv/bin/genesis install --from ../genesis-workflows   (or `genesis install` for GitLab pull)
  List installed:     .venv/bin/genesis list
- Distribution/versioning: pyproject deps are git+ssh (local dev). When you change a repo: bump its
  [project].version, git commit + tag vX.Y.Z + push, and bump dependent PINS (genesis pins genesis-core;
  genesis-workflows pins both). Order releases core → genesis → genesis-workflows so dependency tags exist.
  Commits use: git -c user.name=Genesis -c user.email=genesis@local commit -m "..."  (do NOT change git config).
- CI: each .gitlab-ci.yml rewrites ssh→https via the `GITLAB_PUSH_TOKEN` CI/CD var (already set on all 3
  repos — SHOULD BE ROTATED at some point, it was shared in chat). genesis has a `frontend` job (node:20,
  runs on web/** changes) + the python `genesis` job. glab CLI is authed for READS (glab ci list/trace)
  but its token LACKS `api` scope → cannot `glab ci run`/`glab variable set`; trigger pipelines by PUSHING
  (empty commit if needed). Verify green with: `glab ci list -R ramaswamy.u/<repo>`.
- GITIGNORE LESSON: build-artifact ignores are anchored (`/dist/`, `/build/`, `web/node_modules/`) so they
  don't swallow SOURCE packages (e.g. genesis/dist/, genesis/web/static/). After adding a new source dir,
  verify it's tracked: `git check-ignore <path>` should say NOT ignored, and `git ls-files` should list it.
- project-tracker repo (github.com/ram-020998/project-tracker, branch main) is SEPARATE from the code repos;
  after meaningful work, update tracker.md §6 + relevant progress/ docs and push it too.

════════════════════════════════════════════════════════════════════════
6. HARD-WON LESSONS / RECENT FIXES (do not regress these)
════════════════════════════════════════════════════════════════════════
- ACP MCP env MUST be a list of {name,value} (McpRegistry.acp_servers). A dict silently drops env in
  kiro-cli acp → the MCP container runs without its secrets and hangs to the session timeout. This was THE
  bug that made erd-generation fail. Tests that stub the SDK must assert the REAL shape (a permissive stub
  hid this for weeks). When stubbing an external contract, mirror its real schema.
- kiro_node builds the REAL KiroAgentOptions (fields: cwd, trust_all_tools, trust_tools, agent, model,
  agent_engine, kiro_cli_path, extra_args, mcp_servers, startup_timeout, turn_timeout, stream_limit_bytes,
  debug). There is NO `tools` field (map an allowlist to trust_tools). turn_timeout=420, startup_timeout=120
  for heavy MCP servers (e.g. Atlas). A regression test builds the real dataclass with only collect() stubbed.
- Streaming (SSE): the per-run EventBus stays open until the run is TERMINAL (so gate pause/resume keeps
  streaming); the client dedupes replayed history and CLOSES the EventSource on a terminal final/error —
  otherwise EventSource auto-reconnects and re-replays history forever (the "13× repeated activity" bug).
- Worker error reporting: a generic worker_exit must NOT clobber a specific 'error' event; empty-message
  exceptions (CancelledError/TimeoutError) report their type + a hint. Diagnose from run store detail +
  checkpoint state; for MCP-server logs run the container standalone (Genesis hides them in the ACP subprocess).
- LangGraph specifics: sync invoke can't run async nodes; sync SqliteSaver fails under async (use
  AsyncSqliteSaver). Command(resume=...) needs a checkpointer-compiled graph. Fork seeds a NEW thread.
- Loader compat gate: lockfile genesis_core.major vs CORE_MAJOR — refuse-to-load on mismatch.
- WEB-REVAMP API namespacing (ADR-028, genesis v0.9.0): the new app uses a BROWSER router, so its
  client routes (/runs, /catalog, /settings) are real paths that collided with the root-path API. ALL
  backend endpoints now live under **/api** (APIRouter prefix), and a catch-all serves index.html for
  non-/api,/assets paths (SPA history fallback). The frontend client prepends /api centrally; the Vite
  dev proxy is a single `/api` → :8760. TWO consequences to remember: (1) the dev app needs BOTH
  `npm run dev` AND a running `genesis serve` — a relative fetch with no backend/proxy hits the SPA
  fallback and returns HTML (which crashed the MCP sorter once); (2) the committed interim static/ bundle
  calls root paths and is now API-broken until the 07-10 cutover. The API client also REJECTS non-JSON
  responses (throws ApiError → ErrorState) and there is a route error boundary — don't regress these.
- Uniform 500s on every /config/* call in the browser usually means the BACKEND ISN'T RUNNING: the Vite
  proxy returns 500 on connection-refused. Check `curl http://127.0.0.1:8760/api/config/mcp-cards` first.
- WEB-REVAMP data plane (07-02): the durable EventLog (run_events table) is the source of truth for a
  run's timeline/conversation — the in-memory EventBus is only live fan-out. Gate/approval controls MUST
  derive from durable state (`GET /runs/{id}.gate` via manager.pending_gate), NEVER from a transient event
  (that ephemerality was the original "can't approve from UI" bug). Canonical events: run.started/
  node.completed/agent.message|thought|tool_call|tool_update|result/validator.result/retry.scheduled/
  gate.awaiting|resolved/run.final/error. Kiro conversation = kiro_node forwarding SDK messages via ctx.emit
  (graceful fallback to non-streaming collect when the SDK/stub lacks streaming; _STUBBED guards this).
- WEB-REVAMP frontend contract: mirror the 07-02 event/GateDescriptor/topology/steps shapes in web/src/
  types + MSW fixtures; a drift should fail a test (the "stub hid the contract" lesson applies to the FE too).
- workflow.yaml may carry UI-only keys (e.g. `graph:` topology) — the contract parity lint exempts them
  via YAML_ONLY_KEYS in genesis/lint/contract.py. Node ids in `graph:` must match the LangGraph node names.
- jest-axe (v9) ships no types: ambient `declare module "jest-axe"` in web/src/types/jest-axe.d.ts +
  the vitest matcher augmentation in web/src/vitest-axe.d.ts. Keep them as PURE ambient / module-aug files.
- Recharts bloats the bundle (chunk-size warning) — route-level code-splitting is deferred to 07-10.

════════════════════════════════════════════════════════════════════════
7. HOW TO WORK ON A FIX/ENHANCEMENT ITEM (the loop I want you to follow)
════════════════════════════════════════════════════════════════════════
1. Restate your understanding of the item + which layer/repo/files it touches; note any ADR that applies.
2. Read the relevant code FIRST (don't guess). Reproduce the issue (write a failing test or a repro) when fixing a bug.
3. Make the change in the smallest correct scope. Match existing style/patterns.
4. Add/adjust tests (pytest for backend/core; Vitest for web). For bugs, add a regression test that would
   have caught it — and if a stub hid the bug, fix the stub to mirror reality.
5. Run ALL affected suites + ruff (backend) / tsc + vitest (frontend) until green. For web work,
   VERIFY the build to a temp dir; do NOT rebuild/commit static/ before the 07-10 cutover.
6. Release: bump version(s) + tag + push the changed repo(s) + update dependent pins; verify CI green via glab.
7. Update project-tracker (tracker.md §6 status log; a progress note if substantial) and push it.
8. Report with CITED evidence (test output, run ids, file diffs). Be honest about what you verified vs. couldn't
   (e.g., live Kiro/MCP/browser steps can't be driven headlessly — say so and give the user the manual check).

════════════════════════════════════════════════════════════════════════
8. KNOWN OPEN FOLLOW-UPS (candidate work; I may assign these or others)
════════════════════════════════════════════════════════════════════════
8. THE ACTIVE PROGRAM — WEB REVAMP (M7.1). Remaining specs, in recommended order (each is a
   self-contained session; read the spec, then build the screen composing src/shared/** + the
   07-02 data plane, wire it into src/app/router.tsx replacing its ComingSoon placeholder):
   - 07-04 Settings/Integrations — ✅ DONE (genesis v0.9.0; MCP master-detail, CLI cards, GitLab token, environments CRUD, storage; + the /api namespacing fix, ADR-028).
   - 07-05 Catalog & install — ✅ DONE (genesis v0.10.0; install-lifecycle API + browse/detail/launch; static graph preview pending 07-07's React Flow renderer).
   - 07-06 Runs list & history — ✅ DONE (frontend-only; Active/History tables, filters, active-scoped polling, quick actions).
   - 07-07 Run Detail: graph — ✅ DONE (React Flow live node-status graph + node-status fold + SSE tail + list/timeline/telemetry; inspector/docs are 07-08/09 slots).
   - 07-08 Run Detail: node inspection + Kiro conversation + HITL — per-node transcript from /events, all 3 HITL modes from durable gate.  ← NEXT
   - 07-07 Run Detail: graph — React Flow (@xyflow/react) live node-status graph from /workflows/{id}/graph + /events fold.
   - 07-08 Run Detail: node inspection + Kiro conversation + HITL — per-node transcript from /events, all 3 HITL modes from durable gate.
   - 07-09 Documents & preview — artifacts drawer + rendered preview (md/json/mermaid/csv/text).
   - 07-10 Testing/CI/rollout — MSW contract fixtures, Playwright smoke (incl. approve-a-gate), CI (lint/typecheck/test/build + stale-bundle guard), then the CUTOVER: repoint the served bundle to the new app, delete interim files, rebuild + commit static/.
   New deps for screens (add + install from public npm): @tanstack/react-query, @xyflow/react,
   react-hook-form + zod, react-markdown + remark-gfm + mermaid, shiki, eslint (+ config, for 07-10).
   Post-revamp / other open items:
   - Full ERD dry-run parity check (~37 tables / 174 rels) once the two agent turns complete; record it.
   - Per-integration connection TEST endpoint + cli-cards; artifact.written events; retention eventlog purge (07-02 deferred).
   - Rotate the shared GITLAB_PUSH_TOKEN; refresh the expired Artifactory npm token.
   - lcp MCP image placeholder (<lcp-image>) in mcp-registry.json. Then PHASE 8 (skill migration).

════════════════════════════════════════════════════════════════════════
9. RULES OF ENGAGEMENT
════════════════════════════════════════════════════════════════════════
- Give honest pushback; correct me when I'm wrong. Flag any ADR deviation and confirm before proceeding.
- Ask before destructive/irreversible actions (force push, history rewrite, deleting data, prod anything).
- Don't push directly to main/master of shared repos without permission beyond the normal Genesis release flow
  we already use; never commit secrets; reference secrets by key name only.
- If stuck twice on the same error, stop and diagnose root cause; try a different approach.
- Keep changes scoped to the item; don't refactor unrelated code. The active program is the WEB
  REVAMP (07-04 → 07-10); do NOT start Phase 8 (skill migration) unless asked.

Now: read the docs/code in §1, restate the architecture + current state + the non-negotiables,
then PROCEED (you don't need to wait for me) with the next phase. The active program is the web
revamp; the next item is the lowest-numbered UNDONE spec in §8. My task for this session is:

**Continue the web revamp — implement the next undone phase in §8, currently
`specs/phase-07-08-node-inspection-conversation-hitl.md`** (fill the Run Detail Inspector with the
per-node Kiro conversation transcript from `agent.*` events + Inputs/Outputs/Validation/Raw tabs,
and add the HITL bar — approve/reject/feedback/pause/resume/cancel/fork — driven by the DURABLE
gate, `GET /runs/{id}.gate`; this is the ADR-028/07-02 "approval-from-durable-state" guarantee
reaching the UI). Work the full loop in §7 end-to-end and autonomously: read the spec, flag any
contract gap + get sign-off only for a genuine scope/architecture decision, implement, add tests,
run all suites (backend pytest+ruff / web tsc+vitest+build), release the affected repo(s) + verify
CI green via glab if a backend changed, keep `web/static/` untouched (build-alongside), then update
the tracker §6 + a `progress/phase-07-08-implementation.md` and push project-tracker. When 07-08 is
done and pushed, continue to 07-09, then 07-10 — one phase per session unless I say otherwise.
````
