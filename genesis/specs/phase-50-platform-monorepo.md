# Phase 50 — Platform monorepo: genesis-core, kiro-agent-sdk and the parser move into the genesis repo

> **Status:** SPEC-DRAFTED 2026-10-31 · **Author:** genesis-spec agent.
> Sub-specs: `phase-50-platform-monorepo/50-01..50-09`. Findings (code facts, research, every decision): `50-01-findings.md`.
> Repos: **genesis** (receives the three libraries), **genesis-workflows** (re-pins, KB format check),
> **project-tracker** (agent system). Proposed ADR: **ADR-080** (amends ADR-019 and ADR-046).
> **Start gate (D9): no Phase 50 build work begins until Phase 49 is released** — 50-02 §1 checks it.

## 1. Why this phase exists

The platform is split across four code repos that always ship together: `genesis` pins `genesis-core`,
`kiro-agent-sdk` and `genesis-appian-parser` by `git+ssh` tag, and `genesis-core` pins the SDK the same way. A change
that crosses them needs a tag, a pin bump and a second tag per repo, and the pins drift (L-057). Nothing outside
Genesis uses the libraries (D2). One repo gives one change, one review, one tag and one CI pipeline.
`genesis-workflows` stays separate: it is runtime-pulled, MR-governed content with its own cadence (D1).

## 2. Goal

1. The three libraries live in the genesis repo under `packages/<name>/`, **with their full git history** (D7); the
   app stays at the root, unchanged (D5).
2. No internal package names another internal package as a dependency; every install path installs the local
   packages and the app in one pip command, so no internal name can ever be resolved on public PyPI (D6).
3. One shared version for all four packages, equal to the repo tag; compatibility is carried by `CORE_MAJOR` and a
   new parser `KB_FORMAT_VERSION` (D8).
4. Everything keeps working (D4): install, self-update, developer setup, CI, the fleet, the workflow library and the
   agent system — and the agent system loads the same rules for the same code as before (D12).
5. The old repos are archived read-only with a pointer, never deleted (D13).

## 3. Decisions (locked with the user, 2026-10-31 — detail and rationale in `50-01-findings.md` §6)

| # | Decision |
|---|---|
| D1 | Merge genesis-core, kiro-agent-sdk, genesis-appian-parser into genesis; genesis-workflows stays separate. |
| D2 | Nothing outside Genesis uses the libraries. |
| D3 | No production users: existing installs (own + fleet) may be reinstalled. |
| D4 | Every surface keeps working, the agent system included. |
| D5 | App at the repo root; libraries under `packages/genesis-core/`, `packages/kiro-agent-sdk/`, `packages/genesis-appian-parser/`. |
| D6 | No internal-to-internal dependency entries; one install command everywhere; missing-library check; genesis-workflows pins each library by `#subdirectory=`. |
| D7 | `git subtree add` without squash; old library tags stay in the archived repos; scratch branch + green CI before `master`. |
| D8 | One shared version + a CI sync test; `CORE_MAJOR` unchanged; parser `KB_FORMAT_VERSION` drives full re-syncs; ADR-019 amended. |
| D9 | Phase 49 is released first; the start gate opens 50-02. |
| D10 | CI runs every package's lint + tests on every pipeline, in parallel. |
| D11 | kiro-agent-sdk aligned (hatchling, Python 3.13, pinned ruff, `src/` kept); its POC files removed. |
| D12 | Area names kept, paths and gates repointed; an empty area glob becomes a lint error; repo lists shrink. |
| D13 | Old repos archived with a pointer commit after genesis-workflows is re-pinned; local checkouts moved to `_archived/`; ask before each. |
| D14 | ADR-080 amends ADR-046 as well as ADR-019 (confirmed); defaults F1–F6 accepted. |

## 4. Current state (code-grounded — full detail in `50-01-findings.md` §2)

| Surface | Today | File(s) |
|---|---|---|
| Internal pins | genesis → core/SDK/parser; core → SDK; workflows → core (+ genesis dev) | `genesis/pyproject.toml:11,14,17`, `genesis-core/pyproject.toml:14`, `genesis-workflows/pyproject.toml:12,18` |
| Install | SSH preflight of four repos, `pip install .` | `genesis/scripts/install.sh:30,90,140` |
| Update | `_scope` diffs `git+ssh` lines; `apply` runs `pip install <repo>` | `genesis/genesis/runtime/updater.py:142-156`, `apply()` |
| Dev setup | editable sibling installs; the fleet runs this venv | `genesis/README.md:51`, `genesis-fleet/genesis_fleet/config.py:20-29` |
| CI | genesis (3 jobs), core + parser (1 each), SDK none; `insteadOf` token rewrite | `*/.gitlab-ci.yml` |
| Parser version use | `sync-application` forces a full sync when the parser minor rises | `genesis-workflows/workflows/sync-application/graph.py:52,197-211` |
| Agent system | hard-coded repo lists; three areas' globs/gates name the old repos; 11 code-map keys | `agent-system/tools/genesis_ctx/config.py:8,12`, `genesis_installer.py:32,581-583`, `context/areas.toml:30-51,95-100` |
| Unaffected | worker, loader + `CORE_MAJOR` gate, lockfile, `genesis install`, scaffolder, managed-native installs | `50-01-findings.md` §2.4 |

