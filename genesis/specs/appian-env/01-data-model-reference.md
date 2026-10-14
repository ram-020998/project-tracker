# 01 — Genesis Hub Data Model Reference (live, as discovered 2026-10-14)

> Source of truth for every record type, field UUID, relationship UUID and real data value the site uses.
> All UUIDs below were read from the live environment with `getRecordType` / `listRecordData` — they are
> real, not fabricated. **Re-verify with `getRecordType` before use** if this doc is older than a few days
> (Genesis may add fields; versionIds move on every edit).
>
> Reference syntax in SAIL: `'recordType!{<rtUuid>}<RT Name>.fields.{<fieldUuid>}<fieldName>'` and
> `'recordType!{<rtUuid>}<RT Name>.relationships.{<relUuid>}<relName>.fields.{<fieldUuid>}<fieldName>'`.

# Genesis Hub — schema notes (for the read-only site build)

App: Genesis Hub, prefix GH, appUuid `_a-0000f058-fed5-8000-9bfc-011c48011c48_27312`
Env: merge-assist-dev.appianpreview.com (26.6)
Rules folder: GH Rules and Constants `_a-0000f058-fed5-8000-9bfc-011c48011c48_27319`
Groups: GH Administrators `_e-0000f058-fe86-8000-9b49-01075c01075c_458`, GH Users `..._460`, GH Service Accounts `..._462`
Existing site: none. Existing interface: GH_BlobVersionDocumentSummary `039a0d60-0183-435c-b032-7846a918f660`

All joins are on syncUuid (TEXT). Attribution fields are TEXT usernames (no USER fields).

## GH Feature `5ff1c823-0ff9-4a59-943b-3314aad3b6f7`
id 9f637632-4ec7-4b53-b6bd-9e1454e83205 | syncUuid ce089835-d693-4351-a707-b0b25bd28ead | appUuid c95aa5b6-b29d-4a90-984b-6e75b04fb594
name 05b2cf90-de64-454e-a30d-ab2790d559a8 | description fc100a24-747c-4472-ae15-5a8131a9d6b7 (XL) | ownerUsername 152062ec-f96a-4b84-9bd0-fdea7998f1e7
teamUuid 780757b2-ed89-4067-8d40-8249014c0918 | version 3a7c9959-69b2-49c7-a445-ed08871f3d1d | createdBy ae7d033c-8ec5-4ded-8d21-c67c548a3e41
modifiedBy 7dbdc95c-41cc-4a66-9bf7-4c447daa892c | createdAt 06818ef3-58f8-4fcb-baa1-5b5220515dec | updatedAt dfea561a-2168-445f-ad4a-8a7f0cd8fc95
rels: epics 0de75fc3-6aa6-46ba-81d0-60962bc28bdb (1:N), stories c1588523-ac34-425c-825e-2cac84c71374 (1:N), stageArtifacts 54cfd090-1809-465f-8eb4-c94b3e4c77da (1:N)

## GH Story `31c5187d-3c6f-467a-be02-d4549d98a822`
id e539301b-5f9e-4c5a-8086-5e3add2cb38b | syncUuid 0ebb514f-fd0f-49f7-88ec-a933813858be | featureSyncUuid b874e119-e3dc-4e51-a872-7ff9ac869120
epicSyncUuid fbdc2e78-2169-4b03-8000-a66baac4e1bd | backlogKey 89fb1002-38f3-4ac0-9671-66779772da4f (GNS_ id lives here) | title e64b3bd3-6068-45e2-ba6a-0130faf7db4b
storyType a30ed75e-14ee-40f2-bd07-b8ac3cf85087 | category 6397d10e-7b6b-43e0-a362-6c44e4e02c6b | appianPart 28d96640-0e9f-4a6a-9a69-0068df4e80e7
description 7a7226bb-6f76-4add-a5eb-3b99579ad446 (XL) | devNoteRef 24ec7d30-03de-4579-b247-ca7a1e5bc044 | status 17bdfabd-8707-457e-98e1-e4a96cdb73fd
position 176ae0b5-b95a-4d33-9561-a50877149b64 | ownerUsername 801ae4a3-f1f7-4629-b32b-9a32a7f3576c | teamUuid b6f2e2ee-b001-436e-8a85-68d756275bc0
version 23dcbd62-723d-4ed1-bfa5-5c941d3a0c66 | onBoard 8b5104c6-e8e7-49f9-b8ad-c20bdfa3f6a0 (BOOL) | createdBy 9d8ccc6b-336c-470c-91c5-b33e65b13377
modifiedBy 76f76460-5d59-4b2d-846c-170997a4523d | createdAt 80403c59-90e1-4cf8-b498-7fe54e34809a | updatedAt 09b91765-84f9-4807-841b-b1c625fef74e
rels: feature 3afd6eaf-cec8-43f9-9d46-75279fcd0dd2 (N:1), epic 151d5a24-3fdb-46dc-a9de-ecc186c4a903 (N:1),
      storyItems 9dcd602e-5139-46b8-9a6a-627ff2f69c2d (1:N), stageArtifacts aae1d96c-aea9-4e12-9838-316043cff750 (1:N)

