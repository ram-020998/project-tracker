# 43-05 — Release

> **Phase 43 · sub-phase 05** — ship genesis (frontend + thin backend), flip ADR-071, update the docs.
> Depends on 43-01..43-04 all green + independently reviewed = SHIP.

## Do (per bible §6 release protocol)

1. **Version bump:** genesis `[project].version` → the next minor (e.g. **v0.74.0**) + `genesis/api/app.py` FastAPI version + `web/src/version.ts`. genesis-only — **no** genesis-core/genesis-workflows/kiro-agent-sdk/parser bump (nothing changed there), so no pin changes.
2. **Gates green (all):** genesis pytest + ruff; web tsc + eslint(0) + vitest(+ jest-axe) + build; **`web/static` rebuilt + committed** (stale-bundle guard). Fresh-DB smoke unchanged (no migration → still **v21**).
3. **Commit + tag + push** genesis `vX.Y.0` (single repo; verify the release commit contains **every** changed file — the §7 lesson); verify **CI green** via `glab ci list -R ramaswamy.u/genesis` (genesis + frontend + clean-install jobs; the frontend stale-bundle guard runs because `web/**` changed).
4. **Flip ADR-071 → Accepted** in `reference/decision-log.md` + add the full ADR to `bible/04-adrs-and-constraints.md` (§5).
5. **Docs:** `bible/01-current-state.md` (tag → the new genesis version + a Phase-43 ⭐ SHIPPED line), `bible/08-roadmap-and-backlog.md` (§9 Phase-43 → SHIPPED/COMPLETE), `tracker.md` §6 (SHIPPED entry), `progress/phase-43-unified-story-workspace.md` (the as-built), the onboarding banners' "Last refreshed" + LATEST SHIPPED (bible/00 + AGENT_ONBOARDING), README. Push project-tracker (`git pull --rebase` → push).
6. **Deploy to the fleet** (optional, as prior phases): both instances are editable installs — restart `genesis serve` on each (or `gsm restart --all`) to pick up the new server code + the rebuilt `web/static`. No migration, no library refresh (genesis-workflows unchanged).
7. **Report** with cited evidence (CI pipeline ids, gate counts). Note that live click-through acceptance across every entry point is user-observable in the running fleet.

## Done when

genesis `vX.Y.0` shipped, CI green; ADR-071 Accepted; bible/tracker/progress/README updated + project-tracker pushed; the fleet restarted on the new version. **Phase 43 COMPLETE.**
