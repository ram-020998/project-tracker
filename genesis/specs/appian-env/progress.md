# Genesis Hub Site — progress log (append-only; newest at top)

## 2026-10-14 — Session 2 (implementation)
**Health check:** app had 0 sites, 1 interface (`GH_BlobVersionDocumentSummary`), 12 `GH_*` API rules, no `GH_UI_*` objects.
**Data finding:** Story Item AC itemType = **`ac`** (others `question`, `label`) — recorded in 01 §C.
**Finding:** blob version numbers are independent of stage-artifact `version` (e.g. spec artifact v3 → blob v1). Show the artifact version; use the blob only for the document.

### Sub-spec 03 — helper rules ✅ (all in GH Rules and Constants)
| Rule | UUID | Tests |
|---|---|---|
| GH_UI_lanes | `_a-0000f08b-d302-8000-9c31-011c48011c48_29457` | validated on create |
| GH_UI_stages | `_a-0000f08b-d302-8000-9c31-011c48011c48_29453` | validated on create |
| GH_UI_laneLabel | `_a-0000f08b-d302-8000-9c31-011c48011c48_29479` | 4/4 pass |
| GH_UI_laneColor | `_a-0000f08b-d302-8000-9c31-011c48011c48_29484` | validated (testInputs done) |
| GH_UI_stageLabel | `_a-0000f08b-d302-8000-9c31-011c48011c48_29475` | validated |
| GH_UI_stageStatusColor | `_a-0000f08b-d302-8000-9c31-011c48011c48_29496` | validated |
| GH_UI_stageStatusLabel (extra) | `_a-0000f08b-d302-8000-9c31-011c48011c48_29471` | validated |
| GH_UI_storyTypeColor | `_a-0000f08b-d302-8000-9c31-011c48011c48_29509` | validated |
| GH_UI_changeKindColor | `_a-0000f08b-d302-8000-9c31-011c48011c48_29500` | validated |
| GH_UI_objectTypeNormalize | `_a-0000f08b-d302-8000-9c31-011c48011c48_29504` | 6/6 pass |
| GH_UI_objectTypeIcon | `_a-0000f08b-d302-8000-9c31-011c48011c48_29535` | validated |
| GH_UI_objectTypeColor | `_a-0000f08b-d302-8000-9c31-011c48011c48_29531` | validated |
| GH_UI_formatDateTime | `_a-0000f08b-d302-8000-9c31-011c48011c48_29488` | 3/3 pass ("Sep 6, 2026 6:03 PM") |
| GH_UI_shortUuid | `_a-0000f08b-d302-8000-9c31-011c48011c48_29465` | 4/4 pass |
| GH_UI_fileSize | `_a-0000f08b-d302-8000-9c31-011c48011c48_29492` | 5/5 pass |
| GH_UI_latestBlobs (replaces planned GH_UI_latestArtifactDoc) | `_a-0000f08b-d302-8000-9c31-011c48011c48_29560` | testRule: 2 keys → 2 latest docs (5249, 5245), unknown key skipped, 15 ms |

Signatures: laneColor/stageStatusColor/storyTypeColor/changeKindColor/objectTypeColor take `(value, soft Boolean)`.
`GH_UI_latestBlobs(blobKind Text, blobKeys List of Text)` → List of Map {blobKey, documentId, version, size, publishedBy, createdAt}.
`GH_UI_formatDateTime(value, withTime)` — withTime defaults to true. SAIL sources: `/Users/ramaswamy.u/appian-dev/genesis-hub-site/*.sail`.

