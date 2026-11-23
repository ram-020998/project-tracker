# 55-01 — Findings: Workflow execution enhancements

> **Status:** SPEC-DRAFTED 2026-11-22 — Q&A complete: decisions D1–D11 (§9), defaults F1–F15 (§10, confirmed); D12–D15
> from the 55-02 mockup review (§9, folded per §11); D16 after 55-03 (§9, folded per §12); D17 after 55-04, D18 and D19
> from the user (§13); D20 after 55-05 (§14); D21 after 55-06, D22 and D23 from the user (§15); D24 after 55-07 (§16);
> D25 open with the user.
> Parent: `specs/phase-55-workflow-execution.md` (written after the Q&A).
>
> What was researched and decided before the spec set is written: the request as the user stated it, the four areas as
> they work today (code-grounded), the external and KiroCrew research, the proposed design, the open questions, and
> every decision.

---

## 1. The request (as stated by the user, 2026-11-22)

Phase 55 improves workflow execution for **every** workflow. Four parts:

1. **Memory brief.** At the start of each run an agent step looks at the workflow and its inputs, queries `memory.db`
   for items useful to this run, and writes a memory file into the run's blackboard. Every later agent node's prompt
   gets one line saying the file exists and may be used for extra context. Example: a remark a UX person made in a chat
   (distilled into memory) helps a later `ux-design-analysis` run.
2. **Agent-assisted escalation.** Today an escalation is a program gate: the user picks approve / reject / feedback and
   has no real control over what happens next. Instead, an escalated run opens in an agent chat: the agent shows what
   went wrong and why it escalated, which artifacts exist, and suggests next steps (rerun from the start with a changed
   input; mark the run complete and move its artifact to the real destination; cancel and start a new run; …). The user
   can chat about the run and decides; Genesis applies the decision.
3. **Documents tab.** Run Detail's Documents tab shows many files with unclear names, tool outputs mixed in. Every
   document gets a clear category: input, output, per-node artifacts (which node, when, latest version), tool outputs
   apart, other files. A full page revamp is allowed. The assistant is to inventory the real document types and propose
   the categorization.
4. **Run graph liveness.** The live graph lags the backend, looks stuck while the backend has moved on, and highlights
   edges whose target is not active. It must show the true latest state: live streaming if possible, otherwise a 2–5 s
   refresh or a manual refresh, but never wrong. A standard, solid implementation.

The user confirmed this restatement and wants all four in Phase 55 (D1).

Paths below: `genesis/` = `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis/genesis/`; `web/` = `genesis/web/src/`;
`core/` = `genesis/packages/genesis-core/genesis_core/`; `wf/` = `genesis-workflows/workflows/`.

## 2. Memory today (verified 2026-11-22)

### 2.1 Store and data

- `~/.genesis/memory.db` (`mm0001`, `genesis/memory/migrations/mm0001_memory.py:34-177`): `memories` (+ `memories_fts`),
  `memory_entities`, `memory_entity_links`, `memory_relationships`, `memory_links`, `memory_communities`,
  `memory_consolidation_state`. `Memory` (`genesis/memory/models.py:35-153`): `memory_type` semantic|episodic|procedural,
  `scope` personal|shared (+ `owner`), `text`, `summary`, `importance` 0..1, `tags_json`, `entities_json`, `origin`
  consolidation|reflection|user, bi-temporal `valid_from`/`valid_to`/`superseded_by`, `archived`, `pinned`,
  `protected`, `user_verified`, `embedding_status`.
- Entities carry `entity_kind` application|feature|record_type|concept and a free-text `entity_ref`; no workflow, story
  or run anchor.
- Real data: **63 memories** — shared semantic 39 (consolidation 28, reflection 10, user 1), shared episodic 11, shared
  procedural 9, personal procedural 4; 55 entities, 92 entity links, 28 relationships; 0 pinned.
- **Semantic retrieval is effectively off:** 62 of 63 have `embedding_status=skipped` (no `genesis[embeddings]` extra
  installed); retrieval is keyword (FTS5) + entity graph + importance/recency.
- **Anchors are inconsistent:** one app appears as `app:as-gss-full`, `app:as-gss-full-application`,
  `_a-0000e5bc-…_930416` and `a-0000e5bc-…_930416`; features as `feature-4-document-builder`. A lookup by `app_uuid`
  misses most of them.

### 2.2 Retrieval and injection

- `HybridRetriever.search(query, scope, owner, entity_ids, types, top_k=8, depth=1)` (`genesis/memory/retrieval.py:137-196`):
  0.55·relevance + 0.20·recency (τ 30 d) + 0.25·importance; current, non-archived only; no query → recency×importance.
- Read-only `genesis-memory` MCP (`genesis/mcp/memory_server.py:42-85`): `search_memory`, `get_personal_memory`,
  `get_entity`, `get_entity_memories`, `get_related_entities`, `get_relationships`; `mode=ro`, 32 KB output cap, never
  `mark_used`.
- **Chat only:** wired in `genesis/chat/mcp.py:41,83-87,127-131` with a `_MEMORY_HINT` steering line
  (`genesis/chat/mode_profile.py:21-22`). No `genesis-memory` entry in `mcp-registry.json`; the worker's launch provider
  handles only `genesis-kb` (`genesis/runs/worker.py:~88-100`). No workflow uses memory except the two memory jobs.
- `ctx.extras["memory_store"]` and the lazy `embedder_factory` are already in every run's context
  (`genesis/runtime/context.py:~176-178`).
- ADR-053 (Phase 26) made injection **MCP-only, no auto pre-fetch**; "agentic-node MCP injection" and "auto-prefetch"
  were deferred seams (`specs/phase-26-agentic-memory-layer/26-05-…md` §1, §6–7; umbrella `:224`).

### 2.3 Where a platform-wide brief would hook in

- Prompt: `kiro_node` builds `prompt = prompt_fn(state, ctx, out_path)` at `core/nodes/agent.py:364`, then saves it to
  `_prompts/` (`:~372-378`, the `agent.prompt` event) and sends it (`:~455`). A suffix added right after `:364` reaches
  every agent node of every workflow and stays accurate in the captured prompt. `NODE_AGENT_PROMPT` (`:41-46`) is a
  static agent system prompt.
- Run start: the worker loads `build, META`, builds `ctx`, compiles, then `astream(new_state(...))`
  (`genesis/runs/worker.py:~146-176`). A step before `astream` (for `op == "run"` only) needs no `graph.py` edit; wrapping
  every graph in a parent StateGraph would change node names and checkpoint topology (L-006) and is avoided.
- The reliability lint (`genesis/lint/reliability.py:71`) inspects only the compiled graph; ADR-011 governs agent nodes.
- Run inputs: no universal app/feature/story field; 15 of 19 workflows carry `app_uuid`, the stage and story workflows
  also `feature_id`/`story_id`. Without context: `agent-prompt`, `code-review`, `erd-generation`, `hello-appian`.
- Self-reference: `memory-consolidation` and `memory-maintenance` write memory and must not read a brief of it.

## 3. Escalation today (verified 2026-11-22)

### 3.1 Mechanism

- `hitl_gate(name, kind, prompt_fn, options)` (`core/nodes/gate.py:19-54`); payload `{node, kind, prompt, options
  (default approve/reject), context_refs: dict(state.artifacts), raised_at}`; a `{"feedback":…}` answer sets
  `decisions["<gate>.feedback"]`. `attach_reliability` (`core/nodes/reliability.py:25-75`) routes `escalate →
  on_exhaust_gate`; `attach_healing` (`core/nodes/healing.py:87-161`) escalates after one heal and one restart.
