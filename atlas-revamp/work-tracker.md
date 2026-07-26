# Atlas Revamp — Work Tracker

**Purpose:** Complete, detailed record of all work done addressing the MR !92 review, organized
by the per-persona MR strategy. Nothing omitted. This is the source of truth for where things
stand; the `00`–`05` phase docs describe the *original* design and are intentionally left stale.

**Last updated:** 2026-07-26

---

## 1. Context & objective

Convert the four Atlas Kiro *Powers* into a single Atlas agent + skills in `solutions-os`. An
initial all-in-one implementation (one `atlas` agent + ~40 grouped skills) was opened as
**MR !92** and received **17 review comments** (reviewer: **walid.elsayed**, state: *changes
requested*). We are now addressing that feedback **one persona at a time, each in its own branch
and MR**, so reviews stay small and focused.

Personas: **SQL Forge** (data generation), **Product Owner** (read-only analysis), **UX Designer**
(prototyping/design review).

---

## 2. Repository, remotes & branch state

- **Repo:** `/Users/ramaswamy.u/repo-gitlab/appian/solutions-os`
- **Remotes:**
  - `dev` → `git@gitlab.appian-stratus.com:appian/dev/solutions-os.git` — **push target** (we push only here).
  - `origin` → `git@gitlab.appian-stratus.com:appian/prod/solutions-os.git` — prod; MR target.

| Branch | Base | Commit | Pushed to dev? | MR? | State |
|--------|------|--------|----------------|-----|-------|
| `feature/atlas-agent-revamp` | main | `1e220ab28e` | yes (force-pushed, squashed) | **!92** (prod, changes requested) | Original all-in-one (40 skills). Superseded by per-persona branches. Do not build on it further. |
| `feature/atlas-sql-forge` | `origin/main` | `053c44c175` "Initial staging commit" | **yes** | not yet (later) | SQL Forge complete. |
| `feature/atlas-product-owner` | main | `632b5c97b0` "Initial staging commit" | not yet | not yet | PO complete except E1. Current branch. |

> MR !92 is at `appian/prod/solutions-os!92`, title "feat: Atlas agent — single agent with
> hub-and-spoke skills", 17 comments.

---

## 3. MR !92 — the 17 review comments (mapped)

Grouped into 5 themes. File/line are from the original 40-skill layout on `feature/atlas-agent-revamp`.

**Theme A — collapse ~40 skills → 3 hub skills, spokes become `references/`:**
- general note #3 ("each hub should be the skill, spokes as reference files under it").
- `atlas.json:19` ("boil down to 3 skills … everything else under /references").
- `atlas-product-owner/atlas-product-owner/SKILL.md:1` and `atlas-sql-forge/atlas-sql-forge/SKILL.md:1` ("move hub up one level; nested skills not discoverable outside the agent").
- general note #2 ("UXD and SWL forge skill files too big, hard to review").

**Theme B — terminology "agent"/"sub-agent" (reserved meaning in Kiro):**
- general note #1; `atlas-sql-forge/…/SKILL.md:8`, `:74`, `:106`; `atlas-prompt.md:38`.

**Theme C — convergence / de-duplication:**
- C1 `atlas-ux-designer/atlas-aurora-compliance/SKILL.md:1` — converge with a11y audit; reviewer votes retire it, keep a11y.
- C2 `atlas-ux-designer/atlas-generate-sail-interface/SKILL.md:1` — duplicates Dev MCP; code-gen should rely on Dev MCP.
- C3 `atlas-ux-designer/atlas-sailwind-prototype/SKILL.md` — duplicated by atlas-html-prototype?
- C4 `atlas-sql-forge/atlas-sql-forge-erd/SKILL.md:1` — converge with ERD power (connect @revathi.jayabalan, @saravana.manivasakam).
- C5 `atlas-product-owner/atlas-appian-docs/SKILL.md:1` — "why an Atlas skill? we have the docs MCP, just a wrapper?"

**Theme D — repo hygiene:**
- `atlas.json:98` — DG MCP image is in a personal namespace (`ramaswamy.u/…`); move to shared.

**Theme E — content specifics:**
- E1 `atlas-product-owner/atlas-feature-spec/SKILL.md:28` — inject a standardized spec template for all PMs.
- E2 `atlas-product-owner/atlas-technical-debt/SKILL.md:18` — "how is this excluding app ref / entry points?"
- E3 `atlas-sql-forge/atlas-sql-forge/SKILL.md:95` — "jumps from Step 0 to Step 6, missing steps?"

