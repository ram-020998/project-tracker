# 20-06 — Release + acceptance

> **Status:** ✅ **SHIPPED.** genesis **v0.45.0** (single-repo release; genesis-core/genesis-workflows unchanged) committed +
> tagged + pushed (`d58c7c2`); CI green. **ADR-042/043 → Accepted.** m0010 ships (schema v10). Live-accepted: create feature →
> spec chat authors `spec.html` → annotate in the embedded review → the comment flows into the chat. Tests: genesis 397 pytest
> + web 145 Vitest; ruff/eslint/tsc clean. **PHASE 20 COMPLETE.**

## Goal
Ship Phase 20 as a genesis release, flip ADR-042/043 to Accepted, verify live, and refresh the docs + the bible.

## Release
- Full green gate across the working tree: genesis `pytest` + `ruff`; web `lint` + `typecheck` + `vitest`; `npm run build` and
  **commit the rebuilt `web/static/`** (the `frontend` stale-bundle guard).
- Bump `genesis` `[project].version`, commit + tag `vX.Y.Z` + push (`git -c user.name=Genesis -c user.email=genesis@local`).
  genesis-core / genesis-workflows unchanged → **no pin bumps** (verify the dependency chain still resolves). Bump the FastAPI
  `app.py` version string. Verify CI green via `glab ci list -R ramaswamy.u/genesis` (python `genesis` job + `frontend` guard).
- **`m0010` ships in this genesis release**; `genesis db upgrade` applies it. A running `genesis serve` needs a **restart** to
  load the new backend (new routes + migration + chat seeding).

## ADRs → Accepted
- **ADR-042** (Features & Specs model) and **ADR-043** (embed the vendored Lavish SDK) → **Accepted** in
  `reference/decision-log.md`.

## Live acceptance (user-driven; can't be headless)
1. Open an application → **Features** → **Create feature** (name + description) → land on the **feature page**.
2. **Create spec** → chat opens; confirm the agent knows the application (asks/uses `genesis-kb`).
3. **Add context** → pick a Business Artifact (a Phase-19 linked document) → confirm the agent uses it.
4. Converse → the agent authors the spec; it renders as **HTML** in the embedded surface.
5. **Highlight a passage + comment** → it arrives in the chat → the agent revises → the iframe **reloads** with the change.
6. **Save a milestone** (and confirm the agent reminded you to) → a revision is recorded; set **status** through
   draft → in-progress → in-review → completed.
7. **Export as Markdown** → download + preview.
8. Delete the feature (or untrack the app) → confirm features/specs/revisions cascade away (documents remain — Phase-19).

## Docs + bible
- `progress/phase-20-features-and-spec-authoring.md` — as-built (commits, tag, CI pipeline id, the vendored SDK commit +
  message schema, deviations, the live-acceptance result).
- `tracker.md` §3 (index row) + §6 (a SHIPPED status-log entry); `README.md` phase row → SHIPPED; the umbrella + sub-phase
  spec status headers → SHIPPED.
- **`AGENT_ONBOARDING.md`** (the bible): header "Last refreshed" + latest-SHIPPED tag + newest-work note; §2 tag table +
  test counts + `current_version=10` (m0010) + the Screens list (Features tab + feature page); §4 map (`kb/features.py`,
  `api/features.py`, the vendored `lavish/` SDK, `web/features/features`, the new routes, `settings.feature_specs_dir`); §5
  ADR-042/043 entries; §7 any Phase-20 lessons (e.g. the embed/sandbox findings); §9 a Phase-20 SHIPPED block.
- `THIRD-PARTY-NOTICES.md` (in genesis) — the vendored Lavish SDK (MIT, pinned commit) attribution.

## Exit criteria
genesis released + tagged + CI green; m0010 applies cleanly; ADR-042/043 Accepted; the full live-acceptance script passes;
docs + bible refreshed. **PHASE 20 COMPLETE.**
