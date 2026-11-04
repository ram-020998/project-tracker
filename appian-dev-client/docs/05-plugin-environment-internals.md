# 05 — Plugin Environment Internals (how the Java plugin reads data)

The plugin runs **inside** the Appian application server. It does **not** call Appian over
HTTP and does **not** produce an export package — it calls Appian's own internal Java service
APIs directly, the same ones the Appian Designer UI uses.

## Entry point & service injection

`com.appiancorp.lcpapi.rest.LcpApiServlet extends AppianServlet`, served at:

```
/suite/plugins/servlet/stateless/lcp-api/{path}
```

- Gated by feature toggle `ae.dev-copilot-api.lcp-api-plugin` (defaults enabled when absent).
- Appian's Spring container injects platform service beans via `@Inject`
  (`RecordTypeDefinitionService`, `SiteService`, `WebApiService`, `DesignObjectSearchService`,
  `ExtendedApplicationService`, `ProcessDesignService`, …). `ContentService` + the
  `ServiceContext` come via `ServiceLocator` / `ServiceContextFactory`.
- All injected services are bundled into `routing/ServiceBundle` and handed to each handler.
- **Everything runs under the authenticated user's `ServiceContext`** → object/row security
  applies. This is why an external client only ever sees what its account can.

## Request flow

```
HTTP request
  → LcpApiServlet (doGet/doPost/doPut/doDelete)
  → RequestRouter   (matches method + path template → handler)
  → <Type>Handler   (retrieval: calls the injected Appian service, owns 400/403/404)
  → ObjectRenderer + <Type>Mapper  (rendering: Appian domain object → REST JSON)
  → HttpResponse
```

Clean split: **handlers retrieve, `ObjectRenderer` renders.** The single-object GET and the
batch endpoint both funnel through the same `ObjectRenderer`, so a batched object's JSON is
identical to its individually fetched JSON. (Designer-URL enrichment is the one thing added
only on single-object reads, since it depends on the request URL and costs a lookup.)

## Which Appian service reads which object type

| Object type | Appian service call (the actual retrieval) |
|---|---|
| Interfaces, expression rules, constants, documents, folders, integrations, connected systems (**content-backed — the bulk**) | `contentService.getIdByUuid(uuid)` → `contentService.getVersion(contentId, ContentConstants.VERSION_CURRENT)` → `Content` |
| Record types | `recordTypeService.getWithExternalizedRules(uuid)` (`RecordTypeDefinitionService`) → `RecordTypeDefinition` |
| Process models | `processDesignService.getProcessModelByUuid(uuid)` (`ProcessDesignService`) |
| Sites | `siteService.get(uuid)` |
| Web APIs | `webApiService.getByUuid(uuid)` (+ `getHistoricalVersionByUuid` for `?version=`) |
| Translation sets | `translationSetService.getByUuid(uuid)` |
| Groups / users | `groupService.findGroupsPaging(...)`, `getMemberGroupsPaging(...)`, `UserService` |
| Applications | `ExtendedApplicationService` / content search |
| Dependency graph (precedents/dependents) | `designObjectSearchService` (`DesignObjectSearchService` — the IX analysis index) |

### The common content path (most of an app)

```java
Long contentId = svc.contentService.getIdByUuid(uuid);
Content content = svc.contentService.getVersion(contentId, ContentConstants.VERSION_CURRENT);
// → ObjectRenderer.renderContent(category, content, versionId, svc) → JSON
```

`InterfaceHandler.getInterface` follows exactly this (via `resolveInterface` → content version
→ `InterfaceMapper`). `getIdByUuid` resolves the stable design UUID to Appian's internal numeric
content id; `getVersion(..., VERSION_CURRENT)` returns the current definition bean.

## Underneath the services: backend engines

Those service beans hit Appian's **backend engines**:
- **Content engine** for content-backed objects — single-threaded, which is why
  `ObjectBatchHandler` groups UUIDs **by backing service**: content-backed objects resolve in
  ~2 bulk content-engine calls per chunk regardless of how many types the chunk spans.
- Record / process services for their types.
- RDBMS for record data (`GetRecordData`).

## The batch handler (the exporter)

`ObjectBatchHandler.getObjects` (`POST /objects/batch`):
- Reads `{"uuids":[...], "includeSections":[...]}`; `uuids` ≤ `MAX_BATCH_SIZE` (500), over → 400.
- Dedupes preserving request order.
- Groups by backing service; content-backed via `renderContentBacked`, the rest via
  `renderViaResolver`.
- Content chunked at `CONTENT_CHUNK_SIZE` (100) to bound time on the single-threaded content engine.
- Per-item `status` so one broken object cannot sink a chunk of 500.
- **Why batch exists:** download cost is dominated by *request count* — each request pays
  ~700 ms of server CPU for Basic-auth password hashing on 2-core dev servers, and several
  engines are single-threaded. One auth for hundreds of objects is the only lever that moves.

## Takeaway for our client

We cannot (and need not) replicate the in-JVM service calls. Our client just calls the HTTP
endpoints; the plugin does the Appian-internal work. The only constraints we inherit are:
permissions of the authenticated account, and whichever routes the *deployed* plugin version
implements.
