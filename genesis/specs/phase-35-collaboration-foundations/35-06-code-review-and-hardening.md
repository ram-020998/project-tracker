# 35-06 — Code review & hardening

> **Status:** 🟡 DRAFTED. · Part of Phase 35. Repo: **genesis**. · **Depends on:** 35-02..35-05.

## Purpose

An independent review of the Phase-35 substrate before release — the load-bearing correctness properties that
every later phase relies on.

## Review checklist

- **Opt-in is truly a no-op when disabled.** With no Hub configured: no identity gate, no onboarding, no
  collaboration UI, no provider constructed, no behavior change anywhere. A solo/offline user's experience is
  byte-identical to pre-Phase-35 (aside from the inert new columns).
- **Migration m0019 is additive, correct, idempotent.** Fresh DB → v19; a **populated** DB backfills a unique
  `sync_uuid` on every synced row; re-running is a no-op; `row_version`/owner/team/provenance columns default
  safely; the `collab_*` local tables created. Every `current_version == 18` test bumped.
- **Identity/attribution.** `canonical_username()` fallbacks are correct (identity / legacy owner / "local");
  `LifecycleService.transition(actor=…)` records the username in m0013 at every call site; `memory_owner_username`
  consumers unchanged when no identity is set.
- **The `SyncProvider` seam is clean + Appian-free.** `CollaborationService` depends only on the Protocol; the
  `LocalHubProvider` round-trips records + blobs + manifest + activity; **content-hash dedup** works; the
  **base-version CAS** raises the stale-conflict (no silent overwrite); disabled ⇒ `is_enabled()` false.
- **No local-only data leaks into a published payload** (chat_session_id/run_id/html_path never published;
  local-only tables never touched by publish/pull).
- **Standards:** ruff/tsc/eslint clean; jest-axe on new pages; dark-parity; no hard-coded brand hex; no
  hard-coded `/api`; DB-agnostic store signatures; no DDL outside `db/migrations`.

## Deliverable

Review notes + applied SHOULD-FIX; a short live-acceptance script (enable the local provider → onboard → publish
a record from one profile dir → pull from a second) since real Hub sync is Phase 37.

## Gate

Review clean → 35-07.
