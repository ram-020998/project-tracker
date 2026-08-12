# 22-05 — First-run preflight

> **Status:** ✅ CODE-COMPLETE (2026-08-12; genesis code **held for the v0.47.0 release** at 22-06/07) · **Phase:** 22 ·
> **Repo:** genesis · **Depends on:** 22-02 (uses 22-04 for the Kiro row)
>
> **As built:** `genesis/runtime/preflight.py` `check(settings)` → `{items, ready}` aggregating **required** (kiro
> authenticated via `kiro_auth.status`, DB migrated via `pending`, server healthy) + **optional** (dev-tagged env via
> `EnvironmentRegistry.dev_environment_label`, `uv` on PATH, `gws` client-secret dotfile); each item `{id,label,status,required,
> hint,fix_link}`; `ready` = all required ok. `GET /api/system/preflight`. Web: `features/system/PreflightChecklist` — a
> **dismissible modal** (shown when `!ready`) grouping required vs optional with per-item **Fix →** links into Settings; mounted
> in `AppShell`. **Verified:** 4 preflight tests (required-ok / missing-required-blocks / optional-doesn't-block / endpoint) +
> 2 web tests (jest-axe); real `check()` on this machine → all-ok `ready:true`; full backend **437** + web **160** green;
> ruff/eslint/tsc clean.

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
