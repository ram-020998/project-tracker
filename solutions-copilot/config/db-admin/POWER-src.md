---
name: "jarvis-smt"
displayName: "JARVIS SMT — Database Script Management"
description: "Manages SQL database scripts for Appian applications via SMT (Script Management Tool). Explore schemas, generate idempotent scripts, check change request status, and query application configuration. Works on top of the JARVIS Power — uses JARVIS MCP tools (query_sql) for all data access."
keywords: ["smt", "script management", "database", "sql", "schema", "table", "column", "view", "trigger", "procedure", "change request", "migration", "mariadb", "oracle", "data dictionary", "release", "version", "deploy", "DDL", "ALTER TABLE", "CREATE TABLE", "idempotent", "data model", "reference data", "foreign key", "index", "constraint", "add column", "row count", "register", "dependency"]
author: "Soma"
---

# JARVIS SMT — Database Script Management

## Overview

JARVIS SMT manages SQL database scripts for Appian applications through the Script Management Tool (SMT). It provides schema exploration, script generation, change request tracking, and application configuration queries — all powered by the JARVIS MCP server's `query_sql` tool.

**This power has no MCP server of its own.** It relies entirely on the JARVIS Power's MCP tools for data access. Install the JARVIS Power first.

**Key capabilities:**
- Explore database schemas (tables, columns, views, row counts, comments)
- Generate idempotent SQL scripts that match existing team patterns
- Track change request status and find scripts by JIRA ticket
- Query application registry, releases, and dependency chains
- Support for MariaDB and Oracle (per-app configuration)

## Prerequisites

- **JARVIS Power** must be installed and configured (provides `query_sql` tool)
- SMT application must be deployed on the target Appian environment
- The JARVIS API key user must have access to the SMT database tables

## Action Router

**MANDATORY: Always load `smt-reference.md` FIRST before loading any other steering file.** It contains the schema detection rules, table definitions, script rules, and conventions that all workflows depend on. No SMT workflow can execute correctly without it.

**Loading order:**
1. `smt-reference.md` (ALWAYS — provides schema detection, table schemas, rules, templates)
2. The workflow-specific steering file (based on user request below)

Classify the user's request and load the appropriate steering file:

| User Request | Steering File |
|---|---|
| "What tables does GSS have?", "show schema", "what columns", "data dictionary", "row counts", "what views exist", "missing comments" | `db-explore-workflow.md` |
| "Find scripts for GAMS-3098", "what CRs are open", "show me the SQL", "what's approved", "deployment history", "who submitted" | `db-status-workflow.md` |
| "Generate a script", "create table", "add column", "alter table", "create view", "add index", "write SQL for" | `db-script-workflow.md` |
| "What apps are in SMT?", "what release", "dependency chain", "deployment order", "what DB types", "app config" | `db-config-workflow.md` |
| "Register a new app", "add application", "create a release", "onboard to SMT", "migrate to SMT", "set up dependencies", "verification config" | `db-admin-workflow.md` |

**Default:** If the request mentions database, SQL, tables, columns, scripts, or SMT — activate this power.

## Available Steering Files

| Steering File | Purpose |
|---|---|
| `smt-reference.md` | Complete SMT reference — tables, rules, templates, verification, conventions. Always loaded. |
| `db-explore-workflow.md` | Browse current database schema — tables, columns, views, relationships, missing docs |
| `db-status-workflow.md` | Track change requests, find scripts by JIRA ticket, deployment history |
| `db-script-workflow.md` | Generate SQL scripts matching existing team patterns (pattern-first, never generic) |
| `db-config-workflow.md` | Application registry, releases, dependency chains, deployment ordering |
| `db-admin-workflow.md` | Register new applications, create releases, migrate existing apps, configure verification |

## How It Works

1. User asks a database-related question in Kiro
2. This power's action router matches the request to a steering file
3. The steering file provides step-by-step instructions for the agent
4. The agent calls `query_sql` (from JARVIS MCP server) to read SMT tables
5. Results are formatted and presented following the steering file's guidelines

**No new tools needed.** Everything works through the existing JARVIS `query_sql` tool querying the SMT tables.

## Schema Detection (IMPORTANT)

SMT tables may reside in **either** the `Appian` schema or the `DevTools` schema depending on the environment. At the start of any SMT session, the agent must detect the correct schema by probing:

