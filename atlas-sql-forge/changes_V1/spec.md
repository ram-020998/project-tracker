# Atlas SQL Forge — Changes V1 Specification

**Status:** DRAFT — for discussion
**Author:** (Ramaswamy U + Kiro)
**Created:** 2026-06-22
**Scope:** Three enhancement areas — Data Integrity, User & Document Configuration, Bulk Data Generation

---

## Reference Repositories

All paths are local clones under `/Users/ramaswamy.u/`. GitLab host: `gitlab.appian-stratus.com`.

| Repo | Local path | GitLab project | Role in this change set |
|------|-----------|----------------|-------------------------|
| **solutions-atlas-parser** | `repo-gitlab/appian/solutions-atlas-parser` | `appian/solutions-atlas-parser` | Parses Appian packages → KB. **F1:** add per-node `writes` (record + CDT/DSE), gateway branch conditions, CDT→table resolution. Key files: `parsers/process_model_parser.py`, `parsers/data_store_parser.py`, `parsers/cdt_parser.py` (CDT), `output/bundle_builder.py`, `schema/` modules. |
| **solutions-atlas-mcp-server** | `repo-gitlab/appian/solutions-atlas-mcp-server` | `appian/solutions-atlas-mcp-server` | Read-only MCP over the KB (30+ tools). **F1:** add `get_entry_point_write_graph`, `resolve_write_set`. Key files: `atlas_mcp/server.py`, `atlas_mcp/tools/*`, `atlas_mcp/models.py`. |
| **solutions-atlas-dg-mcp-server** (DG MCP) | `repo-gitlab/ramaswamy.u/solutions-data-generator-mcp` | `ramaswamy.u/solutions-atlas-dg-mcp-server` | Write-capable MCP (8 tools). **F1:** coverage-verify tool, `write_data_store_entity`. **F2:** `list_users(group)`, `list_documents`/`find_document`. **F3:** `to_record_csv` formatter. Docker: `registry.gitlab.appian-stratus.com/ramaswamy.u/solutions-atlas-dg-mcp-server:latest`. |
| **solutions-atlas-kb** | `repo-gitlab/ramaswamy.u/solutions-atlas-kb` | `ramaswamy.u/solutions-atlas-kb` | KB storage + CI sync. Holds `data/<App>/current/{bundles,objects,code,schema}`. **F1:** enriched bundles flow through here after a re-parse. |
| **solutions-lcp-mcp-server** | `repo-gitlab/ramaswamy.u/solutions-lcp-mcp-server` | `ramaswamy.u/solutions-lcp-mcp-server` | **F3:** provides `insertRecordData` (used directly by the agent). Key file: `src/lcp_mcp_server/tools/record_data.py`. Hits the LCP API **plugin** in the target Appian env. |
| **atlas-sql-forge** (power — prod) | `appian/solutions-os/ai-framework/Engineering/.kiro/powers/atlas-sql-forge/` | `appian/solutions-os` | Production Kiro power: `POWER.md`, `mcp.json`, `steering/`. All steering changes (coverage gate, user/doc/bulk steps) land here. |
| **atlas-sql-forge** (power — dev) | `repo-gitlab/ramaswamy.u/atlas-sql-forge` | `ramaswamy.u/atlas-sql-forge` | Dev copy of the power (same `steering/` layout as prod). |
| **ADG Appian application** | (Appian env, not a git repo) | uuid `1df31c0a-6067-46b6-b39c-d8a3b60bb073`, prefix `ADG`, env `merge-assist.appianpreview.com` | **F1:** DSE write API. **F2:** group-filtered user API, `ADG_Application`/`ADG_Document` RTs + CRUD interfaces. Edited via lcp-mcp-server design tools. |
| **erd-gen** | `repo-gitlab/ramaswamy.u/erd-gen` | `ramaswamy.u/erd-gen` | ERD generation CLI (not in scope for V1; listed for completeness). |
| **project-tracker** (this spec) | `repo/project-tracker/atlas-sql-forge` | — | Tracker + `changes_V1/spec.md` (this file), `architecture.md`, SAIL best-practices, DDL sample. |

---

## 0. Purpose

Atlas SQL Forge generates realistic, workflow-aware demo/test data in Appian
applications. It is driven today by:

- **Atlas MCP server** (read-only) — application/workflow/schema intelligence from the parsed KB
- **Data Generator (ADG) MCP server** (write) — CRUD against Appian via the `ADG` application's Web APIs
- A **6-step steering workflow** (Kiro power) that analyzes the business workflow, discovers exemplars, designs a data architecture, builds payloads, validates, and executes.

This spec captures three enhancements requested for the **V1 change set**. It is
deliberately written at the "what + why + candidate approaches" level so we can
agree on direction before producing a detailed implementation plan.

The three areas:

1. **Data Integrity** — guarantee that *every* business table required to bring a
   record to the desired state is actually populated (no silent omissions).
2. **User & Document Configuration** — populate user fields with *group-appropriate*
   users, and populate document fields from a *curated, queryable* document library.
3. **Bulk Data Generation** — adopt the `insertRecordData` CSV-import tool from
   `solutions-lcp-mcp-server` as the **primary** bulk path, keeping SQL generation as a fallback.

---

## 1. Current State (baseline)

### 1.1 ADG Appian application (`prefix: ADG`, uuid `1df31c0a-6067-46b6-b39c-d8a3b60bb073`)

