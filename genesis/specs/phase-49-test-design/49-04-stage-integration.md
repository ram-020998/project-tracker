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
4. `TestDesignStore.create_from_design(...)` with `resolve_object` = 49-05 §2 (R3). One transaction; ids in document
   order (F10). Write `upstream_json` from the launch snapshot.
5. Then (outside the tx, idempotent) run the D7 implementation linker for every linked story already implemented
   (F5; 49-05 §3).
6. Return the suite tree + `{dropped_story_keys, dropped_steps, dropped_scenarios}` so the UI can report them.

## 6. Top-up apply (`apply_topup(topup_id, accepted_refs)`)

`ready` only (else 409). `proposals.json` shape as built (49-03 As built): `items[]` plus `metadata`, `openQuestions`,
`storySuggestions`; a proposed case's ref **is** its `p-N`, and a `new_scenario` step or an `add_step` that uses it names
that same `p-N`; `add_step.position` is **1-based** (the 49-02 store's step positions are 1-based too); never assert an
exact `metadata.sources` list (it may include `"uploaded-docs"`). Expand dependencies: an accepted
`new_scenario`/`add_step` whose referenced `new_case` was not accepted → rejected with reason "depends on p-N". Resolve
objects (R3), call `TestDesignStore.apply_topup`, run the D7 linker for affected stories. `discard_topup(topup_id)` →
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
