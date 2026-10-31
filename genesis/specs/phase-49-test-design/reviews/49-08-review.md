# Review 49-08 — Phase 49 integrated review + live acceptance (genesis-review, 2026-10-30)

Bases: genesis `df9011d` (v0.78.0) → `f0df126`; genesis-workflows `a19153a` (v0.22.0) → `9cb061f`.

**Range note.** The brief named `b9e9487..f0df126` and `325cc23..9cb061f`. A git range excludes its base, and those two
bases are themselves Phase 49 commits (`b9e9487` = 49-02 data model, `325cc23` = 49-03 workflow). To cover "all Phase 49
work" this review uses the previous release tags as bases, so 49-02 and 49-03 are included. Both repos are clean
(`git status` empty); nothing is pushed or tagged.

Commits reviewed — genesis: `b9e9487` 49-02, `454db1f` 49-05, `a8ba5b8` 49-04, `73b3bd3` 49-06, `d62ae03` H1,
`8a7ca96` / `5d69eb7` / `66d7dce` / `45be579` 49-07, `f0df126` H2. genesis-workflows: `325cc23` 49-03, `9cb061f`
(validate_library gate 8: no `workflows/*/tests/__init__.py`).

`genesis-ctx check --since df9011d --repo genesis`: 164 files, areas api, chat, collaboration-hub, db, features-stages,
release-ci, runs-worker, security, stories-workbench, web-shell. `--since a19153a --repo genesis-workflows`: 15 files,
workflows-library (+ release-ci, security).

---

## 1. Gates (§2) — all green, run by the reviewer

| Gate | Result | Evidence |
|---|---|---|
| genesis `pytest` | **1355 passed** | `/tmp/genesis-review/pytest-genesis.txt` (196.7 s) |
| genesis `ruff check genesis` (ruff 0.15.20) | All checks passed | console |
| fresh DB → v25 | OK: migrations 1–25 applied; `kb_sequences` = story 1, test_case 1, test_scenario 1 | `/tmp/genesis-review/freshdb/` |
| v24 DB → v25, rows preserved | OK on a `.backup` **copy of the real `~/.genesis/genesis.db`** (original untouched): `pending [25]` → applied; counts identical for kb_features 4, kb_stories 141, kb_feature_stages 12, kb_objects 3347, runs 357, run_events 229149, chat_sessions 29; `story` sequence still 20; 7 `kb_test_*` tables; `PRAGMA integrity_check` ok, `foreign_key_check` empty | `/tmp/genesis-review/dbcopy/{before,after}.txt` |
| web `npm run lint` | 0 errors, 20 warnings (all pre-existing `react-refresh/only-export-components`; none in `features/test-design/`) | `/tmp/genesis-review/web-lint.txt` |
| web `npm run typecheck` | clean | `/tmp/genesis-review/web-tsc.txt` |
| web `vitest` (incl. jest-axe) | **49 files / 450 tests passed** | `/tmp/genesis-review/web-vitest.txt` |
| bundle fresh | `npx vite build --outDir /tmp/genesis-review/49-08-static` then `diff -r … web/static` → **identical** | console |
| genesis-workflows `validate_library` | PASSED (14 workflows; fixture correctly fails) | `/tmp/genesis-review/validate-library.txt` |
| genesis-workflows `pytest workflows` | **305 passed** | `/tmp/genesis-review/pytest-workflows.txt` |
| kiro-agent-sdk `pytest` (listed by the chat area; repo unchanged) | 93 passed | console |

---

