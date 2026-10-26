# 49-04 — Stage integration: start, finalizer, completion chat, Finalize, top-up, CSV

> **Status:** SPEC-DRAFTED 2026-10-26. Repo: **genesis** (backend services; routes in 49-06). Parent:
> `specs/phase-49-test-design.md`. Decisions: 49-01 D1, D4, D11, D16; F1–F3, F5, F10, F11; R3–R5.

## 1. Goal

Plug `test_design` into the existing stage framework the way Feature Breakdown was plugged in (Phase 31: one stage key,
one `_Binding`, one `ChatModeProfile`, start/re-run — `49-01-findings.md` §2.1), plus the Finalize, top-up and CSV
services. Business logic lives in a service module (`genesis/genesis/services/testdesign_stage.py`, R6) so 49-06's
routes stay thin.

## 2. Stage registration

- `StageStore.VALID_STAGES` += `"test_design"` (`genesis/genesis/kb/stages.py:34`); `ArtifactKind.TEST_DESIGN =
  "test_design"` (`genesis/genesis/domain/enums.py:51`). No stage migration (m0015 is generic). Lifecycle = the shared
  stage machine (`SPEC_TRANSITIONS`).
- `_STAGE_ARTIFACT_FILE["test_design"] = "test-design.html"` (wherever `features.py` maps stage → file).
- **Prerequisite (F2):** `test_design_prereqs_ready(feature_id) -> (bool, why)` = `kb_features.stories_finalized_at IS
  NOT NULL` and the feature has ≥ 1 non-deleted Story-type story; message "Stories must be finalized before Test Design
  can start". Enforced by the start/re-run/top-up services (→ 409 in 49-06) and mirrored in the web (49-07) (L-063).
- **R5:** once `kb_test_suites.finalized_at` is set, re-run → 409 "test design is finalized — use Generate tests for
  uncovered stories"; the stage lifecycle `reopen` gets `downstream_locked=True` in its ctx (the existing precondition,
  `genesis/genesis/domain/transitions.py:46-49`) so Reopen is refused.

## 3. Launch (`launch_test_design(row, feat, notes, files, *, mode, targets=None)`)

Model on `_launch_breakdown` (`genesis/genesis/api/features.py:981-1031`):

1. Snapshot into `settings.feature_stage_artifacts_dir/<stage_id>/`: `spec_snapshot.html`, `ux_snapshot.html`,
   `td_snapshot.html` (via `_consumer_html`; normalize the spec first like 46-03), `stories.json` (49-03 §4.1, from
   `StoryStore`), and in top-up mode `existing.json` (49-03 §4.3, from `TestDesignStore.suite_tree`).
2. `run_manager.start("test-design-analysis", inputs, files={"doc1".."doc3"})`; `FileNotFoundError` → 409 "the
   test-design-analysis workflow is not installed; run `genesis install`" (L-033); any other launch error → 409, never
   a bare 500.
3. Design mode: `stages.set_source(row_id, run_id=…)`, status → `in-progress`; store the story fingerprints read
   (`upstream_json` is written later on the suite at Finalize from this snapshot — keep the snapshot file).
   Top-up mode: insert a `kb_test_topups` row (`running`, `target_story_ids`, `run_id`); the stage row is **not** touched.
4. Guards: design start with an existing completion chat → 409 "use re-run"; with a bound active run → 409; a second
   running top-up for the feature → 409.

## 4. Run → artifact

- `StageFinalizer._BINDINGS["test-design-analysis"] = _Binding(stage="test_design", artifact="test-design.html",
  chat_mode="test_design", title_default="Test Design", seed=_seed_test)` (`genesis/genesis/chat/stage_finalizer.py:161`).
  The finalizer must **skip top-up runs** (input `mode == "topup"`): those are handled by §6. Keep its existing
  guards: stage-match, currently-bound run only, idempotent, level-triggered reconcile (L-058, L-061, L-062).
- `_seed_test`: like `_seed_fb` — the document is `test-design.html` in the working directory; walk the Open Questions;
  refine cases/scenarios with the user; **keep the visible cards and the embedded `<script id="genesis-test-design">`
  JSON in sync**; JavaScript-free single document; re-check the KB only when asked.
- `ChatModeProfile("test_design", mcp_mode="read_only", permission_mode="auto_deny", cwd_sandbox=True,
  extra_trust=("fs_read","fs_write"), steering=_STEERING_TEST)` (`genesis/genesis/chat/mode_profile.py:213`).
  `_STEERING_TEST` is the only new agent prompt on the genesis side: the test model (suite → scenarios of ordered case
  refs → reusable cases), the field rules (D3), never invent `TC-`/`TS-` ids (only `ref`s), keep JSON ↔ HTML in sync,
  read-only (ADR-031/045).
