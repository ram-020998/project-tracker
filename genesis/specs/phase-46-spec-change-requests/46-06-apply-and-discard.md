# 46-06 — Apply changes and Discard change request

> **Status:** ✅ BUILT + SHIPPED (genesis v0.77.0 / genesis-workflows v0.22.0, 2026-10-15; as-built in `progress/phase-46-spec-change-requests.md`) — drafted 2026-10-14. Repos: **genesis** (+ a parity test in **genesis-workflows**). Implements the
> commit half of **ADR-076**. Parent: `specs/phase-46-spec-change-requests.md`. Decisions D7, D8, D12–D14.

## 1. Goal

**Apply changes** executes the agreed plan — exactly the plan shown in the CR document — atomically, then records it
everywhere. **Discard change request** abandons the CR without touching any story. Both return the spec to
**Completed**. One service owns both: `genesis/services/spec_change.py::SpecChangeService`.

## 2. `POST /features/{id}/change-requests/{cr_no}/apply`

Body: `{ "confirm_locked_story_ids": [57] }` — the IDs of **locked** stories (Design Review or later) the plan
changes at the user's request; the web collects them in the confirm dialog (46-07 §5). Response: the apply report
(§8) + the updated CR + spec.

## 3. Pre-checks (all must pass; otherwise 409 with `{error: "apply_blocked", blockers: [...]}` and nothing changes)

| # | Check | Blocker text (example) |
|---|---|---|
| A1 | CR is `open`; spec is `under-change` | "CR-03 is not open" |
| A2 | No chat turn is streaming in the spec session (and, in backlog mode, the breakdown session) | "Wait for the current chat turn to finish" |
| A3 | `analysis.state == current` (46-05 §6) | "The spec changed after the analysis — Analyze impact again" |
| A4 | `validate_plan` has no errors | "The plan has 2 problems — see the CR document" |
| A5 | Every story the plan mentions **still exists** and still has the `row_version` recorded in `impact-input.json`; every `follow_up_of` / `epic_id` still exists | "GNS_000041 changed or was deleted since the analysis — Analyze impact again" |
| A6 | No story the plan updates/removes has a design or implementation run `running` now | "A design run is running for GNS_000041" |
| A7 | `confirm_locked_story_ids` equals exactly the set of locked stories with `decision != no_change` | "Confirm the change to GNS_000057 (Implementation)" |
| A8 | Backlog mode: the breakdown HTML's content hash equals the one recorded at analysis | "The breakdown changed after the analysis" |

## 4. The apply transaction (stories mode)

Normalize the working `spec.html` (46-02) → `final_html`, `final_map`. Then **one SQLite transaction** (`Database.tx`):

1. **Spec revision:** insert revision `N+1` (`kb_feature_stage_revisions`, note "CR-03: <summary>") pointing at
   `revisions/<N+1>.html`; `set_html(html_path=<stage>/spec.html, content_hash)`.
2. **Updated stories** (`decision == update`): apply `changes` (full new value per field); `spec_refs`: add
   `add_spec_refs` + the decision's `clause_ids` that are new links, remove `remove_spec_refs`, **refresh the
   fingerprint** of every ref on a changed clause to `final_map`; `row_version += 1`.
2a. **Answers** (`answer_questions`, any decision except `remove`; on a locked story only with `user_requested`,
   46-05 V4): for each `{question, answer}` find the open question whose normalized text (46-02 §5) equals the
   plan's question; move it from `questions` to `answers` with `source:"cr"`, `cr_no:3`,
   `answered_by = canonical_username`, `answered_at = now`. If no open question matches, append the answer with the
   plan's question text anyway and list it under `answers_unmatched` in the apply report — never fail Apply for it.
3. **New stories:** `create_story` semantics inside the same transaction (`GNS_` key from `kb_sequences`), status
   `to-do`; `epic_id` from the plan; `spec_refs` = the story's `clause_ids` (`origin:"cr"`);
   **board membership:** `on_board = 1` if the followed-up story is on its board, or — for a story with no
   `follow_up_of` — if any story of the feature is on the board (umbrella Q3); a story with `on_board = 1` also gets a
   `kb_board_cards` row at the end of the To Do lane (as Import does); a feature with no board → `on_board = 0`.
   **Position:** with `follow_up_of`, `position = followed_up.position + 1` after shifting every story of the feature
   with `position > followed_up.position` by +1 (one `UPDATE` in the same transaction); without it, append
   (`MAX(position) + 1`, as `create_story` does). The `temp_id → story_id/key` mapping goes into the apply report.
4. **Removed stories** (`decision == remove`): a full snapshot of the row (all columns) is written to the apply
   report first; then `delete_story` (cascades its board card and story stages).
5. **Unchanged stories** (`no_change`, including locked ones): refresh the fingerprints of their refs on changed
   clauses (the link is reviewed — it no longer looks suspect).
6. **Change history:** append one `change_log` entry (46-08 §4) to every story the plan mentions **except removed
   ones** (they no longer exist; their snapshot is in the apply report), with decision `updated | created |
   unchanged | not_applied` — `not_applied` for locked stories left unchanged, so the story shows "The spec changed
   after this story moved past Design". The followed-up story's entry lists the new story under `follow_ups`.
