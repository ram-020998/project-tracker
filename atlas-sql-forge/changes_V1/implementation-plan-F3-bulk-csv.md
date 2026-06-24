# Feature 3 — Bulk Data Generation via CSV Import: Implementation Plan

**Status:** ✅ IMPLEMENTED — `to_record_csv` formatter built + tested; bulk-CSV steering path, SQL-as-fallback, tool references, and `mcp.json` (lcp-mcp-server) applied to both power copies. Remaining: deploy DG MCP image + ensure the LCP plugin/lcp-mcp-server is available in the target env.
**Spec:** `changes_V1/spec.md` §4 (decisions D11–D13)
**Goal:** Make bulk generation go through Appian's record layer using the **existing `insertRecordData`** tool in `solutions-lcp-mcp-server` (record-type UUID + CSV → assigned PKs). The agent calls `insertRecordData` **directly**; the DG MCP gains a **`to_record_csv` formatter** that converts row data into the strict CSV contract the tool requires. **SQL generation stays as a backup** (D12). **No automatic bulk rollback** — cleanup is manual table truncate (D13).

> Smallest of the three features: one DG MCP tool + one steering step + mcp config. No parser, no Atlas MCP, no ADG record/API change.

---

## 1. Current state (grounded)

| Area | Finding |
|------|---------|
| Bulk today | `step-6-generate-sql.md` emits MySQL `INSERT`s with `LAST_INSERT_ID()` chaining + `get_field_map` (camelCase→UPPER_SNAKE) + manual type formatting/escaping. Separate path from records mode. |
| `insertRecordData` | `solutions-lcp-mcp-server/src/lcp_mcp_server/tools/record_data.py`: `insertRecordData(uuid, csvData, versionId=None)` → `lcp_api_plugin_client.api.record_data.insert_record_type_data` (SDK) → **LCP API plugin** in the Appian env. Wraps CSV in `_CsvBody`. Validates ≥1 data row. **Returns inserted rows with assigned PKs.** Companions: `listRecordData`, `updateRecordData`, `deleteRecordData`. Registered via `register_tools(mcp, client)` (FastMCP `@mcp.tool`). |
| CSV contract | Header names must match record **field names** exactly; PK column optional (auto-gen); booleans **`1/0`** (string `true`/`false` rejected); dates `YYYY-MM-DD`; datetimes `YYYY-MM-DD HH:MM:SS`; times `HH:MM:SS`; **UTC**; RFC-4180 quoting; **no embedded JSON**. |
| DG field types | `FieldRegistry.get_record_type(uuid)` → fields with `name`, `field_type` (e.g. Text/Integer/Date/Boolean), `is_primary_key`, `is_custom`; backed by `get_record_properties`. Ideal source for type-correct formatting. |
| Payload shape | `payloads/00-metadata.json` + numbered per-table files: `{table, record_type_uuid, records:[{fields:{...}, output_ref, field_reasoning}]}`; FK via `@alias`; insertion order from `insertion_order.json`. |

**Implication:** the only build work is a deterministic CSV formatter in DG MCP (the value-add that prevents the most common insert failures — wrong boolean/date formatting, unquoted commas), plus a steering step that orchestrates formatter → `insertRecordData` → PK chaining. SQL path is untouched (kept as fallback).

---

## 2. Design (resolved)
- **D11:** do **not** port `insertRecordData`. Agent uses `lcp-mcp-server` directly; DG adds `to_record_csv`.
- **D12:** bulk CSV is the **primary** bulk path; SQL generation is **kept as a backup** (e.g. LCP-plugin-less environments).
- **D13:** **no automatic rollback** for bulk; cleanup by **manual table truncate**. (Session rollback remains only for the interactive record/CDT path.)

### Bulk flow
```
payloads/*.json  ──►  to_record_csv (DG, per record type)  ──►  insertRecordData(uuid, csv) (lcp-mcp-server)
                                                                      │ returns assigned PKs
                                                                      ▼
                                              chain PKs into next table's FK columns (insertion_order)
```

