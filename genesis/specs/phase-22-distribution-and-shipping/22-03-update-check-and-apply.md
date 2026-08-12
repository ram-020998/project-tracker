# 22-03 — Update check + one-click apply

> **Status:** ✅ CODE-COMPLETE (2026-08-12; genesis code **held for the v0.47.0 release** at 22-06/07) · **Phase:** 22 ·
> **Repo:** genesis · **Depends on:** 22-02
>
> **As built:** `genesis/runtime/updater.py` — dist config (`~/.genesis/dist.json`: repo_dir/branch/remote; `install.sh`
> writes it), `deployed_version` (state file → package version → 0.0.0), numeric semver `highest_tag`, `check()` →
> `{current, latest, update_available, on_tracked_branch, scope, repo_available}`, `apply()` (fetch → on-branch guard →
> checkout tag → `pip install .` → `db upgrade` → write deployed_version → **detached restart** via `bash -c "… down; up"`).
> `api/system.py` `register_system_routes` — `GET /api/system/update` (read-only) + `POST /api/system/update` (streams
> progress). CLI `genesis update [--check-only]`. Web: `lib/api/system.ts` + `features/system/UpdateBanner` (hidden /
> available→button / on-wrong-branch→blocked) mounted at the top of the content area in `AppShell` (poll every 5 min; apply →
> poll health → reload). **Corrected default tracked branch to `master`** (genesis's actual default branch, not `main`) — in
> both `updater` and `install.sh`. **Verified:** 8 updater/api tests + 4 banner tests (incl. jest-axe); `genesis update
> --check-only` works against the real remote (on master = tracked, update available); full backend **425** + web **154** green;
> ruff/eslint/tsc/shellcheck clean; `web/static` rebuilt. The detached restart is manual-verify (documented).

## Goal
In-app awareness of newer releases and a one-click, server-side update (§10.1), from git release tags — Friday's model.

## Version resolution
- **Deployed version**, resolved in order: `~/.genesis/deployed_version` (written on each successful update) → the installed
  `genesis` package version → `0.0.0` (forces first-run update visibility).
- **Latest version** = highest `vX.Y.Z` semver tag on the tracked remote (after `git fetch --tags`).
- **Tracked branch + remote** live in a small genesis-side config (analogue of `friday.config`); default branch `main`.

## API (read-only check + guarded apply)
- `GET /api/system/update` → `{ current, latest, update_available, on_tracked_branch, scope }`.
  `scope`: `deps` (a dependency pin moved → `pip install` needed) vs `code` (app code only). The SPA polls on load + every N min.
- `POST /api/system/update` → runs the update server-side, streams progress (SSE/log lines), then **detached-restarts**:
  1. `git fetch --tags`; **guard:** must be on the tracked branch — else return a "switch to `main`" instruction, do nothing.
  2. checkout the target tag (detached HEAD).
  3. `pip install .` (re-resolves any bumped dependency tags).
  4. `genesis db upgrade`.
  5. write `~/.genesis/deployed_version`.
  6. re-exec `genesis up` **detached** so the current request-serving process can exit; the SPA polls `/api/config/health` and
     reloads when the server returns.

## CLI
- `genesis update [--check-only]` — same logic for terminal users (prints the version delta; applies unless `--check-only`).

## Web
- An **update banner** in the app chrome with states: **none** (hidden), **available** → "Update to vX.Y.Z" button, and
  **on-wrong-branch** → shows the version but explains `git checkout main` is required (button disabled with a tooltip).
- Clicking Update calls `POST /api/system/update`, shows progress, and reloads on health-return.

## Acceptance
- Tagging a newer release makes the banner appear within the poll interval; clicking Update lands the new tag, migrates, and the
  app reloads on the new version; `deployed_version` reflects it.
- On a feature branch, the banner shows but blocks the apply with the switch-to-main guidance.

## Tests
- Unit: semver tag-vs-deployed comparison (incl. `0.0.0` first-run, equal, older/newer, non-semver tags ignored); the
  on-branch guard; scope classification (deps vs code). API tests with git/kiro mocked.
- Web: banner states (none/available/wrong-branch) + a jest-axe pass.
- The detached-restart is verified manually in acceptance (headless-undrivable) — document the manual check.
