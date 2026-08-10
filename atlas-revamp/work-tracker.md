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
| `feature/atlas-sql-forge` | `origin/main` | `5def052c64` "Initial staging commit" | **yes** | not yet (later) | SQL Forge complete. |
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

## 5. SQL Forge branch — `feature/atlas-sql-forge` (COMPLETE, committed `5def052c64`, pushed to dev)

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
- **D** (DG MCP shared namespace) — **IN PROGRESS**, see §12. Repo created (Phase 1 merged); code
  seeded via MR (Phase 2, awaiting merge); image publish + atlas.json update still pending (Phase 3–4).
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


---

## 12. DG MCP server migration (Theme D) — personal namespace → appian/prod

**Goal:** move the Data Generator MCP server out of `ramaswamy.u/solutions-atlas-dg-mcp-server`
into `appian/prod/solutions-atlas-dg-mcp-server`, then repoint the `atlas` agent at the shared image.
Same dev→prod fork workflow throughout (branch on dev fork, MR to prod).

### How repo creation works (research)
- Projects under `appian/prod` are declared as code in **`appian/prod/gitlab-configuration`** —
  one YAML per project at `configuration/projects/<name>.yml`, applied by Terraform. Schema:
  `configuration/projects.schema`.
- Precedent: **MR !3974** (ramaswamy.u, merged) created the other Atlas AI tool repos by adding
  exactly 3 YAML files (kb, parser, mcp-server) — no `projects.tf` changes. (The `projects.tf`
  `import` blocks with hardcoded IDs are one-time approval-rule state adoptions, not needed for new projects.)
- **Note on MR creation:** the available agent/glab token returns **403 `insufficient_scope`** for
  creating MRs (matches org policy: agents push to dev forks, humans click "create MR"). So every MR
  in this migration is created via the GitLab UI link; the agent does branch + commit + push only.

### Phase 1 — create the repo (DONE, merged)
- Branch `feature/GAMS-0000-create-atlas-dg-mcp-server` off `origin/main` of `gitlab-configuration`.
- Added `configuration/projects/solutions-atlas-dg-mcp-server.yml`, description + access groups
  **mirroring `solutions-atlas-mcp-server.yml`** exactly (owner/developer/reporter squad groups).
- Committed, pushed to **dev fork** (`appian/dev/gitlab-configuration`), MR to `appian/prod/gitlab-configuration`.
- **Merged by user.** New repo live: `appian/prod/solutions-atlas-dg-mcp-server` (project id **14461**);
  a dev fork also exists: `appian/dev/solutions-atlas-dg-mcp-server` (id **14462**).

### Phase 2 — seed the code (DONE on dev fork, MR awaiting merge)
- Prod repo initially had only a seeded `README.md` ("Initial commit" `069eac2`).
- Source of truth = the personal repo's **`feature/f1-cdt-dse-tools`** branch (5 commits ahead of its
  `main`; has the CDT/data-store, document, and CSV tools that `atlas-prompt.md` references).
- In the local personal repo (`repo-gitlab/ramaswamy.u/solutions-data-generator-mcp`): added remotes
  `devfork` + `prod`; created branch **`feature/GAMS-0000-seed-dg-mcp-server` off `devfork/main`**
  (shared base with prod → clean MR); overlaid the full code via `git checkout feature/f1-cdt-dse-tools -- .`.
- **Fixed `mcp.json`** (per user): replaced the local `python3 main.py` + personal `cwd` config with the
  **docker** config pointing at the shared image:
  ```json
  { "command": "docker",
    "args": ["run","--rm","-i","--env","APPIAN_ENV_URL","--env","APPIAN_API_KEY",
             "registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-dg-mcp-server:latest"],
    "env": { "APPIAN_ENV_URL": "${APPIAN_ENV_URL}", "APPIAN_API_KEY": "${APPIAN_API_KEY}" } }
  ```
- **Squashed to a single commit** (amended into the seed commit) and force-pushed to the dev fork.
  Branch = base + **1 commit** `c64fb97 GAMS-0000 Seed Atlas Data Generator MCP server code`.
- Secret check: `mcp.json` + `.env.example` are placeholders only; scan clean; no `__pycache__`/`.pyc`
  tracked; `.gitignore` included.
- **MR to create/merge** (prod id 14461, target `main`):
  `https://gitlab.appian-stratus.com/appian/dev/solutions-atlas-dg-mcp-server/-/merge_requests/new?merge_request%5Bsource_branch%5D=feature%2FGAMS-0000-seed-dg-mcp-server&merge_request%5Btarget_project_id%5D=14461&merge_request%5Btarget_branch%5D=main`

### Phase 3 — image publish (DONE)
- On merge of MR **!1** (`appian/prod/solutions-atlas-dg-mcp-server`, merged by dineshkumar.k; prod main
  merge commit `ef88316e`, our seed commit `c64fb974`), CI published to registry repo
  `appian/prod/solutions-atlas-dg-mcp-server` with tags **`latest`** and **`ef88316e`**.
  Full image ref: `registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-dg-mcp-server:latest`.

### Phase 4 — repoint the agent (DONE, committed + pushed)
- On `feature/atlas-sql-forge`, updated `atlas.json` `appian-data-generator` image from
  `…/ramaswamy.u/solutions-atlas-dg-mcp-server:latest` → `registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-dg-mcp-server:latest`
  (JSON valid; `kiro-cli agent validate` exit 0). Clears Theme D (`atlas.json:98`).
- **Amended into the branch's single commit** (`5def052c64` → **`5def052c64`**) and force-pushed to the
  dev fork — SQL Forge remains a single-commit MR. DG namespace blocker is now cleared.

