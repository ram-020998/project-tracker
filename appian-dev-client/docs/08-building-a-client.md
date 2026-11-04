# 08 — Building a Client

How to build an independent client against the plugin API — a script, or an Appian object.

## General principles

1. **Probe the version first.** `GET /meta` → branch on `version`. Treat `501` everywhere as
   "this build doesn't have that route" and fall back (e.g. `manifest`/`batch` → `/objects` +
   per-object GET).
2. **Enumerate, then read.** Lists give summaries (`uuid, name, description[, type]`); full
   bodies come from `GET /{collection}/{uuid}` or `POST /objects/batch`.
3. **Respect pagination.** Loop `offset` until `offset + len(items) >= total`.
4. **You get raw server JSON**, not the `appian-dev` YAML (no stripped UUIDs / display-form
   references). That's usually what you want. Replicating the YAML transform means porting the
   `roundtrip` logic — avoid unless you specifically need on-disk parity with `appian-dev`.
5. **Permissions = the account's.** Use an account that can see what you need; row security
   limits record data.

## Reference flow (older build, e.g. v26.6.110) — pseudo

```
meta      = GET /meta
app       = <appUuid>
objects   = []
offset    = 0
loop:
  page = GET /objects?appUuid={app}&limit=50&offset={offset}
  objects += page.items
  if offset + len(page.items) >= page.total: break
  offset += 50
for o in objects:
  collection = map(o.type)                 # DATA_STORE_ENTITY→constants, INTERFACE→interfaces, …
  body = GET /{collection}/{o.uuid}
  save(body)
```

Map the `type` returned by `/objects` to the collection path segment used by the per-object
read. Alternatively, skip the type mapping and iterate the per-type app-scoped lists
(`GET /applications/{app}/{type}`), where the collection is already known.

## Reference flow (newer build with batch) — pseudo

```
manifest = GET /applications/{app}/manifest        # {uuid, objectType, versionId, modifiedAt}[]
for chunk in chunks(manifest.items.uuids, 500):
  res = POST /objects/batch {"uuids": chunk, "includeSections": ["test-cases"]}
  for item in res.items:
     if item.status == "ok": save(item.object)
     else: log(item.uuid, item.message)
```

## curl examples (verified)

```bash
BASE="https://<host>/suite/plugins/servlet/stateless/lcp-api"
AUTH='-u <user>:<password>'

# 1. health
curl -sS $AUTH "$BASE/meta"

# 2. find the application uuid
curl -sS $AUTH "$BASE/applications"

# 3. enumerate one application's objects
curl -sS $AUTH "$BASE/objects?appUuid=<APP>&limit=50&offset=0"

# 4. filter to interfaces only
curl -sS $AUTH "$BASE/objects?appUuid=<APP>&types=interface&limit=50"

# 5. full object body
curl -sS $AUTH "$BASE/interfaces/<UUID>"

# 6. per-type app-scoped list (collection already known)
curl -sS $AUTH "$BASE/applications/<APP>/record-types?limit=50"
```

## Building it in Appian

**Terminology matters:**
- To **call** this plugin and pull data, build an **Integration** object (outbound) backed by
  an **HTTP Connected System**. That is the thing that fetches.
- A **Web API** in Appian is an *inbound* endpoint you expose. Only build one if you want to
  re-expose the fetched data as your own endpoint — and it would call the Integration internally.

**Connected System (HTTP):**
- Base URL: `https://<host>/suite/plugins/servlet/stateless/lcp-api`
- Authentication: **Basic**, username + password. Store the password as a secured field in the
  connected system (never inline in an expression).

**Integration objects (one per call you need):**
- "List objects" — `GET` `/objects`, query params `appUuid`, `types`, `limit`, `offset`.
- "Get interface" — `GET` `/interfaces/{uuid}` with `uuid` as a rule input.
- "List applications" — `GET` `/applications`.
- Model the response into a CDT/dictionary matching the schemas in doc 07.

**Pagination in Appian:**
- Read `total`, `limit`, `offset` from the envelope; iterate in a process model (loop) or a
  recursive expression rule accumulating `items` until exhausted.

**Auth note:** because it's `GET` + Basic, no CSRF handling is needed. (Only cookie-session
POST/PUT need `X-APPIAN-CSRF-TOKEN`.)

**Same-environment caveat:** if the Integration calls the plugin on the *same* Appian
environment it runs in, it still goes out over HTTP through the servlet and authenticates as the
configured account — so it sees what that account can see, which may differ from the running
user. Consider a dedicated service account.

## Upgrade consideration

If you'll pull whole applications regularly, the older per-object path is slow (one HTTP
request + ~700 ms auth CPU per object). Upgrading the plugin to the App-Market version
advertised by `/meta` (e.g. 26.9.10) adds `manifest` + `POST /objects/batch` (up to 500 objects
per request) and app-scoped bulk enumeration — a large throughput win.

## Suggested next steps for this project

- [ ] Decide client form: standalone script (Python/Go) vs. Appian Integration vs. both.
- [ ] Generate a trimmed OpenAPI spec limited to the deployed build's routes (import into the
      client generator / Appian).
- [ ] Build the enumerate→read loop with 501 fallback.
- [ ] Add a `type → collection` mapping table (from `/objects.type` to the GET path segment).
- [ ] Decide whether raw JSON is enough or the `roundtrip` YAML transform is needed.
