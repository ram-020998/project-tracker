# 36-01 — App architecture, object inventory, data model & the frozen API contract (ADR-064)

> **Status:** 🔨 BUILD IN PROGRESS — object inventory + data model built; the frozen contract doc + fixtures still to be written (see progress/phase-36-genesis-hub-appian-app.md). · Part of Phase 36. Repo: **genesis** (this contract doc + the fixtures are checked in here; the Appian objects are built by the Dev-MCP agent). · **Depends on:** 35-01 (the `SyncProvider` Protocol + entity payload model this contract must satisfy), ADR-048 (service-account creds), the installed **Appian skill** (`~/.kiro/skills/appian/`).

## Purpose

This is the **master build reference** for the Genesis Hub Appian application. It names **every Appian object**
to create, its **complete structure** (fields, types, keys, relationships, security), the **dependency order**,
the **naming conventions**, and the **frozen HTTP/JSON API contract** the Genesis-side provider (Phase 37) codes
against. It is written to be executed by a **separate agent that has a write-capable Appian Dev MCP** — that
agent MUST load the Appian skill references (below) before creating anything. **No implementation here — this
is the specification.**

---

## 0. MANDATORY for the building agent — load the Appian skill first

The building agent MUST follow the installed **Appian skill** (`~/.kiro/skills/appian/SKILL.md`) exactly:

- **Before any MCP tool call:** load the Step-1 universal patterns (`tools-mcp.md`, `confirmation-patterns.md`,
  `function-reference.md`, `component-reference.md`, `null-safety-patterns.md`, `short-circuit-patterns.md`,
  `sail-verification-checkpoint.md`).
- **Per task:** `applications.md`, `data-modeling.md`, `record-types.md`, `relationship-patterns.md`,
  `supporting-objects.md` (constants/groups/folders/documents), `security.md` + `security-patterns.md`,
  `expressions.md`/`expression-rules.md`, `write-records-patterns.md` (inline `a!writeRecords`), the Web-API
  guidance, and `change-planning.md`.
- **Every SAIL expression** (Web-API bodies + expression rules) goes through **Step 4 verification** +
  **Step 7B `validateExpression` retry loop** before `create*`. **UUIDs are sourced from the environment**
  (create record types → capture their UUIDs → use the UUID-qualified `'recordType!{uuid}...'` form in
  expressions), **never fabricated**.
- **Naming/keys (skill conventions):** primary key is **`id` (Integer, auto-generated)**; relationships need
  **both** MANY_TO_ONE + ONE_TO_MANY sides; lookup/name fields use `name`. Objects use the **`GH` prefix**
  ("Genesis Hub").
