# Phase 5 — Integration, Validation & Cleanup

**Goal (one session):** Wire all 25 skills into the agent, validate the whole set, smoke-test
the action router, and decide the disposition of the four source powers.

**Depends on:** Phases 1–4 complete.

---

## Step 5.1 — Finalize the agent `resources[]`

Add one `skill://` line per skill (25 total) to `.kiro/agents/atlas.json`. Group by area for
readability (matches how `a11y-expert` lists its skills):

```jsonc
"resources": [
  // shared
  "skill://.kiro/skills/atlas-data-workflow/SKILL.md",
  // data generation
  "skill://.kiro/skills/atlas-generate-records/SKILL.md",
  "skill://.kiro/skills/atlas-generate-sql/SKILL.md",
  "skill://.kiro/skills/atlas-query-records/SKILL.md",
  "skill://.kiro/skills/atlas-rollback-session/SKILL.md",
  "skill://.kiro/skills/atlas-explore-schema/SKILL.md",
  // product owner
  "skill://.kiro/skills/atlas-app-onboarding/SKILL.md",
  "skill://.kiro/skills/atlas-explore-feature/SKILL.md",
  "skill://.kiro/skills/atlas-release-review/SKILL.md",
  "skill://.kiro/skills/atlas-impact-analysis/SKILL.md",
  "skill://.kiro/skills/atlas-feature-spec/SKILL.md",
  "skill://.kiro/skills/atlas-research/SKILL.md",
  "skill://.kiro/skills/atlas-feature-inventory/SKILL.md",
  "skill://.kiro/skills/atlas-technical-debt/SKILL.md",
  "skill://.kiro/skills/atlas-cross-app-analysis/SKILL.md",
  "skill://.kiro/skills/atlas-appian-docs/SKILL.md",
  // ux designer
  "skill://.kiro/skills/atlas-html-prototype/SKILL.md",
  "skill://.kiro/skills/atlas-sailwind-prototype/SKILL.md",
  "skill://.kiro/skills/atlas-generate-sail-interface/SKILL.md",
  "skill://.kiro/skills/atlas-edge-case-analysis/SKILL.md",
  "skill://.kiro/skills/atlas-feasibility-check/SKILL.md",
  "skill://.kiro/skills/atlas-design-consistency-review/SKILL.md",
  "skill://.kiro/skills/atlas-component-decomposition/SKILL.md",
  "skill://.kiro/skills/atlas-design-handoff/SKILL.md",
  "skill://.kiro/skills/atlas-aurora-compliance/SKILL.md"
]
```

Confirm the router table in the seeding `prompt` lists all 25 skills and that every routed
skill name matches an existing folder.

---

## Step 5.2 — Whole-set validation
```bash
# every skill passes the preflight
for d in .kiro/skills/atlas-*; do
  python3 .kiro/skills/skill-creator/scripts/quick_validate.py "$d" || echo "FAIL: $d"
done
# agent is valid JSON
python3 -m json.tool .kiro/agents/atlas.json > /dev/null && echo "atlas.json OK"
```
Cross-checks:
- [ ] Every `skill://` in `resources[]` resolves to an existing `SKILL.md`.
- [ ] Every skill `name` == its folder name and starts with `atlas-`.
- [ ] `tools`/`allowedTools` contain only `read`, `write`, `shell`, `@appian-atlas`,
      `@appian-data-generator` — nothing else from solutions-os.
- [ ] No skill references a non-Atlas MCP, the a11y skills, jarvis, playwright, or gws.
- [ ] Cross-skill path references (e.g. `atlas-data-workflow` from the generate skills)
      point at real files.

---

## Step 5.3 — Router smoke test (manual)

Launch the agent and fire one representative prompt per skill; confirm the correct skill
loads and the right MCP tools are called. Minimum matrix:

| Prompt | Expected skill |
|--------|----------------|
| "Create an evaluation in Complete status with 3 vendors in SourceSelection" | `atlas-generate-records` |
| "Generate SQL for 200 evaluations for perf testing" | `atlas-generate-sql` |
| "Show me the schema for VendorManagement" | `atlas-explore-schema` |
| "Roll back what we just created" | `atlas-rollback-session` |
| "What changed in the latest SourceSelection release?" | `atlas-release-review` |
| "What would break if we change the Evaluation record?" | `atlas-impact-analysis` |
| "Make an HTML prototype of the vendor dashboard" | `atlas-html-prototype` |
| "Generate a SAIL form for vendor intake" | `atlas-generate-sail-interface` |
| "Check this design against Aurora" | `atlas-aurora-compliance` |

Watch specifically for the two known collision risks:
- `atlas-generate-sql` vs `atlas-generate-sail-interface` (data SQL vs UI SAIL).
- `atlas-explore-feature` (single feature) vs `atlas-app-onboarding` (whole app).
If either mis-triggers, tighten the losing skill's `description` (per skill-creator: fix the
description, not the body).

---

## Step 5.4 — Disposition of the source powers

Per the retention requirement, **do not delete any Atlas content until the agent is verified.**
Options (pick one, confirm with the owner):

- **A. Keep powers in place** alongside the new agent during a transition window; add a
  deprecation note at the top of each POWER.md pointing to the `atlas` agent. *(Safest.)*
- **B. Remove the four powers** once smoke tests pass, since all content is retained in the
  skills. Leaves `atlas-developer` and `sail-reference` powers intact (out of scope).

Recommended: **A**, then **B** after one confirmation cycle. Either way, verify no other
solutions-os asset imports these powers before removing.

> `atlas-developer` and `sail-reference` powers, and the `erd-generator` tool, are **not**
> modified in any option.

---

## Step 5.5 — Update the overview tracker
Mark phases complete in `00-overview.md` §7 and note the chosen power disposition.

---

## Phase 5 exit criteria
- [ ] `atlas.json` lists all 25 skills; valid JSON; Atlas-only tools.
- [ ] All skills pass `quick_validate.py`; all cross-references resolve.
- [ ] Router smoke test passes for the matrix above with no mis-triggers.
- [ ] Source-power disposition decided and applied; ERD + out-of-scope powers untouched.
- [ ] Overview updated to "complete".
