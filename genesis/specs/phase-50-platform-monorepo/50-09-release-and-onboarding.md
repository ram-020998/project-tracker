# 50-09 — Release and onboarding

> **Status:** SPEC-DRAFTED 2026-10-31. Agents: **genesis-release** (asks before every tag, push, archive and move),
> then **genesis-docs**. Repos: genesis, genesis-workflows, project-tracker; GitLab projects genesis-core,
> kiro-agent-sdk, genesis-appian-parser. Parent: `specs/phase-50-platform-monorepo.md`. After 50-08 = SHIP.
> Decisions: D3, D7, D8, D13.

## 1. Release order

1. **genesis v0.80.0.** On `phase-50-monorepo`: bump all four `pyproject.toml` versions, the parser `__version__`,
   the `create_app` version and `web/src/version.ts` to 0.80.0 (the version-sync test proves it); `npm run build` +
   commit `web/static/` only if web changed (separate sequential steps, L-089). `git status` clean after the commit
   (L-056). Fast-forward `master` to the branch; tag `v0.80.0`; push `master` + tag (ask). CI green on both.
2. **genesis-workflows v0.24.0.** Its 50-07 commits on `master` (pins already name v0.80.0); bump the version; tag;
   push (ask). CI green — the first run that resolves the subdirectory pins against GitLab.
3. Delete the scratch branches locally and on `origin` (ask).

## 2. Reinstall (D3)

- No run active on either fleet instance. The dev venv was rebuilt in 50-03; reinstall it once more from `master`
  (`scripts/install-packages.sh --editable --dev`).
- Any managed install (`~/.genesis/dist.json` present): fresh `scripts/install.sh`. No in-place update from ≤ v0.79.0:
  **do not click the update banner** on a v0.79.0 install. Its old updater runs `pip install .`, which installs the
  v0.80.0 app but keeps the old libraries (50-05 As built). Say so in the release notes / changelog too.
- Fleet: `gsm provision --all --no-mcp --no-env --force`, `gsm restart --all`, `genesis install` of genesis-workflows
  v0.24.0 on each instance **in the same step** (it carries `sync-application` 0.3.1; an instance running the v0.80.0
  parser with the old 0.3.0 workflow would re-export every app in full, 50-07 As built). Verify `/openapi.json`
  `info.version` = 0.80.0 and `GET /api/workflows/sync-application` = 0.3.1 on both. The live incremental-sync check
  is **not** done here (D22, dev environment down): see §5.

## 3. Archive the old repos (D13) — ask before each project

Only after §1 step 2 is green. For each of genesis-core, kiro-agent-sdk, genesis-appian-parser:

1. In the old local checkout, one commit replacing `README.md` with: "Moved into the genesis repo at
   `packages/<name>/` (history preserved) as of genesis v0.80.0. This repository is archived; old tags remain for
   installs of genesis ≤ v0.79.0." Push it (ask). For **genesis-core** the commit message must contain `[skip ci]`:
   its `GITLAB_PUSH_TOKEN` variable was deleted (D20), so its pipeline could no longer clone kiro-agent-sdk.
2. Archive the GitLab project (ask): `glab api -X POST projects/<id>/archive` (ids: genesis-core 14328,
   kiro-agent-sdk 14306, genesis-appian-parser 14520). Confirm `archived: true`.
3. Move the local checkout to `~/repo-gitlab/ramaswamy.u/_archived/<name>` (ask). Confirm `genesis-ctx status` and
   `agent-system/update.sh` still work (50-04 removed the dependency on them).

## 4. Docs write-back (genesis-docs)

- **ADR-080** from the umbrella §12 via `genesis-ctx add adr --amends ADR-019,ADR-046`, areas `distribution,
  release-ci, core-engine, sdk-acp, parser`.
- `context/L0-core.md` §2 (repo list: genesis with `packages/`, genesis-workflows; the old repos archived) — within
  the ≤ 4K-token budget.
- `context/state/current.md`: one platform row (genesis v0.80.0, packages at 0.80.0, `CORE_MAJOR=1`) + genesis-workflows
  v0.24.0; the new dependency chain; test counts per package; "what works" line for the monorepo.
