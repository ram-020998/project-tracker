# 36-02 — Record types & data model (Appian build)

> **Status:** 🟡 DRAFTED. · Part of Phase 36. **Built by the Dev-MCP agent** (Appian-side). · **Depends on:** 36-01 (the full field tables + inventory). · **Skill refs (load first):** `record-types.md`, `data-modeling.md`, `relationship-patterns.md`, `field-types.md`, `security.md`, `tools-mcp.md`.

## Purpose

Build the **11 record types** (§2 of 36-01) on the Hub data source, with exact fields/types/keys, the
relationships (both sides), and record-level security — the backing data for the Web APIs. **Follow the Appian
skill's record-type conventions exactly** (PK `id` Integer; `syncUuid` unique; relationships both sides; no USER
fields — attribution is Text; **no CLOB — every `Text` field ≤ 4000, variable-length lists normalized into
`GH Story Item`**; UUIDs sourced from the environment, never fabricated).

## Build order (dependency-safe)

1. **Data source / tables.** Create the backing DB tables on the Hub business data source (skill:
   `data-modeling.md`) — one per record type, columns per the §2 tables (`snake_case`), PK `id` identity, the
   documented **unique indexes** (`sync_uuid` on each; the composite uniques on `gh_membership`,
   `gh_board_state`, `gh_activity`, `gh_blob_version`, `gh_story_item`). (If using Appian-managed data-store
   entities, mirror the same structure.)
2. **Record types (create in this order):** `GH Team` → `GH Membership` → `GH Feature` → `GH Epic` → `GH Story`
   → **`GH Story Item`** → `GH Board State` → `GH Stage Artifact` → `GH Blob Version` → `GH Change Log` →
   `GH Activity`. For each: map every field to its column with the Appian field type from §2 (**Text [≤ 4000] /
   Integer / "Date and Time" / Boolean — there is NO CLOB**); set the PK to `id`; **do not** add USER fields
   (attribution stays Text).
   **After each `createRecordType`, capture the returned record-type UUID + field UUIDs** (the Web APIs +
   expression rules in 36-04 need the UUID-qualified `'recordType!{uuid}...fields.{fieldUuid}...'` references —
   sourced, never fabricated).
3. **Relationships (§2.11, after all record types exist):** declare **both** sides for each —
   `GH Feature`↔`GH Epic`, `GH Feature`↔`GH Story`, `GH Epic`↔`GH Story`, `GH Feature`↔`GH Stage Artifact`,
   `GH Story`↔`GH Stage Artifact`, **`GH Story`↔`GH Story Item`**, `GH Team`↔`GH Membership` — joining on the
   `syncUuid`/`*SyncUuid` fields (skill: `relationship-patterns.md` — MANY_TO_ONE + ONE_TO_MANY, or the tool
   will leave the reverse missing).
4. **Record-level security (skill: `security.md`/`security-patterns.md`):** on every Hub record type — **read**
   = `GH All Users`; **write/edit** = `GH Service Accounts` (the API writes as the service account); admin =
   `GH Administrators`. (Open visibility this phase — no per-team row filtering; the `teamUuid`/`ownerUsername`
   tags are stored for a future scoping seam, not enforced.)

## Validation (skill: `change-review.md`)

- Every record type matches the §2 field table (names, types, keys); `syncUuid` uniqueness enforced; the
  composite uniques present; relationships navigable **both** directions; no USER-field relationships created;
  record-level security as above. Confirmed by the 36-06 contract harness (a `PUT`/`GET` round-trip per kind).

## Deliverable

The 11 record types + their tables + relationships + record-level security, matching 36-01 §2, with their UUIDs
captured for 36-04.

## Gate

Contract-conformant record model → 36-03/36-04.
