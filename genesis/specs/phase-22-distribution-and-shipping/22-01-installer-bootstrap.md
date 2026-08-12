# 22-01 — Installer / bootstrap (`scripts/install.sh`)

> **Status:** 📝 DRAFT · **Phase:** 22 · **Repo:** genesis · **Depends on:** — (first sub-phase)

## Goal
A single, idempotent, re-runnable bootstrap that takes a machine with the prerequisites installed to a working Genesis clone
ready to launch. Modeled on Friday's `init.sh`, adapted to Genesis's single clone + `git+ssh` transitive deps.

## Behavior
`scripts/install.sh [--dir <path>] [--branch main] [--no-migrate]`

1. **Prerequisite check** — `python3.13`, `git`, `kiro-cli` on PATH. Fail fast with an actionable message per missing tool
   (e.g. "install kiro-cli and run `kiro-cli login`"). Node is **not** required (frontend ships prebuilt in `web/static`).
2. **SSH-access preflight** — `git ls-remote` against each of the four repos (`genesis`, `genesis-core`, `kiro-agent-sdk`,
   `genesis-appian-parser`). If any is unreachable, print exactly which repo the SSH key can't read and stop — so a missing
   grant never surfaces as an opaque `pip` failure.
3. **Locate or clone** — if run inside an existing `genesis` clone, use it; else clone the tracked branch into `--dir`
   (default `~/genesis`).
4. **venv** — create `.venv` with python3.13 if absent.
5. **Install** — `.venv/bin/pip install .` (non-editable). The three internal deps resolve automatically from their `git+ssh`
   tag pins; `genesis-workflows` is not installed here (pulled at runtime).
6. **Migrate** — `.venv/bin/genesis db upgrade` (unless `--no-migrate`); creates/upgrades `~/.genesis/genesis.db` to the current
   `current_version`.
7. **Scaffold** — ensure `~/.genesis` (state dir) + `~/.genesis/run` exist.
8. **Next steps** — print `genesis up` (and where the guide lives).

## Acceptance
- On a clean machine with prereqs + SSH access: one run leaves a working install; a second run is a no-op/upgrade (idempotent).
- Missing SSH grant → a clear per-repo error, non-zero exit, no half-installed venv left implying success.

## Tests
- `shellcheck` clean; a smoke run in CI's clean-install job (22-06) exercises the happy path.
- Prereq/SSH-preflight branches unit-tested via a thin harness (stub `command -v` / `git ls-remote`).

## Notes
- Keep all state under `~/.genesis` (never in the clone) so a re-clone/update never loses data.
- Windows = WSL only (documented in 22-07); the script targets bash on macOS + Linux.
