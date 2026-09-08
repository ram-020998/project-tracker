# As-built — Two-toggle collaboration enablement (ADR-065) — genesis v0.66.0 → v0.66.1

**Shipped 2026-09-06. Genesis-only, no migration.** Release `d304288` / tag `v0.66.1` (v0.66.0 `399fd17`).
CI: master #6745373 / tag #6745374 (v0.66.0 #6745367/#6745366).

## Why
ADR-063 shipped a single **env-only** opt-in (`GENESIS_COLLAB_ENABLED`). The user wanted (a) an **in-app
Settings toggle** to enable/disable collaboration, (b) that toggle **guarded** so it can only be turned on
when the **Genesis Hub app is reachable in the dev env** (so nothing breaks), (c) collaboration active only
when **both** the env master and the Settings toggle are on, and (d) the Hub URL taken from the **dev-tagged
environment** with a **one-time static Hub app UUID**.

## What shipped
- **Persisted config** — `genesis/collab/config.py::CollabConfigStore` over `~/.genesis/collab.json`
  (`ui_enabled` default **False**, `hub_app_uuid`) via `genesis_core.util.atomic_json`. `settings.collab_config_path`.
  **No DB migration.**
- **Gate** — `CollaborationService.is_enabled()` = `provider is not None` (env master built the provider at
  boot) **AND** `_ui_enabled()` (reads `collab.json`). `_require()` gates every publish/pull, so flipping the
  Settings toggle takes effect **without a restart**. Added `hub_configured()` (env master only) + `_hub_app_uuid()`
  (config wins over the `GENESIS_COLLAB_HUB_APP_UUID` env fallback; drives `is_hub_app` KB exclusion).
- **Hub URL from the dev env** — `build_sync_provider('appian')` derives `base_url` via `_resolve_hub_base_url`
  = `dev_environment().url` + the standard Appian Web-API mount **`/suite/webapi`** (`collab_hub_url` is the
  no-dev-env fallback). `AppianHubProvider.base_url` property added for the status display.
- **API** — `GET /collab/availability` (`env_enabled` + `provider.is_available()` /meta ping -> `can_enable`);
  `PUT /collab/config {ui_enabled, hub_app_uuid}` (**409** unless env master on AND Hub reachable);
  `GET /collab/config` extended (`enabled`/`env_enabled`/`ui_enabled`/`available`/`hub_app_uuid`/`hub_url`).
- **Web** — Settings -> Collaboration: a `Switch` (disabled with a reason when the env master is off or the Hub
  is unreachable) + a one-time Hub-app-UUID field; the stale *"wired in a later phase"* copy removed.
  `useCollabAvailability` + `useSetCollabConfig` hooks; `collabApi.availability`/`setConfig`; extended types.

## v0.66.1 fix
v0.66.0 derived the **bare** dev-env root as the Hub `base_url`, but `AppianHubProvider` expects the Web-API
prefix — so `/meta` was never hit -> `available` always false + a null `hub_url` in Settings. Fixed by
appending `/suite/webapi` in `_resolve_hub_base_url` (+ a test asserting the derived prefix).

## Verification
- Backend pytest **781** (+2: availability-guard 409 + both-on gating), ruff clean; web tsc/eslint clean,
  vitest **262**, `npm run build` (web/static rebuilt); acceptance phase-35/37/38 pass.
- **Live-enabled** against the `merge-assist-dev` dev env (env master set + Settings toggle flipped on):
  `GET /collab/config` -> `enabled:true, env_enabled:true, ui_enabled:true, available:true,
  hub_url:https://merge-assist-dev.appianpreview.com/suite/webapi, hub_app_uuid:_a-0000f058-…, provider:appian`.

## Notes / follow-ups
- Enablement of the env master still requires a `serve` restart with `GENESIS_COLLAB_ENABLED=1` +
  `GENESIS_COLLAB_PROVIDER=appian` (the deployment-level switch). The Settings toggle is the runtime control.
- `collab_hub_url` remains a fallback only for a deployment with no dev-tagged env.

## v0.66.2 — stage_artifact contract fix (first live publish 400)
The first real publish of a completed feature stage to the live Hub returned
`PUT /records/feature_stage/<uuid> → 400: invalid kind or missing syncUuid`. The `CollaborationService`
entity binding sent **kind `feature_stage`** + a `feature_sync_uuid` parent + an artifact blob keyed by the
stage's sync_uuid, but the frozen Hub contract (36-01 §2.1) has **kind `stage_artifact`** with
`parent_sync_uuid` + `parent_kind`, a renamed `upstream_versions` field, and an artifact blob keyed
`<parent_sync_uuid>:<stage>` with that `blob_key` carried on the record. The permissive `LocalHubProvider`
accepted the wrong shape, so all Phase-38 tests/acceptance passed — the mismatch only surfaced on the live
Appian call. **Fix:** remapped the stage binding (`kind`/`parent_kind`/`rename_out`/`blob_key`+`content_hash`
on the record; pull reverses the rename + fetches the blob by `<parent>:<stage>`), updated the SDLC tests to
the contract shape, and added a guard test that every `_BINDINGS` kind is a real contract record kind.
**Live-verified:** `publish_feature_stage → PUT stage_artifact → created v0` against `merge-assist-dev`.
See bible §7. Backend pytest **782**.


## v0.66.3–v0.66.5 — collaboration puller-fidelity fixes
Making a **second instance** (a "new user") actually *see* pulled work exposed a cascade — all masked by the
permissive `LocalHubProvider` (it echoes the full published payload, so tests + headless acceptance passed;
the real Appian Hub stores only its contract fields).

