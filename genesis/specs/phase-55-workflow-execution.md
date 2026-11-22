# Phase 55 — Workflow execution: memory brief, agent-assisted escalation, Documents and a reliable run graph

> **Status:** 📝 **SPEC-DRAFTED 2026-11-22** (genesis-spec). Q&A complete: decisions D1–D11, defaults F1–F15; D12–D15
> from the 55-02 mockup review (2026-11-23) (`phase-55-workflow-execution/55-01-findings.md` §9–§11). 55-02 BUILT.
> Sub-specs: `phase-55-workflow-execution/55-01..55-12`. ADR drafts: `phase-55-workflow-execution/adr-drafts.md`
> (ADR-088, ADR-089, ADR-090).
> Repos: **genesis** (worker, runs, memory, chat, API, web, `packages/genesis-core` nodes and lint),
> **genesis-workflows** (every workflow with an agent node adopts the standard escalation gate and artifact roles),
> **project-tracker** (ADRs, areas, lessons). Builds on genesis v0.83.0 / genesis-workflows v0.27.0.
> Ships after its own review and its own live acceptance; the open Phase 51/53/54 live acceptance is not a gate (D11).

## 1. Why this phase exists

Four weaknesses in how every workflow runs (55-01 §2–§5):

- Memory is distilled every night but no workflow reads it (§2).
- An escalation gives the user approve / reject / feedback with no real control, and in most workflows **any** answer,
  Reject included, ends the run `done` and promotes whatever file exists (§3.1).
- Run Detail's Documents tab is a flat, name-sorted list: the producing step and time of a deliverable are unknown,
  "Result" is a filename guess, and tool outputs, prompts and inputs are mixed or missing (§4).
- The live graph lags the backend, looks stuck for minutes during long nodes and lights the edge into a finished node,
  because the backend never records a node start and the page reads the last completed node as "running" (§5).

## 2. Goal

1. **Memory brief** in every run with an agent node: a program prefetch writes `_memory/brief.md` (shared + the user's
   personal memories); every agent prompt points at it; agent nodes get the read-only memory tools (D2–D5).
2. **Agent-assisted escalation:** one standard escalation gate with six actions; a Resolve agent in Run Detail
   explains the failure and proposes actions; the user confirms; program code applies (D6, D7).
3. **Documents tab revamp:** every file categorized (Output, Inputs, Steps, Tool outputs, System) with its step, time,
   size and write count; mockup first (D8, D9).
4. **Reliable run graph:** a real `node.started`, one versioned snapshot, edges from node states, SSE hints with a 3 s
   poll floor (D10).

## 3. Decisions (locked with the user, 2026-11-22 — detail and rationale in `55-01-findings.md` §9–§10)

| # | Decision |
|---|---|
| D1 | Scope: all four parts in Phase 55, for every workflow. |
| D2 | Memory brief = KiroCrew-style program prefetch from a generic run description (no per-workflow declaration), pointer line in every agent prompt, read-only `genesis-memory` MCP on every agent node; agent-turn brief is the upgrade path. |
| D3 | Default embedder fastembed `BAAI/bge-small-en-v1.5`, installed by default, fetched by the install script with a pinned checksum; existing memories back-filled. |
| D4 | Every run with an agent node gets a brief; `META.memory_brief: false` opts out (the memory workflows); resume reuses, fork copies. |
| D5 | The brief includes the user's personal memories in a separate section; never published to the Hub. |
| D6 | One standard escalation gate in genesis-core with six actions: retry with guidance, accept as is, fix then accept, rerun from the start (with additional instructions, D13), restart from a step (rebinds and cancels, D15), stop. Agent suggests, the user confirms, program code applies; state-built wording (L-106); audited. |
| D7 | The Resolve chat lives only in Run Detail; started on first open; read-only run access + the six actions; every escalation raises a bell notification. |
| D8 | Documents layout (grouped list + viewer; By step / By type; Output · Inputs · Steps · Tool outputs · System); **55-02 mockup first**, reviewed by the user. |
| D9 | No old versions and no tool-output files kept: a write count instead of versions; tool outputs as event metadata after the run ends. |
| D10 | Run graph: versioned server snapshot, `node.started` from LangGraph's `tasks` mode, edges from node states, SSE hints with `id:`/resume, 3 s poll floor, honest Live badge. |
| D11 | Phase 55 ships after its own review and live acceptance; Phase 51/53/54 acceptance is done later by the user and named as open in the release (L-111). |
| D12 | 55-02 mockups approved as mocked (genesis `d0aa1b2`), with the dev's open choices: "written N times · latest", the edge into a waiting gate lit in the warning colour, on a loop re-entry only the edge just taken lit, the brief under Inputs, System collapsed in By type, Resolve credits in the tab and the run total, the bell links to `/runs/<id>/resolve`, the mockup's payload and action names are the contract, "Needs you" pill. |
| D13 | Rerun from the start reuses every input unchanged and takes only additional instructions, which every agent node of the new run gets (amends D6 action 4, F9: `relaunch {instructions}`). |
| D14 | Resolve is its own Run Detail tab beside Flow and Documents with the facts sidebar; action results show in that tab. |
| D15 | Restart from an earlier step forks from the checkpoint, moves the stage/story to the new run and cancels the escalated run, which links to it (amends D6 action 5); the plain fork is unchanged. |