7. **Story-design flags:** for updated stories in `design` whose design is `done`, the change_log entry carries
   `needs_design_rerun: true`.
8. **CR row:** `status = applied`, `result_revision_no = N+1`, `closed_by/at`, `summary_json` (counts).
9. **Spec status:** `under-change → completed` via the `LifecycleService` with `ctx.via_change_request = True`,
   **inside the same transaction** — implementation note: add a transaction-aware variant
   (`build_stage_lifecycle(stage_store, conn=c)` / `transition(..., conn=c)`) so the status write and the m0013 audit
   row commit with the story writes; never apply the stories and fail the status change (or vice versa).
10. **Downstream markers:** `upstream_versions_json` is not changed on UX/TD (their "spec changed" badge is derived,
    46-08 §5); in backlog mode the breakdown's consumed spec revision becomes `N+1` (it has been reconciled).

Any exception rolls back everything and the endpoint returns 409 `{error: "apply_failed", detail}` (never a bare
500); the CR stays open and can be retried.

## 5. After the transaction (best-effort, reported, never rolled back)

1. **Freeze files** in `dir_path`: `result.html`, `impact-input.json`, `plan.json`, `apply-report.json`, and
   `document.html` rendered with `status="Applied"` and the apply report (real `GNS_` keys replace `N1` …).
2. **Sandbox:** write the final normalized `spec.html` back to the sandbox; copy `document.html` to
   `./cr/CR-03/document.html`; update `working/last-normalized.html`.
3. **Chat:** `enqueue_agent_note` divider `cr-applied`: "**CR-03 applied** — 2 stories updated, 1 created,
   2 unchanged (past Design). The spec is now revision 7." Agent text: "CR-03 is closed. Do not edit
   ./cr/CR-03/plan.json any more."
4. **Collaboration** (when enabled, 46-09): publish the spec stage, the CR record + document blob, every
   updated/created story, deletion tombstones for removed stories; clear the advisory marker. On a `HubConflict` for
   a story: pull, re-publish once; if it still conflicts, report "publish pending" for that story (the apply itself
   stands).

## 6. Backlog mode (breakdown completed, stories not finalized — D13)

Instead of steps 2–7, the transaction rewrites the breakdown's **embedded backlog** and its document:

1. Read the current breakdown HTML (`_current_stage_html(breakdown_row)`), parse the embedded backlog
   (`_parse_embedded_backlog`).
2. Apply decisions by `backlog_id`: update fields; set `clauseRefs`; remove items; add new items with ids
   `story-<epicIndex>-<max+1>` in the chosen epic (`epic_key`), positioned after `follow_up_of` when given.
3. Set `specRevision = {revision_no: N+1, content_hash}`.
4. Re-render `breakdown.html` with **`genesis/kb/backlog_doc.py::render_breakdown(backlog)`** — a port of the
   workflow's deterministic `_build_document` / `_story_card_html` / `_table_html` / `_DOC_STYLE`
   (`feature-breakdown-analysis/graph.py:212-420`). genesis cannot import workflow Python (ADR-012), so the code is
   duplicated and kept identical by a **parity test in genesis-workflows** (genesis is its dev dependency):
   `assert graph._build_document(b) == genesis.kb.backlog_doc.render_breakdown(b)` over the workflow's fixtures.
5. Save it as a new breakdown milestone revision (note "CR-03") + `set_html`; also overwrite the breakdown chat's
   sandbox `breakdown.html` (if a chat exists) so its completion chat sees the reconciled backlog.
6. The breakdown stays `completed`; a later **Finalize Stories** reads the reconciled backlog and carries the
   `clauseRefs` into `spec_refs` (46-03 §5).

The CR document's apply report lists backlog ids instead of story keys.

## 7. `POST /features/{id}/change-requests/{cr_no}/discard`

Body: `{}`. Guards: CR `open`; no chat turn streaming. Steps:
1. Restore the sandbox `spec.html` from the base revision (`base.html`); update `working/last-normalized.html`.
2. One transaction: CR `status = discarded`, `closed_by/at`; spec `under-change → completed`
   (`discard-change`, audited). No story, backlog or revision changes; `html_path` already points at the base.
3. Freeze: if an analysis exists, render `document.html` with `status="Discarded"`; keep `plan.json` +
   `impact-input.json` for the record.
4. Chat divider `cr-discarded`: "**CR-03 discarded** — the spec is back to revision 6; no stories were changed."
5. Collab: clear the advisory marker; publish the CR record (status `discarded`) so teammates see the history.

## 8. Apply report (`apply-report.json`, also the API response)

