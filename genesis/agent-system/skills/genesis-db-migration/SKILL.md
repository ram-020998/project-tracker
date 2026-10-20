---
name: genesis-db-migration
description: Use when changing the Genesis database schema — forward-only numbered migrations, the current_version gate, never hand-written DDL at runtime, genesis db upgrade, and the backup rule. For the genesis-dev agent.
---

# Database migrations

Rules & precedent: `{{GENESIS_HOME}}/bin/genesis-ctx area db` (ADR-030 SQLite posture, the migration lessons) and
`{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-054` (the separate memory.db). Migration code lives under the db package in
`{{REPOS}}/genesis/genesis/db/` (migrations are numbered `mNNNN_*`).

## Rules
- Migrations are **forward-only** and **numbered** (`m0001`, `m0002`, …). Never edit a shipped migration; add a new one.
- The schema version (`current_version` / the DB `v<N>` the state file records) advances by exactly the migrations you
  add. Keep `context/state/current.md`'s DB version in sync at phase end (that's the docs agent's job, but note it).
- Never hand-write runtime DDL: schema changes happen only through a migration applied by `genesis db upgrade`.
- Repositories keep DB-agnostic signatures (ADR-030) so the SQLite→Postgres seam stays cheap.

## Backup rule
Back up the database before applying a migration against real data (and before any fleet update that migrates). The
live-acceptance skill covers fleet backups.

## Gates
- `{{REPOS}}/genesis/.venv/bin/python -m pytest -q` for the db/migration tests (a fresh-DB upgrade test + a data-preserving test).

## Regression rule
Every migration gets a test that upgrades a fresh DB to the new version and a test that preserves existing rows.
