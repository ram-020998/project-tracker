# Review 49-05 — base b9e9487 (genesis-review, 2026-10-26)

Scope: the **uncommitted** working tree of `genesis` on top of `b9e9487` (49-02, HEAD; `git rev-parse` confirms it).
`git diff b9e9487` (4 modified files) + the untracked `genesis/services/testimpact.py` and `tests/test_test_impact.py`.
Spec: `49-05-traceability-and-impact.md`; upstream 49-02 As built read; 49-01 findings D7–D9, F5–F8, R1–R3, R7 read.

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings` | **1264 passed** in 314 s (49-02 was 1222; +42 = the new file) |
| `.venv/bin/ruff check genesis tests/test_test_impact.py` | All checks passed |
| `pytest tests/test_test_impact.py` | 42 passed in 3.95 s |
| perf (`-s`, `test_impact_performance_on_a_large_kb`) | 3-hop impact, 2 500 objects / 10 000 edges / 1 000 links: **19 ms** (43 cases); dev recorded 21 ms; spec bound < 1 s |
| web lint/typecheck/vitest/build, kiro-agent-sdk pytest | N/A — no `web/**` or SDK file changed |

## Checklist

`genesis-ctx check` mapped the changed files to api, chat, stories-workbench (+ always-on release-ci, security).
`services/testimpact.py`, `services/__init__.py` and `kb/_graph_reads_mixin.py` map to **no area** (decision 10), so the
manifest's kb-sync rules (ADR-030/036/037/047/070/074, L-026/032/077/079) are checked below by hand as well.

### ADRs
- [N/A] ADR-001 — no graph/orchestration change; all new code is deterministic program code.
- [N/A] ADR-002 / ADR-004 / ADR-020 — no ACP/MCP injection touched.
- [N/A] ADR-005 / ADR-029 — no registry change.
- [OK] ADR-010 — nothing written to run state; impact is computed on demand and nothing stored (`impact`, testimpact.py §5, D9).
- [N/A] ADR-011 — no agent node added.
- [OK] ADR-012 — the app process imports no workflow Python; `SyncLinkObserver` reads only `rec.workflow_id`/`rec.inputs`.
- [N/A] ADR-021 — no write/deploy MCP node.
- [OK] ADR-023 — the service is wired into the existing FastAPI app (`app.py` +151–157); no server added.
- [N/A] ADR-026 / ADR-028 / ADR-043 / ADR-071 — no route or bind change (routes are 49-06).
- [N/A] ADR-027 / ADR-055 — no web change.
- [OK] ADR-030 — SQLite only, through `Database`; public signatures take ids/uuids, not connections.
- [N/A] ADR-031 / ADR-033 / ADR-034 / ADR-045 — the chat-area file touched is the implementation finalizer (program code, not chat).
- [N/A] ADR-032 — no credits (the linker is "no agent, no credits", D7).
- [N/A] ADR-035 — no run inputs.
- [OK] ADR-036 / ADR-037 — reads `kb_objects` / `kb_dependencies` metadata only; no SAIL.
- [N/A] ADR-041 / ADR-042 / ADR-053 / ADR-069 / ADR-073 / ADR-075 / ADR-076 — untouched.
- [OK] ADR-047 — scheduled syncs run `sync-application` (`runtime/sync_jobs.py:137`), so the observer fires for them too.
- [OK] ADR-050 — no status change anywhere in the diff; the finalizer's lane move is unchanged (`_transition` via `LifecycleService`), `_link_tests` runs after it.
- [N/A] ADR-059 / ADR-060 / ADR-061 / ADR-062 / ADR-072 — untouched.
- [OK] ADR-063 / ADR-064 / ADR-065 — no Hub write; new link rows get a `sync_uuid` like 49-02's rows.
- [OK] ADR-068 — nothing mutates an Appian environment; the merge deletes only duplicate *link* rows in `genesis.db`, never an object.
- [OK] ADR-070 — the Object Wiki is read only (`_implemented_objects` SELECT).
- [OK] ADR-074 — `changed_from_sync` follows the SCD-2 rows any sync mode opens/closes; incremental syncs never close, so they report no removals, which is correct.
- [OK] ADR-077 — reviewer used `genesis-ctx`; no bulk docs read; no `--trust-all-tools`.

### Lessons
- [N/A] L-001, L-007, L-016, L-017, L-024, L-041, L-042, L-044, L-045, L-046, L-047, L-069, L-073, L-086 — no chat/ACP/web code.
- [N/A] L-003, L-010, L-018, L-031, L-048, L-068 — no route/SSE/export change.
- [OK] L-004 — data stays in SQLite.
- [N/A] L-019 — no secret writes.
- [OK] L-025 / L-027 — ruff pin unchanged; clean.
- [OK] L-026 — blocking DB work is off the event loop: startup uses `asyncio.to_thread(test_impact.reconcile_all)` (app.py +236); the observer and the finalizer run on the worker reader thread (`RunManager.add_event_observer` docstring, manager.py:83–88); the read-path recovery `reconcile_story_stage` is called from the sync `def get_board` (workbench.py:130), i.e. the threadpool.
- [OK] L-030 / L-051 / L-056 / L-057 / L-087 / L-088 / L-089 — no release in this sub-spec; note for release: the two new files are **untracked** — `git add` them (L-056).
- [OK] L-032 — `_ObjectIndex` keeps the highest-id open row per uuid, matching 49-02's link-state join.
- [OK] L-039 — no list/single-get pair added.
- [OK with minor m3] L-058 — failures are logged loudly (`log.warning(..., exc_info=True)` in `_link_tests`, `SyncLinkObserver._observe`, `reconcile_all`); level-triggered recovery = startup `reconcile_all`, plus the existing on-read `reconcile_story_stage` → `_finalize` → `_link_tests`. The sync resolver has no on-demand path (m3).
- [OK] L-061 — `_link_tests` sits inside `_finalize` after the bound-run and still-in-Implementation guards, so a stale done run cannot trigger it.
- [N/A] L-072 / L-074 / L-085 / L-090 — no Hub pull, board membership, publish hook or table UI.
- [OK] L-077 — no KB merge; read only.
- [OK] L-079 — `test_sync_change_classification_on_scd2_rows` runs real `KbStore.apply` syncs where unchanged objects keep their hash and are not reported.
- [OK] L-083 — fixtures use the real shapes: parser display types ("Expression Rule"), loose agent types ("rule"), real breakdown ACs, real `StoryStore.finalize`, real `ObjectWikiStore` entries, real SCD-2 syncs.

### Spec §6 test list
- [OK] Resolution: current uuid (`test_resolve_current_uuid_takes_the_kb_row`), hallucinated uuid → name → unresolved, ambiguous, type variants (parametrized), closed row, no-name refusal.
- [OK] Linker: resolves + adds + hash untouched + idempotent (`test_linker_resolves_adds_and_leaves_resolved_hashes`), retired skipped, `implementation.json` fallback, by `story_sync_uuid`, finalizer hook + failure-does-not-block.
- [OK] Sync resolver: resolves after a KB row appears, observer filters workflow/status, never raises, startup reconcile idempotent.
- [OK] Impact: direct / 1-hop / 2-hop / 3-hop with path, cycles, clamp, retired cases + scenarios, unresolved never match, roll-up + ordering, scenario min hop, R1 per source, sync classification, story source, perf.

## Dev decisions

1. `SYNC_DONE='succeeded'` — **OK**: `KbStore.finish_sync(sync_id, "succeeded", …)` (kb/store.py:394) is the only success value.
2. Changed objects go through `resolve_object`; an un-synced uuid stays an unresolved link — **OK**. Consistent with R3 and avoids a fresh link reading as *removed* under 49-02's `object_link_state`. `test_linker_keeps_a_not_yet_synced_object_unresolved_then_the_sync_resolves_it` pins it.
3. Resolving overwrites name/type with the KB row; duplicate unresolved link merged — **partly accurate**: true for `resolve_unresolved`, not for the linker (m1).
4. Unknown types compare by squashed raw text — **OK** (`type_key`, `test_unknown_types_compare_by_raw_text`).
5. Ordering — **OK**, matches §5 literally (`_case_order`).
6. Additive fields `hop` / `object_removed` — **OK**; a superset of the §5 shape. 49-06 must mirror them in its DTO.
7. Sync-source removed objects are hop-0 hits; other sources exclude row-less links — **OK**, R1 + F8 (`test_sync_source_lists_removed_objects_as_direct_hits`, `test_objects_source_reports_unknown_and_excludes_removed_objects`).
8. `BEGIN IMMEDIATE` inside `Database.tx()` — **OK**: Python's default (legacy) transaction control opens no implicit transaction before the first DML, so the explicit BEGIN is legal; `tx()`'s `commit()`/`rollback()` close it (database.py:33–42). The early `return counts` in `resolve_unresolved` commits an empty transaction, harmless.
9. No startup reconcile of `StoryImplementationFinalizer` — **OK as stated** (pre-existing; the board GET recovers it, and the recovery now links tests too).
10. Unmapped paths — **confirmed**; a docs hand-off (see below).

## Findings

### Blockers
None.

### Majors
None.

### Minors
- **m1 — The linker does not merge an unresolved duplicate when the case already has the resolved link** (contradicts dev decision 3).
  `_link_one` returns `None` at `if uid and any(r["object_uuid"] == uid …)` before it looks at `matches`, so a case with a
  resolved `uuid-a` link and an unresolved `"vm_score"/"rule"` link keeps both after `link_implemented_objects`. It is
  cleaned up only by a later `resolve_unresolved`, and only when the name + type match is unique in the KB. No data is
  lost, but the case shows a spurious *unresolved* link meanwhile. Fix: when the resolved link exists, delete `matches`
  (count it as merged), or correct decision 3 in the As built. Add a test like `test_resolve_unresolved_merges_into_an_existing_resolved_link` for the linker.
- **m2 — Hub-pulled KB snapshots never trigger the sync resolver.** F6 says "after every successful KB sync"; §4
  narrows the trigger to the `sync-application` observer. With collaboration on, teammates' KB snapshots arrive through
  `KbStore` `hub-pull` syncs (kb/store.py:363–394), which run no workflow. Links to objects a teammate created stay
  unresolved until a local sync or a restart. This follows the spec text, so it does not block. Hand it to 49-06 or the
  backlog: call `resolve_unresolved(app_uuid)` after a successful hub-pull apply. Note that `list_syncs` /
  `changed_from_sync` do include hub-pull syncs (`kind` is returned), which is right for D9 source 3.
- **m3 — The sync resolver's only recovery is at startup (L-058).** If a `sync-application` `run.final` is missed (orphaned
  worker, ADR-012), unresolved links wait for the next restart. L-058 asks for an on-demand path. A cheap one for 49-06:
  have the impact or suite-tree read call `resolve_unresolved` best-effort. It is idempotent and returns early when
  there are no unresolved links.
- **m4 — The link INSERT is duplicated outside its store.** `_link_one` hand-writes the `kb_test_case_objects` INSERT
  twice (columns, `sync_uuid`, timestamps), and `TestDesignStore` already has `_link_object(c, case_id, app_uuid, ref,
  origin, stamp)` (kb/testdesign.py, used by `add_case_object` at :628–634) that runs inside a caller's transaction. Two
  homes for one write will drift. A future Hub publish of test links, for example, would miss these rows (the L-085
  pattern). Reuse the store helper, or move `_resolve_link` / the merge into `TestDesignStore` as well.

### Nits
- **n1** — `_link_one` reports `"added"` even when `ON CONFLICT DO NOTHING` skips the row. The pre-checks make a conflict unreachable today; use `rowcount` so the count stays true if that changes.
- **n2** — `changed_from_sync` labels an object that was removed earlier and is now re-added as `modified` (an earlier row exists). Arguably right; mention it in the 49-06 UI copy or the As built.
- **n3** — The startup hook awaits `reconcile_all` inside `on_event("startup")`, so serving waits for it. The work is bounded and fast, but if it grows, fire it as a background task.
- **n4** — `tests/test_test_impact.py` imports the private `_ObjectIndex` to count loads. Acceptable for this one test.
- **n5** — `StoryImplementationFinalizer` builds its own `TestImpactService` while `app.py` builds another one in `app.state.test_impact`. This is harmless because the service is stateless. The finalizer could take the shared instance.

## Hand-offs
- **genesis-dev:** fix or document m1. m4 is recommended. Remember `git add` for the two untracked files (L-056).
- **49-06:** mirror the additive fields (`hop` on suites, `hop` + `object_removed` on `via`, `object_removed` on cases); map `ImpactNotFoundError` → 404 and `ImpactConflictError` → 409; m2/m3 on-demand resolve.
- **genesis-docs:** `context/areas.toml` should map `genesis/services/testimpact.py` (kb-sync, stories-workbench) and `genesis/kb/_graph_reads_mixin.py` (kb-sync). Today `genesis-ctx check` misses ADR-070/074 and L-026/032/079 for them.

## Verdict: **SHIP**

No blockers or majors, and every applicable gate is green and was re-run by the reviewer. The minors m1–m4 should be
fixed or recorded in the As built before the phase release. m1 is a small, testable fix the dev may fold into the commit.

---

## Round 2 — focused re-check (genesis-review, base b9e9487, working tree still uncommitted)

Scope: the round-1 fixes m1, m4, n1, n5. m2, m3, n2, n3, n4 stay as As-built notes / hand-offs, as stated by the dev.
The two new files are still untracked (`?? genesis/services/testimpact.py`, `?? tests/test_test_impact.py`): `git add`
both before committing (L-056).

### Gates (re-run by the reviewer)
- `.venv/bin/python -m pytest -q -x` → **1265 passed** in 209.92s (matches the dev's claim; only the existing
  `on_event` / SWIG deprecation warnings).
- `.venv/bin/ruff check genesis tests/test_test_impact.py` → **All checks passed!**

### Fix verification
| Item | Status | Evidence |
|---|---|---|
| m1 — linker merges an unresolved duplicate of a resolved link | **FIXED** | `services/testimpact.py` `_link_one`: when the case already has `object_uuid == uid`, every unresolved name/type match is dropped via `TestDesignStore._delete_object_link` and `"merged"` is returned. `link_implemented_objects` returns `{resolved, added, merged}`; `_link_stories` and `reconcile_all` sum it (`linked_merged`, testimpact.py:371-395). Regression test `test_linker_merges_an_unresolved_duplicate_of_a_resolved_link` (test_test_impact.py:282) asserts `merged == 1`, the single resolved `design` link left, and an all-zero second call. Existing linker tests updated to the 3-key shape (lines 214, 222, 239, 249). |
| m4 — link writes have one home | **FIXED** | A case-sensitive grep for `INSERT\|UPDATE \|DELETE` in `services/testimpact.py` finds no SQL writes. Writes go through `TestDesignStore._link_object`, `_resolve_object_link` and `_delete_object_link` (`kb/testdesign.py` diff, +18 lines). Both new helpers carry `AND object_uuid IS NULL`, so they cannot change a resolved link. `_resolve_object_link` refuses a ref without `object_uuid`. Both run inside the caller's `BEGIN IMMEDIATE` transaction. Resolving a row moves it from `ux_kb_test_case_objects_unresolved` to `ux_kb_test_case_objects_resolved` (m0025:142-145). The preceding "no resolved link with this uuid" check means the resolve cannot hit the resolved unique key. |
| n1 — honest "added" count | **FIXED** | `_link_one` compares `c.total_changes` before and after `_link_object`. `Database.tx` yields a raw `sqlite3.Connection` (db/database.py:33), and only that INSERT (`ON CONFLICT DO NOTHING`) runs between the two reads, so a skipped row now returns `None`. |
| n5 — shared service instance | **FIXED** | `StoryImplementationFinalizer.__init__(…, test_impact=None)` uses the injected instance and falls back to a private one. `app.py` builds `TestImpactService` before the finalizer, attaches `SyncLinkObserver`, sets `app.state.test_impact` and passes `test_impact=test_impact`. |

### New findings (round 2)
Blockers: none. Majors: none. Minors: none.

- **r2-n1** — `"merged"` counts (case, object) pairs, not deleted rows. If one case has two unresolved spellings of an
  object it already has resolved, both rows are deleted but `merged` goes up by 1. In the resolve branch, the extra
  spellings (`matches[1:]`) are deleted with no `merged` count at all. The docstring says "unresolved duplicates …
  dropped". Either count the rows or reword the docstring. This only affects the counts in logs and the summary.
- **r2-n2** — No test covers the resolve-then-drop-extra branch of `_link_one` (`matches[1:]`: two unresolved
  spellings of one object, then the linker resolves one and deletes the other). The merge branch and
  `resolve_unresolved`'s merge are covered. Add a one-case test when convenient.

### Carried notes (unchanged from round 1; record them in the As built)
- m2 (Hub-pulled KB snapshots do not trigger the resolver) and m3 (resolver recovery happens only at startup): hand
  off to 49-06 on-demand resolve.
- n2, n3, n4 as written in round 1.
- genesis-docs: the `areas.toml` mapping for `services/testimpact.py` and `kb/_graph_reads_mixin.py`.

## Round 2 verdict: **SHIP**

m1, m4, n1 and n5 are fixed as described, each with matching code and (for m1) a regression test. The full suite
(1265) and ruff are green on the reviewer's re-run. The two new nits do not block. Commit with both untracked files
added.
