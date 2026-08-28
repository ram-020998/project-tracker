# Progress — Phase 29: UX Design Stage (Mockup → grounded implementation analysis)

> As-built record for Phase 29. **Specs:** `specs/phase-29-ux-design-stage.md` (umbrella) +
> `phase-29-ux-design-stage/29-01..29-06`. **ADR-057** (Accepted) — the grounded UX Design stage (refines
> ADR-056). Multi-repo: genesis-core (additive `kiro_node` images) + genesis (PDF render + `m0015` per-stage
> artifact model + `ux_design` lifecycle machine + `ux_design` chat mode + API + web UX stage) +
> genesis-workflows (the `ux-design-analysis` workflow). PDF-only v1; read-only against Appian.

## Status

✅ **PHASE 29 COMPLETE — RELEASED (2026-08-28).** genesis v0.55.0 + genesis-workflows v0.12.0 + genesis-core v0.9.6 + kiro-agent-sdk v0.7.1, CI green (core #6680648 / genesis #6680663 / workflows #6680673; sdk v0.7.1 transitively). The UX Design stage is end-to-end: upload PDF → `ux-design-analysis` run → StageFinalizer opens the `ux_design` completion chat + sets the stage in-review → annotatable review + Mark complete. ADR-057 Accepted; Spec fully preserved (D0); Decision A data-safe.

## Sub-phase ledger

| # | Sub-phase | Status |
|---|---|---|
| 29-01 | Research & analysis | ✅ **DELIVERED — FOR REVIEW** (`29-01-findings.md`) |
| 29-02 | Wireframes & hi-fi mockups (`/dev/ux-design`) | ✅ **DELIVERED — FOR REVIEW** (genesis LOCAL `3ffb3ac`) |
| 29-03 | Brainstorm & finalize (+ lock ADR-057) | ✅ **FINAL — FOR BUILD SIGN-OFF** (`29-03-final-design.md`) |
| 29-04 | Build (sdk → core → genesis → genesis-workflows) | ✅ **BUILD COMPLETE** (LOCAL; 29-06 releases) |
| 29-05 | Code review & hardening | ✅ **COMPLETE — SHIP** (M1 + S1/S2/S3/S5 fixed) |
| 29-06 | Release (sdk → core → genesis → genesis-workflows) | ✅ **RELEASED** (CI green) |

## Decisions locked with the user (2026-08-28)

- **PDF-only v1** — PyMuPDF (fitz) render, zero system deps; **PPTX deferred** (no pure-Python renderer).
- **Re-upload replaces + re-runs** — deletes prior page images + supersedes the artifact; one active analysis
  per feature.
- **Grounding split** — **genesis-kb = structure/dependency/impact only**; **appian-dev MCP = the actual
  code** (heavy reliance).
- **Intent-level output** — screen/interaction intent + affected-objects list; NOT object-level SAIL design
  (that's the later Technical Design stage).
- **Artifact = "UX Implementation Analysis"** — HTML in the agent sandbox, reviewed in the annotatable Lavish
  iframe (reuse Phase 20/21).
- **Generalize the per-stage artifact model now (`m0015`)** — per-`(feature, stage)`; not UX-only.
- **Handoff** — upload → supervised `ux-design-analysis` run (verification escalation gate) → draft doc +
  completion chat; UX stage reuses the Spec lifecycle states (draft→in-progress→in-review→completed).
- **Read-only against Appian** (ADR-036/037) — analysis only; no write/deploy.
- **(resolved 2026-08-28, "your call")** render DPI ~150 / ~40-page cap; `m0015` = option A (migrate Spec onto `kb_feature_stages`); completion = explicit "Mark complete".

## Improvements baked in (research-backed)

- Per-screen decomposition (multimodal models are weak at holistic UI reasoning, stronger per-screen).
- A **grounded** verification/critic pass (re-check vs images + spec + live notes — avoids the
  "progress mirage" of self-graded critics), bounded → escalation gate.
- KB-backed blind-spot / ripple-effect analysis (dependency/impact query on affected objects).

## As-built (filled in as sub-phases complete)

_(nothing built yet — spec drafting only)_

## 29-01 — Research & analysis (delivered 2026-08-28)

`specs/phase-29-ux-design-stage/29-01-findings.md`. Cited external research — multimodal UI-vs-implementation
analysis **failure modes** (models reproduce layout but miss data-binding/interaction/structure; weak
fine-grained UI reasoning → **per-screen decomposition + grounding**, not one-shot vision), **generator→
grounded-critic** loops (reflection reduces hallucination only when externally grounded — the "progress
mirage" of self-graded critics → a **grounded** `verify` pass), and **PyMuPDF** as the pure-wheel PDF→PNG
renderer (pdf2image needs poppler; PPTX has no pure-Python renderer → PDF-only v1). Current-code audit
confirmed the exact seams: the Phase-28 stage plug-in point (STAGE_DEFS `ux` row + registry, no shell edits);
`feature_spec` `ChatModeProfile` as the template + `chat/mcp.py` already wiring genesis-kb + appian-dev;
`FeatureStore`/m0010 as the shape `m0015` generalizes; `ArtifactKind.UX_DESIGN` + `SPEC_TRANSITIONS` already
present (the `ux_design` machine reuses them); the two gaps — `kiro_node` has no image path (SDK does) +
`doc_parsing` is text-only. **Finalized design:** the 9-node `ux-design-analysis` graph + validators; the
grounding contract (genesis-kb structure/impact via get_dependents/transitive/path/hub; appian-dev actual
code; per-change object-ref citation); the intent-level HTML doc template; the `m0015` `kb_feature_stages`
model (recommend migrating Spec onto it); the `ux_design` lifecycle machine (reuse SPEC_TRANSITIONS) + chat
profile; the additive `kiro_node` image seam; DPI ~150 / ~40-page cap. **3 open questions** (DPI/cap; spec
migration A/B; completion criteria) — none blocking. **No code changed.** NEXT = 29-02 mockups on review.

## 29-02 — Wireframes & hi-fi mockup (delivered 2026-08-28)

Coded hi-fi mockup at **`/dev/ux-design`** (`web/src/dev/mockups/UxDesignStageMockups.tsx`, dev-only) +
`29-02-wireframes.md`. Committed **LOCAL** on genesis master (`3ffb3ac`, **no tag/push**). A State control
cycles the UX Design stage states — empty/upload (PDF dropzone + "what happens next" pipeline), running
(supervised run progress), review (the "UX Implementation Analysis" annotatable doc pane — per-screen blocks +
blind-spot/ripple callout + open questions — beside the completion chat), completed (finalized doc + artifact
strip), and the stage card in all 4 statuses. Full-bleed + Expand→immersive; light/dark. Added
Upload/Image/Sparkles/HelpCircle/FileSearch to the curated `shared/ui/icons.ts` re-export. **Tokens/primitives
only — no hardcoded brand hex.** Gates: tsc clean, eslint 0 errors (18 pre-existing warnings elsewhere),
**vitest 210**, build OK; `web/static` rebuilt+committed. Dev-only mockup carries no dedicated vitest test
(Phase-28 `FeatureWorkspaceMockups` precedent). **NEXT = user review of `/dev/ux-design` → 29-03 finalize +
lock ADR-057.**

## 29-03 — Final design (locked 2026-08-28)

`specs/phase-29-ux-design-stage/29-03-final-design.md` — D0–D13 locked. **D0 (user directive): reuse the
Spec-page components, generalized** — `SpecWorkspace`→`StageArtifactWorkspace`, `PreviewDialog`→
`AnnotatablePreviewDialog`, `SpecBuilderPage`→`StageBuilderPage`, reused `ChatThread`, stage-scoped hooks; no
new look-alikes; Spec keeps working (regressions green). Also locked: the 9-node `ux-design-analysis` graph +
validators + grounded `verify` critic; genesis-kb(structure)/appian-dev(code) grounding + citation; the
intent-level HTML doc template; **m0015 = option A** (`kb_feature_stages`, migrate Spec, `current_version`→15);
the `ux_design` lifecycle (reuse `SPEC_TRANSITIONS`) + chat profile; explicit **Mark complete**; the additive
`kiro_node` image seam; DPI 150 / ≤40 pages (PyMuPDF); the generalized stage API; handoff + re-upload. ADR-057
finalized (Proposed until 29-04). **No code changed.** NEXT = user sign-off → 29-04 build.

## 29-04 — Build (IN PROGRESS, 2026-08-28) — LOCAL commits, UNPUSHED, no tags

**Decision A (locked 2026-08-28):** fully repoint Spec onto the generalized `kb_feature_stages`/StageStore
model + retire `kb_feature_specs` from the code paths. **Safe for existing users** — m0015 already copies
their specs (+revisions) at the **offline** `genesis db upgrade` (absolute `html_path` + `chat_session_id`
preserved); the migration does **not** drop `kb_feature_specs` (dead table kept for rollback safety, retired
later). Single-user/local + offline `db upgrade` → the only real risk is a Spec-path code regression, contained
by keeping the Spec test suite green + the 29-05 review + shipping the whole chain together at 29-06.

**DONE (LOCAL commits — do NOT re-do; UNPUSHED; 29-06 releases the chain incl. kiro-agent-sdk):**
- Step 1 — kiro-agent-sdk `dd21b22` (images kwarg on query/collect/collect_streaming); genesis-core `c0472c4`
  (`kiro_node(image_docs=…)` → base64 ACP image parts; AgentProvider images). sdk 93, core 83.
- Step 2 — genesis `45aaa77` — `genesis/kb/pdf_render.py` (PyMuPDF==1.28.2 pinned; DPI 150 / ≤40 pages) +4 tests.
- Step 3 — genesis `beb58a1` — m0015 `kb_feature_stages`(+`_revisions`) + copies Spec rows (option A) +
  `genesis/kb/stages.py` StageStore; `current_version` → 15; bumped `current_version==N` asserts. genesis 645.
- Step 4a — genesis `5b02987` — `build_stage_lifecycle`(+`_service`) (reuse SPEC_TRANSITIONS, `EntityKind.STAGE`);
  `ux_design` `ChatModeProfile` + `_STEERING_UX`; `ctx.extras['pdf_render']`. genesis pytest **647**, ruff clean.

**REMAINING AT THE 29-04 CHECKPOINT (all subsequently completed — see the 29-05 + 29-06 sections below):**
- **4b** generalized stage API in `api/features.py` + **repoint Spec onto StageStore** (D12; feature detail
  returns `stages`; add `feature_stage_artifacts_dir` to settings; keep Spec tests green).
- **5** web: generalize `SpecWorkspace`→`StageArtifactWorkspace`, `PreviewDialog`→`AnnotatablePreviewDialog`,
  `SpecBuilderPage`→`StageBuilderPage`, stage-scoped hooks; flip `STAGE_DEFS.ux` + registry entry; Spec keeps working.
- **6** genesis-workflows `ux-design-analysis` workflow (9-node D1 + validators + grounded verify critic).
- **7** ADR-057 → Accepted; bible/03; then 29-05 review + 29-06 coordinated release.

### 29-04 — Build COMPLETE (2026-08-28) — LOCAL commits, UNPUSHED, no tags (29-06 releases the chain)

Full ledger (all LOCAL): kiro-agent-sdk `dd21b22` (images kwarg) · genesis-core `c0472c4` (kiro_node
image_docs) · genesis `45aaa77` (PyMuPDF render) → `beb58a1` (m0015 + StageStore) → `5b02987` (stage
lifecycle + `ux_design` chat profile + `pdf_render` inject) → `64b9165` (feature_stage_artifacts_dir) →
`6afcac6` (Spec repoint onto StageStore, **Decision A** — audit kind spec→stage; list_features/counts join
kb_feature_stages) → `af7703d` (generalized `/features/{id}/stages/{stage}/…` API + feature detail returns
`stages` + UX upload→run-launch, friendly 409 if uninstalled) → `238c43e` (web generalization:
StageArtifactWorkspace / AnnotatablePreviewDialog / StageBuilderPage + stage-scoped hooks + UxCardActions +
STAGE_DEFS.ux live; SpecBuilderPage deleted; web/static rebuilt) → `885acf7` (worker resolves the internal
managed `genesis-kb`) → `d365353` (upload passes spec_path) → `3fd6fab` (**StageFinalizer** — run→stage
bridge) · genesis-workflows `1053ff2` (the `ux-design-analysis` 9-node workflow + D2 validators + grounded
verify bounded-loop + registry.json + managed genesis-kb in mcp-registry + 14 tests).

**Gates (all green):** genesis pytest **653** + ruff · web tsc + eslint 0 + **vitest 211** + build ·
genesis-workflows **validate_library PASSED (10 workflows)** + pytest **107** · sdk 93 · genesis-core 83.

**Decision A (safe for existing users):** m0015 copies existing specs (+revisions) at the offline `genesis
db upgrade`; absolute `html_path` + `chat_session_id` preserved; `kb_feature_specs` NOT dropped (dead table,
rollback). Spec regressions all green.

**Flagged deviation:** kiro-agent-sdk changed (was "unchanged" in the plan) — the additive `images` kwarg;
so 29-06 releases the whole chain **sdk → core → genesis → genesis-workflows** (keep the pin chain consistent).

**NEXT:** 29-05 independent code review & hardening → 29-06 coordinated release. (bible/03 codebase-map +
ADR-057→Accepted updated in this pass.)

### 29-05 — Code review & hardening COMPLETE — SHIP (2026-08-28)

Independent read-only auditor (tao-architect) reviewed all four repos vs the 29-03 locked design + ADRs +
§7 lessons → initial **NO-SHIP** on one re-upload defect. Resolved: **M1** (genesis `a76289c` —
`reset_for_reupload` now clears chat_session_id/run_id/source_doc_path so re-upload truly replaces + a
StageFinalizer re-run finalizes; +regression test) and **S1/S2/S3/S5** (genesis-workflows `123b76d` —
stronger D2 validators: reconcile spec_ref rule, all screen fields, blast_radius required; resolve_inputs
dev-env/synced-app fail-fast). S4 was a false finding (reconcile() IS called at startup). N1/N3 doc-accuracy
applied; N2/N4/N5/N6/N7 accepted-deferred (non-blocking). Re-review = **SHIP**. Gates: genesis pytest 654 +
ruff · genesis-workflows validate_library (10) + ux tests 14 · web unchanged. Full findings + resolution log
in `29-05-code-review-and-hardening.md`. NEXT = 29-06 coordinated release.

### 29-06 — Release COMPLETE (2026-08-28) — CI green

Coordinated four-repo release (ADR-019 order; the sdk is in the chain per the flagged additive `images`
deviation): **kiro-agent-sdk v0.7.1** (`b68438c`) → **genesis-core v0.9.6** (`761fda8`; re-pin sdk) →
**genesis v0.55.0** (`0d667a2`; re-pin core+sdk, bump pyproject/FastAPI/version.ts, web/static rebuilt) →
**genesis-workflows v0.12.0** (`9472b66`; re-pin core v0.9.6 + genesis v0.55.0). CI green on all: genesis-core
master #6680647 + tag #6680648; genesis master #6680662 + tag #6680663 (incl. clean-install → the full pinned
chain resolves, no ResolutionImpossible); genesis-workflows master #6680672 + tag #6680673 (incl.
library-validate). kiro-agent-sdk has no CI — validated transitively by the green genesis clean-install.
`current_version` → 15 (m0015). ADR-057 Accepted. Docs updated (bible/00 banner + bible/01 §2 tag table/
migrations/counts + bible/03 codebase-map + bible/04 + bible/08 §9 SHIPPED + AGENT_ONBOARDING + decision-log)
+ this progress + tracker. **PHASE 29 COMPLETE — no active phase.** Live acceptance (a real mockup PDF on a
feature's UX Design stage with Kiro signed in + a dev-tagged env + the app synced) is user-driven /
headless-undrivable — the manual check is in the 29-06 spec Notes.

### Post-release live fixes — genesis v0.55.1 (2026-08-28, CI green #6681514)

Exercising `/features/{id}/ux` on the running app surfaced two defects, both fixed + released as v0.55.1
(genesis-only; pins unchanged): (1) **web** `StageBuilderPage` gated the workspace on mere row presence →
a bare draft ux row (no bound chat) showed a dead "no chat session" pane; now gated on a bound completion
chat (Upload / "analysis in progress" until finalized) — `3339141`. (2) **backend** the ADR-035 upload
allowlist omitted `.pdf` → the mockup couldn't be provisioned; added `.pdf` + cap 10→25 MB — `f92562b`.
Release `57011c4` / tag v0.55.1; CI green (master #6681513 + tag #6681514). +3 regression tests.

### First live run + StageFinalizer hardening — genesis v0.55.2 (2026-08-28, CI green #6681788)

The first real end-to-end `ux-design-analysis` run (`r-72c0d9e55c6e`, feature 3) succeeded fully: 14-page
mockup PDF → all 15 nodes green → grounded `verify` **ok** (`verify_rounds=1` — the critic requested one
revision that passed, proving it isn't a rubber stamp) → `analysis.html`. But the run's **stage was left
stranded** (in-progress, no completion chat) — the app-process `StageFinalizer`'s live `run.final` was
missed (orphaned worker / app bounce) and `reconcile()` only runs at startup. Fixed in **v0.55.2** (commit
`0217b4e`, release `cd11281`, CI green master #6681787 + tag #6681788): the finalizer now **logs** finalize
failures (was `except: pass`) and adds **`reconcile_stage()`** in-flight recovery wired into the
feature/stage GET, so opening the stage self-heals it without a restart. +regression test
(`test_stage_get_self_heals_a_stranded_run`); genesis pytest 656. The stranded run was recovered live
(stage 2 → in-review, chat `c-b8c5f0abc484`, analysis served).

### Released genesis v0.56.0 + genesis-workflows v0.12.1 (2026-08-28, CI green)

Post-live-testing UX + workflow-content pass, shipped together. **genesis v0.56.0** (CI master #6683358 +
tag #6683359): global ⌘K search (applications/features/documents); run-detail display fixes (steps-authoritative
node status → no stuck "Running" on large runs, execution counts, "Round k of N" dividers, loop re-entry,
bordered graph canvas); single-nav feature workspace (no "Back to feature"; feature-name breadcrumb in every
stage via a generic `:stage` route) + mockup-faithful UX empty/in-progress states; StageFinalizer hardening.
**genesis-workflows v0.12.1** (CI master #6683423 + tag #6683424): `ux-design-analysis` v0.1.1 reframed to a
UX/business deliverable (FB-4) — plain-language what-exists/what-changes, no object-level technical detail;
re-pin genesis v0.56.0. Gates: genesis pytest 658, web vitest 218, workflows validate_library 10 + pytest 107.
