# Phase 36 — The Genesis Hub Appian Application (the shared backend + its frozen contract)

> **Status:** 🟡 **SPECS DRAFTED (2026-09-05)** — awaiting user sign-off to build. **ADR-064 Proposed.** Umbrella + `phase-36-genesis-hub-appian-app/36-01..36-07`. · **Author:** Genesis agent
> **Type:** **Appian-side build — NOT a Genesis-repo change.** The Genesis Hub is an **Appian application** built **by a separate agent that has a write-capable Dev MCP** (NOT by Genesis, which stays read-only against Appian per ADR-036/037). Deliverable = an **installable Appian application package** + a **frozen HTTP/JSON API contract** that Phase 37's Genesis-side `SyncProvider` codes against. The only artifact that may land in the **genesis** repo is a checked-in **contract document** (+ optionally a typed client stub) — no runtime Appian writes from Genesis. · **Depends on:** Phase 35 (the `SyncProvider` Protocol + `CollaborationService` + the entity/`sync_uuid`/provenance model + the identity/team model — this Appian app is the concrete server those talk to; ADR-063), ADR-048 (the per-environment Appian credentials Genesis will authenticate the Hub with), the researched Appian capabilities (Web APIs returning JSON; RDBMS/service-backed record types; document-management record types with version history; Smart Search).
>
> **Second of four phases** (35 Foundations & Identity → **36 the Genesis Hub Appian application** → 37 Hub wire-up → 38 Collaborative SDLC). This phase can proceed **in parallel** with Phase 35 once 35-01 locks the entity/contract model; Phase 37 depends on **both**.

---

## 1. Why this phase exists

Phase 35 builds the Genesis-side collaboration substrate against a **local/mock** Hub provider. For a real team,
the Hub must be a **real, shared, network-reachable backend**. The locked decision (2026-09-05) is that the Hub
**is the team's Appian dev environment** — the same environment Genesis already syncs from — hosting a
dedicated **"Genesis Hub" Appian application**: record types for the shared entities, a document store for the
KB blobs + published stage-artifact bytes, and **Web APIs** that Genesis calls to publish/pull. Appian is the
right backend for this team because it is **already there** (no new infrastructure to host/secure/back up), the
team are Appian engineers who can build + maintain it, it provides **document versioning** and **AI Smart
Search** natively, and a **shared service account** + record-level structure give a clean write/attribution model.

Because Genesis is **read-only against Appian** (ADR-036/037), Genesis does **not** build this app. A **separate
agent with a write-capable Dev MCP** builds it from this spec. This phase's job is therefore to specify the
Appian application **precisely enough to be built by that agent** and to **freeze the HTTP/JSON contract** so
Phase 37's Genesis-side provider can be written against a stable target.

---

## 2. Goal

1. **A dedicated "Genesis Hub" Appian application**, **isolated** from the customer applications Genesis
   analyzes (its own app, its own record types + data store) so a KB re-sync / deployment / `untrack` of a
   subject app never touches Hub data — and so Genesis's own parser **never treats the Hub app as a subject
   app** (an exclusion rule Phase 37 honors).
