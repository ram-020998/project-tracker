# 38-04 — Deferred UI items (attribution, cross-stage staleness, drag-reorder publish)

> **Status:** 🟡 OPEN — carried into **38-06** (code review & hardening). · Part of Phase 38. Repo: **genesis**.
> **Author:** Genesis agent (2026-09-06). · **Context:** 38-04 shipped the collaboration-UX **foundation +
> the primary mounts** (publish-on-complete on stages, board lane-move auto-publish on the explicit move path,
> Sync-now/auto-pull). Three spec items from 38-04 §6 were **intentionally not mounted**; this doc records
> exactly what, **why** (a real constraint, not an oversight), what **is** already available, and the
> **options** to close each gap so 38-06 can decide deliberately.

---

## 1. What shipped in 38-04 (for contrast)

- **`genesis/api/collab_sync.py`** — the per-entity publish/pull/advisory endpoints (publish stage [by id + by
  `(feature, stage)`], backlog, story, board-move, deletion; `POST /collab/pull`; `GET/POST/DELETE
  /collab/activity/{kind}`), with 37-05-consistent Hub error mapping.
- **Web** — `lib/api/collab.ts` + `types/collab.ts` + `qk.collab.activity` + `features/collab/hooks.ts`
  (`usePublishStage`/`usePublishBacklog`/`usePublishBoardMove`/`usePull`/`useActivity`/…) +
  **`features/collab/SdlcControls.tsx`** (`<PublishToTeamButton>`, `<PublishedBy>`, `<AdvisoryMarker>`) with
  vitest + jest-axe.
- **Mounts** — `<PublishToTeamButton>` in the `StageArtifactWorkspace` action bar (all four stages;
  publish-on-complete + opt-in gated); `useMoveCard` best-effort auto-publish of a lane move (gated on the
  cached opt-in config); a **Sync now** control in Settings → Collaboration.

`<PublishedBy>` and `<AdvisoryMarker>` are **built + unit-tested** but only `<AdvisoryMarker>`'s data path
(`/collab/activity`) is wired; `<PublishedBy>` is not yet mounted on a per-entity surface (see §2).

---

## 2. Deferred item A — per-entity "Published by X • \<when\>" attribution

### What's missing
`<PublishedBy>` is not mounted on the **stage** surfaces (the feature stage cards / stage workspace header).

### Root cause (a real, structural constraint — NOT an oversight)
Phase 38 is a **no-migration** phase (the umbrella + every sub-spec: *"No migration; m0019 stands."*). The
provenance columns needed for attribution — `published_by` / `published_at` / `published_version` — were added
by **m0019** (Phase 35) **only to the three top-level synced tables**:

```
genesis/db/migrations/m0019_collab.py
  _PROVENANCE_TABLES = ("kb_features", "kb_stories", "workbench_boards")   # ← have published_by/at/version
  _UPSTREAM_TABLES   = ("kb_feature_stages", "kb_story_stages")            # ← got upstream_versions_json ONLY
```

So **`kb_feature_stages` has no `published_by`/`published_at`/`published_version` column.** That is exactly why
`CollaborationService` tracks a stage's published version in the `collab_sync_state` cursor
(`feature_stage:<sync_uuid>`) instead of a row column (see `_local_published_version` /
`_record_published_version`). There is **no local column to read a stage's publisher from**, so per-stage
attribution cannot be surfaced from local data without either a schema change or an extra Hub read.

### What IS already available (no new work)
Attribution **is** derivable for the entities whose tables carry the columns:
- **Features** (`kb_features.published_by`/`published_at`), **stories** (`kb_stories.*`), **boards**
  (`workbench_boards.*`). Mounting `<PublishedBy publishedBy=… publishedAt=…/>` on the Features list / a story
  detail / a board card is a **pure wiring task** once those fields are exposed by their read APIs.
- The **change manifest** already carries `published_by` per change (`GET /collab/changes` →
  `HubChange.published_by`), so a *recent-activity* attribution ("last changed by X") can be shown from the
  manifest **without any schema change**.

### Options to close the stage gap (for 38-06 to choose)
| # | Option | Cost | Tradeoff |
|---|---|---|---|
| A1 | **Mount attribution only where columns exist** (features / stories / boards) + a manifest-derived "last changed by X" hint on stages. | Low (wiring only). | Stages get a weaker (manifest) attribution, not a per-row one. **No migration.** |
| A2 | **Additive migration `m0020`** adding `published_by`/`published_at`/`published_version` to `kb_feature_stages` (+ `kb_story_stages`), then have `_record_published_version` write them. | Medium (a migration + `current_version` 19→20 + bump the hardcoded-version tests). | **Breaks the "no-migration" property of Phase 38** — needs explicit user sign-off. Cleanest long-term. |
| A3 | **Read the Hub record's `published_by` on demand** for a stage (an extra `get_record` per card). | Low-medium. | Extra Hub round-trips; only works online; no offline attribution. |