## GH Epic `f023ee8d-e941-4554-b6b1-a8689c9cd6f4`
id 6f79ad1a-3e28-4c2b-86ac-5fd2e668b5c6 | syncUuid db39730a-34eb-47a4-8d1e-d611e390614e | featureSyncUuid f8958879-85de-4491-b00b-d8163b27fa16
backlogKey 7baf564c-a844-41d8-9b6b-4e8234933493 | title 0952db4c-fc14-4fb0-9e13-729a025ad8b8 | description f9b46466-4a6d-418d-8ce1-f59c5c6c34b4 (XL)
workstream 753d8f2a-2918-4903-97a5-aba2c9295c54 | position 99439414-20f6-4122-8a77-8dbffe40571b | version eb31d4c5-104a-416e-8b53-c7d58c464968
createdBy d93a657f-7e4d-47c7-a81d-78aa34f81953 | modifiedBy fb5f67b6-7f4f-466a-948c-b4bc2f606638 | createdAt 95d06514-fa23-4e62-a3d8-ccab65f48b0c | updatedAt 71891a90-fa1b-4612-bee7-925ee68797a1
rels: feature dc2a1283-8512-454f-8672-d6cd02151532 (N:1), stories f22a692e-92b9-4197-88b0-cffcb6e6220c (1:N)

## GH Story Item `556f67aa-34fe-42b1-a67e-76a67f770b84`
id f9e92a74-9b10-4d0d-a888-0d041b265f0f | syncUuid de9521ee-5bd4-4ff2-9c09-92ed74177a79 | storySyncUuid 0c51b86d-ca5c-4631-9211-065a1cc0ae19
itemType d8bcdbcd-8337-4bce-9297-1f20489521f6 | text b025a024-7026-4f1b-a593-d95808226840 (XL) | position 117fc24f-02da-4e1e-9541-dc927d09e528
version 6edcb75e-3a5d-4a7a-b22f-4f106abf03b1 | createdAt 2cd5e3af-fe8a-4f9d-bb4f-1e6e4c286a71 | updatedAt 63835405-121b-4465-80e6-59955e6033f5
rels: story 83aa53bb-39e5-452f-9799-316ddf099037 (N:1)

## GH Stage Artifact `90a731eb-86ba-4d04-baa0-dd4b760fb121`
id 0a6ebbbc-c35a-4241-8cf5-bf82c2d657f7 | syncUuid bafef139-13c0-48af-94c2-a05ae28f63ce | parentSyncUuid f0f2b44b-500b-4c44-bbf2-db30be525a03
parentKind 9ba8d236-a79e-44d4-9077-64a065815a70 | stage d1f2076a-919f-4ce0-a5ef-3cb5dc030a01 | status 8c7df8f5-d076-49d6-a810-a82790dff889
contentHash 236db236-70fe-402d-8fdd-221756f82d86 | blobKey a7610220-295b-4fb3-a556-4e9ad7e3d685 | upstreamVersions ae3c482a-e065-4984-89d9-ff6fd147e0ff
publishedBy 639cd13f-e5bf-4969-8bd4-58225cfd54da | publishedAt b8e876e3-7a34-4b60-9541-a071f201ecf3 | version a034273b-4373-4c00-8137-a742bf50eda2
createdAt e686f103-b087-421e-80fa-ddd83354e502 | updatedAt 4d3b5d05-bb85-4f4b-bc8e-1b5fe270e789
rels: parentFeature 05e474cc-4eb6-49d3-807d-bd50c6546496 (N:1), parentStory 40ef52cd-bb99-4828-984f-0241a757b684 (N:1)

