# ERD-Gen CLI Tool — Project Tracker

## Overview

A self-contained CLI tool (Go binary) that generates Lucidchart ERD diagrams from a structured JSON schema definition. Designed to be called by AI agents (atlas-sql-forge power) or manually.

**Repo:** https://gitlab.appian-stratus.com/ramaswamy.u/erd-gen
**Local:** /Users/ramaswamy.u/repo/erd-gen

## Status

**Phase: Layout & Rendering Quality** — Core pipeline works (JSON → layout → .lucid → upload) but visual output needs significant improvement.

## Session Log

### 2026-05-25 — Initial Build & Discovery

#### Completed
- Created standalone Go repo at `/Users/ramaswamy.u/repo/erd-gen`
- Implemented Sugiyama-style layered layout engine (BFS layering, barycenter crossing minimization)
- Implemented Lucid Standard Import renderer (rectangles + elbow lines + crow's foot notation)
- Implemented ZIP packaging (.lucid output)
- Implemented Lucid REST API upload with `--upload` flag
- Fixed MIME type issue (must send `x-application/vnd.lucid.standardImport`)
- Pushed to GitLab: `ramaswamy.u/erd-gen`
- Added Source Selection test fixture at `testdata/SourceSelection.json`
- Successfully uploaded ERD to Lucidchart (29 tables, 63 relationships)

#### Decisions Made
- **Go over Python/Rust** — stdlib has ZIP, HTTP, JSON; cross-compile is trivial; single binary ~8MB
- **Separate repo from power** — agent installs binary from releases, not bundled in power
- **Lucid Standard Import over Draw.io** — Direct API upload, no manual file import needed
- **Rectangle shapes (not native ERD blocks)** — `ERDEntityBlock2`/`ERDEntityBlock3` are NOT supported by Standard Import API (confirmed via Lucid community forum)
- **`table` shape type exists** — accepts keys: `id, type, x, y, w, h, text, style, rows` — but correct `rows` format is still unknown

#### Learnings — Lucid Standard Import API
- `.lucid` file = ZIP containing `document.json`
- Upload via `POST https://api.lucid.co/v1/documents` with OAuth2 bearer token
- File part MUST have `Content-Type: x-application/vnd.lucid.standardImport` (not `application/octet-stream`)
- Cannot import `.lucid` files via Lucidchart UI — UI import only accepts: `.vdx, .vsd, .vsdx, .vsdm, .pdf, .graffle, .xml, .drawio, .gxml, .gliffy, .bpmn, .xpdl`
- Native ERD shapes (`ERDEntityBlock2`, etc.) are NOT supported in Standard Import
- `rectangle` shape uses `boundingBox: {x, y, w, h}` + `style.fill: {type: "color", color: "#hex"}`
- `table` shape uses flat `x, y, w, h` (NOT `boundingBox`) + has `rows` property
- `table` type does NOT accept `style`, `cells`, `rowCount`, `colCount`, `boundingBox`
- Valid `table` keys: `id, type, x, y, w, h, text, rows`
- Endpoint styles for ERD: `exactlyOne`, `zeroOrMore`, `zeroOrOne`, `oneOrMore`
- Lines: `lineType: "elbow"` with `shapeEndpoint` type
- Lucid MCP server is docs-only (search their documentation), NOT functional API

#### Issues Encountered
- `table` type with `rows: [["PK", "ID"]]` → error about `cells`/`rowCount`/`colCount` undefined
- `table` type with `rows: [{"text": "PK | ID"}]` → same error
- Rectangles with plain text render poorly — no column alignment, no row separators
- Layout overlaps — NodeGap too small, tables in middle layers collide
- Diagram too wide at 8 layers × 380px
- The power's steering wasn't directing agent to use the erd-gen binary (agent wrote Python instead)

#### Architecture
```
erd-gen/
├── schema/schema.go      # Input JSON types (Table, Field, Relationship)
├── layout/layout.go      # Sugiyama layered graph layout engine
├── lucid/render.go       # Lucid Standard Import renderer
├── main.go               # CLI (--input, --output, --upload, --token, --version)
├── testdata/
│   └── SourceSelection.json
├── go.mod
├── .gitignore
└── README.md
```

---

## Next Steps

### Immediate (unblock visual quality)

- [ ] **Resolve `table` shape `rows` format** — 3 test files created at `/tmp/table-test-{1,2,3}.lucid` to try different `rows` formats (strings, arrays, number). Upload and see which succeeds.
- [ ] **If table works** → update renderer to use proper `table` type with columns
- [ ] **If table doesn't work** → Fall back to **Draw.io XML** output (`.drawio` imports cleanly into Lucidchart via UI, supports proper table cells with `shape=table` mxGraph format)

### Layout improvements

- [ ] Increase NodeGap (50 → 80+) to prevent vertical overlap
- [ ] Reduce LayerGap (380 → 300) to compact width
- [ ] Center layers vertically (align midpoints)
- [ ] Consider max tables per layer (overflow to next column if > 6)

### Power integration

- [ ] Update `action-erd.md` steering to reference the tool by install path (`~/.local/bin/erd-gen`)
- [ ] Add install instructions to steering (curl from GitLab releases)
- [ ] Set up CI pipeline for building release binaries (darwin-arm64, darwin-amd64, linux-amd64)

### Future

- [ ] Multiple pages support (Full view + domain-scoped views)
- [ ] Support updating an existing Lucid document (PATCH/replace)
- [ ] Version flag in document title from input JSON

---

## Reference

### Sample ERD (standard template)
- Export JSON: `/Users/ramaswamy.u/Downloads/GSS ERD - Dev.json`
- Format: Uses `ERDEntityBlock2` class with `textAreas` (Key1/Field1, Key2/Field2 pattern)
- Lines: `CFN ERD One Arrow` / `CFN ERD Many Arrow` for crow's foot

### CLI Usage
```bash
# Generate
./erd-gen --input schema.json --output myapp-erd.lucid

# Generate + upload
export LUCID_API_TOKEN="key"
./erd-gen --input schema.json --upload

# Version
./erd-gen --version  # → erd-gen 0.1.0
```

### Input JSON format
```json
{
  "title": "App ERD",
  "tables": [{"name": "T", "domain": "D", "fields": [{"name": "F", "constraint": "PK|FK|"}]}],
  "relationships": [{"from": "CHILD", "to": "PARENT", "type": "many_to_one"}],
  "domains": {"D": "#color"}
}
```
