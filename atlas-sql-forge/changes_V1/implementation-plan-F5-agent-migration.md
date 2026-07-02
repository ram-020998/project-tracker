# Feature 5 — Migrate Atlas SQL Forge from a Power to an Agent (+ Skills): Implementation Plan

**Status:** DRAFT — ready for build
**Reference pattern:** `solutions-copilot/.kiro/agents/*` + `.kiro/skills/*` (role agent → intelligence sub-agents → skills).
**Goal:** Repackage Atlas SQL Forge from a **Kiro power** (`POWER.md` + `steering/` + `mcp.json`) into a **dedicated role agent** (`sql-forge`) with **distinct skills** for single and bulk data generation and the other functionalities — **without losing any content**. Every current artifact maps to a defined new home (§4).

> Hard constraint (user): **loss-free migration.** The §4 mapping table is the contract — nothing in the power may be dropped; each file/tool/rule has a destination.

---

## 0. Key finding — the migration is partly done already

`solutions-copilot` already contains:
- **`data-generator` sub-agent** (`agents/data-generator.json` + `-prompt.md`) — wraps `@appian-data-generator`; reads auto-run, mutations prompt, session/rollback. **The write tier already exists.**
- **`atlas-intel` sub-agent** — read-only `@appian-atlas` KB intelligence; writes an analysis doc to `.kiro/analysis/`. **The read tier already exists.**
- **`tester/test-data-generation` skill** — its SKILL.md says *"the sql-forge data workflow"* and references `step-0…step-6`, `action-generate-data`, `action-bulk-sql`, `tool-reference-*`. **Our steering was already ported here** — but it is (a) buried under the *tester* role as ONE monolithic skill, (b) **pre-F1–F4** (no coverage gate, CDT/DSE, users/docs, bulk-CSV, exemplar mode), and (c) not a standalone agent.

**So F5 = promote that to its own `sql-forge` role agent, decompose the monolith into skills, and bring it up to date with F1–F4.** We reuse the existing `atlas-intel` / `data-generator` sub-agents rather than rebuild them.

---

## 1. Target architecture (two-tier, matches the reference pattern)

```
sql-forge  (ROLE agent — skills, orchestration, NO MCP tools; tools: read/write/shell/subagent)
   │  delegates the COMPLETE objective per hand-off
   ├── atlas-intel      (READ: KB schema/workflow/exemplar/data-model; + F1 write-graph tools)     [exists]
   ├── data-generator   (WRITE/READ: record CRUD, F1 CDT/DSE + coverage, F2 users/docs,
   │                      F3 to_record_csv, F4 get_record_footprint; session + rollback)           [exists, extend]
   └── bulk-loader      (BULK: lcp-mcp-server insertRecordData/list/update/delete)                 [NEW or fold into data-generator — D-A]
```

- **Role agent holds no MCP** (`includeMcpJson: false`), exactly like `developer`. It loads skills and delegates tool work to sub-agents via `subagent`.
- **Skill discipline preserved:** the step files remain **gated references** (tracker + "file must exist before next step") — that behavior moves intact into skill references (§3, §4).
- **Sub-agent-per-step → skill-driven orchestration.** Today `action-generate-data` spawns a generic sub-agent per step (each re-activates the power). In the agent model, the `sql-forge` agent runs the skill (loads references in order) and delegates the *tool calls inside each step* to `atlas-intel` / `data-generator`. The tracker/gate discipline is retained; only the "who holds the tools" boundary changes.

---

## 2. The `sql-forge` role agent

- **`agents/sql-forge.json`:** `name`, `description`, `prompt: file://./sql-forge-prompt.md`, `tools: [read, write, shell, subagent]`, `toolsSettings.subagent.availableAgents: [atlas-intel, data-generator, bulk-loader]` (+ `trustedAgents` for the read-only ones), `includeMcpJson: false`, `resources: [skill://../skills/sql-forge/**/SKILL.md, skill://../skills/shared/**/SKILL.md]`, `welcomeMessage`.
- **`agents/sql-forge-prompt.md`:** carries POWER.md's identity, the **Capabilities menu** (the skills), the **delegation protocol** (plan → single hand-off → read analysis doc), **anti-hallucination** (never invent record types/UUIDs/ref IDs; everything from a sub-agent result), environment resolution, and the architecture overview.

---

## 3. Skill decomposition (proposed — decision D-B)

User ask: *"different skills for single and bulk data generation and other such functionalities."* Proposed set under `.kiro/skills/sql-forge/`:

