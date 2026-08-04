# Design — Action-Specific Skills Redesign

**Status:** ✅ IMPLEMENTED across all three branches (2026-07-29) — data-generator (4 skills), product-owner
(9→4 skills), ux-designer (8→3 skills); each a single commit pushed to the **dev** fork (MRs pending human
creation). Prompt-path convention corrected to agent-dir-relative `file://../resources/<domain>/prompt.md`.
**Supersedes:** the hub-and-spoke layout (3 persona "hub" skills + `references/`) built for MR !92 Theme A.

---

## 1. Why (the pivot)

We are restructuring the Atlas skills to match the **actual solutions-os convention**: a general,
reusable library of **action-specific skills** the user can compose into any workflow — not persona
"hub" skills.

**Convention evidence (existing repo skills):**
- Skills are **`<domain>-<action>`, one action per skill**: `integration-generate/validate/report/conventions`,
  `sdx-analyze/coverage/generate/conventions`, `a11y-audit/fixer/validator`, `data-model-*`.
- The **"hub" is the AGENT, not a skill.** `a11y-expert.json` holds the Action Router / menu / cross-skill
  workflows in its prompt, and its `resources` list only its **own domain's** skills (a11y-fixer, a11y-audit,
  appian-a11y-rules, a11y-validator, appian-a11y-jira).
- Shared content lives two idiomatic ways:
  1. **`.kiro/resources/<domain>/`** — agent `prompt.md`, onboarding, scripts, common docs (referenced by
     path, e.g. `.kiro/resources/dev-automated-testing/...`). Agents point their prompt at
     `file://../resources/<domain>/prompt.md`.
  2. A **`<domain>-conventions` skill** that action skills declare via **`depends_on:`** frontmatter
     (e.g. `integration-generate` → `depends_on: integration-conventions`).

**We use option (1)** — `.kiro/resources/<domain>/` for the agent prompt + shared workflow docs.

## 2. Tension with the reviewer (flag)

This **reverses MR !92 Theme A** (walid: "collapse to 3 hub skills + references"). The repo convention is
the stronger precedent and it **reconciles his core concern** (context bloat): each **agent** loads only its
~6–9 domain skills — not all ~23 — so per-agent metadata stays lean, while every action is an independently
usable skill. Recommend replying on the Theme A thread citing the convention (a11y-expert / integration-* /
sdx-*). This is a second reversal, so worth a heads-up before building.

## 3. Target model (per domain)

- **Agent** `.kiro/agents/<domain>.json` — persona/router; `prompt: file://../resources/<domain>/prompt.md`;
  `resources` = its action skills only. (Scoping mirrors `a11y-expert.json`, which inlines its prompt.)
- **Action skills** `.kiro/skills/<prefix>-<action>/SKILL.md` — one action each, self-contained (own
  `references/` for skill-specific detail), cross-linking siblings in the `description` ("…not X; that's Y").
- **Shared docs** `.kiro/resources/<domain>/` — `prompt.md` + common workflow/tool docs, referenced by path.

> **⚠️ Prompt-path resolution (verified 2026-07-28 — corrects an earlier wrong note).** The agent's
> `prompt` `file://` path resolves **relative to the agent JSON file's own directory** (`.kiro/agents/`),
> NOT the repo root. So the prompt MUST be referenced as **`file://../resources/<domain>/prompt.md`**
> (i.e. `.kiro/agents/` → `../resources/…`). A repo-root form (`file://.kiro/resources/…`) silently fails
> to load — it resolves to `.kiro/agents/.kiro/resources/…` (missing) and the agent runs with no prompt,
> falling back to generic behavior. Evidence: the working global agent `project-tracker.json` uses
> `file://./project-tracker-prompt.md` with the file sitting next to the agent; the Kiro docs otherwise
> recommend an absolute path (not portable for a committed repo). Note: `kiro-cli agent validate` checks
> existence from the repo-root CWD, so it does NOT catch this — verify by actually running the agent.
> (`skill://` **resources** are different: those resolve relative to the workspace root, e.g.
> `skill://.kiro/skills/<prefix>-<action>/SKILL.md`.) Alternative: inline the whole prompt as a string
> like `a11y-expert.json` — zero path risk. **Decision: keep the prompt as a separate file** and use the
> `../resources/…` form for every agent (data-generator ✅, product-owner, ux-designer).

**Side benefit:** the old shared-file conflict (single `atlas.json` / `atlas-prompt.md` across branches)
disappears — each branch now owns **distinct** files (`data-generator.json`, `product-owner.json`,
`ux-designer.json` + separate `.kiro/resources/<domain>/` subdirs), so per-persona MRs no longer collide.

## 4. Confirmed decisions