**Web APIs**
| API | urlAlias | Method | Purpose |
|-----|----------|--------|---------|
| `ADG_API_recordOperations` | `record` | POST | Router for record CRUD (`record/{method}`) |
| `ADG_API_users` | `users` | POST | User lookup (`users/list`) — returns **all** usernames, unfiltered |

**Expression rules (11):** `ADG_UT_getRecordTypeProperties`, `ADG_UT_queryRecordTypeWithFilters`,
`ADG_UT_createOrUpdateRecords`, `ADG_UT_buildRelatedRecords`, `ADG_UT_applyRelatedRecords`,
`ADG_UT_convertFieldValue`, `ADG_UT_returnFieldReferenceFromFieldName`,
`ADG_UT_returnRecordReferenceFromUuid`, `ADG_UT_initialiseEmptyRecordForGivenUuid`,
`ADG_UT_queryUsersFromEnvironment`, `ADG_UT_getCdtProperties` (returns CDT field properties — the CDT analogue of `ADG_UT_getRecordTypeProperties`).

No record types, interfaces, process models, or constants of its own — ADG operates on
*other* applications' record types by UUID.

### 1.2 Atlas KB schema artifacts (per application, under `current/schema/`)

`tables.json`, `relationships.json`, `reference_data.json`, `insertion_order.json`,
`table_classification.json`, `summary.json`, `record_type_map.json`, `field_map.json`.

Process models are parsed into bundles with nodes/flows/variables. **Note:** there is currently **no** structured write-target (`writes_to`) metadata in the KB — write targets only appear as raw `a!writeRecords` / write-smart-service config that the agent must read and interpret per node. (See §2.6; this is the root-cause that Feature 1 addresses.)

### 1.3 DG MCP tools (8)

`get_record_properties`, `create_record`, `update_record`, `delete_record`, `query_records`,
`list_users`, `get_session`, `rollback_session`.

### 1.4 Bulk SQL today

`step-6-generate-sql.md` emits INSERT statements with `LAST_INSERT_ID()` chaining — a separate
code path from the records/API mode.

---

## 2. Feature 1 — Data Integrity (Deterministic Table Coverage)

### 2.1 Problem statement

The strict 6-step workflow correctly *identifies* all business tables involved in reaching a
target state during the **analysis** phase (M1–M3). However, in the **downstream** phases
(M4 payloads / M6 execution) the agent sometimes **drops** tables it had previously identified,
rationalizing that "this table is not required." The result is an incomplete data footprint —
a record that looks valid in one table but is missing rows in dependent tables, breaking the
UI or downstream processes.

This is a **reliability** problem: steering (natural-language instruction) has been maxed out,
and natural-language guidance is inherently probabilistic. We need a **deterministic mechanism**
that the agent cannot rationalize away.

### 2.2 Root-cause analysis

| Cause | Explanation |
|-------|-------------|
| Steering is advisory | The agent can re-interpret "populate all tables" with its own judgment. |
| No machine-checkable contract | There is no artifact that enumerates the *exact* required write-set, so "done" is subjective. |
| Analysis ↔ execution gap | The list of tables lives in prose docs (`analysis.md`, `data-architecture.md`), not in a structured, validated object that the execution step is forced to reconcile against. |
| No closure over FK/workflow dependencies | "Required tables" is computed by reasoning, not by a deterministic graph traversal that is hard to skip. |

### 2.3 Design principle

> Move table-coverage from **probabilistic steering** to a **deterministic, machine-checkable
> contract** that is (a) produced by the parser/KB, and (b) enforced by a validation gate the
> agent must pass before declaring success.

### 2.4 Initial proposal (SUPERSEDED — see resolved decisions D1, D4, D5, D6)

> **NOTE:** The sketch below was the *initial* framing (a separate status-keyed `write_sets.json` and gate options A/B/C). It is **superseded** by the resolved decisions: the write-set is attached **per node in the existing bundles** (D1), with the shape in D4/D6, and the gate mechanism in D5. Kept for context/history only. Skip to §2.6+ for the authoritative design.

Two complementary additions:

#### 2.4.1 KB enhancement: per-entry-point **Write-Set Manifest** (parser → Atlas KB)

Add a new parsed artifact that, for each workflow entry point (action / process), enumerates the
**complete, transitively-closed set of tables written** to reach each reachable status, with the
*reason* each table is in the set. This converts "agent reasons about which tables matter" into
"agent reads a deterministic list."

Proposed shape (`current/schema/write_sets.json` or per-bundle `write_set` block):

```json
{
  "entry_point": "AS_GSS_Award_Vendor",
  "target_status": "AWARDED",
  "required_tables": [
    {
      "table": "AS_GSS_REQUEST",
      "write_type": "UPDATE",
      "reason": "status set to AWARDED by AS_GSS_Award_Vendor node 'Update Request'",
      "source": { "object": "AS_GSS_Award_Vendor", "node": "Update Request" },
      "fields_written": ["STATUS", "AWARD_DATE"],
      "mandatory": true
    },
    {
      "table": "AS_GSS_AWARD_DECISION",
      "write_type": "INSERT",
      "reason": "created by AS_GSS_Award_Vendor node 'Write Award Decision'",
      "fields_written": ["AWARD_DECISION_ID", "REQUEST_ID", "VENDOR_ID"],
      "mandatory": true
    }
  ],
  "prerequisite_states": ["DRAFT", "SUBMITTED", "IN_EVALUATION", "EVALUATION_COMPLETE"],
  "fk_closure_tables": ["AS_GSS_VENDOR_RESPONSE", "AS_GSS_EVALUATION", "AS_GSS_EVALUATION_PHASE"]
}
```

