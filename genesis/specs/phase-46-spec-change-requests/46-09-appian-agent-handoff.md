# 46-09 — Hand-off to the Appian (write-capable Dev-MCP) agent: the Genesis Hub addition

> Written 2026-10-15 so the Hub-side half of 46-09 can be built **in parallel** with the genesis-side bindings.
> The normative spec is `specs/phase-36-genesis-hub-appian-app/contract/spec-change-contract-addition.md` (+ the two
> fixtures). This file is the agent prompt + checklist. Paste the block below into the Appian agent's session.

```text
You are the write-capable Dev-MCP agent that built and owns the Genesis Hub Appian application (Phase 36, ADR-064)
and its Object Wiki addition (Phase 42-06). Your task: build and live-validate ONE more ADDITIVE, backward-compatible
addition to the frozen v1.0.0 Hub contract, for Genesis Phase 46 (spec change requests + story traceability).
Genesis itself stays read-only against Appian (ADR-036/037) — you are the only writer.

READ FIRST (all under /Users/ramaswamy.u/repo/project-tracker/genesis/):
1. specs/phase-36-genesis-hub-appian-app/contract/spec-change-contract-addition.md   ← THE SPEC (normative)
2. specs/phase-36-genesis-hub-appian-app/contract/fixtures/story_with_trace.json and spec_change_request.json
3. specs/phase-36-genesis-hub-appian-app/contract/genesis-hub-api.md (the frozen v1.0.0 contract: kinds, CAS,
   /changes, blobs, activity, status codes, text tiers, the round-trip rule)
4. specs/phase-36-genesis-hub-appian-app/contract/object-wiki-contract-addition.md (the previous addition — follow
   the same pattern and the same reporting format)
5. progress/phase-36-genesis-hub-appian-app.md — the as-built record: record type / field / rule UUIDs, the
   proven SAIL patterns, the GH_records_upsert inline kind allow-list deviation, the null-text "" behaviour, and
   the 36-06 + wiki harness approach
6. Context only (skim): specs/phase-46-spec-change-requests/46-09-collaboration-and-hub.md

BUILD (dev-env Hub, Genesis Hub application only):
A. GH Story Item — three new item_type values: spec_ref, answer, change.
   - GH_casUpsert story branch: explode `spec_refs` / `answers` / `change_log` (arrays of opaque strings) into
     GH Story Item rows exactly like acceptance_criteria / questions / labels (position = array index, atomic
     with the story write). PRESENT key → replace that type's rows ([] clears). ABSENT key → leave that type's
     rows untouched (mixed-version teams). Do NOT change how the existing three types behave; tell me what that
     behaviour is for an absent key.
   - GH_reassembleStoryItems / GH_recordToJson story branch: always return the three new arrays,
     position-ordered, [] when there are no rows. Never parse/trim/re-encode an element.
   - Extend any constant/validation that lists the allowed item_type values.
B. New record type GH Spec Change Request (kind `spec_change_request`) per §3.1 of the spec: DATABASE
   (jdbc/Appian), PK id, syncUuid unique, the 20 wire keys (opened_at / closed_at as payload-preserved TEXT),
   security mirroring GH Stage Artifact, associated with the app, optional relationship to GH Feature.
   - Additive kind-branches (before `default`, existing branches untouched): GH_casUpsert (stage_artifact-shaped
     attribution, CAS 409, GH Change Log row in the same batch), GH_recordToJson (the 20-key projection),
     GH_queryRecords (get + list).
   - GH_records_upsert Web API: append "spec_change_request" to its inline kind allow-list (the ONLY Web API edit
     allowed; Designer if MCP can't edit the body). No new Web API objects.
C. Verify, change only if needed (and report): the artifact blob APIs accept the key `<feature_sync_uuid>:cr-<nn>`;
   POST /activity accepts ttl_seconds 86400; /changes emits the new kind.

VALIDATE (live, as the GH Service Account over the real Web APIs — extend the 36-06 / wiki harness):
- story_with_trace.json steps 1→3 byte-for-byte (incl. the absent-key-preserves rule and [] clearing), stale 409.
- spec_change_request.json: applied create 201 / GET byte-for-byte / update 200 / stale 409; discarded with
  result_revision_no null reading back null; /changes rows; blob 201 → 200 unchanged → GET bytes + hash; also a
  ~1 MB document blob.
- Regression: every existing kind (story's original arrays incl. empty [], stage_artifact, wiki_page,
  wiki_entry), contract_version still "1.0.0", unauthenticated → 401.
- Clean up the validation rows afterwards (change-log rows may stay — append-only feed).

RULES:
- Additive only. Never modify or delete existing records, fields, rules' existing branches, or Web APIs beyond the
  one allow-list edit. Ask before anything destructive or anything that touches existing data.
- Do not bump contract_version (the addition is backward-compatible).
- If the spec is impossible or ambiguous in Appian (e.g. an Integer null that can't read back as null, a text
  tier limit, the blob-key validation), STOP and report the exact constraint + your proposed resolution instead of
  inventing a different contract.

REPORT BACK (and record it):
- Replace the BUILD STATUS line at the top of spec-change-contract-addition.md with the as-built summary.
- Add a "SPEC CHANGE REQUEST ADDITION (Phase 46-09) — BUILT + LIVE-VALIDATED" section to
  progress/phase-36-genesis-hub-appian-app.md: record type UUID + table, every field UUID, the relationship
  UUIDs, security groups, each rule's new version, the Web API edit, harness N/N with the evidence per check,
  the existing absent-key behaviour of the original three story arrays, and every deviation (flagged).
- Push project-tracker (stage only those genesis/… paths; `git pull --rebase` then push; verify the remote HEAD).
- Give the human a short summary: built / validated N/N / deviations / anything Genesis must adapt to.
```

## Checklist for the human

- [ ] Paste the block above into the Appian agent session (it needs Dev-MCP write access to the dev env + the GH
      service-account key for the harness).
- [ ] When it reports back: share the summary here. The genesis side will adapt to any reported deviation
      (e.g. Integer null → 0, a different absent-key behaviour) before the genesis bindings are committed.
- [ ] The two-instance live check (main applies a CR, userb sees it) needs the fleet updated — planned for 46-10
      acceptance, not mid-phase.
