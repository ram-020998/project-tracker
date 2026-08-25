# 28-03 — Brainstorm & Finalize Mockups

> **Status:** ✅ **FINAL — FOR BUILD SIGN-OFF (2026-08-25)** — locked design: `28-03-final-design.md`; ADR-056 Proposed. · **Type:** design finalization / docs + mockup iteration (dev-only; no release) · **Phase:** 28 (Feature Revamp) · **Gate:** ⭐ user sign-off → the build (28-04) is unlocked.

---

## Goal

Iterate the 28-02 mockups with the user to a **locked** feature-workspace design, and **finalize ADR-056**
(move from Proposed → ready-to-Accept-at-build). This is the decision sub-phase.

## Scope

**In:** iterating the `/dev/mockups` screens per user feedback; resolving the umbrella §5 design tensions +
§10 open questions; writing the finalized design spec that 28-04 implements against. **Out:** production
wiring; any stage capability; story workflow.

## Decisions to lock (the §5 tensions)

- **Stage representation** — tabs vs cards-on-overview vs non-gated rail (pick one, with rationale).
- **Feature IA / tab set** — the exact top-level nav (e.g. `Overview · Artifacts · Activity` + how stages
  surface) + the **reserved Stories** slot.
- **Command-center** — dedicated Overview vs the landing itself; what the single-user "needs attention"
  contains (feature health, unresolved AI findings, blocked/stale artifacts — no assignment).
- **Feature status semantics** — derived vs explicit (umbrella §10.2).
- **Stage-container anatomy** — the canonical status/artifact+version/AI-assist/completion/activity contract
  every future stage inherits.
- **Spec integration** — dedicated builder route + preview vs the in-workspace stage summary; keep behavior.
- **"Not yet available" treatment** — how UX/Tech-Design/Breakdown read as first-class-but-not-startable-yet
  **without** implying sequential gating.
- **Reserved plug-points** — confirm the framework leaves clean slots for Stories + (further out) story
  execution/deploy, with nothing built for them now.

## Deliverables

- Iterated mockups at `/dev/mockups` reflecting the final design.
- `specs/phase-28-feature-revamp/28-03-final-design.md` — the **locked** IA + model + stage-container
  contract + component list + a state matrix + the reserved-slot map; the 28-04 build spec references it.
- **ADR-056 finalized** (Proposed, ready to Accept at 28-04/28-06) in `reference/decision-log.md` + `bible/04`.

## Acceptance / DoD

- The user has signed off on the final mockups.
- Every §-decision is recorded with rationale in `28-03-final-design.md`.
- ADR-056 text is final (parallel workspace; single-user; read-only-now plug-points; Stories reserved;
  supersedes ADR-044's sequential clause).
- Progress/tracker updated. **No production feature code changed yet.**

## Gate

⭐ **User sign-off on the finalized design** → 28-04 (build) unlocked. **No build before this gate.**
