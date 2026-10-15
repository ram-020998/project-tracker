# 46-05 — Analyze impact: the diff, the impact input, the plan and the CR document

> **Status:** ✅ BUILT + SHIPPED (genesis v0.77.0 / genesis-workflows v0.22.0, 2026-10-15; as-built in `progress/phase-46-spec-change-requests.md`) — drafted 2026-10-14. Repo: **genesis**. Implements the analysis half of **ADR-076**.
> Parent: `specs/phase-46-spec-change-requests.md`. Decisions D6, D8–D10, D13–D15.

## 1. Goal

When the PO clicks **Analyze impact**, Genesis (program code) computes exactly what changed in the spec and which
stories/backlog items those changes touch; the agent in the spec chat turns those facts into a **plan** of
per-item decisions; Genesis renders the **"CR-03 Impact Analysis"** document from the plan. Nothing is applied.

## 2. Flow

```
[Analyze impact] ─▶ POST /features/{id}/change-requests/3/analyze           (program, < 1 s)
                       normalize spec.html → diff(base, working) → affected items → impact-input.json
                       CR.analysis_id/analyzed_at/analyzed_spec_hash updated; old plan.json archived
                  ◀─ {analysis_id, counts, no_changes}
web: if no_changes → toast "No spec changes since CR-03 opened"; stop.
endpoint: also posts the agent note (instructions, enqueue_agent_note) — the single author of that note
web: sends the chat turn "Analyze impact for CR-03."  (visible user message; nothing else)
agent: reads impact-input.json → writes ./cr/CR-03/plan.json → summarizes in chat
web: CR detail shows analysis.state=current; the document is available (Preview → "CR-03 Impact Analysis")
PO ↔ agent in chat: "make GNS_000057 a follow-up" → agent rewrites plan.json → document re-renders on refresh
```

The analyze endpoint never calls the agent; the chat turn is an ordinary turn (normal credits, normal streaming), so
the PO sees and can interrupt it like any other.

## 3. The deterministic diff — `genesis/kb/spec_diff.py` (new)

Input: base clause map (from `base.html`) and working clause map (normalized sandbox `spec.html`).

| Classification | Rule |
|---|---|
| `unchanged` | same ID, same fingerprint, same section, same position among the section's clauses |
| `moved` | same ID and fingerprint; different section or position — **not a change** (no impact) |
| `formatting` | same ID; fingerprint differs; `formatting_key` equal (46-02 §5) — **no impact**, auto-cleared |
| `modified` | same ID; `formatting_key` differs. If its section or position also changed, the change carries `"moved": true` (shown in the document as "modified and moved") |
| `added` | ID only in working |
| `removed` | ID only in base |
| section changes | a heading whose text changed is `modified` with `kind: "section"`; it does **not** by itself make its clauses changed |

Output `SpecDiff = {changes: [{clause_id, kind, change, section_path_before, section_path_after, label_before,
label_after, before, after, fingerprint_before, fingerprint_after}], counts}`. `before`/`after` are normalized texts;
the document renders a word-level diff of them (§7).

## 4. Affected items

**Stories mode** (stories finalized). For each `modified` / `removed` clause (and each `modified` section): every
story with a `spec_refs` entry on that clause ID — or on its section ID (a *broad* link) — is affected. Each affected
story is included once, listing all its matched clause IDs and `match ∈ {linked, broad}`.

Also included:
- Stories with **no** `spec_refs` (e.g. added manually without refs) are not considered — on a traceable feature every
  breakdown and CR story has refs, and manual stories can be given refs (46-03 §5). CRs exist only on traceable
  features (46-03 §7).
- **Added clauses** with no story → `new_clauses`.
- `formatting` and `moved` changes are listed (for the document) but produce no affected items.

**Backlog mode** (breakdown completed, not finalized): the same, over the embedded backlog's items and their
`clauseRefs`; item identity = the backlog id (`story-2-3`); lanes do not apply (every item is editable).

