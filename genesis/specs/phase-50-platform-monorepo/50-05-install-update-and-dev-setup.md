# 50-05 — Install, update and developer setup

> **Status:** SPEC-DRAFTED 2026-10-31. Agent: **genesis-dev**. Repo: **genesis**, branch `phase-50-monorepo`.
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

- [ ] One script holds the four paths; installer, updater and docs use it.
- [ ] No `git+ssh` reference to the old repos left in the genesis repo outside history (`grep`).
- [ ] Updater tests cover the path-diff scope and the script call.
- [ ] Throwaway install boots and serves the SPA.

## 8. As built

*(filled by genesis-dev)*

## Context manifest

```toml
areas    = ["distribution", "security"]
adrs     = ["ADR-026", "ADR-046"]
lessons  = ["L-048", "L-051", "L-052", "L-068"]
docs     = ["tracker:specs/phase-50-platform-monorepo/50-01-findings.md", "tracker:specs/phase-22-distribution-and-shipping.md"]
code     = ["genesis/scripts/**", "genesis/genesis/runtime/updater.py", "genesis/genesis/runtime/preflight.py",
            "genesis/tests/test_updater.py", "genesis/README.md", "genesis/docs/INSTALL.md"]
upstream = ["50-03"]
```
