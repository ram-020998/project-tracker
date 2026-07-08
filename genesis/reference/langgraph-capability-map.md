# Genesis — LangGraph Capability Map

Which LangGraph (v1) capabilities Genesis uses, where, and why. Confirms we adopt
the useful subset and not accidental complexity.

---

## 1. Core capabilities (used)

| Capability | Genesis usage | Where |
|---|---|---|
| **StateGraph (nodes/edges)** | Every workflow is a `StateGraph` over `PlatformState` | all workflows |
| **Typed state + reducers** | `PlatformState` with append/merge/increment reducers | `genesis_core/state.py` |
| **Conditional edges** | Branches: generate/update, dry-run, validator pass/fail routing | reliability trio, ERD |
| **Cycles/loops** | Retry edge (agent → validator → agent) | reliability trio |
| **Checkpointer (SQLite)** | Per-superstep durable snapshots → resume/edit/fork | `runtime/checkpoint.py` |
| **Interrupts** | HITL mode 1 (approval + escalation gates) | `nodes/gate.py`, Phase 5 |
| **`update_state`** | HITL mode 3 (mid-run state injection) | `runs/hitl.py`, Phase 5 |
| **Time travel / fork** | Fork from a past checkpoint (mode 3) | `runs/hitl.py`, Phase 5 |
| **Fault tolerance / replay** | Crash/restart recovery; pause/resume | engine + checkpointer |
| **Streaming (updates/messages/custom/checkpoints)** | Live step timeline + agent tool-call events → UI | `runs/stream.py`, Phases 5/7 |
| **Subgraphs** | Compose migrated workflows into the flagship `sdlc-pipeline` | Phase 8 Wave D |

---

## 2. Capabilities used later / conditionally

| Capability | Genesis usage | When |
|---|---|---|
| **`Send` (dynamic map-reduce)** | Fan out one agent call per app/table/entry-point (e.g., ERD across many apps; data-gen per table) | when a workflow needs parallel per-item work |
| **Store (long-term memory)** | Remember per-app domain maps, last ERD `document_id` (auto update vs generate), learned preferences | opportunistic, per workflow |
| **Functional API (`@entrypoint`/`@task`)** | Fast path to port procedural code with durability | optional authoring style |
| **`langgraph dev` + Studio** | Interim dev/debug harness: attach Studio to a graph against the shared checkpointer for visualization/HITL/time-travel while building | Phase 5/6 |
| **LangGraph Studio** | Interim run visualization + HITL + time-travel before the custom workbench | Phase 5/6 (M6) |

---

## 3. Capabilities intentionally NOT relied on (yet)

| Capability | Why not (now) |
|---|---|
| **LangGraph Platform (hosted/cloud deploy)** | Genesis is local-only (ADR-003); we use the *server* locally, not the hosted platform. |
| **LangSmith cloud tracing** | Optional; local logging first. Can enable `LANGSMITH_TRACING` later for deep debugging. |
| **LangChain agent abstractions** | We don't use LangChain's agent loop — our "agent" is Kiro via ACP (ADR-002). LangGraph is used standalone. |
| **Managed/remote model providers inside nodes** | Model access is via Kiro (ACP); Genesis doesn't call models directly. |

---

## 4. Mapping to the three HITL modes (capability lens)

| HITL mode | LangGraph mechanism |
|---|---|
| 1 Approval/escalation gate | `interrupt(payload)` + resume `Command(resume=decision)` |
| 2 Pause/resume anywhere | cooperative stop at node boundary + resume from checkpoint (durability) |
| 3 State injection / fork | `update_state(config, values)` + fork from a chosen checkpoint (time travel) |

---

## 5. Why LangGraph over alternatives (recap, see decision-log ADR-001)
- Python-native (matches `kiro-agent-sdk`), first-class **HITL + checkpointing +
  streaming + subgraphs**, low-level orchestration without imposing an agent
  architecture (we bring Kiro). Temporal/OpenAI-SDK/Anthropic-Managed were viable
  but less aligned with our local, Python, Kiro-driven model.
