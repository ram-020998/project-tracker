# Phase 55 — ADR drafts

> **Status:** ✅ **FILED 2026-11-24** (genesis-docs, 55-12 §3): ADR-088, ADR-089 and ADR-090 are **Accepted** in
> `reference/decision-log.md`, brought up to date with the build first (ADR-088: D17, D25; ADR-089: D13, D15,
> D21–D26, D31, D35 and the 55-11 fix pass; ADR-090: D16). The decision log is now their one home; the text below is
> the frozen draft, kept for history. DRAFT 2026-11-22 (genesis-spec).
>
> Was: filed by genesis-docs at the release write-back (55-12 §3) into
> `reference/decision-log.md`; until then this file is the one home of the drafts and every sub-spec that relies on them
> lists it in its manifest `docs`. Each build sub-spec keeps the draft it touches current (its As built names any
> change). Source of every clause: `55-01-findings.md` §9 (D-numbers) and §10 (F-numbers).

## ADR-088 (draft) — Memory brief: a program prefetch at run start plus the memory tools on every workflow agent node

- **Status.** FILED as Accepted 2026-11-24 (was PROPOSED — Phase 55). Amends **ADR-053** (injection no longer MCP-only; the deferred prefetch and
  agentic-node MCP seams are built) and **ADR-054** (default embedder).
- **Areas.** memory, core-engine, runs-worker.
- **Rule (one-liner).** At run start program code writes a budgeted memory brief into the blackboard and every agent prompt points at it; agent nodes get the read-only genesis-memory MCP; a brief never fails a run.
- **Context.** Memory was distilled nightly but read only by chat (55-01 §2). ADR-053 deferred prefetch and node-level
  MCP injection. Workflow inputs differ per workflow; KiroCrew prefetches by the request text plus a recall tool
  (55-01 §6.2).
- **Decision.**
  1. **Program prefetch, no agent turn (D2).** Before the graph starts (`op == "run"` only), the worker renders a
     generic run description — `META` name, summary and node descriptions plus every input, ids resolved to names via
     the KB — runs `HybridRetriever` for shared memories and the user's personal memories (D5), and writes
     `_memory/brief.md` within the F1 budget, marked as data, not instructions. No per-workflow configuration.
  2. **Pointer line + tool (D2, F4, F5).** When the brief exists, `kiro_node` appends one line to the prompt; every
     agent node also gets the read-only `genesis-memory` MCP (internal, trusted read tools, owner = the user) to fetch
     more on demand. A node opts out with `kiro_node(memory=False)`.
  3. **Which runs (D4).** Every run whose compiled graph has an agent node; `META.memory_brief: false` opts a workflow
     out (the two memory workflows). Resume reuses the brief; a fork copies it (ADR-025).
  4. **Never fails a run (F3).** Any failure → no brief, a `memory.brief` event with the reason, no prompt line.
  5. **Privacy (D5).** The brief stays in the local run folder; a personal memory is never copied into anything
     published to the Hub. Memory consolidation skips Resolve chats, which quote the brief (D25).
  6. **Embedder (D3).** fastembed `BAAI/bge-small-en-v1.5` is the default backend, installed by default and fetched by
     `scripts/install-packages.sh` with a pinned checksum; loaded only in worker/MCP subprocesses (ADR-054 unchanged on
     that); existing memories back-filled once.
- **Alternatives.** An agent turn that queries and writes the brief (better relevance today, one turn and 30–90 s per
  run, an ADR-011 exception) — kept as the upgrade path; per-workflow input declarations (authoring burden, messy
  anchors); KiroCrew's Qwen3-Embedding-0.6B (too heavy per worker).
- **Consequences.** genesis-core additive (`CORE_MAJOR` 1); one new canonical event; brief quality depends on the
  embedder and the run description; personal memories now reach workflow agents.
- **As built (55-04, genesis `d1ab6d13`/`419d8363`).** The model is fastembed's own source, the quantized ONNX
  `qdrant/bge-small-en-v1.5-onnx-q` at a pinned revision (5 files, 67 MB, SHA-256 in `genesis/memory/model.py`),
  loaded with `specific_model_path` + `local_files_only` from `<state>/models/`; `install-packages.sh --no-model` skips
  it (CI test jobs). Keyword and entity hints come from the most specific level that resolves (feature/story, else
  app). The memory server reaches nodes through `ctx.extras["memory_mcp"]`, trust exactly `@genesis-memory/<six
  tools>`; the memory MCP is now read-only by its handle and index (chat too). `memory=False` opts a node out.

## ADR-089 (draft) — One standard escalation gate with confirm-gated actions, resolved with a run-bound agent in Run Detail

