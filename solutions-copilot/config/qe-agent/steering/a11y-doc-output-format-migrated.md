---
inclusion: manual
---

# A11y Audit — Document Output Format (MANDATORY)

⚠️ This file defines the EXACT formatting rules for every a11y audit report. These rules are NON-NEGOTIABLE. If the output doesn't match, the audit is incomplete.

---

## Pre-Output Self-Check (RUN BEFORE calling import_to_google_doc)

| # | Check | What to look for | If missing |
|---|-------|-----------------|------------|
| 1 | Summary table exists | `## Summary` followed by a Markdown table with 🔴, 🟡, 🟠, ✅ rows | Add the summary table — do NOT use a single bold line |
| 2 | Findings Overview Table exists | A Markdown table listing ALL findings with columns: #, Rule ID, Interface, Issue, Severity | Add it between Summary and the detailed findings |
| 3 | Every MUST FIX finding has severity line | Every `### Finding N` is followed by `**Severity:** 🔴 High — **MUST FIX**` as the FIRST line after the heading | Add the severity line to every finding |
| 4 | Every VERIFY item has severity line | Every `### VERIFY-N` is followed by `**Severity:** 🟡 Medium — **VERIFY**` as the FIRST line after the heading | Add the severity line to every verify item |
| 5 | Every WATCH OUT item has severity line | Every `### WATCH-N` is followed by `**Severity:** 🟠 Low — **WATCH OUT**` as the FIRST line after the heading | Add the severity line to every watch item |
| 6 | Section headings use emoji prefixes | `## 🔴 Automated SAIL Findings`, `## 🟡 Manual Checks Required`, `## 🟠 Jira Cross-Reference` | Add the emoji to the `##` section heading |
| 7 | No plain-text summary | The summary is NOT a single line like `**14 findings, 8 manual checks**` | Replace with the summary table |
| 8 | Google Doc link will be shared | You will call `import_to_google_doc` and share the link | Do it |

---

## Emoji Severity Indicators (USE THESE EVERYWHERE)

- 🔴 = **MUST FIX** (High severity, automated SAIL finding)
- 🟡 = **VERIFY** (Medium severity, manual check required)
- 🟠 = **WATCH OUT** (Low severity, historical pattern)
- ✅ = **PASSES** (Rule check passed)

These emoji prefixes MUST appear in:
- The summary table rows
- Every `##` section heading for findings/verify/watch sections
- Every `###` finding/verify/watch item's `**Severity:**` line
- The Findings Overview Table severity column

---

## Summary Table (MANDATORY — top of report after metadata)

MUST be a Markdown table. NEVER a single bold line.

```markdown
## Summary

| Category | Count |
|----------|-------|
| 🔴 **MUST FIX** (Automated SAIL Findings) | [N] |
| 🟡 **VERIFY** (Manual Checks Required) | [N] |
| 🟠 **WATCH OUT** (Historical Bug Patterns) | [N] |
| ✅ **PASSES** | [N] |
| **Total Interfaces Audited** | [N] |
```

---

## Findings Overview Table (MANDATORY — between Summary and detailed findings)

```markdown
## Findings Overview

| # | Rule ID | Interface | Issue | Severity |
|---|---------|-----------|-------|----------|
| 1 | RULE-XX-NN | [Interface name] | [Brief description] | 🔴 **MUST FIX** |
| V1 | RULE-VM-NN | [Interface name] | [Brief description] | 🟡 **VERIFY** |
| W1 | JIRA-KEY | [Interface name] | [Brief description] | 🟠 **WATCH OUT** |
```

---

## Finding Format (EVERY finding MUST follow this EXACTLY)

```markdown
### Finding 1 — RULE-LK-01: Link using linkStyle "STANDALONE"

**Severity:** 🔴 High — **MUST FIX**
**Rule ID:** RULE-LK-01
**Aurora Rule:** "[Exact rule text from checklist]"
**Interface:** [Interface name]
**Component:** `[a!componentName]` with `[parameter details]`

**Issue:** [Detailed explanation]

**Fix:** [Specific SAIL code fix]

**How To Test:** [Test method]
```

The `**Severity:**` line with emoji MUST be the FIRST line after the `###` heading. No exceptions.

---

## VERIFY Item Format (EVERY verify item MUST follow this EXACTLY)

```markdown
### VERIFY-01 — RULE-VM-05: Color-only status indicators

**Severity:** 🟡 Medium — **VERIFY**
**Rule ID:** RULE-VM-05
**Interfaces:** [Interface name(s)]

**What:** [What needs to be checked]

**Check:** [How to verify]
```

The `**Severity:**` line with emoji MUST be the FIRST line after the `###` heading. No exceptions.

---

## WATCH OUT Item Format (EVERY watch item MUST follow this EXACTLY)

```markdown
### WATCH-01 — GAMS-7552: Misuse of accessibility text on links

**Severity:** 🟠 Low — **WATCH OUT**
**Jira:** [JIRA-KEY] ([Status])

**Pattern:** [Description of the historical bug pattern]

**Relevance:** [How this relates to the current interface]

**Risk:** [LOW/MEDIUM/HIGH] — [assessment]
```

The `**Severity:**` line with emoji MUST be the FIRST line after the `###` heading. No exceptions.

---

## Section Headings (MUST use emoji prefixes)

```markdown
## 🔴 Automated SAIL Findings (MUST FIX)
## 🟡 Manual Checks Required (VERIFY)
## 🟠 Jira Cross-Reference (WATCH OUT)
```

NEVER use plain text like `## Automated SAIL Findings` without the emoji.

---

## Headings & Structure Rules

- Use `#` for the report title
- Use `##` for major sections (Summary, Findings, Manual Checks, Jira, Component Summary, etc.)
- Use `###` for individual findings, verify items, watch items
- NEVER use ALL-CAPS plain text for section headers — always use Markdown heading syntax
- Every finding gets its own `###` subsection — NEVER put findings in a single paragraph

---

## Bold Labels (MANDATORY on every finding/item)

These field labels MUST be bold in every finding:
- `**Severity:**`, `**Rule ID:**`, `**Aurora Rule:**`, `**Interface:**`, `**Component:**`
- `**Issue:**`, `**Fix:**`, `**How To Test:**`, `**What:**`, `**Check:**`
- `**Pattern:**`, `**Relevance:**`, `**Risk:**`, `**Jira:**`

These status/severity words MUST be bold:
- `**MUST FIX**`, `**VERIFY**`, `**WATCH OUT**`, `**PASSES**`
- `**STILL PRESENT**`, `**FIXED**`, `**NEW VARIATION**`

---

## What NOT To Do

- ❌ Do NOT output the report as unformatted plain text
- ❌ Do NOT use ALL-CAPS for section headers without Markdown heading syntax
- ❌ Do NOT skip bold on severity labels
- ❌ Do NOT skip the summary table — a single bold line is NOT a summary
- ❌ Do NOT skip the Findings Overview Table
- ❌ Do NOT write a finding heading without the `**Severity:**` line immediately after
- ❌ Do NOT write a VERIFY heading without the `**Severity:**` line immediately after
- ❌ Do NOT put findings in a single giant paragraph
- ❌ Do NOT omit emoji prefixes from severity indicators
