# 37-01 — The Appian `SyncProvider`

> **Status:** 🟡 DRAFTED. · Part of Phase 37. Repo: **genesis**. · **Depends on:** Phase 35 (`SyncProvider` Protocol + `build_sync_provider`), Phase 36 (the frozen contract + fixtures), ADR-048 (service-account creds).

## Purpose

Implement `AppianHubProvider` — the real `SyncProvider` over the Phase-36 Genesis Hub Web APIs — so the
unchanged `CollaborationService` talks to a live Appian Hub. Prove it is **contract-identical** to what the
Appian side built by testing against the **shared 36-01 fixtures**.

## Build

1. **`genesis/collab/providers/appian.py::AppianHubProvider(SyncProvider)`** — an HTTP client (reuse the
   platform request stack) to the configured Hub base URL; **service-account API-key auth** resolved from the
   ADR-048 per-env store; implements every Protocol method against the frozen endpoints:
   - `put_record` → `PUT /records/{kind}/{sync_uuid}` with base-version; **map 409 → `HubConflict`**; 200/201.
   - `get_record`/`list_records(since=)` → the GET endpoints (paginate `list_records`).
   - `put_blob` (content-hash → **dedup** 200/201), `get_blob`, `list_blob_versions`.
   - `changes_since(cursor)` → `GET /changes`; `set/clear/list_activity`; `upsert_team`/`list_teams`/
     `upsert_membership`/`list_memberships`/`resolve_user`.
   - `is_available()` → ping `/meta`; read + check `contract_version` (warn on mismatch, don't hard-fail unless
     incompatible).
2. Register in `build_sync_provider()` as `provider='appian'` (constructed when Settings → Collaboration selects
   Appian + supplies base URL + the service-account key is present). Errors → typed provider errors; timeouts +
   retry/backoff for transient 5xx/429; never leak the API key.

## Tests

- **Contract-conformance against the shared 36-01 fixtures** (an MSW/stub server driven by the fixtures): every
  method sends/parses the frozen shapes; **409 → `HubConflict`**; blob **dedup** 200 vs 201; `changes_since`
  cursor advances; `contract_version` mismatch warns. (Same fixtures the Appian side passed → both provably
  aligned; the "stub mirrors the real contract" §7 rule.)
- `is_available()` false on unreachable; auth header present; key never logged. ruff clean.

## Deliverable

`AppianHubProvider` + registration + fixture-driven contract tests.

## Gate

Independent review = SHIP: contract-conformant vs the Phase-36 fixtures; auth/offline correct; gates green.

---
