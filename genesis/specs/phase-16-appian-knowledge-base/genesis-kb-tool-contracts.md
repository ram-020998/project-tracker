# Phase 16 — `genesis-kb` Tool Contracts & Implementation Guide

> **Status:** DRAFT (planning) · **Author:** Genesis agent · **Date:** 2026-08-04 · **Repos:** genesis (+ genesis-workflows for MCP registry)
> **Purpose:** The single, implementation-ready contract for **every tool** Genesis exposes to agents for Appian
> knowledge + environment access. It is derived from a full audit of the **Atlas MCP (34 tools)** and **Jarvis MCP
> (50 tools)** and the user's scoping decisions (2026-08-04). An implementation agent should be able to build the
> `genesis-kb` MCP server and wire the native MCPs **directly from this document**, in the order given, with no
> guesswork about params, return shapes, or backing queries.
> **Companion specs:** 16-01 (parser must emit the fields cited here), 16-02 (`kb_*` tables the queries run against),
> 16-05 (the `genesis-kb` server + cutover). This doc is the authoritative **tool contract**; where it and 16-05
> differ, this doc wins.

---

## 0. Governing principle (non-negotiable)

**Knowledge fetch → the internal Genesis KB (`genesis-kb`). Any call to the Appian environment → the native Appian
Dev MCP / DevOps MCP.** Atlas and Jarvis are **retired as services** — we reproduce their *knowledge* surface locally
and route every *environment* operation through the out-of-the-box Dev/DevOps MCP. The KB stores **no source code**;
code is always fetched live via the Dev MCP.

### Scope decisions (from the Atlas+Jarvis capability analysis)

| Section (from the analysis) | Verdict | Where it lives |
|---|---|---|
| **A — KB structural intelligence (Tier-1)** | **IN (iteration 1)** | `genesis-kb` tools §2 |
| A — deferred (patterns, translations, semantic search, code-analysis) | **OUT** | — |
| **B — versioning / multi-release (6 tools)** | **BACKLOG** — build once Dev MCP ships multi-release (**AP-62096**) | 16-06 (relabelled backlog) |
| **C — schema / DDL / data-gen (9 tools)** | **DEFERRED** | future phase (overlaps Data-Generator MCP) |
| **D — live-environment reads** | **IN, but via Dev/DevOps MCP only** | §3 (native MCP registration) |
| **E — write / deploy / create** | **OUT (for now)** | future, behind `pre_mutation` |
| **F — documents / git-content / pipeline-refresh** | **OUT** | — |

**Implication for the implementation agent:** build the §2 `genesis-kb` tools and the §3 Dev/DevOps registration in
iteration 1. Do **not** build B/C/E/F. Anything an agent needs that is *not* a §2 KB tool must be satisfied by a
Dev/DevOps MCP tool (§3), never by calling Atlas or Jarvis.

---

## 1. `genesis-kb` server mechanics (recap; full detail in 16-05)

- A Genesis-owned **read-only stdio JSON-RPC** MCP server (`genesis/genesis/mcp/kb_server.py`), modeled on
  `introspection_server.py`: opens `genesis.db` **read-only** (`file:{db}?mode=ro`), 32 KB payload cap, secret
  redaction, launched `python -m genesis.mcp.kb_server --db <genesis.db>`.
- Injected into chat (`chat/mcp.py` `_kb_entry` + `@genesis-kb/<tool>` in the read trust set) and available to
  workflow nodes; **cross-app** (an `app_name` arg selects the app; omit where a tool is global).
- **Return shapes mirror the Atlas MCP** so the cutover of chat / `erd-generation` / `design-doc` is lossless. Each
  tool below gives the exact shape.
- **`app_name` resolution:** callers pass the application **name** (as `list_applications` returns). Internally resolve
  to `kb_applications.app_uuid`. (Accept a UUID too, for robustness.)
- **"Current state"** in every query = rows with `valid_to_sync IS NULL` (the SCD-2 columns exist in 16-02 but
  iteration 1 only ever reads current — see §5).
- **Code fields are never read from `kb_*`.** `get_object_code` (and the optional code field on `get_orphan`) delegate
  to the **Dev MCP** (§3). If the Dev MCP is unavailable, return a structured "code unavailable" object — never
  fabricate.

