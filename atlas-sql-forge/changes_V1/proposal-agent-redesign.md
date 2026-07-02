# Atlas SQL Forge — Agent Redesign Proposal (fix the post-migration regression)

**Author:** Kiro (for Ramaswamy U)
**Created:** 2026-07-02
**Status:** PROPOSAL — for review before any rebuild
**Scope:** Diagnose why the power→agent migration made the agent "dumber," and propose a clean,
efficient, intelligent agent + skill + workflow structure.

---

## 1. What I examined

- **Working baseline (git `main`):** `POWER.md` + `steering/` (20 files) — the original power that "just worked."
- **Current agent (git `agent-migration`, working tree):** `.kiro/agents/sql-forge*`, `.kiro/settings/mcp.json`,
  and the `single-data-generation` / `bulk-data-generation` skills (each with a full copy of 13–15 references),
  plus `tool-references`, `schema-exploration`, `query-validate`, `rollback`, `erd-generation`.
- **All V1 planning docs** (`spec.md`, `TRACKER.md`, `PROGRESS-LOG.md`, F1–F7 plans) and the `architecture.md`.

### Key measurement (kills the obvious theory)
| File | Power (main) | Agent (now) | Verdict |
|------|--------------|-------------|---------|
| `action-generate-data.md` | 11.9 KB | 12.2 KB | ~unchanged |
| `step-1-workflow-analysis.md` | 26.1 KB | 26.1 KB | **identical** |
| `step-3` / `step-4` / `step-5` | 14.3 / 14.6 / 11.9 KB | same | ~identical |
| `step-0-initialize.md` | 7.9 KB | 12.6 KB | **grew (mode-aware, dual file/tracker sets)** |
| Agent prompt vs `POWER.md` | 8.8 KB | 10.2 KB + 12 rules + footnotes | **grew, and diluted** |

**The analysis steps did not get bloated. The regression is architectural, in three places: (a) how
sub-agents are spawned, (b) what the always-on prompt emphasizes, (c) bureaucratic overhead crowding out
intelligence.**

---

## 2. Diagnosis — why the agent got "dumber"

### 🔴 Root cause #1 — Worker sub-agents lost the always-on foundational context (the big one)

This single change explains the user's exact symptom ("misses basic things like getting the app schema").

**Power model (worked):**
```
Orchestrator (power active → POWER.md in context)
  └─ spawns sub-agent (role: kiro_default)
       prompt: "Read the steering file 'step-1-...' FROM THE atlas-sql-forge POWER. Follow it EXACTLY."
       → activating the power loads POWER.md into the sub-agent too:
         • CRITICAL RULES (get_record_type_map FIRST, get_field_map, query ref data LIVE, insertion order…)
         • the "Efficient Data Gathering" 6-call recipe ("after these 6 calls you have EVERYTHING")
         • tool catalogs + type-conversion table
       + the step file
   ⇒ every worker had the full foundational playbook.
```

**Agent model (broken):**
```
Orchestrator (running AS sql-forge → sql-forge-prompt.md in context)
  └─ spawns sub-agent (role: kiro_default)   ← a GENERIC agent, NOT sql-forge
       prompt: "Read the reference file `.kiro/.../step-1-...md`. Follow it EXACTLY."
       → kiro_default does NOT load sql-forge-prompt.md.
         It reads ONE big step file and nothing else. It loses:
         • the CRITICAL RULES
         • the 6-call data-gathering recipe (which isn't even in the new prompt anymore — see #2)
         • the tool boundary + tool catalogs
       + MCP-inheritance for kiro_default was never verified (flagged "the one unverified mechanic").
   ⇒ every worker is a context-starved generic agent skimming a 26 KB wall of text.
```

The workers are where Steps 1–5 actually happen. In the power they were *primed experts*; in the agent
they are *amnesiac generalists*. That is why schema-gathering fundamentals are now skipped.

### 🔴 Root cause #2 — The concrete tactical recipe was replaced by fear-fencing

