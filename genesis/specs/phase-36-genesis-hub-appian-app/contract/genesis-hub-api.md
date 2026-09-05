# Genesis Hub API — Frozen Contract (v1.0.0)

> **Status:** ✅ FROZEN — `contract_version = "1.0.0"`. This is the **normative** HTTP/JSON interface the
> Genesis-side `AppianHubProvider` (Phase 37) codes against and the **shared** source of truth for the 36-06
> contract-validation harness + Phase-37 provider tests + the Phase-38 round-trip fidelity gate. Part of
> Phase 36 (ADR-064). Backend = the **Genesis Hub** Appian application (appUuid
> `_a-0000f058-fed5-8000-9bfc-011c48011c48_27312`, dev env `merge-assist-dev.appianpreview.com`, Appian 26.6).
>
> **As-built.** Every shape below is transcribed from the deployed Web APIs + helper rules (see
> `progress/phase-36-genesis-hub-appian-app.md` for object UUIDs). Fixtures live in `./fixtures/*.json`.
> **Lossless sync is a hard invariant** (36-01 §2.0): the round-trip `local → PUT → Hub → GET → local` must
> reproduce every field byte-for-byte (unicode, whitespace, ordering, empty-vs-null).

---

## 1. Transport, auth, and the base path

- **Base URL:** `https://<appian-host>/suite/webapi/<urlAlias>` — every endpoint is an Appian **Web API** object
  keyed by a unique `urlAlias`. Path parameters (`{kind}`, `{key}`, `{syncUuid}`) are **trailing URL path
  segments after the alias**, read by the Web API as `http!request.pathSegments` (1-indexed *after* the alias).
- **Auth:** the shared service account's **API key** in the `appian-api-key` request header (ADR-048; the
  `genesis.hub.service` account, member of `GH Service Accounts`). Every endpoint asserts
  `GH_isServiceCaller()` and returns **`401 {"error":"unauthorized","code":401}`** otherwise.
- **Attribution is payload-carried, not from Appian auth.** The service account is the physical Appian writer;
  the *logical* author is the `created_by` / `modified_by` / `published_by` / `username` field in the request
  body (a canonical Genesis/Appian username string).
- **Content type:** requests and responses are `application/json` (`Content-Type: application/json` on every
  response). Blob bytes travel **base64-encoded inside JSON** (never multipart).
- **Write verbs** (`PUT`, `POST`, `DELETE`) must be added to the Hub's **allowed origins** / CSRF exemption for
  API-key calls (deployment runbook item, 36-05).

### 1.1 urlAlias → contract path map (aliases can't collide, so the path is encoded in the alias)

The Genesis provider maps each logical contract path to the concrete `urlAlias` + trailing segments:

| Contract path | Method | Web API object | urlAlias | Path segments (after alias) |
|---|---|---|---|---|
| `/meta` | GET | `GH_meta` | `meta` | — |
| `/records/{kind}/{syncUuid}` | PUT | `GH_records_upsert` | `records` | `{kind}` `{syncUuid}` |
| `/records/{kind}/{syncUuid}` | GET | `GH_records_get` | `records_get` | `{kind}` `{syncUuid}` |
| `/records/{kind}` | GET | `GH_records_list` | `records_list` | `{kind}` |
| `/changes` | GET | `GH_changes` | `changes` | — |
| `/activity` | POST | `GH_activity_set` | `activity` | — |
| `/activity/{kind}/{syncUuid}` | DELETE | `GH_activity_clear` | `activity_clear` | `{kind}` `{syncUuid}` |
| `/activity/{kind}` | GET | `GH_activity_list` | `activity_list` | `{kind}` |
| `/blobs/{kind}/{key}` | POST | `GH_blobs_put` | `blobs` | `{kind}` `{key}` |
| `/blobs/{kind}/{key}` | GET | `GH_blobs_get` | `blobs_get` | `{kind}` `{key}` |
| `/blobs/{kind}/{key}/versions` | GET | `GH_blobs_versions` | `blobs_versions` | `{kind}` `{key}` |

