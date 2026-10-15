# Genesis Hub API — Spec Change Request & Story Traceability addition (ADR-075/076, Phase 46-09)

> **BUILD STATUS:** 🟡 **BUILT + LIVE-VALIDATED on the dev-env Hub (2026-10-15) — 38/41, ONE OPEN ITEM.** Both changes
> are live on the existing generic endpoints. The story arrays (§2) are **fully green**: every `story_with_trace.json`
> step matches byte-for-byte, absent keys keep their rows, `spec_refs: []` clears, the stale write gets a 409
> (`current_version: 2`), `/changes` shows one row per upsert, and list carries the keys. `spec_change_request`
> (§3) works for create 201 / update 200 / stale 409 / `/changes` / list, **`result_revision_no` reads back `null`**
> on a discarded CR, and the blob at `…:cr-03` is 201 new → 200 unchanged → identical bytes and hash. A ~1 MB
> document is lossless, and `ttl_seconds: 86400` is accepted. All 9 existing kinds still round-trip,
> `contract_version` is `1.0.0`, and unauthenticated calls get 401.
> **⚠️ OPEN:** `opened_at` / `closed_at` do **not** come back as the exact strings yet. The Web API parses the body
> with `a!fromJson`, which turns any ISO date/datetime-looking string into a datetime *before* the rules see it.
> That datetime is UTC, and sub-second digits are lost. The rules now return ISO-8601 UTC (e.g. `.123456+00:00` →
> `2026-10-14T10:00:00.120Z`). For the exact strings, `GH_records_upsert` must also pass the raw body:
> `rawBody: http!request.body` in its `rule!GH_casUpsert(…)` call. That would be a **second Web API edit** and
> needs owner approval; the rule side is already built and tested. As-built: record type **GH Spec Change
> Request** `a0fc6f95-aa70-4ad8-9ffd-a609d3198a84` (table `GH_SPEC_CHANGE_REQUEST`). Rules: `GH_casUpsert` v12,
> `GH_recordToJson` v5, `GH_queryRecords` v5, `GH_reassembleStoryItems` v3, and a new `GH_payloadText`
> `_a-0000f08d-249e-8000-9c33-011c48011c48_30039` (v6). Web API edit: `"spec_change_request"` appended to
> `GH_records_upsert`'s inline kind list, done in Designer. **Genesis must know:**
> - Null `title` / `summary` read back as `""`; the fixture's `summary: null` comes back as `""`.
> - An **absent** `acceptance_criteria` / `questions` / `labels` key clears that type. This is the existing,
>   unchanged behaviour, so always send the three.
> - An explicit JSON `null` on a new key clears that type, the same as `[]`.
>
> Full record: `progress/phase-36-genesis-hub-appian-app.md` § "SPEC CHANGE REQUEST ADDITION".
>
> **Status:** 🟢 FROZEN ADDITION to the v1.0.0 contract — **additive, backward-compatible** (ADR-064 amendment, like
> the v0.69.0 `on_board` field and the Phase-42 Object Wiki addition). Two changes:
> 1. **`story`** gains three arrays — `spec_refs`, `answers`, `change_log` — normalized into **`GH Story Item`** rows
>    with three new `item_type` values (§2).
> 2. A **new record kind `spec_change_request`** (record type **`GH Spec Change Request`**) served by the **existing
>    generic** `/records/{kind}` + `/changes` endpoints, with its frozen document in the **existing** artifact blob
>    store (§3).
>
> **No new Web API object.** The only Web API edit allowed is appending `"spec_change_request"` to the inline kind
> allow-list in `GH_records_upsert` (the same additive edit the Object Wiki needed). Genesis stays read-only against
> Appian (ADR-036/037); the genesis-side bindings are built in parallel (46-09 §2) against a strict local emulator.
>
> **Lossless sync is the hard invariant** (36-01 §2.0): `local → PUT → Hub → GET → local` reproduces every field
> byte-for-byte (unicode, ordering, empty-vs-null, exact timestamp strings). Fixtures:
> `./fixtures/story_with_trace.json`, `./fixtures/spec_change_request.json`.

---

## 1. Why (one paragraph)

Phase 46 makes a finalized feature's spec change only through numbered **change requests** (CR-01, CR-02 …). Each
story records which spec clauses it implements (`spec_refs`), answers to its open questions (`answers`) and a
history of what each CR did to it (`change_log`). Applying a CR updates stories in one transaction; teammates must
see the updated stories, the CR in the feature's change-request list, and the CR's frozen "Impact Analysis"
document. Open CRs are **not** published (they are local to the owner until Apply/Discard); a teammate only sees
an advisory "Spec under change by <name>" marker via the existing activity API (§4 — no Hub change).

---

## 2. Change 1 — `story`: three new arrays via `GH Story Item`

### 2.1 Wire shape

