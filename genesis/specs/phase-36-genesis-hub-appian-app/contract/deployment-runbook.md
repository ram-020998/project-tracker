# Genesis Hub — Deployment, Security & Upgrade Runbook (as-built)

> **Status:** ✅ WRITTEN (2026-09-05). Companion to spec `36-05-packaging-security-and-deployment.md`, reflecting
> what was actually built in the dev env (`merge-assist-dev.appianpreview.com`, Appian 26.6). The `Genesis Hub`
> app (appUuid `_a-0000f058-fed5-8000-9bfc-011c48011c48_27312`, prefix `GH`) satisfies **`contract_version =
> "1.0.0"`** (`./genesis-hub-api.md`). This runbook is the ops procedure to package, secure, deploy, and upgrade
> the Hub. Steps marked **[ADMIN]** need Appian admin/Designer access (no MCP tool automates them); steps marked
> **[GENESIS]** happen in the Genesis app (Phase 37).

---

## 0. What's in the app (packaged inventory)

- **12 record types** (DATABASE-backed on `jdbc/Appian`): the 11 contract/data-model types — GH Team, GH Membership,
  GH Feature, GH Epic, GH Story, GH Story Item, GH Board State, GH Stage Artifact, GH Blob Version, GH Change Log,
  GH Activity (13 relationships; record-level security below) — **plus `GH Blob Version Document`** (a document-management
  record type the user added to physically store/relate the blob Documents; not a contract entity).
- **11 Web APIs:** GH_meta, GH_records_upsert, GH_records_get, GH_records_list, GH_changes, GH_activity_set,
  GH_activity_clear, GH_activity_list, GH_blobs_put, GH_blobs_get, GH_blobs_versions (aliases per
  `genesis-hub-api.md` §1.1).
- **12 expression rules:** GH_isServiceCaller, GH_errorResponse, GH_appendChangeLog, GH_changesSince,
  GH_recordToJson, GH_casUpsert, GH_reassembleStoryItems, GH_queryRecords, GH_blobLatest, GH_pruneBlobVersions,
  GH_recordBlobVersion, GH_convertDocumentToBase64String.
- **2 process models:** `GH Convert Base 64 To Document` (plugin `com.nttdata.plugins.MoreDocumentTools.base64StringToDocument`
  — the base64→Appian-Document converter) **and `GH Store Blob`** (the user's blob-write model that `GH_blobs_put`
  activity-chains to create the Document + return its `documentId`). **`GH_PM_STORE_BLOB` → `GH Store Blob`** (uuid `0003f059-2a54-8000-fb95-7f0000014e7a`).
- **9 constants** (GH_GROUP_ALL_USERS/ADMINS/SERVICE, GH_CONTRACT_VERSION="1.0.0", GH_BLOB_KEEP_LAST_N=10,
  GH_FOLDER_KB_BLOBS, GH_FOLDER_ARTIFACT_BLOBS, GH_ARTIFACTS_FOLDER, GH_PM_STORE_BLOB) + **2 blob folders**
  (GH KB Blobs, GH Artifact Blobs, under GH Artifacts) + **3 groups** (GH Administrators, GH Users, GH Service Accounts).

## 1. Security model (as-built)

- **Record types:** administrator+editor = `GH Administrators`; viewer = `GH Users`; **data_steward =
  `GH Service Accounts`** (the API write authority; service accounts read via GH Users membership). Open
  visibility — no per-team row filtering this phase (`ownerUsername`/`teamUuid` stamped for a later scoping seam).
- **Web APIs:** each body asserts `GH_isServiceCaller()` (caller ∈ `GH Service Accounts`) → **401** otherwise.
  **[ADMIN]** Ensure the 11 Web API objects + the helper rules/constants/record types are visible to
  `GH Service Accounts`.
- **[ADMIN] CSRF / allowed origins:** the write verbs — **PUT** `records`, **POST** `blobs`/`activity`,
  **DELETE** `activity_clear` — must be reachable with only the `appian-api-key` header. Add the Web APIs to the
  API-key CSRF allowlist / allowed origins (Appian Admin Console → Web API security). GET endpoints are
  unaffected. (The dev-env `GH_blobs_put` test already succeeded, so the API-key path works; confirm for every
  write verb before Genesis points at a new env.)
- **Secrets:** the service-account API key never lives in `environments.json` — it rides the SecretProvider
  (ADR-048), entered in Genesis Settings → Environments (dev-tagged env) / Collaboration. Reference by key name.

## 2. Service-account provisioning **[ADMIN]** (manual — no MCP create-user tool)

