# 29-02 — Wireframes & notes (UX Design stage)

> **Status:** ✅ **DELIVERED — FOR REVIEW (2026-08-28).** Coded hi-fi mockup at **`/dev/ux-design`**
> (`web/src/dev/mockups/UxDesignStageMockups.tsx`, dev-only) committed **LOCAL** on genesis master
> (`3ffb3ac`, no tag/push). This doc is the lo-fi companion.

## Locked decisions carried into the mockup (user: "your call", 2026-08-28)
- **Render:** DPI **~150**, **~40-page** cap (friendly error above).
- **`m0015`:** option **(A)** — migrate the existing Spec onto the generalized `kb_feature_stages` model
  (one uniform per-`(feature, stage)` model).
- **Completion:** explicit **"Mark complete"** (mirrors Spec), not auto-on-all-answered.

## The stage is a full-bleed workspace (ADR-056)
Opening the UX Design stage routes to its own full-bleed workspace with the shared slim header
(back-to-feature · "UX Design" · status badge · actions · **Expand → immersive**). The body switches by
the stage's state:

1. **Empty / upload** — a PDF dropzone ("Drop the mockup PDF… PDF only; re-upload replaces + re-runs") + a
   numbered **"what happens next"** pipeline (render pages → per-screen analysis → ground vs Spec + live env
   → synthesize → grounded verify).
2. **Running** — a supervised-run progress panel (render ✓ → per-screen ✓ → reconcile ✓ → ground ⟳ →
   synthesize ○ → verify ○) + "Open run detail →".
3. **Review (`in-review`)** — two panes: **left** = the draft **UX Implementation Analysis** (annotatable —
   Overview, per-screen blocks [Spec basis · Live delta · New/Modify], a **Blind spots / ripple effects**
   callout, and **Open Questions**); **right** = the **completion chat** walking the questions and editing the
   doc live. Header actions: Request changes · **Mark complete**.
4. **Completed** — the finalized doc + an artifact strip (`ux-implementation-analysis.html` v1.0 · Generated ·
   from `mockup-v3.pdf`) with Version history / Reopen / Export .md.
5. **Stage card (all statuses)** — how the UX card reads on the feature Overview grid (not-started →
   "Upload mockup"; in-progress → "View run"; in-review → "Review analysis"; completed → "Open analysis").

## Notes
- Light-first Phase-27 language; **tokens/primitives only, no hardcoded brand hex**; light + dark toggles.
- A11y applied inline (icon `aria-hidden`, icon-button `aria-label`, `SegmentedControl` labelled, chat
  bubbles as regions). Dev-only mockups carry **no dedicated vitest test** (matches the Phase-28
  `FeatureWorkspaceMockups` precedent); gates: tsc/eslint clean, vitest 210, build OK.
- Intent-level only (Spec basis / live delta / what-to-change) — no SAIL/object design (that's Technical
  Design).

## Gate
⭐ **User reviews the `/dev/ux-design` mockup; feedback feeds 29-03 (brainstorm & finalize + lock ADR-057).**
