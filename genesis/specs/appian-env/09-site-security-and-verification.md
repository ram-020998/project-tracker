# 09 — Site creation, security, verification & documentation

## 1. Create the site (only after every page interface passes `testInterface`)
`listSites(appUuid)` first (there is currently **no** site in the app). Then:
```
createSite(
  appUuid: "_a-0000f058-fed5-8000-9bfc-011c48011c48_27312",
  name: "GH Genesis Hub", displayName: "Genesis Hub", webAddressIdentifier: "genesis-hub",
  layout: "SIDEBAR",
  description: "Read-only view of everything published to the Genesis Hub.",
  pages: [
    {name:"Home",         type:"INTERFACE", targetUuid:<GH_UI_HomePage>,         iconId:"f015", webAddressIdentifier:"home"},
    {name:"Applications", type:"INTERFACE", targetUuid:<GH_UI_ApplicationsPage>, iconId:"f1b2", webAddressIdentifier:"applications"},
    {name:"Features",     type:"INTERFACE", targetUuid:<GH_UI_FeaturesPage>,     iconId:"f0ae", webAddressIdentifier:"features"},
    {name:"Board",        type:"INTERFACE", targetUuid:<GH_UI_BoardPage>,        iconId:"f0db", webAddressIdentifier:"board"},
    {name:"Stories",      type:"INTERFACE", targetUuid:<GH_UI_StoriesPage>,      iconId:"f03a", webAddressIdentifier:"stories"},
    {name:"Object Wiki",  type:"INTERFACE", targetUuid:<GH_UI_ObjectWikiPage>,   iconId:"f02d", webAddressIdentifier:"object-wiki"},
    {name:"Team",         type:"INTERFACE", targetUuid:<GH_UI_TeamPage>,         iconId:"f0c0", webAddressIdentifier:"team"}
  ])
```
(`style` is only for HEADER_BAR — omit with SIDEBAR. If `genesis-hub` is taken env-wide, ask the user.)

## 2. Security (decision D4 — GH Users)
- `getObjectSecurity(<site uuid>)` → set **viewer = GH Users** (`_e-0000f058-fe86-8000-9b49-01075c01075c_460`), administrator = GH Administrators (`_e-…_458`) via `updateObjectSecurity` (full replacement — include every role returned). Applying the app's default security on create may already do this — check first.
- All new interfaces/rules inherit the GH Rules and Constants folder security (GH Users viewer) — verify one with `getObjectSecurity`.
- Record types already grant viewer to GH Users (Phase 36). No page `visibilityExpr` needed.
- **Never** grant GH Users editor/admin on anything; never touch GH Service Accounts grants (they back the Web APIs).

## 3. Verification checklist (cite evidence in progress.md)
1. `validateDesignObject` = 0 errors for every `GH_UI_*` object (list them).
2. `testInterface` for every page (no inputs) and every record view (2+ real records each) — `diagnostics.error` empty; capture response sizes.
3. Read-only audit: `grep` the saved expressions (via getInterface to files) for `a!writeRecords|a!startProcess|recordActions|a!deleteRecords|submit: true` → none.
4. Hub contract unaffected: Genesis pull still works (`POST /api/collab/pull` on a running Genesis instance, or a Hub `GET /records/story/<syncUuid>` with the service-account key) → 200, shape unchanged.
5. Manual (headless can't do it): open `https://merge-assist-dev.appianpreview.com/suite/sites/genesis-hub` as a GH Users member — all 7 pages render, cards link to record views, record view titles show, Story view shows AC/questions/wiki changes, Feature view opens stage documents, nothing editable. Ask the user to do this and report back.
6. Performance: each page loads < ~3 s; no per-row queries inside `a!forEach`.

## 4. Documentation (Definition of Done)
- Update `specs/appian-env/progress.md` (every object name + UUID + test evidence).
- Mark sub-spec statuses in `00-overview.md` §5.
- `tracker.md` §6: a dated entry ("Genesis Hub read-only Appian site — built in merge-assist-dev; no Genesis code/release").
- `bible/08-roadmap-and-backlog.md` §9: a short SHIPPED block pointing to `specs/appian-env/` (no repo tags changed).
- Push project-tracker (`git pull --rebase` then push; commit with `git -c user.name=Genesis -c user.email=genesis@local commit`).
