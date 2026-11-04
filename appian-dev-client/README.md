# appian-dev-client

Documentation and reference for building an independent client against the **Appian
Dev MCP / `appian-dev` LCP API plugin** — the HTTP plugin that exposes an Appian
environment's design objects as JSON.

This project captures everything learned while investigating the `appian/dev/composer`
repository (the `appian-dev` branching-and-isolation line) and testing the plugin's
REST endpoints live against a real environment.

## Why this exists

The `appian-dev` toolchain (a.k.a. DevMCP Local) checks Appian design objects out of an
environment onto the local filesystem as YAML, lets agents edit them, and merges them
back. The data transport underneath that is a plain, authenticated REST API served by a
Java plugin installed on the Appian environment. **Those endpoints are not private to
`appian-dev`** — any client (curl, a script, an Appian Integration object) can call them
with ordinary credentials. This repo documents that API and how the whole pipeline works
so we can build our own client.

## Document index

| Doc | Contents |
|---|---|
| [`docs/01-overview-and-branching-strategy.md`](docs/01-overview-and-branching-strategy.md) | What `appian-dev` is, the branching & isolation strategy, product context |
| [`docs/02-repository-and-branch-topology.md`](docs/02-repository-and-branch-topology.md) | The `composer` repo, the `appian-dev` / `dev-mcp` / `DMPD-*` branch lines, how they relate |
| [`docs/03-architecture-devmcp-local.md`](docs/03-architecture-devmcp-local.md) | DevMCP Local architecture, the branch model, on-disk layout, merge/drift/runtime isolation |
| [`docs/04-checkout-export-pipeline.md`](docs/04-checkout-export-pipeline.md) | How objects are exported from the environment to YAML, end to end (client + server side) |
| [`docs/05-plugin-environment-internals.md`](docs/05-plugin-environment-internals.md) | How the Java plugin reads data from the environment (Appian internal services) |
| [`docs/06-api-reference.md`](docs/06-api-reference.md) | API overview: base URL, auth, conventions, pagination, errors |
| [`docs/07-endpoint-contracts.md`](docs/07-endpoint-contracts.md) | **Detailed per-endpoint contracts** (paths, params, request/response schemas) |
| [`docs/08-building-a-client.md`](docs/08-building-a-client.md) | How to build a standalone client, including an Appian Integration/Web API |
| [`docs/09-live-environment-findings.md`](docs/09-live-environment-findings.md) | Live probe results against `merge-assist-dev`, version differences, what works |
| [`docs/10-diffing-exported-vs-live.md`](docs/10-diffing-exported-vs-live.md) | Diffing an exported (unimported) object vs. live; the IX/Haul representation problem; chosen approach |
| [`docs/11-deployment-options-and-decision.md`](docs/11-deployment-options-and-decision.md) | Where the converter must run, modify-plugin vs standalone vs no-plugin options, deployment mechanics, the open decision |

## Prototypes

| Path | What it is |
|---|---|
| [`prototype/plugin/`](prototype/plugin/) | Reference plugin routes: `POST /objects/from-export-xml` (export IX XML → **live plugin JSON**, the converter) and `GET /objects/{uuid}/export-xml` (live object's IX XML) + route registration + README |

## Quick facts

- **Plugin servlet base path:** `/suite/plugins/servlet/stateless/lcp-api`
- **Auth:** HTTP Basic (Appian-native user/password) **or** a browser session cookie + `X-APPIAN-CSRF-TOKEN`
- **Read API is app-scopable and paginated**; bulk reads use `POST /objects/batch` (newer plugin builds only)
- **Source of truth:** `gitlab.appian-stratus.com:appian/dev/composer.git`, branch `origin/appian-dev`,
  plugin at `service-components/lcp-api-plugin`, local client at `service-components/devmcp-local`

> **Security note:** Endpoint examples in these docs use placeholder credentials. Do not
> commit real passwords. Store credentials in a secret manager (or an Appian Connected
> System secured field). The test password used during investigation should be rotated.

## Status

Documentation-only project (investigation notes + API reference). No client code yet.
