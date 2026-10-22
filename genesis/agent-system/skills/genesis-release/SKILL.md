---
name: genesis-release
description: Use when releasing Genesis — the ADR-019 order, every version location to bump, pin bumps, the tag/push protocol (always ask), CI verification, the fleet refresh, and the release-notes template. For the genesis-release agent.
---

# Release

Order & rules: `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-019` (genesis-core semver + CORE_MAJOR compat gate) and
`{{TRACKER}}/bible/05-dev-loop-and-release.md` §6; precedent in the latest release sub-spec
(`{{GENESIS_HOME}}/bin/genesis-ctx search "release" --archive`). Record CI ids and hashes in the release sub-spec's **As run**, not in L0/state.

## Order (ADR-019)
Release upstream→downstream so the compat gate holds: `genesis-core` first (its `CORE_MAJOR` is the gate key), then the
libraries/consumers that declare `genesis_core_major`, then `genesis`. A library whose `genesis_core_major != CORE_MAJOR`
is refused by the loader — bump deliberately, additive-only within a major.

## Version locations (bump EVERY one — missing one is a known regression)
- `genesis-core`: its package version + `CORE_MAJOR` when the major changes.
- each consumer's declared `genesis_core_major` / pinned core version.
- `genesis` app version; the web build (`web/static`) rebuilt + committed when the SPA changed (genesis-web-dev).
- any lockfile/pin the dev-loop doc lists. Grep for the current version string before bumping to catch them all.

## Sequencing (one mutating step per tool call — L-089)
Never put order-dependent mutating commands in one parallel tool batch; the tool may run them in any order. Strictly
in sequence: bump → `npm run build` → `git add`/`commit` → fresh `npm run build` + `git status --short
--untracked-files=all` empty → tag; `gsm stop|provision|restart|start` one per call. Batch only read-only commands.

## Tag / push protocol (irreversible — ALWAYS ask)
Ask the operator before EACH `git tag` and EACH `git push`. Never force-push or reset --hard. After pushing, verify CI:
`glab ci list` and `glab ci trace <id>`; record the pipeline ids.

## Fleet refresh
Only on the operator's explicit go-ahead; back up data first (genesis-live-acceptance), unless the operator waives it.
- `gsm` is NOT on the agent shell's PATH: call `{{REPOS}}/genesis-fleet/bin/gsm`.
- First `GET /api/runs?status=running` on each instance (:8760 main, :8761 userb) → `total: 0`; never restart with a run active.
- Then, one call each: `gsm provision --all --no-mcp --no-env --force` → `gsm restart --all` → `gsm status`.
- Verify the running version from `GET /openapi.json` → `info.version` (the `create_app` version). There is no
  `/api/system/version`; `/api/system/update`'s `current` reads a state file and is stale on the editable dev venv.

## Release notes template (in the release sub-spec)
```
## As run (<date>, genesis-release)
- Versions: genesis-core vX, genesis vY, <libs> …
- Tags: <repo> <tag> (asked+confirmed)  · Commits: <repo> <hash>
- CI: <repo> pipeline <id> green
- Deferred / follow-ups: …
```
