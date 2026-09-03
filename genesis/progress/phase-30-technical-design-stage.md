# Phase 30 — Technical Design Stage — as-built

> **✅ SHIPPED (2026-09-03).** genesis **v0.57.0** (`0878b13`) + genesis-workflows **v0.13.0** (`ae1181c`), CI green
> (genesis **#6725001** / workflows **#6725004**). **ADR-058 Accepted** + an **ADR-056 prerequisite amendment**.
> genesis-core / kiro-agent-sdk / genesis-appian-parser **unchanged**; **no migration** (`current_version` stays 15).
> Specs: `specs/phase-30-technical-design-stage.md` (+ `30-01..30-07`, `30-01-findings.md`).

## What shipped

The third feature stage goes live — and the first that **depends on** its predecessors. Once the **Spec + UX
Design** artifacts exist (in-review/completed), the user opens the Technical Design card, provides an optional
**comment**, and clicks **Start** → a supervised **`technical-design-analysis`** run ("Technical Design
Preparation") produces a reader-first, **object-level, code-grounded** Technical Design; a bound
**`technical_design` completion chat** finalizes it via the same annotatable review as Spec/UX.

### The workflow (genesis-workflows v0.13.0)

`workflows/technical-design-analysis/` — a deterministic LangGraph graph (ADR-001):
`resolve_inputs → load_inputs → plan_sections →[v_plan]→ start_analysis → next_analysis →(analyze)
analyze_section →[v_analysis]→ advance_analysis → next_analysis …→(all analyzed) next_draft →(draft)
draft_section →[v_design]→ advance_draft → next_draft …→(all drafted) assemble →[v_doc]→ verify →[v_verify]→
route_verify →(ok) present ; →(revise, bounded MAX_VERIFY_ROUNDS) assemble ; →(exhausted) escalate`.

- **Plan** decomposes the work into **functional workstreams** (`plan_sections`).
- Two **queue-pop map loops**: per-workstream **existing-state grounding** (`analyze_section`, `@genesis-kb`
  structure/deps + `@appian-dev` actual code — read-only allowlists; save-by-reference for bulk output) then
  per-workstream **design drafting** (`draft_section`). Each loop resets the loop node's retry counter per
  iteration (the §7 code-review-loop lesson).
- **`assemble`** is an **agent** coherence pass (dedup / consistent headings / global roll-up), not a concat.
- **`verify`** is a **grounded critic** (re-checks the draft against Spec + UX + existing-state + a live
  spot-check; flags ungrounded/assumed claims → Open Questions), bounded → escalation gate.
- Every agent wears the ADR-011 reliability trio; `recursion_limit: 300`. `META`/`workflow.yaml` parity; 19 tests.
- Output template (reader-first): Overview → per-workstream (Objective → What exists today → What changes
  [DB/Records/Processes/UI/Expression-rules/Integrations, data-model tables] → Complex designs → Open
  Questions) → global Complex Designs + Open Questions. Each change names a real object or is marked **NEW**.

### The platform (genesis v0.57.0)

- **Backend** (`api/features.py`): `POST /features/{id}/stages/technical_design/start` + `/rerun` (JSON,
  optional comment, no file) with the **prerequisite gate** (Spec + UX at in-review/completed → 409) + friendly
  409 when the workflow isn't installed; `_launch_td` snapshots the Spec + UX HTML to files + launches the run
  **read-only**; `start` rejects an in-flight OR already-finalized stage; upload/reupload guarded to `ux_design`.
- **Generalized `StageFinalizer`** (`chat/stage_finalizer.py`): a `_BINDINGS: {workflow_id → {stage, artifact,
  chat_mode, seed}}` registry; `_finalize` resolves by `rec.workflow_id`, skips unknown workflows, and keeps the
  bound-run (v0.56.2) + a new stage-match guard + the chat_session_id idempotency. One observer serves both
  ux-design-analysis + technical-design-analysis.
- **`technical_design` `ChatModeProfile`** + `_STEERING_TD` (read-only KB/live tools + sandboxed fs-write; the
  only new agent prompt) + the `chat/store.py` mode whitelist.
- **Web** (`web/src/features/features/`): `STAGE_DEFS.design` flipped live + `requires:["spec","ux"]` +
  `deriveAvailability` gating; a `design` stage-registry entry; the TD entry state (blocked / comment+Start /
  running, reusing the in-progress pattern) + `TechnicalDesignCardActions` (Locked/Start/View/Re-run) +
  `RerunTechnicalDesignButton`; `startStage`/`rerunStage` api + `useStartStage` hook.

### UX refinements (30-05, frontend)

- **Clickable stage cards** — the whole card is the click target (accessible stretched-link overlay button); the
  standalone Open/Details button is removed from `StageCard` + all three CardActions; locked + not-available
  cards are not navigable.
- **Openable artifacts** — the Artifacts tab lists every generated stage artifact (Spec/UX/Technical Design) +
  linked reference docs, each clickable: generated → a read-only rendered preview (stage artifact route,
  annotate=0); reference → the Document Library viewer.

## Sub-phases

30-01 research & format study (findings) → 30-02 ADR-058 + finalize → 30-03 workflow → 30-04 platform → 30-05
UX refinements → 30-06 review & hardening (2 fixes: TD-start finalized-stage guard + finalizer stage-match
guard) → 30-07 coordinated release.

## Gates at release

genesis pytest **665** + ruff · web tsc + eslint(0) + **vitest 224** + build (web/static committed) ·
genesis-workflows **validate_library 11 + pytest 126**. CI green on both tags.

## Not done (honest)

**Live acceptance** — a real Kiro run against a synced app (the multimodal-free grounding turns, the generated
document's quality, and the completion chat opening with it) is **user-driven / headless-undrivable**. The
deterministic surface (validators, routing, loops, gating, finalizer binding, web logic) is fully unit-tested;
the agent turns are not. Run it on the box now serving v0.57.0 with the v0.13.0 workflow installed.

## Follow-ups (optional, not started)

- Auto-flag a Technical Design as **stale** when the Spec/UX change after it exists (currently re-run is manual).
- The **Feature Breakdown** stage (the fourth/last reserved stage) — the next candidate.

## Post-ship fixes — genesis v0.58.0 + genesis-workflows v0.14.0 (2026-09-03)

The first real live Technical Design run (`r-4567cd05bcca`, 12 workstreams) surfaced several issues, all fixed
(CI green — genesis #6727262 / workflows #6727270):

- **Root cause of a malformed doc AND the credit under-count (239 vs ~400):** the single `assemble` agent turn
  was asked to re-emit all ~12 workstream blocks (~195 KB in → ~55 KB out) as one document; it hit
  `turn_timeout` (~428 s), which truncated the HTML (dropped WS7, duplicated WS10–12, multiple `</body>`) and
  meant Kiro never sent final `meteringUsage` (those ~160 credits are honestly `unavailable`, ADR-032).
  **Fix (technical-design-analysis v0.2.0):** split into a bounded **`synthesize`** agent (cross-cutting
  Overview + Complex Designs only — small, reliable) + a **deterministic program `assemble`** that stitches
  the already-`v_design`-validated per-workstream blocks (each exactly once, in build order) + a
  programmatically-consolidated global Open Questions. Stronger `check_design`/`check_doc` + `check_synthesis`.
- **`cleanup` node** on both terminal paths deletes only the tool-output scratch (`_toolcalls/` + saved dumps).
- **Approved-escalation finalize bug:** `runs/worker._snapshot` now reports a terminal `done` for a completed
  graph (no next / no interrupt) — an approved escalation had left the run stranded `running`, so its stage
  never finalized. Recovered the stranded run (regenerated a correct doc via the new deterministic assembler;
  TD stage 3 → in-review with its completion chat).
- **Run-detail graph revamp:** elkjs layered LR + orthogonal edge routing (back-edges pre-reversed so
  validator/gate layering stays correct; custom ELK-routed edges → no line through a node), executed path
  **green** with per-edge **×N** counts (new `GET /runs/{id}/transitions`), minimap removed, idle edges
  recoloured to a visible slate. Verified via headless Chrome (CDP): monotonic pipeline, 0 node overlaps, 0
  edges through a non-endpoint node.
- **Run-detail perf:** the Inspector fetches only the selected node's events (`/events?node=`); the graph
  derives status from `/steps` (no per-SSE-tick fold of the whole event log); SSE streams only while active.
  Fixes the lag/stall on a large agent-heavy run (60 k+ events).
- **Honest partial credit provenance** + `index.html` served `no-cache` (reloads pick up the latest bundle).
