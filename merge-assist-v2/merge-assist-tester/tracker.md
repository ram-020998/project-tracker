# Merge Assist — Converter Testing Framework — Tracker

> **Purpose of this document.** A single, self-contained record of the Merge Assist **converter
> testing framework** (and the Merge Assist context needed to understand it). A brand-new AI agent
> session should be able to read *only this file* and understand: what Merge Assist is, why we built
> a testing framework, exactly what was built (objects, UUIDs, endpoints, code), every finding and
> gotcha, how to run it, what works, and what remains. Nothing is assumed.
>
> **Last updated:** 2026-08-14
> **Status:** Framework working end-to-end on the **dev env**. Export axis now has TWO paths (built-in
> IX plugin for content/site/group; **Appian Deployment MCP** for everything incl. webapi/pm/recordtype).
> 7 types clean (0 real gaps); recordtype in progress (1 real gap). See §13 for the current session.

---

## 0. Repo & location map (where everything lives)

| What | Path |
|---|---|
| **Tester client + export plugin (standalone repo)** | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-tester-client` |
| → GitLab remote | `git@gitlab.appian-stratus.com:ramaswamy.u/merge-assist-tester-client.git` (branch `main`) |
| → Python client | `merge-assist-tester-client/mat_client.py` |
| → Export plugin (Java) | `merge-assist-tester-client/object-export-plugin/` |
| → Strategy doc (deep) | `merge-assist-tester-client/docs/CONVERTER_TESTING_STRATEGY.md` |
| → Client README | `merge-assist-tester-client/README.md` |
| **Merge Assist app: docs, steering, plans** | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-appian` |
| **Merge Assist v2: inspect/extract plugin, SAIL converters, app export** | `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/merge-assist-v2` |
| **Project trackers** | `/Users/ramaswamy.u/repo/project-tracker/merge-assist-appian/tracker.md`, `…/merge-assist-v2/tracker.md` |
| **This tracker** | `/Users/ramaswamy.u/repo/project-tracker/merge-assist-v2/merge-assist-tester/tracker.md` |

**Live environment:** `https://merge-assist-dev.appianpreview.com` (dev; old `merge-assist.appianpreview.com`
retired). Web APIs at `{base}/suite/webapi/<urlAlias>`. **Numeric local ids are NOT portable — re-resolve
in dev; trust only UUIDs.**

---

## 1. Merge Assist in one page (context you need first)

**Merge Assist** is an Appian-native application + plugins that helps customers manage **vendor
application upgrades**. The customer runs a vendor-provided Appian app, customizes it, and the vendor
ships a new version. Merge Assist classifies every object in the new vendor package as **New / Safe /
Conflict** and lets a reviewer inspect a **side-by-side diff** of each object.

- **App UUID:** `33060c62-b495-4c03-9948-206c2f976d2b` · **prefix:** `MA` · **site:** `merge-assist`.
- **Environment = customer version.** The app is deployed into the customer's own environment, so the
  live environment *is* the customer's customized version. The user uploads the **new vendor package**
  (and optionally a **base** package); classification compares against the environment.
- **Classification (current):** a single `inspectPackage` of the vendor package against the environment
  returns `created` (→ New), `updated` (→ Safe), and `conflicted` (→ Conflict) buckets. (This replaced
  an older dual-inspect base+vendor cross-reference — see §2.)

### The diff viewer and the converters (this is what we test)
The diff shows two maps side-by-side, rendered by Appian's native **Design Object Diff (DOD)** framework:
- **Left = Environment (customer)**: produced by the platform's native `getObjectFn` via the validated
  guard-bypass pattern `a!asSystem_appian_internal(a!dod_fwk_asGetObjectFn(getObjectFn/getEditableObjectFn(...)))`.
- **Right = New Vendor**: the vendor object exists only as **package XML**. Merge Assist reshapes that XML
  into the same map shape using **per-type SAIL converters** — `MA_convert_<type>` rules routed through
  the dispatcher **`MA_convertXmlToDiffMap(type, xmlJson)`** (`_a-0000efa6-747f-8000-9ba4-011c48011c48_33874`).

The **converters are the fragile part**: each object type has different XML, and the converter must
rebuild the exact keys/nesting/roleMap/parent/fields the DOD framework expects. **The testing framework
exists to prove, per object type, that the converter output matches what the environment produces for the
same object — and to surface every discrepancy so converters can be fixed.**

Key Merge Assist objects referenced later:
- `MA_convertXmlToDiffMap` (dispatcher) `_a-0000efa6-747f-8000-9ba4-011c48011c48_33874` + ~23 `MA_convert_*` rules.
- `MA_renderDiffViewForObject` `_a-0000efa9-1a7d-8000-9ba8-011c48011c48_35306` (production diff interface; has a
  "Current Vs Vendor Latest" / "Base Vs Vendor Latest" dropdown).