---

## 3. Work item A — DG MCP `to_record_csv` formatter

### A1. Tool
- **New tool class** `CsvTools` in `data_generator/tools/csv_format.py`.
- **Signature (arguments):**
  - `record_type_uuid` (str, required)
  - `rows` (array of objects — field name → value; camelCase field names; FK values already resolved by the agent)
  - `include_pk` (bool, default false)
- **Behavior:**
  1. `registry = get_registry(); info = registry.get_record_type(record_type_uuid)` → field types.
  2. Determine the **column order**: union of keys across `rows` intersected with known fields (skip PK unless `include_pk`, skip `is_custom`). Emit a stable header.
  3. For each row, format each value by `field_type`:
     - Boolean → `1`/`0` (reject/realcast python bool, `"true"/"false"`, 1/0).
     - Date → `YYYY-MM-DD`; Datetime → `YYYY-MM-DD HH:MM:SS`; Time → `HH:MM:SS`; **assume/convert to UTC**.
     - Integer/Decimal → bare number.
     - Text/User → string; **RFC-4180 quote** when the value contains comma/quote/newline (double internal quotes).
     - None/missing → empty field.
  4. Build the CSV with Python's `csv` module (guarantees RFC-4180 quoting) into a string.
- **Returns:** `{ "record_type_uuid": ..., "row_count": N, "csv": "<header+rows>" }` so the agent can hand `csv` straight to `insertRecordData`.
- **No Appian write** — only `get_record_properties` (via registry) is read. Pure, deterministic, unit-testable.

### A2. Register
- `models.py`: add `to_record_csv` input schema to `ToolSchemas.get_all_tools()`.
- `server.py`: add `"to_record_csv": CsvTools.to_record_csv` to `tool_handlers`.
- `tools/__init__.py`: export `CsvTools`.

### A3. Field-type source (resolves spec §4.4 open item F3-Q4)
- Use **`get_record_properties` (live)** via `FieldRegistry` — it is already the authority used by `create_record`, returns concrete `field_type`, and is cached. KB field types are a fallback only if the live call is unavailable. **Decision: live `get_record_properties`.**

### A4. Tests (`tests/test_server.py` or new `tests/test_csv_format.py`)
- Boolean `True/False/1/0/"true"` → `1`/`0`.
- Date/datetime/time formatting + UTC normalization.
- RFC-4180 quoting for commas/quotes/newlines; no-JSON guard (objects/lists → reject with clear error).
- PK excluded by default; included when `include_pk=true`.
- Column order stable across heterogeneous rows; missing field → empty.
- Mock `FieldRegistry`/client so no network.

---

## 4. Work item B — Power steering

### B1. New `steering/step-6-bulk-csv.md` (primary bulk path)
Mirrors `step-6-generate-sql.md` structure (blocking checks, tracker, chunked writes) but executes through the record layer:
1. **Brief user confirmation** (one line: N records across M tables).
2. Read `payloads/00-metadata.json` → `file_sequence` (insertion order).
3. **For each table in order:**
   - Read the numbered payload file → `record_type_uuid` + `records[].fields`.
   - **Resolve `@alias` FK references** from PKs returned by earlier `insertRecordData` calls.
   - Call DG `to_record_csv(record_type_uuid, rows)` → get `csv`.
   - Call **`insertRecordData(uuid=record_type_uuid, csvData=csv)`** (lcp-mcp-server) → capture returned **assigned PKs**; store under each record's `output_ref` alias for downstream FK chaining.
4. **No rollback step** — document that bulk cleanup is a **manual table truncate** (D13). Include the affected table list + a sync reminder (synced record types need a post-insert sync, same caveat as SQL mode).
5. Write `execution-log.md` (mode: Bulk CSV) with per-table row counts and assigned PK ranges.