> The concrete URL for e.g. `GET /records/story/<uuid>` is
> `https://<host>/suite/webapi/records_get/story/<uuid>`.

---

## 2. Kinds and the canonical record shapes

`{kind}` ∈ **`team` · `membership` · `feature` · `epic` · `story` · `board_state` · `stage_artifact`** (7 record
kinds). `blob` is a separate change-log kind (not a records kind). All record JSON keys are **snake_case**.

Every record response carries a server-managed **`version`** (Integer, the optimistic-CAS counter) plus audit
fields. On **upsert** Genesis sends the record payload **plus `base_version`** (the version it last saw; omit /
`null` on first create). Server-managed fields (`version`, `created_at`, `updated_at`, and `created_by` on
update) are ignored on input and authoritative on output.

### 2.1 Field tables (response shape per kind)

**team** — `sync_uuid`, `title`, `version`, `created_by`, `created_at`, `updated_at`.
**membership** — `sync_uuid`, `team_uuid`, `username`, `name`, `email`, `joined_at`, `version`.
**feature** — `sync_uuid`, `app_uuid`, `name`, `description`, `owner_username`, `team_uuid`, `version`,
`created_by`, `modified_by`, `created_at`, `updated_at`.
**epic** — `sync_uuid`, `feature_sync_uuid`, `key`, `title`, `description`, `workstream`, `position`, `version`,
`created_by`, `modified_by`, `created_at`, `updated_at`.
**story** — `sync_uuid`, `feature_sync_uuid`, `epic_sync_uuid`, `key`, `title`, `story_type`, `category`,
`appian_part`, `description`, `dev_note_ref`, `status`, `position`, `owner_username`, `team_uuid`, `version`,
`created_by`, `modified_by`, `created_at`, `updated_at`, **`acceptance_criteria` (array of text)**,
**`questions` (array of text)**, **`labels` (array of text)**.
**board_state** — `sync_uuid`, `app_uuid`, `story_sync_uuid`, `status`, `version`, `modified_by`, `updated_at`.
**stage_artifact** — `sync_uuid`, `parent_sync_uuid`, `parent_kind`, `stage`, `status`, `content_hash`,
`blob_key`, `upstream_versions`, `published_by`, `published_at`, `version`, `created_at`, `updated_at`.

### 2.2 Story lists are normalized on the Hub, arrays on the wire (lossless)

`acceptance_criteria` / `questions` / `labels` are **arrays of strings** in the story JSON (both directions). On
write, `GH_records_upsert(kind='story')` **explodes** them into `GH Story Item` child rows (one per element,
`position` = array index, `item_type` ∈ `ac|question|label`) atomically with the story; on read,
`GH_recordToJson` **reassembles** them position-ordered. **An empty array stays an empty array** (`[]`, distinct
from a missing field) — zero child rows. This is a Hub-internal detail; the Genesis local model keeps its JSON
columns. Order and count are preserved exactly (36-01 §2.0).

---

## 3. Endpoints

### 3.1 `GET /meta` — health + contract version
- **200** → `{ "contract_version": "1.0.0", "server_time": "<ISO-8601 datetime>" }`
- Use to verify auth + contract compatibility before syncing.

### 3.2 `PUT /records/{kind}/{syncUuid}` — upsert with base-version CAS
- **Body:** the record payload (snake_case, §2.1) **+ `base_version`** (Integer; omit or `null` to create).
  `actor` is taken from `modified_by`, else `created_by`, else `"service"`. For `story`, include the three
  arrays.
- **Semantics:** query current by `syncUuid`. If found **and** `current.version != base_version` →
  **conflict**. Else write with `version = coalesce(base_version, -1) + 1`, preserve `created_by`/`created_at`
  on update, set `modified_by`/`updated_at`, append a `GH Change Log` row (the `/changes` feed).
