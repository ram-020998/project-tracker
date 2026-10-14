# Genesis Hub Site — progress log (append-only; newest at top)

## 2026-10-14 — Session 1 (discovery + specs)
**Done**
- Onboarded to Genesis (bible); loaded the Appian skill + references (tools-mcp, sites, record-summary-views, function/component
  references, null-safety, short-circuit, SAIL verification checkpoint, query patterns incl. aggregation, interfaces rules,
  header-content/sideBySide/rich-text instruction excerpts).
- Discovered the whole Genesis Hub app: 14 record types, 9 constants, 3 groups, 7 folders, 1 interface (`GH_BlobVersionDocumentSummary`), **0 sites**.
  Full schema + UUIDs + real data in `01-data-model-reference.md`.
- Proposed IA (7 pages + 3 record views); user approved + decided D1–D5 (00 §3).
- **Created live (sub-spec 02):** relationship `GH Object Wiki Entry.story` (`5e33bdce-5007-4bb9-807a-c099712088cf`) and
  `GH Story.wikiEntries` (`b79fea99-9d9d-4906-bc24-aa010a822fc4`). RT versionIds now: Wiki Entry 5, Story 8.
- Wrote this spec set.

**Not done / next:** sub-specs 03 → 04 → 05 → 06 → 07 → 08 → 09 (nothing else created yet — no rules, interfaces, views or site).

**Findings to carry forward**
- `wikiEntries` came back CASCADING (requested NON_CASCADING) — harmless; optional Designer fix.
- Wiki `objectType` values are inconsistent → `GH_UI_objectTypeNormalize`.
- Story Item AC itemType string not yet observed in the sample (only `question`, `label` seen) — verify.
- The skill's rich-text icon alias file is missing in `/Users/ramaswamy.u/appian-dev/.kiro/skills/appian` (glob `**/*icon*` → none) — verify icons by validation.
- `a!richTextItem` / `a!headingField` are not in the skill's components registry list — standard SAIL; confirm with validateExpression.
- Working notes file (scratch): `/Users/ramaswamy.u/appian-dev/genesis-hub-site/schema-notes.md` (same content as 01).

<!-- Template for next entries:
## YYYY-MM-DD — Session N
**Created:** | Object | Type | UUID | validate | test |
**Evidence:** …
**Decisions/deviations:** …
**Next:** …
-->