- Code map (already moved in 50-04) — add `scripts/install-packages.sh`, `tests/test_version_sync.py`, the CLI missing-library check (D15). `progress/phase-50-platform-monorepo.md`; `changelog.md`; README row 50 → SHIPPED; tracker §6.
- Lessons from the build via `genesis-ctx add lesson`. Record the Phase 50 **L-089 recurrences** on the existing
  lesson (not a new one): 50-03 sent the three subtree merges in one batch; 50-04 twice ran the clean-tree check in
  the same batch as the commit; 50-08 genesis-release ran a CI check in the same batch as two pushes. All were verified correct afterwards. Also a **new lesson** (D20): `glab api
  projects/<id>/variables` returns CI/CD variable **values** in clear (masking applies only to job logs) — never call
  it from an agent; and consider a `shell-guard.sh` rule that refuses `glab api …/variables` (L-088: test it with a
  bypass and a positive corpus). `genesis-ctx index && lint` green.

## 5. Acceptance

- [ ] genesis v0.80.0 and genesis-workflows v0.24.0 tagged, CI green (pipeline ids recorded).
- [ ] Fleet on 0.80.0 with `sync-application` 0.3.1 on both instances.
- [ ] **After the release (D22, user):** on the first weekday scheduled sync (Monday 2026-11-02), each instance's newest
      `kb_syncs` row is incremental with `details.kb_format_version` = 1; record it in §6 As run. A full re-export
      instead → open a follow-up fix (not a rollback).
- [ ] Three projects archived with the pointer commit; local checkouts in `_archived/`.
- [ ] ADR-080 recorded; docs write-back done; lint green.

## 6. As run

*(filled by genesis-release / genesis-docs)*

### As run (2026-11-01, genesis-release) — §1–§3

- **Versions:** genesis **v0.80.0** (the app and the three packages, one shared version: the four `pyproject.toml`,
  the parser `__version__`, `create_app`, `web/src/version.ts`; `tests/test_version_sync.py` 6 passed); `CORE_MAJOR` 1
  and `KB_FORMAT_VERSION` 1 unchanged. genesis-workflows **v0.24.0** (`pyproject.toml` only; the four pins on
  `genesis.git@v0.80.0` and `registry.json` `genesis_core_version` 0.80.0 / major 1 came from 50-07).
- **Commits:** genesis `080ef7c` (release: the 7 version locations + README status line + rebuilt `web/static`, 69
  files; web source unchanged in Phase 50 apart from `version.ts`, which the sidebar renders). After the commit a fresh
  `npm run build` left `git status --short --untracked-files=all` empty (own call, L-056/L-089). genesis-workflows
  `a365e60`. Both `master` branches fast-forwarded from the `phase-50-monorepo` branches (genesis 74 + 1 commits on
  `908e5d4`; genesis-workflows 4 + 1 on `04c242e`).
- **Gates before tagging:** genesis app pytest **1418** passed; packages: genesis-core **96**, kiro-agent-sdk **79**,
  genesis-appian-parser **53** + 1 skipped (`test_diff_hash`: two real exports not provided); `ruff` as CI runs it
  (`genesis`, `genesis_core`, `src tests`, `.`) clean; web vitest **467** (50 files). genesis-workflows (dev venv):
  `validate_library` PASSED (14, gate 9 OK), `validate_skills` PASSED (3), workflow tests **317** passed.
- **Tags** (annotated, asked + confirmed each): genesis `v0.80.0` → `080ef7c`; genesis-workflows `v0.24.0` → `a365e60`.
- **Pushes** (asked + confirmed each): genesis `master` + `v0.80.0` (`908e5d4..080ef7c`, fast-forward);
  genesis-workflows `master` + `v0.24.0` (`04c242e..a365e60`, fast-forward).
- **CI:**
  - genesis **#7259141** (`master`) and **#7259142** (`v0.80.0`) — success; all six jobs green (`genesis`,
    `genesis-core`, `kiro-agent-sdk`, `genesis-appian-parser`, `frontend`, `clean-install`).
  - genesis-workflows **#7259218** (`master`) and **#7259219** (`v0.24.0`) — success (`library-validate`,
    `skills-validate`, `workflow-tests`). The first remote run of the subdirectory pins: the `library-validate` log
    shows `INTERNAL-PIN CHECK PASSED` before the token rewrite and the install (H2 remote proof), then all four internal
    packages collected from `genesis.git@v0.80.0` (three with `#subdirectory=packages/<name>`), then `LIBRARY
    VALIDATION PASSED (14 workflow(s) validated)`.
