# Genesis Hub Site — progress log (append-only; newest at top)

## 2026-10-14 — Session 2b (user feedback: Applications drill-down)
**Request:** Applications page = basic cards only; clicking a card goes *inside* the app with tabs **Overview | Features | Stories**.
**Design:** in-page drill-down (local `selected` app UUID) — no new record type (decision D1 still holds). URL does not change; "‹ All applications" link returns to the list.
**Created:**
| Object | UUID | Purpose |
|---|---|---|
| GH_UI_AppOverviewTab (interface, input appUuid) | `_a-0000f08b-d302-8000-9c31-011c48011c48_29731` | 5 KPIs, delivery progress (all 8 lanes), Object Wiki objects (links), KB snapshot grid |
| GH_UI_FeatureCards (interface, inputs appUuid, showAppFilter) | `_a-0000f08b-d302-8000-9c31-011c48011c48_29721` | feature cards + search (+ app filter when appUuid null) |
| GH_UI_StoryGrid (interface, inputs appUuid, showAppFilter) | `_a-0000f08b-d302-8000-9c31-011c48011c48_29727` | record-backed story grid + filters, app fixed when appUuid set |
**Updated:** GH_UI_ApplicationsPage v2 (list of basic cards → tabLayout detail, highlight `#0284C7`); GH_UI_FeaturesPage v2 and GH_UI_StoriesPage v2 now just header + the shared component (one source for both places).
**Evidence:** smoke — Applications list (App …930416, Open application, stories, done; KB history no longer on the list = intended); AppOverview 6/6; AppFeatures (both features, search; app filter hidden = intended); AppStories 4/4;
Features + Stories pages unchanged output after refactor. validateExpression on the full tabLayout detail branch → no errors. validateDesignObject clean on all 4 changed/new objects. Read-only grep → 0.
Old page templates kept as `gen/GH_UI_FeaturesPage.v1.tpl` / `GH_UI_StoriesPage.v1.tpl` for reference.

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

- `GH_UI_WikiPageSummaryView` `_a-0000f08b-d302-8000-9c31-011c48011c48_29638` ✅ wired to GH Object Wiki Page summary (RT v7), title = objectName, news/related-actions hidden.
  Evidence: page 5 smoke → objectName, CREATED, UPDATED, story-1-1 link, "Technical details", RECORD TYPE all Y (128 ms); id 99999 → "Object not found" Y.
  Fix during build: a `sectionLayout` is NOT allowed inside a `sideBySideItem` (runtime error) — moved below the sideBySide inside the card.
- `GH_UI_FeatureSummaryView` `_a-0000f08b-d302-8000-9c31-011c48011c48_29644` ✅ wired to GH Feature summary (RT v8), title = name, news/related-actions hidden.
  Evidence: feature 1 (Multi Round Evaluations) → name, Completed, "Open Spec document", "Open UX Design document", "% done", epic-1 all Y (1.3 s, ~346 KB tree);
  feature 2 (Document Builder) renders (968 ms) incl. "Not started" stages.
  Stage docs via `GH_UI_latestBlobs` + `a!documentDownloadLink` (download). The inline HTML preview (risk 00 §8.1) was NOT added — download-only for now.
  "Objects changed" KPI = count of wiki entries via `WE.story.featureSyncUuid` relationship filter (fetchTotalCount).
- **Sub-spec 05 ✅ DONE.** Note: `updateInterface` echoes the whole expression back — prefer getting it right on create.