## 4. Current state (code-grounded — full detail in `55-01-findings.md` §2–§5)

- Memory: 63 memories, embeddings skipped (no embedder installed), messy anchors; `HybridRetriever` and the read-only
  `genesis-memory` MCP exist, wired to chat only; `ctx.extras["memory_store"]` in every run (§2).
- Escalation: thin gate payload; escalate→END in most workflows; no relaunch, override or retry-from-node; finalizers
  act on `done` + an artifact; copilot confirm cards and the StageFinalizer chat-seeding pattern exist (§3).
- Documents: `manifest()` = rglob + bytes; only prompts attributed; outputs overwritten in place; `_toolcalls/` purged
  at the end (§4).
- Graph: `stream_mode=["updates","custom"]`; cursor = last completed node; edge lit by the cursor; `/steps` re-reads
  the whole log and polls only while something reads running; SSE replays from 0 and never reconnects (§5).

## 5. Design overview

| Concern | Sub-spec |
|---|---|
| Findings, research, decisions | 55-01 |
| Mockups: Documents tab, Resolve, graph states (approval gate; approved, D12–D15) | 55-02 |
| Run liveness: `node.started`, snapshot fold, hint SSE, transport fixes, run graph web | 55-03 |
| Memory brief: run description, prefetch, embedder default + install + back-fill, prompt line, memory MCP on nodes | 55-04 |
| Document records: `file.written`, META artifact roles, categorization service | 55-05 |
| Standard escalation gate, gate payload, run actions (relaunch, fix-then-accept), lint, audit | 55-06 |
| Resolve agent: chat mode, run-scoped tools, proposals, sandbox, notifications | 55-07 |
| HTTP API (contract table, types, fixtures; migration if needed) | 55-08 |
| Web: Documents tab revamp, Resolve tab | 55-09 |
| Library adoption (genesis-workflows) | 55-10 |
| Review, hardening, live acceptance | 55-11 |
| Release + docs write-back | 55-12 |

## 6. Session plan

S1 = 55-02 (**gate:** the user reviews `/dev/phase-55`; requested changes become decisions in 55-01 §9 and are folded
into 55-03 / 55-09 by the spec agent before they start) → S2 = 55-03 → S3 = 55-04 → S4 = 55-05 → S5 = 55-06 → S6 =
55-07 → S7 = 55-08 (each backend sub-spec adds its own routes; 55-08 owns the contract table, web types and fixtures
and adds what is left) → S8 = 55-09 → S9 = 55-10 (genesis-workflows, against the local genesis build) → S10 = 55-11
(genesis-review) → S11 = 55-12 (genesis-release, then genesis-docs). One at a time: they share the genesis checkout.
Every intermediate commit keeps the gates green. Fold each As built into the later sub-specs before they start.

## 7. Sub-phase ledger

