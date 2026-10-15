# 46-09 — Collaboration and the Genesis Hub contract addition

> **Status:** 🟡 DRAFTED 2026-10-14. Repos: **genesis** (collab bindings) + the **Genesis Hub** Appian app (built and
> live-validated by the separate write-capable Dev-MCP agent — genesis stays read-only against Appian, ADR-036/037).
> Parent: `specs/phase-46-spec-change-requests.md`. Additive to the frozen ADR-064 contract v1.0.0, exactly like the
> v0.69.0 `on_board` field and the Phase-42 Object Wiki addition.

## 1. What is shared and what stays local

| Data | Shared? | How |
|---|---|---|
| Spec HTML with `data-cid` attributes | yes | existing `stage_artifact` blob (published at Apply) — pullers compute clause maps from it |
| `kb_stories.spec_refs`, `answers`, `change_log` | yes | new `story` json_cols → arrays on the wire → `GH Story Item` rows (§3) |
| CR records + their frozen documents | yes | new record kind `spec_change_request` + an `artifact` blob (§4) |
| Open-CR working files (sandbox `./cr/…`, `impact-input.json`, live plan) | **no** | local to the owner's machine until Apply/Discard |
| `chat_messages.meta_json` | **no** | chat stays local (ADR-063) |
| `working/last-normalized.html`, `clause-registry.json` | **no** | local repair state |
| "Spec under change" | yes, as an **advisory marker** | existing activity API (§5) |

## 2. genesis bindings (`genesis/collab/service.py`)

- `story` binding: `json_cols = ("acceptance_criteria", "questions", "labels", "spec_refs", "answers",
  "change_log")`. Each element of the three new arrays is sent as a **compact JSON string** (`json.dumps(obj,
  separators=(",", ":"), ensure_ascii=False)`) and parsed back on pull — lossless, and it fits the Story Item text
  field. Element size caps enforced by the API before publish: answer text ≤ 3,000 chars; change_log `summary`
  ≤ 500 chars; every element ≤ 4,000 chars serialized.
