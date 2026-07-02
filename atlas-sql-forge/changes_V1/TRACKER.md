# Atlas SQL Forge — V1 Project Tracker

**Purpose:** Single onboarding document. A fresh session should be able to read this and understand the
entire project: what Atlas SQL Forge is, everything built (F1–F5), current status, all key decisions,
every test-driven fix, learnings, open items, and all repo/path references.

**Last updated:** 2026-07-01
**Maintainer context:** Ramaswamy U + Kiro. Working style: incremental, validate against live env,
**never commit without explicit permission** (everything below is local unless noted).

---

## 1. What Atlas SQL Forge is

An AI system that generates **realistic, workflow-aware test/demo data** in Appian applications. It reads
an application's structure + workflow logic from the **Atlas KB** and writes data to a live Appian
environment via MCP servers, following a strict **gated pipeline** so the data is referentially correct
and covers every table a business state requires.

**Two output modes** × **two generation modes:**
- Output: **single** (≤50 records via API, verify + rollback) · **bulk** (100+ via CSV import → `insertRecordData`; SQL fallback).
- Generation: **Manual Analysis** (trace the workflow from scratch) · **Exemplar-Based** (clone-and-scale a user-provided reference record).

Originally a **Kiro "power"**; **migrated to a Kiro "agent" with skills** (F5, in progress).

---

## 2. Repositories & key paths (reference links)

