# 36-02 — Record types & data model (Appian)

> **Status:** 🟡 DRAFTED. · Part of Phase 36. **Built by the Dev-MCP agent** (Appian-side). · **Depends on:** 36-01 (the frozen record model + contract).

## Purpose

Build the UUID-keyed **record types** that hold the shared entities, on an RDBMS data source, exactly matching
the 36-01 model — so the Web APIs (36-04) have their backing data.

## Build (Dev-MCP agent, in the Genesis Hub Appian application)

1. A dedicated **data source / Data Store** (or record types on the platform RDBMS) for the Hub, isolated from
   any subject-app data.
2. Record types — each with `sync_uuid` (text, **unique index**), `version` (int), `created_by`, `modified_by`,
   `created_at`, `updated_at`; relationships by `sync_uuid` foreign keys (not Appian auto-ids):
   - **Team** (`team_uuid` pk, `title`) · **Membership** (`team_uuid`, `username`; `name`, `email`, `joined_at`).
   - **Feature** (`app_uuid`, `name`, `description`, `owner_username`, `team_uuid`).
   - **Epic** (`feature_sync_uuid`, `key`, `title`, `description`, `workstream`, `position`).
   - **Story** (`feature_sync_uuid`, `epic_sync_uuid`, `key`, `title`, `story_type`, `category`, `appian_part`,
     `description`, `acceptance_criteria`, `dev_note_ref`, `questions`, `labels`, `status`, `position`,
     `owner_username`, `team_uuid`).
   - **BoardState** (`app_uuid`, `story_sync_uuid`, `status`).
   - **StageArtifact** metadata (`parent_sync_uuid`, `parent_kind`, `stage`, `status`, `content_hash`,
     `blob_ref`, `published_by`, `upstream_versions_json`).
3. **Relationships** so a Feature → its Epics/Stories/StageArtifacts are queryable by `sync_uuid`.
4. **Attribution + owner/team fields populated from the request payload** (not Appian auth) — enforced in the
   Web-API expressions (36-04).

## Validation

The record types satisfy the 36-01 field/key/relationship spec; a `sync_uuid` upsert enforces uniqueness; the
`version` column supports the base-version CAS (36-04). Verified by the contract harness in 36-06.

## Gate

Contract-conformant record model → 36-03/36-04.
