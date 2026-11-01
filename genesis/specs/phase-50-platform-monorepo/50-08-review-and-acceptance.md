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

#### H1 — As built (genesis-dev, 2026-11-01)

**Commits** (local, on `phase-50-monorepo`; not pushed):
- genesis `77ea311` (base `34d6dab`): `test(50-08 H1): tests/test_no_internal_dependencies.py …`
- genesis-workflows `6968bb8` (base `7e42fc9`): `ci(50-08 H1): validate_library gate 9 …`

**Changed**
- genesis `tests/test_no_internal_dependencies.py` (new, 133 lines). `pyproject_paths()` = root + `packages/*/pyproject.toml`
  (a test pins the exact four paths, so a lost glob fails). `internal_entries()` reads each with `tomllib` and checks
  `[project].dependencies` and every `[project.optional-dependencies]` list. `requirement_name()` takes the PEP 508 name
  with one stdlib regex and PEP 503-normalizes it, so bare, pinned, extras, marker and `name @ url` forms are all
  caught. The failure lists `file [list]: 'entry'`. Also: 10 parse cases, 5 deliberate entries on a `tmp_path` copy
  (root deps, root deps by direct reference, root `embeddings` extra, genesis-core deps, parser `dev` extra; each must
  give exactly one hit), and `genesis-workflows` / `genesis-coreutils` must not be flagged.
- genesis-workflows `ci/validate_library.py`: gate 9 (docstring item 9). `check_internal_pins(project)` allows the four
  names only as `name @ git+ssh://…/genesis.git@vX.Y.Z`, with `#subdirectory=packages/<name>` for the libraries and none
  for the app, all on one repo and one tag. It is stdlib only (`re`, `tomllib`). `main()` runs it on `pyproject.toml`,
  then proves it rejects 9 known-bad `[project]` tables and accepts 1 good one. The output line is "OK: internal-pin
  check correctly rejects 9 known-bad tables and accepts a good one". The `library-validate` CI job already runs this
  script, so CI needed no change.

**Evidence: each check passes, fails once on a deliberate bad line, then is reverted.** Every edit, run and revert was
its own tool call. The working tree was verified clean in a separate call after each revert (L-089).

| Check | Pass | Deliberate bad line → failure | Reverted |
|---|---|---|---|
| genesis test | `18 passed` | root `pyproject.toml` + `"genesis-core>=0.79",` after `pypdf` → `test_no_pyproject_lists_an_internal_package` FAILED: `an internal package is listed as a dependency (D6) … pyproject.toml [project].dependencies: 'genesis-core>=0.79'`. The copy-based cases failed too, because they copy the dirty checkout | `git status` shows only the new test file; `18 passed` |
| genesis-workflows gate 9 (bare name) | `LIBRARY VALIDATION PASSED (14 workflow(s) validated)`, exit 0 | `"genesis-core",` first in `dependencies` → exit 1: `[pins] pyproject.toml [project].dependencies: 'genesis-core' — genesis-core must be a direct reference 'genesis-core @ git+ssh://…/genesis.git@vX.Y.Z#subdirectory=packages/genesis-core'` | only `ci/validate_library.py` modified; PASSED, exit 0 |
| gate 9 (L-057 tag split) | as above | parser pin `@v0.80.0` → `@v0.79.0` → exit 1: `the internal pins name different repos or tags — move them together (L-057): …@v0.79.0: genesis-appian-parser; …@v0.80.0: genesis-core, kiro-agent-sdk, genesis` | PASSED, exit 0 |
| gate 9 self-proof (review finding 1) | `rejects 9 known-bad tables and accepts a good one` | checker weakened `len(pins) > 1` → `> 2` → exit 1: `[pins] the internal-pin check unexpectedly ACCEPTED [{… v0.80.0 … v0.79.0 …}]` | `grep` shows `> 1`; PASSED, exit 0 |

**Tests / gates** (final tree): genesis `.venv/bin/python -m pytest -q` → **1418 passed** (1400 before, +18).
`ruff check genesis tests/test_no_internal_dependencies.py` → clean. genesis-workflows, run with the genesis venv:
`ci/validate_library.py` PASSED (14), `ci/validate_skills.py` PASSED (3), `pytest -q workflows --ignore=workflows/_fixtures`
→ 317 passed. `ruff check ci/validate_library.py` → clean, with the same finding count as at HEAD (0).

**Review:** `reviews/50-08-H1-review.md`, verdict **SHIP** (no blockers or majors).
- Minor 1 (the self-proof never exercised the L-057 split or the subdirectory paths) is **fixed** before commit.
  `_BAD_PINS` now holds whole tables, including a tag split, a repo split, a library under another library's subdir and
  the app with a subdir, plus `_GOOD_PINS`. The weakened-checker row above proves the fix. The reviewer's terms needed
  only a validator re-run, not a re-review.
- Nit 4 is **done**: the test docstring says a self-referential extra such as `genesis[embeddings]` is flagged on
  purpose (fail closed).
- Minor 2 and nit 3 are **not done** (optional; see Lesson candidates / follow-ups).

**Decisions / deviations** (no ADR deviation):
- The tag must be `vX.Y.Z`, not a branch or sha. The subdirectory must equal `packages/<name>`. All pins must share the
  repo URL as well as the tag. Each of these is stricter than the spec's wording; the reviewer agreed.
- The ~5-line PEP 508 name regex is duplicated in both repos instead of shared. Sharing it would make genesis-workflows
  CI depend on a genesis release that contains the helper.
- genesis-workflows has no pytest file for gate 9. It proves itself in-process, like gate 6's non-compliant fixture.

**Follow-ups (not built):**
- Review minor 2: in CI, gate 9 runs only after `pip install -e ".[dev]"`, because the validator imports `genesis.lint`
  at module top. A name-only pin is therefore still fetched from public PyPI on the runner before the job goes red. The
  merge is still blocked. A fix is a stdlib-only pin step before the install.
- Review nit 3: the host is not pinned. Any `…/genesis.git` host passes, as long as all four pins agree.

**Lesson candidates:** a self-proof for a checker must cover every rule the checker exists for, including the
cross-entry ones. The first version proved only the per-entry paths, and a broken L-057 grouping would have passed CI.

**Code-map changes:** genesis `tests/test_no_internal_dependencies.py` (D6 guard). genesis-workflows
`ci/validate_library.py` gains gate 9 (internal pins).

**Next (not this item):** genesis-release pushes `phase-50-monorepo` of genesis again, after asking, so `77ea311` gets
its own green pipeline. Then comes the focused re-review entry in `50-08-review.md` and row 6. genesis-workflows CI
still waits for the v0.80.0 tag (50-07 §4 / 50-09). The fleet was not touched.

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