### Phase 5 — cleanup (PENDING)
- Archive the personal `ramaswamy.u/solutions-atlas-dg-mcp-server` once the new repo + image are verified.

### Reference commands / IDs
- prod `gitlab-configuration` project id: **2**; prod DG repo id: **14461**; dev DG fork id: **14462**.
- Personal source local path: `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-data-generator-mcp`
  (remotes: `origin`=personal, `devfork`=dev fork, `prod`=prod).

---

## 13. Action-specific skills rebuild (the pivot) — ✅ IMPLEMENTED all 3 branches (2026-07-29)

Pivoted from persona "hub" skills to **action-specific skills clustered by functionality**, matching the
repo convention (`a11y-expert`, `appian-dev`, `dev-automated-testing`, `integration-*`). Full design in
`design-action-specific-skills.md`. Each branch = a single commit pushed to the **dev** fork only; MRs
pending human creation via the dev-fork UI links.

**Convention applied everywhere:**
- `<domain>-<action>` skills flat at `.kiro/skills/`; agent is the hub; shared docs in `.kiro/resources/<domain>/`.
- **Prompt path = `file://../resources/<domain>/prompt.md`** (agent-dir-relative). Corrects an earlier wrong
  "repo-root-relative" assumption — verified against `appian-dev.json`/`project-tracker.json`, which use the
  same form. `kiro-cli agent validate` does NOT catch a wrong prompt path (it checks from repo-root CWD).
- Each consolidated skill = a thin dispatcher `SKILL.md` (mode router) over **verbatim** action `references/`
  (byte-identical to originals — fidelity-audited). Sibling cross-links in every `description`.
- Per-skill workflow, no positional step naming (e.g. renamed `step-6-*` → `create-records.md` / `generate-sql.md`).
- Validation gate per skill (`quick_validate.py`, description ≤512, kebab name==folder, frontmatter = name+description only).

**Branch results:**

| Branch | Domain / agent | Skills | Commit (dev) |
|--------|----------------|--------|--------------|
| `feature/atlas-sql-forge` | `data-generator` (appian-atlas + appian-data-generator on shared prod image) | 4: `data-gen`, `data-gen-bulk`, `data-gen-manage`, `data-gen-erd` | `6ab49a2ec0` |
| `feature/atlas-product-owner` | `product-owner` (appian-atlas + appian-docs; docs tool wired into `tools`) | 4 (9→4): `app-explore`, `app-change`, `app-inventory`, `app-author` | `f09b582886` |
| `feature/atlas-ux-designer` | `ux-designer` (appian-atlas only) | 3 (8→3): `ux-build`, `ux-review`, `ux-handoff` | `0d0e6ed39e` |

**Fidelity audits:** data-gen — all moved bodies byte-identical (git R100 renames); PO — 8/9 identical, 1
intended cross-ref fix; UX — all 8 identical to the stashed originals. Old `atlas-*` hubs + `atlas.json` +
`atlas-prompt.md` removed on each branch; `a11y-expert` / `appian-dev` / `dev-automated-testing` untouched.

**Notable fixes/flags surfaced during the rebuild:**
- data-gen ERD skill depends on a **personal** GitHub tool (`ram-020998/erd-gen`, `curl|bash` install) + a
  Lucid API token — same class as the DG-MCP personal-namespace issue; tied to C4. Flagged, not changed.
- Corrected the ERD skill's output claim (draw.io → **Lucidchart**) and stale "Atlas SQL Forge" branding.
- PO agent: added `@appian-docs` to `tools`/`allowedTools` (old config configured the MCP but never exposed it).
- Both MCPs use `autoApprove: ["*"]` (pre-existing) — auto-approves writes/deletes; workflow docs add
  human-confirm gates. Noted vs the read-only/human-in-the-loop philosophy.

**Still open:** E1 (spec template — skeleton canonical for now); Theme A reviewer reconciliation; three MRs;
DG Phase 5 (archive personal repo); credential rotation.

---

## 14. MR !101 review, sync-with-main, and branch split (2026-07-30 → 31)

### MR !101 (data-gen) — opened, then BLOCKED
- MR **!101** `appian/prod/solutions-os!101`, `feature/atlas-sql-forge` → `main`, author ramaswamy.u,
  reviewer **walid.elsayed**. **20 comments; state: blocked.** (Read via `glab api projects/appian%2Fprod%2Fsolutions-os/merge_requests/101/discussions`.)
