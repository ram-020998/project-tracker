# Phase 38 — Collaborative SDLC — AS-BUILT (✅ SHIPPED, genesis v0.65.0, 2026-09-06)

> **Status:** ✅ **COMPLETE + SHIPPED — genesis v0.65.0** (`394f29e`, tag `v0.65.0`; CI master #6745235 / tag
> #6745236). Single-repo **genesis**; **no migration** (Phase-35 m0019 stands); no core/SDK/workflows pin
> moves. Implements **ADR-063** for the human-authored entities, over the Phase-37 `AppianHubProvider` +
> `CollaborationService`. Umbrella: `specs/phase-38-collaborative-sdlc.md` (+ `38-01..38-07`). **Fourth and
> final phase** of the collaboration program (35 → 36 → 37 → **38**).

## What shipped

The human-authored SDLC work products — **features + published stage artifacts, epics/stories, boards** —
now sync across the team with the full collaboration UX + a one-time adoption path, all **opt-in / off by
default** (a solo install is unchanged). The whole mechanism is **provider-agnostic** and was built + verified
against the file-backed `LocalHubProvider`; the live Appian Hub is the same interface (Phase 37).

### 38-01 — features + published stage artifacts
`CollaborationService` gained **cross-machine parent resolution** (`_ParentRef`: a local int FK ↔ the parent's
global `sync_uuid`) + **artifact-bytes** sync. **`publish_feature_stage`** (publish-on-complete): gates on
`status=='completed'`, lazily publishes the parent Feature, uploads the artifact **bytes** as an `artifact`
blob, then puts the stage metadata with a base-version CAS. **No-leak:** `chat_session_id`/`run_id`/local
`html_path`/`feature_id` never reach the Hub (`_LOCAL_ONLY` + `_map_out` FK translation). **Pull = read-only
mirror:** resolves the parent (skip-and-retry if not local yet — the cursor never advances past an unresolved
parent), writes the bytes to the puller's **own** `feature_stage_artifacts_dir/<id>/pulled.html` + points
`html_path` there, leaves chat/run null. Stages have no `published_version` column (m0019), so their CAS base
is the `collab_sync_state` cursor `feature_stage:<sync_uuid>`.

### 38-02 — stories & epics
`epic` + `story` bindings. **Optional parent** (a story's nullable `epic_id` stays null, never skipped).
**`json_cols`** (`acceptance_criteria`/`questions`/`labels`) are stored locally as JSON strings but travel as
**arrays** on the wire (so the Appian `GH Story Item` normalization can explode them) — lossless both ways.
**`publish_feature_backlog`** (the Finalize trigger — feature + epics + stories), **`publish_epic`/
`publish_story`** (lazy-publish parents), **`publish_deletion`** (a `{_deleted:true}` tombstone → pull removes
the mirror). A **mandatory round-trip fidelity test** (multi-KB unicode/emoji description, 20 long AC, empty
labels, null epic) is a release gate.

### 38-03 — boards
**Lane = the story's `status`** (rides the Story record — already synced by 38-02). **`publish_board_move`** =
`publish_story` (status, CAS) + a **BoardState** signal record. **Automatic membership:**
`reconcile_board_membership` adds a card for every **shared finalized** story of the app on the **local** board
(cross-machine because the pulled feature carries `stories_finalized_at`). `pull_boards` drains BoardState +
reconciles all local boards. **In-lane `board_position` + which boards you curated (`workbench_boards`) stay
LOCAL** (never published).

### 38-04 — collaboration UX
Thin backend action surface **`genesis/api/collab_sync.py`** (publish stage[by id + by `(feature,stage)`]/
backlog/story/board-move/deletion; `POST /collab/pull`; `GET/POST/DELETE /collab/activity/{kind}`; adopt) with
37-05-consistent Hub error mapping (409/401/503/404; disabled→409; advisory→empty). Web: the API client +
hooks + **`SdlcControls`** (`<PublishToTeamButton>` [publish-on-complete + opt-in gated], `<PublishedBy>`,
`<AdvisoryMarker>`) reusing the Phase-37 `<HubStatus>`/`<StalenessBadge>`; jest-axe. **Mounts:**
`PublishToTeamButton` in the stage workspace action bar (all four stages); an explicit board lane move
auto-publishes (best-effort, gated on the cached opt-in config); a **Sync now** control in Settings →
Collaboration.

### 38-05 — adoption (bulk publish)
**`adoption_preview`** counts the local completed/finalized work not yet published; **`adopt_publish`**
publishes only those (stages→epics→stories→boards) — **idempotent** (re-run = no-op), **never automatic**,
`require_onboarded`, disabled→zeros. `GET /collab/adopt/preview` + `POST /collab/adopt`; a Settings
**AdoptionCard** with a two-step explicit confirm.

### 38-06 — review & hardening
**Independent audit → VERDICT: SHIP** (no MUST-FIX). Applied: **C1** (drag-drop cross-lane publish — only the
crossed card; in-lane reorders stay local); a **fix the acceptance script caught** (`publish_feature_backlog`
always re-publishes the feature at Finalize so `stories_finalized_at` propagates); **SHOULD-FIX** (pull seeds
each story's `board_state` CAS cursor so a second contributor's move publishes cleanly; the `set_activity`
guard widened). Deliverable: **`scripts/acceptance/phase-38-collaborative-sdlc-acceptance.py`** — the headless
full-SDLC hand-off (publish → mirror → finalize → boards → adoption; no-leak) — ALL PASS.

### 38-07 — release
genesis **v0.65.0** (three anchors bumped; `web/static` rebuilt + committed). No migration; genesis-only.

## Gates at release
- Backend **pytest 779** + ruff clean. Web **tsc / eslint 0 / vitest 262 / build** + `web/static` committed.
- The full-SDLC live-acceptance script passes headlessly. genesis-core / kiro-agent-sdk / genesis-workflows /
  genesis-appian-parser **unchanged**.

## Live acceptance (user-driven / headless-undrivable)
Deploy the Phase-36 Hub → configure Settings → Collaboration (base URL + service-account key) + onboard two
instances to one team → PO publishes a Spec → UX auto-sees it + publishes UX Design → a Dev picks up Technical
Design then Breakdown → Finalize publishes stories → board lanes sync → attribution/adoption visible. The
acceptance script proves the same flow headless against the local provider.

## Deferred (documented, non-blocking — see `38-04-deferred-ui-notes.md`)
Two **display** follow-ups the audit passed SHIP without: **per-stage "Published by X" attribution** and the
**cross-stage staleness badge** mount. Both are constrained/scoped by the no-migration rule (`kb_feature_stages`
has no `published_by`/`published_version` column); attribution/staleness are available on features/stories/boards
(which carry the columns). Carry as a post-release UI follow-up (options A1/A2/B1 in the notes).

## Program status
**The local-first + shared-Hub collaboration program is DELIVERED** for the KB (Phase 37) + features/artifacts +
stories + boards (Phase 38). **Shared-memory sync remains the one deferred future phase.**
