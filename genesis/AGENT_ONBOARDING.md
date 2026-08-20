# Genesis — Agent Onboarding & Reference ("the bible") — INDEX

> **This is the bible index.** The Genesis bible is the single, task-agnostic source of truth that brings any agent
> session fully up to speed on Genesis and defines every practice you must follow. It has been **split into functional
> chunks** under [`bible/`](./bible/) so that agents can find + update the right part without wrestling a 1,300-line file.
> **Splitting changed the packaging, NOT the authority: the bible is still one document — read + obey all of it.**
>
> ## ⛔ MANDATORY — what "read the bible" means
> When the human says **"read the bible"** (or points you at `AGENT_ONBOARDING.md`), you MUST:
> 1. Read **this index**, then
> 2. Read **every chunk listed in the manifest below, in order** — not just the one that looks relevant. The chunks are
>    interdependent (architecture ↔ ADRs ↔ lessons ↔ the loop); skipping any means you will violate a constraint you
>    never read.
> 3. Then **follow all of it religiously** for the rest of the session — the ADRs (§5) and working agreements (§8/§10)
>    are non-negotiable; the lessons (§7) are do-not-regress.
>
> After reading, briefly **restate** the architecture + current state + the non-negotiables, then do the work the human
> gives you following the loop in `bible/07-working-on-tasks-and-agreements.md` (§8). **This document assigns no task.**
>
> **Last refreshed: 2026-08-20 — latest SHIPPED: genesis v0.51.4 + genesis-core v0.9.5 + genesis-workflows v0.9.6 +
> kiro-agent-sdk v0.7.0 + genesis-appian-parser v0.2.0.** (genesis v0.50.0 + genesis-core v0.9.5 = the
> Phase-25 Architectural Foundation Hardening release (v0.49.0 + v0.50.0), sub-phases 25-01..25-10 + 25-13 (25-11 + 25-12 backlog) — Phase 25 COMPLETE.)
> **Newest planning: Phase 26 — Agentic Memory Layer — IN PROGRESS. 26-01 + 26-02 + 26-03 + 26-05 (read-path
> MCP) + 26-08 (Memory Management UI + curation API) + 26-04 (the memory-maintenance "dreaming" workflow) are
> BUILT (unreleased — local on `genesis` + `genesis-workflows` master, no tag; the phase release is 26-07).
> NEXT = 26-06 (scheduler + config + `GET /api/system/memory`). Umbrella + 26-01..26-08 spec'd; Proposed
> ADR-053 + ADR-054.**
> See `bible/08-roadmap-and-backlog.md` §9 + `specs/phase-26-agentic-memory-layer.md` + `progress/phase-26-agentic-memory-layer.md`.
> (Full phase/release banner + version detail live in
> `bible/00-onboarding-and-overview.md` and `bible/01-current-state.md`.)

---

