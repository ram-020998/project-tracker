# 36-05 — Packaging, security & deployment (Appian)

> **Status:** 🟡 DRAFTED. · Part of Phase 36. **Built by the Dev-MCP agent** (Appian-side) + an ops procedure. · **Depends on:** 36-02/36-03/36-04.

## Purpose

Make the Genesis Hub app **installable + secure**: the shared service account, the security model, an exportable
Appian **package**, and a documented install/upgrade procedure a team runs against their dev environment.

## Build / define

1. **Service account** — a dedicated Appian account whose API key Genesis uses for all Hub writes/reads. Its
   permissions: read/write the Hub record types + document record types + invoke the Web APIs; **no** access to
   subject applications beyond what a developer already has. Document how its API key is provisioned into
   Genesis (rides the ADR-048 per-env credential store; Phase 37 wires it).
2. **Security** — record-level security scoped to the Hub app (open visibility for now, but access limited to
   the team/service account); allowed-origins for the write Web APIs; the service account is the sole writer
   (attribution is payload-carried).
3. **Package** — export the Genesis Hub application (record types + document record types + Web APIs + service
   account references) as an installable Appian package, **versioned** (an app version stamp), with a
   `contract_version` it satisfies.
4. **Install/upgrade procedure** — a documented runbook: import the package into the team's dev env, provision
   the service account + API key, configure allowed-origins, and record the Hub base URL + key in Genesis
   (Settings → Collaboration, Phase 37). Upgrade = import the newer package (record-type/data migrations handled
   Appian-side; the `contract_version` lets Genesis detect a mismatch).
5. **Isolation guidance** — the Hub app is a distinct application; teams do **not** add it to Genesis's tracked
   subject applications (Phase 37 enforces the exclusion by `app_uuid`).

## Gate

Deployable package + runbook; the app installs cleanly into a dev env and serves the APIs → 36-06.
