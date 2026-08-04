# Phase 16-01 — Native Appian parser (`genesis-appian-parser`)

> **Status:** DRAFT (planning) · **Repo:** `genesis-appian-parser` (NEW, pinned) · **Depends on:** nothing (env-free)
> **Goal:** Stand up a Genesis-owned, stdlib-only Python package that parses an Appian application export ZIP into an
> **in-memory structured result** (objects + dependency edges + bundles + content hashes) — **with no source-code
> persistence and no file output**. This is the port of the proven Atlas parser's front-half into a package Genesis
> owns and evolves. After 16-01, `parse(zip) -> KbParseResult` is a pure, tested function the KB store (16-02) and the
> sync workflow (16-03) build on.

---

## 1. Current state (grounded — the Atlas parser we port from)

`appian/prod/solutions-atlas-parser` (read via glab; stdlib-only, Python 3.10+). Relevant modules:
- `appian_parser/package_reader.py` — `PackageReader.read(zip)` extracts to temp, discovers XML/XSD, returns
  `PackageContents` (+ `cleanup`).
- Type detection — `TypeDetector` (root tag `<interfaceHaul>`/`<processModelHaul>`/`<contentHaul>` → internal type);
  `parser_registry.py` `ParserRegistry.get_parser(type)` (factory; 15 parsers + fallback).
- `appian_parser/parsers/*` — 15 type parsers (interface, expression rule/`ai_skill`, process model, record type, CDT,
  integration, web API, site, group, constant, connected system, control panel, decision, data store, document, +
  `application_parser`, `base_parser`).
- `appian_parser/resolution/*` — `uuid_resolver`, `record_type_resolver`, `reference_resolver`, `translation_resolver`,
  `label_bundle_resolver`, `uuid_utils` (resolve `#"_a-…"` → `rule!Name`, record-field/translation URNs → readable).
- `appian_parser/dependencies/analyzer.py` — extracts inter-object deps via SAIL pattern-matching + structured fields.
- `appian_parser/enrichment/*` — depth, edge types, path analysis, statistics, tag classifier, graph enricher.
- `appian_parser/domain/{models,enriched_models,enums,constants,name_utils,appian_type_resolver,field_walker,node_types}`
  — `ParsedObject(uuid, name, object_type, data, diff_hash, source_file)` and the node-type registry.
- `appian_parser/diff_hash.py` — `DiffHashService` (SHA-512 content hash).
- `appian_parser/output/*` — the Atlas **file writers** (bundle/object/code/graph/manifest/search-index/orphan). ~30
  modules. **We do NOT port these** — they write the Atlas JSON tree incl. `code.json`.
- `appian_parser/versioning/*` — `config` (AppConfig/VersionDetector/ReleaseIndexBuilder), `parsed_state`, `delta`
  (`DeltaMerger`/`ModeDetector`), `history`. **We do NOT port these** — versioning moves into `KbStore`'s SCD-2 model
  (16-02); we keep only `VersionDetector.parse_version` if we want optional version-constant reading.
- `appian_parser/schema/*` — DDL-replay / record-type→table mapping. **NOT ported in iteration 1 — Section C
  (schema/DDL/data-gen) is deferred** (scope decision 2026-08-04). The 16 Tier-1 tools need only the object/edge/bundle
  graph, not the DB schema. Port this in the later schema/data-gen phase.
- CLI `python -m appian_parser dump <zip> <out>` + `delta`. We replace the CLI with a library API + an optional thin CLI.

Bundle system (from the parser README): 6 bundle types (action/process/page/site/dashboard/web_api), each a BFS from an
entry point over the dependency graph; `structure.json` (metadata) vs `code.json` (SAIL) split. We keep the **structure**
(and the flow), drop the **code**.

## 2. Design

### 2.1 New repo & packaging
- New GitLab repo `genesis-appian-parser` (mirrors the four-repo discipline). Python **3.13** (Genesis pin, ADR-024),
  **stdlib-only** runtime, `pytest`/`ruff` dev deps, its own `.gitlab-ci.yml` (lint + test). Pinned into `genesis` by
  git tag like `genesis-core` (ADR-019); tag **v0.1.0** at the end of 16-01.
- Package `genesis_appian_parser/` with subpackages mirroring the ported layout: `package_reader.py`, `type_detector.py`,
  `parser_registry.py`, `parsers/`, `resolution/`, `dependencies/`, `domain/`, `bundles/`, `diff_hash.py`, `result.py`,
  `api.py`.

### 2.2 The public API (the whole point)
```python
# genesis_appian_parser/api.py
def parse(source: str | bytes, *, locale: str = "en-US",
          exclude_types: list[str] | None = None) -> KbParseResult: ...
```
- Accepts a zip path or bytes (the sync workflow holds the export in the blackboard). Unzips to a temp dir, parses,
  resolves references, builds the graph + bundles + hashes, returns an **in-memory** result, cleans up the temp dir.
- **Never writes files. Never returns SAIL.** SAIL is parsed only to extract dependency references + descriptions, then
  discarded.

