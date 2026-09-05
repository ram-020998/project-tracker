# 38-02 — Stories & epics sync

> **Status:** 🟡 DRAFTED. · Part of Phase 38. Repo: **genesis**. · **Depends on:** 38-01 (the feature mapping stories reference), `StoryStore`, Phase 36 (Epic/Story records).

## Purpose

Share the finalized backlog: publish **epics + stories** so the whole team sees the same stories under a shared
feature; pull materializes them locally.

## Build

1. **Publish** — `epic`/`story` mappings in `CollaborationService`: upsert Epic records (kind `epic`, keyed by
   `sync_uuid`, referencing the feature `sync_uuid`) + Story records (kind `story`: `feature_sync_uuid`,
   `epic_sync_uuid`, key, title, story_type, category, appian_part, description, acceptance_criteria,
   dev_note_ref, questions, labels, `status` [the lane], position; owner/team/provenance); base-version CAS.
   Publish trigger = **Finalize Stories** (Phase 32) + on story edit (create/update/delete).
   - **Lists stay arrays in the payload; the local model is unchanged.** `acceptance_criteria`/`questions`/
     `labels` are sent as JSON **arrays** in the story payload (Genesis keeps its local SQLite JSON columns as-is
     — **no local normalization / migration**). The **Appian Hub** normalizes them into `GH Story Item` child
     rows to satisfy the 4000-char synced-record-type limit, and reassembles them into arrays on read (Phase 36
     §2.5b / 36-04) — transparent to Genesis. Single text fields (`description`, `dev_note_ref`) are sent in
     full; if one exceeds 4000 the Hub stores it as ordered `GH Text Chunk` rows and reassembles it on read —
     **never truncated** (Phase 36 §2.0/§2.5c). **The sync is lossless in both directions.**
2. **Pull** — materialize/refresh the mirror epics + stories under the feature (map global `sync_uuid` → local
   row); auto for the shared read-only Stories view; notify-then-apply if this user has an unpublished local
   edit to the same story.
3. **Delete** — a deleted story publishes a tombstone (or a soft "deleted" status per the contract) so pullers
   remove it; a delete conflict falls to notify-then-apply.

## Tests

- Finalize → epics/stories on the (fake) Hub; pull on a second instance → same backlog under the feature; edit
  → re-publish → pull reflects it; a delete propagates; CAS conflict → notify. ruff clean.
- **MANDATORY round-trip fidelity test (no data loss):** for a story with a **> 4000-char description**, **many
  long AC**, **unicode**, **empty `labels`**, and a **null `epic`**, assert `local → payload → Hub (records +
  GH Story Item + GH Text Chunk) → payload → local` reproduces every field **exactly** (content, order, count,
  empty-vs-null). This test is a release gate.

## Deliverable

Epic/Story publish/pull mappings (Finalize + edit + delete) + tests.

## Gate

Independent review = SHIP: backlog shared correctly; edits/deletes propagate; CAS correct; gates green.

---
