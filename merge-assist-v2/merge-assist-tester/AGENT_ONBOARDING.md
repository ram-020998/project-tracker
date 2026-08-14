# Merge Assist — Converter Testing: Agent Onboarding & Handover

> **Read this end-to-end before doing anything.** It hands over the full context, process, and
> progress so a brand-new agent session can continue with zero prior memory. Companion docs in the
> tester repo:
> - `merge-assist-tester-client/docs/CONVERTER_TESTING_PROCEDURE.md` — step-by-step SOP + UUID tables.
> - `merge-assist-tester-client/docs/CONVERTER_TESTING_STRATEGY.md` — strategy + type-key vocab.
> - `merge-assist-tester-client/reports/PROGRESS_26.3.md` — live completed/pending status (authoritative).

---

## 1. What we are doing (the mission)

**Merge Assist** reshapes a vendor package's exported object **XML** into the exact same map that the
Appian **Design Object Diff (DOD)** framework produces natively for an environment object. It does this
via per-type expression rules named **`MA_convert_<type>`** (dispatched by `MA_convertXmlToDiffMap`).

We **test each object type self-referentially**: take a real object in the environment, export its XML,
run it through `MA_convert_<type>`, and compare the converter output **field-by-field** against the
environment's own `getObjectFn` diff data for that same object. The environment is the oracle. Any
difference is either a converter defect (fix it) or an explainable environment-only artifact (accept it).

**Goal per object type:** drive the converter until the only remaining diffs are ENV-ONLY/BENIGN
(no real converter gaps), record the result, write a per-type report. Work one type at a time.

---

## 2. Environments, apps, and clients

### Environment (dev)
- **Base URL:** `https://merge-assist-dev.appianpreview.com`
- The prior env (`https://merge-assist.appianpreview.com`) is retired. App reconfigured into dev.
- **CRITICAL — numeric local ids are NOT portable across envs; UUIDs are.** Re-resolve every id in
  the dev env. Trust only UUIDs.

### Applications (UUIDs — stable)
- **Merge Assist (MA)** — `33060c62-b495-4c03-9948-206c2f976d2b` (prefix `MA`). Converters + helpers.
- **Merge Assist Tester (MAT)** — `_a-0000efec-4e49-8000-9be6-011c48011c48_75004` (prefix `MAT`).
  Progress record type, dashboard, diff-launch interface, Converter Testing site, and the
  export/convert/compare Web APIs.

### Tester client (`mat_client.py`)
- Path: `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-tester-client`
- Run with repo venv: `.venv/bin/python mat_client.py <cmd> ...` (dep: `requests`).
- `.env` holds `APPIAN_BASE_URL` (dev) + `APPIAN_API_KEY`. The key now also has **external-deployment**
  permission (see §3.C). If `HTTP 401 APNX-1-4187-000` → stale key; ask user to refresh.
- Output JSON → `/tmp/mat-report/` (`mkdir -p /tmp/mat-report` first).

---

## 3. How the pipeline works (THREE channels)

1. **LCP MCP server (`lcp-mcp-server`)** — design tools: `listApplications`, `getRecordType`,
   `testRule`, `getExpressionRule`, `updateExpressionRule`, `createExpressionRule`, `uploadDocument`,
   `insertRecordData`, etc. Used to resolve ids, inspect/edit converters, upload XML docs, record rows.
   Own auth (LCP basic auth `kiroDeveloper`/`appian26` via `.kiro/settings/mcp.json`).
2. **`mat_client.py` Web-API client** — calls three MAT Web APIs with the `.env` key:
   - `exportObjectV2` (**POST**) — export env object → XML doc **(the built-in IX export; see §3.C for its limits)**.
   - `convertObjectV2` (**GET**) — run converter over an XML doc (by `docId`).
   - `compareObjectV2` (**GET**) — env `getObjectFn` data + converter data for diffing.
   - `run` = export → compare → field diff in one shot.
3. **Appian Deployment MCP (`appian-deployment`)** — the OFFICIAL Deployment REST API, our reliable
   **export** path (replaces the broken IX plugin for export-blocked types). See §3.C.

