# Review 55-11 — base genesis v0.83.0 / genesis-workflows v0.27.0 (genesis-review, 2026-11-24)

> **Status: FINAL for §1 review + §2 gates (fix pass re-reviewed 2026-11-24 at genesis `e8096f71`): SHIP.**
> Round 1 (below) was at `76b27a57`. M1 (with m2) is a known limitation by D35, no code change. §3 live rows A1–A14
> are to be run by the user (D36), after the release (D37); Phase 55's live acceptance is OPEN (L-111). See "Fix pass
> re-review" and "Verdict" at the end.

What this change does: Phase 55 adds a run-start memory brief and the memory tools to every workflow agent node, one
standard escalation gate with six confirm-gated actions and a run-bound Resolve agent in Run Detail, a categorized
Documents tab fed by per-file write records, a versioned run snapshot with `node.started` and a hint-only live stream,
status-coloured graph cards and a per-node model from the workflow files. genesis-workflows adopts the gate, the
artifact roles and the `relaunchable` flags in all 19 workflows.

Reviewed at genesis `76b27a57` (HEAD, clean, 49 commits ahead of v0.83.0) and genesis-workflows `3c29e73` (HEAD,
clean). The three commits no review had seen: genesis `419d8363` (55-04 fixes), `362f8a7a` + `a09c5fbe` (55-09's last
fix and its bundle), genesis-workflows `3c29e73` (55-10 m6, test only).

## Checklist

`genesis-ctx check --since v0.83.0 --repo genesis` (305 files) and `--since v0.27.0 --repo genesis-workflows` (64
files) list the same rule set (the workflows list is a subset). One answer per rule covers both repos unless noted.
"No change in its area" means no file the rule governs is in either diff (checked against the check's file → area
table and `git diff --stat`).

