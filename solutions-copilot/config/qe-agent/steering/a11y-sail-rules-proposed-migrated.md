---
inclusion: manual
---

# Proposed A11y SAIL Rules — Staging Area

⚠️ **This file contains PROPOSED rules that have NOT been approved yet.**
These rules were auto-generated from audit gap analysis and need human review before being added to the main `a11y-sail-rules.md` file.

## How to use this file

1. The `learn_from_audit_gaps` tool writes proposed rules here
2. Review each proposed rule below — edit, delete, or keep as-is
3. When satisfied, call `approve_proposed_rules` to move approved rules to `a11y-sail-rules.md`
4. Or call `approve_proposed_rules(rule_ids=["RULE-XX-01", "RULE-XX-02"])` to approve selectively

## Proposed Rules

<!-- Proposed rules will be appended below this line -->

### Proposed on 2026-04-22 — from gap analysis





### Auto-synced on 2026-04-23 — recurring patterns across 1+ apps



### Proposed on 2026-05-07 — from gap analysis




<!-- Source: GAMS-8013-04 | Category: heading -->
- RULE-HD-03: Rich text styled as heading but not semantic heading. Source: GAMS-8013-04. SAIL components: a!richTextItem, a!headingField. SAIL params to check: headingTag. Detection: Text elements using style: STRONG or size: MEDIUM_PLUS in a!richTextItem that visually appear as section headings are not defined as semantic headings (a!headingField). This prevents screen reader hea