- **The payload is thin:** no error, validator message or retry history; only a few workflows put the last validator
  message in the prompt text.
- **Most escalate gates route to END, and any answer ends the run `done`** (`genesis/runs/worker.py:129-134` reports a
  finished graph with no explicit status as `done`). So **Reject also yields `done`**, and the bound finalizer then
  promotes whatever artifact exists. Workflows that read the answer: `agent-prompt` (approve/feedback → retry, else
  `give_up` failed), `generate-business-map`, `memory-*`, `setup-composer` [retry, discard], `story-verification`
  [send_back, accept, stop] + `escalate_blocked` (state-aware prompts, L-106), `story-implementation`
  `escalate_reverify`, `code-review` `review_escalate`. The five stage/story analysis workflows and `ux-design-analysis`
  go `escalate → (cleanup) → END`.

### 3.2 Run operations

- Routes in `genesis/api/run_routes.py`: `/respond` (`:199-208`), `/pause`, `/resume`, `/cancel`, `PATCH /state`
  (inputs, decisions, artifacts + `META.editable`), `/fork {as_node, values}` (`:210`), `/artifacts…` (`:219-262`).
- Statuses (`genesis/runs/store.py:26-34`): pending, running, awaiting_input:gate, awaiting_input:paused, done, failed,
  cancelled. `_finalize` (`genesis/runs/manager.py:138-159`) is the single compare-and-set terminal write, store then
  announce (L-093).
- **Missing:** a human "mark complete" override; a generic "rerun with changed inputs" (exists only per stage/story via
  `reset_for_rerun`, `genesis/api/features.py:1151,1413`, `genesis/api/workbench.py:227-386`); "retry from node".
  Fork copies state only; the new run's blackboard is empty while `state.artifacts` still point at the old folder
  (`manager.py:653-669`; not verified live).

### 3.3 Run → app bridges

`StageFinalizer` (ux, technical-design, feature-breakdown, test-design → fixed artifact names, `_BINDINGS`
`genesis/chat/stage_finalizer.py:110-121`), `StoryDesignFinalizer`, `StoryImplementationFinalizer`,
`StoryVerificationFinalizer`, `ChatRunSupervisor`, test-exec/capture/compose finalizers. Each acts on `run.final` with
`status == "done"` (verification also on failed/cancelled), requires the run to be the one currently bound (L-061) and
the artifact file to exist, and has a level-triggered `reconcile` (L-058). A human-override `done` through `_finalize`
would trigger them unchanged.

### 3.4 Chat pieces that exist

- Modes (`genesis/chat/store.py:25-33`): read_only, copilot, feature_spec, ux_design, technical_design,
  feature_breakdown, story_design, test_design. Copilot control MCP (`genesis/mcp/control_server.py:39-92`): read tools
  + confirm-gated `start_run`, `respond_to_gate`, `cancel_run` (ADR-033, `permission_mode="ask"` → confirm card,
  `copilot_actions` audit). Introspection MCP: `get_run`, `get_run_steps`, `get_run_events`, `list_failures`, … — **no
  tool reads blackboard files**.
- `chat_run_links(run_id PK, session_id)` (m0004): one session per run, linked only via the control-token `POST /runs`;
  no API binds an existing run.
- The StageFinalizer pattern already pre-binds a chat to a run's output: create the session, copy files into
  `skill_output_dir/<session>/`, `enqueue_system_turn` with a seed (L-042).
- The notification bell (`web/features/notifications/`) is fed only by schedules (`genesis/runtime/scheduler.py:398`);
  a manual run's escalation does not reach it.
- Web gate UI: `web/features/run-detail/components/hitl/HitlBar.tsx` (`GatePanel`: options, Feedback, context chips).

## 4. Documents tab today (verified 2026-11-22)

### 4.1 Code

- `web/features/run-detail/components/docs/DocumentsTab.tsx:74-165`: a flat card rail sorted by name; "Result" is a
  filename regex (`doc-utils.ts:20`); a "Show tool outputs" switch only when `_toolcalls/` exists; never shows
  `_prompts/`, `uploads/`, `.kiro/`, `checkout/`. Polls `GET /runs/{id}/artifacts` every 4 s while active.
- `GET /runs/{id}/artifacts` = `RunWorkspace.manifest()` (`core/workspace.py:69-83`): an `rglob` with bytes only (no
  mtime, node or role), `_kiro/` excluded. No manifest/metadata file exists.

### 4.2 What is in a run folder (10 real runs under `~/Genesis/runs`, joined to `run_events`)

| Run | Files | With an attributing event | Without |
|---|---|---|---|
| ux-design-analysis r-d945d439d221 | 23 | 14 (all `_prompts`) | 9 |
| technical-design-analysis r-d5ed99071d49 | 31 | 19 | 12 |
| feature-breakdown-analysis r-f9a818a124cb | 22 | 10 | 12 |
| story-design-analysis r-0aa082031405 | 15 | 7 | 8 |
| story-implementation r-fb5a9cd14f72 | 89 (74 `.kiro`) | 5 | 84 |
| agent-prompt r-87781054aa00 | 17 (15 `_kiro`) | 1 | 16 |
| memory-consolidation r-ea0fcbed1c4c | 33 (26 `_kiro`) | 2 | 31 |
| test-design-analysis r-cbf4ee22a3da | 36 | 21 | 15 |
| test-execution r-6f190dcfbac4 | 37 (`checkout/` 29, `report/` 5) | 0 | 37 |
| sync-application r-ea9479eee17e | 1 | 0 | 1 |

- Only `_prompts/*` are fully attributed (`agent.prompt`: node, iteration, attempt, ts). **Every real deliverable**
  (`analysis.html`, `technical-design.html`, `breakdown.html`, …) and every program/validator file has **no** event: its
  node and write time are unknown.
- `_toolcalls/` is purged at terminal (`genesis/runs/manager.py:203-218`) and by the workflows' `cleanup` nodes, which
  also delete root files not in `META.artifacts`; `tool_output.recorded` events survive (old runs stored them as
  `custom`, node NULL: 2732 rows; `artifact.saved` 79 rows).
- Files are **overwritten in place** on retry, loop and heal; only prompts are versioned per turn.
- Output files are touched empty before the turn finishes, so a zero-byte file can appear mid-run.
- File patterns observed: inputs (`uploads/*`; materialised `spec.txt`, `uxdesign.txt`, `story.json`, …); final
  outputs (`analysis.html`, `technical-design.html`, `breakdown.html`, `test-design.html`, `implementation-report.html`,
  `rollback.md`, `output.md`, `report/*`); intermediates (`screens.json`, `grounding.json`, `sections.json`,
  `epics.json`, …); control/verdict (`verify.json`, `heal.json`, `reconcile.json`, `result.json`, `report.json`);
  prompts; tool outputs; internal (`_kiro/`, `.kiro/`, `.DS_Store`); workspace trees (`checkout/`); derived media
  (`pages/*.png`).

### 4.3 Declared roles

- `workflow.yaml` `artifacts:` lists inputs, intermediates and results together, with no role. No `outputs:` key.
- Final output is derivable without guessing only from `_BINDINGS` (four stage workflows) or a `result.json`
  `{"artifact": …}` some workflows write; `result.json` has no common schema.
- Uploaded inputs: `inputs_schema.*.format: "file"` → `uploads/<name>` (ADR-035).

