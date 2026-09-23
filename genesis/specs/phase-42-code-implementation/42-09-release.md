# 42-09 — Release

> **Status:** 🟡 DRAFTED. Coordinated multi-repo release. Parent: `specs/phase-42-code-implementation.md`.

## 1. Repos & order

- **genesis-core** — ONLY if 42-03 lands the `kiro_node(skills=…)` primitive in core (additive, `CORE_MAJOR` unchanged). If so, release first (ADR-019 order).
- **genesis** — m0021 + `ObjectWikiStore` + the implementation-start endpoint + `StoryImplementationFinalizer` + the review-surface API + the write-registry worker injection + workflow-node skill provisioning + web. Bump `pyproject`/`api/app.py` FastAPI version/`web/src/version.ts` **together** (the §7 forgotten-file lesson).
- **genesis-workflows** — the `story-implementation` workflow + the `appian-dev-write` registry entry; re-pin genesis (+ core if bumped).
- **The Appian Genesis Hub** — the two new Object-Wiki record types (built by the separate write-capable Dev-MCP agent from the 42-06 contract addition); Appian-side, **no genesis tag**; can land in parallel once the contract is frozen (like Phase 36 beside 35).

## 2. Gates (each repo, before tag)

- genesis: `pytest -q` + `ruff check genesis` green; web `tsc --noEmit` + `eslint` + `vitest` + `npm run build` + **`web/static` committed** (stale-bundle guard); the **`clean-install`** job migrates a fresh DB to **v21** + serves.
- genesis-workflows: `validate_library` (+1 workflow) + `pytest` green; the `appian-dev-write` registry-shape + no-delete guard tests.
- **Verify the release commit contains EVERY changed file before tagging** (`git status` clean after commit — the recurring §7 lesson).

## 3. Release steps

1. Land 42-02..42-08 locally (per-sub-phase gates green + independent review).
2. Bump versions + tags (core? → genesis → genesis-workflows), push, verify CI green via `glab`.
3. `genesis install --from ../genesis-workflows` (the running serve loads the new workflow at run-start; a server-code change needs a restart — never restart with an active run, §7). `gsm provision --all --no-mcp --no-env --force` to refresh the fleet library.
4. The Appian agent deploys the Hub Object-Wiki record types; verify a live publish/pull round-trip (or confirm the local-first path works with the Hub off).
5. Docs → Accepted: bible §2 (tags/tests + a Phase-42 "what works" line) / §3 (codebase map: `object_wiki.py`, the finalizer, the write entry, the workflow, m0021) / §4 (ADR-068/069/070 → Accepted + the ADR-021/036/037/038/062 amendments) / §8 (roadmap block → SHIPPED); `reference/decision-log.md` ADRs → Accepted; `tracker.md` §6 + `progress/phase-42-code-implementation.md`; the onboarding stamp; push project-tracker (`git pull --rebase` → push).

## 4. Report

Cite tags, CI pipeline ids, gate counts, and the live-acceptance status (the object writes are headless-undrivable — give the manual, sandbox-first check).