## GH Object Wiki Page `29ede62a-36af-4980-9019-2c651727e0d9` (table wiki_object_pages)
id 754a49b7-bcd7-4c69-9993-5e8a3e665e78 | syncUuid 220cae5f-065e-47e1-9e27-263de3a3b369 | appUuid 62404209-154c-4753-86c5-72ec73259e31
objectUuid 77e4ae91-0453-43b3-85e3-7b8fed4d34a6 | objectType 62330d54-e6f9-41a3-bfc5-9aaace6292e6 | objectName 30a2b685-b344-4fba-acc5-5a441ca3d2a3
currentSummary ed6f0e50-3559-4d53-85f0-6cfcc08b914b (4000) | ownerUsername ba9fcdc7-0723-4070-94d9-d8b3ac7fe353 | teamUuid 33b40d39-7cc9-438d-8ce1-bc0e2fe94a18
version bf209cbf-0f53-4aa1-90fb-bdf3fb75d2af | createdBy de6dbe6f-f20c-479c-bbe5-905197af8c63 | modifiedBy 371bb8d0-6e34-42c0-8296-72c8bb10f639
createdAt 081241c6-0d9f-4c8c-bded-8d10ec226fe2 | updatedAt f720e2a5-b70a-4dda-8461-053bcd685351
rels: entries f29672c9-7778-498a-8041-1ae3e193c4b1 (1:N)

## GH Object Wiki Entry `c9a367bb-fbd0-4ca6-8c84-6358dee73cb5` (table wiki_object_entries)
id bcf46c35-bf72-4f9e-b468-3672845dc247 | syncUuid 5d4ea9eb-f2ad-4e56-952c-5c0d965461f9 | pageSyncUuid 70e53c07-6477-4e0d-bbdf-7a2c8b8cc617
parentKind a945b2b4-8fd1-462b-b04c-4a9b98b675ec | changeKind b9233134-9d03-4dc8-927b-aaf76b88c3a4 | businessDescription 99f75cf0-aaad-4b65-9ef4-b678bde4ef51 (XL)
technicalDescription 4c6670c2-197b-46c9-acbb-2ffea4098993 (XL) | storyKey 74f3193a-1b51-4b12-98a3-93999db708dc | storySyncUuid 4f6a6c3f-d2d7-4b21-9d1a-f4dfa3b47487
isBugfix 7d378fee-f9a5-4f30-b607-976acbc90e78 (INT) | changeReason ec1fbe30-8c97-490f-9a2c-2fc6692d7046 | objectVersion fee2c99e-06b3-4423-83a1-72323702318a
authorUsername 570b0009-15bb-4b13-8635-5b53e2162baa | createdAt d747118d-793d-4b3e-b6f3-a34723a7c538 | version 8bcec6d7-d318-4e78-91fd-0b8f62c8d0fe
publishedBy f88c1728-3c8b-46fb-9113-b74f17d3df20 | publishedAt ade17967-a0c8-43c0-ae4b-963c2134c29f | updatedAt b7092a0e-9ffd-4f86-aeab-ba1db8ebb63c
rels: page 88f29644-0824-4892-b07b-15466eba1b9f (N:1)  [NOTE: no relationship to GH Story — join on storySyncUuid manually]

## GH Board State `cd472522-5be5-4129-bd74-fce457f6cd08`
id 472073f7-d280-4180-96d6-5260ab638c8b | syncUuid 4cc1cf5e-f22e-4d49-b854-07829c1beb11 | appUuid 323886ba-7e50-4674-9ca1-8ca05de5a459
storySyncUuid ee60e530-bd9b-41e6-b970-6a448119aabc | status 3fc739de-9557-4e69-bc57-6232ce7ad777 | version 8c8b2b2e-e9ca-42ac-8a0c-7ca95100b557
modifiedBy 1b33546e-5efc-46b5-afbd-1953fe0ee546 | updatedAt 24222011-eaf7-4fa2-97f9-660a9988f0b6
rels: NONE (lane is also on GH Story.status)