### Sub-specs 06–08 — page interfaces ✅ (all smoke-tested with real data via GH_UI_devSmokeView; diagnostics.error = null)
| Page | UUID | Smoke evidence |
|---|---|---|
| GH_UI_HomePage | `_a-0000f08b-d302-8000-9c31-011c48011c48_29670` | 9/9 expected strings (KPIs, both features, Stories by lane, activity feed, wiki changes), 378 ms |
| GH_UI_ApplicationsPage | `_a-0000f08b-d302-8000-9c31-011c48011c48_29680` | App …930416, KB snapshot history, features; "Other key" branch not hit (no non-app keys in data now), 1.8 s |
| GH_UI_FeaturesPage | `_a-0000f08b-d302-8000-9c31-011c48011c48_29686` | both features, % done, epics, Open feature, 2.2 s |
| GH_UI_BoardPage | `_a-0000f08b-d302-8000-9c31-011c48011c48_29691` | TO DO / CODE REVIEW / DONE lanes, "+N more" (Done has 72 > cap 25), 1.9 s |
| GH_UI_StoriesPage | `_a-0000f08b-d302-8000-9c31-011c48011c48_29710` | record-backed grid (showSearchBox), % done, 2.0 s |
| GH_UI_ObjectWikiPage | `_a-0000f08b-d302-8000-9c31-011c48011c48_29702` | KPIs incl. BUG FIXES, AS_GSS objects, RECORD TYPE, 1.4 s |
| GH_UI_TeamPage | `_a-0000f08b-d302-8000-9c31-011c48011c48_29698` | Source Selection, King Arthur, admin.user, "2 members", updates published, 0.9 s |
Extra data rules: `GH_UI_storyLaneCounts` `_a-0000f08b-d302-8000-9c31-011c48011c48_29658` (feature×lane aggregation), `GH_UI_allArtifacts` `_a-0000f08b-d302-8000-9c31-011c48011c48_29662` (all artifacts + latest doc id).
Board layout decision: 8 AUTO columns, DENSE, stacked below TABLET_LANDSCAPE, cap 25 cards/lane with show-more; non-standard lanes in an "Other lanes" card (D2). Visual check in browser still pending.

### Sub-spec 09 — site, security, verification ✅ (manual browser check pending)
- **Site `GH Genesis Hub`** uuid **`b2a3e7ef-8e92-4d86-9af8-f658cca5a33b`**, displayName "Genesis Hub", web address `genesis-hub`, layout **SIDEBAR**, 7 pages in order:
  Home(f015) · Applications(f1b2) · Features(f005 star — f0ae swapped for consistency with the star feature icon) · Board(f0db) · Stories(f03a) · Object Wiki(f02d) · Team(f0c0).
  URL: https://merge-assist-dev.appianpreview.com/suite/sites/genesis-hub
- **Security (D4):** `getObjectSecurity(site)` → administrator = GH Administrators, viewer = **GH Users**, editor none (app default security applied on create — no update needed).
  Interfaces/rules inherit GH Rules and Constants (viewer GH Users, admin GH Administrators) — verified on GH_UI_HomePage. Record types already grant GH Users viewer (Phase 36).
- **validateDesignObject = 0 errors / 0 warnings** on: site, all 7 pages, 3 views, StageTracker, StoryCard, latestBlobs, allArtifacts.
- **Read-only audit:** grep over every `GH_UI_*.sail` for `a!writeRecords|a!deleteRecords|a!startProcess|a!writeToDataStoreEntity|recordActions|a!recordActionItem|a!buttonWidget|submit:|a!submitLink|a!startProcessLink` → **0 matches**. Only inputs are local-variable filters/search + show-more dynamicLinks.
- **Hub contract unaffected:** no `GH_*` API rule, Web API, constant, record field or record-type security was modified. Record-type edits were additive only (summary views, title expressions, hide News/Related Actions).
- **Pending (manual — needs a browser):** open the site as a plain GH Users member; check visuals (esp. 8-lane Board width), record view navigation, and that "Open document" downloads the stage HTML.

**Files:** SAIL sources `/Users/ramaswamy.u/appian-dev/genesis-hub-site/*.sail`; templates + ref generator `gen/` (`python3 refs.py <Name>` → `../<Name>.sail`, then createInterface/updateInterface with that path).

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
