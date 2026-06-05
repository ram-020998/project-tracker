---
name: "jarvis-i18n"
displayName: "JARVIS i18n — Internationalization Assistant"
description: "Manages internationalization for Appian applications. Searches bundle keys (BND) and Translation Sets, generates new keys following conventions, and audits interfaces for i18n compliance. Works on top of the JARVIS Power — uses JARVIS MCP tools (query_sql, jarvis_get_translation) for all data access."
keywords: ["i18n", "internationalization", "translation", "bundle", "BND", "translation set", "locale", "label", "displayLabel", "lbl_", "btn_", "acs_", "txt_", "vld_", "ins_", "hlp_", "plc_", "cpt_", "key", "properties"]
author: "Soma"
---

# JARVIS i18n — Internationalization Assistant

## Overview

JARVIS i18n manages internationalization for Appian applications. It supports two i18n systems:

- **BND (Bundle Management)** — Custom system used by older apps (GSS, AM, RM, GCW, VM). Keys stored in DB, synced to .properties files, accessed via `AS_CO_I18N_UT_displayLabel()`.
- **Appian Translation Sets** — Native platform feature used by newer apps (GSM). Strings referenced via `translation!String Name(var: value)`.

The power automatically detects which system an app uses and routes to the correct approach.

**CRITICAL RULE:** Every response MUST include the bundle name (BND) or translation set name (Translation Sets). The developer must always know exactly where a key lives.

## Prerequisites

- **JARVIS Power** must be installed and configured (provides `query_sql` and `jarvis_get_translation` tools)
- BND application must be deployed on the target environment (for BND lookups)
- Translation Sets must be indexed in the KB (for Translation Set lookups)

## Action Router

| User Request | Steering File |
|---|---|
| "Find key", "does key exist", "search for", "what's the label for", "show me keys", "what bundle" | `i18n-lookup-workflow.md` |
| "Create key", "generate key", "I need a label for", "suggest key name", "new i18n key" | `i18n-create-workflow.md` |
| "Audit", "check i18n", "hard-coded text", "stale keys", "missing translations", "i18n compliance" | `i18n-audit-workflow.md` |

**Always load `i18n-reference.md` as background context** for any i18n skill.

**Default:** If the request mentions i18n, translation, bundle, label, key, locale, or internationalization — activate this power.

## Available Steering Files

| Steering File | Purpose |
|---|---|
| `i18n-reference.md` | Complete reference — both systems, conventions, tables, queries. Always loaded. |
| `i18n-lookup-workflow.md` | Find/search keys across BND and Translation Sets |
| `i18n-create-workflow.md` | Generate new keys following naming conventions and patterns |
| `i18n-audit-workflow.md` | Detect hard-coded text, stale keys, prefix violations, duplicates |

## How It Works

1. User asks an i18n question
2. Power checks `get_jarvis_config` to determine which system the app uses
3. Routes to the correct tool:
   - BND → `query_sql` against `Appian.BND_Key`, `Appian.BND_Bundle` tables
   - Translation Sets → `jarvis_get_translation(parentFolderId, query, locale)`
4. Results always include the bundle/translation set name

## Key Naming Convention (BND)

| Prefix | Purpose |
|---|---|
| `acs_` | Accessibility text |
| `btn_` | Button labels |
| `cpt_` | Captions |
| `hlp_` | Help tooltips |
| `ins_` | Instructions |
| `lbl_` | Field labels |
| `plc_` | Placeholders |
| `txt_` | General text |
| `vld_` | Validation messages |

## Example Interactions

```
User: "Does a Cancel key exist for VM?"
→ Loads i18n-lookup-workflow.md
→ Queries BND_Key WHERE app=VM AND keyname LIKE '%cancel%'
→ Shows results grouped by bundle (AS.VM.General, etc.)

User: "Create an i18n key for 'Vendor Score'"
→ Loads i18n-create-workflow.md
→ Checks for duplicates first
→ Suggests: lbl_VendorScore in AS.GSS.General bundle

User: "Audit AS_GSS_FM_vendorForm for i18n"
→ Loads i18n-audit-workflow.md
→ Reads interface SAIL via KB
→ Detects hard-coded strings, reports violations with suggested keys
```

## Relationship to JARVIS Power

- JARVIS handles: Appian objects, code review, design docs, implementation
- JARVIS i18n handles: Translation keys, bundle management, i18n compliance
- They share: The same MCP server, `query_sql`, `jarvis_get_translation`, `jarvis_get_object_content`
- Handoff: When JARVIS creates new interfaces, it should suggest i18n keys via this power
