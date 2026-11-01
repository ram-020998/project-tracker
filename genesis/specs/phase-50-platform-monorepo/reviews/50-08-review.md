# Review 50-08 — Phase 50 whole-phase review and acceptance (genesis-review, 2026-11-01)

> **Status: IN PROGRESS — code review, §2 CI (pipeline #7258881, green) and rows 1–5, 7–9 done; H1 and row 6 open
> (D19).** The verdict stays pending until H1 is built and re-reviewed.

Ranges reviewed:

| Repo | Base | Head | Commits |
|---|---|---|---|
| genesis | `908e5d4` (= `master` = `origin/master` = v0.79.0) | `34d6dab` (`phase-50-monorepo`, dirty 0) | 13 first-parent (3 subtree merges + 10) |
| genesis-workflows | `04c242e` (= `master` = v0.23.0) | `7e42fc9` (`phase-50-monorepo`, dirty 0) | 2 |
| project-tracker | `ab93480` (Phase 49 write-back) | `382a417` (`main`) | agent-system code in `34aaec6`; the rest is specs |

`genesis-ctx check --since 908e5d4 --repo genesis` (146 files; areas chat, core-engine, distribution, parser,
release-ci, sdk-acp, security), `--since 04c242e --repo genesis-workflows` (7 files; release-ci, security,
workflows-library), `--since ab93480` (project-tracker, 36 `tracker:` files; release-ci, security).
`--repo project-tracker` is not accepted by the tool (exit 2, "repo not found"); the form without `--repo` works.

## What I verified myself

**History (D7).** Each subtree merge is an unsquashed two-parent merge in a linear first-parent chain:
`c8c6982` = `908e5d4` + `b68438c`, `40c4a8e` = `c8c6982` + `e5c99ca`, `1cada22` = `40c4a8e` + `10e412a`. The
second parents equal the library tags (`v0.7.1^{commit}` = `b68438c`, `v0.9.8` = `e5c99ca`, `v0.3.0` = `10e412a`),
and each merge's prefix tree equals the library tree (`56342ad…`, `6b65aad…`, `897f398…`, compared with
`git rev-parse <merge>:packages/<name>` against `<tip>^{tree}`). `git diff 908e5d4 1cada22 -- . ':!packages'` is
empty, so the merges touched nothing outside `packages/`.

**What changed in the libraries after the merges** (`git diff --stat 1cada22 HEAD -- packages/*/<src> packages/*/tests`):
kiro-agent-sdk `src/` **unchanged**, only `tests/test_erd_workflow.py` deleted (POC, D11); genesis-core only
`genesis_core/types.py` (comment around `CORE_MAJOR = 1`); the parser only `__init__.py` (`__version__`,
`KB_FORMAT_VERSION`) + the new `tests/test_kb_format_version.py`. Everything else under `packages/` is
`pyproject.toml`, `README.md`, the two deleted library `.gitlab-ci.yml` files and the SDK POC files. So every
core-engine / sdk-acp / parser rule in the checklist governs code that is byte-identical to the released library
tags; they are answered N/A ("moved verbatim") unless a line above touches them.

**No internal dependency entry (D6).** `git grep -nE 'git\+ssh|genesis-core *[@=<>]|kiro-agent-sdk *[@=<>]|
genesis-appian-parser *[@=<>]|"genesis[ @=<>]' HEAD -- '*.toml' '*.cfg' '*.txt' '*.yml' '*.sh'` in genesis → no
dependency hit (two unrelated `genesis binary`/`entry point` strings in shell scripts). `allow-direct-references`
is gone from both hatch configs.

**One file lists the four paths (L-052).** `git grep -l packages/genesis-appian-parser HEAD -- . ':!packages'` →
`scripts/install-packages.sh` (the list), `.gitlab-ci.yml` and `README.md` (`cd packages/<name>` gate lines only),
and tests/fixture paths. No second install list.

**No secret or `.env` imported (D11).** `git ls-tree -r HEAD` has no `.env*` file. The SDK `.env.example` was
imported by the unsquashed merge and deleted in `8706a50`; it stays in history, and its content is placeholders:
every token/key/password value is empty, the two non-empty values are `ATLAS_KB_PROJECT_ID=13490` and
`ATLAS_DATA_PREFIX=ai-framework/tools/Atlas/solutions-kb/data` (an id and a path, not secrets).
`git log -G '(api[_-]?key|token|password)\s*=\s*["'"'"'][A-Za-z0-9_-]{12,}' 908e5d4..HEAD -- packages` → nothing.

