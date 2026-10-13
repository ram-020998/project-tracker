# 45-08 — Collaboration: publish after every sync, KB auto-pull, designated machine

> **Status:** ✅ SHIPPED 2026-10-13 (see the as-built section). Repo: **genesis** (+ the `publish_hub` node in genesis-workflows, 45-06). Refines ADR-063.
> No Hub change (existing blob API + contract). Parent: `specs/phase-45-incremental-delta-sync.md`.

## 1. Publish the snapshot after every successful sync

- `build_context` adds `ctx.extras["kb_publish"](app_uuid) -> int | None`: when `collab.is_enabled()` and the Hub is
  available, `collab.publish_kb(app_uuid, KbStore.export_snapshot(app_uuid))` and return the version; otherwise `None`.
  Same best-effort pattern as Phase 42's `object_wiki_publish`.
- `publish_hub` node (45-06) calls it via `asyncio.to_thread`; records `published_version` in `kb_syncs.details` and
  `report.json`. Failure → logged warning in the report; the run still succeeds.
- Excluded Hub app and not-onboarded identity → skipped with a reason (existing `publish_kb` rules).
- Content-hash dedup + deterministic snapshot (45-04) → an unchanged KB creates no new Hub version.

## 2. Manual Publish uses the snapshot

`POST /applications/{uuid}/publish` switches from `_latest_result_json` to `export_snapshot` (removes the "partial
result.json wipes teammates" hazard). `_latest_result_json` is deleted if unused.

## 3. KB in the always-on auto-pull loop

`CollaborationService.autopull_tick()`: when the manifest has advanced, also check the changes for `kind == "blob"`
KB rows and run `pull_kb_if_newer(app_uuid, kb_store)` for each **tracked** app that changed (hydrate is blocking —
the loop already runs off the event loop). The publisher's own cursor prevents re-pulling its own publish. The
`kb-hub-pull` scheduled job stays (off by default) as a fallback.

Guard: never hydrate an app while a local `sync-application` run for it is in progress (skip; next tick retries).

## 4. Designated machine

`options.run_on_this_machine` (45-07). Hidden when collaboration is off (solo: the schedule just runs). When
collaboration is on it defaults **off**. Card text: "Only one teammate should run scheduled syncs; everyone else
receives the KB automatically." Status shows the last Hub KB publish (`published_by` + time from `list_blob_versions`).

## 5. Tests

`kb_publish` best-effort (disabled / unavailable / onboarding / success); publish endpoint uses the snapshot;
`autopull_tick` pulls the KB only on a blob change for a tracked app and skips during a local sync; publisher does not
re-pull its own version; two-instance acceptance on the `LocalHubProvider` (publish on A after an incremental sync →
B hydrates within one tick, identical current objects/edges/bundles). Update `test_collab_kb.py`.

## 6. As built (2026-10-13; genesis `2b686fc`, genesis-workflows `ca7ece8`, local) — deviations + additions

- **`ctx.extras["kb_publish"](app) -> dict`** (not `int | None`): `{published_version, content_hash}` |
  `{skipped: reason}` (collaboration disabled / Hub app / identity not set up / Hub unreachable) | `{error}`; never
  raises. The workflow's **`publish_hub`** node runs after `v_kb` AND after `record_empty_sync` (an empty sync
  retries a publish that failed earlier; dedup makes it free otherwise), writes `published_version` into the sync's
  details (`update_sync_details`) and `report.json`.
- **Manual Publish** = `export_snapshot`; `_latest_result_json` deleted (409 when the app has no baseline).
- **Auto-pull:** `autopull_tick(kb_store, is_syncing=)` — a `blob` change keyed by a TRACKED app's uuid →
  `pull_kb_if_newer`; an app with a local sync in progress is **deferred** (kept pending in memory, retried on later
  ticks even with no new Hub change). `CollabAutoPuller` gets `kb_store` + `ApplicationSyncService.is_sync_running`.
- **Found + fixed — the local Hub diverged from the contract:** `LocalHubProvider.put_blob` appended a change row of
  kind `kb`/`artifact`; the frozen contract (§3.6) says kind **`blob`**. Now `blob` (the auto-pull accepts both).
  `test_collab.py` pinned the old kind and was updated.
- **Added — diff-based repeat hydrate:** with publish-after-every-sync, pulls become frequent; `hydrate_from_blob`
  used to close + reopen every row (a whole-app SCD-2 copy per pull). Once the app has a KB, it now applies the
  snapshot with the full-mode diff (`_apply_delta`): changed → new version, absent → closed, unchanged → derived
  fields in place. First pull unchanged.
- **Added — anchor rule (workflow):** the incremental listing anchors on this machine's own last sync
  (`OWN_SYNC_KINDS = baseline|full|delta|incremental`); a `hub-pull` row is NOT an anchor (its content is at the
  publisher's coverage point, unknown here) → a wider, safe listing (or a size fallback to full).
- **Status:** `per_app[].last_published_version` from local sync details (no Hub call per GET); the card shows
  "published Hub vN" and the spec'd one-machine text. `published_by` from `list_blob_versions` was not added (it
  would be a Hub call per app per GET).

**Evidence:** genesis pytest **922** (+ `tests/test_kb_collab_sync.py` 6: incremental publish → puller identical
after ONE tick, publisher never re-pulls, unchanged KB → no new version, deferral during a local sync, untracked
apps ignored, repeat hydrate adds only the changed row, Publish endpoint sends the snapshot, `kb_publish` skip);
web vitest 298 + build; workflows pytest **237** (+3: publish after incremental/empty/full, publish failure never
fails the run, hub-pull not an anchor) + validate 13.
- **Review follow-up (`1a1b275`):** deferred KB pulls are **persisted** (`collab_sync_state` key
  `autopull:kb-pending`) so a serve restart can't drop one whose Hub change was already consumed (test: a fresh
  service on the same DB completes the pull). Per-app status ignores `hub-pull` rows when picking the last sync;
  "Hub pull" label added. Review: **SHIP**.
