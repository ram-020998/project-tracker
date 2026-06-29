# 19 — Workflows / Orchestration: Exploration, Spike & Deferral

**Status:** 🅿️ **DEFERRED — NOT REQUIRED AS OF NOW** (decision 2026-06-29) · **Type:** exploration + spike
record · **Builds on:** doc 01 §3 (orchestrator deferred + anti-pattern), docs 13–17 (dashboard)

> Captures the exploration of a **Workflows** feature for the Solutions Copilot dashboard — an
> orchestrated, human-gated, multi-step flow over the role agents — plus the Kiro capability **spike**
> and the resulting design options. **Decision: parked.** Two prerequisites must land first (see §6).
> Documented so the analysis isn't lost when we revisit.

---

## 1. The idea (as proposed)
Add a **Workflows** capability to the dashboard: users interactively build a multi-step flow (add
steps, pick the agent per step, give per-step steering instructions, mark whether human approval is
required to proceed), saved as a JSON/steering definition that an **orchestrator** follows end-to-end.

**Motivating example — dev SDLC for a story:**
1. Dev agent gets the ticket (via integrations/Jira) → gathers existing state (atlas/jarvis) → drafts a
   design doc → **human approves / rejects / modifies**.
2. On approval, implement (incorporating feedback) → mark step complete.
3. Code review of the changes → if feedback, dev fixes.
4. DevOps deploys to **test**.
5. Tester tests the ticket.
6. On pass, DevOps deploys to **other environments**.

---

## 2. Best-practice research (2026) — what the field says
- **Anthropic (*Common workflow patterns*, Mar 2026):** three production patterns — **sequential,
  parallel, evaluator-optimizer**. **Default to sequential** for multi-stage dependencies / draft-review-
  polish (our SDLC is exactly this). "Workflows don't replace agent autonomy; they **shape** where and
  how agents apply it." **Pro tip: try a single agent first; only split into a workflow when one agent
  can't do it reliably.** Autonomous agents = last resort.
- **Human-in-the-loop (2026):** approval gates should be **rare, targeted, load-bearing** — over-gating
  causes *approver fatigue* and queue bottlenecks ("HITL is a queue, and queues have dynamics"). Gate
  design approval and prod-deploy; let safe steps auto-proceed.
- **Durable execution is "table stakes"** for long-running agent workflows (LangGraph checkpointers,
  Temporal event logs, OpenAI Agents SDK resume, Anthropic Managed Agents). Async queues break for
  long-running flows; state must be checkpointed + resumable.

