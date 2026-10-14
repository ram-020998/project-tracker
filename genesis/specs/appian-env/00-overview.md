# Genesis Hub Site — a read-only Appian site over the Genesis Hub data (umbrella spec)

| | |
|---|---|
| **Status** | ✅ BUILT & LIVE (2026-10-14) — site `GH Genesis Hub` at `/suite/sites/genesis-hub`. All sub-specs 02–09 done; manual browser review by the user pending. See `progress.md`. |
| **Where it is built** | Appian env **merge-assist-dev.appianpreview.com** (Appian 26.6), app **Genesis Hub** (prefix `GH`, appUuid `_a-0000f058-fed5-8000-9bfc-011c48011c48_27312`) |
| **How it is built** | Directly in Appian with the **Appian Dev MCP write tools** (`createExpressionRule`, `createInterface`, `addRecordTypeView`, `createSite`, …) by an agent session — **NOT** through Genesis code. No genesis / genesis-workflows / genesis-core change, no release, no tag. |
| **Mandatory skill** | `/Users/ramaswamy.u/appian-dev/.kiro/skills/appian/SKILL.md` (load before ANY Appian MCP call; follow its loading strategy + Step 4A/4B verification + `validateExpression` retry loop + `testInterface`). |
| **Relates to** | ADR-063/064 (Collaboration Hub + Genesis Hub app), ADR-070 (Object Wiki), ADR-072 (GNS_ story ids), ADR-055 (Genesis design language — Indigo·Slate, used as the visual reference) |

## 1. Why

The Genesis Hub Appian application stores everything the team publishes from Genesis — features, the four
feature-stage artifacts (Spec / UX Design / Technical Design / Feature Breakdown), epics, stories with their
acceptance criteria / open questions / labels, the board lane of every story, the **Object Wiki** (per-object
change history written by the Implementation lane), teams/members, and KB snapshot history. Today **nobody can
see this inside Appian** — the data is only reachable through Genesis. This feature adds a **simple, beautiful,
read-only Appian site** so anyone in **GH Users** can browse it directly in the Appian environment.

## 2. Goals / non-goals

**Goals**
- A modern, very polished, **read-only** site ("Genesis Hub") with 7 pages + 3 record views.
- Show *all* useful data in the Hub in a digestible way (dashboards, cards, timelines, tags), not raw tables.
- Navigation from any list → a record view with its own URL (Feature, Story, Object Wiki Page).

**Non-goals (explicit)**
- **No editing**: no record actions, no forms, no `a!writeRecords`, no process models, no buttons that mutate.
- Do **not** reproduce the full Genesis UI (no chat, runs, workbench drag-drop, settings).
- Do **not** change the Hub Web APIs, the frozen JSON contract, or existing record fields.
- Do **not** delete or filter any data (user decision: show test rows as-is).
- No application-name lookup table this phase (user decision: show the app UUID).

## 3. Locked decisions (user, 2026-10-14)

| # | Question | Decision |
|---|---|---|
| D1 | App names are not stored in the Hub | **Show the app UUID** for now (short form + full in tooltip). A `GH Application` record type is a possible later enhancement. |
| D2 | Test/validation leftovers (test-blob rows, a test stage artifact) | **Do not filter** — show as-is. |
| D3 | Add wiki-entry ↔ story relationships | **Yes** — DONE (see 01 §A). |
| D4 | Who can see the site | **GH Users** (group `_e-0000f058-fe86-8000-9b49-01075c01075c_460`). |
| D5 | Site name / URL / layout | **"Genesis Hub"**, web address **`genesis-hub`** (→ `/sites/genesis-hub`), **SIDEBAR** layout. |
| D6 | Detail pages | Record **summary views** on GH Feature, GH Story, GH Object Wiki Page (own URLs, back navigation). |
| D7 | Read-only | Absolutely no record actions / forms / writes. Filters + search inputs (local variables only) are fine. |

## 4. Information architecture (approved)

```
Genesis Hub (site, SIDEBAR)
├── Home              GH_UI_HomePage           f015  KPIs, feature stage pipeline, stories-by-lane chart, recent activity, recent wiki changes
├── Applications      GH_UI_ApplicationsPage   f1b2  one card per appUuid: features, story progress, wiki objects, KB snapshot history
├── Features          GH_UI_FeaturesPage       f0ae  feature cards with 4-stage tracker → Feature record view
├── Board             GH_UI_BoardPage          f0db  read-only 8-lane Kanban, filters (app/feature/type/search)
├── Stories           GH_UI_StoriesPage        f03a  searchable/filterable backlog grid → Story record view
├── Object Wiki       GH_UI_ObjectWikiPage     f02d  object cards by type → Wiki Page record view (timeline)
└── Team              GH_UI_TeamPage           f0c0  teams + member cards
Record views (not site pages; reached via a!recordLink):
  GH Feature   → GH_UI_FeatureSummaryView
  GH Story     → GH_UI_StorySummaryView
  GH Object Wiki Page → GH_UI_WikiPageSummaryView
```
(Icon ids are Font Awesome hex codes for site page tabs — verify each renders; fall back to `f03a` if not.)

