# 28-01 — Research & UX Analysis

> **Status:** ✅ **DELIVERED — FOR REVIEW (2026-08-25)** — findings: `28-01-findings.md`. · **Type:** research / docs-only (no genesis code, no release) · **Phase:** 28 (Feature Revamp) · **Gate:** ⭐ user review of the findings + recommended model before 28-02.

---

## Goal

Produce the evidence base and a recommended feature-workspace **information architecture + interaction
model** that 28-02's mockups will render — grounded in (a) external product patterns and (b) Genesis's actual
constraints (§3 of the umbrella). Draft **ADR-056**.

## Scope

**In:** desk research + a written analysis + a recommended model + open-question list + the ADR-056 draft.
**Out:** any code; any mockup (that's 28-02); anything about story execution / deploy internals.

## Work

1. **External pattern research** (cite sources). Study how mature tools present a multi-artifact unit of work
   with parallel sub-workstreams and an AI assistant, and extract what fits a **single-user** tool:
   - Issue/feature/work trackers & workspaces: **Linear, Jira, Azure DevOps/Boards, Shortcut, Height, Notion
     projects, GitHub Projects/Issues.** (lifecycle rails, parallel status, tabs vs cards, inspect-completed.)
   - AI-native / doc-authoring workspaces: **Notion AI, Linear's product intelligence, Cursor/agent IDE side
     panels, spec/PRD tools** — how they keep an AI conversation *beside* an evolving artifact without making
     chat the only control surface (echoes draft §29).
   - Progress/pipeline visualizations: when a **rail** vs **tabs** vs **cards** best communicate
     "parallel, any-order, inspectable, some-not-yet-available".
   - Capture concrete, sourced takeaways (scresearch notes) — what to adopt, what to avoid, and why, **for a
     single-user, read-only-now tool**.
2. **Genesis-fit analysis.** Reconcile the draft design (`artifacts/designs/Genesis_Appian_Orchestrator_
   Feature_Workspace_UX_Design.md`) with the umbrella's §3 constraints: mark each draft concept as
   **adopt / adapt / defer / drop** (e.g. My-Work/roles → drop; lifecycle rail → adapt to parallel;
   Artifacts/Activity → adopt via existing machinery; story execution → defer as plug-point).
3. **Current-code audit.** Read + summarize the real surfaces the framework will reshape/reuse:
   `web/features/features/*` (FeaturePage/ArtifactPipeline/SpecWorkspace/ActivityFeed/FeaturesTab/hooks/
   status), `api/features.py`, `kb/features.py` (`FeatureStore`, m0010, m0014 CAS), `genesis/domain/*`
   (`LifecycleService`, `enums` `ArtifactKind`/`EntityKind`, `transitions` SPEC_* + forward STORY_STAGE_*),
   m0013 audit, feature spec revisions/versioning, the `feature_spec` chat authoring path. Note exactly what
   is reusable as-is vs what needs a generalized (multi-stage) shape.
4. **Recommended model.** A concrete recommendation for: the feature IA/tab set; stages-as-tabs vs
   cards-on-overview vs non-gated rail; the command-center/Overview; the stage-container anatomy (status /
   artifact+version / AI-assist / completion / activity); the single-user "needs attention" (feature health,
   unresolved AI findings, blocked artifacts — no assignment); how Spec fits; the reserved Stories slot; the
   reserved read-only-now plug-points for future write stages.
5. **ADR-056 draft** — the parallel Feature Workspace model (supersedes ADR-044 sequential unlock).
6. **Open questions** for the user (feed the umbrella §10).

## Deliverables

- `specs/phase-28-feature-revamp/28-01-findings.md` — sourced research + the adopt/adapt/defer/drop table +
  the current-code audit + the recommended IA/model + open questions.
- ADR-056 draft (in the findings or appended to `reference/decision-log.md` as **Proposed**).

## Acceptance / DoD

- Findings cite real external sources and real Genesis code paths (no hand-waving).
- Every draft-design concept is explicitly classified against the §3 constraints.
- A single, coherent **recommended model** is stated (not just options) with rationale.
- ADR-056 drafted. Progress doc + tracker updated. **No genesis code changed.**

## Gate

⭐ **User reviews the findings + recommended model (+ resolves the §10 open questions where possible) before
28-02 mockups begin.**
