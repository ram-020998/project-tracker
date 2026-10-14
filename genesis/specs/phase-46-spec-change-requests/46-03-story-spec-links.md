# 46-03 — Story ↔ spec links (breakdown capture, finalize, coverage)

> **Status:** 🟡 DRAFTED 2026-10-14 (revised the same day: no backfill of existing stories). Repos:
> **genesis-workflows** (`feature-breakdown-analysis` 0.3.0) + **genesis**. Implements the link half of **ADR-075**.
> Parent: `specs/phase-46-spec-change-requests.md`. Depends on 46-02 (clause map) and 46-04 §3 (m0024 columns).

## 1. Goal

Every story (and every backlog item before finalize) records **which spec clauses it implements**, captured at the
moment the breakdown creates it — the most reliable link there is (46-01 §3.1 lesson 2).

**Existing stories are left as they are (user decision, 2026-10-14 — 46-01 §5.6).** Stories and breakdowns created
before Phase 46 get no links and no backfill; traceability and change requests start with breakdowns produced after
this release. §7 defines how such legacy features behave.

## 2. The link record

Stored on `kb_stories.spec_refs` (JSON array, m0024) and, before finalize, as `clauseRefs` on backlog items.

```json
{ "clause_id": "c-9f2a1c0b",
  "fingerprint": "3c1e0d9b77a2f410",   // the clause fingerprint when the link was made or last cleared
  "origin": "breakdown",               // breakdown | cr | manual
  "linked_at": "2026-10-14T09:20:11Z" }
```

- A link may point to a **section** ID (meaning "the whole section"); clause IDs are preferred and the steering says
  so. Section links are treated as broad links in impact analysis (46-05 §4).
- A link is **suspect** when the clause's current fingerprint differs from `fingerprint`. Inside a CR this is how
  impact is found; Apply refreshes the fingerprint of every link on a changed clause (46-06 §4).

## 3. `feature-breakdown-analysis` v0.3.0 (genesis-workflows)

Backward compatible: every change below activates only when the new optional input is present.

| Change | Detail |
|---|---|
| **Input** | `spec_clauses_path` (string, optional): absolute path to a JSON file `{revision_no, content_hash, clauses: [<clause map entries, 46-02 §2>]}` written by genesis at launch. Added to `META.inputs_schema` + `workflow.yaml` (parity lint). |
| **Clause-tagged spec text** | `_load_inputs`: when the clause map is given, `spec.txt` is built **from the clause map** instead of `_strip_html`: one line per block — sections as `## 3.2 Eligibility  [c-1a2b3c4d]`, clauses as `[§3.2-1 c-9f2a1c0b] Applicant must be 18 or older.` |
| **Prompt** (`break_epic_prompt`) | Each item gains `"clauseRefs"`: "the `c-…` IDs of the spec clauses this story/task implements — at least one; prefer clause IDs over section IDs; never invent an ID." |
| **Validator** (`check_stories`) | With a clause map: every item has ≥ 1 `clauseRef`; every ref exists in the map; on failure the message lists the bad refs (drives the retry). Without a clause map: `clauseRefs` optional and unchecked (today's behaviour). |
| **Coverage critic** (`verify_prompt`) | Given the list of requirement clauses no story references, the critic either raises a `Fix` (missing story) or accepts it in the report's summary ("§0-1 is background, no story needed"). |
| **Backlog JSON** (`_build_backlog`) | Story items carry `clauseRefs: [ids]`; the backlog root carries `specRevision: {revision_no, content_hash}`. |
| **Document** (`_story_card_html`) | Each story card shows a small "Spec: §3.2-1, §3.4-2" line (labels from the map). |
| **Version** | `META.version` 0.3.0; `workflow.yaml` mirrors it. |

`_STEERING_FB` (`genesis/chat/mode_profile.py`, the breakdown completion chat) gains: "keep every story's
`clauseRefs` in the embedded JSON; when you add or split a story, give it the clause IDs it implements."

## 4. genesis — launching the breakdown

`_launch_breakdown` (`genesis/api/features.py`):
1. Normalize the spec (46-02 §9) and snapshot it as today.
2. Write `spec_clauses.json` next to `spec_snapshot.html` from the same HTML.
3. Pass `spec_clauses_path` **only if** the installed workflow declares it (`loader.meta_of("feature-breakdown-analysis")
   ["inputs_schema"]["properties"]`); otherwise launch exactly as today (an older library keeps working).
4. Record `upstream_versions_json = {"spec": {"revision_no", "content_hash"}}` on the breakdown row (46-08 §5).

## 5. Finalize → `spec_refs` (+ the workstream bug fix)

`StoryStore.finalize` (`genesis/kb/stories.py`):
- **Bug fix:** epic `workstream` = `epic.get("workstreamRef") or epic.get("workstream")` (today always NULL).
- For each story: `spec_refs` = one record per `clauseRefs` entry with `origin:"breakdown"`,
  `fingerprint` = the clause's fingerprint **in the spec revision recorded in `backlog.specRevision`** (falling
  back to the current consumer spec version, 46-04 §6); refs whose ID is unknown in that map are dropped and
  reported in the finalize response (`dropped_refs`).