2. **Record types for the shared entities**, UUID-keyed (matching Phase 35's `sync_uuid`), with attribution +
   owner/team tags + a per-record **version**: **Team**, **Membership**, **Feature**, **Epic**, **Story**,
   **BoardState** (a story's lane/status on an app's board), and **StageArtifact metadata** (per-`(entity,
   stage)`: status, content hash, blob reference, provenance, consumed-upstream-versions).
3. **A document/blob store** using **Appian Documents (native version history) indexed by a `GH Blob Version`
   record type**: the gzipped **KB blobs** (one per app, versioned, content-hash-deduped, keep-last-N) and the
   published **stage-artifact bytes** (spec/UX/TD/breakdown/design HTML), with **version history**.
4. **The Web API surface** Genesis calls: per-entity **upsert (with base-version CAS)** + **list/get**, a
   **change-manifest / `changes_since(cursor)`** feed, **blob upload/download + list-versions**, **advisory-lock
   markers** (set/clear/list "in-progress by X"), and **teams/membership** CRUD — all JSON, authenticated by the
   **shared service-account** (API key), attribution taken from the **payload** (`created_by`/`modified_by`).
5. **Security + packaging:** the service account + its permissions; allowed-origins/CSRF for the write APIs; and
   an **installable Appian package** a team deploys into their dev environment, with a documented install/upgrade
   procedure.
6. **A frozen API contract** (request/response shapes, status codes incl. the **409 version-conflict** that maps
   to Phase 35's `HubConflict`, pagination, auth header) checked into the **genesis** repo as the authoritative
   reference Phase 37 implements against — plus a **contract-test harness** so the Genesis provider and the
   Appian app can be validated against the same fixtures.

**Success = a separate Dev-MCP agent, following these sub-specs, produces an installable Genesis Hub Appian
application whose Web APIs satisfy the frozen contract; a team can deploy it into their dev environment; and
Phase 37's Genesis `SyncProvider` can publish/pull every shared entity + blob against it exactly as it does
against the Phase-35 local provider.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-05)

1. **The Hub = the team's Appian dev environment** (no separate Hub environment); the Genesis Hub is a
   **dedicated Appian application** inside it, isolated from subject apps.
2. **Built by a separate agent with a write-capable Dev MCP — NOT by Genesis.** Genesis stays read-only against
   Appian (ADR-036/037). These sub-specs are the build instructions + the frozen contract for that agent.
3. **A shared service account** performs all Hub writes; **attribution is carried in the payload**
   (`created_by`/`modified_by` = the acting Genesis user's canonical Appian username), not derived from Appian
   auth. (Spoofing hardening parked — §Phase 35.)
4. **UUID-keyed records** (client-generated `sync_uuid` from Genesis) + a per-record **version** for the
   optimistic-CAS the Genesis side already models (`row_version`); a stale upsert returns **409**.
5. **Open visibility** for now — records carry `owner_username` + `team_uuid` **tags** but the APIs do not
   enforce per-team filtering yet (a future seam).
6. **KB + artifacts are blobs** (Appian Documents + a `GH Blob Version` index; native versioning + content-hash
   dedup + keep-last-N), **not** normalized records — Genesis queries its own local KB (the "materialized read
   cache" decision); the Hub only stores/serves the blob.
7. **Shared memory is out of scope** (deferred future phase) — no memory record types this phase.

---

## 4. Current state (what we build on)

- **Phase 35 defines the client contract** the Appian app must satisfy: the `SyncProvider` operations
  (`put_record`/`get_record`/`list_records` with base-version CAS; `put_blob`/`get_blob`/`list_blob_versions`
  with content-hash dedup; `changes_since(cursor)`; `set/clear/list_activity`; team/membership) and the entity
  payloads (`sync_uuid` + fields + `owner_username`/`team_uuid`/`published_by`/version + `upstream_versions`).
  **This Appian app is the server for exactly those operations.**
- **Appian capabilities (researched, 2026-09-05):** **Web APIs** expose custom JSON/REST endpoints (POST/PUT/
  DELETE with allowed-origins/CSRF handling), authenticated by API key / service account; **RDBMS-backed record
  types** (via a Data Store) hold structured data with relationships + record-level fields; **document-management
  record types** manage documents with **version history**; **Smart Search** provides AI semantic search across
  the data fabric incl. text fields + attached documents (a future enrichment, not required by the contract).
- **Genesis already authenticates to the env** (`APPIAN_API_KEY` + `LCP_*` per-env creds, ADR-048) — the Hub
  service-account credential rides on that store (Phase 37 wires it).
- **The isolation rule** (Phase 33/34 pattern): Genesis's parser/`untrack`/refresh operate per subject
  `app_uuid`; the Genesis Hub app must be a **distinct application** that Genesis's Applications surface simply
  never adds as a tracked subject app (Phase 37 enforces the exclusion).

**Takeaway:** this phase produces an Appian application (record types + a document/blob store + Web APIs +
service account + package) + a frozen JSON contract in the genesis repo. **No genesis runtime change** (the
provider that calls it is Phase 37). The only genesis-repo artifact here is the contract doc (+ optional client
stub + contract fixtures).

---

## 5. Record & document model — full inventory + field tables in 36-01

The Hub is a full Appian application. **36-01 is the master build reference** — it names **every object** (the
`Genesis Hub` app + groups + service account + folders + constants + **11 record types** + relationships +
helper expression rules + **~12 Web APIs**) in **dependency order**, with **complete field tables**, and the
Appian-skill conventions the building agent must follow (PK `id` Integer; `sync_uuid` unique; relationships both
sides; no USER fields — attribution is Text; sourced UUIDs). Summary (full detail in 36-01 §2):

- **Shared entities** (UUID-keyed; each carries `syncUuid` unique + `version` + `createdBy`/`modifiedBy`/
  `createdAt`/`updatedAt`; top-level ones also `ownerUsername`/`teamUuid`): **GH Team**, **GH Membership**,
  **GH Feature**, **GH Epic**, **GH Story**, **GH Board State** (`app_uuid`, `story_sync_uuid`, `status` — lane
  only; in-lane ordering NOT stored), **GH Stage Artifact** (metadata: stage/status/`content_hash`/`blob_key`/
  `upstream_versions`/provenance).
- **Blob store** (36-03): the bytes are **Appian Documents** (native version history) in `GH KB Blobs` /
  `GH Artifact Blobs` folders, **indexed** by the **GH Blob Version** record type (`blob_kind`, `blob_key`,
  `version`, `content_hash`, `document_id`, `size`, `published_by`) — content-hash dedup + keep-last-N.
- **Machinery record types:** **GH Change Log** (the append-only manifest feed — `id` = the `/changes` cursor)
  and **GH Activity** (advisory "in-progress by X" markers with a TTL).
- **Text sizing (Appian synced record types):** three sizes — `Text` (255) / `Long Text` (4000) / `Extra Long
  Text` (64000, max 3 per record type). Large content (the KB blob + artifact HTML) is stored as **Appian
  Documents** (unaffected); genuinely-long free text (`description`, `GH Story Item.text`) uses **`Extra Long
  Text`**; a story's variable-length lists (`acceptance_criteria`/`questions`/`labels`) are **normalized into a
  child record type `GH Story Item`** (variable-*count*, so normalization is the right model). **The Genesis-side
  local model is NOT changed** (SQLite keeps its JSON columns) — the sync payload carries arrays/full text, and
  the Web API explodes/reassembles them (36-01 §2.5b / 36-04). Nothing truncates (§2.0).
- **Attribution is Text** (`created_by`/`modified_by`/`owner_username`/`published_by` = the caller's canonical
  username from the request payload; the actual Appian writer is the shared service account) — **no USER
  fields**.

---

## 6. Web API surface — finalized in 36-01/36-04

All JSON, service-account-authenticated, `/genesis-hub/...` (exact base per Appian Web API conventions):

- `GET  /meta` — `{contract_version, server_time}` (health + version check).
- `PUT  /records/{kind}/{sync_uuid}` — upsert with `base_version` → **409** on version conflict. `kind` ∈
  {team, membership, feature, epic, story, board_state, stage_artifact} — **team + membership are ordinary
  `records` kinds** (no dedicated `/teams` endpoints; Genesis's `upsert_team`/`list_teams` map here).
- `GET  /records/{kind}` (list; pagination + `?since=`) · `GET /records/{kind}/{sync_uuid}` (get).
- `POST /blobs/{kind}/{key}` — upload a blob version (content-hash dedup → no-op if identical) ·
  `GET /blobs/{kind}/{key}` (latest) · `GET /blobs/{kind}/{key}/versions`.
- `GET  /changes?cursor=` — the change manifest (`[{kind, sync_uuid, version, updated_at, published_by}]`,
  `next_cursor`, `contract_version`).
- `POST /activity` / `DELETE /activity/{kind}/{sync_uuid}` / `GET /activity/{kind}` — advisory markers (TTL).

Contract details (status codes, error shapes, the 409↔`HubConflict` mapping, auth header, pagination) are
frozen in **36-01 §3** and checked into genesis as the reference for 37.

---

## 7. ADR

- **ADR-064 (PROPOSED — this phase): The Genesis Hub Appian application + its frozen API contract.** The shared
  Collaboration Hub (ADR-063) is realized as a **dedicated Appian application** in the team's dev environment,
  **built by a separate write-capable Dev-MCP agent** (not by read-only Genesis), exposing **Web APIs** over
  **UUID-keyed record types** (Team/Membership/Feature/Epic/Story/BoardState/StageArtifact-metadata) + **document-
  management record types** for the versioned **KB + artifact blobs** (content-hash dedup, keep-last-N). Writes go
  through a **shared service account**; **attribution is payload-carried**; concurrency is **base-version CAS →
  409** (mapping to ADR-063's `HubConflict`); **visibility is open** (owner/`team_uuid` tags, unenforced). The
  app is **isolated** from subject applications (never parsed by Genesis). A **frozen JSON contract** (+ contract
  fixtures) checked into genesis is the authoritative interface Phase 37 implements. Realizes ADR-063; reuses
  ADR-048 (service-account creds). Mirror in `bible/04` on Accept. **Note:** this ADR governs an Appian-side
  artifact; the genesis-repo footprint is the contract doc only.

---

## 8. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **36-01** | App architecture, **frozen API contract** & **ADR-064** | The full record/document model + the Web-API contract (shapes, status codes, 409 CAS, pagination, auth) frozen + checked into genesis (`specs/.../contract/` or a `reference/` doc) + contract fixtures; the isolation rule; **draft ADR-064.** **Docs only.** | ⭐ user sign-off → build |
| **36-02** | Record types & data model | The Dev-MCP agent builds the Team/Membership/Feature/Epic/Story/BoardState/StageArtifact-metadata record types (UUID keys, version, attribution/owner/team fields, relationships) on the RDBMS data source. | contract-conformant |
| **36-03** | Documents & blob store | Appian **Documents** (native versioning) in the KB/Artifact blob folders + the **`GH Blob Version`** index (content-hash dedup; keep-last-N retention). | contract-conformant |
| **36-04** | Web APIs | The JSON endpoints per §6 (records upsert/list/get + CAS/409; blobs up/down/versions; changes manifest; activity; teams/memberships), service-account auth, allowed-origins/CSRF. | contract-conformant |
| **36-05** | Packaging, security & deployment | The service account + permissions; the installable Appian **package** (export) + a documented install/upgrade procedure into a team's dev env; the isolation guidance. | deployable |
| **36-06** | Contract validation & review | Run the shared **contract-test harness** (the 36-01 fixtures) against the deployed app; independent review of correctness/security; fix gaps. | contract green |
| **36-07** | Hand-off | The Appian package + the frozen contract (+ any typed client stub landing in genesis) handed to Phase 37; docs updated (bible/tracker/progress note the Hub app + contract). | contract green + docs |

**Suggested order:** 36-01 (contract) → 36-02/36-03/36-04 (build; can overlap) → 36-05 (package) → 36-06
(validate) → 36-07 (hand-off). **36-01 must precede any Phase-37 provider work** (it freezes the interface).

---

## 9. Release plan

**No genesis version tag from this phase** (it is an Appian-side deliverable). The genesis-repo footprint is the
**checked-in contract doc + contract fixtures** (committed under the phase-36 specs / `reference/`), which land
alongside Phase 37's provider. The Appian **package** is versioned + released on the Appian side (its own
version stamp); a team upgrades the Hub app by importing the new package. The frozen contract is
**versioned** so Genesis can detect a contract mismatch. CI: n/a for Appian; the **contract-test harness**
(36-06) is the gate, and it is re-used by Phase 37's provider tests.

---

## 10. Scope

**In scope:** the dedicated Genesis Hub Appian application — record types (Team/Membership/Feature/Epic/Story/
BoardState/StageArtifact-metadata, UUID-keyed, versioned, attributed) + document-management blob store
(KB + artifacts, versioned, deduped, retained) + the Web-API surface (records/blobs/changes/activity/teams,
service-account auth, CAS/409) + service-account + package + install/upgrade procedure + the **frozen JSON
contract + fixtures** checked into genesis; the isolation rule.

**Out of scope:** the Genesis-side `SyncProvider` that calls these APIs (Phase 37); any Genesis runtime Appian
writes (Genesis stays read-only); per-team visibility **enforcement** (tags only); Smart-Search-powered
retrieval (a future enrichment); shared-memory record types (deferred); identity verification/anti-spoofing
(parked).

---

## 11. Open questions

- **36-01 to finalize:** the exact Web-API base path + auth header per the deployed Dev MCP's Appian version;
  blob size limits for the doc-management record type (KB blob ~1–2 MB gzipped — well within limits, but confirm
  on the target Appian version); the retention "keep-last-N" mechanism (record-type-managed vs a scheduled
  cleanup). None block the contract shape.
- **Who operates the service account + rotates its key** (ops question for 36-05; ties to the Phase-37 credential
  wiring via ADR-048).
