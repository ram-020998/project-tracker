# 50-04 — Agent-system routing

> **Status:** ✅ DONE 2026-10-31 (genesis-docs) — lint green with the new error rule, agent-system tests 247 passed,
> recall identical for all three libraries; `update.sh` pending the operator (see §5). Agent: **genesis-docs** (maintains the agent system, L0 §6; skill
> `genesis-agent-system`). Repo: **project-tracker** (`agent-system/`, `context/`, `bible/03`). Parent:
> `specs/phase-50-platform-monorepo.md`. Decisions: **D12**, **D16** (`50-01-findings.md` §6, §2.5). Run **immediately after
> 50-03**, with the local genesis checkout on `phase-50-monorepo`, so every later pack routes the moved code.

## 1. Why first

Until this lands, a changed file under `genesis/packages/…` maps to no area: `genesis-ctx check` and `pack` would not
load the core-engine, sdk-acp or parser rules, and nothing fails (an empty glob is only a warning today).

## 2. Changes

| File | Change |
|---|---|
| `context/areas.toml` | `core-engine.paths` → `genesis/packages/genesis-core/genesis_core/**`; `sdk-acp.paths` and the SDK glob in `chat.paths` → `genesis/packages/kiro-agent-sdk/src/**`; `parser.paths` → `genesis/packages/genesis-appian-parser/genesis_appian_parser/**`. Gates run from the package dir with the shared venv: `cd genesis/packages/genesis-core && ../../.venv/bin/python -m pytest -q -p no:warnings`, `… && ../../.venv/bin/ruff check genesis_core`; SDK `cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` (+ `ruff check src tests`, as 50-06); parser likewise. Area names, titles, keywords, skills unchanged. |
| `context/areas.toml` — unmapped CLI files (D16) | Add `genesis/genesis/cli/main.py` to `distribution.paths` (beside `cli/install.py`), and `genesis/genesis/cli/create_workflow.py` + `genesis/genesis/cli/test_workflow.py` to `workflows-library.paths`. App `tests/**` stay unmapped. |
| `genesis_ctx` lint | `area-glob-empty` becomes an **error** (was a warning). |
| `genesis_ctx/config.py:8,12` | Repo list → `genesis`, `genesis-workflows` (project-tracker handled as today). `status` then shows three rows. |
| `agent-system/.../genesis_installer.py:32` | Same repo list; the missing-repo preflight (`:581-583`) then no longer needs the old checkouts. |
| `context/tags/codemap.toml` + `bible/03` repo headers (L12, 202, 232, 252, 255, 616, 645, 676) | Move the genesis-core / SDK / parser sections under `genesis/packages/<name>/…` keys, in lockstep (lint errors on a mismatch). Move text by script or exact edits, never by rewriting (L-087). |
| Tests (`agent-system/tests/`) | (a) a changed file `genesis/packages/genesis-core/genesis_core/nodes/agent.py` maps to `core-engine`; SDK → `sdk-acp` + `chat`; parser → `parser`; `genesis/genesis/cli/main.py` → `distribution`, `genesis/genesis/cli/create_workflow.py` → `workflows-library` (D16); (b) an area whose glob matches nothing fails lint; (c) `status` lists the new repo set. Update fixtures that name the old repos. |
| Skills | `genesis-release`: one repo + one tag for the platform, the shared version (D8), the version-sync test, genesis-workflows pins by `#subdirectory=` (D6), no per-library tags. `genesis-backend-dev`: the repo layout, the shared venv, the one install command. `grep -rn "genesis-core\|kiro-agent-sdk\|genesis-appian-parser"` over `agent-system/skills/` and fix every stale instruction. |
| `OPERATOR_GUIDE.md`, `AGENT_ONBOARDING.md` | Repo list and setup lines. |
| Install | `agent-system/update.sh`; confirm the installed `genesis-ctx` matches. |

Out of this sub-spec: `context/L0-core.md` §2 and `context/state/current.md` (the release write-back, 50-09), and
archived or historical specs (they keep their old paths verbatim — ADR-077; lint skips manifests < 48).

## 3. Recall check

Before and after the change, run `genesis-ctx check --files` on one representative file per library (old path before,
new path after) and diff the ADR/lesson lists: they must be identical. Record both lists.

## 4. Acceptance

- [x] `genesis-ctx lint` green (full, not only `--specs-only`) with the new error rule.
- [x] `agent-system` tests green, including the three new ones.
- [x] Recall check identical for all three libraries.
- [ ] `update.sh` run (operator); `genesis-ctx status` shows the new repo set (done: the shim runs from source).

