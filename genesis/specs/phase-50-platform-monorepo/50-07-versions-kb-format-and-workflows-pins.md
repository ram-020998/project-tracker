# 50-07 — Shared version, KB format version, genesis-workflows pins

> **Status:** SPEC-DRAFTED 2026-10-31. Agent: **genesis-dev**. Repos: **genesis** (branch `phase-50-monorepo`) and
> **genesis-workflows** (local branch `phase-50-monorepo`). Parent: `specs/phase-50-platform-monorepo.md`.
> Decisions: D6, D8 and defaults F4, F5 (`50-01-findings.md` §6; umbrella §10).

## 1. Shared version (D8, F5) — genesis

- Set `packages/*/pyproject.toml` versions and the parser `__version__` to the app's current version (the Phase 49
  version, e.g. 0.79.0). The release (50-09) bumps all of them to 0.80.0 together.
- `tests/test_version_sync.py`: reads the four `pyproject.toml` files (`tomllib`), the parser `__version__`, the
  `create_app` version literal and `web/src/version.ts`; fails with the list of mismatches. Runs in the `genesis` job.
- `CORE_MAJOR` stays `1` (`packages/genesis-core/genesis_core/types.py:11`); its docstring/comment says it is the
  compat gate and independent of the package version (ADR-019 as amended by ADR-080).

## 2. `KB_FORMAT_VERSION` (D8, F4) — genesis (parser)

- `genesis_appian_parser/__init__.py`: `KB_FORMAT_VERSION = 1` (exported), with a comment: bump only when the parse
  output changes so that an existing KB must be rebuilt by a full sync; `1` = the output of parser 0.3.x.
- A parser test pins the value so a bump is a deliberate, reviewed change.

## 3. `sync-application` — genesis-workflows

`workflows/sync-application/graph.py:52,197-211` today compares parser minor versions. Change to:

- `KB_FORMAT = getattr(_gap, "KB_FORMAT_VERSION", None)` (fallback keeps the workflow working with a genesis that
  lacks the constant — version skew).
- The sync records `kb_format_version` in `details` (keep `parser_version` for display).
- `full_sync_reason`: recorded format = `details.kb_format_version`, else **1** when `details.parser_version` has minor
  3 (F4), else "older parser". Full sync when recorded < current. When `KB_FORMAT` is `None`, use today's minor logic.
- `graph.py` stays self-contained (L4 contract §4) and must not add `from __future__ import annotations` if it has
  reducer keys (L-022).
- Tests in `workflows/sync-application/tests/test_incremental_sync.py`: format equal → incremental; recorded 0.3.0
  without format → incremental (no forced full sync); recorded format 1, current 2 → full; no details → full;
  `KB_FORMAT` missing → old behaviour. Bump the workflow version in `workflow.yaml` + `META` + `registry.json`.

## 4. genesis-workflows pins (D6)

`pyproject.toml`:

```toml
dependencies = [
  "genesis-core @ git+ssh://git@gitlab.appian-stratus.com/ramaswamy.u/genesis.git@v0.80.0#subdirectory=packages/genesis-core",
  "kiro-agent-sdk @ git+ssh://git@gitlab.appian-stratus.com/ramaswamy.u/genesis.git@v0.80.0#subdirectory=packages/kiro-agent-sdk",
]
[project.optional-dependencies]
dev = [
  "genesis @ git+ssh://git@gitlab.appian-stratus.com/ramaswamy.u/genesis.git@v0.80.0",
  "genesis-appian-parser @ git+ssh://git@gitlab.appian-stratus.com/ramaswamy.u/genesis.git@v0.80.0#subdirectory=packages/genesis-appian-parser",
  "pytest>=8", "pytest-asyncio>=0.23", "ruff==0.15.20",
]
```

- All four on the **same tag** (L-057). Pin `ruff==0.15.20` (today `>=0.6`, L-025/L-027) only if `ruff check` passes on
  the library unchanged; otherwise record it as a follow-up instead of churning workflow code.
- If 50-02 Q6 found four clones too slow, use the measured alternative recorded there.
- `registry.json`: `genesis_core_version` = `"0.80.0"`, `genesis_core_major` = `1`.
- `.gitlab-ci.yml` keeps its `insteadOf` rewrite (it now reaches the genesis repo); update its comment.
- The pinned tag does not exist until 50-09 tags genesis, so genesis-workflows' remote CI can only go green after
  that (the normal release order). Locally, gates run against `../genesis/.venv`.

## 5. Gates

genesis: `pytest -q` (incl. version sync), parser tests. genesis-workflows: `../genesis/.venv/bin/python
ci/validate_library.py`, `ci/validate_skills.py`, `pytest -q workflows --ignore=workflows/_fixtures`.

## 6. Acceptance

- [ ] Version-sync test passes and fails on a deliberate mismatch (shown once in the As built).
- [ ] `KB_FORMAT_VERSION` exported and pinned by a test.
- [ ] `sync-application` tests cover the five cases; no forced full sync for a KB built by parser 0.3.x.
- [ ] genesis-workflows pins all on one tag; `registry.json` updated.

## 7. As built

*(filled by genesis-dev)*

## Context manifest

```toml
areas    = ["parser", "kb-sync", "workflows-library", "core-engine", "release-ci"]
adrs     = ["ADR-006", "ADR-019", "ADR-036", "ADR-037", "ADR-074"]
lessons  = ["L-022", "L-025", "L-027", "L-050", "L-057", "L-081"]
docs     = ["tracker:specs/phase-50-platform-monorepo/50-01-findings.md", "tracker:specs/phase-45-incremental-delta-sync.md"]
code     = ["genesis/packages/genesis-appian-parser/genesis_appian_parser/__init__.py",
            "genesis/packages/genesis-core/genesis_core/types.py", "genesis/tests/test_version_sync.py",
            "genesis-workflows/workflows/sync-application/**", "genesis-workflows/pyproject.toml",
            "genesis-workflows/registry.json", "genesis-workflows/.gitlab-ci.yml"]
upstream = ["50-02", "50-03", "50-06"]
```
