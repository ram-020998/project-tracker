# Atlas SQL Forge — V1 Progress Log

**What this is:** a running record of everything built and decided for Atlas SQL Forge V1, reflecting the
**current** state (post agent-migration, post bulk-expander, post single/bulk skill split). Companion to
`TRACKER.md` (onboarding overview) and the per-feature `implementation-plan-F1..F6` docs.

**Last updated:** 2026-07-02
**Ground rules:** incremental work; **nothing committed without explicit user permission** (the DG MCP
`expand_record_csv` tool was committed by the user; everything else below is local unless noted).

---

## 1. Current architecture snapshot (as of 2026-07-02)

**Form:** a Kiro **agent** (`sql-forge`) — migrated from the original Kiro power (F5).
**Location:** `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/atlas-sql-forge/.kiro/`

```
.kiro/
├── agents/  sql-forge.json  +  sql-forge-prompt.md      # Option A: agent holds MCP directly; per-step task sub-agents for isolation
├── settings/mcp.json                                     # appian-atlas + appian-data-generator + lcp-mcp-server
└── skills/
    ├── single-data-generation/   SKILL.md + references/  # ≤50 via create_record — OWNS its full pipeline copy (13 refs) incl. step-6-execute
    ├── bulk-data-generation/     SKILL.md + references/  # 100+ via CSV — OWNS its full pipeline copy (15 refs) incl. step-6-bulk-csv + step-6-generate-sql
    ├── tool-references/          references/             # SHARED MCP tool catalogs (Atlas / DG / LCP)
    ├── schema-exploration/  query-validate/  rollback/  erd-generation/  document-library/
```

**Key structural facts:**
- **No shared `data-pipeline` skill anymore** (deleted 2026-07-02 by user request). Single and bulk each
  carry their **own complete copy** of the gated pipeline references — no shared pipeline files between them.
- Each generation skill's `action-generate-data.md` is **trimmed to its type** (single → records/`step-6-execute`;
  bulk → `step-6-bulk-csv` + SQL fallback).
- `tool-references` remains shared (MCP tool catalogs) — the only shared skill the generation skills cite.
- Execution model **Option A** (verified working): the agent holds the 3 MCP servers directly; each pipeline
  step runs in its own **task sub-agent** for context isolation. Per-step sub-agents inherit the MCP servers
  (confirmed in a live bulk run).

**Gated pipeline (per skill):** Step 0 initialize → 1 workflow analysis → 2 exemplar discovery → 3 data
architecture → 4 payloads → 4b coverage gate (HARD BLOCK, manual mode) → 5 validation → 6 execute.
**Generation modes:** Manual Analysis (trace workflow) vs Exemplar-Based (clone a user-provided reference,
E1–E4). Mode is an explicit ask-first gate; exemplar always asks the user for the reference record.

---

## 2. Feature status

| Feature | Status | Summary |
|---------|--------|---------|
| **F1 — Data Integrity** | ✅ IMPLEMENTED (CDT rollback deferred) | Parser per-node `writes` (RECORD+CDT) → Atlas `resolve_write_set` → hard-block coverage gate; DG CDT/DSE + `verify_write_coverage`. |
| **F2 — Users & Documents** | ✅ IMPLEMENTED | Group-aware `list_users(groups)`; ADG document library (`ADG_Application`/`ADG_Document` + CRUD site) + `list_documents`/`find_document`. |
| **F3 — Bulk CSV** | ✅ IMPLEMENTED | `to_record_csv` + `step-6-bulk-csv` → lcp `insertRecordData`; SQL kept as fallback. |
| **F4 — Two Generation Modes** | ✅ IMPLEMENTED (steering-only) | Manual + Exemplar; exemplar uses `query_records` + FK graph (footprint tool deferred). |
| **F5 — Power → Agent Migration** | 🔄 IN PROGRESS | `sql-forge` agent + skills; loss-free port + transform; many test-driven fixes; Option A confirmed. Remaining: retire power, prod migration, README refresh. |
| **F6 — Streamlined Bulk (spec + expander + loader)** | ✅ BUILT (live test pending) | Compact per-table spec + deterministic `expand_record_csv` DG tool + loader sub-agent. |

Decision logs: D1–D13 (`spec.md`), D14–D18 (F4), D19–D22 (F6). F5 decisions in F5 plan §10a.

---

## 3. Agent test-driven fixes (from real `sql-forge` runs)