## 5. Design overview

```
genesis/                              (one repo, one tag vX.Y.Z = every package's version)
  pyproject.toml   genesis/  web/  scripts/  tests/  .gitlab-ci.yml      ← app, unchanged paths
  packages/
    genesis-core/          pyproject (no internal deps)  genesis_core/  tests/
    kiro-agent-sdk/        pyproject (hatchling, 3.13)   src/kiro_agent_sdk/  tests/
    genesis-appian-parser/ pyproject                     genesis_appian_parser/ (KB_FORMAT_VERSION)  tests/

install / update / CI / dev:  pip install [-e] ./packages/kiro-agent-sdk ./packages/genesis-core \
                                           ./packages/genesis-appian-parser .        (one command, offline for internals)
genesis-workflows:  genesis-core, kiro-agent-sdk @ git+ssh://…/genesis.git@vX#subdirectory=packages/<name>
                    dev: genesis @ …/genesis.git@vX, genesis-appian-parser @ …#subdirectory=…
```

The one install command lives in **one place** (L-052): a small script in the genesis repo that the installer,
the updater, CI and the dev setup all call (50-05 §2).

| Building block | Sub-spec |
|---|---|
| Findings + decisions | 50-01 |
| Start gate + packaging spike (throwaway) | 50-02 |
| Repository merge: history import, layout, SDK alignment, dependency removal, dev venv | 50-03 |
| Agent-system routing | 50-04 |
| Install, update, developer setup | 50-05 |
| CI | 50-06 |
| Shared version, KB format version, genesis-workflows re-pin | 50-07 |
| HTTP API | **N/A** — no endpoint changes |
| Review, hardening, live acceptance | 50-08 |
| Release, archive, docs write-back | 50-09 |

## 6. Session plan

All build work happens on a local genesis branch **`phase-50-monorepo`** (D7), one session at a time (they share the
genesis checkout).

S0 = **start gate** (50-02 §1; stop if Phase 49 is not released) → S1 = 50-02 spike (genesis-dev; throwaway, no
commits to genesis) → S2 = 50-03 (genesis-dev; reads 50-02 As built) → S3 = 50-04 (genesis-docs, which maintains the
agent system; immediately after 50-03 so every later pack routes the moved code) → S4 = 50-05 (genesis-dev) →
S5 = 50-06 (genesis-dev) → S6 = 50-07 (genesis-dev; genesis + genesis-workflows) → S7 = 50-08 (genesis-review;
genesis-release pushes the scratch branch for CI, asking first) → S8 = 50-09 (genesis-release, then genesis-docs).

## 7. Sub-phase ledger

| Sub-phase | Repo | Content |
|---|---|---|
| 50-01 | project-tracker | Findings, decisions D1–D13 |
| 50-02 | (throwaway copies) | Start gate; prove the pip behaviour of D6, hatchling for the SDK, subdirectory pins, editable installs |
| 50-03 | genesis | Subtree imports ×3, SDK alignment + POC removal, internal deps removed, fixture paths, missing-library check, dev venv rebuild |
| 50-04 | project-tracker | `areas.toml` paths + gates, empty-glob lint error, routing test, repo lists, code map + `bible/03` headers, skills |
| 50-05 | genesis | The install script, `install.sh`, updater `_scope` + `apply`, preflight item, README + `docs/INSTALL.md` |
| 50-06 | genesis | Four parallel package jobs, `clean-install` rule, `insteadOf` removal, SDK lint fixes |
| 50-07 | genesis, genesis-workflows | Shared version + sync test, `KB_FORMAT_VERSION`, `sync-application` switch, genesis-workflows pins + `registry.json` |
| 50-08 | all | Independent review + gates + live acceptance |
| 50-09 | genesis, genesis-workflows, project-tracker, GitLab | Release genesis v0.80.0 → genesis-workflows v0.24.0, fleet reinstall, archive, local moves, docs write-back (ADR-080) |

## 8. Release plan

Versions assume Phase 49 ships genesis v0.79.0 + genesis-workflows v0.23.0 (49-09); adjust if it slips.

1. **genesis v0.80.0** — first tag of the merged repo; all four packages at 0.80.0; `CORE_MAJOR` stays 1; no DB
   migration.
2. **genesis-workflows v0.24.0** — pins `…/genesis.git@v0.80.0#subdirectory=…` (D6); `sync-application` uses
   `KB_FORMAT_VERSION`; `registry.json` `genesis_core_version` = 0.80.0, `genesis_core_major` = 1.
