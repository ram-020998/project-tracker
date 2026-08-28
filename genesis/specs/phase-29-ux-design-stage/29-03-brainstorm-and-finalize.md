# 29-03 — Brainstorm & Finalize

> **Status:** 📋 **PLANNED** (after 29-02). · **Type:** design finalization / docs (no release) · **Phase:** 29 (UX Design Stage) · **Gate:** ⭐ user sign-off → 29-04 build unlocked.

---

## Goal

Iterate the 29-02 mockups + 29-01 design with the user and **lock** every buildable decision so 29-04 is pure
execution. **Lock ADR-057.**

## Work — resolve & lock

1. **Workflow node graph + validators** — freeze the `ux-design-analysis` nodes (`resolve_inputs` →
   `render_pages` → `load_spec` → `screen_inventory` → `spec_reconcile` → `live_grounding` → `synthesize` →
   `verify` → `present`), the reliability wiring (retry max + escalation gate), and each **validator's**
   check (render count; per-screen coverage; grounding = object ref resolves or explicit "new";
   open-questions cap; doc section skeleton).
2. **Grounding contract** — freeze the split: **genesis-kb** tool set for structure + dependency/impact
   (blind-spot query), **appian-dev** read allowlist for actual interface code; the per-screen object-ref
   citation format.
3. **Doc template** — freeze the exact HTML section skeleton: per-screen block (mockup intent · spec basis ·
   live delta · what-to-change-at-intent-level) + **Blind spots / ripple effects** + **Open Questions**; and
   the **intent-level vs object-level** boundary (no SAIL/object design — that's Technical Design).
4. **`m0015` schema** — freeze the generalized per-`(feature, stage)` artifact/lifecycle model: a new
   `kb_feature_stages`(+`_artifacts`) pair vs. generalizing `kb_feature_specs`; the on-disk artifact layout
   (a `feature_stage_artifacts_dir` analog of `feature_specs_dir`); the `ux_design` `LifecycleService` machine
   + m0013 audit; **additive** (ADR-030/019; bump `current_version` → 15 + its tests). Confirm Spec's existing
   persistence either migrates onto the generalized model or coexists (decide + record).
5. **Completion chat** — freeze the `ux_design` `ChatModeProfile`: seed (feature + draft analysis + mockup
   context), tools (genesis-kb + appian-dev **read** + `fs_read`/`fs_write` sandbox), the walk-open-questions →
   edit-HTML-live behavior, the "extra check" affordance, and the completion criteria (candidate: explicit
   **Mark complete**, mirroring Spec) → `completed`.
6. **`kiro_node` image design** — freeze the additive genesis-core API (how blackboard page images become
   `client.prompt(images=…)` parts; gated on `promptCapabilities.image`; graceful no-op when absent).
7. **Render defaults** — freeze DPI + the page-count guard (tuned against a real deck).
8. **Handoff** — freeze: upload → launches the supervised run (escalation gate) → draft doc + completion chat;
   **re-upload deletes prior page images + supersedes the artifact + re-runs**.
9. **Lock ADR-057** (flip to the agreed final wording; still `Proposed` until 29-04 build).

## Deliverables

- `specs/phase-29-ux-design-stage/29-03-final-design.md` — the LOCKED buildable design (D1..Dn): node graph +
  validators + grounding contract + doc template + `m0015` schema + chat model + image-node API + render
  defaults + handoff + component/API inventory for 29-04.
- ADR-057 final wording in `reference/decision-log.md` + `bible/04`.

## Acceptance / DoD

- Every 29-04 build decision is locked (no "TBD" that blocks execution). ADR-057 final. Progress + tracker
  updated. **No code changed.**

## Gate

⭐ **User signs off on the locked design → 29-04 build begins.** (Do NOT build before this gate.)