Per affected story the program also computes:
- `lane` (story status) and `lane_group`: **`editable`** for `to-do`, `design`; **`locked`** for `design-review`
  and later (D14);
- `design_state`: `none | running | done | failed` (from `kb_story_stages` + the runs table, as the board DTO does);
- `implementation_state`: `none | running | done | failed`;
- `row_version` (for the Apply CAS, 46-06 §3).

## 5. `impact-input.json` (written by genesis into `./cr/CR-03/`)

```json
{ "schema": "genesis.cr-impact-input/1",
  "analysis_id": "6f0c…",                    "cr": "CR-03", "mode": "stories",
  "feature": {"id": 12, "name": "Corporate onboarding"},
  "base_revision": 6, "working_hash": "…",
  "changes": [ {"clause_id": "c-9f2a1c0b", "change": "modified", "label_before": "§3.2-1", "label_after": "§3.2-1",
                "section_path_after": ["3 Eligibility", "3.2 Corporate applicants"],
                "before": "Corporate applicants provide a registration number.",
                "after":  "Corporate applicants provide a registration number or an LEI."} ],
  "ignored_changes": [ {"clause_id": "c-…", "change": "formatting"}, {"clause_id": "c-…", "change": "moved"} ],
  "affected": [ {"story_id": 41, "key": "GNS_000041", "title": "…", "story_type": "Story", "category": "core",
                 "appian_part": "form", "epic_id": 3, "epic_title": "…", "description": "…",
                 "acceptance_criteria": ["Given …"], "questions": ["…"], "answers": [],
                 "dev_note_ref": "…", "labels": [], "lane": "to-do", "lane_group": "editable",
                 "design_state": "none", "implementation_state": "none", "row_version": 3,
                 "matched_clause_ids": ["c-9f2a1c0b"], "match": "linked"} ],
  "new_clauses": [ {"clause_id": "c-77aa0e12", "label": "§6.4-1", "section_path": ["6 Notifications"],
                    "text": "Notify the relationship manager by email when …"} ],
  "epics": [ {"id": 3, "key": "epic-2", "title": "…"} ],
  "rules": { "editable_lanes": ["to-do", "design"],
             "decisions": ["update", "no_change", "remove"],
             "editable_fields": ["title", "description", "acceptance_criteria", "questions", "labels",
                                 "dev_note_ref", "appian_part", "story_type", "category"] } }
```

In backlog mode `affected[]` items carry `backlog_id` instead of `story_id`/`key`/`lane*`/`*_state`/`row_version`.

## 6. Staleness (D10)

`analysis.state` (in the CR detail):
- `none` — Analyze impact has never run for this CR;
- `awaiting_plan` — the impact input exists for the current `analysis_id` but no plan with that `analysis_id` has been
  written yet (the agent turn is running, failed, or was interrupted) — the banner offers **Ask the agent to write the
  plan** (46-07 §4);
- `current` — `plan.json` exists with `analysis_id == CR.analysis_id` **and** the normalized working-copy hash equals
  `analyzed_spec_hash`;
- `stale` — the working copy changed after the analysis (any agent turn that edited `spec.html`), or the plan is for
  an older `analysis_id`.

Apply requires `current` + a valid plan. The web shows "The spec changed after the analysis — Analyze impact again"
(46-07 §4). Re-analyzing keeps the agent's earlier decisions available: the previous `plan.json` is archived as
`plan.<n>.json` and `instructions.md` tells the agent to carry forward decisions for items that are still affected.
This carry-forward is **best-effort agent behaviour**, not program-enforced: the program only validates the new plan
against the new impact input.

## 7. The plan — `./cr/CR-03/plan.json` (written by the agent)

