# 06 — Pages: Home + Applications

Site page interfaces have **no inputs** — each queries its own data. Use `a!queryRecordType` (aggregations for KPIs,
`batchSize: 1` for single-value aggregates), `a!recordData` only inside grid/chart `data`. Every variable-valued filter
needs `applyWhen`. Layout per `10-design-system.md`.

## 1. `GH_UI_HomePage` — "Genesis Hub"
Header: `GH_UI_PageHeader(title:"Genesis Hub", subtitle:"Everything your team has published from Genesis — features, stories, designs and the Object Wiki.", icon:"cubes" or "cube")`.

**Row 1 — KPI cards (6, `GH_UI_KpiCard`):**
| KPI | Query | Link |
|---|---|---|
| Applications | distinct appUuid across GH Feature (aggregation grouping appUuid → count of groups) | Applications page (site page link not available from SAIL → no link, or recordLink none) |
| Features | COUNT GH Feature.id | — |
| Stories | COUNT GH Story.id; hint "{n} tasks" (storyType=Task) | — |
| Done | COUNT stories status="done" → value "{pct}%" , hint "{done} of {total}" | — |
| Objects documented | COUNT GH Object Wiki Page.id; hint "{entries} changes" | — |
| Team members | COUNT GH Membership.id; hint "{teams} team(s)" | — |
(Site pages cannot be deep-linked from SAIL reliably; leave KPI links off, or use `a!recordLink` without identifier to open a record list only if a list is configured — not required.)

**Row 2 (columns WIDE_PLUS | MEDIUM_PLUS):**
- Left card **"Feature pipeline"**: one row per feature (query all features with `stageArtifacts` related fields + per-feature story counts via a grouped aggregation `featureSyncUuid` × `status`): feature name (link → Feature view) · `GH_UI_StageTracker(compact: true)` · mini progress bar (% done) · "n stories".
- Right card **"Stories by lane"**: `a!columnChartField` or `a!barChartField` with categories = lane labels in `GH_UI_lanes()` order, one series "Stories", data = grouped COUNT by status mapped onto lanes (missing lanes = 0); use `a!chartCustomColorScheme`? — a single series takes one colour; acceptable: brand colour. Alternative that shows lane colours: a list of 8 rows (lane pill + count + thin progress bar). **Recommended: the 8-row list** (prettier, uses lane colours).

**Row 3 (columns 1X | 1X):**
- **"Recent activity"**: GH Change Log, sort id desc, batch 12: icon by kind (feature `star`, epic `flag`, story `check-square-o`, stage_artifact `file-text-o`, board_state `columns`, wiki_page/wiki_entry `book`, blob `cloud-upload`, team/membership `users`, other `circle`), text "{publishedBy} updated {kind label} · v{version}", relative/abs time (GH_UI_formatDateTime). Kind label map: feature→"a feature", stage_artifact→"a stage document", story→"a story", epic→"an epic", board_state→"a board lane", wiki_entry→"the Object Wiki", blob→"a snapshot". (Resolving the entity name per row is optional — if done, batch-query by syncUuid per kind with `in` filters; do NOT query per row.)
- **"Latest Object Wiki changes"**: GH Object Wiki Entry sort createdAt desc, batch 6, fields incl. `page.objectName`, `page.id`, `page.objectType`: type icon · objectName (link → Wiki Page view) · changeKind tag · storyKey · date · first ~140 chars of businessDescription (`left(…,140)&"…"`, null-guarded).

Empty states for every card.

## 2. `GH_UI_ApplicationsPage` — "Applications"
Header: title "Applications", subtitle "Appian applications that have Genesis data in the Hub."
Data: distinct appUuid values from GH Feature (grouping) ∪ GH Object Wiki Page (grouping) ∪ GH Blob Version where blobKind="kb" (blobKey grouping). Union the UUID lists (`union()`), then per app compute (with grouped aggregations, not per-app queries where avoidable):
- features (from feature grouping counts), stories + done (Story grouped by `feature.appUuid` × status if related-field grouping is supported; otherwise map featureSyncUuid→appUuid in memory from the feature list — there are few features),
- wiki objects (Wiki Page grouping by appUuid), wiki changes,
- KB snapshots: GH Blob Version blobKind="kb", blobKey=appUuid → count, latest version, latest createdAt, latest size, latest publishedBy.

Layout: one large card per application (cardGroupLayout or columns 1X/1X):
- Title: `GH_UI_shortUuid(appUuid)` (STRONG, LARGE) with the **full UUID** below in SMALL SECONDARY (decision D1: UUID only — no name).
- Stat row: Features · Stories · Done % · Wiki objects · KB snapshots.
- "Features" list: each feature name (link → Feature view) + compact StageTracker.
- "KB snapshot history" (collapsible section): a small local grid (`a!gridField` over a list of maps — **no showSearchBox**) of the last 10 kb blob versions for the app: version, size (`GH_UI_fileSize`), published by, date. Note keys that are not app UUIDs (test keys like `test-blob-1`) will appear as their own "application" cards — **expected (decision D2: don't filter)**. Optionally sort app cards so real app UUIDs (starting with `_a-`) come first.