Full per-comment analysis lives in `mr-92-review-responses.md` (same folder).

---

## 4. Decisions locked (this effort)

1. **Per-persona branches/MRs** — SQL Forge first, then PO, then UX. Push to **dev** fork only.
2. **Adopt Theme A** (3 hub skills + `references/`) — reverses the earlier "one skill = one action"
   principle, approved by requester.
3. **Branch base = `origin/main`** for each persona branch (clean, additive diff). **Consequence:**
   `atlas.json` / `atlas-prompt.md` are shared; each persona branch has its own **scoped** version.
   At integration, whichever MR merges second will conflict on those two files and must be resolved
   by **keeping BOTH hubs (union)** — do not drop a hub. Flag this in each MR description.
4. **SQL Forge:** keep **ERD** (as `references/erd.md`) for now (C4 convergence deferred, pending owners).
5. **DG MCP namespace move (D):** user will do **manually at the end**. Agent left with the personal
   image ref on the sql-forge branch; flagged as a pre-merge blocker.
6. **Terminology (B):** reword "agent/sub-agent/orchestrator/dispatch" → sequential "steps." Also a
   real inconsistency fixed: the agent's `tools` never included the `subagent` tool, so it could not
   spawn sub-agents anyway.
7. **C5 (appian-docs):** **Option (ii)** — wire the official `appian-docs` MCP and drop the
   `appian-docs` reference; routing lives as a line in the prompt (see §7).
8. **Commits:** user commits/pushes themselves (they did for both branches). Do not commit unless asked.

---

## 5. SQL Forge branch — `feature/atlas-sql-forge` (COMPLETE, committed `053c44c175`, pushed to dev)

### Structure produced
```
.kiro/agents/atlas.json           # resources → [atlas-sql-forge hub]; both MCPs (appian-atlas + appian-data-generator)
.kiro/agents/atlas-prompt.md      # SQL-Forge-scoped seeding doc
.kiro/skills/atlas-sql-forge/
├── SKILL.md                      # hub (108 lines), directly invocable
└── references/  (20 files)
    step-0-initialize.md, step-1-workflow-analysis.md, step-2-exemplar-discovery.md,
    step-3-data-architecture.md, step-4-data-payloads.md, step-4b-coverage-gate.md,
    step-5-validation.md, step-6-execute.md, step-6-generate-sql.md,
    exemplar-1-reference-intake.md, exemplar-2-footprint-discovery.md,
    exemplar-3-clone-scale-plan.md, exemplar-4-validation.md,
    explore-schema.md, query-validate.md, rollback.md, erd.md, tools.md,
    tool-reference-atlas.md, tool-reference-data-generator.md
```
23 files total (2 agent + hub + 20 references).

### Work done (per theme)
- **[A] Restructure:** moved hub from nested `atlas-sql-forge/atlas-sql-forge/SKILL.md` up to
  `atlas-sql-forge/SKILL.md`. Converted 18 spoke `SKILL.md` files → `references/*.md` (dropped the
  redundant `atlas-sql-forge-` prefix; stripped YAML frontmatter). The `-tools` spoke split into
  `references/tools.md` + `tool-reference-atlas.md` + `tool-reference-data-generator.md`. Rewrote the
  hub routing from "invoke skill X" → "read `references/X.md`". Fixed the 2 inline pointers inside
  references (both to `atlas-sql-forge-step-6-generate-sql` → `references/step-6-generate-sql.md`).
  `atlas.json` resources: 19 nested entries → 1 hub entry; description scoped to SQL Forge.
  `atlas-prompt.md` trimmed to the SQL Forge domain (removed 3-hub / PO / UX routing; kept Atlas +
  Data Generator tool catalogs).
- **[B] Terminology:** removed all "agent/sub-agent/orchestrator/dispatch" language from hub + prompt;
  reworded to "run the steps in sequence yourself." 0 sub-agent mentions remain.
