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
Phases 1–7 are COMPLETE and the app runs real workflows end-to-end. We are now in a
HARDENING / ENHANCEMENT phase (issue fixes + improvements) BEFORE Phase 8. Your job this
session is to work on specific fix/enhancement items I will give you AFTER you've absorbed
this context. First read everything below and the referenced docs/code, then briefly restate
the architecture + current state and confirm the non-negotiables before changing anything.
Do NOT start coding until you've read the docs and can restate the design.

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
   4. reference/decision-log.md — ADR-001..026 (the "why"; 026 = React+TS choice).
   5. reference/ (all): repo-structure, node-taxonomy-reference, state-and-data-model,
      mcp-and-cli-registry, workflow-authoring-standard, reliability-standard, hitl-design,
      security-and-secrets, testing-strategy, langgraph-capability-map,
      solutions-copilot-relationship, glossary, roadmap-and-sequencing, spike-findings.
   6. progress/phase-01..07-implementation.md — the as-built record for each milestone.
   7. specs/phase-08-skill-migration-program.md — what comes next (context only).

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
  - kiro-agent-sdk    tag v0.0.1   branch main    (ACP adapter; KiroAgentOptions, collect, load_mcp_servers)
  - genesis-core      tag v0.3.3   branch master  (state, workspace, node factories, validators, MCP/CLI registries, compat gate)
  - genesis           tag v0.6.4   branch master  (runtime engine, dist, config, runs, api, cli, web workbench)
  - genesis-workflows tag v0.2.1   branch master  (registries, steering, hello-appian + erd-generation, fixture)

Dependency chain (git-pinned by tag; CI rewrites ssh→https):
  genesis → genesis-core@v0.3.3 → kiro-agent-sdk@v0.0.1 ;
  genesis-workflows → genesis-core (runtime) + genesis (dev).

Tests (all green): genesis 43 · genesis-core 16 · genesis-workflows 9 · web (Vitest) 5. ruff clean. CI green.

What works TODAY (verified live):
  - `genesis serve` → React workbench at http://127.0.0.1:8760 (+ /docs Swagger).
  - `genesis install --from <genesis-workflows dir>`  (or GitLab pull via stored token) → populates ~/.genesis/library.
  - hello-appian runs GREEN end-to-end (real Kiro turn → validator pass → result.json).
  - erd-generation runs past MCP init into the live Atlas schema fetch (the ACP env-shape bug is fixed).
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
                 awaiting_input:paused|done|failed|cancelled; TERMINAL set), events.py
                 (Event, EventBus with history replay), validation.py (validate_inputs jsonschema,
                 check_editable guardrails, merge_patch), worker.py (SUBPROCESS entry:
                 `python -m genesis.runs.worker`; ops run|resume|get_state|update_state|fork;
                 emits JSONL {node|custom|final|error}), supervisor.py (Supervisor.spawn/Worker.kill;
                 reader thread; worker-death detection), manager.py (RunManager: start/pause/resume/
                 cancel/respond/get_state/patch_state/fork/list/wait; per-run EventBus;
                 event_run_id for fork; on_exit keeps bus open until terminal).
  api/     app.py (create_app FastAPI: POST/GET /runs, /runs/{id}/{state,stream(SSE),pause,resume,
                 cancel,respond,fork,artifacts}, PATCH /state, /catalog, /workflows/{id}, /home,
                 /config/{health,gitlab-token,mcp-cards,secrets,environments}, /artifacts/usage;
                 serves the built SPA at "/" + /assets), studio.py (langgraph dev graph).
  cli/     main.py (dispatcher: create-workflow, test-workflow, serve, install, list),
                 create_workflow.py, test_workflow.py, install.py.
  lint/    reliability.py (check_reliability — the Q9 CI gate), contract.py (load_meta,
                 check_meta_yaml_parity, check_hitl_posture).
  testing/ harness.py (run_graph — headless run for tests / `genesis test-workflow`).
  web/     React+TS+Vite SPA. src/: api.ts (typed REST + subscribeRun SSE), types.ts,
                 components.tsx (StatusBadge, Field, useAsync…), surfaces.tsx (Home/Catalog/
                 Config/History), run.tsx (RunLaunch schema form + RunDetail: timeline/activity/
                 state editor/fork/HITL), App.tsx (hash router + sidebar), theme.css (tokens),
                 *.test.* (Vitest). static/ = BUILT bundle (committed; runtime needs no node).
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
    web (frontend):    cd genesis/web && npx tsc --noEmit && npx vitest run && npx vite build