## 5. As built

**2026-10-31, genesis-docs.** Start: genesis on `phase-50-monorepo` at `7cb9f1c` (50-03 SHIP), project-tracker `main`
at `a25862e`, dirty 0. Baseline: agent-system tests 231 passed; `genesis-ctx lint` 0 errors, 0 warnings (the old
globs still matched the old sibling checkouts, so nothing had warned yet).

### Changed (project-tracker only)

| File | Change |
|---|---|
| `context/areas.toml` | `core-engine` → `genesis/packages/genesis-core/genesis_core/**`; `sdk-acp` and `chat`'s SDK glob → `genesis/packages/kiro-agent-sdk/src/**`; `parser` → `genesis/packages/genesis-appian-parser/genesis_appian_parser/**`. Gates `cd genesis/packages/<name> && ../../.venv/bin/…`: core `pytest -q -p no:warnings` + `ruff check genesis_core`; SDK `pytest -q` + **new** `ruff check src tests`; parser `pytest -q` + `ruff check .`. D16: `genesis/genesis/cli/main.py` → `distribution`; `cli/create_workflow.py`, `cli/test_workflow.py` → `workflows-library`. Header comment: the two repos and the error rule. Names, titles, keywords, skills unchanged. |
| `agent-system/tools/genesis_ctx/lint.py` | `area-glob-empty` is an error (was a warning). |
| `agent-system/tools/genesis_ctx/config.py`, `tools/installer/genesis_installer.py` | `REPO_NAMES = ("genesis", "genesis-workflows")`. The installer preflight now reports "2 repos" and no longer needs the old checkouts. |
| `agent-system/tools/genesis_ctx/cli.py` | `check --repo` help text names the two repos. |
| `bible/03-codebase-map.md` + `context/tags/codemap.toml` | Moved by script with asserted counts (L-087): the 8 header lines that were exactly `genesis-core/genesis_core/`, `kiro-agent-sdk/src/kiro_agent_sdk/` or `genesis-appian-parser/` (L12, 202, 232, 252, 255, 616, 645, 676) now start with `genesis/packages/`; the 11 base-map keys `genesis-core/genesis_core/  …` became `genesis/packages/genesis-core/genesis_core/  …`. Diff: 8 + 11 lines, nothing else. `L46` ("duck-types genesis-appian-parser's KbParseResult") names the package, not a path, so it is unchanged. |
| `context/_generated/area-catalog.md` | Regenerated by `index` (gate counts: sdk-acp 2, workflows-library 4). |
| Skills | `genesis-release`: two repos, one platform tag for app + three packages, no per-library tags, genesis then genesis-workflows, the shared-version locations + `tests/test_version_sync.py`, `CORE_MAJOR`/`KB_FORMAT_VERSION` independent of the version, genesis-workflows pins on one tag by `#subdirectory=` (D6, L-057), notes template. `genesis-backend-dev`: the layout, the shared venv (SDK venv retired), `scripts/install-packages.sh --editable --dev`, app and per-package gates. `genesis-ctx`: `status` row set. The §2 grep over `agent-system/skills/` now returns only new-layout lines. |
| `agent-system/OPERATOR_GUIDE.md` | Setup check: `status` shows three rows; the installer needs `genesis` + `genesis-workflows`; the review prompt drops "others unchanged"; the release step names the order; an example constraint names `packages/genesis-core`. |
| Tests | New `tests/test_routing.py` (16): the REAL `areas.toml` routes the core/SDK/parser files and the three CLI files to their areas (a, D16); old checkout paths and `genesis/tests/**` / package `tests/**` route nowhere; library gates run from the package dir with the shared venv; fixture `check --files` on moved paths; an empty glob fails lint as an error (b); `status` lists `genesis`, `genesis-workflows`, `project-tracker` in `--json` and `--brief` (c); installer and genesis-ctx share one repo list. Updated: `test_lint.py::test_area_invalid_and_glob_error` (error, not warning), `test_installer.py` missing-repo case (`genesis-workflows`), fixtures (`conftest.REPO_FILES`, fixture `areas.toml`, `codemap.toml`, `bible/03` header) and `test_sources.py` keys. |

`AGENT_ONBOARDING.md` has no repo list or setup lines, so it is unchanged.

### Recall check (§3)

`/tmp/recall_50_04.py` ran `genesis-ctx check --files <file> --json` on one file per library before (old path) and
after (new path) and compared areas, ADR ids and lesson ids: **identical for all three**.