## 5. Sub-specs (build in this order)

| # | Sub-spec | Delivers | Status |
|---|---|---|---|
| 01 | `01-data-model-reference.md` | every RT/field/relationship UUID + real data values + gotchas | ✅ reference |
| 02 | `02-relationships.md` | wiki entry ↔ story relationships | ✅ DONE (live) |
| 03 | `03-helper-rules.md` | `GH_UI_*` expression rules: labels, colors, normalizers, formatters, shared queries | ✅ DONE |
| 04 | `04-shared-components.md` | `GH_UI_*` component interfaces: page header, KPI card, tag, empty state, stage tracker, lane progress, story card, section card | ✅ DONE |
| 05 | `05-record-views.md` | 3 summary views + title expressions + `addRecordTypeView` | ✅ DONE |
| 06 | `06-pages-home-applications.md` | Home + Applications pages | ✅ DONE |
| 07 | `07-pages-features-board.md` | Features + Board pages | ✅ DONE |
| 08 | `08-pages-stories-wiki-team.md` | Stories + Object Wiki + Team pages | ✅ DONE |
| 09 | `09-site-security-and-verification.md` | create the site, security, end-to-end verification, docs | ✅ DONE |
| — | `10-design-system.md` | visual language every interface must follow | reference |
| — | `progress.md` | running build log — UPDATE after every object you create | living |

Dependency order (Appian): rules (03) → component interfaces (04) → record views (05) → page interfaces (06–08) → site (09).

## 6. Definition of done

- All objects below exist in the Genesis Hub app, named with the `GH_UI_` prefix, each passes
  `validateDesignObject` with zero errors, and every page/view passes `testInterface` with real data
  (no `diagnostics.error`) for every conditional branch.
- Site `GH Genesis Hub` at `/sites/genesis-hub`, sidebar, 7 pages in the order above, visible to GH Users.
- Record views on Feature / Story / Wiki Page open from every link on every page.
- Zero write capability anywhere in the new objects (grep the expressions for `a!writeRecords`, `a!startProcess`, `recordActions` → none).
- `progress.md` + `tracker.md` §6 updated, project-tracker pushed.

## 7. Object inventory (target)

| Type | Name | Sub-spec |
|---|---|---|
| Expression rules | `GH_UI_lanes`, `GH_UI_laneLabel`, `GH_UI_laneColor`, `GH_UI_stages`, `GH_UI_stageLabel`, `GH_UI_stageStatusColor`, `GH_UI_storyTypeColor`, `GH_UI_objectTypeNormalize`, `GH_UI_objectTypeIcon`, `GH_UI_changeKindColor`, `GH_UI_formatDateTime`, `GH_UI_shortUuid`, `GH_UI_fileSize`, `GH_UI_latestArtifactDoc` | 03 |
| Component interfaces | `GH_UI_PageHeader`, `GH_UI_KpiCard`, `GH_UI_TagList`, `GH_UI_EmptyState`, `GH_UI_StageTracker`, `GH_UI_LaneProgress`, `GH_UI_StoryCard`, `GH_UI_LabelValue` | 04 |
| Record views | `GH_UI_FeatureSummaryView`, `GH_UI_StorySummaryView`, `GH_UI_WikiPageSummaryView` | 05 |
| Page interfaces | `GH_UI_HomePage`, `GH_UI_ApplicationsPage`, `GH_UI_FeaturesPage`, `GH_UI_BoardPage`, `GH_UI_StoriesPage`, `GH_UI_ObjectWikiPage`, `GH_UI_TeamPage` | 06–08 |
| Site | `GH Genesis Hub` | 09 |

Rules folder for all of them: **GH Rules and Constants** `_a-0000f058-fed5-8000-9bfc-011c48011c48_27319` (pass `appUuid` and the tool picks it).

## 8. Risks / open items

1. **HTML artifact viewing** — stage artifacts are HTML documents (Spec/UX/TD/Breakdown, 30–430 KB). `a!documentViewerField`
   may download rather than render HTML. Plan: provide `a!documentDownloadLink` ("Open document") always; try
   `a!documentViewerField` in the Feature view behind a "Preview" toggle and keep it only if it renders (sub-spec 05 §3).
2. **Story Item AC itemType value** — confirm the exact string (01 §C) before filtering.
3. **Icon names** — the skill's rich-text icon alias file is missing from this skill install; verify icons by
   `validateExpression`/`testInterface` (an invalid icon errors) or the Appian docs "Rich Text Icon" alias list. Use
   conservative, well-known aliases (`check-circle`, `circle`, `clock-o`, `file-text-o`, `cube`, `users`, `user`,
   `book`, `columns`, `list`, `history`, `tag`, `bug`, `code`, `database`, `sitemap`).
4. **Wide board** — 8 lanes don't fit comfortably; sub-spec 07 specifies the layout decision.
5. **Record-level security** — confirm a plain GH Users member can see the data (09).