## 2. §1 review items

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 1 | Stage plug-in only | **OK** (with notes) | `kb/stages.py:34` `VALID_STAGES` + `test_design`; `domain/enums.py` `ArtifactKind.TEST_DESIGN`; one `_Binding` `chat/stage_finalizer.py:259-261` (`skip_modes=("topup",)`); one `ChatModeProfile` `chat/mode_profile.py:278-282`; `STAGE_CHAT_MODES` `chat/store.py:30`; one `STAGE_DEFS` row + `gate: storiesFinalized` `web/src/features/features/stages.ts:70-73`; one registry entry `stage-registry.tsx:38`; `STAGE_ARTIFACT_FILE` `services/stage_artifacts.py:23`. Edits beyond the plug-in points, all in existing per-stage branches or new D13 screens: the Tests tab + `xl:grid-cols-5` in `FeaturePage.tsx`; the Finalize button / finalized banner / Re-run branch in `StageBuilderPage.tsx:45-104` (beside the existing UX/TD/Breakdown re-run branches); the R5 branch in `services/spec_change.py:198-201`. No generic shell logic changed. |
| 2 | Gate on both sides | **OK** | Backend: `TestDesignStageService.prereqs_ready` (`services/testdesign_stage.py:383-391`) → 409 in `start` (:416), `rerun` (:443), `start_topup` (:497, after the finalized check). Web: `requires: ["breakdown"], gate: storiesFinalized` → `deriveAvailability` returns `reason: "Stories must be finalized"` (`stages.ts:125-135`). Tasks-only: backend message (:390), web check from 49-07 m2. Tests: `test_test_design_stage.py` prereq tests; live row 1 pending. |
| 3 | Finalize once | **OK** | `kb/testdesign.py:383-386` re-reads `finalized_at` inside the tx → `AlreadyFinalizedError("tests")`; service pre-check `testdesign_stage.py:465`. Keys allocated inside the same tx (`_insert_scenario`/`_insert_case` → `_next_key`, `:168-180`), scenarios then cases in epic/story/position order (`:373-379`). Garbled / missing JSON → `TestDesignInvalidError` 422 (`:472-475`), field rules 422 (`:479-481`), the whole write is one `with self._db.tx()` (`:382-409`). Re-run 409 after Finalize (`:444`); Reopen filtered out and 409 (`test_rerun_and_reopen_are_refused_after_finalize`). See minor m2 for the Reopen message. |
| 4 | Ids | **OK** | `kb_sequences` rows `test_case` / `test_scenario` seeded `INSERT OR IGNORE` (`m0025:171`); `UPDATE … RETURNING next_val` in the tx; `test_keys_monotonic_and_never_reused_after_delete`. No renumbering path exists (no code writes `key` after insert). |
| 5 | Lifecycle | **OK** | Case/scenario status only via `lifecycle.transition` (`api/testdesign.py:341,416`); `update_case` refuses `status` (`kb/testdesign.py:611`); `set_status` is the CAS primitive and re-checks invariants inside its tx (`:779-814`). Retire-while-referenced: precondition `_not_in_active_scenario` (`domain/transitions.py:128-148`) + in-tx re-check. Hard delete only Draft and unreferenced (`kb/testdesign.py:741-756`). Stage start goes through `build_stage_lifecycle_service` (`testdesign_stage.py:431`); re-run uses the existing `reset_for_reupload` exactly as the Breakdown/TD re-runs do (`api/features.py:1165,1427`). |
| 6 | Links | **OK** | `kb_test_case_objects` has no FK to `wiki_object_pages` or `kb_objects` (`m0025:120-136`). No write to any `wiki_*` table in `services/testimpact.py`, `kb/testdesign.py`, `services/testdesign_stage.py`, `api/testdesign.py` (grep: the only reference is the read JOIN at `testimpact.py:283`). R3: `_ObjectIndex.resolve` keeps a uuid only if a current `kb_objects` row exists in that app (`testimpact.py:120-131`); manual add goes through the same resolver (`api/testdesign.py:362-368`); `test_hallucinated_uuid_falls_back_to_name_then_unresolved`. R2: states computed on read (`object_link_state`, `kb/testdesign.py:102`; `test_needs_review_suspect_removed_and_mark_reviewed`). |
| 7 | D7 linker | **OK** | Deterministic SQL + wiki/implementation.json reads (`testimpact.py:195-236, 278-308`); idempotent (`_link_one` returns zero deltas on a repeat; `test_startup_reconcile_is_idempotent`); runs after the `submit-review` transition under a broad logged guard (`chat/story_implementation_finalizer.py:167-177`; `test_implementation_finalizer_link_failure_does_not_block_the_lane_move`); startup reconcile off the loop (`api/app.py:246-257`). |
| 8 | Impact | **OK** | `impact()` reads only (`testimpact.py:496-541`); no Hub/collab import in the impact path; `_resolve` first (R8, `api/testdesign.py:461`). Current edges only (`current_adjacency … valid_to_sync IS NULL`, `kb/_graph_reads_mixin.py:11-28`); no LIMIT on the walk; depth clamp `_clamp_hops` + pydantic `ge/le` (`api/testdesign.py:114`); retired cases and scenarios excluded (`:516`, `:560`); R1 removed-in-this-sync = direct hit labelled `object_removed` (`:506, 526-534`; `test_sync_source_lists_removed_objects_as_direct_hits`). |
| 9 | Workflow | **OK** | `attach_reliability` on `design_cases` and `compose_scenarios`, `attach_healing` (verify/heal, `max_heal 1`, `max_restart 1`) (`graph.py:1771-1783`); `validate_library` PASSED. Allowlists read-only (`KB_RO`, `DEV_RO`, `graph.py:73-84`; no write/delete tool). L-064/L-076: per-epic `design_cases` loop, one `compose_scenarios` turn, program `assemble` (`graph.py:1764-1783`). `MAX_EPICS = 16` refuses more epics (`:1054`), keeping two passes inside `recursion_limit: 300`. JSON contract pinned by the vendored 49-03 golden fixtures (`tests/fixtures/test_design_contract/`). |
| 10 | Chat | **OK** | `test_design` profile: `mcp_mode="read_only"`, `permission_mode="auto_deny"`, `cwd_sandbox=True`, `extra_trust=("fs_read","fs_write")` (`chat/mode_profile.py:278-282`), same posture as `feature_breakdown`. `_STEERING_TEST` requires updating both the visible cards and the embedded JSON (`:216-219`); the completion seed repeats it (`stage_finalizer.py:219-233`). |
| 11 | Web | **OK** | No `asChild` on `<Button>` (the one `PopoverTrigger asChild` wraps a plain `<button>`, `TestImpactTab.tsx:265-270`); no `fetch(` or literal `/api` outside `lib/api` (grep); no raw palette classes in `features/test-design/` (grep); `aria-sort` on sortable headers (`CasesTable.tsx:21`, tested `testDesign.test.tsx:304-312`); types pinned by the backend-generated fixtures (`tests/test_test_design_api.py:47,93` ↔ `web/src/test/fixtures/testdesign/*.json`, `contract.test.ts`); jest-axe on every screen (15 assertions in `testDesign.test.tsx`). |
| 12 | Naming (R6) | **OK** | New modules: `api/testdesign.py`, `kb/testdesign.py`, `services/testdesign_stage.py`, `services/testimpact.py`, `db/migrations/m0025_test_design.py` (its `Migration` object is named `testdesign`). No `test_*.py` / `*_test.py` outside `tests/`. Classes named `Test…` carry `__test__ = False`. |
| 13 | No Hub / collab change | **OK** (see m1) | No Hub contract change; collab columns on suites/cases/scenarios (`m0025:31-38`) + `sync_uuid` on links/steps. `LOCAL_ONLY_STAGES` (`collab/service.py:181`) refused on publish (`:343-344`), left out of adoption (`:1076-1078`), skipped on pull with the cursor advanced (`:580-584`). Tests: `test_a_test_design_stage_is_never_published_or_adopted`, `test_a_pulled_test_design_stage_is_skipped` (`tests/test_test_design_stage.py:643-673`). |

### Hardening

| Item | Verdict | Evidence |
|---|---|---|
| **H1** store status before `run.final` | **OK** | `runs/manager.py:143-147` (`_store_status` → `run.final` → bus close) and the gate/pause branch `:211-214`; `_store_status` logs at ERROR and never blocks the announcement (`:151-160`). Six observers registered (`api/app.py:102,107,142,149,165,171`), all read payload status or need `done`; `ChatRunSupervisor.reconcile` now waits for a durable matching `run.final` (`chat/supervisor.py:145-155`). Tests: 5 scripted-worker tests in `test_runs.py`, live-path finalizer tests per family, 2 supervisor gap tests; all in the 1355. Prior focused review `reviews/49-08-H1-review.md` SHIP. Stale comments: n1. |
| **H2** roll-up | **OK** | `stages.ts:141-147`: Completed (all completed) → Draft (all not-started/draft) → else In progress; signature and tones unchanged; only caller `FeaturePage.tsx:72`. 8 tests in `stages.test.ts` cover the 7 listed cases + in-progress/in-review + a not-available stage. Bundle fresh (above). |

---

## 3. Checklist (`genesis-ctx check`, both repos; union of lines)