How it is computed (parser side):
- Walk the workflow path backwards from the target status (using the existing process/action
  bundle graph + `writes_to` metadata) to collect every PM/expression-rule node that writes data.
- Union with the **FK closure** from `relationships.json` + `insertion_order.json` so that any
  table required as a foreign-key prerequisite is included even if no node writes it directly.
- Tag each table with `mandatory: true/false` and a human-readable `reason` + `source`.

This gives the agent a **ground-truth checklist** derived deterministically from the app's code +
schema, not from its own reasoning.

#### 2.4.2 Workflow enhancement: **coverage reconciliation gate** (steering + tooling)

A blocking gate between payload-build (M4) and execution (M6), and again after execution:

- **Pre-execution:** the agent must produce a coverage map: every table in the manifest's
  `required_tables` (where `mandatory: true`) must map to either (a) a payload entry, or
  (b) an explicit, recorded justification for exclusion that references the manifest reason.
  Missing mandatory tables → **hard fail**, cannot proceed.
- **Post-execution:** query the created footprint and assert that every mandatory table has at
  least the expected row(s). Diff against the manifest; any gap is reported and must be remediated.

To make the gate deterministic (not just more steering), the comparison should be done by a
**tool/script**, not by free-form agent judgment. Options for *where* the check runs:

- **(A) DG MCP tool** — e.g. `verify_write_set_coverage(entry_point, target_status, created_footprint)`
  that loads the manifest from the KB and returns a structured pass/fail + missing-table list.
- **(B) Atlas MCP tool** — `get_write_set(entry_point, target_status)` to fetch the manifest, with
  the coverage diff computed by a small DG-side validator.
- **(C) Power-local script** — a deterministic Python check shipped in the power's steering folder.

> Recommendation to discuss: **A + B** — Atlas MCP exposes the manifest (read intelligence), DG MCP
> runs the coverage verification against the live footprint (write/verify intelligence). This keeps
> read/write responsibilities aligned with the existing two-server split.

### 2.5 Alternatives considered

- **More steering / stronger prompts** — rejected; user reports this is maxed out.
- **Record footprint exemplar diffing only** — useful but insufficient when no exemplar exists for
  the target status (empty env / new status). The manifest is derived from code, so it works even
  with zero existing data.

### 2.6 Grounded findings (from inspecting solutions-atlas-kb / SourceSelection)

- Bundles are **already one-per-entry-point** (e.g. `current/bundles/AS_GSS_Generate_Evaluation_Tasks.json`). Each bundle carries `flow.process_model.nodes[]` with `name`, `type` (START_EVENT, SCRIPT_TASK, XOR_GATEWAY, "Start Process", END_EVENT…), and `next` (flow edges). This is what the agent already queries to understand workflow + data flow.
- `current/schema/record_type_map.json` maps table → `record_type_uuid` + `record_type_name` + **relationships** (FK graph as relationshipName → target record type). Solid foundation.
- `summary.json`: 106 tables (37 business / 39 audit / 18 reference / 10 task-management / 2 framework), 174 FKs. `insertion_order.json`: topological table order.
- **CRITICAL:** there is **no structured write-target metadata** in the KB. Grep across all of `current/` for `writes_to` / `write_targets` / `targetRecordType` returned zero matches. The tracker's claim that the parser extracts `writes_to` is **inaccurate**. The only trace of writes is `a!writeRecords` appearing **inside SAIL `code/*.json` files**, which the agent must read and interpret per node. **That manual interpretation step is the root cause of dropped tables** — it is probabilistic reading of raw SAIL, with no structured contract.

### 2.7 Resolved decision D1 (Q1 — granularity)

- **D1 (Q1 — granularity): RESOLVED.** The write-set is attached **per node within the existing per-entry-point bundle structure**, mirroring `flow.process_model.nodes[]`. The parser extracts each node's write targets (from `a!writeRecords` / write smart-service config in that node's code) into a structured `writes` array on the node. A (target_status) view is a **derived composition** over the nodes along a workflow path — NOT a separate status-keyed file. Rationale: maps 1:1 onto the structure the agent already queries; same status can be reached by different actions writing different tables, so entry_point is the stable anchor; avoids storage explosion.

### 2.8 Resolved decision D2 (Q2 — conditional writes)

**RESOLVED.** Conditionality lives at the **node / gateway-branch level**, not as a flag on individual writes:
- Each node's `writes` entries stay simple (record type, table, write type, fields). A write is unconditional *relative to its node executing*.
- Gateway nodes capture their **branch conditions** per outgoing edge (today the bundle only has `next` labels like `(Y)`/`(N)`; the parser must additionally capture the condition expression where available). A node is flagged conditional when only reachable via a gateway branch.
- The coverage gate operates on a **resolved path**: branch decisions for the target scenario select which nodes execute → exact required write-set. Tables on unselected branches are excluded deterministically (exclusion tied to a recorded branch decision, not free judgment).
- **Parser impact:** in addition to per-node `writes`, capture gateway branch conditions on flow edges.