**Recommendation:** **A1** for this program (keeps Phase 38 no-migration; full per-row attribution on the three
tables that already support it, manifest hint on stages). Revisit **A2** as a small standalone follow-up if
per-stage row-level attribution is wanted (it's a clean additive migration).

---

## 3. Deferred item B — the cross-stage staleness badge

### What's missing
`<StalenessBadge>` is **not** mounted to show *"Spec changed (v1→v2) since this stage was built"* on a
downstream stage.

### Root cause + what's available (this one is CLOSE)
Unlike attribution, the **input data exists**: m0019 **did** add `upstream_versions_json` to
`kb_feature_stages` (the snapshot of the upstream artifact versions a stage consumed at start), and 38-01 the
staleness component (`features/collab/staleness.ts::isStale`, notify-only) already exist and are unit-tested.
The gap is purely **plumbing two numbers to the component**:
1. the stage's **consumed** upstream version — from `kb_feature_stages.upstream_versions_json` (present, just
   not yet returned by the stage GET API);
2. the upstream artifact's **current** published version — which the service tracks in `collab_sync_state`
   (`feature_stage:<upstream sync_uuid>`) or which arrives on the change manifest.

### Option (for 38-06)
- **B1:** extend the feature/stage read API to return `upstream_versions_json` (parsed) per stage + expose the
  upstream stages' current published versions (from `collab_sync_state`), then render
  `<StalenessBadge localVersion={consumed[upstream]} hubVersion={currentUpstream} onReview={…}/>` on the
  downstream stage card. **No migration** (the column already exists). `onReview` routes to the existing pull
  flow. This is a **mostly-frontend + one thin API field** task — the reason it was deferred from 38-04 is
  scope/time, not a structural blocker.

**Recommendation:** do **B1** in 38-06 — it's the one deferred item with no structural obstacle and it delivers
the headline "cross-stage staleness" affordance the spec calls out.

---

## 4. Deferred item C — drag-reorder auto-publish (vs. the explicit-move path)

### What's mounted vs. missing
38-04 wired auto-publish on the **explicit** card move (`useMoveCard.onSuccess` → `publishBoardMove`,
best-effort, gated). The **drag-and-drop** path on the board persists via **`useReorderLane`** (a *bulk*
`PATCH …/lanes/{lane}` that sets `board_position` + `status` for every listed card) — and that path does **not**
yet auto-publish.

### Why it was deferred (a correctness nuance, not laziness)
`reorderLane` bundles **two** concerns that Phase 38 treats differently:
- **in-lane ordering** (`board_position`) — **local-only**, must **never** publish (locked decision §3.5);
- **the lane/status** of the one card that crossed lanes — **should** publish.

Because the bulk call can't cleanly tell *which* card crossed lanes, the naive fix (publish `board_state` for
every card in the lane on every reorder) would (a) generate a request **storm** for large lanes and (b) blur the
"ordering stays local" line (even though re-publishing an unchanged status is idempotent). So the explicit-move
path was wired (correct + bounded) and the drag path deliberately left for a considered fix.

### Options (for 38-06)
| # | Option | Notes |
|---|---|---|
| C1 | In `BoardPage.onDragEnd`, detect the **single card whose lane changed** (compare its pre-drag lane to the drop lane) and call `publishBoardMove(appUuid, thatStoryId)` once. | Best fix — one publish per cross-lane drag; pure in-lane reorders publish nothing. Needs the crossed-card id at the drop site (the board already knows it). |
| C2 | Have `reorderLane`'s result / the board diff the previous lane and publish only changed-lane cards. | Slightly more logic in the hook; also correct. |
| C3 | Leave as-is (explicit move publishes; drag relies on the next Sync/again). | Weakest UX. |

**Recommendation:** **C1** in 38-06 (publish exactly the crossed card on drag-drop).

---

## 5. Net for 38-06

- **B1** (cross-stage staleness) and **C1** (drag-drop lane publish) are **no-migration** and should be
  **implemented in 38-06** — they finish the 38-04 spec surface.
- **A1** (attribution where columns exist + a manifest hint on stages) is the **no-migration** attribution
  answer; mount it in 38-06.
- **A2** (a `m0020` migration for per-stage provenance columns) is the only item that would break Phase 38's
  no-migration property — **flag to the user**; do it only as a sanctioned standalone follow-up if row-level
  per-stage attribution is required.

None of these block **38-05** (adoption bulk-publish), which is independent of these display affordances.
