# 28-02 — Wireframes & Hi-Fi Mockups

> **Status:** 📋 **PLANNED** (after 28-01). · **Type:** design / coded mockups (dev-only; no production wiring; no release) · **Phase:** 28 (Feature Revamp) · **Gate:** ⭐ user review of the mockup set before 28-03.

---

## Goal

Turn 28-01's recommended model into **reviewable screens** — lo-fi wireframes first (fast, structural), then
**coded hi-fi mockups** in the shipped light-first design language so brainstorming happens on real pixels.

## Scope

**In:** wireframes + coded hi-fi mockups of the **feature-level** workspace, mounted at **`/dev/mockups`**
(the Phase-27 precedent), using the shipped tokens/primitives (ADR-055/027). **Out:** any production wiring
(`web/features/features` untouched); any backend; story-workspace screens (only a *reserved-slot* affordance
may be shown); the inner surface of future stages beyond a representative "not yet available" treatment.

## Screens to mock (feature-level)

1. **Feature landing / command-center** — header (name · app · identifier · overall status), the
   **parallel stage overview** (the chosen representation from 28-01: tabs / cards / non-gated rail), a
   single-user **feature health / needs-attention** summary (no assignment), and an artifact/activity glance.
2. **Stage overview** — how the 4 feature-level stages read side-by-side in parallel: **Spec** (live:
   not-started → in-progress → in-review → completed), **UX Design / Technical Design / Feature Breakdown**
   as **"not yet available"** first-class containers (clearly *not* gated-by-predecessor — "available in a
   future release", startable-later, not lock-behind-Spec).
3. **A stage container (canonical)** — the reusable anatomy every future stage inherits: status, artifact(s)
   with **version + provenance**, an AI-assist entry point, a **completion** action (records approved
   version), and the stage's activity. Use **Spec** as the worked example (+ how its full-width builder route
   and preview relate to the lighter in-workspace stage summary).
4. **Artifacts** (feature-wide) — list with type / version / source(generated·uploaded·GDrive·KB-derived) /
   stage / updated; provenance + version-history affordance.
5. **Activity** (feature-wide) — audit timeline (not a chat transcript); each event links to its object.
6. *(reserved)* a visual **Stories** slot placeholder (to prove the IA leaves room) — no story screens.

Show **both light and dark** and the key states (not-started / in-progress / in-review / completed /
not-yet-available / needs-attention).

## Approach

- Lo-fi wireframes (ASCII/quick) in `28-02-wireframes.md` to lock structure/hierarchy fast.
- Then coded hi-fi mockups under `web/src/dev/mockups/**` reachable at `/dev/mockups` — **dev-only**, reusing
  `shared/ui` primitives + tokens; **no hardcoded brand hex**; no new heavy deps; jest-axe-sane.
- Rebuild + commit `web/static` only if `/dev/mockups` is part of the served dev bundle (per Phase-27
  practice); otherwise keep dev-only. Gates (tsc/eslint/build) stay green.

## Deliverables

- `specs/phase-28-feature-revamp/28-02-wireframes.md` (lo-fi) + the coded mockups at `/dev/mockups`.

## Acceptance / DoD

- Every §-screen exists as a coded mockup in both themes + the listed states.
- Parallelism is unmistakable (no screen implies stage gating).
- Uses only shipped tokens/primitives; tsc/eslint/build green; a11y-sane. **No production feature code
  changed.** Progress/tracker updated.

## Gate

⭐ **User reviews the mockups** → feedback drives 28-03.
