# Progress — Phase 28: Feature Revamp (the Feature Workspace framework)

> As-built record for Phase 28. **Specs:** `specs/phase-28-feature-revamp.md` (umbrella) +
> `phase-28-feature-revamp/28-01..28-06`. **ADR-056** (Proposed) — the parallel Feature Workspace model,
> superseding ADR-044's sequential unlock clause. Single-user (no assignment/roles); read-only-now
> (implementation/deploy = reserved plug-points); Stories reserved as a first-class slot for a later phase;
> framework/architecture only.

## Status

⭐ **PHASE 28 COMPLETE — SHIPPED genesis v0.54.0 + genesis-workflows v0.11.0 (2026-08-25, CI green).**

## Sub-phase ledger

| # | Sub-phase | Status |
|---|---|---|
| 28-01 | Research & UX analysis | ✅ **DELIVERED — FOR REVIEW** (`28-01-findings.md`) |
| 28-02 | Wireframes & hi-fi mockups (`/dev/feature-workspace`) | ✅ **DELIVERED — FOR REVIEW** |
| 28-03 | Brainstorm & finalize mockups | ✅ **FINAL — FOR BUILD SIGN-OFF** (`28-03-final-design.md`) |
| 28-04 | Feature-workspace architecture build | ✅ **BUILT (unreleased)** — genesis LOCAL `b9568c3` (hardened `be0e7cc`) |
| 28-05 | Code review & hardening | ✅ **DONE — review SHIP** (genesis LOCAL `be0e7cc`) |
| 28-06 | Release | ⭐ **RELEASED** — genesis v0.54.0 + genesis-workflows v0.11.0 |

## Decisions locked with the user (2026-08-25)

- **Single-user stays** — no assignment/roles/permissions/lenses/My-Work; anyone acts on any stage (ADR-026).
- **Read-only-now stays** — no Appian write/deploy; the draft's story-execution write stages + git/branch
  model + environment promotion are OUT; framework leaves clean plug-points only.
- **Stories first-class LATER** — reserve the IA/route slot; do not finalize/build the story workflow now.
- **Parallel, not sequential** — feature-level stages (Spec, UX Design, Technical Design, Feature Breakdown)
  run in parallel/any-order; the sequential unlock-on-completion of ADR-044 is superseded (ADR-056).
- **Framework/architecture only** — no stage capability built this phase; Spec is wired in as the live stage.

## As-built (filled in as sub-phases complete)

_(nothing built yet — spec drafting only)_

## 28-01 — Research & UX analysis (delivered 2026-08-25)

