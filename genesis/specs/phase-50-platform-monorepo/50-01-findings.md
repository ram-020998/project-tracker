# 50-01 — Findings: merge the platform repos into one repository

> **Status:** SPEC-DRAFTED 2026-10-31 — research and decisions D1–D14 locked with the user.
> Parent: `specs/phase-50-platform-monorepo.md`. Proposed ADR: **ADR-080** (platform monorepo; amends ADR-019 and
> ADR-046).
>
> This document records what was researched and decided before the spec is written: the problem as the user stated
> it, how the five repos are wired together today (code-grounded), the impact on every surface (packaging, install,
> update, CI, runtime, the workflow library, the agent system, git history), external research, the options, and
> every decision.

---

## 1. The problem (as stated by the user, 2026-10-31)

Genesis is split across five repos. The user wants to explore combining them into one repository, and asked for a
deep impact analysis of every area **before deciding anything**. Constraint: everything must stay intact, including
the agent system and the installation.

## 2. How the repos are wired today (verified in the code)

Paths are relative to `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/`.

### 2.1 Packages

| Repo | Dist name / import | Build backend | Python | Version | Runtime deps on siblings |
|---|---|---|---|---|---|
| `genesis` | `genesis` / `genesis` | hatchling | >=3.13 | 0.78.0 (static) | `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser` by `git+ssh` tag pin (`genesis/pyproject.toml:11,14,17`) |
| `genesis-core` | `genesis-core` / `genesis_core` | hatchling | >=3.13 | 0.9.8; `CORE_MAJOR=1` (`genesis_core/types.py:11`) | `kiro-agent-sdk` by tag pin (`genesis-core/pyproject.toml:14`) |
| `kiro-agent-sdk` | `kiro-agent-sdk` / `src/` layout | **setuptools** | **>=3.10** | 0.7.1 | none |
| `genesis-appian-parser` | `genesis-appian-parser` / `genesis_appian_parser` | hatchling | >=3.13 | 0.3.0 (+ `__version__`) | none (stdlib-only) |
| `genesis-workflows` | not an app dependency; pulled at runtime | hatchling | >=3.13 | — | `genesis-core` tag pin (runtime), `genesis` tag pin (dev extra) (`genesis-workflows/pyproject.toml:12,18`) |

- Shared runtime constraints agree (`langgraph>=1.2,<2`, `langgraph-checkpoint-sqlite>=3,<4`, `aiosqlite>=0.20`).
- `ruff==0.15.20` in genesis, genesis-core and the parser; kiro-agent-sdk has **no ruff pin and no ruff config**;
  genesis-workflows floats `ruff>=0.6` (L-025/L-027).
- The parser has its own ruff rule set (line length 110, `select` + per-file ignores for the ported Atlas modules);
  genesis and genesis-core use line length 100 with defaults.
- genesis ships the SPA as package data (`force-include "web/static" = "genesis/web_static"`, L-048).
- Test layout: one `tests/` per repo, **no colliding test-file basenames** across the four repos; `conftest.py`
  only in the parser. Three genesis tests read parser fixtures through a sibling path
  (`tests/test_kb_server.py:198,202`, `test_kb_store.py:13`, `test_kb_incremental.py:23`).
- The three library repos hold only `README.md`, `.gitignore`, the package and `tests/`. kiro-agent-sdk also carries
  proof-of-concept leftovers (`examples/`, `workflows/erd_workflow.py`, `runs/`); no `.env` is tracked in its history.

### 2.2 CI

- `genesis/.gitlab-ci.yml` (79 lines): `genesis` job (editable install, `ruff`, `pytest`), `frontend` job
  (`rules: changes: [web/**/*]` + the stale-bundle guard, L-030), `clean-install` job (non-editable `pip install .`,
  migrate, `genesis up`, SPA served, `shellcheck`, installer `--help`).