### 2.3 The result model (`result.py`) — what the KB store consumes
```python
@dataclass(frozen=True)
class KbObject:
    object_uuid: str
    name: str
    type: str                     # "Interface", "Expression Rule", ...
    qname: str | None             # namespaced QName when present (Phase-12 lesson)
    type_id: str | None
    description: str | None
    diff_hash: str                # SHA-512 of canonical content
    is_entry_point: bool
    entry_point_kind: str | None  # action|process|page|site|dashboard|web_api
    metadata: dict                # parameters, output type, record fields, site targets, ... (NO SAIL)

@dataclass(frozen=True)
class KbEdge:
    source_uuid: str
    target_uuid: str
    dep_type: str                 # rule_call|interface_call|constant_ref|record_ref|...

@dataclass(frozen=True)
class KbBundle:
    bundle_id: str
    bundle_type: str
    root_uuid: str
    name: str
    parent_name: str | None
    key_objects: list[str]        # names of the key objects (for the overview/search cards)
    flow: list[str]               # the textual traversal ("Action: … → Process Model: … → Interface: …") — get_bundle returns this verbatim (see genesis-kb-tool-contracts.md §2.10)
    members: list[KbBundleMember] # object_uuid + role(entry_point|member) + flow_order

@dataclass(frozen=True)
class KbParseResult:
    application: KbApplicationInfo # name, app_uuid (if resolvable), version(raw) if version_constant given, counts
    objects: list[KbObject]
    edges: list[KbEdge]
    bundles: list[KbBundle]
    orphans: list[str]            # object_uuids unreachable from any entry point
    errors: list[ParseError]      # per-file parse errors (non-fatal)
    stats: dict                   # object_counts by type, dep counts by type, coverage
```

### 2.4 Port scope
- **Port as-is (adapt imports/style):** `PackageReader`, `TypeDetector`, `ParserRegistry` + the 15 `parsers/`,
  `resolution/*`, `dependencies/analyzer.py`, `domain/*` (`ParsedObject` + node-type registry), `diff_hash.py`, and the
  **bundle builder** (extract the entry-point discovery + BFS logic from Atlas `output/bundle_*`/`graph_builder`,
  keeping only the structural parts).
- **Rewrite:** the output layer → build `KbParseResult` from the parsed objects + graph + bundles (no files).
- **Drop:** all Atlas `output/*` file writers, `code_file_builder`, `versioning/*` (moves to KbStore), the CLI's file
  modes. Keep an optional `python -m genesis_appian_parser dump <zip>` that prints a JSON summary (no code) for manual
  debugging.
- **Keep the option to read the version constant:** port `VersionDetector.parse_version` so `parse(..., version_constant=)`
  can populate `application.version` when configured (used only as optional metadata; the release model is manual).

### 2.5 Explicitly no code, but SAIL still parsed
The dependency analyzer + reference resolver **require** reading SAIL/structured fields to extract edges + descriptions.
That is fine — the SAIL is read in-memory, references are resolved to build `KbEdge`s, and **the SAIL string is not
placed on any `KbObject`** (`metadata` excludes `sail_code`). A unit test asserts no result field contains a raw SAIL
body (guard against regressions that leak code into the KB).

## 3. Files & tests
- New repo `genesis-appian-parser` with the package layout above, `pyproject.toml` (py3.13, stdlib runtime), `.flake8`/
  `ruff`, `.gitlab-ci.yml` (lint + test), `tests/`.
- **Test against REAL captured packages, not stubs** (Phase-12 lesson). Vendor a real export (or a trimmed real subset)
  as a fixture — e.g. a `SourceSelection` slice — and assert:
  - object counts by type match expectations; reference resolution turns `#"_a-…"`/URNs into readable names;
  - entry points detected; bundles built per type; BFS membership correct; orphan set computed;
  - `diff_hash` stable + changes when content changes;
  - QName/`typeId` captured when present; preamble/edge-case shapes tolerated;
  - **no `KbObject.metadata` contains SAIL** (the code-leak guard);
  - `parse(bytes)` == `parse(path)`; temp dir cleaned up.
- Coverage gate in CI (like the Atlas parser's cobertura job).

## 4. Acceptance criteria
1. New repo builds; `genesis_appian_parser` installs stdlib-only; CI lint + test green; tagged **v0.1.0**.
2. `parse(zip) -> KbParseResult` returns objects/edges/bundles/orphans/stats for a real captured package with resolved
   references and correct bundle membership.
3. **No source code is present** in any result field (asserted by test); no files are written.
4. `diff_hash` detects content changes; results are deterministic for the same input.
5. Errors are per-file and non-fatal (a malformed object doesn't abort the parse; it lands in `errors`).

## 5. Out of scope
- The SCD-2 store / versioning / delta merge (16-02).
- Any environment interaction (export/live code) — the parser only consumes a zip.
- The `schema/` data-model (DDL-replay) port — optional future enrichment.
- File output / the Atlas JSON tree / `code.json` — intentionally dropped.