| Skill | Purpose | Volume/Mode |
|-------|---------|-------------|
| `single-data-generation` | Create ≤50 records in the live env, with verify + rollback | single; manual **or** exemplar mode (F4) |
| `bulk-data-generation` | High-volume load: CSV via `to_record_csv`→`insertRecordData` (primary) or SQL (fallback) | bulk; manual **or** exemplar mode (F4) |
| `exemplar-generation` | F4 Track B front-end: reference intake → footprint → clone/scale → payloads | feeds single or bulk |
| `schema-exploration` | Read-only schema/table/ref-data exploration | — |
| `query-validate` | Query & verify created records | — |
| `rollback` | Session cleanup / undo | — |
| `erd-generation` | ERD output (or reuse `documentation/generate-erd`) — D-C | — |
| `document-library` | F2 admin: maintain `ADG_Application`/`ADG_Document`, pick docs by description | config |

**Shared, referenced by multiple skills** (under `skills/sql-forge/references/` or `skills/shared/`): the whole gated pipeline (`step-0…step-6`), `step-4b-coverage-gate`, and the tool references — so single/bulk **don't duplicate** the analysis steps; they compose them. Manual-vs-exemplar mode selection (F4) lives in the generation skills.

> **D-B (decision):** volume-primary skills (`single`/`bulk`) that **share** the pipeline references, with F4 mode chosen inside — matches the user's framing and avoids duplicating steps 0–5. Alternative (mode-primary) rejected as it splits one request across skills.

---

## 4. LOSS-FREE MAPPING (the contract — every artifact has a home)

### Top-level power files
| Current | New home | Notes |
|---------|----------|-------|
| `POWER.md` | `agents/sql-forge-prompt.md` (identity, capabilities menu, delegation, anti-hallucination) + mode-detection → generation skills | Split by concern; nothing dropped |
| `mcp.json` (appian-atlas, appian-data-generator, lcp-mcp-server) | Sub-agent manifests (`atlas-intel`, `data-generator`, `bulk-loader`) via `includeMcpJson:true`; role agent `includeMcpJson:false` | lcp → D-A |
| `README.md` (26KB) | Agent repo `README.md` / `docs/` | Verbatim carry-over |
| `next-steps.md` | `docs/roadmap.md` or project-tracker | Carry-over |
| `.kiro/steering.md` (prod power metadata/architecture) | `sql-forge-prompt.md` architecture section + `skills/.../references/architecture.md` | Design decisions preserved |

### `steering/` action files
| Current | New home |
|---------|----------|
| `action-generate-data.md` (orchestrator, mode routing, sub-agent pipeline) | Split: orchestration+tracker → shared `references/pipeline-orchestration.md`; mode detection → `single`/`bulk` SKILL bodies; F4 mode select |
| `action-bulk-sql.md` | `bulk-data-generation` skill |
| `action-explore-schema.md` | `schema-exploration` skill |
| `action-query-and-validate.md` | `query-validate` skill |
| `action-rollback.md` | `rollback` skill |
| `action-erd.md` | `erd-generation` skill (or reuse `documentation/generate-erd` — D-C) |

### `steering/` step files (the gated pipeline — become shared references)
| Current | New home (shared references) | Used by |
|---------|------------------------------|---------|
| `step-0-initialize.md` | `references/step-0-initialize.md` | single, bulk, exemplar |
| `step-1-workflow-analysis.md` | `references/step-1-workflow-analysis.md` | manual mode |
| `step-2-exemplar-discovery.md` | `references/step-2-exemplar-discovery.md` | manual (cross-check) + basis for `exemplar-generation` |
| `step-3-data-architecture.md` | `references/step-3-data-architecture.md` | manual mode |
| `step-4-data-payloads.md` | `references/step-4-data-payloads.md` | manual mode |
| `step-4b-coverage-gate.md` (F1 hard block) | `references/step-4b-coverage-gate.md` | manual mode |
| `step-5-validation.md` | `references/step-5-validation.md` | both modes |
| `step-6-execute.md` | `references/step-6-execute.md` | `single-data-generation` (shared execution) |
| `step-6-bulk-csv.md` (F3) | `references/step-6-bulk-csv.md` | `bulk-data-generation` (primary) |
| `step-6-generate-sql.md` | `references/step-6-generate-sql.md` | `bulk-data-generation` (fallback) |

### `steering/` tool references → sub-agent capability docs
| Current | New home |
|---------|----------|
| `tool-reference-atlas.md` (incl. F1 `get_entry_point_write_graph`, `resolve_write_set`) | `atlas-intel` prompt + shared `references/tool-reference-atlas.md` |
| `tool-reference-data-generator.md` (incl. F1 CDT/DSE+coverage, F2 users/docs, F3 `to_record_csv`) | `data-generator` prompt + shared `references/tool-reference-data-generator.md` |
| `tool-reference-lcp.md` (F3 `insertRecordData` + CSV contract) | `bulk-loader` prompt + shared `references/tool-reference-lcp.md` |

