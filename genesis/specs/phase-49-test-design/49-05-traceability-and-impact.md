# 49-05 — Traceability maintenance and the test impact engine

> **Status:** SPEC-DRAFTED 2026-10-26. Repo: **genesis** (backend services; routes in 49-06). Parent:
> `specs/phase-49-test-design.md`. Decisions: 49-01 D5–D10; F4–F8; R1–R3, R7.

## 1. Goal

Keep test↔object links current without agents, and answer "which tests does this change put at risk?". One service
module `genesis/genesis/services/testimpact.py` (R6) with four parts: object resolution, the implementation linker
(D7), the sync resolver (F6) + startup reconcile (R7), and the impact engine (D8/D9). All program code, all
idempotent, blocking DB work off the event loop (L-026).

## 2. Object resolution — `resolve_object(app_uuid, ref) -> LinkRef` (R3)

`ref = {uuid?, name, type}` from an agent or the user. Rules, in order:
1. `uuid` given and a **current** `kb_objects` row exists for `(app_uuid, uuid)` → resolved; take name/type from that row
   and `diff_hash_at_link` = its `diff_hash`.
2. Else an **exact** (case-insensitive, trimmed) `name` + normalized `type` match among current rows → resolved (if
   exactly one match; several → unresolved, ambiguity is not guessed).
3. Else **unresolved**: keep `name` + `type`, `object_uuid = NULL`, `diff_hash_at_link = NULL`.

Type normalization reuses the Phase-48 normalizer (`normalize_object_type`, `genesis/genesis/kb/object_types.py`), so
"Interface"/"interface"/the raw Appian type name compare equal. A hallucinated UUID can never become a resolved link.

## 3. Implementation linker — `link_implemented_objects(story_id)` (D7, F5)