### 2.9 Resolved decision D3 (Q3 — reference vs business tables)

**RESOLVED.** Reference tables are **not** a failure mode — the agent already handles them correctly today (it never inserts into reference tables; it resolves existing reference IDs from live `query_records` on the ref table). Therefore:
- The write-set manifest and coverage gate focus **only on the business (and task-management) tables that workflow nodes actually write** via `a!writeRecords` / write smart services. These are the tables that get silently dropped today.
- FK-closure is used to ensure **parent business tables** in the write path aren't missed; reference-table FK targets need only a valid existing value (already handled).
- The gate hard-fails only on **missing writes to business/task-management tables that the resolved workflow path performs**.

### 2.10 Resolved decision D4 (Q4 — per-node `writes` entry shape)

**Grounded finding:** In this app, data writes are mostly **not** `a!writeRecords` in expression-rule SAIL — a grep across all 1,753 `code/*.json` matched only one file (`AS_GSS_FM_completeEvaluation`, using `#"SYSTEM_SYSRULES_writeRecords_v2"`). The majority of business writes happen in **process-model "Write Records" smart-service nodes**, whose config lives in the process model object (not the interface/expression `code/*.json`). So the parser enhancement must extract write targets from (a) PM write-smart-service node config and (b) `SYSTEM_SYSRULES_writeRecords_v2` / `a!writeRecords` calls in SAIL. Reliable signal = the **record type reference** passed to the write.

**RESOLVED shape** (table granularity):
```json
"writes": [
  {
    "record_type_uuid": "ddf6d201-...",
    "record_type_name": "AS_GSS_AI_EvaluationValidationResult_SYNCEDRECORD",
    "table": "AS_GSS_AI_EVAL_VLDN_RESULT",
    "operation": "WRITE",        // WRITE (upsert) | INSERT | UPDATE — best-effort, default WRITE
    "via": "SYSTEM_SYSRULES_writeRecords_v2"  // or PM node / smart-service name
  }
]
```
- **Table/record-type granularity, NOT field-level.** Failure mode is whole tables dropped, not missing fields; field-level write extraction is unreliable. Field completeness stays with the existing M4 `get_record_properties` ≥80% check.
- **`operation` is best-effort `WRITE`** (Appian writeRecords is an upsert; INSERT vs UPDATE often not statically determinable). The gate keys on record-type/table presence, not operation.

### 2.11 Resolved decision D5 (Q5 — coverage gate mechanism)

**RESOLVED.** Coverage is tool-computed and deterministic, never agent judgment.

**Parser → KB:** per-node `writes` + gateway branch conditions on edges.

**Atlas MCP (read / KB intelligence) — two new tools:**
- `get_entry_point_write_graph(entry_point)` → nodes, their `writes`, edges with branch conditions (lets the agent see the data flow).
- `resolve_write_set(entry_points[], branch_decisions)` → **deterministic, FK-closed set of business/task-management tables** required for that path. Pure KB computation: compose per-node writes along selected branches + FK closure via `relationships.json`, filter to business/task-mgmt via `table_classification`. Reasoning-free, so it cannot drop a table.
- The agent's only reasoning step: map target business state → entry points + branch decisions. That choice is explicit and recorded; the required-table set is then computed by the tool.

**DG MCP (write/verify):** post-execution footprint diff against the required set.

**Two-phase gate, both tool-computed:**
- **Pre-execution:** diff `resolve_write_set(...)` vs the table set in `payloads.json`. Any required business/task-mgmt table missing from payloads → **HARD BLOCK**. The agent must investigate *why* the table was missed and resolve it before proceeding to the next step. The only way past is an explicit recorded exclusion that cites a specific branch decision.
- **Post-execution:** DG MCP queries the created footprint and diffs vs the required set; any missing table is reported and must be remediated.

**Decision:** missing table = **hard block** (not a warning). Soft warnings reintroduce the judgment that is failing today; the agent must stop, diagnose the omission, and address it before continuing.

### 2.12 Resolved decision D6 (CDT / Data Store Entity writes)

**Context:** Not all processes are migrated to Record Types. Legacy processes and forms still write via **CDTs through Data Store Entities (DSE)** using the `a!writeToDataStoreEntity` (single) and `a!writeToDataStoreEntities` (multiple) smart services. The write-set is incomplete — and the coverage gate would miss tables — if it only covers record writes.

**Grounded findings:**
- Data stores ARE parsed (`data_store_parser.py`) → `entities[]` with `entity_uuid`, `entity_name`, `cdt_type`. So **DSE→CDT binding exists**.
- CDT objects carry `fields[]` with `column_name` (e.g. `AS_GSS_Evaluation` → `EVALUATION_ID`…) but **no bound table name** — the one missing link is CDT→table.
- Full resolution chain for a CDT write: write node → DSE constant (`cons!…ENT_…`) → data store entity → `cdt_type` → CDT columns → **table**.

**Part 1 — Extraction (parser):**
- Extend write extraction to also detect `a!writeToDataStoreEntity` and `a!writeToDataStoreEntities` (PM smart-service nodes + SAIL calls).
- Each emits a `writes` entry tagged **`mechanism: "CDT"`** (vs `"RECORD"`), capturing `data_store_entity` (uuid/name), `cdt_type`, resolved `table`, `operation: WRITE`, `via`.
- **CDT→table resolution (D6.1 — RESOLVED):** enhance the **CDT parser to capture the bound table name from the CDT's XSD table annotation**; fall back to matching the CDT `column_name` set against `tables.json` if the annotation is absent.
- **Coverage gate is unchanged** — it keys on `table`, so CDT writes contribute to the same required-table set as record writes. `mechanism` informs only the execution API.

