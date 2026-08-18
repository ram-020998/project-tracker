# 25-03 — Atomic JSON-Store Hardening

- **Status:** ✅ BUILT (2026-08-18) — implemented + tested + committed locally; **NOT released** (ships via 25-14). · **Review items:** E-5, D-1 (files) · **Roadmap:** Phase 0 · **Repos:** genesis, genesis-core · **Depends on:** nothing (parallelizable)
- **As built:** `genesis_core/util/atomic_json.py` (`path_lock` + `atomic_write_json` [unique-temp + `os.replace`] + `read_modify_write_json` [serialized RMW]). Migrated: genesis-core custom **MCP + CLI** stores (fixed a shared-`.tmp` collision + added a per-path lock), `environments.py` (`_save` atomic + upsert/remove/set_dev locked — the main D-1 offender), `secrets.py` (refactored onto the shared helper, one lock registry), and the updater `dist.json` write. Native MCP/CLI lockfiles were already atomic+locked (verified, left as-is). Commits genesis-core `bc06930` + genesis `105c538`. genesis-core **71** pytest (+6: concurrent-RMW no-lost-update, crash-safety, round-trip), genesis **522** (+1: 30 parallel env upserts); ruff green. Versions/`CORE_MAJOR` unchanged.

## 1. Goal
Make **every** JSON-file store use the same atomic, serialized write pattern already proven for `secrets.json`, so concurrent writers (FastAPI runs sync handlers in a threadpool) can't corrupt a store.

## 2. Why (review evidence)
- Bible §7 records the v0.20.1 crash: two concurrent secret-set requests corrupted `secrets.json` (a valid object + leftover tail = "Extra data") → 500s. Fixed for secrets with **temp-file + `os.replace` + a per-path lock**.
- The **other JSON stores share the old non-atomic `write_text` pattern** (explicitly flagged as known-deferred): custom MCP (`mcp-custom.json`), custom CLI (`cli-custom.json`), environments (`environments.json`), native MCP/CLI lockfiles, dist config, schedule/lockfile JSON.
- Review D-1: concurrency safety is incomplete for multi-actor use.

## 3. Current state (cited)
- **Hardened:** `genesis/config/secrets.py` (`SecretProvider` — temp+`os.replace`, per-path lock).
- **Not hardened (candidates):** `genesis-core/mcp/custom_store.py`, `genesis-core/clis/custom_store.py`, `genesis/config/environments.py`, `genesis/mcp/native/lockfile.py`, `genesis/cli_tools/native/lockfile.py`, `runtime/updater.py` dist config, `runtime/schedule_store.py` (SQLite — already safe), any `*.write_text(json...)`.

## 4. Design
### 4.1 One shared primitive (`genesis-core` — since both repos have JSON stores)
Extract the proven pattern from `secrets.py` into a reusable helper:
```python
# genesis_core/util/atomic_json.py (NEW)
def atomic_write_json(path, data, *, lock: _PathLock) -> None:  # temp + os.replace under lock
def read_modify_write_json(path, mutate, *, lock) -> Any:       # serialize RMW under a per-path lock
```
- Per-path lock registry (a module-level `dict[Path, threading.Lock]`) so two requests to the *same* file serialize; different files stay parallel.
- `secrets.py` refactors to use it (no behavior change — regression-guarded).

### 4.2 Migrate each store
Point `custom_store.py` (MCP + CLI), `environments.py`, the two native lockfiles, and the dist config through `read_modify_write_json`/`atomic_write_json`. No format change; purely the write path.

## 5. Files touched
- **New:** `genesis_core/util/atomic_json.py`, `genesis-core/tests/test_atomic_json.py`.
- **Edit:** `genesis/config/secrets.py` (adopt shared helper), `genesis-core/mcp/custom_store.py`, `genesis-core/clis/custom_store.py`, `genesis/config/environments.py`, `genesis/mcp/native/lockfile.py`, `genesis/cli_tools/native/lockfile.py`, `runtime/updater.py`.

## 6. Tests
- Concurrency test: N threads each doing read-modify-write on one store; final file is valid JSON and contains all N writes (no lost update / no "Extra data" tail). This is the exact class of bug §7 describes — assert it can't recur.
- Crash-safety: simulate a failure between temp-write and replace → original intact.
- Round-trip parity per store (existing tests keep passing).

## 7. Risks & mitigations
- **Risk:** lock scope too broad → serializes unrelated writes. **Mitigation:** per-path lock keyed by resolved absolute path.
- **Risk:** cross-process (multiple `genesis` processes) writers. **Mitigation:** out of scope for single-user; note it (a file lock could be added later if multi-process becomes real).

## 8. Out of scope
DB-level optimistic locking (that's 25-08); cross-process file locking.

## 9. Definition of Done
Shared `atomic_json` helper in genesis-core; all listed JSON stores migrated; concurrency + crash-safety tests green; genesis-core + genesis releases CI-green; bible §7 note updated ("all JSON stores hardened"); progress doc.
