# 05 — Record summary views (Feature, Story, Object Wiki Page)

Detail pages reached from every list via `a!recordLink(recordType: <RT>, identifier: <id>)`. Each is an interface with
input **`record`** typed as the record type (`typeReference` below) — Appian passes `rv!record`; the view then re-queries
what it needs with `a!queryRecordByIdentifier(recordType, identifier: rv!identifier-equivalent, fields: {...}, relatedRecordData: {...})`
(fields are REQUIRED — omitted fields come back null; up to 250 related rows per relationship).
Wire with `addRecordTypeView(uuid, nameExpression: '="Summary"', interfaceExpression: 'rule!GH_UI_XSummaryView(record: rv!record)')`
— the first view added becomes **Summary** (it cannot use RULES security; leave visibility default). Then
`updateRecordType(uuid, titleExpression: …)` and `hideNewsView: true`, `hideRelatedActionsView: true` (no actions exist).
Use display components only (no input fields). Layout = `a!headerContentLayout` with a `GH_UI_PageHeader` card header.

typeReferences: Feature `{urn:com:appian:recordtype:datatype}5ff1c823-0ff9-4a59-943b-3314aad3b6f7` · Story
`{urn:com:appian:recordtype:datatype}31c5187d-3c6f-467a-be02-d4549d98a822` · Wiki Page
`{urn:com:appian:recordtype:datatype}29ede62a-36af-4980-9019-2c651727e0d9`.

## 1. Title expressions
- GH Feature: `rv!record['recordType!{5ff1c823-0ff9-4a59-943b-3314aad3b6f7}GH Feature.fields.{05b2cf90-de64-454e-a30d-ab2790d559a8}name']`
- GH Story: `concat(a!defaultValue(rv!record[<backlogKey 89fb1002…>],""), if(a!isNotNullOrEmpty(rv!record[<backlogKey>])," · ",""), rv!record[<title e64b3bd3…>])`
- GH Object Wiki Page: `rv!record[<objectName 30a2b685…>]`
(Check `getRecordType` first — Story/Blob Version have an empty titleExpression; Feature/Wiki have none.)

## 2. `GH_UI_StorySummaryView` (most important view)
Query: `a!queryRecordByIdentifier(GH Story, identifier: ri!record[id], fields: all story fields + feature.name + feature.appUuid +
epic.title + epic.backlogKey + storyItems.{itemType,text,position} + wikiEntries.{id,changeKind,storyKey,objectVersion,createdAt,authorUsername,businessDescription} + wikiEntries.page.{id,objectName,objectType}`,
relatedRecordData: storyItems sort position asc limit 250; wikiEntries sort createdAt desc limit 100).
(If a 2-hop `wikiEntries.page` field ref is not allowed in fields, query entries separately with `a!queryRecordType` on Wiki Entry filtered `storySyncUuid = story.syncUuid`, fields incl. `page.objectName`.)

Layout:
- **Header** (`GH_UI_PageHeader`): key (e.g. `story-3-1` / `GNS_000123`) small, title H1, tags: storyType, lane (lane colours), appianPart, category; meta right: "Feature: <name>" link → Feature view, "Epic: <title>".
- **Lane progress strip**: the 8 lanes as a horizontal stepper (milestone-like) with the story's lane highlighted and earlier lanes ✓ (index order from `GH_UI_lanes()`).
- Columns (WIDE_PLUS main / MEDIUM side, stackWhen TABLET):
  - Main:
    - **User story** card: description rendered as 3 lines with "As a / I want / So that" bolded (split on `char(10)`; bold the leading phrase if the line starts with it).
    - **Acceptance criteria** card: items with itemType = AC value (VERIFY — 01 §C) ordered by position; each criterion rendered with Gherkin keywords (`Given`, `When`, `Then`, `And`, `But`) bolded in brand colour at line starts; numbered.
    - **Open questions** card: itemType `question`, numbered list; empty → EmptyState "No open questions".
    - **Objects changed** card: wikiEntries grid/list — object name (link → Wiki Page view), normalized type tag, changeKind tag, version, author, date; empty → "Not implemented yet".
  - Side:
    - **Details** (`GH_UI_LabelValue`s): Type, Lane, Appian part, Category, Position, Owner, Version, Created by/at, Updated at, On board (Yes/No/—).
    - **Labels** (itemType `label`) as tags.
    - **Dev note** card: devNoteRef text with a `file-text-o` icon.
    - **Sync** (small, SECONDARY): syncUuid (full), feature/epic sync UUIDs — useful for debugging.