- New binding `spec_change_request` → `kb_spec_change_requests`, parents `feature_id → feature_sync_uuid`
  (`kb_features`), `blob_kind="artifact"` (the frozen `document.html`), `html_col="document_path"`
  (pull writes the bytes to the puller's `dir_path` and sets a read-only mirror). Local-only columns:
  `dir_path`, `analysis_id`, `analyzed_at`, `analyzed_spec_hash` (added to `_LOCAL_ONLY` or a per-binding exclude).
- **Publish points** (all opt-in-gated, best-effort, reported): Apply and Discard (46-06 §5, §7); answering /
  editing / reopening a question (the same `publish_story` path as a story edit).
- **Conflict merge for stories** (a teammate edited the same story between our Apply and our publish):
  on `HubConflict`, GET the Hub record, merge, re-PUT once with its `base_version`:
  - fields the CR changed → ours; other scalar fields → theirs;
  - `answers`, `change_log` → union (identity: `(question, answered_at)` / `(cr_no, at)`), sorted by time;
  - `spec_refs` → union by `clause_id`, ours wins on the same ID;
  - `questions` → theirs minus questions we answered.
  A second conflict → "publish pending" in the apply report; the next auto-publish retries. Never pull-overwrite a
  just-applied local change.

## 3. Hub change 1 — `GH Story Item.item_type` values

`item_type ∈ ac | question | label` becomes `ac | question | label | spec_ref | answer | change`. `position` keeps
array order per type. `GH_records_upsert(kind='story')` explodes the three new arrays exactly like the existing three;
`GH_recordToJson` reassembles them as `spec_refs`, `answers`, `change_log` (missing → `[]`). Old Genesis versions
never send the new keys; the Hub returns them only when rows exist — old clients ignore unknown keys.

## 4. Hub change 2 — record kind `spec_change_request` (record type `GH Spec Change Request`)

| Field | Type (Appian tier) | Notes |
|---|---|---|
| `sync_uuid` | Text | primary key |
| `feature_sync_uuid` | Text | parent feature |
| `cr_no` | Integer | 1, 2, 3 … |
| `title` | Text (255) | optional |
| `status` | Text | `applied` \| `discarded` (open CRs are not published) |
| `mode` | Text | `stories` \| `backlog` |
| `opened_by`, `opened_at`, `closed_by`, `closed_at` | Text / Date-time | |
| `base_revision_no`, `result_revision_no` | Integer | `result` null when discarded |
| `summary` | Long Text (4,000) | the `summary_json` (counts + one-line summary) as JSON text |
| `blob_key` | Text | `<feature_sync_uuid>:cr-<nn>` — the frozen document in the existing blob store |
| `content_hash` | Text | of the document |
| `version`, `created_by`, `modified_by`, `created_at`, `updated_at` | as every kind | CAS + attribution |

Served by the **existing generic** `/records/{kind}` + `/changes` endpoints and blob endpoints; the
`GH_records_upsert` inline kind allow-list gains `"spec_change_request"` (the same additive edit the Object Wiki
needed). No new Web API object.

## 5. Advisory marker — "Spec under change by <name>"

On Initiate: `CollaborationService.set_activity(kind="stage_artifact", sync_uuid=<spec stage sync_uuid>,
ttl=86_400)`. The activity API carries only `{kind, sync_uuid, username, set_at, expires}` (no note), so pullers see
**"Spec under change by ram"** — the CR number becomes visible to them when the CR record is published at
Apply/Discard (open CRs are not published, §4). Refreshed on every Analyze impact; cleared on Apply/Discard. Pullers
render it with the existing `<AdvisoryMarker>` on the spec card and spec workspace.

## 6. Pullers

- A pulled spec is a read-only mirror (no chat) — **no CR controls**; the coverage overlay, CR list (applied/discarded
  CRs with their frozen documents) and story traceability UI all work read-only from the pulled data.
- Answers can be added on any machine (stories are shared records); they publish like any story edit.
- The "spec changed" badge on a puller's UX/TD mirrors uses the pulled CR records + the pulled
  `upstream_versions` field (already on the `stage_artifact` contract).

## 7. Contract addition document + fixtures (to be written in this sub-phase)

`specs/phase-36-genesis-hub-appian-app/contract/spec-change-contract-addition.md` (mirroring
`object-wiki-contract-addition.md`): the two changes above, field tables, lossless round-trip requirements, and
fixtures `fixtures/story_with_trace.json` (a story carrying all six arrays, unicode + multi-line strings, empty
arrays) and `fixtures/spec_change_request.json`. The 36-06 harness is extended: byte-for-byte round trip of both
fixtures, CAS 409, `/changes` emission, the blob, and every existing kind still passing.

## 8. Order of work

1. Freeze field shapes (after 46-04 §3 and 46-08 §2/§4 are built).
2. Write the contract addition + fixtures; the separate Appian agent builds + live-validates on the dev-env Hub.
3. genesis bindings + publish points + conflict merge, tested against the `LocalHubProvider` **made strict** for the
   new item types and kind (reject unknown kinds/item types — the 38-01 "permissive stub hid the contract" lesson)
   and against the fixtures.
4. Live check with the two fleet instances (`main` applies a CR; `userb` sees updated stories, the CR in the list,
   and the frozen document).

## 9. Tests

Binding round trip (local → payload → local) for the six arrays incl. size caps; `spec_change_request` publish/pull
with the blob; `_LOCAL_ONLY` exclusions; the conflict merge rules; strict `LocalHubProvider`; fixture conformance;
advisory marker set/refresh/clear.

## 10. Contract freeze (2026-10-15) — handed to the Appian agent

Step 1 of §8 is done: the shapes are frozen in
`specs/phase-36-genesis-hub-appian-app/contract/spec-change-contract-addition.md` + fixtures
`story_with_trace.json` / `spec_change_request.json`; the Appian agent's brief is `46-09-appian-agent-handoff.md`
(the human runs it in parallel with the genesis-side work). Refinements of §2–§4 made while freezing:
- **Absent key preserves.** A story PUT that omits `spec_refs` / `answers` / `change_log` leaves those rows untouched
  (an older Genesis on a teammate's machine must not wipe them); a present key replaces, `[]` clears. The Hub always
  returns the three arrays (`[]` when empty) — this resolves §3's "missing → []" vs "only when rows exist".
- **`spec_change_request` fields:** `opened_at` / `closed_at` are payload-preserved **Text** (not Date-time) so the
  exact strings round-trip; `base_content_hash` added (the local column is NOT NULL, a puller needs it);
  `published_by` / `published_at` added (the stage_artifact attribution model); no stage reference on the wire — a
  puller resolves the feature's spec stage locally, and `stage_id` / `dir_path` stay local.
- **Binding gap fixed in the plan:** the CR document path is derived from `dir_path` (`<dir_path>/document.html`), not
  a `document_path` column.

