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