- genesis-core and the parser: 14-line CI files (editable install, ruff, pytest).
- **kiro-agent-sdk has no CI at all.** Its area gate uses its own `kiro-agent-sdk/.venv`.
- Every CI file rewrites `ssh://` to HTTPS with `GITLAB_PUSH_TOKEN` so the runner can clone the sibling repos.
- Job durations (GitLab API, recent successful pipelines; jobs in one pipeline run in parallel): genesis `genesis`
  job ≈ **10–10.5 min** (v0.77.0 626 s, v0.78.0 630 s), `frontend` ≈ 5–5.5 min, `clean-install` ≈ 2 min;
  genesis-core job ≈ 1.5 min (v0.9.8 94 s); parser `lint-and-test` ≈ 1.5–2.3 min (94–139 s). The `genesis` job
  sets the pipeline's wall time.

### 2.3 Install, update, developer setup

- `scripts/install.sh` checks SSH read access to `REPOS=(genesis genesis-core kiro-agent-sdk genesis-appian-parser)`
  (`:30,90`), then `pip install .`; the three libraries come from their tag pins.
- `runtime/updater.py`: `_scope()` decides whether an update needs `pip install .` by diffing the `git+ssh://` lines
  of `pyproject.toml` between the working tree and the target tag (`:142-156`). With no `git+ssh` lines (monorepo),
  it would always answer `code` and **skip reinstalling changed library code**. `tests/test_updater.py:95,99` pin it.
- Developer venv: editable sibling installs (`README.md:51`, `docs/INSTALL.md:10-11,105`).
- Version reporting looks up only the `genesis` distribution (`updater.py:89`); the OpenAPI version is a literal in
  `api/app.py:80`. No UI shows library versions.

### 2.4 Runtime (confirmed unaffected)

- The worker is `sys.executable -m genesis.runs.worker` with the inherited environment and no `PYTHONPATH`
  (`runs/supervisor.py:49,60`); it imports the libraries by package name, so the install source does not matter.
- The loader, the `CORE_MAJOR` gate and the lockfile key on `genesis-workflows/registry.json`
  (`genesis_core_major` / `genesis_core_version`) and never name the library repos.
- The GitLab client and `genesis install` target only `ramaswamy.u/genesis-workflows`.
- The `create-workflow` scaffolder emits no dependency pin. Managed-native MCP / `gws` installs are unrelated.
- `genesis-fleet` (`gsm`) knows only the `genesis` binary and the genesis-workflows source; no reference to the libraries.

### 2.5 The agent system (project-tracker)

- `genesis-ctx`: the repo set is a hard-coded constant (`agent-system/tools/genesis_ctx/config.py:8,12`); `status`
  iterates it (`query.py:47`); `check` emits changed files as `<repo>/<path>` and routes them through area globs
  whose first segment is the repo name (`pack.py:255`, `model.py:252-283`).
- `context/areas.toml`: the `core-engine`, `sdk-acp` and `parser` areas (and one `chat` glob) use
  `genesis-core/…`, `kiro-agent-sdk/src/…`, `genesis-appian-parser/…` globs and `cd <repo> && ../genesis/.venv/…`
  gates (`:32,35-36,40,43,47,50-51,97,100`). A path like `genesis/packages/genesis-core/…` routes to **no area**
  today, and an empty glob is only a lint *warning*, so a missed update fails silently: the review `check` would
  stop loading the core-engine/sdk-acp/parser ADRs and lessons.
- Code map: 11 `codemap.toml` keys are prefixed `genesis-core/genesis_core/…` and must byte-match the repo header
  lines in `bible/03` (L12, 202, 232, 252, 255, 616, 645, 676); a mismatch is a lint **error**.
- ADR `paths` sidecars: none name the three libraries.
- The agent installer has its own repo list (`genesis_installer.py:32`) and **errors when a repo directory is
  missing** (`:581-583`), so `install.sh`/`update.sh` would break once the old checkouts are removed.
- Profiles use a generic `{{REPOS}}/**` token; `shell-guard.sh` and `stop-lint.sh` are repo-agnostic.
- Skills that describe the five-repo layout: `genesis-release` (ADR-019 release order, per-repo versions and pins)
  and `genesis-backend-dev` (repo list, the separate kiro-agent-sdk venv).