`POWER.md` had a crisp, action-oriented block:
```
Step 1: get_record_type_map(app)   → ALL UUIDs + relationships
Step 2: get_field_map(app)         → ALL field names
Step 3: get_reference_data(app)    → ref table UUIDs
Step 4: list_users()               → usernames
Step 5: query_records(ref_uuid)    → live reference values
Step 6: get_insertion_order(app)   → creation sequence
"After these 6 calls you have EVERYTHING needed for data architecture."
```
The new prompt dropped this recipe and, worse, added a footnote telling the agent that rules 2–6 are
**"NOT a license to gather data"** and that gathering-then-acting is "the #1 failure mode." The net effect:
the prompt now *discourages* the natural, correct first move (pull the schema) instead of *teaching* it.
The agent hesitates on fundamentals and over-focuses on ceremony.

### 🔴 Root cause #3 — Emphasis saturation ("everything is MANDATORY")

Count the alarm words in one request path: the prompt has 12 CRITICAL RULES + "🛑 MANDATORY gated pipeline,
NO shortcuts" + "FORBIDDEN" + a tool-boundary HARD RULE; the SKILL adds "🛑 MANDATORY, NO SHORTCUTS" +
"#1 failure mode"; `step-0` adds "🛑 STOP", "YOU ARE VIOLATING THE WORKFLOW", "MANDATORY COMPLIANCE",
"BLOCKING RULES" ×3, and two giant ASCII trackers. **When every line shouts, the model can't rank
importance.** It satisfies the loudest, most concrete demands — *create 7 files, paste the tracker* — and
under-serves the quiet, genuinely important work — *understand the tables, trace the writes*.

### 🔴 Root cause #4 — Step 0 became bureaucratic overhead

`step-0` is now a 12.6 KB ritual about creating 7 (or 5) empty markdown stubs and copying a large tracker,
with mode-branching (Manual=7 files/tracker vs Exemplar=5 files/tracker). The agent burns its first and
freshest attention on paperwork, not on the application. Files-as-gates is a good idea; **this
implementation makes the gate the point instead of the data.**

### 🔴 Root cause #5 — Duplication and contradiction across layers

The same mandates are restated (with drift) in the prompt, each `SKILL.md`, and `action-generate-data.md`;
and `single`/`bulk` each keep a full copy of 13–15 references (a deliberate decision, but it doubles the
drift surface and the context noise). Three overlapping voices repeating gates ≠ clarity.

### 🔴 Root cause #6 — Mode gate friction up front

`single` now forces "ASK FIRST: Manual vs Exemplar" before *any* analysis, and `step-0` maintains two file
sets / two trackers / two gate regimes. More branching and juggling before the agent even looks at the app.

### ⚠️ Security (must flag)
`.kiro/settings/mcp.json` contains **live plaintext secrets** committed to the repo: `GITLAB_TOKEN`,
`APPIAN_API_KEY`, and `LCP_PASSWORD`. These should be rotated and moved to env-var injection (not committed).

---

## 3. Design principles for the fix

1. **One always-on brain, injected everywhere it's needed.** The foundational playbook (the 6-call recipe,
   the anti-hallucination rules, the tool boundary) must be present in *every* context that does real work —
   the orchestrator **and** every worker sub-agent. Never rely on a generic `kiro_default` worker.
2. **Teach the happy path first; gate second.** Lead with the concrete "how to do this well" recipe. Keep
   gates, but as a short checklist at the end of a step — not as the step's headline.
3. **One emphasis budget.** Reserve 🛑/HARD only for the *few* things that are genuinely destructive or the
   actual known failure. Everything else is plain, calm instruction. If everything is critical, nothing is.
4. **Single source of truth per concept.** Each rule/step lives in exactly one file. Skills *compose*
   references; they don't restate them.
5. **Intelligence > ceremony.** Minimize file-creation bureaucracy. The artifacts should be a *byproduct* of
   thinking, not the objective.
6. **Progressive disclosure.** Prompt = short and always-on. SKILL = the workflow spine. References =
   loaded only when a step needs them.

---

## 4. Proposed structure

### 4.1 Directory layout (shared pipeline restored, no duplication)

