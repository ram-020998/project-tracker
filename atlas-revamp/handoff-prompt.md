# Session Handoff Prompt — Atlas Skills Redesign

> Paste into a new session. Full context to continue with no detail lost. Read the tracker docs first.

You are continuing a multi-session project. Read §0 docs, then continue from CURRENT STATE / NEXT STEPS.

## 0. Read first (source of truth)
- `/Users/ramaswamy.u/repo/project-tracker/atlas-revamp/design-action-specific-skills.md` — target architecture, decisions, validation standard, **prompt-path rule**. Governs the work.
- `/Users/ramaswamy.u/repo/project-tracker/atlas-revamp/work-tracker.md` — detailed running log; **§12** (DG MCP migration), **§13** (action-specific rebuild), **§14** (MR !101 review + sync + branch split) are the latest.
- `/Users/ramaswamy.u/repo/project-tracker/atlas-revamp/mr-92-review-responses.md` — original MR !92 comments.
- `00`–`05` phase docs — STALE original plan; history only.

## 1. Goal
Convert four Atlas Kiro Powers into **action-specific skills clustered by functionality** + a persona agent per domain, in `solutions-os`, addressing the MR reviews and matching the repo convention (`a11y-expert`, `appian-dev`, `dev-automated-testing`, `integration-*`).

## 2. Environment / git rules
- Repo: `/Users/ramaswamy.u/repo-gitlab/appian/solutions-os`. Remotes: `dev` = `appian/dev/solutions-os` (**push only here**); `origin` = `appian/prod/solutions-os` (MR target, branch `main`).
- **MRs created by a human via the dev-fork UI link** (agent/glab token 403s on MR create). `glab` IS authenticated for **reading** (e.g. `glab api projects/appian%2Fprod%2Fsolutions-os/merge_requests/<iid>/discussions`).
- **Push flow:** single-commit per branch where possible; new branches push plain; updates use `--force-with-lease` ONLY on non-shared branches. **Never force-push a shared branch** (see §CURRENT — sql-forge is shared).
- **Prompt-path convention (verified):** agent `prompt` = **`file://../resources/<domain>/prompt.md`** (resolves relative to the **agent file dir** `.kiro/agents/`, NOT repo root; `kiro-cli agent validate` does NOT catch a wrong path). `skill://` resources resolve from workspace root.
- **Secrets:** all env values `${VAR}` placeholders; never commit real tokens. (GitLab PAT / GitHub PAT / Appian API key once exposed on `feature/atlas-agent-revamp` still need rotation.)
- **Validation per skill:** `python3 .kiro/skills/skill-creator/scripts/quick_validate.py <folder>` — frontmatter = name+description only (no `depends_on`), name kebab==folder, description ≤512 chars, no angle brackets. Then `kiro-cli agent validate`. Do a byte-level fidelity check on migrated content.