1. Collect the story's changed objects: `wiki_object_entries` joined to `wiki_object_pages` where `story_key =
   kb_stories.key` (or `story_sync_uuid` = the story's `sync_uuid`), `change_kind` ∈ created · updated (deprecated
   objects too — a deprecation is a change). Fallback when no wiki entries exist: the copied `implementation.json`
   in the story-stage artifact dir (`objects[]` with `status == "ok"` and a `uuid`).
2. For every **non-retired** test case linked to the story (`kb_test_case_stories`), for every changed object:
   resolve an **unresolved** link of that case with the same name + type (set uuid + `diff_hash_at_link`, keep origin);
   otherwise add a link with origin `implementation`. Existing resolved links are left alone (their `diff_hash_at_link`
   is **not** refreshed — the object changed, so the case is rightly *suspect* until reviewed or run).
3. Return counts `{resolved, added}`; log them.

Triggers: `StoryImplementationFinalizer._finalize` after the successful `submit-review` transition
(`genesis/genesis/chat/story_implementation_finalizer.py:112-162`) — best-effort, a failure is logged loudly and never
blocks the lane move (L-058); test-design Finalize and top-up apply for already-implemented stories (49-04 §5–§6);
startup reconcile (§4).

## 4. Sync resolver + startup reconcile — `resolve_unresolved(app_uuid)` / `reconcile_all()` (F6, R7)

- `resolve_unresolved(app_uuid)`: for every unresolved link of a non-retired case in the app, apply §2 rule 2; set uuid +
  `diff_hash_at_link`, origin stays (the origin records who *proposed* the link; add origin `sync` only for links this
  step creates — none today, reserved).
- Trigger: a run observer on `run.final` (status done) of workflow `sync-application`
  (`genesis/genesis/services/application_sync.py:28`), reading `app_uuid` from the run inputs; plus at app startup.
- `reconcile_all()` at startup: `resolve_unresolved` for every app with test cases + `link_implemented_objects` for every
  linked story whose implementation stage is completed. Idempotent; bounded by indexes; logs a summary.

## 5. Impact engine — `impact(app_uuid, changed, *, max_hops=2) -> ImpactResult` (D8, D9)

**Inputs** (`changed` is built by one of three resolvers):

| Source | Resolver | Changed set |
|---|---|---|
| objects | `changed_from_objects(app_uuid, uuids)` | the given uuids (must be current rows; unknown → reported) |
| story | `changed_from_story(story_id)` | the objects of §3 step 1 for that story |
| sync | `changed_from_sync(app_uuid, sync_id)` | rows with `valid_from_sync = sync_id` (added if no earlier row for the uuid, else modified) + uuids whose row has `valid_to_sync = sync_id` and no successor (**removed**). Sync must be `status` done for the app. |

**Walk:** build the inbound adjacency once per call from **current** `kb_dependencies` (`valid_to_sync IS NULL`)
for the app — reuse the adjacency helper behind `get_transitive_dependencies` (`genesis/genesis/kb/_graph_reads_mixin.py:18-31`)
but **without** the 200-object cap; BFS from every changed uuid to `max_hops` (clamped 1–5), recording the minimum hop
per reached uuid and one example path (changed object → … → reached object).

**Selection:** every link in `kb_test_case_objects` with `object_uuid` in the reached set (hop 0 = direct), case not
retired, link state not *removed* — except R1: for the **sync** source, links to objects **removed** in that sync are
direct hits labelled `object_removed`. Unresolved links never match. A case's hop = the minimum over its links.

**Roll-up (D6):** affected case → every non-retired scenario containing it (scenario `hop` = min of its affected
cases) → the suite (feature). Order: direct before indirect, then priority (high → low), then key.

**Result shape:** `{app_uuid, source, max_hops, changed: [{uuid, name, type, change: added|modified|removed|picked}],
unknown: [...], suites: [{feature_id, feature_name, cases_affected, scenarios: [{id, key, title, hop,
cases: [case_key…]}]}], cases: [{id, key, title, priority, type, status, feature_id, hop, via: [{changed_uuid,
linked_uuid, path: [names]}]}], totals: {suites, scenarios, cases, direct, indirect}}`. Computed on demand, nothing
stored (D9).

**Sync picker helper:** `list_syncs(app_uuid, limit=20)` → done syncs newest first with `objects_added/modified/removed`
from `kb_syncs` (m0007).

## 6. Tests

Resolution: uuid current → resolved; hallucinated uuid → falls to name match; ambiguous names → unresolved; type
variants normalize. Linker: resolves a matching unresolved link, adds missing ones, skips retired cases, leaves
resolved links' hashes untouched, wiki-less fallback to `implementation.json`, idempotent on a second call, finalizer
hook failure doesn't block the lane move. Sync resolver: resolves after a KB row appears; observer ignores other
workflows; startup reconcile idempotent. Impact: direct vs 1-hop vs 2-hop on a hand-built graph; cycles terminate;
depth clamp; retired cases/scenarios excluded; removed-object rule per source (R1); scenario/suite roll-up and
ordering; sync change classification (added/modified/removed) on SCD-2 fixtures that use real row shapes (L-079: hash
changes only when content changes); **performance**: a 2 500-object / 10 000-edge synthetic KB with 1 000 links
answers a 3-hop query in < 1 s on the dev machine (record the figure in As built).

## Context manifest

```toml
areas    = ["kb-sync", "stories-workbench"]
adrs     = ["ADR-030", "ADR-036", "ADR-037", "ADR-047", "ADR-050", "ADR-068", "ADR-070", "ADR-074"]
lessons  = ["L-026", "L-032", "L-034", "L-058", "L-061", "L-077", "L-079", "L-083"]
code     = ["genesis/genesis/services/testimpact.py", "genesis/genesis/kb/_graph_reads_mixin.py", "genesis/genesis/kb/object_wiki.py",
            "genesis/genesis/kb/testdesign.py", "genesis/genesis/chat/story_implementation_finalizer.py",
            "genesis/genesis/services/application_sync.py"]
docs     = ["tracker:specs/phase-49-test-design/49-01-findings.md", "tracker:specs/phase-49-test-design/49-02-data-model.md"]
upstream = ["49-02"]
```