## GH Team `44b219ed-5d19-4192-90bd-8b8e31431f95`
id d3b054ba-db4f-4639-84b0-7b410119a773 | syncUuid 1d745740-0da2-48bd-89e5-9f32a69cc569 | title 78d54241-bd20-4bb8-8b20-f4db889e8d19
version 56bcc0d9-9ed0-4d83-92c5-c7fbbae86a36 | createdBy d77599b2-31d6-4522-b3dc-ecb45fe9034c | createdAt 5841ca5b-1753-4306-b2ed-eafb3742780d | updatedAt daee6542-543d-4131-9c6d-dc4889ca582f
rels: memberships 765cb6a2-120a-4bbd-b416-a6eecd462abc (1:N)

## GH Membership `d35b1075-8d40-428b-a266-3b84f56075b5`
id f7d5d32c-4b03-435e-9379-4065cc53144f | syncUuid 156c9424-563b-43ca-a832-90ad263e6260 | teamUuid b5f78dec-e663-4a32-8722-a9e0eb6addd6
username 902db2ff-0560-4273-ad48-c49ef7204ad2 | name f728a606-fcad-40ec-ad71-438a61f39b20 | email efc742b3-e537-416c-9417-ac1e14436702
joinedAt 324cce50-e527-4931-9cb8-450df8a88139 | version 7cec5b9a-7226-4f3b-b8bd-13ff2dfc9897
rels: team 72daf94f-f430-4691-848d-cc3c310c731f (N:1)

## GH Change Log `ff9c6698-dd22-4e5a-a457-c188da1a49e4`
id cb086be9-928d-4029-9b8b-22200bf3589e | kind 40f98808-f300-4da7-9473-6e6ad6c2f43a | syncUuid 58ba4ecd-1e4d-4588-87f5-8f4ebb80d4a7
version a4d66c3c-00d4-463b-8153-1f8b96411e97 | updatedAt d2cdd33d-ce61-4c1a-8328-d01c7171fd98 | publishedBy ac77d49d-b26d-4b0d-8f0b-61fdc86a8640
rels: none

## GH Blob Version `c6368222-fe1f-4b0e-9e34-8dd43ce82fe4`
id 13729b74-26e5-4ff2-b9ae-55a380449701 | blobKind 97a68d6d-15c9-4565-bf1b-adf1e9876fa4 | blobKey 5fdb9b7c-d537-4853-bc1b-6a470e21099e
version 99baf0e5-c231-41e3-a4e8-4ca712da5d57 | contentHash edb0213f-e25e-4848-ae6e-eab7fdaf0b23 | documentId b53e799f-d098-49ff-a0b7-5578049bbc05 (DOCUMENT)
size 4c1fcdb9-0ec1-4889-b9b6-bd2c5c97c29c | publishedBy e34bfeb5-5e13-4c1f-8fad-4c41d123d878 | createdAt b3d6eda2-0541-49db-b338-477164adc008
rels: blobVersionDocuments 49b6d512-d6b1-441c-88ef-a58d08c9a145 (1:N), documentProperties 9ea42be3-767a-47fa-befe-b69311102d13 (N:1 SYSTEM_RECORD_TYPE_DOCUMENT)

## GH Activity `c8b98356-4de5-4a67-bcfc-5520f54c2a99`
id 124db86f-842f-47da-800f-2f2e86b5afe3 | kind 2a27811a-f52a-48c8-ae77-1eb9952cb92c | syncUuid 9e503975-d121-4211-8a88-6af0e7d41b1d
username be2b028a-70b4-4a7e-9543-22e7cdbea6fe | setAt 7df5a3ef-32db-4e9e-8aca-026f532a3b2c | expiresAt 34269471-38b0-40aa-9286-2d8ba896d665

## GH Blob Version Document `cc2dcf51-bea2-4432-baad-1d88777b5d2a` (auto-generated doc helper RT; skip)


