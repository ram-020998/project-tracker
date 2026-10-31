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
- **Library test tools (50-06 review follow-up).** The library CI jobs get pytest/ruff only because the app's `dev`
  extra happens to cover every library's `dev` extra. Fix at the root: `scripts/install-packages.sh --dev` installs
  **each** path with its `[dev]` extra (`./packages/genesis-core[dev]` etc., plus `.[dev]`), still in one pip command.
  The libraries that have no `dev` extra get one (pytest + the pinned ruff) so every path takes `[dev]`. Prove it in
  a fresh venv with `pip install --dry-run --report`, and that `pip check` stays clean.

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

- [x] Version-sync test passes and fails on a deliberate mismatch (shown once in the As built).
- [x] `install-packages.sh --dev` installs every package's own `[dev]` extra; the four CI package jobs still pass.
- [x] `KB_FORMAT_VERSION` exported and pinned by a test.
- [x] `sync-application` tests cover the five cases; no forced full sync for a KB built by parser 0.3.x.
- [x] genesis-workflows pins all on one tag; `registry.json` updated.
- [ ] Untested by the spike (50-02 deviations), proven here or in 50-09: a **tag** ref combined with
      `#subdirectory=` (locally against a scratch tag the user creates, or in 50-09 once v0.80.0 exists), and the
      **HTTPS** partial clone that CI's `insteadOf` token rewrite uses (genesis-workflows' first CI run, 50-09 §1).

## 7. As built

**Verdict: SHIP** (`reviews/50-07-review.md`; genesis base `012b59c`, genesis-workflows base `04c242e`). Local commits
only; the 50-03 hold stands (nothing pushed or tagged). Start: genesis `phase-50-monorepo` at `012b59c`, dirty 0;
genesis-workflows `master` at `04c242e` (= v0.23.0), dirty 0, from which local branch `phase-50-monorepo` was created.

### Commits

| Repo | SHA | What |
|---|---|---|
| genesis | `fb4a160` | Shared version 0.79.0 in `packages/*/pyproject.toml` + parser `__version__`; `tests/test_version_sync.py`; `KB_FORMAT_VERSION = 1` + `packages/genesis-appian-parser/tests/test_kb_format_version.py`; `CORE_MAJOR` comment |
| genesis | `34d6dab` | `scripts/install-packages.sh --dev` → every path with its own `[dev]`; `tests/test_install_packages_script.py`; CI comment |
| genesis-workflows | `bc1124c` | sync-application 0.3.1 KB-format check; pins to `genesis.git@v0.80.0`; `registry.json`; CI comment |
| genesis-workflows | `7e42fc9` | Review n1: "kb format unknown, need N" fallback reason |

### Changed

- **genesis `packages/*/pyproject.toml`**: genesis-core 0.9.8 → 0.79.0, kiro-agent-sdk 0.7.1 → 0.79.0, parser 0.3.0 →
  0.79.0, each with a comment that it is the shared version (D8). genesis-core's "follows semver; MAJOR version is the
  compat-gate key" comment is replaced: the version is the shared one, the compat gate is `CORE_MAJOR`.
- **`genesis_appian_parser/__init__.py`**: `__version__ = "0.79.0"`; `KB_FORMAT_VERSION = 1` with the bump rule, in
  `__all__`.
- **`genesis_core/types.py:7-12`**: `CORE_MAJOR = 1` unchanged; the comment says it is independent of the package
  version (ADR-019 as amended by ADR-080).
- **`tests/test_version_sync.py`** (new): reads the seven sources as text (`tomllib` for the four pyprojects, `ast` for
  the parser `__version__`, a regex for `FastAPI(title="Genesis", version=…)` and `GENESIS_VERSION`) and fails with one
  line per mismatch. Collected by the `genesis` CI job (`testpaths = ["tests"]`, 50-06).
- **`scripts/install-packages.sh`**: `--dev` appends `[dev]` to every path (`-e ./packages/<name>[dev] … -e .[dev]`,
  still one pip command); `--help` text updated. All three libraries already had a `dev` extra with pytest and
  `ruff==0.15.20`, so none needed adding. `.gitlab-ci.yml`: comment only.
- **genesis-workflows `workflows/sync-application/graph.py`**: `KB_FORMAT = getattr(_gap, "KB_FORMAT_VERSION", None)`;
  `_recorded_kb_format(details)` (`kb_format_version`, else 1 when `parser_version` ≥ 0.3, else None);
  `full_sync_reason` compares formats when `KB_FORMAT` is set and keeps the Phase 45 minor rule when it is None;
  `_sync_details` and the present summary record `kb_format_version` (omitted when None). META/`workflow.yaml`/
  `registry.json` 0.3.0 → **0.3.1**; `write_kb` description and README updated. No reducer keys, so
  `from __future__ import annotations` stays (L-022); still self-contained.
