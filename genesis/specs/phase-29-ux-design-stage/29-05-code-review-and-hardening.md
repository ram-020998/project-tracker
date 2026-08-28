# 29-05 — Code Review & Hardening

> **Status:** 📋 **PLANNED** (after 29-04). · **Type:** independent review + hardening (no release) · **Phase:** 29 (UX Design Stage) · **Gate:** review clean → 29-06.

---

## Goal

An independent architecture/code review of the built stage (all three repos) + hardening, so 29-06 ships a
correct, standard, reliable stage.

## Review focus

1. **Grounding correctness** — the analysis is genuinely grounded: `screen_inventory` is per-screen;
   `live_grounding` reads structure from **genesis-kb** and actual code from **appian-dev**; every claimed
   change resolves to a real object ref or is explicitly "new"; the **`verify` critic re-checks against the
   images + spec + live notes** (not self-graded — no "progress mirage"); the KB-backed blind-spot query is
   real, not narrative.
2. **Reliability & determinism (ADR-011/001)** — every agent node has validator + retry + escalation; program
   nodes own all I/O/rendering/persistence; `graph.py` is self-contained (loader imports it standalone);
   blocking KB/DB writes run off the event loop (§7); save-by-reference for bulk tool output.
3. **Read-only posture (ADR-036/037/031)** — appian-dev + genesis-kb allowlists are **read-only**; the
   completion chat's write authority is confined to the fs sandbox (HTML edits) — no Appian/registry/deploy
   tools; any write-capable action stays human-confirmed (ADR-045).
4. **Framework fidelity (ADR-056)** — UX went live via **STAGE_DEFS row + registry entry + inner workspace
   only** (no shell/Overview/rail edits); the `m0015` model is generalized (not UX-only) and additive; the
   `ux_design` machine composes `LifecycleService` cleanly.
5. **The multimodal path** — `kiro_node` image support is additive + gated on `promptCapabilities.image`
   (graceful when absent); render is PDF-only, off-loop, bounded (DPI/page cap); re-upload truly
   replaces (deletes prior page images + supersedes the artifact).
6. **Frontend quality** — jest-axe clean on the UX stage pages; dark parity; **no hardcoded brand hex**;
   contract fixtures + prop-API stability; `web/static` matches a fresh build.

## Work

- Independent reviewer reads the built code across the three repos vs. the 29-03 locked design + the ADRs +
  §7 lessons; produces MUST-FIX / SHOULD-FIX / NICE lists.
- Apply MUST-FIX + agreed SHOULD-FIX; re-review to **SHIP**. Re-run all gates green; rebuild + commit
  `web/static`.

## Deliverables

- `specs/phase-29-ux-design-stage/29-05-code-review-and-hardening.md` findings + resolution log.
- Hardened code committed LOCAL on each repo's master (no tag/push).

## Acceptance / DoD

- All MUST-FIX resolved; re-review = **SHIP**. All gates green across the three repos; `web/static` committed.
  Progress + tracker updated.

## Gate

Review clean (SHIP) → 29-06 release.
