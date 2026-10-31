# 50-05 — Install, update and developer setup

> **Status:** ✅ DONE 2026-10-31 (genesis-dev) — review SHIP; genesis `9581140`, `25f384e`, `4ce99c9` on
> `phase-50-monorepo` (local). Was: SPEC-DRAFTED 2026-10-31. Agent: **genesis-dev**. Repo: **genesis**, branch `phase-50-monorepo`.
> Parent: `specs/phase-50-platform-monorepo.md`. Decisions: D3, D6 and defaults F1, F3 (`50-01-findings.md` §6,
> umbrella §10).

## 1. Goal

Every way Genesis gets installed runs the same one command over the local packages and the app (D6), kept in one
place (L-052). No `git+ssh` pin, no access to the old repos.

## 2. `scripts/install-packages.sh` (F1)

- `install-packages.sh [--editable] [--dev] [--python PATH]`: runs **one** `pip install` with
  `./packages/kiro-agent-sdk ./packages/genesis-core ./packages/genesis-appian-parser .` (each `-e` with
  `--editable`; `.[dev]` with `--dev`), from the repo root it finds relative to itself. It is the only file that
  lists the four paths.
- `set -euo pipefail`; clear error output; `shellcheck` clean (the `clean-install` job lints `scripts/*.sh`).

## 3. Installer — `scripts/install.sh`

- `REPOS=(genesis)` (`:30`); the SSH preflight (`:90`) checks only the genesis repo.
- Step 5 (`:137-143`) calls `scripts/install-packages.sh --python "$VENV/bin/python"` instead of `pip install .`;
  update the step label and the header comment (`:15-16`).

## 4. Updater — `genesis/runtime/updater.py`

- `_scope` (F3): `deps` when `git diff --name-only <current>..<tag>` (current = `v` + deployed version) lists
  `pyproject.toml`, anything under `packages/`, or `scripts/install-packages.sh`; else `code`; unknown → `deps`.
  Remove `_dep_lines`.
- `apply()`: the install step runs `scripts/install-packages.sh --python sys.executable` from the checked-out tag
  (the script of the target version, not the running one). Progress text: "Installing Genesis packages…".
- Update the module docstring and the comment above the library refresh: the libraries are installed from the
  checkout; genesis-workflows is still refreshed by `genesis install`.
- Tests (`tests/test_updater.py`): replace the `git+ssh` line tests (`:95,99`) with path-diff cases (app-only change
  → `code`; `packages/genesis-core/...` change → `deps`; root `pyproject.toml` → `deps`; diff failure → `deps`), and
  assert `apply()` invokes the script with the interpreter.
- No cross-over shim for installs made before the merge (D3): they are reinstalled.

## 5. Developer setup and docs

- `README.md` "Develop" (`:47-52`): `scripts/install-packages.sh --editable --dev`, then the gates for the app and
  each package.
- `docs/INSTALL.md` (`:10-11,105` and any other mention of the three repos or SSH access to them): one repo, one
  clone, the script.
- Each `packages/<name>/README.md`: a first line saying it is part of the genesis repo and how to run its tests.

## 6. Gates

`ruff check genesis`, `pytest -q`, `shellcheck scripts/*.sh`, `bash scripts/install.sh --help`. Then a real check in a
throwaway venv: `scripts/install-packages.sh --python /tmp/v/bin/python` → `genesis db upgrade` (temp state dir) →
`genesis up --no-open` → `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8760/` = 200 → `genesis down`.
Use a different port if the fleet holds 8760.

## 7. Acceptance

- [x] One script holds the four paths; installer, updater and docs use it.
- [x] No `git+ssh` reference to the old repos left in the genesis repo outside history (`grep`) — except
  `.gitlab-ci.yml`, which 50-06 owns.
- [x] Updater tests cover the path-diff scope and the script call.
- [x] Throwaway install boots and serves the SPA.

## 8. As built