```
.kiro/
├── agents/
│   ├── sql-forge.json                 # role agent: holds MCP; availableAgents = [sql-forge-worker]
│   ├── sql-forge-prompt.md            # LEAN always-on brain (see §4.3) — ~120 lines
│   ├── sql-forge-worker.json          # NEW: the per-step worker (SAME MCP + SAME core primer)
│   └── sql-forge-worker-prompt.md     # NEW: core primer (rules + 6-call recipe + tool boundary)
├── settings/
│   └── mcp.json                       # secrets via env injection, NOT committed
└── skills/
    ├── _core/                         # NEW shared skill (the single source of truth)
    │   ├── SKILL.md                   # the pipeline spine + the data-gathering recipe
    │   └── references/
    │       ├── step-1-workflow-analysis.md
    │       ├── step-2-exemplar-discovery.md
    │       ├── step-3-data-architecture.md
    │       ├── step-4-data-payloads.md
    │       ├── step-4b-coverage-gate.md
    │       ├── step-5-validation.md
    │       ├── step-6-execute.md        # single
    │       ├── step-6-bulk-csv.md       # bulk primary
    │       ├── step-6-generate-sql.md   # bulk fallback
    │       ├── exemplar-E1..E4.md
    │       ├── initialize.md            # SLIM step-0 (see §4.4)
    │       └── tool-reference-{atlas,lcp}.md
    ├── single-data-generation/SKILL.md  # THIN: mode + "run _core pipeline, Step 6 = execute"
    ├── bulk-data-generation/SKILL.md    # THIN: mode + "run _core pipeline, Step 6 = bulk-csv/sql"
    ├── schema-exploration/              # read-only (unchanged)
    ├── query-validate/                  # (unchanged)
    ├── rollback/                        # (unchanged)
    └── erd-generation/                  # (unchanged)
```

> **Decision reversal:** the 2026-07-02 "delete the shared `data-pipeline` skill and duplicate everything
> into single/bulk" change is a primary contributor to drift and noise. **Restore a single shared `_core`
> pipeline;** `single`/`bulk` become ~30-line thin wrappers that differ only at Step 6. This is the F5-plan
> D-4 design ("shared pipeline skill; single/bulk stay thin") — the split moved us backwards.

### 4.2 The critical fix — a dedicated worker agent (not `kiro_default`)

Replace `role: kiro_default` in the sub-agent pipeline with a purpose-built **`sql-forge-worker`** agent that:
- **inherits the same MCP servers** (`@appian-atlas`, `@lcp-mcp-server`) via `includeMcpJson: true`, and
- **carries the core primer** (`sql-forge-worker-prompt.md`) so every worker starts with the CRITICAL RULES
  + the 6-call data-gathering recipe + the tool boundary — *exactly what the power's re-activation gave them.*