### ADRs
- [N/A] ADR-001 LangGraph owns control flow — no orchestration change; the new workflow's graph is static (`graph.py:1764-1786`).
- [N/A] ADR-002 / ADR-004 per-node MCP over ACP — no SDK/ACP change; nodes declare `mcp=` (`graph.py:1733-1739`).
- [OK] ADR-003 local app + library pull — workflow installed from the library (`genesis install`, live).
- [OK] ADR-005 / ADR-029 curated registry; trust = node tools ∩ allowlist — no registry change; node `tools=` lists are read-only (`graph.py:73-84`).
- [OK] ADR-006 self-contained folder + catalog entry — `workflows/test-design-analysis/{workflow.yaml,graph.py}` + `registry.json` entry.
- [OK] ADR-007 roles are tags — `roles: [developer, tester, product-owner]`.
- [N/A] ADR-008 / ADR-013 / ADR-015 / ADR-016 / ADR-017 — unchanged (Python only).
- [N/A] ADR-009 / ADR-025 HITL modes, fork — not touched; H1 keeps the gate/pause bus open (`manager.py:211-214`, `test_runs` gate test).
- [OK] ADR-010 / ADR-018 / ADR-022 small state, bulk on the blackboard — all inputs passed as file paths (`testdesign_stage.py:470-480`), the workflow reads files.
- [OK] ADR-011 reliability trio — `validate_library` PASSED; `attach_reliability` on both agent nodes, `attach_healing` builds `v_verify`/`v_heal`.
- [OK] ADR-012 app never imports workflow Python — genesis imports none of `graph.py`; the contract is a vendored fixture copy.
- [OK] ADR-014 scaffolded shape — trio + healing pre-wired the standard way.
- [OK] ADR-019 core major — `genesis_core_major` unchanged; no core change.
- [OK] ADR-020 no global Kiro config — no change.
- [OK] ADR-021 auto_approve + gates — `auto_approve: true`, `hitl_points: [escalate]`, no write/deploy MCP tool, so no `pre_mutation` needed.
- [OK] ADR-023 / ADR-024 FastAPI embedding, async-first — routes are plain `def` or `asyncio.to_thread` (`api/testdesign.py:258-268`).
- [OK] ADR-026 no auth, loopback — no new bind/server surface.
- [OK] ADR-027 / ADR-055 web stack + tokens — existing primitives; no raw palette classes; `popover.tsx` wraps the already-present `@radix-ui/react-popover` (`package.json:24`, no new dep).
- [OK] ADR-028 `/api` central — `lib/api/testdesign.ts` uses the client with relative paths; routes under `api` router.
- [OK] ADR-030 SQLite, DB-agnostic repository signatures — `TestDesignStore` methods take ids/dicts.
- [OK] ADR-031 / ADR-033 / ADR-034 / ADR-045 read-only chat, sandbox writes only — `test_design` profile (item 10).
- [N/A] ADR-032 credits — no credit code change (live: run credits observed in row 2).
- [OK] ADR-035 file inputs via multipart → blackboard — `doc1..3` `format: file`; ≤ 3 → 400 (`api/testdesign.py:243-255`); `RunManager.start(files=)` validates.
- [OK] ADR-036 / ADR-037 KB stores no SAIL — tests store names/uuids/types only; impact reads `kb_dependencies`.
- [N/A] ADR-038 / ADR-040 / ADR-047 / ADR-048 / ADR-049 / ADR-051 / ADR-052 / ADR-053 / ADR-054 / ADR-064 / ADR-066 / ADR-069 / ADR-073 / ADR-074 / ADR-077 — not touched.
- [N/A] ADR-039 / ADR-041 / ADR-043 / ADR-057 / ADR-058 / ADR-059 — sibling stages unchanged (only the shared `spec_version` helper moved, `services/stage_artifacts.py:100-114`, same body).
- [OK] ADR-042 feature sub-entities cascade — `kb_test_suites.feature_id … ON DELETE CASCADE`, children cascade with the suite (`m0025:43-50`).
- [OK] ADR-044 / ADR-056 parallel plug-in stages; a stage may gate — item 1; the new descriptor `gate` is a second prerequisite form (genesis-docs hand-off in 49-07).
- [OK] ADR-050 one lifecycle authority — item 5.
- [OK] ADR-060 finalize stories gate + irreversible finalize — Test Design gated on `stories_finalized_at`; its own Finalize is one-time (item 3).
- [OK] ADR-061 / ADR-062 / ADR-068 Workbench/Implementation — only a post-transition best-effort hook added; no lane or write-tool change.
- [OK] ADR-063 / ADR-065 local-first, collab opt-in — item 13.
- [OK] ADR-067 healing tier — `attach_healing(..., max_heal=1, max_restart=1)`, `META.healing` mirrors yaml.
- [OK] ADR-070 wiki append-only, no stub pages — item 6.
- [OK] ADR-071 one canonical story page — the Tests section lives on `StoryWorkspacePage.tsx`; the route is under `/applications/{app}/stories/{id}/test-cases` (`api/testdesign.py:427-435`).
- [OK] ADR-072 monotonic ids from `kb_sequences` in the tx — item 4.
- [OK] ADR-075 / ADR-076 clause ids, locked-spec CR — launch normalizes the spec working copy (`testdesign_stage.py:466-470`); `stage_ctx` keeps the spec branch unchanged for every other stage.

### Lessons
- [OK] L-001 / L-002 / L-024 / L-044 / L-046 / L-047 — no ACP/SDK/chat-command change (N/A in substance).
- [OK] L-003 / L-018 / L-060 / L-066 SSE / run-detail — no change; H1 still closes the bus once on terminal (`test_runs` failing-write test).
- [N/A] L-004 / L-012 / L-014 / L-019 / L-028 / L-031 / L-034 / L-043 / L-048 / L-049 / L-050 / L-053 / L-054 / L-055 / L-071 / L-072 / L-078 / L-080 / L-081 / L-084 / L-087 / L-088 — areas not touched.
- [OK] L-005 canonical events — observers key on `run.final` only.
- [OK] L-006 / L-013 topology — `graph:` node ids match `g.add_node` names (validate_library contract gate); UI-only key exempt.
- [OK] L-007 / L-059 — no transcript change.
- [OK] L-008 worker_exit must not clobber error — H1 failed-path test asserts `detail` kept.
- [OK] L-009 async checkpointer — no engine change.
- [OK] L-010 / L-068 — `/api` prefix; SPA serving unchanged.
- [OK] L-011 contract fixtures — backend-written fixtures, web `contract.test.ts`.
- [OK] L-015 heavy libs lazy — no new heavy lib; mermaid chunks only re-hashed.
- [OK] L-016 credits real — no estimation code.
- [OK] L-017 / L-045 fail-closed trust — read-only allowlists; chat `auto_deny`.
- [OK] L-020 recursion limit — `execution: {recursion_limit: 300}`, `MAX_EPICS = 16` bound (live superstep count: row 2).
- [OK] L-021 / L-023 — workflow saves tool outputs by reference; `cleanup` removes `_toolcalls/` (`graph.py:1250-1270`).
- [OK] L-022 — no `from __future__ import annotations` in `graph.py` (`:38` comment; grep).
- [OK] L-025 / L-027 ruff pinned — ruff 0.15.20, unchanged pins.
- [OK] L-026 blocking DB off the loop — plain-`def` routes, `to_thread` for starts and startup reconcile; observers run on the worker reader thread.
- [OK] L-029 — no managed-native change.
- [OK] L-030 — web files changed, so the frontend CI job runs (release concern for 49-09).
- [OK] L-033 not installed → friendly 409 — `testdesign_stage.py:512-514`, `test_not_installed_and_other_launch_errors_are_409`.
- [OK] L-039 list = single-get fields — one DTO builder per shape (`case_dto`/`scenario_dto`, `suite_view`).
- [OK] L-041 / L-042 / L-073 files in the sandbox; Finalize reads the sandbox-aware current HTML — `current_stage_html` (`testdesign_stage.py:472`), `test_finalize_reads_the_sandbox_copy_and_any_attribute_order`.
- [OK] L-051 / L-056 / L-057 — release work belongs to 49-09; both repos clean now.
- [VIOLATION] L-058 level-triggered recovery — the code has the recoveries (`_heal_stage` on suite and top-up reads, `reconcile_topup` on read and at startup), but live row 16 shows they never settle a top-up whose worker died without a `run.final` (M3).
- [OK] L-061 / L-062 bound-run scoping, binding registry — `_BINDINGS` entry with `skip_modes`; the top-up run did not touch the stage (row 13).
- [OK] L-063 gate both sides — item 2.
- [OK] L-064 / L-075 / L-076 — item 9.
- [OK] L-065 gate → END terminal — the worker treats graph completion as terminal (fix in place since Phase 30); `present` sets `done` (`graph.py:1244`).
- [OK] L-069 no `<Button asChild>` — item 11.
- [OK] L-074 / L-082 / L-085 collab pull/publish — test design skipped on pull, refused on publish (item 13); see m1 for the UI button.
- [OK] L-083 real fixture shapes — fixtures written by the real API.
- [OK] L-086 program-owned ids in agent HTML — the embedded JSON is matched by `id` in any attribute order (`testdesign_stage.py:62-64`).
- [OK] L-089 bundle proof — fresh build identical; `45be579` is the documented recovery from a stale-bundle commit.
- [VIOLATION] L-090 real-browser width probe — live row 15 measured a 0 px Title column and controls spilling out of the stage cards (M1, M2).

