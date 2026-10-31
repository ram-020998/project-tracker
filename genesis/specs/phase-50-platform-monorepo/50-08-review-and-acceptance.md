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
| 2 | Preflight on that install | `platform-packages` ok; uninstall `genesis-appian-parser` → the item reports it missing and the startup log names it; reinstall |
| 3 | `pip install --dry-run --report` of the install command | No index lookup for an internal name (D6) |
| 4 | Dev venv | `genesis_core.__file__`, `kiro_agent_sdk.__file__`, `genesis_appian_parser.__file__` are under `genesis/packages/`; the three parser-fixture tests **ran** (not skipped) in the pytest output |
| 5 | Fleet (main + userb) on the dev venv, after checking no run is active | Both healthy; a workflow run with an agent step completes (proves the worker imports the libraries) |
| 6 | Incremental sync of a tracked app on main with the new `sync-application` installed from the local checkout | Runs **incremental** (no forced full sync); `details.kb_format_version` = 1 |
| 7 | genesis-workflows local gates against the dev venv | validate_library, validate_skills, workflow tests green |
| 8 | Updater unit tests + a manual `genesis update --check` style read on a managed temp install | scope computed by path diff; no crash |
| 9 | `genesis-ctx status`, `pack 50-07`, `check --files genesis/packages/genesis-core/genesis_core/nodes/agent.py` | New repo set; core-engine rules load |

Headless limits: item 5's agent step needs a live Kiro login; if unavailable, give the manual check.

## 4. Output

`specs/phase-50-platform-monorepo/reviews/50-08-review.md` with SHIP / NEEDS_CHANGES, the checklist, the pipeline id
and the acceptance table. NEEDS_CHANGES items go back to genesis-dev as numbered hardening items in this file (§5).

## 5. Hardening items

*(added after the review if needed)*

## 6. As built

*(filled by genesis-review)*

## Context manifest

```toml
areas    = ["distribution", "release-ci", "core-engine", "sdk-acp", "parser", "kb-sync", "workflows-library", "runs-worker"]
adrs     = ["ADR-012", "ADR-019", "ADR-046", "ADR-074", "ADR-077"]
lessons  = ["L-030", "L-048", "L-051", "L-056", "L-057", "L-061", "L-089"]
docs     = ["tracker:specs/phase-50-platform-monorepo.md", "tracker:specs/phase-50-platform-monorepo/50-01-findings.md"]
code     = ["genesis/packages/**", "genesis/scripts/**", "genesis/genesis/runtime/updater.py", "genesis/.gitlab-ci.yml",
            "genesis-workflows/workflows/sync-application/**", "tracker:context/areas.toml"]
upstream = ["50-02", "50-03", "50-04", "50-05", "50-06", "50-07"]
```
