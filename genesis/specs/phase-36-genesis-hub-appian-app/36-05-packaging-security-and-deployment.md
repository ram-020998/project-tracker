# 36-05 — Groups, service account, security, packaging & deployment (Appian build)

> **Status:** 🟡 DRAFTED. · Part of Phase 36. **Built by the Dev-MCP agent** (Appian-side) + an ops runbook. · **Depends on:** 36-02/36-03/36-04. · **Skill refs:** `applications.md`, `security.md`, `security-patterns.md` (group hierarchy), `supporting-objects.md`.

## Purpose

Make the Hub **secure + installable**: the group hierarchy + the shared service account, record/object security,
an exportable versioned Appian **package**, and a deployment/upgrade runbook.

## A. Application + groups (skill: `applications.md` + `security-patterns.md`)

- **Application** `Genesis Hub` (prefix `GH`) — created first (creates default groups/folders). **Isolated**: a
  distinct application; **not** a Genesis subject app (Phase 37 excludes its `app_uuid` from tracking/parsing).
- **Group hierarchy** (parent → children, so permissions inherit — the skill's group-hierarchy template):
  - `GH All Users` (parent) — the team; **read** access to Hub data.
    - `GH Administrators` — manage the app + data.
    - `GH Service Accounts` — the API writer(s).
- **Service account** `genesis.hub.service` (a system/service user) — a member of `GH Service Accounts`; its
  **API key** is what every Genesis instance uses to call the Web APIs. Provisioned in the Appian admin console;
  handed to Genesis (Settings → Collaboration; stored per-env via ADR-048).

## B. Security model

- **Record types (36-02):** read = `GH All Users`; write = `GH Service Accounts`; admin = `GH Administrators`.
  (Open visibility — no per-team row filtering this phase; `ownerUsername`/`teamUuid` tags stored for later.)
- **Web APIs (36-04):** invocable by `GH Service Accounts` (all calls come as the shared service account) +
  `GH Administrators`; each body also asserts `GH_isServiceCaller()`. Write verbs added to **allowed origins**
  (CSRF exemption). The service account has **no access to subject applications** beyond a normal developer.
- **Documents/folders (36-03):** the blob folders are readable by `GH All Users`, writable by
  `GH Service Accounts`.
- **Secrets:** the service-account API key never lives in `environments.json` — it rides the SecretProvider via
  ADR-048 (the Phase-37 wiring); reference by key name only.

## C. Packaging + deployment

- **Package:** export the `Genesis Hub` application (record types + their data-source objects + document
  record/folders + constants + expression rules + Web APIs + group references + optional admin interfaces) as an
  installable Appian **package**, stamped with an **app version** + the **`contract_version`** it satisfies.
- **Runbook (documented, checked into genesis alongside the contract):**
  1. Import the `Genesis Hub` package into the team's **dev environment** (the Hub env).
  2. Create the DB tables / data-store on the Hub data source (or let the import create them).
  3. Create the `genesis.hub.service` account, add it to `GH Service Accounts`, generate its **API key**.
  4. Configure the Web-API **allowed origins**; note the Web-API **base URL**.
  5. In Genesis: Settings → Collaboration → set the Hub **base URL** + the **service-account API key** + select
     the `appian` provider (Phase 37).
  6. **Isolation:** do **not** add the Genesis Hub app as a tracked subject application in Genesis.
- **Upgrade:** import the newer package version; the bumped `contract_version` lets Genesis warn on a mismatch
  (Phase 37 `/meta` check). Record-type/data migrations are handled Appian-side.

## Gate

Deployable, versioned package + runbook; the app installs cleanly into a dev env and serves the Web APIs →
36-06.
