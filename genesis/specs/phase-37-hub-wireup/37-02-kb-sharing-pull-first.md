# 37-02 — KB sharing (pull-first blob sync)

> **Status:** 🟡 DRAFTED. · Part of Phase 37. Repo: **genesis**. · **Depends on:** 37-01 (the Appian provider), the `KbStore.apply` baseline path + the `sync-application`/`api/applications.py` refresh flow, ADR-047 (scheduler).

## Purpose

Make the **application KB** shared — parse once, everyone pulls — via the locked **pull-first** model: sync
pulls + hydrates the latest published blob when newer; a deliberate **refresh-from-Appian** exports + parses +
publishes; content-hash dedup + a per-app lock prevent waste + double-export.

## Build

1. **`KbStore.hydrate_from_blob(app_uuid, result)`** — replace the app's current state from a pulled parse
   result: within one tx, close current-state rows (or the existing `apply('baseline')` over an existing app) +
   baseline-apply the result + recompute bundles + mark the derived business map stale. Runs **off the event
   loop** (`asyncio.to_thread`, §7). The **blob = the gzipped code-free parse result** (`result.json` shape);
   publish serializes the same `KbParseResult` the local parse produced; pull deserializes → `hydrate_from_blob`.
2. **Pull-first sync wiring** (`api/applications.py` / the sync entry): the app "Sync" action → check the Hub KB
   blob version (via `CollaborationService`/`collab_sync_state` `kind='kb:<app_uuid>'`) vs local; **newer ⇒ pull
   the blob + `hydrate_from_blob`** (no export/parse). A separate explicit **"Refresh from Appian (re-export)"**
   action → export → parse → local write → **publish** the gzipped blob (content-hash dedup → **no-op if
   unchanged**), stamping `published_by`/version.
3. **Per-app already-running lock** — extend the existing 409 "a sync is already running" guard to also cover a
   Hub refresh, so two members can't both export the same app simultaneously (content-hash dedup absorbs
   redundant publishes; the lock prevents the wasteful parallel export).
4. **Hub-app exclusion** — the Genesis Hub `app_uuid` is never tracked/refreshed/published as a subject app
   (guard in the Applications surface + the refresh path).
5. **Scheduler** (ADR-047) — an optional periodic Hub-pull / refresh job (a designated machine may run the
   daily refresh; others pull-first). Off by default; opt-in.

## Tests

- `hydrate_from_blob` replaces current state correctly (counts match; bundles recomputed; off-loop).
- Publish serializes → pull deserializes → hydrate → local KB equals the publisher's (round-trip via a fake
  provider).
- Content-hash **dedup**: an unchanged refresh publishes no new version; pull-first skips when not newer.
- The per-app lock blocks a second concurrent refresh (409); the Hub app is excluded. ruff clean.

## Deliverable

`hydrate_from_blob` + pull-first sync + deliberate refresh-publish (gzip/dedup) + per-app lock + Hub-app
exclusion + optional scheduler job + tests.

## Gate

Independent review = SHIP: pull-first correct (no needless re-parse); replace-current correct; dedup/lock/
exclusion correct; gates green.
