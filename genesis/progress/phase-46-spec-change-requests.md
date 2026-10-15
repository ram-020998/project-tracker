# Phase 46 — Spec Change Requests & Story Traceability — progress (as-built)

> Spec: `specs/phase-46-spec-change-requests.md` (+ `46-01..46-11`). ADR-075/076 **Proposed** (Accepted at the 46-11 release).
> Build started 2026-10-14 on the user's go-ahead. Code commits are **local only** (no push/tag until the 46-11 release
> go-ahead). The umbrella §13 defaults (Q1–Q5) were confirmed by the user on 2026-10-14, all as written (findings §5.7).

## Ledger

| Sub-phase | Status | Commits (local) | Review |
|---|---|---|---|
| 46-01 findings | ✅ done (2026-10-14) | docs only | — |
| 46-02 clause model | ✅ built (2026-10-14) | genesis `196e78d` | SHIP |
| 46-03 story↔spec links | ✅ built (2026-10-14) | genesis `0d8622e` · genesis-workflows `da0bb91` | SHIP |
| 46-04 CR lifecycle | ✅ built (2026-10-14) | genesis `b8a9fc8` | SHIP |
| 46-05 impact analysis | ✅ built (2026-10-15) | genesis `297fd2b` | NEEDS_FIXES → fixed → SHIP |
| 46-06 apply / discard | ✅ built (2026-10-15) | genesis `1b31489` · genesis-workflows `7d8e92d` | SHIP (tests folded in) |
| 46-08 story answers / history / badges | ✅ built (2026-10-15) | genesis `e0d0e3e` · genesis-workflows `e20d66e` | SHIP (NITs folded in) |
| 46-07 web | ⏳ next | — | — |
| 46-09 collaboration / Hub | — | — | — |
| 46-10 review + acceptance | — | — | — |
| 46-11 release | — | — | — |

## 46-02 — the spec clause model (genesis `196e78d`)

**What was built**
- `genesis/kb/spec_clauses.py` (new, pure): block extraction per 46-02 §3 (sections `h2`–`h4`; clauses `p` not inside
  another block, `li` with its own text only, body `tr` [not `thead`/`tfoot`, not a leading all-`th` row], `dt`/`dd`,
  `blockquote`, `pre`; excludes `head`/`header`/`nav`/`footer`/`script`/`style`/`h1`/`data-gn-ignore` and empty blocks),
  `normalize_text` / `fingerprint` / `formatting_key` (§5), computed labels with the virtual section 0 and skipped-level
  rule (§6), `normalize_spec(html, previous, registry)` (§7: keep → duplicate resolution → exact re-anchor → fuzzy
  re-anchor 0.85 in-section / 0.92 document-wide, sections first → mint, never reusing a registry/previous/foreign ID) with
  a `RepairReport`, `clause_map(html)`, and `overlay_labels(html, coverage=None)` for the served copy (§11).
- `genesis/services/spec_clauses.py` (new): `SpecClauseService` — normalizes the agent's sandbox `spec.html` in place
  (atomic, only when changed) against `<stage_id>/working/last-normalized.html` (fallback: latest revision, then
  `html_path`), keeps `working/clause-registry.json` (every ID ever issued, removed ones flagged), all under a per-spec
  `path_lock`.
- `ChatModeProfile.post_turn` + `ChatManager.register_post_turn_hook`: `feature_spec` runs the `spec_clauses` hook
  after every non-command turn, via `asyncio.to_thread`, after the assistant message is persisted and while the session
  lock is held; a failure is logged with the traceback and never breaks the turn.
- `_STEERING_SPEC` gains the **Structure** paragraph (one requirement per element; never touch `data-cid`).
- `StageStore.get_by_chat_session`.
- API: both milestone routes for the spec normalize first (every revision carries IDs); `GET /features/{id}/spec/clauses
  ?revision=working|<n>` (409 no content, 400 bad revision, 404 unknown revision); the spec artifact routes
  (`/spec/artifact`, `/stages/spec/artifact`) add render-only `data-gn-label` + a margin stylesheet (`labels=0` turns it
  off). Coverage badges are supported by `overlay_labels(coverage=…)` and get wired when the coverage API lands (46-03).