**Updater scope by path diff (F3).** `_scope` (`genesis/runtime/updater.py:151-167`) runs `git diff --name-only
v<current>..<tag>` and returns `deps` for the root `pyproject.toml`, `scripts/install-packages.sh` or `packages/…`,
else `code`, and `deps` on any git failure. `apply()` runs the target tag's script with `sys.executable`, `cwd=repo`.
Unit tests `tests/test_updater.py::test_scope_*` pass (in the 1400). Live read on a managed throwaway install:
row 8 below.

**`KB_FORMAT_VERSION` fallback (F4).** `sync-application/graph.py:56` `KB_FORMAT = getattr(_gap,
"KB_FORMAT_VERSION", None)`; `_recorded_kb_format` (`:201-211`) = `details.kb_format_version`, else 1 when
`parser_version` ≥ 0.3, else None; `full_sync_reason` (`:213-245`) compares formats, and keeps the Phase 45 minor rule
when `KB_FORMAT` is None. Main's last full sync (`kb_syncs` 50, 2026-10-30, `parser_version` 0.3.0, no
`kb_format_version`) therefore reads as format 1 = current → incremental, which row 6 should confirm live.

**Shared version (D8/F5).** `tests/test_version_sync.py` reads the four pyprojects, the parser `__version__`, the
`create_app` version and `web/src/version.ts`; all 0.79.0. `git grep -nE '__version__|0\.9\.8|0\.7\.1|"0\.3\.0"'`
over `packages genesis web/src scripts pyproject.toml` finds no stale library version (only a web test fixture's
unrelated workflow version "0.3.0"). genesis-core and the SDK have no `__version__`, so nothing is missed by the test.

**Agent system (D12).** Recall check of 50-04 §3 re-run on the new paths with `check --files … --json`, one call per
library, compared id by id with the lists recorded in 50-04 §5: **identical** — core `nodes/agent.py` 40 ADRs + 31
lessons, SDK `client.py` 34 + 31, parser `__init__.py` 14 + 21; areas core-engine / chat+sdk-acp / parser as before.
`genesis-ctx lint` (full): **0 errors, 0 warnings**, L0 ~22,875 / 24,000. `agent-system/tests`: **247 passed**.
`update.sh --dry-run`: "0 added · 0 changed · 0 removed · 21 unchanged" (the installed system matches the source).
`grep` over `agent-system/skills`, `agents`, `OPERATOR_GUIDE.md` for old-repo paths, `git+ssh` or `cd genesis-core`
style commands → nothing.

## Gates (run by me, dev venv `genesis/.venv`, ruff 0.15.20)

| Gate | Result | Author's claim |
|---|---|---|
| `cd genesis && .venv/bin/ruff check genesis` | All checks passed | same |
| `cd genesis && .venv/bin/python -m pytest -q -p no:warnings -rs` | **1400 passed**, 0 skipped (302 s) | 1400 (50-07) |
| `cd genesis/packages/genesis-core && ruff check genesis_core` / `pytest -q -p no:warnings` | clean / **96 passed** | 96 |
| `cd genesis/packages/kiro-agent-sdk && ruff check src tests` / `pytest -q` | clean / **79 passed** | 79 |
| `cd genesis/packages/genesis-appian-parser && ruff check .` / `pytest -q` | clean / **53 passed, 1 skipped** (`test_diff_hash.py:39`, as since 50-03) | 53 + 1 |
| genesis-workflows `ci/validate_library.py` / `ci/validate_skills.py` | PASSED (14) / PASSED (3) | same |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **317 passed** | 317 |
| `genesis-ctx lint` (full) / `agent-system/tests` | 0 errors 0 warnings / **247 passed** | same |
| web (`lint`, `typecheck`, `test`, `build`) | **N/A**: `git diff --stat 908e5d4 HEAD -- web` is empty; the gates appear only because the SDK path is in the `chat` area | — |

## Checklist — genesis (`908e5d4..34d6dab`)

