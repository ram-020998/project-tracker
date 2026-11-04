# 09 — Live Environment Findings

Results of probing a real environment during investigation. These capture **version-specific
behavior** — the deployed plugin predates several routes documented in the newest source.

## Environment under test

| | |
|---|---|
| Host | `merge-assist-dev.appianpreview.com` |
| Base | `https://merge-assist-dev.appianpreview.com/suite/plugins/servlet/stateless/lcp-api` |
| Auth | HTTP Basic, user `kiroDeveloper` (password redacted — rotate) |
| Test application | `_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416` — "AS GSS Full Application" |

## Plugin version (`GET /meta`)

```json
{ "name": "Appian Dev MCP", "version": "26.6.110",
  "key": "com.appiancorp.plugins.lcp.api.retrofit",
  "buildTimestamp": "20261008-132401",
  "appMarket": { "status": "UPDATE_AVAILABLE", "latestVersion": "26.9.10" } }
```

This build is **older than `origin/appian-dev`** HEAD and predates the `manifest` / `objects/batch`
routes.

## Availability matrix (verified by live probe)

### Works (HTTP 200)

- `GET /meta`
- `GET /applications`
- `GET /applications/{app}` (metadata only — no object list)
- `GET /objects` (+ `?appUuid=`, `?types=`, pagination)
- `GET /applications/{app}/{type}` for: `constants, expression-rules, interfaces,
  record-types, process-models, sites, web-apis, groups, folders, documents, portals,
  integrations, connected-systems, data-stores, agents, ai-skills, robotic-tasks`
- Global lists: `GET /{constants, expression-rules, interfaces, record-types, process-models,
  sites, web-apis, groups, documents, folders, portals, integrations, connected-systems,
  data-stores, data-sources}`
- Full reads: `GET /{collection}/{uuid}` (verified for record-types, interfaces, constants,
  expression-rules, process-models, sites)

### Not implemented on this build (HTTP 501 "Operation not implemented by this plugin version")

- `GET /applications/{app}/manifest`
- `POST /objects/batch`
- `GET /applications/{app}/objects`
- **No export/deployment capability:** `GET /applications/{app}/export`, `GET /objects/{app}/export`,
  `POST /deployments`, `GET /deployments`, `POST /objects/versions` → all 501. (So there is no
  in-plugin way to get a live object's IX export XML on this build; use a normal Appian export, or
  deploy the `export-xml` prototype.)
- The prototype `GET /objects/{uuid}/export-xml` → 501 (not built into this plugin; expected)
- `GET /applications/{app}/data-types`
- `GET /applications/{app}/translation-sets`
- `GET /translation-sets` (global)
- `GET /users`
- `GET /environment`
- `GET /quality/design-guidance`, `/quality/static-checks` (and likely `/quality/validate`)

## Scoping behavior of `/objects` (measured)

| Request | `total` |
|---|---|
| `/objects` (no filter) | 10298 (site-wide) |
| `/objects?appUuid={app}` | 2767 |
| `/objects?appUuid={app}&types=interface` | 528 |
| `/objects?application={app}` / `?applicationUuid={app}` | 10298 (param ignored → site-wide) |

**Only `appUuid` scopes the listing.** `application` and `applicationUuid` are ignored.

## Sample objects captured

- An interface: `uuid = _a-0000e5bc-4a9a-8000-9bbc-011c48011c48_938743`,
  `name = AS_GSS_FM_evaluationSummary`.
- A constant full body, an expression-rule full body, etc. — see the schemas embedded in
  [`07-endpoint-contracts.md`](07-endpoint-contracts.md).

## Practical conclusion for this environment

1. Use `GET /objects?appUuid={app}` (paginated, optionally `types`-filtered) to enumerate.
2. `GET /{collection}/{uuid}` per object for full bodies.
3. There is **no bulk/batch** here, so expect one request per object — slow for large apps.
4. To get `manifest` + `objects/batch` (and app-scoped batch), the plugin would need upgrading
   to 26.9.10 (App-Market link is in `/meta`).

## How to re-run the probe

```bash
BASE="https://<host>/suite/plugins/servlet/stateless/lcp-api"; U="<user>:<password>"
probe() { curl -sS -u "$U" -o /dev/null -w "[%{http_code}] GET $1\n" "$BASE$1"; }
curl -sS -u "$U" "$BASE/meta"
probe "/applications"
probe "/objects?appUuid=<APP>&limit=1"
probe "/applications/<APP>/manifest"      # expect 501 on old builds
probe "/objects/batch"                     # (POST on real use) expect 501 on old builds
```

> Security: the investigation used a live password. Treat it as compromised and rotate it.
> Do not store real credentials in this repo.
