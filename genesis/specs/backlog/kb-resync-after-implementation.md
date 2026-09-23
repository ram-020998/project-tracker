# Backlog — Auto KB re-sync after implementation

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-09-23 (Phase 42 spin-off, Q-C). · Depends on Phase 42 (the implementation lane writes objects to the dev env).

## Context
After `story-implementation` writes/updates objects in the dev-tagged environment, the **local KB is stale** — it still reflects the pre-implementation state until a sync runs. **Delta sync already exists** (Phase 16-07 / Phase 23: `sync-application mode=delta` — a full re-export → parse → diff → write-only-changes, surfaced as the app-detail **Refresh** action + the scheduled `application-sync` job). What is **not** built is *auto-triggering* it at the end of an implementation run.

## The deferred capability
At the end of a successful `story-implementation` run (after `author_wiki`, before/with the move to Code Review), **auto-trigger a `sync-application mode=delta`** for the app so the KB (and subsequent tickets' grounding) immediately reflect the new/updated objects — instead of waiting for the manual Refresh or the morning scheduled sync.

## Shape when picked up
- The finalizer (or a terminal workflow node) calls the existing delta-sync path (`ApplicationSyncService` / `RunManager.start("sync-application", {mode:"delta"})`), serialized (the Appian export is one-at-a-time — the §7/ADR-047 lesson), best-effort (a failed re-sync must not fail the implementation).
- Consider debouncing (many implementations in a row → one delayed re-sync) and skipping when a sync is already running (the existing 409 guard).

## Open questions
- Trigger point (per-implementation vs a debounced batch); whether it blocks the card's move to Code Review (probably not — fire-and-forget).
- Interaction with the scheduler (avoid double-syncing around 07:00 IST).
