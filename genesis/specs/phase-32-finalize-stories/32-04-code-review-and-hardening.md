# 32-04 — Code review & hardening

> **Status:** 🟡 DRAFTED. · Part of Phase 32. Repo: **genesis**. · Gate: review clean.

## Purpose

An independent review pass before release — catch the correctness + reuse + a11y issues that unit tests miss,
apply the SHOULD-FIXes, and record the manual live-acceptance steps.

## Review checklist

- **One-time / irreversible.** `stories_finalized_at` gates re-finalize (409) even after deleting all stories;
  there is no un-finalize path; no code path re-syncs `breakdown.html` → stories after finalize.
- **Finalize preconditions.** 409 unless the breakdown stage is `completed`; **422** (not 500/empty) when the
  embedded backlog is missing/garbled; the parse reuses `_parse_embedded_backlog` + `_current_stage_html`
  (same source as the export — no divergent parser). A finalize is atomic (one `tx()`; partial insert can't
  leak a set marker).
- **Concurrency.** `PATCH` uses `row_version` CAS → 409 `StaleWriteError`; the web surfaces it as a reload
  prompt (not a silent overwrite). `epic_id` on create/update is validated to belong to the feature (or null).
- **Cascade.** Deleting a feature / untracking the app cascades `kb_epics` + `kb_stories` (FK ON DELETE
  CASCADE), matching ADR-042 intrinsic-to-app; `epic_id` ON DELETE SET NULL leaves a story parentless, not
  orphaned-dangling.
- **Schema-bump discipline.** `current_version` is 16 and **every** `== 15` test was bumped (grep clean); the
  `clean-install` CI job migrates a fresh DB to v16 + serves.
- **Reuse / no shell edits.** Stories is the existing reserved tab (ADR-056 invariant intact); the header
  Finalize control replaces the back link cleanly; the detail route follows the feature router pattern.
- **Frontend hygiene.** Tokens not raw colors; dark + light parity; jest-axe clean on the grid + detail/edit;
  the typed client prepends `/api` (no hard-coded paths); query keys from the factory; `row_version` sent on
  edit.
- **Forward-compat seam.** `status` defaults `design`, is stored, and is NOT surfaced — the next
  per-story-execution phase can wire the `STORY_STAGE_TRANSITIONS` machine without a migration.

## Live-acceptance (user-driven; record the steps)

Finalize a feature whose Feature Breakdown is `completed` → confirm the dialog → land on the Stories tab →
verify the grid matches the breakdown (epics, Story/Task split, categories) → open a story → edit its title +
reassign its parent from the epic dropdown → save → add a story → delete a story → reload (data persists) →
re-open the header (Finalize is gone; "Stories finalized ✓" shows) → attempt re-finalize is blocked.

## Gate

Review clean; SHOULD-FIX applied; all gates green.
