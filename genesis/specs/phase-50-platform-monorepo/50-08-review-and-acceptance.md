# 50-08 — Review and acceptance

> **Status:** SPEC-DRAFTED 2026-10-31. Agent: **genesis-review** (never edits code); **genesis-release** pushes the
> scratch branches for CI, asking first. Repos: genesis, genesis-workflows, project-tracker. Parent:
> `specs/phase-50-platform-monorepo.md`. Reads every As built 50-02..50-07.

## 1. Code review

- `genesis-ctx check --since master --repo genesis` on `phase-50-monorepo`, and on genesis-workflows and
  project-tracker; answer each rule OK / VIOLATION / N/A.
- Specific checks: no internal dependency entry anywhere (D6); one file lists the four package paths (L-052); updater
  scope by path diff (F3); `KB_FORMAT_VERSION` fallback (F4); SDK lint fixes change no behaviour; the three subtree
  merges are not squashed; no secret or `.env` imported (D11 removed `.env.example`).
- Agent system: the recall check of 50-04 §3 is identical; `genesis-ctx lint` (full) green.

## 2. CI on the scratch branch (D7)

genesis-release pushes `phase-50-monorepo` of genesis to `origin` (ask first; a new branch, not `master`). The
pipeline must be green: `genesis`, `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser`, `frontend` (if web
changed), `clean-install`. Record the pipeline id. genesis-workflows CI cannot pass before the v0.80.0 tag exists
(50-07 §4); it runs in 50-09.

## 3. Live acceptance

| # | Check | Pass |
|---|---|---|
| 1 | Fresh clone of the pushed branch into a temp dir → `scripts/install.sh --dir <tmp> --branch phase-50-monorepo` with a temp state dir and a free port | Installs, migrates, `genesis up` serves the SPA (200) and `/api/config/health` |
| 2 | Missing library on that install | Uninstall `genesis-appian-parser` → `genesis status` exits 1 with one line naming `genesis_appian_parser` and the fix command (D15); reinstall with the script → works |
| 3 | `pip install --dry-run --report` of the install command | No index lookup for an internal name (D6) |
| 4 | Dev venv | `genesis_core.__file__`, `kiro_agent_sdk.__file__`, `genesis_appian_parser.__file__` are under `genesis/packages/`; the three parser-fixture tests **ran** (not skipped) in the pytest output |
| 5 | Fleet (main + userb) on the dev venv, after checking no run is active and backing up both instances' `genesis.db` + `memory.db` (D19) | Both healthy after a `gsm` restart on the branch code; a **`hello-appian`** run (one agent step) completes (proves the worker imports the libraries) |
| 6 | Incremental sync of a tracked app on main with `sync-application` 0.3.1 (installed on both instances before 50-08, D18; check `GET /api/workflows/sync-application` = 0.3.1) | Runs **incremental** (no forced full sync); `details.kb_format_version` = 1. A scheduled weekday sync on either instance since D18 counts as evidence: read its `kb_syncs` row instead of starting a new sync (D19: wait for the first one, Monday 2026-11-02, after the row 5 restart) |
| 7 | genesis-workflows local gates against the dev venv | validate_library, validate_skills, workflow tests green |
| 8 | Updater unit tests + a manual `genesis update --check` style read on a managed temp install | scope computed by path diff; no crash |
| 9 | `genesis-ctx status`, `pack 50-07`, `check --files genesis/packages/genesis-core/genesis_core/nodes/agent.py` | New repo set; core-engine rules load |

Headless limits: item 5's agent step needs a live Kiro login; if unavailable, give the manual check.

## 4. Output

`specs/phase-50-platform-monorepo/reviews/50-08-review.md` with SHIP / NEEDS_CHANGES, the checklist, the pipeline id
and the acceptance table. NEEDS_CHANGES items go back to genesis-dev as numbered hardening items in this file (§5).

## 5. Hardening items

### H1 — Guard against internal names in dependency lists (review M1; D19)

**Agent:** genesis-dev, on `phase-50-monorepo` in genesis and genesis-workflows. Then a focused re-review.
**Order:** H1 is built after the scratch-branch push (§2) and row 5; commit it on the same branch, and genesis-release
pushes the branch again so the H1 commit gets its own green pipeline before the final verdict.

- **genesis:** `tests/test_no_internal_dependencies.py` reads `pyproject.toml` and the three
  `packages/*/pyproject.toml` (`tomllib`). It fails, naming file and entry, if `[project].dependencies` or any
  `[project.optional-dependencies]` list names `genesis`, `genesis-core`, `kiro-agent-sdk` or
  `genesis-appian-parser` in any form: bare, version-pinned or direct reference. Compare PEP 503-normalized names
  (lower case, runs of `-_.` → `-`), and parse each requirement's name with the stdlib only (no new dependency).
- **genesis-workflows:** the same four names may appear **only** as direct `@ git+ssh://…/genesis.git@<tag>` references
  (with `#subdirectory=` for the libraries), all on the same tag (L-057). Add the check to `ci/validate_library.py`
  so the `library-validate` CI job enforces it.
- Evidence in the As built: each check passes, then fails once on a deliberate bad line (e.g. adding
  `"genesis-core>=0.79"` to the app's dependencies; a bare `genesis-core` in genesis-workflows), then is reverted.
- Gates: app `pytest -q` + `ruff check genesis`; genesis-workflows `ci/validate_library.py` + workflow tests.

## 6. As built

*(filled by genesis-review)*

## Context manifest

```toml
areas    = ["distribution", "release-ci", "core-engine", "sdk-acp", "parser", "kb-sync", "workflows-library", "runs-worker"]
adrs     = ["ADR-012", "ADR-019", "ADR-046", "ADR-074", "ADR-077"]
lessons  = ["L-030", "L-048", "L-051", "L-056", "L-057", "L-061", "L-089"]
docs     = ["tracker:specs/phase-50-platform-monorepo.md", "tracker:specs/phase-50-platform-monorepo/50-01-findings.md"]
code     = ["genesis/packages/**", "genesis/scripts/**", "genesis/genesis/runtime/updater.py", "genesis/.gitlab-ci.yml",
            "genesis-workflows/workflows/sync-application/**", "genesis-workflows/ci/validate_library.py",
            "genesis/tests/test_no_internal_dependencies.py", "tracker:context/areas.toml"]
upstream = ["50-02", "50-03", "50-04", "50-05", "50-06", "50-07"]
```
