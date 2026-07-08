# Genesis — Phase 1 De-risking Spike: Findings

**Date:** 2026-07-08 · **Status:** ✅ PASSED (all assumptions validated) · **Task:** Phase 1, Task 0 (ADR-012/019 gate).

The spike proved the load-bearing LangGraph assumptions before building. Throwaway
code lived in `repo-gitlab/ramaswamy.u/_genesis_spike/` (`spike_inprocess.py`,
`worker.py`, `driver_worker.py`); it is not part of any repo.

---

## 1. Environment / versions (verified)

| Component | Version | Notes |
|---|---|---|
| Python | **3.13.3** chosen (pin) | System is 3.14.6; 3.10.17 also present. |
| langgraph | **1.2.8** | Installs + imports cleanly on **both 3.13 and 3.14**. |
| langgraph-checkpoint | 4.1.1 | |
| langgraph-checkpoint-sqlite | 3.1.0 | |
| **aiosqlite** | (required) | Needed by `AsyncSqliteSaver` — see Finding A. |

**Version decision:** pin **Python 3.13** as the baseline (fully supported by
LangGraph + the wider wheel ecosystem: FastAPI/uvicorn/native deps). 3.14 works
for langgraph core but is bleeding-edge for the rest of the stack; not adopted.
→ recorded as ADR-024's version note; supersedes the "3.11+" placeholder in ADR-017.

---

## 2. Assertions validated (25 total, all PASS)

**In-process (`spike_inprocess.py`, 14):**
- (a) SQLite checkpointer takes a per-superstep snapshot (5 checkpoints for a 3-node graph + input); graph completes.
- (b) `interrupt()` pauses the run (`snapshot.next == ("gate",)`, `__interrupt__` payload surfaced); `Command(resume="approve")` completes and applies the decision. → **HITL mode 1**.
- (c) `update_state(cfg, {...})` edits the checkpointed state; resume honors the edit (`consume:EDITED`). → **HITL mode 3**.
- (d) **Fork** to an independent run (see Finding B); original thread head untouched.
- (e2) Async node runs via `ainvoke` + `AsyncSqliteSaver`.
- (g) Compat-gate sketch refuses on `genesis_core` major skew (platform 1.x vs library 2.x).

**Subprocess worker (`driver_worker.py` + `worker.py`, 11):**
- (e) Worker runs a graph against a shared async checkpointer; killed (SIGKILL) mid-`n2`; a **fresh worker resumed** with `ainvoke(None, cfg)` and completed `["n1","n2","n3"]` — **completed node `n1` was NOT re-executed**. → validates ADR-012 disposable-worker + checkpoint-driven resume.
- (f) `sys.exit(3)` inside a node → worker exits rc=3, no RESULT, **parent survives**. An infinite hang → parent not blocked, kills the worker (rc=-9) and **survives**. → validates crash/hang isolation.

---

## 3. Spec-affecting findings

### Finding A — the engine must be ASYNC-first (`AsyncSqliteSaver` + `aiosqlite`)
`kiro_node` is async (`kiro-agent-sdk`'s `collect()` is a coroutine). The spike
proved that **sync `invoke()` cannot bridge an async node** — LangGraph raises
`TypeError: No synchronous function provided to "<node>"`. And the **sync
`SqliteSaver` raises `NotImplementedError` on async execution**.

**Decision (ADR-024):** Genesis runs graphs via the **async API** (`ainvoke` /
`astream`) with **`AsyncSqliteSaver`** (requires **`aiosqlite`**). This affects:
- Phase 1 `runtime/checkpoint.py` → `AsyncSqliteSaver.from_conn_string(genesis.db)`.
- Phase 1 `runtime/engine.py` → `async run()/resume()` using `ainvoke/astream`.
- Phase 1 deps → add `aiosqlite`.
- The subprocess **worker** is an async entrypoint (`asyncio.run(main())`).

### Finding B — "fork" = seed a NEW thread (LangGraph time-travel rewinds the head)
`update_state()` on a *past* checkpoint of a thread **branches within that same
thread** (the thread head moves back onto the branch). That is LangGraph
time-travel, but it does **not** satisfy Genesis's spec of "fork = an independent
run, original intact." The working pattern (validated): read the target
checkpoint's `values`, then **seed a new `thread_id`** via
`update_state(new_cfg, values, as_node="<producing_node>")` so the new thread is
positioned at the right next-node, then resume it.

**Decision (ADR-025):** Genesis fork copies a chosen checkpoint's state into a
**new run/thread** (`as_node` seeding), leaving the original run untouched.
Affects `hitl-design.md` (Mode 3 fork) and Phase 5 `runs/hitl.py` `/fork`.

---

## 4. No blockers
No assumption failed. Both findings are refinements that make the design more
precise; neither contradicts an existing ADR. Cleared to scaffold repos and build
Phase 1.