The orchestrator then hands a worker a *short* task ("Do Step 3 for {app}, folder {path}; read
`_core/references/step-3-data-architecture.md`") and the worker already knows how to gather schema. This
restores the "primed expert per step" behavior that made the original work.

`sql-forge.json` sets `toolsSettings.subagent.availableAgents: ["sql-forge-worker"]` and `trustedAgents`
so orchestration is deterministic and never falls back to a generic agent.

### 4.3 The lean always-on prompt (`sql-forge-prompt.md`) — shape

Keep it to ~120 lines with this order (happy-path first, gates last, one emphasis budget):
1. **Identity** (2 lines).
2. **Capabilities menu** (one line per skill).
3. **The data-gathering recipe** — restored verbatim as the *headline* (the 6 calls → "you now have
   everything"). This is the antidote to the missed-basics symptom.
4. **How a generation job runs** — Step 0 (slim) → delegate Steps 1–5/E1–E4 to `sql-forge-worker` →
   orchestrator does Step 6. 5 lines, calm tone.
5. **The 3 rules that are actually HARD** (only these get emphasis): (a) never invent objects/UUIDs/values —
   everything from a tool result; (b) only `@appian-atlas` + `@lcp-mcp-server`, stop-and-report on failure;
   (c) mutations target non-prod and prompt for approval.
6. **Everything else** (field maximization, insertion order, "don't pass selected_fields", file-gates) as a
   plain bulleted "good practice" list — no 🛑, no ALL-CAPS.
7. Pointer to `_core/SKILL.md` for the workflow and `tool-references` for catalogs.

### 4.4 Slim Step 0 (`initialize.md`)

- Create the request folder `data-requests/{YYYY-MM-DD}_{desc}/` (workspace-relative) and **one** tracker
  file. Create milestone files **lazily** — each step creates its own output file when it runs (a step
  can't complete without its file, which is the real gate). No 7-empty-stub ceremony, no dual trackers.
- Mode (Manual/Exemplar) is a single field in the tracker; the file list follows from it naturally.

### 4.5 Emphasis budget (apply repo-wide)

- Delete ~90% of 🛑 / ALL-CAPS / "MANDATORY" / "FORBIDDEN" / "VIOLATING" language.
- Keep at most **one** ⚠️ per reference, on the single thing most likely to actually go wrong in that step.
- Convert the giant ASCII trackers to a compact 8-line checklist.

---

## 5. The proposed workflow (unchanged in spirit, leaner in delivery)

```
Step 0  Initialize      orchestrator   folder + 1 tracker (mode noted). No stub ceremony.
Step 1  Workflow/Intake worker         Manual: trace writes (get_entry_point_write_graph/resolve_write_set)
                                        Exemplar: E1 intake (ask user for the reference id)
Step 2  Discover        worker         Manual: exemplar cross-check · Exemplar: E2 footprint (full FK graph)
Step 3  Architecture    worker         field maps, live ref data, insertion order, coverage checklist
Step 4  Payloads        worker         payloads/ with reasoning, ≥80% field coverage
Step 4b Coverage gate   worker         Manual only: resolve_write_set vs payloads (the one true HARD gate)
Step 5  Validation      worker         FK integrity, exemplar diff, ref-id resolution
Step 6  Execute         orchestrator   single: create_record · bulk: expand_record_csv→insertRecordData
                                        then verify_write_coverage
```
- **Only two real gates remain:** (1) Step 4b coverage (Manual) / E4 footprint-completeness (Exemplar), and
  (2) "no writes until validation ✅." Everything else becomes ordinary sequencing, not a ceremony.
- Every worker step is run by `sql-forge-worker` (primed), so schema-gathering fundamentals are guaranteed.

---

## 6. Migration plan (safe, reversible, verifiable)

1. **Branch** off `agent-migration` (e.g. `agent-redesign`); do not touch `main`.
2. **Add the worker agent** (`sql-forge-worker.json` + `-worker-prompt.md`) with the core primer + MCP.
3. **Restore `_core`** shared pipeline skill; move the (unchanged) step references there once; delete the
   duplicated copies from `single`/`bulk`; make `single`/`bulk` thin wrappers.
4. **Rewrite `sql-forge-prompt.md`** to the lean shape (§4.3) — recipe first, one emphasis budget.
5. **Slim `initialize.md`** (§4.4) and strip alarm-language repo-wide (§4.5).
6. **Repoint `action-generate-data.md`** to spawn `sql-forge-worker` (not `kiro_default`).
7. **Verify** with two live runs on `SourceSelection` (env pointed at the app's real env):
   - *Single / Manual:* "create an evaluation in In Progress." Confirm the worker calls
     `get_record_type_map`/`get_field_map`/reference queries **without being told**, gates through 4b, and
     creates child rows.
   - *Bulk / Exemplar:* clone-and-scale a reference eval; confirm footprint completeness + CSV load.
8. **Secrets:** rotate the exposed token/key/password and switch `mcp.json` to env injection.
9. Keep `main` (power) intact until the redesigned agent passes both runs; then merge.

---

## 7. Summary of what changes vs. what stays

| Area | Keep | Change |
|------|------|--------|
| Analysis content (steps 1–5) | ✅ keep (it was never the problem) | move to one `_core` copy |
| Sub-agent workers | ✅ per-step isolation | **use `sql-forge-worker` (primed), not `kiro_default`** |
| 6-call data recipe | — | **restore as the prompt headline** |
| Prompt / SKILL / step tone | files-as-gates idea | **one emphasis budget; recipe-first** |
| Step 0 | folder + tracker | **slim; lazy file creation; one tracker** |
| single/bulk skills | two entry points | **thin wrappers over shared `_core`** |
| Gates | 4b coverage + "no write before validation" | **drop the rest to plain sequencing** |
| Secrets in mcp.json | — | **rotate + env-inject** |

---

*Nothing in this document has been implemented. It is a proposal for review. On approval, I'll execute §6
on a new branch and verify with the two live runs before proposing a merge.*