Backing tables (from 16-02): `kb_applications`, `kb_objects`, `kb_dependencies`, `kb_bundles`, `kb_bundle_members`.
Column names below reference that schema.

---

## 2. `genesis-kb` tool contracts (Tier-1 — the full iteration-1 surface)

Each tool: **Replaces** (Atlas/Jarvis equivalents) · **Params** · **Returns** (exact JSON) · **Backing query** ·
**Parser source** (the 16-01 `KbParseResult` fields that populate it).

### 2.1 `list_applications`
- **Replaces:** Atlas `list_applications`; Jarvis `jarvis_get_app_tree`/`get_jarvis_config` (registry part).
- **Params:** none.
- **Returns:** array of
  ```json
  [{"name":"SourceSelection","total_objects":2461,"total_errors":0,
    "bundle_coverage":{"total_objects":2461,"bundled":1898,"orphaned":563},
    "bundles_by_type":{"action":120,"process":40,"page":30,"site":2,"dashboard":5,"web_api":8}}]
  ```
- **Backing query:** `kb_applications` rows; per app: `total_objects` = COUNT `kb_objects` current; `orphaned` = COUNT
  where `is_orphan=1` current; `bundled` = `total-orphaned`; `bundles_by_type` = `kb_bundles` current GROUP BY
  `bundle_type`. `total_errors` from the latest `kb_syncs` row (parser error count).
- **Parser source:** object list + `is_orphan` flags + bundles; `stats`/error count from `KbParseResult.errors`.

### 2.2 `get_app_overview`
- **Replaces:** Atlas `get_app_overview`; Jarvis `jarvis_get_architecture` (partial).
- **Params:** `{app_name (required)}`.
- **Returns:** (mirror Atlas `app_overview.json`)
  ```json
  {"_metadata":{"application":"SourceSelection","generated_at":"…","latest_sync_id":42},
   "object_counts":{"Interface":489,"Expression Rule":990,"Process Model":117,"Record Type":49,"Constant":582,"CDT":107},
   "bundles":[{"id":"AS_GSS_Complete_LPTA_Evaluation","bundle_type":"action","root_name":"…","parent_name":"…","object_count":282,"key_objects":["…"]}],
   "dependency_summary":{"total":5234,"by_type":{"rule_call":3421,"interface_call":892,"constant_ref":654},
     "most_depended_on":[{"name":"AS_CO_UT_isBlank","type":"Expression Rule","inbound_count":1247}]},
   "coverage":{"total_objects":2461,"bundled":1898,"orphaned":563}}
  ```
- **Backing query:** `object_counts` = `kb_objects` current GROUP BY `type`; `bundles` = `kb_bundles` current (+
  `key_objects` from `kb_bundle_members` role=entry_point/top members); `dependency_summary.total`/`by_type` =
  `kb_dependencies` current GROUP BY `dep_type`; `most_depended_on` = top inbound (see `get_hub_objects`); `coverage`
  as in 2.1.
- **Parser source:** objects, edges (`dep_type`), bundles, orphan flags.

### 2.3 `search_objects`
- **Replaces:** Atlas `search_objects`; Jarvis `search_objects_by_name`(live)/`jarvis_search_objects`/`jarvis_get_objects_by_type`.
- **Params:** `{app_name (required), query (required), object_type?, limit? (default 20, max 100)}`. *(For
  objects-by-type parity, allow `query:""` + `object_type` to list a type.)*
- **Returns:**
  ```json
  {"total_matches":12,"returned":12,"results":[
    {"name":"AS_GSS_PM_CompleteLPTAEvaluation","uuid":"_a-…","type":"Process Model",
     "bundles":["AS_GSS_Complete_LPTA_Evaluation"],"inbound_count":3,"outbound_count":47}]}
  ```
- **Backing query:** `kb_objects` current WHERE `app_uuid=?` AND `name LIKE '%'||?||'%'` (case-insensitive) [AND
  `type=?`], `LIMIT`; `inbound_count`/`outbound_count` = COUNT in `kb_dependencies` current by target/source;
  `bundles` = `kb_bundle_members`→`kb_bundles.bundle_id`. (Add FTS5 later; not now.)
- **Parser source:** objects (name/uuid/type), edges (counts), bundle membership.

