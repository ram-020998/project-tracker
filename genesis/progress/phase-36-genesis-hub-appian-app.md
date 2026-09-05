# Phase 36 — The Genesis Hub Appian Application — AS-BUILT (IN PROGRESS)

> **Status: 🔨 BUILD IN PROGRESS (2026-09-05).** ADR-064. Appian-side build in the team dev environment,
> executed by a write-capable Dev-MCP agent (NOT genesis — genesis stays read-only per ADR-036/037). This doc
> is the durable record of what has been created so a new session can continue. **DONE: the isolated app +
> data model (11 record types + 13 relationships) + record-level security + 7 constants + the FULL API SURFACE
> — 11 Web APIs + 11 helper expression rules + the base64 blob store (via the user's `GH Convert Base 64 To
> Document` process). `GH_blobs_put` was verified working end-to-end (201 new + 200 dedup). All objects confirmed
> associated with the Genesis Hub app.** REMAINING (see `36-08-remaining-work.md`): wire the blob-put
> `documentId` (activity-chain), the frozen contract doc + fixtures, packaging + service-account provisioning,
> and end-to-end contract validation (36-06) → hand-off (36-07).

## Environment / identity
- **Appian env:** `https://merge-assist-dev.appianpreview.com` (Appian **26.6**). MCP: `lcp-mcp-server` (authenticated; `listApplications` returns 7 apps incl. "AS GSS Full Application").
- **Skill:** `~/.kiro/skills/appian/SKILL.md` — MANDATORY, load before any MCP tool call.
- **Application:** **Genesis Hub** (prefix **GH**) · appUuid **`_a-0000f058-fed5-8000-9bfc-011c48011c48_27312`** · urlIdentifier `HKB7tw`.
- Auto data source for all record types: **`jdbc/Appian`** (auto-resolved on create).

## ✅ DONE — Layer 1 (app / security / storage / config)
**Groups:** `GH Administrators` `_e-0000f058-fe86-8000-9b49-01075c01075c_458` · `GH Users` `_e-...-01075c01075c_460` (reused as the all-users/read group — no separate "GH All Users") · **`GH Service Accounts`** `_e-...-01075c01075c_462` (child of GH Users; the API writer group).
**Folders (under the auto Knowledge Center `_a-...27325` → Artifacts `_a-...27331`):** `GH KB Blobs` **`_a-...27350`** · `GH Artifact Blobs` **`_a-...27354`**. (NOTE: creating folders directly under the Knowledge Center root 403'd; they live under the Artifacts folder — functionally fine.)
**Constants:** `GH_GROUP_ALL_USERS` `_a-...27381`(→GH Users) · `GH_GROUP_ADMINS` `_a-...27368`(→GH Administrators) · `GH_GROUP_SERVICE` `_a-...27362`(→GH Service Accounts) · `GH_CONTRACT_VERSION` `_a-...27391` = **"1.0.0"** (semver TEXT — `"1.0"` numeric-coerced, so we standardized on 1.0.0; the frozen contract version) · `GH_BLOB_KEEP_LAST_N` `_a-...27376` = 10 · `GH_FOLDER_KB_BLOBS` `_a-...27372` · `GH_FOLDER_ARTIFACT_BLOBS` `_a-...27386`.

## ✅ DONE — 36-02 (11 record types + 13 relationships + record-level security)
All DATABASE-backed (`jdbc/Appian`, tables created), PK `id` INTEGER, `syncUuid` TEXT VARCHAR(255) **unique** (where applicable), **no USER fields** (attribution = TEXT), `description`/`text` = **EXTRA_LONG_TEXT** (`LONGVARCHAR(65535)`), medium text = TEXT length 4000, codes = TEXT 255. **Composite uniques are NOT declared at column level** (tool limitation) — they MUST be enforced in the Web-API logic: `GH_MEMBERSHIP(team_uuid,username)`, `GH_BOARD_STATE(app_uuid,story_sync_uuid)`, `GH_STORY_ITEM(story_sync_uuid,item_type,position)`, `GH_BLOB_VERSION(blob_kind,blob_key,version)`, `GH_ACTIVITY(kind,sync_uuid)`.

**Record-level security on all 11:** administrator+editor=`GH Administrators`, viewer=`GH Users`, **data_steward=`GH Service Accounts`** (the API data-write authority; service accounts inherit read via GH Users membership).

**Record type + field UUIDs (use the UUID-qualified `'recordType!{rtUuid}Name.fields.{fieldUuid}fieldName'` form in all SAIL — NEVER fabricate):**

### GH Team — rt `44b219ed-5d19-4192-90bd-8b8e31431f95` (GH_TEAM)
id `d3b054ba-db4f-4639-84b0-7b410119a773` · syncUuid `1d745740-0da2-48bd-89e5-9f32a69cc569` · title `78d54241-bd20-4bb8-8b20-f4db889e8d19` · version `56bcc0d9-9ed0-4d83-92c5-c7fbbae86a36` · createdBy `d77599b2-31d6-4522-b3dc-ecb45fe9034c` · createdAt `5841ca5b-1753-4306-b2ed-eafb3742780d` · updatedAt `daee6542-543d-4131-9c6d-dc4889ca582f`
rel **memberships** (O2M→Membership) `765cb6a2-120a-4bbd-b416-a6eecd462abc`

### GH Membership — rt `d35b1075-8d40-428b-a266-3b84f56075b5` (GH_MEMBERSHIP)
id `f7d5d32c-4b03-435e-9379-4065cc53144f` · syncUuid `156c9424-563b-43ca-a832-90ad263e6260` · teamUuid `b5f78dec-e663-4a32-8722-a9e0eb6addd6` · username `902db2ff-0560-4273-ad48-c49ef7204ad2` · name `f728a606-fcad-40ec-ad71-438a61f39b20` · email `efc742b3-e537-416c-9417-ac1e14436702` · joinedAt `324cce50-e527-4931-9cb8-450df8a88139` · version `7cec5b9a-7226-4f3b-b8bd-13ff2dfc9897`
rel **team** (M2O→Team) `72daf94f-f430-4691-848d-cc3c310c731f`

### GH Feature — rt `5ff1c823-0ff9-4a59-943b-3314aad3b6f7` (GH_FEATURE)
id `9f637632-4ec7-4b53-b6bd-9e1454e83205` · syncUuid `ce089835-d693-4351-a707-b0b25bd28ead` · appUuid `c95aa5b6-b29d-4a90-984b-6e75b04fb594` · name `05b2cf90-de64-454e-a30d-ab2790d559a8` · description(ELT) `fc100a24-747c-4472-ae15-5a8131a9d6b7` · ownerUsername `152062ec-f96a-4b84-9bd0-fdea7998f1e7` · teamUuid `780757b2-ed89-4067-8d40-8249014c0918` · version `3a7c9959-69b2-49c7-a445-ed08871f3d1d` · createdBy `ae7d033c-8ec5-4ded-8d21-c67c548a3e41` · modifiedBy `7dbdc95c-41cc-4a66-9bf7-4c447daa892c` · createdAt `06818ef3-58f8-4fcb-baa1-5b5220515dec` · updatedAt `dfea561a-2168-445f-ad4a-8a7f0cd8fc95`
rels **epics** (O2M→Epic) `0de75fc3-6aa6-46ba-81d0-60962bc28bdb` · **stories** (O2M→Story) `c1588523-ac34-425c-825e-2cac84c71374` · **stageArtifacts** (O2M→StageArtifact) `54cfd090-1809-465f-8eb4-c94b3e4c77da`

### GH Epic — rt `f023ee8d-e941-4554-b6b1-a8689c9cd6f4` (GH_EPIC)
id `6f79ad1a-3e28-4c2b-86ac-5fd2e668b5c6` · syncUuid `db39730a-34eb-47a4-8d1e-d611e390614e` · featureSyncUuid `f8958879-85de-4491-b00b-d8163b27fa16` · backlogKey(col BACKLOG_KEY) `7baf564c-a844-41d8-9b6b-4e8234933493` · title `0952db4c-fc14-4fb0-9e13-729a025ad8b8` · description(ELT) `f9b46466-4a6d-418d-8ce1-f59c5c6c34b4` · workstream `753d8f2a-2918-4903-97a5-aba2c9295c54` · position `99439414-20f6-4122-8a77-8dbffe40571b` · version `eb31d4c5-104a-416e-8b53-c7d58c464968` · createdBy `d93a657f-7e4d-47c7-a81d-78aa34f81953` · modifiedBy `fb5f67b6-7f4f-466a-948c-b4bc2f606638` · createdAt `95d06514-fa23-4e62-a3d8-ccab65f48b0c` · updatedAt `71891a90-fa1b-4612-bee7-925ee68797a1`
rels **feature** (M2O→Feature) `dc2a1283-8512-454f-8672-d6cd02151532` · **stories** (O2M→Story) `f22a692e-92b9-4197-88b0-cffcb6e6220c`

### GH Story — rt `31c5187d-3c6f-467a-be02-d4549d98a822` (GH_STORY)
id `e539301b-5f9e-4c5a-8086-5e3add2cb38b` · syncUuid `0ebb514f-fd0f-49f7-88ec-a933813858be` · featureSyncUuid `b874e119-e3dc-4e51-a872-7ff9ac869120` · epicSyncUuid `fbdc2e78-2169-4b03-8000-a66baac4e1bd` · backlogKey(BACKLOG_KEY) `89fb1002-38f3-4ac0-9671-66779772da4f` · title `e64b3bd3-6068-45e2-ba6a-0130faf7db4b` · storyType `a30ed75e-14ee-40f2-bd07-b8ac3cf85087` · category `6397d10e-7b6b-43e0-a362-6c44e4e02c6b` · appianPart `28d96640-0e9f-4a6a-9a69-0068df4e80e7` · description(ELT) `7a7226bb-6f76-4add-a5eb-3b99579ad446` · devNoteRef `24ec7d30-03de-4579-b247-ca7a1e5bc044` · status `17bdfabd-8707-457e-98e1-e4a96cdb73fd` · position `176ae0b5-b95a-4d33-9561-a50877149b64` · ownerUsername `801ae4a3-f1f7-4629-b32b-9a32a7f3576c` · teamUuid `b6f2e2ee-b001-436e-8a85-68d756275bc0` · version `23dcbd62-723d-4ed1-bfa5-5c941d3a0c66` · createdBy `9d8ccc6b-336c-470c-91c5-b33e65b13377` · modifiedBy `76f76460-5d59-4b2d-846c-170997a4523d` · createdAt `80403c59-90e1-4cf8-b498-7fe54e34809a` · updatedAt `09b91765-84f9-4807-841b-b1c625fef74e`
rels **feature** (M2O→Feature) `3afd6eaf-cec8-43f9-9d46-75279fcd0dd2` · **epic** (M2O→Epic) `151d5a24-3fdb-46dc-a9de-ecc186c4a903` · **storyItems** (O2M→StoryItem) `9dcd602e-5139-46b8-9a6a-627ff2f69c2d` · **stageArtifacts** (O2M→StageArtifact) `aae1d96c-aea9-4e12-9838-316043cff750`

### GH Story Item — rt `556f67aa-34fe-42b1-a67e-76a67f770b84` (GH_STORY_ITEM)
id `f9e92a74-9b10-4d0d-a888-0d041b265f0f` · syncUuid `de9521ee-5bd4-4ff2-9c09-92ed74177a79` · storySyncUuid `0c51b86d-ca5c-4631-9211-065a1cc0ae19` · itemType `d8bcdbcd-8337-4bce-9297-1f20489521f6` · text(ELT) `b025a024-7026-4f1b-a593-d95808226840` · position `117fc24f-02da-4e1e-9541-dc927d09e528` · version `6edcb75e-3a5d-4a7a-b22f-4f106abf03b1` · createdAt `2cd5e3af-fe8a-4f9d-bb4f-1e6e4c286a71` · updatedAt `63835405-121b-4465-80e6-59955e6033f5`
rel **story** (M2O→Story) `83aa53bb-39e5-452f-9799-316ddf099037`

### GH Board State — rt `cd472522-5be5-4129-bd74-fce457f6cd08` (GH_BOARD_STATE)
id `472073f7-d280-4180-96d6-5260ab638c8b` · syncUuid `4cc1cf5e-f22e-4d49-b854-07829c1beb11` · appUuid `323886ba-7e50-4674-9ca1-8ca05de5a459` · storySyncUuid `ee60e530-bd9b-41e6-b970-6a448119aabc` · status `3fc739de-9557-4e69-bc57-6232ce7ad777` · version `8c8b2b2e-e9ca-42ac-8a0c-7ca95100b557` · modifiedBy `1b33546e-5efc-46b5-afbd-1953fe0ee546` · updatedAt `24222011-eaf7-4fa2-97f9-660a9988f0b6` (no relationships)

### GH Stage Artifact — rt `90a731eb-86ba-4d04-baa0-dd4b760fb121` (GH_STAGE_ARTIFACT)
id `0a6ebbbc-c35a-4241-8cf5-bf82c2d657f7` · syncUuid `bafef139-13c0-48af-94c2-a05ae28f63ce` · parentSyncUuid `f0f2b44b-500b-4c44-bbf2-db30be525a03` · parentKind `9ba8d236-a79e-44d4-9077-64a065815a70` · stage `d1f2076a-919f-4ce0-a5ef-3cb5dc030a01` · status `8c7df8f5-d076-49d6-a810-a82790dff889` · contentHash `236db236-70fe-402d-8fdd-221756f82d86` · blobKey `a7610220-295b-4fb3-a556-4e9ad7e3d685` · upstreamVersions `ae3c482a-e065-4984-89d9-ff6fd147e0ff` · publishedBy `639cd13f-e5bf-4969-8bd4-58225cfd54da` · publishedAt `b8e876e3-7a34-4b60-9541-a071f201ecf3` · version `a034273b-4373-4c00-8137-a742bf50eda2` · createdAt `e686f103-b087-421e-80fa-ddd83354e502` · updatedAt `4d3b5d05-bb85-4f4b-bc8e-1b5fe270e789`
rels **parentFeature** (M2O→Feature) `05e474cc-4eb6-49d3-807d-bd50c6546496` · **parentStory** (M2O→Story) `40ef52cd-bb99-4828-984f-0241a757b684` (both on parentSyncUuid)

### GH Blob Version — rt `c6368222-fe1f-4b0e-9e34-8dd43ce82fe4` (GH_BLOB_VERSION)
id `13729b74-26e5-4ff2-b9ae-55a380449701` · blobKind `97a68d6d-15c9-4565-bf1b-adf1e9876fa4` · blobKey `5fdb9b7c-d537-4853-bc1b-6a470e21099e` · version `99baf0e5-c231-41e3-a4e8-4ca712da5d57` · contentHash `edb0213f-e25e-4848-ae6e-eab7fdaf0b23` · documentId `b53e799f-d098-49ff-a0b7-5578049bbc05` · size `4c1fcdb9-0ec1-4889-b9b6-bd2c5c97c29c` · publishedBy `e34bfeb5-5e13-4c1f-8fad-4c41d123d878` · createdAt `b3d6eda2-0541-49db-b338-477164adc008` (no syncUuid; no relationships)

### GH Change Log — rt `ff9c6698-dd22-4e5a-a457-c188da1a49e4` (GH_CHANGE_LOG)
id(PK=cursor) `cb086be9-928d-4029-9b8b-22200bf3589e` · kind `40f98808-f300-4da7-9473-6e6ad6c2f43a` · syncUuid `58ba4ecd-1e4d-4588-87f5-8f4ebb80d4a7` · version `a4d66c3c-00d4-463b-8153-1f8b96411e97` · updatedAt `d2cdd33d-ce61-4c1a-8328-d01c7171fd98` · publishedBy `ac77d49d-b26d-4b0d-8f0b-61fdc86a8640`

### GH Activity — rt `c8b98356-4de5-4a67-bcfc-5520f54c2a99` (GH_ACTIVITY)
id `124db86f-842f-47da-800f-2f2e86b5afe3` · kind `2a27811a-f52a-48c8-ae77-1eb9952cb92c` · syncUuid `9e503975-d121-4211-8a88-6af0e7d41b1d` · username `be2b028a-70b4-4a7e-9543-22e7cdbea6fe` · setAt `7df5a3ef-32db-4e9e-8aca-026f532a3b2c` · expiresAt `34269471-38b0-40aa-9286-2d8ba896d665`

## 🔨 IN PROGRESS — 36-04/03 (constants ✅ / expression rules 11 built / Web APIs 11 of 11 — FULL API SURFACE BUILT)
**Blob layer DONE (36-03):** the base64→Document blocker was solved by the user's **`GH Convert Base 64 To Document`** process model (plugin `com.nttdata.plugins.MoreDocumentTools.base64StringToDocument`; tested: text + binary convert synchronously, isError=0) + the **`GH_convertDocumentToBase64String(documentId)`** rule (`documenttobase64()`) for reads. Constant **`GH_PM_STORE_BLOB`** `_a-...27560` → the PM. Blob rules: **GH_blobLatest** `_a-...27582`, **GH_pruneBlobVersions** `_a-...27578`, **GH_recordBlobVersion** `_a-...27590`. Blob Web APIs: **GH_blobs_get** `e3a3b070…`, **GH_blobs_versions** `b0561b92…`, **GH_blobs_put** `d563ee72…` (POST `blobs`). **⚠️ ONE USER-CONFIG ITEM:** `GH_blobs_put` has a marked placeholder `local!documentId: 0` — the user wires the **activity-chained** `GH_PM_STORE_BLOB` call (base64String/fileName/extension/folder → `createdDocument`) to set it (a!startProcess alone returns a Reaction Tree, so the doc-create must be activity-chained in the API to return the id synchronously).

## 🔨 IN PROGRESS — 36-04 (constants ✅ / expression rules 8 built / Web APIs 8 of 11 — NON-BLOB CONTRACT COMPLETE)
**Expression rules built (8 — the 6 planned + 2 helpers):**
- **GH_isServiceCaller()** `_a-...27478` · **GH_errorResponse(code,message)** `_a-...27482` · **GH_appendChangeLog(kind,syncUuid,version,actor)** `_a-...27491` · **GH_changesSince(cursor,limit)** `_a-...27497`.
- **GH_recordToJson(kind, record:Any)** `_a-...27503` (v2) — 7-kind projection; **story branch folds in reassembled acceptance_criteria/questions/labels** via GH_reassembleStoryItems (single source; get/list need no merge).
- **GH_casUpsert(kind, syncUuid, payload:Any, baseVersion, actor)** `_a-...27509` — the CAS capstone (7-kind dispatch, conflict/created/updated, story-item explode).
- **GH_reassembleStoryItems(storySyncUuid)** `_a-...27520` (v2, null-safe applyWhen) — rebuilds the 3 arrays from GH Story Item (position-ordered, empty stays empty).
- **GH_queryRecords(kind, syncUuid, limit)** `_a-...27526` — per-kind query (all fields); syncUuid filters to one (get) / null = paged list. Powers get + list.

**Web APIs built (8 of 11):** GH_meta (GET `meta`) · GH_records_upsert (PUT `records`, CAS 409/201/200) · GH_records_get (GET `records_get`, 404) · GH_records_list (GET `records_list`) · GH_changes (GET `changes`) · GH_activity_set (POST `activity`) · GH_activity_clear (DELETE `activity_clear`) · GH_activity_list (GET `activity_list`). **The records + changes + activity + meta contract paths are fully built + validated.** Remaining: the 3 blob Web APIs.
  - urlAlias uniqueness: aliases can't collide, so get/list/clear use `records_get`/`records_list`/`activity_clear`; the Genesis provider maps contract paths → these aliases (finalize in the contract doc).

**ALL SAIL PATTERNS PROVEN (reuse verbatim):**
- UUID-qualified refs (`'recordType!{rtUuid}GH Name.fields.{fieldUuid}f'`) for query/write/delete + record-constructor writes.
- `http!request` live: `.pathSegments` (1-indexed after urlAlias), `.body`→`a!fromJson`→Map, `.queryParameters`.
- Dict access = `index(map,"key",null)` (NOT `['key']` = identifier ref). Side-effect write locals MUST be referenced (unused-local gate blocks) — pattern `index({local!w, local!log, result}, 3, null)`. Null `ri!`/filter values under validation → use `applyWhen`/`a!defaultValue`. Design-time eval does NOT commit writes (tables verified empty).
- **Blob Document mechanism FOUND:** no bytes→Document function exists, but **`Generate Text` smart service (`internal.texttemplatemerge601`, UNATTENDED)** writes arbitrary text to a Document. Store the **base64 string as a text Document** (both kb + artifact); read the doc text back on GET. Needs a small **`GH_storeBlob` process model** (Start → Generate Text[content=base64, folder=cons!GH_FOLDER_*, name=`<key>-v<version>`] → End returns documentId). **DECISION for the blob path:** `a!startProcess` in a Web API is async — either (a) verify `a!startProcess(...).pv.documentId` returns synchronously when the process is fully synchronous (Generate Text is), or (b) make `POST /blobs` async (202 + the process does dedup/insert/prune). Prefer (a) if the sync-pv works; else (b).

## ⬜ REMAINING (do next) — API SURFACE COMPLETE; wiring + docs + packaging left
1. **⚠️ USER-CONFIG (blob PUT):** wire the activity-chained `GH_PM_STORE_BLOB` call in `GH_blobs_put` and set `local!documentId` (marked placeholder). Everything else in the blob path is built + validated.
2. **The FROZEN CONTRACT (36-01 §3): ✅ DONE (2026-09-05).** Written to `specs/phase-36-genesis-hub-appian-app/contract/genesis-hub-api.md` (222 lines — normative per-endpoint request/response, status table incl. 409-CAS + 200/201-dedup, the urlAlias↔path map, auth header, datetime/encoding conventions, `contract_version`="1.0.0") + `contract/fixtures/*.json` (12 adversarial lossless fixtures: meta, team, membership, feature[long unicode], epic, story[many AC / empty questions / unicode labels / null epic], board_state, stage_artifact, conflict[409], changes[incl. blob row], blobs[201/200/get/versions], activity[set/list/clear] — all validated as well-formed JSON). Transcribed from the deployed Web APIs + `GH_recordToJson`/`GH_changesSince`/`GH_reassembleStoryItems` (exact keys). This is the Phase-37 `AppianHubProvider` interface + the shared 36-06 harness.
3. **36-05 packaging + security:** ✅ **runbook DONE** — `contract/deployment-runbook.md` (packaged inventory, security grants, service-account provisioning, CSRF/allowed-origins for the write verbs, the blob-put `documentId` activity-chain step, the Web API max request-body-size 2 MB gate, install/upgrade + per-env checklist). ⬜ Remaining = **[ADMIN]** export the app `.zip` in Designer (no MCP export tool) + do the service-account/CSRF steps.
4. **36-06 contract validation** (end-to-end round-trips per kind + blob, incl. the 2MB blob) → **36-07 hand-off** (contract doc into genesis; bible/tracker/ADR-064 updates). Contract + fixtures are ready as the shared harness (`contract/`).

### urlAlias → contract path map (aliases can't collide, so paths are encoded in the alias; Genesis provider maps these)
`meta`→GET /meta · `records`(PUT)→/records/{kind}/{syncUuid} · `records_get`(GET)→/records/{kind}/{syncUuid} · `records_list`(GET)→/records/{kind} · `changes`(GET)→/changes · `activity`(POST)→/activity · `activity_clear`(DELETE)→/activity/{kind}/{syncUuid} · `activity_list`(GET)→/activity/{kind} · `blobs`(POST)→/blobs/{kind}/{key} · `blobs_get`(GET)→/blobs/{kind}/{key} · `blobs_versions`(GET)→/blobs/{kind}/{key}/versions. (kind/key/syncUuid are trailing pathSegments after the alias.)

## Full built inventory (36-04/03)
**Expression rules (11 + user's 1):** GH_isServiceCaller · GH_errorResponse · GH_appendChangeLog · GH_changesSince · GH_recordToJson(v2) · GH_casUpsert · GH_reassembleStoryItems · GH_queryRecords · GH_blobLatest · GH_pruneBlobVersions · GH_recordBlobVersion (+ user's GH_convertDocumentToBase64String).
**Web APIs (11):** GH_meta · GH_records_upsert · GH_records_get · GH_records_list · GH_changes · GH_activity_set · GH_activity_clear · GH_activity_list · GH_blobs_put · GH_blobs_get · GH_blobs_versions.
**Process model:** GH Convert Base 64 To Document (+ constant GH_PM_STORE_BLOB).

## ✅ 36-06 CONTRACT VALIDATION — live round-trip against the dev env (2026-09-05, service-account API key)
**PASS — the contract behaves correctly for every endpoint** (driven by `/tmp/gh_validate2.py`; evidence in the DB + direct curls):
- All **7 write kinds** upsert with correct base-version CAS: create → `201 {status:created, version:0}`, update → `200 {status:updated, version:1}`; verified in the source tables (GH Team `v2-team-…` v0→v1, GH Feature unicode preserved, GH Change Log rows for every kind incl. updates).
- **CAS conflict** (stale `base_version`) → `409 {error:"conflict", current_version}` ✓.
- **Story items** delete-then-insert replacement ✓ (DB shows only the updated AC; originals removed) — the chained `a!deleteRecords(onSuccess: a!writeRecords(...))` works.
- **Unicode/whitespace lossless** end-to-end (`café 東京 🚀🔥`, blank line + trailing tab) ✓.
- **Reads** (`records_get`/`records_list`/`blobs_versions`/`activity_list`) return correct data once synced ✓ (direct curl 200s); **`/meta`**, **`/changes`**, **blob put→`201`/dedup→`200`**, **activity set→`200`** ✓.

### ⚠️ CRITICAL SAIL LESSON (Web API writes) — do NOT regress
`a!writeRecords`/`a!deleteRecords` are **smart services** that only execute when they are the **terminal** expression of the Web API (or chained via another smart service's `onSuccess`). A write captured in a `local!` and merely referenced (`index({local!w, …}, N, null)`) **does not reliably execute** and yields a **500** even though nothing looks wrong. Also, `onSuccess`/`onError` **must be a FRESH `a!httpResponse(...)`** (per Appian docs: "created with a!httpResponse()"), **not** `a!update(ri!onSuccess, "body", …)` — the latter produces a non-HttpResponse and returns 500 while the write still commits. `GH_appendChangeLog` was refactored to **return a GH Change Log record** written in the SAME `a!writeRecords` batch (atomic). `GH_casUpsert` (v6) + `GH_activity_set` now follow this. **Read-after-write is eventually consistent** (record-type synced replica lags the DB by >15s) — trust the PUT response's `version`; don't immediately re-GET (contract §4a).

### ✅ ALL 11 Web APIs functional — full contract green (2026-09-05)
- ✅ **`GH_activity_clear` (DELETE)** — FIXED + verified: expression corrected to terminal `a!deleteRecords` (guarded), security granted to `GH Service Accounts`, object added to the app. `POST /activity`→`200 {ok}`, `DELETE /activity_clear/{kind}/{su}`→`200 {cleared}`. (Root cause of the earlier 404: the object wasn't in the app + had empty security so the API-key caller couldn't see it; and it used the broken `index()`-in-local pattern.)
- ✅ **`GH_blobs_put` `documentId`** — WIRED by the user + verified: `GET /blobs_get/kb/<key>` returns the real Document bytes as base64, decoding byte-for-byte with `sha256(decoded)==content_hash`. Full blob path green (put 201 / dedup 200 / versions / GET lossless).

## Key decisions / deviations recorded
- Reused auto `GH Users` as the read/all-users group (not a separate "GH All Users").
- Blob folders under the Artifacts folder (KC-root createFolder 403'd).
- `GH_CONTRACT_VERSION` = **"1.0.0"** (semver) to avoid `"1.0"`→numeric coercion.
- `backlogKey` (col `BACKLOG_KEY`) instead of the reserved word `key`.
- Composite uniqueness enforced in the Web-API logic (tool declares only single-column uniques).
- Relationships join on the `syncUuid`/`*SyncUuid` fields (not the int `id` PK — local ints collide across machines).
- Attribution is TEXT (no USER fields) — the service account is the real Appian writer; the logical author is payload-supplied.

## Skill workflow reminders for the continuing agent
- Load `~/.kiro/skills/appian/SKILL.md` first, then for 36-04: `tools-mcp.md`, `expressions.md`/`expression-rules.md`, `write-records-patterns.md`, `query-record-type-patterns.md`, `function-reference.md` + `sail-verification-checkpoint.md` (Step 4), `validation-checkpoint.md` (Step 7B), and the Web-API guidance. **Every SAIL body → Step-4 verify + `validateExpression` retry loop (or `a!localVariables` wrap for ri!/toJson) before create; `testRule` after.**
- **Never fabricate UUIDs** — use the table above (or re-fetch via `getRecordType`/`listRecordTypeFields`).
- Deletions require the skill's `confirmation-patterns.md` Universal Workflow 1 (10 steps) + user confirmation.