- **Responses:**
  - **201** (created) → `{ "status": "created", "version": <int> }`
  - **200** (updated) → `{ "status": "updated", "version": <int> }`
  - **409** (CAS conflict) → `{ "error": "conflict", "current_version": <int> }` — Genesis maps this to
    `HubConflict` → notify-then-apply.
  - **400** → `{ "error": "invalid kind or missing syncUuid", "code": 400 }` (unknown kind or empty syncUuid).
  - **401** → `{ "error": "unauthorized", "code": 401 }`.

### 3.3 `GET /records/{kind}/{syncUuid}` — single record
- **200** → the record JSON (§2.1); for `story`, arrays reassembled.
- **404** → `{ "error": "not found", "code": 404 }`.

### 3.4 `GET /records/{kind}?limit=<n>` — list a kind
- **Query:** `limit` (Integer, default **500**).
- **200** → `{ "records": [ <record JSON>, … ], "next_cursor": null }`.
- **Note:** list returns the kind's records (paged, `next_cursor` currently always `null`). **Incremental
  deltas are served via `/changes`** (below), not via a `since` param on list — list = full pull, changes =
  delta feed. (Fetch changed `sync_uuid`s from `/changes`, then GET each, or full-list a kind.)

### 3.5 `GET /changes?cursor=<n>&limit=<n>` — the change manifest feed
- **Query:** `cursor` (Integer, default 0 = from the beginning), `limit` (Integer, default 500).
- **200** → `{ "changes": [ { "kind": <str>, "sync_uuid": <str>, "version": <int>, "updated_at": <datetime>,
  "published_by": <str> }, … ], "next_cursor": <int>, "contract_version": "1.0.0" }`.
- `changes` are `GH Change Log` rows with `id > cursor`, **ascending**; `next_cursor` = the max `id` on the page
  (or the input `cursor` when empty). `kind` includes `blob` for blob publishes (its `sync_uuid` is the blob
  key). Poll with the last `next_cursor` to get only new changes.

### 3.6 `POST /blobs/{kind}/{key}` — publish blob bytes (dedup + version)
- **`{kind}`** ∈ `kb` | `artifact`. **`{key}`:** for `kb` = the app_uuid; for `artifact` =
  `<parentSyncUuid>:<stage>`.
- **Body:** `{ "base64": "<base64 bytes>", "content_hash": "<hex sha256 of the decoded bytes>",
  "published_by": "<username>" }`.
- **Semantics:** if `content_hash == latest.content_hash` → **dedup, no new document**. Else create a new
  Appian Document from the base64 (activity-chained to `GH Convert Base 64 To Document`), insert a
  `GH Blob Version` row (`version = latest + 1`), append a `blob` change-log row, prune beyond
  `GH_BLOB_KEEP_LAST_N` (10).
- **Responses:**
  - **200** (dedup hit) → `{ "status": "unchanged", "version": <int> }`
  - **201** (new version) → `{ "status": "new", "version": <int> }`
  - **401** unauthorized.

### 3.7 `GET /blobs/{kind}/{key}` — latest blob bytes
- **200** → `{ "base64": "<base64 bytes>", "content_hash": "<hex>", "version": <int> }`.
- **404** → `{ "error": "not found", "code": 404 }` (no version, or its document is unresolved).

### 3.8 `GET /blobs/{kind}/{key}/versions` — version history metadata
- **200** → `{ "versions": [ { "version": <int>, "content_hash": <hex>, "size": <int>, "published_by": <str>,
  "created_at": <datetime> }, … ] }` — newest first (version desc). Bytes are not included.

### 3.9 `POST /activity` — set an advisory in-progress marker
- **Body:** `{ "kind": <str>, "sync_uuid": <str>, "username": <str>, "ttl_seconds": <int> }` (`ttl_seconds`
  default **900**). Upserts one marker per `(kind, sync_uuid)`; `expires_at = now + ttl`.