- `MA_UT_deriveDiffObjectDataFromEnv` `_a-…74113` (env side) and `MA_UT_deriveDiffObjectDataFromXml` `_a-…74101`
  (converter side) — the production rules the tester mirrors.
- Record types: `MA_REC_MergeSession` `fd17fe05-91f4-4f35-9c6b-fd3096dd4629`, `MA_REC_ObjectClassification`
  `e8afcb0f-f662-4cec-9afe-ab5f38e6bfd5`.

---

## 2. Merge Assist app changes made in these sessions (related context)

These app-side changes were done alongside the testing work; they explain the current classification and
the diff options the tester exercises.

### 2.1 Single-inspect classification via native conflict detection (done)
- **Discovery:** Appian's `ImportResults` (public SDK) exposes a first-class **`getConflictedObjects()`**
  bucket that the inspect plugin had been ignoring. A **single vendor inspect** thus yields New/Safe/Conflict
  directly, removing the need for a second "base" inspect.
- **Plugin change (merge-assist-v2 `InspectPackageService.java`):** now emits a `conflicted` array +
  `summary.conflicted` count. Additive; smart-service key `inspectPackageV2` unchanged.
- **Verified bucket semantics on a real package:** `updated` is a **superset that already contains
  `conflicted`** (not disjoint). So **Safe = updated − conflicted**; and `conflicted` entries can omit the
  `type` field, so name/type come from the `updated`/`created` entries.
- **Rule rewrite:** `MA_UT_constructObjectClassifications` (`_a-0000efa7-bf84-8000-9ba6-011c48011c48_34137`) —
  dropped the `baseResponse` input (signature now `(vendorResponse, session)`); conflict set = `vendorResponse.conflicted`;
  fail session if the single vendor response is invalid. `validateDesignObject` clean.
- **Process model:** `MA Process Session Packages` (`0002efa8-20a2-8000-fad1-7f0000014e7a`) — the "Inspect Base
  Package" node was removed (Designer), leaving a single vendor inspect. **Base extraction is kept** (see 2.2).
- **Full write-up:** `merge-assist-appian/docs/04-single-inspect-conflict-detection.md`.

### 2.2 Optional base comparison (done)
- The base package is still uploaded + **extracted** to power the **"Base Vs Vendor Latest"** diff option in
  `MA_renderDiffViewForObject` (uses `baseXmlDocId` field `06cf979b-ac1e-49e0-b5c1-dcc56734486a` on
  `MA_REC_ObjectClassification`; `vendorXmlDocId` is `7a98e402-2783-4a04-bf68-e9c93ad89541`).
- New boolean field **`includeBaseComparison`** (`6a775d57-6d47-48f5-928f-43945c63c6e1`) on `MA_REC_MergeSession`.
- **`MA_FM_createNewSession`** (`_a-0000efa6-747f-8000-9ba4-011c48011c48_33965`) rebuilt: New Vendor is the primary
  required upload; a toggle reveals the optional Base upload; Start Analysis requires base only when toggled;
  unchecking clears a stale base. API-key/Designer conventions followed.

> These are **Merge Assist app** changes. The rest of this tracker is the **testing framework**.

---

## 3. The testing framework — principle & why

### 3.1 Core principle (the self-referential test)
> For one design object that exists in the environment: take **(A)** the environment's native diff data
> (`getObjectFn`), and **(B)** the converter's diff data built from *that same object's exported XML*.
> A and B describe the same object, so they must be structurally identical. Any difference is a converter
> bug or a known, explainable exception.

We do **not** hand-author expected fixtures. The environment is the oracle: export the object the
environment already holds, run it through the converter, diff the two.

### 3.2 Why it's valid
- Same object, same moment → the two representations must match field-for-field.
- Both sides feed the *same* `a!dod_fwk_sectionsGenerator` with the *same* `diffPresentationConfig`; the
  converter's whole job is to emit the shape `getObjectFn` emits.
- It isolates the converter: the left side is trusted platform code, so any diff points at `MA_convert_<type>`.

---

## 4. Architecture of the framework

Three pieces: (1) a **standalone export plugin**, (2) a **Merge Assist Tester** Appian app of Web APIs +
rules, (3) a **Python client**. The environment is the customer/source-of-truth.

