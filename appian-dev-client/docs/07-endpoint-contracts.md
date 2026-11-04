# 07 — Endpoint Contracts

Detailed per-endpoint contracts for the LCP API plugin. Base URL, auth, pagination, and error
conventions are in [`06-api-reference.md`](06-api-reference.md) — not repeated per endpoint.

Legend for availability:
- **all** — present on both the deployed v26.6.110 and newer builds (verified live where noted)
- **new** — present in newer builds only; returns `501` on v26.6.110
- Routes are relative to `…/suite/plugins/servlet/stateless/lcp-api`.

---

## 0. Meta / health

### `GET /meta` — **all**
Plugin self-description. No params.

Response:
```json
{
  "name": "Appian Dev MCP",
  "version": "26.6.110",
  "key": "com.appiancorp.plugins.lcp.api.retrofit",
  "buildTimestamp": "20261008-132401",
  "pluginSrcSha": "170a2df53ede42d4",
  "composerCommit": "…", "composerBranch": "detached",
  "mcpSrcSha": "…", "aeCommit": "…",
  "appMarket": { "status": "UPDATE_AVAILABLE", "latestVersion": "26.9.10", "downloadLink": "…" }
}
```

### `GET /environment` — **new** (501 on v26.6.110)
Environment capabilities (data sources, functions, smart services, plugins).

---

## 1. Applications

### `GET /applications` — **all**
List all applications visible to the caller.

Response:
```json
{
  "items": [
    { "uuid": "_a-0000e5bc-…_930416", "name": "AS GSS Full Application",
      "description": "FOR DEPLOYMENT USE ONLY: …", "prefix": "", "urlIdentifier": "jKKAjg" }
  ]
}
```

### `GET /applications/{appUuid}` — **all**
Application metadata only (no object list on v26.6.110).
```json
{ "prefix": "", "name": "…", "description": "…", "urlIdentifier": "…",
  "defaultObjects": {}, "uuid": "_a-…" }
```

### `GET /applications/{appUuid}/{type}` — **mostly all**
Per-type, app-scoped object lists. `{type}` ∈:
`constants, expression-rules, interfaces, record-types, process-models, sites, web-apis,
groups, folders, documents, portals, integrations, connected-systems, data-stores, agents,
ai-skills, robotic-tasks` → **all** (verified 200 on v26.6.110).
`data-types, translation-sets` → **new** (501 on v26.6.110).

Params: `limit`, `offset`. Response: standard list envelope with summary items
(`{uuid, name, description, ...}`).

### `GET /applications/{appUuid}/manifest` — **new** (501 on v26.6.110)
The bulk-download enumerator. One entry per object:
```json
{ "items": [ { "uuid": "…", "objectType": "…", "versionId": "…", "modifiedAt": "…" } ],
  "total": N, "limit": 50, "offset": 0 }
```

### `GET /applications/{appUuid}/graph` — **new**
Raw dependency graph (`nodes[] + edges[]`) from `DesignObjectSearchService`.

### Application writes — **all/new**, destructive
`POST /applications`, `PUT /applications/{appUuid}`,
`PUT /applications/{appUuid}/objects` (add), `DELETE /applications/{appUuid}/objects` (remove).

---

## 2. Generic object enumeration & cross-object

### `GET /objects` — **all** (verified)
The most useful single enumerator on older builds. Query params:

| Param | Meaning |
|---|---|
| `appUuid` | scope to one application (verified: `appUuid` works; `application`/`applicationUuid` are ignored → site-wide) |
| `types` | CSV of object types to include (e.g. `interface`) |
| `query` | name/text search |
| `lastModifiedBy` | CSV of usernames |
| `lastModifiedFrom`, `lastModifiedTo` | date range |
| `limit`, `offset` | pagination |

Response item:
```json
{ "uuid": "_a-…_940763", "name": "AS_GSS_QE_getEvaluation",
  "description": "…", "type": "…", "lastModifiedBy": "…",
  "lastModifiedOn": "…", "url": "https://…/suite/design/…" }
```
Observed scoping on the test app: no filter → `total` 10298 (site-wide); `appUuid` → 2767;
`appUuid` + `types=interface` → 528.

### `GET /objects/{uuid}/security` — **all**
Object role map / security.

### `GET /objects/{uuid}/versions` — **all**
Version history for one object.

### `POST /objects/versions` — **new**
Batch version history.

