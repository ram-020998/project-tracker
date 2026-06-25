# 06 — Migration Methodology (lossless, gated)

The migration risk lives almost entirely in **discovery** (projects are spread across many
`solutions-os` branches). Treat it as a gated process; do not transform before the matrix is reviewed.

## Gate 1 — Inventory (08-solutions-os-inventory.md)

Enumerate **every** asset on **every** branch. For each, capture:

| Column | Notes |
|---|---|
| ID | stable id (e.g. INV-001) |
| Branch(es) | which branch(es) it appears on |
| Path | source path within `solutions-os` |
| Asset name | folder / file name |
| Current form | power / skill / steering / hook / mcp-config / tool docs / product knowledge / prototype |
| Content type(s) | knowledge / workflow / tool-code / mcp.json / narrative / data |
| Owner | from SWAT table or git history |
| Notes | duplication, bundled mcp.json, branch-only, etc. |

Branches to cover (from `git branch -a`): `main`, `atlas-qe-forge`, `dp-test-execution-agent`,
and dev-only: `expressionTestCases`, `feature/doccenter-integration-prototype`,
`feature/shared-playwright-deploy`, `gam-suite`, `insuranceprototype`, `jarvisRefactorRedeploy`,
`SI-1067`, `add-landing-page-feature`, `removeEnvVariableDependencies`, `new-branch`.

**Exit:** inventory reviewed; no branch unexamined; duplicates flagged.

## Gate 2 — Traceability matrix (09-traceability-matrix.md)

One row **per source artifact** → its target. Seeded from the SWAT 20-project table, extended with
branch findings.

| Column | Notes |
|---|---|
| Inventory ID | links to Gate 1 |
| Source path/branch | provenance |
| Target type | role-agent / skill (shared or role) / sub-agent / mcp / steering / hook / docs(stays) / drop-with-reason |
| Target path | destination in `solutions-copilot` |
| Owning agent(s) | which role(s)/sub-agent link it |
| Status | pending / in-progress / done |
| Acceptance | the check that proves it migrated |

**Rule:** every inventory row maps to ≥1 matrix row. Coverage must reach 100%. "Drop" requires an
explicit reason (e.g., pure duplicate of another row).

**Exit:** matrix reviewed & signed off. This is the contract that nothing is lost.

## Gate 3 — Vertical slice first

Build **one role end-to-end** before scaling: **Developer + its skills + `atlas-intel` sub-agent**.
Validate: skill activation, `subagent` delegation, return contract, no context bloat, both surfaces.

**Exit:** Developer answers a real query through atlas-intel with no bundled MCP config.

## Gate 4 — Scale & verify

- Build remaining roles (PO, UX, Tester), `jarvis-intel`, Data-Gen.
- Migrate every matrix row; flip statuses to done.
- Per-artifact acceptance passes; matrix coverage = 100%; spot-check no orphaned source content.

**Exit:** all 20 SWAT projects + all branch assets operate in their new Agents+Skills form.

## Cross-cutting transform rules (apply to every row)

1. Remove any bundled `mcp.json`; MCP moves to the owning sub-agent.
2. Normalize names (drop `atlas`/`jarvis` codenames).
3. Source-routing logic → steering, not skill bodies.
4. Tool *code* → MCP/sub-agent; only orchestration knowledge becomes skills.
4a. **PRESERVE detailed workflows verbatim (do NOT paraphrase).** Copy large multi-step source
    workflows (trackers, blocking rules, templates, checklists) into the skill's `references/` via
    `git show`; the `SKILL.md` is a thin orchestrator that points to them and adapts only the tooling
    layer to sub-agent delegation. Consolidate multiple sources as modes. See doc 05 §5.8. (This
    fixes the first-slice defect where an 863-line code-review workflow was condensed to 35 lines.)
5. Consolidate duplicates (Jarvis ×3, KB ×4, buildwithclaude ×5) to a single canonical target.
6. Feature/prototype branches → fold into the relevant product knowledge in `solutions-os`, and any
   tooling they carry → skills/sub-agents here.