---

## A. Relationships ADDED by this feature (2026-10-14, already live — sub-spec 02 is DONE)

| On record type | Relationship | Type | UUID | Join |
|---|---|---|---|---|
| GH Object Wiki Entry (`c9a367bb-…`) | `story` | MANY_TO_ONE → GH Story | `5e33bdce-5007-4bb9-807a-c099712088cf` | `storySyncUuid` (4f6a6c3f…) → GH Story `syncUuid` (0ebb514f…) |
| GH Story (`31c5187d-…`) | `wikiEntries` | ONE_TO_MANY → GH Object Wiki Entry | `b79fea99-9d9d-4906-bc24-aa010a822fc4` | GH Story `syncUuid` → entry `storySyncUuid` |

- versionIds after the change: GH Object Wiki Entry **5**, GH Story **8**.
- ⚠️ `wikiEntries` was requested `NON_CASCADING` but the server stored **`CASCADING`** (the tool has no
  updateBehavior field). Cascading only matters when a `a!writeRecords` includes related wiki entries in the
  write payload; the Hub Web API (`GH_casUpsert`) writes stories without related data, so it is harmless.
  If you want it NON_CASCADING, change it in Appian Designer (manual step) — do not delete/recreate.
- These are read-side additions only. They do not change the Hub JSON contract (ADR-064) or any Web API.

## B. Other relationships the site relies on (pre-existing)

- Feature → `epics` (1:N) `0de75fc3-6aa6-46ba-81d0-60962bc28bdb`, `stories` (1:N) `c1588523-ac34-425c-825e-2cac84c71374`, `stageArtifacts` (1:N) `54cfd090-1809-465f-8eb4-c94b3e4c77da`
- Epic → `feature` (N:1) `dc2a1283-8512-454f-8672-d6cd02151532`, `stories` (1:N) `f22a692e-92b9-4197-88b0-cffcb6e6220c`
- Story → `feature` (N:1) `3afd6eaf-cec8-43f9-9d46-75279fcd0dd2`, `epic` (N:1) `151d5a24-3fdb-46dc-a9de-ecc186c4a903`, `storyItems` (1:N) `9dcd602e-5139-46b8-9a6a-627ff2f69c2d`, `stageArtifacts` (1:N) `aae1d96c-aea9-4e12-9838-316043cff750`, `wikiEntries` (new, above)
- Story Item → `story` (N:1) `83aa53bb-39e5-452f-9799-316ddf099037`
- Stage Artifact → `parentFeature` (N:1) `05e474cc-4eb6-49d3-807d-bd50c6546496`, `parentStory` (N:1) `40ef52cd-bb99-4828-984f-0241a757b684`
- Wiki Page → `entries` (1:N) `f29672c9-7778-498a-8041-1ae3e193c4b1`; Wiki Entry → `page` (N:1) `88f29644-0824-4892-b07b-15466eba1b9f`
- Team → `memberships` (1:N) `765cb6a2-120a-4bbd-b416-a6eecd462abc`; Membership → `team` (N:1) `72daf94f-f430-4691-848d-cc3c310c731f`
- Blob Version → `documentProperties` (N:1 SYSTEM_RECORD_TYPE_DOCUMENT) `9ea42be3-767a-47fa-befe-b69311102d13`
- **No relationships** on: GH Board State, GH Change Log, GH Activity, and between GH Feature/Wiki Page and an
  "application" (there is no application record type — group by the `appUuid` TEXT field).
- **No relationship** Blob Version ↔ Stage Artifact: join manually — Stage Artifact `blobKey` = Blob Version `blobKey`
  (blob_kind='artifact'), take the highest `version`.

## C. Real data snapshot (2026-10-14) — volumes + observed values

