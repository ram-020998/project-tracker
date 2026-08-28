# Phase 29 — UX Design Stage (Mockup → grounded implementation analysis)

> **Status:** 📋 **DRAFT — spec only (umbrella + 29-01..29-06); awaiting review, then start 29-01 (research).** · **Author:** Genesis agent · **Date:** 2026-08-28
> **Type:** multi-repo — genesis-core (additive) + genesis (backend + web + migration) + genesis-workflows (new workflow) · **Depends on:** Phase 28 (the Feature Workspace framework; ADR-056), Phase 20/21 (Features & Specs + the `feature_spec` chat authoring; ADR-042/043/044/045), Phase 25-01 (`LifecycleService`/`domain/`; ADR-050), Phase 16 (the internal `genesis-kb` MCP + the managed-native `appian-dev` MCP; ADR-036/037/038), Phase 15 (run-launch file attachments; ADR-035), Phase 27 (design language; ADR-055).

---

## 1. Why this phase exists

Phase 28 shipped the Feature Workspace framework: a Feature is a set of **parallel, plug-in stage
containers** (Spec live; UX Design / Technical Design / Feature Breakdown as first-class "arriving in a later
phase" plug-points). **This phase makes the first of those plug-points live: UX Design.**

In the real SDLC, after a Spec exists a UX designer works with the PO to produce **mockups** and hands the
developers a **PDF/slide deck of screens with comments** explaining what changed and what is new. A developer
then does slow, manual work: read the deck screen-by-screen, cross-reference it against the spec, open the
**live application** to see what already exists, and write up what actually needs to change (and ask the
questions the deck left open). **We are NOT automating mockup creation** (that is a later roadmap item). We
are automating the **developer's analysis of an uploaded mockup** so the manual verify-and-question step
shrinks dramatically.

---

## 2. Goal

Make the **UX Design stage** of a Feature live: the user uploads a **mockup PDF**, and Genesis produces a
single, high-quality, **grounded "UX Implementation Analysis"** — a per-screen document that reconciles
**(a) what the mockup shows**, **(b) what the Spec says**, and **(c) what exists in the live Appian
environment**, and states **what must change / be added at the interface (intent) level**, plus a
**blind-spot / ripple-effect analysis** and **open questions**. A bound **UX Design chat** then walks the
user through those open questions, editing the document live until it is a complete, developer-ready
implementation guide, and the stage is marked complete.

**Success = a developer opens the finished document and trusts it as "the analysis I would have written by
hand," with the manual read-compare-question loop largely done for them.**

---

## 3. Constraints & decisions (locked with the user, 2026-08-28)

These are firm inputs, not open questions.

1. **PDF-only in v1.** Rendering uses **PyMuPDF (fitz)** — a pure wheel, zero system dependencies. Native
   **PPTX is deferred** (no pure-Python renderer; it would add a LibreOffice system prerequisite). The UX
   already hands developers a PDF, so PDF is the common denominator.
2. **Re-upload replaces + re-runs.** A new upload on the stage **deletes the prior page images + supersedes
   the prior analysis artifact** and re-runs the workflow from scratch (one active analysis per feature).
3. **Grounding split: genesis-kb = structure only; appian-dev MCP = the actual code.** Structural
   understanding / dependency graph / blast-radius come from the internal **`genesis-kb`** KB (already
   synced, code-free). The **actual SAIL/interface code is read via the `appian-dev` MCP** — the analysis
   relies **heavily** on appian-dev for real code, using genesis-kb to know *what exists and what depends on
   what*.
4. **Intent-level output.** The document stays at **screen / interaction intent + an explicit list of
   affected objects** — NOT object-level "change interface X's SAIL like this." Object-level design is the
   later **Technical Design** stage; UX Design must not overlap it.
5. **Artifact = "UX Implementation Analysis"** (the locked name), authored as **HTML** in the agent's
   per-session sandbox and reviewed in the **same annotatable Lavish iframe** as the Spec (reuse Phase
   20/21). HTML is authoritative; Markdown is a derived export.
6. **Generalize the per-stage artifact model now (`m0015`).** Realize the ADR-056-reserved generalized
   per-`(feature, stage)` artifact + lifecycle model this phase (Technical Design & Breakdown will reuse it),
   rather than a UX-only store.
7. **Handoff:** uploading on the UX stage **launches a supervised `ux-design-analysis` run** (visible in
   Runs, with the verification escalation gate); on completion the stage shows the **draft** analysis + opens
   the **completion chat**. The UX stage reuses the Spec lifecycle states
   (`draft → in-progress → in-review → completed`).
8. **Read-only against Appian (ADR-036/037).** The workflow + chat only **read** the live environment
   (appian-dev read allowlist); no writes/deploys. This stage is analysis, not implementation.

---

## 4. Current state (what we build on) — code-grounded

- **Stage framework (Phase 28, `web/src/features/features/`):** `stages.ts` (`STAGE_DEFS` — `ux` is
  `available:false`, `deriveStatus:()=>"not-available"`), `stage-registry.tsx` (data-only plug-in point
  `key → {Workspace, CardActions}`), `StageWorkspacePage.tsx` (routed `…/features/:featureId/:stage`,
  registry-dispatched), `FeaturePage.tsx` (Overview + peer stage cards). **Making UX live = flip the
  `STAGE_DEFS.ux` row to `available:true` + a real `deriveStatus`, add a `ux` registry entry
  ({Workspace, CardActions}), and build the inner UX workspace — no shell edits** (the framework's invariant).
- **Spec authoring (Phase 20/21):** the `feature_spec` chat mode (`chat/mode_profile.py`) authors `spec.html`
  in a per-session `fs_write_root` sandbox (cwd=sandbox; `fs_read`/`fs_write` trusted; everything else
  denied), reviewed in a sandboxed Lavish `<iframe>` with a postMessage annotation→chat bridge; `FeatureStore`
  persists the spec + revisions (m0010) with row_version CAS (m0014). **This is the template for the UX
  completion chat + artifact.**
- **Closest workflow analog (`genesis-workflows/workflows/design-doc/graph.py`):** program nodes do I/O +
  routing, narrow Kiro agent nodes do judgment, each agent wrapped by the reliability trio
  (`attach_reliability`: validator + retry + escalation gate), a conditional **open-questions** node, a
  **mockup-file** input (ADR-035), and **save-by-reference** for bulk tool output. The `ux-design-analysis`
  workflow is modeled on this.
- **Doc parsing (`genesis/kb/doc_parsing.py`):** **text-only** (pypdf extracts text; NO page rendering; NO
  PPTX). → we add a **new render step** (PyMuPDF PDF→PNG per page into the blackboard).
- **Multimodal:** the **SDK supports image prompt parts** (`kiro_agent_sdk/client.py::_build_content`, gated
  on `promptCapabilities.image`) and the **chat** path uses it (`ChatManager.stream_turn(text, images)`).
  **But `genesis-core`'s `kiro_node` has no image path** → we add one (additive) so a **workflow** agent node
  can be handed the rendered page images.
- **Domain (`genesis/domain/`, ADR-050):** `ArtifactKind` already includes `UX_DESIGN`; `LifecycleService` is
  generic. → a `ux_design` per-`(feature, stage)` machine is a composition + `m0015` persistence, not net-new
  domain design.

**Takeaway:** the phase = one additive genesis-core capability (agent-node images) + a genesis backend layer
(PDF render + `m0015` generalized stage artifact model + a `ux_design` lifecycle machine + a `ux_design` chat
mode + API) + a genesis web layer (the UX stage workspace, plugging into the Phase-28 framework) + one new
genesis-workflows workflow.

---

## 5. The `ux-design-analysis` workflow (working design; finalized in 29-01/29-03)

A deterministic LangGraph workflow (ADR-001). Program nodes render/route/persist; narrow Kiro agent nodes
(reliability trio each) do judgment. **Per-screen decomposition** and a **grounded verification pass** are
first-class (see §6).

1. **`resolve_inputs`** (program) — validate the uploaded mockup is a PDF (ADR-035 file input); resolve the
   feature + its Spec identity; require a **dev-tagged env** (for appian-dev) + the app **synced** in the KB
   (fail-fast otherwise).
2. **`render_pages`** (program) — PyMuPDF renders each PDF page → `pages/NNN.png` in the blackboard (chosen
   DPI). Validator: ≥1 non-empty page image.
3. **`load_spec`** (program) — pull the feature's Spec (HTML→text) into the blackboard as authoritative
   context.
4. **`screen_inventory`** (agent, **multimodal**) — per page image, extract a structured screen record:
   screen name/purpose, key components + states, and the **UX's own change-comments** on that slide.
   Save-by-reference. Validator: one record per rendered page, required fields present.
5. **`spec_reconcile`** (agent) — map each screen/change to the relevant Spec section(s); classify
   agree / conflict / gap.
6. **`live_grounding`** (agent, **genesis-kb + appian-dev**) — for each identified change: use **genesis-kb**
   for *what exists / dependency graph / blast-radius*, and **appian-dev** to **read the actual code** of the
   specific affected interfaces; decide **add vs modify**; capture the affected object refs. Save-by-reference.
   Validator: each change cites a real object ref (from KB/appian-dev) or is explicitly marked "new".
7. **`synthesize`** (agent) — write the consolidated **HTML** "UX Implementation Analysis": per screen
   (mockup intent · spec basis · live delta · what to change at intent level) + a global **Blind spots /
   ripple effects** section + **Open Questions**.
8. **`verify`** (agent, **grounded critic**) — re-read the HTML **against the images + spec + live-grounding
   notes** (not self-graded): every claimed change grounded (no hallucinated objects), every screen covered,
   blind-spot analysis present, open questions genuinely unresolved-by-research. Emits pass or a targeted fix
   list → bounded loop back to `synthesize`; on exhaustion → **escalation gate**.
9. **`present`** (program) — register the HTML as the feature's **UX Design** stage artifact
   (status → `in-review`); hand off to the completion chat.

Deterministic **validators** enforce: render count, per-screen coverage (one block per rendered screen),
grounding (object refs resolve or explicit "new"), open-questions discipline, and the doc's section skeleton.

---

## 6. Improvements over a single-pass agent (baked in — research-backed)

- **Per-screen decomposition** rather than one giant turn: multimodal models are documented to be unreliable
  at holistic UI reasoning but much stronger at fine-grained per-screen extraction; also gives per-screen
  retry/validation and scales to large decks.
- **A grounded verification (critic) pass**: reflection/critic loops reduce hallucination *only when
  externally grounded* — an ungrounded self-critic exhibits a "progress mirage." Our critic re-checks against
  the images + spec + live-grounding notes, not its own prior output.
- **KB-backed blind-spot analysis**: turn "ripple effects the UX missed" from a guess into a real
  **genesis-kb dependency/impact query** on each affected object — surfacing affected-but-unmentioned
  interfaces.
- **Reliability trio + escalation gate** on every agent node (ADR-011); save-by-reference for bulk tool
  output (Phase 9).

---

## 7. The UX Design chat (completion) & the artifact

- **Artifact:** **"UX Implementation Analysis"** — HTML authored by the agent in its per-session sandbox,
  persisted as the feature's `ux_design` stage artifact (m0015), reviewed in the annotatable Lavish iframe
  (reuse Phase 20/21). Markdown export derived.
- **Completion chat:** a bound **`ux_design`** chat mode (a `ChatModeProfile`) seeded with the feature + the
  draft analysis + the mockup context. The agent **walks the document's Open Questions**, and as the user
  answers, **edits the HTML live** (filling in resolved sections). The user can also ask for **extra checks**
  (re-look at a screen, re-query the live env) — the chat has **genesis-kb + appian-dev read tools** for
  on-demand grounding. When done, the stage → `completed`; the finished document is the developer-ready UX
  implementation guide the downstream stages consume.

---

## 8. Backend: the `m0015` generalized per-stage artifact model

Realize the ADR-056-reserved generalized model: a per-`(feature, stage)` **stage** row (lifecycle state +
current-artifact pointer + revisions) so Spec, UX Design, Technical Design, and Breakdown all persist
uniformly. Exact shape (a new `kb_feature_stages`/`kb_feature_stage_artifacts` pair vs. generalizing
`kb_feature_specs`) is a **29-03/29-04 decision**, kept **additive** (ADR-030/019; `CORE_MAJOR` unchanged;
bump `current_version` tests). Bulk artifact HTML on disk (ADR-010/018); pointers + hash + status in
`genesis.db`. A `ux_design` `LifecycleService` machine (ADR-050) governs the stage; transitions audited in
m0013.

---

## 9. Scope

**In scope:**
- genesis-core: additive **image support in `kiro_node`** (thread blackboard image files → `client.prompt(images=…)`, gated on `promptCapabilities.image`).
- genesis: **PyMuPDF** PDF→PNG render utility (pinned dep); **`m0015`** generalized per-stage artifact model +
  a `ux_design` `LifecycleService` machine; a **`ux_design` chat mode**; API (upload + launch run + artifact
  read + re-upload/replace + completion actions); **web UX stage** (flip `STAGE_DEFS.ux`, add the registry
  entry, build the inner workspace: upload → supervised run → draft doc + completion chat).
- genesis-workflows: the **`ux-design-analysis`** workflow + registry entries (read-only `appian-dev` +
  `genesis-kb` allowlists per node).

**Out of scope (future phases):**
- **Automating mockup creation** (roadmap, not now).
- **Native PPTX** ingestion (PDF-only v1).
- **Object-level** UX→SAIL design (that is the Technical Design stage).
- Any Appian **write/deploy**; multi-user/assignment/roles.

---

## 10. ADR

- **ADR-057 (PROPOSED — this phase): The UX Design stage — grounded mockup→implementation analysis.** A
  Feature's UX Design stage ingests an uploaded **PDF** mockup and produces a **"UX Implementation Analysis"**
  HTML artifact via a deterministic `ux-design-analysis` workflow (program render + narrow **multimodal** Kiro
  agent nodes under the reliability trio, with a **grounded verification** pass), then a bound **`ux_design`
  completion chat** finalizes it. The analysis is **grounded** in the mockup images + the feature's **Spec** +
  the **live environment** (structure via **genesis-kb**, actual code via **appian-dev**), reconciled per
  screen at **intent level** (not object-level design). Enablers: additive **image support in `kiro_node`**;
  **PyMuPDF** for PDF→PNG (PDF-only; PPTX deferred); the ADR-056-reserved **`m0015`** generalized
  per-`(feature, stage)` artifact model + a `ux_design` lifecycle machine; the UX stage becomes the **first
  `available:true` stage after Spec** (plugs into the ADR-056 framework, no shell edits). Read-only against
  Appian (ADR-036/037). Refines ADR-056; reuses ADR-011/031/035/042/043/045/050. **Drafted 29-01, finalized
  29-03, Accepted at 29-04/29-06.** Mirror in `reference/decision-log.md` + `bible/04`.

---

## 11. Sub-phase ledger

| # | Sub-phase | Deliverable | Gate |
|---|---|---|---|
| **29-01** | Research & analysis | Cited research (multimodal UI-vs-implementation analysis; generator/critic grounding; PDF render) + a current-code audit + the finalized workflow shape, `m0015` model, and chat model + the **ADR-057 draft**. **Docs only.** | ⭐ user review |
| **29-02** | Wireframes & hi-fi mockups | Coded mockups at **`/dev/mockups`** of the UX stage container states — empty/upload, running, draft-with-open-questions, and the completion chat + annotatable doc (light-first, Phase-27 language). **Dev-only.** | ⭐ user review |
| **29-03** | Brainstorm & finalize | Iterate with the user; lock the workflow node graph + validators + the doc template/sections + the `m0015` schema + the chat completion UX + lifecycle wiring; **lock ADR-057.** | ⭐ user sign-off → build |
| **29-04** | Build (multi-repo) | genesis-core image node → genesis (render + m0015 + `ux_design` machine + chat mode + API + web UX stage) → genesis-workflows workflow. Gates green; **ADR-057 Accepted**; `web/static` committed. | independent review = SHIP |
| **29-05** | Code review & hardening | Independent review (grounding correctness, reliability trio, read-only posture, the multimodal path, a11y/dark-parity/no-hardcoded-hex/contract fixtures); apply SHOULD-FIX; live-acceptance notes. | review clean |
| **29-06** | Release | Coordinated chain core → genesis → genesis-workflows; tags; CI green; docs (bible/tracker/progress/ADR) updated; report. | CI green |

**Suggested order:** 29-01 → 29-02 → 29-03 → 29-04 → 29-05 → 29-06 (linear; each gated on the prior).

---

## 12. Release plan

**Multi-repo** (unlike Phase 28's frontend-only). Release order per ADR-019: **genesis-core** (additive
`kiro_node` images; `CORE_MAJOR` unchanged) → **genesis** (render + m0015 + ux stage + chat + api + web;
`current_version` → 15) → **genesis-workflows** (the `ux-design-analysis` workflow + registry). kiro-agent-sdk
(image parts already in v0.7.0) + genesis-appian-parser expected **unchanged**. Per-sub-phase: build → gates →
local commit → independent review → docs; **no tag/push until 29-06 on the user's go-ahead**. Keep the whole
pin-chain consistent (§7 ResolutionImpossible lesson).

---

## 13. Open questions — RESOLVED (user "your call", 2026-08-28)

1. **Render DPI / page cap** — ✅ DPI **~150**, **~40-page** cap.
2. **`m0015` shape** — ✅ option **(A)**: migrate the existing Spec onto the generalized `kb_feature_stages` model.
3. **Completion criteria** — ✅ explicit **"Mark complete"** (mirrors Spec).

<!-- original (now resolved): -->
## 13b. (original) Non-blocking open questions (can resolve during 29-01/29-03)

1. **Render DPI / page cap** — a sensible default DPI and a max-page guard for very large decks (a 29-01
   decision, tuned against a real deck).
2. **`m0015` shape** — a new `kb_feature_stages`(+`_artifacts`) pair vs. generalizing `kb_feature_specs`
   (29-03 decision; both additive).
3. **Completion criteria** — is "all open questions answered" the gate to `completed`, or an explicit user
   "mark complete" (like the Spec)? (Candidate: explicit, mirroring Spec.)
