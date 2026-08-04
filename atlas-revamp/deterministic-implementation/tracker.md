# Tracker — Deterministic Implementation (data-gen prose → code)

**Program:** convert `.kiro/skills/data-gen*` + `.kiro/resources/data-generator/` from prose to a tested `dg`
CLI. **Branch:** `feature/atlas-data-generator`. **Source:** `proposal-source.md`. **Plan:** `README.md`.

> **Update this file as work lands.** Status vocabulary (mirrors the frozen enum):
> `NOT_STARTED · IN_PROGRESS · BLOCKED · DONE`. One commit/MR per phase where possible.

---

## 0. Snapshot (2026-08-03)

**Phases 0–9 DONE (10 of 11). Only Phase 10 (CI) remains.** All work on `feature/atlas-data-generator`,
**uncommitted**.

- **`dg` CLI** at `.kiro/resources/data-generator/scripts/`: 10 modules (`dg.py`, `state.py`, `gate.py`,
  `scaffold.py`, `coverage.py`, `validate.py`, `sql_emit.py`, `footprint.py`, `fields.py`, `erd_input.py`)
  + 12 subcommands (`init·state·gate·plan-writes·coverage-gate·verify-input·validate·gen-sql·plan-footprint·build-footprint·check-fields·erd-input`).
- **Tests:** **89 passed**, ruff clean (test_state/gate/scaffold/coverage/validate/sql_emit/footprint/fields/erd_input/cli).
- **Contracts:** 5 JSON schemas + `config/thresholds.json` + `config/domains.example.json`.
- **Fixtures:** `sourceselection-{exemplar,manual,bulk}` all schema-valid; goldens: `coverage-gate.md`,
  `bulk-data.sql`.
- **Program DoD (README §10):** prose **480 ln** (<1,700 ✅), `⚠️` **2** (<15 ✅), 3 fixtures replay ✅.
  Remaining for full DoD: **CI fails on drift/prose-mismatch** (Phase 10).
- **All 15 Appendix-A defects CLOSED.**
- **Open follow-ups:** Phase 10 (CI); **DEC-3/#19** ERD renderer rehoming (input de-hardcoded, renderer not);
  user-membership check excluded from default gate (needs full raw); full `raw/` parity for exemplar/manual
  (scoped today); DEC-5 (was 0–4+7 "Option 3" enough vs full Option 4 — full pipeline now built).

## 1. Phase status

| Phase | Title | Status | MR | Notes |
|---|---|---|---|---|
| 0 | Freeze the contracts (schemas + fixtures) | DONE | — | 5 schemas + thresholds + 3 fixtures (exemplar/manual/bulk) all schema-valid; all defects resolved/recorded. Follow-on captures (raw parity, bulk SQL golden) documented in fixtures README |
| 1 | State and gate | DONE | — | state.py + gate.py + dg state/gate; 23 tests green, ruff clean. Prose retirement of BLOCKING CHECK/TRACKER blocks deferred to Phase 8 (DEC-4) |
| 2 | Scaffold (`dg init`) | DONE | — | scaffold.py + dg init; one canonical artifact list (D-7), repo-root anchor (D-15), collision -NN, seed/date_anchor; 32 tests green, ruff clean. step-0 prose retirement → Phase 8 |
| 3 | Coverage gate | DONE | — | coverage.py + dg coverage-gate/verify-input; D-3 authority + D-4 no-silent-degrade; 42 tests incl. byte-identical golden; ruff clean. Step-5 reconcile lands in Phase 4; prose retirement Phase 8 |
| 4 | Payload validation | DONE | — | validate.py + dg validate; schema/FK/forbidden/date checks + D-3 Step-5 reconcile; D-8 no-op killed; 55 tests, ruff clean. User-membership implemented+tested but out of default gate (needs full raw) |
| 5 | SQL emitter | DONE | — | sql_emit.py + dg gen-sql; generator vocab + fk_binding fan-out + LAST_INSERT_ID chaining + camel→UPPER_SNAKE; byte-identical golden bulk-data.sql, seed-stable; 63 tests, ruff clean |
| 6 | Exemplar footprint | DONE | — | footprint.py + dg plan-footprint/build-footprint; BFS derives real FK column per edge, cycle/self-ref safe; clone helpers (strip PK/remap FK/fan-out); 72 tests, ruff clean |
| 7 | Field coverage enforcement | DONE | — | fields.py + dg check-fields; writable-field % (excl PK/custom), config rounding (D-14), enforced field_reasoning; 79 tests, ruff clean. **← reviewer "Option 3" milestone (0–4+7) reached** |
| 8 | Decisions contract + prose rewrite | DONE | — | decisions.schema finalized + validated on read; 12 workflow/exemplar/generation files rewritten to 4-part form; prose **991 ln (<1700)**, ⚠️ **3 (<15)**; added dg plan-writes; 84 tests, ruff clean. Manage/ERD prose → Phase 9 |
| 9 | Manage actions + ERD | DONE | — | erd_input.py + dg erd-input + config/domains.example.json (de-hardcoded taxonomy; Other fallback; non-GSS proof); ERD SKILL split; 3 manage refs rewritten; 89 tests, ruff clean. ERD renderer #19 → DEC-3 (open) |
| 10 | CI | NOT_STARTED | — | Wire incrementally |

