# 01 — Architecture

## Overview

Atlas is a layered platform. Each layer has a single responsibility and a clean handoff to the next:

```
┌──────────────────────┐   ┌───────────────────────┐   ┌────────────────────────┐   ┌──────────────────┐
│  Appian Packages     │──►│  Atlas Parser         │──►│  Atlas Knowledge Base  │──►│  Atlas MCP Server │──► AI agents / tools
│  (.zip XML/XSD)      │   │  (parse + resolve)    │   │  (versioned JSON)      │   │  (read-only, MCP) │
└──────────────────────┘   └───────────────────────┘   └────────────────────────┘   └──────────────────┘
```

---

## Layer 1 — Atlas Parser (`solutions-atlas-parser`)

A standalone Python 3.10+ library (**zero runtime dependencies — stdlib only**) that converts opaque Appian exports into human-readable, structured JSON.

### The Problem It Solves
Appian exports applications as ZIPs containing thousands of XML files full of:
- Opaque UUIDs: `#"_a-0006eed1-..._43398"`
- Record Type URNs: `urn:appian:record-field:v1:{rt_uuid}/{field_uuid}`
- Translation URNs: `urn:appian:translation-string:v1:{uuid}`

The parser resolves these into readable names: `rule!AS_GSS_BL_validateVendors`, `recordType!Vendor.vendorName`, `"Bonding Required To Bid"`.

### The Pipeline (`cli.py:dump_package`)
Runs sequentially:

1. **Extract** — `PackageReader.read()` unzips to a temp dir, discovers XML/XSD files
2. **Classify** — `TypeDetector.detect()` reads the XML root tag → maps to one of 17 object types
3. **Parse** — `ParserRegistry` routes to a type-specific parser (15 parsers + 1 fallback)
4. **Hash** — `DiffHashService` produces a SHA-512 per object for change detection
5. **Resolve** — `ReferenceResolver.resolve_all()` replaces UUIDs/URNs with names (in-place mutation)
6. **Analyze** — `DependencyAnalyzer` extracts inter-object dependencies (regex on SAIL + structural UUID fields)
7. **Enrich** — `Enricher` adds tags, statistics, critical paths, dependency depths
8. **Output** — writers produce the final directory structure

### Object Types (17)
AI Skill, Application, CDT, Connected System, Constant, Data Store, Decision, Document, Expression Rule, Folder, Group, Integration, Interface, Process Model, Record Type, Site, Web API.

### Notable Parsers
- `process_model_parser.py` — the largest (~1,486 LOC, 80+ node types)
- `record_type_parser.py` — fields, relationships, views, actions
- `interface_parser.py` — SAIL UI definitions

### Reference Resolution (in-memory, no I/O)
- **UUIDResolver** — `#"_a-0006eed1-..."` → `rule!Name` (canonical prefix matching for cross-app suffixes)
- **RecordTypeURNResolver** — RT URN → `recordType!Vendor.vendorName`
- **TranslationResolver** — translation URN → translated text (locale-aware with fallback)
- Field paths are declaratively configured in `domain/constants.py` (`SAIL_CODE_FIELDS`, `UUID_FIELDS`, `STRUCTURAL_FIELDS`); `field_walker.py` walks dotted paths like `nodes[].inputs[].input_expression`.
- **Accuracy:** ~99.95% for UUIDs, ~93–98% for RT URNs.

### Dependency Types
`CALLS`, `USES_CONSTANT`, `USES_CDT`, `USES_RECORD_TYPE`, `USES_INTEGRATION`, `USES_CONNECTED_SYSTEM`, `USES_GROUP`, `USES_DATA_STORE`.

### The Bundle System
6 bundle types, each a self-contained functional flow discovered via entry-point detection + BFS graph traversal:

| Type | Entry Point | Captures |
|------|-------------|----------|
| action | Record Type Action | Action → process model → form → all deps |
| process | Standalone Process Model | PM not triggered by any action/subprocess |
| page | Record Type Views | Summary/detail views → interfaces → deps |
| site | Site | Navigation → all page targets → interfaces |
| dashboard | Control Panel | Dashboard → interfaces → record types |
| web_api | Web API | API endpoint → all called rules/integrations |

Bundles are split into `structure.json` (metadata, always loaded) and `code.json` (SAIL, on demand) to prevent LLM context overflow.

### The Schema Module (DDL Replay Engine)
`appian_parser/schema/ddl_replay_engine.py` replays SQL DDL statements (CREATE / ALTER / DROP / INSERT / UPDATE) to reconstruct database schema state — tables, columns, primary keys, foreign keys, and reference data. This powers the schema tools used by the QE/data-generation tooling. Outputs: `tables.json`, `relationships.json`, `reference_data.json`, `insertion_order.json`, `record_type_map.json`, `field_map.json`, `table_classification.json`.

### Design Principles
Zero runtime dependencies · single responsibility · open/closed (new type = new parser + registry entry) · declarative field paths · in-memory resolution · fail-fast-but-continue · immutable value objects · content hashing.

### Performance Baseline (MacBook Pro M1, 16GB)
~2,500 objects: ~1.9s, ~450MB peak · ~3,500 objects: ~2.7s, ~620MB peak.

---

## Layer 2 — Knowledge Base

Parsed output is committed to a versioned KB inside `solutions-os` at `ai-framework/tools/Atlas/solutions-kb/data/<AppName>/`. See [02-knowledge-base.md](./02-knowledge-base.md) for the full layout and versioning model.

---

## Layer 3 — Atlas MCP Server (`solutions-atlas-mcp-server`)

A Python/Docker MCP server (`atlas_mcp` package) that reads the KB and exposes it to AI assistants — **read-only by design**.

- **Data source:** `GitLabDataSource` reads JSON via the GitLab API, with an LRU cache (500 entries) + pinned anchor files (`app_overview.json`, `search_index.json`, `orphans/_index.json`)
- **Security:** `AtlasTokenValidator` refuses to start if the token has any write/admin scope (only `read_api`, `read_repository`, `read_user`, `read_registry` allowed)
- **Transport:** stdio MCP; entry point `main.py` → `AtlasMCPServer`
- **Distribution:** Docker image via GitLab Container Registry, CI/CD via `.gitlab-ci.yml`

See [03-mcp-servers.md](./03-mcp-servers.md) for the full tool catalog.

---

## Layer 4 — Tools Built on Atlas

Any AI-agent tool can sit on top of the MCP layer without re-parsing XML. See [04-tools-built-on-atlas.md](./04-tools-built-on-atlas.md) for the full catalog (SQL Forge, Locust Forge, ERD-Gen, role-specific powers, etc.).

---

## Data Flow Summary

```
appian-parser                solutions-kb (GitLab)             solutions-atlas-mcp-server
─────────────                ─────────────────────             ──────────────────────────
ZIP → parse → JSON  ─commit─► data/<AppName>/            ◄─API─ GitLabDataSource
                              ├── app_overview.json              │
                              ├── search_index.json              ▼
                              ├── bundles/<Name>/         MCP tools exposed to agents
                              │   ├── structure.json
                              │   └── code.json
                              ├── objects/<uuid>.json
                              ├── schema/
                              ├── changelogs/
                              ├── release_snapshots/
                              └── orphans/
```