### 2.4 `get_dependencies`  (by name)
- **Replaces:** Atlas `get_dependencies`; Jarvis `get_object_dependencies`(live)/`jarvis_get_dependency_chain`.
- **Params:** `{app_name (required), object_name (required)}`.
- **Returns:** (mirror Atlas `objects/<uuid>.json`)
  ```json
  {"uuid":"_a-…","name":"AS_GSS_BL_validateLPTAScores","type":"Expression Rule",
   "calls":[{"uuid":"_b-…","name":"AS_CO_UT_isBlank","type":"Expression Rule","dep_type":"rule_call"}],
   "called_by":[{"uuid":"_a-…","name":"AS_GSS_PM_CompleteLPTAEvaluation","type":"Process Model","dep_type":"rule_call"}],
   "bundles":["AS_GSS_Complete_LPTA_Evaluation"]}
  ```
- **Backing query:** resolve name→uuid in `kb_objects` current (case-insensitive exact match; if none →
  `{"error":"Object '<name>' not found"}`); `calls` = `kb_dependencies` current WHERE `source_uuid=uuid` joined to
  target metadata; `called_by` = WHERE `target_uuid=uuid` joined to source metadata; `bundles` = `kb_bundle_members`.
- **Parser source:** edges + object metadata + bundle membership.

### 2.5 `get_object_detail`  (by uuid)
- **Replaces:** Atlas `get_object_detail`; Jarvis `jarvis_get_object_content`/`jarvis_get_context` (metadata half — **no code**).
- **Params:** `{app_name (required), object_uuid (required)}`.
- **Returns:** the 2.4 shape **plus** `description`, `qname?`, `type_id?`, and `metadata` (parameters, output type,
  record fields, entry-point kind — the structural detail from `kb_objects.metadata_json`, **never `sail_code`**). Code
  is a separate call (`get_object_code`, §2.13).
- **Backing query:** `kb_objects` current WHERE `object_uuid=?` + the same calls/called_by/bundles joins as 2.4.
- **Parser source:** object (name/type/description/qname/type_id/metadata) + edges + bundles.

### 2.6 `get_entry_points_for_object`  *(Jarvis nicety — inverse of `get_bundle`)*
- **Replaces:** Jarvis `jarvis_get_entry_points_for_object`.
- **Params:** `{app_name (required), object_uuid? , object_name?}` (one required).
- **Returns:** `{"uuid":"…","name":"…","bundles":[{"id":"…","bundle_type":"action","root_name":"…"}]}` — the bundles/
  entry points whose member set contains this object.
- **Backing query:** `kb_bundle_members` WHERE `object_uuid=?` (current snapshot) → join `kb_bundles`.
- **Parser source:** bundle membership.

### 2.7 `get_dependents_batch` / `get_precedents_batch`  *(Jarvis nicety — batched `get_dependencies`)*
- **Replaces:** Jarvis `jarvis_get_dependents_batch` / `jarvis_get_precedents_batch`.
- **Params:** `{app_name (required), object_uuids: [string] (required)}`.
- **Returns:** `{"<uuid>":[{"uuid":"…","name":"…","type":"…","dep_type":"…"}], …}` — per input uuid, its direct
  dependents (callers) or precedents (callees).
- **Backing query:** one `kb_dependencies` current query `WHERE target_uuid IN (…)` (dependents) or `source_uuid IN (…)`
  (precedents), grouped in code by the pivot uuid.
- **Parser source:** edges.

### 2.8 `get_shared_objects`  *(Jarvis nicety — cross-bundle objects)*
- **Replaces:** Jarvis `jarvis_get_shared_objects`.
- **Params:** `{app_name (required), min_bundles? (default 2)}`.
- **Returns:** `[{"uuid":"…","name":"…","type":"…","bundles":["…","…"]}]` — objects that appear in ≥ `min_bundles`
  bundles.
- **Backing query:** `kb_bundle_members` (current) GROUP BY `object_uuid` HAVING COUNT(DISTINCT bundle) ≥ `min_bundles`.
- **Parser source:** bundle membership.

### 2.9 `search_bundles`
- **Replaces:** Atlas `search_bundles`; Jarvis `jarvis_get_cluster` (search part).
- **Params:** `{app_name (required), query (required), bundle_type?}`.
- **Returns:** array of bundle-index entries `[{"id":"…","bundle_type":"action","root_name":"…","parent_name":"…","object_count":282,"key_objects":["…"]}]`
  matching `query` against `root_name` **or** `parent_name`.