```
Python client (mat_client.py, API-key auth)
      │  HTTPS  {base}/suite/webapi/<alias>   (Appian-API-Key header)
      ▼
Merge Assist Tester app (_a-...75004, prefix MAT)
  exportObjectV2  [POST]  → PM "MAT Export Object" → smart service "Object Export To Xml"
                                                       (object-export-plugin) → package ZIP
                                                       → unzip → store object XML
                            returns { xmlDocumentId:{id}, zipDocumentId:{id} }
  convertObjectV2 [GET]   → MAT_convertXmlObjectData → MA_convertXmlToDiffMap  (Merge Assist app)
                            returns { objectTypeName, xmlDocId, converted }
  compareObjectV2 [GET]   → { MAT_getEnvObjectData (env getObjectFn) , MAT_convertXmlObjectData }
                            returns { env, converted }
```

**Critical platform facts (learned the hard way — see §8):**
- **LCP-created Web APIs return 404** (known platform issue) → all tester Web APIs were recreated
  **manually in Designer** as the `…V2` aliases.
- **Web APIs are method-specific** → wrong method = **404** (looks like an auth failure).
  `exportObjectV2` = **POST**; `convertObjectV2` and `compareObjectV2` = **GET**.

---

## 5. The export plugin (`object-export-plugin`)

**Why it exists:** to compare against the environment we need the **vendor-format package XML** of an
object. Appian's **public** SDK `ImportExportService` only `import`s / `inspect`s — **no export**. So a
single-object export uses **internal** IX classes (present in `appian-ae.jar`).

- **Repo/location (now in the tester repo):** `merge-assist-tester-client/object-export-plugin/`
- **Plugin key:** `com.appiancorp.objectexport` · **smart service key:** `objectExportToXml` ·
  **palette name:** "Object Export To Xml" · **class:** `ExportObjectToXmlService`.
- **Inputs:** `ObjectTypeKey` (Text), `ObjectId` (Number/Integer — the LOCAL numeric id), `ObjectUuid`
  (Text, optional, used for naming), `TargetFolder` (Folder). **Outputs:** `XmlDocumentId`, `ZipDocumentId`.
- **Mechanics (internal IX APIs):**
  - `com.appiancorp.ix.Type.get(key)` → resolve IX type (`content`, `recordType`, …).
  - `com.appiancorp.ix.LocalIdMap` → set of object refs by type + local id.
  - `com.appiancorp.ix.ExportFacade.export(LocalIdMap, ContentService, ServiceContext, folderId, name)`
    → `ExportResult.getZipDocument()` → a standard package ZIP.
  - `com.appiancorp.services.ServiceContextFactory.getServiceContext(username)` → runs **as the invoking
    user** (must have export rights).
  - Then unzips the one-object ZIP and stores the inner object XML as its own document (skipping `META-INF`),
    returning both doc ids. That XML is the exact input the converters consume in production.
- **Type-key normalization (fix for `Unknown object type key: ContentFreeformRule`):** `Type.get()` only
  accepts IX keys. The service now has `resolveType()` that accepts **IX key OR Appian type name OR converter
  shortType** (case-insensitive), e.g. `content` / `ContentFreeformRule` / `rule` all resolve. Unknown key →
  clear error listing valid keys.
- **Build (standalone):** the 6 Appian SDK/AE jars are **bundled** in `object-export-plugin/lib/` (real files,
  not symlinks), so it builds with no external dependency:
  ```bash
  cd object-export-plugin
  JAVA_HOME=<jdk17> ./gradlew clean jar    # → build/libs/object-export-plugin-1.0.0.jar
  ```
  Deploy the JAR to `<APPIAN_HOME>/_admin/plugins/`.
- **Verified live:** exporting `MA_util_ensureArray` completes in ~1s and returns real doc ids.

> Note: this is a separate test-only plugin. It is **distinct** from the Merge Assist product plugin
> (`merge-assist-plugin`, which has `inspectPackageV2` + `extractPackageObjectsV2` + `xmlToMap` etc.).

---

## 6. Merge Assist Tester app — object inventory

**App:** `_a-0000efec-4e49-8000-9be6-011c48011c48_75004` · prefix `MAT` · urlIdentifier `8V-Jtw`.

### 6.1 Web APIs (created in Designer — the working `…V2` set)
| Web API (name) | urlAlias | Method | UUID | Purpose |
|---|---|---|---|---|
| `MAT_exportObject_V2` | `exportObjectV2` | **POST** | `499d27c4-5dbc-4949-9852-c28c67b7d773` | Start export PM; returns `{success, xmlDocumentId:{id}, zipDocumentId:{id}}` |
| `MAT_convertObject_V2` | `convertObjectV2` | **GET** | `70ae8c52-f258-4155-9d9f-ef0a6128420a` | Converter output for an exported XML |
| `MAT_compareObject_V2` | `compareObjectV2` | **GET** | `b97ed1c5-d48a-40dd-8581-953f440b7080` | `{ env, converted }` for direct comparison |

