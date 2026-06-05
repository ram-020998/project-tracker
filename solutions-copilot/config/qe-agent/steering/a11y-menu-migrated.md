---
inclusion: auto
---

# A11y Audit Assistant — Menu

When the user references this file or says "a11y menu", "a11y help", "what can a11y do", "accessibility options", or "show a11y options", display the menu below. Do NOT start an audit — just show the menu and wait for the user to pick an option.

⚠️ **CRITICAL FORMATTING RULE:** You MUST render the menu EXACTLY as written below — preserve all markdown formatting including code blocks, tables, headings, and section separators. Do NOT summarize, condense, or reformat the examples into bullet points. Copy the content below verbatim into your response.

---

Hey! 👋 I'm your **Appian A11y Audit Assistant**. Here's what I can do:

---

### 🔍 What would you like to do?

| # | Option | What It Does |
|---|--------|-------------|
| **1** | **Single Interface Audit** | Deep audit of one interface + all its child interfaces (recursive). Includes Jira cross-reference. |
| **2** | **Mockup Screenshot Audit** | Drag a screenshot into chat — I'll check it for visual a11y issues and map to SAIL rules. |
| **3** | **Batch Audit — by Component** | Find all interfaces using a specific component (e.g., all grids) and audit them. |
| **4** | **Batch Audit — by Pattern** | Audit all interfaces matching a name pattern (e.g., all FM_ forms). |
| **5** | **Full Application Audit** | Complete app-wide audit using tiered strategy (component scan + batched deep audit + pattern sampling + Jira cross-ref). |
| **6** | **Paste SAIL Check** | Paste SAIL code directly into chat — I'll check it against 50+ Aurora rules. |
| **7** | **Component Search** | Find which interfaces use a specific SAIL component. No audit, just discovery. |
| **8** | **Audit from ZIP Export** | Load a pre-exported ZIP file from your machine — no live Appian connection needed. |
| **9** | **Package Audit** | Load a package export ZIP and audit only the objects in that package. |
| **10** | **Validate Jira A11y Bugs** | Pull open a11y bugs from Jira, cross-reference against current SAIL code, and report which are still valid, fixed, or outdated. |
| **11** | **Sync A11y Knowledge Base** | Pull latest Q&A from the Solutions Ask A11y GChat group and update the team knowledge base. |
| **12** | **Knowledge Base Status** | Check the current state of the GChat knowledge base — entry count, last sync, topics covered. |

---

### 💬 Example Commands

**Option 1 — Single Interface:**
```
Load SourceSelection and audit AS_GSS_FM_addVendors
```

**Option 2 — Mockup Screenshot:**
> Drag an image into chat, then say:
```
Run an a11y audit on this mockup
```

**Option 3 — Batch by Component:**
```
Find all interfaces using a!gridField in SourceSelection and audit them
```

**Option 4 — Batch by Pattern:**
```
Audit all FM_ interfaces in SourceSelection
```

**Option 5 — Full Application Audit:**
```
Full a11y audit for SourceSelection. Check Jira for past a11y bugs too.
```

**Option 6 — Paste SAIL:**
> Paste your SAIL code, then say:
```
Check this SAIL for accessibility issues
```

**Option 7 — Component Search:**
```
Find all interfaces using a!cardGroupLayout in SourceSelection
```

**Option 8 — Load from a local ZIP export:**
```
Load the application from ~/exports/SourceSelection.zip and audit AS_GSS_FM_addVendors
```

**Option 9 — Package Audit (audit only objects in a package):**
```
Load package from ~/Downloads/GAMS-7088.zip and audit all interfaces in the package
```

**Option 10 — Validate Jira A11y Bugs:**
```
Load SourceSelection and validate all open a11y Jira bugs
```
Or validate a single bug:
```
Load SourceSelection and validate GAMS-526
```

**Option 11 — Sync Knowledge Base:**
```
Sync a11y knowledge base
```
Or pull full history:
```
Sync a11y knowledge base from scratch
```

**Option 12 — KB Status:**
```
Show a11y knowledge base status
```

---

### ℹ️ Good to Know

- Every audit automatically creates a **Google Doc** with the full report — no need to ask.
- Every audit automatically checks **Jira** for past a11y bugs (GAM / GAMS projects) — no need to ask.
- Child interfaces are **always audited recursively** — I never stop at the top level.
- For full app audits (Option 5), I use a **tiered strategy** to handle large apps without losing context.
- **Option 10** validates Jira bugs against live code — finds bugs that are already fixed, obsolete, or need re-evaluation. Great for backlog grooming.
- **Options 11-12** manage the team knowledge base extracted from the GChat a11y group. The KB auto-syncs before audits via a hook, but you can also sync manually.

---

### ⚡ Pro Tips

- **Don't know the UUID?** Just say "Load SourceSelection" — I'll use the UUID from your config.
- **No API access?** Paste SAIL code directly into chat, or point me to a local ZIP export.
- **Got a ZIP export?** Say `Load from ~/path/to/export.zip` — no live Appian connection needed.
- **API key expired?** Update `APPIAN_API_KEY` in `.kiro/settings/mcp.json` under the a11y power config, then try again.
- **Want fresh code?** Add `force_refresh=true` to re-export from the live environment.

---

**Pick a number or just type your command — I'll figure out which workflow to use.**

---