### Gates
- [OK] every gate in §1 above.

---

## 4. Findings

### Blockers
- none.

### Majors (all from live acceptance; none from the static review)
- **M1 — The Tests tab Cases table collapses its Title column to 0 px at 1280 and 1440 (row 15a).** The table is
  `table-fixed` with `min-w-[760px]` and seven fixed-width columns totalling 808 px (`CasesTable.tsx:73-83`: Key 112,
  Type 116, Priority 100, Status 96, Stories 136, Scenarios 120, Review 128). It sits in the 2/3 column beside Story
  coverage, whose container is 647 px at 1280 and 754 px at 1440. Title gets 0 px, so each title wraps one character
  per line (the first data row is 3121 px tall), and the container scrolls sideways. At 1920 Title gets 85 px. Light
  and dark are identical. Evidence: `/tmp/genesis-review/row15/probe.json`, `spill.jsonl`, `a-cases-light-1440.png`.
  Fix: size from the measurements (L-090): give Title a floor (for example `min-w-[16rem]`, no fixed width), shrink or
  fold the low-information columns (Status/Review into badges under the title, or drop Scenarios below `2xl`), or let
  the coverage panel stack under the table below `2xl`. Re-probe 1280/1440/1920 in both themes. Keep a class-level pin
  test.
- **M2 — On the feature Overview, controls spill out of the five stage cards at every probed width (row 15c).**
  `xl:grid-cols-5` (`FeaturePage.tsx:168`) gives cards of 187 / 219 / 261 px at 1280 / 1440 / 1920. Every card stays
  in one row with no page scroll, but the card footers (`FeaturePage.tsx:269`) don't fit. The Breakdown card's
  "Re-run" sits 98 / 66 / 24 px past the card edge. At 1280, "Re-upload" (UX) is 30 px past, "Export CSV" (Test Design)
  30 px and "Mark as reviewed" (UX and TD spec-changed chips) 25 px. Light and dark are identical. Evidence:
  `/tmp/genesis-review/row15/overview-controls.jsonl`, `c-overview-dark-1280.png`, `c-overview-light-1440.png`. The
  move from four to five columns caused it: the Phase 48 grid was `lg:grid-cols-4`. Fix: wrap the footer actions
  (`flex-wrap`), or switch to `xl:grid-cols-3 2xl:grid-cols-5`, then re-probe.
- **M3 — A top-up whose worker dies across a server restart stays `running` forever and blocks new top-ups (row
  16).** Live: I restarted main (`gsm stop main` → "Stopped (forced)", `gsm start main`) during top-up run
  `r-165e2472b3e2`, which was in its first `design_cases` turn and was the only active run. The orphaned worker
  (pid 11364, ppid 1) and its `kiro-cli` exited within about 2 minutes without writing `run.final`; the last event was
  seq 243269 at 17:22:48. After the restart, `reconcile_topups` settled nothing. `RunManager.reconcile_status`
  (`runs/manager.py:340-362`) adopts only a durable `run.final`, so the run record stayed `running`, and
  `reconcile_topup` (`services/testdesign_stage.py:598-605`) trusts that status. The top-up row stayed `running`,
  `GET …/topups/latest` kept answering `running`, and `POST …/topups` returned **409 "a test top-up is already
  running for this feature"**. Only a manual `POST /api/runs/r-165e2472b3e2/cancel` (by the reviewer, to unblock row
  13) moved the top-up to `failed`. The row expects the top-up to reconcile to ready or failed on startup (L-058). The
  root cause is in the generic run layer: an orphaned run with no worker and no terminal event has no recovery. The
  Test Design top-up is the first feature that hard-blocks on it. Fix: at startup, and on read when no worker for the
  run is tracked in this process, mark a non-terminal run whose worker pid is gone (or whose last event is older than
  the worker heartbeat) as `failed` with a "worker lost across a restart" detail through `_finalize`. That writes the
  `run.final` every reconcile keys on. Add regression tests: a real `RunManager` with a recorded `running` run and no
  worker → startup → `failed`; and the `TestDesignStageService` startup reconcile → top-up `failed`, new top-up
  allowed.