- **Backing query:** `kb_bundles` current WHERE `app_uuid=?` AND (`name LIKE` OR `parent_name LIKE`) [AND `bundle_type=?`].
- **Parser source:** bundles.

### 2.10 `get_bundle`
- **Replaces:** Atlas `get_bundle`; Jarvis `jarvis_get_cluster`.
- **Params:** `{app_name (required), bundle_id (required — id or root_name), object_type?, limit? (default 50, max 200)}`.
- **Returns:** (mirror Atlas)
  ```json
  {"_metadata":{"bundle_id":"…","bundle_type":"action","root_uuid":"_a-…","root_name":"…","parent_name":"…","object_count":282},
   "entry_point":{"uuid":"_a-…","name":"…","type":"Record Type Action","description":"…"},
   "flow":{"process_model":{"name":"…","complexity_score":12,"total_nodes":18,
             "nodes":[{"name":"…","type":"USER_TASK","next":["… (Approved)"],"writes":[…],"interface":"…"}]},
           "subprocesses":[{"name":"…","nodes":[…]}]},
   "members":[{"uuid":"_a-…","name":"…","type":"Process Model"}],
   "key_objects":["…"],
   "member_summary":{"total":282,"returned":50,"by_type":{"Interface":120,"Expression Rule":90}}}
  ```
- **Backing query:** resolve `bundle_id` (direct id, else match `root_name`/`id` in `kb_bundles`); `_metadata` +
  `entry_point` from `kb_bundles` (root_uuid→`kb_objects` for the entry point + description); `members` =
  `kb_bundle_members` join `kb_objects` (filter `type`, `LIMIT`); `by_type` computed over **all** members before the
  limit; `flow` = `kb_bundles.flow_json` returned **verbatim**.
- **Parser source:** bundle (`root_uuid/name/parent/type/object_count`, `flow`), members, object metadata.
- **Note (parser + schema) — `flow` is a structured dict, NOT a string list (verified 2026-08-04 against Atlas):**
  the Atlas MCP `get_bundle` returns `structure.get("flow")` **verbatim** — a dict
  `{"process_model": <graph>, "subprocesses": [<graph>, …]}` where each `<graph>` =
  `{name, complexity_score, total_nodes, nodes:[{name, type, next?, writes?, gateway_conditions?, subprocess?, interface?}]}`
  (`None` for bundles without a process model). 16-01's `KbBundle.flow` already emits exactly this; 16-02 stores it
  verbatim in `kb_bundles.flow_json` and `get_bundle` returns it verbatim. **The earlier "textual traversal" shape was
  incorrect.**

### 2.11 `list_orphans`
- **Replaces:** Atlas `list_orphans`; Jarvis `jarvis_get_dead_code`.
- **Params:** `{app_name (required), object_type?, limit? (default 50, max 200)}`.
- **Returns:** `{"total_orphans":563,"returned":50,"by_type":{"Expression Rule":342,"Interface":156,"Constant":65},"orphans":[{"uuid":"…","name":"…","type":"…"}]}`.
- **Backing query:** `kb_objects` current WHERE `is_orphan=1` [AND `type=?`]; `by_type` = GROUP BY type over all orphans.
- **Parser source:** objects + `is_orphan`.

### 2.12 `get_orphan`
- **Replaces:** Atlas `get_orphan`.
- **Params:** `{app_name (required), object_uuid (required)}`.
- **Returns:** the `get_object_detail` shape **plus** `sail_code` fetched **live via Dev MCP** (§3). If unavailable,
  omit `sail_code` and include `"code_status":"unavailable"`.
- **Backing query:** `kb_objects` current WHERE `object_uuid=?` (+deps/bundles) → then Dev MCP for code.
- **Parser source:** object metadata (code is live).

### 2.13 `get_object_code`  (LIVE via Dev MCP — no KB storage)
- **Replaces:** Atlas `get_object_code`; Jarvis `get_appian_object`/`jarvis_get_object_content`/`jarvis_get_object_xml`.
- **Params:** `{app_name (required), object_name (required)}` *(+ `version?` reserved for the versioning backlog — see 16-06/AP-62096)*.
- **Returns:** `{"uuid":"…","name":"…","type":"…","sail_code":"…"}` when the Dev MCP returns it, else
  `{"uuid":"…","name":"…","code_status":"unavailable","reason":"…"}`.
