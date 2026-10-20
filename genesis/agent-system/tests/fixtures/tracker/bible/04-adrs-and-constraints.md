<!-- GENESIS BIBLE — CHUNK 04 (fixture). -->
> **This file is one chunk of the Genesis bible.** Fixture copy of the real shapes.

---

## 5. Non-negotiable constraints (ADRs — do not violate; flag + confirm if a task requires it)

- **ADR-001** — **LangGraph orchestrates; agents never route.** The graph decides the next node.
- **ADR-002/004/020** — **Kiro via the SDK; per-node MCP; no global Kiro mutation.** COMBINED-BULLET.
- **ADR-005 (+ ADR-029)** — **Two-tier MCP/CLI registry.** PLUS-BULLET.
- **ADR-026** — **React + TypeScript web.** Localhost bind only.
- **ADR-031** — **Chat is read-only.** It never orchestrates; read-only `@server/tool` allowlist.
- **ADR-053 (ACCEPTED — Phase 26, SHIPPED)** — **The Memory Layer.** One MCP injection path.

- **The Q1–Q14 product decisions (ADR-003, ADR-006–009, ADR-013–017)** — local web app (Q1). RANGE-BULLET.

**Key implementation contracts:**
- Node fns are `async fn(state, config: RunnableConfig)`.
- ACP MCP entries: `env` is a **LIST** of `{name,value}`.

---
- **ADR-061 (ACCEPTED — Phase 33, SHIPPED genesis v0.61.0)** — **The Workbench board.** Per-application Kanban.

- **Amendment (v0.69.0) — Workbench board membership is EXPLICIT (amends ADR-061 + ADR-063).** AMEND-BULLET.