ADRs
- [OK] ADR-001 LangGraph owns control flow — no graph/orchestration code changed (library code verbatim, see above).
- [N/A] ADR-002, ADR-004, ADR-020 per-node MCP over ACP, no global `mcp.json` — SDK `src/` unchanged; core `nodes/agent.py` unchanged.
- [OK] ADR-003 local web app pulling workflows from GitLab — unchanged; install clones only genesis (`scripts/install.sh:30`).
- [N/A] ADR-005, ADR-029 MCP/CLI registry tiers — not touched.
- [OK] ADR-006 workflow packages + lockfile — `genesis install`/loader unchanged (`git diff --stat 908e5d4 HEAD -- genesis/dist` empty).
- [N/A] ADR-007 roles — not touched.
- [N/A] ADR-009, ADR-021, ADR-025 HITL modes / gates / fork — not touched.
- [N/A] ADR-010, ADR-018, ADR-022 state/blackboard/artifacts — not touched.
- [N/A] ADR-011 reliability trio — no agent node added or changed; `validate_library` reliability lint PASSED.
- [OK] ADR-012 subprocess worker; app never imports workflow Python — `cli/main.py` adds only `importlib.util.find_spec` for the three libraries (stdlib, no workflow import).
- [OK] ADR-016 names — package names unchanged (`genesis`, `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser`).
- [OK] ADR-017, ADR-024 Python 3.13 — SDK raised to `requires-python = ">=3.13"` (`packages/kiro-agent-sdk/pyproject.toml`), CI image `python:3.13` for every job.
- [OK] ADR-019 `CORE_MAJOR` gate — `CORE_MAJOR = 1` unchanged (`genesis_core/types.py:12`); comment states it is independent of the pip version. The pip version no longer follows semver: the user-approved amendment D8/D14 (ADR-080, proposed; genesis-docs records it in 50-09).
- [N/A] ADR-023 FastAPI embedding LangGraph — not touched.
- [OK] ADR-026 loopback only — no bind change; throwaway server served on 127.0.0.1 (row 1).
- [N/A] ADR-027, ADR-055 web stack/design — no web change.
- [N/A] ADR-030, ADR-041, ADR-054 persistence/documents/memory DB — no DB change (DB v25 migrations 1–25 applied by the throwaway install, row 1).
- [N/A] ADR-031, ADR-032, ADR-033, ADR-034, ADR-035, ADR-045, ADR-053, ADR-069 chat/credits/skills/inputs — SDK and chat code unchanged.
- [OK] ADR-036, ADR-037, ADR-073, ADR-074 KB from the dev env, code-free, package tools only in program code, incremental — parser code unchanged except two constants; the KB-sync behaviour change is in genesis-workflows (below).
- [N/A] ADR-038, ADR-040 managed-native installs — not touched.
- [N/A] ADR-039, ADR-042, ADR-047, ADR-050, ADR-051, ADR-059, ADR-060, ADR-061, ADR-062, ADR-063, ADR-065, ADR-066, ADR-067, ADR-068, ADR-075, ADR-076 — governed code not touched (verbatim move).
- [OK] ADR-046 clone + venv + install + `genesis up` + git-tag self-update — still holds, with the install step = `scripts/install-packages.sh` (approved amendment D14, ADR-080 proposed). Proven on a throwaway non-editable install (row 1 rehearsal) and the updater read (row 8).
- [OK] ADR-077 agent context — globs repointed, recall identical, never `--trust-all-tools` (profiles unchanged by 50-04; `update.sh --dry-run` 21 unchanged).