### 3.C — The export problem and the Deployment-MCP bridge
The built-in `object-export-plugin` (behind `exportObjectV2`) reliably exports **content objects,
site, group** but returns **HTTP 504** for `webApi`, `processModel`, `recordType` (IX `ExportFacade`
fails for those types). The **Appian Deployment MCP** solves this:

- Installed at `~/appian-deployment-mcp`; wired into `~/.kiro/settings/mcp.json` as server
  `appian-deployment` (env `default` = dev domain + the deployment-capable API key).
- Prereq (done): Admin Console → Outgoing External Deployments enabled + API key's service account
  set as **Authenticate As**. Without it, export `POST /deployments` → 403 `APNX-1-4552-001`.
- **Bridge to feed the converter (for any type):**
  1. `export_package(export_type="application", uuids=[appUuid])` → `poll_deployment_status` →
     `download_exported_package` (saves zip to `/tmp/mat-report/deploy/`).
  2. Unzip → per-object IX XML at `<type>/<uuid>.xml` (identical `*Haul` format the converters expect).
  3. `python3 upload_xml.py <file> <name> <MAT_ObjectExports_folderUuid> <MAT_appUuid> xml`
     → uploads the XML into the **MAT Object Exports** folder
     `_a-0000efee-f112-8000-9bea-011c48011c48_75077` (this is the ONLY folder the convert/compare
     Web-API user can read — uploads to other folders → convert/compare HTTP 500).
  4. Resolve numeric `docId` via `getcontentdetailsbyuuid`, then
     `mat_client.py convert/compare --type <shortType> --doc-id <docId> --uuid <uuid>`.
- `upload_xml.py` lives in the tester repo (reuses LCP `/documents` POST + basic auth).

---

## 4. The per-object testing loop

1. **Pick an object** of the target type; capture its **UUID** + name.
2. **Get its XML into an env doc (docId):**
   - **Export-OK types (content, site, group):** `mat_client.py run --short-type <t> --id <localId>
     --uuid <uuid>` exports+compares in one shot. Resolve `<localId>` first (see below).
   - **Export-blocked types (recordtype, webapi, processmodel) & anything else:** use the
     **Deployment-MCP bridge** (§3.C) to get a `docId`, then call `convert`/`compare` directly.
