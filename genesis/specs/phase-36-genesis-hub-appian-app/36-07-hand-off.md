# 36-07 — Hand-off

> **Status:** ✅ **DONE (2026-09-05).** · Part of Phase 36. · **Depends on:** 36-06 (contract validation — PASS).

## Outcome — Phase 36 COMPLETE

The `Genesis Hub` Appian application is fully built in the team dev env and **validated end-to-end** with the
shared service-account API key: 11 record types + 13 relationships + record-level security + 7 constants + the
base64 blob store + **11 Web APIs + 12 helper expression rules**. The **frozen contract v1.0.0 + 12 fixtures +
deployment runbook** are checked into genesis at `specs/phase-36-genesis-hub-appian-app/contract/`. ADR-064 →
**Accepted**; bible (`00`/`01`/`04`/`08`), `AGENT_ONBOARDING.md`, `tracker.md` §6, and the progress as-built are
updated to COMPLETE. **No genesis version tag** (Appian-side; the contract doc is the only genesis-repo
footprint). Phase 37 (`AppianHubProvider`, genesis ~v0.64.0) implements + tests against this contract.

## Purpose

Hand the validated Hub app + frozen contract to Phase 37, and update the project docs.

## Deliverables

1. The installable Appian **package** (versioned) + the install/upgrade runbook (36-05).
2. The **frozen contract + fixtures** checked into genesis (36-01) — the interface 37-01 implements; the
   `contract_version` recorded.
3. (Optional) a typed **client stub** in genesis generated from the contract, to seed 37-01.
4. **Docs:** flip **ADR-064 → Accepted** (decision-log + `bible/04`); note the Genesis Hub app + contract in
   `bible/01` §2 ("what works" / external dependencies) + `bible/08` §9 (flip the Phase-36 block) +
   `tracker.md` §6 + `progress/phase-36-genesis-hub-appian-app.md` (as-built, incl. the app version +
   `contract_version`). No genesis version tag (Appian-side).

## Gate

Contract green + docs updated → Phase 36 COMPLETE; Phase 37 may wire the Appian provider.