Updated per-node `writes` entry (superset of D4):
```json
{
  "mechanism": "RECORD" | "CDT",
  "table": "AS_GSS_...",
  "operation": "WRITE",
  // RECORD mechanism:
  "record_type_uuid": "...", "record_type_name": "...",
  // CDT mechanism:
  "data_store_entity": "<entity uuid/name>", "cdt_type": "urn:...:AS_GSS_Evaluation",
  "via": "writeToDataStoreEntity | writeToDataStoreEntities | writeRecords | SYSTEM_SYSRULES_writeRecords_v2 | <PM node>"
}
```

**Part 2 — Execution APIs (ADG app + DG MCP):**
- New ADG expression rules + a Web API method using `a!writeToDataStoreEntity` / `a!writeToDataStoreEntities`, mirroring the existing record CRUD rules. Agent sends simple JSON (entity identifier + field→value); the ADG rule constructs the typed CDT (`cast('type!{ns}CDT', …)`) and writes to the DSE.
- CDT field metadata is available from the Atlas KB CDT object (fields + types + `column_name`) **and, at runtime, from the new `ADG_UT_getCdtProperties` rule** (uuid `_a-0000eff6-da77-8000-9bf2-011c48011c48_75944`, "The rule to fetch CDT properties") — the CDT analogue of `ADG_UT_getRecordTypeProperties`. This is what backs a `get_cdt_properties` DG tool / `dse/properties` Web API method mirroring `get_record_properties`.
- DG MCP: new `write_data_store_entity` tool + session tracking. **Rollback:** reuse soft-delete (`isActive=false`) where the CDT has `isActive`; otherwise `a!deleteFromDataStoreEntities`.

**Execution routing (D6.2 — RESOLVED): mirror the workflow mechanism.** If the workflow wrote a table via CDT/DSE, the agent replicates via the DSE API; if via record, it uses the record API. The `mechanism` tag on each write drives the choice. (The DSE API is also the only option for CDT-only tables that have no record type.)

### 2.13 Remaining open questions

All F1 open questions are **RESOLVED** (see D1–D6). No open questions remain for Feature 1.

---

## 3. Feature 2 — User & Document Configuration

### 3.1 Part 1 — Group-aware user resolution

#### 3.1.1 Problem

Today `ADG_API_users` returns **all** users. When the generated data simulates a process that can
only be initiated by members of a specific group (e.g. only `Group X` can initiate `Process A`),
the agent may pick a user with no valid relationship to that process, producing semantically wrong
data (e.g. an initiator who lacks permission).

#### 3.1.2 What we have (grounded)

- In Appian these workflows are launched from the **UI via a record action, related action, or start-process link** — **not** via process-model security. Eligibility ("who can initiate") is enforced by the **visibility condition** configured on that action/link (e.g. `a!isUserMemberOfGroup(loggedInUser(), cons!…GRP…)`, often delegated to a BL visibility rule).
- The Atlas KB **already captures each action's `VISIBILITY` expression** on the record type object: `type_specific.actions[].expressions.VISIBILITY`. Example (Evaluation record):
  - `createNewEvaluation` → `"rule!AS_GSS_BL_getVisibilityToCreateEvaluation(user: loggedInUser())"`
  - `addVendor` → `"rule!AS_GSS_BL_getRelatedActionVisibilityForUpdateEvaluation(evaluationStatusId: …)"`
- So the group that gates initiation is reachable by **tracing the visibility expression / its referenced rule** — no new structured artifact or deterministic group extraction is required.

#### 3.1.3 Proposed approach (RESOLVED — D8)

This is primarily **steering + a group-filtered user API**, NOT a parser/KB change:

1. **No parser change for initiator groups.** The action `VISIBILITY` expression is already in the KB. (Earlier assumption of a `process_security.json` artifact is dropped.)
2. **Steering (agent at analysis time):** for the action/related-action/start-process link that drives the target workflow, read its `VISIBILITY` expression, follow the referenced visibility rule (via the dependency graph / `get_object_code`), and identify the eligible group(s). This is agent reasoning guided by a steering step — deterministic group extraction is explicitly **out of scope**.
3. **ADG Appian API:** add a **group-filtered user query** returning **effective (nested) members** of a group (D7). Either extend `ADG_API_users` (`users/list`) with an optional `groupName`/`groupUuid` filter, or add a `users/byGroup` method; backed by a new expression rule (e.g. `ADG_UT_queryUsersByGroup`) using Appian group-membership functions.
4. **DG MCP:** add/extend `list_users(group=…)` so the agent fetches the group-scoped candidate pool.
5. **Workflow:** when populating the **initiator / `createdBy`-type field**, the agent draws from the group-scoped pool identified from the action's visibility rule, not the global user list.

#### 3.1.4 Open questions