### F1–F4 capabilities (tools stay in MCP servers / ADG app; knowledge moves to skills)
| Capability | New home |
|-----------|----------|
| F1 coverage gate + CDT/DSE mechanism | `step-4b` + `step-6-execute` references; tools on `atlas-intel`/`data-generator` |
| F2 group-aware users | `step-1`/`step-4` references + `list_users(groups)` on `data-generator` |
| F2 document library (RTs, DocumentLibrary interface/site live in the ADG app) | `document-library` skill + `list_documents`/`find_document` on `data-generator` |
| F3 bulk CSV | `bulk-data-generation` skill + `to_record_csv` (data-generator) + `insertRecordData` (bulk-loader) |
| F4 exemplar mode (`exemplar-step-1..4`, `get_record_footprint`) | `exemplar-generation` skill + `get_record_footprint` on `data-generator` |

**Verification of loss-free:** after migration, `grep`/diff every source file's headings and critical rules against the new references (§8 acceptance) — no orphaned content.

---

## 5. MCP / tool wiring (decision D-A)

Bulk CSV needs `lcp-mcp-server insertRecordData` (F3). Two options:
- **D-A(i):** add `@appian-lcp` to the existing `data-generator` sub-agent's tools (one write sub-agent for all data ops). Simpler; keeps one write tier.
- **D-A(ii):** new `bulk-loader` sub-agent holding only `@appian-lcp`. Cleaner separation; mirrors "one MCP per sub-agent."

