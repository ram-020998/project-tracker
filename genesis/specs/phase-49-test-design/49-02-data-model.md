# 49-02 — Data model: test suites, scenarios, cases, links, ids and lifecycle

> **Status:** SPEC-DRAFTED 2026-10-26. Repo: **genesis** (backend). Parent: `specs/phase-49-test-design.md`.
> Decisions: 49-01 D2–D7, D10–D12, D15; F8–F10; R2, R6. One migration **m0025** (DB 24 → 25).

## 1. Goal

The persistent model every other sub-spec builds on: seven tables, two id sequences, one repository
(`TestDesignStore`), the test lifecycle machine, and the fingerprint helpers. No HTTP, no UI, no workflow here.

## 2. Migration m0025 `test_design`

New file `genesis/genesis/db/migrations/m0025_test_design.py`, appended to `MIGRATIONS`
(`genesis/genesis/db/migrations/__init__.py:34`). Idempotent (`CREATE TABLE IF NOT EXISTS`, `INSERT OR IGNORE`).
"Collab columns" below = `sync_uuid TEXT` (unique index), `row_version INTEGER NOT NULL DEFAULT 0`,
`owner_username TEXT`, `team_uuid TEXT`, `published_by TEXT`, `published_at TEXT`, `published_version INTEGER` — the
m0019/m0021 pattern, unused this phase but present so Hub sync is additive later (D12). Every table has
`created_at`/`updated_at TEXT NOT NULL` unless noted.

| Table | Columns (besides id, timestamps, collab columns) | Keys / FKs |
|---|---|---|
| `kb_test_suites` | `feature_id`, `title`, `description`, `finalized_at` (the one-time marker, D11), `source_stage_id` (the `test_design` stage row), `upstream_json` (story fingerprints + spec version the run read) | `feature_id` UNIQUE, FK → `kb_features` ON DELETE CASCADE (F9, ADR-042) |
| `kb_test_cases` | `suite_id`, `key` (`TC-000001`), `title`, `gherkin_json` (`{"given":[…],"when":[…],"then":[…]}`), `test_type` ∈ positive·negative·boundary·end-to-end, `priority` ∈ high·medium·low, `status` ∈ draft·ready·retired (default `draft`), `automation_status` (default `not-automated`), `origin` ∈ design·topup·manual, `position`, `retired_at` | FK `suite_id` → `kb_test_suites` CASCADE; `key` UNIQUE; index `(suite_id, position)` |
| `kb_test_scenarios` | `suite_id`, `key` (`TS-000001`), `title`, `description`, `status` (as cases), `origin`, `position`, `retired_at` | FK `suite_id` CASCADE; `key` UNIQUE |
| `kb_test_scenario_steps` | `scenario_id`, `case_id`, `position` (no `updated_at`; + `sync_uuid`) | FK `scenario_id` CASCADE; FK `case_id` → `kb_test_cases` ON DELETE CASCADE — D2's "no delete while referenced" is enforced in the **store** (`delete_case`), not by `RESTRICT`, because SQLite applies `RESTRICT` the moment a case row goes, which would break the feature → suite cascade (F9); UNIQUE `(scenario_id, position)`; index `case_id`. The same case may appear twice in one scenario. |
| `kb_test_case_stories` | `case_id`, `story_id`, `story_key` (denormalized `GNS_`), `fingerprint` (§5), `origin` ∈ design·topup·manual, `linked_at`, `reviewed_at` (+ `sync_uuid`) | FK `case_id` CASCADE; FK `story_id` → `kb_stories` ON DELETE CASCADE (F9); UNIQUE `(case_id, story_id)`; index `story_id` |
| `kb_test_case_objects` | `case_id`, `app_uuid`, `object_uuid` (NULL = unresolved, D5), `object_name`, `object_type`, `diff_hash_at_link` (NULL while unresolved), `origin` ∈ design·implementation·sync·manual, `linked_at`, `reviewed_at` (+ `sync_uuid`) | FK `case_id` CASCADE; partial UNIQUE `(case_id, app_uuid, object_uuid) WHERE object_uuid IS NOT NULL`; partial UNIQUE `(case_id, app_uuid, object_name, object_type) WHERE object_uuid IS NULL`; index `(app_uuid, object_uuid)`. **No FK to `wiki_object_pages` or `kb_objects`** (D5; `kb_objects` is SCD-2). |
| `kb_test_topups` | `feature_id`, `stage_id`, `run_id`, `status` ∈ running·ready·applied·discarded·failed, `target_story_ids` (JSON), `proposals_json`, `decisions_json`, `row_version` | FK `feature_id` CASCADE; index `(feature_id, status)` |