- Top-up runs: a small observer in the same service (or a second finalizer class following the `StageFinalizer`
  pattern) moves the `kb_test_topups` row to `ready` with `proposals_json` read from the run's `proposals.json` on
  `run.final` done, to `failed` on error; plus startup reconcile (L-058).

## 5. Finalize (`finalize_test_design(feature_id)`)

1. Stage `test_design` must be `completed` → else 409. Suite already finalized → 409.
2. Parse the embedded JSON from the **current** stage HTML (`_current_stage_html`, L-073); missing/garbled or zero cases
   → 422. The parser must **not depend on attribute order**: 49-03 emits
   `<script id="genesis-test-design" type="application/json">` (`id` first), unlike the breakdown block that
   `_BACKLOG_RE` expects with `type` first (`features.py:75-88`) — match on the `id` attribute (BeautifulSoup is already
   a pinned dependency, ADR-075) or an order-independent regex.
3. **Pre-clean, then write** (49-02 As built: `create_from_design` refuses the *whole* document on an unknown story key,
   an unknown step reference or a scenario with no steps). In this order: drop unknown story keys from cases (a case
   left with no story is kept — *no linked story*); drop steps whose case ref no longer exists; then **drop scenarios
   left with no steps**. Report all three lists. Validate the remaining shape with the `v_cases`/`v_scenarios` rules.
4. `TestDesignStore.create_from_design(...)` with `resolve_object = TestImpactService.resolver()`
   (`genesis/genesis/services/testimpact.py:166`; R3). One transaction; ids in document order (F10). Write
   `upstream_json` from the launch snapshot.
5. Then (outside the tx, idempotent) call `TestImpactService.link_feature_implemented(feature_id)`
   (`testimpact.py:238`) for stories already implemented (F5; 49-05 §3).
6. Return the suite tree + `{dropped_story_keys, dropped_steps, dropped_scenarios}` so the UI can report them.

## 6. Top-up apply (`apply_topup(topup_id, accepted_refs)`)

