# 38-05 — Adoption (one-time bulk publish of existing completed work)

> **Status:** ✅ SHIPPED (genesis v0.65.0). · Part of Phase 38. Repo: **genesis**. · **Depends on:** 38-01/38-02/38-03 (the publish mappings).

## Purpose

Let a team adopting the Hub **seed it with their backlog of already-finished work** in one explicit, confirmed
action — without re-touching each artifact. **Nothing auto-publishes.**

## Build

1. A **"Publish existing completed work"** action (Settings → Collaboration, and/or a per-app "publish all"
   control — finalize placement here): enumerate the local **completed** stage artifacts + **finalized** stories
   + **board state** that are **not yet published** (no `published_version`, or a newer local content hash),
   present a **summary** (what will be published, for which apps/features), and **require an explicit confirm**.
2. On confirm, publish them via the 38-01/38-02/38-03 mappings, stamping the current user as
   `published_by`/`owner_username`. **Idempotent** — content-hash dedup + base-version CAS skip anything already
   on the Hub; safe to re-run.
3. **Never automatic**; only completed/finalized work is offered; solo/unconfigured installs never see it.

## Tests

- The action lists exactly the unpublished completed/finalized items; confirm publishes them; re-running is a
  no-op (dedup/CAS); nothing publishes without confirm; disabled when collaboration is off. ruff clean.

## Deliverable

The one-time confirmed bulk-publish (idempotent) + tests.

## Gate

Independent review = SHIP: confirmed + idempotent; only completed work; never automatic; opt-in no-op; gates green.

---
