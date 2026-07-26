# MR !92 — Review Response Notes

**MR:** appian/prod/solutions-os!92 — *feat: Atlas agent — single agent with hub-and-spoke skills*
**URL:** https://gitlab.appian-stratus.com/appian/prod/solutions-os/-/merge_requests/92
**Reviewer:** walid.elsayed · **State:** changes requested · **Comments:** 17
**Prepared:** 2026-07-22

This captures my thoughts on each comment to help us decide responses before editing. Comments
cluster into 5 themes; I address each comment individually and cross-link to the theme.

> ⚠️ **Heads-up on one tension:** several comments (esp. the "3 skills + references" architecture)
> ask for the **opposite** of the earlier explicit direction ("everything as individual skills,
> one action per skill"). That's a real product decision — flagged in Theme A so we align the
> reviewer and the original ask rather than silently flipping.

---

## Themes at a glance

- **A. Architecture: collapse ~40 skills → 3 hub skills, spokes become `references/`** (biggest; also fixes nested-folder discoverability and "move hub up a level").
- **B. Terminology: stop using "agent" / "sub-agent"** (reserved meaning in Kiro; and we don't actually spawn sub-agents).
- **C. Convergence / de-duplication** with existing capabilities (a11y audit, Dev MCP, ERD power, docs MCP, html vs sailwind).
- **D. Repo hygiene** (move DG MCP image out of personal namespace).
- **E. Content specifics** (spec template, technical-debt orphan logic, step numbering).

---

## A. Architecture — "3 skills, everything else under references/"

**Comments:** general note #3; `atlas.json:19` ("boil down to 3 skills … everything else under /references"); `atlas-product-owner/atlas-product-owner/SKILL.md:1` and `atlas-sql-forge/atlas-sql-forge/SKILL.md:1` (move hub up one level; nested skills "not discoverable outside the agent"); general note #2 (UXD/SQL-forge files too big).

**My thoughts — I largely agree, and it also fixes two other comments at once.**
- The reviewer is **correct on discoverability**: Kiro's default skill inheritance glob is single-level (`skill://.kiro/skills/*/SKILL.md`). Our nested `…/atlas-product-owner/atlas-product-owner/SKILL.md` is only reachable because the agent lists it explicitly; it is **not** discoverable as a standalone `/atlas-product-owner` skill in the IDE/CLI. This is the exact caveat I raised when we did the grouping.
- Collapsing to **3 hub skills** (`atlas-sql-forge`, `atlas-product-owner`, `atlas-ux-designer`) each at `.kiro/skills/<hub>/SKILL.md`, with the spokes moved to `.kiro/skills/<hub>/references/*.md`, would:
  - make each persona hub **directly invocable** (`/atlas-product-owner`) without the orchestrator,
  - cut always-loaded skill metadata from ~40 to 3,
  - keep context lean — reference files still load **on demand** when the hub tells the agent to read them (same progressive-disclosure benefit we wanted from spokes),
  - resolve the "move hub up one level" and "nested not discoverable" comments in one move.
- **What we lose:** individual spokes can no longer self-trigger via their own `description`. For our design that's fine — the hubs already route to each step/action, so triggering was always meant to go through the hub.
- **Big files (Theme #2):** moving the verbatim UX/SQL-forge bodies into `references/` doesn't shrink them, but they stop being registered skills and only load when needed. If we want them smaller, we can split long reference files by section — separate concern.

**Recommendation:** Adopt the 3-hub + `references/` layout. **But confirm with the requester first**, because it reverses the earlier "one action per skill" instruction. If we adopt it, the migration is mostly mechanical: `SKILL.md` (hub) stays, each spoke `SKILL.md` → `references/<name>.md`, and the hub's routing switches from "invoke skill X" to "read `references/X.md`".

---

## B. Terminology — "agent" / "sub-agent"

**Comments:** general note #1; `atlas-sql-forge/…/SKILL.md:8` ("pick different term"); `:74` ("not sure this is the right term" — the "sub-agents" label on the Manual pipeline); `:106` ("we are not spawning sub agents"); `atlas-prompt.md:38` ("replace this word … a sub agent is a real agent available to orchestrator").

**My thoughts — agree, and there's a real inconsistency to fix, not just wording.**
- In Kiro, "sub-agent" means a real agent spawned via the `subagent` tool. Our hub text says Steps 1–5 "run as sub-agents," but the `atlas` agent's `tools` are only `read, write, shell, @appian-atlas, @appian-data-generator` — **no `subagent` tool**. So the agent literally cannot spawn sub-agents; the wording is misleading and, as the reviewer says, will confuse the model.
- Two clean ways to resolve:
  1. **Reword to sequential steps (simplest, matches capability):** the single agent reads each step reference and performs it in order — call them "steps"/"phases," drop "agent/sub-agent" entirely. This pairs naturally with Theme A (hub reads `references/step-N.md`).
  2. **Actually use sub-agents (heavier):** add the `subagent` tool + crew trust to the agent and genuinely spawn per-step runs for fresh context. Only worth it if we want isolation/parallelism; otherwise it adds moving parts.

**Recommendation:** Option 1 — replace "sub-agent/agent workflow" with "steps the agent runs in sequence." Update the hub, the `## Sub-agent dispatch note`, and `atlas-prompt.md:38`.

---

## C. Convergence / de-duplication

### C1. `atlas-aurora-compliance` vs a11y audit — `atlas-ux-designer/atlas-aurora-compliance/SKILL.md:1`
> "converge with the audit skill … both do static SAIL checks against Aurora … i vote to retire this one and keep the a11y skills."

**Agree.** `a11y-audit` already does static SAIL checks against the canonical Aurora/a11y rule catalog. Duplicating that in an Atlas skill invites drift. **Retire `atlas-aurora-compliance`.** Caveat: we deliberately kept the Atlas agent "Atlas-only" (no a11y dependency); retiring means UX users needing an Aurora check use the `a11y-expert` agent instead. That's the right separation — note it explicitly rather than cross-wiring.

### C2. `atlas-generate-sail-interface` vs Dev MCP — `…/atlas-generate-sail-interface/SKILL.md:1`
> "duplicating the DEV MCP work … code generation should only rely on the Dev MCP; reading Aurora guidelines is good."

**Partially agree.** If a Dev MCP owns SAIL generation, our skill should **delegate generation to it** and keep only the Aurora-doc grounding (via Git-content tools). Action: rework the skill to "gather Aurora guidance + hand off to Dev MCP for generation," or retire if the Dev MCP already reads Aurora. Needs to confirm the Dev MCP's current SAIL-gen capabilities.

### C3. `atlas-sailwind-prototype` vs `atlas-html-prototype` — `…/atlas-sailwind-prototype/SKILL.md`
> "Is this duplicated by atlas-html-prototype?"

**Not a strict duplicate, but mergeable.** HTML = standalone Pico/Sailwind-Lite (~80%, no setup); Sailwind = React component library (~90%, needs Node). Different outputs/fidelity. Options: (a) keep both but cross-reference clearly, or (b) merge into one `atlas-prototype` skill with a `mode: html | react` parameter. Under Theme A they'd both be reference files anyway — I'd merge them into one "prototype" reference with two modes.

### C4. `atlas-sql-forge-erd` vs the ERD power — `…/atlas-sql-forge-erd/SKILL.md:1`
> "connect with @revathi.jayabalan @saravana.manivasakam — this one or the erd power? merge?"

**Needs a decision with the named owners.** We already excluded the solutions-os `erd-generator` *tool* earlier and kept the power's own ERD action (per requester). But there's clearly overlap with a standalone ERD power. Action: sync with the owners; either merge capabilities or pick one canonical ERD path. Don't ship two.

### C5. `atlas-appian-docs` — why a skill? — `…/atlas-appian-docs/SKILL.md:1`
> "we have the docs MCP available … just a wrapper?"

**Mostly agree.** It is a thin wrapper: it uses Atlas Git-content tools as a fallback because our agent is Atlas-only and doesn't wire a docs MCP. If the org's docs MCP is standard, the cleaner move is to **wire the docs MCP at the agent level and drop this skill** (or keep a 5-line router that defers to it). Decision hinges on whether we add the docs MCP to the atlas agent.

---

## D. Repo hygiene — personal → shared repo

**Comment:** `atlas.json:98` — "This needs to move out from personal repo to shared repo."

**Agree — must fix before merge.** The Data Generator MCP image is `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest` (personal namespace). The Atlas MCP is already shared (`appian/prod/solutions-atlas-mcp-server`). Action: publish the DG MCP image under a shared/prod namespace (same pattern as the earlier Atlas KB migration) and update the `appian-data-generator` image ref in `atlas.json`. (The LCP image, if it ever comes back, has the same issue.)

---

## E. Content specifics

### E1. Standardized spec template — `atlas-product-owner/atlas-feature-spec/SKILL.md:28`
> "If we have a standardized template format, we should inject here for all PMs to use."

**Agree — easy win.** Replace our inline generic spec skeleton with the org's canonical PM/feature-spec template (ideally referenced from a shared location so it stays current). If no standard exists yet, this is a prompt to create one. Low effort, high consistency payoff.

### E2. technical-debt: excluding app ref / entry points — `atlas-product-owner/atlas-technical-debt/SKILL.md:18`
> "How is this excluding the app ref / entry points?"

**Good catch — needs verification, likely a clarification.** The skill relies on `list_orphans`. The concern is false positives: an object reachable only via a site/web-API/record-action entry point shouldn't be called "unused." My understanding is the Atlas parser computes reachability **from entry points** and defines orphans as unreachable — so entry-point-reachable objects are already excluded. Action: (a) verify that's how `list_orphans` defines orphans, and (b) add a one-line note in the skill stating orphans = "not reachable from any entry point (sites, web APIs, record actions)," plus a caveat to confirm before deletion. If `list_orphans` does *not* account for entry points, we add an explicit exclusion step.

### E3. Step numbering jumps 0 → 6 — `atlas-sql-forge/atlas-sql-forge/SKILL.md:95`
> "This jumps from Step 0 - Initialize to step 6, are we missing numbering or real steps?"

**Not missing — a labeling/readability issue.** Steps 1–5 (and exemplar E1–E4) exist, but they live under the `### Manual Analysis pipeline` and `### Example-Based pipeline` sub-headings, so the only `### Step N` headings are 0 and 6, which reads like a gap. Fix: relabel so the numbered steps are visible in the outline (e.g., `### Step 1 …` through `### Step 5`, then `### Step 6`), or add a one-line "Steps 1–5 are in the pipeline sections below" pointer right after Step 0. Pure clarity fix.

---

## Suggested disposition / order of work

| # | Item | Stance | Effort | Needs decision/others |
|---|------|--------|--------|-----------------------|
| A | 3 hubs + `references/` (also fixes discoverability & move-up) | Adopt (confirm vs earlier ask) | M | Requester sign-off |
| B | Drop "agent/sub-agent" wording; fix the no-`subagent`-tool inconsistency | Do | S | — |
| D | Move DG MCP image to shared namespace | Do (pre-merge) | M | Infra/registry |
| C1 | Retire `atlas-aurora-compliance` (keep a11y) | Do | S | — |
| E1 | Inject standard spec template | Do | S | Is there an org template? |
| E3 | Fix step numbering label | Do | S | — |
| E2 | Clarify/verify orphan vs entry-point logic | Verify + note | S | Confirm `list_orphans` semantics |
| C5 | `atlas-appian-docs` → rely on docs MCP | Likely drop | S | Wire docs MCP? |
| C2 | `atlas-generate-sail-interface` → delegate to Dev MCP | Rework/retire | M | Dev MCP capabilities |
| C3 | Merge html + sailwind prototypes | Merge | S–M | — |
| C4 | ERD: converge with ERD power | Decide | M | @revathi.jayabalan, @saravana.manivasakam |

**Fastest path to unblock the MR:** B, C1, E1, E2, E3 are low-risk edits we can make now.
A and D are the substantive ones; A needs requester alignment (it reverses earlier direction),
D needs the shared registry. C2/C4/C5 need input from other owners.