| Library (file) | Areas | ADRs | Lessons |
|---|---|---|---|
| core (`…/genesis_core/nodes/agent.py`) | core-engine, release-ci, security | 40: ADR-001 002 004 009 010 011 012 017 018 019 020 021 022 023 024 025 026 029 030 037 039 041 042 050 051 053 054 061 062 063 065 066 067 068 069 073 074 075 076 077 | 31: L-001 002 004 005 006 009 016 017 020 021 022 023 025 026 027 030 041 042 045 051 056 057 059 064 065 075 076 087 088 089 092 |
| SDK (`…/kiro_agent_sdk/client.py`) | chat, release-ci, sdk-acp, security | 34: ADR-001 002 004 005 010 011 020 026 027 029 030 031 032 033 034 035 037 041 042 045 050 051 053 055 059 060 063 065 069 073 074 075 076 077 | 31: L-001 002 007 016 017 018 021 024 025 027 030 041 042 044 045 046 047 051 056 057 058 061 064 069 073 086 087 088 089 092 093 |
| parser (`…/genesis_appian_parser/__init__.py`) | parser, release-ci, security | 14: ADR-011 026 030 036 037 038 039 041 047 063 065 073 074 077 | 21: L-017 025 027 030 031 032 035 036 037 038 045 050 051 056 057 077 079 087 088 089 092 |

D16 check: `cli/main.py` and `cli/install.py` → distribution; `cli/create_workflow.py`, `cli/test_workflow.py` →
workflows-library (ADR-011 and ADR-014 now load for them).

### Gates

- `genesis-ctx index` then `genesis-ctx lint` (full): **0 errors, 0 warnings**, L0 ~22,875 / 24,000 tokens.
- `pytest -q agent-system/tests`: **247 passed** (231 + 16 new).
- New SDK gate as written: `cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/ruff check --no-cache src tests` →
  All checks passed (the core and parser gates are the ones 50-03 ran).
- `update.sh --dry-run`: preflight ok, "2 repos"; 3 changed (skills genesis-backend-dev, genesis-ctx, genesis-release),
  18 unchanged. The installed `genesis-ctx` is the source shim, so `status --brief` already prints the three rows.
  **`update.sh` itself is for the operator** (it writes `~/.kiro/genesis`, outside the docs agent's write roots).

### Review

No `genesis-review` sub-agent: genesis-docs cannot spawn sub-agents (its profile lists none). This sub-spec's changes
are in the 50-08 whole-phase review range (project-tracker).

### Decisions / deviations

- **`workflows-library` gets the genesis app gates** (`pytest`, `ruff check genesis`), because its globs now touch the
  genesis repo (the `areas.toml` rule: an area's gates are those of the repos its globs touch). Without this, a change to
  `cli/create_workflow.py` would print only the genesis-workflows gates.
- **SDK lint gate is `ruff check src tests`** (spec §2 / 50-06), not `ruff check .`; both are clean today.
- No ADR deviation. ADR and lesson tags are untouched (D12), which is why recall is identical.

### Follow-ups (for the 50-09 write-back, not this sub-spec)

- `bible/05` §6 L12–21 (dev venv, per-repo gate commands, "pyproject deps are git+ssh") and
  `reference/coding-standards.md` L129 (`genesis-core/nodes/agent.py`) still describe the old layout; they become wrong
  as 50-05/50-07 land. The release skill still points at `bible/05` §6.
- `context/L0-core.md` §2 and `context/state/current.md` (already out of scope here).

### Lesson candidates

None new. L-087 (move text by script with asserted counts) was applied and held.

### Code-map changes

The 11 genesis-core base-map keys are now `genesis/packages/genesis-core/genesis_core/  …`; the SDK and parser
entries sit under `genesis/packages/…` headers inside their phase sections (keys unchanged).

## Context manifest

```toml
areas    = ["release-ci", "security", "core-engine", "sdk-acp", "parser", "chat", "distribution", "workflows-library"]
adrs     = ["ADR-011", "ADR-014", "ADR-046", "ADR-077"]
lessons  = ["L-087", "L-088", "L-089"]
docs     = ["tracker:specs/phase-50-platform-monorepo/50-01-findings.md", "tracker:context/areas.toml",
            "tracker:agent-system/OPERATOR_GUIDE.md"]
code     = ["tracker:agent-system/tools/genesis_ctx/**", "tracker:agent-system/tests/**",
            "tracker:agent-system/skills/genesis-release/SKILL.md", "tracker:agent-system/skills/genesis-backend-dev/SKILL.md",
            "tracker:context/tags/codemap.toml"]
upstream = ["50-03"]
```
