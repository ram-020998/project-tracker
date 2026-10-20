# Genesis — Decision Log (ADRs)

Each ADR: Context · Decision · Consequences. Status: all **Accepted** unless noted.

## ADR-001 — LangGraph as the orchestration engine (not an LLM orchestrator)

- **Decision:** LangGraph routes every run; agents never pick the next node.

## ADR-003 (Q1) — Local web app; shared GitLab library; internal Solutions users

A local web app on 127.0.0.1 with a shared GitLab workflow library.

## Technical ADRs (foundational)

## ADR-026 — Web workbench stack: React + TypeScript (supersedes the Preact default)

**Status:** Accepted. The web app is React + TypeScript under `genesis/web/src/app/`.

## ADR-027 — Overcut visual language for the workbench

**Status:** Accepted (2026-07-10). Extends ADR-026 (React+TS).

### ADR-027 addendum (2026-07-10) — Overcut visual study

The study confirms the node-card canvas. ADDENDUM-027-TEXT.

### ADR-028 (2026-07-11) — Backend API namespaced under `/api` + SPA history fallback

**Status:** Accepted. Every route lives under `/api` in `genesis/genesis/api/app.py`.

### ADR-029 — Two-Tier MCP/CLI Registry (revises ADR-005/020)

**Status:** Accepted. Curated + custom tiers.

## ADR-031 — Chat is a read-only conversational assistant (never orchestrates)

**Status:** Accepted. Chat never mutates; read-only `@server/tool` allowlist in `genesis/genesis/chat/manager.py`.

## ADR-033 — The Chat copilot may operate runs (human-confirmed); amends ADR-031

**Status:** Accepted. Copilot run operations need a human confirmation.

## ADR-038 — Managed native Appian MCP servers (vendored, versioned)

**Status:** Accepted. Native servers are vendored.

## ADR-040 — Managed-native CLI connector (`gws` installed inside Genesis)

**Status:** Accepted. The gws CLI is managed natively.

## ADR-051 — AgentProvider interface over the agent runtime (Phase 25-05)

**Status:** Accepted. An AgentProvider Protocol wraps the Kiro loader. ADR-051-BODY.

- **ADR-053 (ACCEPTED — Phase 26, SHIPPED genesis v0.52.0 + genesis-workflows v0.10.0)** — **Memory Layer**: personal
  vs shared memory, one `genesis-memory` MCP as the only injection path. ADR-053-BODY.
- **ADR-054 (ACCEPTED — Phase 26, SHIPPED genesis v0.52.0)** — memory **store/infra + local embedder** in
  `~/.genesis/memory.db`. ADR-054-BODY.


## ADR-026 amendment (Phase 25-04) — localhost-bind guardrail

**Status:** Accepted. Amends ADR-026: the server binds 127.0.0.1 only. AMEND-026-TEXT.

## ADR-061 — The Genesis Workbench: a per-application Kanban board (Phase 33)

**Status:** Accepted. Boards live in `genesis/genesis/kb/boards.py`.

## ADR-063 — The Genesis Collaboration Hub (Phase 35)

**Status:** Accepted. Local-first with selective centralization.

## ADR-064 — The Genesis Hub Appian application (Phase 36)

**Status:** Accepted. Frozen API contract.

## Amendment (2026-09-09, genesis v0.69.0) — explicit Workbench board membership (amends ADR-061/063/064)

Board membership is explicit. AMEND-061-TEXT.

## ADR-038/040 amendment — Phase 41 (Dev MCP 26.6.90 + SAIL CLI)

Both connectors gain version gates. AMEND-038-040-TEXT.

## ADR-076 — Spec change requests: a chat-driven CR, a program-applied plan (Phase 46) — **Accepted**

- **Status:** **Accepted** — 2026-10-15.
- **Decision.** A change request is applied by a program, never by the agent. LAST-SECTION-TEXT.
