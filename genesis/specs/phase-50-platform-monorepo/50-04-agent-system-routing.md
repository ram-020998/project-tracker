# 50-04 — Agent-system routing

> **Status:** SPEC-DRAFTED 2026-10-31. Agent: **genesis-docs** (maintains the agent system, L0 §6; skill
> `genesis-agent-system`). Repo: **project-tracker** (`agent-system/`, `context/`, `bible/03`). Parent:
> `specs/phase-50-platform-monorepo.md`. Decision: **D12** (`50-01-findings.md` §6, §2.5). Run **immediately after
> 50-03**, with the local genesis checkout on `phase-50-monorepo`, so every later pack routes the moved code.

## 1. Why first

Until this lands, a changed file under `genesis/packages/…` maps to no area: `genesis-ctx check` and `pack` would not
load the core-engine, sdk-acp or parser rules, and nothing fails (an empty glob is only a warning today).

## 2. Changes

| File | Change |
|---|---|
| `context/areas.toml` | `core-engine.paths` → `genesis/packages/genesis-core/genesis_core/**`; `sdk-acp.paths` and the SDK glob in `chat.paths` → `genesis/packages/kiro-agent-sdk/src/**`; `parser.paths` → `genesis/packages/genesis-appian-parser/genesis_appian_parser/**`. Gates run from the package dir with the shared venv: `cd genesis/packages/genesis-core && ../../.venv/bin/python -m pytest -q -p no:warnings`, `… && ../../.venv/bin/ruff check genesis_core`; SDK `cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` (+ `ruff check src`); parser likewise. Area names, titles, keywords, skills unchanged. |
| `genesis_ctx` lint | `area-glob-empty` becomes an **error** (was a warning). |
| `genesis_ctx/config.py:8,12` | Repo list → `genesis`, `genesis-workflows` (project-tracker handled as today). `status` then shows three rows. |
| `agent-system/.../genesis_installer.py:32` | Same repo list; the missing-repo preflight (`:581-583`) then no longer needs the old checkouts. |
| `context/tags/codemap.toml` + `bible/03` repo headers (L12, 202, 232, 252, 255, 616, 645, 676) | Move the genesis-core / SDK / parser sections under `genesis/packages/<name>/…` keys, in lockstep (lint errors on a mismatch). Move text by script or exact edits, never by rewriting (L-087). |
| Tests (`agent-system/tests/`) | (a) a changed file `genesis/packages/genesis-core/genesis_core/nodes/agent.py` maps to `core-engine`; SDK → `sdk-acp` + `chat`; parser → `parser`; (b) an area whose glob matches nothing fails lint; (c) `status` lists the new repo set. Update fixtures that name the old repos. |
| Skills | `genesis-release`: one repo + one tag for the platform, the shared version (D8), the version-sync test, genesis-workflows pins by `#subdirectory=` (D6), no per-library tags. `genesis-backend-dev`: the repo layout, the shared venv, the one install command. `grep -rn "genesis-core\|kiro-agent-sdk\|genesis-appian-parser"` over `agent-system/skills/` and fix every stale instruction. |
| `OPERATOR_GUIDE.md`, `AGENT_ONBOARDING.md` | Repo list and setup lines. |
| Install | `agent-system/update.sh`; confirm the installed `genesis-ctx` matches. |

Out of this sub-spec: `context/L0-core.md` §2 and `context/state/current.md` (the release write-back, 50-09), and
archived or historical specs (they keep their old paths verbatim — ADR-077; lint skips manifests < 48).

## 3. Recall check

Before and after the change, run `genesis-ctx check --files` on one representative file per library (old path before,
new path after) and diff the ADR/lesson lists: they must be identical. Record both lists.

## 4. Acceptance

- [ ] `genesis-ctx lint` green (full, not only `--specs-only`) with the new error rule.
- [ ] `agent-system` tests green, including the three new ones.
- [ ] Recall check identical for all three libraries.
- [ ] `update.sh` run; `genesis-ctx status` shows the new repo set.

## 5. As built

*(filled by genesis-docs)*

## Context manifest

```toml
areas    = ["release-ci", "security", "core-engine", "sdk-acp", "parser", "chat"]
adrs     = ["ADR-077"]
lessons  = ["L-087", "L-088"]
docs     = ["tracker:specs/phase-50-platform-monorepo/50-01-findings.md", "tracker:context/areas.toml",
            "tracker:agent-system/OPERATOR_GUIDE.md"]
code     = ["tracker:agent-system/tools/genesis_ctx/**", "tracker:agent-system/tests/**",
            "tracker:agent-system/skills/genesis-release/SKILL.md", "tracker:agent-system/skills/genesis-backend-dev/SKILL.md",
            "tracker:context/tags/codemap.toml"]
upstream = ["50-03"]
```