### B2. Keep SQL as backup
- Leave `step-6-generate-sql.md` and `action-bulk-sql.md` intact (D12).
- **Update `action-bulk-sql.md`** (or `action-generate-data.md` mode selection) to offer two bulk modes: **CSV import (primary)** vs **SQL file (fallback, LCP-plugin-less envs)**. Default to CSV; instruct fallback to SQL when the LCP plugin isn't available.

### B3. Tool reference + MCP config
- **`tool-reference-data-generator.md`:** document `to_record_csv`.
- **New: `tool-reference-lcp.md`** (or a section in the data-generator reference): document `insertRecordData`/`listRecordData`/`updateRecordData`/`deleteRecordData` and the CSV contract.
- **`mcp.json` (power):** add `lcp-mcp-server` as an available MCP server alongside Atlas MCP and DG MCP, with env for the target environment + LCP plugin.
- Apply to **both** power copies (dev `ramaswamy.u/atlas-sql-forge`, prod `appian/solutions-os/.../powers/atlas-sql-forge`).

---

## 5. Cross-cutting

### 5.1 PK chaining
`insertRecordData` returns rows **with assigned PKs**. The steering captures them per `output_ref` alias and substitutes into FK columns of dependent tables, following `insertion_order.json`. The formatter is invoked **per record type** along that order (one `insertRecordData` call per table, batching its rows).

### 5.2 Rollback (D13)
No automatic rollback for bulk. `execution-log.md` records exactly which tables/PK ranges were inserted so an operator can truncate/clean manually. (lcp `deleteRecordData` exists if a targeted cleanup is ever needed, but it is **not** wired into the bulk flow for V1.)

### 5.3 Prerequisite
Bulk CSV requires the **LCP API plugin** deployed/reachable in the target Appian env (that's what `insert_record_type_data` calls). If absent → fall back to SQL (D12). Document in `step-0-initialize.md` env checks.

---

## 6. Sequencing
- A (DG `to_record_csv`) → B1 (bulk-csv step) → B3 (mcp.json + references). B2 (keep/relabel SQL) is independent doc work.
- Fully independent of F1 and F2; can be built in parallel with either.

## 7. Deployment
1. Deploy DG MCP image with `to_record_csv`.
2. Ensure `lcp-mcp-server` is deployed/available for the target env (LCP plugin present).
3. Update both power copies (steering + `mcp.json`); dev first, then prod.
4. Smoke-test: format a small payload → `insertRecordData` into a throwaway record type → confirm PKs returned and FK chaining works.

## 8. Risks & mitigations
| Risk | Mitigation |
|------|-----------|
| LCP plugin not installed in env | Detect in step-0; fall back to SQL mode (D12). |
| Boolean/date mis-format (the classic failure) | Formatter is type-driven from `get_record_properties`; unit tests cover each type; reject embedded JSON with a clear error. |
| Header/field-name mismatch | Header comes from `FieldRegistry` field names (not guessed); validate every payload key against known fields, error on unknown. |
| FK chaining errors (parent PK not captured) | Enforce insertion order; assert each `output_ref` is captured before dependents run; stop on missing alias. |
| Large CSV / row limits | Batch per `insertRecordData` call if needed; document any plugin row cap. |
| Synced record types stale after insert | Include sync reminder in `execution-log.md` (same as SQL mode). |

## 9. Acceptance criteria
- [ ] DG `to_record_csv` produces an RFC-4180 CSV with field-name headers and type-correct values (booleans `1/0`, UTC dates/datetimes/times), PK excluded by default, unknown/JSON values rejected.
- [ ] `step-6-bulk-csv.md` drives: payload → `to_record_csv` → `insertRecordData` → PK capture → FK chaining in insertion order; writes a Bulk CSV execution log.
- [ ] SQL path retained and selectable as fallback; mode selection documents CSV-primary / SQL-fallback.
- [ ] `lcp-mcp-server` present in both power `mcp.json` files; tool references updated.
- [ ] No bulk rollback wired; manual-truncate cleanup documented with affected tables/PK ranges.
- [ ] Unit tests for the formatter pass; end-to-end smoke test inserts and chains PKs in a non-prod env.