`ready` only (else 409). `proposals.json` shape as built (49-03 As built): `items[]` plus `metadata`, `openQuestions`,
`storySuggestions`; a proposed case's ref **is** its `p-N`, and a `new_scenario` step or an `add_step` that uses it names
that same `p-N`; `add_step.position` is **1-based** (the 49-02 store's step positions are 1-based too); never assert an
exact `metadata.sources` list (it may include `"uploaded-docs"`). Expand dependencies: an accepted
`new_scenario`/`add_step` whose referenced `new_case` was not accepted → rejected with reason "depends on p-N". Resolve
objects with `TestImpactService.resolver()` (R3), call `TestDesignStore.apply_topup`, then
`TestImpactService.link_feature_implemented(feature_id)`. Use the shared service instance (49-05 As built), not a new
one per call. `discard_topup(topup_id)` →
`discarded`. Created records are **Ready** (D15), origin `topup`; their object links keep origin `design` (49-02 As
built — `topup` is not an object-link origin). Use the shared contract fixtures in
`genesis-workflows/workflows/test-design-analysis/tests/fixtures/` as the golden inputs for these tests (L-011).

## 7. CSV export (`suite_csv(feature_id) -> str`) — D16

stdlib `csv`; header `Test Case ID, Title, Given, When, Then, Type, Priority, Status, Automation Status, Stories,
Scenarios, Objects`; one row per case (retired included, status says so) in suite order; multi-line Gherkin joined with
`\n` inside the quoted cell; `Stories` = `GNS_` keys `; `-joined; `Scenarios` = `TS-000002#3` (key # position) entries
`; `-joined; `Objects` = `Name (Type)` `; `-joined with `[unresolved]` where applicable. Filename `<feature>-tests.csv`
sanitized like the Jira export (`features.py:1196`).

## 8. Tests

Prereq gate (not finalized → refused; finalized → ok); re-run/Reopen refused after test Finalize (R5); launch writes the
snapshots + `stories.json` in the 49-03 §4.1 shape (golden fixture shared with the workflow tests — L-011); not-installed
→ 409; finalizer binding finalizes a design run and **ignores** a top-up run; Finalize happy path, 409s, 422s, dropped
keys reported, document-order ids; top-up lifecycle running → ready → applied/discarded, dependency rejection, failed
run → failed; CSV header + a multi-line Gherkin + an unresolved object row round-trip through `csv.reader`.

## Context manifest

```toml
areas    = ["features-stages", "chat"]
adrs     = ["ADR-031", "ADR-035", "ADR-042", "ADR-045", "ADR-050", "ADR-056", "ADR-058", "ADR-059", "ADR-060", "ADR-072"]
lessons  = ["L-033", "L-041", "L-042", "L-058", "L-061", "L-062", "L-063", "L-073", "L-011"]
code     = ["genesis/genesis/services/testdesign_stage.py", "genesis/genesis/kb/stages.py", "genesis/genesis/domain/**",
            "genesis/genesis/chat/stage_finalizer.py", "genesis/genesis/chat/mode_profile.py", "genesis/genesis/api/features.py"]
docs     = ["tracker:specs/phase-49-test-design/49-01-findings.md", "tracker:specs/phase-49-test-design/49-03-workflow.md"]
upstream = ["49-02", "49-03", "49-05"]
```

## As built (genesis-dev, 2026-10-26)

**Commits:** genesis `a8ba5b8`, "feat(features): 49-04 Test Design stage integration — start/re-run, StageFinalizer
binding, test_design chat mode, Finalize, top-up, CSV" (base `454db1f`, the 49-05 commit). Local only; nothing was
pushed or tagged. No other code repo changed.

**Changed**
- `genesis/services/testdesign_stage.py` (new). `TestDesignStageService(settings, *, run_manager, test_impact)`:
  `prereqs_ready`, `is_finalized`, `start`, `rerun`, `launch_test_design(row, feat, notes, files, *, mode, targets)`,
  `finalize_test_design`, `start_topup`, `latest_topup`, `reconcile_topup`, `reconcile_topups`, `settle_topup`,
  `apply_topup`, `discard_topup`, `suite_csv`, `suite_csv_filename`. It also holds `TopupRunObserver`, the errors
  `TestDesignError` → `TestDesignNotFoundError` (404), `TestDesignConflictError` (409) and `TestDesignInvalidError`
  (422, or 400 for more than 3 docs), each with a `.status`, and the pure helpers `parse_embedded_test_design`,
  `clean_design`, `validate_design`, `expand_topup_decisions`, `suite_csv_rows`, `csv_filename`, `stories_document`,
  `existing_document`. `services/__init__.py` exports the service, the observer and the errors.
- `api/app.py` builds ONE `TestDesignStageService` over the shared `app.state.test_impact` (as the user asked:
  `resolver()` for Finalize and top-up apply, then `link_feature_implemented(feature_id)` after each). It exposes it as
  `app.state.test_design`, attaches `TopupRunObserver`, and runs `reconcile_topups` at startup via
  `asyncio.to_thread` (L-026).
- Stage registration: `StageStore.VALID_STAGES` += `test_design`; `ArtifactKind.TEST_DESIGN`;
  `stage_artifacts.STAGE_ARTIFACT_FILE["test_design"] = "test-design.html"` (this is the map features.py uses);
  `chat/store.py` `STAGE_CHAT_MODES` += `test_design`.
- `chat/stage_finalizer.py`: `_Binding` gains `skip_modes`. The new `test-design-analysis` binding (stage
  `test_design`, artifact `test-design.html`, chat mode `test_design`, `_seed_test`) skips `mode == "topup"` runs. All
  existing guards are kept.
- `chat/mode_profile.py`: the `test_design` `ChatModeProfile` (read_only, auto_deny, cwd sandbox, fs_read/fs_write)
  and `_STEERING_TEST`.
- `services/spec_change.py` `stage_ctx`: for `test_design`, `downstream_locked` = the suite is finalized (R5). Reopen
  is then refused and not offered.
- `services/stage_artifacts.py`: `spec_version()` is the shared copy of `features.py`'s `_spec_version`, which now
  delegates to it.
- `kb/testdesign.py`: additive reads `topup_for_run(run_id)` and `list_topups(feature_id=None, *, status=None)`.
  `get_topup` shares `_topup_dict` with them (L-039).
- `collab/service.py` (review m1): `LOCAL_ONLY_STAGES = {"test_design"}`. `publish()` refuses such a stage, adoption
  leaves it out, and a pulled one is skipped (cursor advances, L-082). This enforces 49-01 D12.

**Tests:** `tests/test_test_design_stage.py` has 44 tests over the real app (`create_app`). Runs are real `RunRecord`s
and are ended through the real `RunManager._finalize`. They cover every §8 item plus the D12 guards.
`tests/test_chat_mode_profile.py` has +1 posture test. The 49-03 golden fixtures are vendored byte-identically into
`tests/fixtures/test_design_contract/`, with a drift test that skips when the sibling checkout is absent (L-011).
Genesis suite: **1311 passed** (was 1266). `ruff check genesis` is clean.

**Review:** genesis-review, `reviews/49-04-review.md`. Round 1: **SHIP** with m1–m3 and n1–n5. I fixed m1 (D12), n1
(exact `id` match) and n2's message part. The re-review was **SHIP** with no new findings. m2 and m3 are recorded
below. n3–n5 are recorded decisions.

**Decisions / deviations** (no ADR deviation):
1. No routes here. 49-06 maps the `TestDesignError` family via `.status` and calls every method off the event loop.
2. **Top-ups settle on the `run.final` payload status.** `RunManager._finalize` calls the observers before it writes
   the run status (`runs/manager.py:134-140`), so re-reading `rec.status` in a live observer sees `running`. The
   reconcile paths use the run record.
3. `start` refuses: prerequisites (F2); a finalized suite (R5); an existing completion chat ("use re-run"); a bound run
   that is still active, or done whose document is not open yet. A failed or cancelled bound run does not block a fresh
   start. Draft → in-progress goes through the stage `LifecycleService` (`start`). `rerun` mirrors the breakdown
   (`reset_for_reupload`) and also has no active-run guard (n2, same as breakdown/TD).
4. Finalize reads `current_stage_html` (sandbox first, L-073). The block is matched on `id` whatever the attribute
   order. The pre-clean order is: unknown story keys, then steps to unknown cases, then empty scenarios. A case left
   with no story is kept. `validate_design` enforces title, ≥ 1 when and ≥ 1 then, type, priority, object name and
   type, and unique refs, and reports them as 422. Dropped lists: `dropped_story_keys: [{case, story_key}]`,
   `dropped_steps: [{scenario, case, position}]`, `dropped_scenarios: [{scenario, title}]`. The result also carries
   `links` (the `link_feature_implemented` counts, or null if linking failed; it is best-effort and logged).
5. `upstream_json` = the launch snapshot `<stage_dir>/upstream.json`: `{run_id, mode, spec: {revision_no,
   content_hash}, stories: {GNS_key: fingerprint}}`.
6. Top-up: target ids must be Story-type stories of the feature (a Task → 422). Stale `running` rows are reconciled
   before the "already running" guard. Snapshots go to `<stage_dir>/topups/<hex>/`, so the design snapshot is never
   overwritten. `existing.json` holds non-retired records only (49-03 §4.3; the fixture's retired case is a workflow
   test input). Apply also rejects an item whose step names a TC-/TS- that is no longer live. `decisions_json` =
   `{accepted, rejected: [{ref, reason}]}` with reasons `rejected` / `depends on p-N` / `… is not a live …`. A done run
   without a readable `proposals.json` → `failed`.
7. CSV: the Scenarios column lists non-retired scenarios only. Cells are not escaped against spreadsheet formulas,
   consistent with the Jira export (n3).
8. The steering adds one rule beyond §4: in the embedded JSON, write `<` as `\u003c` (the 49-03 convention), so a
   chat edit cannot end the `<script>` early.

**Hand-offs**
- **49-06 (m2):** a dedicated test-design status/read GET must call `StageFinalizer.reconcile_stage` (the generic
  feature and stage GETs already do), or the stage stays "in progress" after the run ends (see the m3 backlog item).
  Register `/stages/test_design/start|rerun|finalize` BEFORE the generic `/stages/{stage}/start|rerun` in
  `features.py`, or the generic route (TD only → 400) catches them. Map `ConflictError` from the store to 409, and
  the `ValueError` from a collab publish of a test-design stage is already a 409 there.
- **49-07:** `latest_topup` reconciles on read, so polling it is enough to see `ready`/`failed`.
- **49-08:** run the fixture drift test once with both repos checked out (n4).
- **Backlog (m3, pre-existing, needs the user's sign-off):** every run→artifact finalizer's live path is a no-op.
  `StageFinalizer`, `StoryDesignFinalizer` and `StoryImplementationFinalizer` return on `rec.status != "done"` inside
  `_observe`, but the status is written after the observers run. Stages finalize only on the next read or at startup.
  The existing tests call `_finalize` after a manual `set_status("done")`, which hides it. Fix: pass the payload status
  into `_finalize`, or write the status before emitting `run.final`, plus a regression test through
  `RunManager._finalize`.
- **Backlog (n3):** formula escaping for both CSV exports. **(n5):** a DB guard for one running top-up per feature,
  for the Hub phase.

**Lesson candidates**
- An observer that bridges a run's end into app state must take the terminal status from the event, not re-read the
  run store: `RunManager` notifies observers before it writes the status. Test such bridges through the real
  `RunManager._finalize`, not by setting the status by hand and calling the bridge.
- Adding a value to a generic registry (`VALID_STAGES`) silently opts it into every consumer of that registry (here
  the Hub publish, adoption and pull). Grep the consumers when you add one.

**Code-map changes:** `services/` gains `testdesign_stage.py` (`TestDesignStageService`, `TopupRunObserver`).
`chat/stage_finalizer.py` binds `test-design-analysis` (skips top-ups). `chat/mode_profile.py` adds `test_design`.
`kb/stages.py` adds the `test_design` stage. `collab/service.py` adds `LOCAL_ONLY_STAGES`. `api/app.py` wires
`app.state.test_design`. `services/stage_artifacts.py` exports `spec_version`.
