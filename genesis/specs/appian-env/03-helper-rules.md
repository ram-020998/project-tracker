# 03 — Helper expression rules (`GH_UI_*`)

Small, pure, null-safe rules so every page renders labels/colours identically. Create with `createExpressionRule`
(`appUuid` = Genesis Hub → lands in GH Rules and Constants). **Before creating:** `listExpressionRules(appUuid)` to
avoid collisions (existing API rules: `GH_isServiceCaller`, `GH_errorResponse`, `GH_appendChangeLog`, `GH_changesSince`,
`GH_recordToJson`, `GH_casUpsert`, `GH_reassembleStoryItems`, `GH_queryRecords`, `GH_blobLatest`, `GH_pruneBlobVersions`,
`GH_recordBlobVersion`, `GH_convertDocumentToBase64String` — **never modify these**; they back the Hub Web APIs).
Workflow per rule: write SAIL to a local file → `validateExpression` → `createExpressionRule` with `testInputs` →
`createExpressionRuleTestCases` (EXPECTED_OUTPUT) → `runAllExpressionRuleTestCases` green.
Colours/labels come from `10-design-system.md` (§2–§4) — keep them in sync.

| Rule | Inputs | Returns | Behavior |
|---|---|---|---|
| `GH_UI_lanes` | — | List of Map `{value,label,color,soft}` | The 8 lanes in board order (10 §2). Single source for Board columns, Home chart, lane progress. |
| `GH_UI_laneLabel` | `status` Text | Text | lookup in `GH_UI_lanes()` by value; unknown → `a!defaultValue(ri!status,"—")`. |
| `GH_UI_laneColor` | `status` Text, `soft` Boolean | Text hex | color (or soft) of the lane; unknown → `#64748B` / `#F1F5F9`. |
| `GH_UI_stages` | — | List of Map `{value,label,icon}` | spec / ux_design / technical_design / breakdown (10 §3). icons e.g. `file-text-o`, `paint-brush`, `sitemap`, `list`. |
| `GH_UI_stageLabel` | `stage` Text | Text | from `GH_UI_stages()`; unknown → raw. |
| `GH_UI_stageStatusColor` | `status` Text | Text hex | completed `#059669`, in-review `#D97706`, in-progress `#0284C7`, draft `#64748B`, null → `#94A3B8`. Also expose label: `GH_UI_stageStatusLabel` OPTIONAL (completed→"Completed", null→"Not started"). |
| `GH_UI_storyTypeColor` | `storyType` Text, `soft` Boolean | Text hex | Story → brand, Task → slate. |
| `GH_UI_objectTypeNormalize` | `objectType` Text | Text | Normalizes the inconsistent wiki `objectType` values: `lower()`, strip spaces/underscores (`stripwith(lower(x)," _-")`) then a!match: `recordtype`→"Record Type", `interface`→"Interface", `expressionrule`/`rule`→"Expression Rule", `processmodel`→"Process Model", `constant`→"Constant", `recorddata`/`referencedata`/`data`→"Reference Data", `integration`→"Integration", `connectedsystem`→"Connected System", `webapi`→"Web API", `site`→"Site", `group`→"Group", `cdt`/`datatype`→"Data Type", `decision`→"Decision", default → `proper`-ish raw (`a!defaultValue(ri!objectType,"Other")`). Null-safe (guard `lower` on null). |
| `GH_UI_objectTypeIcon` | `objectType` Text (raw) | Text | icon alias per normalized type: Record Type `database`, Interface `desktop`, Expression Rule `code`, Process Model `sitemap`, Constant `thumb-tack`, Reference Data `table`, Integration `plug`, default `cube`. Verify each alias renders. |
| `GH_UI_objectTypeColor` | `objectType` Text | Text hex | per 10 §4. |
| `GH_UI_changeKindColor` | `changeKind` Text | Text hex | created success, updated warning, deprecated danger, else slate. |
| `GH_UI_formatDateTime` | `value` Date and Time, `withTime` Boolean | Text | null → "—"; else `text(ri!value, if(withTime,"MMM d, yyyy h:mm a","MMM d, yyyy"))` (guard null BEFORE `text()`). |
| `GH_UI_shortUuid` | `uuid` Text | Text | null → "—"; for app UUIDs like `_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416` return a readable short form: `"App …" & right(uuid, 6)` (e.g. "App …930416"); for plain UUIDs `left(uuid,8)`. Pages show this with the full UUID in a tooltip (decision D1). |
| `GH_UI_fileSize` | `bytes` Number (Integer) | Text | null → "—"; <1024 "N B"; <1048576 `fixed(b/1024,1)&" KB"`; else `fixed(b/1048576,1)&" MB"`. |
| `GH_UI_latestArtifactDoc` | `blobKey` Text | Document (or Integer) | `a!queryRecordType` on GH Blob Version, filters blobKind="artifact" AND blobKey=ri!blobKey (applyWhen not null), sort version desc, batchSize 1, fields documentId,version,size,createdAt → return the map `{documentId, version, size, createdAt}` or null. Used by the Feature view to open/download stage artifacts. |

## Notes
- Every `a!queryFilter` with a variable value MUST set `applyWhen: a!isNotNullOrEmpty(...)`.
- Aggregation measures need a `field` even for COUNT (use the `id` field).
- `fixed()` / `proper()` are standard Appian functions but not in the skill's function table → verify via Tier 2A
  (`functions.json`) before use, or avoid (`proper` is not needed).
- Test cases to create (minimum): `GH_UI_laneLabel("design-review")="Design Review"`, unknown → raw; `GH_UI_objectTypeNormalize`
  for each observed value (`Record Type`,`record_type`,`recordData`,`constant`, null); `GH_UI_fileSize(2892892)="2.8 MB"`;
  `GH_UI_formatDateTime(null,true)="—"`; `GH_UI_shortUuid("_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416")="App …930416"`.