- **genesis-workflows `pyproject.toml`**: runtime `genesis-core` + `kiro-agent-sdk`, dev `genesis` +
  `genesis-appian-parser`, all `git+ssh://…/genesis.git@v0.80.0[#subdirectory=packages/<name>]` (one tag, L-057; parsed
  with `packaging.requirements`: one ref `{'v0.80.0'}`). `pyyaml`/`jsonschema` kept in dev. `registry.json`:
  `genesis_core_version` "0.80.0", `genesis_core_major` 1. `.gitlab-ci.yml`: `insteadOf` kept, comment updated.

### Tests

Fresh venv `/tmp/g5007/ve` (python3.13, pip 25.1.1) for the genesis gates; `../genesis/.venv` for genesis-workflows.

| Gate | Result |
|---|---|
| `pip install --dry-run --ignore-installed --report` of the four `-e <path>[dev]` | each `requested_extras ['dev']` from its own `file://` folder, 0.79.0; ruff 0.15.20, pytest, pytest-asyncio resolved |
| `scripts/install-packages.sh --editable --dev --python /tmp/g5007/ve/bin/python` | exit 0; `pip check` "No broken requirements found."; all four editable at 0.79.0 under `genesis/` |
| `genesis` job: `ruff check genesis` / `pytest -q -rs` | clean / **1400 passed**, 0 skipped (198 s) = 1389 (50-06, sibling checkout present) + 11 new |
| `genesis-core` job: `ruff check genesis_core` / `pytest -q -p no:warnings` | clean / **96 passed** |
| `kiro-agent-sdk` job: `ruff check src tests` / `pytest -q` | clean / **79 passed** |
| `genesis-appian-parser` job: `ruff check .` / `pytest -q` | clean / **53 passed, 1 skipped** (51 + 2 new; skip `test_diff_hash.py:39`) |
| `shellcheck scripts/install-packages.sh` | clean |
| genesis-workflows `ci/validate_library.py` / `ci/validate_skills.py` | PASSED (14) / PASSED (3) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **317 passed** (305 + 12 new) |

**Deliberate mismatch, shown once on the real checkout** (`web/src/version.ts` set to 0.79.1, then reverted;
`git status` clean afterwards):
```
E       AssertionError: version mismatch — bump all of them together:
E         web/src/version.ts GENESIS_VERSION: '0.79.1' (app pyproject.toml: '0.79.0')
1 failed in 0.03s
```

New tests: version sync (6: the real check, a mismatch in four sources on a copy, a source with no version);
install script (5: editable and non-editable `--dev` argv, every package's dev extra has pytest + `ruff==0.15.20`);
parser (2: pinned value, exported); sync-application (12: the five spec cases plus 0.3.7/0.79.0 without a format,
< 0.3 without a format, and three end-to-end runs: format 1 → 2 forces full and records 2; a baseline recorded as
parser 0.3.0 with no format stays incremental; `KB_FORMAT` None keeps the minor rule and records no format). Run
against the old `graph.py` (`git stash` of that file only, then restored): 15 failed, including the F4 end-to-end case.

### Review

`reviews/50-07-review.md` — **SHIP**, no blockers or majors; the reviewer re-ran every gate with the same counts.
Nit 1 fixed (`7e42fc9`; 317 passed, `validate_library` PASSED after it). Nit 2 (web type `kb_format_version`) not
taken: nothing reads it and it would need a web build; for whoever first shows it (L-011). Minor 1 is recorded below
and carried to 50-09.

### Decisions / deviations

- **`>= 0.3` instead of "minor 3"** for a recorded `parser_version` without `kb_format_version` (§3). A KB from
  parser ≥ 0.3 is at least format 1 (0.3.x is format 1; no 0.4–0.78 exists; 0.79/0.80 carry the same parse code).
  The rule can only cause one extra full sync after a future bump, never skip a needed one. It avoids a second full
  sync for records written by an old sync-application 0.3.0 on the new parser (`parser_version` "0.79.0"/"0.80.0").
  Reviewer agreed.
- **genesis-workflows ruff not pinned** (§4 allows it): ruff 0.15.20 `ruff check .` reports 20 pre-existing findings
  (9 E702, 8 F401, 2 E701, 1 F841; none in changed lines) and that repo's CI runs no ruff, so L-027's condition does
  not apply. **Follow-up:** fix the 20 findings, then pin `ruff==0.15.20` (comment at `pyproject.toml:30`).
- `pyyaml>=6`, `jsonschema>=4` kept in genesis-workflows' dev extra (the spec snippet omits them; the CI validators
  use them).
