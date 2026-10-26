# Review 49-04 — base 454db1f (genesis-review, 2026-10-26)

Sub-spec: `specs/phase-49-test-design/49-04-stage-integration.md`. Repo: `genesis`, base `454db1f` (the 49-05 commit,
resolved). The change is uncommitted: `git diff 454db1f` (11 modified files) plus untracked
`genesis/services/testdesign_stage.py`, `tests/test_test_design_stage.py` and `tests/fixtures/test_design_contract/`.
Upstream As built notes read: 49-02 (store API, top-up edges, 1-based positions, object-link origin), 49-03 (contracts
§4.1–4.3, embedded block id-first, `p-N` refs), 49-05 (`resolver()`, `link_feature_implemented`, run off the loop).

No live acceptance: backend services only, no routes or UI (49-06/49-07 own those). I agree with that call.

## Gates (run by the reviewer)

- `.venv/bin/python -m pytest -q -p no:warnings` → **1309 passed** in 200 s (author: 1309; base 1266).
- `.venv/bin/ruff check genesis tests/test_test_design_stage.py tests/test_chat_mode_profile.py` → All checks passed.
- `pytest tests/test_test_design_stage.py tests/test_chat_mode_profile.py` → 54 passed.
- Vendored fixtures vs `genesis-workflows/workflows/test-design-analysis/tests/fixtures/*.json`: `cmp` byte-identical
  for all four files.
- Web gates (`npm run lint/typecheck/test/build`, stale bundle): N/A, no `web/**` change.
- `kiro-agent-sdk` pytest: N/A, no SDK change.

## The author's decisions, checked

1. **No routes; services raise `TestDesignError` subclasses with `.status`.** Matches the spec header ("routes in
   49-06") and R6. OK.
2. **TopupRunObserver settles on the `run.final` payload status.** Confirmed correct. `RunManager._finalize`
   (`runs/manager.py:139-141`) calls `_log(run_id, RUN_FINAL, …)`, which runs the observers synchronously
   (`manager.py:113-118`), and only then calls `store.set_status`. An observer that re-reads `rec.status` sees
   `running`.
   **The pre-existing consequence is also confirmed.** `StageFinalizer._finalize` (`chat/stage_finalizer.py:97-100`),
   `StoryDesignFinalizer._finalize` (`story_design_finalizer.py:114-117`) and `StoryImplementationFinalizer._finalize`
   (`story_implementation_finalizer.py:116-119`) all return early on `rec.status != "done"` when `_observe` calls them,
   so the live path never finalizes anything. Those stages are finalized by the on-read heal (`features.py:353-356`,
   `:443-446`, `:871-874`) and the startup `reconcile()` (`app.py:233-239`). The existing tests hide this: every one
   calls `_finalize(run_id)` directly after setting the store status to `done` (for example
   `test_features_api.py:361,374,460`), so no test goes through the real chokepoint. This predates 49-04 and is out of
   its scope. It belongs in its own fix with a regression test that ends a run through `rm._finalize` (see m3).
3. **Finalize parse / pre-clean / validate / upstream.** `current_stage_html` (sandbox first, L-073) is used at
   `testdesign_stage.py` `finalize_test_design`. `_EMBED_RE` uses a look-ahead on `id`, so attribute order does not
   matter; tests cover both orders and single quotes (`test_parse_embedded_is_attribute_order_independent`,
   `test_finalize_reads_the_sandbox_copy_and_any_attribute_order`). The clean order is story keys, then steps, then
   empty scenarios, and a case left without a story is kept (`test_clean_design_order_of_drops`,
   `test_finalize_drops_unknown_keys_dangling_steps_and_empty_scenarios`). `validate_design` enforces title, at least
   one when and one then, type, priority, object name and type, and duplicate refs (`test_finalize_422s`).
   `upstream.json` holds `{run_id, mode, spec, stories}` and is written to the suite (`test_finalize_happy_path…`
   asserts `suite.upstream.run_id`). OK.
4. **start / rerun guards.** These match §3.4 and L-062: prereqs, finalized (R5), existing chat ("use re-run"), and a
   bound run that is not failed or cancelled. Draft → in-progress goes through `LifecycleService.transition("start")`,
   which follows ADR-050 more closely than the breakdown/TD routes (they call `set_status` directly). `rerun` mirrors
   the breakdown (`features.py:1155-1169`), including `reset_for_reupload`. OK (see n2).
5. **Top-up.** Task ids give 422 and foreign ids give 422 (`test_topup_guards`). Stale running rows are reconciled
   before the "already running" guard (`test_stale_running_topup_does_not_block_a_new_one`). Snapshots go to
   `<stage_dir>/topups/<hex>/`, and the test asserts that the design snapshot dir differs and that the stage row is
   untouched. Dependency expansion and dead-record rejection are covered by
   `test_apply_rejects_dependants_of_a_rejected_case` and `test_expand_decisions_rejects_steps_on_dead_records`.
   `decisions_json` = `{accepted, rejected:[{ref, reason}]}` is asserted. Created records are `ready`/`topup` and
   object links stay `design`, matching 49-02 As built #7. OK.
6. **CSV.** The header and the multi-line Gherkin round-trip through `csv.reader`, `[unresolved]` appears, the retired
   case row is present with an empty Scenarios cell (`test_csv_export_round_trips`), and the filename is sanitized
   exactly like the Jira export (`features.py:1189`). No formula escaping, consistent with the existing export
   (see n3).

The user's instruction is met. The service is built once over `app.state.test_impact` (`app.py:163-166`; asserted by
`test_the_app_wires_one_shared_test_impact_service`). `resolver()` is passed to both `create_from_design` and
`apply_topup`. `link_feature_implemented(feature_id)` is called after each (asserted by `calls == [env.fid]` in the
Finalize and apply tests). It runs best-effort outside the write and is logged loudly on failure.

