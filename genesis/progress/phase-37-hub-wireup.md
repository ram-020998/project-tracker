# Phase 37 — Hub Wire-up — AS-BUILT (✅ SHIPPED, genesis v0.64.0, 2026-09-06)

> **Status:** ✅ **COMPLETE + SHIPPED — genesis v0.64.0** (single-repo; no migration — m0019 stands; no
> core/SDK/workflows pin moves). Implements **ADR-063** (the `SyncProvider` seam) against **ADR-064** (the
> deployed Genesis Hub app). Umbrella: `specs/phase-37-hub-wireup.md` (+ `37-01..37-06`). Depends on Phase 35
> (`genesis/collab/` seam + identity/teams) + Phase 36 (the frozen contract + fixtures).

## What shipped

The first two shared surfaces — **the application KB + identity/teams** — go live against the real Appian Hub,
plus the reusable **sync-UX foundation** Phase 38 extends.

### 37-01 — `AppianHubProvider` (the real `SyncProvider`)
`genesis/collab/providers/appian.py` — maps every Protocol method onto the frozen **Genesis Hub API contract
v1.0.0**: records upsert/get/list (**base-version CAS → `HubConflict` on 409**), blobs put (**dedup 200 / new
201**)/get/versions, `changes_since` cursor manifest, activity set/list/clear, and **teams/memberships as
generic `records` kinds** (deterministic `uuid5` membership key). `appian-api-key` auth resolved from the
ADR-048 dev-env per-env SecretProvider scope (`APPIAN_API_KEY`); **injectable transport** (default `requests`
+ retry/backoff on 5xx/429; **the key is never logged**). Reads are treated as **eventually consistent**
(contract §4a) — trusts the PUT/POST returned version, never re-GETs. `is_available()` pings `/meta` and warns
(never hard-fails) on a `contract_version` mismatch. Registered as `build_sync_provider('appian')`.
**Contract-conformance tested against the shared Phase-36 fixtures** (vendored to `tests/fixtures/hub_contract/`).

### 37-02 — KB sharing (pull-first)
- **`KbStore.hydrate_from_blob(app_uuid, result)`** — SCD-2 **replace-current** in ONE tx (close all current
  objects/edges → baseline-open the pulled snapshot → recompute bundles → mark business map stale → record a
  `hub-pull` sync). Blocking → callers offload via `asyncio.to_thread` (the §7 checkpointer-deadlock lesson).
- **`genesis/kb/blob.py`** — the KB blob = **gzipped code-free parse result** (`result.json` shape;
  `serialize_result`/`deserialize_result` with an attribute-shim decoupled from the parser dataclasses; no SAIL,
  ADR-037). **`gzip mtime=0`** so identical content is byte-identical → the Hub content-hash dedup hits.
- **`CollaborationService.publish_kb` / `pull_kb_if_newer`** — publish serializes + `put_blob('kb', app_uuid)`
  with content-hash dedup (no new version if unchanged); pull-first hydrates only when the Hub blob is newer than
  the local `kb:<app_uuid>` cursor (**no needless re-parse**). **Hub-app exclusion** via
  `settings.collab_hub_app_uuid`.
- **API** — `POST /applications/{uuid}/pull` (pull-first) + `/publish` (deliberate refresh→publish); the Hub app
  is rejected from `add`. The existing sync-busy **409** guard covers the export path (no double-export).
- **Scheduler** — an off-by-default `kb-hub-pull` job (a designated machine may run the daily refresh; others
  pull-first). `app.py` builds `collab_service` before the applications + scheduler wiring so they share it.

### 37-03 — identity/teams live + onboarding gate
The `/collab/*` onboarding + Settings identity/team routes are **provider-agnostic**, so they now hit real
Appian automatically once `provider='appian'` (local `collab_teams`/`collab_memberships` stay the offline cache).
**`is_onboarded()`/`require_onboarded()` + `NotOnboardedError`** — a publish with no canonical identity is
blocked (never a silent unattributed write); gated in `publish` + `publish_kb`; the API `/publish` maps it to
**409**. Onboarding is decided from the locally-cached identity (`canonical_username`), so it works **offline**.
Attribution (`published_by`) carries the canonical username end-to-end.

### 37-04 — sync-UX foundation
- Backend: `CollaborationService.is_available()` + `changes_since` passthrough; `GET /api/collab/status` +
  `GET /api/collab/changes?cursor=` (degrade to empty when disabled/unreachable → the poll no-ops).
- Web: `useHubStatus`/`useHubChanges` (TanStack `refetchInterval` polls, only while a relevant view is open) +
  `useSyncNow` ("Check for updates"); **`<HubStatus>`** (live reachability + "Hub unreachable — working locally"
  offline state; renders nothing when disabled) mounted in Settings → Collaboration; **`<StalenessBadge>`** +
  pure `isStale` (**notify-then-apply** — shows "Newer version available — Review" only when the Hub version is
  strictly higher; **never auto-overwrites**).

### 37-05 — review & hardening (independent audit)
An independent auditor confirmed the design and found:
- **MUST-FIX** — `gzip.compress` embeds the current time on Python 3.13 → identical KB content hashed
  differently every publish → the Hub dedup never hit. Fixed with `mtime=0` + a determinism regression test.
- **SHOULD-FIX** — `/pull` + `/publish` returned a raw 500 on a down/401 Hub. Promoted
  `HubTransportError`/`HubAuthError` to the transport-neutral `provider.py` (re-exported from `genesis.collab`);
  the endpoints now degrade to **503** (unreachable) / **401** (bad key). Regression test added.
- **NITs** (blob 200/201 status not surfaced; `get_blob` latest-only; `list_records` `since`; broad offline
  excepts) — documented/deferred to Phase 38.
- Deliverable: **`scripts/acceptance/phase-37-hub-acceptance.py`** (two instances over a local hub:
  publish→pull→hydrate identical, dedup no-op, onboarding gate, determinism/offline) — ALL PASS.

### 37-06 — release
genesis **v0.64.0** (`42e610e`, tag `v0.64.0`); three anchors bumped (`pyproject.toml`, `web/src/version.ts`,
`api/app.py`); `web/static` rebuilt + committed. No migration; genesis-only.

## Gates at release
- Backend **pytest 761** + ruff clean. Web **tsc / eslint 0 / vitest 254 / build** + `web/static` committed.
- genesis-core / kiro-agent-sdk / genesis-workflows / genesis-appian-parser **unchanged**.
- CI: master + `v0.64.0` pipelines (see tracker §6 for the pipeline ids).

## Live acceptance (user-driven / headless-undrivable)
Deploy the Phase-36 Hub → configure Settings → Collaboration (base URL + service-account key) on two instances →
onboard both → **refresh-from-Appian** on instance A (parse + publish the KB blob) → **sync** on instance B
(pull + hydrate, no parse) → team + attribution visible on both. The `scripts/acceptance/phase-37-hub-acceptance.py`
harness proves the same flow headless against the local provider.

## Out of scope (Phase 38)
Per-entity publish/pull for features + published stage artifacts + stories/epics + boards (+ their per-entity
sync UX wiring `<HubStatus>`/`<StalenessBadge>` onto those surfaces) + the one-time adoption bulk-publish;
shared-memory sync (deferred).