### Minors
- **m1 — The Test Design workspace offers "Publish to team", which always fails.** `StageArtifactWorkspace.tsx:211-218`
  renders `PublishToTeamButton` for every stage when collaboration is enabled and the stage is completed. For
  `test_design` the server refuses by design (`collab/service.py:343-344` → `api/collab_sync.py:59` 409 "the
  test_design stage is local-only until the Hub phase"). The main instance runs with `GENESIS_COLLAB_ENABLED=1`, so the
  user sees an enabled button that can only error. Fix: hide the button for local-only stages (a `localOnly` flag on
  the `STAGE_DEFS` row, or `stage !== "test_design"`), plus a Vitest assertion that the completed Test Design workspace
  shows no publish button with collab enabled.
- **m2 — A refused Reopen after test Finalize carries the spec's reason.** `stage_ctx` sets `downstream_locked` for a
  finalized test design (`services/spec_change.py:198-200`), so the refusal reason is
  `SPEC_PRECONDITION_REASONS[(COMPLETED, "reopen")]` = "the breakdown is complete — use Initiate change request"
  (`domain/transitions.py:79`), which is wrong for this stage (there is no change request on a test design). The UI hides
  Reopen (filtering precondition), so only a direct API call sees it; acceptance row 6 asks for the R5 message. Fix: a
  callable reason that returns "the test design is finalized — its records are authoritative; use Generate tests for
  uncovered stories" when the stage is `test_design`, and extend `test_rerun_and_reopen_are_refused_after_finalize`
  (`tests/test_test_design_stage.py:416-426`) to assert `detail.reason`.

- **m3 — The stage entry page has no refresh of its own while a run is in progress (row 18 side note).** The
  operator watched row 18 live and reports it works. My headless page, opened at 16:21:08 on
  `…/features/6/test-design` and never reloaded, still showed "Designing the tests…" 321 s after the run's
  `run.final(done)` at 17:06:04. The page made 0 navigations and no `GET /api/features/6` after its first load
  (`/tmp/genesis-review/row18-watch.log`). In code, `useFeature` has no `refetchInterval` (`features/hooks.ts:30-36`)
  and the client sets `refetchOnWindowFocus: false` (`lib/query/client.ts:9`). So the running card's promise "This
  page opens the completion chat automatically once the draft is ready" (`TestDesignEntry.tsx:117-133`) depends on
  something outside the page: a focus, a navigation, or another query's invalidation. The UX, TD and Breakdown
  running states share the pattern. Fix: poll `useFeature` every ~5 s while the stage row has a `run_id` and no
  `chat_session_id`, the same way `hooks.ts:384` polls a busy change request; add a Vitest with fake timers.
- **m4 — The Test Impact table's Key column wraps the key onto two lines at 1440 (row 15b).** "TC-" and "000007" sit
  on separate lines in a `w-[112px]` header column plus the row indent (`TestImpactTab.tsx:200`;
  `row15/b-impact-light-1440.png`). No cell is clipped and there is no horizontal scroll. Fix: `whitespace-nowrap`
  on the key cell or a wider column.

### Nits
- **n1 — Two comments still describe the pre-H1 order.** `api/testdesign.py:224-226` ("RunManager notifies observers
  before it stores the terminal status") and `tests/test_test_design_stage.py:4-5` ("which emits ``run.final`` BEFORE it
  writes the run status"). Both are now false; the on-read heal remains a valid safety net (restart / orphaned worker).
- **n2 — The scenario read does not run the R8 resolve.** `GET /test-scenarios/{id}` (`api/testdesign.py:382-388`)
  skips `_resolve`, so a scenario page opened right after a Hub KB pull can show an object as unresolved until the suite
  or a case page is opened. R8 lists only suite, case and impact reads, so this is within spec; consider adding it.
- **n3 — The retired-step refusal names the internal id.** `PUT /test-scenarios/4/steps` returns 422 "test case #18 is
  retired" (live row 17), and the scenario page shows it as is. The user knows the case as TC-000018. Fix: use the key
  in the `set_steps` message.
- **n4 — The case page's story picker allows a Task.** Live row 7 linked TC-000003 to GNS_000001, a Task, and the
  server accepted it (`set_case_stories`). D14 / `_STEERING_TEST` say Task-type stories get no own cases. Coverage still
  reports the Task as `task`, so nothing is miscounted. Either filter Tasks out of the picker or document that manual
  links may include them.

---

## 5. Live acceptance (§3)

**Setup (operator-approved at the HITL gate).**
- Before installing, I backed up the library files to `/tmp/genesis-review/backup-library/`. Then
  `genesis install --from ../genesis-workflows test-design-analysis` installed test-design-analysis 0.1.0 at ref `local`.
- No run was active on main (API + DB checked). I backed up `~/.genesis/genesis.db` with `.backup` to
  `/tmp/genesis-review/backup/genesis-v24.db` (integrity ok, v24, 357 runs, 229149 events).
- `gsm stop main` / `gsm start main`: main came up on the `f0df126` checkout. `info.version` is still 0.78.0 because
  49-09 bumps it. OpenAPI lists the 24 test-design routes; the DB is **v25** with all 357 runs present. The startup link
  reconcile logged `{'apps': 0, …, 'errors': 0}`. userb (:8761) was not touched.
- The `database is locked` 500s in `~/.genesis/run/genesis.log` (`POST /api/collab/pull`, scheduler) all come from the
  old process (pid 45597) before the restart. They are not a Phase 49 effect.
- Feature 6 "Evaluation Instructions" was used for the live rows; feature 5 "New Test Feature" for row 1. App
  `_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416` (AS GSS Full Application).
- Browser steps ran in headless Chromium (Playwright 1.64.1 driving the cached Chromium 1217), drivers in
  `/tmp/genesis-review/*.js`. Rows 14 (spreadsheet), 17 (pointer drag) and 18 were run by the operator.
- Evidence is under `/tmp/genesis-review/`.

| # | Result | Evidence |
|---|---|---|
| 1 | **PASS** | `POST /api/features/5/stages/test_design/start` → **409** "Stories must be finalized before Test Design can start". The card is locked (`row01-feature5-locked.png`). Its tooltip reads "Complete Feature Breakdown first" because feature 5 also lacks the prerequisite stage, which `deriveAvailability` reports before the `gate`. That is as built; the "Stories must be finalized" text is pinned by `stages.test.ts:150` and `testDesign.test.tsx:178,210`. |
| 2 | **PASS** | Started from the UI with notes + one `.md` doc → 200, run `r-d02d990d3331` (`row02-entry-filled.png`, `row02-running.png`). The doc was folded into `notes.txt` ("=== SUPPORTING DOC (doc1) ==="). The graph ran the per-epic loop (4 of 8 epics have a Story; Task-only epics are skipped) and the scenario node. **Agents opened the input files:** every `design_cases` turn's first tool call was "Reading techdesign.txt, spec.txt, uxdesign.txt, notes.txt" and two turns also read `stories.json`; `compose_scenarios` read `case_pool.json`, `techdesign.txt`, `spec.txt`, `uxdesign.txt`, `notes.txt` (`agent.tool_call` events 229171…237963). **65 nodes** completed (one superstep each on this linear graph), against `recursion_limit: 300`. The run used the whole healing ladder: patch → one guided restart → patch, then **escalated**. The critic kept flagging a real conflict in the source documents: a 2000-character column in the Technical Design against 4000 in the Spec. The operator approved the escalation gate at 17:06:04; the run ended `done`. The reviewer never answered the gate. |
| 3 | **PASS** | `run.final(done)` at 17:06:04.957 and completion chat `c-dd7106f77064` at 17:06:04.961, 4 ms later, with no read in between. That is the live `StageFinalizer` path, so **H1 works live**. `test-design.html` (164 KB) has a "Scenarios" section, a "Test cases" section by epic, "Open questions" and one embedded `genesis-test-design` JSON block (32 cases, 6 scenarios, 28 open questions). |
| 4 | **SKIPPED (operator)** | The operator approved and finalized the design before the chat edit. R5 then refuses a re-run, and the operator chose to skip rather than run feature 4. Static coverage: `_STEERING_TEST` + `_seed_test` (item 10). |
| 5 | **PASS** | Finalized at 17:06:53 (operator). 32 cases TC-000001..032 and 6 scenarios TS-000001..006, all Ready, origin `design`. Case keys follow epic/story position (checked against `kb_epics.position` / `kb_stories.position`); 32 cases and 6 scenarios in the document = 32 + 6 records, so nothing was dropped. 118 object links (91 resolved, 27 unresolved). Coverage: 5/5 Stories covered, 0 uncovered. Tests tab shows the tree (`row15/a-cases-*.png`). |
| 6 | **PASS** (m2 confirmed live) | `rerun` → 409 "test design is finalized — use Generate tests for uncovered stories"; `start` → same 409; a second `finalize` → 409 "…one-time action". `allowed` = `[]`. Forced `actions/reopen` → 409 `precondition_failed` with reason **"the breakdown is complete — use Initiate change request"** (m2). Stage stays `completed`. |
| 7 | **PASS** | Case page TC-000003 (`row07-*.png`). Edited Gherkin saved (Then 2 → 3 lines, `row_version` 0 → 1). Stories changed (+GNS_000001, see n4). Planned object `AS_GSS_INT_evaluationInstructionsAcceptance` (Interface) linked as `object_uuid=null`, state `unresolved`, origin `manual`. Retire refused in place: "the test case is used by scenario(s) TS-000001 — remove it from them first", status stays ready. Removing step 3 on TS-000001 (7 → 6 steps) then let Retire through (`retired_at` set); Restore → **TC-000003** ready. |
| 8 | **PASS** | Added one acceptance criterion to GNS_000017 from its story page. All 5 linked cases showed **Needs review** on the story page (5 badges), the Tests tab (summary 5, 5 table badges) and the TC-000016 case page. **Mark reviewed** cleared it (suite needs-review 5 → 4). Afterwards the story's acceptance criteria were restored exactly through the API (the original is in `row08-story-original.json`) and the cases were marked reviewed again, so all 5 are clear. Observation: the shared story form (`StoryForm.tsx:51`) saves one entry per line, turning 2 multi-line acceptance criteria into 8. That is pre-existing behaviour, not Phase 49. |
| 9 | **SKIPPED (option b)** | None of the 19 feature-6 stories has Object Wiki entries or an implementation stage (DB query). Covered by `test_test_impact.py` linker tests and `test_story_implementation.py::test_finalizer_live_run_final_advances_to_code_review`. |
| 10 | **PASS** | The operator made a description-only edit to `AS_GSS_QE_getEvaluation` (Expression Rule). The first incremental sync, `r-2d0e3979a267` (sync 51), found 0 changes because the edit wasn't saved yet. The second, `r-3d654fbe7ce5` (sync 52), reported 1 modified; temporary package `genesis-delta-20261030T173402Z` was created and then deleted (ADR-073). Test Impact → KB sync #52, depth 2: changed = that object (`modified`); 12 cases = **2 direct** (TC-000009, TC-000013) + **10 indirect, all at hop 2**. Depth 1: 2 cases, 0 indirect (`row10-sync52-depth{1,2}.{json,png}`). The case page shows the link as `suspect` (Object changed), separately from Needs review. |
| 11 | **PASS** | Objects source with `AS_GSS_CPS_evaluationDetailsForSummary` (Interface, 18 linked cases), depth 2: hops `[0×18, 2]` (direct first); TC-000009 via `evaluationDetailsForSummary → FM_evaluationSummary → Evaluation_RECORD`; totals 1 suite / 5 scenarios / 19 cases = 18 + 1, consistent (`row11-impact.json`). The UI shows the Feature › Scenario › Case table with Direct labels and "Path" popovers (`row15/b-impact-*.png`). |
| 12 | **PASS** | Object Wiki page of `AS_GSS_Evaluation_SYNCEDRECORD`: the Tests section lists 21 cases (API agrees: 21). "Check test impact" → `?tab=test-impact&object=e6bc8561…&objectName=AS_GSS_Evaluation_SYNCEDRECORD` with the object already picked (`row12-*.png`). |
| 13 | **PASS** (apply path live; reject-dependency path by tests) | Added story GNS_000020 (Story, epic 29). The top-up dialog pre-checked only GNS_000020; the other 5 were listed unchecked (`row13-a-topup-dialog.png`). The first top-up was used for row 16. Top-up 2 (`r-f552d2bf832f`) → `ready` with p-1, p-2 (new cases) and p-3 (new scenario using p-1, p-2). The operator accepted all three → **TC-000033, TC-000034, TS-000007**, Ready, origin `topup`, both linked to GNS_000020, which is now covered. Rejecting a new case and seeing its dependent auto-rejected was not exercised live; it is covered by `test_test_design_stage.py:516-517`, `logic.test.ts:122-123` and `testDesign.test.tsx:360`. |
| 14 | **PASS** | Operator: the CSV opens correctly in a spreadsheet. Server side: `Content-Disposition: attachment; filename="Evaluation-Instructions-tests.csv"`, the 12-column header, 32 data rows (before the top-up) with unique keys, all 32 with multi-line Gherkin cells. TC-000003's Then cell holds the 3 lines including the row-7 edit; Objects lists `[unresolved]` for the planned object. |
| 15 | **FAIL** → M1, M2, m4 | Measured at 1280 / 1440 / 1920 in light and dark (`row15/probe.json`, `spill.jsonl`, `overview-controls.jsonl`, 24 screenshots). **(a) Cases table:** table 808 px vs container 647 / 754 / 893; Title **0 / 0 / 85 px**; scrolls sideways at 1280 and 1440 (M1). **(b) Test Impact:** table 982 / 1142 / 1350 = container, Title 534 / 694 / 902, no clipped cell, no scroll; Key wraps (m4). **(c) Stage grid:** 5 cards in 1 row, 187 / 219 / 261 px, no page scroll; footer controls spill past the card edge (M2). **(d) Case Objects table:** table = container 607 / 714 / 853, Name 292 / 378 / 452, Type 112 / 124 / 149, State 101 / 105 / 125, Origin 60 / 63 / 75, no clipping, no scroll — pass. No horizontal page scroll anywhere at ≥ 1280. |
| 16 | **FAIL** → M3 | Restarted main during top-up 1 (`r-165e2472b3e2`, the only active run). The top-up never reconciled: the run stayed `running` with no `run.final`, and a new top-up got a 409 until the reviewer cancelled the dead run, which moved top-up 1 to `failed`. |
| 17 | **PASS** | **Retired-case step:** retired TS-000004 and then TC-000018 (one of its steps). The scenario page shows the step as retired. Move step 1 down → **422 "test case #18 is retired"**, shown in the page (n3). After removing that step, reordering → 200. Afterwards the case and scenario were restored and the original order `[17,18,20,21,32]` put back (`row17-*.png`). **Tasks-only locked entry:** no Tasks-only feature exists in this app, so not run live (Vitest from 49-07 m2 covers it). **Both review badges in a real table:** Needs review (row 8) and Object changed / `suspect` (row 10). **Pointer drag:** operator — works. **CSV download:** row 14. **Top-up loop:** row 13. |
| 18 | **PASS** (operator), with m3 | Operator: stayed on the page during `r-d02d990d3331` and the stage reached the completion chat without a reload or restart. The backend half is proven by row 3 (chat 4 ms after `run.final`). The reviewer's headless page, never reloaded, did **not** update within 321 s and made no feature request after its first load (m3). |

**State left on main by the acceptance run** (all in feature 6; the operator can keep or delete it):
- The suite: 34 cases and 7 scenarios. TC-000003 has the row-7 edit, the GNS_000001 link and a planned object link.
- Story GNS_000020, added for row 13.
- Runs `r-d02d990d3331` (done), `r-165e2472b3e2` (cancelled by the reviewer), `r-f552d2bf832f` (done), and syncs
  51/52 (`r-2d0e3979a267`, `r-3d654fbe7ce5`).
- Top-up 1 `failed`, top-up 2 `applied`.
- Story GNS_000017 was restored exactly.
- No run is active.
- DB backup: `/tmp/genesis-review/backup/genesis-v24.db`.

---

## Verdict: **NEEDS_CHANGES**

The static review and every gate are green: §1 items 1–13, H1 and H2 are all OK, and pytest 1355, vitest 450,
workflows 305, validate_library, ruff, typecheck, the fresh bundle and the v24 → v25 migration on a copy of the real DB
all pass. H1 is proven live (row 3). Three live acceptance rows fail, so the phase does not ship as is:

1. **M1:** the Cases table Title column collapses to 0 px at 1280 and 1440.
2. **M2:** stage-card controls spill out of the five-column Overview grid at every probed width.
3. **M3:** a top-up orphaned by a restart never reconciles and blocks new top-ups.

These three, plus m1–m4 and n1–n4, are for genesis-spec to turn into one fix item. Each fix needs a regression test,
and the two layout fixes need a re-run of the row-15 probe (`/tmp/genesis-review/row15-*.js`). Rows 15 and 16 must be
re-accepted live after the fix.

---

## Re-review after H3 — genesis `f0df126..d138078` (genesis-review, 2026-10-31)

Scope: the H3 commits `9324a76`, `b4a9f09`, `3dacbf5`, `d138078` (spec §1.1 H3, `reviews/49-08-H3-review.md`), the §2
gates, and live §3 rows 6, 15, 16 and 18 on main (:8760) with feature 6. genesis-workflows is unchanged since `9cb061f`.
HEAD resolves to `d138078`; `git status --short --untracked-files=all` gives 0 lines in both repos.

Main was already running the H3 code when this re-review started: `genesis serve` (pid 87078) started 12:10:53 IST,
after `d138078` (11:58:41), `~/.genesis/run/runs.lock` existed, and `/` served `index-DSkW34-u.js`, the committed
bundle. The genesis package is imported from the checkout (`genesis/genesis/__init__.py`).
Evidence is under `/tmp/genesis-review/rereview/`.

### Code review of H3

The four commits were reviewed in `reviews/49-08-H3-review.md`: round 1 NEEDS_CHANGES (MJ1, mi1–mi3, ni1, ni2), round 2
**SHIP** at `d138078`. There are no commits after `d138078`, so that review covers the code under test here. The H3 As
built now records everything round 2 asked for: mi3 as a genesis-spec follow-up (decision 5), ni2 and mi4 under "Not done
by the sweep", the run-owner lock, the 2xl coverage deviation (decision 1), the n4 `keep=` rule (decision 3) and the
list of features that benefit from the sweep. `genesis-ctx check --since f0df126 --repo genesis` gives the same areas
(api, features-stages, runs-worker, release-ci, security) and the same ADR/lesson lines as the H3 review. That review's
answers stand. The lines the live rows below change are:

- [OK] **L-058** (was VIOLATION in §3 above): live row 16 shows the level-triggered recovery now settles an orphaned
  top-up at startup.
- [OK] **L-090** (was VIOLATION): live row 15 at 1280 / 1440 / 1920 in both themes measures no collapsed column and no
  spilled control.
- [OK] ADR-009 / L-081: the sweep failed only the `running` top-up. No paused or gated run existed on main, so the live
  "never touch paused/gated" half rests on `test_startup_sweep_never_touches_paused_gated_terminal_or_tracked_runs`.

### §2 gates (re-run by the reviewer at `d138078`)

| Gate | Result | Evidence |
|---|---|---|
| genesis `pytest -q -p no:warnings` | **1366 passed** (246.6 s) | `pytest-genesis.txt` |
| `ruff check genesis` (ruff 0.15.20) | All checks passed | console |
| fresh DB → v25 | migrations 1–25 applied; `kb_sequences` story 1, test_case 1, test_scenario 1 | console, `freshdb/` |
| v24 → v25, rows preserved | on a copy of `/tmp/genesis-review/backup/genesis-v24.db`: pending `[25]` → applied; kb_features 4, kb_stories 141, kb_feature_stages 12, kb_objects 3347, runs 357, run_events 229149, chat_sessions 29 identical; story sequence still 20; 7 `kb_test_*` tables; `integrity_check` ok; `foreign_key_check` empty | `v24-copy.db` |
| web `npm run lint` | 0 errors, 20 warnings (the same pre-existing `react-refresh` warnings) | `web-lint.txt` |
| web `npm run typecheck` | clean | `web-tsc.txt` |
| web `npm test` (incl. jest-axe) | **50 files / 459 passed** | `web-vitest.txt` |
| bundle fresh | `npx vite build --outDir /tmp/genesis-review/rereview/static-d138078` then `diff -r … web/static`: **IDENTICAL** | console |
| genesis-workflows `validate_library` | PASSED (14 workflows; the fixture correctly fails) | console |
| genesis-workflows `pytest workflows` | **305 passed** | console |

### Live rows

| # | Result | Evidence |
|---|---|---|
| 6 | **PASS** (m2 fixed) | Feature 6 Test Design: `completed`, suite finalized 2026-10-30 17:06:53, `allowed` = `[]`. `POST …/test_design/rerun` → 409 "test design is finalized — use Generate tests for uncovered stories"; `…/start` → the same 409; `…/finalize` → 409 "…already finalized for this feature — this is a one-time action"; `…/actions/reopen` → 409 `precondition_failed` with reason **"the test design is finalized — its records are authoritative; use Generate tests for uncovered stories"** (was the spec's "the breakdown is complete — use Initiate change request"). After the calls the stage is still `completed`, `row_version` 6, `updated_at` unchanged, and no run was started. |
| 15 | **PASS** (M1, M2, m4 fixed) | Probed main's shipped bundle directly (no dev server), with the H3 scripts copied to `/tmp/genesis-review/rereview/row15-*.js` (output paths changed only) plus `row15-shots.js`. Light and dark give identical numbers. No page h-scroll on any of the 4 screens at any width. **(a) Cases table** 1280 / 1440 / 1920: table = container 982 / 1142 / 1074 px, no container scroll, no clipped cell, no header wraps, Title **282 / 442 / 374 px** (was 0 / 0 / 85). The other columns are Key 96, Type 108, Priority 88, Status 80, Stories 92, Scenarios 100, Review 136. `row15-spill.js`: no leaf past its cell. **(b) Test Impact**: table = container 982 / 1142 / 1350, Key **120 px**, Title 526 / 686 / 894, no clipped cell; all 35 `TC-` keys render on one line at every width and theme (`impact-keys.json`; was "TC-" / "000007" on two lines). **(c) Stage grid**: 3 + 2 cards of 320 / 373 px at 1280 / 1440, one row of 5 × 261 px at 1920; `row15-footer.js` and `row15-spill.js` find **no control clipped or past its card edge** (was up to 98 px past). This time the probe's `clipped` flag is false on every card. **(d) Case Objects** (TC-000009): table = container 607 / 714 / 853, Name 254 / 336 / 413, no clipping, no scroll. Screenshots: `row15/a-cases-*.png`, `b-impact-*.png`, `c-overview-settled-*.png` (taken after the card fade-in; the probe's own `c-overview-*.png` catch it mid-animation), `d-case-objects-*.png`; data: `probe.json`, `footer.jsonl`, `spill.jsonl`. |
| 16 | **PASS** (M3 fixed) | DB backed up first: `.backup` → `/tmp/genesis-review/rereview/backup-pre-row16.db` (integrity ok, v25, 363 runs, none active). Started top-up 3 for GNS_000020 (`POST …/test-suite/topups` → 200, run `r-dfc474e2a4dd`). 45 s later it was the **only active run**, in its first `design_cases` turn (`agent.tool_update` events), worker pid 90499 (ppid 87078). `gsm stop main` at 06:49:35Z (pre-approved). With main down, the record was still `running`, there was no `run.final`, the top-up was `running`, and the worker had been re-parented to ppid 1. `gsm start main` → pid 91165. Startup log: `WARNING genesis.runs.manager: RunManager: failed 1 run(s) orphaned by a restart: r-dfc474e2a4dd`, before "Application startup complete". DB: `error` seq 246491 "worker lost across a server restart" → stored `failed` with that detail → **one** `run.final{failed}` seq 246492 (06:49:43.721) → top-up 3 `failed` at 06:49:43.722. `GET …/topups/latest` → 3 `failed`; `GET /api/runs/r-dfc474e2a4dd` → `failed`, "worker lost across a server restart". **A new top-up is allowed:** `POST …/topups` → **200** (top-up 4, run `r-2c783066f859`; was 409 "already running"). I cancelled it at once (`POST /api/runs/r-2c783066f859/cancel`), which settled top-up 4 `failed`. Nothing was left active. The orphaned worker pid 90499 had exited by the next check (within about 2 minutes), as the As built says. |
| 18 | **PASS** (H1 + m3 fixed) | Feature 4 "Document Builder" (operator's choice; it had no Test Design stage, so nothing was overwritten). DB backed up first: `backup-pre-row18.db`. A headless Chromium page (`row18-f4.js`, 1440 px) opened `…/features/4/test-design`, filled the notes and clicked **Start test design** at 07:02:53Z (run `r-cbf4ee22a3da`, stage draft → in-progress). From there the page was **never reloaded or navigated** (0 main-frame navigations after the start, `watch.log`). While the run was in flight the page made a `GET /api/features/4` every 5 s (936 in 78 min), which is the m3 poll. The run went through the healing ladder (83 `node.completed`, against `recursion_limit` 300) and then **escalated** at 08:17:10. The operator approved that gate at 08:21:00.33; the reviewer never answered it. Then: `run.final{done}` 08:21:01.499 → completion chat `c-797ca51a5dcd` created 08:21:01.504 (5 ms later) → stage `submit` in-progress → in-review 08:21:01.518. That is the live `StageFinalizer` path with no read in between (H1). The page's next poll, at 08:21:02.846, picked it up, and by the 08:21:17 check the page had moved from "Designing the tests…" to the completion chat with `test-design.html` (339 KB) under Session outputs, without a reload (`row18/c-after-finish-no-reload.png`; before: `a-entry.png`, `b-running.png`). The poll **stopped** once the chat existed: no `GET /api/features/4` after 08:21:02.846. In the first pass the same page made no request after its first load and was still stale 321 s after `run.final`. |

### Finding from the live rows (pre-existing, not Phase 49)

- **Minor — a user cancel of a run with a live worker can end `failed` with two terminal `run.final` events.**
  Cancelling top-up 4 above wrote `error` "worker exited abnormally" (seq 246500), `run.final{cancelled}` (246501), then
  `run.final{failed}` (246502). The record ended `failed` / "worker exited abnormally". `RunManager.cancel`
  (`runs/manager.py:313-319`) kills the worker and calls `_finalize(CANCELLED)`, while the worker reader thread handles
  the resulting `worker_exit` with `_finalize(FAILED)` (`:224-229`). Both pass the check-then-act guard at `:140-142`
  before either one stores its status. This is the follow-up the H1 As built already records (H1 review M3: no lock on
  the guard). H3 did not change it, and the DB shows the same pattern on 11 runs since 2026-07-13 (for example
  `r-0bdd08eb2777`, `r-6545274053db`, `r-d18b37366f3e`). It does not block 49-08. It is now seen live on a Test Design
  top-up (the top-up still settled correctly from the first `run.final`). I recommend genesis-spec take it from the
  backlog: a per-run lock or a conditional `UPDATE runs SET status=? WHERE run_id=? AND status NOT IN (terminal)`,
  with a test that cancels a run while its scripted worker emits `worker_exit`.

### State this re-review left on main (features 6 and 4)

- Top-up 3 `failed` (row 16, run `r-dfc474e2a4dd`, "worker lost across a server restart"). Top-up 4 `failed` (the
  cancelled proof, run `r-2c783066f859`). Because top-up 4 is the latest, the Tests tab shows "The last test generation
  failed — nothing was proposed". That is correct for this data, and the banner clears at the next top-up.
- No change to the suite (34 cases, 7 scenarios), the stages, or the stories. No run is active.
- DB backup taken before the restart: `/tmp/genesis-review/rereview/backup-pre-row16.db`.
- Feature 4 (row 18): a new Test Design stage, run `r-cbf4ee22a3da` (done, escalation approved by the operator). After
  the run the operator approved the stage, reopened it and approved it again (08:21:23 → 08:21:38,
  `lifecycle_transitions`), so it is **completed and not finalized**: there are no `TC-`/`TS-` records for feature 4.
  Nothing else on feature 4 changed. No run is active.
- DB backup taken before row 18: `/tmp/genesis-review/rereview/backup-pre-row18.db`.

### Re-review findings

- Blockers: none. Majors: none.
- Minor (pre-existing, outside Phase 49): the cancel / `worker_exit` double-finalize race described above. It goes to
  the backlog as the H1 review M3 follow-up.
- Accepted follow-ups already in the H3 As built: mi3 (the m3 poll keeps polling on a stage whose run failed without a
  draft, for genesis-spec), mi4 (the lock decides who sweeps, not who runs workers), ni2 (`_toolcalls/` is purged while an
  orphan may still run), and the orphaned OS process is not killed.

The §4 findings are resolved as follows (each verified live where a row covers it, otherwise by the H3 review and its
tests):

| Finding | Status |
|---|---|
| M1 Cases Title collapses | Fixed: row 15a, Title 282 / 442 / 374 px |
| M2 stage-card controls spill | Fixed: row 15c, nothing past a card edge |
| M3 orphaned top-up stays running | Fixed: row 16 |
| m1 Publish to team on Test Design | Fixed (H3 review; Vitest with collab on) |
| m2 Reopen reason | Fixed: row 6 |
| m3 stage page doesn't refresh itself | Fixed: row 18 |
| m4 Test Impact key wraps | Fixed: row 15b |
| n1–n4 | Fixed (H3 review; n4 includes both pickers) |
| L-058 / L-090 VIOLATIONs | Now OK (rows 16, 15) |

## Final verdict (49-08, after H3): **SHIP**

There are no blockers or majors. Every §2 gate is green at `d138078`: pytest 1366, ruff, vitest 459, lint, typecheck,
a fresh bundle, the v25 migrations, `validate_library` and workflows 305. The three live rows that failed (15 and 16)
or carried a minor (6, 18) all pass on main. Every remaining §4 finding is fixed with a regression test, and the
remaining notes are recorded follow-ups. Phase 49 can go to release (49-09). At release, ship all of genesis
`b9e9487..d138078` and genesis-workflows `325cc23..9cb061f` together (L-056).
