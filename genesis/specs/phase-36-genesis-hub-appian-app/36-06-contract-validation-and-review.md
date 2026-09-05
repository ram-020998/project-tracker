# 36-06 — Contract validation & review

> **Status:** 🟡 DRAFTED. · Part of Phase 36. · **Depends on:** 36-01 (contract + fixtures), 36-02..36-05 (the built app).

## Purpose

Prove the deployed Genesis Hub app **satisfies the frozen 36-01 contract** before Phase 37 codes against it, and
review its correctness + security.

## Activities

1. **Contract-test harness** — run the shared 36-01 fixtures against the deployed app's Web APIs: every endpoint
   returns the specified shape + status code; the **base-version CAS** returns **409 {current_version}** on a
   stale upsert; the blob **dedup** returns 200-unchanged vs 201-new; the change manifest advances a cursor +
   reports `contract_version`; advisory markers set/expire; teams/memberships round-trip. (This same harness is
   reused by the Genesis provider tests in 37-01 — one source of truth for both sides.)
2. **Security review** — the service account is the sole writer; attribution is payload-carried; allowed-origins
   correct; the Hub app is isolated from subject apps; no subject-app data reachable via the Hub APIs.
3. **Independent review** — record model matches 36-01; blob versioning/dedup/retention correct; error envelope
   uniform; fix any gaps.

## Gate

Contract harness green + review clean → 36-07.
