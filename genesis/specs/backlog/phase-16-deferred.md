# Phase 16 — Deferred / Backlog register

> **Status:** LIVING DOC · **Owner:** Genesis agent · **Created:** 2026-08-06
> **Purpose:** The single, detailed record of **everything deliberately deferred** during Phase 16 (Appian Knowledge
> Base / "Atlas-into-Genesis") — what was cut from iteration 1, **why**, what it's **blocked on**, what is **already in
> place** so it lands cheaply, and the **acceptance** each item still needs. A future agent should be able to pick up any
> item from here without re-deriving the context.
>
> **How to read this:** items are grouped by *sub-phase backlog* (§1), *`genesis-kb` tool-contract sections deferred*
> (§2), *platform/infra deferrals* (§3), and the *manual live-acceptance checklist* (§4). §5 records the
> **schema-readiness** already shipped so several of these are code-only when unblocked.
>
> **Shipped for context (NOT deferred):** 16-01 parser (`genesis-appian-parser` v0.1.0), 16-02 schema + `KbStore`
> (m0007, genesis v0.28.0), 16-03 `sync-application` **baseline** (genesis v0.29.1 + genesis-workflows v0.8.2), 16-08
> native Dev/DevOps MCP (genesis-core v0.9.1 + genesis v0.31.1 + genesis-workflows v0.8.4), 16-04 Applications surface
> (genesis v0.32.0), 16-05 **`genesis-kb` MCP server + chat cutover** (genesis v0.33.0). **In progress:** 16-07 delta
> **Option A** (re-export + delta-merge). See `progress/phase-16-0*` for as-builts.

---

## 1. Sub-phase backlog

### 1.1 — 16-06 · Versioning / multi-release  **(BACKLOG — externally gated)**
- **What:** the release-history slice of the KB. Six read tools on `genesis-kb`:
  `list_releases`, `get_changelog`, `compare_releases`, `get_object_history`, `get_object_at_release`,
  `get_release_impact`; plus a **release-tagging UX** (mark "released v1.0" in the Applications page) and
  **point-in-time reads** across all structural tools (an `at_release` / `version` argument).
- **Why deferred / blocked on:** **Dev MCP `AP-62096`** ("Object version viewing/comparison", Code Review) —
  **26.8 GA / 2026-08-28**. Live *code at a past release* needs the Dev MCP's versioned object read, which does not
  exist until then. (The underlying version-UUID plumbing AP-51279 is Done; the MCP surface is AP-62096.)
- **Already in place (lands as CODE-ONLY, no migration):**
  - `kb_*` tables are fully **SCD-2** (`valid_from_sync` / `valid_to_sync`) and `kb_releases` exists (m0007).
  - `KbStore.tag_release(app, version_label, env_version_ref?, notes?)`, `list_releases(app)`, and the point-in-time
    helpers `_snapshot_sync_for` / `_validity(sid)` + `get_app_overview(app, at_release=...)` are **already wired and
    unit-tested** (see `tests/test_kb_store.py::test_point_in_time_overview`).
  - `get_object_code` already carries a **reserved `version?` param** (ignored until AP-62096).
- **Acceptance when built:** the 6 tools return Atlas-mirrored shapes over historical SCD-2 rows; a tagged release
  snapshots bundles under `release_label`; `get_object_at_release` fetches code at that release via the Dev MCP
  versioned read; UX to tag/browse releases + a per-release changelog.
- **Refs:** `specs/phase-16-appian-knowledge-base/16-06-version-tagging-and-point-in-time.md`; ADR-037; tool-contracts §5 (Section B).