**Verdict: SHIP** (`reviews/50-05-review.md`, base `7cb9f1c`, range `7cb9f1c..25f384e`; the m2/n1/n2 fixes in
`4ce99c9` came after the verdict, each with its own evidence below). Branch `phase-50-monorepo` in genesis, local
only; the 50-03 hold stands (nothing pushed or tagged). Start: genesis at `7cb9f1c` (50-03 SHIP), dirty 0; 50-04 DONE.

### Commits (genesis, branch `phase-50-monorepo`)

| SHA | What |
|---|---|
| `9581140` | `scripts/install-packages.sh` (new, mode 100755); `scripts/install.sh` step 2/5 + header; `genesis/runtime/updater.py` `_scope` + `apply()`; `tests/test_updater.py`; new `tests/test_install_packages_script.py` |
| `25f384e` | `README.md`, `docs/INSTALL.md`, the three `packages/<name>/README.md` |
| `4ce99c9` | Review fixes: relative `--python` made absolute before the `cd` (m2) + test; header no longer says CI calls the script (n1); INSTALL.md "No module named pip" troubleshooting line (n2) |

### Changed

- **`scripts/install-packages.sh`** `[--editable] [--dev] [--python PATH]`: finds the repo root from its own path
  (checks `pyproject.toml` `name = "genesis"`), `--python` defaults to `<repo>/.venv/bin/python` (error if absent,
  never a system interpreter), a relative path is made absolute against the caller's cwd, checks the three
  `packages/<name>/pyproject.toml` exist, `cd`s to the root and runs **one** `"$PYTHON" -m pip install
  ./packages/kiro-agent-sdk ./packages/genesis-core ./packages/genesis-appian-parser .` (`-e` before each with
  `--editable`, `.[dev]` with `--dev`). It prints the command first; a pip failure ends with
  `install-packages.sh: pip install failed (exit N)`. `set -euo pipefail`. `--help` prints the header block only.
  It is the only file that lists the four paths (`git grep ./packages/kiro-agent-sdk` finds no other list outside
  tests/docs).
- **`scripts/install.sh`**: `REPOS=(genesis)`; the SSH preflight message speaks of the genesis repo only; step 5 runs
  `"$REPO_ROOT/scripts/install-packages.sh" --python "$VENV/bin/python"` (the pip self-upgrade line stays); header
  steps 2 and 5 rewritten.