The `story` record (both directions) gains three keys, each an **array of strings**, exactly like
`acceptance_criteria` / `questions` / `labels`:

| Key | `item_type` value | Element (a string) |
|---|---|---|
| `spec_refs` | `spec_ref` | compact JSON of one link, e.g. `{"clause_id":"c-1a2b3c4d","fingerprint":"9f2c8e1a7b3d4c5e","origin":"breakdown","linked_at":"2026-10-14T10:00:00.123456+00:00"}` |
| `answers` | `answer` | compact JSON of one answer, e.g. `{"question":"Is fifty the max?","answer":"Yes","answered_by":"ram","answered_at":"…","source":"cr","cr_no":3}` |
| `change_log` | `change` | compact JSON of one history entry (cr_no, decision, summary ≤ 500, clause labels/ids, fields, at, by, follow-ups …) |

**The Hub treats every element as an opaque string.** It never parses, validates, re-orders, trims or re-encodes
it. Genesis serializes with `json.dumps(obj, separators=(",", ":"), ensure_ascii=False)` and parses back on pull;
elements contain unicode, quotes, backslashes and `\n` escapes, all of which must survive byte-for-byte.

**Sizes:** genesis caps every element at **4,000 characters serialized** before publishing (answers ≤ 3,000, change
summaries ≤ 500 inside). `GH Story Item.text` is already Extra Long Text (64,000), so **no field change is needed**
— remember the limit is in bytes, and multibyte characters count more than 1.

### 2.2 Write semantics (`GH_records_upsert(kind='story')` → `GH_casUpsert` story branch)

- `item_type` ∈ `ac | question | label` becomes **`ac | question | label | spec_ref | answer | change`**. If the
  `itemType` field or any rule constrains the values (a constant list, a validation, a check), extend it.
- **Present key → replace that type's rows** (one row per element, `position` = array index), atomically with the
  story write, exactly like the existing three. **An empty array clears** that type's rows (zero rows).
- **ABSENT key → leave that type's existing rows untouched.** This is the backward-compatibility rule for mixed
  teams: a teammate on an older Genesis (which never sends these keys) editing a story's title must **not** wipe
  its spec links, answers or history. ⚠️ Check how the current story branch treats an absent
  `acceptance_criteria` / `questions` / `labels` and **do not change that behaviour** for the existing three; apply
  the absent-key-preserves rule to the three new types only (and report what the existing behaviour is).
- `version` / CAS / change-log row: unchanged (one story upsert = one version bump + one `GH Change Log` row).

### 2.3 Read semantics (`GH_recordToJson` story branch / `GH_reassembleStoryItems`)

- The story JSON **always** includes `spec_refs`, `answers` and `change_log`, each position-ordered, **`[]` when
  there are no rows** (same as `questions: []` today). Old Genesis versions ignore unknown keys (verified: the
  genesis puller keeps only keys that are local columns).
- Get and list (`GH_queryRecords`) both return them (the reassembly is in `GH_recordToJson`, so both paths get it).

---

## 3. Change 2 — new record kind `spec_change_request`

### 3.1 Record type `GH Spec Change Request` (DATABASE `jdbc/Appian`, PK `id` INTEGER, `syncUuid` unique)

| Wire key | Appian field | Type / tier | Notes |
|---|---|---|---|
| `sync_uuid` | `syncUuid` | Text 255, unique | the record key |
| `feature_sync_uuid` | `featureSyncUuid` | Text 255 | parent feature (a plain shared column, like `story.feature_sync_uuid`) |
| `cr_no` | `crNo` | Integer | 1, 2, 3 … (unique per feature in practice; no Hub constraint needed) |
| `title` | `title` | Text 4000 | nullable (null reads back as `""` — established behaviour) |
| `status` | `status` | Text 255 | `applied` \| `discarded` (open CRs are never published) |
| `mode` | `mode` | Text 255 | `stories` \| `backlog` |
| `opened_by` | `openedBy` | Text 255 | username |
| `opened_at` | `openedAt` | **Text 255** | **payload-preserved string** (e.g. `2026-10-14T10:00:00.123456+00:00`) — not a Date-time, so it round-trips byte-for-byte |
| `closed_by` | `closedBy` | Text 255 | |
| `closed_at` | `closedAt` | **Text 255** | payload-preserved string |
| `base_revision_no` | `baseRevisionNo` | Integer | the spec revision the CR started from |
| `base_content_hash` | `baseContentHash` | Text 255 | sha-256 hex of that revision (a puller needs it: the local column is NOT NULL) |
| `result_revision_no` | `resultRevisionNo` | Integer | the revision Apply produced; **null when discarded** |
| `summary` | `summary` | Long Text 4000 | a small JSON object as text (counts + one-line summary), opaque to the Hub |
| `blob_key` | `blobKey` | Text 255 | `<feature_sync_uuid>:cr-<nn>` (e.g. `…:cr-03`) — the frozen document |
| `content_hash` | `contentHash` | Text 255 | sha-256 hex of the document bytes |
| `published_by` | `publishedBy` | Text 255 | `coalesce(payload.published_by, actor)` (stage_artifact model) |
| `published_at` | `publishedAt` | Text 255 / as stage_artifact | `coalesce(payload.published_at, now())` — mirror whatever `stage_artifact` does |
| `version` | `version` | Integer | server-managed CAS counter |
| `created_at`, `updated_at` | `createdAt`, `updatedAt` | as other kinds | server-managed |