- **Scratch branches** (asked + confirmed): `origin/phase-50-monorepo` of genesis deleted; local `phase-50-monorepo`
  deleted in genesis and genesis-workflows (`-d`; the genesis-workflows branch was never pushed). `genesis-ctx status`:
  both repos on `master`, 0 dirty, 0 ahead.
- **§2 fleet** (go-ahead given): no run active on :8760/:8761; `gsm stop --all` (no `-wal`/`-shm` left); `genesis.db`
  + `memory.db` of both instances copied to **`/tmp/genesis-50-09-backup/{main,userb}/`** (the shell guard refuses
  `~/genesis-backups`; `/tmp` as in D18; cleared on reboot), SHA-256 equal to the sources, `integrity_check` ok on all
  four; dev venv reinstalled from `master` (`scripts/install-packages.sh --editable --dev`: all four at 0.80.0,
  imports from `genesis/packages/…`); `gsm provision --all --no-mcp --no-env --force` (genesis-workflows v0.24.0,
  `sync-application` 0.3.1); `gsm start --all` → main pid 93609, userb pid 93671. Both: `/openapi.json`
  `info.version` **0.80.0**, `GET /api/workflows/sync-application` **0.3.1**, `/api/config/health` 200, 0 running runs,
  no pending migration. No managed install (`~/.genesis/dist.json` absent), so no `install.sh` reinstall.
- **§3 archive:**
  - Pointer commits (README replaced with the §3 text; asked + confirmed each push): genesis-core `661ae8c`
    (`[skip ci]`; pipeline **#7259247** skipped), kiro-agent-sdk `b40c560` (no CI configured), genesis-appian-parser
    `38f0832` (pipeline **#7259260** success).
  - **GitLab archive: DEFERRED to the user.** `glab api -X POST projects/14328/archive` returned **HTTP 403**: glab's
    token has read scope only (no `api` scope; the user is Owner, access level 50). The user archives genesis-core
    (14328), kiro-agent-sdk (14306) and genesis-appian-parser (14520) in the GitLab UI.
  - Local moves to `_archived/`: **DEFERRED by the user** (checkouts left in place until the projects are archived).
- **Deviations / follow-ups:**
  - **L-089 recurrences (for genesis-docs, on the existing lesson):** genesis-release batched order-dependent steps
    or a verifying read with its step about a dozen times in this release: build + status, add + status, add + commit,
    checkout/ff + verify (both repos), tag + verify, push + `ci list` (both repos), remote branch delete + local
    `-d`, run check + `gsm stop`, `mkdir` + `cp`, `cp` + checksum, `gsm start` + `gsm provision`, README write + add,
    commit + log. Each outcome was re-verified in its own call and was correct. The riskiest one, the run check
    batched with `gsm stop`, ran before the stop and still read 0 runs on both instances. A rule in the prompt does
    not stop the agent from batching; a structural guard may be needed (e.g. a hook that refuses a mutating command
    in a parallel batch).
  - README of genesis still says "migrations m0001–m0024 (DB v24)" (stale since Phase 49; genesis-docs).
  - Row 6 / §5 Monday sync check (D22) stays with the user.

## Context manifest

```toml
areas    = ["release-ci", "distribution", "workflows-library", "security"]
adrs     = ["ADR-016", "ADR-019", "ADR-046", "ADR-077"]
lessons  = ["L-030", "L-033", "L-056", "L-057", "L-061", "L-089"]
docs     = ["tracker:specs/phase-50-platform-monorepo.md", "tracker:specs/phase-50-platform-monorepo/50-08-review-and-acceptance.md"]
code     = ["genesis/pyproject.toml", "genesis/packages/**", "genesis-workflows/pyproject.toml", "genesis-workflows/registry.json"]
upstream = ["50-07", "50-08"]
```