Found by running the agent and observing wrong behavior; all are prompt/steering fixes (local).

| # | Symptom | Fix |
|---|---------|-----|
| 1 | Used **Jarvis**/foreign tools | Tool-boundary HARD RULE: only the 3 MCP servers; stop-and-report on failure. Run AS the `sql-forge` agent. |
| 2 | Didn't offer **Manual vs Exemplar** | ASK-FIRST mandatory mode gate in single/bulk. |
| 3 | **Skipped the pipeline** (ad-hoc create) | Hard MANDATORY-pipeline enforcement (prompt + skills): Step 0 first, file gates, sub-agents, no create until validated. |
| 4 | Tool catalogs not loaded | Default-load `tool-references` at task start. |
| 5 | Exemplar **auto-searched** for a record | Force ASK-the-user for the reference at every level (skill + E1); forbid search; reworded "when to use." |
| 6 | Exemplar created **manual stub files** | Mode-aware Step 0 (Manual 7 files vs Exemplar 5); coverage-gate gate made Manual-only. |
| 7 | Folder in **home dir** | Step 0 + skill bodies: `data-requests/{YYYY-MM-DD}_{desc}/` **workspace-relative**, never `~`/abs/tmp. |
| 8 | Documents not from library in exemplar | E3 resolves Document fields from the library (`find_document`), not clone. |
| 9 | Bulk **hand-built CSV / bailed to SQL / tiny batches** | `to_record_csv` mandatory; SQL is fallback ONLY for missing plugin (never for volume/context); ~1000-row batches; don't cross-load `single` during bulk. Ultimately addressed structurally by **F6**. |

**Confirmed working in the latest bulk run:** agent identity, tool boundary (no Jarvis), ask-first mode gate,
exemplar ask-for-reference, mode-aware Step 0 (5 exemplar files), `to_record_csv` usage, **per-step
sub-agents inheriting MCP (Option A)**, no SQL bail-out.

---

## 4. F6 — Streamlined bulk generation (this session's build)

**Problem:** bulk execution forced the LLM to invent values, expand to scale, format CSV, and chain FKs all
at once, per table, in the main context → hallucination, ad-hoc `execute_bash` Python, context blowup.

**Solution — separate authoring from expand+write, make expansion deterministic:**

- **D19 compact spec artifact:** bulk payloads are `payloads/NN-<table>.spec.json` (template + `fk_binding`/
  `row_count` + generators), NOT thousands of raw rows.
