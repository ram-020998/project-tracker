# 46-03 — Story ↔ spec links (breakdown capture, finalize, coverage, existing features)

> **Status:** 🟡 DRAFTED 2026-10-14. Repos: **genesis-workflows** (`feature-breakdown-analysis` 0.3.0, new
> `spec-story-linking` 0.1.0) + **genesis**. Implements the link half of **ADR-075**.
> Parent: `specs/phase-46-spec-change-requests.md`. Depends on 46-02 (clause map) and 46-04 §3 (m0024 columns).

## 1. Goal

Every story (and every backlog item before finalize) records **which spec clauses it implements**, captured at the
moment the breakdown creates it — the most reliable link there is (46-01 §3.1 lesson 2). Existing features whose
stories pre-date Phase 46 get links through a one-time, confidence-scored AI action.

## 2. The link record

Stored on `kb_stories.spec_refs` (JSON array, m0024) and, before finalize, as `clauseRefs` on backlog items.

```json
{ "clause_id": "c-9f2a1c0b",
  "fingerprint": "3c1e0d9b77a2f410",   // the clause fingerprint when the link was made or last cleared
  "origin": "breakdown",               // breakdown | backfill | cr | manual
  "confidence": null,                  // null for breakdown/cr/manual; 0..1 for backfill suggestions
  "confirmed": true,                   // false only for low-confidence backfill suggestions
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
- For each story: `spec_refs` = one record per `clauseRefs` entry with `origin:"breakdown"`, `confirmed:true`,
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
                              "confirmed": true, "suspect": false } ] } ],
  "uncovered": ["c-77aa0e12"],   // requirement clauses with no item (sections excluded)
  "unlinked_items": 12 }          // stories/backlog items with no refs at all (pre-Phase-46)
```

- `mode=backlog` reads `clauseRefs` from the breakdown's embedded backlog (`_parse_embedded_backlog`).
- A section-level ref counts as covering every clause in the section.
- Used by the preview overlay (46-02 §11) and the coverage popover (46-07 §6).

## 7. Existing features — "Link stories to the spec"

For features finalized (or broken down) before Phase 46, `spec_refs` / `clauseRefs` are empty.

### 7.1 The `spec-story-linking` workflow (genesis-workflows, new, 0.1.0)

Deterministic LangGraph graph; every agent node wears the ADR-011 trio.

```
resolve_inputs → load_inputs → next_batch ─(batch)→ link_batch [agent, no MCP] → v_links → advance → next_batch
                                          └─(done)→ assemble [program: links.json] → present → cleanup
```

- **Inputs:** `feature_id`, `spec_clauses_path` (clause map), `items_path` (JSON written by genesis: stories or
  backlog items `{id, key, title, description, acceptance_criteria, epic_title}`), `mode` (`stories`|`backlog`).
- **Batching:** one batch per epic (max 25 items per batch; larger epics split).
- **`link_batch` prompt:** the clause-tagged spec text + the batch; output per item
  `{item_id, refs: [{clause_id, confidence 0..1, reason}]}`; "only link a clause the item genuinely implements;
  confidence < 0.5 means leave it out".
- **`v_links`:** every item of the batch present once; every clause ID exists; confidence in [0,1].
- **Output:** `links.json` = all items' refs.

### 7.2 genesis

- `POST /features/{id}/spec/link-stories` → normalizes the spec, writes the inputs, starts the run (409 if not
  installed / no stories or backlog / a linking run is already active). Response `{run_id}`.
- `SpecLinkFinalizer` (RunManager observer, same pattern + guards as `StageFinalizer`: bound-run check, idempotent,
  on-read recovery, failures logged) applies `links.json` on `run.final{done}`:
  - `confidence ≥ 0.8` → `confirmed:true`; `0.5 ≤ confidence < 0.8` → `confirmed:false` (a **suggested** link);
  - `origin:"backfill"`; fingerprint = the clause's current fingerprint; existing refs are kept (union);
  - backlog mode writes `clauseRefs` into the embedded backlog via the 46-06 §6 backlog writer.
- The coverage API reports `unlinked_items`; the spec workspace shows the banner (46-07 §8) while it is > 0 and no
  linking run has completed for this feature.
- Suggested links appear dashed in the coverage popover and on the story (46-08 §3) with **Confirm** / **Remove**.

## 8. Tests

- Workflow: clause-tagged `spec.txt`; validator accepts valid refs, rejects unknown/missing refs with the list;
  backlog carries `clauseRefs` + `specRevision`; without `spec_clauses_path` the graph is byte-for-byte today's
  behaviour (golden run); `spec-story-linking` full-graph run with a fake agent.
- genesis: launch passes the input only when declared; finalize writes `spec_refs` + `workstream`; unknown refs
  dropped + reported; coverage API in both modes; section refs; `SpecLinkFinalizer` idempotency + threshold rules.

## 9. Acceptance

On a fresh feature: the breakdown cards show "Spec: §…" lines; after finalize every story has ≥ 1 confirmed ref;
the spec preview shows a badge per clause and hollow badges for uncovered clauses. On an existing finalized feature:
"Link stories to the spec" completes and ≥ 90% of stories get ≥ 1 confirmed ref (spot-checked by the user).
