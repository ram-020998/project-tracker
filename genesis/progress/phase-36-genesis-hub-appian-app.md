# Phase 36 — The Genesis Hub Appian Application — AS-BUILT (IN PROGRESS)

> **Status: 🔨 BUILD IN PROGRESS (2026-09-05).** ADR-064. Appian-side build in the team dev environment,
> executed by a write-capable Dev-MCP agent (NOT genesis — genesis stays read-only per ADR-036/037). This doc
> is the durable record of what has been created so a new session can continue. **Data model + security are
> COMPLETE; the Web-API/expression-rule logic layer + contract doc + packaging remain.**

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

## 🔨 IN PROGRESS — 36-04 (constants ✅ / expression rules 4 of 8 / Web APIs 1 of 12)
**Expression rules created (4 of 8):**
- **GH_isServiceCaller()** `_a-...27478` — `a!isUserMemberOfGroup(loggedInUser(), cons!GH_GROUP_SERVICE)`.
- **GH_errorResponse(code:Integer, message:Text)** `_a-...27482` — `a!httpResponse(statusCode, headers:{a!httpHeader(Content-Type, application/json)}, body:a!toJson(a!map(error, code)))`.
- **GH_appendChangeLog(kind:Text, syncUuid:Text, version:Integer, actor:Text)** `_a-...27491` — `a!writeRecords` one GH Change Log row (id identity auto-increments = the cursor; id NOT set).
- **GH_changesSince(cursor:Integer, limit:Integer)** `_a-...27497` — `a!queryRecordType(GH Change Log, filter id>cursor, sort id asc, batchSize limit)` → `{changes:[{kind,sync_uuid,version,updated_at,published_by}], next_cursor=max(id)}`.

**Web APIs created (1 of 12):**
- **GH_meta** (GET, urlAlias `meta`) `7186c6e1-ddb2-45d0-be12-5295e31b7b2e` — asserts `rule!GH_isServiceCaller()` else `rule!GH_errorResponse(401,"unauthorized")`; else `a!httpResponse(200, …, a!toJson(a!map(contract_version: cons!GH_CONTRACT_VERSION, server_time: now())))`.

**ALL SAIL PATTERNS PROVEN in this env (de-risked — reuse verbatim):**
- **UUID-qualified refs are the correct form** for MCP create/validate: `'recordType!{rtUuid}GH Name'` and `'recordType!{rtUuid}GH Name.fields.{fieldUuid}fieldName'` (single quotes + `{uuid}` braces, name incl. spaces). `a!queryRecordType` with these **discovers cleanly** (only a `serviceContext is null` eval artifact — parse+discovery pass).
- **Writes:** `a!writeRecords(records:{ 'recordType!{rtUuid}GH Name'( 'recordType!{rtUuid}GH Name.fields.{fUuid}f': value, … ) })` **validates `hasErrors:false`** (record-constructor form). Usable inside expression-rule bodies invoked by Web APIs.
- **Web APIs:** `createWebApi` (expressionFilePath) runs full parse+design+eval and accepts `a!httpResponse`/`a!httpHeader`/`a!toJson`/`cons!`/`now()`/`rule!` — GH_meta created clean. **Request object = `http!request`** (Appian platform: `.body` [JSON string → `a!fromJson`], `.queryParameters`, `.pathSegments`, `.headers`, `.method`) — validated by createWebApi at creation (raw `validateExpression` lacks `http!` context, like `ri!`). Existing env Web APIs declare `requestBodyType:NONE` and read `http!request.body` directly.
- **Validation:** `validateExpression` can't eval `a!toJson` (no TypeService) or resolve `ri!`/`http!`/serviceContext — for those rely on `createExpressionRule`/`createWebApi` with **testInputs** (all 4 rules above validated this way). Wrap `ri!` in `a!localVariables` with test values only for pure standalone checks.