Onboard to the Genesis project by reading its bible before doing anything else.
  
  1. Read the bible INDEX first:
     /Users/ramaswamy.u/repo/project-tracker/genesis/AGENT_ONBOARDING.md
  
  2. Then read EVERY chunk it lists, in order — do not skip any (they are interdependent):
     - bible/00-onboarding-and-overview.md   (purpose, what Genesis is, read-order)
     - bible/01-current-state.md             (repos/tags, tests, what works)
     - bible/02-architecture.md              (mental model)
     - bible/03-codebase-map.md              (where code lives)
     - bible/04-adrs-and-constraints.md      (ADR-001..047 — non-negotiable)
     - bible/05-dev-loop-and-release.md      (env, tests, release, CI)
     - bible/06-hard-won-lessons.md          (do-not-regress bugs)
     - bible/07-working-on-tasks-and-agreements.md (the work loop + working agreements)
     - bible/08-roadmap-and-backlog.md       (shipped phases + what's next)
  
  3. Then read the supporting docs the bible points to (at least):
     - tracker.md  — read §6 STATUS LOG top-down (the running history / source of truth for "what is done")
     - reference/decision-log.md      (the ADRs — the "why")
     - reference/coding-standards.md  (§1 is the hard floor)
     For the specific area you'll touch, also read the relevant specs/<phase>.md and progress/<phase>.md,
     and the cited source files, BEFORE editing.
  
  4. When done, briefly RESTATE: the layered architecture, the reliability trio, the state/blackboard rule,
     the subprocess-worker model, the SQLite data plane, and the release/versioning protocol — plus the
     current shipped versions.
  
  Then follow the bible religiously for the rest of the session: obey the ADRs (§5) and working agreements
  (§8/§10), respect the hard-won lessons (§7), and use the work loop in §8 (understand → verify against real
  code → smallest correct change → test → run all gates green → release if a repo changed → update the bible
  + tracker + progress → report with cited evidence). Do NOT start backlog or a new phase unless I explicitly
  ask. Ask before any destructive/irreversible action.
  
  Do not write any code or make changes until you have read the above and given me the restatement.
  
  If you want a shorter version for quick use:
  
  Read the Genesis bible before doing anything: start at
  /Users/ramaswamy.u/repo/project-tracker/genesis/AGENT_ONBOARDING.md and read the INDEX plus EVERY chunk in
  bible/ (00–08) in order — don't skip any. Then read tracker.md §6, reference/decision-log.md, and
  reference/coding-standards.md, plus the specs/ + progress/ docs and source files for the area I name.
  Briefly restate the architecture + current state + non-negotiables, then follow the bible religiously
  (ADRs and working agreements are non-negotiable; use the §8 work loop). Don't start backlog/new-phase work
  unless I ask, and ask before destructive actions. No code changes until you've read it and restated.
  
  Both point at the index, which itself enforces the read-all rule — so even the short one will pull the whole bible.

## ▶ ACTIVE HANDOFF — continue Phase 26 (Agentic Memory Layer) at **26-06**

> **After reading the whole bible, this is the work to pick up.** Phase 26 is IN PROGRESS; **26-01 + 26-02 +
> 26-03 + 26-04 + 26-05 + 26-08 are BUILT + tested green but UNRELEASED** (local commits, no tag — the phase
> release is **26-07**). Only **26-06** remains before the **26-07** release.
>
> **Read first (in this order):** `specs/phase-26-agentic-memory-layer.md` (umbrella) →
> `specs/phase-26-agentic-memory-layer/26-06-scheduler-integration-and-config.md` (the next task) →
> `progress/phase-26-agentic-memory-layer.md` (as-built for 26-01..26-08) → `bible/08` §9 Phase-26 block →
> **Proposed ADR-053 + ADR-054** in `bible/04`. Then read the code the task cites before editing.
>
> **Done so far (reuse these — do NOT rebuild):** 26-01 store/graph + `mm0001`; 26-02 embedder + vectors;
> 26-03 `memory-consolidation` write workflow + `ctx.extras`; 26-04 `memory-maintenance` "dreaming" workflow;
> 26-05 read-only `genesis-memory` MCP + retrieval (chat-wired); 26-08 curation API (`genesis/api/memory.py`)
> + the `/memory` web workspace. Both workflows are registered in genesis-workflows `registry.json`.
>
> **NEXT = 26-06 — scheduler integration + config (genesis):** (1) register two backend `Scheduler` jobs
> (mirror `genesis/runtime/sync_jobs.py` `DEFAULT_JOBS` + `register_sync_jobs`, wired in `api/app.py`):
> **memory-consolidation** (~02:00 IST daily) + **memory-maintenance** (~Sun 03:00 IST) — each starts the
> workflow via `RunManager.start(<id>, {owner})`. (2) A **`memory_owner_username`** Setting
> (`runtime/settings.py`, env `GENESIS_MEMORY_OWNER`) threaded into: the MCP launch `--owner`
> (`chat/mcp.py._memory_entry` already reads `getattr(settings,'memory_owner_username','local')` — make the
> attr real), the workflow `owner` input, and `api/memory.py`'s `edited_by`. (3) **`GET /api/system/memory`**
> — memory health/stats (counts by scope/type, pending-embeddings, last consolidation/maintenance run from
> `consolidation_cursor()`), + a web surface if in scope. (4) The **internal-server node-injection
> follow-up from 26-05** — let agentic workflow nodes inject `genesis-memory` (a genesis-core seam mirroring
> `_kb_entry` for nodes; the shared `mcp-registry.json` can't express the venv `command`).
>
> **Then:** **26-07** (release: bump/tag **genesis + genesis-workflows**, `genesis db upgrade` covers both
> DBs, ADR-053/054 → Accepted, docs). This is the FIRST push to master for Phase 26 — everything above is
> local/unpushed until the human approves the release.
>
> **Gotchas / rules:** memory.db is **separate** (`settings.memory_db_path`), own migrations; the embedder/
> vector index only load in the **worker/MCP subprocess**; retrieval degrades under `NullEmbedder`; memory.db
> writes in async nodes go via `asyncio.to_thread` (bible §7). **Code commits are local/unpushed** (genesis
> master ahead ~7; genesis-workflows ahead 2) — the release is 26-07; don't push master / bump versions until
> then unless the human asks.
>
> **Dev/test (bible §6):** venv `genesis/.venv`. Gates: `cd genesis && .venv/bin/python -m pytest -q -p
> no:warnings` (currently **627**) `+ .venv/bin/ruff check genesis`; web `cd genesis/web && npx tsc --noEmit
> && npx eslint . && npx vitest run` (**189**) then `npm run build` (→ web/static, commit it); workflows
> `cd genesis-workflows && ../genesis/.venv/bin/python ci/validate_library.py + ... -m pytest -q workflows
> --ignore=workflows/_fixtures` (**93**). Stub Kiro via `set_collect_impl` (see the memory workflow tests).

---

## 📚 The bible manifest (read all, in this order)

| # | Chunk | Original § | What it holds — why you read it |
|---|---|---|---|
| 0 | [`bible/00-onboarding-and-overview.md`](./bible/00-onboarding-and-overview.md) | header + §0 + §1 | Purpose + how to keep the bible current; the phase/release banner; **what Genesis is** (one paragraph); the **onboarding read-order** (which design docs + code to read before touching an area). **Start here.** |
| 1 | [`bible/01-current-state.md`](./bible/01-current-state.md) | §2 | **Current state** — the five-repo tag table, dependency chain, test counts, milestones, and "what works today". *Changes every release.* |
| 2 | [`bible/02-architecture.md`](./bible/02-architecture.md) | §3 | **Architecture / mental model** — layered design (agents never orchestrate), the reliability trio, state/blackboard rule, subprocess-worker execution, the SQLite data plane, HITL modes, release/versioning. |
| 3 | [`bible/03-codebase-map.md`](./bible/03-codebase-map.md) | §4 | **Codebase map** — where every module lives across genesis-core / genesis / genesis-workflows / kiro-agent-sdk / genesis-appian-parser. |
| 4 | [`bible/04-adrs-and-constraints.md`](./bible/04-adrs-and-constraints.md) | §5 | **Non-negotiable constraints** — ADR-001..047 + key implementation contracts. **Do not violate; flag + confirm if a task requires it.** |
| 5 | [`bible/05-dev-loop-and-release.md`](./bible/05-dev-loop-and-release.md) | §6 | **Environment, dev loop, release, CI** — the venv, how to run tests/app, the versioning/tag/push protocol, CI, npm/gitignore gotchas. |
| 6 | [`bible/06-hard-won-lessons.md`](./bible/06-hard-won-lessons.md) | §7 | **Hard-won lessons** — concrete bugs + root causes you must not regress. *Grows often.* |
| 7 | [`bible/07-working-on-tasks-and-agreements.md`](./bible/07-working-on-tasks-and-agreements.md) | §8 + §10 | **The work loop** (understand→verify→scope→test→gates→release→document→report) + the **working agreements** (honest pushback, ask before destructive actions, keep scope tight). |
| 8 | [`bible/08-roadmap-and-backlog.md`](./bible/08-roadmap-and-backlog.md) | §9 | **Roadmap & backlog** — the shipped-phase as-builts (context) + what is next. *Largest; grows every phase.* |

Adjacent authoritative folders (referenced throughout the chunks): [`specs/`](./specs/) (per-phase plans + `specs/backlog/` deferred work + `specs/bugs/` filed defects), [`progress/`](./progress/) (as-built records), [`reference/`](./reference/) (decision-log/ADRs, coding-standards, taxonomies), [`spike/`](./spike/), [`tracker.md`](./tracker.md) (§6 status log = running history).

---

## 🔁 Cross-reference map (§N → chunk)

The chunks preserve the original section numbers, so references inside them like *"see §7"* / *"per §2"* still resolve.
Use this map:

- **§0** What Genesis is → chunk 00 · **§1** How to onboard → chunk 00
- **§2** Current state → chunk 01
- **§3** Architecture → chunk 02
- **§4** Codebase map → chunk 03
- **§5** ADRs / constraints → chunk 04
- **§6** Environment / dev loop / release / CI → chunk 05
- **§7** Hard-won lessons → chunk 06
- **§8** The work loop → chunk 07 · **§10** Working agreements → chunk 07
- **§9** Roadmap & backlog → chunk 08

---

## ✍️ Keeping the bible current (part of Definition of Done)

When tags, architecture, ADRs, or hard-won lessons change, update the **specific chunk** (not a monolith) and this
index's "Last refreshed" stamp. Routing:

- **A release** (new tag / version / test counts / "what works") → `bible/01-current-state.md` (§2) + this index's
  Last-refreshed line + the release banner in `bible/00-onboarding-and-overview.md`.
- **A new/changed ADR** → `bible/04-adrs-and-constraints.md` (§5) — and mirror the decision in `reference/decision-log.md`.
- **A new hard-won lesson** → `bible/06-hard-won-lessons.md` (§7).
- **A new module / moved code** → `bible/03-codebase-map.md` (§4).
- **A roadmap/phase change** → `bible/08-roadmap-and-backlog.md` (§9).
- **A change to the process/loop or working agreements** → `bible/07-working-on-tasks-and-agreements.md` (§8/§10).

Rules for editing a chunk: **keep it verbatim-faithful — never summarize away or drop existing content when adding an
entry** (the intelligence of the bible is the accumulated detail). Append/refine in place. If you add a NEW chunk, add a
row to the manifest above and to the §→chunk map. Then push project-tracker (`git pull --rebase` → push) per §6.