- Always-loaded docs naming the repos: `context/L0-core.md` §2, `context/state/current.md` (versions, chain, counts).
- `genesis-ctx lint --specs-only` skips manifests of phases < 48 and does not require `code` paths to exist, so
  historical specs (34 files cite the library paths) keep linting.

### 2.6 Git

| Repo | Default branch | Commits | Tags | Notes |
|---|---|---|---|---|
| genesis | master | — | 126 | ~169 MiB packed (committed `web/static` bundles); **14 unpushed Phase 49 commits** |
| genesis-core | master | — | 22 | small |
| kiro-agent-sdk | **main** | — | 9 | small |
| genesis-appian-parser | **main** | — | 3 | 4.8 MiB fixture zip |
| genesis-workflows | master | — | 46 | **2 unpushed Phase 49 commits** (stays separate) |

- Every repo tags `vX.Y.Z`, with overlapping values (all have `v0.1.0`), so imported tags collide.
- Root files that collide: `README.md`, `pyproject.toml`, `.gitignore`, `.gitlab-ci.yml`, `tests/`. genesis has no
  `packages/` directory, so `packages/<name>/` resolves every collision.
- `git subtree` is available; `git filter-repo` is not installed. No LFS, submodules or in-repo hooks.
- GitLab (read via `glab api`, 2026-10-31, after the user fixed connectivity):
  - All projects are private and not archived, in the personal namespace `ramaswamy.u` (not a group, so there are
    no group-level variables). Ids: genesis 14327, genesis-core 14328, kiro-agent-sdk 14306,
    genesis-appian-parser 14520, genesis-workflows 14329, genesis-fleet 14721.
  - No open MRs and no failing or running pipelines anywhere. kiro-agent-sdk and genesis-fleet have no pipelines.
  - No protected branches or tags on any project; `only_allow_merge_if_pipeline_succeeds` is off everywhere.
  - `GITLAB_PUSH_TOKEN` (masked, not protected, all environments) is defined in genesis, genesis-core and
    genesis-workflows only. Its scope cannot be read (the value is masked).
  - CI job-token allowlists are self-only; no deploy keys, project access tokens, webhooks, mirrors, GitLab
    Releases or published packages exist. The only coupling between the projects is the git tag pins.

### 2.7 GitLab compatibility with the history import (D7)

Checked 2026-10-31 with read-only `glab api` calls:

- Instance: **GitLab 19.4.3 EE**. A subtree import produces ordinary git merge commits (two parents, one with an
  unrelated history); GitLab needs no special feature to accept or display them.
- genesis push rules (`projects/14327/push_rule`): **max file size 10 MB**; no commit-message or branch-name regex,
  no author-email regex, `member_check` off, committer checks off, unsigned and non-DCO commits allowed, secret
  prevention off. The library commits are authored as `genesis@local`, which these rules accept.
- Largest blob in the three libraries' full histories: the parser's **4.8 MiB** fixture zip (no blob ≥ 9 MiB in any
  of the three; checked with `git rev-list --objects --all --filter=blob:limit=9m --filter-print-omitted`).
- genesis project: 317 commits, repository size ≈ 213 MB; merge method `merge` (merge commits kept), squash
  `default_off`, LFS enabled but unused, SHA-1 object format (same as the libraries).
- CI clones with `ci_default_git_depth: 20` (shallow). Path rules that use `changes: compare_to` must still work
  with a shallow clone; the CI sub-spec verifies this.
- Not readable with this token: instance-wide limits (`application/settings` → 403), e.g. the maximum push size.
  The import adds a few MB, far below any GitLab default; the scratch-branch push (D7) proves it.

### 2.8 Further findings made while specifying

- **The fleet runs the dev venv.** `gsm` resolves the `genesis` binary to
  `~/repo-gitlab/ramaswamy.u/genesis/.venv/bin/genesis` (`genesis-fleet/genesis_fleet/config.py:20-29`). That venv
  holds **editable installs of the old sibling checkouts** (`genesis/README.md:51`). Until it is reinstalled from
  `packages/`, both pytest and the fleet keep importing the OLD repos' code with no error. 50-03 rebuilds it and adds
  a test that the imported library modules live inside the genesis repo.