### `GET /objects/dependents?...` / `POST /objects/dependents` — **new/varies**
Dependents by query / batch.

### `POST /objects/batch` — **new** (501 on v26.6.110)
Bulk body fetch — the efficient path. Request:
```json
{ "uuids": ["…", "…"], "includeSections": ["test-cases"] }
```
- `uuids`: 1..500 (over 500 → 400). Deduped, request order preserved.
- `includeSections` (optional): `test-cases` (interfaces, expression rules);
  `fields`, `views`, `actions`, `user-filters` (record types); `security`.
  Unknown section name → 400.

Response (one item per distinct uuid, keyed by uuid, **not** by position):
```json
{ "items": [ { "uuid": "…", "objectType": "…", "status": "ok",
               "object": { … full object … } },
             { "uuid": "…", "objectType": "…", "status": "error", "message": "…" } ],
  "total": N, "errors": [] }
```
`object` JSON is identical to the single-object GET (minus designer-URL enrichment).

---

## 3. Design objects — full reads

All of the form `GET /{collection}/{uuid}` → full body. Each carries `versionId` and `_rest`.
Global list form `GET /{collection}?limit=&offset=` returns summary items `{uuid, name, description}`.

### Constants — `GET /constants`, `GET /constants/{uuid}` — **all**
```json
{ "uuid": "_a-…_930488", "name": "AS_GSS_ENT_R_DATA", "description": "Value: AS_GSS_R_Data",
  "type": "DATA_STORE_ENTITY", "value": "79819fd1-…@1966", "multiple": false,
  "versionId": "1", "_rest": { "url": "https://…/suite/design/…" } }
```
Summary items also expose `type`, `value`, `multiple`.

### Expression rules — `GET /expression-rules`, `GET /expression-rules/{uuid}` — **all**
```json
{ "uuid": "_a-…_935192", "name": "AS_GSS_QE_getRefDataByTypes",
  "description": "Returns a list of reference data by the type",
  "expression": "rule!AS_CO_UT_queryEntity(\n  entity: cons!AS_GSS_ENT_R_DATA, …)",
  "inputs": [ { "name": "refTypes", "type": "Text", "multiple": true },
              { "name": "refDataIds", "type": "Number (Integer)", "multiple": true } ],
  "versionId": "1", "_rest": { "url": "…" } }
```
Sub-resources: `/expression-rules/{uuid}/test-cases`, `/…/test-cases/{testCaseUuid}`.

### Interfaces — `GET /interfaces`, `GET /interfaces/{uuid}` — **all**
Same shape as expression rules:
```json
{ "uuid": "…", "name": "AS_GSS_FM_evaluationSummary", "description": "…",
  "expression": "a!…", "inputs": [ … ], "versionId": "…", "_rest": { … } }
```
Sub-resources: `/interfaces/{uuid}/test-cases`, `/…/test-cases/{testCaseUuid}`.

### Record types — `GET /record-types`, `GET /record-types/{uuid}` — **all**
```json
{ "uuid": "…", "name": "ADG_Application", "pluralName": "ADG Applications",
  "description": "…", "sourceType": "…", "dataSourceName": "…", "tableName": "…",
  "typeReference": "…", "fields": [ … ], "relationships": [ … ], "listColumns": [ … ],
  "hasRecordEvents": false, "hideNewsView": …, "hideRelatedActionsView": …,
  "versionId": "…", "_rest": { … } }
```
Sub-resources (**all** unless noted):
`/record-types/{uuid}/fields`, `/fields/{fieldName}`, `/relationships`, `/actions`,
`/views`, `/user-filters`, `/events`, `/data` (record rows).

### Process models — `GET /process-models`, `GET /process-models/{uuid}` — **all**
```json
{ "uuid": "…", "name": "…", "description": "…", "creator": "…",
  "parentFolderUuid": "…", "nodes": [ … ], "processVariables": [ … ], "lanes": [ … ],
  "versionId": "…", "_rest": { … } }
```
Sub-resources: `/process-models/{uuid}/nodes`, `/nodes/{nodeId}`, `/processes`, `/history`;
schema helpers `/process-models/node-types`, `/node-types/{type}`; folders
`/process-model-folders`.

### Sites — `GET /sites`, `GET /sites/{uuid}` — **all**
```json
{ "uuid": "…", "name": "…", "displayName": "…", "webAddressIdentifier": "…",
  "description": "…", "layout": "…", "pages": [ … ], "versionId": "…", "_rest": { … } }
```

