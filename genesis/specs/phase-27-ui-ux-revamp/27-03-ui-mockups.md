# 27-03 — Hi-fi UI mockups

> **Phase 27 (UI/UX Revamp) · sub-phase 03 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`. Depends on: **27-02** (wireframes approved).
> **Status:** ✅ **APPROVED (2026-08-21)** — user approved the `/dev/mockups` look (orange/stone + Poppins iteration); finalized spec: `27-03-design-language.md`. · **Type:** design/mockups (coded in `/dev`, ADR-055) · **Gate:** ✅ **passed → implementation (27-04+) unlocked.**

## Objective
Produce **modern, future-looking, light-first hi-fi mockups for every revamped page**, and finalize the **visual design language** as an **implementable token + component spec** — the single source of truth the implementation phases build to, pixel-for-pixel.

## Inputs
27-02 wireframes + IA/flows; ADR-055 (design language + mockup medium); the existing token system (`tokens.css`, `tailwind.config.ts`) as the palette baseline to modernize.

## Deliverables
1. **Finalized visual language** — the modern, light-first spec:
   - **Color roles** (surfaces, text, primary/accent, semantic success/warning/danger/info, borders, focus) as a refined light token set + a dark-parity set; WCAG AA verified.
   - **Type scale** (display/title/body/label/mono), weights, line-height, tracking.
   - **Spacing & grid** rhythm, container widths, radii, **elevation/shadow** scale, iconography, and **motion** (durations/easings, reduced-motion).
2. **Hi-fi mockups for all pages** in umbrella §3 (light default; note dark-parity where non-trivial), covering key states (populated / empty / loading / error) for the primary surfaces.
3. **Component redline / mapping** — for each mockup element, which `shared/ui` primitive (new or modernized) renders it; new primitives needed; deprecations.
4. **Design → token handoff** — the concrete `tokens.css` values + Tailwind mappings + component variants the 27-04 foundation will implement.

## Approach (recommended: coded mockups in `/dev` KitchenSink)
1. Implement the finalized token set as a **preview theme** and build the mockups as **real, themeable coded screens in `/dev`** (outside the shell) — closest to implementation, reviewable in-browser in both themes, and reusable as the 27-04 foundation. *(If ADR-055 chose static/Figma mockups instead, produce those; coded-in-`/dev` is the recommendation.)*
2. Mock the shell + one flagship page first (likely Applications or Run-detail) to lock the language, review, then fan out to the rest.
3. Keep everything token-driven (no hardcoded hex) so the mockups *are* the style guide.
4. Review with the user; iterate to approval.

## Acceptance
- A hi-fi light-first mockup exists for **every** page-group + the shell + the canonical states.
- The visual language is fully specified as implementable tokens + component variants + a redline map.
- ⭐ **User reviews and approves** → this unlocks implementation (27-04+). No implementation phase starts before this sign-off.

## Out of scope
No production wiring to real data/hooks (mockups may use fixtures), no route changes, no releasable `web/static` change unless the mockups are built in `/dev` and we choose to ship the gallery (decided at 27-04).
