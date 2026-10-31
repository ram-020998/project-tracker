---
name: genesis-release
description: Use when releasing Genesis — the ADR-019 order, every version location to bump, pin bumps, the tag/push protocol (always ask), CI verification, the fleet refresh, and the release-notes template. For the genesis-release agent.
---

# Release

Order & rules: `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-019` (the CORE_MAJOR compat gate; amended by ADR-080, the
platform monorepo — proposed in `{{TRACKER}}/specs/phase-50-platform-monorepo.md` §12 until recorded) and
`{{TRACKER}}/bible/05-dev-loop-and-release.md` §6; precedent in the latest release sub-spec
(`{{GENESIS_HOME}}/bin/genesis-ctx search "release" --archive`). Record CI ids and hashes in the release sub-spec's **As run**, not in L0/state.

## Repos and order
Two code repos. **genesis** is the platform: the app at the root plus `packages/genesis-core`, `packages/kiro-agent-sdk`
and `packages/genesis-appian-parser`, all released by ONE tag `vX.Y.Z` (no per-library tags; the archived library repos
keep their old tags). **genesis-workflows** pins that tag. Release genesis first, then genesis-workflows. The loader
refuses a library whose `genesis_core_major != CORE_MAJOR` — bump `CORE_MAJOR` deliberately, additive-only within a major.

## Version locations (bump EVERY one — missing one is a known regression)
- genesis, one shared version: the root and the three `packages/*/pyproject.toml`, the parser `__version__`, the
  `create_app` version and `web/src/version.ts`. `tests/test_version_sync.py` fails on any mismatch — run it before
  the release commit. `CORE_MAJOR` (`packages/genesis-core/genesis_core/types.py`) and the parser `KB_FORMAT_VERSION`
  do NOT follow the version: change them only on a core major change / a parse-output change that needs a full re-sync.
- genesis-workflows, every pin on the SAME genesis tag (L-057): `genesis-core`, `kiro-agent-sdk` (runtime) and
  `genesis-appian-parser` (dev) as `…/genesis.git@vX.Y.Z#subdirectory=packages/<name>`, the dev `genesis` pin without
  `#subdirectory`; `registry.json` `genesis_core_version` (= the genesis version) and `genesis_core_major`.
- `web/static` rebuilt + committed when the SPA changed (genesis-web-dev).
- any lockfile/pin the dev-loop doc lists. Grep for the current version string before bumping to catch them all.

## Sequencing (one mutating step per tool call — L-089)
Never put order-dependent mutating commands in one parallel tool batch; the tool may run them in any order. Strictly
in sequence: bump → `npm run build` → `git add`/`commit` → fresh `npm run build` + `git status --short
--untracked-files=all` empty → tag; `gsm stop|provision|restart|start` one per call. Batch only read-only commands, and
only with other reads: a verifying read (`git status`, `git rev-list`, `ls` of a backup, a run or health check) runs in
its **own** call after the step it proves, never in the same batch as that step (L-089; the 49-09 As run batched tag +
`rev-list`, mkdir + backup, provision + run check, restart + status).

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
- Versions: genesis vX.Y.Z (app + the three packages), genesis-workflows vA.B.C
- Tags: <repo> <tag> (asked+confirmed)  · Commits: <repo> <hash>
- CI: <repo> pipeline <id> green
- Deferred / follow-ups: …
```