- **Status.** FILED as Accepted 2026-11-24 (was PROPOSED — Phase 55). Amends **ADR-011** (an agent node's escalation goes to the standard gate),
  **ADR-031** (a new run-scoped chat mode) and **ADR-033** (new human-confirmed run actions).
- **Areas.** core-engine, runs-worker, chat, workflows-library, web-runs.
- **Rule (one-liner).** Every agent node escalates to genesis-core's standard gate (retry with guidance, accept, fix then accept, rerun with instructions, restart from a step, stop); a Resolve agent only proposes, the human confirms, program code applies.
- **Context.** Most escalate gates routed every answer, Reject included, to END and the run ended `done`; the payload
  carried no failure detail; no run-level relaunch, override or retry-from-node existed (55-01 §3).
- **Decision.**
  1. **Standard gate (D6, F6, F8).** genesis-core provides the escalation gate used by `attach_reliability` and
     `attach_healing`; payload extended additively with the failed node, validator messages, retry/heal history, last
     error, files with roles, and the actions allowed in the current state (L-106). The reliability lint requires it
     (or a custom gate declared beside it).
  2. **Actions (D6 as amended by D13, D15; keys `retry`, `accept`, `fix_accept`, `relaunch`, `restart_from`, `stop`,
     D12).** Retry the failed step with guidance (gate answer); accept as is (gate answer → forward, `done`, the
     finalizer promotes); fix then accept (program copies the confirmed file, then accept); rerun from the start with
     additional instructions (`RunManager` relaunch: every input reused, the instructions in every agent node's prompt
     and kept across resume and fork; the escalated run `cancelled` and linked; a bound stage/story moved to the new
     run, D13); restart from an earlier step (a fork from that checkpoint, the original's checkpoints untouched per
     ADR-025, then the escalated run `cancelled` and linked and the binding moved before the new run starts, D15);
     stop (gate answer → `failed`, reason recorded). Old approve / reject / feedback map to accept / stop / retry. The
     plain fork (ADR-009 mode 3) is unchanged. Rerun and restart are offered only for a workflow that declares
     `META.relaunchable: true` (default false, with an optional `relaunch_hint`), and never for one that uses
     `appian-dev-write`, whatever its flag (ADR-068 stays the single approval for Dev changes; D23).
  3. **Resolve agent (D7, D14, F7).** A chat session bound to the run, shown only in Run Detail's **Resolve tab**
     (`/runs/<id>/resolve`), started when the user first opens it; read-only access to the run (events, steps, gate, its files copied into the
     sandbox; tool outputs readable while the run waits, D9); it records **proposals** only; the user's Confirm on a
     proposal card calls the API, and program code applies it. It never answers a gate itself (ADR-033 intact). Every
     action, from Resolve, the manual menu or the chat copilot, is audited on the run's own events (actor, source, action, parameters,
     proposal id; D22); `copilot_actions` holds the Resolve proposal flow only. Every escalation raises a "needs you" bell notification.
- **Alternatives.** Keep per-workflow gates (the `done`-on-reject bug stays); let the agent call mutating tools behind
  a permission prompt (weaker: the agent picks the parameters at call time); a Chat-page session (user chose Run
  Detail only).
- **Consequences.** Every library workflow with an agent node adopts the gate (genesis-workflows release); one new
  chat mode; new run endpoints; ADR-001 intact (the graph routes every gate answer; relaunch and fork are run
  management).

## ADR-090 (draft) — Run Detail reads one versioned run snapshot; the live stream is only a hint

- **Status.** FILED as Accepted 2026-11-24 (was PROPOSED — Phase 55). Updates **L-005** (`node.started` becomes canonical).
- **Areas.** runs-worker, web-runs, api.
- **Rule (one-liner).** The run graph renders only from GET /runs/{id}/snapshot (versioned by event seq); SSE sends lifecycle hints that trigger a re-fetch, with a 3 s poll floor; edges light only when their target runs.
- **Context.** The backend never recorded a node start; the cursor is the last completed node; the web lit the edge into
  it and stopped polling between completions (55-01 §5).
- **Decision (D10, F12, F13; as built in 55-03).** The worker adds LangGraph's `tasks` stream mode and records
  `node.started` (a gate task and a task resumed after a kill start again with the same task id); an incremental
  server fold serves the snapshot (version = highest seq; rebuilt from the log after a restart; reads only the fold's
  kinds after the last folded seq); a run is `legacy` when it has node activity but no `node.started`; an edge count is
  the completed hops plus the hop into an unfinished node; the hint stream (`/live`) carries `id:`, never replays the
  log, sends one `resync` to a reconnect that missed hints, and puts `status` on `run.final` frames; no
  `?since_version` (a pause writes no event, so an equal seq cannot prove the snapshot unchanged); the client keeps an
  equal version and drops a lower one; poll every 3 s while active and on focus / visibility / online / Refresh; old
  runs fall back without the cursor edge.
- **Consequences.** One new canonical event kind; `/steps` and `/transitions` stay for other readers; the event bus
  and SSE subscribers become bounded.
