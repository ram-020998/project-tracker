# AGENT ONBOARDING — Genesis Hub read-only Appian site (`specs/appian-env/`)

> Read this first. It tells you what the feature is, what is already done, which documents to read in which order,
> the rules you must follow, and exactly where to start. **Then update `progress.md` as you work.**

## 1. The feature in one paragraph
Genesis publishes team data (features, stage documents, epics, stories + acceptance criteria/questions/labels, board lanes,
the Object Wiki, teams, KB snapshots) to the **Genesis Hub** Appian application. Nobody can see that data inside Appian today.
We are building a **simple, very polished, strictly read-only Appian site "Genesis Hub"** (`/sites/genesis-hub`, sidebar,
visible to **GH Users**) with **7 pages** (Home, Applications, Features, Board, Stories, Object Wiki, Team) and **3 record
views** (Feature, Story, Object Wiki Page). It is built **directly in Appian with the Dev MCP write tools** — there is **no
Genesis code change, no release, no tag**.

## 2. Environment & identifiers you need
- Env: `https://merge-assist-dev.appianpreview.com` (Appian 26.6). Tools: the `appian` MCP tools in your tool list
  (createExpressionRule, createInterface, testInterface, validateExpression, addRecordTypeView, updateRecordType, createSite, …).
- App **Genesis Hub**, prefix `GH`, appUuid `_a-0000f058-fed5-8000-9bfc-011c48011c48_27312`.
- Rules folder **GH Rules and Constants** `_a-0000f058-fed5-8000-9bfc-011c48011c48_27319` (passing `appUuid` selects it).
- Groups: GH Administrators `_e-0000f058-fe86-8000-9b49-01075c01075c_458` · **GH Users** `_e-0000f058-fe86-8000-9b49-01075c01075c_460` · GH Service Accounts `_e-0000f058-fe86-8000-9b49-01075c01075c_462`.
- All record-type / field / relationship UUIDs: `01-data-model-reference.md` (never fabricate UUIDs — copy from there or re-read with `getRecordType`).

## 3. Read in this order
1. `00-overview.md` — goals, non-goals, **locked decisions D1–D7**, IA, object inventory, DoD, risks.
2. `progress.md` — what is already built (as of writing: only the two relationships of sub-spec 02).
3. `01-data-model-reference.md` — schema + real data values + gotchas (§D).
4. `10-design-system.md` — palette, lane/stage/tag colours, layout rules. Every interface follows it.
5. The sub-spec you are about to build: `03` → `04` → `05` → `06` → `07` → `08` → `09` (dependency order; don't skip ahead —
   pages call the helper rules and components, the site needs the pages).
6. The Appian skill: `/Users/ramaswamy.u/appian-dev/.kiro/skills/appian/SKILL.md` and its mandatory references
   (`references/tools-mcp.md`, `confirmation-patterns.md`, `function-reference.md`, `component-reference.md`,
   `null-safety-patterns.md`, `short-circuit-patterns.md`, `sail-verification-checkpoint.md`; for interfaces also
   `appian-workflow-patterns.md`, `interfaces.md`, `sail.md`, `record-summary-views.md`, `query-record-type-patterns.md`,
   `ui-patterns.md`, `interface-generation-checklist.md`, `validation-checkpoint.md`, `sites.md`, `patterns/{kpis,card_lists,tabs}.md`,
   and the component instruction files listed in `04-shared-components.md`). **Read these in small chunks** — the
   context window is the scarce resource on this task (a previous session ran out).

## 4. Non-negotiable rules
- **Read-only.** No record actions, forms, `a!writeRecords`, `a!deleteRecords`, `a!startProcess`, submit buttons, grid `recordActions`.
  Filter/search inputs on local variables are fine.
- **Do not modify existing Hub objects** that back the Web APIs (all `GH_*` rules without `UI_`, the 11 Web APIs, the
  blob process model, constants, record fields, security of record types). Additive only: new `GH_UI_*` objects, record
  views, title expressions, the site.
- **Do not delete or filter data** (D2). **Show app UUIDs, not names** (D1).
- **Ask before** anything destructive or anything outside this spec (e.g. new record types/fields/relationships).
- Follow the skill loop per object: list existing → Step 4A/4B verification (write the verification block) → write SAIL to a
  local file (`/Users/ramaswamy.u/appian-dev/genesis-hub-site/<name>.sail`) → `validateExpression` (max 3 fix attempts) →
  create with `testInputs` → `testInterface`/`testRule` every branch → `validateDesignObject` → log UUID in `progress.md`.
- Null-safety everywhere (`a!defaultValue`, guard `text()`/`left()`/`user()`/`not()`; nested `if()` instead of `and()` for
  guarded property access). `applyWhen` on every variable filter. Never a bare `a!recordLink` in a grid column.
- Never query inside `a!forEach` per row — query once (aggregations/`in` filters) and join in memory.

## 5. Where to start (next session)
1. Read §3 docs 1–4.
2. Quick health check: `getApplication(appUuid)`; `listApplicationObjects(appUuid, ["sites","interfaces","expressionRules"])`
   — confirm only `GH_BlobVersionDocumentSummary` exists among interfaces and no `GH_UI_*` objects yet (otherwise resume from `progress.md`).
3. Verify sub-spec 02 (relationships) per `02-relationships.md` §Verification.
4. Resolve the open data question: page `listRecordData` on GH Story Item (`556f67aa-34fe-42b1-a67e-76a67f770b84`, limit 50,
   several offsets) to find the acceptance-criteria `itemType` string; record it in `01` §C + `progress.md`.
5. Build sub-spec **03** (helper rules), then 04, 05 … 09. After each object, append to `progress.md`.
6. Close out per `09` §3–§4 (verification evidence, tracker §6, bible §9 note, push project-tracker), and give the user the
   manual browser check.

## 6. Status table (keep updated)
| Sub-spec | Status |
|---|---|
| 01 data model reference | ✅ |
| 02 relationships | ✅ live (verify) |
| 03 helper rules | ✅ |
| 04 shared components | ⬜ |
| 05 record views | ⬜ |
| 06 Home + Applications | ⬜ |
| 07 Features + Board | ⬜ |
| 08 Stories + Wiki + Team | ⬜ |
| 09 site + security + verification + docs | ⬜ |