Sequences (D4): `INSERT OR IGNORE INTO kb_sequences (name, next_val) VALUES ('test_case', 1), ('test_scenario', 1)`.

## 3. Repository `TestDesignStore` (`genesis/genesis/kb/testdesign.py`)

R6: the module must not be named `test_*.py`. Constructor like `StoryStore` (`Database | str | Path`). All writes in
`self._db.tx()`; all updates CAS on `row_version` (→ `StaleWriteError`, ADR-050/25-08). Sync methods; callers in async
code run them off the event loop (L-026).

| Method | Contract |
|---|---|
| `_next_case_key(conn)` / `_next_scenario_key(conn)` | Mirror `_next_story_key` (`kb/stories.py:48-60`): `INSERT OR IGNORE` the row, `UPDATE … RETURNING next_val`, return `TC-{n:06d}` / `TS-{n:06d}`. Called only inside an open write tx. |
| `get_suite(feature_id)` | The suite row or `None`. |
| `suite_tree(feature_id)` | `{suite, scenarios: [{…, steps:[{position, case_id, case_key}]}], cases: [case_dto…]}` — one call, no N+1 (≤ 5 queries). |
| `create_from_design(feature_id, stage_id, design, *, story_ids_by_key, resolve_object)` | **Atomic** Finalize write (49-04 calls it): creates the suite (`finalized_at` = now), then scenarios and cases with keys allocated in **document order** (F10: scenarios first, then cases by epic, story, position); steps; story links (fingerprint now, origin `design`); object links via the injected `resolve_object` (R3, 49-05). Status **ready** for every record. Raises `AlreadyFinalizedError` if `finalized_at` is set. |
| `apply_topup(topup_id, accepted_refs, …)` | Atomic: creates the accepted proposals (status **ready**, origin `topup`), inserts accepted "add existing case to scenario" steps at the proposed position (shifting later steps), marks the top-up `applied` with `decisions_json`. |
| `create_case(suite_id, fields)` / `create_scenario(suite_id, fields)` | Manual add: status **draft**, origin `manual`, new key. |
| `update_case(case_id, fields, expected_row_version)` / `update_scenario(…)` | Edit title, gherkin, type, priority (cases) or title/description (scenarios). Not `status` (lifecycle only). |
| `set_steps(scenario_id, case_ids, expected_row_version)` | Replace the ordered step list; every case must belong to the same suite and not be retired → `ValueError`. |
| `set_case_stories(case_id, story_ids)` | Replace links; new links get the current fingerprint and origin `manual`; existing links keep theirs. Stories must belong to the suite's feature. |
| `add_case_object(case_id, ref, origin)` / `remove_case_object(link_id)` | Upsert per the unique keys; idempotent. |
| `mark_reviewed(case_id)` | F7: refresh every link's `fingerprint` (story) and `diff_hash_at_link` (current `kb_objects` row), set `reviewed_at`. |
| `delete_case(case_id)` / `delete_scenario(id)` | Only `draft` and (cases) not referenced by any step → else `ConflictError` (D15). |
| `cases_for_story(story_id)`, `cases_for_object(app_uuid, object_uuid)` | Read helpers for 49-06; return the same `case_dto` as `suite_tree` (L-039: one builder). |
| `set_status(entity, id, status)` | Persistence primitive the lifecycle writes through (membership-validated only). |

`case_dto` = all columns + `gherkin` (parsed), `stories: [{story_id, story_key, title, needs_review}]`,
`objects: [{link_id, object_uuid, object_name, object_type, origin, state}]` with `state` ∈ resolved · unresolved ·
suspect · removed, `needs_review` (any story link), `scenario_keys` (non-retired scenarios using it). Derived on read
(R2, §5).

## 4. Lifecycle (ADR-050)

- `EntityKind.TEST_CASE = "test_case"`, `EntityKind.TEST_SCENARIO = "test_scenario"` (`genesis/genesis/domain/enums.py`);
  `TestStatus` enum draft · ready · retired.
