# 29-06 — Release

> **Status:** 📋 **PLANNED** (final; after 29-05). · **Type:** coordinated multi-repo release (on the user's go-ahead) · **Phase:** 29 (UX Design Stage) · **Gate:** CI green.

---

## Goal

Ship the UX Design stage as a coordinated release across the three repos, CI-green, with all docs updated.

## Work — release chain (ADR-019 order: core → genesis → genesis-workflows)

1. **Pre-release gates (all green):**
   - genesis-core: `pytest` + `ruff`.
   - genesis: `pytest` + `ruff`; web `tsc` + `eslint` + `vitest` + `npm run build` + **`web/static` committed**
     (stale-bundle guard); the `m0015` `current_version==15` tests updated.
   - genesis-workflows: `pytest` + `validate_library` + `validate_skills` (via `../genesis/.venv/bin/python`).
2. **Version bumps + tags + pins (keep the whole chain consistent — §7 ResolutionImpossible lesson):**
   - **genesis-core** vX (additive `kiro_node` images; `CORE_MAJOR` unchanged) → tag + push.
   - **genesis** vY.0 (render + m0015 + `ux_design` machine + chat mode + API + web UX stage) — bump
     `pyproject` + `api/app.py` FastAPI version + `web/src/version.ts`; **re-pin genesis-core → vX**; tag + push.
   - **genesis-workflows** vZ (the `ux-design-analysis` workflow + registry) — **re-pin genesis + genesis-core
     to the just-released tags**; tag + push.
3. **Verify CI green** on all three repos (master + tag pipelines) via `glab ci list`.
4. **ADR-057 → Accepted** (already flipped at 29-04); **docs:** bible/00 banner + bible/01 §2 (tag table rows
   + `current_version` 14→15 + test counts) + bible/03 codebase-map (new modules) + bible/04 ADR-057 +
   bible/08 §9 (SHIPPED block) + AGENT_ONBOARDING (banner + handoff) + decision-log; spec + progress statuses
   → RELEASED; tracker §6 entry. Push project-tracker.
5. **Report** with cited evidence (commits, tags, CI pipeline ids, gate counts).

## Acceptance / DoD

- All three repos tagged + pushed; **CI green** (master + tag) on each. Pin chain consistent (no
  `ResolutionImpossible`). ADR-057 Accepted. All docs updated + project-tracker pushed. Report cites evidence
  and is honest about what wasn't verified (the live multimodal run + completion chat are headless-undrivable
  → give the manual check).

## Gate

CI green on all three repos → **PHASE 29 COMPLETE.**

## Notes

- Live acceptance is user-driven: upload a real mockup PDF on a feature's UX Design stage → the supervised
  `ux-design-analysis` run renders pages → per-screen analysis → grounding (genesis-kb structure + appian-dev
  code) → synthesize → grounded verify → the draft **UX Implementation Analysis** appears → the completion
  chat walks the open questions + edits the doc live → Mark complete. Requires a dev-tagged env + the app
  synced in the KB + Kiro signed in.