**Recommendation:** D-A(i) — fold LCP into `data-generator` (it's already the data-write tier), unless the LCP plugin's availability varies per env enough to warrant isolation.

---

## 6. Where it lives (decision D-D)

- **D-D(i):** add `sql-forge` agent + `skills/sql-forge/**` **into `solutions-copilot`** — the `atlas-intel`/`data-generator` sub-agents it delegates to already live there; least wiring.
- **D-D(ii):** a dedicated repo mirroring the `.kiro/agents` + `.kiro/skills` layout.

**Recommendation:** D-D(i) (solutions-copilot) for reuse of the existing sub-agents; retire the standalone `atlas-sql-forge` power once parity is confirmed. Keep the `tester/test-data-generation` skill as a thin alias that points at the new `sql-forge` skills (so the tester role still works) — or have `tester` delegate to `sql-forge`.

---

## 7. Sequencing
1. **Scaffold** `agents/sql-forge.json` + `sql-forge-prompt.md` (from POWER.md), wire sub-agents (D-A).
2. **Port pipeline** step files → `skills/sql-forge/references/**` **verbatim first** (loss-free), then split action files into skill SKILL.md bodies.
3. **Fold F1–F4** knowledge into the right references (coverage gate, CDT/DSE, users/docs, bulk-csv, exemplar) — most already exist in the power; F4 exemplar refs are new.
4. **Reconcile** with the pre-existing `tester/test-data-generation` skill (bring up to F1–F4; alias or delegate — D-D).
5. **Parity check** (§8), then retire the power.

## 8. Acceptance criteria (loss-free gates)
- [ ] `sql-forge` role agent loads; capabilities menu lists all skills; delegates to `atlas-intel`/`data-generator`(/`bulk-loader`) with no MCP tools on the role agent.
- [ ] **Every §4 source artifact has a populated destination**; a heading/critical-rule diff shows **no dropped content** (coverage-gate hard block, CDT/DSE mechanism map, group-aware users, document library, bulk CSV contract, on-spot reconciliation, FK chaining, tracker/gate discipline all present).
- [ ] `single-data-generation` and `bulk-data-generation` skills each run end-to-end (manual + exemplar modes) reusing the shared pipeline references.
- [ ] `exemplar-generation` (F4), `schema-exploration`, `query-validate`, `rollback`, `erd-generation`, `document-library` skills present and functional.
- [ ] MCP wiring resolves (atlas/data-generator/lcp); an end-to-end single create + a bulk load succeed against a non-prod env.
- [ ] Old power archived/retired only **after** parity is signed off.

## 9. Risks & mitigations
| Risk | Mitigation |
|------|-----------|
| **Content loss** during split (the user's core concern) | Port step files **verbatim first**, split second; §4 mapping is a checklist; heading/critical-rule diff in acceptance |
| Losing the gate/tracker discipline when steps stop being sub-agent-spawned | Keep the tracker + "file exists before next step" rules inside the references; the role agent enforces them |
| Duplicating steps across single/bulk skills | Steps live once as **shared references**; skills compose them (D-B) |
| Divergence from the existing `tester/test-data-generation` skill | Reconcile in step 4: make `sql-forge` the source of truth; `tester` aliases/delegates (D-D) |
| lcp availability per env | D-A; step-0 env check already flags LCP-plugin absence → SQL fallback |
| Two prod copies drift (power vs agent) during transition | Freeze power edits once migration starts; single source of truth = agent |

## 10a. RESOLVED decisions (2026-07-01)

- **Location:** the agent lives in **this `atlas-sql-forge` repo** (not solutions-copilot); `sql-forge` is the **top-level agent**. solutions-copilot is only the reference pattern.
- **D-1 Delegation model → Option A:** `sql-forge` **holds MCP directly** (`includeMcpJson: true` with `appian-atlas` + `appian-data-generator` + `lcp-mcp-server`; tools: `read, write, shell, subagent`). No dedicated `atlas-intel`/`data-generator` MCP sub-agents — context isolation already comes from the **per-step task sub-agents** the workflow spawns (retained from `action-generate-data.md`). *Build-time check: confirm per-step sub-agents inherit the MCP servers.*
- **D-2 Skill decomposition → Scheme 1 (volume-primary):** `single-data-generation` and `bulk-data-generation` are the primary skills; **manual-vs-exemplar (F4) is a mode gate inside each**; pipeline lives once as shared references.
- **D-3 ERD → dedicated `erd-generation` skill** wrapping the `erd-gen` CLI (graceful check for binary + Lucid token).
- **D-4 Shared pipeline → shared `data-pipeline` skill** (`skills/sql-forge/data-pipeline/`) holding `step-0`, `step-1…5`, `step-4b`, `exemplar-E1…E4`, and tool references. `single`/`bulk` skills stay thin (mode gate + their own step-6). F4's exemplar collapses into this pipeline as the exemplar branch, not a separate skill.

**Final skill set:** `single-data-generation`, `bulk-data-generation`, `data-pipeline` (shared), `schema-exploration`, `query-validate`, `rollback`, `erd-generation`, `document-library`.

**Status:** 🔄 IN PROGRESS — agent scaffolded, pipeline ported (loss-free), and reviewed (2026-07-01). Remaining: F4 exemplar mode, README refresh, build-time sub-agent MCP-inheritance check, retire the old power after parity sign-off.

## Implementation status (2026-07-01)

| Item | Status | Evidence |
|------|--------|----------|
| Agent shell (`sql-forge.json` + `sql-forge-prompt.md` + `settings/mcp.json`) | ✅ Done | Option A wiring; JSON valid; tool refs ↔ server keys aligned |
| `data-pipeline` skill (SKILL.md + 15 verbatim references) | ✅ Done | `step-0…6`, `4b`, 3 tool-refs, `action-generate-data` copied via `cp` |
| `single-data-generation` + `bulk-data-generation` skills | ✅ Done | thin, mode-gated, compose shared pipeline; all cross-refs resolve |
| Supporting skills: `schema-exploration`, `query-validate`, `rollback`, `erd-generation`, `document-library` | ✅ Done | action files ported; document-library authored (F2) |
| Loss-free check | ✅ Verified | all 19 `steering/*.md` → exactly 1 copy in `.kiro/skills`; POWER.md at-risk content confirmed present |
| Transformation (power-isms → agent-native) | ✅ Verified | final sweep: zero residual `kiro_powers`/`powerName`/`steering file`/`the power`; sub-agent prompts read references by path + tool-access note |
| Build-time: per-step sub-agent MCP inheritance (Option A) | ⏳ Open | documented in orchestration note; verify when the agent runs |
| F4 exemplar mode authored into `data-pipeline` | ⏳ Next | per F5-then-F4 sequence |
| README refresh (power → agent) | ⏳ Pending | root README still describes the power |
| Retire old power (`POWER.md`, `steering/`, root `mcp.json`) | ⏳ Hold | keep until parity sign-off |

---

## 10b. Remaining open decisions
- **D-A** LCP wiring: fold into `data-generator` vs new `bulk-loader` sub-agent. *(lean: fold in)*
- **D-B** Skill split: volume-primary with shared pipeline refs. *(recommended)*
- **D-C** ERD: new `erd-generation` skill vs reuse `documentation/generate-erd`. *(lean: reuse)*
- **D-D** Location: extend `solutions-copilot` vs dedicated repo; and tester-skill reconciliation. *(lean: solutions-copilot + tester delegates)*
- Whether `sql-forge` is a top-level role agent or a sub-agent invoked by `tester`/`developer` (it can be both: a role agent that other roles delegate to).
