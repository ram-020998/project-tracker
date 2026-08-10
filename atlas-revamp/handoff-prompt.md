# Session Handoff Prompt — Atlas Data-Generation Skills + MCP (as of 2026-08-10)

> Paste into a new session to continue with **no context lost**. This document is self-contained but the
> running log in `work-tracker.md` is the authoritative detail. Read §0, then jump to §7 CURRENT STATE and
> §10 NEXT STEPS.

---

## 0. Read first (source of truth)
- `work-tracker.md` — complete running log. Latest and most relevant: **§13** (action-specific rebuild),
  **§14** (MR !101 review + branch split), **§15** (determinism `dg` CLI rebuild), **§16** (ERD→MCP migration,
  gates, secret cleanup, clean rebase, final MR-!101 coverage, handoff). §16.7 = the live handoff state.
- `design-action-specific-skills.md` — target architecture + decisions + the **prompt-path rule** + the skill
  validation standard.
- `mr-92-review-responses.md` — original MR !92 comments (historical).
- `00`–`05` phase docs — **STALE** original plan; history only.

## 1. Goal & where it landed
Convert four Atlas Kiro *Powers* (SQL Forge / data-gen, Product Owner, UX Designer, + ERD) into
**action-specific skills clustered by functionality**, each with a **persona agent**, in the `solutions-os`
repo — matching the repo convention (`a11y-expert`, `appian-dev`, `dev-automated-testing`, `integration-*`)
and addressing the MR !92 / !101 reviews.

**The data-generation domain is essentially DONE and MR-ready** (this is where nearly all recent work went).
Product-Owner and UX-Designer domains were built earlier but are **not yet cleaned/re-MR'd** (see §10).

## 2. Repos, remotes, and workflow rules
Two repos are in play:

**A. `solutions-os` (the skills + agents)** — `/Users/ramaswamy.u/repo-gitlab/appian/solutions-os`
- Remotes: `dev` = `git@…:appian/dev/solutions-os` (**push here only**); `origin` = `appian/prod/solutions-os`
  (MR target, branch `main`).

**B. `solutions-atlas-dg-mcp-server` (the Data Generator MCP server — Python)**
- Prod: `appian/prod/solutions-atlas-dg-mcp-server` (project id 14461); dev fork `appian/dev/…` (id 14462).
- Local personal source: `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-data-generator-mcp`.
- Image: `registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-dg-mcp-server:latest`.

**Workflow rules (both repos):**
- **Push to the dev fork only.** **Humans create MRs** via the dev-fork UI link — the agent/`glab` token
  returns **403 `insufficient_scope`** on MR create (read is fine: `glab api projects/appian%2Fprod%2Fsolutions-os/merge_requests/<iid>/discussions`).