- `create_story`/`update_story` accept an optional `spec_refs` list (validated: IDs must exist in the current spec
  clause map; `origin` defaults to `manual`).

## 6. Coverage API

`GET /features/{id}/spec/coverage` → for the consumer spec version:

```json
{ "mode": "stories",            // stories (finalized) | backlog (breakdown completed, not finalized) | none
  "clauses": [ { "clause_id": "c-9f2a1c0b", "label": "§3.2-1", "kind": "clause",
                 "items": [ { "story_id": 41, "key": "GNS_000041", "title": "…", "status": "to-do",
                              "suspect": false } ] } ],
  "uncovered": ["c-77aa0e12"] }  // requirement clauses with no item (sections excluded)
```

- `mode=backlog` reads `clauseRefs` from the breakdown's embedded backlog (`_parse_embedded_backlog`).
- `mode=none` for a legacy (untraced) feature (§7) — the preview then shows clause labels but no badges.
- A section-level ref counts as covering every clause in the section.
- Used by the preview overlay (46-02 §11) and the coverage popover (46-07 §6).

## 7. Legacy features (breakdown produced before Phase 46)

A feature is **traceable** when its breakdown's embedded backlog carries `specRevision` (written only by
`feature-breakdown-analysis` ≥ 0.3.0 run with a clause map, §3), or when any of its stories has a non-empty
`spec_refs`. Helper: `is_traceable(feature_id)` in `genesis/kb/spec_changes.py`.

| | Traceable feature | Legacy feature |
|---|---|---|
| Spec lifecycle after the breakdown | Initiate change request (46-04 §2) | **Unchanged** — Reopen as today |
| Coverage badges in the preview | yes | no (labels only; `coverage.mode = none`) |
| Story "From the spec" card (46-08 §3) | yes | hidden |
| Clause IDs in the spec | yes | yes (the normalizer runs for every spec; harmless) |

A legacy feature whose breakdown is **not finalized** becomes traceable by **re-running the breakdown** (the re-run
reads the clause map); a finalized legacy feature stays legacy. No AI backfill, no confidence scores, no suggested
links.

## 8. Tests

- Workflow: clause-tagged `spec.txt`; validator accepts valid refs, rejects unknown/missing refs with the list;
  backlog carries `clauseRefs` + `specRevision`; without `spec_clauses_path` the graph is byte-for-byte today's
  behaviour (golden run).
- genesis: launch passes the input only when declared; finalize writes `spec_refs` + `workstream`; unknown refs
  dropped + reported; coverage API in all three modes; section refs; `is_traceable` (backlog marker, story refs,
  legacy).

## 9. Acceptance

On a fresh feature: the breakdown cards show "Spec: §…" lines; after finalize every story has ≥ 1 ref; the spec
preview shows a badge per clause and hollow badges for uncovered clauses. An existing (legacy) feature behaves
exactly as before.
