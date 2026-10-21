# Review 48-02 — base d6ee6cd → 940deef, repo genesis (genesis-review, 2026-10-21)

Scope: the one local commit `940deef` "feat(api): Object Wiki read API" (6 files, +609, unpushed). Backend only: no web
change, no migration. Spec `48-02-api.md`, umbrella `phase-48-object-wiki-ui.md`, findings `48-01-findings.md` (§2.8, D4/D6/D7).
`genesis-ctx check --since d6ee6cd` mapped the change to the areas api, stories-workbench, release-ci and security.

## Gates (run by the reviewer)

| Gate | Result |
|---|---|
| `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` | **1185 passed** in 148.98s (matches the author's claim) |
| new tests only (`tests/test_object_wiki_api.py tests/test_object_types.py`) | **80 passed** in 3.10s |
| `.venv/bin/ruff check genesis` (+ the two new test files) | **All checks passed!** (ruff 0.15.20, pinned `pyproject.toml:58`) |
| `cd genesis/web && npm run lint && typecheck && test` / `npm run build` | N/A — no `web/**` file in the diff (`git show --stat 940deef`) |
| `git status --short` | clean; the commit holds all 6 files (L-056) |

## Checklist

### ADRs
- [N/A] ADR-011 reliability trio — no agent node or workflow touched.
- [OK] ADR-012 — the app process imports no workflow Python; the new module imports only `fastapi` + `..kb` (`api/object_wiki.py:10-12`).
- [N/A] ADR-021 — no gate, write or MCP node.
- [OK] ADR-023 — plain FastAPI routes on the existing router (`api/app.py:155-157`).
- [OK] ADR-026 — no new bind/listener and no auth surface; local read-only GETs, the same posture as the sibling `applications.py` routes.
- [N/A] ADR-027 / ADR-055 — no web change.
- [OK] ADR-028 — routes are registered on the `/api` router; the tests call `/api/applications/{app}/wiki[/{obj}]` (`test_object_wiki_api.py:_list/_detail`).
- [N/A] ADR-031 / 033 / 034 / 045 — no chat surface.
- [N/A] ADR-035 — no run input files.
- [N/A] ADR-042 / 075 / 076 — no spec/clause code.
- [N/A] ADR-043 — no Lavish.
- [N/A] ADR-047 / 074 — no sync change.
- [N/A] ADR-049 — no navigation change (48-03 owns the tab).
- [OK] ADR-050 — no status transition; the handlers are GET-only and the store methods use only `connect()` + SELECT, never `tx()` (`kb/object_wiki.py` list_objects/get_object).
- [N/A] ADR-059 / 060 / 061 / 062 — no breakdown/finalize/board change.
- [OK] ADR-063 / 064 / 065 — reads only the LOCAL tables, with no Hub call (`api/object_wiki.py` docstring + body); collab is untouched.
- [OK] ADR-068 — read-only; nothing mutates the environment and nothing deletes.
- [OK] ADR-070 — the ledger stays append-only: no write paths are added and the existing methods are unchanged (the diff only appends after `get_page_with_entries`).
- [OK] ADR-071 — `story.id` = `kb_stories.id`, the canonical story page's local id (`_resolve_stories`, `kb/object_wiki.py` ~L318); tested in `test_story_resolution`.
- [OK] ADR-072 — the fixtures use `GNS_<6>` keys; ambiguous pre-ADR-072 keys are handled (decision 2 below).
- [OK] ADR-037 (manifest) — only descriptions and metadata are returned, never SAIL/object code.
- [OK] ADR-030 (manifest) — SQLite only; plain repository signatures.
- [OK] ADR-077 — review run from L0 + check + targeted `lesson` calls; no bulk reads.

### Lessons
- [N/A] L-003 / L-018 — no SSE.
- [OK] L-004 — SQLite read model, no JSON store.
- [OK] L-010 — under `/api`; error bodies are FastAPI JSON `detail`, and the 404 text matches the existing `applications.py:109` wording exactly.
- [OK] L-011 — the contract is fixed here and mirrored in 48-03. **Pending:** spec §7 requires one real JSON sample of each response in **As built**; the spec has no As built section yet (see Minor m4).
- [N/A] L-017 / L-045 — no chat trust.
- [N/A] L-019 — no secret writes.
- [OK] L-025 / L-027 — ruff pinned `==0.15.20`.
- [N/A] L-030 — no web; only relevant at release.
- [N/A] L-031 / L-048 / L-068 — no export, SPA packaging or index.html change.
- [OK] L-039 — ONE builder, `_object_row`, is used by both list and detail; `test_list_row_equals_detail_object_and_kb_values_win` asserts `detail.object == list row` for every page, including the derived fields.
- [N/A] L-051 / L-056 / L-057 / L-087 / L-088 — release and agent-system lessons; the commit contains all its files.
- [N/A] L-069 / L-074 / L-085 — no web, board or publish hook.
- [OK] L-072 / L-084 — pulled pages are handled: `latest_entry_id` is never read, and "latest" is derived from the entries (`_ROW_SELECT` `le` join). `""` text → `is_bugfix False` and blank story key/sync never match. Covered by `test_pulled_page_derives_latest_from_entries` and the blank-entry case in `test_story_resolution`.
- [OK] L-083 — the fixtures use real shapes: `Record Type`/`Expression Rule`/`recordData`, `GNS_000123`, `_a-<base>_<suffix>` uuids and mixed Hub timestamp forms.
- [OK] L-032 — the KB join picks `MAX(k2.id)` among the open rows, at most one per object (`_ROW_SELECT`). This is not exercised by a test (nit n2).

### Spec conformance (48-02 §2–§6)
- [OK] §2 endpoints, response envelopes, 404 texts and empty-list behaviour are covered by tests 1 (`test_untracked_app_is_404_on_both_endpoints`, `test_unknown_object_is_404`, `test_tracked_app_with_no_pages_lists_empty`, plus cross-app isolation `test_pages_of_another_app_are_not_listed`).
- [OK] §2.1 every field is present. `empty_row ==` checks the full dict, so a field added or dropped would fail the test.
- [OK] §2.2 entry keys are an exact set; provenance columns are not exposed; `is_bugfix` is a JSON bool.
- [OK] §3 the list is one SQL statement (correlated subqueries, no N+1). The detail costs 3 queries (row, entries, one batched story query). Indexes exist for the joins (`ix_wiki_object_entries_page`, `ix_kb_objects_cur`, m0007:142).
- [OK] §4 the normalizer is pure; every canonical key is a fixed point; the table-driven tests cover the parser names, the wiki variants, case/space variants and empty/unknown values.
- [OK] §5 story resolution is app-scoped, batched and falls back from sync id to key.
- [OK] §6 test scenarios 1–6 are all present.

## Evaluation of the author's deliberate decisions

1. **`julianday()` ordering instead of a string sort: accepted, and it is the better reading of the spec.** Wiki-entry
   `created_at` is a SHARED column: it is not in `_LOCAL_ONLY` (`collab/service.py:37-44`) and not listed in the
   `wiki_entry` binding's `local_only`. A puller therefore keeps the author's string. I probed SQLite:
   `…Z`, `….000Z`, `….123456+00:00`, `….000+05:30` and `YYYY-MM-DD HH:MM:SS` all parse.
   `+0000` (offset with no colon) and Appian display strings (`10/2/2026 8:00 PM GMT`) return NULL. They sort last
   rather than wrong, which is a sound fallback. The exact form the live Hub returns is still **unverified**, so 48-04 should
   look at one pulled entry's `created_at` (Minor m1). The deviation from the spec's literal wording must be recorded in As built (m4).
2. **Ambiguous key → null: accepted.** `kb_stories.key` is not unique for pre-ADR-072 backlog ids. Linking to an arbitrary
   one of them would violate the intent of ADR-071 (land on the right story), so returning null is the conservative,
   tested choice (`story-1-1` case). Record it in As built as a refinement of D6.
3. **Unlisted parser types → `other` with `type_raw` kept: accepted.** The spec fixes the canonical list and keeps the
   raw value for the web. If 48-03 wants e.g. Data Store or Control Panel icons, that would be a spec change, not a fix here.
4. **Name precedence mirrored in Python and SQL: acceptable, but a small drift risk.** The two forms are equivalent today:
   Python `or` drops `""` just as `NULLIF(…, '')` does, and `kb_name` is NULL without the join. Nit n1 suggests a single source.

## Findings

### Blockers
- None.

### Majors
- None.

### Minors
- **m1. Hub timestamp form unverified live.** `_ENTRY_ORDER_DESC` (`kb/object_wiki.py` ~L226) depends on SQLite
  understanding the Hub's returned `created_at`. An unparseable value sorts last, so an entry in that form never becomes
  "latest". Action for 48-04: during live acceptance, pull a teammate's entry and confirm `julianday(created_at)` is not NULL
  (`SELECT created_at, julianday(created_at) FROM wiki_object_entries WHERE published_by IS NOT NULL LIMIT 5`).
- **m2. The list sort key and `last_changed_at` diverge on edge values.** In SQL, `_LAST_AT = COALESCE(le.created_at, p.updated_at)`.
  The row value in Python is `last_entry_at or page_updated_at`. These differ when the latest entry's `created_at` is `""`
  (the Hub's null text, L-084), or when every entry is unparseable (`julianday` NULL → the page sorts last, with no
  fallback to `p.updated_at`). The effect is ordering only. Fix (optional): `COALESCE(NULLIF(le.created_at,''), p.updated_at)`.
  Ordering within the unparseable band is acceptable.
- **m3. No test for the sync-mismatch → key fallback.** `test_story_resolution` covers "sync wins" and "key only", but not an
  entry whose `story_sync_uuid` is unknown locally while its `story_key` matches uniquely. That is exactly what a pulled entry
  looks like when the story's sync id differs. The code handles it (`lookup`), but the D6 "else" branch should be pinned by a case.
- **m4. As built not yet written.** Before closing 48-02, the sub-spec needs its As built section with: the commit, the tests,
  this verdict, decisions 1–3 recorded as spec refinements, and **one real JSON sample of each response (§7)**. 48-03 consumes those
  samples verbatim as its msw fixtures, so a sample produced from the test fixture (e.g. a `print(r.json())` of `_list`/`_detail`) is required.

### Nits
- **n1.** Remove the mirrored name precedence: select `{_NAME} AS display_name` in `_ROW_SELECT` and have `_object_row` read it.
  The ORDER BY can reference the same alias.
- **n2.** L-032 guard (`MAX(k2.id)`) has no test with two open KB rows for one object. That state is hard to construct via
  `KbStore.apply`, so a direct-insert test would be needed. Optional.
- **n3.** In `_resolve_stories`, `sync_ids`/`keys` are lists used for `in` membership. A `set` would be cleaner; the sizes involved make this cosmetic.

## Verdict: **SHIP**

There are no blockers or majors, and every applicable gate is green and was re-run by the reviewer (pytest 1185 passed, ruff clean).
m4 (As built + JSON samples) is required before 48-02 is marked done and before 48-03 starts. m1 is carried into 48-04
live acceptance. m2/m3 are recommended small follow-ups and can be folded into this sub-spec before release.

## Delta review (148c064) — genesis-review, 2026-10-21

Scope: `git diff 940deef..148c064` only (2 files, +59/−15: `genesis/kb/object_wiki.py`, `tests/test_object_wiki_api.py`).

| Gate (re-run by the reviewer) | Result |
|---|---|
| `.venv/bin/python -m pytest -q -p no:warnings` | **1187 passed** in 144.28s (1185 + 2 new; matches the author) |
| `.venv/bin/ruff check genesis tests/test_object_wiki_api.py` | **All checks passed!** |
| `git status --short` | clean; the commit holds both files (L-056) |

- **m2 — resolved.** `_NAME`, `_FIRST_AT = COALESCE(NULLIF(fe.created_at,''), p.created_at)` and `_LAST_AT = COALESCE(NULLIF(le.created_at,''), p.updated_at)`
  are each selected once in `_ROW_SELECT` (`kb/object_wiki.py:231-237`). The list ORDER BY uses the same constants (`:190-192`).
  `test_blank_latest_created_at_falls_back_to_page_updated_at` is a real regression test. On 940deef the `""` would have reached
  `julianday()` as NULL and sorted the page last, so `[RULE, REC]` would have failed; it now passes. As noted in the original review,
  a non-blank but unparseable value still sorts last with no page fallback. That is acceptable and is tied to m1.
- **n1 — resolved.** `_object_row` reads `display_name`/`first_documented_at`/`last_changed_at` (`:267,273-274`), so the Python
  mirror is gone. The behaviour is equivalent: `k.name` is non-NULL only when the current-KB join hits, which is the old `in_kb` guard.
  The removed columns (`kb_name`, `object_name`, `page_*_at`, `*_entry_at`) are not referenced anywhere else in `genesis/` (grep).
  L-039 still holds, because `test_duplicate_current_kb_rows_yield_one_wiki_row` asserts `detail.object == list row`.
- **m3 — resolved.** `test_story_resolution` adds a pulled entry whose sync id is unknown on this machine and whose key `GNS_000123` is unique.
  It resolves to `by_key`, which pins the D6 "else" branch.
- **n2 — resolved.** The new test direct-inserts a second open `kb_objects` row for the same object and asserts one wiki row with
  `in_kb True` and `entry_count 1`. It pins the existing `MAX(k2.id)` guard, so it passes on 940deef too, as a pin for L-032 should.
- **n3 — resolved.** `sync_ids`/`keys` are sets, and `sorted()` is applied only when binding the parameters, so the bound order stays deterministic.
- No new findings. The delta adds no new surface: still read-only SELECTs, no writes, no web change, and no change to ADRs 050/063/070/071.

Carried: **m1** → 48-04 live acceptance. **m4** (As built + one real JSON sample per response) is still required before 48-02
is closed and before 48-03 consumes the samples.

### Delta verdict: **SHIP**
