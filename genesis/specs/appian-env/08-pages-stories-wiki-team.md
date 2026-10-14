# 08 — Pages: Stories + Object Wiki + Team

## 1. `GH_UI_StoriesPage` — "Stories"
Header: "Stories" / "The full backlog across every feature."
Toolbar filters (local vars): Application, Feature, Epic (dependent on feature), Type (Story/Task), Lane (multiple dropdown from
`GH_UI_lanes()`), Appian part (distinct values via grouping), Search. All filters → `a!queryFilter(…, applyWhen: …)` inside `a!recordData(filters: a!queryLogicalExpression("AND", …))`.
KPI strip (small): Showing N · Done x% · Stories vs Tasks.

Main = `a!gridField(data: a!recordData(recordType: GH Story, filters: …), pageSize: 25, showSearchBox: true, rowHeader: 2, showExportButton: false)`
(record data → search box allowed). Columns:
1. **Key** — backlogKey SMALL STRONG (sortField backlogKey).
2. **Title** — `a!richTextDisplayField(labelPosition:"COLLAPSED", value: a!richTextItem(text: title, link: a!recordLink(GH Story, fv!row[id])))` (MUST be wrapped).
3. **Type** — tag (GH_UI_storyTypeColor).
4. **Lane** — tag with lane colours.
5. **Feature** — `fv!row[feature.name]` (related field — include in recordData `fields` if needed).
6. **Epic** — `fv!row[epic.title]`.
7. **Appian part** — tag slate.
8. **Updated** — GH_UI_formatDateTime(updatedAt, false), sortField updatedAt.
Default sort: feature, epic position, position (or updatedAt desc). Empty message: "No stories match these filters."

## 2. `GH_UI_ObjectWikiPage` — "Object Wiki"
Header: "Object Wiki" / "What every Appian object is for, and every change Genesis made to it — in business and technical terms."
Filters: Application, Object type (normalized types — compute choices from a grouping on objectType then map through
`GH_UI_objectTypeNormalize` + `union()`), Change kind (created/updated/deprecated — filters pages having such entries: simpler = filter in memory), Search (objectName `includes`).
KPI strip: Objects · Changes · Created / Updated / Deprecated counts (Wiki Entry grouped by changeKind) · Bug fixes (isBugfix=1).

Layout: card grid (cardGroupLayout or 3 columns), sorted updatedAt desc, one card per GH Object Wiki Page:
- type icon stamp (colour per type) + objectName (STRONG, link → Wiki Page view) + normalized type tag.
- currentSummary truncated to ~220 chars (`left()` null-guarded) SECONDARY.
- footer: "v{version} · {n} changes · updated {date}" (n from a Wiki Entry grouping by pageSyncUuid).
Because type filtering must work on the normalized type, query all pages (batch 500 — ~10 today) and filter in memory.

## 3. `GH_UI_TeamPage` — "Team"
Header: "Team" / "Collaboration teams and the people publishing to the Hub."
Data: GH Team with `memberships.{username,name,email,joinedAt}` (relatedRecordData limit 250). Plus per-username contribution
counts (optional, nice): Change Log grouped by publishedBy (COUNT) → "N updates published".
Layout: per team a section card: team title (LARGE), created by/at, member count tag; members as cards (columns 3-up):
initials avatar (stamp with text = first letters of name, brand background), name STRONG, username SECONDARY, email SMALL,
"Joined {date}", contributions count. (Usernames are text; do not call `user()` unless guarded — see 01 §D.1.)
Empty: "No teams yet — teams are created from Genesis Settings → Collaboration."
