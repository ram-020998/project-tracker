---
name: "a11y-fixer"
displayName: "A11Y Fixer"
description: "Automated accessibility fix deployment. Reads A11Y Jira tickets, identifies the interface to fix, retrieves SAIL code, applies the fix, deploys with human approval, and verifies using Playwright browser automation."
keywords: ["a11y", "accessibility", "wcag", "screen reader", "fix", "deploy", "508", "aria", "alt text", "label", "heading", "caption", "accessibilityText"]
author: "Solutions Team"
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
| 5 | Get & Analyze Code | — |
| 6 | Apply Fix | — |
| 7 | Deploy | — |
| 8 | POST-FIX (Playwright) | — |
| 9 | Close Out | — |

Reprint this table after EVERY phase. Update statuses: ✅ done, ⏳ in progress, — not started, ⛔ skipped.

**Phase 4 and 8 REQUIRE `browser_navigate` + `browser_snapshot`. No exceptions.**

## Overview

A11Y Fixer reads an accessibility Jira ticket, identifies the interface to fix, retrieves its SAIL code, applies the accessibility fix, deploys it with human approval, and verifies the fix using Playwright browser automation.

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
| "What are the XML rules?", "How do you modify the code?" | `a11y-xml-rules.md` |
| "How do I navigate Appian with Playwright?" | `playwright-appian-helper.md` |

**Default**: If the user provides a GAMS ticket number (fix, verify, check — any action), ALWAYS load `a11y-fixer-workflow.md`.

## Tool Routing

### Read (solutions-intelligence)
| Tool | Used For |
|------|----------|
| `solutions-intelligence.search_objects` | Find interface by name |
| `solutions-intelligence.get_object_code` | Get SAIL code for analysis |
| `solutions-intelligence.get_dependencies` | Get navigation path for verification |
| `solutions-intelligence.get_app_overview` | Get entry points for verification |

### Write (lcp-api)
| Tool | Used For |
|------|----------|
| `lcp-api.getInterface` | Get live interface code (current state) |
| `lcp-api.updateInterface` | Deploy the fixed SAIL code |
| `lcp-api.searchObjects` | Broader search when intelligence search misses |
| `lcp-api.evaluateExpression` | Validate SAIL expressions |

### Verify (playwright)
| Tool | Used For |
|------|----------|
| `playwright.browser_navigate` | Open interface in browser |
| `playwright.browser_snapshot` | Capture accessibility tree |
| `playwright.browser_click` | Interact with UI elements |
| `playwright.browser_type` | Input text for login/testing |

### Track (jira)
| Tool | Used For |
|------|----------|
| `jira.get_jira_issue` | Read the A11Y ticket details |

## How It Works

1. **Read** the Jira ticket → extract interface, component, fix type
2. **Locate** the interface using `solutions-intelligence.search_objects` + `lcp-api.searchObjects`
3. **Retrieve** the SAIL code via `lcp-api.getInterface`
4. **Classify** the fix against the 56-pattern taxonomy
5. **Apply** the fix (modify SAIL expression)
6. **Deploy** via `lcp-api.updateInterface` (human approves)
7. **Verify** using Playwright browser automation (accessibility tree snapshot)

## Safety Model

- **Human approval required** before every deployment
- **Only expression/SAIL modified** — never security roles, process models
- **Business logic untouched** — never modify saveInto, showWhen logic, variables
- **Tier 3 refused** — agent will not attempt structural refactoring
- **One interface at a time** — sequential, not batch

## Available Steering Files

| Steering File | Purpose |
|---------------|---------|
| `a11y-fixer-workflow.md` | Main end-to-end workflow (Phases 1–8) |
| `a11y-fix-patterns.md` | Complete taxonomy of 56 fix patterns across 3 tiers |
| `a11y-xml-rules.md` | DO/DON'T rules for safe code manipulation |
| `a11y-verification.md` | Verification workflow (pre/post fix using Playwright) |
| `playwright-appian-helper.md` | How to navigate, interact with, and verify Appian UIs using Playwright |
