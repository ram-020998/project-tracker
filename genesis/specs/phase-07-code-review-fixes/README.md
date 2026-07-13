# Phase 7 — Code-Review Fixes & Modularity Program

> A spec package produced from a full, code-grounded review at the **phase-7 checkpoint**
> (web revamp 07-01…07-10 essentially complete). It formalizes the review and turns every
> agreed fix into an **implementation-ready** spec. Local single-user posture unchanged
> (ADR-012/023/026/027).

**Author basis:** every claim was verified by reading the actual code in `kiro-agent-sdk`,
`genesis-core`, `genesis`, and `genesis/web` on 2026-07-11 (genesis app at **v0.11.0**).
File/function citations are inline in each doc.

---

## 1. Documents in this package

| # | Doc | Priority | Layer(s) | Depends on |
|---|-----|----------|----------|------------|
| — | [`00-code-review.md`](00-code-review.md) | — | — | — |
| 01 | [`01-p0-persistence-and-migrations.md`](01-p0-persistence-and-migrations.md) | **P0** | genesis | — |
| 02 | [`02-p0-overview-dashboard.md`](02-p0-overview-dashboard.md) | **P0** | genesis / web | — (indep. of 01) |
| 03 | [`03-p1-integrations-studio.md`](03-p1-integrations-studio.md) | **P1** | sdk / core / genesis / web | 01 (soft) |
| 04 | [`04-p2-eventlog-retention-and-bus-consolidation.md`](04-p2-eventlog-retention-and-bus-consolidation.md) | **P2** | genesis | 01 (soft), 07-10 cutover |
| 05 | [`05-p2-persistence-scale-decision.md`](05-p2-persistence-scale-decision.md) | **P2** (decision) | — | 01 |
| 06 | [`06-conversation-rich-chat.md`](06-conversation-rich-chat.md) | **P1** | web | 07-08, 07-09 |

Each numbered doc is an independently deliverable work-item that fits the multi-agent
session model in `AGENT_ONBOARDING.md` (read spec → implement → test → release + verify CI →
progress doc → push).

---

## 2. Why these, and what they fix

The review's headline: **the architecture is strong and the foundation is more solid than
first assumed** — in particular the run/conversation data is already in **SQLite** (not JSON
files), and the conversation is durably persisted. Two premises in the original ask were
partly mistaken; one (MCP/CLI modularity) is a real, largely-unbuilt gap. The fixes:

- **01 (P0) — Persistence & migrations.** The DB is real but coupled: raw `sqlite3` + hand-written
  DDL in three places, **no migration framework**. This is the #1 foundational risk before more
  features land. Introduce a `genesis/db/` layer + a minimal migrator + repository pattern.
- **02 (P0) — Overview dashboard.** The landing screen (`GET /home` exists) is a **static
  placeholder** that never calls the API. Wire it; extend `/home` with metrics/active-runs/health.
- **03 (P1) — Integrations Studio.** MCP/CLI are **read-only manifest registries** installed from
  the library; you cannot add a custom server/CLI, edit its JSON, or set a per-tool allowlist from
  the app. Build a **two-tier registry** (curated + custom-writable) with CRUD, a JSON editor,
  secrets, **tool introspection + allowlist**, and a real connection test. Revises ADR-005.
- **04 (P2) — Retention & bus consolidation.** `run_events` grows unbounded (no automated purge);
  a **dual event bus** (`_buses` legacy + `_cbuses` canonical) carries interim debt to remove at cutover.
- **05 (P2) — Scale decision.** A framework for **when** SQLite→Postgres/pgvector is warranted
  (multi-user, or transcript search/RAG) — decision doc, not implementation.
- **06 (P1) — Conversation rich chat.** Upgrade the Run-Detail Conversation tab to the polished
  agent-chat UX studied in the `ai-sre` reference (unified auto-expand/collapse **Thinking**
  timeline, **markdown** answers, streaming affordances) while keeping our stronger durable
  event-fold engine + reliability semantics.

---

## 3. Recommended sequencing

```
P0  01 persistence/migrations ─┐
    02 overview dashboard ─────┤  (01 & 02 are independent; do in parallel)
                               │
P1  03 integrations studio ────┤  (soft-depends on 01 for the custom store; can start on a file store)
    06 conversation rich chat ─┘  (independent; pure frontend)
                               │
P2  04 retention + bus cleanup │  (after 01; bus removal at the 07-10 cutover)
    05 scale decision (ADR)    ┘  (revisit only when a §5 trigger fires)
```

**Do first:** 01 (unblocks every future data feature) and 02 (fast, visible, closes a gap you
flagged). 06 is a self-contained frontend win that can run alongside. 03 is the largest initiative
(a mini-phase). 04/05 are hardening/decision items.

---

## 4. Conventions used in these specs

- **Current-state** sections cite real files/functions so an implementer can diff against them.
- **Non-goals** are explicit to prevent scope creep (esp. no auth/multi-tenancy — ADR-026).
- **Definition of Done** mirrors the existing CI gates (backend `pytest`+`ruff`; web
  `tsc`+`vitest`+`build`+stale-bundle guard) and demands tests for new logic.
- **Deviations/risks** are called out honestly, per the project's pushback norm.
- Build-alongside invariant (until 07-10 cutover): do **not** commit `web/static/`.

---

## 5. Status

| Doc | Status |
|-----|--------|
| 00 code review | ✅ Drafted |
| 01 persistence/migrations | ✅ Implemented — genesis v0.12.0 |
| 02 overview dashboard | ✅ Implemented — genesis v0.12.1 |
| 03 integrations studio | ✅ Implemented — genesis-core v0.5.0 + genesis v0.13.1 |
| 04 retention + bus | ✅ Implemented — genesis v0.14.0 |
| 05 scale decision | ✅ Decided — remain on SQLite (ADR-030); re-open on trigger |
| 06 conversation rich chat | ✅ Spec drafted — not implemented |

Update this table + `tracker.md` §6 as each item is implemented.
