# ERD-Gen CLI Tool — Project Tracker

**Last Updated:** 2026-05-26
**Repo:** https://gitlab.appian-stratus.com/ramaswamy.u/erd-gen
**Local:** /Users/ramaswamy.u/repo-gitlab/ramaswamy.u/erd-gen
**Version:** 1.0.0

---

## Overview

A self-contained Go CLI tool that generates ERD diagrams in Lucidchart from a structured JSON schema definition. Used by the atlas-sql-forge power's `action-erd` steering.

---

## Current Status: ✅ Production Quality

- Zero table crossings (all 63 lines route around obstacles)
- Parallel lines spaced 20px apart (no overlapping)
- Channel-based Manhattan routing with obstacle avoidance
- `elbowControlPoints` + `shapeEndpoint` for crow's foot notation + custom routing
- Domain containers in 3-column grid with 3-column internal table layout
- Proper cell formatting (PK/FK + field names)
- Generate, update, export, share, config commands
- Token stored persistently in `~/.config/erd-gen/config.json`

**Remaining:** Lines still overlap each other in dense areas. Can be further improved with dynamic gap sizing based on line density.

---

## Session Log

### 2026-05-25 — Initial Build

- Created standalone Go repo
- Implemented Sugiyama-style layout (BFS layering, barycenter crossing minimization)
- Discovered Lucid Standard Import format through trial and error
- Successfully uploaded first ERD (rectangles with text — poor formatting)
- Pushed to GitLab

### 2026-05-26 — Format Discovery & v1.0.0

