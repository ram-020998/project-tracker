# 29-05 — Code Review & Hardening

> **Status:** ✅ **COMPLETE — SHIP** (2026-08-28). · **Type:** independent review + hardening (no release) · **Phase:** 29 (UX Design Stage) · **Gate:** review clean → 29-06.

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


---

## Findings & resolution log (2026-08-28)

Independent architecture/code review (a `tao-architect` auditor, read-only, across all four repos) vs the
29-03 locked design (D0–D13) + the ADRs + the §7 hard-won lessons. Initial verdict **NO-SHIP** on one real
re-upload defect; after applying the MUST-FIX + the agreed SHOULD-FIX, re-review = **SHIP**.

### MUST-FIX (resolved)
- **M1 — Re-upload silently failed to replace.** `StageStore.reset_for_reupload` cleared the artifact
  pointers but left `chat_session_id` set; `StageFinalizer` treats a set `chat_session_id` as
  "already finalized" and would skip the fresh run's finalization → the stage stranded in-progress serving
  the STALE analysis (violates D11). **Fixed:** reset now also clears `chat_session_id`/`run_id`/
  `source_doc_path`; +regression test (`test_reset_for_reupload_clears_binding`). genesis `a76289c`.

### SHOULD-FIX (resolved)
- **S1** `v_reconcile` now requires ≥1 `spec_ref` for any non-`gap` verdict (D2 spec-grounding rule).
- **S2** `v_screens` now requires all D2 fields (`screen_name`, `components`, `states`, `ux_comments`).
- **S3** `resolve_inputs` fails fast when the platform reports no dev-tagged env or an un-synced app (the
  grounding sources) — best-effort via `ctx.environments` / `ctx.extras['kb_store']`, tolerant of a bare ctx.
- **S5** `v_grounding` now requires the `blast_radius` key (may be empty) so the KB blind-spot/ripple query
  isn't skippable (D3). All in genesis-workflows `123b76d`.
- **S4 — not a defect (verified).** The reviewer flagged `StageFinalizer.reconcile()` as never called; it
  **is** invoked at startup (`api/app.py` `_bind_supervisor` hook, line ~170) — the reviewer read the
  construction site (102–104) only. No change; the docstring claim is accurate.

### NICE (applied the cheap doc-accuracy ones; the rest accepted-deferred)
- **N1** corrected the UI-only `workflow.yaml` graph label for `screen_inventory` (images-only, not mcp).
- **N3** corrected the `feature_stage_artifacts_dir` docstring (the run renders `pages/` into its own
  blackboard, not the stage dir).
- **Deferred (non-blocking):** N2 (iframe a11y label "Spec preview" → generic), N4 (informational
  `genesis_core_version` pin), N5 (legacy `feature_specs_dir` orphan-dir cleanup on delete), N6 (rolled-up
  status now needs both Spec + UX complete — by design for the parallel model), N7 (per-page block count).

### Verified-correct (highlights, from the auditor)
State reducers (decisions shallow-merge, retries per-key; the verify-loop retry reset is correct); the
`from __future__ import annotations` in graph.py is safe (no custom reducer keys); the grounded `verify`
critic re-checks images+spec+grounding (not self-graded); read-only posture (KB_RO/DEV_RO ⊆ server
allowlists; ux_design chat = read-only + auto_deny + fs sandbox); determinism (render off-loop; agent nodes
wear the trio; save-by-reference; standalone graph); the additive+gated image seam; ADR-056 framework
fidelity (STAGE_DEFS + registry + inner workspace only); m0015 additive/idempotent + Decision-A data-safe;
artifact-filename + upload→run-input consistency; StageFinalizer thread-safety + idempotency.

## Outcome
All MUST-FIX + agreed SHOULD-FIX resolved; re-review = **SHIP**. Gates green: genesis pytest **654** + ruff ·
web tsc/eslint0/vitest 211/build (untouched) · genesis-workflows **validate_library (10)** + ux tests **14**.
Hardening committed LOCAL: genesis `a76289c`, genesis-workflows `123b76d` (no tag/push — 29-06 releases). →
**29-06 coordinated release.**
