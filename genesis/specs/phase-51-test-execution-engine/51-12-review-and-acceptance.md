# 51-12 — Review, hardening and live acceptance

> **Status:** SPEC-DRAFTED 2026-11-02. Repos: genesis, genesis-workflows, playwright-appian, project-tracker
> (agent-system). Parent: `specs/phase-51-test-execution-engine.md`. Run by **genesis-review** (read-only on code)
> after 51-02..51-11 are BUILT; report in `specs/phase-51-test-execution-engine/reviews/51-12-review.md` with SHIP /
> NEEDS_CHANGES. Findings are fixed by genesis-dev before release; each fix gets a regression test.

## 1. Independent review (file:line evidence for each; plus `genesis-ctx check --since <phase base>` per repo)

1. **No agent at execution** — `test-execution` has program nodes only; regression and impact runs spend no credits
   (D2, ADR-001).
2. **Committed code only** — every execution records a commit and runs an export of it; un-adopted edits never run
   (D16.7).
3. **References, never copies** — scenario specs are generated; no case/action code duplicated across files; the
   generator is deterministic (golden tests) (D2).
4. **QA only** — the host allow-list is the QA host on every session; tests refuse to run without a QA environment or
   when the QA host equals another environment's (D5, D8); no MCP write tool, no deployment in any new workflow.
5. **Secrets** — test passwords only in the SecretProvider; never in state, checkpoints, events, files, logs, API
   responses, the agent's environment (51-03 S4/S5 recipe followed); Kiro started with the clean environment.
6. **No shell for agents** (D3b) — every browser agent node uses the `appian-browser` MCP server in a fail-closed node
   (`auto_deny`, `trust_all_tools=False`, explicit trust list, `fs_write_root` = the run folder); no new node trusts
   Kiro's shell or runs with `trust_all_tools`; the server has no session/login/host/mode tools and starts with the
   clean environment; the 51-03 M2 corpus re-run against the built workflows (L-088).
7. **Reliability** — the ADR-011 trio on every agent node; healing bounds (F10); `validate_library` green.
8. **Lifecycle** — library items and scenarios change status only through `LifecycleService` (ADR-050); retire/delete
   preconditions; contract rule (D16.5).
9. **Lane order** — every consumer listed in 51-09 §2 updated or proven order-free (L-094); audited transitions.
10. **Finalizers** — bound run, idempotent, reconcile, status stored before announce (L-058, L-061, L-093).
11. **Subprocesses** — timeouts and process groups everywhere (F8); nothing left running after cancel/pause.
12. **DB** — m0026 upgrade from a populated v25 DB; the `kb_test_suites` rebuild preserves rows and cascades.
13. **Web** — primitives/tokens, no `<Button asChild>`, central `/api`, fixtures = contracts, jest-axe, lazy heavy libs.
14. **`playwright-appian`** — any change is additive, recorded in its `DECISIONS.md`, invariants D-02/D-04/D-05 kept,
    its gates green.
15. **Naming** — no new `test_*` module or symbol outside tests (L-092).

## 2. Gates

genesis: `pytest` + `ruff`; fresh DB → v26 and v25 → v26 with data. web: `lint`, `typecheck`, `vitest`, `npm run build`
byte-identical to the committed `web/static`. genesis-workflows: `validate_library`, `validate_skills`, `pytest
workflows`. playwright-appian: `npm run lint && npm run typecheck && npm test` (+ `npm run build`). project-tracker:
agent-system tests, `genesis-ctx lint`.

## 3. Live acceptance (local `genesis serve`, the three workflows installed, a real tracked app, a **real QA
environment** with test users for two roles — provided by the user)

| # | Step | Expected |
|---|---|---|
| 1 | Settings → Environments: change the Dev entry's type via the select; add a QA entry; try a second QA; try a QA with the Dev host | Dev unchanged in behaviour (KB sync works); second QA and host collision refused |
| 2 | Settings → CLI card; Install Chromium | Node/Chromium/apwt versions shown; Chromium installed under `~/.genesis/testing/browsers` |
| 3 | Testing → Setup: site URL, two test users with passwords, workspace created | Readiness clear; `~/.genesis/testing/apps/<uuid>/` is a git repo with the template; no password in any file (grep) |
| 4 | Record workflow as role A: create an evaluation, add a factor | Headed Chromium signed in as A; Stop → capture analysing → proposals (new actions, contracts with inputs/outputs) with replay results |
| 5 | Accept two, reject one | One commit; accepted items Ready (replay passed) or Draft; rejected absent |
| 6 | Edit an action: break its contract while used | Refused; Save as new action works; history shows commits; Revert works |
| 7 | Edit a file in VS Code | "Changed outside Genesis"; an execution before Adopt runs the old code; Adopt commits |
| 8 | Regression: reference two feature scenarios, create one cross-feature regression scenario, set data setups (one shared, one "changes shared data") | Plan shows 2 setup instances; Run now → execution; the data created matches the plan (count evaluations in QA) |
| 9 | Break one step on purpose (a wrong label in a case script) | Result Failed at that case step; later scenarios on the same setup still run; screenshot + Playwright report open |
| 10 | Make a setup fail (wrong input) | Its scenarios Blocked, other setups' scenarios run |
| 11 | Test Impact → pick objects → Run impacted tests | Only scenarios containing affected automated cases run; uncovered cases listed |
| 12 | Schedule daily at a near time; keep Genesis running | `regression-run` starts it once; header badge updates; turning schedule off stops it |
| 13 | Workbench: drag a story Code Review → Deployment → Verification with no QA env configured (temporarily) | F2 warning; card stays in Deployment |
| 14 | With QA: drag to Verification; confirm | Run explores as each affected role, authors scripts, executes; report on the story page; passing story → Done; proposals listed |
| 15 | A story whose feature is genuinely broken in QA | Product defect → card back to Implementation with the defect list |
| 16 | QA unreachable mid-run (block the host) | Blocked → escalation gate with Retry / Send back / Accept |
| 17 | Accept verification proposals | One commit; library + regression updated |
| 18 | Cancel a running execution | Run cancelled; no Chromium/apwt daemon left (`ps`) |
| 19 | Security spot checks | A verification turn's log shows no shell tool call allowed and no secret in any tool result; an agent attempt to read outside the run folder or reach `127.0.0.1:8760` through the browser is refused |
| 20 | **Real-browser width probe (L-090):** 1280 / 1440 / 1920 px, light + dark — Library table, Executions table, execution results tree, Regression grouping, Setup users table | No clipped key/name columns, no horizontal scroll ≥ 1280; measured widths recorded |
| 21 | Restart `serve` while an execution is queued and one is running | Startup reconcile: finished one finalized, queued one starts (L-058, L-097) |

## Context manifest

```toml
areas    = ["release-ci", "security"]
adrs     = ["ADR-001", "ADR-011", "ADR-012", "ADR-029", "ADR-050", "ADR-061", "ADR-068", "ADR-077"]
lessons  = ["L-058", "L-069", "L-088", "L-089", "L-090", "L-092", "L-093", "L-094", "L-097"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:agent-system/skills/genesis-live-acceptance/SKILL.md"]
code     = ["genesis/genesis/testexec/**", "genesis/genesis/api/testing.py"]
upstream = ["51-02", "51-03", "51-04", "51-05", "51-06", "51-07", "51-08", "51-09", "51-10", "51-11"]
```