**Routing breakthrough:**
- Discovered `elbowControlPoints` works WITH `shapeEndpoint` (crow's foot + custom routing)
- Built Manhattan router with obstacle avoidance (channel-based Z-routes)
- Achieved **zero table crossings** (63/63 lines route cleanly)
- Added parallel lane spacing (lines sharing a channel offset 20px apart)
- Added containers as obstacles so lines route AROUND containers, not through them

**Layout engine:**
- 3-column grid for containers
- 3-column internal layout for large domains (>6 tables)
- Connectivity-based container ordering (most-connected domains adjacent)
- Tables sorted within domains (externally-connected at edges)
- Dynamic spacing: 200px container gaps, 80px table gaps, 40px internal column gaps

**Key discovery: Table shape format**
- The Lucid docs describe `table` with `boundingBox` + `rowCount` + `colCount` + `cells`
- The API error messages initially said valid keys are `id, type, x, y, w, h, text, rows` (misleading)
- After testing, confirmed the DOCUMENTED format IS correct — the error was from other shapes in the same file
- `rectangleContainer` works perfectly for domain grouping

**Bugs found and fixed:**
1. `stroke` on table shapes breaks cell content — only use `style.fill`
2. `text` field with Go's `omitempty` drops the key when constraint is empty — Lucid needs `"text": ""` always present
3. Row height < 34px makes text invisible
4. `#hex` with alpha channel (8 chars) not supported in `fill.color`
5. Upload requires explicit `Content-Type: x-application/vnd.lucid.standardImport` MIME on file part

**Architecture rebuild to v1.0.0:**
- Subcommand architecture: generate, update, export, share
- `api.go` centralizes all Lucid REST API calls
- Generate: build + upload, returns document ID + URL
- Update: delete old document + create new (full regeneration, not patch)
- Export: GET /documents/{id}/contents
- Share: POST /documents/{id}/shareLinks

**Lucid MCP Server exploration:**
- Official Lucid MCP at `https://mcp.lucid.app/mcp` can create diagrams from text
- Tested: generates ERDs but ignores formatting requirements (no containers, no 2-column tables, no crow's foot)
- Conclusion: MCP is unreliable for precision formatting — CLI approach is correct
- MCP useful for ad-hoc quick diagrams, not production ERDs

---

## Learnings: Lucid Standard Import API

### What Works
| Feature | Format |
|---------|--------|
| Table with cells | `type: "table"` + `boundingBox` + `rowCount` + `colCount` + `cells` |
| Rectangle | `type: "rectangle"` + `boundingBox` + `text` + `style.fill` |
| Container | `type: "rectangleContainer"` + `boundingBox` + `containerTitle` + `magnetize` |
| Lines | `lineType: "elbow"` + `shapeEndpoint` with `style` + `shapeId` |
| ERD cardinality | `exactlyOne`, `zeroOrMore`, `zeroOrOne`, `oneOrMore` |
| Endpoint position | `position: {x: 0-1, y: 0-1}` for precise attachment |
| Cell styling | `cells[].style.fill: {type: "color", color: "#hex"}` |
| Column widths | `userSpecifiedCols: [{index: 0, size: N}]` |

### What Breaks
| Issue | Cause | Fix |
|-------|-------|-----|
| Cells empty | `stroke` in table `style` | Remove `stroke`, only use `fill` |
| Cells empty | `text` key missing (Go `omitempty`) | Always include `"text": ""` |
| Text invisible | Row height < 34px | Use ≥ 34px per field row |
| Invalid fill | Alpha channel in hex (8 chars) | Use 6-char hex only |
| Upload fails 415 | Wrong MIME type on file part | Set `x-application/vnd.lucid.standardImport` |
| Table rejected | Using flat `x,y,w,h` for table | Must use `boundingBox: {x,y,w,h}` |
| Native ERD shapes | `ERDEntityBlock2` in Standard Import | NOT SUPPORTED — use `table` type |
| Lines through shapes | Lucid auto-routing | Cannot fix via API (Lucid confirmed) |
| No UI import for .lucid | File → Import menu | Only accepts .drawio, .vsdx, etc. |

### API Endpoints Used
| Operation | Method | URL |
|-----------|--------|-----|
| Create document | POST | `https://api.lucid.co/v1/documents` |
| Get contents | GET | `https://api.lucid.co/v1/documents/{id}/contents` |
| Delete document | DELETE | `https://api.lucid.co/v1/documents/{id}` |
| Create share link | POST | `https://api.lucid.co/v1/documents/{id}/shareLinks` |

### Auth
- Bearer token via `Authorization: Bearer <token>` header
- Token from Lucid developer portal (API Keys page)
- Environment variable: `LUCID_API_TOKEN`

---

## Architecture

```
erd-gen/
├── main.go              # Subcommand router (generate|update|export|share|version|help)
├── cmd_generate.go      # Build + upload → URL + document ID
├── cmd_update.go        # Delete old + create new (full regen)
├── cmd_export.go        # GET document contents as JSON
├── cmd_share.go         # Create view-only share link
├── api.go               # Lucid REST API client
├── schema/schema.go     # Input JSON types (Table, Field, Relationship)
├── layout/layout.go     # Domain-grouped horizontal layout engine
├── lucid/render.go      # Standard Import renderer (tables, containers, lines)
├── testdata/
│   └── SourceSelection.json
├── go.mod
├── .gitignore
└── README.md
```

---

## Deployment & Distribution

**CI Pipeline:** ✅ Working (golang:1.22-alpine, builds darwin-arm64/amd64, linux-amd64)
**Release tags:** v1.1.0 (stale), v1.1.1 (current)
**Install method:** curl from GitLab releases with `PRIVATE-TOKEN: ${GITLAB_TOKEN}` header
**Known issue:** First v1.1.0 tag created empty release that blocked re-creation. Used v1.1.1 instead.
**Binary download issue:** Without auth header, GitLab returns HTML login page instead of binary. Steering updated to include `GITLAB_TOKEN`.

**Steering rules for agent:**
- Agent MUST install erd-gen silently (no asking, no options)
- NO Markdown/Mermaid fallbacks — only Lucidchart via erd-gen
- If install fails via curl, retry with `git clone + go build`
- Token config is one-time user action (`erd-gen config --token`)

**Repo moved:** `/Users/ramaswamy.u/repo/erd-gen` → `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/erd-gen`

---

## Next Steps

| Priority | Task |
|----------|------|
| P1 | Fix GitLab release download URLs (ensure binaries are accessible with GITLAB_TOKEN) |
| P2 | Fine-tune lane spacing based on actual line density per gap |
| P2 | Support multiple pages (Full ERD + domain-scoped views per page) |
| P3 | Auto-detect schema changes and highlight new/removed tables |
| P3 | Add `erd-gen update` self-update command once releases are stable |
