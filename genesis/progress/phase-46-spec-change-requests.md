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
| 46-05 impact analysis | ⏳ next | — | — |
| 46-06 apply / discard | — | — | — |
| 46-08 story answers / history / badges | — | — | — |
| 46-07 web | — | — | — |
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