- `TEST_TRANSITIONS` (`genesis/genesis/domain/transitions.py`): `(draft, "approve") → ready`, `(ready, "retire") →
  retired`, `(draft, "retire") → retired`, `(retired, "restore") → ready`. `restore` keeps the key (D4).
- Preconditions: `retire` of a **case** used by a non-retired scenario → refused with a message naming the scenarios
  (remove it from them first); `approve` of a scenario requires ≥ 1 step.
- `build_test_lifecycle_service(store, emit)` in `genesis/genesis/domain/lifecycle.py` (model on
  `build_story_lifecycle_service`, `lifecycle.py:254-282`); transitions are audited in the m0013 table.
- `retired_at` set on retire, cleared on restore. Retired records are excluded from impact and coverage (D15).

## 5. Fingerprints and derived states (R2)

- `story_fingerprint(story) = sha256(normalize(title) + "\n" + "\n".join(normalize(ac) for ac in acceptance_criteria))[:16]`
  where `normalize` = collapse whitespace + strip (same idea as `spec_clauses` fingerprints). Lives in
  `kb/testdesign.py`; unit-tested with the real AC shape (L-083).
- Story link `needs_review` = `link.fingerprint != story_fingerprint(current story)`.
- Object link `state`: `object_uuid IS NULL` → **unresolved**; no current `kb_objects` row (`valid_to_sync IS NULL`) for
  `(app_uuid, object_uuid)` → **removed** (F8); current `diff_hash != diff_hash_at_link` → **suspect**; else
  **resolved**.

## 6. Tests

Migration: fresh DB → v25 with all tables/indexes/sequence rows; upgrade from v24 preserves existing rows
(genesis-db-migration skill). Store: key allocation (monotonic, never reused after delete, concurrent tx serialized);
`create_from_design` atomic (a failure mid-way leaves nothing) and refuses a second call; document-order ids; a
referenced case refuses `delete_case` while a feature delete still cascades everything; draft-only delete; CAS conflict → `StaleWriteError`; `set_steps` cross-suite/retired refusal;
cascade on feature delete and on story delete (F9); derived states for each object `state` and `needs_review`;
`suite_tree` query count bounded; list and single-get DTOs identical (L-039). Lifecycle: every allowed/refused
transition incl. the retire-while-referenced precondition; audit row written.

## Context manifest

```toml
areas    = ["db", "stories-workbench"]
adrs     = ["ADR-030", "ADR-042", "ADR-050", "ADR-060", "ADR-063", "ADR-070", "ADR-072", "ADR-075"]
lessons  = ["L-004", "L-026", "L-039", "L-083"]
code     = ["genesis/genesis/db/migrations/**", "genesis/genesis/kb/testdesign.py", "genesis/genesis/kb/stories.py",
            "genesis/genesis/domain/**"]
docs     = ["tracker:specs/phase-49-test-design/49-01-findings.md"]
upstream = []
```

## As built (genesis-dev, 2026-10-26)

**Commits:** genesis `b9e9487` — "feat(db): 49-02 test design data model — m0025, TestDesignStore, TC-/TS- ids, test
lifecycle" (base `df9011dc`). Local only; not pushed or tagged.

**Changed**
- `genesis/db/migrations/m0025_test_design.py` (new; Migration object `testdesign`, name `test_design`, version 25) +
  `migrations/__init__.py`. Seven tables as §2, the partial unique indexes, a unique `sync_uuid` index per table, and
  the two `kb_sequences` seed rows. Enum columns are validated in the store, not by `CHECK` (the same approach as
  `kb_feature_stages.status`), so part 2 can add values without rebuilding a table.
- `genesis/kb/testdesign.py` (new): `TestDesignStore`, `LinkRef`, `ObjectResolver`, `story_fingerprint`,
  `object_link_state`.
- `genesis/domain/`: `EntityKind.TEST_CASE/TEST_SCENARIO`; `LifecycleState.READY/RETIRED`; `TestStatus`;
  `TEST_TRANSITIONS` + the per-kind preconditions/reasons + `TEST_FILTERING_PRECONDITIONS`; `build_test_lifecycle[_service]`;
  `ConflictError`; `AlreadyFinalizedError(what=)`. `LifecycleService` gets two additive features:
  `EntityLifecycle.context`, a store-derived precondition ctx that overrides the caller's ctx so it cannot be bypassed,
  and callable `precondition_reasons`.
- Tests pinned to schema version 24 bumped to 25 (9 files; the synthetic next migration in `test_db.py` → 26).