- **Three genesis tests read the parser fixture by absolute path and skip when it is missing**
  (`tests/test_kb_server.py:196-203`, `tests/test_kb_incremental.py:22-24`, `tests/test_kb_store.py:12-14`). Once the
  old checkout moves (D13) they would skip silently. 50-03 repoints them to the repo-relative
  `packages/genesis-appian-parser/tests/fixtures/`.
- **`updater.apply()` runs `pip install <repo>`** (`runtime/updater.py`, "Installing (pip install .)" step) and
  `install.sh` runs `pip install .` (`scripts/install.sh:140`); under D6 both must run the one install command.
- **genesis-workflows** installs `pip install -e ".[dev]"` in all three CI jobs (`genesis-workflows/.gitlab-ci.yml:7-11`).
  Under D6 neither genesis nor genesis-core pulls the other libraries any more, so genesis-workflows must list
  `genesis-core` **and** `kiro-agent-sdk` as runtime dependencies and `genesis` + `genesis-appian-parser` in its dev
  extra (`sync-application` imports the parser, `workflows/sync-application/graph.py:50`).
- **ADR-046's rule text** names "`pip install .`" and "the three internal deps resolve from their `git+ssh` tag pins".
  D6 changes both, so ADR-080 amends ADR-046 as well as ADR-019 (flagged to the user 2026-10-31).

## 3. External research