Lessons
- [N/A] L-001, L-002, L-016, L-017, L-018, L-020, L-021, L-022, L-023, L-024, L-026, L-029, L-031, L-032, L-035, L-036, L-037, L-038, L-041, L-042, L-044, L-045, L-046, L-047, L-049, L-050, L-058, L-059, L-064, L-065, L-068, L-069, L-073, L-075, L-076, L-077, L-079, L-086, L-093 — the code they govern is unchanged.
- [OK] L-004 SQLite data plane — unchanged.
- [OK] L-005, L-006, L-007 events/topology/transcript — unchanged.
- [OK] L-009 — no engine change.
- [OK] L-025, L-027 pinned ruff — `ruff==0.15.20` in every genesis-repo package's `dev` extra (asserted by `test_every_package_declares_a_dev_extra_with_its_test_tools`); genesis-workflows: see its checklist.
- [OK] L-030 frontend job rule — `frontend` byte-identical in `.gitlab-ci.yml`; no web change in this phase; the 50-09 version bump touches `web/src/version.ts`, so the release tag will run it.
- [OK] L-033 install before run — unchanged; D18 install done that way.
- [OK] L-048 SPA as package data — the non-editable throwaway install serves `GET /` 200 `<title>Genesis</title>` (row 1 rehearsal).
- [OK] L-051 clone + git-tag self-update — `genesis update --check-only` works on a managed throwaway install (row 8).
- [OK] L-052 one place — `scripts/install-packages.sh` is the only four-path list; `install.sh:140`, `updater.py:244-246`, CI `before_script` and README call it (`test_installer_calls_the_script`).
- [OK] L-056 — no tag in this sub-spec; 50-09 must check `git status` before tagging.
- [OK] L-057 — genesis has no internal pins left; genesis-workflows pins all four on one tag (below).
- [OK] L-061 — fleet not restarted so far; active runs checked (0 on both) before any fleet step.
- [OK] L-087 — code-map/bible headers moved by script (50-04).
- [OK] L-088 — shell guard active (it refused a `git tag` in a throwaway clone during this review).
- [OK] L-089 — dependent steps in this review run one per call; author recurrences are recorded in 50-03/50-04/50-07 As built for the 50-09 write-back.
- [OK] L-092 — new tests have unique module names; root `testpaths = ["tests"]` keeps package tests out of the app run.

Gates — all green (table above); web N/A.

## Checklist — genesis-workflows (`04c242e..7e42fc9`)

- [OK] ADR-001, ADR-010, ADR-018, ADR-022 — `sync-application` stays a deterministic program graph; only `full_sync_reason` and the recorded details change.
- [OK] ADR-006, ADR-014 — META/`workflow.yaml`/`registry.json` all 0.3.1; `validate_library` PASSED (parity lint).
- [OK] ADR-011 — no agent node; reliability lint PASSED.
- [OK] ADR-012 — `graph.py` self-contained (imports only stdlib, langgraph/langchain_core, `genesis_core`, `genesis_appian_parser`).
- [OK] ADR-019 — `registry.json` `genesis_core_major` 1; `genesis_core_version` "0.80.0" is informational (the loader checks the major only, `genesis/dist/loader.py:43-45`).
- [OK] ADR-037, ADR-073, ADR-074 — incremental path unchanged; a KB built by parser ≥ 0.3 is not forced to a full sync (`test_incremental_sync.py`, 12 new tests).
- [N/A] ADR-003, ADR-005, ADR-007, ADR-015, ADR-017, ADR-020, ADR-021, ADR-026, ADR-029, ADR-030, ADR-031, ADR-033, ADR-034, ADR-035, ADR-036, ADR-038, ADR-039, ADR-041, ADR-045, ADR-048, ADR-056, ADR-057, ADR-058, ADR-059, ADR-061, ADR-062, ADR-063, ADR-065, ADR-067, ADR-068, ADR-069, ADR-075, ADR-076, ADR-078 — not touched.
- [OK] ADR-077 — workflows-library routing unchanged for this repo; D16 paths added.
- [OK] L-006, L-013 — `graph:` topology node ids unchanged; only a description string changed.
- [OK] L-022 — `from __future__ import annotations` (`graph.py:36`) with no reducer keys (no `Annotated`/`operator.add`).
- [OK] L-025/L-027 — genesis-workflows CI runs no `ruff check`, so the pin rule does not apply; `ruff>=0.6` kept with a comment and a backlog item (20 pre-existing findings).
- [OK] L-057 — four pins on one ref `v0.80.0` (`pyproject.toml:17-18,24-25`); `registry.json` follows.
- [N/A] L-009, L-017, L-020, L-021, L-023, L-024, L-026, L-029, L-030, L-033, L-042, L-045, L-049, L-051, L-053, L-064, L-075, L-076, L-087, L-088, L-092 — not touched.
- [OK] L-056, L-089 — see genesis.
- Gates: `validate_library` PASSED (14), `validate_skills` PASSED (3), workflow pytest 317 passed; `cd genesis` app gates green (above).

## Checklist — project-tracker (`ab93480..382a417`)