- Single clean commit per branch where possible. New branches push plain; updates use
  **`--force-with-lease` ONLY on non-shared branches**. **Never force-push a shared branch** (`feature/atlas-sql-forge`
  is shared with colleagues' performance work — leave it alone).
- **Secrets:** all env values are `${VAR}` / `<placeholder>` — **never commit real tokens.** (See §9 — 4 tokens
  were once committed and MUST be rotated.)

## 3. Architecture (the mental model)
Per domain: **one persona agent** (`.kiro/agents/<domain>.json`) that is the hub/router, listing its
**action-specific skills** (`.kiro/skills/<domain>-<action>/SKILL.md`) in `resources`, with **shared docs**
under `.kiro/resources/<domain>/` (agent `prompt.md` + workflow + tool references).

**Data-generation specifics:**
- **Two data sources:** `appian-atlas` MCP (read-only: schema, write-graph, reference data) and
  `appian-data-generator` MCP (write: create/query records, CDT, coverage, **and now the ERD tools**).
- **Determinism engine — the `dg` CLI.** The mechanical, deterministic parts of the workflow are a
  **stdlib-only Python CLI** at `.kiro/resources/data-generator/scripts/dg.py` (library modules in `dglib/`).
  The agent parameterizes it; it does pure on-disk work and **never calls MCP/network**. This is the answer to
  the reviewer's "too much MD / not deterministic" (#15/#20.4).
- **Two generation modes** converging on the same execution:
  - **Manual** (`workflow/manual/step-1..5` + `step-4b` coverage gate) — trace the write-graph from scratch.
  - **Auto-analysis** (`workflow/auto-analysis/auto-1..4`) — clone-and-scale a user-provided reference record.
  - Common **`workflow/step-0-initialize.md`** (`dg init`) sits above both.
- **Gates enforce correctness (the LLM cannot shortcut them):**
  - `dg coverage-gate` (manual step-4b) — payloads vs `resolve_write_set`; HARD BLOCK.
  - `dg build-footprint` (auto) — **footprint completeness gate**: hard-fails listing any planned table with no
    `raw/auto-analysis/<table>.json` capture (cited escape hatch `--exclude TABLE="reason"`). Added after a live
    test missed tables (§16.3).
  - `dg validate` (step-5/E4) — schema + FK + membership + coverage reconcile.
  - `dg check-fields` — field coverage + mandatory `field_reasoning` for every populated field/deliberate null.

## 4. `solutions-os` data-generator layout
```
.kiro/agents/data-generator.json         # persona agent; MCPs appian-atlas + appian-data-generator; prompt=file://../resources/data-generator/prompt.md
.kiro/skills/
  data-generate-records/                 # live records (≤~50) — SKILL.md + references/create-records.md
  data-generate-sql/                      # bulk INSERT script — SKILL.md + references/generate-sql.md
  data-generate-erd/                      # ERD via the DG MCP ERD tools — SKILL.md + references/generate-erd.md
.kiro/resources/data-generator/
  prompt.md                              # agent seeding: sources, HARD RULES, router, dg CLI, MCP catalogs
  workflow/
    step-0-initialize.md                 # common (dg init); explains dg invocation + DG_STATE targeting
    manual/       step-1..5 + step-4b-coverage-gate.md
    auto-analysis/ auto-1..4 (reference-intake, footprint-discovery, clone-scale-plan, validation)
  tools/  README.md, tool-reference-atlas.md, tool-reference-data-generator.md   # each opens with MCP "steering"
  scripts/
    dg.py                                # entry CLI (run from repo root)
    dglib/  state, gate, scaffold, footprint, fields, coverage, validate, sql_emit  + config/ + schemas/
    tests/  pytest suite (89 tests) + fixtures
    ruff.toml, .gitignore
```
**Invocation contract (documented in prompt.md + step-0):**
- `python3 .kiro/resources/data-generator/scripts/dg.py <subcommand>` from the repo root (stdlib-only, any
  `python3` ≥ 3.9). Folder subcommands take `--dir <request-folder>`; **`gate`/`state` use the global
  `--state <folder>/state.json`** (or `export DG_STATE=<folder>/state.json`).
- **Run the test suite with `python3.13 -m pytest`** (system `python3` is 3.14 with no pytest).

**Notable design points / decisions:**
- The `data-generate-manage` skill and **rollback were removed** (owner decision) — explore/query were workflow
  mechanics (covered by the tool-reference), not user-facing skills.
- **HARD RULE** in prompt + skills: run the deterministic `dg` steps; persist MCP outputs to `raw/`;
  materialize `payloads/`; generate gate reports via `dg` (don't hand-write them or set a gate PASS to skip).
- **D12 documents:** on BOTH manual (step-4) and auto (`auto-3`) paths, Document-type fields (e.g. `appianDocId`)
  must be resolved via the DG MCP document library (`find_document`/`list_documents`) — never copied from the
  reference or invented (§16.4).

## 5. The Data Generator MCP server (ERD lives here now)
- Branch `feature/erd-tools` on the dev fork — **MERGED to prod, image built**. ERD tools are **live**.
- Python package using the **`mcp` SDK**, Dockerized. `requirements.txt` pins **`mcp<2.0.0`** (2.0.0 removed
  `Server.list_tools()`/`Tool.inputSchema` and broke CI).
- ERD internals: `data_generator/erd/` (`layout`, `router`, `render`, `packaging`, `input_builder`, `lucid_api`)
  — a from-scratch Go→Python port of the former personal `erd-gen`; no personal repo, no external CLI.
- **5 ERD MCP tools:** `build_erd_input`, `generate_erd` (upload; `dry_run:true` returns the Lucid doc offline,
  no token), `update_erd`, `export_erd`, `share_erd`. Agent flow: Atlas `get_app_schema`+`get_schema_relationships`
  → `build_erd_input` → `generate_erd`.
- **Lucid API key:** `LUCID_API_TOKEN`, configured in the server's `mcp.json` env (fill-in placeholder). Only
  the upload/update/export/share paths need it; offline build + `dry_run` don't. The `/v1` base path already
  supplies the required `Lucid-Api-Version`; a 401 = invalid/expired/whitespace-mangled token or a container
  started before the token was set (the client `.strip()`s the token and returns an actionable 401 message).
- Tests: `python3.13 -m pytest` (85 pass); CI runs `flake8 … --max-line-length=120 --ignore=E501,W503` + pytest.

## 6. Branch / domain map
| Branch (dev fork) | Agent | Skills | State |
|---|---|---|---|
| **`feature/atlas-data-generator`** ← USE THIS | `data-generator` | `data-generate-records`, `data-generate-sql`, `data-generate-erd` | **clean single commit `b1cce65823`; MR-ready — re-rebase onto latest main first (§7)** |
| `feature/atlas-product-owner` | `product-owner` | `app-explore`, `app-change`, `app-inventory`, `app-author` | built (commit `f09b582886`); **NOT cleaned/renamed/re-MR'd** |
| `feature/atlas-ux-designer` | `ux-designer` | `ux-build`, `ux-review`, `ux-handoff` | built (commit `0d0e6ed39e`); **NOT cleaned/re-MR'd** |
| `feature/atlas-sql-forge` | — | — | **SHARED** with colleagues' perf work — do NOT touch/force-push |
| `feature/atlas-agent-revamp` | original 40-skill | — | archive only (MR !92) |

## 7. CURRENT STATE (2026-08-10)
- **`feature/atlas-data-generator`** = one clean commit **`b1cce65823`**, force-pushed to dev. No secrets (all
  `${VAR}`), no test-run artifacts (`data-requests/` gitignored). Verified: 3 skills pass `quick_validate`,
  `kiro-cli agent validate` exit 0, **89 `dg` tests pass**, working tree clean.
  - It was rebased to **0 behind main on 2026-08-05**, but **`main` keeps advancing** — as of 2026-08-10 it is
    already **11 behind**. This is fine (the diff is additive, all under `.kiro/…data-generator` paths, so a
    rebase is normally conflict-free apart from `.gitignore`). **Before opening the MR, re-check
    `git rev-list --count HEAD..origin/main` and rebase onto the latest `main`, re-validate, then
    force-push-with-lease** (non-shared branch — OK).
- **DG MCP server** merged + image published → ERD MCP tools live; the data-generate-erd skill uses them.
- **MR !101** (`appian/prod/solutions-os!101`, blocked, reviewer walid.elsayed, 20 comments) — points at the OLD
  shared branch. **All 20 comments are now covered** (§8). It should be **closed/retargeted** to the new MR.
- Local safety branch `backup/pre-clean-ff31ca0155` holds the pre-cleanup tip (deletable once the MR looks right).

## 8. MR !101 — coverage (all 20 covered)
- **Implemented:** #3/#14/#16 skill renames (`data-generate-*`); #4/#13/#17 auto-analysis+manual restructure +
  `mode` enum `exemplar`→`auto-analysis`; #5–7 stale codes removed; #8/#9 output paths; #10 README purpose;
  #11/#12 MCP "steering" sections; #15/#20.4 deterministic `dg` CLI + MD trim; **#19/#20.3 ERD personal repo →
  resolved via the merged DG MCP ERD tools**; #20.1 clean split; #20.2 now 0 behind main.
- **No code change (correct outcome):** #1/#2 (DG-vs-Dev-MCP — answered in thread: DG has record/CDT handling
  Dev MCP lacks); #18 (DRY across 2 skills — reviewer "can live with it").

## 9. Key learnings / gotchas
- **Deterministic gates beat steering.** The agent will shortcut MD instructions (it under-queried the footprint,
  hand-wrote gate reports). The fix is always a `dg` gate that hard-fails, not more prose.
- **Prompt-path:** agent `prompt` = `file://../resources/<domain>/prompt.md` (relative to `.kiro/agents/`, NOT
  repo root). `kiro-cli agent validate` does NOT catch a wrong path — verify by running the agent.
- **Skill validation:** `python3 .kiro/skills/skill-creator/scripts/quick_validate.py <folder>` — frontmatter =
  `name`+`description` only (no `depends_on`); `name` kebab == folder; description ≤512 chars, **no angle brackets**.
- **Tests need `python3.13`** (system `python3` = 3.14, no pytest). `dg` itself is stdlib-only and runs on any 3.9+.
- **`gate`/`state` need `--state`/`DG_STATE`** pointed at the request folder — a bare call targets `./state.json`.
- **Secrets exposed & must be ROTATED:** `GITLAB_TOKEN`, `GITHUB_TOKEN`, `APPIAN_API_KEY`, `LUCID_API_TOKEN` were
  committed in an earlier "Intermediate commit" (`ff31ca0155`) and pushed — the old object lingers on the remote
  until GC. The branch tip is clean now, but rotation is what neutralizes them.
- **Small verified steps.** Large multi-file ops time out; validate after each change; keep the tracker updated.

## 10. NEXT STEPS (in priority order)
1. **Open the data-gen MR** (human): dev `feature/atlas-data-generator` → `appian/prod/solutions-os` `main`,
   via the UI link the push prints. **First re-rebase onto the latest `main`** (it advances daily; the branch is
   11 behind as of 2026-08-10 — `git rebase origin/main`, resolve the `.gitignore` union, re-validate,
   `git push --force-with-lease dev`). **Close/retarget MR !101** to the new MR (comment that #19 is resolved via
   the merged DG MCP). A ready title/description draft is in the chat log / can be regenerated.
2. **ROTATE the 4 tokens** (GitLab PAT, GitHub PAT, Appian API key, Lucid key).
3. **Product-Owner & UX-Designer domains** — still on old commits, not reviewed/cleaned. If pursuing: apply the
   same treatment (rebase onto latest main, `${VAR}` secrets, no artifacts, validate, single clean commit, dev
   push, human MR). PO open item **E1** (inject an org feature-spec template — currently a canonical skeleton).
4. **DG MCP Phase 5 / cleanup** — archive the personal `ramaswamy.u/solutions-atlas-dg-mcp-server` and the
   personal `ram-020998/erd-gen` repo (both superseded).
5. **Delete** local `backup/pre-clean-ff31ca0155` once the MR is confirmed good.
6. **Theme-A reviewer reconciliation** (agent-as-hub vs "3 hub skills") — if it resurfaces, cite the repo
   convention (a11y-expert / integration-* / sdx-*): each agent loads only its own domain's skills, so per-agent
   metadata stays lean while every action is independently usable.

## 11. Verification commands (copy-paste)
```bash
# solutions-os (data-generator)
cd /Users/ramaswamy.u/repo-gitlab/appian/solutions-os
for s in data-generate-records data-generate-sql data-generate-erd; do \
  python3 .kiro/skills/skill-creator/scripts/quick_validate.py .kiro/skills/$s; done
kiro-cli agent validate --path .kiro/agents/data-generator.json
(cd .kiro/resources/data-generator/scripts && python3.13 -m pytest -q)
python3 .kiro/resources/data-generator/scripts/dg.py --help          # CLI sanity
git rev-list --count origin/main..HEAD; git rev-list --count HEAD..origin/main   # ahead / behind

# read MR !101 (read-only; create/comment 403s for the agent)
glab api "projects/appian%2Fprod%2Fsolutions-os/merge_requests/101/discussions?per_page=100"

# DG MCP server (from a checkout of the dev fork)
python3.13 -m pytest -q
flake8 data_generator/ tests/ --max-line-length=120 --ignore=E501,W503
```

## 12. Working style
Small, verified steps. Confirm scope + destructive actions (force-push, history rewrite) before doing them.
For shared branches use merge, never force-push. Validate every skill + agent + the `dg`/MCP tests after
changes. Keep `work-tracker.md` updated as you go. Be careful and lossless; correct the user when something is
wrong (e.g., the missing-Lucid-header hypothesis was refuted by the docs — the `/v1` path already carries it).
