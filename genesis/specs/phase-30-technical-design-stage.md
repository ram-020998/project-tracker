# Phase 30 — Technical Design Stage (Spec + UX → grounded technical design)

> **Status:** 📋 **SPEC DRAFT (2026-09-03).** Awaiting review, then build. · **Author:** Genesis agent
> **Type:** multi-repo — **genesis** (backend + web; no migration — reuses m0015) + **genesis-workflows** (new workflow). genesis-core / kiro-agent-sdk / genesis-appian-parser **unchanged**. · **Depends on:** Phase 29 (the UX Design stage + the generalized per-stage artifact model m0015, the `StageArtifactWorkspace`/`AnnotatablePreviewDialog`/`StageBuilderPage` reuse surface, the `StageFinalizer` run→stage bridge, the `ux_design` chat mode; ADR-057), Phase 28 (the Feature Workspace framework; ADR-056), Phase 20/21 (Features & Specs + the annotatable chat authoring; ADR-042/043/044/045), Phase 25-01 (`LifecycleService`/`domain/`; ADR-050), Phase 16 (`genesis-kb` + the managed-native `appian-dev` MCP; ADR-036/037/038).

---

## 1. Why this phase exists

Phase 28 framed a Feature as a set of **parallel, plug-in stage containers**; Phase 29 made **UX Design**
the first live one after Spec. **This phase makes the third stage live: Technical Design** — and it is the
first stage that **depends on** its predecessors.

In the real SDLC, once a **Spec** (what the feature must do) and a **UX Design** (how the UI must look/behave)
exist, a dev lead writes a **Feature Technical Design**: read both documents, open the **live application**
to see how the relevant functionality is *already* built, and write down — grounded in the real code — the
concrete technical changes (data model, records, process models, interfaces, expression rules, integrations,
complex designs), plus the **questions** the docs left open. Today this is slow, manual, and error-prone.
**We automate the analysis:** produce a grounded, reader-friendly Technical Design the dev lead can trust and
finish by answering the agent's questions — exactly the Spec/UX handoff experience, one stage further down.

**The example authority for the output construction is `/Users/ramaswamy.u/Documents/GSS/technical-design-examples`** (five real GSS/PSC feature TDs) — re-read as the format ground truth in 30-01.

---

## 2. Goal

Make the **Technical Design stage** live: once the **Spec and UX Design artifacts both exist**, the user opens
the stage, provides an optional **comment** (any extra instruction beyond the two docs), and clicks **Start**.
Genesis launches a supervised **`technical-design-analysis`** run (label **"Technical Design Preparation"**)
that:

1. **Ingests + plans** — reads the Spec + the UX Implementation Analysis + the comment, and decomposes the work
   into **functional workstreams**.
2. **Grounds the existing state per workstream** — for each workstream, reads the **live app** (structure/deps
   via **genesis-kb**, actual code via **appian-dev**) and writes a thorough **"what exists today / how it's
   configured"** analysis.
3. **Designs per workstream** — with all three inputs, drafts the technical design for each workstream (data
   model, records, processes, interfaces, expression rules, integrations, complex designs).
4. **Verifies (grounded critic) → presents** — re-checks the draft against the inputs + live env; every change
   cites a real existing object or is clearly marked NEW; blind spots become **Open Questions**. The doc is
   handed to the user in a **completion chat** with the **same annotatable preview** as Spec/UX; the user
   answers the questions inline and the agent revises.

**Success = a dev lead opens the finished Technical Design, reads it top-to-bottom as an easy, coherent story
(workstream by workstream), trusts every "what changes" claim as grounded in the real app, and only has to
answer the genuinely open questions — the read-compare-write loop done for them.**

---

## 3. Constraints & decisions (locked with the user, 2026-09-03)

Firm inputs, not open questions.

