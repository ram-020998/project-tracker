# 45-08 — Collaboration: publish after every sync, KB auto-pull, designated machine

> **Status:** 🟡 DRAFTED. Repo: **genesis** (+ the `publish_hub` node in genesis-workflows, 45-06). Refines ADR-063.
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
