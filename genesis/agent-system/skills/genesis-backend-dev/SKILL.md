---
name: genesis-backend-dev
description: Use when writing or changing Python in the Genesis backend (the genesis repo — app plus packages/genesis-core, packages/kiro-agent-sdk, packages/genesis-appian-parser — and genesis-workflows) — the layout, the venv, the install command, the test/ruff commands, Python conventions and the regression-test rule. For the genesis-dev agent.
---

# Backend development (Python)

Authoritative sources (read in ranges, do not read whole):
- Dev loop & commands: `{{TRACKER}}/bible/05-dev-loop-and-release.md` §6.
- Conventions: `{{TRACKER}}/reference/coding-standards.md` §2–§4 (already in your L0).
- Tests: `{{TRACKER}}/reference/testing-strategy.md`.
- For the rules that apply to the files you touch: `{{GENESIS_HOME}}/bin/genesis-ctx pack <sub-spec>` (or `--areas …`).

## Layout and environment
- Two code repos: `{{REPOS}}/genesis` (the app at the root; the libraries in `packages/genesis-core`,
  `packages/kiro-agent-sdk`, `packages/genesis-appian-parser`, each with its own `pyproject.toml`, `tests/` and ruff
  config) and `{{REPOS}}/genesis-workflows`. No internal package declares another one as a dependency.
- One shared venv for everything: `{{REPOS}}/genesis/.venv` (the SDK's own venv is retired).
- Run Python as `{{REPOS}}/genesis/.venv/bin/python …` (not a bare `python`).
- Install / refresh the dev venv with the one install command, from `{{REPOS}}/genesis`:
  `scripts/install-packages.sh --editable --dev` (the three packages + the app, editable). Never `pip install` an
  internal package by name — an internal name must never be resolved against a package index.

## Gates (run before you hand off; `{{GENESIS_HOME}}/bin/genesis-ctx check` lists the exact ones per area)
- App: in `{{REPOS}}/genesis`, `.venv/bin/python -m pytest -q` and `.venv/bin/ruff check genesis` (narrow while iterating).
- A library: in `{{REPOS}}/genesis/packages/<name>`, `../../.venv/bin/python -m pytest -q` and
  `../../.venv/bin/ruff check <scope>` (`genesis_core` · `src tests` · `.`).
- genesis-workflows: `../genesis/.venv/bin/python ci/validate_library.py` and its pytest (see `check`).
- Type/parity checks where the area defines them (workflow META↔yaml parity, etc.).

## Conventions
- Type hints everywhere; `from __future__ import annotations`; small, pure functions; no broad `except`.
- Async-first engine (ADR-024): `ainvoke`/`astream`, `AsyncSqliteSaver`, `aiosqlite`; Python pinned 3.13.
- State is small/serializable/editable (ADR-010/018/022); bulk goes to the RunWorkspace blackboard, never inline in state/chat.
- Secrets by key name only; never commit a secret; never hard-code `/api` in the client (ADR-028 — see genesis-api-dev).

## Regression-test rule (do-not-regress)
Every new behaviour gets a test; every bug fix gets a test that FAILS before the fix and passes after. Keep tests
next to the code's existing suite; match the project's fixtures and style. Do not add a new test framework.

## Loop
Pack → restate task + applicable ADRs/lessons → smallest correct change → gates green → regression test →
scoped local commit. If stuck twice on the same error, find the root cause and change approach.
