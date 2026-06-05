# Action: Release Review

Help a PO understand what changed in a release and prepare stakeholder communication.

## When to use
- "What changed in the latest release?"
- "Prepare release notes"
- "What's new in version X?"
- Sprint review preparation

## Workflow

1. `list_releases(app)` → show release history with dates and change counts
2. `get_changelog(app, release)` → detailed changes
3. `get_release_impact(app, release)` → which features were affected
4. Summarize for stakeholders

## How to present

**Lead with the business impact, not the object counts:**

❌ "33 objects added, 12 objects modified, 0 removed"
✅ "This release includes 3 new features and updates to 8 existing features"

**Group changes by business area:**
```
Release 25.04.02.09.00 Summary:

New Features (3):
- AI Vendor Analysis — automated vendor proposal analysis
- Document Review Workflow — submit documents for team review
- Factor Requirement Extraction — AI-powered requirement parsing

Updated Features (8):
- Evaluation Setup — improved vendor search with result counts
- Complete Evaluation — updated awardee selection interface
- Start Evaluation — added vendor analysis toggle
- [... etc]

No features were removed.
```

**For each changed feature, explain what changed in user terms:**
- Use `get_changelog(app, release, filter_bundle="bundle_name")` to see specific changes
- Translate: "Interface modified" → "The form was updated"
- Translate: "Expression Rule added" → "New business logic was added"
- Translate: "members_added" → "New components were added to this feature"

**End with:**
- "Want me to dive deeper into any of these changes?"
- "Want me to compare this release with an older one?"