**Tests:** `tests/test_test_design_store.py` has 35 tests covering every §6 item, plus the review regressions. The
genesis suite is at **1222 passed** (was 1187). `ruff check genesis` is clean.

**Review:** genesis-review, `reviews/49-02-review.md`. Round 1 was NEEDS_CHANGES (M1, M2, m1–m4, n1–n4). Round 2 was
**SHIP**, and it raised a new m5, which is fixed in the same commit.

**Decisions / deviations** (no ADR deviation):
1. The test states live on `LifecycleState`, because the transition tables are typed on it. `TestStatus` is the store's
   validation set, and a test pins `TestStatus ⊆ LifecycleState`.
2. Preconditions come from the store (`TestDesignStore.lifecycle_context`), so no caller can skip them. No test
   precondition filters `allowed()`, so Retire, Approve and Restore stay offered and a refusal carries the reason
   (review M2; 49-06/07/08 rely on this).
3. Added precondition: restoring a scenario is refused while any of its step cases is retired (review M1). `set_status`
   re-checks both invariants after its UPDATE, inside the same transaction. `set_steps`, `delete_case` and `apply_topup`
   take the write lock before they validate (review m4/m5).
4. Step `position` is **1-based**; case and scenario `position` is 0-based.
5. `create_from_design(feature_id, stage_id, design, *, story_ids_by_key, resolve_object, upstream=None)` is rigid. An
   unknown story key, an unknown step ref, a scenario with no steps, or a bad type/priority/gherkin raises `ValueError`
   and nothing is written. Objects are resolved before the transaction opens (`resolve_object(app_uuid, ref) -> LinkRef`).
   F10 order: scenarios in document order, then cases sorted by (epic position, first linked story's position,
   document index). Returns `{suite_id, finalized_at, case_keys, scenario_keys}` (ref → key). The suite title is the
   feature name.
6. Methods added beyond §3: `get_case`, `get_scenario` (single-gets, L-039), `create_topup`, `get_topup`,
   `set_topup_status` (edges running → ready|failed, ready → discarded; `applied` only through `apply_topup`).
   `apply_topup(topup_id, accepted_refs, *, story_ids_by_key, resolve_object, decisions=None)` defaults
   `decisions_json` to `{accepted, rejected}` and returns `{case_keys, scenario_keys, added_steps}`.
7. Object links created by a top-up keep origin `design`, because the object-origin set has no `topup`.
8. `cases_for_story` and `cases_for_object` leave out retired cases unless `include_retired=True` (D15).
9. `story_fingerprint` reuses `spec_clauses.normalize_text` (NFKC + whitespace collapse), so a newline-only change to an
   acceptance criterion does not flag the case.
10. `add_case_object` follows its unique keys strictly. It does not turn an unresolved link into a resolved one; that
    is 49-05's linker.

**Hand-offs**
- **49-04 (m1):** after dropping steps that point at dropped cases, also drop (and report) any scenario left with no
  steps. Otherwise `create_from_design` refuses the whole Finalize.
- **49-03 (decision 4):** the top-up `add_step.position` is 1-based. Say so in the workflow prompt.
- **49-06 (n3):** if `ScenarioDto.steps` gains `case_title`/`case_status`, add them in both `suite_tree` and
  `get_scenario`; the equality test will catch a drift. Map `ConflictError` to 409.
- **genesis-docs (n4):** `context/areas.toml` maps `genesis/domain/**` and `genesis/kb/testdesign.py` to no area, so
  `genesis-ctx check` misses ADR-050 for them.

**Lesson candidates**
- With Python `sqlite3`'s default transaction control, the transaction opens at the first DML. A `with db.tx()` block
  that SELECTs to validate and then writes is not atomic against a concurrent writer. Put the CAS write first, or use a
  no-op UPDATE to take the lock, then validate (review m4/m5).
- A module or symbol named `test_*` (here, the Migration object) can be collected by pytest once a test imports it.
  Name it differently and set `__test__ = False` on `Test*` classes (R6).

**Code-map changes:** `db/migrations/` adds m0025 `test_design` (7 tables + 2 counters; DB → v25). `kb/` adds
`testdesign.py` (`TestDesignStore`). `domain/` adds the test kinds, `TEST_TRANSITIONS`, `build_test_lifecycle_service`
and `ConflictError`.