## 3. Tension with our own program (must be acknowledged)
**Doc 01 §3** explicitly **defers an orchestrator (decision #7)** and names this exact failure mode:
chaining role agents into a sequential pipeline for the *same* feature = the **"telephone game"**
(role-split sequential agents *"spent more tokens on coordination than on actual work"*); "decompose by
context boundaries, not by problem type." The proposed workflow **is** a role-agent pipeline — so
building it is a deliberate re-opening of a deferred decision. The difference between the anti-pattern
and a good workflow is entirely in the **how**: deterministic control flow (not an improvising LLM),
well-defined hand-off artifacts, **targeted** gates, and persisted resumable state. We already have
three of those four ingredients (analysis-document hand-off, execution-tracker discipline, role agents).

---

## 4. Kiro capability spike (2026-06-29) — findings
Probed via `kiro-cli` help, the orchestration tool docs, and session storage.

**Primitives that exist:**
- **`subagent` / `agent_crew`** — DAG pipeline of agents (`depends_on`, parallel where independent).
  **Limits:** `blocking` mode only; **sub-agent sessions terminate on completion and cannot be
  resumed**; **no nesting** (a sub-agent cannot spawn sub-agents); non-configurable turn limit. → a
  single-shot, in-turn delegation engine.
- **`session-management` (ACP)** — persistent sessions, inbox/`send_message` (escalation-to-parent),
  `interrupt`, `inject_context`, `revive_session`, groups. **But "excluded from the default agent tool
  set… used internally."** Whether a custom orchestrator can be granted it is **unverified**.
- **Planning Agent (`/plan`)** — built-in **plan → human approval → hand off to execution agent**.
  Precedent that Kiro does HITL gate + context transfer, but it's one fixed built-in.
- **Session durability + resume** — conversations persist (SQLite, per-directory), resumable by ID
  (`--resume`, `--resume-id`, `--resume-picker`); `--list-sessions --format json` returns `sessionId`s.
- **Headless** — `--no-interactive "query"` + trust flags; one-shot, no mid-session input, approval
  prompts hang.
- **Agent CLI** — `kiro-cli agent create/edit/validate/set-default` (programmatic).
- **No** `workflow`/`schedule`/`background`/`cron`/`orchestrate` subcommand. **No native durable,
  human-gated, resumable workflow engine.**

**Validated by the user (IDE):** an agent instructed by **steering** to get approval **pauses and asks
inline, and only continues on "Yes."** → Human-in-the-loop gates work natively in a live IDE session;
**headless is not needed.**

### 4.1 THE decisive constraint
**No sub-agent nesting + lean role agents (no own MCP) ⇒ an orchestrator CANNOT spawn role agents as
workers for action steps.** A nested `developer` can't delegate to atlas/jarvis and has no MCP itself,
so it can't explore/build/deploy. The only legal one-level shape is: the **top-level agent delegates
directly to the MCP-owning agents** (atlas-intel, jarvis-intel, data-generator, integrations).

---

## 5. Design options (when revisited) — native IDE, no headless
- **C2 (recommended for the native single-chat feel):** one **workflow-orchestrator agent** the user
  chats with that reads the workflow steering, **carries the role *skills*** (progressive disclosure),
  **delegates only to the four MCP-owning sub-agents** (one level — legal), pauses **inline** for
  approvals (validated), and reads/updates a **run-state file** (`.kiro/workflows/runs/<id>.json`) per
  step (execution-tracker discipline) so it survives close/`--resume`. Keeps the key win (no heavy MCP
  on the main agent); gives up per-role *prompt* isolation (one agent, many hats).
- **C1 (role-purist):** the **dashboard owns** the workflow def + run-state + gates; each step runs as
  that **role agent in a normal IDE chat** (top-level → delegation works), human approves inline and
  advances the step in the dashboard. The orchestrator is the extension + the human.
- **Durability without headless:** run-state file as source of truth + native session `--resume`.
- **Authoring UI** (dashboard): steps `{agent, skill?, instructions, inputsFrom, gate}`, reject→loop
  targets; produces the workflow JSON. Low-risk, manifest-driven; valuable regardless of runtime.

### 5.1 Open questions to verify before building
1. Does **tool-approval surface when the actor is a sub-agent** (e.g. a jarvis-intel deploy gate), not
   just the top-level agent? (User validated top-level only.)
2. Can the **dashboard launch/seed a native IDE chat** with a chosen agent + prefilled prompt (for a
   one-click "Start workflow"), or only hand over a copy-able prompt?

---

## 6. Why this is DEFERRED (prerequisites) — decision 2026-06-29
Workflows orchestrate steps; the steps must work first. Parked until:
1. **The six role agents are tested, hardened, and verified working** end-to-end (live runs, not just
   structural validation) — see doc 11 §7. A workflow over unreliable steps amplifies failures.
2. **Agent-driven Appian object development is solved.** Today, actually *creating/modifying Appian
   objects* (the "implement" and "deploy" steps) is effectively a **manual step** — there is no proven,
   reliable path for an agent to author Appian objects via jarvis/Local-Component-Plugin/etc. **This is
   the real blocker.** Until an agent can dependably build and deploy objects, the most valuable
   workflow steps can't be automated, so orchestrating them is premature.
3. (Then) close the §5.1 open questions and pick C2 vs C1.

**Conclusion:** the concept is sound and on-trend, the Kiro substrate is sufficient (native IDE +
inline gates + run-state + resume; orchestrator delegates to MCP-owning agents, never nests role
agents), but it is **not required now**. Revisit after hardening + the object-development capability
land. This document preserves the full analysis for that time.

---

## 7. Related
Doc 01 §3 (orchestrator deferral + anti-pattern), doc 02 (subagent/hooks primitives), docs 13–17
(dashboard/installer that would host the authoring UI + run-state), doc 10 (backlog), doc 11 §7
(hardening prerequisites).
