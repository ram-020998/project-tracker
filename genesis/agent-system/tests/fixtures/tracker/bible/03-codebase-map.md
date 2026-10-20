<!-- GENESIS BIBLE — CHUNK 03 (fixture). -->
> **This file is one chunk of the Genesis bible.** Fixture.

---

## 4. Codebase map (where things live)

```
genesis-core/genesis_core/
  types.py        PlatformContext; ValidationResult;
                  CORE_MAJOR=1.
  state.py        PlatformState TypedDict + reducers.
  nodes/  program.py; agent.py (kiro_node).
  state.py `_telemetry_merge` sums credits.

genesis/genesis/
  db/       database.py; runner.py
            migrations/ (m0001_baseline).
  chat/     manager.py; supervisor.py (read-only chat).

# ── Phase 25 — Architectural Foundation Hardening (genesis v0.49.0) ──
genesis/genesis/
  api/app.py  /api namespace + localhost guardrail.

# ── Phase 29 — UX Design stage (grounded mockup→implementation analysis; ADR-057) ──
genesis/genesis/
  kb/features.py  UX stage container.
```

---

# ── Phase 31 — Feature Breakdown stage (ADR-059) ──
genesis/genesis/
  kb/stories.py   backlog stories.

**Phase 45 — Incremental Delta Sync (genesis v0.76.0):**
```
genesis/
  kb/store.py          apply(mode='incremental').
```