- `beautifulsoup4==4.15.0` pinned directly.

**Deviations from the spec (deliberate)**
- The normalizer edits only the start tags of the blocks it touches instead of re-serializing with BeautifulSoup, so all
  other markup stays byte-identical (re-serialization remains as a fallback if a source position can't be verified).
- `data-gn-ignore` is not stripped (it is the author's exclusion marker); every other `data-gn-*` is.
- A table row's overlay label goes on its first cell (a `tr` can't render the margin pseudo-element).
- `tfoot` rows are not clauses (totals/footers), in addition to `thead` rows.
- `GET …/spec/clauses` defaults to `working`; the "consumer version" default arrives with change requests (46-04 §6).
- The real-spec fixture is not committed (business content). Instead: a synthetic spec + 8 awkward-markup cases are
  committed, and the two live specs in `~/.genesis` were checked read-only (169 and 100 blocks: byte-identical apart from
  the IDs, rendered text identical, idempotent).

**Evidence**
- genesis pytest **959** passed (was 923; +36: `tests/test_spec_clauses.py` 28, `tests/test_spec_clauses_api.py` 8) +
  ruff clean. No web change (the preview UI is 46-07), so web gates were not affected.
- Independent review = **SHIP**; its findings folded in (tfoot rows, duplicate `data-cid` on one tag, awkward-markup
  regression tests, a comment on the GET side effect). Reviewer timing: a 500-block spec with every ID dropped and 30%
  reworded re-anchors 500/500 IDs in ~95 ms.
- Not verified: a live agent turn in a running `genesis serve` (the server needs a restart to load the hook; no restart
  done — the fleet is not updated mid-phase).

## 46-03 — story ↔ spec links (genesis `0d8622e` · genesis-workflows `da0bb91`)

**What was built**
- **m0024** (`current_version` 23 → 24) with the **whole phase's DDL** from 46-04 §3: `kb_stories.spec_refs` /
  `answers` / `change_log`, `chat_messages.meta_json`, `kb_spec_change_requests` + the one-open-CR-per-spec partial
  unique index (+ a feature index). Every `current_version == 23` assertion bumped; the synthetic next-migration test
  moved to v25.
- `genesis/kb/spec_changes.py` (new, pure): `is_traceable(backlog, stories)` (46-03 §7), `make_spec_refs` (link
  records `{clause_id, fingerprint, origin, linked_at}`; unknown IDs dropped and returned), `build_coverage` (per clause:
  items + `suspect` + `via_section`; a section ref covers every clause under it, through sub-sections; a direct link
  wins over a section link for the same item), `coverage_counts`, `backlog_items` / `story_items`.
- `StoryStore`: `finalize(…, spec_refs_for=)`; **the workstream fix** (`workstreamRef` → `kb_epics.workstream`, was
  always NULL); `spec_refs` is a JSON field on create/update/read.
- `StageStore.set_upstream_versions` — the breakdown row now records `{"spec": {revision_no, content_hash}}`.
- Breakdown launch: normalizes the spec, snapshots it, writes `spec_clauses.json`
  (`{revision_no, content_hash, clauses}`; `revision_no` = the latest revision when byte-identical to the snapshot,
  else null) and passes `spec_clauses_path` **only when the installed `feature-breakdown-analysis` declares it**
  (`run_manager.loader.meta_of`; a malformed workflow.yaml is logged and treated as an older library).
- Finalize: a traceable backlog's `clauseRefs` become `spec_refs` with the fingerprint from the launch-time clause map
  when its `content_hash` matches `backlog.specRevision` (else the current spec); unknown refs are reported as
  `dropped_refs`. A legacy backlog stores no refs and the response has no `dropped_refs`.
- `GET /features/{id}/spec/coverage?revision=working|<n>` → `{revision, traceable, mode, clauses, uncovered}`
  (stories once finalized; backlog when the breakdown is completed; else / legacy → none). The spec preview overlay
  now shows a story-count badge per clause (hollow "no story" when uncovered) whenever coverage mode isn't none.
- Manual `spec_refs` on story create/update (clause IDs or `{clause_id, origin}`), validated against the current
  spec clause map (400 on unknown IDs; origin defaults to `manual`).
- Collaboration: the three new story columns are **local-only** (`_LOCAL_ONLY`) until 46-09 maps them onto the Hub
  contract, so the frozen contract never receives unknown fields.
- `_STEERING_FB`: keep each story's `clauseRefs` in the embedded JSON; give added/split stories their clause IDs.
- **genesis-workflows `feature-breakdown-analysis` 0.3.0** (registry + workflow.yaml parity): optional
  `spec_clauses_path`; with a map, `spec.txt` is clause-tagged, `break_epic` asks for `clauseRefs`, `check_stories`
  rejects missing/unknown refs (listing them), the coverage critic gets the list of uncovered requirement clauses,
  the backlog carries `clauseRefs` (deduped, unknown dropped) + `specRevision`, and each story card shows
  "Spec: §…". Without a map the run is byte-identical to 0.2.0 (prompts, `backlog.json`, `breakdown.html` — checked
  against the previous source).

**Deviations / notes**
- m0024 carries all of Phase 46's schema now (unreleased; one migration per phase) instead of growing per sub-phase.
- Section headings in the clause-tagged spec text use the heading depth (`3` → `##`, `3.2` → `###`); the 46-03 §3
  example shows `## 3.2`.
- Coverage uses the working copy until 46-04 introduces the consumer version.
- The preview overlay parses the clause map twice per serve (coverage + labels); fine at current sizes.

**Evidence**
- genesis pytest **974** (+15 `tests/test_spec_links.py`) + ruff clean; genesis-workflows `validate_library` **13** +
  pytest **250** (+7 traced-path tests in the breakdown suite).
- Independent review = **SHIP**; findings folded in (O(1) coverage dedup + direct-over-section precedence, YAML errors
  on the declared-input check, a comment on the CAS-free setter). Coverage of 500 clauses × 200 stories < 1 s (test).
- Not verified live: a real breakdown run with the clause map (needs the fleet updated + a Kiro run).

## 46-04 — change-request lifecycle (genesis `b8a9fc8`)

**What was built**
- **Domain:** `LifecycleState.UNDER_CHANGE`; `SPEC_TRANSITIONS` += `completed –initiate-change→ under-change`,
  `under-change –apply-change|discard-change→ completed`; preconditions: `reopen` needs *not* `downstream_locked`,
  `initiate-change` needs `is_spec ∧ downstream_locked ∧ via_change_request`, apply/discard need `via_change_request`
  (reasons per 46-04 §2.1). `LifecycleService.allowed(…, ctx=)` is precondition-aware (also used for the
  `IllegalTransitionError` allowed list). `transition(…, conn=)` writes the status and the m0013 audit row on the
  caller's transaction (`StageStore.set_status(conn=)`, `LifecycleAuditStore.record(conn=)`).
- **`downstream_locked`** = a *traceable* feature (46-03 §7) whose breakdown is completed or whose stories are
  finalized. Legacy features are never locked and keep Reopen. Computed by `SpecChangeService.stage_ctx`, used by
  both `/spec/*` and `/stages/{stage}/*` action + allowed endpoints.
- **`SpecChangeStore`** (`kb/spec_changes.py`): create (`cr_no = max + 1`, one open CR per spec via the m0024 partial
  index → `OpenChangeRequestExistsError`), get / get_by_no / get_open / list, set_analysis, set_summary, close
  (open-only CAS); `cr_label` (`CR-01`, `CR-100`).
- **`services/stage_artifacts.py`** (new): the one shared resolver — `current_stage_html` (working copy: sandbox
  first) and `consumer_stage_html` (a spec `under-change` → the CR's frozen `base.html`, then the base revision
  file, then `html_path`) + `write_revision`. `api/features.py` and `api/workbench.py` both use it (the duplicated
  resolver is gone).
- **`services/spec_change.py`** (new) `SpecChangeService`:
  - **Initiate** (`POST /features/{id}/change-requests {title?}`): guards (spec completed, locked, owns a chat
    session, chat not streaming, no open CR) → normalize → baseline milestone "Baseline for CR-n" when the working
    copy differs from the latest revision → frozen `base.html` + sandbox `./cr/CR-n/` (`instructions.md` per 46-04 §8,
    `base-spec.html`, `context/ux-design.html`, `context/technical-design.html`, earlier CR documents) → **one
    transaction**: CR row + audited `initiate-change` → the `cr-divider` agent note. Mode = stories when finalized,
    else backlog. Any failure removes the files it created and leaves the spec `completed`.
  - **Discard** (`POST …/{cr_no}/discard`; 46-06 §7 built here by agreement): restore the sandbox `spec.html` and
    `working/last-normalized.html` to `base.html` byte-for-byte → **one transaction**: CR `discarded` + audited
    `discard-change` → `cr-discarded` note. A failed transaction puts the edited working copy back.
  - **List / detail** (`GET …/change-requests[/{cr_no}]`); detail carries `analysis.state = none` (46-05 fills it),
    `can_apply = false`.
  - Initiate/discard are serialized per spec (in-process lock); leftover CR directories are refused, never reused.
- **Guards while under change:** both spec milestone routes 409; the deprecated `PATCH /spec/status` 409s for
  `under-change` (and refuses to leave `completed` while locked); Finalize Stories 409; the breakdown milestone 409
  during a backlog-mode CR; generic CR actions 409 (precondition). Prerequisite checks count `under-change` as
  present (`StageStore.PRESENT_STATUSES`). Export .md filename `spec-<id>-working-copy-CR-n.md`.
- **Consumer isolation (D11):** UX / TD / breakdown launches, the Workbench story-design launch, and the
  clauses / coverage defaults read the consumer version (default revision = the CR's base revision while under
  change; `revision=working` still available). The chat preview keeps the working copy.
- **Chat:** `chat_messages.meta_json` round-trips (`ChatMessageRecord.meta`; the chat API returns `meta` without
  `agent_text`); `ChatManager.enqueue_agent_note(visible, agent_text, kind, meta)` — queued on a running client and
  prepended as `Genesis: …` to its next non-command turn, otherwise replayed by the cold-start preamble (system
  messages now replay as `Genesis:` lines with their agent text); queued notes are dropped when the client closes
  (the replay carries them). **Add context now uses it** (the transcript-only defect, 46-01 §2.4, is fixed for every
  stage).

**Deviations / notes**
- `submit`'s has-HTML precondition does **not** filter `allowed(ctx=)` (`SPEC_FILTERING_PRECONDITIONS` = the lock/CR
  rows only): the web doesn't refetch `allowed` after a chat turn writes the artifact, so hiding *Submit for review*
  would strand it; the 409 still explains why.
