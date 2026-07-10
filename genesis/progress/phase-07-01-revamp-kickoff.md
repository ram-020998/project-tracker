# Genesis — Phase 7.1 (Web Revamp) Kickoff Record

> Planning/kickoff record for the **Web Revamp** program (M7.1 — a sub-series of
> Phase 7). Companion to `specs/phase-07-01..10-*` and ADR-027. This documents the
> decisions and the root-cause findings that motivated the program; per-sub-spec
> as-built records will follow as each is implemented.

**Date:** 2026-07-10 · **Milestone:** M7.1 (Web Revamp) · **Status:** 🟡 Specced,
implementation started (07-02 data plane in progress).

---

## 1. Why this program exists (what live use revealed)

After Phases 1–7 shipped, the user ran real workflows through the interim workbench
and hit hard limits. Investigating the code (not guessing) produced three findings:

1. **HITL gate approval is unreachable after a reload/restart.** The `awaiting`
   event that drives the approval UI lives **only in an in-memory `EventBus`**
   (`runs/manager.py`) and is never persisted. On page reload, opening a run later,
   or (most commonly) after restarting the long-lived `genesis serve`, the bus is
   empty → the `GatePanel` never renders → the user sees status
   `awaiting_input:gate` but **no actionable control**. This exactly matches the
   reported symptom (ERD ran, produced documents, waited for approval, could not be
   approved from the UI). Root cause: gate state must derive from the **persistent
   checkpoint**, not a transient event.
2. **The Kiro conversation is discarded.** `kiro_node` uses `collect()` and keeps
   only the final output. The SDK's `prompt()` already yields typed
   `AgentMessageChunk / AgentThoughtChunk / ToolCall / ToolCallUpdate / ResultMessage`
   — none of it reaches the UI. "Show what Kiro is doing" is feasible but needs
   wiring, not new capability.
3. **The UI under-exposes the platform generally.** No workflow graph, no per-node
   inspection, no document preview, raw-JSON-as-primary-surface, a hand-rolled
   frontend (hash router, raw fetch, `theme.css`) with no design system or
   server-state layer — not a foundation for the planned feature set.

**Conclusion:** a full, spec-first rebuild — and it is **full-stack**, because parts
of the target UX are not yet *emitted* by the backend.

---

## 2. Decisions taken this session

- **Full rebuild** of `genesis/web/` (user directive), not a retrofit.
- **Any repo may be touched** for a solid implementation (user authorized the
  cross-repo data-plane work spanning genesis / genesis-core / kiro-agent-sdk /
  genesis-workflows).
- **Stack (ADR-027):** Vite + React 18 + TS (strict) · React Router v6 · TanStack
  Query v5 (+ typed `EventSource`→Query bridge) · Zustand · Tailwind + shadcn/ui ·
  React Flow (`@xyflow/react`) · react-hook-form + zod · react-markdown + mermaid +
  shiki · Recharts · lucide-react · Vitest + RTL + MSW + Playwright.
- **UX bar:** Overcut (https://overcut.ai) — dark-first, dense, calm agentic-SDLC
  control plane. Local single-user only (ADR-026 unchanged; no auth/RBAC).
- **Spec-first:** author the full spec series before implementation.

---

## 3. What was produced (specs)

Ten detailed specs in `specs/phase-07-0N-*` + ADR-027 + tracker spec-index/status-log:

| Spec | Scope |
|---|---|
| 07-01 | Program overview & frontend architecture (anchor) |
| 07-02 | Backend & core data-plane (persistent event log, gate-from-checkpoint, ACP conversation streaming, topology/steps/artifact-content/status APIs) |
| 07-03 | Design system & component library |
| 07-04 | Settings & configuration |
| 07-05 | Catalog & install management |
| 07-06 | Runs list & history |
| 07-07 | Run detail — graph visualization & orchestration state |
| 07-08 | Run detail — node inspection, Kiro conversation & HITL |
| 07-09 | Documents & artifact preview |
| 07-10 | Testing, CI & rollout (cutover from interim web) |

---

## 4. Implementation sequencing

Critical path: **07-02 (data plane)** and **07-03 (design system)** unblock
everything; then the screen specs (04–09); then 07-10 testing/rollout. Backend
changes are **additive** (no breakage mid-migration). Planned version bumps:
kiro-agent-sdk v0.1.0 · genesis-core v0.4.0 (CORE_MAJOR stays 1) · genesis v0.7.0 ·
genesis-workflows v0.3.0. Release order: sdk → core → genesis → workflows.

**Status at time of writing:** starting 07-02 (the data plane) first, since it is
the enabler for the durable-gate fix and the conversation/graph/document features.

---

## 5. Open notes / risks

- The live Kiro-conversation and live-graph features cannot be verified headlessly
  (need real Kiro/MCP + a browser); component tests use scripted event fixtures, and
  the durable-gate fix is verifiable via a simulated-restart test.
- Reminder: rotate the shared `GITLAB_PUSH_TOKEN` (exposed earlier).
- genesis-workflows dev pins are stale (core v0.3.2 / genesis v0.6.3) — will be
  bumped when 07-02 releases new versions.
