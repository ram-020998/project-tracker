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

genesis-workflows/
  registry.json (catalog + genesis_core_major=1), mcp-registry.json (REAL internal images:
  appian-atlas [read-only], jarvis [read-write-deploy], appian-data-generator, jira),
  cli-registry.json, bundles.json, schemas/, steering/01-07, ci/validate_library.py (7-gate publish
  runner), workflows/{_template, hello-appian, erd-generation}, MIGRATION.md.
  skills/{gam/SKILL.md + references/, _fixtures/noncompliant} + skills-registry.json + ci/validate_skills.py
  (self-contained pyyaml validator: registry+manifest+parity+fixture gate) — Phase 14-02.

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