- The baseline milestone revision is written before the CR transaction and is kept if that transaction fails (it is a
  plain snapshot of the working copy).
- The advisory "spec under change" marker (46-04 §5.1 step 8) moves to 46-09 with the rest of the collaboration work.
- Discard was built here (umbrella ledger) instead of 46-06; freezing a *Discarded* CR document follows in 46-06 once
  the 46-05 renderer exists.
- No web change yet (46-07): an `under-change` spec shows a raw status label in today's UI until then.
- 46-09 note: its `spec_change_request` binding names `html_col="document_path"`, but the table has `dir_path`.

**Evidence**
- genesis pytest **994** (+20 `tests/test_change_requests.py`) + ruff clean. The racing-initiate test fails 3/3 with
  the per-spec lock removed and passes with it.
- Independent review = **SHIP**; findings folded in (racing initiates could delete the winner's CR files → per-spec
  lock + no reuse of leftover directories; ctx computed once outside the transaction; stores threaded through the
  resolver; an end-to-end Workbench story-design isolation test; hoisted import).
- Not verified live: a real chat turn receiving an agent note in a running `genesis serve` (the fleet is not
  restarted mid-phase).

## 46-05 — impact analysis (genesis `297fd2b`)

**Decisions recorded before the build (2026-10-15)** — full text in `specs/.../46-05-impact-analysis.md` §11
(findings §5.8): Q1 = A (new clauses list *candidate* stories; the plan may update a candidate only to attach the
new clause); Q2 = A (`no_changes` only when nothing differs; formatting/moved-only CRs are analyzed and applied as a
revision with no story changes); refinements 3–16 accepted (LCS-stable positions, ancestor-section broad links, the
run-state mapping, the staleness order, a pure `validate_plan`, V6 = the breakdown's Gherkin rule, `breakdown_hash`
in the impact input, the awaiting-plan document, `can_apply` from A1–A4, **Discard freezes the CR document in
46-05**, analyze guards + a no-op `no_changes`, the single `cr-analyzed` note, an optional `title_suggestion`).

