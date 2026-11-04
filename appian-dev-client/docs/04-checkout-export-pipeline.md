# 04 — Checkout / Export Pipeline (environment → YAML)

How `appian-dev checkout` pulls an application out of an environment and writes it to disk.
This is the end-to-end flow; the environment-internal half is in doc 05.

## One-line shape

```
appian-dev checkout -app <uuid>                 (CLI — thin client)
  └─ POST /api/branches/{name}/checkout?stream=1 → local Go server (devmcp-local)
       └─ branch.CheckoutWithOptions()           → orchestrates
            ├─ plugin.Client → HTTP → Appian Java plugin servlet (reads JSON)
            ├─ roundtrip     → JSON → stable YAML
            └─ writes {collection}/{name}.yaml  +  .devmcp/merge-base/  +  .devmcp/sync.json
```

The CLI holds no credentials. It posts to the **running local server** because the
session/password live only in that server's memory (`checkout/fromenv.go`). The server
streams NDJSON back: one `{"progress"}` line per object, then one terminal `{"result"}`
(decoded with a streaming JSON decoder, not a line scanner — the terminal line for a
1,300-object app exceeds a 64 KB scanner limit).

## Step 1 — Enumerate the application

Server asks the plugin for the application's object list. On newer plugins this is the
**manifest**:

```
GET /applications/{appUuid}/manifest   → one {uuid, objectType, versionId, modifiedAt} per object
```

`branch.EnumerateForCheckout` → a list of `ObjectRef{Type, UUID, Name}`, written to
`.devmcp/enumeration.json` *before the first object* (so later reference resolution and the
graph know every object the app contains, even ones no file is written for).

> On plugins too old for `manifest` (e.g. v26.6.110), enumeration uses `GET /objects?appUuid=…`
> or the per-type app-scoped list routes instead. See doc 09.

## Step 2 — Fetch each object from the plugin

`plugin.Client` is an HTTP client against the Java plugin servlet, authenticated with Basic
auth **or** an adopted cookie session. Checkout uses only the read-only subset
(`roundtrip.Getter`):

- **Single object:** `GetObject(collection, uuid, query)` → `GET {collection}/{uuid}` → object JSON verbatim.
- **Composite objects** (record types, sites…): extra `GetSubCollection(collection, uuid, path)`
  calls (e.g. `GET record-types/{uuid}/views`), assembled into one object.
- **Batching (normal path):** `GetObjectBatch(uuids, sections)` → `POST /objects/batch`, up to
  **500 full objects per request** (`MaxBatchSize`), chunked and ramped; falls back to per-object
  `fetchOne` on retry. A batched object is built through the *same* converter as a single fetch,
  so the on-disk bytes are byte-identical either way.

Read options default to including **test cases** and **security**, degrading gracefully
(`ErrTestCasesDisabled`) if the deployment has them off, reported once rather than per object.

### Sections

`includeSections` on the batch request carries sub-resources cheaply as siblings of `object`:
- `test-cases` — interfaces and expression rules
- `fields`, `views`, `actions`, `user-filters` — record types
Unknown section names are rejected (so a misspelling can't be read as "no test cases").

## Step 3 — Convert server JSON → stable YAML (`roundtrip`)

`roundtrip/convert.go`:
- `fromGetType` decodes JSON → `Object{Type, Fields}`, dropping **transient** fields, the
  type's `DropOnRead` keys, and Any-Type placeholders (so reads are symmetric).
- `Object.MarshalYAML()` produces deterministic YAML: sorted keys, literal block scalars for
  multi-line expressions, a caveat comment header for not-fully-representable kinds.
- `StableYAML` = `MarshalYAML` minus volatile fields (e.g. folder `modifiedAt`), used for drift
  comparison.
- References rewritten to display form; server-minted identities stripped (restored from the
  merge base on read).

## Step 4 — Write three things to disk

In the `branch.CheckoutWithOptions` loop (`branch/branch.go`), per object:

1. **Object file** → `{dir}/{collection}/{fileName}.yaml`. `collection` = `record-types`,
   `expression-rules`, `constants`, `process-models`, `sites`, `groups`, `folders`,
   `translation-sets`, `applications`, … File name from the object's own name, de-duplicated
   by `claimFileName` (UUID-derived fallback).
2. **Merge base** → `writeMergeBase` copies the *same bytes* to `.devmcp/merge-base/<path>` —
   the byte-for-byte "as checked out" ancestor. Anchors three-way merge and restores stripped UUIDs.
3. **Sync record** → a `syncEntry` per object → `.devmcp/sync.json`: `versionId`, `versionUuid`,
   `diffHash`, `sha256`.

A merge-base/sync write failure does not skip the object; it is reported as a degraded
comparison, never silently.

## Step 5 — Optional data passes

- `-runtime-data` → record rows via `GetRecordData` → `data/default/rows/<recordTypeUuid>.csv`,
  read through row security as the signed-in account (reported explicitly, since a secured
  0-row table looks like an empty one).
- `-sync-users` → users/groups/memberships into the local directory.

## Net result

The working tree is what the agent edits; the `.devmcp/merge-base/` copy + `sync.json` tokens
are what make every later diff, drift check, and three-way merge possible offline. **That dual
write is the key design point.**

## Implication for our client

If you call `POST /objects/batch` (or the per-object GETs) directly, you get the **raw server
JSON** — identical to what `appian-dev` consumes. You do **not** automatically get the
stripped/display-form YAML; that transformation is the client-side `roundtrip` logic. For most
"pull the data out" use cases the raw JSON is exactly what you want.