- **200** → `{ "status": "ok" }`. **400** → `{ "error": "kind and sync_uuid required", "code": 400 }`.
- **Advisory only** — never a hard lock (soft-lock posture, ADR-063).

### 3.10 `DELETE /activity/{kind}/{syncUuid}` — clear a marker
- **200** → `{ "status": "cleared" }` (idempotent — 200 even if none existed).

### 3.11 `GET /activity/{kind}` — live markers
- **200** → `{ "markers": [ { "kind": <str>, "sync_uuid": <str>, "username": <str>, "set_at": <datetime>,
  "expires_at": <datetime> }, … ] }` — only markers with `expires_at > now`.

---

## 4. Status codes (uniform)

| Code | Meaning | Body |
|---|---|---|
| 200 | OK / updated / unchanged / cleared / ok | endpoint-specific |
| 201 | Created / new blob version | `{ "status": "created" | "new", "version": <int> }` |
| 400 | Bad request (invalid kind, missing required field) | `{ "error": <str>, "code": 400 }` |
| 401 | Unauthorized (not a service caller) | `{ "error": "unauthorized", "code": 401 }` |
| 404 | Not found (record / blob) | `{ "error": "not found", "code": 404 }` |
| 409 | CAS conflict (stale `base_version`) | `{ "error": "conflict", "current_version": <int> }` |
| 429 | Rate limited (reserved; not emitted by v1) | `{ "error": <str>, "code": 429 }` |

> The error envelope from `GH_errorResponse` is `{ "error": <message>, "code": <statusCode> }`. The **409
> conflict** and **200/201 dedup/upsert** bodies are the domain-specific shapes above (not the generic
> envelope) — match them exactly.

---

## 5. Datetime + encoding conventions

- **Datetimes** are Appian `a!toJson` datetime encodings (ISO-8601, e.g. `"2026-09-05T18:00:00Z"`). Genesis
  parses them tolerantly.
- **`content_hash`** is the hex SHA-256 of the **decoded** blob bytes (the client computes it; the Hub dedups on
  equality with the latest stored hash). `size` on `GH Blob Version` is currently the **base64 string length**
  (≈ decoded × 4/3) — an indicator, not exact decoded-byte count (36-08 note; harden if the contract later
  requires exact bytes).
- **Text sizing (server-side, lossless):** short codes/uuids/hashes → 255; `title`/`dev_note_ref`/
  `upstream_versions` → 4000; `description` + story-item `text` → 64000 (Extra Long Text). Values must fit in
  **bytes** (multibyte/emoji count > 1). Content beyond 64000 bytes belongs in an artifact blob, not a field.

---

## 6. Fixtures (`./fixtures/`)

Adversarial, lossless round-trip fixtures — each `*.json` pairs the **PUT request body** Genesis sends with the
**GET response body** the Hub returns (server-managed fields added). Used by the 36-06 harness + Phase-37
provider tests. Deliberately exercise: multi-KB unicode/emoji `description`, many/long acceptance criteria,
**empty arrays** (`questions: []`), `null` optional fields (`epic_sync_uuid`), and the 409/dedup bodies.

| Fixture | Covers |
|---|---|
| `meta.json` | `GET /meta` response |
| `team.json`, `membership.json` | team/membership upsert↔get |
| `feature.json` | feature with a long unicode/emoji description |
| `epic.json` | epic (nullable position) |
| `story.json` | story with many AC, **empty `questions`**, unicode labels, `null` `epic_sync_uuid` |
| `board_state.json`, `stage_artifact.json` | the remaining kinds |
| `conflict.json` | the **409** CAS body |
| `changes.json` | the `/changes` page shape (incl. a `blob` row) |
| `blobs.json` | blob put (201 new / 200 unchanged), get, versions |
| `activity.json` | activity set / list / clear |

> **Round-trip rule (Phase 38 / 36-06):** for every kind, `put_request` (minus `base_version` + server fields)
> must equal the corresponding field subset of `get_response` — byte-for-byte, arrays included.