```json
{ "cr": "CR-03", "applied_at": "…", "applied_by": "ram", "result_revision": 7,
  "updated": [{"story_id": 41, "key": "GNS_000041", "fields": ["acceptance_criteria"], "answers_added": 1, "answers_unmatched": [],
               "needs_design_rerun": false}],
  "created": [{"temp_id": "N1", "story_id": 131, "key": "GNS_000131", "follow_up_of": "GNS_000057",
               "on_board": true}],
  "removed": [{"story_id": 88, "key": "GNS_000088", "snapshot": {…all columns…}}],
  "unchanged": ["GNS_000063"], "not_applied_locked": ["GNS_000057"],
  "links_refreshed": 9,
  "publish": {"enabled": true, "ok": ["spec", "cr", "GNS_000041", "GNS_000131"], "pending": [], "errors": []} }
```

## 9. Tests

Each pre-check (A1–A8) blocks with its message and changes nothing; a full stories-mode apply (update + create +
remove + unchanged + locked-not-applied + locked-at-request) verifies every table and file; atomicity (inject a
failure at step 6 → everything rolled back, CR still open, spec still `under-change`); fingerprint refresh; board
membership rule; `GNS_` keys allocated in order; backlog mode end-to-end + the genesis-workflows parity test;
discard restores the sandbox byte-for-byte and changes no story; publish hooks called with the right entities (fake
provider), `HubConflict` retry path.


## 10. Build decisions (2026-10-15, before the build — recorded with the user)

Asked one question at a time; the user chose option A for both. The other points (proposals 1–12) were proposed by
the assistant at the 46-06 restatement and accepted by the user ("Yes") without change. They refine §2–§9 above;
where they differ, this section wins.

**Q1 — what Apply publishes before 46-09 → A.** When collaboration is enabled, Apply publishes (best-effort,
reported, never rolled back) what the existing bindings already support: the spec stage, every updated or created
story, deletion tombstones for removed stories, and — in backlog mode — the breakdown stage. A `HubConflict` is
reported as "publish pending" for that entity; there is **no pull-then-republish** in 46-06 (46-09 §2 forbids a pull
overwriting a just-applied change; its conflict-merge rules arrive there). The CR record + document blob, the
advisory marker and the conflict merge stay in 46-09. Rejected: B (publish nothing until 46-09); C (all of §5.4 now,
incl. the pull-and-republish that contradicts 46-09 §2).

**Q2 — answers on locked stories and the Apply confirmation → A.** A7's confirmation set also includes locked
stories (Design Review or later) that keep `no_change` but carry `answer_questions` (matching V4, which already
treats such an answer as a change): `confirm_locked_story_ids` must equal exactly the set of locked items whose
decision is not `no_change` **or** that carry answers. The Apply dialog lists them ("Record 1 answer on GNS_000057
(Implementation) as you asked"). Rejected: B (keep A7 as written; answers on locked stories pass on
`user_requested` alone).

**Accepted proposals (1–12):**
1. **One transaction for real.** `StageStore.add_revision` / `set_html` / `set_upstream_versions` and the `StoryStore`
   create / update / delete paths gain an optional `conn=` (additive, like `set_status(conn=)`). The revision file is
   written inside the transaction block and removed on rollback; the stage's authoritative "latest" file is swapped in
   after the commit.
2. `StoryStore._JSON_FIELDS` gains `answers` and `change_log` now (Apply writes them); their API/UI stay in 46-08.
3. **The plan is read once.** Apply reads `plan.json` once under the per-spec lock; exactly those bytes are
   validated, executed and frozen — a concurrent agent write cannot change what is applied.
4. **Formatting-only changes clear suspicion.** Apply refreshes the link fingerprints of every story on a clause whose
   change is `formatting` (no `change_log` entry). A formatting/moved-only CR therefore applies as a new revision
   that changes no story fields (46-05 §11 Q2).
5. **Candidates** (46-05 §11 Q1) get A5's existence + `row_version` check, apply their `add_spec_refs` (+ any
   `changes`), and receive an `updated` `change_log` entry.
6. **`change_log.summary`** = the decision's (or new story's) rationale, capped at 500 chars (the 46-09 cap); clause
   labels come from the final clause map (the base map for removed clauses).
7. **Sandbox write-back** of the final spec happens only when the sandbox `spec.html` still holds the bytes Apply
   read; otherwise it is left alone and the apply report carries a warning.
8. **Backlog-mode re-render** replaces `breakdown.html` as specified (§6.4): markup the breakdown chat added outside
   the embedded JSON is lost (flagged, accepted). New backlog items get the renderer's full field shape (`storyType`,
   `category`, `appianPart`, …).
9. **Parity test** (genesis-workflows) uses `pytest.importorskip("genesis.kb.backlog_doc")` until 46-11 re-pins
   genesis v0.77.0 (the dev pin v0.76.0 lacks the module); it covers the workflow fixtures incl. the traced path with
   labels.
10. **Positions** shift feature-wide as specified (`position > followed_up.position` → +1); per-epic order is kept.
11. **Board membership** of a new story: `on_board = 1` only when the feature's application has a Workbench board
    and the Q3 rule holds; the card goes at the end of the To Do lane (`max(to-do board_position) + 1`).
12. The 409 `apply_blocked` body carries a `blockers` list (`ChangeRequestError` gains it).
