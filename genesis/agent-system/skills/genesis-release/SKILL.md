---
name: genesis-release
description: Use when releasing Genesis — the ADR-019 order, every version location to bump, pin bumps, the tag/push protocol (always ask), CI verification, the fleet refresh, and the release-notes template. For the genesis-release agent.
---

# Release

Order & rules: `{{GENESIS_HOME}}/bin/genesis-ctx adr ADR-019 ADR-080` (the CORE_MAJOR compat gate, as amended by
ADR-080, the platform monorepo) and
`{{TRACKER}}/bible/05-dev-loop-and-release.md` §6; precedent in the latest release sub-spec
(`{{GENESIS_HOME}}/bin/genesis-ctx search "release" --archive`). Record CI ids and hashes in the release sub-spec's **As run**, not in L0/state.

## Repos and order
Three code repos. **genesis** is the platform: the app at the root plus `packages/genesis-core`, `packages/kiro-agent-sdk`
and `packages/genesis-appian-parser`, all released by ONE tag `vX.Y.Z` (no per-library tags; the archived library repos
keep their old tags). **genesis-workflows** pins that tag. **playwright-appian** (branch `main`) is the browser-test tool
genesis vendors as a tarball. Order: playwright-appian (when it changed) → genesis → genesis-workflows. The loader
refuses a library whose `genesis_core_major != CORE_MAJOR` — bump `CORE_MAJOR` deliberately, additive-only within a major.

## playwright-appian (its BIBLE §10.4–§10.5, D-37/D-38)
- Tag `vX.Y.Z` = `package.json` version = `VERSION` in `src/core/version.ts`; move the CHANGELOG `[Unreleased]` notes and
  the README tarball URLs; run its gates (`npm run lint && npm run typecheck && npm test`, `npm run build`).
- Run its CLI as `npx --no-install apwt …`, never a bare `npx apwt` (in a non-TTY shell it installs from the registry).
- Push `main` and wait for green, then the tag (ask before each). Its tag pipeline publishes to the GitLab npm registry
  of project 13864 only after that pipeline's gates (`publish`, then `verify-published`, both green;
  `glab ci list -R ramaswamy.u/playwright-appian`). Never publish by hand, never republish a version or move a tag.
- Record the published tarball URL in the As run:
  `https://gitlab.appian-stratus.com/api/v4/projects/13864/packages/npm/playwright-appian/-/playwright-appian-X.Y.Z.tgz`.
  Then vendor that exact tarball into genesis (the 51-05 procedure) before the genesis release that ships it (L-057).
- **Download it with npm, not curl (L-119):** anonymous reads of that URL answer 404. Run
  `npm pack playwright-appian@X.Y.Z --registry https://gitlab.appian-stratus.com/api/v4/projects/13864/packages/npm/`
  (the user's `~/.npmrc` token; check that it exists by count only, never print it, never read CI variables, L-100),
  then compare the file's SHA-1 with `npm view playwright-appian@X.Y.Z dist.shasum --registry …` and its SHA-512 with
  `dist.integrity`, each in its own message. Copy it byte for byte to `genesis/testexec/vendor/playwright-appian-X.Y.Z.tgz`
  (remove the old one), set `VENDORED_APWT_VERSION`, `VENDORED_APWT_SHA256` and `VENDORED_APWT_SOURCE_COMMIT` and the
  docstring in `genesis/testexec/vendor.py`, and check that no test compares the vendored version with a literal.
  `npm run smoke:install -- --tarball <URL>` checks the published file.

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
`rev-list`, mkdir + backup, provision + run check, restart + status). The calls of one message run in parallel, so
"own call" means **its own message**; check a bundle commit with `git show --stat <sha> -- web/static`.

## Tag / push protocol (irreversible — ALWAYS ask)
Ask the operator before EACH `git tag` and EACH `git push`. Never force-push or reset --hard. After pushing, verify CI:
`glab ci list` and `glab ci trace <id>`; record the pipeline ids. genesis "CI green" = the four package jobs
(`genesis`, `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser`) plus `frontend` / `clean-install` when their
`changes` rules match (a new tag runs all six). `glab ci get` can show a pipeline as running for minutes after its
jobs ended (51-13, #7335323): read the job traces (`glab ci trace <job> -b <ref>`) before calling a pipeline stuck. Work
that never ran in CI before the release commit meets Linux CI for the first time at the release (L-112): expect it, and
check the release commit's first pipeline before tagging. **Time-of-day window (Phase 53 D27):** until backlog
`phase-53-follow-ups.md` §6 m1 is fixed, `test_regression_job_handler_starts_due_apps_and_skips_busy_ones` fails
whenever the real time is 00:00–02:00 IST: tag, push and re-run genesis CI only outside **18:30–20:30 UTC**, and a red
run inside that window on that test alone is re-run outside it, not treated as a regression.

## GitLab API limits
glab's token has read scope only: archiving a project, settings and variables are the operator's, in the GitLab UI
(the 50-09 archive call returned 403). **Never call `glab api …/variables`** or any CI-variables API: it returns values
in clear (L-100).

## Fleet refresh
Only on the operator's explicit go-ahead; back up data first (genesis-live-acceptance), unless the operator waives it.
- `gsm` is NOT on the agent shell's PATH: call `{{REPOS}}/genesis-fleet/bin/gsm`.
- First `GET /api/runs?status=running` on each instance (:8760 main, :8761 userb) → `total: 0`; never restart with a run active.
- Then, one call each: `gsm provision --all --no-mcp --no-env --force` → `gsm restart --all` → `gsm status`.
- **`gsm provision` installs only the workflow library** (`genesis install --from <genesis-workflows checkout>`); it does
  NOT run `scripts/install-packages.sh`. The fleet runs from the editable dev venv, so code is live at commit but new
  dependencies and state-dir assets are not (L-099). When the release adds a Python dependency or a state-dir asset
  (Phase 55: `fastembed` and the embedding model), with the fleet **stopped** (`gsm stop --all`, ports checked in their
  own call): run `{{REPOS}}/genesis/scripts/install-packages.sh --editable --dev` once (it fetches the model and
  re-embeds for the default state dir only), then for every other instance `gsm exec <name> -- memory fetch-model` and
  `gsm exec <name> -- memory reembed`, one call each; then provision and `gsm start --all`. Check each instance with
  `gsm exec <name> -- memory status` (and `db status`).
- Verify the running version from `GET /openapi.json` → `info.version` (the `create_app` version). There is no
  `/api/system/version`; `/api/system/update`'s `current` reads a state file and is stale on the editable dev venv.

## Release notes template (in the release sub-spec)
```
## As run (<date>, genesis-release)
- Versions: genesis vX.Y.Z (app + the three packages), genesis-workflows vA.B.C, playwright-appian vP.Q.R (if released; tarball URL)
- Tags: <repo> <tag> (asked+confirmed)  · Commits: <repo> <hash>
- CI: <repo> pipeline <id> green
- Deferred / follow-ups: …
```
