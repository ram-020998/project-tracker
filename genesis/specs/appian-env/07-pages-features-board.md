# 07 — Pages: Features + Board

## 1. `GH_UI_FeaturesPage` — "Features"
Header: "Features" / "Each feature moves through Spec → UX Design → Technical Design → Feature Breakdown before its stories are built."
Filters (local vars, sideBySide in the header meta or a toolbar card): **Application** dropdown (choices = distinct appUuid →
labels `GH_UI_shortUuid`, plus "All"), **Search** textField (name contains; use `a!queryFilter(operator:"includes")` with applyWhen).

Data: `a!queryRecordType(GH Feature, fields: feature fields + stageArtifacts.{stage,status,version,publishedAt,publishedBy}, relatedRecordData: stageArtifacts limit 20)` sorted updatedAt desc;
plus one grouped story aggregation (featureSyncUuid × status COUNT) and one epic aggregation (featureSyncUuid COUNT).

Layout: a card per feature (cardGroupLayout, card width ~MEDIUM_PLUS, or columns 2-up):
- Top: feature name (LARGE STRONG, link → Feature view) · "App …xxxxxx" tag (tooltip full) · updated date SECONDARY.
- Description (2 lines max via `left(...,180)`), else nothing.
- `GH_UI_StageTracker(compact: true)` — 4 coloured pills.
- Progress: progressBar % done + "x / y stories done · z epics".
- Whole card `link: a!recordLink(recordType: GH Feature, identifier: id)`.
Empty state: "No features published yet — publish a feature stage from Genesis to see it here."

## 2. `GH_UI_BoardPage` — "Board" (read-only Kanban)
Header: "Board" / "Where every story is in the delivery pipeline. Read-only — move cards in Genesis."
Filters: **Application** (appUuid via the story's feature), **Feature** dropdown (feature names), **Type** (All/Story/Task),
**Search** (title/key `includes`). Also a **"On board only"** checkbox (filter `onBoard = true`) default OFF (many stories
have onBoard null — Genesis membership is explicit; show all by default and let the user narrow).

Data: ONE `a!queryRecordType(GH Story, fields: id, backlogKey, title, storyType, appianPart, status, position, featureSyncUuid,
epic.title, feature.name, filters…, pagingInfo batchSize 500 sort position asc)`. Group in memory by status using `GH_UI_lanes()`
(`a!forEach(lanes, … wherecontains(fv!item.value, local!stories.status))` — guard empty lists).
Lane summary strip on top: 8 pills "To Do 12 · Design 3 · …" coloured by lane.

**Layout decision (8 lanes):** use `a!columnsLayout` with **8 `a!columnLayout(width:"AUTO")`** columns, `spacing:"DENSE"`,
`stackWhen: {"PHONE","TABLET_PORTRAIT","TABLET_LANDSCAPE"}`, `showDividers: true`. Each column: lane header (coloured dot +
label STRONG + count tag) then compact `GH_UI_StoryCard`s (key + type tag, 2-line title link → Story view, epic SECONDARY).
Cap each column to the first 25 cards + "+N more" text (`a!dynamicLink` toggling `local!expandedLanes` to show all).
Alternative if the 8 columns look cramped on the env's 1440px width: a **lane selector** (`a!tabLayout`? — exists via registry `a!tabItem`) with
"All lanes" = 2 rows of 4 columns. Implement 8 columns first, screenshot/inspect, then decide (record the decision in progress.md).
Empty lane: SECONDARY "No stories".
No drag & drop, no buttons other than show-more toggles (read-only, decision D7).