Zero Extra-Long fields. Integer nulls (`result_revision_no` on a discarded CR) must read back as **`null`**, not
`0` — if Appian can't return null for an Integer here, report it (genesis can tolerate `0` only if documented).

- **Relationship (optional but recommended):** `GH Spec Change Request.feature` MANY_TO_ONE → `GH Feature` on
  `featureSyncUuid` → `syncUuid`, and the inverse ONE_TO_MANY on `GH Feature` (`changeRequests`). Not cascading
  unless features already cascade to their stage artifacts — mirror `GH Stage Artifact`.
- **Security:** mirror `GH Stage Artifact` / the Object Wiki types (administrator + editor = `GH Administrators`,
  viewer = `GH Users`, data steward = `GH Service Accounts`); associate with the app.

### 3.2 Rules (additive kind-branches before `default`; existing branches untouched)

- **`GH_records_upsert`** Web API inline kind allow-list: append `"spec_change_request"` (the one allowed Web API
  edit; in Designer if MCP can't edit the Web API body, as for the Object Wiki).
- **`GH_casUpsert`**: a `spec_change_request` branch — stage_artifact-shaped attribution (publishedBy/publishedAt
  from the payload, updatedAt = now, createdAt = coalesce(existing, now())), `version = coalesce(base, -1) + 1`,
  **409 CAS** on a stale `base_version`, a `GH Change Log` row in the same `a!writeRecords` batch.
- **`GH_recordToJson`**: a `spec_change_request` projection with exactly the 20 keys of §3.1 (snake_case).
- **`GH_queryRecords`**: get (by syncUuid) + list branches, all projected fields.
- `GH_changesSince` / `/changes`: must emit `kind: "spec_change_request"` rows (no change expected — it's generic).

### 3.3 The frozen document (blob)

- `POST /blobs/artifact/<feature_sync_uuid>:cr-<nn>` with the existing body (`base64`, `content_hash`,
  `published_by`) — the existing artifact blob store, dedup + versions + prune, **no change expected**.
  ⚠️ Verify the blob Web APIs / rules don't validate the key's suffix against the stage names (`spec`,
  `ux_design`, …). If they do, extend that list with the `cr-<nn>` pattern additively and report it.
- Documents are small self-contained HTML (tens of KB; the harness should also try ~1 MB).

---

## 4. Advisory marker — no Hub change

Genesis calls the existing `POST /activity` with `{kind: "stage_artifact", sync_uuid: <the spec stage's sync_uuid>,
username, ttl_seconds: 86400}` on Initiate, again on every Analyze, and `DELETE /activity/stage_artifact/<uuid>` on
Apply/Discard. Please just confirm a 24-hour `ttl_seconds` is accepted (no upper bound).

---

## 5. Acceptance — extend the 36-06 harness

All against the dev-env Hub as the service account, then clean up the validation rows:

1. **`story_with_trace.json`** — the step sequence in the fixture:
   - step 1 PUT with all six arrays (unicode, quotes/backslashes/newline escapes inside elements, an empty
     `questions`) → GET reproduces every array byte-for-byte and in order;
   - step 2 PUT **without** the three new keys (an "old Genesis" edit of the title) → GET still returns step 1's
     `spec_refs` / `answers` / `change_log` unchanged;
   - step 3 PUT with `change_log` present and `spec_refs: []` → `spec_refs` is `[]`, `answers` unchanged,
     `change_log` replaced;
   - CAS 409 on a stale `base_version`; `/changes` shows one row per upsert.
2. **`spec_change_request.json`** — applied CR: PUT create → 201, GET byte-for-byte (timestamps exact,
   `summary` text exact); PUT update with `base_version` → 200; stale → 409; a discarded CR with
   `result_revision_no: null` reads back `null`; `/changes` emits the kind; the blob PUT (201) / re-PUT (200
   unchanged) / GET (bytes + hash) at `…:cr-03`.
3. **Regression:** every existing kind still passes (story's three original arrays incl. empty `[]`,
   stage_artifact, the Object Wiki kinds), `contract_version` still `1.0.0`, unauthenticated → 401.

Record the as-built (record type + field UUIDs, rule versions, the Web API edit, harness N/N, any deviation) in
`progress/phase-36-genesis-hub-appian-app.md` (a new "SPEC CHANGE REQUEST ADDITION" section) and replace the
BUILD STATUS line above.
