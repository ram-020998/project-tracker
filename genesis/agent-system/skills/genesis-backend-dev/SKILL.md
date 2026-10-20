---
name: genesis-backend-dev
description: Use when writing or changing Python in the Genesis backend (genesis, genesis-core, genesis-workflows, kiro-agent-sdk, genesis-appian-parser) — the venv, the test/ruff commands, Python conventions and the regression-test rule. For the genesis-dev agent.
---

# Backend development (Python)

Authoritative sources (read in ranges, do not read whole):
- Dev loop & commands: `{{TRACKER}}/bible/05-dev-loop-and-release.md` §6.
- Conventions: `{{TRACKER}}/reference/coding-standards.md` §2–§4 (already in your L0).
- Tests: `{{TRACKER}}/reference/testing-strategy.md`.
- For the rules that apply to the files you touch: `{{GENESIS_HOME}}/bin/genesis-ctx pack <sub-spec>` (or `--areas …`).

## Environment
- One shared venv for ALL Python repos: `{{REPOS}}/genesis/.venv`.
- Run Python as `{{REPOS}}/genesis/.venv/bin/python …` (not a bare `python`).
- `kiro-agent-sdk` has its own venv: `{{REPOS}}/kiro-agent-sdk/.venv` — use it for that repo's tests.

## Gates (run before you hand off; `{{GENESIS_HOME}}/bin/genesis-ctx check` lists the exact ones per area)
- `{{REPOS}}/genesis/.venv/bin/python -m pytest -q` (narrow to the touched package while iterating).
- `{{REPOS}}/genesis/.venv/bin/ruff check .` (line-length and lint per each repo's config).
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
