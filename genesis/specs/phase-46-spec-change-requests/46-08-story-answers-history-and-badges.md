# 46-08 — Story answers, spec references, change history, and "spec changed" badges

> **Status:** 🟡 DRAFTED 2026-10-14. Repos: **genesis** (API + web) + **genesis-workflows** (story design /
> implementation prompts). Parent: `specs/phase-46-spec-change-requests.md`. Decisions D16, D17.

## 1. Goal

Make the traceability visible where developers work — the **Story Workspace** and the **board card** — and close the
stand-up loop: a question on a story can be **answered**, and the answer flows into the next design run. Flag the
UX Design and Technical Design stages when the spec changed after they were produced.

## 2. Story question answers

**Data:** `kb_stories.answers` (m0024) — JSON array, in answer order:
```json
{ "question": "Do we accept an LEI?", "answer": "Yes, as an alternative to the registration number.",
  "answered_by": "ram", "answered_at": "2026-10-14T10:02:00Z", "source": "manual", "cr_no": null }
```
`source ∈ manual | cr` (`cr_no` set when an applied CR answered it, 46-06 §4 step 2a). Manual answers address a question
by **index** (the UI knows it); CR answers address it by **normalized text** (the agent only sees text) — 46-06 §4 step 2a. `questions` keeps only the
**open** questions; answering moves a question from `questions` to `answers`.

**API** (`genesis/api/features.py`, story routes; `row_version` CAS → 409 on a stale write):
- `POST /features/{fid}/stories/{sid}/answers` `{question_index, answer, row_version}` → moves
  `questions[question_index]` to `answers` (`source: manual`, `answered_by = canonical_username`).
- `PATCH /features/{fid}/stories/{sid}/answers/{index}` `{answer, row_version}` → edits an answer.
- `DELETE /features/{fid}/stories/{sid}/answers/{index}?row_version=` → **Reopen question**: moves it back to the end
  of `questions`.
- `StoryStore._JSON_FIELDS` += `answers`, `spec_refs`, `change_log`; `PATCH /features/{fid}/stories/{sid}` accepts `answers` and
  `spec_refs` for full edits (validated).

**UI — Story Workspace Overview** (`web/src/features/workbench/StoryWorkspacePage.tsx`):
- **Open questions** card: each question has an **Answer** button → an inline textarea + Save/Cancel.
- **Answered questions** card (shown when non-empty): question, answer, "ram · 14 Oct" (or "from CR-03" with a link
  to the CR document), and a menu with **Edit answer** / **Reopen question**.
- jest-axe on both cards.

## 3. Spec references on the story

**UI — Story Workspace Overview**, a **"From the spec"** card:
- one chip per `spec_refs` entry: label (`§3.2-1`, from the consumer clause map) + the clause text on hover; a muted
  "removed from the spec" chip when the clause no longer exists;
- clicking a chip opens the spec preview scrolled to that clause (`#cid` fragment — the preview script scrolls to
  `[data-cid=…]` and highlights it);
- empty state (a story added manually without refs): "Not linked to the spec"; the card is hidden on legacy features
  (46-03 §7).
- `GET /features/{fid}/stories/{sid}` returns `spec_refs` enriched with `{label, text, exists}` resolved against the
  consumer clause map (no extra request).

## 4. Change history on the story

