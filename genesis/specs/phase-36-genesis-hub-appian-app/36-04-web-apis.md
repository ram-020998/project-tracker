# 36-04 — Web APIs (Appian)

> **Status:** 🟡 DRAFTED. · Part of Phase 36. **Built by the Dev-MCP agent** (Appian-side). · **Depends on:** 36-01 (frozen contract), 36-02 (records), 36-03 (blobs).

## Purpose

Build the **Web APIs** Genesis calls — the concrete HTTP/JSON endpoints of the frozen 36-01 contract — over the
record types (36-02) and blob store (36-03), authenticated by the shared service account.

## Build (Dev-MCP agent) — per the frozen contract

- **Records:** `PUT /records/{kind}/{sync_uuid}` (upsert; **base-version CAS** → `409 {current_version}` on
  conflict; bump `version`; set `modified_by` from payload); `GET /records/{kind}?since=&limit=` (paginated);
  `GET /records/{kind}/{sync_uuid}`.
- **Blobs:** `POST /blobs/{kind}/{key}` (dedup on `content_hash` → `200` unchanged / `201` new version);
  `GET /blobs/{kind}/{key}` (latest); `GET /blobs/{kind}/{key}/versions`.
- **Change manifest:** `GET /changes?cursor=` → `{changes:[{kind, sync_uuid, version, updated_at,
  published_by}], next_cursor, contract_version}` (an append-only change log across the record types).
- **Advisory:** `POST /activity` (set, with TTL), `DELETE /activity/{kind}/{sync_uuid}` (clear),
  `GET /activity/{kind}` (list live markers).
- **Teams:** `POST /teams`, `GET /teams`, `POST /memberships`, `GET /teams/{team_uuid}/memberships`.
- **Auth:** the service-account **API-key header** (name per the target Appian version); write verbs added to
  **allowed-origins** (Appian's CSRF exemption for POST/PUT/DELETE Web APIs). **Attribution from the payload.**
- **Errors:** the uniform `{error, code}` envelope + the 36-01 status-code table.

## Validation

Every endpoint matches the 36-01 shapes + status codes (esp. the **409** CAS + the **dedup** 200/201); the
change manifest advances a cursor; activity markers expire. Verified by the contract harness (36-06) with the
36-01 fixtures.

## Gate

Contract-conformant API surface → 36-05.