- **[E3] Step numbering:** Steps **0, 1, 2, 3, 4, 4b, 5, 6** now all visible as headings (fixed 0→6 jump).
- **ERD:** kept as `references/erd.md` (decision #4).

### Verification (all passed)
- `quick_validate.py .kiro/skills/atlas-sql-forge` → "Skill is valid!"
- `kiro-cli agent validate --path .kiro/agents/atlas.json` → exit 0.
- Single hub resource resolves; 0 leftover sub-agent / PO / UX / nested-spoke references.
- Nothing outside `.kiro/`; no stray empty dirs.

### Open items (SQL Forge)
- **[D]** DG MCP image still `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest`
  (personal namespace) — **pre-merge blocker**, user moves manually.
- **[C4]** ERD convergence with the ERD power — deferred; sync with @revathi.jayabalan / @saravana.manivasakam.
- MR not yet created (deferred by user).
- (Optional/low-priority) largest reference `step-1-workflow-analysis.md` (~26 KB) not split.

---

## 6. Product Owner branch — `feature/atlas-product-owner` (COMPLETE except E1, committed `632b5c97b0`)

### Structure produced
```
.kiro/agents/atlas.json           # resources → [atlas-product-owner hub]; MCPs: appian-atlas + appian-docs (read-only); tools: read/write/shell/@appian-atlas
.kiro/agents/atlas-prompt.md      # PO-scoped seeding doc (read-only)
.kiro/skills/atlas-product-owner/
├── SKILL.md                      # hub (router + business-language table)
└── references/  (9 files)
    app-onboarding.md, cross-app-analysis.md, explore-feature.md, feature-inventory.md,
    feature-spec.md, impact-analysis.md, release-review.md, research.md, technical-debt.md
```
12 files total (2 agent + hub + 9 references). Diff vs main = 12 files.

### Work done (per theme)
- **[A] Restructure:** hub moved up to `atlas-product-owner/SKILL.md`; 10 spokes → `references/*.md`
  (dropped `atlas-` prefix; stripped frontmatter). Router rewritten to "read `references/X.md`".
- **[B] Stale refs:** hub previously pointed at the `atlas-sql-forge-tools` skill and said "invoke the
  specific atlas-* skill" — both fixed (tool details now defer to the agent catalog; routing uses
  reference paths). PO hub had no sub-agent language.
- **[E2] technical-debt entry points** (`technical-debt.md`): added a "What counts as unused" caveat —
  orphans are candidates, not conclusions; lists entry-point types to check (sites/site pages, record
  type actions & list actions, process start forms/models, Web APIs, report links) before recommending
  removal; instructs to say so honestly if unsure whether the KB's orphan calc excludes an entry-point
  type. (Could not live-verify `list_orphans` semantics — no Atlas MCP in this session — so worded as
  a caveat rather than an assertion.)
- **[C5] appian-docs — resolved via Option (ii)** (see §7 for the enabling discovery):
  1. Deleted `references/appian-docs.md`.
  2. Removed the hub's appian-docs router row; replaced with a note distinguishing platform-docs vs
     app-specific questions.
  3. Wired the official `appian-docs` SSE MCP into `atlas.json` with a **placeholder** Bearer token
     (`Bearer ${APPIAN_DOCS_API_KEY}`), `autoApprove: [search_appian_knowledge_sources]`.
  4. Added a router line to `atlas-prompt.md`: platform/product questions → `search_appian_knowledge_sources`
     (appian-docs MCP); customer-app questions → Atlas tools. Added `APPIAN_DOCS_API_KEY` to the setup
     section with a "never commit it" note; changed the closing line from "Atlas-only" to "read-only,
     wires `appian-atlas` + `appian-docs`."
- **Agent scoped to PO:** read-only — `tools`/`allowedTools` = read/write/shell/`@appian-atlas`
  (dropped `@appian-data-generator`, since PO doesn't write data — this also kept the flagged personal
  DG image OUT of the PO MR). mcpServers = `appian-atlas` + `appian-docs`.

### Verification (all passed)
- `quick_validate.py .kiro/skills/atlas-product-owner` → "Skill is valid!"
- `kiro-cli agent validate` → exit 0.
- 0 dangling `references/appian-docs` references; `search_appian_knowledge_sources` present in
  atlas.json (1), atlas-prompt.md (2), hub SKILL.md (1). Bearer is placeholder-only.
- Working tree clean; docs-MCP wiring + reference deletion confirmed in committed HEAD.
- (The `guide-appian-docs.md` that appears in `git ls-tree` is the ORIGINAL power steering file under
  `ai-framework/Product/.kiro/powers/…` — untouched, not part of our new skills.)

### Open items (PO)
- **[E1] feature-spec standardized template** (`feature-spec.md`) — **OPEN, awaiting user.** Question:
  is there an existing org/PM spec template to inject, or keep the current skeleton and mark it canonical?
- MR not yet created; not yet pushed to dev.