| Sub-phase | Repo | Content |
|---|---|---|
| 55-01 | project-tracker | Findings, research, decisions D1–D11, defaults F1–F15 |
| 55-02 | genesis (`web/src/dev/`) | `/dev/phase-55` mockups with stub data: Documents tab (both views, every category, old-run fallback, live run), Resolve (first turn, proposals, confirm, each action's result), graph states (running program node, loop re-entry, gate, paused, disconnected) — **BUILT** (genesis `7f32ac0..d0aa1b2`, local; review SHIP; user review D12–D15: Resolve as a tab) |
| 55-03 | genesis (`runs/`, `api/run_routes.py`, `web/src/features/run-detail/`) | `tasks` stream → `node.started`; snapshot fold + `GET /runs/{id}/snapshot`; hint SSE `GET /runs/{id}/live`; bounded bus, async subscribers, pump logging, stderr drain; graph web on the snapshot |
| 55-04 | genesis (`memory/`, `runs/worker.py`, `runtime/context.py`, `mcp/memory_server.py`, `packages/genesis-core` `kiro_node`, `scripts/install-packages.sh`) | Run description, prefetch, `memory.brief` event, prompt line, memory MCP on nodes, bge-small default + install + back-fill, fork copy |
| 55-05 | genesis (`runs/`, `lint/contract.py`, `packages/genesis-core`) | `file.written` from the worker's task start/finish diff; `META.artifacts` map form + parity lint; `runs/documents.py` categorization; `GET /runs/{id}/documents` |
| 55-06 | genesis (`packages/genesis-core` nodes + `lint/reliability.py`, `runs/manager.py`, `api/features.py`, `api/workbench.py`) | `escalation_gate` (routes, payload, guidance and run-instructions lines), old answers mapped, relaunch with instructions, restart from a step (fork + rebind + cancel), fix-then-accept, `copilot_actions` audit |
| 55-07 | genesis (`chat/`, `mcp/`, `runtime/notifications.py`) | `run_resolve` chat mode, run-scoped read tools + `propose_action`, sandbox copy, first-turn seed, notifications on every escalation |
| 55-08 | genesis (`api/`, `db/`, `web/src/types`, `web/src/lib/api`) | Contract table for every new route; Resolve session storage (m0031 if needed); fixtures from real responses |
| 55-09 | genesis (`web/`) | Documents tab revamp; Resolve tab (chat, proposal cards, manual action menu, confirm dialogs, results; `/runs/:runId/resolve`) |
| 55-10 | genesis-workflows | Standard gate in every workflow with an agent node; `META.artifacts` roles + labels; `memory_brief: false` on the memory workflows; versions bumped |
| 55-11 | all | Review + gates + live acceptance (Phase 55 only, D11) |
| 55-12 | genesis, genesis-workflows, project-tracker | Releases + docs write-back (ADR-088..090, L-005, lessons, areas, state, progress) |

API sub-spec: **55-08**.

## 8. Release plan

One release after 55-11 = SHIP with its live acceptance done (D11): **genesis v0.84.0** (app + three packages at one
shared version, ADR-080; genesis-core additive, `CORE_MAJOR` 1; m0031 only if 55-08 needs it), then **genesis-workflows
v0.28.0** (pins on `genesis.git@v0.84.0`, L-057; the standard gate needs genesis ≥ 0.84.0). The release notes, README
row and state say the Phase 51/53/54 live acceptance is still open (D11, L-111). Users: the embedder model is fetched by
`scripts/install-packages.sh`; update every workflow from Catalog after the library release (L-033).

## 9. Scope

**In:** §2. **Out:** an agent-written memory brief (D2's upgrade path); per-workflow memory query declarations;
keeping old file versions or tool-output files after a run (D9); a Resolve chat on the Chat page (D7); the Resolve
agent applying actions itself; Qwen3-size embedders; parallel-branch attribution of file writes (no workflow uses
`Send`; 55-05 records the limit); multi-user anything (ADR-026). **Deferred** (to `specs/backlog/phase-55-follow-ups.md`
at write-back): the agent-written brief, versions, memory-usage feedback into ranking (`mark_used`), anchor
normalization in consolidation.

## 10. Defaults

F1–F15 in `55-01-findings.md` §10 (confirmed 2026-11-22).

## 11. Risks

| Risk | Mitigation |
|---|---|
| Brief relevance is weak (keyword-only before back-fill; long run descriptions) | 55-04 tests on the real 63 memories with real run inputs; acceptance reviews three real briefs; agent nodes can still call `search_memory` |
| Memory text carries instructions from old chats (prompt injection) | The brief header and prompt line mark memories as data; entries are quoted verbatim, never merged into the prompt body |
| `tasks` stream mode behaves differently on resume, retries or interrupts | 55-03 starts with a spike on LangGraph 1.2.8 covering resume after a gate, a retry loop and a pause/kill |
| Accept as is lets an invalid output reach later nodes, which then fail | Accept is offered only when the failed node's output exists and is non-empty; a later failure fails the run normally and is shown in Resolve |
| A relaunch races the escalated run's worker or a finalizer (L-108, L-061) | The escalated run is cancelled through the stop-intent + CAS path first; the stage/story is rebound before the new run starts; tests through the real `_finalize` (L-093) |
| The Resolve agent's files go stale while it talks | The sandbox copy is refreshed on each new escalation; proposals are re-validated against the run's current state at apply time |
| `file.written` misattributes a file written by a background thread after its node ended | The diff is taken at task start/finish in the worker; late writes are attributed to the next node and documented; acceptance checks the four stage workflows |
| The library adoption changes routing in 16 workflows | Per-workflow route tests: each action → its route → the stored outcome (L-106); a CI-image run before the release commit (L-112) |
| The fleet restarts on a build with an unreleased migration | No fleet restart before the release; a migration edited in place re-checks process start times (54 D36 pattern) |

## 12. ADR summaries

- **ADR-088 (draft) — Memory brief.** Program prefetch at run start into `_memory/brief.md`, a pointer line in every
  agent prompt, the read-only memory MCP on agent nodes, never fails a run, bge-small default. Amends **ADR-053**,
  **ADR-054**.
- **ADR-089 (draft) — Standard escalation gate + Resolve agent.** Six confirm-gated actions; the agent proposes, the
  human confirms, program code applies. Amends **ADR-011**, **ADR-031**, **ADR-033**.
- **ADR-090 (draft) — Versioned run snapshot.** The graph renders from one snapshot; SSE is a hint; `node.started`
  canonical (updates **L-005**).

## Context manifest

```toml
areas    = ["runs-worker", "web-runs", "memory", "chat", "core-engine", "workflows-library"]
adrs     = ["ADR-001", "ADR-011", "ADR-019", "ADR-025", "ADR-031", "ADR-033", "ADR-053", "ADR-054", "ADR-066"]
lessons  = ["L-005", "L-059", "L-060", "L-066", "L-106", "L-111"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/adr-drafts.md"]
code     = ["genesis/genesis/runs/**", "genesis/packages/genesis-core/genesis_core/nodes/**", "genesis/web/src/features/run-detail/**"]
upstream = []
```
