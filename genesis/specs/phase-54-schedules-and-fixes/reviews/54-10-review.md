# Review 54-10 — whole Phase 54, genesis `ea00dfd..2ad1c50`, genesis-workflows `d0c0f53..7b35f8a` (genesis-review, 2026-11-20)

**Round 1 (interim: live rows that need the user's go-ahead are still open, see §3).**

**The user's answers in this session (recorded in `54-01-findings.md` §8):**
- **D47, live-acceptance permissions.**
  - Yes: start colima for the `python:3.13` run (L-112); a QA regression run (A4, and A8's red-regression part); the
    application-sync Run now (A9; Dev export plus a `genesis-delta-*` package, ADR-073); a real `story-design-analysis`
    re-run on story 74 (A14).
  - No: any `story-implementation` run.
  - No v0.82.0 server: A13's "reproduced on v0.82.0 first" half is satisfied by 54-02's fail-first tests.
- **D48:** all three older HTML paths (M1) are fixed in this pass.
- **D49:** B1 is in this release.
- **D50, the A1 verdict:** every surface matches the approved mockup except the six changes in 54-12 §2:
  1. Schedules filters and search reuse the Runs page's pills and search box.
  2. The Schedules grid uses the Runs table style, without the line above it.
  3. The whole row is clickable.
  4. Read notifications can be removed, and the bell has Clear read.
  5. The application-sync Sync options card has no Edit button.
  6. Catalog → Agents gets a search box.
- The fixes for round 1 and D50 are sub-spec **54-12** (`54-12-review-fixes.md`), which genesis-dev is building. This
  review re-runs per 54-12 §5.

What this change does: Phase 54 replaces the fixed scheduled jobs with one schedule model (m0030, DB v30). It adds a
scheduler engine with missed, overlap, gate, time-limit and auto-pause rules, user schedules for workflows, agent
prompts and regression suites, custom agents, an `agent-prompt` workflow, a read-only chat with a custom agent and the
notification bell. It also revamps the story and feature pages and ships the 54-02 fixes (paused-run edit, artifact
events, failed captures, environment labels, `/api` 404).

Inputs read: the 54-10 spec, the As built and "Found, not fixed" / "For 54-10" notes of 54-02..54-09, `54-01-findings.md`
§8 (D1–D46, plus D48 from the user in this session) and `adr-drafts.md`. `genesis-ctx check --since ea00dfd --repo genesis` (305
files) and `--since d0c0f53 --repo genesis-workflows` (10 files). HEADs resolved: genesis `2ad1c50`, genesis-workflows
`7b35f8a`; both trees clean.

## §1 Independent review

1. **Unattended trust (D2, D3). OK, with finding m2.** The rule has one home,
   `packages/genesis-core/genesis_core/mcp/pickable.py:23-34` (`PICKABLE_CURATED`, `NOT_PICKABLE_CURATED`). The node's
   built-ins are `NODE_BUILTINS` (`genesis_core/nodes/agent.py:37`), and `delete_file` is not among them. MCP trust is
   `_node_mcp_trust` (`agent.py:172-210`), fed by the per-run `mcp_names` (`agent.py:350-352`, `:397`). The rule is
   checked at:
   - create and update: `api/schedule_routes.py:196-210` (`_check_agent_prompt`); the agent store,
     `agents/store.py:282`;
   - fire: `agents/prompt_inputs.py:37,43`;
   - node start: `genesis-workflows/workflows/agent-prompt/graph.py` `checked_server_names` on the worker's own registry;
   - chat: `chat/custom_agent.py:98,123`.
   
   `test_every_curated_server_is_classified` and `test_the_pickable_curated_servers_are_read_only_with_an_allowlist`
   (agent-prompt `tests/test_workflow.py:171-187`) cover all 9 curated names and refuse the six servers. Live: a
   hand-launched run naming `appian-dev-write` failed before any turn with the D3 reason and no credits
   (`r-b9cf32cf2dfc`). **Gap (m2):** a *workflow*-type schedule can target `agent-prompt` and skips D3 at save.
2. **Chat (D6, ADR-031/034). OK.** `chat/manager.py` `_ensure_started` adds the agent only when
   `profile.takes_custom_agent` (only `read_only`, `mode_profile.py:277`). Picks are re-checked and capped to their
   allowlists, and a server with no allowlist is left out (`custom_agent.py:84-112`). `builtins=()` means no shell, and
   writes go only to `fs_write_root=skill_out`. Other modes refuse an agent: `create_session` and `set_session_mode`
   (`manager.py:822-827`, `:968-970`). Activation is verified (L-113): the probe re-ran PASS, including its negative
   control (§3 A11).
3. **Engine rules (D8, D10, D12, D30, D31). OK in the code, VIOLATED live (B1).**
   - Cancels go through `RunManager.cancel` / `TestExecutionService.cancel` (`runtime/scheduler.py:396-410`).
   - `_fire` closes the row in `finally` (`scheduler.py:224-266`); a failed close is recovered by the next tick's
     `_follow` (`:331-335`).
   - Ticks and Run now need the owner lock (`:176-177`, `:199-200`, `api/app.py:309`).
   - **`9a365c0` is right for the path it fixes** (`schedule_store.py:394-398`, test
     `test_review_rerun2_m3_a_past_once_cannot_be_turned_on`), **but Resume is a second path to the same bug (m1,
     reproduced).**
   - Live, the rules held whenever no run blocked the database (A5–A8 below). While one did, a fire was lost, a
     hand-paused run was cancelled as "timed out", and slots were recorded "missed" while Genesis ran (B1).
   - Also found: idle time is lost when a run ends between two ticks (m3).
4. **Migration (L-081, L-102, L-103). OK.**
   - `db/migrations/m0030_schedules.py` is additive and guarded (no table rebuild, so L-102 does not apply).
   - System rows keep `schedule_json`, `options_json`, `enabled` and `user_modified`
     (`test_m0030_keeps_every_system_row_as_the_user_left_it_and_adds_the_default_policy`). On the user's real data
     (copy) `application-sync` kept its edited schedule and `user_modified=1` (`evidence/54-10/schedules-before-after.json`).
   - Regression entries become rows once (`test_m0030_turns_each_on_regression_entry_into_its_own_row_and_retires_the_dispatcher`).
     The real home's single entry has cadence `off`, so no row was created, which is correct.
   - `regression-run` is never re-created (`schedule_store.py:40` `RETIRED_JOB_KEYS`, `:294`;
     `test_after_m0030_a_boot_keeps_the_users_app_sync_and_never_brings_the_dispatcher_back`).
   - Deleting a schedule removes its `schedule_runs` rows in the same transaction (`schedule_store.py:418-427`,
     `test_delete_user_removes_its_slot_history_in_the_same_transaction`).
   - **In-place edits D36/D37 (`9895cdb`) and B1 idle columns (`e45a042`):** acceptable only while no database has
     applied m0030. **Fleet check:** the fleet is *not running*. No process listens on :8760 or :8761, and
     `ps -ww -eo pid,lstart,command` lists no `genesis serve` (the machine rebooted at 01:15 IST on 2026-11-20).
     Both fleet databases, opened read-only (`?immutable=1`), are at `max(version)=29` (applied 2026-11-14). m0030
     first landed 2026-11-18 18:48 (`41d4d0e`). **Risk:** the fleet's `genesis_bin` is the editable dev venv, so any
     `gsm` start now applies HEAD's m0030 to the real databases before the release. D36's condition then breaks.
5. **Credits (ADR-032). OK.** History credits come only from `eventlog.aggregate_credits` / `credits_provenance`
   (`schedule_routes.py:425-441`). Live: A2's row shows 0.2607 `metered`; probe rows show `unavailable` (no agent turn).
6. **Contracts (54-06). OK.**
   - Golden fixtures come from real responses (54-06 As built; `test_schedules_api.py`).
   - Removed endpoints have no code consumer. `git grep` for `sync-settings|/system/schedules|testing/schedule|regression_job|ScheduleSection|ApplicationSyncSection|syncSchedule|update_settings|list_jobs|mark_fired|due_slot`
     finds only `docs/architecture/**`, which is the known genesis-docs hand-off.
   - Route order (L-096): static schedule paths are registered first (`schedule_routes.py:257`), and ids use
     `{schedule_id:int}`. Live, `DELETE /api/schedules/pickable` answers 405 and an unknown `/api` path answers 404 JSON.
7. **Fixes (54-02). OK.** Each fix has a failing-first test (54-02 As built and review). Live on the release candidate
   (A13): B1 edits keep the status with no `run.final`; B2's old custom rows fold (`r-65ab19fae948` shows its 2
   artifacts); O1 discarded the real failed compose capture #3; O4 handled a URL label.
8. **genesis-core (ADR-019). OK.**
   - The change is additive: `kiro_node` accepts callables and its defaults are unchanged (`agent.py:273-306`);
     `from_layers(override=True)` is the default (`registry.py:55-69`).
   - `CORE_MAJOR = 1` (`genesis_core/types.py:12`).
   - Existing workflows pass unchanged: genesis-workflows pytest 463 passed.
9. **Web. OK.** No `Button asChild` (the only hits are comments and Radix `DialogClose asChild`). The added lines of 72
   changed `.ts/.tsx` files have no raw palette, hex or opacity modifiers. jest-axe runs on the schedules, agents, bell,
   chat-agent, story, features and shared-ui tests. tsc is green, so no removed component is still imported.
9b. **Agent-written HTML on the app's origin: 3 paths open (M1; scope A = D48: all three go into this fix pass).**

| Route (file:line) | Content | How the UI shows it | Protection today (live headers on :8790) |
|---|---|---|---|
| `GET /workbench/boards/{app}/cards/{story}/design/artifact?annotate=0` (`api/workbench.py:321-338`) | story design (agent) | Design tab frame `sandbox="allow-same-origin"` (`StoryWorkspacePage.tsx:279-281`); "Open in new tab" (`:300`) | **CSP `script-src 'none'; object-src 'none'` + nosniff** ✔ |
| same, `annotate=1` (`workbench.py:330-333`) | design + Lavish SDK | `AnnotatablePreviewDialog` `sandbox="allow-scripts"` (opaque origin, `AnnotatablePreviewDialog.tsx:113-119`) | no CSP; sandboxed frame only ✔ (no UI opens it top-level) |
| `GET /applications/{app}/stories/{id}/verification/report` (`workbench.py:512-524`) | Genesis's own report | frame `sandbox="allow-popups …"` (`VerificationSection.tsx:246-247`); new tab (`:178,:203`) | **CSP + nosniff** ✔ |
| Implementation report: no route; `report_html` in JSON | agent report | `srcDoc` frame `sandbox=""` (`StoryWorkspacePage.tsx:518`) | no scripts ✔ |
| `GET /runs/{id}/artifacts/{name}` and `/download` (`run_routes.py:239-261`); chat outputs (`:297-318`) | run docs | JSON text preview (code/markdown; react-markdown without raw HTML; mermaid `securityLevel:"strict"`); `.html` downloads as `application/octet-stream` (`_shared.py:17-36`), attachment | ✔ |
| `GET /features/{id}/stages/{stage}/artifact` (`api/features.py:1530-1544`) | stage artifacts (agent) | previews `sandbox="allow-scripts"` ✔ — **but `PulledStageView` frames it with NO sandbox and `annotate=1`** (`StageBuilderPage.tsx:160-161`) | **none** ✘: a teammate's pulled HTML runs scripts on this machine's origin |
| `GET /features/{id}/change-requests/{cr}/document` (`api/change_requests.py:96-105`) | CR impact analysis (chat-drafted) | frames `allow-scripts` ✔ — **opened top-level in a new tab** by `SpecChangedBanner.tsx:34`, `StoryTraceCards.tsx:21` | **none** ✘ |
| `GET /features/{id}/spec/artifact?annotate=0#clause` (`api/features.py:696-716`) | spec (agent) | frames `allow-scripts` ✔ — **opened top-level** by `StoryTraceCards.tsx:133` (`specClauseUrl`) | **none** ✘ |
| reports origin (`testexec/reports_origin.py`) | Playwright reports | second loopback origin (ADR-085) | nosniff ✔ |

10. **ADR draft. OK, with one nit.** `adr-drafts.md` matches the build. The navigation is
    `web/src/shared/layout/nav.ts:15-27`: Home · Workbench · Chat · Runs · Schedules · Catalog · Documents · Memory,
    with Settings pinned. The five system keys are `sync_jobs.py:47,59,65` and `memory_jobs.py:31,36`, and D43 is in
    clause 4. Nit: the draft states neither D30 (red regression runs don't count toward the pause) nor D31 (gate and
    paused time don't count toward the time limit), though both are in the code (genesis-docs can add a clause).

## Checklist

### ADRs (genesis check)
- [OK] ADR-001 — the agent-prompt graph is LangGraph-owned (`graph.py` `build`); chat orchestrates nothing.
- [OK] ADR-002/004/020 — per-node MCP over ACP from `ctx.mcp.acp_servers(mcp_names)` (`agent.py:362`); no global `mcp.json`.
- [N/A] ADR-003, 008, 013, 015, 016, 017, 023, 024, 025, 030, 035, 036, 037, 038, 039, 040, 041, 042, 044, 046, 048,
  050, 051, 052, 053, 054, 056, 057, 058, 059, 060, 062, 063, 064, 066, 067, 070, 072, 074, 075, 076, 078, 079, 080,
  081 — not touched in a way the rule governs (no change to those subsystems' contracts; the feature-activity read in
  ADR-050's area writes nothing, `services/feature_activity.py`).
- [OK] ADR-005/029 — two tiers kept; the worker loads custom-only names with `override=False` (`registry.py:55-69`, `runs/worker.py:94-104`); trust = node tools ∩ allowlist (`agent.py:172-210`).
- [OK] ADR-006/007/014/019 — `agent-prompt` is a folder package in `registry.json`; `schedulable` is a META key mirrored in yaml (parity lint, `lint/contract.py`); validate_library 19 passed.
- [OK] ADR-009 — all three HITL modes still work live: approve/feedback/reject at the escalation gate, pause and resume, and a state edit (A10b, A13).
- [OK] ADR-010/018/022 — the run inputs carry pointers and a small snapshot; `output.md` lives in the run folder.
- [OK] ADR-011 — `agent-prompt` has validator `validate_output` + retry 2 + escalation (`graph.py` `attach_reliability`); reliability lint green.
- [OK] ADR-012 — the node re-checks D3 from genesis-core inside the worker; the app never imports workflow code.
- [OK] ADR-021 — no write-capable server can reach the agent-prompt node (D3), so it is not a mutating node and needs no `pre_mutation` gate.
- [OK] ADR-026 — no new listener; the release candidate bound 127.0.0.1 only.
- [OK] ADR-027/055 — shared primitives (`RowMenu`, `TimeInput`, `MultiSelect`, `SectionCard`, `StatGrid`); tokens only (grep above).
- [OK] ADR-028 — every new route is under `/api`; the web client prepends it (`lib/api/*`).
- [OK] ADR-031/033/034/045 — the custom-agent chat is read-only with sandboxed writes; Copilot is hidden and refused with an agent (D26).
- [OK] ADR-032 — §1.5.
- [VIOLATION→M1] ADR-043 — Lavish SDK frames must be sandboxed (postMessage host); `PulledStageView` frames the annotated artifact unsandboxed (`StageBuilderPage.tsx:160-161`). Predates Phase 54 (`64d26a38`, v0.66.4); in scope per D48.
- [OK] ADR-047 (amended by the ADR-087 draft) — system rows stay backend-defined, not deletable (`ScheduleForbidden`, `schedule_store.py:421-422`), editable on Schedules.
- [OK] ADR-049 (amended by the draft) — §1.10.
- [OK] ADR-061/071/084 — the story page is still the one canonical page; the lanes are unchanged; the design re-run is gated by lane (`StoryWorkspacePage`, live: disabled in Code Review with its reason).
- [OK] ADR-065 — collaboration off on the copy by both gates (env unset, `ui_enabled` false); `/api/collab/status` → `{"enabled":false}`.
- [OK] ADR-068/073 — `appian-dev-write` and `appian-dev-packages` are never pickable (`pickable.py:28-29`); live refusal `r-b9cf32cf2dfc`.
- [OK] ADR-069 — skills are provisioned into the run's `.kiro/skills/` (live `skills.provisioned` event, A2).
- [OK] ADR-077 — reviewer launched without `--trust-all-tools`; pack and check used.
- [OK] ADR-082/083 — no new browser-agent path; regression runs still go through `TestExecutionService` on QA.
- [OK] ADR-085 — reports origin unchanged.
- [OK] ADR-086 — agent-prompt and chat agents are projected under Genesis-owned `KIRO_HOME` (`<run>/_kiro/`), activation verified (probe PASS).

### ADRs (genesis-workflows check)
- [OK] ADR-001, 005, 006, 011, 012, 019, 021, 029, 069, 073, 086 — as above.
- [N/A] the rest of that list — the 10 changed files are `agent-prompt` plus `schedulable: true` / patch bumps on
  `sync-documents`, `generate-business-map`, `hello-appian`; no other contract changes.

### Lessons
- [OK] L-001/002 — `kiro_node` still builds the real options; env list form untouched.
- [OK] L-005 — the new kinds are canonical (`artifact.saved`, `tool_output.recorded`); `agent.prompt` joins the web lists (54-06).
- [OK] L-006/013 — agent-prompt yaml `graph:` node ids = graph names.
- [VIOLATION→B1] L-026 — a blocking program node holds the checkpointer's write lock (the lesson's mechanism, generalized from writes to any blocking call); live evidence below.
- [OK] L-011 — contract tests over recorded fixtures (`schedules/*`, `agents/*`, `feature-activity.json`).
- [OK] L-014/015 — jest-axe types untouched; the mockups chunk is lazy (`router.tsx:40`).
- [OK] L-016/032 — §1.5.
- [OK] L-017/116 — chat allowlists are `@server/tool` from `registry.allowlist` (`custom_agent.py:108`); tested on the real registry.
- [OK] L-020/022 — agent-prompt has no custom reducer and no `from __future__`; a three-attempt loop stays well inside the recursion limit.
- [OK] L-025/027 — ruff 0.15.20 pinned; clean in all three packages.
- [OK] L-033 — a missing `agent-prompt` → 409 on Run (`custom_agents.py:136-138`) and `skipped` on fire (`schedule_targets.py:101-102`, live A8).
- [OK] L-039 — every stage-row read carries `run_status` (54-09 m1).
- [OK] L-065 — `give_up` sets `failed` (live reject → failed, `r-18e936364770`).
- [OK] L-068 — the SPA shell is still no-cache (54-02 tests).
- [OK] L-069 — no `Button asChild`.
- [OK] L-081 — §1.4.
- [OK] L-089 — the bundle check ran after the build exited (`diff -r` IDENTICAL). (I broke this rule twice in live
  set-up, sending a wait and a server start in one message. Each time I noticed it, redid the step, and did not count the bad attempt as evidence.)
- [VIOLATION→M2, m6] L-090 — real-data geometry: Objects-changed type overlaps Action at all widths; app-sync headers wrap.
- [OK] L-091 — store writes validate under `BEGIN IMMEDIATE` (`schedule_store.py` `update`, agents `update`).
- [OK] L-094 — §1.6 consumer grep.
- [OK] L-096 — §1.6.
- [OK] L-097 — §1.3.
- [N/A] L-102 — no table rebuild.
- [OK] L-103 — §1.4.
- [OK] L-104 — A16 (no stray processes).
- [OK] L-106 — the agent-prompt gate prompt names all three routes and Feedback really re-runs with the note (live A10b).
- [OK in code / VIOLATED live via B1] L-107 — every handler path closes its row, but a close blocked by the lock leaves
  the row to the next tick, which records "interrupted" and loses the fire (A2 first attempt).
- [VIOLATION→m5] L-108 — pause's status write can fail (`manager.py:196-200` returns True on error), leaving a killed run "running"; the scheduler then cancelled it as timed out (#12).
- [OK] L-109 — one D3 home, one prompt-input builder, one `counts_toward_pause` reader.
- [OK] L-110 — every gate result below was run here at the recorded HEADs.
- [OK] L-111 — the not-run rows are named below for 54-11.
- [OPEN] L-112 — no `python:3.13` run yet (Docker/colima down; asked the user).
- [OK] L-113/117 — the probe used the product projection plus a negative control that must fail; PASS.
- [OK] L-114/115/118/119 — untouched in this phase (no SDK wire change, front matter checked by the existing provisioner, no SSE change, no tarball change).
- [N/A] L-003, 004, 007–010, 012, 018, 019, 021, 023, 024, 028–031, 034–038, 040–064, 066, 067, 070–080, 082–088,
  092, 093, 095, 098–101, 105 — areas not changed in a way the lesson governs.

### Gates (run by me, 2026-11-20)
- [OK] genesis `pytest -q -p no:warnings`: **2095 passed** in 717 s, 11:31:19–11:43:18 IST (outside 00:00–02:00; nothing deselected).
- [OK] genesis `ruff check genesis`; genesis-core `ruff check genesis_core`; kiro-agent-sdk `ruff check .`: all clean (ruff 0.15.20).
- [OK] genesis-core pytest **120 passed**; kiro-agent-sdk **302 passed**; genesis-appian-parser all passed + 1 skipped.
- [OK] web `npm run lint`: 0 errors, 20 warnings (all in lines older than this phase, checked with `git blame`); `npm run typecheck` clean; `npm test` **897 passed (81 files)**.
- [OK] Bundle: `npx --no-install vite build --outDir /tmp/54-10-static-a` then `diff -r … web/static` → IDENTICAL.
- [OK] genesis-workflows `ci/validate_library.py` PASSED (19); `ci/validate_skills.py` PASSED (5); pytest **463 passed**.
- [OPEN] One run in `python:3.13` or a CI branch run (L-112): **not run yet.** Docker is down (colima stopped), and a CI branch run needs a push, which I may not do. D47 allows colima, so I will run it on the 54-12 HEAD at the re-review.

## §3 Live acceptance (release candidate `2ad1c50` on a copy of the real home, D46)

**Set-up (D46), in order, before any row:**
1. **Copy:** `/tmp/g5410` (mode 700).
   - `genesis.db` and `memory.db` were taken with `sqlite3 <db> ".backup …"`; the rest of `~/.genesis` was copied as
     files (`run/` left out), and `~/Genesis/runs` went to `/tmp/g5410/artifacts`.
   - The fleet was already down, so nothing wrote during the copy.
   - What the copy did to the real home: macOS's `sqlite3` left an empty `-wal` and a `-shm` beside the real
     databases. The database files themselves are unchanged (mtime 01:13).
   - The copy's `genesis.db` held 1,592 absolute paths into the real home and artifacts root, in 13 tables (story/stage
     `html_path`, `runs.artifacts_dir`, …). I rewrote them to the copy (`/tmp/54-10-probe/paths_survey.py --apply`).
     Without this, a design re-run on the copy would have written into the real `~/.genesis`. The checkpoint blobs keep
     the old paths, so no old run was resumed or forked.
2. **Before the first tick:** m0030 was applied offline (`premigrate.py`; v29 → v30). Every `scheduled_jobs` row was
   turned off, and the system rows were set `user_modified=1` so `ensure_defaults` cannot adopt a default `enabled`.
   Collaboration is off by both gates (env unset, copy `collab.json` `ui_enabled:false`).
3. **Release candidate:** `/tmp/g5410/serve.sh`, `127.0.0.1:8790` (reports :8890), with
   `GENESIS_STATE_DIR`/`GENESIS_ARTIFACTS_DIR` on the copy and `GENESIS_API_BASE` on :8790. `/openapi.json` reports
   0.82.0 (the bump is 54-11's job).
4. **Installed on the copy:** `agent-prompt`, `sync-documents`, `generate-business-map`, `hello-appian` from local
   genesis-workflows `7b35f8a`. Also `probe-54-10`, a zero-credit program-only fixture written under `/tmp/g5410-lib`
   (not in any repo; mode ok, fail, gate or sleep).

The fleet (:8760/:8761) was never started or touched. The copy's files are not in the evidence. Credits spent so far:
**≈ 1.03** (agent-prompt runs 0.4836, chats 0.5513; all metered).

Evidence: `specs/phase-54-schedules-and-fixes/evidence/54-10/`.

| # | Result | Evidence |
|---|---|---|
| A1 | **User verdict D50: matches the mockup except six changes**, now 54-12 §2. Re-check those six after 54-12 | — |
| A2 | **FAIL first, then PASS.** 1st attempt (#7, 12:02) lost to B1: the run never started (`database is locked`), and the row was closed "interrupted". 2nd (#23): fired at 12:38, `output.md` "KB explorer says: …" (instructions applied), skill `appian` provisioned, only `genesis-kb` projected, history `ok` 0.2607 metered, output.md listed in the run's documents. Repeat with `appian-dev` (Dev up): `r-0dc9e335e902` listed Dev apps, 0.0612 metered | `b1-lockwatch.txt`, `schedules-final.txt` |
| A3 | **PASS.** `sync-documents` {scope: library}, every 1 h 09:00–18:00 weekdays. Run now → `ok`. Runs list badge "Scheduled: A3 sync documents hourly" → `/schedules/28`, also on Run Detail | `a3-runs-badges.png` |
| A4 | **not run yet: waiting on the user's go-ahead (QA run).** The real home has no migrated regression row (its only entry was `off`) | — |
| A5 | **PASS** (after redoing it, see the L-089 note). Stop 12:24:42 → start 12:29: #20 one catch-up run, #21 one run + one `missed` row + one bell notice. A `once` beyond grace (#19, simulated by moving its slot back while serve was down) → `missed` + completed + notice | `schedules-final.txt` |
| A6 | **PASS.** #15: the run was paused by hand at its gate; slot 12:15 → `skipped` "previous run still active". **But with a long-running (blocking) run instead, the skip write itself failed (B1)** | `schedules-final.txt` |
| A7 | **Partly PASS, part FAIL.** #14: needs-you notice, then cancelled at the next slot, `failed` "gate not answered", one terminal `run.final` (the earlier `awaiting_input:gate` final is the normal gate pause). #16: waited at its gate across a `genesis serve` restart with `timeout_min:2`, paused by hand, resumed, approved after ~19 min → `ok`, not "timed out". **FAIL:** a run paused by hand *while running* (#12) was cancelled as "timed out", because B1 made the pause's status write fail. **Defect m3:** #16's row has `idle_s 0`; its 18 min of idle time were dropped | `batch1.json`, `schedules-final.txt` |
| A8 | **Partly PASS.** #13: three failures → Paused (failing) + `auto_paused` notice; Resume refused while off (409 "schedule is off"), then clears to 0. Readiness skip (#22, workflow uninstalled) → `skipped`, failure count unchanged. **not run yet:** red regression `failed` without counting (needs QA, user's go-ahead) | `schedules-final.txt` |
| A9 | **Partly PASS.** App-sync row edited (schedule + all four options) through `PUT /schedules/1`; Reset to default restores schedule, options and **on** (turned straight back off). Settings → General has no sync card. Document sync Run now → follows its run to `ok`; the "failed when its run fails" path could not be induced (removing gws gave a readiness `skipped`), so it stands on `test_document_library_sync_follows_its_run_instead_of_ok_at_start`. **not run yet:** app-sync Run now (Dev export + `genesis-delta-*` package, ADR-073; user's go-ahead). **Defect m4:** every migrated system row shows "Never run" | `a17-list-gate.png` |
| A10 | **PASS.** Create, edit (model claude-haiku-4.5), Run once (`r-0dc9e335e902`, the agent's model used). Delete refused 409 naming "Weekly KB digest". Model change refused 422 `model` "the model list is not available" while kiro-cli was unreachable (a restart with PATH/HOME without kiro-cli); an unchanged model saves 200. An agent whose skill was uninstalled → 422 `field: "skills"` | — |
| A10b | **PASS.** A real v3 turn with per-run model `claude-haiku-4.5`, skill `appian`, custom-only server `team-kb-open` marked read-only (D32): the projection had only `@blackboard` and `@team-kb-open`, and its tool was called. At the escalation gate after 3 refused attempts: Feedback re-ran the agent with the note in its prompt (`r-1b8a4993b2f7` → done); Reject → failed (`r-18e936364770`). A non-pickable server fails the node before any turn | `chat-agent-probe.json` |
| A11 | **PASS.** Read-only session with KB explorer: instructions applied ("KB explorer says:"), skill `appian` loaded, `@genesis-kb/list_applications` used. A shell or file request was refused (no such tool). `team-kb-open` (no allowlist) was not started, with the D43 notice. A non-allowlisted tool (`team-kb` `get_app_overview`) is **not listed** at all; a wire-level denial cannot be provoked when the engine never offers the tool. Resume after a restart kept the agent. Deleting the agent mid-chat → the chat kept working and `session.agent` was kept. Browser, both themes: agent header, read-only note, no Copilot toggle, New chat panel, focus back on "New chat" after Escape, list marker ", agent KB explorer". Probe re-run: **PASS** (0 credits, activation + control) | `a11-*.png`, `chat-agent-probe.json` |
| A12 | **PASS.** Notices from A5/A7/A8 listed; mark read (15 → 14); a link opened `/schedules/25`; Mark all read → 0; focus back on the bell | `a12-*.png` |
| A13 | **PASS on the release candidate; reproduction on v0.82.0 waiting on the user's go-ahead.** B1: gated and paused runs edited → status kept, no `run.final` row, `state.edited` note, the edit is in state after resume/approve; a bad key → 400 with status unchanged. B2: old run `r-65ab19fae948` lists its artifacts. O1: failed compose capture #3 discarded (real data); **not run:** a compose waiting at its gate (needs QA + credits). O4: label `https://example-qa3.appianpreview.com` added, made Dev, Dev restored, deleted. Unknown `/api` path → 404 JSON for GET and DELETE; `DELETE /schedules/pickable` → 405 | `a13.json` |
| A14 | **Partly PASS / FAIL (M2).** Story 74 (real): Design in dark mode readable on the real `_DOC_STYLE`; Re-run disabled in Code Review with its reason; "Open in new tab" URL served with CSP + nosniff. Implementation: real `objects[]`, metered credits 24.23, report and rollback tabs. **FAIL:** "Record Type Relationships" overlaps the Action tag at 1280/1440/1920 in both themes. Feature 4 Overview (Needs attention) and Activity (all stages, filter chips) render real history. `phase54-ux-pages.mjs` stopped on its first page: it waits for seed-only texts ("Design stage" on a story that opens on Implementation in its lane), a probe limit, not a product bug. **not run yet:** a real design re-run (user's go-ahead); real paused/gated `story-verification` (QA); report frame in dark mode on a fresh run; Activity with pulled CRs (collaboration is off on the copy, and no pulled CR exists in it) | `story74-1440-light.png`, `a15/` |
| A15 | **FAIL (M2, m6), keyboard PASS.** 3 widths × 2 themes on schedules list/detail/app-sync, agents, story 74, feature 4: no page scrolls sideways; table overflow on Objects changed (M2); app-sync "Last sync per application" headers wrap at 1280/1440 (m6, probe WARN). Keyboard only: row menu (Enter opens, arrows move, Escape returns focus); MultiSelect (Enter opens on search, Tab+Space picks, removing a chip leaves focus on "Add skills"); TimeInput 24 h (typing 21 jumps to minutes, 45+ArrowUp → 46) | `a15/`, `pages/` |
| A16 | **PASS.** After the A2–A11 runs and each serve stop: no `kiro-cli`, kas or MCP process left from the release candidate (`ps -ww`; the two kas processes are the user's 11:02 session and this reviewer's) | — |
| A17 | **PASS.** Run now: the run link appeared after 2.3 s. A scheduled run at a gate: header "Waiting at a gate", banner "cancelled in about 10 hours", Open run. Row menu Delete → confirm dialog → row gone. Kiro's real model list in the agent editor (13 models + Kiro default). System rows on the Schedules page. Bell with real scheduler notices. `phase54-pages.mjs` re-run: all pages and portals OK except the m6 header wraps | `a17-*.png`, `pages/phase54-pages-result.json` |

## Findings

### Blockers
- B1 **A blocking program node holds `genesis.db`'s write lock for its whole run, and Phase 54's unattended engine
  loses work because of it.** (`packages/genesis-core/genesis_core/nodes/program.py:17-24`; L-026.)
  - **What:** `program_node` calls its sync `fn` on the worker's event loop. The worker's `AsyncSqliteSaver` executes
    a checkpoint INSERT and then awaits `commit()`; while `fn` blocks the loop, the commit cannot run, so the write
    lock stays held. This is L-026's mechanism, but for any blocking call, not only a write.
  - **Case:** `lockwatch.py`: one probe run with a 20 s program node, nothing else running. `BEGIN IMMEDIATE` fails on
    every sample from 2 s to 20 s and is free at 22 s.
  - **Real workflows do this.** `sync-application` `export_package` polls with `time.sleep(3)` for up to 240 s
    (`genesis-workflows/workflows/sync-application/graph.py:360-377`). The fleet's own log has 25 "database is locked"
    lines on v0.82.0 and before, e.g. 2026-11-18 12:01, just after a 12:00 sync slot.
  - **Effects live, while one such run held the lock:**
    - an agent-prompt `once` fire was lost (run start failed, then closed "interrupted"; the once completed);
    - two gated runs failed in the checkpointer;
    - a hand pause answered 200 but its status write failed, and the scheduler then cancelled the run as "timed out"
      (D31 broken);
    - a run has `run.final{failed}` but `status=running`, so its schedule's row stays open and later slots skip;
    - delayed ticks recorded slots "missed — Genesis was not running".
  - **Why it blocks:** application sync runs every 4 h on the user's real schedule, so user schedules at the same hours
    will collide.
  - **Fix (smallest):** run `program_node`'s `fn` with `await asyncio.to_thread(fn, state, ctx)`, which is L-026's
    fix, made general. This is an additive genesis-core change, but genesis-dev must check that no program node relies
    on running on the loop. Alternative: make the checkpointer connection autocommit; pick by probe.
  - **Regression test:** a worker run whose program node blocks 5 s, while the test asserts `BEGIN IMMEDIATE` on the
    same database succeeds within 1 s. Then re-run A2, A6 (with a long run) and A7 (pause while running) live.
  - **If skipped:** scheduled runs are silently lost or mis-recorded whenever they overlap an application sync or any
    long program node.
  - The root cause predates Phase 54; **D49: it is in this release** (54-12 §1.1). Phase 54 is what makes it hit
    unattended work.

### Majors
- M1 **Agent-written HTML still runs on the app's origin on three older paths** (§1.9b table; D48: in this fix pass).
  1. `StageBuilderPage.tsx:160-161` (`PulledStageView`): add `sandbox="allow-scripts"` without `allow-same-origin`.
     **Check live that a pulled artifact can still be annotated.** The UX probe's frames already throw
     `SecurityError: Failed to read the 'localStorage' property … sandboxed and lacks the 'allow-same-origin' flag`,
     so the SDK may need a guard. If annotation breaks, stop and ask the user (D48).
  2. `api/change_requests.py:96-105`: the `annotate=0` answer gets `Content-Security-Policy: script-src 'none';
     object-src 'none'` + `X-Content-Type-Options: nosniff`, as `workbench.py:337-338`.
  3. `api/features.py:696-716` (and the same branch at `:1542-1544`): the same headers on `annotate=0`. **Note:**
     the read-only spec carries Genesis's own clause scripts (`kb/spec_clauses.py:545-554`, `genesis-clause-focus-js`
     and `-overlay-js`); under `script-src 'none'` the `#clause` jump still works natively, but the focus highlight
     does not. Say so in the As built, or allow those two scripts by hash.
  
  Each needs a regression test: a header test per route, and a test that the pulled view's frame has `sandbox` without
  `allow-same-origin`. If skipped: a teammate's (or an agent's) HTML can call this machine's `/api` with the user's
  full rights.
- M2 **Objects changed table: a long free-text type overlaps the Action column**
  (`web/src/features/workbench/StoryWorkspacePage.tsx:365`, `w-[9.5rem]` Type column).
  - **Case:** story 74's "Record Type Relationships" type covers the "Created" tag at 1280/1440/1920 in light and dark
    (`a15-objects-changed-overlap-1280-light.png`; `scrollWidth > clientWidth` on that cell at all six sizes).
  - **Fix:** let the Type cell wrap (`whitespace-normal break-words`, as the object names do) and size it again from
    the probe (L-090); keep the 54-09 probe page with a long type in its seed.
  - If skipped: the acceptance row A14/A15 stays failed.

### Minors
- m1 **Resume of a user-paused `once` after its time leaves it Active forever** (`runtime/schedule_store.py:439-455`).
  - **Case** (`/tmp/54-10-probe/once_resume.py`): a once at 16:00 IST, paused at 15:30, resumed at 17:30 → state
    `active`, `last_fired_slot` 17:30, `due()` → `(None, [])`, `next_runs` `[]`. It never runs, is never `missed` and
    never completes. `9a365c0` fixed only the "turn on" path.
  - **Fix:** in `set_pause(…, None)` call `_future_once(job.schedule, now)` (refuse "a one-time schedule must be in the
    future"), as `update` does. Add a test next to `test_review_rerun2_m3_a_past_once_cannot_be_turned_on`.
- m2 **A workflow-type schedule can target `agent-prompt` and skips the D3 check at save**
  (`api/schedule_routes.py:180-194`; `/schedules/pickable` lists `agent-prompt` among workflows at `:269-274`).
  - **Case:** a workflow schedule `{workflow_id: "agent-prompt", inputs: {mcp_servers: [{name: "appian-dev-write"}]}}`
    is saved, then fails at every fire (refused at node start) and counts toward auto-pause.
  - **Fix:** leave `agent-prompt` out of the workflow targets (pickable list) and refuse it in `_check_workflow` (422
    `target.workflow_id`, "use an agent prompt schedule"). Add a test.
- m3 **Idle time is dropped when a run leaves a gate or pause and ends between two ticks**
  (`runtime/scheduler.py:428-437` `_close_terminal`; the idle bookkeeping at `:341-347` runs only for a non-terminal run).
  - **Case:** #16: `idle_since` 06:44 UTC, closed 07:02 `ok`, `idle_s 0`; the history shows a 19 min run with no idle
    time.
  - **Fix:** when closing a row whose `idle_since` is set, add `now − idle_since` to `idle_s` (in `_close_terminal` or
    `close_fire`). Add a test: a gated run answered and finished between two ticks keeps its idle seconds.
- m4 **Every migrated system schedule shows "Never run"** (`api/schedule_routes.py:138-140` reads only
  `schedule_runs`).
  - **Case:** the copy's app sync ran 2026-11-19 14:30 (`last_run_at`/`last_run_status` kept on the row), but the list
    and detail say "Never run" (`a17-list-gate.png`).
  - **Fix:** fall back to `job.last_run_at`/`last_run_status`/`last_run_detail` when there is no history row (or have
    m0030 seed one closed row per system job). Add a test.
- m5 **Pause answers 200 and leaves a killed run "running" when its status write fails**
  (`runs/manager.py:379-393` with `_claim_status` `:195-200` returning True on error).
  - **Case:** #12, `r-6dda3c62aae1`: the POST answered `running`, the worker was killed, and the scheduler later
    cancelled the run as "timed out".
  - **Fix:** for `PAUSED` (no `run.final` to announce), propagate the failed write (5xx) instead of returning the
    record as if paused; keep cancel's announce-anyway path. Add a test with a store whose `claim_status` raises. Most
    of the cases go away with B1, but the swallow stays.
- m6 **Application-sync detail, "Last sync per application": headers wrap at 1280 and 1440**
  (`web/src/features/schedules/ScheduleDetailPage.tsx:138`; `phase54-pages.mjs` WARN, `schedule-detail-app-sync-1280-light.jpg`).
  - **Fix:** `whitespace-nowrap` on the headers and column widths from the probe (L-090).

### Nits
- n1 The needs-you notice prints the cancel time as UTC ISO ("by 2026-11-21T06:43+00:00",
  `runtime/scheduler.py:360-361`); show it in the schedule's zone, as the detail banner does in words.
- n2 FastAPI warns "Duplicate Operation ID spa_fallback__full_path__patch" at `/openapi.json` (the 54-02 catch-all
  for every method); give each method its own `operation_id`, or hide the route from the schema.
- n3 History "Outcome: Running" while the header says "Waiting at a gate" (`a17-detail-gate.png`).
- n4 Invalid stored inputs answer 400 with no `field` (`schedule_routes.py:192-194` raises `ScheduleError`); D38 lists
  `target.inputs` as a 422 field.
- n5 An agent-prompt run's documents list 67 provisioned skill files beside `output.md` (`/runs/{id}/artifacts`; this
  is the ADR-069 provisioning in the blackboard and predates Phase 54). Hide `.kiro/` from the documents list.
- n6 The ADR-087 draft omits D30 and D31 (§1.10).

## Not checked
- The `python:3.13` image (L-112): allowed by D47; runs at the re-review on the 54-12 HEAD.
- The v0.82.0 reproduction for A13: replaced by 54-02's fail-first tests (D47).
- A4, A8's red regression, A9's app-sync Run now and the A14 design re-run: allowed by D47, run after 54-12.
- Real paused or gated `story-verification` and a gate-waiting compose discard: these need QA and credits.
- Activity with pulled CRs: there is no pulled CR in the copy, and collaboration stays off (D46).
- The model list inside the schedule wizard (my script did not reach that step's control; the agent editor's list was checked).
- One observation, not proven: `~/.genesis`'s directory mtime moved to 11:33 IST, while the genesis pytest run was
  going (11:31–11:43), with no file in it newer than 01:15. A test may open the real home's database (a WAL open
  creates and removes `-wal`/`-shm`). Worth a grep for tests using `Settings.load()` without a `GENESIS_STATE_DIR`
  monkeypatch.

## Verdict: NEEDS_CHANGES (round 1)

B1, M1 and M2 must be fixed, each with its regression test, and the minors should go in the same pass. All of this is
54-12 §1, with D50's six A1 changes in 54-12 §2. Then I re-review the 54-12 diff, run the CI-image gate, and re-run the
rows listed in the Resume note.

## Resume note (2026-11-20 14:00 IST, end of round 1)

**Copy and server: kept running for the re-review (user's instruction).**
- **Copy:** `/tmp/g5410` (mode 700). It holds `home/` (the copy of `~/.genesis`, DB v30, paths rewritten to the copy)
  and `artifacts/` (the copy of `~/Genesis/runs`). It contains the user's secrets: never print, attach or commit its
  files.
- **Server:** `serve.sh` (normal) and `serve-nokiro.sh` (A10's D35 row only) start the release candidate. It is
  running now as pid 40413 on `127.0.0.1:8790`, reports origin `:8890`, at genesis `2ad1c50` (editable venv: after
  54-12 lands, restart it with `serve.sh` to pick up the new code, and re-check the m0030 version first if 54-12 edits
  m0030, D36).
- **Logs and data:** log `/tmp/g5410/serve.log` (not evidence). Fixture library `/tmp/g5410-lib` (`probe-54-10`).
  Probe scripts `/tmp/54-10-probe/` (`mk.py`, `st.py`, `lockwatch.py`, `a13.py`, `chat.py`, `shot.mjs`, `bell.mjs`,
  `a17.mjs`, `kbd.mjs`, `chatui.mjs`, `models.mjs`, `once_resume.py`).
- **State on the copy:**
  - Collaboration is off. Every system schedule is off; the system rows have `user_modified=1`; app sync was Reset
    then turned off.
  - Still on: only #26 "A17 gate wait (Run now)", a zero-credit probe, daily 23:14. Its run `r-12174a8034e6` waits at
    a gate and is cancelled at 23:14, then a new gated run fires.
  - #25 is Paused (failing).
  - Custom agents 1 (KB explorer), 2 (Dev reader, used by "Weekly KB digest" #24, off) and 3 (GAM helper). Agent 4
    was deleted on purpose (A11).
  - Custom MCP servers `team-kb` and `team-kb-open`. A fake environment `https://example-qa3…` was added and deleted;
    Dev is back on MergeAssist Dev. Failed compose capture #3 is discarded.
- **Fleet:** not running since the 01:15 reboot; both databases at v29. Do not start it before 54-11 (D36).
- **Delete** the copy and stop the server when 54-10 closes, unless the user says otherwise.

**Rows done (round 1):**
- PASS: A3, A5, A6 (with a paused run), A10, A10b, A11 (including the probe), A12 (mark read / all), A13 on the
  release candidate (its v0.82.0 half = 54-02's fail-first tests, D47), A16, A17.
- PASS in part:
  - A7: the gate parts pass.
  - A8: auto-pause, Resume and the readiness skip pass.
  - A9: edit, Reset, the Settings card and doc-sync following its run pass.
  - A14: the read-only parts pass.
  - A15: the keyboard checks pass.

**Rows waiting for 54-12, then a re-run on the copy (54-12 §5):**
- A2: a fire while a long run holds the database (B1).
- A7: pause a *running* scheduled run (D31, B1 and m5).
- A9: "Last result" of migrated system rows (m4), and the Sync options card without Edit (D50).
- A12: Remove and Clear read.
- A14 and A15: the Objects changed table (M2), the app-sync headers (m6), and widths for the D50 pages.
- A17: re-run `phase54-pages.mjs`.
- A1: the six D50 changes.
- 9b live: a pulled artifact still annotates in its sandbox; the CR document and spec-clause headers.
- m1, m2 and m3: their own checks.
- A6: a skip behind a long-running run.

**Rows waiting on the D47 permissions (now given), to run after 54-12:**
- The `python:3.13` image run (colima).
- A4 (a regression schedule on QA, GAM Test) and A8's red regression (`failed`, not counted).
- A9's application-sync Run now (Dev export + `genesis-delta-*` package; fleet down, so one export at a time, L-050).
- A14's real `story-design-analysis` re-run on story 74.

**Not run, for 54-11's release notes (L-111):**
- `story-implementation` (D47 no).
- A real paused or gated `story-verification`, the report frame on a fresh implementation run, and a gate-waiting
  compose discard: these need QA plus credits and a fresh `story-implementation`. Ask again at the re-review if wanted.
- A14 Activity with pulled CRs: no pulled CR in the copy, and collaboration is off.