### 1.2 — 16-05b · Workflow cutover (`erd-generation` + `design-doc`) off `appian-atlas` → `genesis-kb`  **(BLOCKED)**
- **What:** finish the 16-05 cutover for the two remaining Atlas consumers so `appian-atlas` can be fully retired.
- **Why deferred / blocked on (three independent blockers):**
  1. **Section-C schema/DDL tools (deferred, §2.2 below).** `erd-generation`'s `fetch_schema` node uses
     `get_app_schema` + `get_schema_relationships`; `design-doc`'s `research_atlas` also uses
     `get_app_schema` / `get_schema_summary` / `get_field_map` / `get_record_type_map` / `get_reference_data`.
     `genesis-kb` iteration-1 does **not** provide schema/DDL (the code-free parser doesn't capture DB DDL).
  2. **16-06 versioning tools.** `design-doc`'s `research_atlas` uses `list_releases` / `get_object_at_release` /
     `get_changelog` / `get_release_impact` / `compare_releases` / `get_object_history` — the *reason the Atlas node
     exists as a second source*. Gated on AP-62096 (see 1.1).
  3. **Jarvis retirement.** `design-doc`'s sibling `research_jarvis` node still uses **Jarvis** (retired as a service).
     A true cutover means repointing live-env reads Jarvis → **Dev MCP** — a design change, not a repoint.
- **Decision in force (2026-08-06):** `appian-atlas` **remains a registered curated MCP** and **both workflows keep
  using it** (`required_mcp` unchanged; `genesis-workflows` not re-released for 16-05). Documented in the umbrella spec
  ("Phased-cutover decision"). Only **chat** cut over in 16-05 (it used Atlas *structural* reads that `genesis-kb`
  mirrors 1:1).
- **Two viable paths for schema when unblocking:** (a) build the Section-C schema tools on `genesis-kb`; **or**
  (b) repoint the workflows' schema/data-model research to **live Dev-MCP record-type tools**
  (`getRecordType`, `listRecordTypeFields`, `listRecordTypeRelationships`, `getRecordTypeField`) — an environment call,
  per the governing principle. (b) avoids storing DDL in the KB but couples ERD/design-doc to a live env.
- **When cutting over:** update each node's `mcp=`/`tools=` + prompts + the workflow `required_mcp`, and rewrite the
  workflow **tests to the real `genesis-kb` shapes** (Phase-12 "stub-hid-the-contract" lesson), then drop `appian-atlas`
  from the two workflows (and from the registry once nothing references it).
- **Refs:** `specs/phase-16-appian-knowledge-base/16-05-kb-mcp-and-cutover.md` §2.4; `progress/phase-16-05-kb-mcp-and-cutover.md`.

### 1.3 — 16-07 · True incremental delta (the changed-objects API path)  **(DEFERRED after Option A)**
- **Option A ships now** (re-export + `KbStore.apply(mode='delta')`) — see the 16-07 spec / progress. The items below
  are the *incremental optimization* deferred for later.
- **What:** a **new Appian "changed-objects" API** so a delta exports only what changed in `[start, end]` instead of a
  full re-export.
  - Proposed contract: `GET /changed-objects?app=<uuid>&start=<iso8601>&end=<iso8601>` (service-account key), paginated,
    returning `[{object_uuid, name, type, last_modified, change_kind: added|modified|removed}]`; **ideally** also
    returns/links the changed objects' content/XML to avoid a per-object export round-trip.
- **Why deferred / blocked on:** the API is **owned by the Appian side** and its **contract is not finalized**; it is
  **not deployed**. **Confirmed 2026-08-06:** the **Dev MCP cannot back this** — there is *no* modified-since / history /
  audit tool; the `list*` tools filter only by `query` (name) / `appUuid` / `limit` / `offset`; and design objects carry
  **no modified timestamp** in their outputs (only `Folder` has `created_at`/`modified_at`, and even those "may be null
  due to API limitations"). So a genuine changed-in-window capability **requires the new API** — it cannot be
  synthesized from the Dev MCP.
- **Contract points to settle with the Appian side:** content-inline vs identifiers-only (drives whether Genesis then
  exports the subset via the Deployment API); **explicit deletes** (required to close SCD-2 rows — Option A infers them
  from a full re-parse, the changed-objects path must report them); rename handling (UUID-keyed, fine); pagination for
  large windows; clock/timezone (use the env server time; store the window Genesis actually queried).
- **Already in place:** `KbStore.apply(mode='delta', removed_uuids=...)` (SCD-2 transitions + bundle recompute),
  `kb_syncs.window_start/window_end`, the `mode: baseline|delta` input on `sync-application`, and (after Option A) the
  delta graph path + the isolated fetch seam to slot the API client into.
- **Refs:** `specs/phase-16-appian-knowledge-base/16-07-delta-refresh-and-scheduling.md` §2.1–2.2 + §5.

### 1.4 — 16-07 · Scheduler (automatic delta)  **(DEFERRED — fast-follow within 16-07)**
- **What:** a lightweight in-app scheduler that starts a delta `sync-application` run per app every N minutes/hours
  (`sync_interval`, on/off), non-overlapping (skip if a sync is running), with back-off on repeated failure and a
  last-run / next-run surface in the Applications page.
- **Why deferred:** it is the one genuinely new "background job" concept; the 16-07 spec explicitly permits
  **manual-only v1 + scheduler as a fast-follow**. Manual "Sync now" already exists (16-04 `POST
  /applications/{id}/sync`). Keep it minimal + observable (runs are normal `sync-application` runs, so tracking/retry/
  errors come free).
- **Wiring decision (when built):** an asyncio task started in `create_app` (honoring the single-user local posture)
  that calls `RunManager.start(..., mode='delta')` for due apps; plus an additive `sync_interval` column (**m0008**) on
  `kb_applications` (or a config file — prefer the migration).
- **Refs:** 16-07 spec §2.3.

### 1.5 — 16-07 · Changelog surface  **(PARTIAL — per-release diffs blocked on 16-06)**
- **What:** the Applications-detail **Changelog** view — per-sync deltas (added/modified/removed + affected bundles)
  and **per-release diffs**.
- **Status:** per-sync deltas are computable **now** from `kb_syncs` + SCD-2 (`objects_added/modified/removed`);
  **per-release diffs need 16-06** (`compare_releases` / `get_changelog`). Build the per-sync view when convenient;
  the per-release view lands with 16-06.
- **Refs:** 16-07 spec §2.4.

---

## 2. `genesis-kb` tool-contract sections deferred (from the Atlas 34-tool + Jarvis 50-tool audit)

> The authoritative capability analysis + scope verdicts live in
> `specs/phase-16-appian-knowledge-base/genesis-kb-tool-contracts.md` §0 + §5. Iteration 1 = **Section A / Tier-1
> (16/17 read tools)** only. The rest, verbatim status:

### 2.1 — Section A (deferred slice)  **(OUT)**
Patterns, translations, **semantic search** (a future **pgvector** trigger — ADR-030), and **code analysis / explain**.
Rationale: the agent reasons over *fetched* code; these are not KB tools. Semantic search waits for the ADR-030 trigger
(multi-user / transcript RAG / heavy analytics) — until then `search_objects` is `LIKE` substring (FTS5 is a cheap
interim upgrade, §3.3).

### 2.2 — Section B (versioning)  →  **16-06** (see §1.1). **BACKLOG**, gated on AP-62096.

### 2.3 — Section C · Schema / DDL / data-gen  **(DEFERRED — future phase)**
- **Tools:** `get_app_schema`, `get_schema_summary`, `get_schema_relationships`, `get_insertion_order`,
  `get_reference_data`, `get_field_map`, `get_record_type_map` (7 schema) + `get_entry_point_write_graph`,
  `resolve_write_set` (2 write-set).
- **Also needs:** the parser's `schema/` module (not ported in 16-01) + schema tables in `kb_*`.
- **Why deferred:** overlaps the **Data-Generator MCP**; the code-free structural parser doesn't capture DB DDL; not
  needed for the Tier-1 structural intelligence. **This is the direct blocker for `erd-generation` + `design-doc`
  schema needs (see §1.2).**
- **Alternative when needed:** serve schema via **live Dev-MCP record-type tools** rather than storing DDL in the KB
  (governing principle: environment calls → Dev/DevOps MCP).

### 2.4 — Section D · Live-environment reads  **(IN — via Dev/DevOps MCP only, NOT the KB)**
Not "deferred" so much as *routed*: live object SAIL/XML, SAIL evaluation, read-only SQL, environment info, list-apps,
package export/download are served by the **native Dev MCP / DevOps MCP** (read/export-only allowlists), never by
Atlas/Jarvis. `genesis-kb.get_object_code` co-injects the Dev MCP for this. (Recorded here so a future agent doesn't
try to add these to `genesis-kb`.)

### 2.5 — Section E · Write / deploy / create  **(OUT)**
All creation/deploy/data-mutation tools. When added later: behind a **`pre_mutation` gate + copilot confirmation**
(ADR-021/033), via the Dev/DevOps MCP (their write tools are currently **excluded** from the read-only allowlists).

### 2.6 — Section F · Documents / git-content / pipeline-refresh  **(OUT)**
Atlas extras: document binaries, a generic GitHub-content reader, and pipeline-refresh (a KB refresh is triggered via
the Applications API / `sync-application`, not an agent tool).

---

## 3. Platform / infra deferrals

### 3.1 — Retention / pruning of old SCD-2 rows + release snapshots  **(umbrella Q5)**
As an app evolves, closed SCD-2 rows and old bundle snapshots accumulate. A retention policy (keep-last-N releases /
max-age) to prune history — reuse the existing `RetentionService` patterns. Can follow.

### 3.2 — Multi-environment  **(OUT)**
Iteration 1 is single **dev-tagged** environment (16-08 §2.0 `is_dev`). Multiple concurrent environments per app is out
of scope (aligns with the local single-user posture, ADR-026).

### 3.3 — FTS5 search for `search_objects`  **(NICE-TO-HAVE)**
`search_objects` is `name LIKE '%q%'` today. An SQLite **FTS5** index over object names (+ maybe descriptions) is a
cheap, self-contained upgrade. Not now.

### 3.4 — `get_object_code` live-wiring hardening  **(FOLLOW-UP, verify against a live env)**
`genesis/kb/dev_mcp.object_code` maps object type → Dev-MCP getter (`getExpressionRule`/`getInterface`/…) and passes
`{"uuid": ...}` as the arg, with a **defensive** code extraction. This is **unverified against a live Dev MCP** (can't
be driven headlessly). To harden: confirm each getter's real param name + response field carrying SAIL; add getters for
any missing types; today, unknown/unmapped types degrade to `code_status:"unavailable"` (never fabricated). Same caveat
applies to `get_orphan`'s code field.

---

## 4. Manual live-acceptance checklist (cannot be driven headlessly)

These passed their **automated** tests (stubs/seeded DBs) but need a human to verify against the real Appian env +
kiro-cli. Record results in the relevant `progress/` doc when done.

- **16-03 baseline sync:** a real Deployment REST export of an app from the dev-tagged env → parse → KB populated.
- **16-05 chat:** chat answers an app-structure question from the internal KB; a `get_object_code` call returns **live
  SAIL** via the Dev MCP; graceful "code unavailable" when the env is down.
- **16-07 Option A delta:** re-sync an already-baselined app after a change in the env → SCD-2 history + bundle
  recompute + window recorded; deletes close rows; empty window = no-op.
- **16-08 Dev/DevOps MCP:** live introspection (`tools/list`) + a real read tool call from the installed managed
  servers; a managed re-install (drop-in) + rollback.
- **16-07 real delta (future):** with the changed-objects API deployed, a dev change is picked up incrementally.

---

## 5. Schema-readiness already shipped (so unblocking is cheap)

Recorded so a future agent knows these need **no migration / no re-architecture**:
- **SCD-2 + releases** (m0007): `valid_from_sync`/`valid_to_sync` on `kb_objects`/`kb_dependencies`; `kb_releases`;
  `kb_bundles.release_label` for release snapshots. → **16-06 is code-only.**
- **`KbStore`** already has `tag_release` / `list_releases` / point-in-time (`_snapshot_sync_for` / `_validity` /
  `get_app_overview(at_release=)`) + `apply(mode='delta', removed_uuids=)`. → **16-06 + 16-07 delta reuse these.**
- **`sync-application`** already declares `mode: baseline|delta`, records `kb_syncs.window_start/window_end`, and (after
  Option A) has the delta graph path + an isolated fetch seam → **the changed-objects client slots into that seam.**
- **`get_object_code`** carries the reserved `version?` param → **AP-62096 lights it up with no signature change.**
- **`appian-devops` allowlist** already includes export/inspect/status/download tools → **partial-export optimization
  can use them when the changed-objects API returns identifiers-only.**
