# 36-08 — Remaining work to close Phase 36

> **Status:** 🔨 OPEN — the Genesis Hub app + its **full API surface are BUILT and (blob-put) verified** in the
> dev env. This doc is the punch-list to finish Phase 36. · Part of Phase 36 (ADR-064). · **As-built + every
> UUID + the urlAlias↔path map:** `progress/phase-36-genesis-hub-appian-app.md` (READ FIRST).

## Where we are (done)
- **App / security / storage / config:** `Genesis Hub` (prefix GH, appUuid `_a-0000f058-fed5-8000-9bfc-011c48011c48_27312`) + groups (`GH Administrators`/`GH Users`/`GH Service Accounts`) + blob folders (`GH KB Blobs`/`GH Artifact Blobs`) + 7 constants (+ `GH_PM_STORE_BLOB`). 
- **Data model (36-02):** 11 record types + 13 relationships + record-level security (data_steward = `GH Service Accounts`). COMPLETE.
- **Logic + API (36-04/03):** **11 helper expression rules** + **11 Web APIs** + the **base64 blob store** (the user's `GH Convert Base 64 To Document` process + `GH_convertDocumentToBase64String`). All associated with the app. **`GH_blobs_put` verified end-to-end** (201 new + 200 content-hash dedup).

## Remaining — punch-list

### A. Finish the blob PUT wiring (Appian; user)
- In **`GH_blobs_put`** replace the marked placeholder `local!documentId: 0` with the **activity-chained** `GH_PM_STORE_BLOB` call (`GH Convert Base 64 To Document`) passing `base64String=local!b64`, `fileName=local!fileName`, `extension="bin"`, `folder=local!targetFolder`, and set `local!documentId = <the process's createdDocument>` (a!startProcess alone returns a Reaction Tree, so the doc-create must be activity-chained in the Web API to return the id synchronously). After wiring, `GET /blobs_get/...` returns the real bytes.

### B. Web-API security & access (Appian; admin)
- Grant the `GH Service Accounts` group the needed access to all 11 `GH_*` Web APIs (+ the helper rules/constants/record types they call) so the service account can invoke them.
- Confirm **CSRF / allowed origins** for the write verbs — `PUT records`, `POST blobs`, `POST activity`, `DELETE activity_clear` — are reachable with just the API-key header.
- **Service-account provisioning (MANUAL — no create-user MCP tool):** create user `genesis.hub.service`, add to `GH Service Accounts`, mint its **API key** (this is the key Genesis stores per ADR-048).

### C. The FROZEN CONTRACT + fixtures (project-tracker; the Phase-37 interface) — ✅ DONE (2026-09-05)
- ✅ `specs/phase-36-genesis-hub-appian-app/contract/genesis-hub-api.md` — per-endpoint request/response JSON, status codes (incl. **409-CAS** + **200/201-dedup**), the **auth header**, `contract_version="1.0.0"`, the **urlAlias↔path map**, datetime/encoding conventions, and the as-built shapes (transcribed from the deployed Web APIs + `GH_recordToJson`).
- ✅ `contract/fixtures/*.json` — 12 adversarial **lossless** fixtures (meta · team · membership · feature[long unicode] · epic · story[many AC / empty questions / unicode labels / null epic] · board_state · stage_artifact · conflict[409] · changes[incl. blob row] · blobs[201/200/get/versions] · activity[set/list/clear]); all validated as well-formed JSON. Shared with Phase-37 provider tests + the 36-06 harness.
- **urlAlias → contract path** (aliases can't collide, so the path is encoded in the alias; the Genesis provider maps these; trailing segments are `http!request.pathSegments`):
  `meta`(GET)→/meta · `records`(PUT)→/records/{kind}/{syncUuid} · `records_get`(GET)→/records/{kind}/{syncUuid} · `records_list`(GET)→/records/{kind} · `changes`(GET)→/changes · `activity`(POST)→/activity · `activity_clear`(DELETE)→/activity/{kind}/{syncUuid} · `activity_list`(GET)→/activity/{kind} · `blobs`(POST)→/blobs/{kind}/{key} · `blobs_get`(GET)→/blobs/{kind}/{key} · `blobs_versions`(GET)→/blobs/{kind}/{key}/versions.
- **Contract shapes to codify** (as built): upsert body = the record payload (snake_case) + `base_version`; actor = payload `modified_by`|`created_by`. Conflict → `409 {error:"conflict", current_version}`. Create → `201`, update → `200`, both `{status, version}`. Blob put body = `{base64, content_hash, published_by}` → `200 {status:"unchanged",version}` | `201 {status:"new",version}`. Blob get → `{base64, content_hash, version}`. `/changes` → `{changes:[{kind,sync_uuid,version,updated_at,published_by}], next_cursor, contract_version}`. Story upsert carries `acceptance_criteria`/`questions`/`labels` arrays (exploded to `GH Story Item`, reassembled on get/list).

### D. Packaging & deployment (36-05; me + admin)
- Export the `Genesis Hub` app as an installable package; write the install/upgrade runbook.
- Note the **Appian Web API max request-body size** on the target 26.6 env — this is the real **2 MB blob** gate (a config check, not a code limit; the converter/plugin are size-linear).

### E. Contract validation (36-06; needs the API key)
- End-to-end round-trips per kind: `PUT records/{kind}/{syncUuid}` → `GET records_get/...` → **byte-identical** (incl. story array reassembly); stale `base_version` → **409**; `GET changes` cursor paging; activity set/list/clear; a **2 MB blob** put/get (validates the request-size limit + the doc round-trip).
- Adversarial lossless fixtures from §C. This harness is shared with Phase 37.

### F. Hand-off (36-07; me)
- Commit the contract doc + fixtures into the **genesis** repo (the only genesis-repo footprint of this phase — no genesis tag).
- Update `bible/01`/`03`/`04` (ADR-064 already Accepted), `tracker.md` §6, and this progress doc to "Phase 36 COMPLETE — the Hub app + frozen contract exist"; note Phase 37 (`AppianHubProvider`) codes against the contract.

## Known small notes (as built — decide in the contract doc)
- `GH_blobs_put` stores `size` as the **base64 length** (≈ decoded × 4/3) — an indicator, not exact decoded bytes. Change to exact if the contract requires it.
- `GH_records_list` returns all records of a kind (paged, `next_cursor:null`); **incremental deltas are served via `/changes`** by design. Document this in the contract (list = full pull; changes = delta).
- `GH_pruneBlobVersions` deletes the **index rows** beyond keep-last-N; the orphaned Appian **Documents** are left (deleting Documents needs a Delete-Document smart service/process) — add a scheduled "Delete Documents Older Than" cleanup later if desired.
- Composite uniques (membership/board_state/story_item/blob_version/activity) are enforced in the Web-API logic (single-column `isUnique` only at the column level).

## Gate
All of A–F done + a green 36-06 round-trip → **Phase 36 COMPLETE**; Phase 37 wires the Genesis-side `AppianHubProvider` to this contract.
