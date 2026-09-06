# 37-04 — Sync-UX foundation

> **Status:** ✅ SHIPPED (genesis v0.64.0). · Part of Phase 37. Repo: **genesis/web** (+ thin backend). · **Depends on:** 37-01 (provider), 37-02 (KB pull), the `CollaborationService` change-manifest + `collab_sync_state`.

## Purpose

Build the reusable **sync UX** — the change-manifest poll, the "Sync now / Check for updates" control, the
notify-then-apply scaffolding, and offline-first behavior — that Phase 38 plugs features/stories/boards into.

## Build

1. **Change-manifest poll** — a backend `GET /api/collab/changes` (over `CollaborationService.changes_since`) +
   a web poll: **foreground** (TanStack Query `refetchInterval`) while a collaboration-relevant view is open, and
   the **ADR-047 scheduler** for a periodic baseline pull. Auto-apply read-only shared kinds; surface others.
2. **"Sync now / Check for updates"** control (global + per-surface) → force a manifest check + pull.
3. **Notify-then-apply scaffolding** — where a local draft's `published_version` differs from the Hub's, show a
   non-blocking "newer version available — review" affordance (the reusable component + hook); never auto-
   overwrite a local draft.
4. **Offline-first** — when `provider.is_available()` is false: hide/disable sync affordances with a clear
   "Hub unreachable — working locally" state; queue nothing destructive; resume on reconnect.
5. Reusable web hooks/components (`features/collab/…` — `useHubChanges`, `useSyncNow`, `<StalenessBadge>`,
   `<HubStatus>`), tokens/primitives, jest-axe, commit `web/static`.

## Tests

- vitest: the poll drives pulls; Sync-now forces a check; the staleness affordance appears only when versions
  differ; offline state renders when unavailable. jest-axe green; tsc/eslint clean; build + `web/static`.

## Deliverable

The sync-UX foundation (poll + Sync-now + notify-then-apply + offline) + reusable hooks/components.

## Gate

Independent review = SHIP: poll/Sync-now/offline correct; notify-then-apply never auto-overwrites; a11y; gates
green.
