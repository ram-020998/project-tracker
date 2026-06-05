---
name: "jarvis-a11y-fixer"
displayName: "A11Y Fixer"
description: "Automated accessibility fix deployment. Reads A11Y Jira tickets, identifies the interface to fix, retrieves XML, applies the fix, deploys with human approval, and verifies using a virtual screen reader."
keywords: ["a11y", "accessibility", "wcag", "screen reader", "fix", "deploy", "508", "aria", "alt text", "label", "heading", "caption", "accessibilityText"]
author: "Soma"
---

# A11Y Fixer — Automated Accessibility Fix Deployment

## ⚠️ STOP — READ THIS FIRST

When a user gives you a ticket number, your FIRST response MUST be this tracker. Print it BEFORE calling any tools. Use this exact markdown table format:

**A11Y FIXER — GAMS-XXXX**

| Phase | Step | Status |
|-------|------|--------|
| 1 | Understand Ticket | ⏳ |
| 2 | Locate Interface | — |
| 3 | Plan Navigation | — |
| 4 | PRE-FIX (Playwright) | — |
| 5 | Get & Analyze XML | — |
| 6 | Apply Fix | — |
| 7 | Deploy | — |
| 8 | POST-FIX (Playwright) | — |
| 9 | Close Out | — |

Reprint this table after EVERY phase. Update statuses: ✅ done, ⏳ in progress, — not started, ⛔ skipped.

**Phase 4 and 8 REQUIRE `browser_navigate` + `browser_snapshot`. No exceptions.**

## Appian Environment (for Playwright verification)

**Site URLs:** Obtained automatically from Jarvis via `get_jarvis_config` → `siteUrlList` for each app.

**Credentials:** Stored in `appian-env.local` (not tracked in Git). Copy from template:

```bash
cp appian-env.template appian-env.local
# Edit with your username and password
```

Both files live in the `A11yFixer/` root directory (outside the power folder).
The agent reads `appian-env.local` for login credentials, and gets the site URL from Jarvis based on the app prefix.

## Overview

A11Y Fixer reads an accessibility Jira ticket, identifies the interface to fix, retrieves its XML, applies the accessibility fix, deploys it with human approval, and verifies the fix using a virtual screen reader.

**Supported fix types:**
- **Tier 1 (42 patterns):** Parameter additions, changes, and removals — fully automated
- **Tier 2 (6 patterns):** Component insertions — automated with care
- **Tier 3 (8 patterns):** Structural refactoring — agent will NOT attempt these

## Action Router

Before doing anything, classify the user's request:

| User Request | Steering File to Load |
|---|---|
| "Fix GAMS-XXXX", "A11Y fix for GAMS-XXXX", "Verify GAMS-XXXX", any ticket number | `a11y-fixer-workflow.md` |
| "What A11Y patterns can you fix?", "Show me the fix taxonomy" | `a11y-fix-patterns.md` |
| "What are the XML rules?", "How do you modify the XML?" | `a11y-xml-rules.md` |
| "How do I navigate Appian with Playwright?" | `playwright-appian-helper.md` |

**Default**: If the user provides a GAMS ticket number (fix, verify, check — any action), ALWAYS load `a11y-fixer-workflow.md`.

## MANDATORY: Execution Tracker

After completing each phase, ALWAYS print this tracker:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
A11Y FIXER — GAMS-XXXX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 1: Understand Ticket    [status]
Phase 2: Locate Interface     [status]
Phase 3: PRE-FIX (Playwright) [status]  ← MUST use browser_navigate + browser_snapshot
Phase 4: Get & Analyze XML    [status]
Phase 5: Apply Fix            [status]
Phase 6: Deploy               [status]
Phase 7: POST-FIX (Playwright)[status]  ← MUST use browser_navigate + browser_snapshot
Phase 8: Close Out            [status]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
Use: ✅ done, ⏳ in progress, — not started, ⛔ skipped

**Phase 3 and Phase 7 REQUIRE the Playwright MCP tools (`browser_navigate`, `browser_snapshot`).** Reading XML is NOT verification. You must open the actual interface in a browser and read the accessibility tree. If you haven't called `browser_navigate`, you haven't done Phase 3.

## Dependencies

This power requires the **Jarvis** MCP server to be configured. It uses the following Jarvis tools:

- `jarvis_search_objects` / `search_objects_semantic` — find interfaces
- `jarvis_get_object_xml` — fetch object XML
- `deploy_modified_object` — deploy changes
- `evaluate_sail_expression` — validate SAIL
- `query_sql` — check bundle keys
- `get_jarvis_config` — get app registry

It also requires the **Jira** MCP for reading tickets.

Ensure the Jarvis MCP server is running (see `ai-framework/tools/Jarvis/README.md` for setup instructions).

## Prerequisites

- **Jarvis power installed** — with MCP server connected to an Appian environment
- **Jira MCP** — configured for the GAMS project
- **Appian environment** — with KB generated and deployment access

## How It Works

1. **Read** the Jira ticket → extract interface, component, fix type
2. **Locate** the interface using Jarvis KB search + semantic search
3. **Retrieve** the XML via `jarvis_get_object_xml`
4. **Classify** the fix against the 56-pattern taxonomy
5. **Apply** the fix (modify XML `<definition>` section only)
6. **Deploy** via `deploy_modified_object` (human approves)
7. **Verify** by re-fetching XML + running virtual screen reader

## Key Tool Dependencies

### From Jarvis MCP
| Tool | Used For |
|------|----------|
| `jarvis_search_objects` | Find interface by name in KB |
| `search_objects_semantic` | Broader search when KB search misses |
| `jarvis_get_object_xml` | Get raw XML for modification |
| `deploy_modified_object` | Deploy the fixed XML |
| `query_sql` | Check existing bundle keys in BND_Key table |
| `jarvis_get_cluster` | Get navigation path for verification |
| `jarvis_get_app_tree` | Get entry points for verification |
| `get_jarvis_config` | Get app registry IDs and KB folder IDs |

### From Jira MCP
| Tool | Used For |
|------|----------|
| `get_jira_issue` | Read the A11Y ticket details |

## Available Steering Files

| Steering File | Purpose |
|---------------|---------|
| `a11y-fixer-workflow.md` | Main end-to-end workflow (Phases 1–8) |
| `a11y-fix-patterns.md` | Complete taxonomy of 56 fix patterns across 3 tiers |
| `a11y-xml-rules.md` | DO/DON'T rules for safe XML manipulation |
| `a11y-verification.md` | Verification workflow (pre/post fix using Playwright MCP) |
| `playwright-appian-helper.md` | How to navigate, interact with, and verify Appian UIs using Playwright MCP |

## Safety Model

- **Human approval required** before every deployment
- **Only `<definition>` section modified** — never roleMap, history, namedTypedValue
- **Business logic untouched** — never modify saveInto, showWhen, variables
- **Appian inspection gate** — malformed XML is rejected before deployment
- **Backup created** — every deploy creates a rollback point
- **Tier 3 refused** — agent will not attempt structural refactoring

## Bundle Key Convention

When adding user-facing text (labels, accessibilityText, captions), use the i18n bundle pattern:

```
#"AS_GAM_CO_I18N_UT_displayLabel"(
  bundle: ri!i18nData,
  bundleKey: "acs_KeyName"
)
```

- Accessibility keys use `acs_` prefix
- Check existing keys first: `SELECT keyname, enuslabel FROM Appian.BND_Key WHERE bundleid = 13 AND keyname LIKE 'acs_%'`
- If no suitable key exists, use a literal value for now and flag for bundle key creation
