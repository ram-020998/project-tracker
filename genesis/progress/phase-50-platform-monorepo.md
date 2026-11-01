# Phase 50 — Platform monorepo: genesis-core, kiro-agent-sdk and the parser move into the genesis repo — as built

> **Status:** ✅ SHIPPED 2026-11-01 · genesis **v0.80.0** (`080ef7c`; the app and `packages/genesis-core`,
> `packages/kiro-agent-sdk`, `packages/genesis-appian-parser`, all at 0.80.0) → genesis-workflows **v0.24.0** (`a365e60`;
> `sync-application` 0.3.1, all four internal pins on `genesis.git@v0.80.0`) · no migration (DB v25; memory.db v1) ·
> **ADR-080** Accepted (amends ADR-019, ADR-046). `CORE_MAJOR` 1 and `KB_FORMAT_VERSION` 1 unchanged.
> Spec: `specs/phase-50-platform-monorepo.md` + `50-01..50-09` (each has its As built / As run; H1, H2 in 50-08 §5).
> Reviews: `specs/phase-50-platform-monorepo/reviews/` (all SHIP). Follow-ups: `specs/backlog/phase-50-follow-ups.md` (§1–§6).
> CI: genesis master #7259141 + tag #7259142 (six jobs); genesis-workflows master #7259218 + tag #7259219; scratch-branch
> pipelines #7258881 (all six jobs) and #7259044 (H1). Old-repo pointer commits: genesis-core `661ae8c` (`[skip ci]`),
> kiro-agent-sdk `b40c560`, genesis-appian-parser `38f0832` (#7259260). Fleet (main :8760, userb :8761) on 0.80.0 on 2026-11-01.

## What changed

- **For a user:** nothing in the app. Installing needs SSH access to the genesis repo only. An install of v0.79.0 or
  older must be reinstalled from a fresh clone: its update banner runs the old updater (`pip install .`), which installs
  the new app but keeps the old libraries. No managed install existed (`~/.genesis/dist.json` absent).
- **For a developer:** one clone; the dev venv is `scripts/install-packages.sh --editable --dev`; the gates of each
  package run from `genesis/packages/<name>` with the shared venv (`bible/05` §6). One tag releases everything; the
  version lives in seven places that `tests/test_version_sync.py` keeps equal. Old library history: `git blame` or
  `git log <subtree-merge>^2 -- <old path>`.
- **For the agent system:** two code repos in `genesis-ctx` and the installer; the core-engine, sdk-acp and parser
  areas route `genesis/packages/…`; an area glob matching nothing is a lint error; recall identical before and after.

## Delivered (by sub-spec)

| Sub-spec | Result | Commits |
|---|---|---|
| 50-01 | Findings, decisions D1–D22, defaults F1–F6 | — |
| 50-02 | Start gate passed; throwaway spike GO for D6: one pip command over local folders never asks an index for an internal name (pip 25.1.1 and 26.2.2), subdirectory pins and partial clone work, pip always reinstalls local folders | — |
| 50-03 | Three unsquashed `git subtree add` imports (12 + 37 + 11 commits, SHAs kept, no library tag imported); SDK on hatchling/3.13, POC files removed; internal deps removed; fixture paths; CLI missing-library check (D15); dev venv rebuilt; review SHIP | genesis `c8c6982`, `40c4a8e`, `1cada22`, `8706a50`, `06ace89`, `aa17d27`, `7cb9f1c` |
| 50-04 | `areas.toml` paths + gates, D16 CLI mapping, empty glob = lint error, repo lists, code-map keys + `bible/03` headers moved by script, skills; agent-system tests 247; recall identical | project-tracker |
| 50-05 | `scripts/install-packages.sh`; `install.sh` and the updater call it; updater `_scope` by path diff; README, INSTALL.md, package READMEs; throwaway install served the SPA; review SHIP | genesis `9581140`, `25f384e`, `4ce99c9` |
| 50-06 | CI: four always-on parallel package jobs on a shared template, `clean-install` via the script, no `insteadOf`; SDK lint clean unchanged; review SHIP | genesis `012b59c` |
| 50-07 | Shared version + sync test; `KB_FORMAT_VERSION`; `--dev` installs each package's own `[dev]`; `sync-application` 0.3.1 on the format; genesis-workflows pins + `registry.json`; D18 early fleet install of 0.3.1; review SHIP | genesis `fb4a160`, `34d6dab`; workflows `bc1124c`, `7e42fc9` |
| 50-08 | Whole-phase review SHIP; scratch-branch CI green; acceptance rows 1–5, 7–9 PASS, row 6 DEFERRED (D22). H1: no-internal-dependency test + workflows gate 9. H2: gate 9 moved to stdlib-only `ci/check_internal_pins.py`, run before the token and the install (D20) | genesis `77ea311`; workflows `6968bb8`, `e4af068` |
| 50-09 | Release v0.80.0 → v0.24.0 (asked before each tag and push), scratch branches deleted, fleet backed up and reinstalled, old-repo pointer commits, this write-back | genesis `080ef7c`; workflows `a365e60` |

Tests at release: genesis app pytest **1418** (1366 at v0.79.0: +5 CLI, +3 platform, +8 updater, +7 script, +11 version-sync and install-script tests (50-07), +18 internal-dependency); web vitest **467** (50 files, unchanged); genesis-core **96** (the 91 in
the previous state file was stale; 96 at v0.9.8 too); kiro-agent-sdk **79** (93 − 14 removed ERD tests);
genesis-appian-parser **53** + 1 skipped (51 + 2 `KB_FORMAT_VERSION` tests); genesis-workflows `validate_library` 14
(gate 9 added), `validate_skills` 3, pytest **317** (305 + 12 sync tests).

## Live acceptance (50-08 §3)

Fresh clone of the scratch branch installed, migrated and served the SPA; a missing parser made `genesis status` exit 1
with the one-line message, the script fixed it; the dry-run report showed no index lookup for an internal name; the dev
venv imports every library from `genesis/packages/`, and the three parser-fixture tests ran (not skipped); the fleet
restarted on branch code ran `hello-appian` to completion (the worker imports the libraries); genesis-workflows gates
green against the dev venv; updater scope by path diff; `genesis-ctx status`, `pack 50-07` and `check --files` on a
moved core file load the core-engine rules. **Row 6** (a live incremental sync on parser 0.80.0 + `sync-application`
0.3.1) is **DEFERRED** (D22: the dev environment was down on 2026-11-01): the user reads each instance's newest
`kb_syncs` row after the first weekday scheduled sync (Monday 2026-11-02); expected incremental with
`details.kb_format_version` = 1, and a full re-export → a follow-up fix, not a rollback.

## Decisions and deviations (all in the sub-specs; no ADR deviation)

- History check uses `git blame` / `git log <merge>^2`, since path-limited `git log` on the new prefix shows only the
  merge (50-02, 50-03).
- CLI message names the `packages/` folders; `genesis --help` also prints it when a library is missing (D15, 50-03).
- Provenance test uses PEP 610 `direct_url.json`, so CI package jobs install editable (50-03, 50-06).
- `install-packages.sh --python` defaults to `<repo>/.venv` (never a system interpreter); the updater runs it with
  `bash <path>` from the target tag (50-05). The updater `scope` label is always `deps` now; retiring it is backlog §1 (D17).
- CI: GitLab `extends` instead of a YAML anchor; no separate version-sync job (the `genesis` job collects the test) (50-06).
- `KB_FORMAT_VERSION` fallback: a record without the marker counts as format 1 when `parser_version` ≥ 0.3 (widened
  from "minor 3", F4) (50-07). genesis-workflows ruff stays unpinned (20 pre-existing findings; backlog §3).
- Gate 9 is stricter than the spec: `vX.Y.Z` tags only, exact `packages/<name>` subdirectory, one repo URL (H1); it runs
  with `python -I` before the token rewrite (H2). The host is not pinned (review nit, no action).
- D20: a spec-agent `glab api …/variables` call printed `GITLAB_PUSH_TOKEN`; the user deleted the variable from genesis
  and genesis-core, revoked the token and set a new one only in genesis-workflows. D21: protecting genesis-workflows'
  refs and token deferred (backlog §4). D22: released without row 6.
- 50-09: the fleet backup went to `/tmp/genesis-50-09-backup/` (the shell guard refuses `~/genesis-backups`; cleared on
  reboot). The GitLab archive call returned 403 (glab's token is read-only), and the user deferred the `_archived/`
  moves: both stay with the user (projects 14328, 14306, 14520).

## Lessons (write-back decisions)

| Candidate (source) | Decision |
|---|---|
| No internal deps → `pip check` cannot see a missing library; check before the first internal import (50-02) + stale sibling editable installs import silently, test PEP 610 origin (50-03) + prove import order with `sys.modules[name] = None` (50-03) | **Added L-098** (merged) |
| Unify versions only after version-keyed behaviour has its own constant; an editable venv makes the bump live at commit (50-07) + map "no marker" to the lowest guaranteed format (50-07) | **Added L-099** (merged) |
| `glab api …/variables` returns values in clear; never call it from an agent (D20, 50-09 §4) | **Added L-100**; a `shell-guard.sh` rule is backlog §6 (proposed, not built) |
| L-089 recurrences: 50-03 subtree merges, 50-04 check + commit (twice), 50-07 edit + add + commit, 50-08 push + CI check, about a dozen in the 50-09 release, three batched `add lesson` calls in this write-back | **Extended L-089**; structural guard = backlog §5 |
| A checker's self-proof must cover every rule, including cross-entry ones (50-08 H1) | **Extended L-088** (same rule family: every guard needs a corpus that exercises it) |
| Subtree history needs `blame` / `log <merge>^2` (50-02) | **Routed** to `bible/05` §6 (a how-to, not a rule) |
| A script that `cd`s must make relative paths absolute first (50-05) | **Dropped**: fixed and covered by `tests/test_install_packages_script.py`; generic shell practice |
| macOS: a freshly written file or a new venv's pip may not be visible for seconds (50-05) | **Dropped**: not root-caused; INSTALL.md says to re-run; the before/after proofs used were direct runs |
| Library CI jobs depended on the root dev extra being a superset (50-06) | **Dropped**: fixed structurally (`--dev` installs each package's own `[dev]`, tested) |
| `genesis status` reports the default port (50-06) | **Backlog** §2 |

## Agent-system notes

1. L-089 recurred in nearly every session, including this write-back: three `genesis-ctx add lesson` calls in one
   batch (ids L-098–L-100 verified in a separate call and matched their bodies), `index` with `lint`, and `git status`
   with `git add` (lint and the staged set were re-checked alone afterwards). Rules in prompts and skills do not
   prevent it; backlog §5 asks for a spike of what the Kiro CLI exposes before designing a guard.
2. The `genesis-release` skill now names ADR-080 directly, the six-job CI-green set and the GitLab API limits (archive and
   variables are the operator's; never call the CI-variables API). The operator runs `agent-system/update.sh`.
3. The genesis repo `README.md:18` still says "migrations m0001–m0024 (DB v24)" (stale since Phase 49). It is code-repo
   text, outside the docs agent's write roots: fix it with the next genesis commit.
