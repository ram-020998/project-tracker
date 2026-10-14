# 02 — Relationships for the site (✅ DONE 2026-10-14)

**Goal:** let a Story view list the wiki entries it produced, and a wiki entry link back to its story.

Done live with `addRecordTypeRelationship` (user approved, decision D3):

1. GH Object Wiki Entry `c9a367bb-fbd0-4ca6-8c84-6358dee73cb5` → **`story`** MANY_TO_ONE → GH Story
   `31c5187d-3c6f-467a-be02-d4549d98a822`; source field `storySyncUuid` `4f6a6c3f-d2d7-4b21-9d1a-f4dfa3b47487`,
   target `syncUuid` `0ebb514f-fd0f-49f7-88ec-a933813858be`. Relationship UUID **`5e33bdce-5007-4bb9-807a-c099712088cf`**. NON_CASCADING.
2. GH Story → **`wikiEntries`** ONE_TO_MANY → GH Object Wiki Entry; source `syncUuid`, target `storySyncUuid`.
   Relationship UUID **`b79fea99-9d9d-4906-bc24-aa010a822fc4`**. Stored as CASCADING by the server (see 01 §A — harmless; optionally flip to Non-cascading in Designer).

**Verification still to do (first thing in sub-spec 05):** query a story that has wiki entries
(story syncUuid `27dde3a9-17c3-4d63-9d5f-d78269ea8a91`, key `story-1-1`) with
`a!queryRecordByIdentifier` including `…relationships.{b79fea99…}wikiEntries.fields.{…}changeKind` and confirm rows return.
Also confirm the Hub Web APIs still work after the change: call `GET /records/story/<syncUuid>` via Genesis
(`/api/collab/pull` on a running Genesis instance, or the Phase-36 contract harness) — expect 200, unchanged shape.

**Do not:** delete/recreate these; do not add other relationships without asking.
