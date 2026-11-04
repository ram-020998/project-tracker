# 06 — API Reference (overview, auth, conventions)

This is the overview. Per-endpoint detail is in [`07-endpoint-contracts.md`](07-endpoint-contracts.md).

## Base URL

```
https://{environment-host}/suite/plugins/servlet/stateless/lcp-api
```

Example (investigation env):
`https://merge-assist-dev.appianpreview.com/suite/plugins/servlet/stateless/lcp-api`

From the OpenAPI spec (`openapi/lcp/lcp-api-via-plugin`, title "LCP API Plugin", v1.0.77):

```yaml
servers:
- url: https://{environment}/suite/plugins/servlet/stateless/lcp-api
```

## Authentication

Two mechanisms; the servlet's Spring Security chain accepts either because `/plugins/servlet`
is not a path that forbids Basic:

1. **HTTP Basic** — an Appian-native username/password. Simplest; GETs just work.
   ```
   Authorization: Basic base64(user:password)
   ```
2. **Session cookie + CSRF** — a browser-captured session (SSO sites). Send `Cookie:` plus
   `X-APPIAN-CSRF-TOKEN`. **A POST/PUT with no `X-APPIAN-CSRF-TOKEN` returns 401 even with a
   valid cookie.** GETs do not need the CSRF header.

The call always runs as the authenticated user, so results are limited by that account's
object visibility and record row security.

## Conventions

### Pagination (list endpoints)

Query params `limit` and `offset`. Response envelope:

```json
{ "items": [ ... ], "total": 637, "limit": 50, "offset": 0 }
```

- Default `limit` is 50 when omitted or non-positive.
- Oversized limits are bounded to a server max (not rejected) on `/objects`; the dedicated
  bulk route `POST /objects/batch` caps at **500** and rejects over-limit requests.
- Loop: keep requesting until `offset + len(items) >= total`.

### Full-object reads

`GET /{collection}/{uuid}` → the full object. Every body carries:
- `versionId` — optimistic-concurrency / drift token (Web APIs carry none).
- `_rest` — a passthrough object holding fields not explicitly mapped (e.g. the designer `url`).

### Content versioning

Content-backed reads accept an optional `?version=` (defaults to current). Web APIs support
`?version=` via a historical-version lookup.

### Errors

```json
{ "error": "human-readable message" }
```

with the HTTP status:

| Status | Meaning |
|---|---|
| 400 | bad request (missing/invalid params, malformed JSON, batch > 500) |
| 401 | credentials rejected, or POST/PUT with no CSRF token on a cookie session |
| 403 | not found / access denied (also used for unknown application UUID on scoped routes) |
| 404 | object not found |
| 412 | (session case) missing CSRF cookie |
| 501 | **route not implemented by this plugin version** — the single most important one to handle |

### Version-sensitivity

The deployed plugin version decides which routes exist. Always call `GET /meta` first and
treat `501` as "feature absent on this build." See
[`09-live-environment-findings.md`](09-live-environment-findings.md) for the matrix observed on
v26.6.110 vs. what newer builds add (`manifest`, `objects/batch`, etc.).

## Collection path segments

The `{collection}` segment used in `GET /{collection}` and `GET /{collection}/{uuid}`:

```
applications  constants  expression-rules  interfaces  record-types  process-models
sites  portals  web-apis  groups  users  documents  folders  translation-sets
integrations  connected-systems  connected-system-types  data-stores  data-sources
decisions  tempo-reports  task-reports  deployments  objects
```

Record-type and process-model have sub-resource routes; see the contracts doc.

## Recommended "get all objects of an application" flow

**Newer plugins (have manifest + batch):**
```
GET  /applications/{app}/manifest            → list of {uuid, objectType, versionId, modifiedAt}
POST /objects/batch  {"uuids":[...≤500...]}  → bodies (chunk the uuids)
```

**Older plugins (e.g. v26.6.110):**
```
GET /objects?appUuid={app}&limit=50&offset=0   → {uuid,name,description,type,...}; paginate
GET /{collection}/{uuid}                        → full body per object
```
(or the per-type app-scoped lists `GET /applications/{app}/{type}`).

## Quick smoke test

```bash
BASE="https://<host>/suite/plugins/servlet/stateless/lcp-api"
curl -sS -u "<user>:<password>" "$BASE/meta"
```
A `200` with `{name, version, ...}` confirms the plugin is installed and the credentials work.