**What was built**
- **`kb/spec_diff.py`** (new, pure): `diff_specs(base_map, working_map)` → unchanged / moved / formatting / modified
  (`moved` flag) / added / removed per block, sections included; position = a per-section LCS of the common IDs (one
  insertion moves nothing); `SpecDiff.identical`; `ancestors()`.
- **`kb/spec_impact.py`** (new, pure): `story_item` / `backlog_item`, `build_impact_input` → the
  `genesis.cr-impact-input/1` document: `changes`, `ignored_changes` (formatting/moved), `affected` (linked = the
  clause; broad = any ancestor section — removed clauses use the base ancestry; a modified heading affects only
  direct links), `new_clauses` with `candidates` (Q1; an affected item is never a candidate), `candidates`
  (`for_clause_ids`), `epics`, `counts`, `rules` (`item_key`, editable fields), `breakdown_hash` in backlog mode.
- `StoryStageStore.run_states_for_feature` + `run_state()` (refinement 5).
- **`kb/cr_plan.py`** (new, pure): `load_plan` (defensive: fenced JSON, garbage, non-object), `validate_plan`
  V1–V12 (each finding = `{rule, item, message}`; candidates may only `update` with `add_spec_refs` ⊆ their new
  clauses; V6 = the breakdown's `_GHERKIN`, on the story as it would be after the change), `plan_counts`.
- **`kb/cr_document.py`** (new, pure): the script-free, Lavish-safe "CR-n Impact Analysis" document — header + status
  chip (draft / awaiting the plan / out of date / Applied / Discarded), summary counts, validation box, spec changes
  with word-level `<del>`/`<ins>`, affected stories grouped by clause (per-field before/after), existing stories
  taking new clauses, new stories, removed requirements, uncovered requirements, apply-report footer; unique stable
  ids (`cr-clause-*`, `cr-story-*`, `cr-new-*`); everything HTML-escaped. `placeholder_document` before the first
  analysis.
- **`SpecChangeService`**: `analyze` (per-spec lock; 409 when the CR isn't open / the spec isn't under change / no
  chat / chat busy; normalize → diff → `no_changes` (writes nothing) or the impact input written to the frozen dir
  (authoritative) + the sandbox (agent copy) + `plan-format.md`, the previous plan archived as `plan.<n>.json`,
  `set_analysis`, one `cr-analyzed` agent note); `analysis` (none → stale-by-hash → awaiting_plan →
  stale-by-analysis_id → current, with validation + counts); `plan`; `document` (live while open, frozen once
  closed); `detail` → `can_apply` / `apply_blockers` from A1–A4; **Discard freezes `plan.json` + the Discarded
  `document.html`** (and copies it into the sandbox so the next CR's agent can read it). `instructions.md` now
  points at `plan-format.md` and the candidate rule.
- **API** (`api/change_requests.py`): `POST …/{cr_no}/analyze`, `GET …/{cr_no}/plan`, `GET …/{cr_no}/document`
  (`annotate=1` → the existing Lavish injection; else theme only), `GET …/{cr_no}/export.md`
  (`CR-n-impact-analysis.md`). `api/features.py` wires stories, `StoryStageStore` and the backlog + breakdown hash.

**Deviations / notes**
- A garbage `plan.json` reads as `current` with a V1 error (the banner says "fix the plan"), not `awaiting_plan`.
- `impact-input.json` lives in both the frozen dir (program-owned, the one validation reads) and the sandbox (for
  the agent); `plan-format.md` (the schema) is written next to it at every analysis.
- A missing `base.html` makes `analyze` refuse (500 `base_missing`) but never breaks the read endpoints (validation
  reports V1).
- No web change (46-07). Apply (A5–A8 + the transaction) is 46-06.

**Evidence**
- genesis pytest **1035** (+41: `test_spec_diff.py` 8, `test_cr_impact_plan.py` 17, `test_cr_document.py` 5,
  `test_cr_analyze.py` 11) + ruff clean.
- Independent review = **NEEDS_FIXES** → fixed → focused re-review **SHIP**: an affected story could also be a
  candidate (duplicate document ids + a double "to update" count) → candidates skip affected items; a plan without
  `analysis_id` now reads as stale; a missing `base.html` degrades reads instead of a 500 — each with a regression
  test.
- Not verified live: a real agent turn writing `plan.json` from `impact-input.json` (needs the fleet updated).

## 46-06 — apply and discard (genesis `1b31489` · genesis-workflows `7d8e92d`)

**Decisions recorded before the build (2026-10-15)** — full text in `specs/.../46-06-apply-and-discard.md` §10
(findings §5.9): Q1 = A (Apply publishes what existing bindings support — spec stage, updated/created stories,
tombstones, breakdown in backlog mode; `HubConflict` → "publish pending", no pull; CR record/blob/marker/merge in
46-09); Q2 = A (A7's confirmation also covers answers on locked stories); proposals 1–12 accepted (conn-aware stores
with revision files removed on rollback, `answers`/`change_log` JSON fields now, the plan read once under the lock,
formatting-only fingerprint refresh, candidates in A5 + change_log, summary = rationale ≤ 500 chars, guarded sandbox
write-back, backlog re-render replaces `breakdown.html`, parity test `importorskip` until 46-11, feature-wide position
shift, `on_board` only with a board, `blockers` in the 409).

**What was built**
- **Stores (conn-aware, additive):** `StageStore.add_revision / set_html / set_upstream_versions(conn=)` +
  `next_revision_no`; `StoryStore.create_story(after_story_id=, conn=)` (position shift after the followed-up story;
  `on_board` / `answers` / `change_log` on create), `update_story(conn=)`, `delete_story(conn=)`, `snapshot()`;
  `_JSON_FIELDS` += `answers`, `change_log`; Finalize carries backlog items' `answers`. `BoardStore.board_id_for` +
  `append_to_todo(conn=)`.
- **`kb/cr_apply.py`** (new, pure): link refresh (modified + formatting-only clauses), link add/remove
  (`origin: "cr"`), answers moved by normalized question text (unmatched kept + reported), `change_log` entries
  (summary = rationale ≤ 500), and `apply_backlog` (backlog mode: updates, `clauseRefs`, answers, removals, new
  `story-<epic>-<max+1>` items after `follow_up_of`, `specRevision`).
- **`kb/backlog_doc.py`** (new): `render_breakdown` — the workflow's renderer copied verbatim (`_DOC_STYLE`, `_esc`,
  `_fmt_ac`, `_assign_ids`, `_story_card_html`, `_table_html`, `_build_document`).
- **`SpecChangeService.apply`** (`POST …/{cr_no}/apply {confirm_locked_story_ids}`), under the per-spec lock:
  - pre-checks A1–A8 → 409 `apply_blocked` + `blockers`; A7's confirmation set = locked items whose decision is not
    `no_change` **or** that record answers (Q2); A5 checks affected items **and** candidates against the frozen
    impact input; the working copy and `plan.json` are read once and exactly those bytes are validated, applied and
    frozen;
  - **one transaction**: spec revision N+1 (file removed on rollback) + `set_html`; stories mode — new follow-up
    stories (GNS_ key, epic of the followed-up story, positioned after it, `on_board` + a To Do card only when the
    app has a board), updates (fields, links, fingerprints, answers), removals (full snapshot first), fingerprint
    refresh on unmentioned stories, `change_log` (`updated | created | unchanged | not_applied`, `follow_ups`,
    `follow_up_of`, `needs_design_rerun`); backlog mode — the reconciled backlog re-rendered, a breakdown revision
    "CR-n", the breakdown's consumed spec revision set to N+1; then the CR row (applied + summary) and the audited
    `apply-change`. Any exception rolls back everything → 409 `apply_failed`; the CR stays open;
  - after the commit (best-effort, every miss in `warnings`): the latest files, frozen `result.html` / `plan.json`
    / `apply-report.json` / the *Applied* `document.html` (real keys, no validation box), the breakdown chat's
    `breakdown.html`, a guarded sandbox check (a concurrent chat edit is left alone), the `cr-applied` note, and
    publishing (Q1: spec stage, updated/created stories, tombstones, the breakdown in backlog mode; `HubConflict` →
    pending, no pull).
- `api/app.py` passes the collaboration service to the features routes.
- **genesis-workflows:** a parity test in `feature-breakdown-analysis` — `render_breakdown == _build_document` over
  five backlogs (incl. unicode / `</script>` / empty epics / the traced path with labels) **and** byte-identical
  source of every ported function; `importorskip` until 46-11 re-pins genesis.

**Deviations / notes**
- A locked story that keeps `no_change` but records a confirmed answer gets `change_log` decision `unchanged`
  (it was answered, not left behind); a plain locked `no_change` is `not_applied`.
- Stories whose only change is a fingerprint refresh or an answer are not published until 46-09 (the new story
  columns are local-only until then anyway).
- The stage's "latest" file is written right after the commit (best-effort); the revision file — the durable
  record — is written inside the transaction block.
- A leftover `revisions/N+1.html` refuses Apply with a 500 `stale_files` (never overwritten, never deleted).
- Discard needed no change in 46-06 (built in 46-04, frozen document in 46-05); its Hub publish is 46-09.

**Evidence**
- genesis pytest **1054** (+19 `tests/test_cr_apply.py`) + ruff clean; genesis-workflows `validate_library` **13** +
  pytest **252** (+1 parity test, ran locally against the editable genesis).
- Independent review = **SHIP**; its SHOULD-FIX (three unasserted paths — `not_applied`, `needs_design_rerun`, the
  candidate update) folded in as tests; NITs recorded above.
- Not verified live: an Apply in a running `genesis serve` with a real agent-written plan, and publishing against
  the live Hub (fleet not updated mid-phase).

## 46-08 — story answers, spec references, history, badges (genesis `e0d0e3e` · genesis-workflows `e20d66e`)

**Decisions recorded before the build (2026-10-15)** — full text in `specs/.../46-08-story-answers-history-and-badges.md`
§9 (findings §5.10): Q1 = A (`needs_design_rerun` for CR-updated stories with a done design in Design **or Design
Review** — amends 46-06); Q2 = A (a "From the spec" chip opens the read-only spec in a new tab, scrolled to and
highlighting the clause); Q3 = A (the story workflows also receive the open questions, marked unresolved); proposals
1–10 and 14 accepted (index vs text answers, 3,000-char answer cap, validated `answers` PATCH keeping provenance,
enrichment in both story reads, server-side design-rerun resolution from `runs.created_at` in both board reads,
always-sent story keys, the null-revision badge fallback + `spec-reviewed` scope + badge in both stage reads,
removed-clause chips, legacy features hide the spec card, answer-only history from `answers`, 46-07/46-08 web split).

**What was built**
- **`kb/story_trace.py`** (new, pure): answer / edit / reopen a question (`AnswerError` → 400; answers ≤ 3,000
  chars), `validate_answers` for a story PATCH (an entry matching an existing one keeps its provenance; anything
  else becomes a manual answer by the caller), `enrich_refs` (`{label, text, exists, kind}` from the consumer clause
  map), `spec_clauses` / `workflow_story_fields`, `story_flags` (latest change-log entry: `design_rerun` until a
  design run *starts* after it, `not_applied` while past Design) and `stage_spec_changed` (recorded revision, else
  the time rule; never the spec; the breakdown not after Finalize). `services/stage_artifacts.consumer_spec_map`.
- **API** (`api/features.py`): `POST /features/{fid}/stories/{sid}/answers`, `PATCH …/answers/{i}`,
  `DELETE …/answers/{i}?row_version=` (row_version CAS → 409, `canonical_username`); `PATCH` story accepts
  `answers`; every story response (list, get, create, patch, answer ops) carries enriched `spec_refs`;
  `spec_changed` on every stage in `GET /features/{id}` **and** `GET …/stages/{stage}`; `POST …/stages/{stage}/
  spec-reviewed` (UX / TD / breakdown; 400 for the spec) stores the latest spec revision + hash + reviewer; the UX
  and TD launches now record the consumed spec version (`upstream_versions_json`).
- **Workbench:** the board card DTO carries `spec_flags` (`kb/boards._card_dict` → both `get_board` and
  `get_card`, from the latest design run's `runs.created_at`); the Story Workspace read returns enriched refs,
  `flags` and `context.traceable`; the design and implementation launches add `answers`, the open `questions` and
  `spec_clauses` to the `story` dict.
- **Q1:** Apply flags `needs_design_rerun` for CR-updated stories with a done design in Design **or Design Review**
  (`services/spec_change.py`).
- **Q2:** the served spec carries a small script that scrolls to and highlights `#c-xxxxxxxx` (only that pattern).
- **Web:** Story Workspace Overview — Open questions (Answer), Answered questions (Edit answer / Reopen question;
  CR answers link to the CR document), "From the spec" chips (new tab at the clause; muted "removed from the spec";
  hidden on legacy features), Change history (newest first, follow-ups, re-run tag), the not-applied notice (Dismiss
  stored in the browser); Design tab re-run banner (Re-run design, or "move it into Design" without a board card);
  board-card "spec changed" icon; `SpecChangedBanner` under the stage workspace header (with the stage's Re-run
  control, View CR-n, Mark as reviewed) and compact on the Overview stage card. `web/static` rebuilt.
- **genesis-workflows:** `story-design-analysis` 0.3.1 and `story-implementation` 0.1.1 list answered questions,
  open questions (marked unresolved) and the spec clauses in the ticket block; without the keys the prompt is
  byte-identical (golden test).

**Deviations / notes**
- Editing a CR-recorded answer keeps `source: cr` + `cr_no` (the CR link stays) and records the editor as
  `answered_by` / `answered_at`; the card shows both (review NIT).
- The compact stage-card banner offers View CR-n + Mark as reviewed only; the stage's Re-run control is in the card
  actions right below it (the full banner in the stage workspace reuses the Re-run control).
- The badge compares revision numbers only (the recorded content hash is kept for the record); a stage launched
  from an unsaved working copy uses the time rule.
- Manual answers are not published until 46-09 (the story columns are still local-only).

**Evidence**
- genesis pytest **1081** (+27 `tests/test_story_trace.py`, incl. the Q1 regression for Design Review) + ruff
  clean; web tsc clean, eslint 0 errors (19 pre-existing warnings), vitest **309** (+11, jest-axe on the new cards,
  notice, banner and icon), build committed; genesis-workflows `validate_library` **13** + pytest **256** (+4).
- Independent review = **SHIP** (no MUST/SHOULD); NITs 1 (edited CR answer shows its editor, + test) and 4 (single
  story reads skip the clause map without spec links) folded in; 2, 3, 5 recorded above.
- Not verified live: the Story Workspace cards / board icon / stage banner in a running `genesis serve`, and a real
  story-design run with the new ticket block (the fleet is not updated mid-phase).