## 3. Domains / final structure (all built + pushed to dev)
| Branch | Agent | Skills | Latest commit(s) |
|--------|-------|--------|------------------|
| `feature/atlas-data-generator` **(clean data-gen branch — USE THIS)** | `data-generator` (appian-atlas + appian-data-generator, shared prod image) | 4: `data-gen`, `data-gen-bulk`, `data-gen-manage`, `data-gen-erd` | `7095239373` (fixes) on `6941d0f49f` (skills), off current `main` |
| `feature/atlas-product-owner` | `product-owner` (appian-atlas + appian-docs; docs tool wired into `tools`) | 4 (9→4): `app-explore`, `app-change`, `app-inventory`, `app-author` | `f09b582886` |
| `feature/atlas-ux-designer` | `ux-designer` (appian-atlas only) | 3 (8→3): `ux-build`, `ux-review`, `ux-handoff` | `0d0e6ed39e` |
| `feature/atlas-sql-forge` **(SHARED — colleagues' perf work + our data-gen)** | (superseded for data-gen) | — | `3afbad5a0f`; synced with main at merge `57e02151bd` |
| `feature/atlas-agent-revamp` | original 40-skill all-in-one (MR !92) | archive only | — |

Convention on all: `<domain>-<action>` skills; agent-as-hub; shared docs in `.kiro/resources/<domain>/`; consolidated skills = a dispatcher `SKILL.md` over verbatim action `references/`; `../resources` prompt path; sibling cross-links in descriptions.

## 4. CURRENT STATE (as of 2026-07-31)
- **Active clean branch = `feature/atlas-data-generator`** (pushed to dev, first push). Contains ONLY our data-gen work (26 files) on top of **current `main`** (0 behind); the #5–#9 review fixes are in. **This is the branch to open the new data-gen MR from.** Local checkout is currently on this branch.
- **MR !101** (`appian/prod/solutions-os!101`, `feature/atlas-sql-forge` → main) is **BLOCKED** by reviewer walid.elsayed (20 comments; see work-tracker §14). It points at the OLD shared branch → should be **closed/retargeted**; open a fresh MR from `feature/atlas-data-generator`.
- **`feature/atlas-sql-forge` is now SHARED** — colleagues (Hanna Shapiro, Suganya B, Raajiv Madivanane) merged performance-executor / perf-profiler / OpenSearch-scorecard work into it. It was synced with main via a **merge** (`57e02151bd`, no force). Leave it for their performance work; do NOT rebase/squash/force-push it.
- **MR !101 minor items already fixed** (on the data-gen branch): removed stale codes F4/D15/D16/D17/D18/D9 (#5–#7); added `reference.md`/`footprint.md` output paths (#8/#9).
- Working tree clean; nothing uncommitted.

## 5. NEXT STEPS
1. **Open the clean data-gen MR** from `feature/atlas-data-generator` → prod `main` (human, via UI link the push prints). **Close or retarget !101** (add a note pointing reviewers to the new MR).
2. **Address remaining MR !101 items on `feature/atlas-data-generator`:**
   - **Renames (#3/#4/#13/#14/#16):** reviewer wants clearer names — e.g. skills `data-generate-records/-sql`, `data-generator-manager`, `data-generate-erd`; `exemplar/` → auto-analysis-flow; `workflow/` → manual flow. Agree exact names first, then rename (folder + frontmatter `name` + agent `resources` + prompt router + cross-links; `quick_validate` after).
   - **Step-0 placement (#17):** Initialize is common to both paths → move it out of `workflow/`; propose `resources/data-generator/` with a common step-0 + `auto-analysis/` + `manual/` subfolders.
   - **ERD personal repo (#19):** `data-gen-erd` installs `github.com/ram-020998/erd-gen` via `curl|bash` — migrate `erd-gen` to a shared namespace, or drop `data-gen-erd` from the MR.
   - **Determinism / trim (#15, #20.4):** biggest ask — convert step-0 (and other deterministic bits) to Python scripts the agent parameterizes; trim the ~4k MD lines. Likely the **follow-up MR** the reviewer wants ("rebuild the skills").
   - **Tools docs (#10/#11/#12):** clarify `tools/README.md` purpose; frame tool-reference docs as MCP-usage steering (ties to the #13 folder rename).
3. **PO & UX MRs** (`feature/atlas-product-owner`, `feature/atlas-ux-designer`) — open when ready (dev-fork UI links).
4. **Theme-A reviewer reconciliation** (agent-as-hub vs "3 hub skills") — cite repo convention; and confirm stance on C1 (keep aurora-patterns) / C2 (keep generate-sail).
5. **E1** — `app-author`'s feature-spec skeleton is canonical; inject an org template if desired.
6. **DG MCP Phase 5** — archive personal `ramaswamy.u/solutions-atlas-dg-mcp-server`. **Credential rotation.**

## 6. Working style
Small verified steps (large multi-file ops time out). Confirm scope/destructive actions. For shared branches use merge (never force-push). Validate every skill + agent. Keep the tracker updated. Be careful and lossless.