- **Backing:** resolve name→uuid in `kb_objects`, then **call the Dev MCP** read-object tool for the live SAIL. **No
  `kb_*` code storage.** `version` is ignored until AP-62096 ships (then it maps to the versioned read).
- **Parser source:** name→uuid resolution only; code is 100% live.

### 2.14 `get_dependency_path`  (graph)
- **Replaces:** Atlas `get_dependency_path`.
- **Params:** `{app_name (required), from_name (required), to_name (required), max_hops? (default 6, max 10), direction? (outbound|inbound, default outbound)}`.
- **Returns:** `{"found":true,"hops":3,"path":[{"id/uuid":"…","name":"…","type":"…"}],"edge_types":["rule_call","interface_call"]}` or `{"found":false,"hops":null,"path":[],"message":"No path within N hops"}`.
- **Backing query:** BFS/shortest-path over `kb_dependencies` current (app-side BFS or a recursive CTE). `direction`
  chooses source→target (outbound) vs target→source (inbound). Resolve names via `kb_objects`.
- **Parser source:** edges + object metadata (path node labels).

### 2.15 `get_transitive_dependencies`  (graph)
- **Replaces:** Atlas `get_transitive_dependencies`; Jarvis `jarvis_get_impact_analysis` (inbound direction).
- **Params:** `{app_name (required), object_name (required), max_hops? (default 3, max 5), edge_types? [string], direction? (outbound|inbound)}`.
- **Returns:** `{"root":{"uuid":"…","name":"…","type":"…"},"max_hops":3,"total_reachable":128,"by_type":{"Expression Rule":80,"Interface":30},"objects":[{"uuid":"…","name":"…","type":"…","depth":1}],"truncated":true?}` (objects capped at 200).
- **Backing query:** bounded BFS over `kb_dependencies` current with optional `dep_type` filter; `depth` per node;
  `by_type` aggregate; cap 200 + `truncated`.
- **Parser source:** edges + object metadata.

### 2.16 `get_hub_objects`  (graph)
- **Replaces:** Atlas `get_hub_objects`; Jarvis `jarvis_get_architecture` (most-connected).
- **Params:** `{app_name (required), top_n? (default 20, max 100), object_type?}`.
- **Returns:** `[{"uuid":"…","name":"…","type":"…","inbound_count":1247}]` sorted desc by inbound count.
- **Backing query:** `kb_dependencies` current GROUP BY `target_uuid` ORDER BY COUNT desc LIMIT `top_n`, join
  `kb_objects` [filter `type`].
- **Parser source:** edges + object metadata.

**Summary — iteration-1 `genesis-kb` surface = 16 tools** (2.1–2.16). All read-only; all backed by `kb_*` current
state; `get_object_code` + the code field of `get_orphan` delegate live to the Dev MCP.

---

## 3. Environment access — native Dev MCP / DevOps MCP (Section D), not Atlas/Jarvis

Every *environment* operation that Atlas/Jarvis used to perform is routed through the out-of-the-box native MCPs,
registered as curated servers in `genesis-workflows/mcp-registry.json` (env vars as a **LIST** of `{name,value}`;
secrets from the SecretProvider scoped to the server name). **Read-only allowlists only** (write/deploy = Section E,
out of scope).

| Env capability (was Atlas/Jarvis) | Native MCP | Registration / allowlist notes |
|---|---|---|
| Read live object SAIL / XML | **`appian-dev`** (Dev MCP) | read-object tool(s), read-only allowlist. `genesis-kb.get_object_code` co-injects + calls this. |
| Evaluate SAIL expression | `appian-dev` | read allowlist (evaluate) |
| Read-only SQL query | `appian-dev` | read allowlist (query) |
| Environment info | `appian-dev` / `appian-devops` | read allowlist |
| List applications in the env (Applications "Add" flow) | `appian-dev` | read allowlist (list applications) — used by `/api/applications/available` (16-04) |
| Export a package (sync pipeline) | **`appian-devops`** (Deployment MCP) | `get_application_packages`, `export_package`, `poll_deployment_status`, `download_exported_package` — the deterministic REST path in 16-03 uses the same Deployment API directly |
| Package contents from a URL | `appian-devops` | export/download path |