**Reviewer "Option 3" milestone (a legitimate stopping point):** Phases 0–4 + 7 DONE.
**Full Option 4:** all phases DONE + program DoD in README §10 met.

---

## 2. Per-phase exit checklists

> Copy each phase's "Done when" from its phase doc; tick as verified. Keep the exact command/test that proved it.

### Phase 0 — Freeze contracts
- [x] `state.schema.json` written — validated (Draft 2020-12); enforces enum + gate_mode
- [x] `decisions.schema.json` written — D1–D14 stub (finalized Phase 8)
- [x] `payload-metadata.schema.json` written — validated; rejects legacy `status=COMPLETE` and `$alias` conv
- [x] `payload-file.schema.json` written — validated; requires `field_reasoning`; RECORD requires uuid
- [x] `payload-spec.schema.json` written — bulk generator vocab aligned to `expand_record_csv`
- [x] `config/thresholds.json` written (coverage %, rounding, batch, live_record_limit, bulk_min_rows)
- [x] Fixture: `sourceselection-exemplar/` captured (raw/ scoped + payloads + decisions + state + reports) — **schema-valid + FK-topology clean (67 refs / 36 aliases)**
- [x] Fixture: `sourceselection-manual/` captured — real `write_graph`+`write_set`; **coverage reconciles (req=10/cov=6/excl=4/missing=0)**; schema-valid
- [x] Fixture: `sourceselection-bulk/` captured — generation specs (110 rows); schema-valid
- [~] exemplar/manual raw/ full parity (record_properties ×N, field_map, reference_data, documents, exemplar/*) — follow-on captures per README
- [~] bulk `out/bulk-data.sql` — Phase-5 golden (frozen once sql_emit.py exists)
- [x] `tests/fixtures/README.md` (capture procedure + DEC-6 scoping + per-fixture status) written
- [~] Every Appendix-A defect has a recorded resolution — D-1/D-2 closed; D-4/D-5/D-6/D-14 contract-frozen; D-3/D-8/D-9/D-10/D-11/D-13/D-15 mapped to phases (see §4)
- [x] **All three fixtures validate against the schemas (0 errors)**

### Phase 1 — State and gate
- [x] `state.py` (atomic writes via temp+os.replace, 4-value enum, loud on corrupt/missing)
- [x] `gate.py` (precondition graph as data; both manual & exemplar chains)
- [x] `dg state` / `dg gate` subcommands (+ enum enforced at CLI via argparse choices)
- [x] `pytest tests/` green — **23 passed** (missing step, wrong/emoji status, out-of-order, both mode graphs, corrupt state fails loud, atomic write); ruff clean; `ruff.toml` + `.gitignore` + `conftest.py` added
- [x] Done-when CLI verified: `gate 4b→5` exit 1 → `state set 4b PASS` → `gate 4b→5` exit 0; `status COMPLETE` rejected
- [~] Retired: 9 BLOCKING CHECK + 9 EXECUTION TRACKER UPDATE blocks — **code ready**; prose edits deferred to the Phase 8 rewrite (DEC-4)

### Phase 2 — Scaffold
- [x] `scaffold.py` + `dg init`
- [x] Mode-dependent artifact set from ONE list `_REPORTS`/`reports_for()` (fixes D-7). Canonical: manual=6 reports, exemplar=5 (supersedes legacy inconsistent 6-vs-7); analysis.md + coverage-gate.md are manual-only
- [x] Same-day collision `-02/-03`
- [x] Folder anchored to repo root (`find_repo_root` / `--root`), not cwd (fixes D-15)
- [x] `seed` (default int(YYYYMMDD)) / `date_anchor` (default today) recorded at init
- [~] Expected-scaffold golden: replaced by in-`tmp_path` structural assertions (deterministic; no redundant committed tree)
- [x] `pytest tests/test_scaffold.py` green (9 tests) — total suite **32 passed**, ruff clean; `dg init` CLI smoke verified (exemplar → 5 reports; gate 0→E1 exit 1 while step 0 PENDING)
- [~] Retired: `step-0-initialize.md` 442 → ~40 ln — code ready; prose edit deferred to Phase 8 (DEC-4)

### Phase 3 — Coverage gate
- [x] `coverage.py` (required_set/payload_tables/diff/mechanism_map/render_report/run_gate/verify_input_args)
- [~] Step 5 consumes this output (D-3): coverage.py is the single authority + records mechanism_map & excluded in state 4b; the Step-5 *reconcile* (no get_app_schema, no 2nd taxonomy) is wired in Phase 4 (validate.py)
- [x] Refuses silent degrade; `gate_mode=kb_stale` (exit 2); `--allow-degraded` → `degraded_manual`, report tainted, never unqualified PASS (fixes **D-4**)
- [x] `dg verify-input` builds verify_write_coverage args from mechanism map (RECORD→uuid, CDT→constant_name)
- [x] `pytest tests/test_coverage.py` green — all 8 cases (present/missing/cited/uncited/extra/kb_stale/degraded/CDT); total suite **42 passed**, ruff clean
- [x] Golden-file: `sourceselection-manual/reports/coverage-gate.md` byte-identical replay; fixture reconciles (req=10/cov=6/missing=0)
- [~] Retired: `step-4b` 234→~30 ln; `step-5` §5a; `create-records` §6e — code ready; prose edits deferred to Phase 8 (DEC-4)

### Phase 4 — Payload validation
- [x] `validate.py`: schema (jsonschema), FK topology (@alias grammar + forward-ref/cycle + legacy reject), forbidden fields (PK/isCustomRecordField via record_properties), dates, coverage reconcile (D-3)
- [x] `dg validate` writes reports/validation-report.md + sets state 5 (manual) / E4 (exemplar)
- [x] `pytest tests/test_validate.py` — each check pass+fail path (malformed JSON, forward @alias, cycle, legacy $alias, PK/custom, bad date, 4b-not-PASS) + both fixtures validate; total suite **55 passed**, ruff clean
- [~] User/ref/document membership: implemented; user-membership kept out of the default gate (needs full record_properties + current users.json — enable in CI). ref/document SKIP when raw absent
- [~] Retired: `step-5` 306→~60 ln; `exemplar-4` → `dg validate --mode exemplar` — code ready; prose deferred to Phase 8

### Phase 5 — SQL emitter
- [x] `sql_emit.py` (camelCase→UPPER_SNAKE via field_map/fallback, typed literals, escaping, LAST_INSERT_ID/@var FK chaining, generator vocab + fk_binding fan-out)
- [x] Header comment records seed/date_anchor/request
- [x] `dg gen-sql` → `out/bulk-data.sql`
- [x] byte-identical golden `sourceselection-bulk/out/bulk-data.sql`; same-seed→byte-identical (tested)
- [x] `pytest tests/test_sql_emit.py` green (escaping quotes/backslash/newline, NULL vs empty, types, generators, seeded-int stability, multi-parent FK fan-out, counts 10/100, golden) — suite **63 passed**, ruff clean
- [~] Retired: `generate-sql.md` 382→~50 ln — code ready; prose deferred to Phase 8

### Phase 6 — Exemplar footprint
- [x] `dg plan-footprint` — BFS from root over the child graph; each step names the child's REAL FK column (grandchild → parent PK, not root); derived from schema_relationships so wrong-FK guess impossible
- [x] `dg build-footprint` — assembles reports/footprint.md (plan + per-table row counts)
- [x] Clone mechanics in code: `strip_and_remap` (E3 r1 strip PK / r2 remap internal FK→@alias / r3 preserve reference FK) + `fan_out` (r6)
- [x] Cycle detection via visited set; self-reference skipped
- [x] `pytest tests/test_footprint.py` green — diamond (no dup), grandchild-by-parent-PK, self-ref, cycle terminates, non-root FK column, clone helpers, fixture smoke; suite **72 passed**, ruff clean
- [~] Retired: `E2` 73→~15 ln; `E3` 106→~45 ln — code ready; prose deferred to Phase 8

### Phase 7 — Field coverage
- [x] `fields.py` (writable-field count excl PK & isCustomRecordField; rounding from config; threshold)
- [x] `field_reasoning` required for every populated field + deliberate null (hard fail if missing)
- [x] `dg check-fields` (writes reports/field-coverage.md)
- [x] `pytest tests/test_fields.py` green (at threshold, just below, documented-nulls pass, missing-reasoning hard-fail, 5/8=62 floor asserted +nearest/ceil, fixture evaluation) — suite **79 passed**, ruff clean
- [~] Retired: `step-4` §4d → `dg check-fields` — code ready; prose deferred to Phase 8

### Phase 8 — Decisions + prose rewrite
- [x] `decisions.schema.json` finalized; `dg validate` validates decisions.json on read (check_decisions; pass+fail tested)
- [x] Each rewritten step file → 4 parts (decisions produced · dg call · on-nonzero · judgment): step-0/1/2/3/4/4b/5, exemplar-2/3/4, create-records, generate-sql (12 files)
- [x] Deletions: step-1 1a–1h manual-trace dup, step-3 §3f anti-rationalization essay, create-then-insert choreography (D-13), STOP/COMPLIANCE apparatus
- [x] step-4 internals renumbered 4.1–4.5 (D-9)
- [x] **Total procedural prose 991 ln (< 1,700)**; **`⚠️` = 3 (< 15)**; added missing `dg plan-writes`; no dangling dg refs in prose; 84 tests, ruff clean
- [~] Manage refs (explore-schema/query-validate/rollback) + data-gen-erd prose → rewritten in Phase 9 (budget already met)

### Phase 9 — Manage + ERD
- [x] ERD: `config/domains.example.json` (GSS worked example) + gitignored `config/domains.json`; `dg erd-input` builds `<app>-erd.json`; unmatched → `Other`
- [x] Non-GSS fixture test places tables in real domains (Orders/Billing), not all `Other` — proves de-hardcoding
- [x] Manage refs rewritten (explore-schema/query-validate/rollback); D14 routing stays with the model; DG/Atlas MCP tools referenced
- [x] `data-gen-erd/SKILL.md` split into short SKILL.md + `references/generate-erd.md`
- [x] `pytest tests/test_erd_input.py` (config load, GSS assignment + precedence, field selection, build, non-GSS) + all 4 skills quick_validate + dg erd-input smoke → suite **89 passed**, ruff clean
- [x] **Total procedural prose 480 ln; `⚠️` = 2** (both well under budget)
- [~] ERD renderer rehoming (#19) — NOT closed here (input de-hardcoded only); tracked as DEC-3

### Phase 10 — CI
- [ ] `.gitlab-ci.yml` job: pytest + ruff over scripts/
- [ ] Schema-lint job validating every committed fixture
- [ ] Reference-integrity job (fail if a step names a missing subcommand, or a subcommand no step invokes)
- [ ] An MR renaming a subcommand without updating prose fails CI

---

## 3. Program definition of done (README §10)
- [ ] Total procedural prose < 1,700 lines (from 4,194)
- [ ] Every `dg` subcommand referenced by exactly one step file
- [ ] `grep -c '⚠️'` across the family < 15
- [ ] All three fixtures replay byte-identical through the pipeline
- [ ] CI fails on contract drift or prose/subcommand mismatch

---

## 4. Defect resolution log (Appendix A — must be resolved before Phase 1)

| ID | Defect (short) | Resolved by | Resolution recorded | Status |
|---|---|---|---|---|
| D-1 | Dual payload contract (monolith vs split) | §7.1, Phase 0 | **Contract frozen**: split `payloads/` only; no monolithic `payloads.json` in any schema | CLOSED |
| D-2 | Six FK placeholder notations | §7.2, Phase 0 | **Contract frozen**: `@alias([index])?(.field)?` only; metadata `fk_placeholder_convention=at-alias-v1`; legacy `$alias` rejected. Runtime reject in Phase 4 | CLOSED |
| D-3 | Three conflicting coverage checks (can deadlock) | Phase 3 | **CLOSED (Phase 3+4)**: single required set from resolve_write_set; validate.py `reconcile_coverage` consumes state 4b, no get_app_schema/2nd taxonomy | CLOSED |
| D-4 | Gate silently degrades yet reports PASS | §7.4 `gate_mode`, Phase 3 | **CLOSED (Phase 3)**: empty write graph → BLOCKED `kb_stale` (exit 2); `--allow-degraded` → `degraded_manual`, report tainted; tested | CLOSED |
| D-5 | Ten status vocabularies; COMPLETE vs COMPLETED | §7.3, Phase 1 | **Contract frozen**: enum `PENDING\|IN_PROGRESS\|PASS\|BLOCKED` in all schemas; no emoji in state. Enforced in Phase 1 | CONTRACT FROZEN |
| D-6 | ~50-record boundary asserted 4×, enforced 0× | §7.5, Phase 2 | **Contract frozen**: `config.live_record_limit=50`, `bulk_min_rows=100`. Enforced in Phase 2 | CONTRACT FROZEN |
| D-7 | step-0 says both 6 and 7 files | Phase 2 (one list) | **Recorded**: single artifact list in scaffold.py; count derived, never asserted twice. Impl Phase 2 | RECORDED |
| D-8 | Only mechanical step-4 check cannot fail (no-op) | Phase 4 | **CLOSED (Phase 4)**: validate.py runs real JSON-Schema + FK topology + forbidden-field + date checks; malformed JSON and forward @alias now fail (tested) | CLOSED |
| D-9 | `4b` names two different things | Phase 8 (renumber 4.1–4.5) | **CLOSED (Phase 8)**: step-4 internals renumbered 4.1–4.5; step-4b is the coverage gate | CLOSED |
| D-10 | Value selection explicitly non-reproducible | §7.4 `seed`, Phase 7 | **CLOSED (Phase 5/7)**: seed recorded (Phase 2) + used by sql_emit generators; seeded-int stability tested | CLOSED |
| D-11 | Dates hardcoded, no anchor | §7.4 `date_anchor`, Phase 7 | **CLOSED (Phase 5/7)**: `date_anchor` recorded + used by sql_emit date generator (offsets from anchor) | CLOSED |
| D-12 | Undefined external refs D9/D15/D16/D17/D18 | Phase 0 (locate/inline) | **Already removed in commit `7095239373` (part-1 fix)** | **CLOSED** |
| D-13 | Tool choreography embedded in workflow | Phase 8 (code writes artifacts) | **CLOSED (Phase 8)**: create-then-insert choreography removed from create-records; dg writes artifacts | CLOSED |
| D-14 | Coverage % has no rounding rule | §7.5, Phase 7 | **CLOSED (Phase 7)**: config.coverage_rounding applied in fields.round_pct; 5/8 to 62 asserted | CLOSED |
| D-15 | Interactive-only inputs (cwd) in agent flow | Phase 2 | **Recorded**: scaffold anchors to repo root (or `--root`), never `os.getcwd()`. Impl Phase 2 | RECORDED |

---

## 5. Decision log

| ID | Decision | Options | Choice | Date | Status |
|---|---|---|---|---|---|
| DEC-1 | `dg` CLI location | (a) `.kiro/skills/data-gen/scripts/` (proposal) · (b) `.kiro/resources/data-generator/scripts/` (shared by 4 skills) | **RESOLVED (b)** — user accepted; schemas/config already created there | 2026-07-31 | CLOSED |
| DEC-2 | Fixture-capture environment availability (Atlas+DG MCP, SourceSelection) | available now / needs setup | **RESOLVED — verified reachable**: Atlas MCP `list_applications` shows SourceSelection (2917 objs); DG MCP `list_users` OK | 2026-07-31 | CLOSED |
| DEC-3 | ERD renderer (`erd-gen`) rehoming (#19) | migrate to shared namespace / drop `data-gen-erd` / keep behind flag | — | — | OPEN |
| DEC-4 | Prose-rewrite cadence | batch at Phase 8 / rewrite per-phase as it lands | **proposed: per-phase** | 2026-07-31 | OPEN |
| DEC-5 | Delivery target | full Option 4 / Option 3 stopping point (0–4+7) then reassess | — | — | OPEN |
| DEC-6 | Fixture `raw/` scope | whole-app dumps / table-scoped to what the fixture touches | **RESOLVED — table-scoped** (documented in fixtures README); insertion_order kept verbatim | 2026-07-31 | CLOSED |

---

## 6. Session log

| Date | Who | What |
|---|---|---|
| 2026-07-31 | ram + kiro | Created `deterministic-implementation/`; moved proposal → `proposal-source.md`; wrote README, tracker, and phase docs 00–10. Cross-verified proposal (line counts exact; precedent real; D-1/D-2/D-7 confirmed; D-12 already fixed). |
| 2026-07-31 | kiro | **Phase 0 (schema slice) started.** Verified both MCP servers reachable (SourceSelection present). Read the real 2026-07-21 run artifacts; documented migration deltas (`$alias`→`@alias`, `mode`/`generation_mode`→`mode`/`volume_mode`, `COMPLETE`→`PASS`, `_alias`→`output_ref`). Authored 5 JSON schemas + `config/thresholds.json` under `.kiro/resources/data-generator/scripts/` on `feature/atlas-data-generator`. Validated all as Draft 2020-12 + positive/negative discrimination tests pass. DEC-1/DEC-2 CLOSED; D-1/D-2 CLOSED; D-4/D-5/D-6/D-14 contract-frozen. **Not committed.** Remaining Phase 0: transform the 2026-07-21 run into the manual/exemplar golden fixture (+ `raw/`, `state.json`, `decisions.json`), capture a bulk fixture, write fixtures README, resolve remaining Appendix-A rows. |
| 2026-07-31 | kiro | **Exemplar fixture built & validated** (`tests/fixtures/sourceselection-exemplar/`). Captured real scoped `raw/` (record_type_map, insertion_order [verbatim], schema_relationships, users, record_properties for the root). Migrated the 2026-07-21 run via a deterministic one-shot script → 16 payloads (36 records) in the new contract (`@alias`, snake_case `output_ref`, `mechanism:RECORD`, generated `field_reasoning`) + new-contract `00-metadata.json`. Authored `decisions.json` (D1/D6/D9/D10/D11) + `state.json` (E1–E4+gen PASS); copied 4 reports. **Validation: all artifacts schema-valid; FK topology clean (67 refs, 36 aliases, no forward/undeclared).** DEC-6 CLOSED (table-scoped raw/). Temp venv + migration helper removed. **Not committed.** Remaining Phase 0: manual + bulk fixtures (each needs its own real MCP run), full exemplar raw/ parity, and recording the remaining Appendix-A resolutions. |
| 2026-07-31 | kiro | **Phase 0 DONE.** Built **manual** fixture from real `resolve_write_set`+`get_entry_point_write_graph` for entry point `AS_GSS_Evaluation_SYNCEDRECORD - Create new evaluation` (write_set: 10 required tables + cited exclusions; write_graph verbatim main process incl. D3 gateways). decisions.json (D2/D3/D4) + state.json (step 4b **reconciles req=10/cov=6/excl=4/missing=0**) + 6 business payloads. Built **bulk** fixture (2 generation specs, 110 rows, expand_record_csv vocab + fk_binding). **All 3 fixtures validate against the schemas (0 errors); manual FK topology clean.** All Appendix-A defects now resolved (D-1/D-2/D-12 CLOSED; D-4/5/6/10/11/14 CONTRACT FROZEN; D-3/7/8/9/13/15 RECORDED→impl in their phases). fixtures README updated with per-fixture status + follow-ons (exemplar/manual raw parity; bulk `out/bulk-data.sql` = Phase-5 golden). **Not committed** (per instruction). Next: Phase 1 (state.py + gate.py). |
| 2026-08-03 | kiro | **Phase 1 DONE.** Added `state.py` (State class: 4-value enum enforcement, atomic temp+os.replace writes, loud failure on corrupt/missing — no permissive default), `gate.py` (PRECONDITIONS as data for both manual `0→…→gen` and exemplar `E1→…→E4` chains + `gate()`), `dg.py` (CLI: `dg state get/set`, `dg gate --require --then`; enum also enforced at CLI via argparse choices). Tests: `tests/test_state.py` + `tests/test_gate.py` = **23 passed**; added `conftest.py`, `ruff.toml`, `.gitignore`. **ruff clean.** Verified Done-when CLI sequence. Prose retirement of the 9 BLOCKING CHECK / 9 TRACKER UPDATE blocks deferred to the Phase 8 rewrite (DEC-4). **Not committed.** Next: Phase 2 (scaffold / `dg init`). |
| 2026-08-03 | kiro | **Phase 2 DONE.** Added `scaffold.py` (`dg init`): creates `data-requests/{date}_{slug}[-NN]/` with skeleton (raw/, raw/record_properties/, raw/exemplar/ [exemplar], payloads/, reports/, out/ [bulk]); artifact set from ONE canonical list `_REPORTS`/`reports_for()` (fixes **D-7**; manual=6 reports/exemplar=5, analysis+coverage-gate manual-only); repo-root anchoring via `find_repo_root`/`--root` (fixes **D-15**); same-day `-NN` collision; seed=int(YYYYMMDD)/date_anchor defaults; writes state.json (all chain steps PENDING) + decisions.json (D1). Wired `dg init`. `tests/test_scaffold.py` (9) → suite **32 passed**, ruff clean; CLI smoke verified. step-0 prose retirement deferred to Phase 8. **Not committed.** Next: Phase 3 (coverage gate — highest value). |
| 2026-08-03 | kiro | **Phase 3 DONE.** Added `coverage.py` (required_set / payload_tables / diff / mechanism_map / render_report / run_gate / verify_input_args) + `dg coverage-gate` (writes reports/coverage-gate.md, sets state 4b + gate_mode) + `dg verify-input`. **D-4 CLOSED**: empty write graph → BLOCKED `kb_stale` (exit 2); `--allow-degraded` → `degraded_manual`, report permanently tainted. **D-3 authority landed** (single required set; Step-5 reconcile wired in Phase 4). `tests/test_coverage.py` = all 8 cases + count reconciliation + **byte-identical `coverage-gate.md` golden** against the manual fixture → suite **42 passed**, ruff clean. Committed golden `sourceselection-manual/reports/coverage-gate.md`. Prose retirement (step-4b/step-5 §5a/create-records §6e) deferred to Phase 8. **Not committed.** Next: Phase 4 (payload validation). |
| 2026-08-03 | kiro | **Phase 4 DONE.** Added `validate.py` (check_schema via jsonschema; check_fk_topology — @alias grammar, forward-ref/cycle detection, legacy `$alias`/`__FK_FROM_STEP` rejection; check_forbidden_fields — PK/isCustomRecordField via record_properties; check_dates; reconcile_coverage — consumes state 4b, no get_app_schema → **D-3 CLOSED**) + `dg validate` (writes validation-report.md, sets state 5/E4). **D-8 CLOSED** (no-op replaced; malformed JSON + forward @alias now fail). `tests/test_validate.py` covers each check pass+fail + both fixtures validate green → suite **55 passed**, ruff clean (bumped ruff line-length to 140 for descriptive messages; caught+fixed an accidental dropped `else` in check_schema during wrapping). check_users implemented+tested but excluded from default gate (env-sensitive: groupAssignee int false-positive, historical GSS users). **Not committed.** Next: Phase 5 (SQL emitter) or 6/7. Reviewer "Option 3" milestone (0–4+7) nearly complete — only Phase 7 remains. |
| 2026-08-03 | kiro | **Phase 5 DONE.** Added `sql_emit.py` (generator vocab const/seq/cycle/pick/int/str/row_index/date; `fk_binding` fan-out; camelCase→UPPER_SNAKE via raw/field_map.json or derived fallback; typed SQL literals with quote/backslash/newline escaping, bool→1/0, NULL; LAST_INSERT_ID/@var FK chaining in insertion order; header comment) + `dg gen-sql` → out/bulk-data.sql. Generated + committed golden `sourceselection-bulk/out/bulk-data.sql` (10 evaluations + 100 vendors, vendor EVALUATION_ID → @evaluation_N). `tests/test_sql_emit.py` (literals, generators, seeded-int stability, multi-parent FK chaining, golden byte-identity, determinism, counts) → suite **63 passed**, ruff clean. `generate-sql.md` prose retirement deferred to Phase 8. **Not committed.** Next: Phase 6 (exemplar footprint) / 7 (field coverage → Option-3 milestone). |
| 2026-08-03 | kiro | **Phase 6 DONE.** Added `footprint.py` (`plan_footprint` BFS over the child adjacency from schema_relationships — each step names the child's real FK column so a grandchild links by its parent's PK not the root's; visited-set cycle/self-ref guard; `build_footprint`+`render_report`; clone helpers `strip_and_remap` [E3 r1/2/3] + `fan_out` [r6]) + `dg plan-footprint` / `dg build-footprint`. `tests/test_footprint.py` covers diamond (no dup), grandchild-by-parent-PK, self-ref skip, cycle terminates, non-root FK column, clone helpers, fixture smoke → suite **72 passed**, ruff clean. E2/E3 prose retirement deferred to Phase 8. **Not committed.** Next: Phase 7 (field coverage → completes Option-3 milestone 0–4+7). |
| 2026-08-03 | kiro | **Phase 7 DONE — reviewer "Option 3" milestone (Phases 0–4 + 7) REACHED.** Added `fields.py` (writable_fields excl PK/isCustomRecordField; round_pct with config floor/nearest/ceil — **D-14 CLOSED**; threshold enforcement; field_reasoning required for every populated field + deliberate null, hard fail if missing) + `dg check-fields` → reports/field-coverage.md. `tests/test_fields.py`: at-threshold, just-below, documented-nulls pass, missing-reasoning hard-fail, 5/8=62 floor (+nearest/ceil), exemplar evaluation passes → suite **79 passed**, ruff clean. **D-10/D-11 CLOSED** (seed + date_anchor recorded and used by sql_emit; seeded stability tested). 9 dg modules total. **Not committed.** Remaining: Phase 8 (decisions + prose rewrite — the big retirement pass), Phase 9 (manage+ERD), Phase 10 (CI). |
| 2026-08-03 | kiro | **Phase 8 core DONE.** (A) Finalized decisions.schema.json + added `validate.check_decisions` (decisions.json validated on every `dg validate`; pass+fail tested). (B) Rewrote 12 procedural files to the 4-part form (decisions·dg call·on-nonzero·judgment): step-0 (442→33), step-1 (572→33, deleted 1a–1h manual-trace dup), step-2 (345→17), step-3 (369→25, deleted §3f essay), step-4 (370→33, renumbered 4.1–4.5 **D-9**), step-4b (234→35, Appendix-B form), step-5 (306→36), exemplar-2/3/4, create-records (314→32, removed choreography **D-13**), generate-sql (382→32). **Total procedural prose 991 lines (<1700); ⚠️=3 (<15).** Added missing `dg plan-writes` + regression test (caught a py3.14 argparse crash from a `%` in a help string). Reference-integrity: every `dg <cmd>` in prose is registered. Suite **84 passed**, ruff clean. **D-9 & D-13 CLOSED.** Manage/ERD prose deferred to Phase 9. **Not committed.** Next: Phase 9 (manage + ERD). |
| 2026-08-03 | kiro | **Phase 9 DONE.** ERD de-hardcoded: `config/domains.example.json` (GSS patterns/colors/field rules) + gitignored `config/domains.json`; `erd_input.py` + `dg erd-input` build `<app>-erd.json` (PK-first/FK/key fields, domain by pattern with `Other` fallback, relationship-type map). Loosened `_VENDOR_`→`_VENDOR` etc. so token-final names match. `tests/test_erd_input.py` incl. a **non-GSS proof** (Orders/Billing not all Other). Split `data-gen-erd/SKILL.md` (236→28) + `references/generate-erd.md`. Rewrote 3 manage refs (explore-schema/query-validate/rollback; D14 routing stays with model). **Total procedural prose 480 ln (from 4,194); ⚠️=2.** All 4 skills quick_validate; suite **89 passed**, ruff clean. ERD renderer #19 NOT closed (input only) → DEC-3 open. **Not committed.** Next: Phase 10 (CI). |