- **v0.66.3 (backend):** `pull_all` **crashed** — `NOT NULL constraint failed: kb_feature_stages.title` (the
  Hub `stage_artifact` record has no `title`). `_upsert_local` now fills every NOT-NULL-no-default local
  column absent from the mirror payload (`title` ← a nice stage label, `*_at` ← now) via `_required_cols`.
  Separately, pulled features **never populated the Workbench board** — auto-membership needs
  `kb_features.stories_finalized_at IS NOT NULL`, but the Hub `feature` record drops it; `pull_boards` now
  **derives** it (`_stamp_pulled_finalized` — a pulled feature that has stories was finalized upstream).
- **v0.66.4 (web):** completed pulled stages showed **"Start the stage"** — `StageBuilderPage` gated the
  workspace on `chat_session_id`, but a pulled mirror has the artifact with **no local chat** (chat/run stay
  local, ADR-063). Added a third branch: a completed/in-review chat-less stage renders **read-only**
  (`PulledStageView` — the artifact via `artifactUrlFor` annotate=0 + a "shared by your team" banner + Export).
- **v0.66.5 (backend):** the derived stage `title` maps to a human label (`_STAGE_LABELS`:
  spec→Spec, ux_design→UX Design, technical_design→Technical Design, breakdown→Feature Breakdown).

**No Hub change needed.** A per-entity probe (`_map_out` payload keys vs the frozen contract fields) confirmed
the only genuinely-dropped, non-attribution fields are `feature.stories_finalized_at` + `stage_artifact.title`
— both correctly derived puller-side. `published_by` is not a loss (the Hub stores it as
`created_by`/`modified_by`; `_to_record` recovers it). The mirrors are read-only, so derived values never flow
back to the Hub.

**Verified live:** userb (a second instance on :8761 via `genesis-fleet`) pulled 1 feature / 12 epics / **72
stories** / 4 stage artifacts + **72 Workbench board cards**, and each stage opens read-only. Gates: backend
pytest **784** + ruff; web tsc/eslint 0 / **vitest 263** / build. Regression tests added: title-less
`stage_artifact` pull, board-populate-after-pull, and the read-only pulled-stage view. See bible §7.

## v0.67.0 — collaboration auto-pull
A puller only pulled via Settings → Collaboration → **"Sync now"**, so a teammate's board move / feature +
story updates didn't reflect until a manual sync (the 30s `useHubChanges` poll only updated the
"updates available" indicator; it never auto-applied). Diagnosed live: a card moved to Implementation on
main published correctly (Hub story + BoardState both `implementation`) but userb kept the old lane until
pulled.

**`useAutoPull`** (in `features/collab/hooks.ts`, mounted once via `CollabAutoPull` in `AppShell`) pulls
automatically on **app load**, **every route change** (board / features / stories / stage), a **30s
interval**, and **window refocus / tab-visible**. It is **throttled** (min 8s between real pulls + an
in-flight guard so rapid navigation never spams the Hub), **gated** on collaboration `enabled` +
`available`, and **quiet on error** (no toast every interval when the Hub blips). After each pull it
invalidates the `applications`/`features`/`workbench`/`collab` queries so every surface refreshes. Safe to
auto-apply — pulled entities are **read-only mirrors** on this instance (no local draft to clobber;
notify-then-apply only matters on the author). `usePull` gained a `{ quiet }` option for the background
driver. Tests: `useAutoPull` auto-pulls when enabled+available, and no-ops when disabled. web **vitest 265**.
Both fleet instances restarted on v0.67.0 so teammate moves now reflect within ~30s (or on navigation) with
no manual step.

## v0.67.1 — auto-pull latency fix (board-aware + event-driven)
Board moves were slow to appear on a second instance ("multiple refreshes"). **Measured the root cause
before changing anything** — a live probe published a Story from main and polled the Hub: the change was
visible via `/collab/changes` (the manifest the pull walks) **and** `get_record` in **~0.9s**. So there is
**no Appian replica lag** on this path (read-your-writes) — the earlier eventual-consistency hypothesis was
wrong. userb's config was fully enabled/available; the delay was the **frontend auto-pull cadence**: a flat
**30s** interval (and auto-pull is a foreground driver — the backend has no background pull loop; the
`kb-hub-pull` scheduler is KB-only and off by default).

**Fix** (`web/src/features/collab/hooks.ts::useAutoPull`, mounted once via `CollabAutoPull`):
- **Board-aware interval** — **10s** while a Workbench board route (`/workbench/:appUuid`) is open, **30s**
  otherwise (`BOARD_ROUTE` test on `location.pathname`).
- **Event-driven** — the interval runs a cheap `GET /collab/changes` poll and issues a real `pull` **only
  when the Hub change cursor advances** since last seen (`seenCursorRef`); the first poll just seeds the
  cursor. No pull-write/DB churn on an idle tick.
- **Force pull on app load / window reload** (bypasses the 8s throttle) + a throttled pull on every route
  change; refocus / tab-visible also trigger the change-driven check.

Net: with the Hub read at ~0.9s, a teammate board move reflects within **~10s** on the board, or instantly
on reload/navigation. `useAutoPull` gained injectable `{ boardMs, idleMs, throttleMs }` for testing. Tests:
the existing mount-pull + disabled-noop, plus a new **event-driven** test (a second `/changes` page with a
new change → a second pull). web **vitest 266**; tsc/eslint clean. Both fleet instances restarted on v0.67.1.