**Data:** `kb_stories.change_log` (m0024) — JSON array, append-only (never edited):
```json
{ "cr_no": 3, "cr_sync_uuid": "…", "decision": "updated",
  "summary": "AC 2 now accepts an LEI", "clause_labels": ["§3.2-1"], "clause_ids": ["c-9f2a1c0b"],
  "fields": ["acceptance_criteria"], "at": "2026-10-14T10:40:00Z", "by": "ram",
  "needs_design_rerun": false, "follow_up_of": null, "follow_ups": ["GNS_000131"] }
```
`decision ∈ created | updated | unchanged | not_applied` (removed stories are deleted; their snapshot lives in the
CR's apply report). `follow_ups` lists stories created as follow-ups of this one; a created story has `follow_up_of`.

**UI:**
- Story Workspace Overview, a **"Change history"** card (shown when non-empty): newest first — "**CR-03** · Updated
  acceptance criteria · §3.2-1 · ram · 14 Oct" with a link to the CR document; "Follow-up: GNS_000131"; for a
  created story "Created by CR-03 as a follow-up to GNS_000057".
- **Not-applied notice** (decision `not_applied`, story still past Design): a warning callout at the top of the
  Overview — "The spec changed after this story moved past Design (CR-03). It was not changed. Follow-up:
  GNS_000131." The callout has **Dismiss** (stored per story in local UI state only; the history entry stays).
- **Board card** (`StoryCard`): a small "spec changed" icon with a tooltip when the latest `change_log` entry is
  `not_applied`, or `updated` with `needs_design_rerun` (and no design run started after it).

## 5. Design out of date → re-run

When an applied CR updated a story in **Design** whose design was already `done`, the change_log entry has
`needs_design_rerun: true`. Considered resolved as soon as a story-design run for that story **starts** after the
entry's `at`.
- Story Workspace **Design** tab: banner "The story changed after this design was written (CR-03). Re-run the design
  to update it." + **Re-run design** → the existing `POST /workbench/boards/{app}/cards/{sid}/design/start`
  (re-runs in place; the card is already in Design). Hidden when there is no board card (then: "Move the story into
  Design on its board to re-run the design").
- Board card icon as in §4.

## 6. UX Design / Technical Design "spec changed" badge (D16)

- **Write the consumed version** at launch: `_launch_analysis` (UX), `_launch_td`, `_launch_breakdown` set the
  stage's `upstream_versions_json = {"spec": {"revision_no": <consumer revision>, "content_hash": <hash>}}`.
- **Derive the badge** in the stage GET payload: `spec_changed = {cr_no, applied_at}` of the **latest applied CR**
  whose `result_revision_no > consumed.revision_no`; for a stage with no recorded version (produced before
  Phase 46), use the latest applied CR whose `closed_at` is later than the stage's last run start (or `updated_at`
  when it has no run). Not shown for the breakdown once stories are finalized; in backlog mode the breakdown's
  consumed revision is set to the CR's result revision on Apply (it is reconciled), so no badge.
- **UI** (`StageWorkspaceHeader` + the stage card on the feature Overview): an info banner "The spec changed after
  this was produced — **CR-03** (14 Oct). Re-run to refresh it, or mark it reviewed." Buttons: the stage's existing
  **Re-run** control, **View CR-03**, **Mark as reviewed**.
- `POST /features/{id}/stages/{stage}/spec-reviewed` sets `upstream_versions_json.spec` to the current consumer
  revision + `reviewed_at`/`reviewed_by`; the badge disappears.
- Notify-only (ADR-063): never blocks the stage.

## 7. Answers and references reach the story workflows (genesis-workflows)

- genesis Workbench launches add `answers` (`[{question, answer}]`) and `spec_clauses` (`[{label, text}]` for the
  story's refs, from the consumer clause map) to the `story` dict passed to `story-design-analysis` and
  `story-implementation`.
- `story-design-analysis` (0.3.1) and `story-implementation` (0.1.1): the ticket block in the prompts lists
  "Answered questions" and "Spec clauses this story implements" when present (both workflows already accept the
  `story` object; the keys are optional, older genesis versions simply omit them). `workflow.yaml` descriptions of
  the `story` input are updated; versions bumped.

## 8. Tests

Answer / edit / reopen endpoints (CAS, index bounds, `canonical_username`); `_JSON_FIELDS` round-trip; spec-ref
enrichment (exists / removed); change_log rendering incl. follow-up links; not-applied callout + board
icon conditions; design-rerun resolution rule; `upstream_versions_json` written by each launcher; badge derivation
(recorded version, legacy fallback, breakdown suppression, backlog-mode reconcile); `spec-reviewed` endpoint; the two
workflow prompt additions (golden prompt text with and without the new keys); jest-axe on the new cards, callout and
banner.


## 9. Build decisions (2026-10-15, before the build — recorded with the user)

Asked one question at a time; the user chose option A for all three. The other points (proposals 1–10 and 14) were
proposed by the assistant at the 46-08 restatement and accepted by the user ("Yes") without change. They refine
§2–§8 above; where they differ, this section wins.

**Q1 — which updated stories get "re-run design" → A.** `needs_design_rerun` is set for every story a CR **updates**
whose design is `done`, in the **Design or Design Review** lane (a Design Review story is only updated when the user
explicitly asked and confirmed it in Apply). A successful design run auto-advances the card to Design Review, so the
46-06 rule (Design lane only) would almost never fire. This amends the built 46-06 Apply code (+ a regression test).
Rejected: B (keep 46-06 as built — Design lane only); C (any lane incl. Implementation and later).

**Q2 — what a "From the spec" chip does → A.** It opens the **read-only spec** in a new browser tab
(`…/spec/artifact?annotate=0` with labels, `#c-…` fragment); a small addition to the served overlay script scrolls to
and highlights the clause `[data-cid=…]`. Same "open in a new tab" pattern as Phase 43; no dependency on 46-07.
Rejected: B (navigate to the spec stage workspace and open its preview at the clause — depends on 46-07); C (no
navigation, a popover with the clause text only).

**Q3 — what the story workflows receive → A.** The Workbench launches pass `answers` (`[{question, answer}]`),
`spec_clauses` (`[{label, text}]`) **and the open `questions`** in the `story` dict; the story-design-analysis 0.3.1 /
story-implementation 0.1.1 ticket block lists "Answered questions", "Open questions — unresolved; do not assume an
answer; raise them in the design's Open Questions" and "Spec clauses this story implements" when present. Rejected: B
(answers + spec_clauses only, as §7 was written).

**Accepted proposals (1–10, 14):**
1. Manual answers address a question by index, CR answers by normalized text (46-06 `normalize_text`). Manual answers
   are allowed in any lane (the lane rule outside a CR stays deferred, umbrella §12).
2. Answer text is capped at **3,000 chars** now (answer API + story PATCH), so 46-09 never meets oversized data;
   `change_log.summary` is already capped at 500 (46-06).
3. `PATCH /features/{fid}/stories/{sid}` accepts `answers`, validated strictly; existing entries keep their
   `answered_by` / `answered_at` / `source` / `cr_no`; new entries are stamped `source: manual` + `canonical_username`.
4. One shared helper enriches `spec_refs` with `{label, text, exists}` in **both** `GET /features/{fid}/stories/{sid}`
   and the Story Workspace read (`GET /applications/{app}/stories/{id}/workspace`, which the page actually uses); the
   workspace read also carries `traceable` and the derived design/spec flags.
5. "A design run started after the entry" is decided server-side from durable data: the story's latest design run
   `runs.created_at` > the entry's `at`. The board card DTO carries the derived flag in **both** `get_board` and
   `get_card`; the workspace read carries the same flag.
6. genesis always sends the new `story` keys (no "workflow declares it" check): both workflows declare `story` as an
   open object (no `additionalProperties: false`), so an older library accepts and ignores them.
7. Badge: a recorded spec version with `revision_no: null` (an unsaved working copy at launch) uses the legacy time
   rule. `spec-reviewed` stores the latest spec revision number + content hash + `reviewed_at` / `reviewed_by`; it is
   allowed for `ux_design`, `technical_design` and `breakdown` (400 for `spec`). The badge is derived in **both** the
   stage GET and the feature detail's `stages` list (which feeds the Overview stage cards).
8. Removed clauses render as muted "removed from the spec" chips and are left out of `spec_clauses`; all clause text
   comes from the consumer clause map (the CR's base revision while a CR is open).
9. Legacy (untraced) features: the "From the spec" card is hidden; answers and change history work for every story.
10. The history card shows "No change · answered N questions" for an answer-only entry by counting the story's
    `answers` with that `cr_no` (no data-model change). Publishing manual answers stays in 46-09.
14. 46-08 owns the Story Workspace cards + design banner, the board-card icon, and the `StageWorkspaceHeader` banner +
    stage-card badge; the spec workspace, CR banner/dialogs, preview tabs and coverage popover are 46-07.
