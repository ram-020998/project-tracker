# 02 — The Knowledge Base

The Atlas Knowledge Base (KB) is the versioned, structured representation of every parsed Appian application. It lives in `solutions-os` at:

```
ai-framework/tools/Atlas/solutions-kb/data/<AppName>/
```

- **GitLab project ID:** `13490`
- **Data prefix:** `ai-framework/tools/Atlas/solutions-kb/data`
- **Branch:** `main`

---

## Applications Currently in the KB (~16)

AiDocumentBuilder · AiDocumentCenter · AwardManagement · CaseManagementStudio · ClauseAutomation · ConnectedClaimsManagement · ConnectedUnderwriting · ContractWriting · GamSuiteModule · ProcureSightEnterprise · ProcureSightPlus · RequirementsManagement · SourceSelection · UserAccessManagement · VendorManagement (+ others as synced).

---

## Per-Application Directory Layout

```
data/<AppName>/
├── app_config.json            # application name, version constant, max retained releases
├── release_index.json         # list of releases with change summaries + latest pointer
├── current/                   # the latest parsed snapshot (full detail)
│   ├── app_overview.json      # metadata, object counts, bundle index, dependency summary, coverage
│   ├── search_index.json      # name → {uuid, type, bundles, inbound/outbound counts}
│   ├── manifest.json
│   ├── graph.json             # full dependency graph
│   ├── parsed_state.json      # full parsed state (used for delta parsing)
│   ├── orphans_index.json
│   ├── bundles/               # one JSON per bundle (structure + code)
│   │   └── <BundleName>.json
│   ├── objects/               # per-object detail keyed by UUID/URN
│   │   └── <uuid>.json
│   ├── code/                  # SAIL code keyed by UUID
│   ├── documents/             # binary/doc assets (e.g. images)
│   ├── enrichment/            # object_enrichments.json (tags, stats, paths)
│   └── schema/                # database schema (DDL replay output)
│       ├── tables.json
│       ├── relationships.json
│       ├── reference_data.json
│       ├── insertion_order.json
│       ├── record_type_map.json
│       ├── field_map.json
│       ├── table_classification.json
│       └── summary.json
├── history/                   # per-object historical snapshots (many entries)
├── release_snapshots/         # frozen snapshot per release
│   └── <version>/
│       ├── app_overview.json
│       └── manifest.json
└── changelogs/                # per-release diff files
    └── <version>.json
```

---

## Key Output Files

### `app_overview.json`
The single richest file. Keys: `_metadata`, `description`, `domains`, `capabilities`, `cross_app_dependencies`, `package_info`, `object_counts`, `bundles`, `dependency_summary`, `coverage`.

Example (SourceSelection current / 3.0.0):
- 2,030 AS_GSS objects; counts include 1,063 Expression Rules, 542 Interfaces, 133 Process Models, 58 Record Types, 651 Constants, 107 CDTs, 9 AI Skills, 3 Sites
- `dependency_summary.most_depended_on` surfaces hub objects, e.g. `AS_GSS_Evaluation_SYNCEDRECORD` (187 inbound), `AS_GSS_QR_getEvaluation` (69 inbound)

### `search_index.json`
`name → {uuid, type, bundles, inbound_count, outbound_count}` — the lookup the MCP server uses for object search and dependency tracing.

### `bundles/<Name>.json`
Self-contained functional flow. Keys: `_metadata`, `entry_point`, `flow`, `members`, `key_objects`. Large bundles also split into `structure.json` + `code.json` in the split architecture.

### `schema/*` (for QE/data tooling)
| File | Content |
|------|---------|
| `tables.json` | Table definitions with columns, types, PKs |
| `relationships.json` | FK graph (from_table, to_table, columns) |
| `reference_data.json` | Ref table metadata (UUID, row_count, ref_types) |
| `insertion_order.json` | Topologically sorted table list |
| `record_type_map.json` | Table → record type UUID + relationships |
| `field_map.json` | UPPER_SNAKE column → camelCase field name |
| `table_classification.json` | business / reference / audit / task_management / framework |

---

## Versioning Model

- Each app retains multiple releases (configurable via `max_retained_releases` in `app_config.json`).
- `release_index.json` lists every release with a `change_summary` (objects/bundles added, modified, removed, unchanged) and a `latest_release` pointer.
- `changelogs/<version>.json` holds the detailed diff:
  - `summary` — counts
  - `object_changes[]` — `{uuid, name, type, status (added/modified/removed), old_hash, new_hash, affected_bundles}`
  - `bundle_changes[]` — `{bundle_id, bundle_type, status, members_added[], members_removed[]}`

### Example — SourceSelection release history
| Version | Appian | Objects | Δ vs previous |
|---------|--------|---------|----------------|
| 25.03.02.06.00 (2.6.0) | 25.03 | 2,437 | baseline |
| 25.03.02.07.00 (2.7.0) | 25.03 | 2,466 | +29 obj, 68 mod, +4 bundles |
| 25.04.02.08.00 (2.8.0) | 25.04 | 2,577 | +111 obj, 45 mod, +8 bundles |
| 25.04.02.09.00 (2.9.0) | 25.04 | 2,705 | **+128 obj, 56 mod, +19 bundles** |
| 26.03.03.00.00 (3.0.0) | 26.03 | 2,750 | +45 obj, 29 mod, **−1 bundle** |

> Example of a real, business-meaningful change captured: in **2.8.0** the *Create Evaluation* form gained an **Award Instrument Type** selector (IDIQ/FSS/GWAC/…), and in **2.9.0** a complete **AI Vendor Analysis** feature was added (Start Analysis action, 5 AI skills, 7 record types, 11 process models, 22 interfaces).

---

## The Sync Pipeline

`solutions-kb/sync_packages.py` keeps the KB current:

1. Downloads the **FULL** package for each app from the Appian package API (`eng-test-solutions-package-repo...`).
2. Detects the package version (parses the version constant, e.g. `AS_GSS_TXT_APPLICATION_VERSION`).
3. Compares against `release_index.json`'s latest:
   - **First parse** → full parse (baseline)
   - **New version** → full parse → new release
   - **Same version** → fetch DELTA package (`-d:m~1`) → delta parse
4. Supports parallel sync (`--parallel --workers N`) and single-app sync (`--app <Name>`).

CI is wired via `.gitlab-ci-sync.yml` (run manually or scheduled; set `APP_NAME` variable to target one app).