- **Blocking summary (#20):** (1) two unrelated changes in one MR / only ~11 lines of code — split it;
  (2) 22 commits behind main, missing the updated repo structure; (3) ERD skill references a personal
  repo — not production-ready; (4) ~4,000 lines of MD, most is code-able / not needed → follow-up MR to
  rebuild the skills more deterministically. Review detail files in a Google Drive folder ("MR 101 …").
- **Comment map:** DG-MCP vs Dev-MCP #1/#2 (answered: DG has record/CDT handling Dev MCP lacks);
  skill renames #3 (wants `data-generate-records/-sql`, `data-generator-manager`, `data-generate-erd`);
  "exemplar" is vague → auto-analysis-flow #4; undefined codes F4/D15/D16 #5–#7; missing output paths
  #8/#9; `tools/README.md` purpose #10; tool-reference as MCP steering #11/#12; "workflow" folder too
  broad (it's the manual flow) #13; rename skills #14/#16; step-0 → Python (determinism) #15; step-0 is
  common to both paths so shouldn't live under manual `workflow/` #17; analysis referenced from both skills
  = DRY (livable) #18; no personal repos (ERD) #19.

### Minor fixes done (committed)
- Removed **stale design codes** `F4/D15/D16/D17/D18` (exemplar docs) + `D9` (step-1) — comments #5–#7.
- Added **output-file paths** for `reference.md` / `footprint.md` (request folder) — comments #8/#9.
- Committed on `feature/atlas-sql-forge` as `3afbad5a0f` (pushed), later cherry-picked to the new branch.

### The branch had become SHARED (root of #20.1)
Colleagues merged their features INTO `feature/atlas-sql-forge`: **Hanna Shapiro** (Performance agent +
OpenSearch/Grafana scorecard), **Suganya B** (performance-executor agent + skill suite), **Raajiv
Madivanane** (perf-profiler). 6 commits + merges on top of our data-gen commit — our work was intact
(base), not overwritten.

### Sync with main (safe merge, no history rewrite)
- Branch was **27 behind `origin/main`** (incl. a "simplify repo structure" commit — but `.kiro/skills`
  still exists at root on main, so **no skill relocation needed**; the "only agents under .kiro" is a future
  direction hinted by `ai-framework/*/.kiro/skills/.gitkeep` placeholders).
- Chose **merge over rebase** (shared branch): fast-forwarded local to the colleagues' commits, then
  `git merge origin/main` (clean, 0 conflicts) → merge commit **`57e02151bd`**, **0 behind main**.
  Pushed as a **fast-forward (no force)** — colleagues just `git pull`; nothing rewritten. Posted a group
  heads-up. **Declined squash** (would rewrite the shared branch / erase colleagues' authorship).

### Branch split — the clean data-gen branch (current)
- Created **`feature/atlas-data-generator`** off `origin/main`; cherry-picked ONLY our two commits →
  `6941d0f49f` (data-gen skills + agent + README) + `7095239373` (the #5–#9 fixes). **0 conflicts.**
- Diff vs main = **exactly our 26 files** (no colleague/perf/opensearch files); **0 behind main**;
  all 4 skills + agent validate. **Pushed to dev** (first push). `feature/atlas-sql-forge` left untouched
  for the colleagues' performance work.
- **This `feature/atlas-data-generator` branch is now the one to open the clean data-gen MR from.**

### README
- Added a **Data Generation Skill Suite** section to the repo `README.md` (styled like the a11y suite) —
  carried on both `feature/atlas-sql-forge` and `feature/atlas-data-generator`.

### Still open (data-gen)
Renames #3/#4/#13/#14/#16; step-0 → Python + trim MD (determinism, #15/#20.4); step-0 placement
restructure #17; tools docs purpose/steering #10–#12; **ERD personal repo #19** (migrate `erd-gen` to a
shared namespace or drop `data-gen-erd`); open the new MR from `feature/atlas-data-generator` and
close/retarget **!101**; Theme-A reviewer reconciliation.


---

## 15. Determinism rebuild — `dg` CLI (2026-08-03) — WIP, UNCOMMITTED (discovered this session)

**Context:** A prior session on 2026-08-03 began the biggest MR !101 ask — **#15 / #20.4: convert the
deterministic MD workflow to Python the agent parameterizes, and trim the ~4,000 MD lines**. This was
left **entirely uncommitted** on `feature/atlas-data-generator` and was NOT recorded until now. The
tracker previously said "tree clean" (as of 07-31) — that is stale.

### What exists (uncommitted, verified this session)
- **New `.kiro/resources/data-generator/scripts/`** — a `dg` CLI (`dg.py`) plus pure-function libs:
  `scaffold.py`, `state.py`, `gate.py`, `fields.py`, `footprint.py`, `coverage.py`, `sql_emit.py`,
  `validate.py`, `erd_input.py`. `dg.py` header: *"Pure functions over on-disk artifacts; never calls
  MCP/network."* Supporting: `schemas/` (state, decisions, payload-file/-metadata/-spec JSON schemas),
  `config/` (`thresholds.json`, `domains.example.json`), `ruff.toml`, `.gitignore`, and `tests/`
  (10 test files + fixtures + conftest).
- **New `.kiro/skills/data-gen-erd/references/generate-erd.md`** (untracked).
- **16 tracked MD files trimmed** — diffstat **+283 / −3,997**. The workflow/exemplar docs + skill
  `references/` are now **thin delegation docs** that invoke `dg <subcommand>` (e.g. `dg init`,
  `dg gate --require 5 --then gen`, `dg verify-input`) instead of prose procedure. Confirmed on
  `step-0-initialize.md` (453→~30 lines) and `data-gen/references/create-records.md`.

### Verification run this session (all green)
- **89 tests pass** — `python3.13 -m pytest -q` in the scripts dir (0.35s). (System `python3` is 3.14
  with no pytest; **use `python3.13`**.)
- **All 4 skills valid** — `quick_validate.py` on `data-gen`, `data-gen-bulk`, `data-gen-erd`,
  `data-gen-manage` → "Skill is valid!".
- **Agent validates** — `kiro-cli agent validate --path .kiro/agents/data-generator.json` → EXIT 0.
- **ruff NOT run** — not installable here (PEP 668 externally-managed env; declined
  `--break-system-packages`). Lint is a nice-to-have; the 89 passing tests are the functional signal.

### NOT yet done (still open on this branch)
- **Renames #3/#4/#13/#14/#16** — skill folders are still `data-gen` / `data-gen-bulk` / `data-gen-erd`
  / `data-gen-manage` (reviewer wants clearer names).
- **Step-0 placement #17** — not restructured into a common step-0 + auto-analysis/ + manual/ layout.
- **ERD personal repo #19** — `erd-gen` still personal namespace.
- **Not committed / not pushed.** Working tree dirty (16 modified + 2 untracked trees).

### Immediate decisions needed before committing
1. **`dg` invocation contract:** the trimmed MD calls a bare `dg` command. Confirm how the agent runs it
   (PATH shim vs `python3 …/dg.py`) and that the seeding prompt tells it the interpreter — the host
   default `python3` is 3.14 (no deps); the working interpreter here was `python3.13`. This must be
   pinned in the prompt/docs or the agent will fail at runtime.
2. **Commit strategy:** this is the reviewer's requested **follow-up MR** ("rebuild the skills more
   deterministically"). Decide whether it lands on `feature/atlas-data-generator` (same MR) or a
   dedicated follow-up branch/MR, since #20.1 was "don't mix unrelated changes."
3. Do the renames (#17 restructure) BEFORE committing, or as a separate pass, to avoid churn.

### Update 2026-08-03 (later) — invocation contract RESOLVED (edits only, not committed)
Decision #1 above is done, matching the repo standard (a11y-* / data-model-* / integration / skill-creator
all invoke scripts as `python3 <full-path>/script.py` — no PATH shim). Confirmed `dg` is **stdlib-only**
(only non-obvious imports are `glob`/`tempfile`, both stdlib) → runs on any `python3` ≥ 3.9 **including the
host default 3.14**; no venv/`setup.sh` needed (the a11y venv pattern is only for PyYAML deps).
- **prompt.md** — added a "Deterministic CLI (`dg`)" section: canonical form
  `python3 .kiro/resources/data-generator/scripts/dg.py <sub>` (run from repo root), stdlib-only note,
  subcommand list, pointer to `tools/README.md`.
- **15 runnable command lines** across 8 docs rewritten from bare `dg <sub>` →
  `python3 .kiro/resources/data-generator/scripts/dg.py <sub>` (line-anchored `^    dg `; args/quotes/inline
  comments preserved; backups taken + removed). Inline prose `` `dg <sub>` `` mentions left as the CLI's
  short name (mirrors a11y prose using short script names).
- **tools/README.md** (#10) — clarified purpose (MCP tools vs the `dg` CLI) + added a full `dg` command
  reference table.
- **Verified:** 4 skills `quick_validate` OK; `kiro-cli agent validate` EXIT 0; `dg --help` runs on default
  `python3`; **89 pytest pass**; zero runnable bare-`dg` lines remain; 19 full `python3 …/dg.py` refs.
- **Not committed** (per instruction). Still on `feature/atlas-data-generator`, HEAD `7095239373`.
- Still-open decision #2 (same MR vs dedicated follow-up MR) and #3 (renames/#17 restructure) unchanged.

### Update 2026-08-03 (later 2) — skill renames #3/#14/#16 DONE (edits only, not committed)
Renamed all four skill folders to a consistent `data-generate-` prefix (matches repo `<domain>-<action>`):
`data-gen`→`data-generate-records`, `data-gen-bulk`→`data-generate-sql`, `data-gen-manage`→`data-generate-manage`,
`data-gen-erd`→`data-generate-erd` (chose `data-generate-manage` over the reviewer's literal
`data-generator-manager` for prefix consistency). Done via `git mv` (renames staged, not committed).
Updated: each SKILL.md `name`, all sibling cross-links in descriptions, agent `resources` (4 `skill://`),
`prompt.md` router+prose, `tools/README.md`, `decisions.schema.json` description. Left untouched: semantic
prose ("not created by data-gen", "in a data-gen session") + code docstrings + test fixtures.
Verified: 0 stale refs; 4 skills `quick_validate` OK; agent validate EXIT 0; 89 pytest pass.
Remaining MR!101 open items: #4 (rename "exemplar"), #13 (rename "workflow"), #17 (step-0 placement),
#11/#12 (tool-reference as MCP steering), #19 (ERD external tool hosting).

### Update 2026-08-03 (later 3) — #4/#13/#17 folder restructure + mode rename DONE (Scope 2, edits only, not committed)
Chose reviewer **option B** layout + full **Scope 2** (rename the internal mode enum too).
- **Layout** (`git mv`): `resources/data-generator/workflow/{ step-0-initialize.md (common), manual/ (step-1..5,4b), auto-analysis/ (auto-1..4, was exemplar-1..4) }`. Old `exemplar/` folder removed.
- **Mode enum** `exemplar` → **`auto-analysis`** everywhere it's a functional value: `dg.py` (`--mode {manual,auto-analysis}`, `mode==` check), `scaffold.py` (mode chains + `if mode==` + error msgs), `footprint.py` glob, and the JSON **schema enums** (decisions/payload-metadata/state). Request subdir `raw/exemplar/` → **`raw/auto-analysis/`**. Fixture dir `sourceselection-exemplar/` → `sourceselection-auto-analysis/` (+ its `mode` values). Tests: fixture paths, `mode=` args, `raw/…` assertions, and `test_exemplar_*` names → `auto-analysis`.
- **Docs/prose**: repointed both skill dispatchers' Path A/B (`workflow/manual/…`, `workflow/auto-analysis/…`), relabeled "Example-Based/Exemplar-Based/exemplar mode" → **Auto-Analysis** in prompt, skills, workflow docs, tool-reference, help strings, schema descriptions, fixtures README.
- **KEPT (different concept — manual step 2):** `step-2-exemplar-discovery.md`, the `exemplar.md` artifact, "exemplar value patterns", "Step 2 exemplar", and the manual-chain listing. Flagged that "exemplar" still names the manual sampling step (legitimately distinct from the auto-analysis flow).
- **Verified:** 89 pytest pass; `dg init --help` shows `{manual,auto-analysis}`; 4 skills `quick_validate` OK; agent validate EXIT 0; 0 stale folder-path refs. Renames staged via git mv, **not committed**.
- **MR !101 remaining after this:** #11/#12 (tool-reference as MCP steering), #19 (ERD external tool hosting), #1/#2 & #18 (discussion/no-action). #3/#4/#13/#14/#15/#16/#17/#5-10/#20.1/#20.2/#20.4 done.

### Update 2026-08-03 (later 4) — #11/#12 MCP steering DONE (edits only, not committed)
Added a "How to use this MCP (steering)" section to the top of both `tools/tool-reference-atlas.md`
(when to use / canonical call order: record_type_map → field_map → reference_data → schema → write-graph;
resolve UUIDs via the map not search_objects) and `tools/tool-reference-data-generator.md` (execution/verify
phase, gated behind analysis + human confirm; get_record_properties → create in insertion order capturing PKs
for @alias FKs → verify_write_coverage/query_records → get_session before rollback; bulk = CSV→SQL). Kept the
per-tool arg/return detail below as reference. `tools/README.md` reframed to note the steering+reference split.
Verified agent validate EXIT 0. MR!101 remaining: #19 (ERD external tool hosting); #1/#2 & #18 (no-action).

### Update 2026-08-03 (later 5) — live agent test (session 474c96b1), fixes + audit (edits only, not committed)
User ran the `data-generator` agent live (SourceSelection, auto-analysis clone of reference `code26R0907`).
**Outcome: succeeded end-to-end** — 30 records / 14 tables created live, `verify_write_coverage` PASS 14/14,
rollback offered. Renamed skills, `workflow/manual` + `workflow/auto-analysis` paths, `--mode auto-analysis`,
and `python3 …/dg.py` invocation all worked in the live env.

**Two friction points found + FIXED (docs):**
1. `dg plan-footprint` returned empty because nothing told the agent to first save `get_schema_relationships`
   → `raw/schema_relationships.json`. Added a "## 1. Save the schema graph (required input)" step to
   `workflow/auto-analysis/auto-2-footprint-discovery.md`.
2. Agent fumbled `gate`/`state` invocation (guessed `--request-dir`/`--pass`/`--dir`). Root cause: CLI
   inconsistency — `gate`/`state` use the global `--state` flag (default `state.json`/`$DG_STATE`) while all
   other subcommands use `--dir`. Added a "## 4. Running dg against THIS request folder" note to
   `step-0-initialize.md` (use `export DG_STATE=<folder>/state.json`, shows `state set` + `gate` forms) and
   fixed the gate example in `create-records.md`. (DG_STATE honored at dg.py:200.)

**Audit of the run:**
- **Tools: ✅ only correct tools** — Atlas (read) + DG (write/query) MCP + read/write/shell. Hard rule
  respected (schema from MCP, not local files).
- **Steering: structure followed (right skill, auto-analysis path, gates in order) BUT the agent bypassed the
  deterministic `dg` validators** — only ran init/gate/plan-footprint/state; **hand-wrote `footprint.md` and
  `validation-report.md` and set gates PASS manually** (the reviewer's #15/#20.4 anti-pattern).
- **Documents: partial** — produced decisions/state/reference/footprint/data-architecture/validation-report/
  execution-log. **Missing `payloads/` and `raw/`** (records created from an in-context plan; raw captures
  never saved — the plan-footprint failure's direct cause).

**Hardening added (addresses the drift):** a **HARD RULE** in `prompt.md` (dg section) + both skill
dispatchers — MUST persist MCP outputs to `raw/`, materialize `payloads/` and execute from them, generate
gate reports via `dg build-footprint`/`validate`/`check-fields`/`coverage-gate` (never hand-write them or set
a gate PASS to skip a check), and re-run a failed `dg` step after fixing its input rather than routing around.
Verified: 2 skills quick_validate OK, agent validate EXIT 0. (89 dg pytest unaffected — no code changed.)

### Update 2026-08-05 — removed `data-generate-manage` skill + rollback (per owner intent; edits only, not committed)
Owner clarified explore-schema/query-validate were never meant as user-facing skills — they're generation-
workflow mechanics that got split out during reorg — and rollback is not wanted for now.
- **Deleted the `data-generate-manage` skill** (SKILL.md + explore-schema/query-validate/rollback references).
  Its explore/query content already lives in the common reference `resources/data-generator/tools/
  tool-reference-atlas.md` (schema tools + steering) and `tool-reference-data-generator.md` (query/verify),
  so nothing was lost — just de-duplicated.
- **Removed rollback everywhere** it was an offered capability: the create-records "Offer rollback" step
  (→ plain "Finish: set gen PASS + report"), records SKILL.md line-52 offer, prompt DG-MCP description +
  `get_session`/`rollback_session` tool line, and the `tool-reference-data-generator.md` steering step,
  `get_session`+`rollback_session` catalog entries, efficiency rule, pk_field note + README list.
- **Rewired:** agent `resources` 4→3 (records/sql/erd); agent description scrubbed of inspect/manage/schema/
  query/rollback triggers; prompt router row removed + menu "four"→"three"; removed dead **D14** (manage-
  routing) decision from `decisions.schema.json` and updated the 2 D14-dependent tests in `test_validate.py`.
- **Verified:** 0 orphaned `data-generate-manage`/rollback refs; agent + decisions.schema JSON valid; 3 skills
  quick_validate OK; agent validate EXIT 0; **89 pytest pass**.
- Suite is now **3 skills**: `data-generate-records`, `data-generate-sql`, `data-generate-erd` (erd still
  pending the #19 hosting decision).

### Update 2026-08-05 (later) — ERD renderer ported Go→Python, vendored in scripts/ (closes #19; edits only, not committed)
Owner asked to strip the Go and vendor the renderer as Python scripts. Done — faithful from-scratch port of
`github.com/ram-020998/erd-gen` (Go, stdlib-only) into **stdlib-only Python** under
`.kiro/resources/data-generator/scripts/`:
- `erd_layout.py` (← layout.go — domain grouping/ordering + grid placement), `erd_router.py` (← router.go —
  orthogonal obstacle-avoiding routing), `erd_render.py` (← render.go — Lucid Standard Import doc, matching
  field order + omitempty), `erd_api.py` (← api.go — Lucid REST via `urllib`; the ONLY networked part),
  `erd_gen.py` (← main.go + cmd_*.go — CLI: generate/update/export/share; `.lucid` = ZIP of document.json).
- **Offline by default**: `erd_gen.py generate --input <app>-erd.json --output <app>.lucid` builds the diagram
  file with no token/network; `--upload` (and update/export/share) opt-in via `LUCID_API_TOKEN`.
- **Fidelity verified**: built the original Go binary (go1.26) and compared — the emitted `document.json` is
  **semantically equal** to the Go tool's for the same input; the Python port is also **byte-deterministic**
  across runs (Go was not — it iterates a map in random order). 11 new unit tests in `tests/test_erd_gen.py`.
- Repointed `data-generate-erd` SKILL.md + `references/generate-erd.md` + `tools/README.md` + `erd_input.py`
  docstring to the bundled renderer; **removed all "external erd-gen CLI / personal repo / #19 / DEC-3 / curl|bash"
  references.** This **closes MR!101 #19 / #20.3** (no personal repos; renderer is now in-repo, deterministic,
  tested).
- **Verified**: erd skill quick_validate OK; agent validate EXIT 0; **full suite 100 pytest pass** (89 dg + 11 erd);
  no lingering external-erd-gen refs.

**MR!101 now**: every actionable comment implemented (incl. #19); #1/#2 & #18 remain discussion/no-action.
Still not committed/pushed; fresh MR from `feature/atlas-data-generator` + close/retarget !101 still pending.

### Update 2026-08-05 (later 2) — scripts reorganized by functionality (edits only, not committed)
Owner: "scripts are scattered." Regrouped the 15 flat modules into two functional packages, keeping the
documented `dg.py` invocation UNCHANGED (zero workflow-doc churn):
```
scripts/
  dg.py                     # entry — path unchanged
  dglib/                    # workflow engine: state, gate, scaffold, footprint, fields,
                            #   coverage, validate, sql_emit, erd_input + config/ + schemas/
  erd/                      # ERD renderer: erd_gen (entry), erd_layout, erd_render, erd_router, erd_api
  tests/  ruff.toml  .gitignore
```
Mechanics (no module-logic edits, no test-file edits, no `_HERE` edits):
- `config/` + `schemas/` moved INTO `dglib/` so `_HERE`-relative loads (fields/validate/erd_input) still resolve.
- `dg.py` prepends `dglib/` to `sys.path` (3-line bootstrap) → its bare imports work; `erd/erd_gen.py`'s own
  dir is `sys.path[0]` when run, so its bare imports work.
- `conftest.py` now adds `dglib/` + `erd/` to `sys.path` → all tests keep bare imports unchanged.
- Doc path updates: `scripts/erd_gen.py` → `scripts/erd/erd_gen.py` (erd SKILL.md, generate-erd.md, README);
  `config/*.json` → `dglib/config/*.json` (erd docs, step-0 thresholds ref, `.gitignore`).
- **Verified:** 100 pytest pass; `dg.py` + `erd/erd_gen.py` run and build a valid `.lucid`; 3 skills
  quick_validate OK; agent validate EXIT 0.

## 16. ERD→MCP migration, gate/doc fixes, and clean MR-ready branch (2026-08-05)

This section supersedes the "vendored ERD renderer" approach in §15 (later-1/later-2): the ERD renderer was
moved OUT of solutions-os and INTO the Data Generator MCP server, and the branch was cleaned + rebased and is
now MR-ready.

### 16.1 ERD generation folded into the DG MCP server (`solutions-atlas-dg-mcp-server`)
Owner decision: expose the full ERD lifecycle as MCP tools so the agent uses tools (not shell scripts) and the
Lucid key is configured in the agent's MCP config.
- Worked on the **dev fork** `appian/dev/solutions-atlas-dg-mcp-server`, branch **`feature/erd-tools`**.
- Ported the Go `erd-gen` (already Python from §15) into `data_generator/erd/` (`layout`, `router`, `render`,
  `packaging`, `input_builder`, `lucid_api` using `requests`). Added `data_generator/tools/erd.py` exposing
  **5 MCP tools**: `build_erd_input`, `generate_erd` (upload; `dry_run` returns the doc offline), `update_erd`,
  `export_erd`, `share_erd`. Registered in `server.py` (21 tools total) + schemas in `models.py`.
- Config: `LUCID_API_TOKEN` optional in `config.py`; wired into the repo's `mcp.json` env (later changed to
  fill-in `<your-lucid-api-key>` placeholders so users input the key directly). `.env.example`/README/docs updated.
- **CI fix:** `requirements.txt` pinned **`mcp<2.0.0`** — the unpinned `mcp` had resolved to the new 2.0.0
  which removed `Server.list_tools()`/`Tool.inputSchema` and broke the Test stage (pipeline 6505858).
- **Lucid 401 hardening:** verified via Lucid docs that the `/v1` base path already supplies the required
  `Lucid-Api-Version` (so NOT a missing-header bug); a 401 = invalid/expired/malformed token or a container
  started before the token was set. Added token `.strip()` + an actionable 401 message.
- Verified in clean venv: **85 pytest pass**, flake8 clean (CI parity). Commits `005f079`→`94d7f33`→`26e50af`
  →`0c5f54d`; pipelines green.
- **STATUS: MERGED to prod + image built** (per owner) — the ERD MCP tools are live in
  `registry.gitlab.appian-stratus.com/appian/prod/solutions-atlas-dg-mcp-server:latest`.

### 16.2 solutions-os ERD skill rewired to the MCP tools; vendored renderer removed
- `data-generate-erd` SKILL.md + `references/generate-erd.md` rewritten to drive the flow via the
  `@appian-data-generator` MCP tools (Atlas schema → `build_erd_input` → `generate_erd` [dry_run to skip
  upload] → update/export/share). No local scripts, no request-folder artifacts.
- Removed from solutions-os: the vendored `scripts/erd/` package, `scripts/tests/test_erd_gen.py`, the
  `dg erd-input` subcommand (`dglib/erd_input.py` + dg.py wiring + `test_erd_input.py`), and
  `dglib/config/domains.example.json`. Updated prompt (dg subcommand list + added ERD tools to the DG MCP
  catalog), `tools/README.md`, `step-0`, `conftest.py`, `.gitignore`.

### 16.3 Footprint completeness gate (fixes missed tables — session 3f0d3db6)
Live test cloned an evaluation but the agent queried only ~8 of the 33 planned tables and declared the
footprint complete (criteria-assignments etc. missed); `build_footprint` had no plan-vs-capture reconcile.
- Added `reconcile_plan()` to `dglib/footprint.py`; `dg build-footprint` now **hard-fails (exit 1) listing any
  planned table with no `raw/auto-analysis/<table>.json` capture**, with a cited `--exclude TABLE="reason"`
  escape hatch (mirrors the manual coverage-gate). Report gains a "Completeness gate: PASS/FAIL" section.
- Steering: HARD RULE in `auto-2-footprint-discovery.md` — query every planned table (even if expected empty).
- 5 new tests; suite green.

### 16.4 Document-library (D12) handling on the auto-analysis path (fixes unused document library)
The clone path never used the DG MCP document library — its "preserve reference FK verbatim" rule swept
Document-type fields (`appianDocId`) into copy-as-is. Added **D12** to `auto-3-clone-scale-plan.md`: resolve
every Document-type field via `find_document`/`list_documents` (record `{documentId,name,why}`; never copy the
reference's id or invent one), and carved Document fields out of "preserve verbatim." Aligns with the existing
`decisions.schema.json` D12 (already scoped to "E3 rule 3").

### 16.5 Readiness cross-check → secret/artifact/history cleanup → clean rebase (MR-ready)
Cross-verification found the branch was NOT MR-ready: the committed "Intermediate commit" (`ff31ca0155`) held
**real secrets** (GITLAB/GITHUB/APPIAN/LUCID) and **test-run artifacts** (`d1.json`, `data-requests/`, 18 files;
124 files / 8138 insertions vs main).
- Owner removed secrets from the working file. Rebuilt the branch clean: mixed-reset to main, dropped artifacts,
  gitignored `data-requests/`, staged only the intended set (agent + `resources/data-generator/**` + 3
  `data-generate-*` skills + README), gated for secrets/artifacts, committed as **one clean commit**.
- Branch was **16 behind** the real main (built off a stale local `origin/main`). **Rebased** the single commit
  onto latest `origin/main` (`9c4dbc758f`); one `.gitignore` conflict resolved by union (`test-artifacts/` +
  `data-requests/`). Now **0 behind, 1 ahead** = `b1cce65823`.
- Re-validated on the new base: 3 skills `quick_validate` OK, `kiro-cli agent validate` EXIT 0, **89 dg pytest
  pass**, working tree clean, secret/artifact gates PASS.
- **Force-pushed-with-lease** to the dev fork (non-shared branch): `feature/atlas-data-generator` = `b1cce65823`
  (remote == local). Backup of the old tip at local branch `backup/pre-clean-ff31ca0155`.

### 16.6 MR !101 — FINAL coverage (re-fetched 2026-08-05, still 20 comments, none new)
ALL comments covered:
- Code/doc: #3/#14/#16 (renames), #4/#13/#17 (auto-analysis/manual restructure + mode rename), #5–7 (codes),
  #8/#9 (paths), #10 (README), #11/#12 (MCP steering), #15/#20.4 (deterministic `dg` + trim),
  **#19/#20.3 (ERD personal repo) — FULLY RESOLVED via the merged DG MCP ERD tools**, #20.1 (split), #20.2 (0 behind).
- No-code (correct outcome): #1/#2 (DG-vs-Dev-MCP — answered in thread), #18 (DRY — reviewer "can live with it").

### 16.7 CURRENT STATE / NEXT STEPS (handoff)
- **solutions-os**: dev fork branch `feature/atlas-data-generator` = clean single commit `b1cce65823`, 0 behind
  main, validated, no secrets/artifacts. **MR-ready.**
- **DG MCP**: merged to prod + image built; ERD tools live.
- **PENDING (human):**
  1. **Create the solutions-os MR** dev→`appian/prod/solutions-os` `main` via the UI link (agent token 403s on
     MR create). Draft title/description prepared. **Close/retarget MR !101** to it (note #19 resolved via DG MCP).
  2. **ROTATE the 4 exposed tokens** (GitLab PAT, GitHub PAT, Appian API key, Lucid key) — they persist in the
     old, now-unreferenced commit object on the remote until GC.
  3. PO & UX MRs (`feature/atlas-product-owner`, `feature/atlas-ux-designer`) still pending (unchanged).
  4. DG MCP Phase 5 — archive personal `ramaswamy.u/solutions-atlas-dg-mcp-server` + personal `erd-gen` repo.
- **Delete** local `backup/pre-clean-ff31ca0155` once the MR looks correct.

## 17. MR !111 opened, reviewed, and review round addressed (2026-08-06 → 08-10)

The clean data-gen branch was opened as **MR !111** (`appian/prod/solutions-os!111`,
`feature/atlas-data-generator` → `main`, author ramaswamy.u). Reviewer **walid.elsayed** left 4 inline
threads + a praise comment linking a **Kiro-generated review doc** (auth-gated Google Doc; user saved it to
`atlas-revamp/MR !111 — mr-111-...review.md`). Verdict: request changes. All 16 findings (2 P0, 9 P1, 5 P2)
were addressed and force-pushed.

### Delivery
- Committed as **`6260d091dd`** on top of `b1cce65823`, rebased both onto latest `origin/main`
  (clean, 0 behind / 2 ahead), force-pushed-with-lease to dev: **`b1cce65823...9b573fadaa`** → MR !111 updated.
- Backup of the pre-review tip at local branch `backup/pre-mr111-review`.
- Verified: **98 pytest pass**, `ruff check .` clean (E/F/I/W, E402 ignored), 3 skills `quick_validate` OK,
  `kiro-cli agent validate` exit 0, working tree clean.

### P0 (blocking)
- **P0-1 README ghost skills** — README listed 4 non-existent skills (`data-gen`/`-bulk`/`-manage`/`-erd`);
  rewrote the table to the 3 real skills (`data-generate-records`/`-sql`/`-erd`), dropped manage/rollback,
  fixed "Example-Based"→"Auto-Analysis".
- **P0-2 jsonschema silent SKIP** — `check_schema`/`check_decisions` returned SKIP without `jsonschema`
  (hiding failed validation). Added `_require_jsonschema()` → hard-fail with install hint; new
  `scripts/requirements.txt` (`jsonschema>=4.0`); corrected the "no third-party deps" wording in prompt.md +
  tools/README.md.

### P1 (recommended)
- **P1-1 prompt URI (Thread 1)** — `file://../resources/...` → **`file://.kiro/resources/data-generator/prompt.md`**.
  Confirmed correct: `kiro-cli agent validate` errors on this form identically for the team's working
  `TEA.json`/`dev-automated-testing.json`, so its file:// check is NOT authoritative (corrects the old
  "prompt-path rule" in the handoff/design docs).
- **P1-2 workflow docs outside skill folder (Threads 2 & 3)** — fully qualified all `workflow/…` paths to
  `.kiro/resources/data-generator/workflow/…` + added an explicit "Runtime files" note to both SKILL.md
  (not auto-loaded; requires `read`/shell at runtime).
- **P1-3 CDT in sql_emit** — `emit_sql` now raises `ValueError` on `mechanism=="CDT"`; added `test_cdt_spec_rejected`.
- **P1-4 check_users excluded** — wiring it in exposed real false positives (`groupAssignee:31` is a GROUP id;
  scoped clone `users.json` misses demo users). Fixed `_is_user_field` to exclude `group*` fields; redesigned
  `run_validate(strict_users=False)`: user membership is **advisory (WARN → INCOMPLETE, exit 0)** by default,
  **hard FAIL under `dg validate --with-users`**. Added WARN level + INCOMPLETE banner + `--with-users` flag +
  `test_auto_analysis_strict_users_hard_fails`.
- **P1-5 sparse CLI tests (Thread 4)** — added CLI smoke tests (init, state set/get, gate block→open, gen-sql,
  validate, coverage-gate hard-block, verify-input) on tmp fixture copies.
- **P1-6 dglib not a package** — added `dglib/__init__.py`; `dg.py` → `from dglib import … as …lib` +
  `from dglib.state import VALID_STATUSES, State, StateError` (fixed a hidden dynamic `__import__("state")`);
  relative imports in gate.py/scaffold.py; conftest adds only the scripts dir; all 8 test files migrated.
  Eliminates `import coverage`/`state` shadowing.
- **P1-7 ruff/CI** — import order clean after P1-6; created `.kiro/resources/data-generator/.gitlab-ci-data-generator.yml`
  (`dg-tests` job: ruff + pytest + jsonschema, scoped `rules: changes`) and `include`d it in root `.gitlab-ci.yml`
  (mirrors the a11y-rules pattern).
- **P1-8 fixture MCP version** — added `raw/_capture.json` (image tags + captured_at) to all 3 fixtures +
  documented it in fixtures/README.md.
- **P1-9 duplicated CRITICAL RULES** — canonical 12-item `## CRITICAL RULES` now in prompt.md; both SKILL.md
  reference it with a brief summary; removed a stale "roll back a session" mention.

### P2 (polish)
- **P2-1** naming audit clean (no `data-gen-*`; 22 `data-generate-*`; no exemplar/example-based leftovers).
- **P2-2** split the 700-char README paragraph; MCP env as a bullet list.
- **P2-3** removed the dead `@@FK:` branch in `sql_literal`.
- **P2-4/P2-5** added determinism notes (seed = `(seed, field, row index)`; `cycle` index-arithmetic vs
  `pick` seeded-RNG) to `payload-spec.schema.json`.

### Still open
- **Rotate the 4 exposed tokens** (GitLab/GitHub/Appian/Lucid) — user action, unchanged.
- Re-review of !111 by walid; then merge (MCP image already live).
- PO & UX domain MRs; DG MCP Phase 5 (archive personal repos); delete `backup/*` safety branches once merged.