- ~~Direct members only, or nested membership?~~ — **RESOLVED (D7): effective (nested) members.**
- ~~How is a field mapped to its group?~~ — **RESOLVED (D8):** handled in **steering** — the agent reads the action's already-captured `VISIBILITY` expression and traces the referenced rule to find the group; no deterministic parser extraction. Scope = the **initiator** (who can launch the action). Other role user-fields fall back to the global pool unless analysis surfaces a specific filter.
- Multiple eligible groups → selection policy (first, random, round-robin)? — **RESOLVED (D9): random across the union** of effective members of all eligible groups. Correctness property: the chosen user must be an effective member of at least one eligible group; the union is the candidate pool, and random selection spreads initiators across eligible groups for more realistic demo data.

### 3.2 Part 2 — Document library / configuration

#### 3.2.1 Problem

Document-type fields require a **real Appian document id** from the environment. There is currently
no way to (a) maintain a curated set of example documents, or (b) let the agent discover and pick
the *semantically correct* document for a given field/context.

#### 3.2.2 Proposed approach

A user-maintainable **document library** inside the ADG application, organized by **Application**. Users create an Application entry, then configure that application's example documents. The agent matches by **application name** to fetch the right document set, then reads each document's description to pick the correct one.

**Data model (two new record types, CDM-backed tables):**
1. `ADG_Application` — user-maintained: `id` (PK), `name` (the match key the agent uses — unique), `description`, `isActive`, audit fields.
2. `ADG_Document` — `id` (PK), `applicationId` (FK → `ADG_Application`), `documentId` (Appian document reference), `name`, `description` (what the agent reads to choose), `isActive`, audit fields.
- Relationship: `ADG_Application` 1—* `ADG_Document`.
- Files live in an ADG knowledge-center folder; `documentId` points to the uploaded Appian doc.

**CRUD UI (modern, standard; NO process models):**
- **Application CRUD** — list + create / edit / deactivate.
- **Document CRUD** — per selected application: list + create / edit / deactivate, with a file-upload field + name + description.
- **All writes use `a!writeRecords` directly in the interfaces' `saveInto`** (no process models). Document upload via `a!fileUploadField` writing the resulting document into `ADG_Document.documentId`.
- Hosted as a small ADG site (or record-list + interfaces). UI must be modern and follow the SAIL design/accessibility best practices in `appian-application/sail-best-practices/`.

**Exposure to the agent:**
- Query method (extend the `record` Web API or add `documents/list`) returning `ADG_Document` rows filtered by **application name** → `{ documentId, name, description }`.
- **DG MCP:** `list_documents(application)` / `find_document(application, query)` so the agent searches by application name then matches on description.

**Workflow:** when a payload field is Document-type, the agent resolves it from the library — match the target application by name, read candidate document descriptions, select the best-fitting `documentId` — never invents a doc id.

#### 3.2.3 Open questions / resolved

- ~~Global vs per-application~~ — **RESOLVED (D10):** one global library **organized by user-created Application records**; the agent matches by **application name**.
- ~~Matching~~ — **RESOLVED:** filter documents by application name, then the agent matches on **document description** to pick.
- ~~Maintenance / who administers~~ — **RESOLVED:** end users via **CRUD interfaces** (Applications + Documents); writes via direct `a!writeRecords`, **no process models**; modern/standard UI.
- Versioning of example documents — assume **always latest** (user-maintained); no version history needed for V1.

---

## 4. Feature 3 — Bulk Data Generation via CSV import

### 4.1 Problem / goal

The current bulk path generates raw SQL INSERTs (`step-6-generate-sql.md`). We want to switch bulk
generation to use the **`insertRecordData`** CSV-import tool that already exists in
`solutions-lcp-mcp-server` (`src/lcp_mcp_server/tools/record_data.py`), so bulk loads go through
Appian's record layer (record-type UUID + CSV) and return assigned primary keys — instead of
hand-rolled SQL.

### 4.2 What the tool does (confirmed)

`insertRecordData(uuid, csvData, versionId=None)`:
- `uuid` — target record type UUID.
- `csvData` — header row + one or more data rows. Headers must match record field names exactly;
  PK column optional (auto-generated). Type rules: booleans `1/0`; dates `YYYY-MM-DD`; datetimes
  `YYYY-MM-DD HH:MM:SS`; times `HH:MM:SS`; UTC; RFC-4180 quoting; no embedded JSON.
- Returns inserted rows **with assigned PKs** (usable for FK chaining in downstream tables).
- Companions in the same module: `listRecordData`, `updateRecordData`, `deleteRecordData`.

### 4.3 Proposed approach