## 5. Run graph liveness today (verified 2026-11-22)

**Root cause:** the backend never records that a node started; the graph infers "running" from the last completed node.

- Worker: `compiled.astream(..., stream_mode=["updates","custom"])` (`genesis/runs/worker.py:170`); `updates` fires
  only when a node **finishes**. `runs.cursor` is set by `note_progress` to the **completed** node
  (`genesis/runs/store.py:157-166`), after `node.completed` is published (`manager.py:238-241`, a small race).
  `kiro_node`'s `agent_start`/`agent_end` are non-canonical → stored as `custom`. Program nodes emit nothing before
  completing (61 of 83 and 88 of 121 completions in two large runs).
- `/steps` (`genesis/runs/steps.py:17-74`): re-reads and parses the whole log per call (up to 30k events); a node is
  `running` once any event names it, `ok` after its first `node.completed` and **never returns to running** on a loop
  re-entry (L-059); a program node is absent until it completes.
- Web (`web/features/run-detail/`):
  - `RunDetailPage.tsx:97` `runningNode = run.cursor` and `RunGraph.tsx:87` `running = edge.target === runningNode`
    → **the edge into the last completed node pulses** (the reported wrong-edge symptom).
  - `useRunSteps` polls only while some step reads `running` (`hooks.ts:137-144`); the SSE tail invalidates `/steps`
    only on `node.completed`/gate/error (`hooks.ts:175-222`). During a 5–13 min agent node (real runs: 787 s, 415 s,
    350 s) nothing refreshes the graph → "stuck".
  - `deriveNodeStates(..., events=undefined, ...)` (`RunDetailPage.tsx:94`): the loop re-entry heuristic is dead code;
    the cursor is marked `current` but skipped because it is already `ok` (`node-states.ts:114-121`).
  - `useRunStream` opens `EventSource(?after=0)` on every mount, replaying the whole log (30k events, ~360 refetch
    triggers); `onerror` closes it for good (no reconnect); "Live" shows during replay; no `visibilitychange` handling.
  - A "Reload graph" button exists (`RunGraph.tsx:128-140`) but reloads the same misleading model.
- Transport: worker stdout JSON lines → `Supervisor._pump` thread (exceptions swallowed, `supervisor.py:79-82`) →
  synchronous `eventlog.append` per event → `EventBus` (unbounded history per run, `_cbuses` never pruned,
  `manager.py:91,125`) → SSE `GET /runs/{id}/events/stream` (`run_routes.py:350-374`): no `id:` field, no
  `Last-Event-ID`, `asyncio.to_thread(next, sub)` parks a thread per subscriber until the next event (a gated run emits
  none). Worker stderr is a PIPE read only at exit (latent block risk, not reproduced).
- History: `c04dc7e` (`/steps` authoritative, L-060), `c90bcc0` (stop client folding, `/transitions`, L-066),
  `f4ca84a` (refresh button), `7afd9ce` (per-node SSE). Every fix patched around the same missing "started" signal.

## 6. Research (2026-11-22)

### 6.1 External