### Web APIs — `GET /web-apis`, `GET /web-apis/{uuid}` — **all**
`{ uuid, name, description, expression, inputs, versionId, _rest }`. Optional `?version=`.

### Other design objects (**all** unless noted)
- `GET /folders`, `GET /folders/{uuid}`, `GET /folders/{uuid}/contents`
- `GET /documents`, `GET /documents/{uuid}`, `GET /documents/{uuid}/content`, `/text`
- `GET /portals`, `GET /portals/{uuid}`
- `GET /integrations`, `GET /integrations/{uuid}`, `GET /applications/{app}/integrations`
- `GET /connected-systems`, `GET /connected-systems/{uuid}`, `GET /connected-system-types`, `/{typeId}`
- `GET /data-stores`, `GET /data-stores/{uuid}`
- `GET /data-sources`, `GET /data-sources/tables`, `/tables/columns`
- `GET /custom-data-types`, `/by-reference`; `GET /data-types` (**new**)
- `GET /decisions/{uuid}` (**new** — DMPD-423 added decision tables)
- `GET /tempo-reports`, `/{uuid}`; `GET /task-reports`, `/{uuid}`
- `GET /translation-sets` (**new**), `/{uuid}`, `/{uuid}/strings`, `/translation-locales`

### Groups / users (**all** except users)
- `GET /groups`, `GET /groups/{uuid}`, `GET /groups/{uuid}/members`
- `GET /users` — **new** (501 on v26.6.110)

---

## 4. Validation / quality / expressions (mostly **new**)

- `POST /expressions/validate` — validate an expression
- `POST /expressions/evaluate`, `/evaluate-batch`, `/evaluate-k` — evaluate expression(s)
- `POST /objects/{uuid}/validate`
- `GET /quality/design-guidance`, `/static-checks`, `/validate` — **new** (501 on v26.6.110)

---

## 5. Write / lifecycle endpoints (destructive — not needed for a read client)

Documented for completeness; **do not call from a read-only data client.** All `POST`/`PUT`/
`DELETE` need CSRF when using a cookie session.

- Create: `POST /{constants|expression-rules|interfaces|record-types|sites|portals|
  process-models|web-apis|folders|groups|users|documents|decisions|data-stores|
  connected-systems|integrations|tempo-reports|task-reports|translation-sets|applications}`
- Update: `PUT /{collection}/{uuid}` (+ record-type sub-resource PUTs:
  `/record-types/{uuid}/{source|relationships/{relUuid}|fields/{fieldUuid}|actions/{actionUuid}|
  views/{urlStub}|views/reorder|data|user-filters/{filterUuid}|custom-fields/{fieldUuid}}`)
- Delete: `DELETE /record-types/{uuid}/custom-fields/{fieldUuid}`,
  `DELETE /applications/{appUuid}/objects`
- Record-type sub-resource creates: `POST /record-types/{uuid}/{fields|custom-fields|
  relationships|actions|views|user-filters|events|data}`
- Security: `PUT /objects/{uuid}/security`
- Documents: `POST /documents` (upload), `PUT /documents/{uuid}/content` (replace),
  `POST /document-content-zip`
- Portals: `POST /portals/{uuid}/publish`, `/unpublish`
- Deployments: `POST /deployments`, `POST /deployments/{uuid}/complete`, `GET /deployments/{uuid}`
- Folders: `POST /folders/{uuid}/move-objects`
- Testing: `POST /interfaces/{uuid}/test`, `/test-cases`, `/test-cases/{tcUuid}/run`,
  `/test-cases/run`; same family under `/expression-rules/{uuid}`; `POST /process-models/{uuid}/test`;
  `POST /integrations/{uuid}/test`
- Tasks: `GET /tasks`, `POST /tasks/{taskId}/complete`
- Metrics: `POST /metrics`, `GET /metrics-audit`

---

## Appendix — full route table (newest build)

The complete `RequestRouter.java` table from `origin/appian-dev` lists 200+ routes. The
sections above cover every read route and summarize writes. If you need the verbatim list,
regenerate it:

```bash
cd <composer worktree>/service-components/lcp-api-plugin
grep -nE '^\s*(get|post|put|delete)\(' \
  src/main/java/com/appian/research/lcpapis/routing/RequestRouter.java
```