1. **Prerequisite gating.** Technical Design can start **only when the Spec and UX Design artifacts both
   exist and are at `in-review` or `completed`** (the artifact is present — full "Mark complete" is NOT
   required). Until then the stage is a first-class but **locked** card. Enforced in the UI (locked card) and
   the backend (409 on start) — defense in depth. *(This introduces stage **prerequisites** — an amendment to
   ADR-056's "no stage gates another"; see §10.)*
2. **Entry = comment + Start (no upload).** Unlike UX (a PDF upload), Technical Design consumes artifacts
   already in the system. The entry surface is a "both artifacts are ready" panel with an **optional comment
   textarea** and a **Start** button → a JSON start (not a multipart upload).
3. **Decomposition by functional workstream.** `plan_sections` splits the work into functional workstreams
   (the feature's scope items), NOT by object type — the reader follows the feature area by area.
4. **Two grounded loops.** A per-workstream **existing-state analysis** loop AND a per-workstream **design
   drafting** loop (research-backed — §6), each turn context-isolated.
5. **Reader-first output.** Optimize the document for a human reading it end-to-end: a clear per-workstream
   flow (objective → what exists today → what changes → complex designs → open questions), data-model tables,
   readable prose. Object-level detail (real object names, columns) is expected and welcome (this is the
   technical stage), but the **organizing principle is readability**, not an object dump. **No Resources/links
   section** — the Spec & UX artifacts already live in the app.
6. **Re-run supported.** Like UX Re-upload: confirm → reset the stage → relaunch with a fresh comment
   (discards the prior TD doc + its completion chat). Available from the stage workspace header + the Overview
   card. No automatic "stale" flagging if Spec/UX change later (manual re-run).
7. **Read-only against Appian (ADR-036/037).** The workflow + completion chat only **read** the live env
   (appian-dev read allowlist + genesis-kb); the design *proposes* object changes but never creates/edits
   them. This stage is analysis, not implementation.
8. **Maximum reuse.** Reuse the Phase-29 generalized surface wholesale (StageStore/m0015,
   `StageArtifactWorkspace`, `AnnotatablePreviewDialog`, `StageBuilderPage`, the annotation→chat bridge, the
   in-progress screen, the escalation-gate + reliability-trio pattern, the `StageFinalizer`). **The only
   changed agent prompt is the completion-chat steering** (`_STEERING_TD`).
9. **Naming:** workflow id **`technical-design-analysis`**; run label **"Technical Design Preparation"**; chat
   mode **`technical_design`**; artifact **`technical-design.html`**; stage key **`design`** / artifactKind
   **`technical_design`** (already reserved in `stages.ts`).
10. **Two UX refinements folded in (30-05):** (A) the **stage card itself is clickable** to open the stage
    (drop the "Open"/"Details" button — all stages); (B) **artifacts are openable/viewable** (click an
    artifact to view it, like the Document Library).

---

## 4. Current state (what we build on) — code-grounded

- **Generalized stage model (Phase 29, m0015).** `kb_feature_stages`/`kb_feature_stage_revisions` +
  `genesis/kb/stages.py::StageStore` are already **per-`(feature, stage)`** (`get_or_create`, `set_html`,
  `set_status`, `set_source`, `set_chat_session`, `add_revision`, `reset_for_reupload`, row_version CAS). A
  `technical_design` stage is `StageStore.get_or_create(feature_id, "technical_design", …)` — **no migration**
  (`current_version` stays 15).
- **Stage framework (`web/src/features/features/`).** `stages.ts` already declares the `design` stage with
  `artifactKind:"technical_design"`, `available:false`. Making it live = flip `available:true` + a real
  `deriveStatus` + a `design` registry entry + a prerequisite gate — **no shell edits** (the ADR-056
  invariant). `stage-registry.tsx`, `StageWorkspacePage.tsx`, `StageBuilderPage.tsx`, `StageArtifactWorkspace`,
  `AnnotatablePreviewDialog` are all stage-generic already.
- **The UX workflow (`genesis-workflows/workflows/ux-design-analysis/graph.py`).** The exact skeleton to
  clone: program nodes render/route/persist; narrow Kiro agent nodes judge; `attach_reliability` (validator +
  retry + escalation) per agent; a bounded `route_verify → synthesize` critic loop with retry-counter reset;
  read-only namespaced `@genesis-kb/…` + `@appian-dev/…` allowlists; fail-fast `resolve_inputs`
  (dev env + KB sync); save-by-reference for bulk tool output.
- **StageFinalizer (`genesis/chat/stage_finalizer.py`).** Bridges a `done` run → its stage (opens the
  completion chat, copies the artifact, sets in-review). Currently **hard-codes** `WORKFLOW_ID =
  "ux-design-analysis"`, `_ARTIFACT = "analysis.html"`, `mode="ux_design"`, and a UX `_seed`. → **generalize**
  to a small workflow→stage **binding registry** so it serves both `ux-design-analysis` and
  `technical-design-analysis`.
- **Chat modes (`genesis/chat/mode_profile.py`).** `ux_design` is a `ChatModeProfile` (read-only KB/live tools
  + sandboxed fs-write + `_STEERING_UX`). A `technical_design` profile is a near-clone with `_STEERING_TD`.
- **Stage API (`genesis/api/features.py`).** The generalized `/features/{id}/stages/{stage}` surface (GET,
  upload, reupload, artifact, milestone, allowed/actions) exists. UX uses a **multipart upload** (ADR-035
  file). Technical Design needs a **JSON start-with-comment** path (+ reupload-with-comment) — an additive
  endpoint alongside the file path.

**Takeaway:** this phase = one new genesis-workflows workflow + a thin genesis backend layer (JSON start,
prerequisite gate, StageFinalizer generalization, `technical_design` chat mode) + a web layer (flip `design`
live + gating + a registry entry + the comment/Start entry-state, reusing the in-progress screen) + the two
UX refinements. **No genesis-core / SDK / migration change** — a materially smaller phase than 29.

---

## 5. The `technical-design-analysis` workflow (working design; finalized in 30-01/30-03)

Deterministic LangGraph (ADR-001). Program nodes plan/loop/persist; narrow Kiro agent nodes (reliability trio
each) do judgment. **Per-workstream decomposition** and a **grounded verification pass** are first-class (§6).

1. **`resolve_inputs`** (program) — resolve feature + `spec_path` + `uxdesign_path` (both required — the
   prerequisite is also enforced here) + the optional `comment`; require a **dev-tagged env** (appian-dev) +
   the app **synced** in the KB. Fail-fast otherwise.
2. **`load_inputs`** (program) — materialize `spec.txt` + `uxdesign.txt` (HTML→text) + `comment.txt` into the
   blackboard as authoritative context.
3. **`plan_sections`** (agent) — read all three → decompose into **functional workstreams**: a JSON array of
   `{workstream, objective, scope_notes}`. Validator: non-empty; each has an objective.
4. **`analyze_section`** (agent, **genesis-kb + appian-dev**, looped per workstream) — for the current
   workstream, ground against the live app: what **already exists** (the relevant records/tables/processes/
   interfaces/rules) and **how it's configured**, using genesis-kb for structure/deps/blast-radius and
   appian-dev to **read the actual code**. Append to `existing_state.json`. Save-by-reference for bulk output.
   Loop node resets its retry counter per workstream (the §7 code-review-loop lesson). Validator: cites real
   object refs; no fabrication.
5. **`draft_section`** (agent, looped per workstream) — with {spec + UX + this workstream's existing-state
   analysis}, draft the workstream's technical design: **DB changes** (with data-model tables), **record
   changes**, **process-model changes**, **UI changes**, **expression-rule changes**, **integrations**, and
   **complex designs** — each change naming a real existing object or marked **NEW**. Append to
   `design_sections.json`. Validator: required change-groups present or explicitly "none"; grounded.
6. **`assemble`** (agent) — a coherence pass that stitches the per-workstream drafts into a single reader-first
   **`technical-design.html`**: `<h1>` feature + "Technical Design"; `<h2>Overview</h2>`; one `<h2>` per
   workstream (Objective → What exists today → What changes [grouped, with tables] → Complex designs → Open
   Questions); then a global `<h2>Complex Designs</h2>` + `<h2>Open Questions</h2>`. It is an **agent** node (reliability trio): dedup, consistent headings/ordering, and the global roll-up — NOT a mechanical concat (locked with the user 2026-09-03).)
7. **`verify`** (agent, **grounded critic**) — re-read the HTML against spec + UX + `existing_state.json` and
   spot-check the live app: flag ungrounded assumptions, object names that don't exist (unless NEW), missing
   change-groups, and confirm the Open Questions genuinely capture blind spots (the agent must **not assume**).
   Emits pass or a targeted fix list → bounded loop back to `draft_section`/`assemble`; on exhaustion →
   **escalation gate**.
8. **`present`** (program) — register `technical-design.html` as the `technical_design` stage artifact (→
   `in-review`); the `StageFinalizer` opens the completion chat.

Deterministic **validators** enforce: a non-empty workstream plan, per-workstream grounding (refs resolve or
explicit NEW), per-workstream change-group coverage, the doc's section skeleton, and the critic verdict shape.

---

## 6. Improvements over a single-pass agent (baked in — research-backed)

- **Per-workstream decomposition (map) + assemble (reduce)** instead of one giant turn — a hierarchical
  Planner→Manager→Worker pipeline measured **95.7% vs 80.9%** exact-match over a monolithic LLM on a
  comparable structured-extraction task; map-reduce fan-out/critic-refiner is the documented topology for
  long, grounded documents. Splitting **both** the existing-state analysis and the design drafting per
  workstream keeps each turn focused and grounded.
- **Context-isolated iterations.** Each per-workstream turn gets only that workstream's inputs + grounding —
  countering the documented "four-step per-unit pattern erodes after the first unit" failure of long
  single-agent runs.
- **A grounded verification (critic) pass**, not self-grading — reflection loops reduce hallucination *only
  when externally grounded* (the "progress mirage"). Our critic re-checks against the inputs + live env.
- **KB-backed grounding + save-by-reference** (Phase 9) for the large process-model / record-type reads the
  existing-state analysis will pull.
- **Reliability trio + escalation gate** on every agent node (ADR-011); bounded revise loop.

---

## 7. The Technical Design chat (completion) & the artifact

Identical experience to Spec/UX — **only the initial steering changes**. A bound **`technical_design`** chat
mode (a `ChatModeProfile`, read-only genesis-kb + appian-dev + sandboxed fs-write) is seeded with the feature
identity + the drafted `technical-design.html`. `_STEERING_TD` tells the agent its job is to **walk the
document's Open Questions one at a time**, and as the user answers, **revise exactly that part and rewrite
`technical-design.html`** — grounding re-checks against the live app on request. The doc is reviewed in the
**same annotatable preview** (`AnnotatablePreviewDialog`); annotations flow back into the chat. When done, the
stage → `completed`. This is the developer-ready technical design the Feature Breakdown stage (later) consumes.

---

## 8. Prerequisite gating (the new framework capability)

Technical Design requires **Spec + UX Design artifacts present** (status `in-review`/`completed`). Realized as:
- **Frontend:** `StageDescriptor` gains optional `requires: StageKey[]` + a pure `deriveAvailability(detail)`;
  `design` requires `["spec","ux"]`. A stage whose prerequisites are unmet renders a **locked** card ("Complete
  Spec & UX Design first") and its workspace shows a blocked state — distinct from the "arriving in a later
  phase" state.
- **Backend:** the JSON start endpoint returns **409** if either prerequisite artifact is missing/too-early
  (defense in depth), and `resolve_inputs` fails fast if `spec_path`/`uxdesign_path` are absent.
This is a bounded, additive amendment to ADR-056 (a stage MAY declare prerequisites); the parallel model
otherwise stands (Breakdown, when it ships, declares its own).

---

## 9. The two UX refinements (30-05)

- **(A) Clickable stage cards.** In `StageCard` (`FeaturePage.tsx`) the card body becomes the primary click
  target (opens the stage workspace); the standalone **Open**/**Details** button is removed for **all** stages.
  Genuinely-distinct secondary actions (Spec **Create**, **View**; UX/TD **Re-run**) remain, layered above the
  click surface with `stopPropagation`, using the accessible card-overlay-link pattern (no real button nested
  inside a link) — jest-axe stays green.
- **(B) Openable artifacts.** In `ArtifactsTab` the rows become clickable and the tab lists **all** generated
  stage artifacts (Spec, UX Design, Technical Design) + linked reference docs. **Generated** artifacts open in
  a **read-only rendered HTML preview** (reuse the `SpecPreviewOverlay`/`AnnotatablePreviewDialog` read-only
  path + the stage artifact endpoint); **Reference** business docs open the **Document Library viewer**
  (`/documents/:id`).

---

## 10. ADR

- **ADR-058 (PROPOSED — this phase): The Technical Design stage — grounded, workstream-decomposed technical
  design.** A Feature's Technical Design stage consumes the finalized **Spec** + **UX Implementation Analysis**
  (+ an optional user comment) and produces a reader-first **Technical Design** HTML artifact via a
  deterministic `technical-design-analysis` workflow: plan → **per-workstream existing-state grounding** (map)
  → **per-workstream design drafting** (map) → assemble (reduce) → **grounded verification** critic (bounded →
  escalate) → present; then a bound **`technical_design` completion chat** finalizes it via the same
  annotatable review. Grounded in the live env (**genesis-kb** = structure/deps, **appian-dev** = actual code),
  **read-only** (ADR-036/037); object-level and code-grounded (the inverse of ADR-057's UX intent-level
  output), organized by functional workstream for readability; every change cites a real object or is marked
  NEW; the agent must not assume — blind spots become Open Questions. Reuses the Phase-29 generalized surface
  (m0015 StageStore, `StageArtifactWorkspace`/`AnnotatablePreviewDialog`/`StageBuilderPage`, the StageFinalizer
  — generalized to a workflow→stage binding registry). No migration; genesis + genesis-workflows only.
- **ADR-056 amendment (this phase): a stage MAY declare prerequisite stages.** Technical Design requires the
  Spec + UX Design artifacts present (`in-review`/`completed`). The parallel, non-gating model otherwise
  stands; prerequisites are declared per-stage (`StageDescriptor.requires`) and enforced UI + backend.

Mirror both in `reference/decision-log.md` + `bible/04`.

---

## 11. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **30-01** | Research & format study | Cited research (hierarchical decomposition / map-reduce / grounded critic for long design docs) + a study of the five example TDs → the locked reader-first output construction; a current-code audit of the reuse surface. **Docs only.** | ⭐ user review |
| **30-02** | ADR & finalize | Lock the workflow node graph + validators + the doc template/sections + the prerequisite-gating model + the entry (comment/Start) + re-run + the StageFinalizer generalization; **draft ADR-058 + the ADR-056 amendment.** | ⭐ user sign-off → build |
| **30-03** | Workflow (genesis-workflows) | The `technical-design-analysis` graph (plan → per-workstream analyze loop → per-workstream draft loop → assemble → grounded verify → present), prompts, validators, workflow.yaml, tests, registry entries (read-only allowlists). | independent review = SHIP |
| **30-04** | Platform build (genesis) | Prerequisite gating (frontend + backend 409); the JSON start-with-comment + re-run endpoints; **generalize `StageFinalizer`** (workflow→stage binding registry); the `technical_design` chat mode + `_STEERING_TD`; web: flip `STAGE_DEFS.design` live + gating + a `design` registry entry + the comment/Start entry-state (reusing the in-progress screen). Gates green; `web/static` committed. | independent review = SHIP |
| **30-05** | UX refinements | (A) clickable stage cards (drop Open, all stages, accessible overlay-link) + (B) openable artifacts (generated → rendered preview; reference → doc viewer; list all stage artifacts). jest-axe green. | independent review = SHIP |
| **30-06** | Code review & hardening | Independent review (grounding correctness, reliability trio, read-only posture, prerequisite gating, reuse cleanliness, a11y/dark-parity/no-hardcoded-hex/contract fixtures); apply SHOULD-FIX; live-acceptance notes. | review clean |
| **30-07** | Release | Coordinated chain **genesis → genesis-workflows**; tags; CI green; docs (bible/tracker/progress/ADR) updated; report. | CI green |

**Suggested order:** 30-01 → 30-02 → 30-03 → 30-04 → 30-05 → 30-06 → 30-07 (linear; each gated on the prior).

---

## 12. Release plan

**Two-repo** (no core/SDK/migration — a simplification vs Phase 29). Order per ADR-019: **genesis** (backend
JSON start + gating + StageFinalizer generalization + `technical_design` mode + web) → **genesis-workflows**
(the `technical-design-analysis` workflow + registry, re-pinning the genesis dev-pin). genesis-core /
kiro-agent-sdk / genesis-appian-parser **unchanged**. Per-sub-phase: build → gates → local commit →
independent review → docs; **no tag/push until 30-07 on the user's go-ahead**. Keep the pin chain consistent
(§7 ResolutionImpossible lesson); a web change → `npm run build` + commit `web/static` (stale-bundle guard).

---

## 13. Scope

**In scope:** the `technical-design-analysis` workflow; prerequisite gating (ADR-056 amendment); the JSON
start-with-comment + re-run; the generalized StageFinalizer; the `technical_design` chat mode; the web
Technical Design stage (live + gating + entry state, reusing the Phase-29 workspace + in-progress screen); the
two UX refinements (clickable cards + openable artifacts).

**Out of scope (future):** the **Feature Breakdown** stage (next); auto-"stale" flagging of a TD when Spec/UX
change; any Appian **write/deploy**; multi-user/assignment/roles; JIRA/story-map integration; a Resources/links
section in the doc.

---

## 14. Open questions

None blocking — all resolved with the user (2026-09-03): **`assemble` is an agent** coherence pass (not a program concat); the start **comment is optional** (empty accepted).