- **LangGraph stream modes** ([streaming docs](https://docs.langchain.com/oss/python/langgraph/streaming),
  [Pregel.stream reference](https://reference.langchain.com/python/langgraph/pregel/main/Pregel/stream)): besides
  `updates`/`custom`, `tasks` emits task start and finish events with results and errors, and `checkpoints` emits each
  checkpoint in `get_state()` form; both need a checkpointer; `debug` combines them. A `version="v2"` output format gives
  one typed `StreamPart` shape for all modes (LangGraph ≥ 1.1; Genesis runs 1.2.8). This is the standard way to know a
  node started.
- **HITL patterns** ([LangChain HITL overview](https://docs.langchain.com/oss/javascript/concepts/human-in-the-loop),
  [Agent Inbox](https://github.com/langchain-ai/agent-inbox)): an interrupt is answered by accept, edit, respond (free
  text back to the agent) or ignore; the pause is durable on the checkpoint. None of them lets an agent choose the
  route; the human's answer resumes the thread.
- **Artifacts in workflow UIs**: Argo shows artifacts per step in the DAG and a list by step name and path, previews
  known types sandboxed ([artifact visualization](https://argo-workflows.readthedocs.io/en/latest/artifact-visualization/));
  Prefect artifacts carry a key, a description and versions, attached to a task run or a flow run
  ([Prefect artifacts](https://www.prefect.io/docs/v3/concepts/artifacts)). Common ground: an artifact is declared with
  a role and a producing step; the UI groups by step and by role and keeps versions.
- **Run views** ([Temporal Web UI](https://docs.temporal.io/devtools/web-ui/),
  [Temporal UI redesign](https://temporal.io/blog/the-dark-magic-of-workflow-exploration)): the history is grouped
  into event groups with summaries; "pending activities" (started, not finished) is a first-class view.

Content was rephrased for compliance with licensing restrictions.

### 6.2 KiroCrew (reference only; `/Users/ramaswamy.u/repo/KiroCrew`)

- Memory: a bounded **prefetch** at session start (`src/kiro_crew/context_assembly/store_admission.py:625`, 5 s
  embedding deadline, keyword fallback), injected blocks each switchable, a resumed session does not re-inject, plus a
  pointer line to the `memory_recall` tool for the rest (`docs/architecture/context-management.md:176-205,262-272`). A
  file-based `briefing.md` per member (`src/kiro_crew/members_parts/prompt_layers.py:238`).
- Escalation: a worker reports `blocked|question` (`src/kiro_crew/agent_parts/spec_prompts.py:929-948`); the conductor
  adjudicates and records the decision; person-facing `ask_question` cards; options rendered from the newest reply only
  (`docs/decisions/2026-09-13-options-are-read-from-the-newest-reply-only.md`). Reusable rule: the agent returns a
  validated proposal, the host applies it only after a person confirms.
- Live status: `src/kiro_crew/dashboard_feed.py:1-60` (subscribe once; a baseline fold value plus updates ordered by
  revision; stale updates dropped), `crew_log/bus.py` (a lost event is repaired by the next read of the fold),
  `projection/checkpoint.py` (fold savepoints), an SSE helper with a per-client write deadline, a subscriber cap and a
  20 s keepalive (`apps/builtins/auto_improvement/backend/sse.py:1-115`); "the page polls for most state".

## 7. Proposed design (assistant draft for the Q&A; §9 decisions win where they differ — D2 replaced the agent brief with a program prefetch, D7 put the chat in Run Detail only, D9 dropped versions and tool-output files)

- **Memory brief:** a platform step at run start (not a `graph.py` edit) writes `_memory/brief.md`; one line appended to
  every agent prompt at `core/nodes/agent.py:364`; idempotent on resume; excluded for the memory workflows; its own
  events. Needs an ADR-053 amendment (prefetch into a file).
- **Escalation:** the gate node stays (ADR-011); an escalation chat bound to the run gets the run's failure context and
  files; the agent proposes, the human confirms, program code applies (ADR-001, ADR-033 amendment for new run actions:
  mark complete + promote, rerun with changed inputs, retry from a node); fix the escalate→END "any answer is done" bug.
- **Documents:** record per-file metadata (producing node, iteration, time, role) at write time; declare artifact roles
  per workflow; a categorized, node-grouped Documents page; tool outputs listed from their events.
- **Run graph:** `tasks` stream mode → a canonical `node.started` (amends L-005); one server-side run snapshot with a
  version; edges from node states only; SSE as a change hint with `id:`/resume and reconnect; a 2–3 s poll floor while
  active.

## 8. Open questions (asked one at a time 2026-11-22; all answered — Q1→D1, Q2→D2, Q3→D3, Q4→D4, Q5→D5, Q6→D6, Q7→D7, Q8→D8, Q9→D9, Q10→D10, Q11→D11, Q12→§10 defaults)

1. Scope and restatement.
2. Memory step: an agent turn, a program step, or both (program narrows, agent selects)? → program prefetch, KiroCrew-style.
3. Which embedder.
4. Which workflows get the memory brief.
5. Personal memories in the brief.
6. Escalation: which actions the agent may propose and how each is applied.
7. Escalation: where the chat lives.
8. Documents: layout and categories (+ the mockup sub-spec).
9. Documents: keeping versions and tool-output files.
10. Run graph: live SSE vs poll.
11. Release ordering against the open Phase 51/53/54 live acceptance.
12. The remaining defaults and the sub-spec plan.

## 9. Decisions (locked with the user, one at a time)

| # | Decision | Reason |
|---|---|---|
| D1 | **Scope: all four parts in Phase 55, as restated in §1** — memory brief, agent-assisted escalation, Documents tab categorization/revamp, reliable run graph — applying to every workflow. Spec set: findings, the four feature sub-specs, an API sub-spec, review & acceptance, release & onboarding. | User (2026-11-22): "Yes the restatement is right and i want all 4 in phase 55." |
| D2 | **Memory brief = KiroCrew-style program prefetch (option K), not an agent turn.** At run start, program code renders a generic run description (the workflow's `META` summary and node descriptions + every input, ids resolved to names via the KB; no per-workflow declaration), runs `HybridRetriever`, and writes a budgeted top-k to `_memory/brief.md` (memory marked as data, not instructions). Every agent prompt gets one line pointing at the brief, and every agent node gets the read-only `genesis-memory` MCP to fetch more on demand (KiroCrew's `[Memory tools]` → `memory_recall` pattern). No new agent node, so no ADR-011 question; no credits, < 1 s. Needs an ADR-053 amendment (prefetch into a file + memory MCP on workflow nodes, both deferred Phase 26 seams). The embedder becomes on by default (the model is D3). Option A (an agent turn queries and writes the brief) is the upgrade path if live briefs prove poor. | User (2026-11-22): "Ill agree with K". Considered: A (agent queries; better relevance today with messy anchors, but one turn and 30–90 s per run, ADR-011 exception), B/C (per-workflow input declarations or program-narrows-agent-selects; both need inputs→query rules). KiroCrew evidence: `src/kiro_crew/memory.py:1068` `get_context(query=<message>)`, `context_assembly/store_admission.py:625`, `docs/architecture/context-management.md:176-283`. |
| D3 | **Default embedder = fastembed `BAAI/bge-small-en-v1.5`** (ONNX, ~130 MB, 384-d), replacing model2vec `potion-base-8M` as the default backend (`genesis/memory/embedder.py:27-29`); installed by default (not an optional extra). Reason: the brief embeds the run description inside every run's worker (ADR-012), so load time and RAM count per run; bge-small matches paraphrase far better than static vectors at ~1 s load. Proposed defaults (unless the user objects): the model is fetched by `scripts/install-packages.sh` with a pinned checksum (no first-use download inside a run); existing `embedding_status=skipped` memories are back-filled once. Amends ADR-054's default (it named model2vec). | User (2026-11-22): "Ill go with your recommendation". KiroCrew uses Qwen3-Embedding-0.6B Q8_0 (610 MB, 1,024-d, llama.cpp in-process, 1.6–2.5 GB peak RSS; `KiroCrew/docs/system-specs/modules/memory-skills-hooks.md:3576-3604`) — rejected as too heavy per worker for a 63-memory store. Considered: potion-base-8M (lighter, weaker). |
| D4 | **Which runs get a brief: every run whose graph has at least one agent node, by default.** Runs with no agent node (`sync-application`, `sync-documents`, `test-execution`) are skipped automatically (detected from the compiled graph, no flag). A new optional `META.memory_brief: false` opts a workflow out; `memory-consolidation` and `memory-maintenance` set it (they write memory and must not read a brief of it). No other per-workflow configuration. Scheduled runs get it like any run. A resumed run reuses its brief (written once per run); a fork copies the brief into the new run (the original untouched, ADR-025). | User (2026-11-22): "I agree with this". Considered: only the feature-stage and story workflows. |
| D5 | **The brief includes the user's personal memories (option B)** in a separate "Your preferences" section, retrieved with the owner Genesis already uses (`canonical_username(settings)`); shared memories in their own section. The brief stays in the local run folder (`_memory/`) and is never published to the Hub; a personal memory is never copied into anything published (the agent may follow a preference in its output). | User (2026-11-22): "B". Single-user app: every run, scheduled ones included, is the user's; personal procedural memories are among the most useful hints. Considered: A (shared only). |
| D6 | **One standard escalation gate in genesis-core, adopted by every workflow, with a fixed action set** *(action 4 amended by D13, action 5 by D15; names per D12 item 10)*. The agent only suggests; each action runs after the user presses Confirm on a card; program code applies it (ADR-001, ADR-033). Actions: (1) **Retry the failed step with guidance** — gate answer → back to the node, retry budget reset, the user-edited guidance added to its prompt; (2) **Accept the output as it is** — gate answer → the graph continues as if the check passed (assemble/present/cleanup run), the run ends `done`, the bound finalizer promotes the artifact; (3) **Fix the output, then accept** — the agent drafts a corrected file, the user reviews the diff and confirms, program code copies it into the run, then as (2); (4) **Rerun from the start with changed inputs** — a new generic `RunManager` relaunch: a new run with the edited inputs, the escalated run ends `cancelled` and is linked to it, stage/story runs rebound via the existing `reset_for_rerun` path; (5) **Restart from an earlier step** — `RunManager.fork` (exists; original untouched, ADR-025); (6) **Stop the run** — gate answer → END `failed` with the reason recorded, nothing promoted. Today's Approve / Reject / Feedback map to 2 / 6 / 1; workflows with richer gates (e.g. story-verification send-back) keep their own options beside the standard ones. Gate wording and the agent's suggestions are built from the run's state (L-106: e.g. no Accept when the output is missing or empty). Every action is audited in `copilot_actions`. Fixes the "any answer ends `done`" bug (§3.1). | User (2026-11-22): "this is good". |
| D7 | **The escalation chat lives in Run Detail only (option A)** *(placement: a Resolve tab, D14)*: a **Resolve** panel on the escalated run's page, beside the graph and Documents, holding the chat, the suggested-action cards and the Confirm cards; not listed on the Chat page (hidden like the stage chat modes, `genesis/chat/store.py:29`). Reuses the existing chat components (`ChatThread`, confirm cards). Defaults proposed with it and not objected to: every escalation of any run raises a "needs you" bell notification linking to the panel; the session starts when the user first opens Resolve (the agent's first turn presents what went wrong, the files and its suggestions; an unopened escalation costs no credits); the agent gets read-only access to the run (events, steps, gate, the run's files copied into its sandbox) plus the six D6 actions as confirm-gated tools, nothing else that writes. | User (2026-11-22): "We can just have it in the run detail page alone. Ill go with A". Considered: B (Chat page only), C (both, one session; the assistant's recommendation). |
| D8 | **Documents tab design approved; a mockup sub-spec comes first.** Layout: a grouped list (search; view toggle **By step** default / By type) + a viewer with a metadata header (category, step, pass, attempt, written time, size, version picker, Open in step, Download). Categories, each assigned by one rule: **Output** (pinned, auto-selected; a role the workflow declares in `META`, new), **Inputs** (uploads, files built from inputs, the memory brief; `META` role + `format: file`), **Steps** (each node in graph order with the files it wrote — intermediates and checks such as `verify.json`/`heal.json` with a pass/fail mark — and its prompts per turn; from a new per-file write record in genesis-core: node, pass, attempt, time, size), **Tool outputs** (tool, step, size, time; from `tool_output.recorded`), **System** (`_kiro/`, `.kiro/skills/`, `checkout/`; hidden by default). Each file shows a human label from `META`, its step, write time, size, version count and a "latest" mark. Old runs fall back to name rules and show "step unknown". **Sub-spec 55-02 is the mockup** (a `/dev` mockup the user reviews before any build); by default it also mocks the Resolve panel (D7) and the run graph states (part 4). | User (2026-11-22): "Im good with this design, but make sure that we have a sub spec at the first to create the mockup for this which i can review. Make this as the 55-01 or 55-02". 55-01 is the mandatory findings, so the mockup is 55-02. |
| D9 | **Keep neither old versions nor tool-output files (option C).** Files stay overwritten in place (latest only); the per-file write record (D8) gives a **write count** ("written 3 times") and the step/pass/attempt of the latest write. Tool outputs keep today's purge at run end (`purge_tool_store_on_final` default on; `cleanup` nodes unchanged); the Documents tab lists each tool call from its `tool_output.recorded` event (tool, step, size, time) with no file to open once the run has ended. While a run waits at a gate it is not terminal, so `_toolcalls/` still exists and the Resolve agent (D7) can read the tool outputs then. The D8 version picker becomes a write count. | User (2026-11-22): "ill go with c". Considered: A (keep both until retention; the assistant's recommendation), B (keep versions, purge tool outputs). |
| D10 | **Run graph: a server snapshot as the truth, a live SSE hint, and a 3 s poll floor (option B).** Backend: the worker adds LangGraph's `tasks` stream mode and records each task start as a new canonical `node.started` event (amends L-005; one backend list + web list + fixtures, L-122), so program nodes and loop re-entries (L-059) show as running; `GET /runs/{id}/snapshot` returns `{version (latest event seq), run status, gate, active nodes, per-node status + counts, traversed edges}` from an incremental fold (no per-call re-read of the whole log, L-066), replacing the page's separate `/steps` + `/transitions` + run fetches; edges are highlighted only when their target is running (the cursor-based edge logic is removed); the SSE subscriber leak (`to_thread(next)`), the unbounded per-run bus and the swallowed pump exceptions are fixed. Client: SSE carries only lifecycle hints (node started/completed, gate, final) each with an `id:`; a hint triggers a snapshot re-fetch; a hint or snapshot with a lower version is ignored; reconnect with backoff from the latest seq (never `after=0` replay); a 3 s poll while active plus on focus and Refresh; the "Live" badge only while connected. The inspector's per-node conversation stream is unchanged. | User (2026-11-22): "B". Considered: A (poll only, 3 s). Reference: KiroCrew `src/kiro_crew/dashboard_feed.py` (baseline fold + newer-only updates). |
| D11 | **Release order: Phase 55 ships after its own review and its own live acceptance only.** The still-open Phase 51 (51-12 steps 1–27), 53 (53-11 §5) and 54 (54-10 round 2) live acceptance is done by the user later, for all phases together; it is not a Phase 55 gate and is not folded into 55's acceptance. Per L-111 the Phase 55 release notes, README row and state say plainly that the 51/53/54 acceptance is still open. | User (2026-11-22): "Ill do the liev acceptance for all phases at the end. So dont worrry about it. Lets finish phase 55 and complete the live acceptance for phase 55 only". Considered: A (51/53/54 acceptance first; the assistant's recommendation), C (fold the open rows into 55's acceptance). |
| D12 | **55-02 mockup review: all six surfaces approved as mocked at genesis `d0aa1b2`** (`/dev/phase-55`; 55-02 As built "User review (D8)"), including the dev's open choices taken as approved with the page: (1) a file row reads "written N times · latest" (tooltip: earlier writes are not kept); (2) **the edge into a gate that is waiting is lit in the warning colour**; (3) **on a loop re-entry only the edge just taken is lit** (e.g. `reassemble → verify`, not `assemble → verify`); (5) the memory brief is under Inputs with the step "Run start (before the first step)"; (6) System stays, collapsed, in By type too; (7) Resolve credits show in the tab ("This chat") and the run header total includes them; (8) the bell notice links to `/runs/<id>/resolve` (a new SPA route); opening the notice does not start the agent, opening Resolve does; the notice is marked read when the gate is answered; (10) **the mockup's field names are the contract** for the escalation payload and the actions (`web/src/dev/mockups/phase55/fixtures.ts`: `failed_node`, `validator_messages`, `history[{at, kind, text, ok}]`, `last_error`, `files[{path, role, bytes, writes, check}]`, `allowed{action: null \| reason}`; action keys `retry`, `accept`, `fix_accept`, `relaunch`, `restart_from`, `stop`); (12) n1 an escalation gate's run pill reads "Needs you", n3 a validator whose check failed reads "OK · check failed N times". | User (2026-11-23): "Everything looks good. One change…" (the change is D13). Folded into 55-03 (2, 3), 55-06/55-07/55-08 (10), 55-09 (1, 5–8, 12). |
| D13 | **Rerun from the start takes the run's inputs unchanged and asks only for additional instructions** (amends D6 action 4 and F9). The action is "Rerun from the start with additional instructions": every input of the escalated run (feature id, stage id and the rest; uploads re-provisioned) is reused as is; the user gives free-text instructions; **every agent node of the new run** gets them in its prompt (a line beside the F4 memory line in `kiro_node`); they persist for the new run's resume and fork. `POST /runs/{id}/relaunch {instructions}` replaces `{inputs}`. The escalated run ends `cancelled` and links to the new run; a bound stage/story moves to it. | User (2026-11-23), 55-02 review row 4; mocked in genesis `09fd371`. |
| D14 | **Resolve is its own Run Detail tab** beside Flow and Documents, with the facts sidebar on the right; the side-panel placement is dropped; the results of each action show inside the Resolve tab. D7's "panel" reads as this tab. | User (2026-11-23): "my choices 1. B"; mocked in `7495448`, `1778a50`. |
| D15 | **Restart from an earlier step binds the stage (or story) to the new run and cancels the escalated run**, which links to it, like Rerun (amends D6 action 5). The fork still seeds a new thread from the chosen checkpoint and the original's checkpoints and history are untouched (ADR-025); the original then ends `cancelled` through the stop-intent + CAS path (L-108), and the binding moves to the new run before it starts (L-061). The forked run starts running at once (not left paused). The plain `POST /runs/{id}/fork` (ADR-009 mode 3, no cancel, no rebind) is unchanged. | User (2026-11-23): "2. bind the stage to the new run and cancel the old one"; mocked in `7495448`. |
| D16 | **55-03 build rulings, taken as built** (55-03 As built "Decisions / deviations" 1–12; review SHIP): no `?since_version` (a pause writes no event, so an equal seq cannot prove the snapshot unchanged; the client keeps an equal version, drops a lower one); a reconnect that missed hints gets one `resync` frame, not a replay; `run.final` hint frames carry `status`; snapshot nodes also carry `tool_calls`, `messages`, `entered_from`, and the page no longer fetches `/steps` or `/transitions`; an edge count = completed hops + the hop into an unfinished node; ↻ counts the current or stopped execution; a stopped execution's time runs to the terminal `run.final` or the stored pause time; `legacy` = node activity with no `node.started`; badge Polling / Live / Reconnecting / Finished; Refresh in the header; `fold_steps` keeps its old loop rule for its other readers; `/live` read with `fetch` + `readSse`. **One deviation from the approved mockup:** a re-entered node shows "round k", not "round k of N", and no per-item label ("workstream 4 of 8"), because nothing generic in the event log gives N or the item; the user can object at 55-11 A1. | Spec agent (2026-11-23), folding the 55-03 As built; the "of N" deviation reported to the user. |
| D17 | **55-04 build rulings, taken as built** (55-04 As built "Decisions / deviations"; review SHIP): the model is fastembed's `qdrant/bge-small-en-v1.5-onnx-q` (quantized ONNX, 5 files, ~67 MB, not the ~130 MB D3 assumed), loaded offline with `specific_model_path` + `local_files_only=True` (0.32 s, 287 MB), revision and SHA-256 pinned in `genesis/memory/model.py`; fastembed pinned to 0.7.4, the `embeddings-onnx` extra removed; CI test jobs install with `--no-model`; no `genesis doctor` exists, so the embedder state is on the health surface (never fails readiness) and in `genesis memory status`; `genesis memory reembed` rebuilds the vector table when the model size changes; search hints come from the feature or story when known, else the app (the app's entities match nearly every memory); a store/retriever "match any of these names" keyword mode (the whole description matched nothing); **no minimum similarity** (a no-context run still gets 12 memories); personal memories get their budget first; node steps last in the description so the cap cuts them first; the 5 s deadline runs on abandonable threads; the memory MCP opens `memory.db` read-only (chat too); the memory server reaches agent nodes through `ctx.extras`, not `mcp-registry.json`. **Deviation from the spec's test:** memory #27 is not in the feature-4 brief (linked only to two concepts, never names the feature, more than 12 Document Builder memories compete); the test checks #26 first + ≥ 10 feature memories; judged by the user at 55-11 A4 with the no-context brief. | Spec agent (2026-11-23), folding the 55-04 As built; #27 and the no-context brief reported to the user. |
| D20 | **55-05 build rulings, taken as built** (55-05 As built "Decisions / deviations" 1–18; review SHIP at round 2): no `mtime` on `RunWorkspace.manifest` (Documents lists the folder with the worker's own `scan`; genesis-core untouched); the worker forwards `task_finish` with its diff and the manager logs `file.written`; `execution` = the node's nth distinct task id (a gate resumed with the same id stays one; can differ from the snapshot's ↻); `.pids/` excluded and listed as System; a list-form workflow gets the name rules but keeps each file's step; `_launch` files without a role are inputs; `_parallel` writes have no step; **deviation from F12:** an old run's file saved by reference takes its step from its `artifact.saved` event instead of `node: null`; `writes` = record count (0 = unknown); labels from the role, the upload's input title, or "Turn k · <item>" for prompts; `written_at` = current mtime; only existing files are documents; extra fields `writing`, `legacy`, `roles_declared`, `status`, `version`; `FoldCache` shared with the snapshot. Limits accepted: a task killed before its finish (pause, crash) leaves no record of what it wrote; a write between two nodes is reported only when the file changes again; `*.part` is never listed; the fan-out start order is not spiked. **Spec-agent rulings while folding:** `file.written` is not a `/live` hint (Documents re-reads on `node.completed`); System files (`_kiro/`, `.kiro/`, `.pids/`, `checkout/`) are listed but neither previewed nor downloaded, refused by the file routes (55-08), because the run's Kiro home is not confirmed free of secrets. | Spec agent (2026-11-23), folding the 55-05 As built. |
| D21 | **55-06 build rulings, taken as built** (55-06 As built "Decisions / deviations" 1–15; review SHIP): one gate serves all a workflow's agents (`decisions["_escalation.from"]`); a healing escalation's `failed_node` is the verify node, and Accept depends on `attach_healing(artifact=)`; the payload also carries `extra_options [{id, label, hint}]`; an unknown answer stops the run (`failed`), never `done`; **relaunch does not call the stage / story re-run endpoints** (they delete the stage folder the unchanged inputs point into and re-snapshot upstream, against D13) — it starts with the old inputs and rebinds before the worker spawns (L-061), so it skips the re-run's prerequisite checks and reads the old snapshots; validate, then cancel; one run is never replaced twice (`_replace_lock`, `_replaced_by`); **relaunch and restart_from are refused for queue-managed workflows** (test-execution, story-verification, setup-composer, action-capture, test-design top-ups), each refusal saying where to restart instead (ADR-081/082); restart_from copies the run folder (without `_kiro/`, `_toolcalls/`, `.pids/`), rewrites the absolute state pointers, and resets `status`, `retries`, `_healing` and the `_escalation.*` markers; the plain fork carries a relaunch's instructions; fix_and_accept takes the Resolve `session_id`; fix targets limited (category output / intermediate / check, ≤ 25 MB, never System, `_memory`, `uploads`, `*.part`); history wording as the mockup, without "of N"; stop's reason becomes the run's `detail`. Limits accepted: the launch environment is not stored (relaunch uses the active one, as resume does); a rebind that raises after the cancel is untested. **Spec-agent rulings while folding:** (1) **restart takes the step to restart from**, not LangGraph's `as_node` (which continues *after* the named node): `POST /runs/{id}/restart-from {from_step}`, and the server forks from the latest checkpoint whose `next` holds that step (55-08); (2) a workflow whose cleanup must run on stop routes stop through it with a new additive `escalation_gate(stop_to=)` (55-10); the run still ends `failed`. | Spec agent (2026-11-23), folding the 55-06 As built. |
| D24 | **55-07 build rulings, taken as built** (55-07 As built "Decisions / deviations"; review SHIP after one round): **reads stay unscoped** — `run_resolve` confines writes to the sandbox (`fs_write_root`) but not reads, like every sandboxed chat mode, because ADR-086 rejected read path-scoping and deferred it to Phase 52 (55-07 §1's "confined" means writes; no ADR deviation, confirmed by the spec agent); **no migration** — the Resolve session id is `resolve-<run_id>`, so the id is the run → session link; the Resolve routes, an internal token-checked proposal route for the MCP server and `restart_from(from_step=)` were built in 55-07 (planned for 55-08); the first turn runs in the background, its events and the proposal events go to the session's notification stream; a proposal too long to store whole is refused with guidance to shorten it; an old library gate gets a computed action map without Fix then accept; an interim guard refuses Rerun/Restart for a workflow that declares `appian-dev-write` until 55-08's D23 reader replaces it; Confirm applies once even on a double click. The review's M finding (a restart dropped every earlier step's decisions, inherited from 55-06) is fixed. Limits accepted: an off-thread refresh racing the run's end can put `run/_toolcalls/` back (retention removes it); a cold-start turn can see one note twice; two `serve` processes on one home refuse each other's proposals. | Spec agent (2026-11-23), folding the 55-07 As built. |

## 10. Defaults — ✅ confirmed by the user 2026-11-22 ("confirm")

| # | Default |
|---|---|
| F1 | **Brief size:** up to 12 shared and 6 personal memories, ≤ 12,000 characters; each entry shows id, type, importance, anchors and text; a header says the memories are data, not instructions; when memories are left out, a notice says so and points to `search_memory`. |
| F2 | **Brief location and event:** `_memory/brief.md`; one canonical `memory.brief` event (query length, memory ids, size, embedder, duration; L-122). |
| F3 | **Never fails a run:** if `memory.db` is missing, empty or unreadable, or the embedder fails, no brief is written, the event records why, the prompt line is left out, and the run continues. |
| F4 | **Prompt line** added at `core/nodes/agent.py:364` only when the brief exists; a node opts out with `kiro_node(memory=False)`. |
| F5 | **Memory tools on agent nodes:** when a brief is enabled, every agent node gets the `genesis-memory` MCP automatically (like the blackboard MCP); its 6 read-only tools trusted; an internal server, not in the catalog. |
| F6 | **Richer gate payload** (additive; `CORE_MAJOR` unchanged): the failed node, validator messages, retry and heal history, last error, the files with their roles, and the actions allowed in the run's state. |
| F7 | **Resolve agent:** the chat's default model; credits metered and shown on the run (ADR-032); on start the run's files (System excluded) are copied into its sandbox; "Fix the output" writes its draft there. |
| F8 | **Lint:** an agent node's escalation must go to the standard gate, or to a custom gate declared beside it. |
| F9 | **Relaunch** *(amended by D13: the body is `{instructions}`, the inputs are reused unchanged)*: `POST /runs/{id}/relaunch {inputs}`; a stage- or story-bound run uses that binding's `reset_for_rerun`; the new run records `trigger = {source: "relaunch", from_run}`. |
| F10 | **Write records:** a canonical `file.written` event per written file (path, node, pass, attempt, size); a new `GET /runs/{id}/documents` returns the categorized list. |
| F11 | **META roles:** `META.artifacts` also accepts `{name: {role: output\|input\|intermediate\|check, label}}`; the list form still works (additive, ADR-019); the parity lint covers it. |
| F12 | **Old runs:** no `node.started` → the graph falls back to `/steps`, without the cursor edge bug; no write records → Documents uses name rules and shows "step unknown". |
| F13 | **Snapshot cache:** the fold is kept in memory per run, rebuilt from the event log on first request after a restart; version = the run's highest event seq. |
| F14 | **ADRs:** ADR-088 memory brief + memory tools on workflow nodes + bge-small default (amends ADR-053, ADR-054); ADR-089 standard escalation gate, its actions and the Resolve agent (amends ADR-011, ADR-031, ADR-033); ADR-090 Run Detail reads one versioned snapshot, SSE only a hint; L-005 updated for `node.started`. Drafts: `adr-drafts.md`. |
| F15 | **Release:** genesis v0.84.0 + genesis-workflows v0.28.0; `CORE_MAJOR` 1; a genesis.db migration only if the Resolve session needs its own run link (`chat_run_links` allows one session per run; 55-08 decides). |

Sub-spec plan (confirmed with F1–F15): 55-01 findings · 55-02 mockups · 55-03 run liveness · 55-04 memory brief ·
55-05 document records · 55-06 standard escalation gate and run actions · 55-07 Resolve agent · 55-08 HTTP API ·
55-09 web (Documents + Resolve) · 55-10 library adoption · 55-11 review and acceptance · 55-12 release and onboarding.

## 11. After 55-02 (2026-11-23): the mockup review folded into the later sub-specs

D12–D15 recorded from the 55-02 As built ("User review (D8)"). Folded: **55-03** (snapshot `active_edges` with a
`waiting` state and the last-taken edge per active node; D12 items 2, 3); **55-06** (payload and action names from the
mockup, D12 item 10; relaunch with instructions, D13; `restart_from` = fork + rebind + cancel, D15); **55-07**
(proposal action keys; outcomes of relaunch and restart_from; the notice link and mark-read, D12 item 8); **55-08**
(relaunch body `{instructions}`; a new `POST /runs/{id}/restart-from`; payload field names); **55-09** (the Resolve tab
and route, D14; row wording, brief placement, System in By type, credits, "Needs you" pill, validator label, D12);
**55-11** (A5, A6 rows); umbrella §3 and ADR-089 draft. 55-02 is BUILT; next is 55-03.

## 12. After 55-03 (2026-11-23): As built folded into the later sub-specs

55-03 BUILT (genesis `793c04b6..29775149`, local; review SHIP after one round). D16 records its build rulings.
Folded: **55-05** (diff at the forwarded `tasks` finish, which also comes for an erroring node; a fresh stat snapshot
at every start because a gate or a resumed task starts again with the same id; fan-out attributed to `"_parallel"`;
reuse the `SnapshotCache` read-after-seq pattern); **55-06** (the enriched gate payload reaches `snapshot.run.gate`
with no fold change; `__interrupt__` already filtered); **55-08** (`/snapshot` and `/live` rows as built, no
`?since_version`, the real fixtures); **55-09** (the Resolve tab keys on the snapshot; "Needs you" is a `statusMeta`
change; Documents re-read on lifecycle hints + the 3 s poll); **55-11** (§1 item 4, untested fan-out and two-serve
cases); **55-12** (the lesson candidates); ADR-090 draft text. Two 55-03 bug fixes worth noting for the release
notes: every gate's `__interrupt__` chunk used to raise in `on_event` and be swallowed by the pump, and a worker that
wrote more than 64 KB to stderr blocked on the unread pipe. Next is 55-04.

## 13. After 55-04 (2026-11-23): As built folded into the later sub-specs

55-04 BUILT (genesis `d1ab6d13`, `419d8363`, local; review SHIP; `419d8363` holds the review fixes, not re-reviewed,
full suite not re-run after it — carried to 55-11). D17 records its build rulings. **Live effect before the release:**
the fleet runs from the editable dev venv, so new fleet runs already write briefs (keyword + entity only: fastembed
is not installed in the dev venv), the unrestarted servers store `memory.brief` as `custom`, and the nightly memory
workflows get a brief until 55-10's opt-out ships (against D4) — the user's call is D18. Folded: **55-05** (the
`brief.md.part` write, a fork's copied brief has no event); **55-06** (the instructions line beside `MEMORY_LINE`; a
relaunch gets a fresh brief, a restart_from reuses the copy); **55-10** (check the library schema and parity lint
accept `memory_brief`); **55-11** (review `419d8363`; the #27 and no-context calls in A4; a live negative control for
the memory tools; a CI-image run with fastembed and a Linux offline load); **55-12** (release notes: the ~67 MB model
download, `reembed`, `status`, the read-only memory server).

**D18 (user, 2026-11-23):** option B — the user turned the `memory-consolidation` and `memory-maintenance` schedules
**off on both fleet instances** (main :8760, userb :8761) until Phase 55 ships, so no memory run gets a brief before
55-10's opt-out. Other fleet runs keep getting briefs from the dev venv. 55-12's deploy step turns both back on after
the library release (consolidation catches up from its cursor). Considered: A (leave it), C (take the fleet off the
dev venv until v0.84.0; the thorough fix, a backlog candidate if L-099 recurs).

**D19 (user, 2026-11-23):** option A — **no memory text in any commit.** The 55-04 evidence held the full text of the
user's memories (personal ones included) in seven brief files (`evidence/55-04/briefs-bge/*.md`,
`briefs-keyword-entity/*.md`, `live-r-ea61596cd428/brief.md`); the other evidence files hold ids, scores and run
descriptions only (checked against every memory's text). The spec agent redacted the seven files (ids, types,
importance and text length kept; anchors and text removed) and rewrote the three unpushed commits from the 55-04 As
built on (`git filter-branch --tree-filter`, range `77a41ec..main`, nothing pushed was touched), so no commit holds the
text; a scan of every unpushed commit against all 68 memory texts finds none. The old commits stay only in the local
backup ref `refs/original/refs/heads/main` until the user removes it. Rule from now on (55-11 set-up, every later
evidence folder): briefs, Resolve sandboxes, prompts and tool outputs that carry memory text are reviewed locally and
committed only redacted. Considered: B (keep; repo is the user's), C (delete in a new commit; text stays in history).

## 14. After 55-05 (2026-11-23): As built folded into the later sub-specs

55-05 BUILT (genesis `5bbae6d3`, `7d67c548`, `3c3e38ae`; review SHIP at round 2; the full suite at `419d8363` first:
2221 passed, 4 skipped, closing 55-04's open run). D20 records its build rulings. Live effect: new fleet workers scan
their folders (~2–3 ms per scan) and emit `task_finish` / `files_written` lines the unrestarted v0.83.0 servers
ignore, so nothing reaches the fleet's DB until a restart. Folded: **55-06** (fix-then-accept logs its own
`file.written` with node `_resolve`, since the worker diff cannot see a copy made at the gate; `_resolve` in
`PSEUDO_NODES`); **55-07** (sandbox list and roles from `manager.documents` / `roles_of`); **55-08** (the
`/documents` row as built; `legacy` = finished with no write records; `writing` only while running; `execution`
semantics; `file.written` not a live hint; System paths refused by the file routes); **55-09** (write count only
when > 0; pseudo-steps; prompt labels; System listed but not previewable); **55-10** (the schema and the cleanup
nodes must accept the map form); **55-11** (a live `file.written` / `/documents` check during a run; the fan-out
start order; the kill limit).

## 15. After 55-06 (2026-11-23): As built folded into the later sub-specs

55-06 BUILT (genesis `6c6f93a5`, `a9a1cce8`, `88b57a52`, local; review SHIP; genesis 2295 passed, genesis-core 152).
D21 records its build rulings and two spec-agent rulings. Open with the user: the audit of manual actions (D22) and a
Resolve relaunch of `story-implementation`, which writes to Dev again (D23). Live effect: nothing changes for fleet
runs (no installed workflow uses the new gate); the dev venv's CLI is live (`create-workflow` scaffolds the new gate,
`test-workflow` fails F8 on today's workflows). Until 55-10, `validate_library` fails 56 F8 violations in 16 workflows
and 7 library tests that run the lint fail. Folded: **55-07** (call the methods with `source`, `session_id`,
`proposal_id`; check the session is the run's own before fix-and-accept; cards from `gate.allowed`; restart names a
step); **55-08** (the four routes, error mapping, the enriched payload and `run.relaunched` rows, `restart-from
{from_step}`, the queue-managed 409, the scheduler follow-up); **55-09** (restart picks a step; Rerun/Restart
disabled for queue-managed workflows; the `<gate>_stop` step); **55-10** (one shared gate, `artifact=`, `stop_to=`
for cleanup, the 56 violations and 7 tests); **55-11** (the untested rebind-failure path and the other limits);
**55-12** (the lesson candidates, the docs that name `hitl_gate`).

**D22 (user, 2026-11-23):** option A — **the run's own event log is the audit for every escalation action**
(amends D6's "every action is audited in `copilot_actions`"). Every action, from a Resolve proposal or the manual
menu, is recorded on the run's events (`gate.resolved`, `run.relaunched`, the `_resolve` `file.written`) with `actor`,
`source` (`resolve` | `manual`), `action`, its parameters and, when there is one, the `proposal_id`. `copilot_actions`
keeps only the Resolve proposal → confirm flow (as 55-06 built it). No migration for the audit; the audit survives a
deleted chat and lives as long as the run (retention reclaims it with the run's events). Folded into 55-07, 55-08 and
the ADR-089 draft. Considered: B (m0031 rebuilds `copilot_actions` with a nullable session, `actor`, `source`; a
cross-run audit table nothing needs today).

**D23 (user, 2026-11-23):** **a workflow-level flag decides whether Resolve may start a new run** (the user's idea,
refined): `META.relaunchable: bool` (default **false**, opt-in) + optional `META.relaunch_hint: str`, both mirrored
in `workflow.yaml` and checked by the parity lint through one reader (L-109). It covers both actions that start a new
run, Rerun from the start (D13) and Restart from a step (D15); `allowed.relaunch` / `allowed.restart_from` read it and
give the hint (or a generic reason) when false. Default false so an older or unflagged library workflow is never
relaunchable on v0.84.0. **Code guard (ADR-068):** the platform refuses to relaunch or restart a workflow that uses a
write-capable MCP server (`appian-dev-write`) even if it declares `relaunchable: true`, so the Implementation lane's
confirm stays the single approval for Dev changes. `story-implementation` declares `relaunchable: false` with the hint
"Re-run it from the Implementation lane"; Retry with guidance, Accept, Fix then accept and Stop stay offered inside its
escalated run. 55-06's hard-coded refusals (test-execution, story-verification, setup-composer, action-capture,
test-design top-ups) are covered by the default; the service checks stay only where a run that skips the queue would
break an execution record (ADR-081), and a test-design top-up stays refused per run. Folded into 55-08 (the reader, the
`allowed` computation, the guard), 55-09, 55-10 (the flags per workflow), 55-11, 55-12 and the ADR-089 draft.
Considered: A (refuse Rerun and Restart for `story-implementation` only), B (allow it with a Dev-write confirm; an
ADR-068 amendment).

## 16. After 55-07 (2026-11-23): As built folded into the later sub-specs

55-07 BUILT (genesis `70f7c383`, `0a4acd0c`, local; review SHIP after one round; genesis 2331 passed, 4 skipped; a live
check in a scratch state, ~1.0 credits). D24 records its build rulings. Live effect: only the worker's fork change
reaches fleet runs through the dev venv, and the old servers never take that path; do not restart the fleet onto
this code before 55-08 replaces the interim write guard. Open with the user: whether memory consolidation reads
Resolve chats (D25). Folded: **55-08** (no migration; the routes 55-07 built and the stream events as contract rows
with recorded fixtures; the `ResolveProposal` type; replace the interim `WRITE_SERVERS` guard with D23 and guard the
manual routes; the long-proposal refusal); **55-09** (open, first turn from the stream, reload, cards from
`/resolve/escalation`, editable fields, restart names a step, the legacy action map); **55-11** (a live Confirm of
each action; a write-outside attempt the agent will act on; the v3 meta tools; restart on a healing workflow);
umbrella and **55-12** (no migration expected, DB v30).

## Context manifest

```toml
areas    = ["memory", "runs-worker", "web-runs", "core-engine", "chat"]
adrs     = ["ADR-001", "ADR-011", "ADR-021", "ADR-031", "ADR-033", "ADR-053", "ADR-054", "ADR-066", "ADR-067"]
lessons  = ["L-005", "L-042", "L-059", "L-060", "L-066", "L-106"]
docs     = ["tracker:specs/phase-26-agentic-memory-layer.md", "tracker:specs/phase-39-run-inspection-observability.md"]
code     = ["genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/genesis/runs/worker.py", "genesis/web/src/features/run-detail/**"]
upstream = []
```
