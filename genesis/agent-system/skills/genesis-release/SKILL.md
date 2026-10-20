---
name: genesis-release
description: Use when releasing Genesis — the ADR-019 order, every version location to bump, pin bumps, the tag/push protocol (always ask), CI verification, the fleet refresh, and the release-notes template. For the genesis-release agent.
---

# Release

Order & rules: `genesis-ctx adr ADR-019` (genesis-core semver + CORE_MAJOR compat gate) and
`{{TRACKER}}/bible/05-dev-loop-and-release.md` §6; precedent in the latest release sub-spec
(`genesis-ctx search "release" --archive`). Record CI ids and hashes in the release sub-spec's **As run**, not in L0/state.

## Order (ADR-019)
Release upstream→downstream so the compat gate holds: `genesis-core` first (its `CORE_MAJOR` is the gate key), then the
libraries/consumers that declare `genesis_core_major`, then `genesis`. A library whose `genesis_core_major != CORE_MAJOR`
is refused by the loader — bump deliberately, additive-only within a major.

## Version locations (bump EVERY one — missing one is a known regression)
- `genesis-core`: its package version + `CORE_MAJOR` when the major changes.
- each consumer's declared `genesis_core_major` / pinned core version.
- `genesis` app version; the web build (`web/static`) rebuilt + committed when the SPA changed (genesis-web-dev).
- any lockfile/pin the dev-loop doc lists. Grep for the current version string before bumping to catch them all.

## Tag / push protocol (irreversible — ALWAYS ask)
Ask the operator before EACH `git tag` and EACH `git push`. Never force-push or reset --hard. After pushing, verify CI:
`glab ci list` and `glab ci trace <id>`; record the pipeline ids.

## Fleet refresh
Only on the operator's explicit go-ahead; back up data first (genesis-live-acceptance). 

## Release notes template (in the release sub-spec)
```
## As run (<date>, genesis-release)
- Versions: genesis-core vX, genesis vY, <libs> …
- Tags: <repo> <tag> (asked+confirmed)  · Commits: <repo> <hash>
- CI: <repo> pipeline <id> green
- Deferred / follow-ups: …
```
