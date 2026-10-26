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

## As built (genesis-dev, 2026-10-26)

**Commits:** genesis `454db1f`, "feat(kb): 49-05 test traceability + impact engine…" (base `b9e9487`, the 49-02 commit).
The commit is local only; nothing was pushed or tagged.

**Changed**
- `genesis/services/testimpact.py` (new) adds `TestImpactService` with:
  - resolution: `resolve_object` and `resolver()`
  - the D7 linker: `implemented_objects`, `link_implemented_objects` and `link_feature_implemented`
  - sync handling and reconcile: `resolve_unresolved` and `reconcile_all`
  - impact: `changed_from_objects`, `changed_from_story`, `changed_from_sync`, `list_syncs` and `impact`

  The file also adds `SyncLinkObserver`, the errors `ImpactNotFoundError` (→ 404) and `ImpactConflictError` (→ 409), and
  the `ChangedSet` / `ChangedObject` TypedDicts. `services/__init__.py` exports these.
- `kb/_graph_reads_mixin.py`: the adjacency builder is now the module-level `current_adjacency(conn, app_uuid,
  direction)`. `KbGraphReadsMixin._adjacency` delegates to it, so behaviour is unchanged. The impact walk uses it with
  no 200-object cap.
- `kb/testdesign.py`: two new helpers that run inside the caller's transaction, `_resolve_object_link` and
  `_delete_object_link`. Both touch only rows where `object_uuid IS NULL`. Together with `_link_object` they are now the
  only code that writes `kb_test_case_objects` (review m4).
- `chat/story_implementation_finalizer.py`: after the `submit-review` move it calls `_link_tests(story_id)`. This is
  best-effort, and a failure is logged with `exc_info`. The constructor takes an optional `test_impact=` (the shared
  instance).
- `api/app.py`: builds one `TestImpactService` (`app.state.test_impact`), attaches `SyncLinkObserver`, passes the
  service to the finalizer, and adds a startup hook that runs `await asyncio.to_thread(test_impact.reconcile_all)`
  (L-026). It also adds a module logger.

**Tests:** `tests/test_test_impact.py` has 44 tests and covers every §6 item. The genesis suite is at **1266 passed**
(was 1222). `ruff check genesis tests/test_test_impact.py` is clean. **Performance:** a 3-hop impact query over 2 500
objects, 10 000 edges and 1 000 links takes **21 ms** on the dev machine (the reviewer measured 19 ms; the limit is 1 s).

**Review:** genesis-review, `reviews/49-05-review.md`. Round 1 was **SHIP** with minors m1–m4 and nits n1–n5. I fixed
m1, m4, n1 and n5. Round 2 was **SHIP** and raised r2-n1 and r2-n2. I fixed both after round 2: `merged` now counts
deleted rows, and a test covers the resolve-one-spelling-and-drop-the-other branch. That last change was not
re-reviewed.

**Decisions / deviations** (no ADR deviation):
1. A sync counts as "done" when `kb_syncs.status = 'succeeded'`, the only success value `KbStore.finish_sync` writes.
   This applies to both `changed_from_sync` and `list_syncs`. `list_syncs` also returns `hub-pull` syncs, with their
   `kind`.
2. The linker passes every changed object through §2 resolution. A wiki or `implementation.json` uuid becomes a resolved
   link only when the KB has a current row for it. A NEW object that has not been synced stays an **unresolved** link
   (name + type, origin `implementation`), and the sync resolver resolves it later. Storing the uuid directly would make
   the link read as *removed* under 49-02's `object_link_state`, and §2 forbids uuids the KB has not confirmed.
3. Resolving a link (linker or sync resolver) also copies the KB row's name and type, the same as rule 1, and keeps the
   origin. An unresolved link that duplicates the same object on the same case is deleted (merged). That happens when
   the case already has the resolved link, or when there are two spellings such as "Foo" and "foo".
   `link_implemented_objects` returns `{resolved, added, merged}` (the spec's `{resolved, added}` plus `merged`).
   `resolve_unresolved` returns `{resolved, merged}`.
4. Matching is name `strip().casefold()` plus `normalize_object_type`. Two types the normalizer doesn't know (both
   `other`) compare by their squashed raw text, so "Widget" never matches "Gadget".
