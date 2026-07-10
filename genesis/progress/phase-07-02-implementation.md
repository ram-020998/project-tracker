# Genesis — Phase 7.2 (Web Revamp: Backend Data Plane) Implementation Record

> As-built record of `specs/phase-07-02-backend-data-plane.md`. The critical-path,
> cross-repo enabler for the web revamp (M7.1).

**Date:** 2026-07-10 · **Milestone:** M7.1 · **Status:** ✅ COMPLETE — released +
CI green across all four repos.

---

## 1. What shipped

The full data plane the revamped UI needs, implemented durable-first and additive
(no breaking changes mid-migration):

- **Persistent event log** — `genesis/runs/eventlog.py` `EventLog` over a new
  `run_events` table (WAL, shared `genesis.db`): `append/list(after_seq,kinds,node)/
  last_seq/latest/purge`, monotonic `seq`. Every worker event is now written to the
  log AND fanned out live. A run's timeline + conversation survive a reload/restart.
- **Gate from checkpoint (the approval-bug fix)** — `hitl_gate` now emits a full
  **GateDescriptor** (`node,kind,prompt,options,context_refs,raised_at`).
  `RunManager.pending_gate()` derives it durably: fast path from the log's latest
  `gate.awaiting` (unless a later `gate.resolved`), cold path reconstructing from the
  checkpoint's pending `__interrupt__` write. `GET /runs/{id}` now returns
  `gate: GateDescriptor|null`. **Regression test proves the gate is reachable from a
  brand-new RunManager (simulated server restart).**
- **Canonical event union** — the manager maps worker events + `ctx.emit` payloads
  into stable kinds: `run.started, node.completed, agent.message|thought|tool_call|
  tool_update|result, validator.result, retry.scheduled, gate.awaiting|resolved,
  run.final, error, custom`.
- **Live Kiro conversation** — SDK `collect_streaming(prompt, options, *, on_message)`
  (v0.1.0; `collect` now delegates to it). `kiro_node` prefers streaming and forwards
  each ACP message to `ctx.emit` as `agent.*` events (graceful fallback to `collect`
  when the SDK predates streaming, and when a test injects a collect stub). Trio emits
  `validator.result` + `retry.scheduled`.
- **Topology / steps / artifacts / status** — `loader.graph_of` (authored
  `graph:` section or linear fallback) + `GET /workflows/{id}/graph`;
  `GET /runs/{id}/steps` (per-node fold); `GET /runs/{id}/events` (durable, paginated)
  + `GET /runs/{id}/events/stream` (canonical replay-after-seq then live tail, dedupe
  by seq); artifact `media_type`/`preview_kind` in the listing + `GET
  …/artifacts/{name}` (preview/full, path-traversal rejected) + `…/download`;
  mcp-card `status` field. `respond` validates the decision against `gate.options`
  (400 `GateResponseError`).
- **ERD graph section** — `erd-generation/workflow.yaml` gained a `graph:` topology
  (11 nodes / 16 edges) matching `graph.py`; the contract parity lint now exempts
  yaml-only presentation keys (`graph`).

## 2. Tests

- kiro-agent-sdk: `collect_streaming` observer+aggregation, `collect` delegation — **41 pass**.
- genesis-core: `kiro_node` streaming-emit (+ stub-fallback preserved) — **17 pass**.
- genesis: `tests/test_dataplane.py` (5) — EventLog unit, durable events+steps,
  **gate-survives-restart**, respond option validation, API graph/events/steps +
  artifact content/traversal — **48 pass** total.
- genesis-workflows: library validation passes (2 workflows) with the new graph
  section — **9 workflow tests pass**. Package ruff clean (CI lints package dirs only).

## 3. Releases (dependency order, all CI green)

kiro-agent-sdk **v0.1.0** → genesis-core **v0.4.0** (pin sdk v0.1.0; CORE_MAJOR
stays 1) → genesis **v0.7.0** (pin core v0.4.0) → genesis-workflows **v0.3.0**
(pin core v0.4.0 + genesis v0.7.0; this also cleared the stale dev pins). Note: the
first push attempt failed on an SSH timeout to gitlab; retried successfully.

## 4. Deferred (noted follow-ups)

- Per-integration connection **test** endpoint + `cli-cards` (status field is done;
  the Settings screen 07-04 will need the test action).
- `artifact.written` events (documents drawer currently refetches on status change).
- Retention purge of the event log (retention is display-only for now).
- Shared golden event-shape **fixtures** will be materialized with the frontend
  `types/` in 07-10 (shapes are currently asserted by `test_dataplane`).

## 5. Next

07-03 (design system) + 07-04..09 (screens) now have their data contracts. The
run-detail centerpiece (07-07/08/09) can consume `/graph`, `/events(/stream)`,
`/steps`, `gate`, and artifact content directly.
