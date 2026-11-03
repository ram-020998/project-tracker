# Review 51-07 — base genesis ee1b77c · genesis-workflows 5a24d17 (genesis-review, 2026-11-03)

Scope: the **uncommitted working tree** of both repos against those bases (nothing is committed yet; the base shas
resolve: genesis `ee1b77c` is HEAD, genesis-workflows `5a24d17` is HEAD). playwright-appian: no change. Spec:
`specs/phase-51-test-execution-engine/51-07-action-library-and-recording.md` (no As built section yet; the author's
brief was used as the As built). Context: `genesis-ctx pack 51-07` (~40K tokens, OK); `genesis-ctx check --since …`
per repo.

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/python -m pytest -q -p no:warnings` | **1602 passed** in 386 s, 0 skipped (the real-workspace library tests and the real-Playwright test ran) |
| genesis `.venv/bin/ruff check genesis` (ruff 0.15.20) | All checks passed |
| genesis-workflows `ci/validate_library.py` | LIBRARY VALIDATION PASSED (16 workflows; reliability lint fixture check OK) |
| genesis-workflows `ci/validate_skills.py` | SKILLS VALIDATION PASSED (4 skills) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **343 passed** |
| genesis-workflows `ruff check workflows/action-capture` | All checks passed |
| web `lint`/`typecheck`/`test`/`build` | N/A: `git diff --stat ee1b77c -- web` is empty |
| wheel (`pip wheel --no-deps . -w /tmp/51-07-wheel`) | lists `genesis/testexec/templates/lib/index.ts` and `scan-refs.mjs` |

Reviewer probe (scratch script in `/tmp/51-07-probe/`, typecheck off, plain git): `TestWorkspace.change` with a
raising `after_commit` → HEAD back at the base, files restored, index clean; a raising `before_commit` → nothing
committed; the no-op adopt path passes HEAD to `after_commit`; deleting a path that is neither tracked nor present
raises `WorkspaceError: git add failed: pathspec … did not match` (n1).

## Checklist

### Manifest ADRs and lessons (the ones the brief asked about)
- [OK] **ADR-010/018** — state small, bulk on the blackboard. `action-capture` state carries artifact pointers
  (`proposals.json`, `replay.json`, `verify.json`, `heal.json`, `result.json`) and small `decisions`; code lives in
  `<run>/proposed/`. Proposal code copied into `kb_test_captures.proposals_json` (deviation 6) is a catalog row, not
  graph state, capped at 200 KB per file × ≤ 30 proposals (`capture_finalizer.py` `MAX_CODE_BYTES`,
  `graph.py` `MAX_PROPOSALS`). Accepted.
- [OK] **ADR-011** — `segment` and `heal` wear the trio: `attach_reliability(segment, v_segment, on_exhaust_gate=
  "escalate")` and `attach_healing(… heal …, gate="escalate", retry_max=rmax)` (`graph.py` `build`); the reliability
  lint passed; test `test_meta_mirrors_the_yaml_and_every_agent_wears_the_trio`.
- [OK] **ADR-012** — no workflow Python in the app: `CaptureFinalizer` reads `result.json` only; `graph.py` imports only
  genesis_core/langgraph and reaches apwt/Playwright through `ctx.extras['apwt']`; the replay generators are copied
  into `graph.py` (see m4). The item-page replay (deviation 3) runs Playwright as a subprocess from the app process,
  not graph code — allowed, with m5.
- [OK] **ADR-050** — every status change goes through `LifecycleService`: `changed` in `_apply_save`, `approve` in
  `replay`/`ProposalService.apply`, retire/restore/approve in `transition`; `changed` by hand refused
  (`test_a_code_save_of_a_ready_item_demotes_it_through_the_audited_changed_edge`). Audited row `(ready, changed,
  draft)` with actor. The "reason names the commit" part of D20 is not met (m3).
- [OK] **ADR-067** — `attach_healing(verify=replay, heal, reassemble, restart_target="segment", max_heal=1,
  max_restart=1)`; `verify_report` emits one fix per failing proposal; tests
  `test_the_graph_turns_a_trace_into_replayed_proposals_with_one_heal`,
  `test_unfixable_proposals_escalate_and_present_marks_them_failed`.
- [OK] **ADR-069** — `kiro_node(skills=["genesis-test-authoring", "playwright-appian"])`; `_skill_source` resolves
  `playwright-appian` only from `<run>/checkout/node_modules/playwright-appian/skills/playwright-appian`
  (`runtime/context.py` +84–92), no managed/global fallback; test
  `test_the_playwright_appian_skill_resolves_from_the_run_checkout_only`. Recording start refuses when
  `genesis-test-authoring` is not installed (`recording.py` `start`).
- [OK] **L-021** — the prompts name files and say "do not paste them into your reply" (`segment_prompt`).
- [OK] **L-024** — skills via the filesystem (ADR-069 provisioning), no wire param.
- [OK] **L-026** — workflow: `generate`, `v_segment`, `replay` are raw async nodes doing their work in
  `asyncio.to_thread`; `reassemble`/`present` only touch small run files. App: services are sync and documented
  "async callers use `asyncio.to_thread`"; the startup sweep uses `to_thread` (`app.py` +305–316). No routes yet (51-10).
- [OK] **L-041/L-042** — `segment`/`heal` work on files in the run folder (cwd = blackboard); bulk context as files.
- [OK] **L-064/L-076** — one `segment` turn for the whole flow keeps cross-item consistency; output is many files, not
  one huge reply; heal patches per proposal in place.
- [OK] **L-083** — fixtures are real shapes: `apwt-0.3.0-record.json` (recorded 0.3.0 outputs), `replay-report-1.59.1.json`
  (a real @playwright/test 1.59.1 report, also under `scripts/spikes/51-07/evidence/`), `scan-refs-0.1.json`,
  `create-evaluation.trace.json` (the sandbox trace).
- [VIOLATION → M1] **L-091** — `ProposalService.decide` and `CaptureStore.set_decisions` are right (CAS on
  `row_version` with the status in the same UPDATE). `RecordingService.stop`/`refresh`/`discard` check
  `cap["status"] == "recording"` and then act with no lock or claim (M1).
- [OK] **L-092** — no `tests/__init__.py` in `workflows/action-capture/tests/`; `TestLibraryService.__test__ = False`;
  no new product symbol named `test_*` (grep of `genesis/genesis/**` and `graph.py`: only pre-existing names).
- [OK] **L-094** — a separate `LIBRARY_TRANSITIONS` (`transitions.py` +235), used only by `build_library_lifecycle`;
  `TEST_TRANSITIONS` unchanged (test `test_the_changed_edge_is_library_only_test_cases_keep_their_table`); the only
  other users of `TEST_ACTION`/`TEST_SETUP` are `lifecycle.py` 373/403/404. Replacing `TEST_FILTERING_PRECONDITIONS`
  (empty frozenset, `transitions.py` 184) with `LIBRARY_FILTERING_PRECONDITIONS` drops nothing. **Deviation 1 accepted.**

### genesis repo checklist (`genesis-ctx check --since ee1b77c --repo genesis`)
- [OK] ADR-001 — LangGraph owns control flow; the recording is human-driven app code, the capture is a graph.
- [OK] ADR-011 — see above.
- [OK] ADR-012 — see above.
- [OK] ADR-019 — no genesis-core change; `CORE_MAJOR` untouched.
- [OK] ADR-021 — `action-capture` `auto_approve: true`, one escalation gate; its QA replay has no `pre_mutation` gate,
  sanctioned by D22 / ADR-082 (draft, amends ADR-021 for QA test runs; `adr-drafts.md` line 9).
- [OK] ADR-023 — services embedded in the FastAPI app; no server.
- [N/A] ADR-026 — no bind or network surface change; no routes.
- [N/A] ADR-027, ADR-043, ADR-049, ADR-055 — no web change.
- [N/A] ADR-028, L-010, L-096 — no route added (51-10).
- [OK] ADR-030 — SQLite; store methods take ids and dicts.
- [N/A] ADR-031/033/034/045 — no chat change; the new skill is a workflow-node skill (ADR-069).
- [N/A] ADR-035 — no run input file upload (the trace is copied by `prepare`).
- [OK] ADR-037 — no SAIL source stored; the stored code is the workspace's TypeScript.
- [N/A] ADR-041, 042, 044, 047, 056–065, 070–076, 079 — not touched.
- [OK] ADR-050 — see above (m3 for the reason).
- [OK] ADR-067 — see above.
- [N/A] ADR-068 — no Appian environment write tool.
- [OK] ADR-077 — no agent-system change.
- [OK] ADR-078 — library items run Draft → Ready → Retired with retire-not-delete; delete only for never-used items
  (`delete` checks `where_used` and `ever_referenced` before and inside the lock).
- [OK] ADR-080 — no package dependency change.
- [N/A] L-003, L-018 — no SSE change.
- [OK] L-004 — catalog in SQLite.
- [OK] L-017 — `segment`/`heal` get no MCP servers (`required_mcp: []`).
- [N/A] L-019 — no secret write.
- [OK] L-025/L-027 — ruff pinned 0.15.20 in both repos.
- [N/A] L-030, L-089 — no web bundle.
- [N/A] L-031, L-039, L-043, L-048, L-068, L-069, L-071–L-074, L-082, L-084–L-086, L-090, L-095 — not touched.
- [N/A] L-045 — no chat surface.
- [N/A] L-051, L-056, L-057, L-098, L-099 — release concerns (51-13); nothing committed or tagged yet.
- [OK] L-058 — `CaptureFinalizer` has live (`run.final` observer), startup (`reconcile`) and on-read
  (`reconcile_capture`) paths; failures logged at error.
- [OK] L-061/L-062 — finalizes only the capture whose `run_id` equals the run and is still `analysing`
  (`finalize_run`), CAS `analysing → ready|failed`.
- [N/A] L-063 — no stage.
- [OK] L-064, L-075, L-076 — see above.
- [OK] L-083 — see above.
- [N/A] L-087, L-088, L-100 — not touched.
- [VIOLATION] L-091 — M1.
- [OK] L-092, L-093 (the finalizer relies on RunManager storing the terminal status first, 51-06), L-094.
- [OK] L-097 — `reap_stale` and `reap_stale_replays` run only when `manager.holds_run_owner_lock()` (`app.py` +309);
  `CaptureFinalizer._reconcile` fails a ghost run only under the lock.
- [OK] Gates: pytest 1602 passed; ruff clean; web gates N/A.

### genesis-workflows checklist (`genesis-ctx check --since 5a24d17 --repo genesis-workflows`)
- [OK] ADR-001 — the graph decides; `segment` only writes files.
- [N/A] ADR-003, 007, 015, 017 — no change of substance.
- [N/A] ADR-005, ADR-029 — no MCP/CLI registry entry.
- [OK] ADR-006 — self-contained folder (`workflow.yaml` + `graph.py`), `registry.json` entry 0.1.0.
- [OK] ADR-010/018/022 — see above; artifacts under the run folder.
- [OK] ADR-011, ADR-012, ADR-067, ADR-069 — see above.
- [OK] ADR-014 — META/YAML parity checked by the gate and `test_meta_mirrors_the_yaml_and_every_agent_wears_the_trio`.
- [OK] ADR-019 — no core pin change.
- [N/A] ADR-020 — no Kiro config written.
- [OK] ADR-021 — see above.
- [N/A] ADR-026, 030, 031, 033, 036–039, 041, 045, 046, 048, 056–059, 061–063, 065, 068, 073–076, 080 — not touched.
- [OK] ADR-034 — the new skill is in `skills-registry.json` and passes `validate_skills`.
- [N/A] ADR-035 — no file input.
- [OK] ADR-077 — no agent-system change.
- [OK] ADR-078 — proposals land as Draft, Ready only with a passing replay at the code.
- [OK] L-006 — `graph:` topology node ids match (generate, segment, v_segment, replay, v_replay, replay_route, heal,
  v_heal, heal_route, reassemble, escalate, present).
- [OK] L-009 — async nodes, checkpointer-compiled graph.
- [OK] L-013 — `graph:` is a YAML-only key.
- [OK] L-017 — no MCP; skill tells the agent to use only Genesis-opened sessions.
- [OK] L-020 — `execution.recursion_limit: 120`.
- [OK] L-021, L-024, L-026, L-042, L-064, L-075, L-076 — see above.
- [OK] L-022 — no custom-reducer state keys; `from __future__ import annotations` is safe (docstring says so).
- [OK] L-023 — `_coerce_list`, `_load`, defensive `replay_outcome`.
- [OK] L-025/L-027 — ruff pinned.
- [N/A] L-029, L-049, L-053 — no managed MCP or Appian credential.
- [N/A] L-030, L-051, L-056, L-057, L-087–L-089, L-098–L-100 — no release step.
- [OK] L-033 — readiness does not check that `action-capture` is installed, but a failing `RunManager.start` marks
  the capture `failed` with the reason (`_analyse`), so a missing workflow does not 500. 51-10/51-13 should add the
  install check to readiness.
- [OK] L-092 — no `tests/__init__.py`.
- [OK] Gates: validate_library PASSED, validate_skills PASSED, pytest 343 passed, ruff clean.

### Spec §8 tests
Save/typecheck/commit, refused breaking contract, retire refused with names, delete only if never referenced, revert,
outside edit → adopt (also a change committed outside Genesis), the generator-contract checks, lib/ + template case +
setup → 51-06 generator → real Playwright (3 expected, 0 unexpected), D20 demote via audited `changed` on save,
revert and adopt, metadata-only keeps status, Replay pass re-approves and fail leaves Draft, refs rebuild from
scan-refs, recording start/stop with a stubbed apwt on real fixtures, action-capture node tests, validator rejects bad
proposals, apply in one commit, Ready vs Draft, validate gates — **all present**. Missing: the `change()` undo path
(M2), the multi-update apply failure (m1), a stop/refresh race (M1).

## Deviations the author asked me to judge

1. **Separate `LIBRARY_TRANSITIONS`** — accepted; it is the L-094-correct choice (above).
2. **D20 audit reason does not name the commit** — not acceptable silently: D20 is a user decision and says "reason
   names the new commit". See m3; it needs your decision (options below), not necessarily a migration in 51-07.
3. **Item-page replay in the app process, no `TE-` row; capture replay with no ExecutionStore row** — accepted as a
   reading of "kind adhoc, not shown in Executions"; it is a subprocess, not workflow Python (ADR-012 holds). It needs
   the guards in m5 before 51-10 exposes it.
4. **Replayed code carries `ACT-NEW`; apply records the replay at the committed hash** — accepted. `apply` checks
   `sha256(code) == code_sha256` of the replayed file (`proposals.py` `_replayed_at_code`), and the only rewrite is the
   quoted key literal (`create_many` replaces `'ACT-NEW'`/`"ACT-NEW"`). `update` proposals commit byte-identical code.
5. **Setups and a scenario's first case navigate themselves** — accepted; templates (`setup_template`,
   `case_template`) and the skill (§2 line 83) say so; the real-Playwright test exercises it.
6. **Proposal code inline on the capture row** — accepted (above).
7. **One real workspace per test session with `npm ci --prefer-offline`** — accepted; the full suite ran in 386 s here
   with no skips.

## Findings

### Blockers
None.

### Majors
- **M1 — `RecordingService.stop` / `refresh` / `discard` are check-then-act with no serialization (L-091).**
  `recording.py` `stop`: `if cap["status"] != "recording": return cap` → `record_stop` → `reap` → `_analyse` →
  `RunManager.start` → only then `set_status(..., expected_status="recording")`. `refresh` calls `stop`. A Stop
  click while the UI polls `refresh` (the normal 51-11 pattern) runs both bodies: two `record stop` calls and **two
  `action-capture` runs**; the loser's `set_status` raises `StaleWriteError` after its run started, so that run (agent
  turns, credits, a QA replay that writes app data) is an orphan whose result `CaptureFinalizer` never stores
  (`cap.run_id != run_id`). `discard` racing `stop` can likewise start a run for a discarded capture. **Fix:** hold
  `RecordingService._lock` (or a per-capture lock) across the whole `stop`/`refresh`/`discard` body and re-read the
  capture inside it, so the status check and the run start are one critical section; add a two-thread test (stop +
  refresh at once → exactly one `RunManager.start`).
- **M2 — the `TestWorkspace.change` undo path has no test.** The brief and the docstring promise "commit undo when
  after_commit fails"; it is the guarantee that git and the catalog never disagree after a failed catalog write, and
  every create/save/revert/adopt/delete/apply relies on it. My probe shows it works today, but nothing in
  `tests/test_testexec_library.py` exercises a raising `after_commit` (grep: no `after_commit`/undo test). **Fix:** a
  test that makes the catalog write fail (e.g. a `StaleWriteError` from `store.update`, or a monkeypatched
  `after_commit`) and asserts HEAD unchanged, the file bytes restored, a clean `git status`, and the catalog row
  unchanged (and, for `create`, the allocated row deleted).

### Minors
- **m1 — a multi-item proposal apply is not atomic on the catalog side.** `create_many.after_commit` runs
  `_apply_save` per update; `_apply_save` compensates only its own writes. If a later update raises (stale
  `row_version`: `save()` metadata edits do not take the workspace lock; or the `changed` precondition, m2) or
  `on_commit` raises (`record_replay`/`approve`/`set_status`), `change()` undoes the commit and the outer `except`
  deletes the created rows, but the earlier updates' new `content_hash`/contract/refs, their `changed` audit row and
  Draft status, and any `record_replay`/`approve` stay. The catalog then names code that is not in HEAD (`status()`
  shows `changed`). **Fix:** compensate every completed update (and its replay/approve) in `create_many`'s `except`, or
  run the catalog half in one DB transaction; add a test with two updates where the second fails.
- **m2 — `_apply_save` can refuse a legitimate adopt.** It demotes whenever the item is Ready and the hash changed. If
  the new code already has a passing replay (someone committed outside Genesis, then ran Replay, which replays HEAD and
  records `passed` at HEAD's hash), the `changed` precondition (`not replay_passed_at_hash`) fails →
  `PreconditionFailedError` → the adopt is rolled back and cannot succeed. **Fix:** skip the transition when
  `store.lifecycle_context(...)["replay_passed_at_hash"]` is already true for the new hash (the item stays Ready).
- **m3 — D20 audit reason (deviation 2).** `lifecycle_transitions` (m0013) has no reason column and `LifecycleEvent`
  has no reason field, so the audit row says `changed` + actor + time; the commit is only findable by `git log` on the
  item path near that time (library items have no `last_commit` column). **Your decision:** (a) accept for 51-07,
  record it in the As built, and add a backlog item for an additive `detail` column on `lifecycle_transitions`
  (m0027, ADR-050 extension, all kinds benefit); or (b) do that migration now in 51-07. I recommend (a): the change
  is cross-cutting and the commit is recoverable.
- **m4 — two copies of the replay generators with no parity test.** `genesis/testexec/replay.py` and
  `action-capture/graph.py` both define `replay_spec_ts` / `replay_config_ts` / `replay_outcome`; they already differ
  (`graph.py`'s `replay_outcome` adds `step_errors`). The genesis replay spec is only checked as text against a stub
  runner. **Fix:** a genesis test that loads `graph.py` standalone (importlib, as the 46 backlog-renderer parity test
  does) and asserts identical `replay_spec_ts`/`replay_config_ts` output for the same steps.
- **m5 — the item-page replay has no guard, cancel or retention.** `TestLibraryService.replay` blocks up to
  `REPLAY_GLOBAL_TIMEOUT_S` (900 s) plus the runner's margin, allows any number at once, and leaves report/trace
  folders under `<artifacts>/library-replays/` that no retention prunes. Backlog item 12 covers only the reap. **Fix:**
  extend item 12 (or 51-10's spec) with one-replay-per-item, a cancel, and retention of `library-replays/`.

### Nits
- **n1** — `change({path: None})` for a path that is neither tracked nor present fails with "git add failed:
  pathspec … did not match" (probe). `delete()` of a never-committed item whose file is missing hits it. Drop such
  paths from the `git add`.
- **n2** — a crash between `state_save` and the `finally` in `_launch` leaves `<ws>/.auth/rec-<id>.json`
  (git-ignored). `reap_stale` could delete `.auth/rec-*.json`.
- **n3** — spec §4.1 names the saved login `.auth/<capture-id>.json`; the code writes `.auth/rec-<id>.json`. Note it in
  the As built.
- **n4** — the recording evidence shows the reap killed only the recorder's group (`killed_pgids: [18886]`); Chromium
  (own group 18887) exited because its parent died (`ps_after_2s: []`). That meets §4.3, but say so in the As built:
  the browsers-folder marker did not cause a separate kill.

### Not verified (live)
A signed-in recording on the real QA site, and an `action-capture` run with a real Kiro `segment`/`heal` agent (the
workflow tests stub the agent). Both belong to 51-12. The local evidence (`scripts/spikes/51-07/evidence/library.json`,
`recording.json`) was read, not re-run.

## Verdict: NEEDS_CHANGES

Fix M1 (serialize stop/refresh/discard + a race test) and M2 (a test of the `change()` undo path). m1–m5 should be
fixed or moved to the backlog with the As built naming them; m3 needs the user's choice.

---

## Re-review (genesis-review, 2026-11-03) — same bases, still uncommitted

genesis HEAD is still `ee1b77c`, genesis-workflows HEAD `5a24d17`; both trees uncommitted. I read the changed code
(`recording.py`, `library_service.py` `create_many`/`_restore_item`/`_apply_save`, `workspace.py` `change`,
`testexec_store.py` `remove_uncommitted`) and the new tests. Probe scripts are in `/tmp/51-07-rr/`; no repo file was
changed.

### Gates (run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/python -m pytest -q -p no:warnings` | **1609 passed** in 408 s, 0 skipped (the m4 parity test ran against the sibling checkout) |
| genesis `ruff check genesis tests/test_testexec_library.py tests/test_testexec_recording.py` | All checks passed (`ruff check tests` as a whole shows 26 old errors in files this change does not touch; CI lints `genesis` only) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **343 passed** |
| genesis-workflows `ci/validate_library.py` / `ci/validate_skills.py` | PASSED (16) / PASSED (4) |
| genesis-workflows `ruff check workflows/action-capture` | All checks passed |

### The first pass's findings

- **M1 — fixed.** `RecordingService._lock` is a class-level `threading.RLock`; `start`, `stop`, `refresh` and
  `discard` hold it, and `_stop`/`_refresh`/`_discard` re-read the capture inside it (`recording.py` `_stop`
  `cap = self._capture(capture_id)   # re-read inside the lock`). The test
  `test_stop_and_refresh_at_once_start_exactly_one_action_capture_run` bites: with the lock replaced by a no-op
  (pytest plugin `/tmp/51-07-rr/nolock.py`) it failed 5 of 5 runs (`StaleWriteError … expected 'recording' but found
  'failed'`); with the real lock it passed 5 of 5. L-091 for the recording is now OK.
- **M2 — fixed.** `test_a_failing_catalog_write_undoes_the_commit_and_the_file` makes `store.update` raise on the
  `content_hash` write and asserts HEAD, file text, `git status --porcelain -- actions setups cases` and the row
  unchanged for a save, and no file and no new key for a create. Matches my first-pass probe.
- **m1 — fixed for the case tested, but the fix brings a new bug (R-M1 below).**
  `test_a_refused_multi_item_apply_puts_every_updated_item_back` passes and shows the first update back at its hash,
  Ready, audit trail ending `changed → approve`.
- **m2 — fixed.** `_apply_save` skips `changed` when `lifecycle_context(...)["replay_passed_at_hash"]` is already true
  (`library_service.py` `_apply_save`); test `test_adopting_code_that_already_replayed_green_keeps_it_ready`.
- **m3 — accepted as option (a).** Backlog item 13 (`specs/backlog/phase-51-follow-ups.md` line 107) describes the
  additive `detail` column and `LifecycleService.transition(detail=)`. The As built must record the D20 deviation and
  the user must be told, as you said.
- **m4 — fixed.** genesis `replay_outcome` returns `step_errors`; `test_the_workflow_copy_of_the_replay_generators_
  matches_the_app` loads `graph.py` standalone and compares all three functions. It skips without the sibling
  checkout, so genesis CI will not run it; genesis-workflows CI does not run it either (see R-n2).
- **m5 — moved.** Backlog item 12 (line 97) now lists one-replay-per-item (409), a cancel and retention of
  `library-replays/`.
- **n1 — fixed.** `change()` stages only paths that are written, were present, or are tracked, and returns None when
  none are left; test `test_deleting_a_never_committed_item_whose_file_is_gone_works`.
- **n2 — fixed.** `reap_stale` deletes `<ws>/.auth/rec-<id>.json` of each interrupted capture; test
  `test_reap_stale_also_deletes_a_saved_login_left_by_a_crash`.
- **n3/n4** — to be noted in the As built. Not yet written; I will check it when it is.

### New findings

#### Majors
- **R-M1 — the m1 compensation can overwrite another save's catalog write and leave code that was never replayed
  marked Ready (an L-091 regression, introduced by the m1 fix).** `create_many` snapshots each update item
  *before* `ws.change` takes the workspace lock, and its `except` runs *after* `ws.change` has released the lock.
  `_restore_item` decides "did we touch it?" by comparing the current row with the snapshot, so it cannot tell its
  own writes from another writer's. Reproduced with `/tmp/51-07-rr/test_probe_m1_comp.py`: a Ready item; a save of
  the same item takes the workspace lock first (commits new code, demotes to Draft); the apply then loses its CAS
  (`StaleWriteError … expected 4 but found 6`) and compensates. Result: HEAD has the other save's code, but the
  catalog row has the **original** hash and status **ready** (the restore ran `approve` at the old hash), and
  `status(APP)` reports the item `changed`. Before the m1 fix the same sequence left the catalog correct, because
  `_apply_save` compensated only its own writes and its CAS failed before it wrote anything. The window is the time
  the apply waits for the workspace lock, which a typecheck or an execution's regenerate-and-commit can make seconds
  long.
  **Fix:** compensate only what this apply wrote, and do it inside the lock. For example, keep a list of the update
  items whose `_apply_save` returned (and whether `on_commit` recorded a replay or approved them), wrap the body of
  `after_commit` in `try/except`, and restore that list there, before re-raising into `change()`'s undo. A failure
  before `after_commit` (checks, typecheck) then restores nothing. Use the `row_version` that `_apply_save`/`on_commit`
  left as the CAS for the restore, not a fresh read. Keep the created-row removal as it is. Add the probe scenario as
  a test: a concurrent save wins the lock, the apply is refused, and the row matches HEAD (hash and status of the
  other save).

#### Nits
- **R-n1** — `_restore_item` does not clear a `last_replay` that `on_commit` recorded when the snapshot had none
  (`if old and old != now.get("last_replay")`), and re-recording an old replay stamps a new `at`. The item page could
  show a passing replay of code that is not in HEAD. Harmless to the Ready rule (the hash no longer matches), but
  clear it, or store `last_replay_json` back verbatim.
- **R-n2** — the m4 parity test runs only on a machine with both checkouts. Consider a copy of the check on the
  genesis-workflows side (it can import `genesis.testexec.replay` from its pinned genesis), so a CI run catches drift.
- **R-n3** — in the M1 test, `gate.set()` is called right after the threads start, so `gate.wait(0.5)` widens nothing,
  contrary to its comment. The test still fails without the lock (above); drop the gate or set it after a short
  sleep so the comment is true.
- **R-n4** — a `remove_uncommitted` or restore of a created item's refs leaves `ever_referenced` set on existing
  targets that a refused commit referenced, so a never-used item can become undeletable after a refused apply. It
  predates this round (the single-create path does the same); worth a line in the As built or the backlog.

### Checklist changes since the first pass
- L-091 (recording) — VIOLATION → **OK** (M1 above).
- L-091 (library apply) — **VIOLATION** (R-M1): check-then-act outside the workspace lock in the new compensation.
- Every other checklist line is unchanged from the first pass; the new code adds no ADR surface (no route, no
  migration, no web change; `remove_uncommitted` is a store method in `genesis/kb/`, ADR-030 OK).

## Re-review verdict: NEEDS_CHANGES

Fix R-M1 (compensate only this apply's own writes, inside the workspace lock, with a test of the concurrent-save
case). M1, M2, m2, m4, n1 and n2 are fixed; m3 and m5 are in the backlog; the nits are optional. Write the As built
with n3, n4, the m3 deviation and R-n4 before the next pass.

---

## Third pass (genesis-review, 2026-11-03) — same bases, still uncommitted

genesis HEAD is still `ee1b77c`, genesis-workflows HEAD `5a24d17`; both trees uncommitted. I read the changed code
(`library_service.py` `create_many`/`after_commit`/`_restore_item`/`_apply_save`, `testexec_store.py`
`restore_replay`/`remove_uncommitted`, `workspace.py` `change`), the new tests, the As built and backlog items 9–14.
Probes are in `/tmp/51-07-rr3/` and `/tmp/51-07-rr/`; no repo file was changed.

### Gates (run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/python -m pytest -q -p no:warnings` | **1610 passed** in 435 s |
| genesis `ruff check genesis tests/test_testexec_library.py tests/test_testexec_recording.py` | All checks passed |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **344 passed** |
| genesis-workflows `ci/validate_library.py` / `ci/validate_skills.py` | PASSED (16) / PASSED (4) |
| genesis-workflows `ruff check workflows/action-capture` | All checks passed |

The author's numbers match.

### The re-review's findings

- **R-M1 — fixed.** `after_commit` (run by `TestWorkspace.change` under `path_lock`, `workspace.py` `change`) now reads
  each update item's row and refs right before `_apply_save` writes it, appends to `applied` only after
  `_apply_save` returns, and on any later failure restores `reversed(applied)` before re-raising into `change()`'s
  undo (`library_service.py` `after_commit`, the `applied` list). The outer `except` only calls `remove_uncommitted`
  for this call's created rows. In the concurrent-save case the apply's `_apply_save` CAS uses the row version read
  before the lock (`item["row_version"]` or the caller's `expected_row_version`), so it fails before writing, the item
  is never in `applied`, and nothing is restored. `test_a_refused_apply_never_overwrites_a_concurrent_save` is my
  probe as a test and asserts the file, hash, Draft status and an empty `status()`. The m1 test still passes
  (first update back at its hash, Ready, trail `changed → approve`). L-091 for the library apply: **OK**.
- **R-n1 — fixed.** `TestLibraryStore.restore_replay` writes `last_replay_json` back verbatim or NULL;
  `_restore_item` calls it whenever the replay differs. Probe `test_probe_on_commit_replay_is_cleared`: an item with
  no replay, `on_commit` records a passing one and raises → after the restore `last_replay` is `None`, the hash is the
  old one, status Draft, `status()` empty.
- **R-n2 — fixed.** `test_the_replay_generators_match_the_platform_copy` compares all three generators with
  `genesis.testexec.replay` in genesis-workflows (it ran in the 344). It imports a module that the current pin
  (`genesis.git@v0.80.0`, `pyproject.toml` dev extra) does not have; the same test file already imports Phase 51
  modules (`genesis.kb.testexec_store.TestSettingsStore`), so the release must move the genesis-workflows pins to the
  Phase 51 genesis tag in any case (L-057). A note for 51-13, not a finding.
- **R-n3 — fixed.** `test_testexec_recording.py` sleeps 0.2 s after starting the threads, then opens the gate. With
  `RecordingService._lock` replaced by a no-op (`RR_NOLOCK=1`, plugin `/tmp/51-07-rr/nolock.py`) the test failed
  5 of 5 runs; with the real lock it passes.
- **R-n4 — recorded** as As built decision 11 and backlog item 14.
- **As built** — written. It covers n3 (decision 9), n4 (the live evidence paragraph), the m3/D20 deviation for the
  user (decision 2, backlog 13), R-n4 (decision 11) and the points for 51-08..51-11 (bold decisions 3, 5, 7, 8).
  Commit shas and final gate numbers are still to be added after the commit, as stated.

### New findings

#### Nits
- **T-n1 — `_restore_item` uses a fresh `row_version`, so a metadata-only save that lands inside the window is
  overwritten.** `save(fields=…)` does not take the workspace lock. Probe `test_probe_metadata_edit_inside_the_window`:
  `on_commit` renames the item through `svc.save(…, fields={"name": …})` with no `expected_row_version`, then raises;
  after the restore the name is the old one and the rename is gone silently. The window is one `after_commit` (the
  later `_apply_save` calls and `on_commit`), and there is no route yet. 51-10 should make every metadata save pass the
  page's `expected_row_version`; such a save then loses its CAS against the apply's own write instead. Optional
  hardening: restore with the `row_version` the apply's last write left (from the `SaveResult`, bumped by what
  `on_commit` wrote) and let a mismatch log and skip.
- **T-n2** — the As built's "Commits" bullet says backlog items 9–13; there are 9–14. In the R-n2 test, `os.unlink`
  is not in a `finally` (a failed assert leaves a temp file).

### Checklist changes since the re-review
- L-091 (library apply) — VIOLATION → **OK** (R-M1 above).
- Every other line is unchanged; this round adds one store method (`restore_replay`, in `genesis/kb/`, ADR-030 OK)
  and tests. No route, migration or web change.

## Third pass verdict: SHIP

No blockers or majors remain and every gate is green. Before or with the commit: add the commit shas and final numbers
to the As built, and fix the "9–13" count. The user still has to confirm the m3/D20 deviation (As built decision 2) or
ask for the migration; that is a decision, not a code change. T-n1 goes to 51-10 (always pass `expected_row_version`).