> **User directive (revised):** Do **not** move/port `insertRecordData` into the DG MCP server (it's a rework). Instead, the agent uses the **`lcp-mcp-server` directly** for the insert step, and the DG MCP provides a **tool that converts the generated data into the exact CSV format `insertRecordData` expects.**

**Approach (RESOLVED — D11):**

1. **No tool migration.** `lcp-mcp-server` is configured as an available MCP server for the power; the agent calls its `insertRecordData(uuid, csvData)` for bulk inserts.
2. **New DG MCP tool — CSV formatter** (e.g. `to_record_csv`): takes a target record type + a list of row objects (field name → value) and returns a **CSV string matching `insertRecordData`'s strict contract**:
   - Header = exact record field names; PK column optional.
   - Type formatting: booleans `1/0` (not true/false), dates `YYYY-MM-DD`, datetimes `YYYY-MM-DD HH:MM:SS`, times `HH:MM:SS`, all **UTC**; RFC-4180 quoting for commas/quotes/newlines; no embedded JSON.
   - Needs per-field type info to format correctly — sourced from `get_record_properties` (existing DG tool) or KB field types. One record type per call (mirrors `insertRecordData`).
   This converter is the value-add: it guarantees the formatting that would otherwise cause insert failures.
3. **Bulk flow:** agent builds rows → `to_record_csv` (DG) → `insertRecordData` (lcp-mcp-server) → capture returned PKs → feed into downstream CSVs per `insertion_order.json`.

**Cross-cutting:**
- **PK chaining:** `insertRecordData` returns assigned PKs; the agent chains them into FK columns of dependent record types in insertion order. The formatter is invoked per record type along that order.
- **Rollback:** bulk inserts happen via lcp-mcp-server (outside DG's `SessionManager`). Rollback options: lcp `deleteRecordData` by PK, or soft-delete (`isActive=false`) via the existing path. (See open question.)
- **Steering:** replace/add a bulk step (`step-6-bulk-csv.md`) — build rows, call DG formatter, call lcp `insertRecordData`, chain PKs.

### 4.4 Open questions

1. ~~Port vs SDK dependency~~ — **RESOLVED (D11): neither.** Use `lcp-mcp-server` directly + a DG CSV-formatter tool.
2. ~~Replace vs coexist with SQL~~ — **RESOLVED (D12): coexist.** Bulk CSV (via `insertRecordData`) is the primary path; **SQL generation is kept as a backup** (e.g. for environments where the LCP plugin isn't available).
3. ~~Rollback for bulk~~ — **RESOLVED (D13): no automatic rollback for bulk operations.** Bulk loads are cleaned up by **manually truncating tables**. (Session rollback remains only for the interactive record/CDT write path.)
4. Formatter field-type source: `get_record_properties` (live) vs KB field types — confirm during implementation.

---

## 5. Suggested prioritization (for discussion)

| # | Feature | Impact | Effort | Notes |
|---|---------|--------|--------|-------|
| 1 | Data Integrity (per-node `writes` incl. CDT/DSE + deterministic coverage gate) | **Highest** — directly fixes correctness/reliability | High | Parser (record + CDT/DSE write extraction, gateway conditions, CDT→table), Atlas MCP (2 tools), DG MCP (coverage verify + DSE write), ADG (DSE write API), steering (hard-block gate, mirror mechanism) |
| 2 | Bulk via CSV import | Medium-High — well-scoped | Low | DG `to_record_csv` formatter + steering; agent uses lcp-mcp-server `insertRecordData`; SQL kept as backup; no bulk rollback |
| 3a | Group-aware users | Medium — correctness of user fields | Low-Med | NO parser change (VISIBILITY already in KB); ADG group-filtered user API (nested) + DG `list_users(group)` + steering (trace visibility rule, random across union) |
| 3b | Document library | Medium — unblocks document fields | Med | `ADG_Application` + `ADG_Document` RTs; modern CRUD interfaces (direct `a!writeRecords`, no PMs); query-by-app-name API; DG `list_documents` |

**Proposed order:** **Feature 1 (Data Integrity)** first — core reliability gap, largest surface (now includes CDT/DSE). Land **Feature 3 (Bulk CSV)** in parallel (low risk, small). Then **Feature 2** — group-aware users (small, no parser work) then document library (new RTs + UI). Open to reprioritizing.

---

## 6. Affected components summary

| Component | F1 Data Integrity | F2 Users | F2 Documents | F3 Bulk CSV |
|-----------|-------------------|----------|--------------|-------------|
| `solutions-atlas-parser` | ✅ per-node `writes` (record **+ CDT/DSE**, `mechanism` tag); gateway branch conditions; CDT→table via XSD; record/DSE write-node extraction | — (visibility expr already captured) | — | — |
| Atlas KB artifacts | ✅ enriched bundles (`writes` on nodes) | — (no new artifact) | — | — |
| `solutions-atlas-mcp-server` | ✅ get_entry_point_write_graph, resolve_write_set | — (uses existing action VISIBILITY + get_object_code) | — | — |
| ADG Appian app (APIs/rules) | ✅ **DSE write API** (`a!writeToDataStoreEntity[ies]`) mirroring record CRUD | ✅ group-filtered user query (nested members) | ✅ `ADG_Application` + `ADG_Document` RTs; CRUD interfaces (direct `a!writeRecords`, no PMs); query-by-app-name API | — |
| DG MCP server | ✅ coverage verify tool; **write_data_store_entity** + **get_cdt_properties** (backed by `ADG_UT_getCdtProperties`) | ✅ list_users(group) | ✅ list_documents(application)/find_document | ✅ **CSV-formatter tool** (`to_record_csv`) |
| Power steering | ✅ coverage gate (hard block); mirror-mechanism execution | ✅ trace action VISIBILITY rule → group → group-scoped initiator | ✅ match app by name → pick by description | ✅ bulk-csv step (DG formatter → lcp `insertRecordData`) |
| `lcp-mcp-server` | — | — | — | ✅ used directly for `insertRecordData` (configured as available MCP) |

---

## 7. Decision log (D1–D13)

| # | Topic | Decision |
|---|-------|----------|
| D1 | F1 write-set granularity | Attach `writes` **per node** inside the existing per-entry-point bundles (mirrors `flow.process_model.nodes[]`); status view is a derived composition, not a separate file. |
| D2 | F1 conditional writes | Conditionality lives at the **node/gateway-branch level**; parser captures gateway branch conditions on edges; gate resolves a concrete path. |
| D3 | F1 reference vs business | Reference tables already handled (agent never inserts them). Gate focuses **only on business/task-mgmt tables** the workflow writes. |
| D4 | F1 `writes` entry shape | **Table/record-type granularity** (not field-level); `operation` best-effort `WRITE`; fields = record_type_uuid/name, table, operation, via. |
| D5 | F1 coverage gate | Tool-computed & deterministic. Atlas MCP `resolve_write_set` (FK-closed business set); pre-exec payload diff = **HARD BLOCK**; post-exec footprint diff via DG MCP. |
| D6 | F1 CDT / Data Store Entity | Extract `writeToDataStoreEntity[ies]` as `writes` with `mechanism:"CDT"`; resolve CDT→table via XSD annotation (column-match fallback). New ADG DSE write API + DG `write_data_store_entity`. **D6.1** CDT→table via XSD. **D6.2** execution **mirrors workflow mechanism**. |
| D7 | F2 user membership | Group-user lookup returns **effective (nested) members**. |
| D8 | F2 field→group mapping | Handled in **steering** — agent reads action `VISIBILITY` (already in KB), traces the rule to the group. No parser change. Scope = initiator. |
| D9 | F2 multiple eligible groups | **Random across the union** of effective members of all eligible groups. |
| D10 | F2 document library | Global library **organized by user-created `ADG_Application`**; agent matches by **application name** then by document **description**. CRUD via interfaces with direct `a!writeRecords` (no PMs); modern UI. |
| D11 | F3 tool integration | **Don't port** `insertRecordData`. Agent uses `lcp-mcp-server` directly; DG MCP adds `to_record_csv` formatter. |
| D12 | F3 SQL path | Bulk CSV is primary; **SQL generation kept as backup** (LCP-plugin-less envs). |
| D13 | F3 bulk rollback | **No automatic rollback** for bulk; cleanup by manual table truncate. |

---

## 8. Glossary

- **Record Type** — modern Appian object bound to a DB table; CRUD via `a!writeRecords`.
- **CDT (Complex Data Type)** — legacy typed structure bound to a table via a **Data Store Entity**; CRUD via `a!writeToDataStoreEntity[ies]`.
- **Data Store Entity (DSE)** — binds a CDT to a table within a data source; referenced in writes via a `cons!…ENT_…` constant.
- **Bundle** — per-entry-point unit in the KB (`current/bundles/<EntryPoint>.json`) containing `flow.process_model.nodes[]`, members, key objects. What the agent queries to understand a workflow.
- **Entry point** — an action / related action / start-process link / process that launches a workflow.
- **Write-set** — the set of tables written to reach a target state; composed from per-node `writes` along a resolved path + FK closure.
- **Coverage gate** — deterministic pre-/post-execution check that every required business/task-mgmt table is covered.
- **ADG** — the Atlas Data Generator Appian application (prefix `ADG`) exposing the write/query Web APIs.
- **DG MCP** — the write-capable Data Generator MCP server (`solutions-atlas-dg-mcp-server`).

---

## 9. Assumptions & prerequisites

- **KB re-parse required.** F1 parser changes only take effect after the affected apps are re-parsed and the KB sync runs; the new `writes`/branch-condition data must exist in `current/bundles/` before the gate can use it.
- **LCP plugin availability.** F3 `insertRecordData` (and lcp-mcp-server generally) calls the **LCP API plugin** deployed in the target Appian environment. Bulk CSV requires that plugin; otherwise fall back to SQL (D12).
- **Environment isolation.** All writes target designated non-production environments (current: `merge-assist.appianpreview.com`). DG MCP is configured per environment.
- **ADG deployment.** F2 new record types (`ADG_Application`, `ADG_Document`), interfaces, and the DSE write API must be deployed to the ADG application; tables created via CDM (`createTable`).
- **Power MCP config.** `mcp.json` in the power must list Atlas MCP, DG MCP, **and** lcp-mcp-server for F3.
- **Backward compatibility.** Existing DG tools and the record write path remain unchanged; all additions are additive.

---

## 10. Non-goals / out of scope (V1)

- Deterministic extraction of the initiator **group** from visibility rules (D8 — steering handles it).
- **Field-level** write extraction in the write-set (D4 — table granularity only; field completeness stays with M4 ≥80%).
- Per-field group constraints beyond the **initiator** (other user fields fall back to the global pool).
- **Version history** for library documents (D10 — always latest).
- **Automatic rollback** for bulk operations (D13 — manual truncate).
- ERD generation changes (`erd-gen` untouched in V1).

---

## 11. Open items to confirm during implementation

- **F3-Q4:** formatter field-type source — `get_record_properties` (live) vs KB field types.
- DSE write **rollback** specifics where a CDT lacks `isActive` (`a!deleteFromDataStoreEntities`).
- Exact ADG exposure for documents/users: extend existing `record`/`users` Web APIs vs add new methods.
- Whether `resolve_write_set` accepts multiple entry points in one call (multi-transition paths) — expected yes.

---

## 12. Next steps

1. ✅ Approaches aligned and all open questions resolved (D1–D13); design is authoritative.
2. ⏭️ Produce a **sequenced implementation plan** per repo (tasks, dependencies, execution order), starting with Feature 1.
3. Confirm the §11 implementation-time items as work begins.