- [OK] ADR-077 — rules still selected by program: `areas.toml` globs repointed; `area-glob-empty` is now an error (`lint.py:64-66`); recall identical; lint green.
- [OK] L-087 — 8 + 11 lines moved by script (50-04 As built); lint's code-map/bible lockstep check green.
- [OK] L-088 — PreToolUse guard untouched and working.
- [OK] L-089 — the 50-04 batch recurrence is recorded for 50-09.
- [OK] L-025/L-027 — n/a to the tracker (no ruff in its CI).
- [N/A] ADR-011, ADR-026, ADR-063, ADR-065, ADR-074, L-017, L-030, L-045, L-051, L-056, L-057, L-092 — no governed code in the tracker diff.
- Gates: none defined for these areas; `genesis-ctx lint` + `agent-system/tests` run anyway (green).

## Live acceptance (§3)

Evidence folder: `/tmp/genesis-review/50-08/`. Throwaway files: `/tmp/g5008/` (local clone of the branch, venv,
state dirs, scripts).

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Fresh clone of the **pushed** branch → `install.sh --dir <tmp> --branch phase-50-monorepo`, temp state, free port | **PASS**. `install.sh` taken from `origin/phase-50-monorepo` (`git show …:scripts/install.sh`, outside any checkout, so its step 3 clones) and run as `GENESIS_STATE_DIR=/tmp/g5008/r1/state GENESIS_ARTIFACTS_DIR=/tmp/g5008/r1/runs install.sh --dir /tmp/g5008/r1/genesis --branch phase-50-monorepo` → exit 0: SSH preflight "✓ genesis" (one repo); cloned `git@gitlab.appian-stratus.com:ramaswamy.u/genesis.git`, branch `phase-50-monorepo`, HEAD `34d6dab`; step 5 printed the one command `…/.venv/bin/python -m pip install ./packages/kiro-agent-sdk ./packages/genesis-core ./packages/genesis-appian-parser .` and installed genesis, genesis-core, kiro-agent-sdk, genesis-appian-parser all 0.79.0; migrations 1–25 + memory.db 1 ("schema version: 25"); `dist.json` = repo `/tmp/g5008/r1/genesis`, branch `phase-50-monorepo`, remote `origin`. `pip check` clean, `pip list --editable` empty, libraries import from the venv's `site-packages` (parser 0.79.0, format 1). `genesis up --port 8796` → `GET /` 200 `<title>Genesis</title>`, `/api/config/health` 200, openapi 0.79.0; `genesis down` "Stopped.", `GET /` 000. (The earlier local-clone rehearsal gave the same results.) | `row1-install.log`, `row1-serve.txt`, `row1-local-serve.txt` |
| 2 | Missing library | **PASS** on the throwaway install: `pip uninstall genesis-appian-parser` → `genesis status` exit 1, stdout empty, stderr one line `Missing Genesis packages: genesis-appian-parser. Run scripts/install-packages.sh from the genesis repo.`; reinstall with the script → exit 0, `genesis status` "○ stopped" exit 0, parser 0.79.0 / format 1 importable. The message names the `packages/` folder name, not the import name `genesis_appian_parser`: the 50-03 deviation, accepted then (matches the folder and the script) | this report |
| 3 | `pip install --dry-run --report` of the install command | **PASS**: fresh venv, `pip install -v --dry-run --ignore-installed --report` of the four paths, exit 0; the four internal distributions resolve from `file:///…/packages/<name>` and `file:///…/clone` at 0.79.0, `requested: true`; none of the 68 resolved distributions has a `requires_dist` naming an internal package, so pip has no reason to query an index for one; the verbose log shows no `/simple/<internal>/` URL | `/tmp/g5008/report.json`, `/tmp/g5008/dryrun.log` |
| 4 | Dev venv | **PASS**: `genesis_core`, `kiro_agent_sdk`, `genesis_appian_parser` `__file__` under `genesis/packages/…`; the three parser-fixture tests ran (`test_kb_store.py`, `test_kb_incremental.py`, `test_kb_server.py::test_real_package_via_server` in a 50-passed run; full app run 1400 passed, 0 skipped with `-rs`) | this report |
| 5 | Fleet on the dev venv + a workflow run with an agent step (D19 (2): back up, restart with `gsm`, `hello-appian`) | **PASS**. Before: `GET /api/runs?status=active` total 0 on :8760 and :8761; the servers (pids 87926/87938) had started Sat 31 Oct 19:42, before the branch's first commit (`c8c6982`, 21:43), so they ran pre-merge app code. `gsm stop --all` → no `-wal`/`-shm` left; backups of `genesis.db` + `memory.db` of both instances, SHA-256 equal to the sources, `pragma integrity_check` ok on all four. `gsm start --all` → main pid 90882, userb pid 90884 (started Sun 1 Nov 11:31), both healthy, openapi 0.79.0, `hello-appian` 0.1.0 and `sync-application` 0.3.1 installed on both (no install needed). Run **`r-dc3a0619cbde`** (`hello-appian` on main): `run.started` 06:01:54Z → `agent.result` `make_result` ok, **0.384 credits, provenance metered** → `validator.result` ok → `v_result`, `finish` completed → `run.final` status **done** 06:02:18Z (24 s); `result.json` in the run folder; no error in `genesis.log`. The worker runs `genesis/.venv`, whose three libraries import from `genesis/packages/…` (row 4) | `db-backup/{main,userb}/`, `row5-start.json`, `row5-run.json`, `row5-events.json` |
| 6 | Incremental sync with `sync-application` 0.3.1 (D19 (3): Monday's scheduled sync, `kb_syncs` on both instances) | **PENDING** until the first weekday scheduled sync (Mon 2026-11-02). Pre-read: both instances report 0.3.1; main's last full sync (`kb_syncs` 50, 2026-10-30) recorded parser 0.3.0 and no format, 2 days old (full every 7) → expected **incremental** with `details.kb_format_version` = 1 | |
| 7 | genesis-workflows local gates | **PASS**: validate_library 14, validate_skills 3, 317 passed | gates table |
| 8 | Updater + `genesis update --check-only` on a managed temp install | **PASS**: unit tests in the 1400; throwaway `dist.json` (repo = local clone, branch `phase-50-monorepo`): deployed 0.78.0 → "update available → v0.79.0 (scope: deps)"; deployed 0.79.0 → "already up to date."; deployed 0.70.9 (no such tag) → scope `deps` via the git-failure fallback; `_scope('0.79.0', 'phase-50-monorepo')` = deps (diff touches `packages/…`). No crash. A `code` result cannot be shown on real tags because every release bumps the root `pyproject.toml` (50-05 m1, D17); it is covered by `test_scope_*`. The shell guard refused a throwaway `git tag`, so no synthetic tag was made | `row8-updater-check.txt` |
| 9 | `genesis-ctx status`, `pack 50-07`, `check --files …/nodes/agent.py` | **PASS**: status rows genesis, genesis-workflows, project-tracker; pack 58,522 tokens (OK) with core-engine and parser routed by path `genesis/packages/…`; check → core-engine with 40 ADRs + 31 lessons | `pack-50-07.md` |

## CI on the scratch branch (§2)

genesis-release pushed `phase-50-monorepo` to `origin` as a new branch (D19 (1)). Checked by me with `glab api`:
`git ls-remote origin` → `refs/heads/phase-50-monorepo` = `34d6dabc…`, `refs/heads/master` = `908e5d47…`
(untouched); no tag.

**Pipeline #7258881** (IID 286, ref `phase-50-monorepo`, sha `34d6dabc`, source push, 06:03:51Z → 06:18:15Z):
**success**. <https://gitlab.appian-stratus.com/ramaswamy.u/genesis/-/pipelines/7258881>

| Job | Job id | Status | Duration | From the job log |
|---|---|---|---|---|
| `genesis` | 81449254 | success | 862 s | `install-packages.sh: python -m pip install -e ./packages/kiro-agent-sdk[dev] -e ./packages/genesis-core[dev] -e ./packages/genesis-appian-parser[dev] -e .[dev]`; ruff "All checks passed!"; **1393 passed, 7 skipped** |
| `genesis-core` | 81449255 | success | 112 s | ruff clean; **96 passed** |
| `kiro-agent-sdk` | 81449256 | success | 72 s | ruff clean; **79 passed** (its first CI run) |
| `genesis-appian-parser` | 81449257 | success | 181 s | ruff clean; 54 progress marks, one `s` (the known `test_diff_hash.py:39` skip; `-q` prints no summary line in this package) |
| `frontend` | 81449258 | success | 384 s | ran because a new branch makes every `changes` rule true (50-06 §3) |
| `clean-install` | 81449259 | success | 101 s | migrations 1–25; "Genesis is up (pid 119)"; "Stopped." |

**The 7 app skips.** The CI log prints only progress marks, so I mapped the 7 `s` positions onto the local
collection order (same 1400 tests, `pytest --collect-only`): positions 785–787 are
`tests/test_native_mcp.py::TestInstallWithUv::{test_devops_full_install, test_dev_full_install,
test_version_bump_and_rollback}` (`skipif(not HAS_UV)`, `test_native_mcp.py:265`: the `python:3.13` image has no
`uv`), and 1239–1242 are the four `test_test_design_stage.py::test_vendored_contract_fixtures_match_the_workflow_repo`
cases (no sibling genesis-workflows checkout), as 50-06 recorded. Both reasons are environmental and pre-date Phase 50:
master's last pipeline (#7256473 on `908e5d4`, job 81429291) reported "1356 passed, **10** skipped". The parser-fixture
tests are **not** among the skips (their fixture is tracked: `git ls-files packages/genesis-appian-parser/tests/fixtures`),
so the umbrella's "fixture tests skip silently" risk did not happen in CI either. Locally, with `uv` and the sibling
checkout present, all 1400 pass with 0 skipped.

genesis-workflows CI was not run, as planned (50-07 §4): its pins need the v0.80.0 tag (50-09).

## Findings

### Blockers
- None.

### Majors
- **M1 — D6 has no test.** Nothing fails if a `pyproject.toml` in the genesis repo names an internal package
  again. A name-only entry such as `"genesis-core>=0.79"` in the root `pyproject.toml` would still pass every gate
  (the one install command satisfies it from `./packages/genesis-core` in the same pip call), while a bare
  `pip install .` would resolve the unrelated public-PyPI `genesis-core`: the dependency-confusion risk that is this
  phase's first risk row (umbrella §11). Existing tests check where libraries were installed from
  (`test_platform_packages.py`) and that `install.sh` has no `git+ssh` (`test_installer_calls_the_script`), not the
  dependency lists. Fix (genesis-dev, hardening H1): a test in `tests/` that reads the root and the three
  `packages/*/pyproject.toml` with `tomllib` and fails if any `dependencies` or `optional-dependencies` entry
  names `genesis`, `genesis-core`, `kiro-agent-sdk` or `genesis-appian-parser` (normalise `_`/`-`, case), with a
  deliberate-mismatch case on a copy like `test_version_sync.py`.
  **Accepted by the user as hardening item H1 (D19 (4), 50-08 §5)**, which also adds a direct-reference-only check
  for the four names to genesis-workflows' `ci/validate_library.py`. H1 is built after §2 and row 5, pushed again,
  and re-reviewed before the final verdict.

### Minors
- **m1 — the install command and the dependency lists route to no area.** `genesis-ctx check` maps
  `genesis/scripts/install-packages.sh`, `genesis/scripts/install.sh`, `genesis/pyproject.toml`,
  `genesis/packages/*/pyproject.toml` and `genesis/.gitlab-ci.yml` to "—", so a future change to them loads only
  the always-on release-ci/security rules, not distribution (ADR-046, L-048, L-052) or the coming ADR-080. Only
  `install-packages.sh` and the package pyprojects are new; the others were unrouted before Phase 50, so D12's
  "same rules as before" holds. Fix (genesis-docs, 50-09, with ADR-080's tags): add `genesis/scripts/**`,
  `genesis/pyproject.toml` and `genesis/packages/*/pyproject.toml` to `distribution.paths`.
- **m2 — `context/state/current.md` still says Phase 50 is "spec-drafted, not started"** (printed by every
  `status`). Out of scope for 50-04 by design; 50-09's write-back overwrites it.

### Nits
- n1 — `genesis-ctx check --repo project-tracker` exits 2 "repo not found"; the skill says check covers the tracker,
  which it does only without `--repo`. Worth one line in the genesis-ctx skill.
- n2 — Carried, not new: 50-07 §6's open box (a tag ref with `#subdirectory=` and the HTTPS partial clone) is proven
  only in 50-09 §1; the D18 lockfiles read `libraryRef: local` until the 50-09 library reinstall.

## Verdict: PENDING (code review alone: NEEDS_CHANGES for M1 → H1)

Done: code review, gates, §2 pipeline #7258881 (all six jobs green), rows 1–5 and 7–9. Open before the final verdict
(D19): H1 built by genesis-dev on the branch → genesis-release pushes again (asks first) → its own green pipeline →
focused re-review of H1 → row 6 from Monday's (2026-11-02) scheduled `kb_syncs` rows on both instances.