- **D20 deterministic expander:** DG MCP tool **`expand_record_csv`** expands a spec (+ resolved parent PKs)
  into batched, contract-correct CSV (reuses `to_record_csv`'s formatter; chunks to ≤~1000 rows). The LLM
  never emits rows or hand-builds CSV.
- **D21 loader sub-agent:** the load loop runs in a sub-agent so the large CSV batches stay OUT of the
  orchestrator context; it returns only assigned-PK ranges + counts.
- **D22 FK chaining:** orchestrator holds a small PK map (`alias → [pks]`); primary parent via
  `fk_binding.parent_alias`, secondary FKs via `from_alias` tokens resolved at load time.

**Generator vocabulary:** `const`, `seq`, `cycle`, `pick`, `int`, `date`, `str` (`{i}/{p}/{c}`), `row_index`.

**Built & verified:**
- **DG MCP `expand_record_csv`** (`tools/csv_format.py`): `SpecError`, `_eval_generator`, `expand_rows`,
  `CsvTools.expand_record_csv`; registered in `models.py` + `server.py`. **`pytest` 77 passed; flake8 clean**
  (`--max-line-length=120 --ignore=E501,W503`). **Committed by the user** on branch `feature/f1-cdt-dse-tools`.
- **E3 (`exemplar-step-3-clone-scale-plan.md`)** now mode-aware: single → literal payloads; bulk → compact
  specs (cloning rules mapped to generators; secondary FKs via `from_alias`; scale via `children_per_parent`).
- **`step-6-bulk-csv.md`** rewritten to the spec-driven loader flow (PK map, `expand_record_csv` →
  `insertRecordData` per batch, loader sub-agent); literal-row path retained as `6c-legacy`.
- **`tool-reference-data-generator.md`** documents `expand_record_csv`.
- **`bulk-data-generation/SKILL.md`** Step 3 + hard rules point at the spec/expand loader flow.

**Remaining:** one live end-to-end bulk run to validate the full spec → expand → insert loop.

---

## 5. Single/bulk skill split (this session)

Per user decision (no shared pipeline files between the two skills):
- Copied the gated-pipeline references into **each** generation skill (same-depth copy → relative paths stay valid).
- **Single** owns: step-0…5, 4b, exemplar-step-1…4, action-generate-data, **step-6-execute** (13 files).
- **Bulk** owns: the same analysis/exemplar steps + **step-6-bulk-csv**, **step-6-generate-sql**, action-bulk-sql (15 files).
- Rewired SKILL.md pointers (`../data-pipeline/references/` → `references/`), `action-generate-data` hardcoded
  paths (→ owning skill), and trimmed each orchestrator to its type's Step 6.
- **Deleted the shared `data-pipeline` skill.** Updated the agent prompt (removed it from shared skills;
  orchestration now points at the active generation skill's own `action-generate-data.md`).
- **Verified:** all SKILL.md and action-generate-data references resolve; zero `data-pipeline` mentions remain
  in `.kiro`. `tool-references` remains the only shared skill.

**Trade-off accepted:** the ~9 identical analysis steps are now duplicated across single and bulk. A fix to a
shared step (e.g. step-4b, step-1) must be applied in **both** copies to avoid drift.

---

## 6. Repos, branches, key IDs

| Component | Local path | Branch / state |
|-----------|-----------|----------------|
| Agent (dev) | `repo-gitlab/ramaswamy.u/atlas-sql-forge` | agent `.kiro/`; legacy power files still present pending retirement |
| DG MCP | `repo-gitlab/ramaswamy.u/solutions-data-generator-mcp` | `feature/f1-cdt-dse-tools`; `expand_record_csv` committed; 77 tests pass |
| Atlas MCP | `repo-gitlab/appian/solutions-atlas-mcp-server` | `feature/f1-write-set-tools` (F1 tools) |
| Atlas parser | `repo-gitlab/appian/solutions-atlas-parser` | F1 per-node `writes` merged to dev/main |
| LCP MCP | `repo-gitlab/ramaswamy.u/solutions-lcp-mcp-server` | F3 `insertRecordData` |
| Prod power | `appian/solutions-os/.../.kiro/powers/atlas-sql-forge` | still power form (agent migration NOT applied to prod) |
| ADG app | Appian env | uuid `1df31c0a-6067-46b6-b39c-d8a3b60bb073`, prefix `ADG` |

---

## 7. Environment / config gotchas

- **DG MCP env must match the target app's env.** Runs 401'd against `merge-assist.appianpreview.com` while
  the target (SourceSelection/AS GSS) lives on `eng-test-fed-aq-dev2.appianpreview.com`. Set
  `APPIAN_ENV_URL`/`APPIAN_API_KEY` to where the app actually is.
- **Atlas KB app_name:** use the KB name (`SourceSelection`), not the Appian display name.
- **LCP plugin** required for bulk CSV; else SQL fallback (flagged in Step 0 env check).
- **Run AS the `sql-forge` agent** so only its 3 MCP servers are in scope (avoids Jarvis leakage).
- `insertRecordData` accepts up to **~1000 rows per call** — prefer large batches.

---

## 8. Open / pending items

- [ ] **F6 live end-to-end bulk run** (spec → `expand_record_csv` → `insertRecordData`, FK chaining, loader sub-agent).
- [ ] **F5:** retire legacy power files after parity; migrate prod to the agent; finish README refresh.
- [ ] Keep the duplicated analysis steps in sync across single/bulk (drift risk from the split).
- [ ] (Optional) duplicate `tool-references` into each generation skill if fully-self-contained skills are wanted.
- [ ] Other-repo commits/merges: Atlas MCP `feature/f1-write-set-tools`; KB re-parse rollout.
- [ ] Deferred: F1 CDT rollback; F4 `get_record_footprint`; F6 data-realism vocabulary (value pools/faker/seed-then-distribute); recipes.

---

## 9. Document index (`changes_V1/`)

- `spec.md` — V1 spec + D1–D13.
- `implementation-plan-F1-data-integrity.md` … `F5-agent-migration.md` — per-feature plans.
- `implementation-plan-F6-bulk-expander.md` — F6 (spec + expander + loader), A/B/C done.
- `TRACKER.md` — onboarding overview.
- `PROGRESS-LOG.md` — **this document** (running record of everything done + current state).