3. Fresh reinstall of the user's install and the fleet (D3); then archive the three old repos and move their local
   checkouts, asking before each (D13). Detail: 50-09.

## 9. Scope

- **In:** everything in §2; ADR-080; the agent-system changes of D12; one install script.
- **Out:** moving genesis-workflows; moving the app under `packages/` (D5 option B); uv or any new packaging tool;
  path-filtered CI (D10); publishing packages to any index; branch/tag protection on GitLab (may be added by the
  user any time).
- **Deferred:** none planned. A later phase may revisit layout B or CI path filters if they become worth it.

## 10. Defaults (proposed by the spec writer, accepted by the user 2026-10-31 — D14)

| # | Default |
|---|---|
| F1 | Install script: `scripts/install-packages.sh [--editable] [--dev]`, the only place that lists the four paths, in dependency order SDK → core → parser → app. |
| F2 | Missing-library check: a required preflight item `platform-packages` plus a startup log error naming the missing module; `genesis serve` still starts. |
| F3 | Updater `_scope` = `deps` when `git diff --name-only <deployed tag>..<target tag>` touches `pyproject.toml`, `packages/**` or `scripts/install-packages.sh`; else `code`. Unknown → `deps`. |
| F4 | `KB_FORMAT_VERSION = 1` represents today's parser 0.3.x output; a recorded `parser_version` with minor 3 and no `kb_format_version` counts as format 1, so no app is forced into a full sync. |
| F5 | Version-sync test checks the four `pyproject.toml` versions, the parser `__version__`, the `create_app` version and `web/src/version.ts`. |
| F6 | Each library keeps its own `README.md`, `.gitignore`, `tests/` and tool config inside `packages/<name>/`; their CI files are dropped. |

## 11. Risks

| Risk | Mitigation |
|---|---|
| A stray `pip install` resolves `genesis-core` / `genesis` on public PyPI (dependency confusion) | No internal dependency entries (D6); 50-02 proves with `--dry-run --report` that pip never asks an index for an internal name |
| Editable dev venv keeps importing the OLD sibling checkouts (tests + fleet) | 50-03 rebuilds the venv and adds a test that every library's `__file__` is inside the genesis repo |
| Agent-system globs miss the moved code → reviews silently stop loading core-engine/sdk-acp/parser rules | 50-04 right after 50-03; empty glob = lint error; routing test (D12) |
| Updater skips reinstalling changed library code | F3 path-diff scope + tests |
| Parser fixtures tests skip silently after the checkout moves | Repo-relative paths (50-03); 50-08 checks they run, not skip |
| genesis-workflows clones the 213 MB genesis repo up to four times per CI job | 50-02 measures pip's partial clone; if too slow, consolidate to fewer requirements (50-07) |
| Version skew: old genesis-workflows with the new parser, or new workflows with the old parser | `KB_FORMAT_VERSION` read with a fallback (F4); release order genesis → workflows; at worst one full sync |
| SDK first-ever lint run needs many fixes | Fix in 50-06; scope is formatting only, no behaviour change |
| Archiving too early breaks genesis-workflows' old pins | Archive is read-only, still clonable; done only after the re-pin is green (D13) |

## 12. ADR summaries (proposed — genesis-docs records them on Accept)

- **ADR-080 — The platform is one repository.** The genesis repo holds the app at its root and genesis-core,
  kiro-agent-sdk and genesis-appian-parser under `packages/`, with their history. No internal package declares another
  as a dependency; every install path installs the local packages and the app in one command, so an internal name is
  never resolved against a package index. All four share one version, equal to the repo tag; compatibility is carried
  by explicit constants (`CORE_MAJOR`, `KB_FORMAT_VERSION`). genesis-workflows stays separate and pins the libraries by
  git subdirectory. **Amends ADR-019:** the `CORE_MAJOR` loader gate and additive-only-within-a-major stay;
  genesis-core's pip version is the platform version (no separate semver). **Amends ADR-046:** distribution is still
  clone + venv + install + git-tag self-update, but the install step is the one install command over the local
  packages instead of `pip install .` with `git+ssh` tag pins.

## Context manifest

```toml
areas    = ["distribution", "release-ci", "core-engine", "sdk-acp", "parser", "workflows-library", "kb-sync"]
adrs     = ["ADR-003", "ADR-006", "ADR-016", "ADR-019", "ADR-024", "ADR-046", "ADR-077"]
lessons  = ["L-030", "L-052", "L-056", "L-057"]
docs     = ["tracker:specs/phase-50-platform-monorepo/50-01-findings.md"]
code     = ["genesis/pyproject.toml", "genesis/scripts/install.sh", "genesis/genesis/runtime/updater.py",
            "genesis/.gitlab-ci.yml", "genesis-workflows/pyproject.toml"]
upstream = []
```
