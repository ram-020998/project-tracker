# Atlas Platform — Complete Documentation

This folder documents the **entire Atlas platform**: the parsing engine, the knowledge base, the MCP serving layer, and **everything built on top of it** (powers and tools used by AI agents).

> **Atlas in one line:** Atlas turns any Appian application into structured, machine-readable knowledge and serves it to AI agents over a standard interface (MCP) — the foundation layer that any number of agent-powered tools are built on.

---

## Document Index

| # | Document | Covers |
|---|----------|--------|
| 1 | [01-architecture.md](./01-architecture.md) | End-to-end architecture: parser → KB → MCP → tools; the data pipeline |
| 2 | [02-knowledge-base.md](./02-knowledge-base.md) | KB directory layout, output schema, versioning, sync pipeline |
| 3 | [03-mcp-servers.md](./03-mcp-servers.md) | The three MCP servers and every tool they expose |
| 4 | [04-tools-built-on-atlas.md](./04-tools-built-on-atlas.md) | Every power/tool built on Atlas (SQL Forge, Locust Forge, ERD-Gen, role powers, etc.) |
| 5 | [05-setup-and-usage.md](./05-setup-and-usage.md) | Installation, configuration, environment variables, example queries |

---

## The Platform at a Glance

```
Appian Packages (.zip)
        │
        ▼
   Atlas Parser  ───────────────►  Atlas Knowledge Base (versioned JSON)
   (solutions-atlas-parser)          (solutions-os/ai-framework/tools/Atlas/solutions-kb/data)
        │                                       │
        │                                       ▼
        │                          Atlas MCP Server (read-only, Docker)
        │                          (solutions-atlas-mcp-server)
        │                                       │
        ▼                                       ▼
   schema/ folder                    ANY AI-agent tool built on top
   (DDL replay engine)               • Knowledge search & version history
                                     • ERD generation
                                     • Test-data generation (QE)
                                     • Performance test scripts
                                     • Documentation / release notes
                                     • Migration / impact analysis
                                     • …N more
```

---

## Repositories Involved

| Repo | Location | Role |
|------|----------|------|
| `solutions-atlas-parser` | `appian/prod/solutions-atlas-parser` | Parses Appian packages → structured JSON + schema |
| `solutions-atlas-mcp-server` | `appian/prod/solutions-atlas-mcp-server` | Read-only MCP server exposing the KB |
| `solutions-os` | `appian/prod/solutions-os` | Hosts the KB (`ai-framework/tools/Atlas/solutions-kb`) + role powers |
| `solutions-atlas-dg-mcp-server` | `ramaswamy.u/solutions-atlas-dg-mcp-server` | Write-capable Data Generator MCP |
| `solutions-atlas-locust-mcp-server` | `ramaswamy.u/solutions-atlas-locust-mcp-server` | Locust API-intelligence MCP |
| `atlas-sql-forge` | `ramaswamy.u/atlas-sql-forge` | Test-data + bulk-SQL generation power |
| `atlas-locust-forge` | `ramaswamy.u/atlas-locust-forge` | Performance-test script generation power |
| `erd-gen` | `ramaswamy.u/erd-gen` | Lucidchart ERD generation CLI |

> **KB project ID:** `13490` · **Data prefix:** `ai-framework/tools/Atlas/solutions-kb/data`

---

## Core Principles

1. **Parse once, reuse everywhere** — application understanding is solved a single time; every tool inherits it.
2. **Standard agent interface (MCP)** — any AI agent (Kiro, Amazon Q, future providers) plugs in.
3. **Read-only and secure** — the serving layer refuses write-scoped tokens.
4. **Always current** — an automated pipeline re-syncs the KB as applications release.
5. **Compounding value** — every new tool built on Atlas adds value without adding complexity to the base.

*Last updated: 2026-06-16*
