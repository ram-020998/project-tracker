# Phase 24 — UX revamp & environment-scoped credentials (umbrella)

> **Status:** 📝 DRAFT (approved direction, 2026-08-18). Two user-feedback changes, delivered together. **Not yet
> implemented** — specs written for review. ADRs: **048** (env-scoped core-MCP creds) + **049** (Applications-first IA).
> Sub-specs live in [`phase-24-ux-revamp-and-environment-credentials/`](./phase-24-ux-revamp-and-environment-credentials/).

## Background
Two pieces of user feedback:
1. **Navigation is too broad** — 6 primary destinations; the landing should be Applications, and Overview + Catalog should
   move out of the top level.
2. **Core-MCP credentials are split** from their environment — creds for `appian-dev`/`appian-devops` are entered on the MCP
   cards, separate from the Environments tab.

## Sub-specs
- **[01 — Environment-scoped credentials](./phase-24-ux-revamp-and-environment-credentials/24-01-environment-credentials.md)** — enter
  the Dev/DevOps creds on the environment form; store per-env in the SecretProvider (`env:<label>`); resolve them **only**
  from the dev env; `LCP_API_PATH` becomes a public env field; hide `LCP_URL`/`APPIAN_DOMAIN` (auto-derived); one-time
  non-destructive migration of legacy server-scoped creds. Backend-anchored → **do this first**.
- **[02 — Nav & IA revamp](./phase-24-ux-revamp-and-environment-credentials/24-02-nav-and-ia-revamp.md)** — Applications is the landing +
  first tab; primary nav = Applications · Chat · Runs · Documents; Overview + Catalog become Settings tabs (default =
  Overview). Frontend-only.

## Delivery order
1. **01 (credentials)** — smaller, testable headlessly, de-risks the env UX. Release chain: genesis-workflows
   (`mcp-registry.json`) + genesis.
2. **02 (nav/IA)** — frontend-only genesis release (rebuild + commit `web/static`).

## Definition of done
- Both sub-specs' code + tests green (pytest + ruff; vitest + eslint + tsc + build); CI green.
- Existing users' Dev/DevOps setup keeps working with **no re-entry** (migration verified).
- Bible refreshed per keep-current routing: `bible/04-adrs-and-constraints.md` (ADR-048/049),
  `bible/03-codebase-map.md` (settings tabs + env creds), `bible/01-current-state.md` (versions), `bible/06-hard-won-lessons.md`
  if anything is learned; `reference/decision-log.md` (ADR-048/049); `tracker.md` §6.
