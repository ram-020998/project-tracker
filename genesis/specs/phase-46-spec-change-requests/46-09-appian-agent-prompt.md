# 46-09 — Full prompt for the Appian (write-capable Dev-MCP) agent

> Paste everything inside the fence into a fresh Appian-agent session. Companion files: the normative spec
> `specs/phase-36-genesis-hub-appian-app/contract/spec-change-contract-addition.md`, the fixtures, and the short
> checklist in `46-09-appian-agent-handoff.md`.

```text
====================================================================================================================
ROLE
====================================================================================================================
You are the write-capable Appian Dev-MCP agent that built, owns and live-validated the **Genesis Hub** Appian
application: Phase 36 (the Hub itself, ADR-064; 11 record types, 13 relationships, record-level security, 11 Web
APIs, 12 helper expression rules, a frozen JSON contract v1.0.0) and the Phase 42-06 **Object Wiki** addition
(ADR-070; two record kinds added additively, harness 18/18). Genesis — a local-first AI SDLC platform — talks to the
Hub only through its Web APIs, with a service-account API key. **Genesis is read-only against Appian (ADR-036/037);
you are the only writer.**

Your task now: build and live-validate ONE more **additive, backward-compatible** addition to the Hub contract for
Genesis **Phase 46 — Spec Change Requests & Story Traceability**. Do not start building until you have read the
documents in PART 1 and written the restatement in PART 2.

If you have an Appian skill / Appian MCP guidance available in your environment (naming conventions, record type
and relationship rules, SAIL patterns, UUID handling), load it BEFORE calling any Appian MCP tool.

====================================================================================================================
PART 0 — WHAT PHASE 46 IS (so you understand why the Hub changes)
====================================================================================================================
In Genesis, a feature goes through stages: Spec → UX Design → Technical Design → Feature Breakdown (epics/stories)
→ Finalize Stories → a Workbench board (To Do → Design → Design Review → Implementation → Code Review → …).
Before Phase 46, once stories existed, editing the spec meant "Reopen" and the stories silently went stale.

Phase 46 changes that for finalized features:
- Every requirement in the spec HTML gets a stable clause id (`data-cid="c-xxxxxxxx"`, 8 hex). Each story records
  which clauses it implements: its **spec_refs** (link records `{clause_id, fingerprint, origin, linked_at}`).
- Changing a finalized spec goes through a numbered **change request** (CR-01, CR-02 …): Initiate → edit the spec
  in the chat → Analyze impact → a CR "Impact Analysis" document → Apply changes | Discard.
- **Apply** updates/creates/removes stories in one transaction, records answers to stories' open questions
  (**answers**: `{question, answer, answered_by, answered_at, source: "cr"|"manual", cr_no}`) and appends a history
  entry per story (**change_log**: `{cr_no, cr_sync_uuid, decision, summary, clause_labels, clause_ids, fields, at,
  by, needs_design_rerun, follow_up_of, follow_ups}`), produces spec revision N+1, and freezes the CR document.
- Users can also answer a story's open questions by hand at any time (manual answers).

What teammates (other Genesis machines that PULL from the Hub) must see: the updated stories including those three
new lists, the feature's change-request list (applied/discarded CRs), and each CR's frozen document. Open CRs are
never published — a teammate only sees an advisory "Spec under change by <name>" marker through the EXISTING
activity API (no Hub change for that).

So the Hub needs exactly two changes:
1. **story**: three new arrays (`spec_refs`, `answers`, `change_log`) stored as `GH Story Item` rows with three new
   `item_type` values (`spec_ref`, `answer`, `change`).
2. A new record kind **`spec_change_request`** (record type **GH Spec Change Request**) on the existing generic
   records/changes endpoints, its document in the existing artifact blob store.

====================================================================================================================
PART 1 — READ THESE DOCUMENTS FIRST, IN THIS ORDER, COMPLETELY
====================================================================================================================
All paths are under /Users/ramaswamy.u/repo/project-tracker/genesis/ . Read every file in full; do not skim the
normative ones (marked ★).

1. ★ specs/phase-36-genesis-hub-appian-app/contract/spec-change-contract-addition.md
   THE SPEC for this task (normative). §2 = the story arrays (wire shape, write semantics incl. the ABSENT-KEY
   rule, read semantics); §3 = GH Spec Change Request (20 fields with tiers, rules to extend, the blob); §4 = the
   advisory marker (no change, just confirm the TTL); §5 = the acceptance harness.
2. ★ specs/phase-36-genesis-hub-appian-app/contract/fixtures/story_with_trace.json
   Three PUT→GET steps + a stale-409 case for the story arrays. Elements are opaque strings containing unicode,
   quotes, backslashes and \n escapes — they must come back byte-for-byte.
3. ★ specs/phase-36-genesis-hub-appian-app/contract/fixtures/spec_change_request.json
   applied create / update / stale 409 / discarded (null result_revision_no) / the blob at
   `<feature_sync_uuid>:cr-03` / a /changes row example.
4. ★ specs/phase-36-genesis-hub-appian-app/contract/genesis-hub-api.md
   The frozen v1.0.0 contract: the kinds, record field tables, §2.2 story arrays normalized into GH Story Item,
   §3.2 PUT upsert with base-version CAS (201 created / 200 updated / 409 conflict `{"error":"conflict",
   "current_version":N}`), §3.3/3.4 get/list, §3.5 /changes, §3.6–3.8 blobs (dedup on content_hash, versions,
   prune to 10), §3.9–3.11 activity, §4 status codes, §4a read-after-write, §5 datetime/encoding + text sizing,
   §6 fixtures + the round-trip rule.
5. ★ specs/phase-36-genesis-hub-appian-app/contract/object-wiki-contract-addition.md
   The previous addition — follow the SAME pattern (additive kind-branches before `default`; the one Web API
   allow-list edit; record-level security mirroring existing types) and the SAME as-built reporting format.
6. ★ progress/phase-36-genesis-hub-appian-app.md
   The as-built record you must work from (NEVER fabricate UUIDs — use the UUID-qualified
   `'recordType!{rtUuid}Name.fields.{fieldUuid}fieldName'` form). Key facts you will need (verify them live):
   - Groups: GH Administrators `_e-0000f058-fe86-8000-9b49-01075c01075c_458`, GH Users `…_460`,
     GH Service Accounts `…_462` (the API writer = data_steward).
   - Conventions: DATABASE-backed (`jdbc/Appian`), PK `id` INTEGER, `syncUuid` TEXT 255 unique, no USER fields
     (attribution is TEXT), Extra-Long = LONGVARCHAR(65535) (≤3 per record type), medium text = 4000,
     codes = 255. Composite uniques are enforced in the Web-API logic, not columns — incl.
     `GH_STORY_ITEM(story_sync_uuid, item_type, position)`.
   - GH Story — rt `31c5187d-3c6f-467a-be02-d4549d98a822`; rel storyItems (O2M→Story Item)
     `9dcd602e-5139-46b8-9a6a-627ff2f69c2d`.
   - GH Story Item — rt `556f67aa-34fe-42b1-a67e-76a67f770b84` (GH_STORY_ITEM): id `f9e92a74-…`, syncUuid
     `de9521ee-…`, storySyncUuid `0c51b86d-…`, **itemType `d8bcdbcd-8337-4bce-9297-1f20489521f6`**, **text (ELT)
     `b025a024-7026-4f1b-a593-d95808226840`**, position `117fc24f-…`, version, createdAt, updatedAt; rel story
     `83aa53bb-…`.
   - GH Feature — rt `5ff1c823-0ff9-4a59-943b-3314aad3b6f7` (syncUuid field `ce089835-…`); rels epics / stories /
     stageArtifacts.
   - GH Stage Artifact — rt `90a731eb-86ba-4d04-baa0-dd4b760fb121` (the attribution model to mirror:
     publishedBy / publishedAt from the payload).
   - GH Change Log — rt `ff9c6698-dd22-4e5a-a457-c188da1a49e4`; GH Blob Version — rt `c6368222-…`;
     GH Activity — rt `c8b98356-…`.
   - Rules: GH_casUpsert `_a-…27509` (the CAS capstone; per-kind dispatch; the story-item explode),
     GH_recordToJson `_a-…27503` (per-kind projection; the story branch folds in GH_reassembleStoryItems),
     GH_reassembleStoryItems `_a-…27520`, GH_queryRecords `_a-…27526`, GH_appendChangeLog, GH_changesSince,
     the blob rules (GH_blobLatest, GH_pruneBlobVersions, GH_recordBlobVersion), GH_isServiceCaller,
     GH_errorResponse. Latest versions after the Object Wiki: GH_casUpsert v10, GH_recordToJson v4,
     GH_queryRecords v4 — confirm the current versions live before editing.
   - Web API `GH_records_upsert` `8e153f45-c413-4eb4-be0f-4e722130fc2d` (PUT `records`) has its OWN inline kind
     allow-list (rejects unknown kinds with 400 "invalid kind or missing syncUuid"); last time it had to be edited
     in Designer because MCP can't read/write a Web API's SAIL body. The read Web APIs have no kind guard.
   - Known behaviour: a null TEXT field reads back as "" (accepted, documented).
   - The validation approach: a Python harness driven as the `kiroDeveloper` GH Service Account over the real Web
     APIs (`/tmp/gh/wiki_harness.py` last time), then cleanup of validation rows.
7. specs/phase-36-genesis-hub-appian-app/36-02-record-types-and-data-model.md, 36-03-document-management-and-blob-
   store.md, 36-04-web-apis.md, 36-05-packaging-security-and-deployment.md, 36-06-contract-validation-and-review.md
   — the design rationale behind the record types, the blob store, the Web APIs, security and the harness (read the
   sections relevant to story items, blobs, CAS and validation).
8. specs/phase-36-genesis-hub-appian-app/contract/deployment-runbook.md — how the app is deployed/configured.
9. Context (skim, for the "why"): specs/phase-46-spec-change-requests/46-09-collaboration-and-hub.md (esp. §1 what is
   shared, §4 the record, §5 the marker, §10 the contract-freeze refinements) and the umbrella
   specs/phase-46-spec-change-requests.md §1–§3.
10. Decision log: reference/decision-log.md — ADR-063 (collaboration, soft locks), ADR-064 (the Hub), ADR-070 (the
    Object Wiki addition precedent), ADR-075/076 (Phase 46, Proposed).

====================================================================================================================
PART 2 — RESTATE, THEN START (no questions needed unless something is impossible)
====================================================================================================================
Before your first write, briefly restate: (a) the two changes; (b) the absent-key rule and why it exists; (c) the
exact objects you will create/modify (with the UUIDs you verified live); (d) your validation plan. Then inspect the
CURRENT live definitions of GH_casUpsert (story branch), GH_reassembleStoryItems, GH_recordToJson, GH_queryRecords,
GH_records_upsert's allow-list and the blob rules/Web APIs, and note anything that differs from the as-built doc.

====================================================================================================================
PART 3 — BUILD (dev-env Hub, the Genesis Hub application only)
====================================================================================================================
A. Story arrays → GH Story Item (spec §2)
   1. Allowed item types become `ac | question | label | spec_ref | answer | change`. Extend any constant, rule or
      validation that lists the allowed values.
   2. GH_casUpsert story branch — for each of `spec_refs`→`spec_ref`, `answers`→`answer`, `change_log`→`change`:
      - key PRESENT in the payload → replace that type's rows for the story (one row per element, position = array
        index, text = the element string unchanged), atomically in the same write batch as the story + its change
        log row; an empty array `[]` deletes that type's rows;
      - key ABSENT → touch nothing of that type (an older Genesis that never sends these keys must not wipe them).
      - Keep the composite uniqueness (story_sync_uuid, item_type, position).
      - DO NOT change how acceptance_criteria / questions / labels behave today. Find out and REPORT what the
        current behaviour is when one of those three keys is absent.
   3. GH_reassembleStoryItems + the GH_recordToJson story branch: return `spec_refs`, `answers`, `change_log`
      ALWAYS (position-ordered; `[]` when there are no rows), on both get and list. Elements are opaque: never
      parse, trim, normalize or re-encode them.
   4. Sizes: elements are ≤ 4,000 characters (Genesis enforces it); GH Story Item.text is already Extra Long — no
      field change. Remember limits are bytes (multibyte/emoji count more).

B. New record type GH Spec Change Request — kind `spec_change_request` (spec §3)
   1. Create the record type (DATABASE `jdbc/Appian`, table e.g. `GH_SPEC_CHANGE_REQUEST`, PK `id` INTEGER,
      `syncUuid` TEXT 255 unique) with the fields of spec §3.1 exactly:
      syncUuid, featureSyncUuid (255), crNo (Integer), title (4000), status (255: applied|discarded),
      mode (255: stories|backlog), openedBy (255), openedAt (TEXT 255, payload-preserved), closedBy (255),
      closedAt (TEXT 255, payload-preserved), baseRevisionNo (Integer), baseContentHash (255),
      resultRevisionNo (Integer, nullable), summary (Long 4000, opaque JSON text), blobKey (255),
      contentHash (255), publishedBy (255), publishedAt (as GH Stage Artifact does), version (Integer),
      createdAt, updatedAt (server-managed, as other kinds). No Extra-Long fields.
   2. Record-level security mirroring GH Stage Artifact / the Object Wiki types (admin+editor = GH Administrators,
      viewer = GH Users, data_steward = GH Service Accounts); associate it with the application.
   3. Recommended relationship: GH Spec Change Request.feature (MANY_TO_ONE → GH Feature on featureSyncUuid →
      syncUuid) + the inverse GH Feature.changeRequests (ONE_TO_MANY); cascading only if GH Feature already
      cascades to its stage artifacts.
   4. Rules — additive kind-branches inserted BEFORE `default`, existing branches byte-for-byte untouched:
      - GH_casUpsert: `spec_change_request` — publishedBy = coalesce(payload.published_by, actor), publishedAt =
        coalesce(payload.published_at, now()), createdAt = coalesce(existing, now()), updatedAt = now(),
        version = coalesce(base, -1) + 1, 409 CAS on a stale base_version, a GH Change Log row in the same
        a!writeRecords batch.
      - GH_recordToJson: the 20-key snake_case projection of spec §3.1.
      - GH_queryRecords: get (by syncUuid) + list branches with all projected fields.
   5. Web API GH_records_upsert: append "spec_change_request" to its inline kind allow-list (the ONLY Web API edit
      allowed). No new Web API objects.
   6. Integer nulls: `result_revision_no` must read back as `null` for a discarded CR (not 0). If Appian can't do
      that, STOP and report — do not silently return 0.

C. Verify (change only if necessary, additively, and report):
   - The artifact blob Web APIs/rules accept the key `<feature_sync_uuid>:cr-<nn>` (no validation of the suffix
     against stage names). Documents are small HTML (tens of KB; also test ~1 MB).
   - POST /activity accepts `ttl_seconds: 86400` (no upper bound).
   - /changes emits `kind: "spec_change_request"` rows.
   - `contract_version` stays "1.0.0" (backward-compatible addition; do NOT bump it).

====================================================================================================================
PART 4 — VALIDATE LIVE (extend the 36-06 / wiki harness; service account over the real Web APIs)
====================================================================================================================
1. story_with_trace.json:
   - step 1 PUT (all six arrays) → GET equals the fixture's get_response byte-for-byte (arrays + order; server
     fields version/created_at/updated_at may differ in value but must be present);
   - step 2 PUT WITHOUT the three new keys (title edit, base_version 0) → GET still has step 1's spec_refs /
     answers / change_log unchanged;
   - step 3 PUT with `spec_refs: []` and a 2-entry change_log, answers absent → spec_refs `[]`, change_log replaced,
     answers preserved;
   - stale PUT (base_version 0 after version 2) → 409 `{"error":"conflict","current_version":2}`;
   - /changes shows one story row per upsert.
2. spec_change_request.json:
   - applied: PUT create → 201; GET byte-for-byte (opened_at / closed_at exact strings incl. microseconds and the
     +00:00 offset; summary text exact; unicode title); update with base_version 0 → 200 v1; stale → 409;
   - discarded: create → GET has `result_revision_no: null`, `summary` read back per the established null-text
     behaviour (report what it is), title `""`;
   - blob: POST /blobs/artifact/<feature_sync_uuid>:cr-03 → 201 new v1; same bytes again → 200 unchanged v1;
     GET → bytes + content_hash identical; a ~1 MB document round-trips;
   - /changes emits the kind.
3. Regression: every existing kind still passes — story's original arrays (AC order, empty `questions` `[]`,
   unicode labels, null epic), stage_artifact byte-for-byte, wiki_page, wiki_entry, team/membership/feature/epic/
   board_state; meta contract_version "1.0.0"; unauthenticated → 401.
4. Clean up every validation row (stories, story items, CR records, blob versions/documents you created). Change-log
   rows may stay (append-only feed, monotonic cursor).

====================================================================================================================
PART 5 — RULES OF ENGAGEMENT
====================================================================================================================
- Additive only. Never modify or delete existing records/data, fields, record types, relationships, existing rule
  branches, or Web APIs beyond the single allow-list append. Ask the human before anything destructive or anything
  that touches existing data.
- Never fabricate a UUID — read it live and use the UUID-qualified references.
- If the spec is impossible or ambiguous in Appian (Integer null, a text tier, the blob-key check, the absent-key
  rule interacting with the existing explode logic), STOP and report the exact constraint + your proposed
  resolution. Do not invent a different contract; Genesis is being built against this one in parallel.
- Keep the existing Web API behaviour and status codes identical for every existing kind.

====================================================================================================================
PART 6 — RECORD AND REPORT
====================================================================================================================
1. In specs/phase-36-genesis-hub-appian-app/contract/spec-change-contract-addition.md replace the top
   "BUILD STATUS: ⏳ NOT BUILT" line with the as-built summary (record type UUID + table, rule versions, the Web
   API edit, harness N/N, deviations) — same style as object-wiki-contract-addition.md.
2. In progress/phase-36-genesis-hub-appian-app.md add a section "SPEC CHANGE REQUEST ADDITION (Phase 46-09) —
   BUILT + LIVE-VALIDATED (<date>)": the new record type + every field UUID, relationship UUIDs, security, each
   rule's new version and what changed, the Web API edit, the story item-type change, the current absent-key
   behaviour of the original three arrays, harness N/N with per-check evidence, cleanup, and every deviation
   (flagged as such).
3. Commit and push project-tracker: from /Users/ramaswamy.u/repo/project-tracker, stage ONLY those two genesis/…
   files, commit, `git pull --rebase origin main` then `git push origin main`, and verify
   `git ls-remote origin -h refs/heads/main` equals your local HEAD.
4. Give the human a short summary: what was built, validation N/N, deviations, and anything Genesis must adapt
   to (e.g. how a null Integer or null text reads back, the existing absent-key behaviour).
```