| Component | Local path | GitLab / remote | Role |
|-----------|-----------|-----------------|------|
| **Agent (dev)** — was the dev power | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/atlas-sql-forge` | `ramaswamy.u/atlas-sql-forge` | The `sql-forge` agent + skills (F5). Also still holds legacy `POWER.md`, `steering/`, root `mcp.json`, `README.md`, `next-steps.md` (archival until power retired). |
| **Power (prod)** | `/Users/ramaswamy.u/repo-gitlab/appian/solutions-os/ai-framework/Engineering/.kiro/powers/atlas-sql-forge/` | `appian/solutions-os` | Production power (STILL in power form — F1–F3 steering live here; agent migration NOT yet applied to prod). |
| **DG MCP server** | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-data-generator-mcp` | `ramaswamy.u/solutions-atlas-dg-mcp-server` | Write/query MCP. Branch `feature/f1-cdt-dse-tools`. Image `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest`. Test venv `.venv-cdt`. |
| **Atlas MCP server** | `/Users/ramaswamy.u/repo-gitlab/appian/solutions-atlas-mcp-server` | `appian/solutions-atlas-mcp-server` | Read-only KB intelligence. F1 tools on branch `feature/f1-write-set-tools`. Image `.../appian/prod/solutions-atlas-mcp-server/...:latest`. |
| **Atlas parser** | `/Users/ramaswamy.u/repo-gitlab/appian/solutions-atlas-parser` | `appian/solutions-atlas-parser` | Parses Appian packages → KB. F1 per-node `writes` extraction (merged to `dev/main`). |
| **Atlas KB** | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-atlas-kb` | `ramaswamy.u/solutions-atlas-kb` | KB storage + CI sync. `data/<App>/current/{bundles,objects,code,schema}`. |
| **LCP MCP server** | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-lcp-mcp-server` | `ramaswamy.u/solutions-lcp-mcp-server` | F3 bulk `insertRecordData`. |
| **ADG Appian app** | (in Appian env, not git) | uuid `1df31c0a-6067-46b6-b39c-d8a3b60bb073`, prefix `ADG` | Web APIs + rules + F1 CDT API + F2 record types/interfaces. Env historically `merge-assist.appianpreview.com`. |
| **Project tracker / specs** | `/Users/ramaswamy.u/repo/project-tracker/atlas-sql-forge/` | — | `changes_V1/{spec.md, implementation-plan-F1..F5, TRACKER.md(this)}`, `architecture.md`, `tracker.md`, SAIL best-practices, DDL sample. |
| **Reference pattern (agents/skills)** | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/solutions-copilot/.kiro/{agents,skills}` | `ramaswamy.u/solutions-copilot` | The role-agent → sub-agent → skills pattern F5 mirrors. Has `atlas-intel`, `data-generator` sub-agents + a `tester/test-data-generation` skill (the old sql-forge workflow). |
| **Appian dev-mcp-skills** | — | `github.com/appian/dev-mcp-skills` | Appian's official skills for the Appian dev MCP (record types, SAIL, etc.). Substrate for "how to build Appian objects correctly". |

**Spec decision log:** `changes_V1/spec.md` §7 (D1–D13). F4 adds D14–D18 (in `implementation-plan-F4`).
F5 decisions in `implementation-plan-F5` §10a.

---

## 3. Feature status summary

| Feature | Status | One-line |
|---------|--------|----------|
| **F1 — Data Integrity** | ✅ IMPLEMENTED (CDT rollback deferred) | Deterministic table-coverage: parser per-node `writes` (RECORD+CDT) → Atlas `resolve_write_set` → hard-block coverage gate. |
| **F2 — Users & Documents** | ✅ IMPLEMENTED | Group-aware `list_users(groups)`; ADG document library (`ADG_Application`/`ADG_Document` + CRUD site) + `list_documents`/`find_document`. |
| **F3 — Bulk CSV** | ✅ IMPLEMENTED | `to_record_csv` formatter + `step-6-bulk-csv` (→ lcp `insertRecordData`); SQL kept as fallback. 71 DG tests pass. |
| **F4 — Two Generation Modes** | ✅ IMPLEMENTED (steering-only; footprint tool deferred) | Manual vs Exemplar front-ends; both emit `payloads/` → shared Step 6. Exemplar uses `query_records`+FK graph (no new tool). |
| **F5 — Power → Agent Migration** | 🔄 IN PROGRESS | `sql-forge` agent + skills scaffolded, pipeline ported loss-free + transformed + reviewed; F4 authored; many test-driven fixes. Remaining: retire power, prod migration, live end-to-end validation. |
| **Recipes (compiled/replayable)** | ⏸ DEFERRED | Considered (hash-validated `ADG_Recipe` store); shelved in favor of Exemplar mode (simpler, ~80% of the savings). |

---

## 4. Feature details

### F1 — Data Integrity (deterministic table coverage)
- **Problem:** the agent sometimes silently dropped required tables in payloads/execution (probabilistic steering). Fix = a **machine-checkable coverage contract**.
- **Parser (A):** per-node `writes` on `flow.process_model.nodes[]` (RECORD via `writeRecords`; CDT via `writeToDataStoreEntity[ies]`), `gateway_conditions`, distinct `WRITE_RECORDS`/`WRITE_DSE` node types; CDT→table via XSD `@Table` (+ column-set fallback). Merged to `dev/main`, synced to KB, 319 parser tests.
- **Atlas MCP (B):** `get_entry_point_write_graph(app, entry_point)`, `resolve_write_set(app, entry_points[], branch_decisions)` → FK-closed business/task-mgmt required-table set. Branch `feature/f1-write-set-tools`, 81 tests.
- **ADG app + DG MCP (C):** ADG rules `ADG_UT_getCdtProperties`, `ADG_UT_getConstantReferenceByName`, `ADG_UT_constructCdtValue`, `ADG_UT_writeDataStoreEntity`, `ADG_UT_queryDataStoreEntity` + Web API `ADG_API_cdtOperations` (urlAlias `cdt`, POST; body `{constantName, namespace, cdtName, fields}`). DG tools `write_data_store_entity`, `get_cdt_properties`, `query_data_store_entity`, `verify_write_coverage`; `_post` 4xx→AppianAPIError; CDT session tracking. All live-verified.
- **Steering (D):** `step-4b-coverage-gate.md` (HARD BLOCK via `resolve_write_set` vs payloads), step-1 records entry_points+branch_decisions, step-6 mechanism-aware dispatch + post-exec `verify_write_coverage`.
- **Deferred:** CDT rollback (`cdt/delete`); cross-module DSE constants lacking inline entity ref.

### F2 — Users & Documents
- **Users:** `ADG_UT_queryUsersByGroup(groupNames)` (nested/effective members, union) + `users` API group filter; DG `list_users(groups)`. Steering: step-1 traces action `VISIBILITY` rule → eligible group(s); step-4 picks initiator randomly across the union.
- **Documents:** record types `ADG_Application` (uuid `0d5788bb-9300-476c-b14f-829525d5c2c4`) + `ADG_Document` (uuid `c6e99789-ce3f-4e86-9459-bac933f6a8fb`), 1—* relationship, upload folder + `ADG_DOCUMENT_LIBRARY_FOLDER` constant. Modern CRUD interface `ADG_DocumentLibrary` + site `/adg-document-library` (writes via `a!writeRecords`, `a!fileUploadField`; no PMs). DG `list_documents(application)` / `find_document(application, query)`. Steering: step-3 (check library) + step-4 (resolve Document fields by description). All live-verified.

### F3 — Bulk CSV
- **DG `to_record_csv(record_type_uuid, rows, include_pk=false)`** in `tools/csv_format.py`: type-driven from `get_record_properties` — boolean→`1/0`, date `YYYY-MM-DD`, datetime `YYYY-MM-DD HH:MM:SS` (UTC), time `HH:MM:SS`, number bare, text RFC-4180; excludes PK/custom; rejects embedded JSON + unknown fields. Returns `{success, record_type_uuid, row_count, columns, csv, skipped_fields?}`. 15 DG tools total, 71 tests, flake8 clean.
- **Bulk flow:** payload → `to_record_csv` → lcp `insertRecordData(uuid, csv)` → capture assigned PKs → FK chain in insertion order. **No auto-rollback (D13)** — manual truncate.
- **SQL kept as fallback (D12)** for LCP-plugin-less envs.

### F4 — Two Generation Modes
- **Manual** = existing Steps 1–4b. **Exemplar** = E1 reference intake → E2 footprint discovery → E3 clone & scale → E4 light validation. Both emit identical `payloads/` → shared Step 6.
- **Exemplar decisions (D14–D18):** explicit mode choice w/ Manual fallback (D15); footprint = coverage, no write-set gate (D16); traverse the **full FK graph** not just declared relationships (D17); clone/remap + preserve reference-table FKs (D18).
- **`get_record_footprint` DG tool = DEFERRED/optional.** Exemplar E2 reuses `query_records` + Atlas FK graph (`get_schema_relationships`/`get_record_type_map`), same as Manual Step 2. Zero code for F4.

### F5 — Power → Agent Migration
- **Target:** `sql-forge` top-level **agent** in the `atlas-sql-forge` repo (solutions-copilot is only the reference pattern). See §5 for the structure and §6 for decisions.
- **Method:** ported step/tool-ref files **verbatim** (`cp`, loss-free), then transformed power-isms → agent-native. Reviewed (coverage + transformation + integrity all verified). F4 authored natively.

---

## 5. The agent structure (`atlas-sql-forge/.kiro/`)

```
.kiro/
├── agents/
│   ├── sql-forge.json          # manifest: includeMcpJson:true; tools read/write/shell/subagent + @appian-atlas/@appian-data-generator/@lcp-mcp-server; allowedTools pre-approves read family
│   └── sql-forge-prompt.md      # identity, capabilities menu, 12 CRITICAL RULES, tool-boundary rule, MANDATORY gated-pipeline orchestration, anti-hallucination
├── settings/
│   └── mcp.json                 # appian-atlas + appian-data-generator + lcp-mcp-server
└── skills/
    ├── data-pipeline/           # SHARED gated pipeline (SKILL.md + references/)
    │   └── references/          # step-0..6, step-4b, exemplar-step-1..4, action-generate-data
    ├── tool-references/         # SEPARATE skill: tool-reference-{atlas,data-generator,lcp}.md (load by default)
    ├── single-data-generation/  # ≤50 via API; mode gate (Manual/Exemplar); hard pipeline enforcement
    ├── bulk-data-generation/    # 100+ via CSV/SQL; mode gate; hard pipeline enforcement
    ├── schema-exploration/      # read-only schema (action-explore-schema)
    ├── query-validate/          # query + verify (action-query-and-validate)
    ├── rollback/                # session undo (action-rollback)
    ├── erd-generation/          # ERD via erd-gen CLI (action-erd)
    └── document-library/        # F2 admin/use of the ADG document library