5. `resolver()` returns a caching `ObjectResolver` that loads each app's current objects once. 49-04 should pass
   `resolve_object=svc.resolver()` to `create_from_design` and `apply_topup`.
6. Ordering follows §5 literally: direct before indirect, then priority, then key. Indirect hops are not sub-ordered by
   hop. Scenarios sort by (indirect?, key) and suites by (indirect?, feature name).
7. Fields added to the §5 result: `hop` on suites, `hop` and `object_removed` on each `via` entry, and `object_removed`
   on cases (the R1 label).
8. For the sync source, an object removed in that sync is a hop-0 hit (R1). For the other sources, a link whose object
   has no current row is excluded (F8). `changed_from_story` keeps not-yet-synced objects in `changed` (they reach
   nothing), and `unknown` is used only by the `objects` source.
9. Write transactions take the lock with `BEGIN IMMEDIATE` at the start. 49-02 used a no-op UPDATE for the same purpose.
10. `link_feature_implemented(feature_id)` runs the linker for the feature's stories that have test cases and a
    completed `implementation` story stage. 49-04 calls it after Finalize and after top-up apply. `reconcile_all` uses
    the same query for every app.

**Hand-offs**
- **49-04:** use `svc.resolver()` as `resolve_object`, call `link_feature_implemented(feature_id)` after Finalize and
  after top-up apply, and run both off the event loop.
- **49-06:** map `ImpactNotFoundError` → 404 and `ImpactConflictError` → 409. A non-`objects|story|sync` source is a
  `ValueError` → 422. Mirror the added result fields (decision 7) in `web/src/types` and the fixtures (L-011). Call
  `impact` and `list_syncs` via `asyncio.to_thread`. Review **m3**: give the sync resolver an on-demand path, a
  best-effort `resolve_unresolved(app_uuid)` on the impact or suite read, because today its only recovery is at
  startup (L-058). Review **m2**: KB snapshots pulled from the Hub (`hub-pull`, `kb/store.py:363`) never trigger the
  resolver. §4 names only `sync-application`, so either call it after a successful hub-pull apply or record it in the
  backlog. Review **n2**: `changed_from_sync` labels an object that was removed and later re-added as `modified`; say so
  in the UI copy.
- **genesis-docs:** `context/areas.toml` maps `genesis/services/testimpact.py` and `genesis/kb/_graph_reads_mixin.py`
  to no area, so `genesis-ctx check` missed the kb-sync ADRs and lessons for them. Suggested mapping: kb-sync and
  stories-workbench.
- **Pre-existing, not changed:** `StoryImplementationFinalizer.reconcile()` is never called at startup (`app.py` only
  reconciles the supervisor, the stage finalizer and the design finalizer). The board GET recovery covers it, and
  `reconcile_all` covers the test-link part.
- Review **n3**: serving waits for the startup reconcile. The work is bounded and fast; if it grows, make it a
  background task.

**Lesson candidates**
- A "resolve by uuid" step must not trust a uuid the local KB doesn't confirm. Do that check before you store a link,
  or derived state turns a fresh, correct link into *removed*. Keep the link unresolved by name + type until a sync
  provides the row.
- When a service writes rows that a store owns, route every write through the store's in-transaction helpers. A second
  hand-written INSERT drifts, for example when a later Hub publish expects the store's columns (review m4, the L-085
  pattern).

**Code-map changes:**
- `services/` gains `testimpact.py`: `TestImpactService` (resolution, D7 linker, sync resolver, startup reconcile, impact
  engine) and `SyncLinkObserver`.
- `kb/_graph_reads_mixin.py` exports `current_adjacency`.
- `kb/testdesign.py` gains `_resolve_object_link` and `_delete_object_link`.
- `chat/story_implementation_finalizer.py` runs the D7 linker after submit-review.
- `api/app.py` wires `app.state.test_impact`, the sync observer and a startup `reconcile_all`.
