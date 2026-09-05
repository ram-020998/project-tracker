# 36-01 — App architecture, the frozen API contract & ADR-064

> **Status:** 🟡 DRAFTED — docs only; gate = user sign-off → build. · Part of Phase 36. Repo: **genesis** (the contract doc + fixtures are checked in here; the app is Appian-side). · **Depends on:** 35-01 (the `SyncProvider` Protocol + entity payload model this contract must satisfy), ADR-048 (service-account creds), the researched Appian capabilities.

## Purpose

Freeze **what the Dev-MCP agent builds** and **the exact HTTP/JSON contract** Genesis's Phase-37 provider codes
against — the record/document model, the Web-API request/response shapes, status codes (incl. the **409**
version-conflict that maps to `HubConflict`), pagination, and auth — plus **contract fixtures** and **ADR-064**.
The contract is the load-bearing artifact of this phase: it lets Phase 36 (Appian build) and Phase 37 (Genesis
provider) proceed against one stable interface. **No implementation.**

## Deliverables (checked into genesis, alongside Phase 37)

1. **The record & document model** (fields, types, keys, relationships, versioning) for Team, Membership,
   Feature, Epic, Story, BoardState, StageArtifact-metadata, KbBlob, ArtifactBlob — per the umbrella §5, in a
   normative table. Every record: `sync_uuid` (unique), `version` (int, CAS), `created_by`/`modified_by`/
   `created_at`/`updated_at`; top-level ones + `owner_username`/`team_uuid`.
2. **The frozen Web-API contract** (`specs/phase-36-genesis-hub-appian-app/contract/genesis-hub-api.md`):
   - `PUT /records/{kind}/{sync_uuid}` body/response; **base-version CAS** semantics → **409** with a
     `{current_version}` body (Genesis maps → `HubConflict` → notify-then-apply). `201` create / `200` update.
   - `GET /records/{kind}?since=<cursor>&limit=` (paginated list) + `GET /records/{kind}/{sync_uuid}`.
   - `POST /blobs/{kind}/{key}` (multipart or base64; `content_hash` in body → **dedup**: `200` "unchanged" vs
     `201` new version) + `GET /blobs/{kind}/{key}` (latest) + `GET /blobs/{kind}/{key}/versions`.
   - `GET /changes?cursor=` → `{changes:[{kind, sync_uuid, version, updated_at, published_by}], next_cursor}`.
   - `POST /activity` / `DELETE /activity/{kind}/{sync_uuid}` / `GET /activity/{kind}` (TTL advisory markers).
   - `POST /teams` / `GET /teams` / `POST /memberships` / `GET /teams/{team_uuid}/memberships`.
   - **Auth:** the service-account API-key header (name per the Appian Web-API convention on the target version);
     allowed-origins/CSRF note for the write verbs.
   - **Error envelope:** a uniform `{error, code}` shape; the status-code table (200/201/400/401/404/409/429).
   - **A `contract_version`** field on `GET /changes` (and a `/meta` endpoint) so Genesis detects a mismatch.
3. **Contract fixtures** (`contract/fixtures/*.json`) — canonical request/response examples for every endpoint,
   **shared** by the Appian contract-test harness (36-06) AND the Genesis provider tests (37-01), so both sides
   validate against identical shapes (the "stub must mirror the real contract" §7 rule).
4. **The isolation rule** documented: the Hub is a distinct Appian application; Genesis's Applications surface
   never adds it as a tracked subject app; Phase 37 enforces the exclusion by `app_uuid`.
5. **ADR-064** drafted (Proposed) in `reference/decision-log.md` per the umbrella §7.

## Gate

⭐ User sign-off on the record model + the frozen contract → the Dev-MCP agent builds 36-02..36-05; Phase 37's
provider (37-01) codes against this contract.
