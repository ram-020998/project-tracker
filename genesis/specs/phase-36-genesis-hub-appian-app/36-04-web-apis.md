# 36-04 — Constants, expression rules & Web APIs (Appian build)

> **Status:** 🟡 DRAFTED. · Part of Phase 36. **Built by the Dev-MCP agent** (Appian-side). · **Depends on:** 36-01 (the frozen contract + object inventory), 36-02 (record types + their captured UUIDs), 36-03 (blob store). · **Skill refs (MANDATORY):** `supporting-objects.md` (constants), `expressions.md`/`expression-rules.md`, `write-records-patterns.md`, `function-reference.md`, `null-safety-patterns.md`, `sail-verification-checkpoint.md` (Step 4), `validation-checkpoint.md` (Step 7B), the Web-API guidance. **Every SAIL body passes Step-4 verification + the `validateExpression` retry loop before create.**

## Purpose

Build the **constants**, the **helper expression rules** (the reusable logic), and the **Web API objects** (the
HTTP/JSON surface). Web APIs delegate to the expression rules + `a!writeRecords` — **no process models**.

## A. Constants (skill: `supporting-objects.md`)

- `GH_GROUP_ALL_USERS`, `GH_GROUP_ADMINS`, `GH_GROUP_SERVICE` — Group constants (security expressions).
- `GH_CONTRACT_VERSION` — Text (e.g. `"1.0"`); returned by `/meta` + `/changes`.
- `GH_BLOB_KEEP_LAST_N` — Integer (e.g. `10`).
- `GH_FOLDER_KB_BLOBS`, `GH_FOLDER_ARTIFACT_BLOBS` — Folder constants (blob targets, 36-03).

## B. Helper expression rules (create before the Web APIs)

Each is a validated SAIL rule (Step-4 + Step-7B). Signatures are the contract; the agent generates + validates
the bodies.

| Rule | Inputs → Output | Behavior |
|---|---|---|
| `GH_isServiceCaller()` | → Boolean | true iff the authenticated user is in `GH Service Accounts` (all API calls come as the shared service account). Web APIs reject otherwise (`401`). |
| `GH_errorResponse(code, message, extra)` | → `a!httpResponse` | the uniform `{error, code}` envelope + HTTP status (400/401/404/409/429). |
| `GH_casUpsert(kind, syncUuid, payloadMap, baseVersion, actor)` | → map `{status, version, record}` | look up the current record by `kind`+`syncUuid`; if found and `current.version != baseVersion` → `{status:"conflict", current_version}`; else `a!writeRecords` the mapped fields with `version = coalesce(baseVersion,-1)+1`, `modifiedBy=actor`, `updatedAt=now()` (+ `createdBy`/`createdAt` on create); then `GH_appendChangeLog(...)`; return `{status:"created"|"updated", version, record}`. **The single CAS write path** all record kinds share (dispatch the `kind`→record-type inside). |
| `GH_appendChangeLog(kind, syncUuid, version, actor)` | → (writes) | insert a `GH Change Log` row (id = next sequence) — the manifest feed. |
| `GH_changesSince(cursor, limit)` | → map `{changes, next_cursor}` | `a!queryRecordType(GH Change Log, filter id > cursor, sort id asc, paging limit)` → the manifest page + `next_cursor = max(id)`. |
| `GH_blobDedupAndStore(kind, key, bytesB64, contentHash, actor)` | → map `{status, version}` | latest `GH Blob Version` for the key; if `contentHash` equal → `{status:"unchanged", version}`; else create/upload the Document (36-03) + insert the `GH Blob Version` row (`version=latest+1`) + `GH_appendChangeLog('blob', key, version, actor)` + `GH_pruneBlobVersions(kind,key)` → `{status:"new", version}`. |
| `GH_pruneBlobVersions(kind, key)` | → (deletes) | delete `GH Blob Version` rows (+ their Documents) beyond `GH_BLOB_KEEP_LAST_N` for the key. |
| `GH_recordToJson(kind, record)` | → map | project a record type row → the contract's JSON field names (camel/snake per the contract). |

## C. Web API objects (skill: Web-API guidance; each returns `a!httpResponse`)

All start by asserting `GH_isServiceCaller()` (else `GH_errorResponse(401,…)`) and are added to the Web-API
**allowed origins** for the write verbs (Appian CSRF exemption). URL aliases under the Hub app's Web-API base.

| Web API | Method · path | Logic |
|---|---|---|
| `GH_meta` | GET `/meta` | → `{contract_version: cons!GH_CONTRACT_VERSION, server_time: now()}`. |
| `GH_records_upsert` | PUT `/records/{kind}/{syncUuid}` | parse body (payload + `base_version` + `actor`); `GH_casUpsert(...)`; on `conflict` → `GH_errorResponse(409, "conflict", {current_version})`; else `200`(update)/`201`(create) + the record JSON. Valid `kind` ∈ {team, membership, feature, epic, story, board_state, stage_artifact} (400 otherwise). |
| `GH_records_list` | GET `/records/{kind}?since=&limit=` | query the kind's record type (optionally filter to changed-since via join to `GH Change Log`, or return all with paging) → `{records:[GH_recordToJson…], next_cursor}`. |
| `GH_records_get` | GET `/records/{kind}/{syncUuid}` | query by `syncUuid` → the record JSON or `GH_errorResponse(404,…)`. |
| `GH_blobs_put` | POST `/blobs/{kind}/{key}` | parse body (base64 + `content_hash` + `published_by`); `GH_blobDedupAndStore(...)` → `200 {status:"unchanged",version}` or `201 {status:"new",version}`. |
| `GH_blobs_get` | GET `/blobs/{kind}/{key}` | latest `GH Blob Version` → return the Document bytes (base64) + `content_hash` + `version`; `404` if none. |
| `GH_blobs_versions` | GET `/blobs/{kind}/{key}/versions` | the `GH Blob Version` history metadata for the key. |
| `GH_changes` | GET `/changes?cursor=&limit=` | `GH_changesSince(cursor,limit)` → `{changes, next_cursor, contract_version}`. |
| `GH_activity_set` | POST `/activity` | upsert a `GH Activity` marker (kind, syncUuid, username, `expiresAt = now()+ttl`). |
| `GH_activity_clear` | DELETE `/activity/{kind}/{syncUuid}` | delete the marker. |
| `GH_activity_list` | GET `/activity/{kind}` | markers where `expires_at > now()`. |
| `GH_records_delete` (OPTIONAL) | DELETE `/records/{kind}/{syncUuid}` | soft-delete/tombstone for the story-delete propagation (Phase 38-02) — or model deletes as a `status`; finalize in 36-01. |

**recordType! references:** every query/write in these rules/APIs uses the **UUID-qualified** form with the
UUIDs captured in 36-02 (skill rule — never fabricate). **Attribution** (`createdBy`/`modifiedBy`/`publishedBy`)
comes from the **request body `actor`/`published_by`**, never from the Appian session (which is always the
service account).

## Validation

Each Web API matches the 36-01 contract shapes + status codes (esp. the **409** CAS + **200/201** dedup); every
SAIL body passed `validateExpression`; conditionally-rendered logic exercised. Confirmed by the 36-06 harness
with the 36-01 fixtures (shared with Phase 37).

## Deliverable

The constants + the 8 helper expression rules + the 11–12 Web API objects, contract-conformant.

## Gate

Contract-conformant API surface → 36-05.