```

**Execution model (Option A):** the agent holds MCP directly; context isolation comes from **per-step
task sub-agents** (the orchestrator spawns a fresh sub-agent per Step 1–5/4b), retained from
`action-generate-data.md`. Step 0 and Step 6 run in the orchestrator directly.

**Gated pipeline (Manual):** Step 0 initialize → 1 workflow analysis → 2 exemplar discovery → 3 data
architecture → 4 payloads → 4b coverage gate (HARD BLOCK) → 5 validation → 6 execute/bulk/SQL. Files are
gates; each step writes its file before the next starts.

**Exemplar file set (5, not 7):** `reference.md`, `footprint.md`, `payloads/00-metadata.json`,
`validation-report.md`, `execution-log.md` (NO analysis/exemplar/data-architecture/coverage-gate).

---

## 6. F5 resolved decisions

- **Location:** agent lives in the `atlas-sql-forge` repo; `sql-forge` is the top-level agent.
- **D-1 Delegation → Option A:** agent holds MCP directly (no dedicated atlas-intel/data-generator sub-agents); per-step task sub-agents give isolation.
- **D-2 Skills → Scheme 1 (volume-primary):** `single-`/`bulk-data-generation` are primary; Manual/Exemplar is a mode gate inside each; pipeline shared.
- **D-3 ERD → dedicated `erd-generation` skill** (wraps `erd-gen` CLI).
- **D-4 Shared pipeline → `data-pipeline` skill**; **tool refs later split into their own `tool-references` skill** (user request).

---

## 7. Test-driven fixes (agent runs, 2026-07-01)

Each was found by running the agent and observing wrong behavior; all are steering/prompt fixes (local).

| # | Symptom observed | Root cause | Fix |
|---|------------------|-----------|-----|
| 1 | Agent used **Jarvis** tools | Ran as default agent + skills (Jarvis in scope); own tools failed → improvised | **Tool-boundary HARD RULE** in prompt: only the 3 MCP servers; **stop-and-report** on failure, never substitute. Also: run AS the `sql-forge` agent. |
| 2 | Didn't offer **Manual vs Exemplar** options | Skill said "Ask (or infer, then confirm)" → agent inferred | **ASK-FIRST mandatory mode gate** in single/bulk (present both, wait for choice). |
| 3 | **Skipped the data-pipeline** (ad-hoc gather→create) | Migration demoted the "master workflow" mandate to a skimmed reference | **Hard MANDATORY-pipeline enforcement** in prompt + both skills: Step 0 first, file gates, sub-agents, **no create until validation ✅** (+ coverage-gate ✅ in Manual), shortcut forbidden. |
| 4 | Tool catalogs not loaded | No default-load instruction | Prompt now: **load `tool-references` by default** at task start. |
| 5 | Exemplar mode **auto-searched** for a record | "or a record exists in target status" phrasing + narration before loading E1 | Force **ASK the user for the reference** at every level (single/bulk skill, data-pipeline, E1); forbid search; reworded "when to use". |
| 6 | Exemplar run created **manual stub files** | `step-0` was mode-unaware (always 7 manual files) | **Mode-aware `step-0`**: Manual=7 files, Exemplar=5; added exemplar templates + tracker. Also made the "no-create-until coverage-gate ✅" gate **Manual-only** (Exemplar gates on validation-report ✅). |
| 7 | Folder created in **home dir** (`~/data/adg-requests`) | `step-0` said only "current working directory" | `step-0`: create `data-requests/{date}_{desc}/` as a **workspace-relative path**; ⛔ home/tmp/absolute. |
| 8 | Exemplar not using **document library** | Library resolution was only in Manual step-3/step-4; E3 cloned `documentId` verbatim | **E3 special-cases Document fields** → resolve from library via `find_document`/`list_documents`, not clone. |

**Confirmed working after fixes:** tool-boundary (no Jarvis on a proper run); Atlas KB resolves `SourceSelection` schema; mode-aware step-0 created only the 5 exemplar files; ask-for-reference (agent used the user's evaluation number).

---

## 8. Learnings

1. **Migration diluted enforcement.** In the power, `action-generate-data.md` was the *executed* master workflow carrying hard mandates. As a skill *reference* it got skimmed. **Fix pattern:** hoist hard rules into the **prompt (always in context)** and the **entry skills**, not buried references.
2. **Skills guide, manifests restrict.** Skills don't scope tools; only the agent manifest does. Running skills inside another agent (default/Jarvis-equipped) leaks foreign tools. **Must run AS the `sql-forge` agent.**
3. **Verbatim port ≠ done.** `cp` preserved content (loss-free), but power-isms ("steering file", "the power", auto-search phrasing) and **mode-unaware** files (step-0) needed transformation/adaptation.
4. **Mode consistency is cross-cutting.** Exemplar mode differs in file set, gates (no coverage-gate — footprint is coverage), and document handling. Any rule referencing coverage-gate/analysis/etc. must branch by mode or it becomes unsatisfiable in Exemplar.
5. **`get_record_footprint` unnecessary.** `query_records` + the Atlas FK graph already do footprint traversal (Manual Step 2 proves it). Simpler > new tool.
6. **Recipes deferred.** Exemplar mode delivers most of the token savings with far less work; a saved clone plan is a natural recipe precursor if revisited.
7. **Environment/config is a common failure source** (see §9) — surface it, don't work around it.
8. **Efficiency insight (origin of F4/F5):** a single "create one eval in a status" ran ~45 min / heavy tokens, almost all in Steps 1–5 analysis; the writes were a few calls. Per-step sub-agents + Exemplar mode target this.

---

## 9. Environment / config gotchas

- **DG MCP env must match the target app's env.** Runs hit `merge-assist.appianpreview.com` with **401**, but the target app (AS GSS / SourceSelection) lives on `eng-test-fed-aq-dev2.appianpreview.com`. Set `APPIAN_ENV_URL`/`APPIAN_API_KEY` to the env where the app actually is.
- **Atlas KB app_name matters.** `get_record_type_map("SourceSelection")` works; `"AS GSS Full Application"` → "not available". Use the KB application name (from `list_applications`), not the Appian display name.
- **LCP plugin required for bulk CSV.** If absent → SQL fallback (step-0 env check flags it).
- **Run context:** launch AS the `sql-forge` agent so only its 3 MCP servers are in scope (avoids Jarvis/etc.).

---

## 10. Open / pending items

**F5 (to finish the migration):**
- [ ] **Build-time:** verify per-step task sub-agents inherit the MCP servers under Option A (the one unverified mechanic).
- [ ] **Live end-to-end validation:** run Manual + Exemplar × single + bulk against a correctly-configured env; confirm gated files, coverage gate, child rows, and execution.
- [ ] **Retire the legacy power** in the dev repo (`POWER.md`, `steering/`, root `mcp.json`) after parity sign-off.
- [ ] **Migrate prod** (`solutions-os/.../powers/atlas-sql-forge`) to the agent form (currently still a power; F1–F3 steering only).
- [ ] Finish README refresh (mostly done; some cosmetic "Records/SQL Mode" labels remain).
- [ ] Cosmetic: agent created an extra `execution-tracker.md` + used a timestamp folder name once — naming rule reinforced; watch on re-run.

**Other repos (owned by user — commits/merges pending):**
- [ ] DG MCP branch `feature/f1-cdt-dse-tools` — commit/push/merge; deploy image.
- [ ] Atlas MCP branch `feature/f1-write-set-tools` — merge; deploy image.
- [ ] KB re-parse rollout so `writes`/`gateway_conditions` exist for target apps before the coverage gate uses them.
- [ ] Delete DG MCP scratch `_test_api.py` if any remains (held a live key; must not be committed).

**Deferred (future):**
- [ ] F1 CDT rollback (`cdt/delete` + `delete_data_store_entity`).
- [ ] F4 `get_record_footprint` optimization tool (only if agent-driven traversal proves too heavy).
- [ ] Recipes (compiled/replayable `ADG_Recipe` store, hash-based validity).

---

## 11. Plan documents (in this folder)

- `spec.md` — V1 spec + decision log D1–D13 (authoritative design).
- `implementation-plan-F1-data-integrity.md` — ✅ IMPLEMENTED.
- `implementation-plan-F2-users-documents.md` — ✅ IMPLEMENTED.
- `implementation-plan-F3-bulk-csv.md` — ✅ IMPLEMENTED.
- `implementation-plan-F4-generation-modes.md` — ✅ IMPLEMENTED (steering-only; footprint tool deferred); D14–D18.
- `implementation-plan-F5-agent-migration.md` — 🔄 IN PROGRESS; loss-free mapping table + F5 decisions + status.
- `../architecture.md` — the original four-layer architecture doc.
- `../tracker.md` — earlier phase tracker (Phases 1–5, schema layer, APIs, DG MCP, ERD).
- `TRACKER.md` — **this document** (the current onboarding source of truth).

---

## 12. Quick start for a new session

1. Read this file, then `spec.md` (decisions) and the `implementation-plan-F5` (current work).
2. The agent lives at `atlas-sql-forge/.kiro/` — start from `agents/sql-forge-prompt.md` and `skills/data-pipeline/SKILL.md`.
3. To test: launch **as the `sql-forge` agent** with `APPIAN_ENV_URL`/`APPIAN_API_KEY` pointing at the env where the target app lives, `GITLAB_TOKEN` for Atlas KB. Try: *"single-data-generation — create an evaluation in In Progress status in SourceSelection"* and expect it to (a) ask Manual vs Exemplar, (b) run Step 0 into `./data-requests/…`, (c) gate through the pipeline, (d) not create until validated.
4. **Do not commit anything without the user's explicit permission.**