**Dead / superseded (LCP-created, 404 — safe to delete):** `mat_exportObject` `2929e8e7-9e00-450b-a2a2-4574ed54318e`,
`mat_convertObject` `0bf8cd80-2528-4881-890b-168a06a9d2db`, `compareObject` `de89857d-fbbd-4300-8f1c-69517330d4e8`.

### 6.2 Rules
| Rule | UUID | Role |
|---|---|---|
| `MAT_convertXmlObjectData` | `_a-0000efec-4e49-8000-9be6-011c48011c48_75041` | `if(empty docId, error, MA_convertXmlToDiffMap(type, a!fromJson(xmltomap(docId))))` — the converter side. **LCP-created** (no DOD dependency). |
| `MAT_getEnvObjectData` | Designer-built | Env `getObjectFn` diff data by `(objectTypeName, objectUuid)` using `a!asSystem_appian_internal` + `a!dod_fwk_asGetObjectFn` + `a!dod_config_getTypeMap()`. **Must be in Designer** (LCP can't save DOD-referencing objects — §8). |

### 6.3 Process model, constants
| Object | UUID | Notes |
|---|---|---|
| PM `MAT Export Object` | `0002efef-120d-8000-fd73-7f0000014e7a` | Start → `Object Export To Xml` smart service → End. Params `objectTypeKey`, `objectId`, `objectUuid`. Folder from `cons!MAT_FOLDER_OBEJCT_EXPORTS`. Output PVs `xmlDocumentId`, `zipDocumentId`. |
| Constant `MAT_PM_EXPORT_OBJECT` | Process Model ref (Designer) | Lets `a!startProcess` launch the export PM from `exportObjectV2`. (LCP can't create PROCESS_MODEL-typed constants — Designer only.) |
| Constant `MAT_FOLDER_OBEJCT_EXPORTS` | Folder ref (Designer) | Target folder for exported ZIP + object XML docs. (Note the spelling "OBEJCT" as created.) |

### 6.4 The two Web API expressions (reference)
**exportObjectV2 (POST):** reads `http!request.queryParameters` (`type`, `id`, `uuid`), calls
`a!startProcess(processModel: cons!MAT_PM_EXPORT_OBJECT, processParameters: {objectTypeKey, objectId, objectUuid})`,
returns `a!httpResponse` JSON `{success, processId, objectTypeKey, objectId, objectUuid, xmlDocumentId, zipDocumentId}`.
`a!startProcess` completes synchronously (single unattended node), so the doc ids are populated in the response.

**convertObjectV2 (GET):** reads `type`, `docId`; returns `a!toJson(a!map(objectTypeName, xmlDocId, converted: rule!MAT_convertXmlObjectData(...)))`.

**compareObjectV2 (GET):** reads `type`, `uuid`, `docId`; returns `{ objectTypeName, objectUuid, xmlDocId, env: MAT_getEnvObjectData(type, uuid), converted: MAT_convertXmlObjectData(type, docId) }`.

---

## 7. The Python client (`mat_client.py`)

- **Dependency-light:** only `requests` (lazy-imported). Usable as CLI or importable `MatClient`.
- **Auth: API key ONLY.** Sends `Appian-API-Key`. Basic auth was removed. Config via env vars, a `.env`
  file (auto-loaded), or CLI flags: `APPIAN_BASE_URL`, `APPIAN_API_KEY`.
- **Per-endpoint methods** baked into `ENDPOINTS = {export:(exportObjectV2,POST), convert:(convertObjectV2,GET), compare:(compareObjectV2,GET)}`.
- **`doc_id_of()`** unwraps the export's `xmlDocumentId` which is a **Document value `{"id": N}`** (also handles lists/scalars).
- **`TYPE_MAP`** maps converter shortType → IX key so `run` needs only `--short-type`.
- **`run`** does export → (compare | convert) and computes a recursive field **`diff`** + **`match`** flag.
- **`diff_values`** kinds: `value_mismatch`, `missing_in_converted`, `extra_in_converted`, `length_mismatch`.
- **Errors** return `{"ok": false, "error": ...}` with HTTP status, method, and the
  `requested-while-authenticated` header — invaluable for diagnosing 404/500.

**Commands:**
```bash
python mat_client.py export  --type content --id 6538 --uuid <uuid>          # POST
python mat_client.py convert --type rule    --doc-id <xmlDocId>              # GET
python mat_client.py compare --type rule    --uuid <uuid> --doc-id <xmlDocId>
python mat_client.py run --short-type rule --id 6538 --uuid <uuid> [--no-compare]
```

A `.venv` in the repo already has `requests` (`.venv/bin/python mat_client.py …`).

### Type keys (two vocabularies — the #1 mistake)
- **export** → IX key (`content` covers rule/interface/constant/decision/integration; plus `recordType`,
  `processModel`, `datatype`, `dataStore`, `group`, `groupType`, `site`, `webApi`, `connectedSystem`,
  `application`). The plugin also accepts Appian type names / shortTypes.
- **convert/compare** → converter **shortType** (`rule`, `interface`, `constant`, `recordtype`, `processmodel`, …).

---

## 8. Findings, gotchas & lessons learned (do not lose these)

1. **LCP-created Web APIs 404 (known platform issue).** Web APIs created through the LCP API don't route.
   → Create tester Web APIs **manually in Designer** (the `…V2` aliases). This cost significant debugging;
   the 404 initially looked like an auth failure.
2. **Web APIs are method-specific → wrong method = 404.** `exportObjectV2`=POST, `convert/compareObjectV2`=GET.
   A GET to a POST alias (or vice versa) returns `404` + `requested-while-authenticated: false`. Always match the method.
3. **Auth = opaque API key, not a JWT.** An Appian Admin-Console **API Key** is an opaque string sent as
   `Appian-API-Key`. A JWT (`eyJ…`) is an OAuth token and will **not** authenticate as an API key (and expires).
   The `requested-while-authenticated` response header tells you if the call authenticated (`true`/`false`).
   When a call runs anonymous, Appian returns **404** for non-public Web APIs (hiding them) or **500** for a
   public one whose expression needs a real user.
4. **The env side needs an authenticated privileged user.** `MAT_getEnvObjectData` reads design-object internals
   (`asSystem` + DOD). Called anonymously it fails (earlier 500). Call `compare` authenticated as a service
   account with Designer/export rights.
5. **Export type key normalization.** `Type.get()` needs an IX key; passing `ContentFreeformRule` threw
   `Unknown object type key`. The plugin now normalizes IX key / Appian type name / shortType.
6. **`xmlDocumentId` is `{"id": N}`.** It's a Document value; unwrap before chaining (client does this).
7. **Local id vs UUID.** `exportObjectV2` needs the **numeric local id** (`LocalIdMap` is by local id), not the
   UUID. Resolve in Appian via `a!util_convertUuidToId(uuid, type)` (type is a `type!{…}Xxx` reference).
   *Possible enhancement:* resolve uuid→id inside the export Web API/PM so callers pass only `(type, uuid)`.
8. **DOD validator blocks LCP** for any object referencing `a!dod_config_getTypeMap()` (deferred lambdas use
   `fv!o1/o2/value`). So `MAT_getEnvObjectData` and the compare Web API are **Designer-only** — same reason
   `MA_renderDiffViewForObject` can't be edited via LCP.
9. **`a!startProcess` sync output** works here because the export PM is a single unattended node (completes in
   the start transaction). If a future PM doesn't, read the doc id back via a query instead.
10. **LCP can't create `PROCESS_MODEL`-typed constants** → `MAT_PM_EXPORT_OBJECT` was created in Designer.
11. **Environment-only diff fields are expected** and should be filtered/accepted (ids, `latestVersionNumber`,
    resolved names, security-principal metadata). Real converter gaps are the rest (e.g. `roleMap` shape).

---

## 9. Current status (what works / what's pending)

**WORKING (verified live 2026-07-05):**
- ✅ `export` (POST `exportObjectV2`) → real XML + ZIP doc ids.
- ✅ `convert` (GET `convertObjectV2`) → converter diff map.
- ✅ `compare` (GET `compareObjectV2`) → `{env, converted}`.
- ✅ `run` → export→convert→compare + field diff + `match` flag.
- ✅ Export plugin builds standalone (bundled jars) and is deployed/working.
- ✅ Client is API-key-only, compiles, and runs.

**PENDING / NEXT:**
- ▶ Run the **full converter matrix** per object type (simple → complex), triage diffs, fix `MA_convert_*`.
- ▶ Consider an **ignore-list** in the client `diff` for known env-only fields to reduce noise.
- ▶ Consider resolving **uuid→id inside the export Web API/PM** so callers pass only `(type, uuid)`.
- ▶ Delete the dead LCP Web APIs (`mat_exportObject`, `mat_convertObject`, `compareObject`).
- ▶ Known converter areas to reconcile from the first run: **`roleMap` shape** (env `{inherit, entries}` vs
  converter `{administrators, editors, …}`); complex types (record type, process model) and aiSkill later.

---

## 10. Worked example (verified live)

Object: `MA_util_ensureArray` (expression rule in the Merge Assist app),
uuid `_a-0000efa6-747f-8000-9ba4-011c48011c48_33621`, **local id 6538**.

```bash
python mat_client.py run --short-type rule --id 6538 --uuid _a-0000efa6-747f-8000-9ba4-011c48011c48_33621
```
1. `export` (POST) → `success: true`, `xmlDocumentId: {"id": 13489}` (unwrapped to `13489`), `zipDocumentId`.
2. `compare` (GET, `type=rule`, `docId=13489`) → `{env, converted}` (name, description, inputs, expression,
   `latestVersionNumber`, `roleMap`, `parent`, …).
3. Client diffs them → `match: false`, **~30 diffs**. Triage:

| Diff path | Kind | Class |
|---|---|---|
| `roleMap.*` (administrators/editors/viewers/adminOwner/deny…) | extra_in_converted | **REAL** — env uses `{inherit, entries:[…]}`, converter uses a different roleMap shape |
| `expression` | value_mismatch | real/benign — trailing newline/whitespace |
| `inputs[0].description` | value_mismatch | benign — `""` (env) vs `null` (converter) |
| `latestVersionNumber` | value_mismatch | env-only (`2` vs `null`) |
| `parent.id` / `parent.name` | value_mismatch | env-only resolved metadata |
| `parent.uuidForSecurity`/`typeForSecurity`/`qNameForSecurity`/`isVisibleOnSystem`/`dodIsSensitiveNameData` | missing_in_converted | env-only security metadata |

Even a trivial rule surfaces one **real** converter item (`roleMap` shape) plus expected env-only fields.
That per-type triage loop is the whole point of the framework.

---

## 11. How to run (quick start for a new agent)

1. **Prereqs on the environment:** the tester app objects exist (§6), the export plugin JAR is deployed to
   `_admin/plugins/`, and you have an **opaque API key** for a service account with Web API + design-object
   export rights.
2. **Configure the client:** in `merge-assist-tester-client/.env` set:
   ```
   APPIAN_BASE_URL=https://merge-assist.appianpreview.com
   APPIAN_API_KEY=<opaque service-account API key>
   ```
3. **Install deps:** `pip install requests` (or use the repo's `.venv`).
4. **Resolve the object's local id** in Appian: `a!util_convertUuidToId(uuid, 'type!{http://www.appian.com/ae/types/2009}ContentFreeformRule')`
   (use the right `type!` reference per object type).
5. **Run:** `python mat_client.py run --short-type <shortType> --id <localId> --uuid <uuid>`.
6. **Read the `diff`**, classify each entry (real gap vs env-only), fix `MA_convert_<type>` in the Merge
   Assist app (via LCP MCP, per MA conventions), and re-run until only env-only diffs remain.

Deep reference: `merge-assist-tester-client/docs/CONVERTER_TESTING_STRATEGY.md`.

---

## 11A. Git repository, LFS & cloning

The tester client repo is on **GitLab**: `git@gitlab.appian-stratus.com:ramaswamy.u/merge-assist-tester-client.git`
(branch `main`).

**Git LFS is required.** The 6 Appian SDK/AE jars in `object-export-plugin/lib/` are stored via **Git LFS**
(they total ~32 MB and `appian-ae.jar` alone is 20.8 MB — GitLab enforces a 10 MiB per-blob limit, so they
cannot be committed as normal git blobs). `.gitattributes` routes `object-export-plugin/lib/*.jar` to LFS.

**Cloning:**
```bash
git lfs install                         # once per machine
git clone git@gitlab.appian-stratus.com:ramaswamy.u/merge-assist-tester-client.git
# LFS fetches the jars automatically; then build the plugin:
cd merge-assist-tester-client/object-export-plugin && JAVA_HOME=<jdk17> ./gradlew clean jar
```
Without `git lfs`, the jar files come down as small text pointer files and the plugin build fails — install
LFS and `git lfs pull`.

**What is NOT tracked (`.gitignore`):** `.env` (API key), `.venv/`, `__pycache__/`, `.DS_Store`, and the
plugin build output/cache (`object-export-plugin/build/`, `object-export-plugin/.gradle/`). The built plugin
JAR is therefore not in git — rebuild it with `./gradlew clean jar`.

**History note:** the very first commit accidentally included the jars as normal blobs (push rejected by
GitLab's 10 MiB limit) plus build/cache/`.DS_Store`. This was fixed by adding `.gitignore`, moving the jars to
LFS, and amending the (unpushed) root commit — so the pushed history contains no oversized raw blob.

---

## 12. Appendix — consolidated UUID / endpoint reference

**Tester app** `_a-0000efec-4e49-8000-9be6-011c48011c48_75004` (MAT):
- Web APIs: `exportObjectV2` POST `499d27c4-5dbc-4949-9852-c28c67b7d773`; `convertObjectV2` GET
  `70ae8c52-f258-4155-9d9f-ef0a6128420a`; `compareObjectV2` GET `b97ed1c5-d48a-40dd-8581-953f440b7080`.
- Rule `MAT_convertXmlObjectData` `_a-0000efec-4e49-8000-9be6-011c48011c48_75041`; `MAT_getEnvObjectData` (Designer).
- PM `MAT Export Object` `0002efef-120d-8000-fd73-7f0000014e7a`.
- Constants `MAT_PM_EXPORT_OBJECT` (Process Model), `MAT_FOLDER_OBEJCT_EXPORTS` (Folder).
- Dead LCP Web APIs: `mat_exportObject` `2929e8e7-…`, `mat_convertObject` `0bf8cd80-…`, `compareObject` `de89857d-…`.

**Merge Assist app** `33060c62-b495-4c03-9948-206c2f976d2b` (MA):
- `MA_convertXmlToDiffMap` `_a-0000efa6-747f-8000-9ba4-011c48011c48_33874` (+ ~23 `MA_convert_*`).
- `MA_renderDiffViewForObject` `_a-0000efa9-1a7d-8000-9ba8-011c48011c48_35306`.
- `MA_UT_deriveDiffObjectDataFromEnv` `_a-…74113` / `MA_UT_deriveDiffObjectDataFromXml` `_a-…74101`.
- `MA_UT_constructObjectClassifications` `_a-0000efa7-bf84-8000-9ba6-011c48011c48_34137`.
- `MA_FM_createNewSession` `_a-0000efa6-747f-8000-9ba4-011c48011c48_33965`.
- `MA Process Session Packages` PM `0002efa8-20a2-8000-fad1-7f0000014e7a`.
- Records: `MA_REC_MergeSession` `fd17fe05-…` (incl. `includeBaseComparison` `6a775d57-…`),
  `MA_REC_ObjectClassification` `e8afcb0f-…` (incl. `vendorXmlDocId` `7a98e402-…`, `baseXmlDocId` `06cf979b-…`).

**Export plugin:** key `com.appiancorp.objectexport`, smart service `objectExportToXml`
("Object Export To Xml"), class `ExportObjectToXmlService`, JAR `object-export-plugin-1.0.0.jar`.

**Endpoints:** `https://merge-assist.appianpreview.com/suite/webapi/{exportObjectV2 [POST] | convertObjectV2 [GET] | compareObjectV2 [GET]}`
(auth: `Appian-API-Key`).

**Verified example object:** `MA_util_ensureArray`, uuid `_a-0000efa6-747f-8000-9ba4-011c48011c48_33621`, local id `6538`.


---

## 13. Session 2026-08-14 — dev env, Deployment MCP export bridge, compare type-key fix, converter progress

### 13.1 Environment & clients
- Migrated to dev env `https://merge-assist-dev.appianpreview.com`. Old-env local ids/doc ids discarded;
  everything re-resolved. UUIDs are the only portable ids.
- MAT progress rows re-baselined in dev (`MAT_REC_ConverterTest` `373dfe3c-a483-4c30-b072-89aaf3993aae`).

### 13.2 THE export problem, solved with the Appian Deployment MCP
- The built-in `object-export-plugin` (`exportObjectV2`) reliably exports **content objects, site,
  group**, but returns **HTTP 504** for `webApi`, `processModel`, `recordType` (IX `ExportFacade` fails).
  Verified engine-healthy (site exports succeeded interleaved).
- Installed the **Appian Deployment MCP** (community App Market utility wrapping the Deployment REST API)
  at `~/appian-deployment-mcp`, wired into `~/.kiro/settings/mcp.json` (server `appian-deployment`,
  env `default` = dev). Prereq: Admin Console → **Outgoing External Deployments** enabled + API key's
  service account set as **Authenticate As** (else `POST /deployments` → 403 `APNX-1-4552-001`).
- **Export bridge (works for every type):** `export_package(application, [appUuid])` →
  `poll_deployment_status` → `download_exported_package` → unzip → `<type>/<uuid>.xml` (identical IX
  `*Haul` format) → `upload_xml.py <file> <name> <MAT ObjectExports folder> <MAT app> xml` →
  `getcontentdetailsbyuuid` for docId → `mat_client.py convert/compare --doc-id`.
- **New client tool:** `merge-assist-tester-client/upload_xml.py` (local XML → env document via LCP
  `POST /documents`, basic auth). Uploaded docs MUST land in the **MAT Object Exports** folder
  `_a-0000efee-f112-8000-9bea-011c48011c48_75077` (only folder the convert/compare Web-API user can read;
  elsewhere → HTTP 500).

### 13.3 CRITICAL — compare type key ≠ converter shortType
- `compareObjectV2`'s env half keys on the **DOD type-map key** (`a!dod_config_getTypeMap`), authoritative
  list from rule **`MA_getValidObjectTypes`** `_a-0000efa7-bf84-8000-9ba6-011c48011c48_34170`.
- **Record types use `record`, NOT `recordtype`.** Passing `recordtype` → HTTP 500 (looked like "no env
  oracle"); `record` → HTTP 200 with full data. Client fixed: added `COMPARE_TYPE_MAP`
  (`recordtype`→`record`); `compare_object` sends the DOD key. Other types match across both vocabularies.
- Lesson: **always confirm the compare key via `MA_getValidObjectTypes` before declaring a type blocked.**

### 13.4 New platform gotchas (this session)
- `a!dod_displayName_contentByUuid` is **unavailable** in dev → build content display maps from
  `getcontentdetailsbyuuid` text parsing.
- MCP `createExpressionRule` rejects `fn!try`/`a!util_convertUuidToId`/`fn!lambda_appian_internal` and
  `ri!` lambda params; `updateExpressionRule` tolerates them but rejects **unused local variables**.
  ⇒ edit converters via `update`, inline logic, no lambdas, remove unused locals.
- `fn!reverse()` does NOT reverse strings (lists only).
- `a!util_convertUuidToId(uuid, ContentFreeformRule)` returns `""` for interfaces/integrations.

### 13.5 Shared helper change
- **`MA_util_convertRoleMap_V2`** now orders entries by role priority (none→administrator→editor→viewer→deny)
  so all callers get env-matching order (promoted from a per-converter fix; re-verified group/interface/
  constant/connectedsystem — no regressions). NOTE: some types' env roleMap has **no `inherit`** key
  (site, record) — strip it in those converters.

### 13.6 Converter results this session
| Type | Result | Notes |
|---|---|---|
| site | 🟡 CLEAN (4 env-only) | Rewrote: inline branding hex, favicon defaultImage resolve, page contentName via getcontentdetails, `ContentFreeformRule`→`Interface(260)`, roleMap default-only. Env-only: id, pages[0].id, siteUrl, versionIdentifier. |
| connectedsystem | 🟡 CLEAN (3 env-only) | Created temp `MA_TEST_CS_HTTP`. V2 roleMap+reorder, integrationType/uuid, blank sharedParameters.baseUrl, enableRtdShortcut null, vaultFieldMetadata {}. Env-only: id, version, latestVersionNumber. |
| recordtype | 🔴 GAPS 62→15 (1 real) | Compare key `record`. Fixed V2 roleMap (no inherit), field displayName/type (short top-level / full sourceCfg), versionUuid→"", nameExpr `a!` normalize, sourceCfg empty defaults, supportsIncrementalSync, craFlags, detailViewCfg/views split. 14 env-only DB ids + **1 real: `enabledFeatures` (bitmask 2047 → decoded feature-name list)**. |
| webapi / processmodel | ⛔ BLOCKED | export 504 (deployment MCP can export) AND compareObjectV2 500 (no env oracle). |
| application / knowledgecenter | ⛔ BLOCKED | export OK + converter runs, but compareObjectV2 500 with correct key + valid doc → genuine env-oracle gap. |

### 13.7 Two-axis constraint (mental model)
A type is testable only if BOTH: (1) **export** works (built-in for content/site/group; Deployment MCP
bridge for the rest — solved), AND (2) the **compare oracle** (`MAT_getEnvObjectData`, Designer-only)
serves it. Oracle confirmed for the 7 core types **+ record**; returns 500 for application/webapi/
processmodel/knowledgecenter. Extending the oracle to more types is a **Designer task** (LCP can't
read/edit `MAT_getEnvObjectData` — reaches the DOD framework).

### 13.8 Temp artifacts to delete at cleanup
- Rules: all `MA_TMP_*` (incl. `MA_TMP_dumpSite` `_a-0000f03b-67ee-8000-9bde-011c48011c48_26522`).
- Fixtures: `MA_TEST_CS_HTTP` `_a-…26693`, `MA_TEST_APP` `_a-…26866` (+ auto KC `_a-…26879`), uploaded
  `dep_*` XML docs in MAT Object Exports.

### 13.9 Next steps
1. recordtype: decode `enabledFeatures` bitmask→name list (last real gap).
2. datatype/datastore/grouptype/translation*: fetch XML via the bridge, compare with the correct DOD key
   (`MA_getValidObjectTypes`) — untested; may or may not have an oracle.
3. Designer task: extend `MAT_getEnvObjectData` to serve application/webapi/processmodel/knowledgecenter.
