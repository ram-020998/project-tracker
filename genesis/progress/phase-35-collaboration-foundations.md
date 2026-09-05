# Phase 35 — Collaboration Foundations & Identity — AS-BUILT

> **✅ SHIPPED — genesis v0.63.0 (2026-09-05). ADR-063 Accepted.** Single-repo (genesis); no core/SDK/workflows
> change. The first of the four-phase Team Collaboration program (35 Foundations → 36 the Genesis Hub Appian app
> → 37 Hub wire-up → 38 Collaborative SDLC). **Opt-in / off by default — a solo install is unchanged.**

## What shipped

The **local-first → shared-Hub substrate**: global identifiers + concurrency columns, a pluggable transport
seam, a self-asserted identity model, and the publish/pull service — all exercised end-to-end against a
**local/mock provider** with **no Appian** (the Appian Hub is Phase 36/37).

### 35-02 — Migration m0019 + global ids (`current_version` 18 → 19)
`genesis/db/migrations/m0019_collab.py` (additive, forward-only, idempotent):
- **`sync_uuid TEXT`** (+ a one-time uuid4 **backfill** + a `UNIQUE` index) on the six synced tables:
  `kb_features`, `kb_feature_stages`, `kb_epics`, `kb_stories`, `workbench_boards`, `kb_board_cards`.
- **`row_version`** on the four synced tables that lacked the m0014 CAS column (`kb_features`, `kb_epics`,
  `kb_board_cards`, `workbench_boards`).
- **owner/team/provenance** columns (`owner_username`, `team_uuid`, `published_by`, `published_at`,
  `published_version`) on the top-level entities (`kb_features`, `kb_stories`, `workbench_boards`), plus
  `upstream_versions_json` on the stage tables (`kb_feature_stages`, `kb_story_stages`).
- Local tables: `collab_identity` (singleton), `collab_teams`, `collab_memberships`, `collab_sync_state`.
- The six store create-paths now stamp a `sync_uuid`; reads expose it (`SELECT *`).

### 35-03 — Identity + canonical username
`genesis/collab/identity.py`: the `Identity` model + `IdentityStore` over `collab_identity` (+ a local
team/membership read cache); `current_user()`; **`canonical_username(settings)` → `appian_username` →
`memory_owner_username` → `"local"`** (defensive; falls back on an un-migrated DB). Threaded `actor=` into
**every** `LifecycleService.transition(...)` call site (`chat/stage_finalizer.py`,
`chat/story_design_finalizer.py`, `api/features.py`) so the **m0013 audit rows are attributed**; the
`memory_owner_username` consumers (`api/system.py`, `runtime/memory_jobs.py`, `chat/mcp.py`, `api/memory.py`)
now derive from `canonical_username()`.

### 35-04 — The `SyncProvider` seam + `CollaborationService` + local provider
- `genesis/collab/provider.py` — the `SyncProvider` **Protocol** (`runtime_checkable`) + provider-neutral DTOs
  (`Record`/`BlobRef`/`Change`/`Activity`/`PutResult`/`Team`/`Membership`) + `HubConflict`. **No Appian.**
- `genesis/collab/providers/local.py` — **`LocalHubProvider`**, a file-backed emulator under
  `settings.collab_hub_dir`: records with a **base-version CAS → `HubConflict`**, **content-hash blob dedup**,
  a monotonic change-log manifest (`changes_since`), advisory markers with TTL, and teams/memberships. The test
  double.
- `genesis/collab/service.py` — **`CollaborationService`**: `publish(kind, sync_uuid)` (map row → payload with
  the **`_LOCAL_ONLY` no-leak** exclusion → `put_record` with base-version CAS → stamp `published_*` locally)
  and `pull(kind)` (walk the manifest from the `collab_sync_state` cursor → upsert local mirrors by
  `sync_uuid`, local-only columns null) + blob helpers + advisory heartbeat + `is_enabled()` opt-in gate.
  `_BINDINGS` wires **`feature`** this phase (stories/stages/boards are Phase 38 — they need cross-machine
  parent resolution). `content_hash` = sha256.
- `genesis/collab/__init__.py` — **`build_sync_provider(settings)` → `SyncProvider | None`**: returns `None`
  unless `collab_enabled` + `collab_provider == "local"`. Settings gained `collab_enabled`/`collab_provider`/
  `collab_hub_url` (env `GENESIS_COLLAB_*`) + a `collab_hub_dir` property.
- `api/collab.py` (`GET /collab/config`; `GET/PUT /collab/identity`; `GET/POST /collab/teams`;
  `POST /collab/teams/{uuid}/join`; `PUT /collab/active-team`; `GET /collab/teams/{uuid}/members` — teams gated
  409 when disabled) + a `CollaborationService` on `app.state.collab` + a preflight "Collaboration identity"
  item (only when a Hub is configured).

### 35-05 — Web
Settings → **Collaboration** tab (`web/src/features/collab/CollaborationSection.tsx`): Hub status/opt-in +
identity form + team management (team UI only when enabled). A first-run **`OnboardingDialog`** (mounted in
`AppShell`, shown only when `enabled && !identity_set`, deferrable). `types/collab.ts` + `lib/api/collab.ts` +
`qk.collab` + `features/collab/hooks.ts`.

## Gates (at release)
- Backend: `pytest` **730 passed**, `ruff` clean.
- Web: `tsc` clean, `eslint` **0 errors** (20 pre-existing warnings), `vitest` **247 passed**, `npm run build`
  OK (`web/static` committed).
- **Live acceptance** (`scripts/acceptance/phase-35-collab-acceptance.py`, local provider, two simulated
  instances): all 9 checks pass — opt-in gate on/off, canonical username, feature `sync_uuid`, publish v0,
  pull mirror + provenance on a second instance, no-op re-pull, solo fallback to `"local"`.

## Deliberately out of scope (later phases)
The Appian Hub application + its Web APIs/record types/blob store (Phase 36); the real Appian `SyncProvider`
+ KB sharing + live identity/teams (Phase 37); features/artifacts/stories/boards publish-pull + the
collaboration UX + adoption bulk-publish (Phase 38); shared-memory sync (deferred); per-team **visibility
enforcement** (tags stamped, not enforced); identity **verification** / anti-spoofing (parked).

## Release
genesis **v0.62.0 → v0.63.0** (`pyproject.toml` + `web/src/version.ts` + `create_app`); commit + tag `v0.63.0`
pushed to master; CI green (genesis + frontend + clean-install → DB v19). No core/SDK/workflows pins moved.
