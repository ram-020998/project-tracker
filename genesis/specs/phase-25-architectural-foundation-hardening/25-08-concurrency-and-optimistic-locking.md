# 25-08 — Concurrency & Optimistic Locking

- **Status:** 📝 DRAFTED · **Review items:** D-1, §17 · **Roadmap:** Phase 3 · **Repos:** genesis (+ migration **m0014**) · **Depends on:** 25-01 (typed entities to version)

## 1. Goal
Add **optimistic concurrency control** to the mutable domain rows (features/specs and, when they land, stories/stages) so concurrent writers — the near-term goal of parallel story execution — cannot silently lose updates or corrupt state.

## 2. Why (review evidence)
- **D-1:** FastAPI runs sync handlers in a threadpool; there is **no optimistic locking / row versioning** on KB/feature mutations. Fine for one user; unsafe once stories run in parallel.
- **§17 (Concurrency):** the review's explicit scenario — Story A/B/C progressing under different developers — must not corrupt Feature state.
- **Critical *if* parallel stories land** (review D-1) — so this must precede 25-11.

## 3. Current state (cited)
- `FeatureStore`/`KbStore` writes are last-write-wins `UPDATE`s with no version/`updated_at` guard.
- SQLite WAL + `busy_timeout` serialize *physical* writes (bible §7) but do **not** prevent a **lost update** (read-modify-write races at the application level).
- The `sync-application` job is already serialized (Appian export is one-at-a-time/409) — that's an *external* constraint, not row-level CC.

## 4. Design
### 4.1 Row version column (m0014)
- Add `row_version INTEGER NOT NULL DEFAULT 0` (or reuse `updated_at` as a token) to `kb_features`, `kb_feature_specs`, and the new lifecycle-bearing tables from 25-01. Additive migration; `current_version` → 14 (bump version tests, bible §7).

### 4.2 Compare-and-swap in the store/service
- Mutating methods take an expected `row_version`; the `UPDATE ... WHERE id=? AND row_version=?` returns rowcount 0 on a stale write → raise `StaleWriteError` (typed).
- `LifecycleService.transition` (25-01) performs its state change as a CAS — so two concurrent transitions on the same entity can't both win.
- API maps `StaleWriteError` → **HTTP 409 Conflict** with `{expected, actual}` so the client can refetch + retry (review §9 idempotency/versioning).

### 4.3 ETag/If-Match at the API edge (optional, thin)
- GET returns the `row_version` (as an ETag); mutating requests may send `If-Match`. If absent, the service reads-then-CAS (still safe, just a smaller race window). Keep optional to avoid churn.

### 4.4 Run-start idempotency
- `POST /api/runs` (and the copilot `start_run`) gain an optional idempotency key so a double-submit (review §17 "double submission") starts one run, not two.

## 5. Files touched
- **New:** `db/migrations/m0014_row_version.py`, `tests/test_optimistic_locking.py`, `tests/test_run_idempotency.py`.
- **Edit:** `kb/features.py` (+split stores from 25-06), `domain/lifecycle.py` (CAS transition), `api/features.py` + `api/app.py` (409 mapping, optional ETag), `runs/manager.py` (idempotency key).

## 6. Tests
- Lost-update test: two concurrent updates with the same base version → one succeeds, the other raises `StaleWriteError`/409 (asserts no silent overwrite).
- Concurrent `LifecycleService.transition` on one entity → exactly one wins.
- Double-submit run start with the same idempotency key → one run.

## 7. Risks & mitigations
- **Risk:** version churn breaks existing single-user flows. **Mitigation:** default `row_version=0`; service reads-then-CAS when the caller doesn't supply a version, so existing single-threaded callers are unaffected.
- **Risk:** schema bump breaks `current_version==N` tests. **Mitigation:** bump them with the migration (bible §7).

## 8. Out of scope
Cross-process locking; distributed locks; pessimistic DB locking.

## 9. Definition of Done
Row-version CAS on features/specs/lifecycle tables; `StaleWriteError`→409; run-start idempotency; m0014 + version tests bumped; concurrency tests green; genesis release CI-green; progress doc. (Precedes 25-11.)
