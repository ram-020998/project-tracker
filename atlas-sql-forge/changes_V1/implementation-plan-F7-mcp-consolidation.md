# Feature 7 — Consolidate the DG (ADG) MCP server into the LCP MCP server

**Status:** 🔄 IN PROGRESS — server-side modules + tools built (2026-07-02). Parity schema-diff, full
`pytest`/`flake8`, and the agent/steering switch remain (need the repo venv/deps).

## Implementation status (2026-07-02)

| Slice | Status | Notes |
|-------|--------|-------|
| `backends/adg/` (config, client [httpx], field_registry) | ✅ built | client ported to **httpx** (LCP stack; no `requests` dep); ADG-isolated |
| `backends/interfaces.py` + `factory.py` | ✅ built | Record/User/Cdt/FieldMetadata protocols; factory defaults to ADG |
| `generation/` (session_manager, csv_format) | ✅ built | neutral logic; `_category` handles ADG + LCP enum type names |
| `tools/data_generator/` (records, cdt, csv_tools, __init__) | ✅ built | 16 parity tools (same names/args) + `generate_and_insert_records`; CDT in a removable module |
| `server.py` wiring | ✅ built | `data_generator` added to imports + `_PLUGIN_CLIENT_DOMAINS` |
| Ported-logic tests | ✅ pass (8) | `tests/unit/test_data_generator_logic.py` — expand/format incl. LCP enums (run via shim; CI pytest pending) |
| Unused-import / py_compile | ✅ clean | all new modules compile; F401s removed (flake8 cfg = 120, E501/W503 ignored) |
| **Pending (need venv/deps):** full `pytest`, `flake8 .`, real package import, **schema-diff parity (16 tools DG↔LCP)** | ⏳ | |
| **Agent switch** (drop `@appian-data-generator`, point bulk at `generate_and_insert_records`) | ✅ done (2026-07-02) | mcp.json (DG server removed, ADG creds added to lcp server), manifest tools/allowedTools, prompt tool-boundary (2 servers), step-6-bulk-csv + bulk orchestrator → `generate_and_insert_records` (loader sub-agent now optional), tool-references updated, all boundary refs → `@appian-atlas` + `@lcp-mcp-server`. JSON validated; zero `@appian-data-generator` refs remain. |
| **Pending:** retire DG repo/image after live sign-off; rebuild+push the LCP image with F7 code | ⏳ | |