- **Relative path dependencies are not portable with plain pip.** A PEP 508 direct reference needs an absolute
  `file://` URL; hatch `{root:uri}`, uv `[tool.uv.sources]` and pdm `${PROJECT_ROOT}` are tool-specific and do not
  apply to `pip install .` ([PEP 508](https://peps.python.org/pep-0508/),
  [hatch context formatting](https://hatch.pypa.io/latest/config/context/),
  [uv workspaces](https://docs.astral.sh/uv/concepts/projects/workspaces/)).
- **Git subdirectory installs work**: `pkg @ git+ssh://…/genesis.git@vX.Y.Z#subdirectory=packages/genesis-core`
  ([pip VCS support](https://pip.pypa.io/en/stable/topics/vcs-support/)). The tag is repo-wide and pip clones the
  whole repo.
- **Dependency confusion risk (verified 2026-10-31):** `genesis-core` and `genesis` are **taken on public PyPI** by
  unrelated projects ([genesis-core](https://pypi.org/project/genesis-core/), [genesis](https://pypi.org/project/genesis/));
  `kiro-agent-sdk` and `genesis-appian-parser` are not. A bare-name requirement that pip resolves against PyPI would
  install a stranger's package. Today's direct `git+ssh` references avoid this; any design that drops them must keep
  every internal requirement as a local path or a direct reference.
- **History-preserving merge:** `git subtree add --prefix=<dir> <repo> <ref>` without `--squash` keeps the original
  commits (and their SHAs) as a second parent history; `git filter-repo --to-subdirectory-filter` rewrites SHAs
  ([git-subtree](https://github.com/git/git/blob/master/contrib/subtree/git-subtree.adoc),
  [git-filter-repo](https://github.com/newren/git-filter-repo)).
- **GitLab CI:** `rules: changes` evaluates to true on tag pipelines and pipelines without a push diff; use
  `changes: compare_to` for path filters ([GitLab CI rules](https://docs.gitlab.com/ci/yaml/#ruleschanges)).
- **GitLab archiving** makes a project read-only but still clonable, so old tag pins keep resolving
  ([GitLab archive a project](https://docs.gitlab.com/user/project/working_with_projects/#archive-a-project)).

## 4. Options

Each decision row in §6 names the alternatives considered and why they were rejected:

| Question | Chosen | Rejected | Row |
|---|---|---|---|
| Which repos merge | genesis-core, kiro-agent-sdk, parser | also genesis-workflows | D1 |
| Layout | app at root, libraries under `packages/` | everything under `packages/` | D5 |
| How the app refers to the libraries | not at all (one install command) | bare names; self-referencing git refs | D6 |
| History | `git subtree add`, no squash | squash; fresh copy; `filter-repo` | D7 |
| Versions | one shared version + explicit compat constants | per-package versions | D8 |
| Order | Phase 49 released first | merge folded into the Phase 49 release | D9 |
| CI | every package, every pipeline | path-filtered library jobs | D10 |
| kiro-agent-sdk | aligned (hatchling, 3.13, ruff), POC removed | moved as-is | D11 |
| Agent-system areas | names kept, paths repointed | renamed / regrouped | D12 |
| Old repos | archived with a pointer commit | deleted; left as-is | D13 |

## 5. Prerequisites found

- **START GATE (D9): Phase 50 build work starts only after Phase 49 is released.** Before the first Phase 50
  sub-spec begins, check and record in its As built: (1) `genesis-ctx status` shows `genesis` and
  `genesis-workflows` with **ahead 0** and dirty 0; (2) the Phase 49 umbrella status is `SHIPPED`; (3) the Phase 49
  release tags exist on the remote. If any check fails, stop and report; do not start the history import.
- **Phase 49 (Test Design) is built but not released**: 14 genesis + 2 genesis-workflows commits are unpushed
  (`backup/phase-49-wip` branches exist), migration m0025 and ADR-078/079 are proposed. Phase 50 starts after
  Phase 49 ships.
- `context/state/current.md` and the SessionStart status still say "Active phase: none — Phase 48 complete"; this
  is stale while Phase 49 is in flight (reported to the docs agent).

## 6. Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | Merge `genesis-core`, `kiro-agent-sdk` and `genesis-appian-parser` into the `genesis` repo. `genesis-workflows` stays a separate repo. (User, 2026-10-31.) | The library is runtime-pulled, MR-governed content with its own cadence (ADR-003/005/006/014); merging it would need ADR amendments for no release-overhead gain. |
| D2 | Nothing outside Genesis uses the three libraries, so they need not stay separately installable for third parties. (User, 2026-10-31.) | Removes the need to publish them independently; genesis-workflows' need for `genesis-core` remains (§2.1). |
| D3 | There are no production users; existing installs (the user's own and the fleet) may be reinstalled instead of being carried across by the one-click updater. (User, 2026-10-31.) | Avoids a cross-over shim for the old `updater.py`. |
| D4 | Requirement: every surface keeps working after the merge: install, self-update, developer setup, CI, the fleet, and the agent system (`genesis-ctx`, areas, code map, skills, installer). Analyse all impact areas before deciding the design. (User, 2026-10-31.) | Stated constraint for the phase. |
| D5 | Layout A: the app stays at the `genesis` repo root (`genesis/`, `web/`, `scripts/`, `tests/`, root `pyproject.toml` unchanged); the three libraries move to `packages/genesis-core/`, `packages/kiro-agent-sdk/`, `packages/genesis-appian-parser/`. Layout B (every package under `packages/`, app included) rejected. (User, 2026-10-31.) | A moves only what the merge requires: app paths, app history, install/update, the `frontend`/`clean-install` CI rules and ~85% of the agent system's routing (73 `areas.toml` app lines, 19 app code-map keys) stay as they are. B's benefit is symmetry, which does not pay for ~3x the path changes; B can be a later phase. |
| D6 | Dependency option 3: no internal package lists another internal package in its `pyproject.toml` dependencies (genesis drops `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser`; genesis-core drops `kiro-agent-sdk`). Third-party deps stay where they are. Every install entry point (installer, updater, CI, dev setup) installs the local `packages/*` folders and the app in ONE pip command; a startup/preflight check names any missing library. genesis-workflows pins each library it needs explicitly by `git+ssh://…/genesis.git@vX#subdirectory=packages/<name>`. Options 1 (bare names) and 2 (self-referencing git refs) rejected. A throwaway-venv spike confirms the pip behaviour first. (User, 2026-10-31.) | Only option that never resolves an internal name against public PyPI, where `genesis-core` and `genesis` are taken by unrelated projects (§3); installs stay offline and the libraries always come from the same checkout. Option 2's release commit must name a not-yet-existing tag. |
| D7 | Import the libraries' history with `git subtree add --prefix=packages/<name> <repo> <branch>` **without `--squash`** (one merge commit per library; original commits and SHAs kept). Old library tags are not imported (they collide with genesis's `vX.Y.Z`); they stay in the archived repos. The import is pushed to a scratch branch first and its CI must pass before it reaches `master`; if it goes through an MR, squash must be off. Squash and fresh-copy options rejected; `git filter-repo` rejected (rewrites SHAs, not installed). (User, 2026-10-31, on condition that the GitLab instance supports it — verified, §2.7.) | Keeps `log`/`blame` and every SHA cited in progress docs and As-built sections resolvable in one repo at small size cost. |
| D8 | One shared version for all four packages: every `pyproject.toml` (app + `packages/*`) carries the repo tag's version (first: 0.79.0 or whatever the Phase 50 release is), and a CI test fails if any differ. Compatibility is carried by explicit constants, not package versions: `CORE_MAJOR` (unchanged, still the ADR-019 loader gate) and a new parser constant (working name `KB_FORMAT_VERSION`), bumped only when the parse output needs a full re-sync; `sync-application` compares it instead of the parser's `__version__` minor (`genesis-workflows/workflows/sync-application/graph.py:52,197-211`). ADR-019 is amended (proposed, written by the docs agent at release): the `CORE_MAJOR` gate and additive-only-within-a-major stay; "genesis-core follows semver" becomes "genesis-core's pip version is the platform version". Separate per-package versions rejected. (User, 2026-10-31.) | Nothing reads genesis-core's or the SDK's version for behaviour (the loader checks only `CORE_MAJOR`, `dist/loader.py:41-47`; `genesis_core_version` is only recorded in the lockfile, `dist/install.py:72,80`). The parser's minor version drives full re-syncs today, so with lockstep versions it must first move to an explicit format constant, else every Genesis minor release forces a full sync of every app. One number removes per-package bump bookkeeping and drift (the L-057 class of mistake). Cost: one forced full sync per app when the new marker is first recorded (the sub-spec may map recorded parser 0.3.x to the first format value to avoid it). |
| D9 | Order: Phase 49 (Test Design) is released first; Phase 50 starts only after that. The first Phase 50 build sub-spec (and the umbrella's session plan) opens with the start gate in §5: confirm Phase 49 is released before any work. Folding the merge into the Phase 49 release rejected. (User, 2026-10-31.) | Keeps each release about one thing; a fault in the install/update restructuring is not mixed with a feature release, and either can be rolled back alone. |
| D10 | CI runs every package's lint and tests on every pipeline: one job per package (`genesis`, `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser`), all in parallel, no `rules: changes` path filters on them. The `frontend` and `clean-install` filters stay; `clean-install` adds `packages/**/*`. kiro-agent-sdk gets CI and a pinned ruff for the first time (L-025/L-027). Path-filtered library jobs rejected. (User, 2026-10-31.) | The app job (~10.5 min) sets the wall time and the library jobs (~1.5–2.3 min) finish inside it, so always-run costs no waiting time, only ~4–6 runner-minutes on app-only pipelines. Path filters would need dependency-aware lists, `compare_to` with a depth-20 clone, and still run everything on tags; a stale list skips tests silently (L-030). Filters can be added later if runner minutes become a constraint. |
| D11 | Align kiro-agent-sdk with the other packages as it moves in: hatchling build backend, `requires-python = ">=3.13"` (ADR-024), `ruff==0.15.20` in its dev extra with line length 100 (as genesis-core), `src/` layout kept. Its proof-of-concept files are removed in one commit: `workflows/erd_workflow.py`, `tests/test_erd_workflow.py`, `examples/quickstart.py`, `.env.example` (an Atlas/Lucid/LCP template with empty values; Atlas retired by ADR-036). Their history stays in git and the archived repo. Moving it unchanged rejected. (User, 2026-10-31.) | All four packages build and declare Python the same way, which keeps the single install command (D6), the version-sync test (D8) and the release skill uniform; CI stops linting and testing an Atlas-era script nobody runs (last changed in the repo's first two commits). Flattening `src/` would change import setup and agent-system globs for no gain. |
| D12 | Agent-system routing: keep the area names `core-engine`, `sdk-acp`, `parser` (and `chat`'s SDK glob) and only repoint their `paths` to `genesis/packages/genesis-core/genesis_core/**`, `genesis/packages/kiro-agent-sdk/src/**`, `genesis/packages/genesis-appian-parser/genesis_appian_parser/**`, and their `gates` to run from the package directory with the shared `genesis/.venv` (the SDK's own `.venv` is retired). ADR and lesson tags are untouched, so every pack loads the same rules as before, at the new paths. In the same phase: an area glob matching no files becomes a lint **error** (today a warning); a `genesis-ctx` test proves a changed file under `genesis/packages/<lib>/` maps to its area; the repo lists in `genesis-ctx` (`config.py:8,12`) and the agent installer (`genesis_installer.py:32`) shrink to `genesis`, `genesis-workflows` (+ project-tracker); the code-map keys and `bible/03` repo headers move in lockstep. Restructuring or renaming the areas rejected. (User, 2026-10-31.) | The merge moves files, not responsibilities, so the same rules must keep reaching the same code. Renaming would force retagging every ADR/lesson and a recall check. Today a stale glob fails silently and reviews would stop loading the core-engine/sdk-acp/parser rules (§2.5); the lint error and routing test close that gap. |
| D13 | The three old repos (genesis-core, kiro-agent-sdk, genesis-appian-parser) are **archived, never deleted**: one last commit replaces each README with a "moved to `genesis/packages/<name>/`" pointer, then the GitLab project is archived (read-only, still clonable). Done in the release sub-spec only after genesis-workflows is re-pinned to the genesis repo and its CI is green. The local checkouts are moved to `~/repo-gitlab/ramaswamy.u/_archived/`, not deleted, once the agent installer no longer needs them (D12). The release agent asks the user before each archive and each move. Deleting the projects and leaving them as-is rejected. (User, 2026-10-31.) | Archived projects keep every old tag pin installable (genesis ≤ v0.78.0, older genesis-workflows tags), so old releases and rollback still work; old SHAs stay resolvable twice (D7 + archive); read-only prevents commits to the wrong repo; GitLab can unarchive. Deleting is irreversible and gains only a few MB. |
| D14 | ADR-080 amends **ADR-046** as well as ADR-019 (distribution stays clone + venv + install + git-tag self-update; only the install step changes to the one install command over the local packages). Defaults F1–F6 (umbrella §10) accepted as written. (User, 2026-10-31, on review of the spec set.) | D6 changes the two things ADR-046's rule text names (`pip install .`, `git+ssh` tag pins); the deviation was flagged and confirmed. |

## Context manifest

```toml
areas    = ["distribution", "release-ci", "core-engine", "sdk-acp", "parser", "workflows-library", "kb-sync"]
adrs     = ["ADR-003", "ADR-006", "ADR-016", "ADR-019", "ADR-024", "ADR-046", "ADR-077"]
lessons  = ["L-025", "L-027", "L-030", "L-048", "L-051", "L-056", "L-057", "L-087", "L-088"]
code     = ["genesis/pyproject.toml", "genesis/.gitlab-ci.yml", "genesis/scripts/install.sh",
            "genesis/genesis/runtime/updater.py", "genesis-core/pyproject.toml", "kiro-agent-sdk/pyproject.toml",
            "genesis-appian-parser/pyproject.toml", "genesis-workflows/pyproject.toml"]
docs     = ["tracker:context/areas.toml", "tracker:agent-system/tools/genesis_ctx/config.py"]
upstream = []
```
