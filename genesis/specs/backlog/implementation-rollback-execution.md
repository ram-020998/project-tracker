# Backlog — Implementation rollback execution

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-09-23 (Phase 42 spin-off). · Depends on Phase 42 (the implementation lane produces the rollback document).

## Context
Phase 42's `story-implementation` workflow **produces** a local rollback document (`rollback.md`) before it writes any objects — the current code + object **version** of every object it will update, plus a "delete to roll back" note for new objects. Phase 42 explicitly does **not** *execute* rollbacks (locked with the user, Q7).

## The deferred capability
A workflow / action that **executes** a rollback: hand a separate agent the run's `rollback.md`, and it restores each modified object to its captured original code/version and (for new objects) marks them deprecated (no deletes, per the Phase-42 stance) — reversing an implementation run. Likely a Workbench action ("Roll back this implementation") on a Code-Review/Implementation card, or a lane move, bound to a new `story-rollback` workflow that reuses `appian-dev-write` (update-only) + the reliability trio + verify.

## Open questions when picked up
- Trigger surface (a card action vs a lane); which runs are rollback-able (the last implementation run's `rollback.md`).
- Partial rollback (some objects changed further since) — conflict detection via object versions.
- The no-delete stance means "roll back a newly-created object" = deprecate-in-description, not delete — confirm that's the desired semantic, or gate a true delete behind explicit human confirmation here.
- Wiki entries for a rollback (a `change_kind` = `rolled-back`?).
