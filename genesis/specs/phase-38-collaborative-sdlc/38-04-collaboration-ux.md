# 38-04 — Collaboration UX

> **Status:** ✅ SHIPPED (genesis v0.65.0). · Part of Phase 38. Repo: **genesis/web** (+ thin backend). · **Depends on:** 38-01/38-02/38-03 (the entity mappings), Phase 37 (the sync-UX foundation: poll / Sync-now / `<StalenessBadge>` / `<HubStatus>` / notify-then-apply).

## Purpose

Surface collaboration in the SDLC UI — publish controls, auto-pull, notify-then-apply, the cross-stage staleness
badge, advisory in-progress markers, and "published by X" attribution — reusing (not rebuilding) the Phase-37
components.

## Build

1. **Publish controls** — a **"Publish to team"** action on a **completed** stage (feature stage workspace +
   Overview card); publish-on-finalize for stories; a lane move auto-publishes status (38-03). Disabled until a
   stage is completed; shows a spinner + result.
2. **Auto-pull + notify-then-apply** — shared read-only views (features list, a feature's published stages,
   the Stories grid, boards) **auto-refresh** from the poll; where the user holds a **local draft** newer/older
   than the Hub, show the Phase-37 **notify-then-apply** affordance (review before applying) — never auto-
   overwrite a draft.
3. **Cross-stage staleness badge** — from `upstream_versions`: on a stage whose consumed upstream artifact has
   since republished, show **"Spec changed (v1→v2) since this was built — review"** (non-blocking; the owner
   decides to re-run). Notify-only.
4. **Advisory "in-progress by X"** — while a stage workspace / board is open, heartbeat `set_activity`; show
   others' markers as a soft "being worked on by X" hint (not enforced); clear on publish/close/stale.
5. **Attribution** — "published by X • \<when\>" on features / stage cards / stories / board cards; the active
   team + members surfaced (from Phase 37).
6. Reuse `features/collab/` components/hooks; tokens/primitives; **jest-axe** on new/changed surfaces; commit
   `web/static`.

## Tests

- vitest: publish control enabled only when completed; auto-pull refreshes shared views; notify-then-apply
  appears on a divergent local draft (no auto-overwrite); the staleness badge appears from `upstream_versions`;
  advisory markers render; attribution renders. jest-axe green; tsc/eslint clean; build + `web/static`.

## Deliverable

The SDLC collaboration UX (publish / auto-pull / notify-then-apply / staleness / advisory / attribution).

## Gate

Independent review = SHIP: publish-on-complete gating; no draft auto-overwrite; staleness notify-only; advisory
non-blocking; a11y/dark-parity/no-hardcoded-hex; gates green.