```json
{ "schema": "genesis.cr-plan/1",
  "analysis_id": "6f0c…",
  "summary": "Corporate applicants may give an LEI instead of a registration number; RM email notification added.",
  "clause_notes": [ {"clause_id": "c-9f2a1c0b", "classification": "new-scope",
                     "summary": "LEI accepted as an alternative identifier"} ],
  "decisions": [
    {"story_id": 41, "decision": "update", "clause_ids": ["c-9f2a1c0b"],
     "rationale": "The form must accept an LEI; AC 2 changes.",
     "changes": {"acceptance_criteria": ["Given …\nWhen …\nThen …"]},
     "answer_questions": [{"question": "Do we accept LEI?", "answer": "Yes — CR-03 §3.2-1"}],
     "user_requested": false},
    {"story_id": 52, "decision": "no_change", "clause_ids": ["c-9f2a1c0b"],
     "rationale": "Wording only; the AC already covers both identifiers.",
     "answer_questions": [{"question": "Is the LEI optional?", "answer": "Yes, either identifier is enough."}]},
    {"story_id": 57, "decision": "no_change", "clause_ids": ["c-9f2a1c0b"],
     "rationale": "In Implementation — left unchanged; follow-up GNS story N1 covers LEI validation.",
     "user_requested": false},
    {"story_id": 63, "decision": "no_change", "clause_ids": ["c-9f2a1c0b"],
     "rationale": "The summary screen shows whichever identifier was captured; no change."} ],
  "new_stories": [
    {"temp_id": "N1", "follow_up_of": 57, "epic_id": 3, "title": "Validate LEI for corporate applicants",
     "story_type": "Story", "category": "core", "appian_part": "process-model",
     "description": "As a …\nI want …\nSo that …", "acceptance_criteria": ["Given …\nWhen …\nThen …"],
     "dev_note_ref": "See Technical Design → 'Corporate onboarding' workstream",
     "questions": [], "labels": [], "clause_ids": ["c-9f2a1c0b"],
     "rationale": "GNS_000057 is past Design; the LEI check is new scope."} ],
  "no_story_needed": [ {"clause_id": "c-…", "reason": "Background text"} ] }
```

- `decisions` items in backlog mode use `backlog_id`; `new_stories` may use `epic_key` (backlog epic id).
- `changes` holds only the fields that change (full new value per field). `add_spec_refs` / `remove_spec_refs`
  (clause ID lists) are optional per decision; by default Apply adds the decision's `clause_ids` that are `added`
  clauses and keeps the rest.
- `remove` deletes the story (or backlog item) on Apply.
- `answer_questions` is allowed with any decision except `remove` (it records the PO's answer; it is the only
  change a `no_change` decision may carry). On a locked story it counts as a change and needs `user_requested`.

## 8. Plan validation — `validate_plan(plan, impact_input, db) -> {ok, errors[], warnings[]}`

Errors block Apply; warnings are shown only.