- Frontend: source in genesis/web/src; BUILT bundle in genesis/web/static is COMMITTED (so runtime needs
  no node). If you change web/**, you MUST rebuild (`npm run build` / `npx vite build`) and commit static/,
  then the user hard-refreshes the browser (no server restart needed for static files).
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

════════════════════════════════════════════════════════════════════════
7. HOW TO WORK ON A FIX/ENHANCEMENT ITEM (the loop I want you to follow)
════════════════════════════════════════════════════════════════════════
1. Restate your understanding of the item + which layer/repo/files it touches; note any ADR that applies.
2. Read the relevant code FIRST (don't guess). Reproduce the issue (write a failing test or a repro) when fixing a bug.
3. Make the change in the smallest correct scope. Match existing style/patterns.
4. Add/adjust tests (pytest for backend/core; Vitest for web). For bugs, add a regression test that would
   have caught it — and if a stub hid the bug, fix the stub to mirror reality.
5. Run ALL affected suites + ruff (backend) / tsc + vitest (frontend) until green. If web changed, rebuild
   the bundle and commit static/.
6. Release: bump version(s) + tag + push the changed repo(s) + update dependent pins; verify CI green via glab.
7. Update project-tracker (tracker.md §6 status log; a progress note if substantial) and push it.
8. Report with CITED evidence (test output, run ids, file diffs). Be honest about what you verified vs. couldn't
   (e.g., live Kiro/MCP/browser steps can't be driven headlessly — say so and give the user the manual check).

════════════════════════════════════════════════════════════════════════
8. KNOWN OPEN FOLLOW-UPS (candidate work; I may assign these or others)
════════════════════════════════════════════════════════════════════════
- Catalog install/update/remove BUTTONS in the workbench (backend Installer exists via `genesis install`
  CLI + dist.Installer; needs API endpoints + UI wiring).
- Browser/UX pass on the workbench (accessibility audit, visual polish, empty/error states, stream reconnect UX).
- Full ERD dry-run parity check (~37 tables / 174 relationships) once the two agent turns complete; record it.
- Retention purge endpoints (/runs/purge, DELETE /runs/{id}/artifacts) — retention module exists; wire the API/UI.
- In-flight ACP session/cancel on pause (SDK enhancement) so a slow Kiro turn cancels promptly.
- Rotate the shared GITLAB_PUSH_TOKEN.
- lcp MCP image is still a placeholder (<lcp-image>) in mcp-registry.json (OD-1 future).

════════════════════════════════════════════════════════════════════════
9. RULES OF ENGAGEMENT
════════════════════════════════════════════════════════════════════════
- Give honest pushback; correct me when I'm wrong. Flag any ADR deviation and confirm before proceeding.
- Ask before destructive/irreversible actions (force push, history rewrite, deleting data, prod anything).
- Don't push directly to main/master of shared repos without permission beyond the normal Genesis release flow
  we already use; never commit secrets; reference secrets by key name only.
- If stuck twice on the same error, stop and diagnose root cause; try a different approach.
- Keep changes scoped to the item; don't refactor unrelated code or start Phase 8 unless asked.

Now: read the docs/code in §1, restate the architecture + current state + the non-negotiables,
then ask me for (or proceed with) the specific fix/enhancement item. My task for this session is:

<<< PASTE THE SPECIFIC ITEM(S) HERE >>>
````
