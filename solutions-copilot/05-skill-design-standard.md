# 05 — Skill Design Standard

The rule that makes "lose nothing" enforceable and keeps skills discoverable.

## 5.1 Granularity rule

**One skill = one coherent task a role performs.**

- Test: if the `description` needs the word "and" to join two *unrelated* triggers, **split it**.
- Too coarse → it's a power again (sprawling, hard to trigger reliably).
- Too granular → skill sprawl, hard to discover.
- Keep the `SKILL.md` body short and **actionable** (workflow steps). Push bulk reference material
  (rule lists, grammars, long checklists) into `references/` so it loads only on demand.

## 5.2 SKILL.md template

```markdown
---
name: <lowercase-hyphen-name>            # matches folder name; max 64 chars
description: <What it does> + Use when <triggers/keywords/phrasings>.   # max 1024 chars
---

## Purpose
One or two lines.

## Inputs / preconditions
What the skill needs (e.g., a record type name, a package URL, a feature packet path).

## Workflow
1. Step ...
2. If MCP data is needed, delegate: subagent(<atlas-intel|jarvis-intel|data-generator>, "<focused ask>").
3. ...

## Return format
The exact shape the skill should output (so downstream use is deterministic).

## References
- See `references/<file>.md` for <detail> (loaded on demand).
```

## 5.3 Description-writing rules (drives auto-activation)

- Lead with the action, then the triggers. Include the words a user would actually type.
- Good: `Analyze blast radius of a change to an Appian object. Use when asked "what breaks if I change X", for refactoring risk, or pre-change review.`
- Vague: `Helps with impact analysis.`

## 5.4 Power → destination mapping (not 1:1)

A migrated `solutions-os` power/project splits into up to four destinations. Tag every piece:

| Source content type | Destination |
|---|---|
| Reference knowledge, rule sets, grammars, checklists | **Skill** (`skills/`) — body + `references/` |
| Multi-step workflow a role runs | **Skill** (body as workflow) or **role prompt** |
| Source-routing / always-on guidance | **Steering** (`steering/`) |
| Actual tool/server code (MCP/CLI) | **MCP**, owned by an intelligence **sub-agent** (or external tools repo) |
| Bundled `mcp.json` | **Deleted** — MCP now lives in the sub-agent |
| Pure narrative docs | **Stays in `solutions-os`** |
| Event automation | **Hook** (agent `hooks`) |

## 5.5 Shared vs role-specific

- A skill used by **2+ roles** → `skills/shared/` once; linked by each agent's `resources`.
- A skill used by **one role** → `skills/<role>/`.
- Never copy a skill into multiple roles. Link, don't duplicate.

## 5.6 Naming normalization

Drop tool codenames: `atlas-developer` → `developer`, `atlas-sql-forge` skills → `sql-forge`/data
skills under `developer`/`tester`. Name for **what it does**, not the backend it came from. Cloud
(Atlas) vs Live (Jarvis) is an internal detail behind the sub-agents.

## 5.7 Acceptance per skill (definition of done)

- `SKILL.md` has valid frontmatter (name matches folder; description ≤1024).
- Triggers reliably on representative phrasings (manual check via `/context show` / direct ask).
- Any MCP need is expressed as a sub-agent delegation with a return contract.
- All source content from the originating power is represented (traced in the matrix).

## 5.8 Fidelity rule — PRESERVE, do not paraphrase (mandatory)

**Detailed, multi-step source workflows MUST be preserved verbatim — never summarized.** Several
source powers contain large, strict workflows (e.g. Jarvis `code-review-workflow` 863 lines,
`design-doc-workflow` 1012 lines, `spike-research` 1014 lines, `expression-test-generation` 996
lines) with execution trackers, blocking rules, object-type mappings, templates, and checklists.
Paraphrasing them silently drops behavior.

Required technique (the same one used for `sail-reference`):
1. **Copy each source workflow verbatim** into the skill's `references/` (e.g.
   `references/package-review-workflow.md`). Use `git show <ref>:<path> > references/<file>.md` —
   do not retype or condense.
2. **`SKILL.md` is a thin orchestrator**: frontmatter (trigger) + which reference(s) to load +
   an explicit instruction to **follow the reference exactly** + a small "tooling adaptation" table
   mapping the original direct MCP calls to the sub-agent delegation model. Only the *tooling layer*
   is adapted; **steps, trackers, templates, and rules stay unchanged**.
3. **Consolidate multiple sources as modes**, not by picking one (e.g. code-review = Mode 1 full
   package/ticket review from Jarvis + Mode 2 lightweight KB review from atlas-developer).
4. **Verify by line count**: a migrated skill's referenced content should be comparable to the sum
   of its sources. A 35-line skill replacing an 863-line workflow is a red flag.
5. **Delegation transform (MANDATORY).** Skills run on role agents that have **NO Atlas/Jarvis MCP
   tools** — so a preserved workflow that says "call `get_object_diff`" is *functionally broken*
   unless redirected. Transform the **data-access mechanism** (not the logic): every direct MCP tool
   call becomes a **delegation to the owning sub-agent** (Atlas/KB tools → `atlas-intel`; live/diff/
   package/config/SQL/eval → `jarvis-intel`; record data → `data-generator`). Implement this by
   **prepending the binding "Delegation Protocol" block to every preserved workflow reference** that
   contains tool calls, plus the per-skill tooling-adaptation table in `SKILL.md`. Preserve all other
   steps/templates/trackers/rules unchanged. Pure-knowledge references (checklists, SAIL grammar)
   have no tool calls and need no protocol.

**Core principle:** *skills never call MCP tools directly; all data collection is delegated to the
intelligence sub-agents.* The verbatim source stays intact; only the tooling layer is redirected.