## ⬜ REMAINING (do next)
1. **4 helper expression rules** (36-04 §B): `GH_recordToJson(kind, record)` (project a row → contract JSON field names; polymorphic over 7 kinds — dispatch `a!match(ri!kind)`; access fields via the UUID-qualified refs per kind; consider typing `record` as Any/Map or a per-kind design if Any-typed field access won't validate) · `GH_casUpsert(kind,syncUuid,payloadMap,baseVersion,actor)` (the shared CAS write: query current by kind+syncUuid → if `current.version != baseVersion` return `{status:"conflict", current_version}` else a!writeRecords the kind's record with `version=coalesce(baseVersion,-1)+1` + modifiedBy/updatedAt (+createdBy/createdAt on create) → `rule!GH_appendChangeLog`; **for kind='story' also explode acceptance_criteria/questions/labels arrays into GH Story Item rows [query existing by storySyncUuid → deleteRecords + a!writeRecords current] in the same op**) · `GH_pruneBlobVersions(kind,key)` (query GH Blob Version for key sort version desc, deleteRecords rows + Documents beyond `cons!GH_BLOB_KEEP_LAST_N`) · `GH_blobDedupAndStore(kind,key,bytesB64,contentHash,actor)` (latest GH Blob Version for key; if contentHash equal → `{status:"unchanged",version}`; else create/upload an Appian **Document** into GH_FOLDER_KB_BLOBS/GH_FOLDER_ARTIFACT_BLOBS [find the Document-create smart-service/function — the one genuinely-new mechanism to prove] + insert GH Blob Version row version=latest+1 + `rule!GH_appendChangeLog('blob',key,version,actor)` + `rule!GH_pruneBlobVersions`).
2. **11 Web APIs** (36-04 §C) — pattern proven by GH_meta; each asserts `rule!GH_isServiceCaller()` else `rule!GH_errorResponse(401,…)`; parse `http!request`; add write verbs to allowed origins (CSRF exemption): `GH_records_upsert` (PUT /records/{kind}/{syncUuid}; parse `http!request.body`+base_version+actor via `a!fromJson`; `rule!GH_casUpsert`; conflict→`GH_errorResponse(409,…,{current_version})`; 201 create/200 update; kind∈team|membership|feature|epic|story|board_state|stage_artifact else 400; story explodes/reassembles GH Story Item) · `GH_records_list` (GET /records/{kind}?since=&limit=) · `GH_records_get` (GET /records/{kind}/{syncUuid}; story reassembles arrays) · `GH_blobs_put` (POST /blobs/{kind}/{key}) · `GH_blobs_get` (GET /blobs/{kind}/{key}) · `GH_blobs_versions` (GET /blobs/{kind}/{key}/versions) · `GH_changes` (GET /changes?cursor=&limit= → `rule!GH_changesSince` + contract_version) · `GH_activity_set` (POST /activity) · `GH_activity_clear` (DELETE /activity/{kind}/{syncUuid}) · `GH_activity_list` (GET /activity/{kind}) · optional `GH_records_delete`. NOTE the path/kind/syncUuid come from `http!request.pathSegments` or the urlAlias pattern — confirm how this env maps `{kind}`/`{syncUuid}` (query param vs path segment) when building the first records API.
3. **Blob behavior (36-03)** is implemented by `GH_blobDedupAndStore`/`GH_pruneBlobVersions` (folders already exist).
4. **36-05 packaging + security:** export the Genesis Hub app as an installable package + install/upgrade runbook; document the **service-account provisioning** (MANUAL admin step — no create-user MCP tool: create the `genesis.hub.service` user, add to `GH Service Accounts`, mint its API key). Confirm allowed-origins/CSRF for the write Web APIs on Appian 26.6.
5. **The FROZEN CONTRACT (36-01 §3):** write `specs/phase-36-genesis-hub-appian-app/contract/genesis-hub-api.md` + `contract/fixtures/*.json` into project-tracker (normative request/response shapes, status codes incl. 409-CAS + 200/201-dedup bodies, pagination, auth header, `contract_version` = "1.0.0"). This is the interface Phase 37's `AppianHubProvider` codes against + the shared 36-06 test harness. **Not yet written.**
6. **36-06 contract validation** (harness vs the deployed app) → **36-07 hand-off**.

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
