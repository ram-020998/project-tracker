# Phase 38 — Collaborative SDLC: features, stories, boards & the collaboration UX

> **Status:** 🟡 **SPECS DRAFTED (2026-09-05)** — awaiting user sign-off to build. Umbrella + `phase-38-collaborative-sdlc/38-01..38-07`. · **Author:** Genesis agent
> **Type:** single-repo — **genesis** (per-entity publish/pull for features + published stage artifacts, stories/epics, boards; the collaboration UX; the adoption bulk-publish). No migration (Phase 35's m0019 stands; artifacts already carry `sync_uuid`/provenance). genesis-core / SDK / workflows / parser **unchanged**. · **Depends on:** **Phase 37** (the live `AppianHubProvider` + `CollaborationService` + the sync-UX foundation [poll/Sync-now/notify-then-apply/offline] + live identity/teams), **Phase 35** (`sync_uuid`/provenance/`upstream_versions` columns + the publish/pull service + the advisory-lock model), Phase 36 (the Hub record types for Feature/Epic/Story/BoardState/StageArtifact + ArtifactBlob), and the existing entity stores (`FeatureStore`/`StageStore`/`StoryStore`/`BoardStore`) + the finalizers + lifecycle.
>
> **Fourth of four phases** (35 → 36 → 37 → **38 Collaborative SDLC**). This phase completes the feature: the
> **human-authored work products** (features + their published stage artifacts, stories/epics, boards) sync
> across the team, with the full **collaboration UX** (staleness badges, advisory in-progress markers,
> per-entity publish/pull), and a one-time **adoption** path to seed the Hub with existing completed work.
> **Shared-memory sync remains a deferred future phase.**

---

## 1. Why this phase exists

Phase 37 made the KB + identity/teams live. The point of collaboration, though, is the **SDLC hand-off**: a PO
authors a **Spec** and publishes it; a UX designer opens the *same* feature, sees the published spec, does the
**UX Design** and publishes; a developer picks up the **Technical Design**, then the **Feature Breakdown**;
finalized **stories** and the **board** status are visible to everyone. This phase makes those human-authored
entities shared — **publish-on-complete** (explicit push of the finished artifact; the chat/run stay local) and
**pull** (auto for read-only shared views + boards; notify-then-apply where a local draft exists) — reusing the
Phase-37 sync-UX foundation, and adds the collaboration affordances (who published, staleness, in-progress) and
a one-time bulk-publish so a team can adopt the Hub with a backlog of already-finished work.

---

## 2. Goal

1. **Features + published stage artifacts sync (per-stage publish-on-complete).** A **shared Feature** is one
   object contributed to sequentially: publishing a *completed* stage (spec / ux_design / technical_design /
   breakdown) upserts the Feature record (if new) + the StageArtifact **metadata record** + the artifact **HTML
   bytes** (ArtifactBlob) — **the chat/run stay local** (the FK-free `chat_session_id`/`run_id`/`html_path`
   columns are never published). Pulling a feature materializes a **read-only local mirror** with the artifact
   bytes written to the puller's disk (their `html_path`), so a downstream stage can consume it. Provenance +
   **consumed-upstream-versions** are captured (the notify-only cross-stage staleness badge).
2. **Stories & epics sync.** On **Finalize Stories** (and edits), publish epics + stories (UUID-keyed) so the
   team sees the same backlog; pull materializes them locally.
3. **Boards sync.** The lane = each story's shared `status` (rides the Story record); **membership is
   shared/automatic** (a board shows the app's shared finalized stories — no per-user re-import); **in-lane card
   ordering stays local**; **which boards you've added to your Workbench sidebar stays local** (personal
   curation). A card moved to a new lane publishes the story's status; others auto-pull it.
4. **The collaboration UX.** Reusing the Phase-37 foundation: per-entity **publish** controls (publish this
   completed stage / finalize+publish stories); **auto-pull** for shared read-only views + boards;
   **notify-then-apply** where you hold a local draft; the **cross-stage staleness badge** ("Spec changed
   v1→v2 since this was built"); the **advisory "in-progress by X"** marker on a stage/feature being edited;
   "published by X • \<when\>" attribution throughout. All a11y-clean.
5. **Adoption.** A one-time, explicit, **confirmed** "publish my existing completed work" bulk action (features
   + completed stage artifacts + finalized stories + board state) so a team adopting the Hub seeds it without
   re-touching each artifact. **Nothing auto-publishes**; solo installs are untouched.

**Success = a PO publishes a completed Spec; a UX designer's Genesis auto-shows the feature + the spec, they do
+ publish the UX Design; a developer picks up the Technical Design then Breakdown; finalized stories + the board
lanes are the same for everyone; edits show "published by X", staleness, and advisory markers; and a team can
bulk-publish their existing completed work in one confirmed action — the full role-sequential SDLC hand-off,
live, with chat/runs staying private.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-05)

1. **Publish-on-complete, artifact-only.** Only the finished **artifact bytes + metadata** publish; the
   authoring **chat + run stay local** (never published). One shared Feature, contributed to stage-by-stage.
2. **Pull is auto for read-only shared views + boards; notify-then-apply where a local draft exists.** Push is
   always explicit.
3. **Cross-stage staleness = notify-only with provenance** — record consumed upstream versions; show a
   non-blocking badge when an upstream artifact republishes; never auto-cascade/re-run/block.
4. **Concurrency = soft advisory "in-progress by X" + `row_version` CAS** (no hard lock).
5. **Boards:** lane=status shared; membership shared/automatic (no per-user re-import); **in-lane ordering
   local**; **sidebar board curation local (personal)**.
6. **Visibility open** — owner/`team_uuid` stamped (from Phase 35), not enforced.
7. **Adoption:** existing work **never auto-publishes**; a one-time explicit **confirmed** bulk "publish existing
   completed work" helper; opt-in; solo untouched.
8. **Shared memory is out of scope** (deferred future phase).

---

## 4. Current state (what we build on) — code-grounded

- **Phase 37** delivered the live `AppianHubProvider` + `CollaborationService.publish/pull` + the **sync-UX
  foundation** (poll / Sync-now / `<StalenessBadge>` / `<HubStatus>` / offline / notify-then-apply scaffolding)
  + live identity/teams + attribution. **This phase adds the per-entity mappings + the SDLC UX on top** — the
  service + UX foundation are reused, not rebuilt.
- **The entity stores exist:** `FeatureStore` (`kb_features` — now `sync_uuid`/owner/team/provenance from m0019),
  `StageStore` (`kb_feature_stages` — `sync_uuid`/`row_version`/`upstream_versions_json`; artifact HTML on disk
  via `html_path`, `content_hash`; the FK-free local-only `chat_session_id`/`run_id`), `StoryStore`
  (`kb_epics`/`kb_stories` — `sync_uuid`/`row_version`), `BoardStore` (`workbench_boards`/`kb_board_cards` —
  `sync_uuid`; lane = `kb_stories.status`; in-lane `board_position` [stays local]).
- **The artifact bytes are already on disk + hashed** (`html_path`/`content_hash`, and the freshest is the chat
  sandbox copy via `_current_stage_html`) — publishing an artifact = push those bytes (ArtifactBlob) + the
  metadata record; pulling = write bytes to the puller's disk + set their local `html_path`.
- **Downstream stages consume prior *artifacts*, not business docs** (verified: `_launch_td` snapshots the
  feature's spec/ux HTML; the workbench design/start snapshots spec/ux/td) — so a puller who has the published
  artifacts can run the next stage; **documents legitimately stay local.**
- **Finalize Stories** (Phase 32) + the board `reorder_lane`/`move_card` (Phase 33) are the natural publish
  trigger points for stories + board state.

**Takeaway:** this phase = per-entity publish/pull mappings for features+stage-artifacts, stories/epics, and
boards (over the Phase-37 service), the SDLC collaboration UX (reusing the Phase-37 components), and the
one-time adoption bulk-publish. **No migration; genesis-only.**

---

## 5. Entity sync mappings — finalized in 38-01/38-02/38-03

- **Feature + stage artifacts** (38-01): publish a *completed* stage → upsert Feature (kind `feature`) +
  StageArtifact metadata (kind `feature_stage`, carrying status/content_hash/`upstream_versions`/provenance) +
  the ArtifactBlob bytes; base-version CAS. Pull → mirror the Feature + stages read-only; write artifact bytes
  to disk (`html_path`); leave `chat_session_id`/`run_id` null. Capture `upstream_versions` at publish (the
  staleness badge).
- **Stories/epics** (38-02): publish at Finalize (+ on edit) → upsert Epic + Story records (kinds `epic`/
  `story`, keyed by `sync_uuid`, referencing the feature's `sync_uuid`); pull → mirror.
- **Boards** (38-03): publish the story's `status` (lane) via the Story record + a BoardState record
  (`app_uuid`, `story_sync_uuid`, `status`); membership = the app's shared finalized stories (automatic); pull →
  apply lane/status; **in-lane `board_position` never syncs** (local); **sidebar curation local**.

## 6. Collaboration UX — finalized in 38-04

Reuse the Phase-37 foundation: per-entity **Publish** controls (a completed stage → "Publish to team";
Finalize → publish stories; a lane move → auto-publish status); **auto-pull** shared read-only views + boards;
**notify-then-apply** where a local draft is newer/older than the Hub; the **cross-stage staleness badge**
(from `upstream_versions`); the **advisory "in-progress by X"** marker (heartbeat while a stage workspace/board
is open); "published by X • \<when\>" attribution on features/stages/stories/cards. jest-axe; `web/static`.

## 7. Adoption — finalized in 38-05

A one-time, explicit, **confirmed** "Publish existing completed work" action (Settings → Collaboration or a
per-app control): enumerate the local completed stage artifacts + finalized stories + board state that aren't
yet published, show a summary + confirm, then publish them (stamping the current user as `published_by`/owner).
**Never automatic.** Idempotent (content-hash dedup + base-version CAS skip already-published).

## 8. ADR

No new ADR — this phase **implements** ADR-063 for the human-authored entities (features/stories/boards). If the
per-stage publish-on-complete semantics warrant a recorded nuance, note it as an ADR-063 addendum; otherwise the
umbrella + sub-specs suffice.

## 9. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **38-01** | Features + published stage artifacts sync | Per-stage publish-on-complete (Feature + StageArtifact metadata + ArtifactBlob bytes; CAS; chat/run stay local) + pull-to-read-only-mirror (bytes to disk) + `upstream_versions` capture; tests. | independent review = SHIP |
| **38-02** | Stories & epics sync | Publish at Finalize + on edit (Epic/Story records, UUID-keyed) + pull-to-mirror; tests. | independent review = SHIP |
| **38-03** | Boards sync | Lane=status shared (via Story + BoardState) + membership auto (app's shared finalized stories) + in-lane ordering local + sidebar curation local; a lane move auto-publishes status; tests. | independent review = SHIP |
| **38-04** | Collaboration UX | Publish controls; auto-pull + notify-then-apply; the cross-stage staleness badge; advisory in-progress markers; attribution throughout (reusing the Phase-37 components); jest-axe; `web/static`. | independent review = SHIP |
| **38-05** | Adoption (bulk publish) | The one-time confirmed "publish existing completed work" action (features + completed stages + finalized stories + board state), idempotent; solo untouched; tests. | independent review = SHIP |
| **38-06** | Code review & hardening | Independent review (artifact-only publish [no chat/run leak]; pull materializes a read-only mirror correctly; CAS/notify-then-apply; boards lane/membership/ordering rules; staleness notify-only; advisory + CAS; adoption idempotent + confirmed; opt-in no-op; a11y). | review clean |
| **38-07** | Release | genesis vX.Y.0 (suggest **v0.65.0**); tag; CI green (clean-install v19); docs (bible §2/§3/§4/§8 + tracker + progress); the full-SDLC live-acceptance script. | CI green |

**Suggested order:** 38-01 → 38-02 → 38-03 → 38-04 → 38-05 → 38-06 → 38-07 (linear).

## 10. Release plan

Single-repo genesis (suggest **v0.65.0**); no migration (m0019 stands); no core/SDK/workflows pin moves.
Per-sub-phase gates (pytest+ruff; web tsc/eslint/vitest/build + `web/static`); local commits; **no tag/push
until 38-07 on the user's go-ahead.** Live acceptance (a real Hub + ≥2 instances role-playing PO/UX/Dev) is
user-driven / headless-undrivable — provide the manual script.

## 11. Scope

**In scope:** per-entity publish/pull for features + published stage artifacts (artifact-only; chat/run stay
local), stories/epics, boards (lane=status shared; membership auto; in-lane order + sidebar curation local); the
collaboration UX (publish controls, auto-pull, notify-then-apply, cross-stage staleness badge, advisory
in-progress markers, attribution); the one-time confirmed adoption bulk-publish. All opt-in.

**Out of scope:** shared-memory sync (deferred future phase); per-team visibility **enforcement** (tags only);
identity verification/anti-spoofing (parked); any Appian write from Genesis (still read-only); syncing chat/runs/
catalog/documents/personal-memory (local by design).

## 12. Open questions

- **38-01:** whether a *feature* publishes on first stage-publish (lazy) or via an explicit "publish feature"
  (lean: lazy — the Feature record upserts when its first completed stage is published).
- **38-03:** the exact auto-pull cadence for boards (reuse the Phase-37 foreground poll interval).
- **38-05:** the adoption action's placement (Settings → Collaboration vs a per-app "publish all" control) —
  finalize in 38-05.