| Record type | Rows (approx) | Notes |
|---|---|---|
| GH Feature | 2 | "Multi Round Evaluations" (sync `af85cc2e-8bd6-4880-b285-d8588e8cd9ef`), "Document Builder" (sync `5f1fcae1-a501-4eb3-bc1c-8a6eb6dee400`). Both appUuid `_a-0000e5bc-4a9a-8000-9bbc-011c48011c48_930416`. description/owner/team often blank. createdBy=`service`. |
| GH Epic | ~21 | backlogKey `epic-N`, title, description, `position` (order), workstream often blank. |
| GH Story | ~101+ (offset 100 returned id 101) | backlogKey e.g. `story-3-1` (newer stories may carry `GNS_000123` — ADR-072 stores it here). storyType `Story`/`Task`. category e.g. `core`. appianPart `form`/`data-model`/`process-model`/… . description = "As a … / I want … / So that …" with `\n` newlines. devNoteRef = "See Technical Design → …". status = lane (`to-do`, `done`, …). onBoard boolean (often null). |
| GH Story Item | ~400 | itemType observed: `question`, `label`; acceptance criteria are expected as another itemType (likely `acceptance_criteria` / `ac`) — **VERIFY the exact value** with `listRecordData` paging before coding the filter. syncUuid pattern `<storySync>:<itemType>:<n>`. `position` = order. AC text is Gherkin (Given/When/Then). |
| GH Stage Artifact | 5 | parentKind `feature`; stage ∈ `spec`,`ux_design`,`technical_design`,`breakdown`; status `completed` (also possible: `draft`,`in-progress`,`in-review`). One row (id 5) is a test row whose parentSyncUuid is a field UUID — leave it (user: do not filter). `upstreamVersions` is JSON text e.g. `{"spec":3,"ux_design":2}`. publishedBy e.g. `admin.user`. |
| GH Blob Version | ~10+ | blobKind `artifact` (blobKey = `<featureSync>:<stage>` or a stage syncUuid) or `kb` (blobKey = appUuid, plus test keys like `test-blob-1`, `val-blob-…`). `documentId` is a DOCUMENT (Appian doc id e.g. 5242). size in bytes (KB snapshots ~2.9 MB). |
| GH Object Wiki Page | ~10 | objectType values are **inconsistent** (`Record Type`, `record_type`, `recordData`, `constant`, …) → normalize with a helper rule (sub-spec 03). objectName, currentSummary (≤4000), version. |
| GH Object Wiki Entry | ~10–15 | changeKind `created`/`updated`/`deprecated`. businessDescription + technicalDescription (Extra Long). storyKey e.g. `story-1-1`, storySyncUuid. isBugfix INTEGER 0/1. changeReason, objectVersion (text), authorUsername, createdAt. |
| GH Board State | ~100 | duplicates Story.status per story (appUuid, storySyncUuid, status). Prefer GH Story.status; Board State not needed. |
| GH Team / Membership | 1 / 2 | Team "Source Selection" (sync `abc73d15-bad5-434c-b6f2-5f1f84e4f6ac`). Members `admin.user` (Ramaswamy), `king.arthur` (King Arthur). Emails are free text (may be odd values) — show as-is. |
| GH Change Log | many | kind (feature/epic/story/stage_artifact/board_state/wiki_page/wiki_entry/blob/…), syncUuid, version, updatedAt, publishedBy. id is monotonic → "Recent activity" feed. |
| GH Activity | 0 | Empty (TTL advisory markers). Optional "In progress now" widget only if non-empty. |

## D. Gotchas to respect

1. **Usernames are TEXT, not USER fields** (service-account writes; payload attribution). Do not use `a!userRecordLink`
   on them unless the username exists; display as text (optionally `user(u,"firstName")` guarded by a null check
   AND an existence check — a non-existent username errors in `user()`; safest: display raw username).
2. **App names are not stored** — user decision (2026-10-14): **show the app UUID** (a short form + full UUID in tooltip).
3. **Do not filter test/validation rows** — user decision: show data as-is.
4. Datetimes are stored UTC; display with `text(x, "MMM d, yyyy h:mm a")` (the viewer's timezone applies).
5. `GH Blob Version Document` (`cc2dcf51-…`) is a generated doc-helper record type — ignore.
6. Existing record-type list columns exist on Story / Blob Version / Wiki types — do not change them (Designer convenience).
7. Record-level security already grants **viewer = GH Users** on the Hub record types (Phase 36), so site queries work
   for GH Users members. Verify once with a non-admin GH Users member after the site is built.