### ADRs
- [OK] ADR-001 — LangGraph owns control flow — every gate answer is routed by the graph (`escalation.py` `EscalationGate.route`/`apply`); relaunch / restart / fix are run management in `RunManager` (`manager.py:1217`, `:1270`, `:1137`); Resolve only stores proposals (`resolve_server.py:67` `propose_action`).
- [OK] ADR-002 — narrow Kiro turns over ACP with per-node MCP — the memory server is added per node through `ctx.extras["memory_mcp"]` (`agent.py` `_memory_for`, `kiro_node` servers append); no global mcp.json.
- [N/A] ADR-003 — no change to the local-app / library model.
- [OK] ADR-004 — per-node injection: `genesis-memory` is injected only on nodes of a run with a brief, `memory=False` opts out (`agent.py`, `test_agent_memory.py`).
- [N/A] ADR-005 — registry unchanged except `mcp-registry.json` untouched; the memory server is internal, not in the catalog (`worker.py` `_internal_launch_spec`).
- [OK] ADR-006 — each probe and library workflow stays a folder package; registry.json entries match (`validate_library` catalog gate, 55-10 m3).
- [N/A] ADR-007 — roles untouched.
- [N/A] ADR-008 — no change.
- [OK] ADR-009 — all three HITL modes kept: the gate still `interrupt()`s; pause/resume unchanged (L-108 path); plain fork unchanged (`manager.py:924`), restart is a separate method.
- [OK] ADR-010 — state stays small: the brief is a file, the gate payload carries pointers and short messages (`escalation.py` `payload`, `messages[:50]`); `task_start` never forwards `input` (`worker.py` `_task_start` docstring).
- [OK] ADR-011 — trio mandatory: lint F8 requires an `escalation_gate` target (`lint/reliability.py`; `probe-legacy` fails it: "escalates to 'escalate', not to an escalation_gate"); `validate_library` 0 violations.
- [OK] ADR-012 — the app reads `workflow.yaml` only (`relaunch_policy.py` docstring, `loader.meta_of`); the brief and model choice run in the worker; ruled live below (web process holds no onnxruntime, A4).
- [N/A] ADR-013 — no config UI change.
- [OK] ADR-014 — `create-workflow` scaffolds the gate, the role map and `relaunchable: false` (`cli/create_workflow.py`; 55-06 n2 test).
- [N/A] ADR-015 — no change.
- [N/A] ADR-016 — no rename.
- [OK] ADR-017 — Python only.
- [OK] ADR-018 — bulk via the blackboard: brief in `_memory/brief.md`, Resolve copies files into its sandbox, never into chat.
- [OK] ADR-019 — additive: `escalation_gate`, `ExtraOption`, `models` exports added, `hitl_gate` kept (`genesis_core/__init__.py`); `CORE_MAJOR = 1` (`types.py:12`); `NodeKind` gains `escalation_gate` only. A v0.27.0 workflow still installs and loads on the candidate (`probe-legacy` installed, A12 pending).
- [N/A] ADR-020 — no global Kiro config touched.
- [OK] ADR-021 — gates still pause only at approval/escalation/pre_mutation; story-implementation keeps its pre-mutation path (55-10); stop never writes.
- [OK] ADR-022 — run files under the artifacts root; the Resolve copy is removed by retention with the run (`config/retention.py` +7).
- [N/A] ADR-023 — no server-model change.
- [OK] ADR-024 — async nodes; blocking reads off the loop (`brief.py` `_off_loop` daemon threads, deadline).
- [OK] ADR-025 — restart forks a NEW thread and copies the folder; the original's checkpoints untouched (`manager.py` `_restart_from`, `worker.py` fork op); plain fork unchanged.
- [OK] ADR-026 — no new non-loopback bind; the candidate refused nothing new.
- [OK] ADR-027 — tokens and primitives only: no raw palette class or hex in the web diff (`git diff v0.83.0 -- web/src ':!web/src/dev'` grep: none).
- [OK] ADR-028 — every new route under `/api` (`run_routes.py`, `resolve_routes.py:53-79`); the client prepends `/api` (`lib/api/resolve.ts`, `runs.ts`).
- [OK] ADR-029 — trust = node tools ∩ allowlist; the memory server adds exactly `@genesis-memory/<six tools>` (`agent.py`, `test_agent_memory.py`).
- [OK] ADR-030 — SQLite only; no migration (`git diff --stat v0.83.0 -- genesis/db` empty; DB stays v30).
- [OK] ADR-031 — Resolve is read-only + sandboxed writes: profile `run_resolve` `auto_deny`, builtins `fs_read`/`fs_write`, no shell (`mode_profile.py` +36); trust = introspection + genesis-resolve tools only (`chat/mcp.py` `build_resolve_mcp`). Live negative control: A7 (pending).
- [OK] ADR-032 — Resolve credits are the stored per-turn usage (`chat/manager.py:600-603`, `resolve.py` `credits_of`); live A10 pending.
- [OK] ADR-033 — the agent only proposes; every action is the user's Confirm → `RunManager` (`resolve.py` `confirm`/`_apply`); `respond` refuses run operations as answers (`manager.py:661`, `:677`).
- [OK] ADR-034 — Resolve writes only under its session sandbox (`fs_write_root`); fix-and-accept reads only from `skill_output_dir/<session>` (`manager.py` `fix_and_accept`, `is_relative_to(sandbox)`).
- [OK] ADR-035 — a relaunch re-provisions uploads through `start(files=)` (`manager.py` `_reupload`).
- [N/A] ADR-036..ADR-040 — no KB, parser, managed-MCP or gws change.
- [N/A] ADR-041 — document library untouched.
- [N/A] ADR-042 — no spec authoring change.
- [N/A] ADR-043 — Lavish untouched.
- [N/A] ADR-044 — superseded; no stage-model change.
- [OK] ADR-045 — Resolve reuses the chat surface (steer, Stop, model); still read-only (`ResolveTab.tsx` steer/cancel through the session routes).
- [OK] ADR-046 — `install-packages.sh` stays the one install command; it now fetches the model (exit 0 in the image and on the copy, `evidence/55-11/gates/ci-image.txt`).
- [OK] ADR-047 — system schedules untouched; the scheduler only follows a replaced run (`scheduler.py` `_successor`).
- [N/A] ADR-048 — no credential change.
- [N/A] ADR-049 — nav unchanged (the Resolve tab is a Run Detail tab, D14).
- [OK] ADR-050 — stage status changes on rebind go through the stores' existing `reset_for_reupload` / `reset_for_rerun` paths (`api/features.py`, `api/workbench.py` bindings), as each stage's own re-run does.
- [OK] ADR-051 — the model choice goes through the provider seam (`agents/models.py choose_model(provider, …)`).
- [N/A] ADR-052 — no DocumentProvider change.
- [OK] ADR-053 — personal memories only in their brief section, the brief stays in the run folder, nothing publishes it; consolidation skips `run_resolve` chats (`memory/chat_read.py:36`).
- [OK] ADR-054 — memory.db opened read-only by the brief and the MCP (`memory/db.py ReadOnlyDatabase`); the model loads only in workers/MCP: the candidate's web process maps no onnxruntime/model file (`lsof -p 23960`: 0 matches).
- [OK] ADR-055 — no MUI; tinted cards on `*-subtle` tokens (`card-tone.ts`).
- [OK] ADR-056 — stages stay independent; a rebind resets only the bound stage.
- [N/A] ADR-057..ADR-060 — stage workflows' contents unchanged beyond the gate adoption.
- [N/A] ADR-061 — board untouched; a story rebind never moves the card (`workbench.py` docstring).
- [OK] ADR-062 — the Design lane confirm still launches; Resolve relaunch of a story run is the D23 flag (story-design true).
- [N/A] ADR-063..ADR-065 — collaboration untouched; the brief is never published (no collab file changed).
- [OK] ADR-066 — the captured prompt is the sent one, with the memory / instructions / guidance lines (`agent.py` lines appended before the capture).
- [OK] ADR-067 — `attach_healing` keeps its ladder; its exhaustion goes to the standard gate (`healing.py` `ladder_key`).
- [OK] ADR-068 — no relaunch / restart for a workflow naming `appian-dev-write` whatever its flag (`relaunch_policy.py` `write_refusal`, checked before the flag in `manager.py _new_run_refusal`); story-implementation `relaunchable: false`.
- [N/A] ADR-069 — skills provisioning unchanged.
- [N/A] ADR-070..ADR-072 — no wiki / story-page / id change.
- [N/A] ADR-073, ADR-074 — no package or sync change.
- [N/A] ADR-075, ADR-076 — no clause / CR change.
- [OK] ADR-077 — this review used `genesis-ctx pack`/`check`; no agent ran with trust-all.
- [N/A] ADR-078, ADR-079 — test-design content unchanged.
- [OK] ADR-080 — one shared version (all four still 0.83.0, bumped at 55-12); no internal dependency entry added; `fastembed==0.7.4` is external (`pyproject.toml`).
- [OK] ADR-081 — queue-managed workflows refused for relaunch/restart (`bindings.refuse`, testexec services +3 each).
- [OK] ADR-082 — story-verification stop goes through cleanup (`stop_to=`), no new environment path.
- [N/A] ADR-083 — browser-agent isolation unchanged.
- [OK] ADR-084 — story-verification `send_back` stays an extra; card moves only by its own route (55-10).
- [N/A] ADR-085 — reports origin untouched.
- [OK] ADR-086 — Resolve starts a projected agent through the same v3 path (activation verified in the SDK); no trust flag; the memory MCP and resolve server are projected tools.
- [OK] ADR-087 — schedules unchanged except following a relaunched run; system jobs still not deletable.