## 3. `GH_UI_FeatureSummaryView`
Query feature by id with fields + `stageArtifacts.{stage,status,version,publishedBy,publishedAt,blobKey,contentHash,upstreamVersions}`,
`epics.{id,backlogKey,title,description,position}` (sort position), `stories.{id,backlogKey,title,storyType,status,appianPart,epicSyncUuid}` (limit 250).
Plus a lane aggregation: `a!queryRecordType(GH Story, aggregationFields(grouping status, COUNT id), filter featureSyncUuid = feature.syncUuid)`.

Layout:
- Header: feature name H1, subtitle "App <GH_UI_shortUuid(appUuid)>" (tooltip full uuid), created by/at, owner/team if present.
- KPI row (4): Stories total, Done %, Epics, Objects changed (count wiki entries whose story is in this feature — aggregate on Wiki Entry with filter `story.featureSyncUuid` if relationship filter works; else count via the stories list).
- **Stage pipeline** (`GH_UI_StageTracker`, full mode): 4 stage cards; each completed stage card has **"Open document"** = `a!documentDownloadLink(label: "Open", document: GH_UI_latestArtifactDoc(blobKey).documentId)` and shows `v{version} · published by {publishedBy} · {date}` + upstreamVersions ("built from Spec v3, UX v2") when present.
  - Preview (risk 00 §8.1): add a `local!previewStage` dynamicLink "Preview"; when set, show `a!documentViewerField(document: …, height:"TALL")`. Test with a real artifact; if the HTML doesn't render inline, remove the preview and keep only the download link.
- **Progress**: `GH_UI_LaneProgress` from the aggregation.
- **Epics & stories**: for each epic (position order) a collapsible `a!sectionLayout(isCollapsible: true, labelHeadingTag:"H3", label: "<epic-key> · <title> (n stories, x done)")` containing epic description + a compact list of `GH_UI_StoryCard`s (stories filtered by epicSyncUuid). Stories with no epic → "Unassigned" section.

## 4. `GH_UI_WikiPageSummaryView`
Query page by id with fields + `entries.{…all entry fields…}` sorted createdAt desc (limit 250) + `entries.story.{id,title,backlogKey}` (new relationship).
Layout:
- Header: type icon stamp (`GH_UI_objectTypeIcon`), objectName H1, normalized type tag, "App …xxxxxx", version, last updated.
- **Current summary** card (currentSummary, larger text).
- **Change timeline**: one card per entry (newest first): left = coloured dot/icon by changeKind; right = changeKind tag + "Bug fix" tag (isBugfix=1) + `v{objectVersion}` + author + date; **Business** paragraph; **Technical** paragraph inside a collapsible section (collapsed by default, labelHeadingTag H4); "From story: <storyKey · title>" linked to the Story view (via `entries.story.id`; if the story isn't in the Hub, plain storyKey); changeReason SECONDARY.
- Side: Details (objectUuid full, appUuid full, owner, team, created by/at, modified by, syncUuid).

## 5. Verification for this sub-spec
- `testInterface` each view with a real `record` (pass `{"record": {"<id field name>": <id>}}` or the identifier input) — ids: Feature 1 and 2; Story 1 (no wiki) and the story with syncUuid `27dde3a9-17c3-4d63-9d5f-d78269ea8a91` (has wiki entries); Wiki Page 5.
- Open a record view URL in a browser (manual check) and confirm the header, tabs and links render.