## Checklist

### ADRs
- [N/A] ADR-001 — no orchestration change; the agent edits a document only.
- [N/A] ADR-002 / ADR-004 / ADR-020 — no MCP injection change; the profile reuses `mcp_mode="read_only"`.
- [N/A] ADR-005 / ADR-029 — no registry change.
- [OK] ADR-010 — run inputs are blackboard/stage-dir paths (`launch_test_design` inputs), never bulk content.
- [N/A] ADR-011 — no agent node in genesis (the workflow is 49-03's).
- [OK] ADR-012 — the app never imports workflow Python; the contract is read as JSON fixtures and run artifacts.
- [N/A] ADR-023 / ADR-026 / ADR-028 / ADR-043 / ADR-047 / ADR-071 — no route, bind or SPA change.
- [N/A] ADR-027 / ADR-055 — no web change.
- [OK] ADR-030 — SQLite only; `list_topups` builds SQL from fixed fragments with bound parameters (`kb/testdesign.py:406-418`).
- [OK] ADR-031 / ADR-045 / ADR-034 — `test_design` profile: `read_only` + `auto_deny` + `cwd_sandbox` + `fs_read/fs_write` only (`mode_profile.py:278-282`; `test_test_design_posture`).
- [N/A] ADR-032 — no credit handling.
- [N/A] ADR-033 — the copilot is untouched; `test_design` is a stage mode in `STAGE_CHAT_MODES` (`chat/store.py:30`).
- [OK] ADR-035 — supporting docs go through `rm.start(files={"doc1".."doc3"})` and are capped at 3 (`_check_files`; `test_too_many_docs_is_a_400`). Upload size bounds stay with the 49-06 route, as for the breakdown.
- [N/A] ADR-037 — no SAIL stored.
- [N/A] ADR-041 — no documents.
- [OK] ADR-042 — the test design is a feature sub-entity; the chat refines the document and program code persists it.
- [OK] ADR-044 / ADR-056 — a new parallel stage container with its own lifecycle (`VALID_STAGES`, `ArtifactKind.TEST_DESIGN`).
- [N/A] ADR-049 — no IA change.
- [OK] ADR-050 — start uses `LifecycleService.transition`; Reopen is locked through the existing precondition via `stage_ctx` (`spec_change.py:196-213`; `test_rerun_and_reopen_are_refused_after_finalize` drives the real route → 409 `precondition_failed`). `rerun` uses `reset_for_reupload` like every existing re-run (pre-existing pattern).
- [N/A] ADR-051 / ADR-053 / ADR-069 — untouched.
- [N/A] ADR-057 — UX stage untouched.
- [OK] ADR-058 — prerequisite declared and enforced in start, re-run and top-up (`_require_prereqs`; `test_prereq_*`).
- [N/A] ADR-059 — breakdown untouched (only `_spec_version` was extracted, with identical logic: `stage_artifacts.py:100-114` vs the removed body).
- [OK] ADR-060 — Finalize is one-time: a second call gives 409 (`test_finalize_409s`); `AlreadyFinalizedError` maps to 409.
- [N/A] ADR-061 / ADR-062 / ADR-068 — no lane change.
- [VIOLATION — minor, see m1] ADR-063 / ADR-064 / ADR-065 — the collaboration data subset grows implicitly: a completed `test_design` stage now qualifies for `adopt_publish` and `publish_feature_stage`, which is against 49-01 D12 ("local only, no collab binding").
- [N/A] ADR-067 — no healing change.
- [N/A] ADR-072 — no story ids allocated.
- [N/A] ADR-073 / ADR-074 — no KB sync change.
- [N/A] ADR-075 / ADR-076 — no clause or CR change. Spec normalization before snapshot is reused (`_normalize_spec`).
- [OK] ADR-077 — reviewer ran without trust-all; context via genesis-ctx.

### Lessons
- [N/A] L-001, L-003, L-007, L-010, L-016, L-017, L-018, L-019, L-024, L-031, L-043, L-044, L-046, L-047, L-048, L-068, L-069, L-090 — areas not touched by this diff.
- [OK] L-004 — top-up and suite state live in SQLite; files are only snapshots/artifacts.
- [OK] L-011 — golden fixtures vendored byte-identically, with a drift test (`test_vendored_contract_fixtures_match_the_workflow_repo`). It skips when the sibling checkout is absent, so CI does not catch drift (n4).
- [OK] L-025 / L-027 — ruff pinned; clean.
- [N/A] L-030, L-051, L-056, L-057, L-087, L-088, L-089 — release/agent-system lessons; nothing is released here. L-056 applies at commit time: three untracked paths must be `git add`-ed.
- [OK] L-026 — service methods are sync; the startup reconcile uses `asyncio.to_thread` (`app.py:249-252`); the observer runs on the reader thread. 49-06 must call them via `to_thread` (49-05 hand-off).
- [OK] L-033 — not installed → 409 with the `genesis install` hint (`test_not_installed_and_other_launch_errors_are_409`).
- [OK] L-039 — `list_topups` and `get_topup` share `_topup_dict`, so they return the same derived fields.
- [OK] L-041 / L-042 — sandbox cwd + trusted fs tools; the document is a file in the working directory.
- [OK] L-045 — read-only posture kept; the steering states the limits.
- [OK] L-058 — top-ups settle live, on read (`latest_topup`, `start_topup`) and at startup; failures are logged at warning (`test_missed_run_final_is_recovered_on_read_and_at_startup`, `test_failed_topup_run_moves_to_failed`, `test_done_run_without_proposals_fails_the_topup`).
- [OK] L-061 — the binding keeps the currently-bound-run guard; `skip_modes` stops the `reconcile()` sweep (which lists every done `test-design-analysis` run) from finalizing a top-up into the stage (`test_finalizer_binds_a_design_run_and_ignores_a_topup_run`).
- [OK] L-062 — binding registry entry plus start gated on the run lifecycle.
- [OK] L-063 — backend side enforced; the web mirror is 49-07.
- [N/A] L-064 / L-075 / L-076 — workflow-side.
- [VIOLATION — minor, see m1] L-071 / L-072 / L-082 / L-085 — the same collaboration exposure as ADR-063.
- [N/A] L-084 — no Hub payload work.
- [OK] L-073 — Finalize reads `current_stage_html` (sandbox copy first), tested against a stale `html_path`.
- [OK] L-083 — fixtures use real shapes (GNS_ keys from 123, real Gherkin AC).
- [OK] L-086 — n/a in substance; the parser reads the block and never rewrites the HTML.

### Gates
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → 1309 passed.
- [OK] `cd genesis && .venv/bin/ruff check genesis` → clean.
- [N/A] `cd kiro-agent-sdk && .venv/bin/python -m pytest -q` — SDK unchanged.
- [N/A] `cd genesis/web && npm run lint && npm run typecheck && npm test` — no web change.
- [N/A] `cd genesis/web && npm run build` — no web change.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- **m1 — a completed `test_design` stage is now publishable to the Hub, against D12 (local only).** Adding `"test_design"`
  to `StageStore.VALID_STAGES` brings the stage into the generic collaboration paths:
  `CollaborationService._adoption_rows` selects every `kb_feature_stages` row with `status='completed'`
  (`collab/service.py:1064-1065`), and `publish_feature_stage` / `publish_feature_stage_by_kind` accept any stage
  (`service.py:765-794`, exposed at `api/collab_sync.py:72-78`). With collaboration on, an explicit "adopt" therefore
  publishes the test-design document as a `stage_artifact`. A teammate's pull then creates a chat-less completed
  `test_design` stage on their machine. They could Finalize it there and allocate colliding `TC-`/`TS-` ids, which is
  the prerequisite D12 defers to the Hub phase. The exposure needs collaboration enabled plus an explicit action, so
  this is minor. Fix (small, now or as the first item of 49-06): exclude `test_design` in `_adoption_rows`, refuse it
  in `publish_feature_stage` with a `ValueError` ("test design is local-only until the Hub phase", D12), and have the
  puller skip a `stage_artifact` whose `stage` is `test_design`. Add one test for each. Or record an explicit decision
  plus a backlog item if the user wants the document shared.
- **m2 — hand-off to 49-06: test-design reads must heal the stage.** Because of decision 2, a completed design run
  reaches `in-review` only when something calls `StageFinalizer.reconcile_stage` (or at restart). The generic feature
  and stage GETs already do this (`features.py:443-446`, `:871-874`). If 49-06 adds a dedicated test-design status
  GET that the web polls, it must call the same heal, or the panel will sit at "in progress" after the run ends. Put
  this in the 49-04 As built hand-offs.
- **m3 — pre-existing, not caused by 49-04: every run→artifact finalizer's live path is a no-op.** Confirmed above
  (decision 2). The impact is latency, not data loss: stages finalize on the next read or at startup. The tests mask it
  by calling `_finalize` after a manual `set_status("done")`. Record it in the backlog and the lesson candidates. The
  fix is to pass the terminal status from the `run.final` payload into `_finalize` (as `TopupRunObserver` does), or
  write the store status before emitting `run.final`, plus a regression test that ends a UX run through
  `RunManager._finalize` and asserts the stage is `in-review` with no read in between. Not a 49-04 change; get the
  user's sign-off before touching shipped finalizers.

### Nits
- **n1** — `_EMBED_RE`'s `\bid\s*=` also matches `data-id="genesis-test-design"`, because `-` is a word boundary.
  A `(?<![\w-])id` look-behind would make the match exact. Harmless in practice.
- **n2** — `rerun` has no active-run guard. It deletes the stage dir (the running worker's snapshots) and relaunches.
  The old run then fails or is ignored as superseded (L-061). This mirrors the breakdown and TD re-runs, so it is
  consistent. Separately, `start` reports "already in progress" when the bound run is `done` without a drafted
  artifact; "the last analysis produced no document — use re-run" would be clearer.
- **n3** — CSV formula injection: agent-authored cells starting with `=`, `+`, `-` or `@` are written raw. This is
  consistent with the Jira export, and it is a local single-user app, so it is acceptable. Consider one backlog line
  covering both exports.
- **n4** — the fixture drift test skips in CI (no sibling checkout), so drift is caught only on a dev machine. Fine
  for now; 49-08 should run it once with both repos present.
- **n5** — `start_topup` checks "one running per feature" in Python, with no DB guard, so two concurrent requests
  could both launch. The risk is negligible for a single-user app; note it for the Hub phase.

## Verdict: SHIP

There are no blockers or majors, every gate I ran is green, and the user's shared-`TestImpactService` instruction is
implemented and tested. Fix m1 before 49-06 exposes the stage (or record the decision). Carry m2 into the 49-04 As
built hand-offs. Log m3 as a pre-existing backlog item and lesson candidate. Before committing, stage the three
untracked paths (L-056).

---

# Re-review — fix delta, base 454db1f (genesis-review, 2026-10-26)

Scope: the round-1 fixes only, still uncommitted (`git diff 454db1f` now 13 modified files, +180/−23, plus the same
three untracked paths). I read the diff of `genesis/collab/service.py`, the changed regions of
`genesis/services/testdesign_stage.py`, and the new and changed tests.

## Gates (run by the reviewer)

- `.venv/bin/python -m pytest -q -p no:warnings` → **1311 passed** in 195 s (author: 1311; round 1: 1309, +2 new tests).
- `.venv/bin/ruff check genesis tests/test_test_design_stage.py` → All checks passed.
- `pytest tests/test_test_design_stage.py tests/test_collab_sdlc.py tests/test_chat_mode_profile.py` → 80 passed.

## Round-1 findings, checked

- **m1 — RESOLVED.** `LOCAL_ONLY_STAGES = frozenset({"test_design"})` (`collab/service.py:181`).
  - Publish: the guard sits in `publish()` after the row load (`service.py:343-344`), so it covers every caller:
    `publish_feature_stage` (`:793`), `publish_feature_stage_by_kind`, `adopt_publish`, and the CR auto-publisher in
    `spec_change.py:1125,1127` (spec and breakdown only, so it never reaches the guard). The routes map `ValueError`
    to 409 (`api/collab_sync.py:59-60`), which is the right status for this refusal.
  - Adoption: `_adoption_rows` filters on the selected `stage` column (`service.py:1077-1078`), so
    `adoption_preview` and `adopt_publish` both exclude it.
  - Pull: `_upsert_local` skips a `stage_artifact` whose payload `stage` is local-only, after the known-version check
    and before the tombstone and artifact download (`service.py:580-584`). It logs a warning and returns `True`, so
    the cursor advances and one record cannot pin it (L-082).
  - Tests: `test_a_test_design_stage_is_never_published_or_adopted` covers both publish entry points, the preview
    count, the adopt count and Hub absence. `test_a_pulled_test_design_stage_is_skipped` asserts the record is
    handled, no local row exists, and a second pull returns `[]` (the cursor advanced). Both use the real
    `LocalHubProvider`, which enforces the contract kinds.
- **n1 — RESOLVED.** `(?<![\w-])id` (`testdesign_stage.py:65`); the `data-id="genesis-test-design"` negative is
  asserted in `test_parse_embedded_is_attribute_order_independent` (test file line 684). Single-quoted and
  attribute-order cases still pass.
- **n2 (second half) — RESOLVED.** A bound run with status `done` and no chat now gives "…finished but its document is
  not open yet — open the stage, or use re-run" (`testdesign_stage.py:389-392`). An active run still gives "already in
  progress", and a missing record falls through to the same message. Covered in
  `test_start_guards_an_existing_chat_and_an_active_run` (test file lines 273-276). The re-run half is unchanged,
  which I accept as consistent with breakdown/TD.
- **m2, m3 — NOT YET RECORDED.** The brief says these are carried in the As built, but
  `specs/phase-49-test-design/49-04-stage-integration.md` (119 lines) has no As built section yet, and a grep for
  `reconcile_stage`, `hand-off` and `backlog` finds nothing. This is not a code defect. It is a Definition-of-Done
  item: write the As built with (a) the m2 hand-off to 49-06 (a dedicated test-design status GET must call
  `StageFinalizer.reconcile_stage`) and (b) m3 as a backlog item plus lesson candidate, before the commit.
- **n3, n4, n5 — unchanged**, recorded decisions. Agreed.

## New findings from the delta

None. The pull skip returns before the tombstone branch, so a Hub tombstone for a test-design stage is also ignored.
That is correct, because such a record should never exist.

## Re-review verdict: SHIP

All gates are green and m1, n1 and n2 are fixed with regression tests. Before committing: (1) write the 49-04 As
built, including the m2 hand-off and the m3 backlog line; (2) `git add` the three untracked paths
(`genesis/services/testdesign_stage.py`, `tests/test_test_design_stage.py`, `tests/fixtures/test_design_contract/`)
and confirm the commit contains every changed file (L-056).