### Lessons
- [OK] L-001 — new MCP entries use `"env": []` lists (`worker.py _internal_launch_spec`, `chat/mcp.py _resolve_entry`).
- [OK] L-002 — `kiro_node` still builds the real options (`Options(**opt_kw, model=…)`).
- [OK] L-003 — `/live` ends after a terminal `run.final` (`run_routes.py` `run_live`).
- [OK] L-004 — SQLite only.
- [OK] L-005 — superseded for `node.started` by ADR-090 draft; the other kinds unchanged (canonical list below).
- [OK] L-006 — every adopted workflow keeps a `graph:` with the gate and `<gate>_stop` nodes (`hello-appian/workflow.yaml`).
- [N/A] L-007 — transcript fold unchanged.
- [OK] L-008 — stop reason is the run's detail; `worker_exit` rules unchanged.
- [OK] L-009 — async only; fork uses `aupdate_state`.
- [OK] L-010 — `/api` prefix central.
- [OK] L-011 — types + fixtures recorded from real responses (`web/src/test/fixtures/runs/*.json`, `phase55-contract.test.ts`).
- [N/A] L-012 — settings detail untouched.
- [OK] L-013 — new UI-only keys exempt; `relaunchable`, `memory_brief`, `models` mirrored and parity-linted (`lint/contract.py` +84).
- [OK] L-014 — jest-axe types untouched; new views use `toHaveNoViolations` (resolve, documents, liveness, node-card tests).
- [OK] L-015 — `/dev/phase-55` mockups lazy (`router.tsx`).
- [OK] L-016 — credits real (ADR-032).
- [OK] L-017 — trust in `@server/tool` form (`build_resolve_mcp`).
- [OK] L-018 — `/live` read with `readSse` (CRLF-safe, 55-03).
- [N/A] L-019 — no secret writes.
- [OK] L-020 — retries keyed by node name; the gate resets `retries[failed_node]` (`escalation.py apply`).
- [OK] L-021 — tool outputs stay files; Resolve reads them from its copy.
- [OK] L-022 — `escalation.py` uses `from __future__`, but it is genesis-core, not a workflow graph with custom reducers; the probe graphs keep their files' form.
- [OK] L-023 — the gate's `_read_json` is defensive (`escalation.py`).
- [OK] L-024 — skills untouched.
- [OK] L-025, L-027 — ruff pinned (`ruff==0.15.20`); ruff clean on genesis, genesis-core, kiro-agent-sdk.
- [N/A] L-028, L-029 — no introspection / managed-native change.
- [OK] L-030 — web files changed and `web/static` is fresh (`vite build --outDir /tmp/55-11-static-b` → `diff -r … web/static`: IDENTICAL).
- [N/A] L-031..L-032, L-035..L-040 — no KB / parser / document-sync change.
- [OK] L-033 — the library must be installed before it runs: release notes item for 55-12 (users update from Catalog).
- [OK] L-034 — graph cards back to 84 px, layout unchanged (`layout.ts` +2/−… `NODE_H`).
- [OK] L-041 — Resolve: cwd = sandbox and fs tools trusted (`run_resolve` `cwd_sandbox=True`).
- [OK] L-042 — the run's files are copied into the Resolve sandbox as files (`resolve.py _copy_run`).
- [N/A] L-043 — no SDK embed.
- [OK] L-044 — 55-13 spiked the installed CLI's model list.
- [OK] L-045 — read-only chat refined, human confirm kept (proposal cards).
- [N/A] L-046, L-047 — slash commands / MD export untouched.
- [OK] L-048 — SPA package data unchanged.
- [N/A] L-049..L-055 — no managed-MCP / sync / shipping / gws / renderer change.
- [OK] L-056 — n/a until 55-12 tags; every changed file is committed (both trees clean).
- [OK] L-057 — genesis-workflows pins still `@v0.83.0`; 55-12 moves them (its §1).
- [OK] L-058 — the escalation notifier reconciles at startup and on the bell poll (`app.py`, `notifications.py`).
- [OK] L-059 — a re-entry shows "round k" (D16).
- [OK] L-060 — node status from the snapshot, never the capped `/events`.
- [OK] L-061 — finalizers act on the currently bound run; relaunch and restart move the binding before the new worker spawns (`manager.py:1253`, `:1379`; `test_run_actions.py _spy_rebind`). See m1 for the untested failure path.
- [OK] L-062 — the binding registry generalizes the stage/story bindings (`runs/bindings.py`).
- [N/A] L-063, L-064 — no prerequisite / large-turn change.
- [OK] L-065 — `<gate>_stop` sets `failed` before END or `stop_to` (`escalation.py _make_stop`).
- [OK] L-066 — snapshot and documents fold incrementally after the last folded seq (`snapshot.py`, `documents.py FoldCache`); 55-05/55-08 changed only the shared cache.
- [OK] L-067 — layout untouched.
- [OK] L-068 — index caching untouched.
- [OK] L-069 — no `Button asChild` in the diff.
- [N/A] L-070..L-072, L-074, L-081..L-085 — no collab / board / pull change.
- [OK] L-073 — stage HTML resolution untouched.
- [OK] L-075 — the second tier escalates to the same gate.
- [OK] L-076 — no fan-out added.
- [OK] L-083 — fixtures from real runs (`tests/fixtures/documents/*.json`, ten real runs).
- [OK] L-086 — n/a to normalizer; untouched.
- [OK] L-087 — no corpus migration.
- [N/A] L-088 — no shell guard change.
- [OK] L-089 — the bundle commit `a09c5fbe` holds only `web/static` (`git show --stat`).
- [OK] L-090 — 55-09 and 55-13 probed 3 widths × 2 themes; the live width row is A9 (pending).
- [OK] L-091 — proposal supersede / stale / claim use `BEGIN IMMEDIATE` or a CAS (`chat/store.py` +68); see m3 for `respond`.
- [OK] L-092 — no `tests/__init__.py` added in the library.
- [OK] L-093 — terminal state stored before `run.final`; tests through the real `_finalize` (`test_run_actions.py`).
- [OK] L-094 — every consumer of the new kinds, `allowed`, and the bindings listed (55-08 contract table); one gap found: m2 (legacy gates).
- [N/A] L-095 — no object links.
- [OK] L-096 — `/runs/:runId/resolve` before `/runs/:runId/node/...` (`router.tsx`), `/outputs/{name:path}/download` before `/outputs/{name:path}` (`run_routes.py:394-400`), proven by behaviour (`test_phase55_api.py:496-538`).
- [OK] L-097 — the orphaned-run sweep unchanged and still under the run-owner lock.
- [OK] L-098 — no internal dependency entry.
- [OK] L-099 — no behaviour keyed on the version string; the editable dev venv effect is stated (D18, D34).
- [OK] L-100 — no CI-variables call.
- [N/A] L-101 — no npx change.
- [N/A] L-102 — no table rebuild (no migration).
- [OK] L-103 — the Resolve run copy goes with the run in retention (`retention.py`).
- [N/A] L-104, L-105 — no reaper / report change.
- [VIOLATION] L-106 — a gate's prompt is a promise — on a LEGACY escalation gate Resolve offers "Retry with guidance" and "Stop" as available, but many v0.27.0 graphs route every answer to END and the run ends `done` (m2 → **M1**). *Fix pass: accepted as a known limitation by the user's decision D35 (55-01-findings §22); not fixed, see the re-review.*
- [OK] L-107 — the brief, the model read and the notices end on every error path (`brief.py` outer `except`, `models.py` cached failed read).
- [OK] L-108 — relaunch / restart cancel through `cancel()` (stop intent + CAS) before the new run starts (`manager.py:1251`, `:1375`).
- [OK] L-109 — one reader each: `relaunch_policy.parse_relaunch`, `artifact_roles`, `node_models.parse_models`, `resolve_session_id`; parity tests per 55-05/55-08/55-13.
- [OK] L-110 — gates re-run here at the recorded HEADs, `PYTHONDONTWRITEBYTECODE=1`.
- [OK] L-111 — the release notes must list the not-run rows (below; filled at the end).
- [OK] L-112 — CI-image run done at `76b27a57` / `3c29e73` (below).
- [OK] L-113 — Resolve's projected agent goes through the SDK's activation check; no trust flag.
- [OK] L-114 — no new tool-call parsing.
- [OK] L-115 — skills front matter check unchanged.
- [OK] L-116 — the memory and resolve trust sets are tested against the real projection (`test_agent_memory.py`, `test_resolve.py` "real projection" tests).
- [OK] L-117 — Resolve's negative controls are in the unit tests; the live negative controls are A4 and A7 (pending).
- [OK] L-118 — `/live` cleanup is synchronous inside the cancelled scope (`run_routes.py` `sub.release()`); the chat turn's finally is shielded.
- [N/A] L-119 — no tarball fetch.
- [OK] L-120 — relaunch / restart / fix answer the run to follow; the scheduler follows `run.relaunched.to_run` (`scheduler.py _successor`).
- [OK] L-121 — the fork worker and edit workers never write the escalated run's status.
- [OK] L-122 — `node.started`, `file.written`, `run.relaunched`, `memory.brief`, `model.fallback` in `CANONICAL_KINDS` (`manager.py:72`), `canonical-kinds.json` and the web list; `contract.test.ts` checks all three both ways.
- [OK] L-123 — no opacity modifier on a token colour in the diff.
- [OK] L-124 — the notifier decides "gate gone" from the durable log (55-07 m1).
- [OK] L-125 — the live copy was taken with SQLite's online backup (`evidence/55-11/live/setup_db.py`), integrity ok, v30, counts equal.