1. Skill prefixes `data-gen-*`, `app-*`, `ux-*` — **approved**.
2. Keep a **persona agent per domain** — **yes**.
3. Shared docs (prompt + workflow) in **`.kiro/resources/<domain>/`** — **yes**.
4. Data-gen generation split into **`data-gen` (normal) + `data-gen-bulk`** — **yes**. (Utility actions remain
   their own skills — see §5.1; flag if you'd rather fold them in.)
5. Implement **data-gen first** — **yes**.

Proposed agent + resources names (adjustable): `data-generator` / `product-owner` / `ux-designer`
(agent file + `.kiro/resources/<name>/`), with skill prefixes `data-gen-*` / `app-*` / `ux-*`.

---

## 5. Final per-branch design

### 5.1 Data generation — branch `feature/atlas-sql-forge` → domain `data-generator`

**Skills** (`.kiro/skills/`):
| Skill | Action | Built from (current reference) |
|---|---|---|
| `data-gen` | Normal/demo generation — live records (≤50) via Data Generator MCP; execute + verify + rollback offer | shared workflow + `step-6-execute.md` |
| `data-gen-bulk` | Bulk generation — INSERT SQL script (100+) | shared workflow + `step-6-generate-sql.md` |
| `data-gen-manage` | Consolidated inspect/manage: explore schema · query & validate records · roll back a session | `explore-schema.md` + `query-validate.md` + `rollback.md` |
| `data-gen-erd` | Generate an ERD diagram | `erd.md` |

> Per decision (2026-07-28): schema/query/rollback are **consolidated into one `data-gen-manage`** skill
> (generic name) rather than three separate skills. ERD stays separate (distinct "generate a diagram" action).

**Shared → `.kiro/resources/data-generator/`:**
- `prompt.md` — agent seeding: Atlas + Data Generator tool catalogs, hard rules, router (from the current data-gen `atlas-prompt.md`).
- `workflow/` — `step-0-initialize.md` … `step-5-validation.md`, `step-4b-coverage-gate.md`.
- `exemplar/` — `exemplar-1-reference-intake.md` … `exemplar-4-validation.md`.
- `tools/` — `tool-reference-atlas.md`, `tool-reference-data-generator.md`.

`data-gen` and `data-gen-bulk` each run the **shared analysis workflow** (Steps 0–5 / exemplar E1–E4 in
`.kiro/resources/data-generator/workflow` + `/exemplar`, referenced by path) and keep only their
**mode-specific Step 6** in their own `references/`.

**Agent `.kiro/agents/data-generator.json`:** MCPs = `appian-atlas` + `appian-data-generator` (new shared prod
image); `resources` = the 4 skills; `prompt` = `file://../resources/data-generator/prompt.md`.

### 5.2 Product Owner — branch `feature/atlas-product-owner` → domain `product-owner`  ✅ IMPLEMENTED (commit `f09b582886`, pushed to dev)

**Skills** (prefix `app-`) — the 9 PO references were consolidated by functionality into **4** action
skills (9 → 4), each a dispatcher `SKILL.md` over verbatim action `references/`:
- **`app-explore`** — overview (onboarding) · feature deep-dive · cross-app comparison
- **`app-change`** — release review · impact analysis
- **`app-inventory`** — feature inventory · technical debt
- **`app-author`** — feature spec · research

(`appian-docs` stays dropped → `appian-docs` MCP routed from the agent prompt.)

**Shared → `.kiro/resources/product-owner/`:** `prompt.md` — business-language translation table (moved out
of the hub), Atlas tool catalog, `search_appian_knowledge_sources` (docs MCP) routing, menu + scope line.

**Agent `.kiro/agents/product-owner.json`:** MCPs = `appian-atlas` + `appian-docs`; tools
`read`/`write`/`shell`/`@appian-atlas`/**`@appian-docs`** (docs tool wired into `tools` — fixed a gap in the
old config); `resources` = the 4 skills; `prompt` = `file://../resources/product-owner/prompt.md`.

_Fidelity: 8/9 action bodies byte-identical to originals; `app-explore/references/overview.md` differs only
by an intended cross-ref fix._

### 5.3 UX Designer — branch `feature/atlas-ux-designer` → domain `ux-designer`  ✅ IMPLEMENTED (commit `0d0e6ed39e`, pushed to dev)

**Skills** (prefix `ux-`) — the 8 UX references were consolidated by functionality into **3** action skills
(8 → 3), each a dispatcher `SKILL.md` over verbatim action `references/`:
- **`ux-build`** — prototype (html/react) · aurora-patterns · generate-sail
- **`ux-review`** — edge-cases · feasibility · consistency
- **`ux-handoff`** — component decomposition · design-to-dev handoff

**Shared → `.kiro/resources/ux-designer/`:** `prompt.md` — Atlas + Git-content sourcing, Aurora/Sailwind repo
map, the key distinctions (aurora-patterns distinct from the a11y `audit`; generate-sail distinct from the
Dev MCP; consistency is app-relative), menu + scope line.

**Agent `.kiro/agents/ux-designer.json`:** MCP = `appian-atlas`; tools `read`/`write`/`shell`/`@appian-atlas`;
`resources` = the 3 skills; `prompt` = `file://../resources/ux-designer/prompt.md`.

_Fidelity: all 8 action bodies byte-identical to the stashed originals. C1/C2/C3 preserved (aurora-patterns
and generate-sail kept as prominent modes with purpose notes; prototype stays html/react)._

---

## 6. Implementation plan (per branch; data-gen first)

For each domain, on its existing branch:
1. Create `.kiro/resources/<domain>/` and move the shared prompt + workflow/tool docs there (from the current
   hub `atlas-prompt.md` and shared references).
2. Create the per-action skill folders `.kiro/skills/<prefix>-<action>/SKILL.md` with authored frontmatter
   (`name`, `description` with sibling cross-links) + bodies lifted from the current references; skill-specific
   detail goes in each skill's own `references/`.
3. Create the agent `.kiro/agents/<domain>.json` (prompt = `file://../resources/<domain>/prompt.md`,
   resources = its skills, correct MCPs/tools).
4. Delete the old `atlas-<persona>/` hub folder and the old `atlas.json` / `atlas-prompt.md`.
5. Validate: `quick_validate.py` each skill; `kiro-cli agent validate`; resources resolve; grep for stale
   `atlas-*` / hub references.
6. Commit as a single commit; push to the **dev** fork; MR to prod (human-created via UI link).

## 7. Open / pending

- **Agent + resources names** — RESOLVED: `data-generator` / `product-owner` / `ux-designer` (implemented).
- **Data-gen utilities** — RESOLVED: schema + query + rollback consolidated into one `data-gen-manage`
  skill; ERD kept as its own `data-gen-erd`. So data-gen = 4 skills.
- **PO/UX consolidation** — RESOLVED: PO 9→4 (`app-explore`/`app-change`/`app-inventory`/`app-author`);
  UX 8→3 (`ux-build`/`ux-review`/`ux-handoff`). Each a dispatcher `SKILL.md` over verbatim `references/`.
- **Prompt-path convention** — RESOLVED: `file://../resources/<domain>/prompt.md` (agent-dir-relative);
  see the ⚠️ note in §3. All three agents use it.
- **E1** — `app-feature-spec` (now `app-author` → `references/feature-spec.md`) still uses the canonical
  skeleton template; inject an org/PM template later if desired. STILL OPEN (non-blocking).
- **Reviewer reconciliation** — reply on the MR !92 Theme A thread citing repo convention (`a11y-expert`,
  `appian-dev`, `dev-automated-testing`, `integration-*`) — action-specific per-agent scoping addresses the
  context-bloat concern while keeping every action reusable. STILL OPEN.
- **Three MRs** (sql-forge / product-owner / ux-designer) — pending human creation via the dev-fork UI links.
- **DG MCP Phase 5** (archive personal repo) and **credential rotation** — STILL OPEN (see work-tracker).
- **`data-gen` vs agent name** — the normal skill is `data-gen` while the agent/resources are `data-generator`
  (slight token variance to avoid a skill/agent name clash); flag if you want them identical.


---

## 8. Skill authoring & validation standard (from `skill-creator`)

Every skill we create/modify MUST follow the `skill-creator` guidance and pass its pre-flight validator
before being called done.

**Validate after any frontmatter change (HARD RULE from skill-creator):**
```bash
SKILL_CREATOR_DIR=$(find "$(pwd)/.kiro/skills" ~/.kiro/skills -maxdepth 2 -name "skill-creator" -type d | head -1)
python3 "$SKILL_CREATOR_DIR/scripts/quick_validate.py" <absolute-path-to-skill-folder>
```

**Hard rules the validator enforces (`quick_validate.py`):**
- Frontmatter keys limited to: `name`, `description`, `license`, `allowed-tools`, `metadata`, `compatibility`
  — **any other key fails** (so **do not add `depends_on`**; we use `.kiro/resources` for shared docs, not
  `depends_on`, which keeps us clean here).
- `name`: kebab-case `^[a-z0-9-]+$`, no leading/trailing/consecutive hyphens, ≤ 64 chars, **== folder name**.
- `description`: **≤ 512 characters**, **no angle brackets** (`<` `>`), and must include *what it does* +
  *when to trigger* (concrete phrases/contexts) + *when NOT to* (sibling cross-links). (Note: the validator
  caps at 512 even though prose guidance says ~1024 — target ≤ 512.)

**Authoring guidance (skill-creator writing guide) to apply:**
- **Progressive disclosure:** name+description always loaded (keep tight); SKILL.md body < ~500 lines; heavier
  detail in `references/` ("for X, read `references/x.md`"). Reference files > ~300 lines get a short TOC.
- **Anatomy:** `SKILL.md` (required) + optional `scripts/` (deterministic code), `references/` (read-on-demand
  docs), `assets/` (output templates).
- **Descriptions lean slightly pushy** (agents under-trigger): name situations/file-types/phrasings that
  should activate "even if the user doesn't say it explicitly," and disambiguate adjacent skills.
- **Write imperative; show don't tell** (explicit output templates + input/output examples).
- **Explain *why*, not just *what*;** reserve `## HARD RULE:` blocks for the few genuinely rigid constraints.

**Implication for §6 step 5:** validation = run `quick_validate.py` on **each** new skill folder (not just the
old hub), plus `kiro-cli agent validate` on the new agent JSON, plus a grep for stale `atlas-*`/hub references.
