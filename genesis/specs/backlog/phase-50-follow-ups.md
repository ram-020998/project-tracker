# Backlog — Phase 50 follow-ups (platform monorepo)

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-10-31 (Phase 50, 50-01 D17). · Depends on Phase 50.

## 1. Retire the updater's `scope` label

**Context.** `runtime/updater.py` `_scope()` labels an available update `deps` or `code`. Since 50-05 it is `deps`
when the path diff between the deployed version and the target tag touches the root `pyproject.toml`, `packages/**` or
`scripts/install-packages.sh`. Since 50-07 every release bumps the version line in every `pyproject.toml`, so the
label is always `deps` (50-05 review m1). It was already loose before Phase 50: a managed install is non-editable, so
even an app-only change needs a reinstall.

**Who reads it.** Only `genesis update --check-only` prints it (`genesis/genesis/cli/main.py:183`); `/api/system`
returns it in `UpdateStatus`, typed in `web/src/lib/api/system.ts`, but no screen shows it (only
`features/system/system.test.tsx` fixtures). `apply()` always reinstalls. No behaviour depends on it.

**When picked up.** Remove `scope` from `UpdateStatus`, the CLI line, the web type and fixtures and the updater tests,
as one API contract change (L-011: mirror the contract in `web/src/types` + fixtures). Or give it a real meaning if a
use appears (e.g. "needs a DB migration").

## 2. `genesis status` does not report the port the server actually runs on

**Context (50-06 As built).** After `genesis up --port 8791`, a bare `genesis status` printed port 8760. The
`status` sub-command takes `--port` with a default of 8760 (`genesis/genesis/cli/main.py:66-67`) and passes it to
`runtime/launcher.status`, so it reports the default port unless told otherwise. Predates Phase 50.

**When picked up.** Have `up` record the host/port it started on next to its pid file and let `status` (and `down`,
`logs` if they share the assumption) read it when `--port` is not given. Small; distribution area (L-052: keep it in
the one launcher module).