3. **Resolve numeric local id** (only needed for the built-in `exportObjectV2`/`run` path):
   - **Content objects** (rule, interface, constant, decision, integration, web API, **connected
     system**, **application**, **knowledge center**): `MA_TMP_explore` → `getcontentdetailsbyuuid(uuid)`
     → parse `Id: N`. (`a!util_convertUuidToId(uuid, ContentFreeformRule)` returns `""` for
     interfaces/integrations — always prefer the getcontentdetails parse.)
   - **Group / site / process model:** `MA_TMP_uuidToId(shortType, uuid)`
     (`group` / `site` / `processmodel` — see the rule's own mapping).
   - **Record type / datatype / datastore:** not content objects; the built-in export 504s anyway —
     use the Deployment-MCP bridge.
4. **Run the diff.** For the bridge path: `convert` (validates converter parses) then `compare`
   (env oracle). Parse `match`, `diff` (`{path, kind, env?, converted?}`), `env`, `converted`.
   - **⚠ compare `type` uses the DOD key, not always the converter shortType — see §5a.**
5. **Triage every diff** (see §6).
6. **Fix `MA_convert_<type>`** via `updateExpressionRule` (**always pass `inputs` alongside the
   expression**). Inspect raw parsed XML with a temp `a!fromJson(xmltomap(docId))` rule.
7. **Record the row** in `MAT_REC_ConverterTest`.
8. **Write/update** `reports/<type>/26.3.md`, `reports/PROGRESS_26.3.md`, `reports/README.md`.

---

## 5a. Type keys — TWO vocabularies (critical)
- **Converter shortType** (the `convert` dispatcher `MA_convertXmlToDiffMap` → `MA_convert_*`): e.g.
  `recordtype`, `webapi`, `site`, `interface`.
- **DOD compare key** (the env `getObjectFn` half of `compareObjectV2`, from `a!dod_config_getTypeMap`):
  the authoritative list is returned by rule **`MA_getValidObjectTypes`**
  (`_a-0000efa7-bf84-8000-9ba6-011c48011c48_34170`) — call it via `testRule`.
- **They differ for record types: converter uses `recordtype`, compare uses `record`.** Passing
  `recordtype` to compare → HTTP 500; `record` → 200. The client encodes this in `COMPARE_TYPE_MAP`
  (`recordtype`→`record`); `compare_object` sends the DOD key. Most other types match across both
  vocabularies. The strategy-doc §9 table listing `recordtype` for compare is WRONG.

## 5. Hard-won platform gotchas (do NOT rediscover)

- **`validateExpression` / raw LCP eval → HTTP 403.** Use `testRule` to evaluate helper rules.
- **LCP cannot read/save objects that transitively reach the DOD framework**
  (`a!dod_fwk_sectionsGenerator` / `a!dod_config_getTypeMap`). `MAT_getEnvObjectData`,
  `MAT_compareObject_V2` body, `MAT_launchDiffView`, `MA_renderDiffViewForObject` are **Designer-only**
  (getWebApi/getInterface return null expression for them).
- **`a!dod_displayName_contentByUuid` is UNAVAILABLE in the dev env** (`function … is unavailable`).
  Build content display maps from `getcontentdetailsbyuuid` text parsing instead (name + id).
- **MCP `createExpressionRule` is strict:** rejects `fn!try`, `a!util_convertUuidToId`,
  `fn!lambda_appian_internal` as "undocumented", and `ri!` lambda params as "incorrectly scoped".
  **`updateExpressionRule` tolerates** them (existing converters keep their lambdas). ⇒ Put new logic
  **inline** in converters via `update`; avoid `fn!lambda_appian_internal`.
- **`updateExpressionRule` rejects "Unused Local Variables"** — remove any `local!` you stop using.
- **`fn!reverse()` does NOT reverse a string** (it reverses lists). For last-dot/extension work use
  forward `find(".", s)`.
- **`a!util_convertUuidToId(uuid, ContentFreeformRule)` returns `""` for interfaces** (and
  integrations) — parse the id from `getcontentdetailsbyuuid` instead.
- **Uploaded XML docs must go to the `MAT Object Exports` folder**
  (`_a-0000efee-f112-8000-9bea-011c48011c48_75077`) or convert/compare 500 (Web-API user can't read
  other folders).
- **Web APIs are method-specific:** export = POST, convert/compare = GET. Wrong method → 404.
- **API key errors:** `HTTP 500 authenticated=false` / `HTTP 401 APNX-1-4187-000` → refresh key.
  Export `403 APNX-1-4552-001` → external deployments not enabled / Authenticate-As not set.
- **`getcontentdetailsbyuuid(uuid)`** returns a Text blob (parse it); covers content objects
  (rule/interface/constant/integration/**connectedsystem**/**application**/**knowledgecenter**/document).
  Record types/groups/sites/process models return "No object with this UUID".
- **`getDocumentText` LCP op unavailable** — inspect XML via `xmltomap` in a temp rule.
- **`a!util_convertUuidToId(uuid, type)`** — arg order (uuid, type); wrap in `tointeger()`.
- **`type!{...}Name` literals must resolve at save time** — one candidate type ref per temp rule.
- **Typed-value unwrap:** `xmltomap` renders scalars as `{xsi:type, content}`; empty as `{xsi:type}`.
  Use `try(index(obj,"content",""), obj)` (`getVal`/`getStr`).
- **MCP transport drops** need a **fresh chat session** to re-register tools. If tools resolve to the
  `dummy` placeholder, they're not registered. **New MCP servers (e.g. `appian-deployment`) only appear
  after a session restart.**

---

## 6. Diff triage — classify every entry

| Class | Definition | Examples | Action |
|---|---|---|---|
| **ENV-ONLY** | Only the live env can produce it | DB ids (`id`, field ids, view ids, source ids), `latestVersionNumber`, `versionIdentifier`, `siteUrl`, resolved inherited `roleMap.entries`, CS `description`/`sharedParameters` | Accept |
| **BENIGN** | Semantically equal; cosmetic | trailing `\n`, `""` vs `null` | Accept (optionally normalize) |
| **REAL** | Wrong shape/value the framework cares about | legacy `roleMap` shape, wrong `typename`, non-canonical field type, missing `parent.*`, unextracted typed values, extra/missing keys | **Fix** |

**Systemic ENV-ONLY patterns:** inherited security (`roleMap.entries` length differs); referenced-object
enrichment (env inlines a referenced object's resolved config); generated DB ids everywhere.

---

## 7. Fixing converters — shared helpers & tools

Dispatcher: `MA_convertXmlToDiffMap` routes by shortType to `MA_convert_<type>` (MA app).

| Helper | UUID | Purpose |
|---|---|---|
| `MA_util_convertRoleMap_V2` | `_a-0000efa9-1a7d-8000-9ba8-011c48011c48_49028` | Correct `{inherit, entries[]}` roleMap; resolves group display; **now orders entries by role priority (none→administrator→editor→viewer→deny)** to match env. Use this, not legacy `MA_util_convertRoleMap`. NOTE: some types' env roleMap has **no `inherit`** key (e.g. site, record) — strip it in those converters. |
| `MA_util_resolveGroupDisplay` | `_a-0000f006-b2ce-8000-9c03-011c48011c48_76849` | Group UUID → `[Name]`, id, security fields. |
| `MA_util_resolveConnectedSystem` | `_a-0000f006-b2ce-8000-9c03-011c48011c48_77021` | Connected-system display block. |
| `MA_util_buildContentParent` | `_a-0000f006-b2ce-8000-9c03-011c48011c48_76526` | Content object RuleFolder `parent` map; null for `SYSTEM_*` roots. |
| `MA_util_resolveInputTypeName` | `_a-0000f006-b2ce-8000-9c03-011c48011c48_76767` | Rule/interface input type display. |
| `MA_util_xmlTypeToAppianType` | `_a-0000efa9-1a7d-8000-9ba8-011c48011c48_35403` | XML type token → `Number (Integer)` etc. (NOTE: record fields want the SHORT `Integer`/`Text` at top-level but FULL `{…}Integer` inside `sourceCfg`.) |
| `MA_util_ensureArray` / `MA_util_ensureTextArray` / `MA_util_getNestedIndex` | (MA app) | single-vs-list normalize; safe nested index. |
| `MA_getValidObjectTypes` | `_a-0000efa7-bf84-8000-9ba6-011c48011c48_34170` | **Authoritative** typeId/type/shortType list (the DOD compare keys). |

**Common fixes:** roleMap legacy → V2 (+ strip `inherit` where env omits it); typed-value unwrap;
raw parent UUID → `buildContentParent`; numeric-looking text → `tostring`; `""` vs `null` → default
`""` (use `a!defaultValue(x,"")`); non-canonical field type → strip `{…}` prefix; system-rule expr
`#"SYSTEM_SYSRULES_X"()` → `a!X()`; keys env lacks → remove; env-only DB ids → leave null (accept).

### Client-side tools (tester repo)
- `mat_client.py` — `export` / `convert` / `compare` / `run`. `COMPARE_TYPE_MAP` maps shortType→DOD key.
- `upload_xml.py` — upload a local XML file → env document (LCP `/documents`). Used by the
  Deployment-MCP bridge (§3.C).

### Temp helper rules (MA app) — DELETE at the very end
- `MA_TMP_uuidToId` `_a-…76487`, `MA_TMP_explore` `_a-…76514`, `MA_TMP_parseXml` `_a-…76520`,
  `MA_TMP_parseInputs` `_a-…76761`, `MA_TMP_dumpInteg` `_a-…76973`,
  `MA_TMP_dumpSite` `_a-0000f03b-67ee-8000-9bde-011c48011c48_26522` (generic xmltomap dumper),
  `MA_TMP_dodContent`/`MA_TMP_probe` (throwaway probes, may fail to create).

### Temp test fixtures created for testing — DELETE at the end
- Connected system **`MA_TEST_CS_HTTP`** `_a-0000f03b-67ee-8000-9bde-011c48011c48_26693` (content id 5049).
- Application **`MA_TEST_APP`** `_a-0000f03b-67ee-8000-9bde-011c48011c48_26866` + its auto knowledge
  center `_a-…26879`.
- Uploaded XML docs in `MAT Object Exports` (dep_group_*, dep_rt_*, dep_app_*).

---

## 8. Progress tracker

- **Record type `MAT_REC_ConverterTest`** — `373dfe3c-a483-4c30-b072-89aaf3993aae` (MAT app).
- **Columns:** `objectUuid, objectType, objectName, localId, xmlDocId, zipDocId, diffCount,
  realGapCount, matchStatus, progressStatus, notes, lastTestedOn`. Omit `id` on insert.
  `notes` is **VARCHAR(255)** — keep < 255 chars. Dates `YYYY-MM-DD HH:MM:SS` (UTC).
- Rows are re-baselined in the dev env (old-env rows discarded). Current rows: site, webapi(blocked),
  processmodel(blocked), connectedsystem, application(blocked), knowledgecenter(blocked), recordtype.

### Visual diff site (MAT app)
- Site **Converter Testing** `c703b63a-89d3-4289-abae-4b6b2c118c51` (dev URL
  `…/suite/sites/converter-testing`). `MAT_dashboard` `_a-…76628`. `MAT_launchDiffView` `_a-…76622` —
  SHELL only in LCP; real body in `docs/MAT_launchDiffView_designer_body.sail` (paste in Designer once).

---

## 9. Current status — Appian release 26.3

Legend: ✅ PASS (0 diffs) · 🟡 CLEAN (only env-only, no real gaps) · 🔴 GAPS · ⏳ PENDING · ⛔ BLOCKED.

| Object type | Status | Diffs (real) | Notes |
|---|---|---|---|
| group | ✅ PASS | 0 (0) | Full match (re-verified dev env). V2 roleMap + group display, groupType, policies. |
| constant | 🟡 CLEAN | 2 (0) | roleMap/typename/description/parent. |
| rule | 🟡 CLEAN | 3 (0) | roleMap/parent/testValues. |
| interface | 🟡 CLEAN | ~2 (0) | roleMap shape/parent/defaults; entries content env-only (re-verified dev). |
| integration | 🟡 CLEAN | 10 (0) | typed-value unwrap, V2 roleMap, parent, query params, CS resolve. (Not re-run in dev — no integration instance.) |
| site | 🟡 CLEAN | 4 (0) | Rewrote: inline branding hex, favicon defaultImage resolve, page contentName via getcontentdetails, ContentFreeformRule→Interface(260), roleMap default-only. Env-only: id, pages[0].id, siteUrl, versionIdentifier. |
| connectedsystem | 🟡 CLEAN | 3 (0) | V2 roleMap + priority reorder, integrationType/uuid, blank sharedParameters.baseUrl, enableRtdShortcut null, vaultFieldMetadata {}. Env-only: id, version, latestVersionNumber. Tested via temp `MA_TEST_CS_HTTP`. |
| **recordtype** | 🔴 GAPS | 15 (1) | **62→15.** Compare key is **`record`**. Fixed V2 roleMap (no inherit), field displayName/type (short top-level / full sourceCfg), versionUuid→"", nameExpr `a!` normalize, sourceCfg empty defaults, supportsIncrementalSync, craFlags, detailViewCfg/views split. 14 env-only DB ids left; **1 real gap: `enabledFeatures` (bitmask `2047` → decoded feature-name list)**. Tested via Deployment-MCP bridge (MA_REC_SessionStatus). |
| webapi | ⛔ BLOCKED | — | Built-in export 504; **and** compareObjectV2 500 (no env `getObjectFn` oracle). Deployment MCP can export it, but compare oracle missing. |
| processmodel | ⛔ BLOCKED | — | Built-in export 504; compareObjectV2 500 (bespoke PM diff). |
| application | ⛔ BLOCKED | — | Export OK (content) + converter runs, but compareObjectV2 500 with correct key `application` and a valid doc → genuine env-oracle gap. |
| knowledgecenter | ⛔ BLOCKED | — | Export OK (content); compareObjectV2 500 (no env oracle). |
| decision | ⛔ BLOCKED | — | No decision instance in env. |
| aiskill | ⛔ BLOCKED | — | No native DOD diff config. |
| datatype | ⏳ PENDING | — | Get XML via Deployment-MCP bridge; compare key `datatype`. Untested. |
| datastore | ⏳ PENDING | — | Bridge; compare key `datastore`. Untested. |
| grouptype | ⏳ PENDING | — | compare key `grouptype`. Untested. |
| translationstring / translationset | ⏳ PENDING | — | Untested. |
| controlpanel / portal / report / feed | ⏳ PENDING | — | In valid-types list; untested. |

**Completed (0 real gaps): group, constant, rule, interface, integration, site, connectedsystem (7).**
**In progress: recordtype (1 real gap: enabledFeatures).**
**Blocked on env oracle / instance: webapi, processmodel, application, knowledgecenter, decision, aiskill.**
**Pending (need testing via bridge + correct compare key): datatype, datastore, grouptype, translation*, controlpanel, …**

### The two-axis constraint (important mental model)
A type is testable only if BOTH hold:
1. **Export** — built-in for content/site/group; **Deployment-MCP bridge** for everything else (solved).
2. **Compare oracle** — env `getObjectFn` via `MAT_getEnvObjectData` (Designer-only). Confirmed supports
   the 7 core types **+ record**. Returns 500 for application, webapi, processmodel, knowledgecenter.
   Extending it to more types is a **Designer task** (LCP can't read/edit it — it reaches the DOD fwk).
   **Always confirm the compare key against `MA_getValidObjectTypes` before concluding "no oracle".**

---

## 10. Suggested next-step order
1. **recordtype** — close the last real gap (`enabledFeatures` bitmask→name list; find/build a decode).
2. **datatype, datastore, grouptype, translationset/string** — fetch XML via the Deployment-MCP bridge,
   upload to MAT Object Exports, `compare` with the correct DOD key (from `MA_getValidObjectTypes`).
   Each may or may not have an env oracle — check empirically.
3. For truly oracle-missing types (application/webapi/processmodel/knowledgecenter): **Designer task** —
   extend `MAT_getEnvObjectData` to emit env diff data, then test via the bridge.
4. Revisit **decision**/**aiskill** if instances/diff-config appear.

---

## 11. Immediate to-dos for a new session
1. Confirm MCP tools live: `listApplications` (see MA + MAT). Confirm `appian-deployment` present:
   `list_environments` → `default`. If missing → restart session (new MCP registers on restart).
2. Confirm client: `mkdir -p /tmp/mat-report`; a quick `run`/`compare` on a known object. `HTTP 401` →
   refresh key.
3. **Re-resolve ids** in dev; trust only UUIDs.
4. Continue per §10. For export-blocked/new types use the **Deployment-MCP bridge** (§3.C) and the
   **correct compare key** (§5a, `MA_getValidObjectTypes`).

## 12. Cleanup (only when the whole matrix is done)
- Delete `MA_TMP_*` temp rules (§7). Keep all `MA_util_*` helpers.
- Delete temp fixtures: `MA_TEST_CS_HTTP`, `MA_TEST_APP` (+ its KC), uploaded `dep_*` docs in MAT Object Exports.
- Delete dead LCP Web APIs if present (`mat_exportObject`, `mat_convertObject`, `compareObject`).
- Paste `MAT_launchDiffView_designer_body.sail` into `MAT_launchDiffView` in Designer.
- Commit/push the tester client repo (reports + docs + `upload_xml.py`).

---

## 13. Key file map
- Tester client: `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-tester-client/`
  - `mat_client.py` — diff CLI (`export`/`convert`/`compare`/`run`); `TYPE_MAP` (export ixKey),
    `COMPARE_TYPE_MAP` (DOD compare key).
  - `upload_xml.py` — local XML → env document (LCP `/documents`), for the Deployment-MCP bridge.
  - `.env` — dev base URL + deployment-capable API key.
  - `docs/CONVERTER_TESTING_PROCEDURE.md`, `docs/CONVERTER_TESTING_STRATEGY.md`,
    `docs/MAT_launchDiffView_designer_body.sail`.
  - `reports/PROGRESS_26.3.md` (live status), `reports/README.md`, `reports/_TEMPLATE.md`,
    `reports/<type>/26.3.md`.
  - `object-export-plugin/` — the built-in IX export plugin source (504s for webapi/pm/recordtype).
- Deployment MCP: `~/appian-deployment-mcp/` (installed); config in `~/.kiro/settings/mcp.json`
  (`appian-deployment` server). Downloaded artifacts under `/tmp/mat-report/deploy/`.
- Trackers: `/Users/ramaswamy.u/repo/project-tracker/merge-assist-v2/` (this doc under
  `merge-assist-tester/`).