- The shared dev venv `genesis/.venv` was **not** reinstalled (the fleet runs from it); its editable metadata still
  says 0.9.8 / 0.7.1 / 0.3.0 / 0.79.0. The code it imports is current. 50-09's fleet update reinstalls it.
- Not proven here (§6, left to 50-09 §1): a **tag** ref with `#subdirectory=` (genesis-dev cannot create tags;
  v0.80.0 does not exist) and the HTTPS partial clone through CI's `insteadOf`. That acceptance box stays open.
- A background run of the app suite was killed silently at the tool's 120 s timeout (as in 50-06); the foreground
  run above is the evidence.
- No ADR deviation. D8's ADR-019 amendment (ADR-080, proposed) is reflected in comments only; genesis-docs writes it.

### Minor 1 (review): the dev fleet is already in the skew window — carry to 50-09

The fleet (:8760/:8761) runs `genesis/.venv`, which imports the parser editable from this branch checkout, so its
workers now see parser `__version__` **0.79.0** while the installed library is still sync-application **0.3.0**
(`~/.genesis/library/workflows/sync-application/workflow.yaml`). 0.3.0 compares parser minors (0.3 vs 0.79), so
**the next sync of every app on either instance, manual or scheduled, will be a full re-export** ("kb built by an older
parser (need >= 0.79.0)"). The result is correct and 0.3.1 then reads that record as format 1, so it happens at most
once per app. The default schedule runs on weekdays (ADR-074), and 2026-11-01 is a Sunday. Options for the user:
accept it; disable the scheduled sync until 50-09; or install sync-application 0.3.1 on the fleet early (a fleet
mutation, needs a yes). In 50-09, install 0.3.1 in the same step as the v0.80.0 fleet update.

### Lesson candidates

- When a version string feeds behaviour (here, a full-sync rule), unify versions only after the behaviour has its own
  constant, and remember that an editable dev venv makes the version bump live for every process using that venv on
  the commit, not at release.
- Map "no recorded marker" to the lowest format the recorded evidence guarantees (≥ 0.3 → format 1), not to an exact
  version match: that mapping can only cause an extra full sync, never skip one.
- L-089 recurrence: the project-tracker As built edit, `git add` and `git commit` went out in one tool batch. The
  commit (`2329322`) turned out complete (`git diff` empty afterwards), but a batched status read showed a stale view.

### Code-map changes (for genesis-docs)

- `genesis/packages/genesis-appian-parser/genesis_appian_parser/__init__.py`: `KB_FORMAT_VERSION` (parse-output
  format; bump only when a full re-sync is needed; 1 = parser 0.3.x).
- `genesis/tests/test_version_sync.py`: the shared-version check over the seven sources (D8/F5).
- `genesis/scripts/install-packages.sh`: `--dev` = each path with its own `[dev]` extra.
- `genesis-workflows/workflows/sync-application/graph.py` (0.3.1): `KB_FORMAT`, `_recorded_kb_format`,
  `full_sync_reason` format rule; `kb_syncs.details.kb_format_version`.
- `genesis-workflows/pyproject.toml`: four pins on one `genesis.git` tag by `#subdirectory`; `registry.json`
  `genesis_core_version` follows the shared version.
- Scratch: `/tmp/g5007/` (fresh venv, report, log) can be deleted.

## Context manifest

```toml
areas    = ["parser", "kb-sync", "workflows-library", "core-engine", "release-ci", "distribution"]
adrs     = ["ADR-006", "ADR-019", "ADR-036", "ADR-037", "ADR-074"]
lessons  = ["L-022", "L-025", "L-027", "L-050", "L-052", "L-057", "L-081"]
docs     = ["tracker:specs/phase-50-platform-monorepo/50-01-findings.md", "tracker:specs/phase-45-incremental-delta-sync.md"]
code     = ["genesis/scripts/install-packages.sh", "genesis/packages/*/pyproject.toml",
            "genesis/packages/genesis-appian-parser/genesis_appian_parser/__init__.py",
            "genesis/packages/genesis-core/genesis_core/types.py", "genesis/tests/test_version_sync.py",
            "genesis-workflows/workflows/sync-application/**", "genesis-workflows/pyproject.toml",
            "genesis-workflows/registry.json", "genesis-workflows/.gitlab-ci.yml"]
upstream = ["50-02", "50-03", "50-06"]
```
