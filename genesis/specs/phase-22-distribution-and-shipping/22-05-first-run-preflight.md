# 22-05 — First-run preflight

> **Status:** 📝 DRAFT · **Phase:** 22 · **Repo:** genesis · **Depends on:** 22-02 (uses 22-04 for the Kiro row)

## Goal
A first-run checklist that tells a new user exactly what's missing before Genesis is fully usable, reusing the existing health
+ dev-env readiness signals — no new probing logic where an endpoint already exists.

## API
- `GET /api/system/preflight` → aggregates existing signals into a checklist:
  - **kiro-cli authenticated** (from 22-04 `GET /api/system/kiro`) — **required**.
  - **DB migrated** (`current_version` == latest) — required; should already be true post-install.
  - **Server health** (`/api/config/health`) — required.
  - **Appian dev environment** configured + reachable (existing dev-env check) — **optional** (only for the Appian KB / Business
    Map / Documents features); shown as "optional — needed for Appian features".
  - **`uv` present** (managed-native MCPs) + **`gws` dotfiles** (Document Library) — optional, feature-gated.
- Each item: `{ id, label, status: ok|missing|error, required: bool, hint, fix_link? }`.

## Web
- A **first-run screen** (shown when any required item is not `ok`, or via Settings) rendering the checklist with clear
  required-vs-optional grouping and a link/button per item into the relevant Settings panel (Kiro → 22-04; Environments →
  existing; CLI/gws → existing).
- Once all **required** items are `ok`, the screen steps aside (dismissible; re-openable from Settings).

## Acceptance
- Fresh install, Kiro not signed in → the screen lists Kiro as the blocking item and links to the sign-in panel; after sign-in
  all required items are green and the screen clears. Optional Appian items remain visible but non-blocking.

## Tests
- API test: preflight aggregation over mocked health/kiro/dev-env (required all-ok vs a missing required vs an optional-missing).
- Web: the three grouping states + jest-axe.

## Notes
- Pure read-only aggregation — no new external calls beyond what health/dev-env/kiro already do.