**Action for the implementation agent:** the Dev/DevOps MCP servers are **installed + kept updatable** by **16-08**
(managed, versioned, `uv`-installed under `~/.genesis/mcp-servers/`, launched from the per-server venv, updatable from
source — Dev from the connected site's bundle servlet, DevOps from a configured/drop-in artifact; never forked). At
implementation time, **introspect the installed Dev MCP** (`POST /api/config/mcp-servers/appian-dev/tools`) to capture
exact read-tool names, then set the read-only `tool_allowlist`. Registration is a **managed reference** (ADR-038), not a
static image — this resolves the old `lcp` `<lcp-image>` placeholder. **No write/deploy tools in either allowlist**
(Section E). Trust wiring uses `@appian-dev/<tool>` / `@appian-devops/<tool>`.

---

## 4. Implementation order (build sequence)

1. **Parser fields (16-01):** ensure `KbParseResult` emits everything §2 needs — objects (`uuid/name/type/qname/type_id/description/is_entry_point/entry_point_kind/is_orphan/metadata`), edges (`source/target/dep_type`), bundles (`id/type/root_uuid/root_name/parent_name/object_count/key_objects/**flow**`), bundle members (`object_uuid/role/flow_order`). No `sail_code` on any field.
2. **Schema + store (16-02):** `kb_*` tables (incl. `kb_bundles.flow_json`); `KbStore` read methods returning the **exact §2 shapes** (each §2 tool ↔ one `KbStore` method). Unit-test each method's shape against a real-package fixture.
3. **`genesis-kb` server (16-05):** wrap the `KbStore` read methods as the §2.1–2.13 tools; implement §2.14–2.16 graph queries (BFS/CTE + hub aggregate). Read-only stdio, mode=ro, 32 KB cap.
4. **Dev/DevOps registration (§3):** register `appian-dev` + `appian-devops` (read/export-only allowlists); wire `get_object_code`/`get_orphan` code to `@appian-dev`; wire the Applications "available apps" enumeration to `@appian-dev`.
5. **Chat wiring + cutover (16-05):** `_kb_entry` + `@genesis-kb/*` trust; co-inject `@appian-dev` read tools; cut `chat` / `erd-generation` / `design-doc` off `appian-atlas` → `genesis-kb` (+ `appian-dev` for code); update those workflows' prompts/allowlists + tests to the §2 shapes.
6. **Verify:** per-tool shape tests (green), a chat KB question answered from the internal KB, and a `get_object_code` returning live SAIL via the Dev MCP.

**Within step 2–3, tool build order:** current-state/file-backed first (2.1, 2.2, 2.3, 2.4, 2.5, 2.9, 2.10, 2.11, 2.12) → graph (2.14, 2.15, 2.16) → live code (2.13, + `get_orphan` code) → Jarvis niceties (2.6, 2.7, 2.8).

---

## 5. Backlog / deferred / out (do NOT build in iteration 1)

- **BACKLOG — Versioning (Section B, 16-06):** `list_releases`, `get_changelog`, `compare_releases`,
  `get_object_history`, `get_object_at_release`, `get_release_impact` + release tagging + point-in-time reads. Gated on
  Dev MCP **AP-62096** (26.8 GA). **Schema readiness:** 16-02 keeps the SCD-2 columns (`valid_from_sync`/`valid_to_sync`)
  and `kb_releases` table as **additive** so this backlog lands as *code only, no migration*; iteration-1 sync writes
  current state only (every current row has `valid_to_sync IS NULL`). The `version?` param on `get_object_code` is
  reserved but ignored until then.
- **DEFERRED — Schema/DDL/data-gen (Section C):** the 7 schema tools + 2 write-set tools + the parser `schema/` module
  + schema tables. A future phase (overlaps the Data-Generator MCP).
- **OUT — Write/deploy/create (Section E):** all creation/deploy tools. When added later, behind `pre_mutation` +
  copilot confirmation (ADR-021/033), via Dev/DevOps MCP.
- **OUT — Atlas extras (Section F):** documents (binaries), git-content (generic GitHub reader), pipeline-refresh
  (a KB refresh is triggered via the Applications API / sync workflow, not an agent tool).
- **OUT — A-deferred:** patterns, translations, semantic search (pgvector = future ADR-030 trigger), code
  analysis/explain (the agent reasons over fetched code; not a KB tool).