- **`genesis/runtime/updater.py`**: `_dep_lines` removed. `_scope(repo, current, tag)` runs `git diff --name-only
  v<current>..<tag>` (`v` added to a bare deployed version) → `deps` if a path is the root `pyproject.toml`,
  `scripts/install-packages.sh` or under `packages/`; `code` otherwise; `deps` on a non-zero exit or a git exception.
  `check()` passes the deployed version. `apply()` after the checkout runs `["bash", <repo>/scripts/install-packages.sh,
  "--python", sys.executable]` with `cwd=<repo>` (the checked-out tag's script), progress "Installing Genesis
  packages… this can take a minute.", error line `error: installing Genesis packages failed: <stderr or stdout tail>`.
  It still always installs; `scope` stays informational. Module docstring, `is_managed_install` docstring, the
  `check()` comment and the library-refresh comment/warning updated.
- **Docs**: README install comment + prerequisites (SSH to the `genesis` repo), a `packages/` bullet, Develop =
  `python3.13 -m venv .venv` → `scripts/install-packages.sh --editable --dev` → the gates for the app and each package
  (ruff scopes `genesis_core` · `src tests` · `.`) + "never pip install an internal package by name". INSTALL.md:
  prerequisites (one repo), install step 2/3, the update flow, a note that installs from v0.79.0 and earlier must
  reinstall instead of using the banner, troubleshooting for the genesis SSH test, `Missing Genesis packages: …` and
  the transient pip error. Each `packages/<name>/README.md` opens with a blockquote: part of the genesis repo,
  install with `scripts/install-packages.sh`, run tests with `../../.venv/bin/python -m pytest -q`; genesis-core's
  and the parser's Develop sections now use the shared venv instead of an own `.venv` / bare `pip install -e`.

### Tests

| Gate | Result |
|---|---|
| `ruff check genesis` (final HEAD `4ce99c9`) | All checks passed |
| app `pytest -q` (final HEAD) | **1389 passed** (1374 at 50-03 + 8 updater + 7 script) |
| `shellcheck scripts/*.sh` | clean |
| `bash scripts/install.sh --help` / `install-packages.sh --help` | print their headers |
| Throwaway non-editable: fresh `python3.13 -m venv /tmp/g5005/v` → `scripts/install-packages.sh --python /tmp/g5005/v/bin/python` | exit 0; `Processing ./packages/kiro-agent-sdk`, `./packages/genesis-core`, `./packages/genesis-appian-parser`, the repo; genesis 0.79.0 / core 0.9.8 / SDK 0.7.1 / parser 0.3.0; `pip check` clean; `site-packages/genesis/web_static/{index.html,assets}` present |
| `env GENESIS_STATE_DIR=/tmp/g5005/state GENESIS_ARTIFACTS_DIR=/tmp/g5005/runs genesis db upgrade` | migrations 1–25, memory.db 1 |
| `genesis up --no-open --port 8790` → curl → `genesis down` (`/tmp/g5005/check.sh`; the fleet holds 8760/8761) | up exit 0 (pid 24170); `GET /` **200**, `<title>Genesis</title>`; `/api/config/health` 200; openapi 0.79.0; down → "Stopped."; `GET /` afterwards 000 |
| Throwaway editable: `/tmp/g5005/ve`, `--editable --dev` | `pip list --editable` shows the four at the repo / `packages/<name>`; `pip check` clean; each library imports from `packages/`; ruff 0.15.20 installed |
| Fleet after the checks | :8760 and :8761 `/api/config/health` 200; the shared dev venv was not reinstalled |

New/changed tests. `tests/test_updater.py`: the git+ssh tests replaced by `test_scope_*` (app-only diff incl.
`packages.md` and `docs/pyproject.toml` → `code`; `packages/genesis-core/…` → `deps`; root `pyproject.toml` → `deps`;
the script → `deps`; exit 128 → `deps`; `OSError` → `deps`; bare `0.79.0` → `v0.79.0..`); `test_check_update_available`
asserts the exact `diff --name-only v0.46.1..v0.46.2` call; `test_apply_updates_whole_stack` asserts the script argv
with `sys.executable`, `cwd=<repo>`, no direct pip call, and the order checkout → script → db upgrade → genesis install
→ restart; `test_apply_stops_when_install_script_fails` (no db upgrade, version not recorded). 10 of the 19 fail on
the old `updater.py` (checked with the old file stashed). `tests/test_install_packages_script.py` runs the real
script against a fake interpreter that logs its cwd and argv: plain, `--editable --dev`, pip failure (exit 3
reported), relative `--python` from another cwd, missing interpreter / unknown flag, `--help`, and that
`install.sh` calls the script and has no own `install .` or `git+ssh`. The relative-path fix was proven directly:
the old script with `--python ./fake-python` from `/tmp/g5005` → `No such file or directory`, exit 127; the new one
→ exit 0 with the absolute path.

### Review

`reviews/50-05-review.md` — **SHIP**, no blockers or majors; the reviewer re-ran every gate (1388 at `25f384e`), ran
the script under macOS `/bin/bash` 3.2, a throwaway install twice (pip rebuilds same-version local folders, so a
library change without a version bump is picked up), and checked `/` via `TestClient` (its shell would not start a
server). m2, n1, n2 fixed in `4ce99c9`; m1 recorded below; n3 is for 50-09.

### Decisions / deviations

- **m1 kept as specified (F3), not changed.** The reviewer showed `_scope(repo, "v0.78.0", "v0.79.0")` = `deps` because
  every release bumps `version =` in the root `pyproject.toml`. After 50-07 (D8) every release also bumps
  `packages/*/pyproject.toml`, so ignoring the root version line would not bring `code` back; it would need
  version-line filtering across four pyprojects and the parser `__version__`, for a label. `apply()` always installs,
  and a non-editable install needs a reinstall for any code change anyway, so `deps` is never unsafe. Suggestion for
  the docs agent / a later phase: retire `UpdateStatus.scope` or redefine it as "libraries changed".
- **`--python` defaults to the repo's `.venv`**, not a `python3` on PATH, so a bare call can never install into a
  system interpreter.
- **The updater runs the script with `bash <path>`**, so it does not depend on the checkout keeping the exec bit.
- **No pip retry in the script.** On this Mac a brand-new venv sometimes fails `python -m pip` with "No module named
  pip" for some seconds although `site-packages/pip` is there (files carry `com.apple.provenance`); the same command
  passes on retry. The failure is loud and `install.sh` is idempotent (reviewer agreed); INSTALL.md says to re-run.
  Related: twice a test run right after a `git stash` of a file still saw the previous file content (a 19-pass on the
  old updater, a 7-pass on the old script) while `grep` saw the new content; the direct before/after runs above are
  the evidence used, not those two runs.
- **`.gitlab-ci.yml` left to 50-06** (umbrella): lines 7–8 and 61 still mention git+ssh, lines 10 and 62 still run
  `pip install -e ".[dev]"` / `pip install .`. 50-06 must switch both to the script; the script header names 50-06.
- **README and INSTALL.md beyond the spec lines**: the package READMEs' Develop sections and a `packages/` bullet in
  the README, since they described the retired sibling-venv setup.
- No ADR deviation. The install step change is what the planned ADR-080 records as an amendment of ADR-046 (D14).

### Lesson candidates

- A script that `cd`s must make every caller-supplied relative path absolute first; test the script from a cwd other
  than its repo.
- On this macOS host a freshly written file (a new venv's pip, a `git stash`-restored source) may not be what a
  process sees for a few seconds. A before/after proof should run the old code by a path that was not just rewritten
  (e.g. `git show <rev>:<file>` to a new name, then run it), and a fresh venv may need one re-run.

### Code-map changes (for genesis-docs)

- `genesis/scripts/`: add `install-packages.sh` — the one install command (four local paths, `--editable/--dev/--python`);
  `install.sh` calls it and preflights only the genesis repo.
- `genesis/genesis/runtime/updater.py`: `apply` = checkout tag → that tag's `scripts/install-packages.sh --python
  sys.executable` → db upgrade → `genesis install` → detached restart; `_scope` = path diff (`pyproject.toml`,
  `packages/`, the script → `deps`).
- New test: `tests/test_install_packages_script.py`.

### Notes for later sub-specs

- **50-06:** switch `.gitlab-ci.yml` installs to `scripts/install-packages.sh` (editable in the package jobs, per
  `tests/test_platform_packages.py`; non-editable in `clean-install`), remove the git+ssh comments and `insteadOf`.
- **50-09 (review n3):** a v0.79.0 install that clicks "Update to v0.80.0" runs its old updater (`pip install .`), gets
  the new app and keeps its old git+ssh libraries, and the D15 check passes. Reinstall the user's install and the
  fleet from a fresh clone; do not use the banner.
- `/tmp/g5005/` (three throwaway venvs, logs, `check.sh`) can be deleted.

## Context manifest

```toml
areas    = ["distribution", "security"]
adrs     = ["ADR-026", "ADR-046"]
lessons  = ["L-048", "L-051", "L-052", "L-068"]
docs     = ["tracker:specs/phase-50-platform-monorepo/50-01-findings.md", "tracker:specs/phase-22-distribution-and-shipping.md"]
code     = ["genesis/scripts/**", "genesis/genesis/runtime/updater.py",
            "genesis/tests/test_updater.py", "genesis/README.md", "genesis/docs/INSTALL.md"]
upstream = ["50-03"]
```