1. Create the user **`genesis.hub.service`** (a service/system account) in the Appian Admin Console.
2. Add it to the **`GH Service Accounts`** group.
3. Generate its **API key** (Admin Console → API Keys → tied to the service account). This is the key every
   Genesis instance uses for all Hub calls.
4. (Recommended) Give it only Hub access — no access to subject applications beyond a normal developer.

## 3. Packaging **[ADMIN]** (Appian export — Designer/Deployment)

> There is no MCP tool to export an application package — do this in Appian Designer.

1. In Designer, open the **Genesis Hub** application → **Export** → include: the **12 record types** (+ their
   data-source/table objects; incl. `GH Blob Version Document`), the **11 Web APIs**, the **12 expression rules**,
   **both process models** (`GH Convert Base 64 To Document` + `GH Store Blob`), the **9 constants**, the **2 blob
   folders**, the **3 group references**, (optional) admin interfaces.
2. Export as a **versioned package** (`.zip`) — stamp the package name/notes with an **app version** + the
   **`contract_version` = "1.0.0"** it satisfies.
3. Store the package + this runbook + `genesis-hub-api.md` together (the deployment bundle).

## 4. Install into a new environment **[ADMIN]**

1. Import the `Genesis Hub` package into the target team's **dev environment** (the Hub env). Let the import
   create the DB tables on the Hub data source (`jdbc/Appian`), or create them first.
2. Recreate the 3 groups if not carried by the import; re-point the `GH_GROUP_*` constants + `GH_FOLDER_*`
   constants + `GH_PM_STORE_BLOB` at the imported objects.
3. Do §2 (service account + API key) in the target env.
4. Do §1 CSRF/allowed-origins for the write verbs.
5. **Smoke test** (needs the API key — see §6): `GET /meta` → `{contract_version:"1.0.0", …}`.

## 5. The blob-put wiring **[ADMIN/DEV — one code touch]**

`GH_blobs_put` has a marked placeholder `local!documentId: 0`. Before blob GET returns real bytes, wire the
**activity-chained** call to `GH Convert Base 64 To Document` (`cons!GH_PM_STORE_BLOB`) inside `GH_blobs_put`:
pass `base64String = local!b64`, `fileName = local!fileName`, `extension = "bin"`, `folder =
local!targetFolder`, and set `local!documentId = <the process's createdDocument output>`. (`a!startProcess`
alone returns a Reaction Tree, so the doc-create must be **activity-chained** in the Web API to return the id
synchronously — verified pattern.) Everything else in PUT (dedup, version, index write, changelog, prune,
200/201) is built + verified.

## 6. Request-size limit — the real 2 MB blob gate **[ADMIN]**

The base64 converter + plugin are size-linear (tested text + binary). The binding constraint on a ~2 MB KB blob
is the **Appian Web API maximum request-body size** on the target env (a platform/config limit, not a code
limit). Confirm the limit accommodates the largest expected base64 payload (a 1–2 MB gzip blob → ~1.4–2.7 MB
base64) end-to-end before relying on KB publish; raise it if needed. **Validate with a real 2 MB blob put/get in
36-06.**

## 7. Upgrade

1. **[ADMIN]** Import the newer `Genesis Hub` package version into the env; record-type/data migrations are
   handled Appian-side.
2. If the API shape changed, bump **`GH_CONTRACT_VERSION`** — Genesis's Phase-37 `/meta` check warns on a
   mismatch. Additive-only changes keep `1.0.0`; a breaking change is `2.0.0` + a new fixtures set.
3. Re-run the 36-06 round-trip harness against the upgraded env.

## 8. Genesis-side wiring **[GENESIS — Phase 37]**

Settings → Collaboration/Environments: set the Hub **base URL** (`https://<host>/suite/webapi`) + the
**service-account API key** + select the `appian` provider. **Do NOT** add the Genesis Hub app as a tracked
subject application (isolation — ADR-063/064; Phase 37 excludes its `app_uuid`).

---

## Checklist (per environment)
- [ ] Package imported; tables created; constants re-pointed.
- [ ] `genesis.hub.service` created + in `GH Service Accounts` + API key minted.
- [ ] Record-type + Web-API + rule/constant security grants confirmed for `GH Service Accounts`.
- [ ] Write verbs (PUT records, POST blobs/activity, DELETE activity_clear) on allowed origins / CSRF exempt.
- [ ] `GH_blobs_put` `documentId` wired (activity-chain).
- [ ] Web API max request-body size confirmed for ~2 MB base64.
- [ ] `GET /meta` returns `contract_version:"1.0.0"`.
- [ ] 36-06 round-trip harness green (all kinds + 2 MB blob).