**Note:** `AdgClient` is a sync `httpx.Client` called from async tools (matches DG's sync behavior); can move
to `httpx.AsyncClient` + `await` later if event-loop blocking becomes a concern.

## Code-review fixes (2026-07-02)

| # | Finding | Fix | Status |
|---|---------|-----|--------|
| 1 | Tools imported ADG internals (`backends.adg.client`) — boundary breach | Added neutral `backends/errors.py` (`BackendAPIError`); adg client aliases it; tools import from `backends.errors`. Boundary verified clean. | ✅ |
| 2 | `AdgConfig` hand-rolled vs project's pydantic `BaseSettings` | Reimplemented `AdgConfig` as `BaseSettings` (ADG_* → APPIAN_* fallback, validators, properties). | ✅ |
| 3 | Tools bypassed `handle_tool_error` (no logging, only caught `BackendAPIError`) | Added `data_generator/_common.py::dg_error` — parity shape for backend errors + logging, routes unexpected errors through `handle_tool_error`; broadened catches. | ✅ |
| 5 | Complex args not coerced (MCP may send list/dict as JSON strings) | Added `JsonDict`/`JsonList` (+ existing `JsonListOfDicts`) coercers; applied to `fields`, `filters`, `rows`, `template`, `fk_binding`, `related_records`, `required_tables`, `selected_fields`, `paging_info`. | ✅ |
| 4 | `generate_and_insert_records` PK parse fragile | Confirmed insert `.parsed` is a CSV `str`; hardened `_extract_pks` (bytes + case-insensitive header) and added a `pk_warning` + log when PKs can't be captured (was silent → would break FK chaining). | ✅ |
| 6 | Sync httpx in async tools | Accepted for now (documented above). | ⏳ defer |

All modified modules `py_compile` clean; no unused imports; ported-logic unit tests (8) pass. Full `pytest`/`flake8`
+ real import + schema-diff parity still pending the repo venv.

---
**Decision:** Option 2 — one MCP server (`lcp-mcp-server`) fronting **two backends**: the LCP API plugin
(modern records) **and** the ADG Appian app Web APIs (for what the plugin can't do — CDT/DSE, etc.).
Retire the separate DG MCP server (`@appian-data-generator`).

**Hard requirement (user):** the LCP MCP server must expose **exactly the same tools** (names + argument
schemas + behavior) as the DG server today, so steering/agent references don't have to change beyond
dropping the DG server from the manifest. This doc is the authoritative parity map.

---

## 1. Why two backends are unavoidable

The LCP API plugin (per its SDK) exposes: `record_data` (insert/update/delete/list), `record_types`
(incl. `list_record_type_fields`, `get_record_type_by_uuid`), `groups` (`list_group_members`,
`get_group_by_name`, …), `documents`, and full design-object management. It has **no** data-store /
CDT / entity API. DG's CDT/DSE tools are backed by **custom ADG Appian expression rules** (`a!writeToDataStoreEntity`),
which no platform plugin provides. Therefore the ADG app must remain a backend; the LCP MCP server will
hold **two clients**:

- **`LcpPluginClient`** (existing) — LCP API plugin (records, fields, groups, documents).
- **`AdgClient`** (ported verbatim from DG's `client.py`) — ADG Web APIs: `/suite/webapi/record/*`,
  `/suite/webapi/users/*`, `/suite/webapi/cdt/*`. Uses the ADG env URL + API key (same config DG uses today).

**Guiding principle for parity:** port each DG tool **backed by the same ADG Web API it uses today**, so
behavior is byte-for-byte identical. Adopt LCP-native APIs only where they are a strict improvement
(the new bulk tool; optionally `get_record_properties`) and only if output shape is preserved.

---

## 2. Complete DG tool inventory → LCP parity map (16 tools)

Legend for **Backend in LCP server**: `ADG` = call the ADG Web API via the ported `AdgClient` (identical to
today); `LCP` = use the LCP plugin natively (only where output/behavior preserved); `LOGIC` = pure Python
ported into the LCP server.

| # | Tool (name unchanged) | Exact args | Today's backend (DG) | Backend in LCP server | Parity risk |
|---|-----------------------|-----------|----------------------|-----------------------|-------------|
| 1 | `get_record_properties` | `record_type_uuid`* | ADG `/record/properties` | **ADG** (keep identical). *Optional later:* LCP `list_record_type_fields` — but must preserve DG output shape incl. `isCustomRecordField` | LCP native omits custom/computed fields → keep ADG for exact parity |
| 2 | `create_record` | `record_type_uuid`, `fields`, `related_records[{relationshipName, recordType, records}]` | ADG `/record/create` | **ADG** (LCP insert is flat CSV — no related-records-in-one-call) | Must stay ADG to keep related-records semantics |
| 3 | `update_record` | `record_type_uuid`*, `record_id`*, `fields`* | ADG `/record/update` | **ADG** | none if ADG |
| 4 | `delete_record` | `record_type_uuid`*, `record_id`* | ADG `/record/delete` | **ADG** | none if ADG |
| 5 | `query_records` | `record_type_uuid`*, `filters[{field,operator,value}]`, `selected_fields`, `paging_info` | ADG `/record/query` | **ADG** (LCP `list_record_type_data` filter support unconfirmed — see §4) | keep ADG unless LCP filters verified |
| 6 | `list_users` | `groups[]` | ADG `/users/list` (effective/nested members, union) | **ADG** (or LCP `list_group_members` + union logic if member semantics match) | ADG safest; LCP native needs nested-member + union parity check |
| 7 | `get_session` | — | in-memory `SessionManager` | **LOGIC** (port `SessionManager`) | none |
| 8 | `rollback_session` | `confirm`* | deletes tracked rows via ADG `/record/delete` (+ CDT) | **LOGIC** + ADG | none |
| 9 | `write_data_store_entity` | `constant_name`*, `cdt_type` \| `namespace`+`cdt_name`, `fields`*, `pk_field` | ADG `/cdt/write` | **ADG ONLY** (no LCP equivalent) | must stay ADG |
| 10 | `get_cdt_properties` | `cdt_type` \| `namespace`+`cdt_name` | ADG `/cdt/properties` | **ADG ONLY** | must stay ADG |
| 11 | `query_data_store_entity` | `constant_name`*, `filters`, `selected_fields`, `paging_info` | ADG `/cdt/query` | **ADG ONLY** | must stay ADG |
| 12 | `verify_write_coverage` | `required_tables[]` \| (`table`*, `mechanism`, `record_type_uuid`, `constant_name`, `filters`, `min_rows`) | LOGIC + `query_records`/`query_data_store_entity` | **LOGIC** (+ ADG for the queries) | none |
| 13 | `list_documents` | `application_name`* | LOGIC + `query_records` on `ADG_Application`/`ADG_Document` | **LOGIC** (+ ADG query, or LCP record query) | none |
| 14 | `find_document` | `application_name`*, `query`* | LOGIC + `query_records` + description ranking | **LOGIC** (+ ADG/LCP query) | none |
| 15 | `to_record_csv` | `record_type_uuid`*, `rows`*, `include_pk` | LOGIC + `get_record_properties` | **LOGIC** (field types from ADG or LCP `list_record_type_fields`) | none — port `csv_format.py` |
| 16 | `expand_record_csv` | `record_type_uuid`*, `template`*, `fk_binding`, `row_count`, `seed`, `batch_size`, `include_pk` | LOGIC + `get_record_properties` | **LOGIC** (same as above) | none — port `csv_format.py` |

*`*` = required arg.*

**Net:** for exact parity, **8 tools stay ADG-backed** (1–6, 9–11), **6 are pure logic ports** (7–8, 12–16
minus overlap), all with **identical names + arg schemas**. Nothing about the tool *interface* changes —
only which server hosts them.

---

## 3. New tool added during consolidation (the context fix)

| Tool | Args | Backend | Purpose |
|------|------|---------|---------|
| `generate_and_insert_records` | `record_type_uuid`*, `template`*, `fk_binding` \| `row_count`, `seed`, `batch_size`, `parent_pks`/aliases | **LCP native**: `list_record_type_fields` + `insert_record_type_data` + ported expand/format | Bulk executor. Expands spec → formats CSV → inserts in ≤1000 batches → returns ONLY `{inserted_count, pk_ranges, pk_list}`. The multi-thousand-row CSV and the echoed insert rows **never leave the server** → removes the context blowup that killed bulk runs at ~250 rows. |

Existing `insertRecordData` (+ list/update/delete record data) stay as-is on LCP.

---

## 4. Items to VERIFY before/while building

1. **LCP `list_record_type_data` filter support — RESOLVED: paging only (`limit`/`offset`), NO filters.**
   Therefore `query_records` (filters by `{field, operator, value}`) **must stay ADG-backed** — it cannot be
   LCP-native. (This also means `verify_write_coverage`, `list_documents`, `find_document` — which rely on
   filtered queries — use the ADG query path.)
2. **`get_record_properties` output shape.** DG returns `isCustomRecordField` (used to exclude computed
   fields like `factorFieldsBlank`). If we ever switch it to LCP `list_record_type_fields`, add an adapter so
   the output shape + custom-field exclusion is preserved. Default: keep ADG.
3. **`list_users` nested-member + union semantics.** DG returns effective (nested) members across a union of
   groups (D7/D9). If using LCP `list_group_members`, confirm it returns nested members; else keep ADG.
4. **ADG env config in the LCP server.** The `AdgClient` needs the ADG app's env URL + API key (same as DG
   uses now). Both backends target the same Appian env, so one set of creds likely suffices — confirm.

---

## 5. Modular architecture in the consolidated server (ADG isolated, LCP-only future updates)

**Requirement:** the ADG-backed functionality must be a **self-contained module** inside the LCP MCP server,
so that (a) all future MCP-server changes happen in the **one LCP repo**, and (b) any ADG-backed capability
can be **swapped for an LCP-native implementation later** (if/when the plugin gains it) without touching the
rest of the server. The ADG **Appian application** remains the backend *service* for CDT/DSE etc.; only the
MCP-*server* code consolidates.

**Backend abstraction (the key to swappability):** tools depend on **capability interfaces**, not concrete
clients. Each interface has an ADG implementation now and can get an LCP implementation later; a small
factory/config picks the implementation per capability (default = ADG for exact parity).

```
src/lcp_mcp_server/
├── backends/
│   ├── lcp_plugin/            # existing LCP API plugin client (native records/fields/groups/documents)
│   └── adg/                   # ⬅ SELF-CONTAINED ADG MODULE (everything ADG lives here, nothing else imports its internals)
│       ├── client.py          # AdgClient → /suite/webapi/record/*, /users/*, /cdt/*  (ported from DG client.py)
│       ├── session_manager.py # ported verbatim
│       ├── csv_format.py       # expand_rows + build_record_csv + generators (ported)
│       └── config.py           # ADG_ENV_URL / ADG_API_KEY (isolated config)
├── backends/interfaces.py      # Protocols: RecordBackend, UserBackend, CdtBackend, DocsBackend, CoverageBackend
├── backends/factory.py         # picks impl per capability (env/flag; default ADG); ONE place to re-point to LCP-native later
├── tools/
│   ├── (existing lcp tools: insertRecordData, listRecordData, …)
│   ├── generate_and_insert.py  # NEW, LCP-native bulk executor
│   └── data_generator/         # the 16 DG-parity tools (same names/args), thin — call interfaces, not clients directly
│       └── __init__.py         # register_tools(mcp) — additive; deleting this dir cleanly removes all 16
└── server.py                   # calls each module's register_tools()
```

**Modularity rules:**
- **Nothing outside `backends/adg/` imports ADG internals** — only through the capability interfaces. Removing
  CDT/DSE later = delete `backends/adg/` + the CDT tools; the rest is untouched.
- **Tools are thin adapters** over interfaces → re-backing a tool (e.g. `query_records` ADG→LCP once the
  plugin supports filters) is a one-line factory change, not a tool rewrite.
- **ADG config is namespaced** (`ADG_*`) and separate from the LCP plugin config, so the two backends are
  independently configurable (both may reuse the same Appian env creds — confirm in §4.4).
- **Self-registering tool packages** (`register_tools`) so adding/removing a capability module is localized.

Config: existing LCP plugin settings + `ADG_ENV_URL`/`ADG_API_KEY` (isolated in `backends/adg/config.py`).

## 5b. Which capability each interface covers (parity defaults)

| Interface | Tools it serves | Default impl | Future LCP-native? |
|-----------|-----------------|--------------|--------------------|
| `RecordBackend` | create/update/delete/query_records, get_record_properties | **ADG** | update/delete/props maybe; **query_records stays ADG** (LCP list is paging-only, no filters — see §4) |
| `UserBackend` | list_users(groups) | **ADG** | LCP `list_group_members` if nested-member+union parity holds |
| `CdtBackend` | write/get_cdt_properties/query_data_store_entity | **ADG only** | never (no LCP DSE support) |
| `DocsBackend` | list_documents/find_document | **ADG** (query ADG_Document) | LCP record query later |
| `CoverageBackend` | verify_write_coverage | **LOGIC** (+ Record/Cdt backends) | n/a |
| (pure logic) | to_record_csv, expand_record_csv, session, generate_and_insert_records | **LOGIC / LCP-native** | n/a |

---

## 6. Sequencing

1. **Define capability interfaces** (`backends/interfaces.py`) + a `factory` (default → ADG).
2. **Build the self-contained `backends/adg/` module**: port `client.py`, `session_manager.py`,
   `csv_format.py`, `config.py` verbatim from DG; implement the interfaces as `Adg*Backend`.
3. **Reproduce the 16 tools** in `tools/data_generator/` with identical names/schemas, written as **thin
   adapters over the interfaces** (never importing ADG internals directly). Copy DG's tests.
4. **Add `generate_and_insert_records`** (LCP-native) — the bulk executor.
5. **Parity test:** run DG's ported suite against the LCP-hosted tools; schema-diff tool names + args
   DG↔LCP — must be identical for the 16.
6. **Switch the agent:** drop `@appian-data-generator` from `settings/mcp.json` + `agents/sql-forge.json`;
   tool *names* unchanged so steering barely changes — merge the DG tool catalog into `tool-references`,
   point bulk Step 6 at `generate_and_insert_records`.
7. **Retire** the DG MCP server after parity sign-off. All future MCP-server changes now happen in the LCP
   repo; the ADG module is the single place ADG-backed behavior lives.

## 7. Acceptance (exact parity + modularity)

- [ ] A schema diff shows the LCP server exposes all 16 DG tool names with **identical argument schemas**.
- [ ] DG's ported unit tests pass against the LCP-hosted implementations.
- [ ] **All ADG-dependent code lives under `backends/adg/`; nothing outside it imports ADG internals** (only
      via capability interfaces) — verified by an import-boundary check.
- [ ] **Deleting `backends/adg/` + the CDT tools removes CDT/DSE cleanly** with no breakage elsewhere
      (modularity smoke test).
- [ ] Re-backing one capability (e.g. `list_users`) to LCP-native is a **factory-only change** (no tool edits).
- [ ] CDT/DSE tools (9–11) work via the ADG backend from the LCP server (live check).
- [ ] `generate_and_insert_records` loads a large table end-to-end with **no CSV in the agent context**.
- [ ] Agent runs with **only** `@appian-atlas` + `@lcp-mcp-server`; DG server removed; bulk + single both pass.

## 8. Risks

| Risk | Mitigation |
|------|-----------|
| Behavioral drift when re-backing a tool (e.g. ADG→LCP) | Default to the **same ADG backend**; only adopt LCP-native where output verified identical |
| Two backends' creds/config in one server | Reuse the single Appian env creds; document both |
| Tool-name collisions with existing LCP tools | None expected (DG names are distinct from `insertRecordData` etc.); verify at build |
| CDT/DSE still coupled to the ADG app | Accepted — inherent; the ADG app remains the CDT/DSE backend regardless of MCP fronting |