| # | Rule | Level |
|---|---|---|
| V1 | JSON parses; `schema == "genesis.cr-plan/1"`; `analysis_id` matches the CR | error |
| V2 | **Completeness:** every `affected` item has **exactly one** decision; no decision for an item not in `affected`; no duplicates | error |
| V3 | Story/backlog IDs belong to the feature; `follow_up_of` / `epic_id` / `epic_key` exist in the feature (epics are fixed — no new epics) | error |
| V4 | **Lane rule:** a `locked` item with `decision != no_change`, or with `answer_questions`, requires `user_requested: true` (and its rationale should quote the request — warning if it doesn't look like a quote) | error / warning |
| V5 | `changes` keys ⊆ `rules.editable_fields`; values have the right types; `story_type ∈ Story|Task`; `category ∈ core|nice-to-have` | error |
| V6 | Acceptance criteria of a `Story` are Gherkin (`Given … When … Then …`, the breakdown rule); a `Task` may have none | error |
| V7 | `clause_ids` exist in the working map, or in the base map for `removed` clauses | error |
| V8 | Every `new_clauses` entry is covered by a new story, an `add_spec_refs` of an updated story, or `no_story_needed` | error |
| V9 | Every new story has ≥ 1 clause ID, a title, a description | error |
| V10 | `remove` on a story whose implementation is `running` or `done` | error |
| V11 | Decision `update` on an item whose design or implementation run is `running` | error ("wait for the run, or choose no_change") |
| V12 | An `update` of a Design-lane story whose design is `done` | warning — Apply sets `needs_design_rerun` (46-08 §4) |

`GET …/{cr_no}/plan` returns `{plan, validation}`; the document shows the validation box (§9) and the CR banner offers
"Ask the agent to fix" (posts the error list as a chat message).

## 9. The CR document — `genesis/kb/cr_document.py` (new, deterministic)

`render_cr_document(cr, impact_input, plan, validation, *, status, apply_report=None) -> html`. Self-contained,
script-free, Lavish-safe HTML (same conventions as the breakdown document; tokens via the existing theme injection).

Sections, in order:
1. **Header:** "CR-03 Impact Analysis" · title · status chip (*Open — draft*, *Open — out of date*, *Applied*,
   *Discarded*) · opened by/at · base revision → (result revision) · analysis time.
2. **Summary:** `plan.summary`; counts: clauses changed / added / removed; stories to update / create / remove /
   unchanged; locked stories untouched.
3. **Validation** (only when there are errors/warnings): list, each with the item it concerns.
4. **Spec changes:** per changed clause — label, section path, classification chip (from `clause_notes`), before/after
   with word-level `<del>`/`<ins>` (stdlib `difflib`), and the decisions that reference it. Collapsed list of
   formatting-only and moved clauses.
5. **Affected stories** grouped by clause: key · title · lane chip · decision chip (*Update*, *No change*,
   *Remove*, *Locked — no change*, *Updated at your request*) · rationale · for `update` a per-field diff (old → new;
   AC as lists) · answered questions.
6. **New stories:** cards (temp id `N1` → after Apply the real `GNS_` key), epic, follow-up-of link, type, category,
   description, AC, clauses.
7. **Removed requirements:** the removed clauses and what was decided for their stories.
8. **Uncovered new requirements:** `no_story_needed` with reasons.
9. **Footer (after Apply):** the apply report — created keys, updated keys, removed keys (with snapshot link),
   design re-runs flagged, publish result.

Every block carries a stable element id (`cr-clause-<id>`, `cr-story-<id>`, `cr-new-<temp_id>`) so Lavish
annotations quote meaningful targets.

**Endpoints:**
- `GET /features/{id}/change-requests/{cr_no}/document?theme=&annotate=1` — open CR: rendered **live** from the
  sandbox files on every request (cheap; always matches the plan); applied/discarded CR: the frozen `document.html`.
  Lavish injected when `annotate=1` (same `_inject_artifact` path as stage artifacts); a placeholder ("No analysis
  yet — click Analyze impact") before the first plan.
- `GET …/{cr_no}/export.md` — `markdownify` of the document.

## 10. Tests

`spec_diff` classification table (each row, incl. moved vs modified, formatting-only, section rename); affected-item
selection (linked, broad, backlog mode); lane groups and run states; impact-input
golden file; every validator rule (V1–V12) with a failing and passing case; renderer golden HTML for an open, an
applied and a discarded CR; staleness transitions (edit after analysis → stale; re-analyze → none → plan → current);
analyze endpoint guards (no open CR, spec unchanged, chat busy).

## 11. Build decisions (2026-10-15, before the build — recorded with the user)

Asked one question at a time; the user chose option A for both. The other points (gaps 3–16) were proposed by the
assistant at the 46-05 restatement and accepted by the user ("Yes") without change. They refine §2–§9 above; where
they differ, this section wins.

**Q1 — attaching a new clause to an existing story → A (candidates).** Each `new_clauses` entry carries
`candidates`: the stories (backlog items in backlog mode) linked to any *other* clause of the same section (direct
or via a section ref), with the same fields as an `affected` item (lane, `lane_group`, run states, `row_version`).
The plan may hold an `update` decision for a candidate **only to attach new clauses** (`add_spec_refs` ⊆ the new
clause IDs it is a candidate for; `changes` / `answer_questions` allowed as for any update). V2 becomes: every
`affected` item has exactly one decision; a decision may target an affected item **or** a candidate; nothing else;
no duplicates. V8 counts a candidate update's `add_spec_refs` as covering the clause. The lane rule (V4), run-state
rules (V10/V11) and Apply's `row_version` check (46-06 A5) apply to candidates too. Rejected: B (section-linked
stories auto-affected — rare, since links are clause-level); C (new clauses only via new stories / no story needed).

**Q2 — a CR that only reformats or moves clauses → A.** `no_changes` is returned only when the working copy has
**no differences at all** from the base (identical clause maps: IDs, fingerprints, order, sections). A
formatting/moved-only CR is analyzed normally: `affected` is empty, the agent writes a plan with no decisions (a
summary only), and Apply saves the spec as a new revision without touching a story. Rejected: B (formatting/moves =
no change → only Discard possible, edits lost); C (Genesis writes the empty plan itself — breaks D8, the agent is
the only plan author).

**Accepted refinements (gaps 3–16):**
3. **Position** = index among the clauses present in **both** versions within the section (LCS-stable), so one
   insertion does not mark later siblings `moved`.
4. **Broad link** = a ref to **any ancestor section** of the changed clause (as coverage does). A modified heading
   affects only stories linked directly to that section. Removed clauses use the **base** map's ancestry.
5. **Run states:** `pending | running | awaiting_input*` → `running`; `done` → `done`; `failed | cancelled` →
   `failed`; no story stage / no run → `none`.
6. **Staleness order:** no `analysis_id` → `none`; working hash ≠ `analyzed_spec_hash` → `stale`; no `plan.json` →
   `awaiting_plan`; plan `analysis_id` ≠ the CR's → `stale`; else `current` (validation reported alongside).
7. `validate_plan` stays **pure**: `validate_plan(plan, impact_input, *, story_ids, base_map, working_map)` —
   `story_ids` = every story id of the feature (for `follow_up_of`), not a db handle.
8. **V6** duplicates the breakdown's rule (`(?is)\bgiven\b.*\bwhen\b.*\bthen\b` per criterion; a Story needs
   ≥ 1), applied to the story **as it would be after** the change (no workflow import, ADR-012).
