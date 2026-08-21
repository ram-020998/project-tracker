# 27-11 — Cross-cutting polish, a11y/responsive audit, dark-mode parity & release

> **Phase 27 (UI/UX Revamp) · sub-phase 11 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`. Depends on: **27-04..27-10**.
> **Status:** 📋 DRAFT · **Type:** genesis frontend (ships the phase release + docs).

## Objective
Land the final quality pass across the whole app and **release the revamp**: a consistent empty/loading/error sweep, a full **responsive** and **accessibility** audit, verified **dark-mode parity**, documentation, and the tagged release.

## Deliverables
- **State sweep** — every page has canonical empty / loading (skeleton) / error / not-found states from the pattern library.
- **Responsive sweep** — laptop → wide-monitor verification of every page-group; nav + rails collapse correctly.
- **Accessibility audit** — jest-axe green on **every** page; keyboard paths, focus order, visible focus, reduced-motion, and WCAG AA contrast verified in **both** themes; fix regressions.
- **Dark-mode parity** — manual both-theme walkthrough of every surface; **zero hardcoded-hex** remaining (grep gate).
- **Docs** — bible/00 banner + bible/01 (§2 current-state) + bible/03 (if primitives moved) + `progress/phase-27-ui-ux-revamp.md` as-built + `tracker.md` §6 + ADR-055 Accepted in `reference/decision-log.md`.
- **Release** — final bump + tag + CI green (likely **v0.53.0** given breadth; decided at release time), `web/static` committed.

## Acceptance / gates
- All pages pass jest-axe in both themes; responsive verified; no hardcoded hex; light default + dark parity.
- Full web gates green (`tsc/eslint/vitest/build`); genesis pytest unaffected (re-confirmed if any `.py` touched); stale-bundle guard clean.
- Phase docs updated + pushed; release tagged (on the user's go-ahead) with CI green.

## Out of scope
Any deferred functional improvements discovered during the revamp → filed to `specs/backlog/`, not folded into the release.