`specs/phase-28-feature-revamp/28-01-findings.md`. Cited external research (Jira epic-status roll-up · Linear
parallel views/display-options · NN/g tabs + progressive disclosure · PatternFly stepper=ordered · ChatGPT
Canvas / Claude Artifacts split-screen · "audit trail, not chat transcript"). Current-code audit: the
`LifecycleService`/`domain/` layer is generic (ADR-050) so **feature-stage machines are additive** and
`ArtifactKind`(SPEC/UX_DESIGN/TECHNICAL_DESIGN/BREAKDOWN…) + a forward story-stage table already exist; the
main new backend is a **generalized per-stage artifact model** (likely a small additive migration) since
today is one-spec-per-feature, plus per-(feature,stage) addressing (a `STAGE` entity). Adopt/adapt/defer/drop
table vs the draft. **Recommended model:** command-center **Overview + peer stage cards** (non-gating progress
indicator, NOT a stepper), a reusable **stage-container contract**, **derived** feature status (Jira-style
roll-up + override), a side-by-side **canvas** option for the spec builder, and a single-user **needs-
attention** (system signals only). **ADR-056 drafted** (Proposed; supersedes ADR-044's sequential clause). 5
open questions for the user. **Gate: user review before 28-02.**

## 28-02 — Wireframes & hi-fi mockups (delivered 2026-08-25)

Lo-fi wireframes: `specs/phase-28-feature-revamp/28-02-wireframes.md`. Coded hi-fi mockup:
`web/src/dev/mockups/FeatureWorkspaceMockups.tsx` (587 lines) at route **`/dev/feature-workspace`** (dev-only)
+ `web/src/app/router.tsx`. Committed **LOCAL** on genesis master (`a649ac9`, ahead 1, **no tag/push**).
Renders the 28-01 recommended model: command-center **Overview + peer stage cards** with a **non-gating**
progress meter; a reusable **stage-container** (Spec = side-by-side chat + live-artifact *canvas* with
allowed-action buttons + an artifact strip showing version/provenance; UX/Tech/Breakdown as first-class
**"arriving in a later phase"**, explicitly *not* gated by Spec); **Artifacts** (type/version/source/updated
with provenance chips) + **Activity** (audit timeline, object links, "not a chat transcript") tabs; a
**reserved Stories** slot; **plus the stages-as-tabs alternative** for contrast (with a note on the
tradeoff). **Layout** (overview+cards | stages-as-tabs) + **light/dark** toggles. Shipped tokens/primitives
only (no hardcoded brand hex); themed via `.theme-light`/`.theme-dark`. Gates green: tsc, eslint, **vitest
204**, build; `web/static` rebuilt + committed (stale-bundle guard OK). **Gate: user review before 28-03.**

### 28-02 rev (2026-08-25) — full-bleed stage workspace

Per user feedback (stage work area too small): opening a stage from a card/tab now routes to a **full-bleed
stage workspace** filling the whole content area (the Spec chat + live-artifact canvas fills full height),
with an **Expand → immersive** toggle that hides the faux sidebar + control bar for a maximal canvas
("Exit full screen" returns). Mirrors the real per-stage builder route pattern (deep-linkable; a stage card
can be cmd-clicked to a new browser tab since it's a real URL). Committed LOCAL on genesis master (`9342f92`,
no tag). Gates green: tsc/eslint/**vitest 204**/build; web/static rebuilt. Overview + cards layout confirmed
by the user as the direction.

## 28-03 — Brainstorm & finalize (2026-08-25)

User approved **Overview + cards** and the **full-bleed stage workspace + expand-to-immersive**. Locked design:
`specs/phase-28-feature-revamp/28-03-final-design.md` — 11 resolved decisions (D1–D11); IA + routes (feature
workspace + `/:stage` full-bleed route, deep-linkable, `?expand=1` immersive); the **stage-container contract**
(`StageDescriptor` + inner `Workspace`); a **stage-agnostic lifecycle** + a **derived feature status** pure fn;
Overview composition; feature-wide **Artifacts** + **Activity** (m0013); the **backend plan** (a generalized
per-stage artifact model — `m0015 kb_feature_stages` sketch or a `spec+stage` refinement, decided at build;
per-(feature,stage) `LifecycleService` machines; additive API); the **web component inventory** (replaces
`ArtifactPipeline`). **ADR-056** finalized (Proposed) in `reference/decision-log.md` + `bible/04` (also
backfilled the missing **ADR-055** into bible/04 — a Phase-27 gap). **Gate: user sign-off on 28-03-final-design
unlocks 28-04 (build).**

## 28-04 — Feature-workspace architecture build (BUILT 2026-08-25, unreleased)

Committed **LOCAL** on genesis master (`b9568c3`, ahead 3, **no tag/push**). **Frontend-only** — only Spec is
live this phase, so **no migration** (stages + derived status are computed client-side from the existing
feature+spec APIs; the generalized per-stage persistence lands with the first stage that needs it). Files
(`web/src/features/features/`): **`stages.ts`** (framework core — `StageDescriptor` + `deriveStages` +
`deriveFeatureStatus` + stage-agnostic status vocabulary); **`FeaturePage.tsx`** rewritten as the
**Feature Workspace** (derived status badge + non-gating `ProgressMeter`; tabs Overview · Artifacts ·
Activity · Stories[reserved]; Overview = Feature-health + single-user Needs-attention + a peer **StageCard**
grid; `ArtifactsTab` from the spec + the app's linked docs; **reuses `ActivityFeed`**; `StoriesReserved`;
`SpecPreviewOverlay` = read-only `annotate=0` "View"); **`StageWorkspacePage.tsx`** (routed full-bleed stage
workspace — `spec`→the builder, else a first-class **not-available** workspace); **`SpecBuilderPage.tsx`**
gained an **Expand → immersive** toggle (`fixed inset-0 z-50`); **router** `…/features/:id/:stage` (absorbs
`…/spec`); **deleted `ArtifactPipeline.tsx`**; **`features.test.tsx`** landing block rewritten to the new
workspace + a jest-axe test. **Extensibility:** a future stage = one `STAGE_DEFS` entry + its inner
`Workspace` + a `LifecycleService` machine — **no shell changes**. Gates green: **tsc**, **eslint**,
**vitest 205** (features 12 incl jest-axe), **build**; `web/static` rebuilt + committed (stale-bundle guard
OK). Backend untouched → genesis pytest unaffected (confirm at 28-06). **ADR-056 stays Proposed** (flip to
Accepted after the 28-05 review). **NEXT = 28-05 independent review.**

## 28-05 — Code review & hardening (2026-08-25) — review SHIP

Independent review (subagent `tao-architect`, read-only, blocking) returned **NEEDS_CHANGES** first: the
live-stage plug-in path leaked spec-specific `if`s in 3 shell spots (the phase's headline promise). Fixed:
- **stages.ts** — self-describing `StageDescriptor` (+ `artifactKind` + a per-descriptor `deriveStatus`);
  `deriveStages` is now generic (no `if key==='spec'`).
- **stage-registry.tsx** (new, data-only) — the component-wiring plug-in point (`key → {Workspace, CardActions}`).
- **StageWorkspacePage** — dispatches via the registry (no spec branch).
- **StageCard** (FeaturePage) — generic; delegates to the registry's `CardActions` with an Open/Details fallback.
- **SpecCardActions.tsx** (new) — the Spec card's Create/Open/View + read-only preview, self-contained.
- **StageWorkspaceHeader.tsx** (new) — shared header for the builder + not-available workspace.
- **SpecBuilderPage** — shared header + **Escape-to-exit** immersive (a11y).
- **FeaturePage** — ARIA tabs (`role=tab/tabpanel` + `aria-controls` + ids).
- **stages.test.ts** (new) — unit tests for `deriveStages` + `deriveFeatureStatus`.

**Re-review = SHIP:** all 4 MUST-FIX RESOLVED (cited); no residual per-stage `if`/`isSpec` in the shell; no
new circular imports/dead code; the UX-Design plug-in walkthrough confirmed to touch only a `STAGE_DEFS` row
+ a registry entry + the new inner component (+ backend machine) — **no shell edits**. Two cosmetic
non-blockers noted (a hardcoded `/spec` breadcrumb label outside the shell; a duplicated local `type Tone`).
Committed LOCAL on genesis master (`be0e7cc`, no tag). Gates green: tsc, eslint (0 warnings in features/),
**vitest 210** (incl the new pure-fn tests + jest-axe), build; web/static committed. **ADR-056 → Accepted.**
**NEXT = 28-06 release (on the user's go-ahead).**

## 28-06 — Release ⭐ SHIPPED (2026-08-25)

- **genesis v0.54.0** — release commit `8ab4b41`, tag `v0.54.0`, pushed to master; **CI green — #6650764 (master) +
  #6650766 (v0.54.0 tag)**. Bumps: `pyproject` + FastAPI `create_app` + `web/src/version.ts` → 0.54.0. Frontend-only
  (no migration); genesis-core / kiro-agent-sdk / genesis-appian-parser unchanged.
- **genesis-workflows v0.11.0** — release commit `db45cb7`, tag `v0.11.0`; **CI green — #6650936 (master) + #6650937
  (v0.11.0 tag)**. Two new library skills (`appian-object-generation`, `sail-mockup-generation`) + `skills-registry.json`
  entries; pins unchanged (genesis-core@v0.9.5 + genesis@v0.52.0). (Released alongside on the user's request.)
- **Gates:** web **vitest 210** (jest-axe + `stages.test.ts`) + tsc/eslint/build; genesis pytest **635** + ruff;
  genesis-workflows validate_skills (3) + validate_library (9) + pytest **93**. `web/static` rebuilt + committed.
- **ADR-056 Accepted.** Docs flipped to SHIPPED (bible/00 banner, bible/01 §2 rows + counts, bible/03 map, bible/04 +
  decision-log ADR-056, bible/08 §9, AGENT_ONBOARDING, spec statuses, this progress, tracker). **PHASE 28 COMPLETE.**
