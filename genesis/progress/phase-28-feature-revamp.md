# Progress — Phase 28: Feature Revamp (the Feature Workspace framework)

> As-built record for Phase 28. **Specs:** `specs/phase-28-feature-revamp.md` (umbrella) +
> `phase-28-feature-revamp/28-01..28-06`. **ADR-056** (Proposed) — the parallel Feature Workspace model,
> superseding ADR-044's sequential unlock clause. Single-user (no assignment/roles); read-only-now
> (implementation/deploy = reserved plug-points); Stories reserved as a first-class slot for a later phase;
> framework/architecture only.

## Status

🔬 **28-01 (research) DELIVERED — awaiting user review before 28-02 (mockups).** No genesis code changed;
nothing tagged or pushed. Spec set + `28-01-findings.md` pushed to project-tracker.

## Sub-phase ledger

| # | Sub-phase | Status |
|---|---|---|
| 28-01 | Research & UX analysis | ✅ **DELIVERED — FOR REVIEW** (`28-01-findings.md`) |
| 28-02 | Wireframes & hi-fi mockups (`/dev/mockups`) | 📋 PLANNED — **NEXT** (after review) |
| 28-03 | Brainstorm & finalize mockups | 📋 PLANNED |
| 28-04 | Feature-workspace architecture build | 📋 PLANNED |
| 28-05 | Code review & hardening | 📋 PLANNED |
| 28-06 | Release | 📋 PLANNED |

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