---

## 7. Key external input — "Using Kiro CLI Developer & Kiro at Appian (Amazon Q)" doc

User pointed to `~/Downloads/Using Kiro CLI Developer & Kiro at Appian (Amazon Q).md`. Relevant findings:

- **Official Appian Docs MCP exists** (this unblocked C5):
  ```json
  "appian-docs": {
    "type": "sse",
    "url": "https://appian-docs-api.mcp.kapa.ai",
    "headers": { "Authorization": "Bearer API-KEY" },
    "disabled": false,
    "autoApprove": ["search_appian_knowledge_sources"]
  }
  ```
  Single tool `search_appian_knowledge_sources`; covers docs.appian.com + Community KB (latest monthly
  + last two quarterly releases). **API key is a single shared key** from InfoDev and **must not be
  stored in repos/chat** → we use a `${APPIAN_DOCS_API_KEY}` placeholder.
- **How the agent knows when to use it (option ii):** the MCP tool's own description is not enough to
  distinguish platform vs app-specific questions, so the routing line in `atlas-prompt.md` is what
  reliably triggers it. (No dedicated skill file needed for a single self-describing tool.)
- Doc also documents read-only GitLab / Jira / GitHub MCPs and the org philosophy: **read-only,
  human-in-the-loop, no MCP write access**; "you can still use agents to commit to **dev forks** and
  create PRs" — validates our push-to-dev + MR workflow, and aligns with the PO agent being read-only.

---

## 8. Secret handling notes (important history)

- On `feature/atlas-agent-revamp`, `atlas.json` was **pushed to dev with real credentials** (GitLab PAT,
  GitHub PAT, Appian API key/JWT, env URL). They were reverted to `${VAR}` placeholders and the branch
  squashed + force-pushed. **Those credentials must be treated as compromised and rotated** — force-push
  does not guarantee the old commit object is unrecoverable on the remote. (Rotation is the user's action.)
- Discipline applied since: **all env values in agent configs are `${VAR}` placeholders**, including the
  new `APPIAN_DOCS_API_KEY`. Verified no real Bearer token is committed on the PO branch.

---

## 9. Reusable restructure recipe (for the UX branch, not yet started)

1. `git checkout -b feature/atlas-<persona> origin/main`.
2. Bring skills over: `git checkout feature/atlas-agent-revamp -- .kiro/skills/atlas-<persona>`;
   bring agent files from a cleaned branch as a template.
3. Python script: for each spoke, strip leading YAML frontmatter, write to
   `references/<short-name>.md` (drop the group prefix); flatten any nested `references/`; then
   `rmtree` the spoke folders.
4. Rewrite the hub `SKILL.md` at the group root: router → `references/*.md`; remove agent/sub-agent
   terminology; fix cross-refs (grep for sibling skill names + `atlas-sql-forge-tools`); remove the
   old inner hub folder.
5. Scope `atlas.json` (description + `resources` = [hub] + appropriate MCPs/tools) and rewrite
   `atlas-prompt.md` for the domain.
6. Validate: `quick_validate.py <hub>`; `kiro-cli agent validate`; grep for stale refs; confirm
   resources resolve and nothing is outside `.kiro/`.

---

## 10. Pending / not started

- **UX Designer branch** — NOT started. Comments to address: A (restructure), B (terminology),
  **C1** (retire `atlas-aurora-compliance`, keep a11y), **C2** (`atlas-generate-sail-interface` →
  delegate to Dev MCP; needs Dev MCP capability confirmation), **C3** (merge html + sailwind
  prototypes). Largest files live here (general note #2).
- **E1** (PO feature-spec template) — awaiting user.
- **D** (DG MCP shared namespace) — user, manual, pre-merge for SQL Forge.
- **C4** (ERD convergence) — needs @revathi.jayabalan / @saravana.manivasakam.
- **MR creation** for SQL Forge and PO — deferred; remember the shared-file union note (§4.3) in
  each MR description.
- **Credential rotation** for the secrets exposed on `feature/atlas-agent-revamp` — user action.

---

## 11. Immediate next steps

1. Resolve **E1** (spec template) → PO branch complete.
2. Push PO branch to **dev** (user) when ready.
3. Start the **UX Designer** branch using the §9 recipe; get a decision on C2 (Dev MCP) and confirm C1/C3.
4. When creating MRs: dev fork only; note the DG-namespace blocker (SQL Forge) and the shared
   agent-file union requirement in the descriptions.