9. The impact builder parses `kb_stories.answers` itself; `StoryStore` gains it in 46-08.
10. The breakdown's content hash at analysis (for 46-06 A8) is recorded in `impact-input.json`
    (`breakdown_hash`), not a new column.
11. The document shows the "No analysis yet" placeholder only **before the first analysis**; while awaiting the
    plan it renders the computed facts with each item marked "awaiting the agent's plan".
12. CR detail computes `can_apply` / `apply_blockers` now from A1–A4 (CR open + spec under change, chat idle,
    analysis `current`, plan valid). A5–A8 run inside Apply (46-06).
13. **Discard freezes the CR document** with status *Discarded* (when an analysis exists) — built in 46-05 now that
    the renderer exists (46-04 had deferred it).
14. **Analyze guards:** runs under the per-spec lock; 409 when the CR is not open / the spec is not under change /
    the chat is busy. `no_changes` returns 200 and writes nothing (no files, no analysis id, no note).
15. **The single analysis note:** a `cr-analyzed` divider ("Impact analysis for CR-03 — N stories affected, M new
    clauses") whose hidden agent text says: read `impact-input.json`, write `plan.json`, carry forward decisions
    from `plan.<n>.json`.
16. The plan may carry an optional `title_suggestion` (Q5) — shown in the document only; never auto-applied.