### Gates (run by the reviewer)
- [OK] genesis `pytest -q -p no:warnings` (`PYTHONDONTWRITEBYTECODE=1`, HEAD `76b27a57`): **2399 passed, 4 skipped** in 901 s, EXIT=0 (`evidence/55-11/gates/genesis-pytest-local-tail.txt`).
- [OK] `ruff check genesis`, `ruff check genesis_core`, kiro-agent-sdk `ruff check .`: all clean.
- [OK] genesis-core pytest **173 passed**; kiro-agent-sdk **302 passed**; genesis-appian-parser passed (1 skipped), exit 0.
- [OK] web `npm run lint` (0 errors, 20 warnings, all `react-refresh/only-export-components` / pre-existing `exhaustive-deps` patterns), `npm run typecheck` clean, vitest **1051 passed** (86 files).
- [OK] stale bundle: fresh `vite build` equals `web/static` (IDENTICAL).
- [OK] genesis-workflows `ci/validate_library.py` PASSED (19 workflows, 0 violations), `ci/validate_skills.py` 5 passed, pytest **678 passed**.
- [OK] **CI image (L-112)**: colima arm64 `python:3.13`, git archives of `76b27a57` + `3c29e73` under `/tmp/colima/gr-55-11`, installed with `scripts/install-packages.sh --dev` **with the model** (fetched 5 files, pinned checksums, fastembed 0.7.4): validate_library / validate_skills PASSED, library **678 passed**, genesis-core **173**, kiro-agent-sdk **302**, genesis full **2343 passed, 58 skipped, 2 failed** — the two known arm64-only `test_sail_cli` tests (54-11) — and `test_document_records.py` **46 passed ×5** plus inside the full run (55-10's open failure did not recur; still no captured assertion, so 55-12 keeps its item).
- [OK] **Linux offline model load** (`docker run --network none`): control `gaierror` (no network), `LocalEmbedder BAAI/bge-small-en-v1.5`, 384-d query and documents, 1.49 s load + embed, `genesis memory status` ready; memory tests 58 passed, 1 skipped (the macOS `sandbox-exec` test) (`evidence/55-11/gates/offline.txt`).

## §1 items 1–9

1. **Memory brief — OK.** `op == "run"` only (`worker.py:306`); skipped with no agent node or `memory_brief: false`
   (`worker.py:204-209`, the two memory workflows set it); one `memory.brief` event on every path, outer catch in both
   `prefetch` and `_memory_brief` (F3); personal memories in their own section (`render_brief`), nothing published;
   header marks data; trust exactly the six tools (`agent.py`); web process loads no model (lsof); runs never download
   (`local_files_only`, Linux offline load above); consolidation skips Resolve (`chat_read.py:36`). **`419d8363`:**
   m1 (`__main__` guard moved) and m2 (re-pend before drop) and n1 (short answer) have tests
   (`test_memory_brief.py:493-545`) and pass; n2 (deadline wording) and n3 (`.part` + `os.replace`) have none — m4.
2. **Escalation — OK with findings.** Routes per action and stop → `failed` (`escalation.py apply`, `_make_stop`); an
   unknown answer stops; accept / fix refused when `allowed` gives a reason (`manager.py _check_answer`,
   `fix_and_accept`); run operations refused as answers (`:661`); audit fields on `gate.resolved` / `run.relaunched`
   / `file.written` (`_audit_fields`); relaunch cancels via `cancel()` (CAS) — no second `run.final`; instructions in
   every agent prompt and inherited by fork/restart (`_run_instructions`); restart forks, cancels, rebinds, then
   starts; lint F8; D23 one reader, default false, write guard first. **55-06 limits:** the rebind-raises path is still
   untested (m1); queue-managed refusals in place; the launch environment is still not stored (accepted, as resume).
   Legacy gates: M1. Concurrent answers: m3.
3. **Resolve chat — OK (code).** `run_resolve`: no shell, `auto_deny`, sandboxed writes, introspection + resolve
   tools only. Live negative controls: A7 (pending).
4. **Liveness — OK.** Later sub-specs changed only `snapshot.py`'s shared cache (55-05) and `run_routes.py`'s other
   routes; `node.started` canonical three ways; `/live` unchanged since 55-03. Fan-out edge counts and two `serve`
   processes: not covered by tests (stated in 55-03) — left to A2 where a fan-out exists.
5. **Documents — OK (API).** Categories by declared role, name rules only for old runs (`documents.py:62-67`); System
   paths 403 (`run_routes.py:327`); System hidden and spent tool outputs hidden in the web (55-13 tests). On four old
   runs of the real home the API returned sensible categories (e.g. technical-design `r-d5ed99071d49`: 1 output,
   1 check, 7 intermediate, 19 prompts, `legacy: true`). The page check is A8.
6. **Contracts — OK.** Fixtures from real responses; route order proven by behaviour; no migration.
7. **genesis-core — OK.** Additive; `CORE_MAJOR` 1; old library still installs and loads. **`3c29e73`** (test only):
   seeds the window's last session and asserts the cursor moves; it passes (678) — OK.
8. **Web — OK.** Tokens only, no `asChild`, jest-axe on the new views. **`362f8a7a`:** the first turn counts as
   running until an assistant message follows the last seed; the backend always appends an assistant message when a
   turn ends, even on error or cancel (`chat/manager.py:598-603`), so the composer cannot stay stuck in "steer" after a
   failed or stopped first turn. The stored-steer dedupe compares text (n1). Test added and fail-first checked.
9. **ADR drafts — OK so far.** ADR-088's As built matches `model.py` / `worker.py`; ADR-089's action set, the
   `copilot` source and D23 match `manager.py`; ADR-090 matches `snapshot.py` / `/live`. One gap to record in ADR-089
   when M1 is fixed (what Resolve offers on a legacy gate).

## Findings

### Blockers
None so far.

### Majors
- **M1 Resolve's legacy action map promises routes the old gate does not take** (`genesis/runs/manager.py:847-854`
  `gate_allowed` legacy branch; `_check_answer` legacy mapping `:670-680`). What: on an escalation gate from an older
  library (v0.27.0, the state of every installed workflow between the v0.84.0 app and the user's Catalog update, and
  of the fleet's main instance today), Resolve offers Retry with guidance, Accept and Stop as available and sends them
  as `{feedback}`, `approve`, `reject`. Problem: in v0.27.0 `hello-appian`, `code-review`, `erd-generation`,
  `ux-design-analysis` and the template the gate goes `escalate → END` for every answer (`git show
  v0.27.0:workflows/<w>/graph.py`: `add_edge("escalate", END)`), and in most others it continues to the next node, so
  "Retry with guidance" ends the run `done` without retrying and "Stop" ends it `done` with the artifact promoted —
  the 55-01 §3.1 bug, now behind Resolve's own wording (L-106). Fix (smallest): in the legacy branch, keep the gate's
  real options but label them as the old gate's answers and say the workflow decides what happens next ("this
  workflow's gate predates the standard gate: Approve / Reject / Feedback go to its own routing; update the workflow
  from Catalog for Retry and Stop"), or mark retry and stop unavailable with that reason and leave the inspector's
  GatePanel as the way to answer. Add a test on a v0.27.0-style graph (answer → route → stored status). If skipped:
  after the v0.84.0 release a user who stops a run in Resolve before updating the library gets a `done` stage. A12 /
  A14 will confirm it live on `probe-legacy` (v0.27.0 hello-appian, scratch only).

### Minors
- **m1 A relaunch or restart whose rebind raises is still untested, and it leaves the escalated run cancelled**
  (`manager.py:1251-1257`, `:1375-1383`; no test names `before_spawn` or the "could not move the" detail). Case: the
  stage row's `reset_for_reupload` raises (a busy database past its retries): the old run is already `cancelled`
  ("relaunched as r-…"), the new run is `failed` ("could not prepare the run"), no `run.relaunched` is logged and the
  stage stays bound to the cancelled run. Fix: rebind before cancelling where the order allows it (the finalizer is
  scoped to the bound run, L-061, so the old run's later `run.final` is a no-op), or keep the order and add one test
  per action that makes `rebind` raise and asserts the three records. If skipped: a rare failure leaves two dead runs
  and a stage the user must re-run by hand.
- **m2 (folded into M1).**
- **m3 `respond` is check-then-write** (`manager.py:637-646`). Case: a Resolve Confirm and a manual-menu answer (or two
  tabs) on the same gate within one request's time both read `awaiting_input:gate`, both store `running` and both spawn
  a resume worker with the answer, so the next node runs twice (two Kiro turns; for story-implementation, two passes of
  its Dev writes). Resolve's own double Confirm is safe (the proposal CAS), the cross-surface case is not. Fix: claim the
  transition with a compare-and-set (`UPDATE runs SET status='running' WHERE run_id=? AND status='awaiting_input:gate'`,
  the `claim_status` pattern, L-091) and refuse the loser with 409. If skipped: a rare double resume.
- **m4 `419d8363` n2 and n3 have no regression test** (`brief.py:418-420`, `:481-484`). Case: reverting n3 to a plain
  `write_text` passes the suite, so a kill during the write could leave a half brief that a resume reuses. Fix: one test
  that makes `os.replace` raise and asserts no `brief.md` (and no event claiming one), and one that times out
  `_describe` and asserts the event text.

### Nits
- **n1** `ResolveTab.tsx` (`storedSteers`) drops a local "sent during the turn" line when any stored steer has the same
  text, so two identical steers ("yes", "yes") show once until the session re-reads. Key by count or by the steer id.
- **n2** `.gitlab-ci.yml:15-16` says the clean-install job "fetches it the way a user's install does"; it fetches the
  model into the default state dir and then migrates a different `mktemp` state, and no CI job loads the model (the
  load test is macOS-only, `test_memory_brief.py:472`). The image run above covers this release; a Linux
  `--network none` load in CI would keep it covered.

## §3 Live acceptance (round 1 — set-up done, rows pending)

**Set-up (done, no credits, no fleet change):** `/tmp/gr-55-11/` (mode 700): `state/` = rsync of `~/.genesis` without
the databases, `genesis.db` and `memory.db` by online backup (integrity ok, v30 / mm v1, 510 runs, 302,237 events, 68
memories, equal to the source); `runs/` = rsync of `~/Genesis/runs`; candidate = a non-editable venv of `76b27a57`
(`scripts/install-packages.sh`, model fetched into the copy, **66 current memories embedded**, the 2 left out are #4
archived and #48 superseded); library = genesis-workflows `3c29e73` + three scratch probes (`probe-accept`,
`probe-norelaunch`, `probe-legacy` = hello-appian whose check also needs a key the prompt never asks for;
`evidence/55-11/live/make_fixtures.py`); all five system schedules were already off in the real home and stay off;
collaboration off (no `GENESIS_COLLAB_ENABLED`, `collab.json ui_enabled=false` on the copy); `GENESIS_API_BASE` =
`:8790` so the Resolve MCP never reaches the fleet; candidate `genesis serve` on **:8790** (reports :8890). Fleet main
:8760 and userb :8761 untouched; no fleet run was active when the copy was taken. Old runs of the copy are read only
(no action is taken on a run that existed before the copy).

| # | Result | Evidence / reason |
|---|---|---|
| A1–A14 | TO BE RUN BY THE USER (D36) | after the release (D37); A12/A14's legacy-gate checks are observations, not pass/fail (D35). The copy at `/tmp/gr-55-11/` runs a frozen candidate of `76b27a57`, which lacks the fix pass: rebuild it from the released tag (or `e8096f71`) before running the rows. |
| A4 (install step) | DONE in round 1 | install + back-fill 66/66 current memories; health "fastembed … ready" (runs, briefs and the negative control are the user's) |

## Not checked
- Every live row A1–A14 (D36: the user's, after the release, D37). Phase 55's live acceptance is open; the release
  notes, README row and `current.md` must say so (L-111).
- Fan-out edge counts and two `serve` processes on one live run (55-03 limits).
- CI-image run (L-112) of the fix pass: round 1 ran the image at `76b27a57`; the fix pass touches only
  `genesis/runs/{manager,store}.py` and two test files, with no dependency, install or platform-specific change, so I
  did not repeat it. 55-12's tag pipeline is the first CI run of `e8096f71`.
- genesis-core, kiro-agent-sdk, parser, web and genesis-workflows gates were not re-run: the fix pass changes none of
  their files (`git diff --stat 76b27a57 e8096f71`: 4 files, all under `genesis/runs/` and `tests/`).

## Fix pass re-review (2026-11-24, genesis `76b27a57..e8096f71`)

Commits: `3f391a61` (m4, test only), `e8096f71` (m1 + m3). Tree clean at `e8096f71`, local, not pushed.
`genesis-ctx check --since 76b27a57 --repo genesis`: 4 files (`genesis/runs/manager.py`, `genesis/runs/store.py` →
runs-worker; `tests/test_memory_brief.py`, `tests/test_run_actions.py`), areas release-ci, runs-worker, security; gates
pytest + `ruff check genesis`.

### Gates (re-run by the reviewer at `e8096f71`)
- [OK] `pytest -q -p no:warnings` (`PYTHONDONTWRITEBYTECODE=1`): **2406 passed, 4 skipped** in 984 s
  (`/tmp/gr-55-11-fp/full-pytest.txt`). Round 1 had 2399 + 4; +7 = the 2 m4 tests + 5 m1/m3 tests (the rebind test is
  parametrized twice). Matches the author's count.
- [OK] `ruff check genesis`: "All checks passed!"
- [OK] **Fail-first, independent (L-110):** a throwaway worktree of `e8096f71` at `/tmp/gr-55-11-fp/wt`, imported via
  `PYTHONPATH` (checked: `genesis.__file__` = the worktree), fresh `PYTHONPYCACHEPREFIX` per run, `-p no:cacheprovider`.
  With `manager.py` checked out from `76b27a57` (store.py kept): `failed_rebind[relaunch]`, `failed_rebind[restart_from]`,
  `…at_once_resume_the_run_once`, `…loses_to_a_stop_writes_nothing` FAIL (the last on "Left contains one more item …
  file.written"); `…copy_fails_gives_the_gate_back` passes (as the author says: it pins the new give-back). With
  `manager.py` at `e8096f71`: 6 passed, **5 runs in a row** (the race tests are not flaky over 5 runs). The worktree is
  removed (`git worktree list`: only the main tree).
- [OK] m4 tests pass at `e8096f71` (2 passed). Fail-first by reading, not re-mutated: with the n2 `except
  asyncio.TimeoutError` (`brief.py:418-420`) removed, the outer catch yields `"TimeoutError: "` ≠ the asserted text;
  with n3's `.part` + `os.replace` (`brief.py:482-484`) replaced by a plain `write_text`, the patched writer leaves half
  a `brief.md` and the last assert fails. The author ran both mutations.

### The rules on these files
Every ADR / lesson line of the check is answered by round 1's checklist for the same files; the fix pass changes only
the ones below. All other lines: unchanged from round 1 (OK or N/A with the same evidence; no file of their area
changed).
- [OK] ADR-009 — gate answers, pause/resume and fork keep their paths; respond still `interrupt`-resumes through the
  worker (`manager.py:661-664` `_resume_gate` → `_spawn op=resume`).
- [OK] ADR-025 — restart still forks first; the fork is failed, the original untouched, when the rebind fails
  (`manager.py:1404-1414`).
- [OK] ADR-030 — `claim_transition` is one parameterized `UPDATE … WHERE run_id=? AND status=?` in the store
  (`store.py:157-165`), raw SQL stays in the store layer.
- [OK] ADR-033 — Resolve still only confirms; a losing confirm is marked `stale` through the existing
  `RunStateError` handler (`chat/resolve.py:639-640`); the route maps it to 409 (`run_routes.py:226`).
- [OK] L-061 — the binding moves before the old run's `run.final{cancelled}`, so the finalizer of the old run sees the
  stage bound elsewhere (`manager.py:1273-1282`, `:1404-1416`); a failed move keeps the stage on the old run
  (test asserts `stages.get(sid)["run_id"] == old`). One partial case remains: see m5.
- [OK] L-091 — the write lock is taken first: the CAS is the claim, before `gate.resolved` and the spawn
  (`manager.py:644-653`); `fix_and_accept` claims before the copy (`:1200-1203`) and gives back with a CAS (`:1210`).
- [OK] L-093 — terminal state stored before its event is unchanged; the old run's later `run.final` is the one
  `cancel` announces after its CAS (`manager.py:594-608`).
- [OK] L-107 — every error path of the new code ends: rebind failure → new run `_finalize(FAILED)` + audit + re-raise
  (`start` `:522-527`, restart `:1409-1414`); copy failure → give-back + `RunActionError`. One path after the claim
  does not give back: nit n4.
- [OK] L-108 — cancel still goes through `_intend_stop` + `_claim_status` CAS; moving it inside `before_spawn` keeps
  "stop recorded before kill" (`manager.py:599-603`); `cancel` does not raise on a failed write (`_claim_status`
  `:347-360`), so a failed cancel cannot fail the already-rebound new run.
- [OK] L-110 — gates and fail-first re-run here at the recorded head, fresh pycache, worktree import proven.
- [OK] L-120 — relaunch still returns the new id and logs `run.relaunched` only on success (test asserts no
  `run.relaunched` on the failed path).
- [OK] L-121 — the fork worker never writes the old run's status; a failed fork or rebind fails only the fork.
- [N/A] ADR-026, 028, 082–086 and the security-area lessons (L-017, L-044, L-045, L-105, L-113, L-116, L-117) — no
  route, trust, browser or Kiro-launch code changed.
- [OK] Release-ci lines (L-056, L-057, L-112 …) — nothing tagged; both commits contain their implementation and tests
  together (`git show --stat`); the pins move in 55-12.

### Round-1 findings, re-judged
- **M1 (and m2) — NOT FIXED, accepted by D35 (known limitation).** No code change, as decided. Conditions the release
  must meet (from D35, carried here so 55-12 cannot drop them): the release notes tell the user to answer an escalation
  of a run started on an older workflow from the Flow tab's gate panel, not Resolve; 55-12 updates every workflow from
  Catalog right after the library release; ADR-089's As built records what Resolve offers on a legacy gate. The L-106
  line stays a VIOLATION accepted by the user, not an OK.
- **m1 — FIXED.** `_relaunch`'s `before_spawn` now rebinds, then cancels (`manager.py:1273-1282`); `start` fails the
  new run and re-raises when it raises (`:522-527`). `_restart_from` order is fork → rebind → cancel → start
  (`:1404-1420`), and the failed rebind writes the error audit (`:1412-1413`), which round 1's code did only for a
  failed fork. Test `test_a_failed_rebind_fails_only_the_new_run_and_the_escalated_run_still_waits_bound[relaunch|
  restart_from]` asserts the old run's status, detail, no `run.final`, no `run.relaunched`, the stage still on the old
  run, one failed new run with the right detail, `_replacing` cleared, and that the old run can still be answered and
  ends `done`. Fail-first confirmed.
  *Side effect checked:* an answer that arrives between the rebind and the cancel (respond does not take
  `_replace_lock`) can now resume the old run for a moment before `cancel` kills it; round 1's order refused that
  answer instead. The window is one stage-row write; `cancel` handles a running run (kill + CAS + one `run.final`), and
  write workflows are never relaunchable (ADR-068, `write_refusal`), so no Appian write can run in it. Not a finding.
- **m3 — FIXED.** `RunStore.claim_transition` (`store.py:157-165`, `retry_when_busy`, one CAS). `respond` validates,
  claims, then `_resume_gate` logs, spawns and audits (`manager.py:640-664`); the loser gets `RunStateError` with
  nothing logged or spawned. `fix_and_accept` validates the accept with `_check_answer` and claims BEFORE the copy
  (`:1200-1203`), gives the gate back by CAS on a failed copy (`:1210`), and resumes through `_resume_gate` with
  `session_id=None` (`:1220`), the same single `copilot_actions` row as round 1. Tests race two threads through a
  barrier on `pending_gate` (the read-validate window) and assert one `gate.resolved`, one resume spawn equal to the
  logged decision, one `run.final`, and that a losing fix wrote no file and no `file.written`. Fail-first confirmed;
  5/5 stable. The give-back test pins `awaiting_input:gate`, no `gate.resolved`, and a later accept ending `done`.
- **m4 — FIXED.** `test_a_slow_run_description_is_the_deadline_error` and
  `test_a_brief_cut_off_while_it_is_written_leaves_no_brief` (`tests/test_memory_brief.py:324-359`) cover n2 and n3 as
  asked; they use the real `describe_run` and a writer that writes half and raises ENOSPC.

### New findings (fix pass)

#### Blockers
None.

#### Majors
None.

#### Minors
- **m5 The stage / story rebind is two writes, so a failure between them leaves a stage with no run, and the
  escalated run unbound** (`api/features.py:301-304` `reset_for_reupload` then `set_source`; `api/workbench.py:91-93`
  `reset_for_rerun` then `set_source`). Pre-existing at `76b27a57` (the author's known limit 1); m1's new order changes
  what it leaves behind. Case: `reset_for_reupload` commits, `set_source` raises `database is locked` past its retries.
  The new run is failed (correct), the old run is still waiting (correct), but the stage is now "in progress" with
  `run_id` NULL. If the user then answers the old run from the gate panel and it ends `done`, its finalizer finds no
  bound stage (L-061) and the stage never gets the result; the stage reads "in progress" with nothing running. m1's
  test makes the first write fail, so it does not cover this. Smallest fix: give each stage store one method that does
  the reset and the `run_id` write in one `tx()`, and call it from both `rebind`s; one test that fails the second
  write and asserts the stage still points at the old run. Not blocking: it needs a busy database between two
  consecutive local writes, and the user can re-run the stage. Backlog (`phase-55-follow-ups`).
- **m6 `RunManager.resume` on a gate-waiting run writes `running` without a CAS** (`manager.py:620-623`). Pre-existing,
  outside m3's scope (the author's known limit 2). Case: `POST /api/runs/{id}/resume` (API, CLI or the copilot's run
  control) while a gate answer is applied: two resume workers on one thread. The web never offers Resume on a gated run
  (`HitlBar.tsx:181-205`: Resume only when `paused`), so no UI path hits it. Smallest fix: `resume` refuses
  `awaiting_input:gate` with 409 ("answer the gate") or claims `paused → running` with `claim_transition`. Backlog.

#### Nits
- **n1, n2** from round 1: not touched, still open (as the author says). Backlog.
- **n3 (new)** The n3 test cuts the write inside `brief.md.part`, and `prefetch` leaves that half `.part` file in
  `_memory/` (`brief.py:482-484` has no cleanup on error). It is harmless (nothing reads `*.part`, and `_memory/` is a
  System folder) but it is a stray file. `part.unlink(missing_ok=True)` in an `except` would match
  `fix_and_accept`'s own pattern.
- **n4 (new)** In `fix_and_accept`, only a failed copy gives the gate back. After the claim, a failure of
  `target.stat()` or the `file.written` append (`manager.py:1212-1216`) leaves the run `running` with no worker until
  the startup orphan sweep fails it; round 1's code left it waiting at the gate in that case. Same for `respond` if the
  `gate.resolved` append fails after the claim. Very rare (the event log write retries a busy database); widening the
  give-back `try` to cover everything up to `_spawn` would close it.

## Verdict: SHIP (§1 review + §2 gates, at genesis `e8096f71` / genesis-workflows `3c29e73`)

m1, m3 and m4 are fixed with regression tests whose fail-first I reproduced independently; the full genesis suite
(2406 passed, 4 skipped) and ruff are green at `e8096f71`; the other repos' gates stand from round 1 (no file of theirs
changed). M1 (with m2) ships as a known limitation by the user's decision D35, with the release-note and ADR-089
conditions above. The new minors m5 and m6 are pre-existing, narrow and have no UI path or need a database failure
between two local writes; they go to the backlog with n1–n4.

This SHIP does **not** cover live acceptance: §3 rows A1–A14 are to be run by the user after the release (D36, D37).
Per L-111, 55-12's release notes, the README row and `context/state/current.md` must say plainly that Phase 55's live
acceptance is open, and the umbrella status reads `SHIPPED (live acceptance open)`. The `/tmp/gr-55-11/` candidate is
at `76b27a57`; rebuild it from the release before running the rows.
