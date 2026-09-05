# 37-05 — Code review & hardening

> **Status:** 🟡 DRAFTED. · Part of Phase 37. Repo: **genesis**. · **Depends on:** 37-01..37-04.

## Review checklist

- **Provider contract-conformance** vs the shared Phase-36 fixtures (esp. 409→`HubConflict`, blob dedup,
  `contract_version`).
- **Pull-first correctness** — sync pulls when newer (no needless re-parse); refresh-from-Appian is the only
  export path; content-hash dedup no-ops unchanged; the per-app lock blocks double export; the Hub app is
  excluded.
- **`hydrate_from_blob`** replaces current state correctly + off-loop (no checkpointer deadlock, §7).
- **Attribution** flows to the Hub; the onboarding-gate blocks un-onboarded publishes.
- **Offline-first** — Hub-down never blocks local work; sync resumes; opt-in still a no-op when disabled.
- **Standards** — ruff/tsc/eslint; jest-axe; no hard-coded `/api`/brand-hex; secrets by key name (the service-
  account key never logged).

## Deliverable

Review notes + applied SHOULD-FIX; the live-acceptance script for 37-06.

## Gate

Review clean → 37-06.