1. Try `DevTools.SMT_Application` first — if it exists and has data, use `DevTools`
2. Fall back to `Appian.SMT_Application` if DevTools doesn't exist or is empty
3. If both exist, use the one with more rows (that's the active/live schema)

See `smt-reference.md` Section 3 for the full detection query pattern.

## Key Tables (Quick Reference)

| Table | What It Holds |
|---|---|
| `{SMT_SCHEMA}.SMT_Application` | Registered apps, prefixes, DB types, dependencies |
| `{SMT_SCHEMA}.SMT_DevPhase` | Releases per app, current release flag |
| `{SMT_SCHEMA}.SMT_ChangeRequest` | Change requests (status, JIRA link, submitter) |
| `{SMT_SCHEMA}.SMT_ChangeRequest_Script` | Scripts within CRs (actual SQL content) |
| `{SMT_SCHEMA}.SMT_Script` | Approved/committed scripts |
| `{SMT_SCHEMA}.SMT_ScriptExecutionHistory` | Deployment execution log |
| `{SMT_SCHEMA}.SMT_InformationViewTables` | Cached table metadata (names, types, row counts, comments) |
| `{SMT_SCHEMA}.SMT_InformationViewColumns` | Cached column metadata (types, keys, comments) |
| `{SMT_SCHEMA}.SMT_Comment` | Review comments on CRs |
| `{SMT_SCHEMA}.SMT_Diff` | Script version diffs |
| `{SMT_SCHEMA}.SMT_DataSourceConfig` | Verification data source UUIDs |
| `{SMT_SCHEMA}.SMT_EnvConfig` | Environment configuration |
| `{SMT_SCHEMA}.SMT_Deployment` | Deployment records |

> `{SMT_SCHEMA}` = `DevTools` or `Appian` depending on environment (detected at session start)

## Critical Rules (Always Apply)

1. **All scripts must be idempotent** — re-runnable without error (verification runs them twice)
2. **Stored procedures and triggers ALWAYS re-run** — use DROP + CREATE or CREATE OR REPLACE
3. **Triggers/procedures must be in separate scripts** — never combined with table DDL
4. **Tables before views** — dependency ordering matters
5. **Never generate generic SQL** — always research existing patterns in the same app first (see Rule 9 below)
6. **One CR per JIRA ticket** — group related scripts together
7. **SMT stays in dev only** — never deployed to higher environments
8. **Never delete shipped data** — rename to 'deprecated' instead
9. **Pattern-first generation is mandatory** — follow this strict fallback chain:
   - **Level 1: App-specific patterns** — Query existing scripts in the SAME application that do something similar. Use their exact style.
   - **Level 2: Cross-app patterns** — If no similar scripts exist in the app, check other apps in the same SMT instance.
   - **Level 3: SMT templates** — If no patterns found anywhere, fall back to templates in `smt-reference.md` Section 7.
   - **Level 4: NEVER** — Generic SQL from general knowledge is NEVER acceptable. If templates don't cover the case, tell the user and ask for guidance.
   - **Transparency requirement:** Always tell the user which level was used: "Generated from existing VM INSERT pattern (script #5426)" or "No existing patterns found — used SMT reference data template."
10. **Generate scripts for ALL supported DB types** — Before generating any script:
    - Query `{SMT_SCHEMA}.SMT_Application.dbtypes` for the target app
    - If the app supports `["MARIA_DB","ORACLE"]` → generate BOTH MariaDB and Oracle versions
    - If the app supports only `["MARIA_DB"]` → generate MariaDB only
    - Research patterns for EACH DB type separately (Oracle patterns may differ from MariaDB patterns in the same app)
    - NEVER skip a supported DB type. If you can't generate for one type, tell the user explicitly.

## Relationship to JARVIS Power

- JARVIS handles: Appian objects (SAIL code, interfaces, expression rules, process models)
- JARVIS SMT handles: Database layer (tables, columns, SQL scripts, schema changes)
- They share: The same MCP server, the same `query_sql` tool, the same Appian environment
- Handoff: When JARVIS design workflow detects data model changes are needed, it suggests activating JARVIS SMT to generate the scripts

## Example Interactions

```
User: "What tables does GSS have?"
→ Loads db-explore-workflow.md
→ Queries SMT_InformationViewTables WHERE TABLE_NAME LIKE 'AS_GSS%'
→ Shows tables with row counts and comments

User: "Find scripts for GAMS-3098"
→ Loads db-status-workflow.md
→ Queries SMT_ChangeRequest WHERE jiraticketnumber = 3098
→ Shows CR status, scripts, and SQL content

User: "Generate a script to add VENDOR_SCORE to AS_GSS_EVALUATION"
→ Loads db-script-workflow.md
→ Researches existing ALTER TABLE scripts in GSS
→ Checks current table structure
→ Generates idempotent SQL matching team patterns

User: "What's the deployment order for VM?"
→ Loads db-config-workflow.md
→ Queries SMT_Application for VM's dependency chain
→ Shows ordered list: GAM releases first, then VM releases
```
