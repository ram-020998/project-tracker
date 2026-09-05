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
2. **Pull** — materialize/refresh the mirror epics + stories under the feature (map global `sync_uuid` → local
   row); auto for the shared read-only Stories view; notify-then-apply if this user has an unpublished local
   edit to the same story.
3. **Delete** — a deleted story publishes a tombstone (or a soft "deleted" status per the contract) so pullers
   remove it; a delete conflict falls to notify-then-apply.

## Tests

- Finalize → epics/stories on the (fake) Hub; pull on a second instance → same backlog under the feature; edit
  → re-publish → pull reflects it; a delete propagates; CAS conflict → notify. ruff clean.

## Deliverable

Epic/Story publish/pull mappings (Finalize + edit + delete) + tests.

## Gate

Independent review = SHIP: backlog shared correctly; edits/deletes propagate; CAS correct; gates green.

---