- **No USER fields.** Attribution (`createdBy`/`modifiedBy`/`ownerUsername`/`publishedBy`) is stored as **Text**
  (the caller's canonical Genesis/Appian **username string** carried in the request payload), NOT as an Appian
  USER field — so we avoid the `SYSTEM_RECORD_TYPE_USER` relationship requirement and correctly represent that
  the **service account** is the actual Appian writer while the *logical* author is payload-supplied.
- **⚠️ Synced record types have THREE text sizes (Appian data-sync limits, verified in the 26.x docs — text
  beyond a field's size is truncated on sync, and limits are in BYTES so an emoji counts as 4):**
  **`Text` = 255** · **`Long Text` = 4000** · **`Extra Long Text` = 64000** — and a synced record type may have
  **at most 3 `Extra Long Text` fields**. So: (a) all large content (the KB blob + artifact HTML) is stored as
  **Appian Documents**, never record columns (36-03) — unaffected; (b) genuinely-long single free-text fields
  (`description`) use **`Extra Long Text` (64000)** — ample for any realistic summary; each record type uses ≤ 1
  (well within the 3-field budget); (c) **variable-length lists** (`acceptance_criteria`, `questions`, `labels`)
  are **normalized into a child record type `GH Story Item`** (one row per item) — because they are
  variable-*count* (not just long), normalization is the right model regardless of the char limit; each item's
  `text` uses `Extra Long Text` (64000) for headroom. **The Genesis-side local model is NOT changed** (SQLite
  keeps its JSON columns); the **sync payload carries the arrays / full text**, and the Appian **Web API
  explodes lists into `GH Story Item` on write + reassembles on read** — an Appian-Hub-internal concern
  (§2.5b, 36-04), **lossless** (§2.0). Sensible sizing per field: keys/uuids/hashes/statuses/types → `Text`
  (255); `dev_note_ref`/`title`/`upstream_versions` → `Long Text` (4000); `description` + `GH Story Item.text` →
  `Extra Long Text` (64000).

---

## 1. Object inventory (in dependency order — create in this sequence)

| # | Object type | Object name (prefix `GH`) | Purpose |
|---|---|---|---|
| 1 | **Application** | `Genesis Hub` (prefix `GH`) | The isolated Hub app; creates default groups + folders. |
| 2 | Group | `GH All Users` | Parent group; the team (read access to Hub data). |
| 2 | Group | `GH Administrators` | Child of All Users; manage/admin. |
| 2 | Group | `GH Service Accounts` | Child of All Users; the API writer(s). |
| 2 | **Service account (user)** | `genesis.hub.service` | The single account whose **API key** Genesis uses for all Hub calls; member of `GH Service Accounts`. |
| 3 | Knowledge Center + Folders | `GH Documents` → `GH KB Blobs`, `GH Artifact Blobs` | Hold the versioned blob documents (KB + artifacts). |
| 4 | Constant | `GH_GROUP_ALL_USERS`, `GH_GROUP_ADMINS`, `GH_GROUP_SERVICE` | Group refs for security expressions. |
| 4 | Constant | `GH_CONTRACT_VERSION` (Text, e.g. `"1.0"`) | The API contract version returned by `/meta` + `/changes`. |
| 4 | Constant | `GH_BLOB_KEEP_LAST_N` (Integer, e.g. `10`) | Blob retention (keep last N versions). |
| 4 | Constant | `GH_FOLDER_KB_BLOBS`, `GH_FOLDER_ARTIFACT_BLOBS` (Folder) | Target folders for blob documents. |
| 5 | **Record types** (11) | `GH Team`, `GH Membership`, `GH Feature`, `GH Epic`, `GH Story`, **`GH Story Item`** (normalized AC/questions/labels — child of Story), `GH Board State`, `GH Stage Artifact`, `GH Blob Version`, `GH Change Log`, `GH Activity` | The shared entities + the normalized story-item child + the blob-version index + the change manifest + advisory markers (full field tables in §2). |
| 6 | Record type relationships | Feature↔Epic, Feature↔Story, Epic↔Story, Feature↔StageArtifact, **Story↔StoryItem**, Team↔Membership (both sides each) | Queryability + admin views (§2.11). |
| 7 | **Expression rules** (helpers) | `GH_isServiceCaller`, `GH_casUpsert`, `GH_appendChangeLog`, `GH_changesSince`, `GH_blobDedupAndStore`, `GH_pruneBlobVersions`, `GH_recordToJson`, `GH_errorResponse` | The reusable logic the Web APIs delegate to (§4 in 36-04). |
| 8 | Interfaces (OPTIONAL) | `GH_adminDashboard`, `GH_teamsView`, `GH_featuresView` | Admin visibility only — not required by the contract. |
| 12 | **Web APIs** (12) | `GH_records_upsert`, `GH_records_list`, `GH_records_get`, `GH_blobs_put`, `GH_blobs_get`, `GH_blobs_versions`, `GH_changes`, `GH_activity_set`, `GH_activity_clear`, `GH_activity_list`, `GH_meta` (+ optional `GH_records_delete`) | The HTTP/JSON surface Genesis calls (§3 contract; §4 in 36-04 for each object's logic). |
| 13 | Documents | (created at runtime) | Blob documents uploaded by `GH_blobs_put` into the blob folders. |

**No process models required** — writes are inline `a!writeRecords` in the Web-API expressions (skill:
`write-records-patterns.md`). A process model is only needed if async/scheduled retention is preferred over
inline pruning (see 36-03). **No site required** (headless API); the optional admin interfaces (#8) are a
convenience.

---

## 2. Data model — record types (full field tables)

**Every** record type is backed by a database table on the Hub data source (skill: `data-modeling.md`), with:
PK **`id`** (Integer, identity); **`syncUuid`** (Text, **unique index**) = the Genesis `sync_uuid`; **`version`**
(Integer, default 0) = the optimistic-CAS counter; and audit **`createdBy`/`modifiedBy`** (Text usernames),
**`createdAt`/`updatedAt`** ("Date and Time"). Types are Appian field types (Text / Integer / "Date and Time" /
Boolean). **Text fields use one of the three synced sizes — `Text` (255) / `Long Text` (4000) / `Extra Long
Text` (64000), max 3 `Extra Long Text` per record type; sized per field so nothing truncates** (large content is
a Document, 36-03; variable-length lists are normalized into `GH Story Item`, §2.5b — never a JSON string
column). Column names are `snake_case`; field names `camelCase`.

### 2.0 Data integrity — LOSSLESS, order-preserving sync (no truncation, no drop) — MANDATORY

The publish/pull mapping between the Genesis local model (JSON) and the Hub (normalized) **MUST be lossless in
both directions.** Concretely:
- **No text is truncated.** Each text field is sized to hold its content — genuinely-long free text
  (`description`, `GH Story Item.text`) uses **`Extra Long Text` (64000 bytes)**, ample for any realistic value;
  medium text uses `Long Text` (4000); short codes use `Text` (255). (Limits are **bytes** — a value with
  multibyte characters/emojis must fit in bytes; a >64000-byte value is out of scope and belongs in an artifact
  Document, not a field.)
- **Lists are preserved exactly** — `acceptance_criteria`/`questions`/`labels` → `GH Story Item` rows keep
  **content + order** (`position`) + **count** (including an **empty list** → zero rows, distinct from a missing
  field); reassembled to the identical array.
- **Round-trip fidelity is a hard gate:** for every synced kind, `local → publish payload → Hub records →
  pull payload → local` must reproduce the original **byte-for-byte** at the field level (unicode, whitespace,
  ordering, empty-vs-null all preserved). Enforced by a **round-trip fidelity test** on the Genesis side (38-02)
  and the contract harness (36-06) using adversarial fixtures (a long multi-KB description, many/long AC,
  unicode/emoji, empty arrays, nulls).
- **Deletes propagate** (a removed story/AC item is removed on pull — tombstone/soft-delete per the contract),
  so pull does not silently retain stale data.

### 2.1 `GH Team` — table `gh_team`
| field (column) | type | notes |
|---|---|---|
| id (id) | Integer | PK |
| syncUuid (sync_uuid) | Text | **unique** = the team_uuid (client-generated by Genesis) |
| title (title) | Long Text (4000) | |
| version (version) | Integer | CAS |
| createdBy (created_by) / createdAt (created_at) / updatedAt (updated_at) | Text / DateTime | audit |

### 2.2 `GH Membership` — table `gh_membership`
| field | type | notes |
|---|---|---|
| id | Integer | PK |
| syncUuid (sync_uuid) | Text | **unique** (membership row id) |
| teamUuid (team_uuid) | Text | → `GH Team.syncUuid` |
| username (username) | Text | canonical Genesis/Appian username |
| name (name) | Text | |
| email (email) | Text | |
| joinedAt (joined_at) | DateTime | |
| version | Integer | CAS |
| **unique** (team_uuid, username) | | one membership per user per team |

### 2.3 `GH Feature` — table `gh_feature`
| field | type | notes |
|---|---|---|
| id | Integer | PK |
| syncUuid (sync_uuid) | Text | **unique** |
| appUuid (app_uuid) | Text | the Appian app the feature belongs to |
| name (name) | Text | |
| description (description) | Extra Long Text (64000) | summary; ample headroom, never truncated (§2.0); 1 of the ≤3 Extra-Long-Text budget |
| ownerUsername (owner_username) | Text | forward-compat visibility tag |
| teamUuid (team_uuid) | Text | forward-compat visibility tag |
| version / createdBy / modifiedBy / createdAt / updatedAt | Integer / Text / Text / DateTime / DateTime | |

### 2.4 `GH Epic` — table `gh_epic`
| field | type | notes |
|---|---|---|
| id | Integer | PK |
| syncUuid (sync_uuid) | Text | **unique** |
| featureSyncUuid (feature_sync_uuid) | Text | → `GH Feature.syncUuid` |
| key (backlog_key) | Text | provenance ("epic-1") |
| title (title) | Long Text (4000) | |
| description (description) | Extra Long Text (64000) | summary; ample headroom, never truncated (§2.0); 1 of the ≤3 Extra-Long-Text budget |
| workstream (workstream) | Text | |
| position (position) | Integer | |
| version / createdBy / modifiedBy / createdAt / updatedAt | | |

### 2.5 `GH Story` — table `gh_story`
| field | type | notes |
|---|---|---|
| id | Integer | PK |
| syncUuid (sync_uuid) | Text | **unique** |
| featureSyncUuid (feature_sync_uuid) | Text | → `GH Feature.syncUuid` |
| epicSyncUuid (epic_sync_uuid) | Text | → `GH Epic.syncUuid` (nullable) |
| key (backlog_key) | Text | |
| title (title) | Long Text (4000) | |
| storyType (story_type) | Text | 'Story' | 'Task' |
| category (category) | Text | 'core' | 'nice-to-have' |
| appianPart (appian_part) | Text | |
| description (description) | Extra Long Text (64000) | summary; ample headroom, never truncated (§2.0); 1 of the ≤3 Extra-Long-Text budget |
| devNoteRef (dev_note_ref) | Long Text (4000) | one-line TD pointer |
| status (status) | Text | the board **lane** |
| position (position) | Integer | |
| ownerUsername / teamUuid | Text | visibility tags |
| version / createdBy / modifiedBy / createdAt / updatedAt | | |

> **`acceptanceCriteria`, `questions`, `labels` are NOT columns** on `GH Story` (each is a variable-length list
> that can exceed 4000 chars). They are **normalized into `GH Story Item`** child rows (§2.5b). Genesis sends
> them as **arrays** in the story upsert payload; the `GH_records_upsert` Web API **explodes** them into
> `GH Story Item` rows on write and **reassembles** them into arrays on read (36-04). The Genesis local model
> keeps its JSON columns unchanged.

### 2.5b `GH Story Item` — table `gh_story_item` (normalizes the story's variable-length lists — one row per item)
| field | type | notes |
|---|---|---|
| id | Integer | PK |
| syncUuid (sync_uuid) | Text | **unique** (child row id; client-generated by Genesis) |
| storySyncUuid (story_sync_uuid) | Text | → `GH Story.syncUuid` |
| itemType (item_type) | Text | 'ac' | 'question' | 'label' |
| text (text) | Extra Long Text (64000) | one AC line / question / label (Extra Long Text for headroom; 1 of the ≤3-per-record-type budget) |
| position (position) | Integer | order within its `itemType` |
| version / createdAt / updatedAt | | |
| **unique** (story_sync_uuid, item_type, position) | | |

> Written atomically **with** the parent story (not an independently-synced `kind`): `GH_records_upsert`
> for `kind='story'` replaces the story's `GH Story Item` rows (delete-for-story + insert current) in the same
> operation; `GH_records_get`/`GH_records_list` for `kind='story'` reassembles them into the
> `acceptance_criteria`/`questions`/`labels` arrays. The change log records a `'story'` change (children are an
> implementation detail of the story).

### 2.6 `GH Board State` — table `gh_board_state`
| field | type | notes |
|---|---|---|
| id | Integer | PK |
| syncUuid (sync_uuid) | Text | **unique** |
| appUuid (app_uuid) | Text | the board's application |
| storySyncUuid (story_sync_uuid) | Text | → `GH Story.syncUuid` |
| status (status) | Text | the lane (mirrors the story's status; the board projection) |
| version / modifiedBy / updatedAt | | |
| **unique** (app_uuid, story_sync_uuid) | | one board-state per story per app |

### 2.7 `GH Stage Artifact` — table `gh_stage_artifact`
| field | type | notes |
|---|---|---|
| id | Integer | PK |
| syncUuid (sync_uuid) | Text | **unique** |
| parentSyncUuid (parent_sync_uuid) | Text | the feature or story `syncUuid` |
| parentKind (parent_kind) | Text | 'feature' | 'story' |
| stage (stage) | Text | 'spec'|'ux_design'|'technical_design'|'breakdown'|'design'|… |
| status (status) | Text | draft→in-progress→in-review→completed |
| contentHash (content_hash) | Text | of the current artifact bytes |
| blobKey (blob_key) | Text | → `GH Blob Version.blobKey` (kind='artifact') |
| upstreamVersions (upstream_versions) | Long Text (4000) | small JSON, e.g. `{"spec":3}` (well within 4000) |
| publishedBy (published_by) | Text | |
| publishedAt (published_at) | DateTime | |
| version / createdAt / updatedAt | | |

### 2.8 `GH Blob Version` — table `gh_blob_version` (the queryable blob index; bytes live as Documents)
| field | type | notes |
|---|---|---|
| id | Integer | PK |
| blobKind (blob_kind) | Text | 'kb' | 'artifact' |
| blobKey (blob_key) | Text | 'kb' → the app_uuid; 'artifact' → `<parentSyncUuid>:<stage>` |
| version (version) | Integer | monotonic per (blobKind, blobKey) |
| contentHash (content_hash) | Text | for **dedup** (no new version if equal to latest) |
| documentId (document_id) | Integer | the Appian **Document** holding the bytes (Document ref) |
| size (size) | Integer | bytes |
| publishedBy (published_by) | Text | |
| createdAt (created_at) | DateTime | |
| **unique** (blob_kind, blob_key, version) | | |

### 2.9 `GH Change Log` — table `gh_change_log` (the append-only change manifest feed)
| field | type | notes |
|---|---|---|
| id | Integer | PK = the **cursor sequence** (monotonic; `/changes?cursor=` returns `id > cursor`) |
| kind (kind) | Text | 'team'|'membership'|'feature'|'epic'|'story'|'board_state'|'stage_artifact'|'blob' |
| syncUuid (sync_uuid) | Text | the changed record's `syncUuid` (or blobKey for 'blob') |
| version (version) | Integer | the record's new version |
| updatedAt (updated_at) | DateTime | |
| publishedBy (published_by) | Text | |

### 2.10 `GH Activity` — table `gh_activity` (advisory "in-progress by X" markers, TTL)
| field | type | notes |
|---|---|---|
| id | Integer | PK |
| kind (kind) | Text | the entity kind |
| syncUuid (sync_uuid) | Text | the entity being worked on |
| username (username) | Text | who claims it |
| setAt (set_at) | DateTime | |
| expiresAt (expires_at) | DateTime | TTL; `list` filters `expires_at > now()` |
| **unique** (kind, sync_uuid) | | one active marker per entity |

### 2.11 Relationships (both sides — skill: `relationship-patterns.md`)
Join on the `syncUuid` fields (not `id`): **GH Feature 1—* GH Epic** (`feature.syncUuid` ↔ `epic.featureSyncUuid`),
**GH Feature 1—* GH Story**, **GH Epic 1—* GH Story**, **GH Feature 1—* GH Stage Artifact** (parentKind='feature'),
**GH Story 1—* GH Stage Artifact** (parentKind='story'), **GH Story 1—* GH Story Item** (`story.syncUuid` ↔
`storyItem.storySyncUuid`), **GH Team 1—* GH Membership**. Each declared with the
MANY_TO_ONE **and** the ONE_TO_MANY reverse. (Relationships are for admin views/queryability; the APIs also work
via field filters — but declare both sides per the skill to avoid the one-sided-relationship failure mode.)

---

## 3. The frozen HTTP/JSON API contract

Checked into genesis at `specs/phase-36-genesis-hub-appian-app/contract/genesis-hub-api.md` (+ `contract/
fixtures/*.json`). All JSON; the **`GH` Web-API objects** implement these; the **service-account API-key header**
authenticates (all callers are the shared service account). **Attribution is taken from the request body**, not
Appian auth.

- `GET /meta` → `{contract_version, server_time}` (health + version check).
- `PUT /records/{kind}/{syncUuid}` — upsert (kinds: team, membership, feature, epic, story, board_state,
  stage_artifact). Body = the record payload + `base_version`. **CAS:** if `base_version != current.version` →
  **`409 {error:"conflict", current_version}`** (Genesis maps → `HubConflict` → notify-then-apply); else write,
  `version = base_version + 1`, set `modifiedBy` from the payload, **append a `GH Change Log` row**. `201` on
  create / `200` on update.
- `GET /records/{kind}?since=<cursor>&limit=<n>` → paginated `{records:[…], next_cursor}` (records changed since
  the cursor); `GET /records/{kind}/{syncUuid}` → the record or `404`.
- `POST /blobs/{kind}/{key}` — body = base64 payload + `content_hash` + `published_by` (kind: 'kb'|'artifact').
  **Dedup:** if `content_hash == latest.content_hash` → **`200 {status:"unchanged", version}`**; else store a new
  Appian **Document** (a new version of the per-key document) + insert a `GH Blob Version` row + **prune** beyond
  `GH_BLOB_KEEP_LAST_N` + append a 'blob' `GH Change Log` row → **`201 {status:"new", version}`**.
- `GET /blobs/{kind}/{key}` → the latest bytes (base64 + `content_hash` + `version`); `GET /blobs/{kind}/{key}/
  versions` → the version history metadata.
- `GET /changes?cursor=<n>&limit=` → `{changes:[{kind, sync_uuid, version, updated_at, published_by}],
  next_cursor, contract_version}` (rows from `GH Change Log` with `id > cursor`).
- `POST /activity` (body: kind, syncUuid, username, ttl_seconds) → upsert a `GH Activity` marker;
  `DELETE /activity/{kind}/{syncUuid}` → clear; `GET /activity/{kind}` → live markers (`expires_at > now`).
- **Errors:** uniform `{error, code}` envelope; status table `200/201/400/401/404/409/429`. **Auth:** the
  service-account API-key header; write verbs added to **allowed origins** (Appian CSRF exemption).
- **Note:** **team + membership are ordinary `kind`s on the generic records endpoints** (no dedicated `/teams`
  endpoints — simpler, fewer objects); Genesis's `SyncProvider.upsert_team`/`list_teams` map to
  `PUT/GET /records/team` + `/records/membership`.

The exact request/response JSON per endpoint + status codes + the 409/dedup bodies are the normative
`genesis-hub-api.md` + `fixtures/`, **shared** with Phase 37's provider tests (one source of truth).

---

## 4. Deliverables

1. This master reference (object inventory + full data model + relationships + the frozen contract).
2. `contract/genesis-hub-api.md` + `contract/fixtures/*.json` (normative shapes for every endpoint, incl. the
   409-CAS + 200/201-dedup bodies + the `contract_version`).
3. **ADR-064** (already drafted, Proposed, in `reference/decision-log.md`).
4. The dependency-ordered build plan (§1) the Dev-MCP agent executes in 36-02..36-05.

## Gate

⭐ User sign-off on the object inventory + data model + frozen contract → the Dev-MCP agent builds 36-02..36-05;
Phase 37's provider (37-01) codes against this contract.