### Sub-spec 04 — shared components ✅
| Interface | UUID | Inputs | Evidence |
|---|---|---|---|
| GH_UI_PageHeader | `_a-0000f08b-d302-8000-9c31-011c48011c48_29570` | title, subtitle, eyebrow, icon, color, meta(Any) | created w/ testInputs; testInterface OK (ContentLayout, 75 ms) |
| GH_UI_KpiCard | `_a-0000f08b-d302-8000-9c31-011c48011c48_29576` | label, value, icon, color, softColor, hint | testInterface OK |
| GH_UI_TagList | `_a-0000f08b-d302-8000-9c31-011c48011c48_29584` | tags (Map list {text,color,soft,tooltip}), label | testInterface OK (empty → nothing) |
| GH_UI_EmptyState | `_a-0000f08b-d302-8000-9c31-011c48011c48_29580` | icon, title, message | testInterface OK (null defaults) |
| GH_UI_LabelValue | `_a-0000f08b-d302-8000-9c31-011c48011c48_29566` | label, value (Text) | testInterface OK (null → "—") |
| GH_UI_StageTracker | `_a-0000f08b-d302-8000-9c31-011c48011c48_29600` | artifacts (Map list {stage,status,version,publishedBy,publishedAt,documentId}), compact | full + compact modes OK; with-data branch evaluated at create |
| GH_UI_LaneProgress | `_a-0000f08b-d302-8000-9c31-011c48011c48_29596` | counts (Map list {status,count}), showLegend, showAllLanes | empty branch OK; data branch evaluated at create |
| GH_UI_StoryCard | `_a-0000f08b-d302-8000-9c31-011c48011c48_29608` | story (Map {id,backlogKey,title,storyType,appianPart,status,epicTitle,featureName}), showLane | null branch OK; card links to GH Story record |

**Learnings:** `a!richTextDisplayField` has NO `numberOfLines` param on this env (rejected). Icon aliases verified valid by validateExpression:
file-text-o, paint-brush, sitemap, list, database, desktop, code, thumb-tack, table, plug, globe, users, user, cube, cubes, star, flag, check-square-o,
columns, book, cloud-upload, circle, check-circle, clock-o, history, tag, bug, folder-open, rocket, th-large, layer-group, bolt, inbox, bar-chart, tasks,
comment, question-circle, external-link, eye, download, arrow-right, calendar, envelope, info-circle, search, filter, code-fork, shield, dot-circle-o.
**INVALID:** `chart-bar`. Validation does catch bad icons (control test). `testInterface` ignores maxResponseSizeBytes (returns the full tree) — use sparingly.

### Sub-spec 05 — record views (in progress)
- **Deviation:** views take input **`identifier` (Number (Integer))** and are wired as `rule!GH_UI_XSummaryView(identifier: rv!identifier)` (simpler + testable), instead of a `record` input.
- **Bootstrap:** `a!recordLink` to a record type with NO summary view fails validation. Feature + Wiki Page had no views, so a placeholder Summary view was added to each first (Feature RT v6, Wiki Page RT v5), then replaced by the real interface.
- GH Story already had a Summary view in RULES mode with an empty UI; it was converted to EXPRESSION `=true()` + the new interface (RT v9→v10).
- `GH_UI_richLines` `_a-0000f08b-d302-8000-9c31-011c48011c48_29614` (extra helper): bolds leading Gherkin/user-story keywords per line.
- `GH_UI_StorySummaryView` `_a-0000f08b-d302-8000-9c31-011c48011c48_29620` ✅ wired to GH Story summary; title = `backlogKey · title`; hideNewsView + hideRelatedActionsView.
  Evidence: story 1 renders (5 AC with Gherkin bolding, 4 questions, label, dev note, "Objects changed (0)" empty state);
  story **73** (`27dde3a9…`, story-1-1) smoke → `Objects changed (3)=Y, AS_GSS=Y, CREATED=Y` — **sub-spec 02 relationship `WE.story` verified**.
- Test helpers (read-only, not in the site): `GH_UI_devSmokeTest` rule `_a-0000f08b-d302-8000-9c31-011c48011c48_29626` (target `storyIdBySync` → find story id by syncUuid);
  `GH_UI_devSmokeView` interface `_a-0000f08b-d302-8000-9c31-011c48011c48_29632` — renders a target and prints `SMOKE <target> chars=N expect=a=Y,b=N` (pipe-separated expectText). Use it instead of raw testInterface (which dumps 50 KB trees). Add new targets to `gen/GH_UI_devSmokeView.full.tpl` as pages are built.
- SAIL generator: `/Users/ramaswamy.u/appian-dev/genesis-hub-site/gen/refs.py` (`@RT(S)`, `@F(S.feature.name)` macros → full UUID refs); templates `gen/*.tpl` → `../*.sail`.

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
