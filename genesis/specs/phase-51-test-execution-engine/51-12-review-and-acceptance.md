# 51-12 — Review, hardening and live acceptance

> **Status:** SPEC-DRAFTED 2026-11-02. Repos: genesis, genesis-workflows, playwright-appian, project-tracker
> (agent-system). Parent: `specs/phase-51-test-execution-engine.md`. Run by **genesis-review** (read-only on code)
> after 51-02..51-11 are BUILT; report in `specs/phase-51-test-execution-engine/reviews/51-12-review.md` with SHIP /
> NEEDS_CHANGES. Findings are fixed by genesis-dev before release; each fix gets a regression test.

## 1. Independent review (file:line evidence for each; plus `genesis-ctx check --since <phase base>` per repo)

1. **No agent at execution** — `test-execution` has program nodes only; regression and impact runs spend no credits
   (D2, ADR-001).
2. **Committed code only** — every execution records a commit and runs an export of it; un-adopted edits never run;
   a verification execution adds only its recorded overlay (D24), and nothing the agent authored reaches the workspace
   or DB before the proposals are accepted
   (D16.7).
3. **References, never copies** — scenario specs are generated; no case/action code duplicated across files; the
   generator is deterministic (golden tests) (D2).
4. **QA only** — the host allow-list is the QA host on every session; tests refuse to run without a QA environment or
   when the QA host equals another environment's (D5, D8); no MCP write tool, no deployment in any new workflow.
5. **Secrets** — test passwords only in the SecretProvider; never in state, checkpoints, events, files, logs, API
   responses, or the agent's prompt, files and tool results (51-03 S4 recipe followed; the agent's inherited
   environment is ADR-083's accepted risk). Every folder a run leaves (the Playwright report incl. the zip inside
   `index.html` and trace zips, `<run>/apwt-out`, capture folders) scanned for each test password in raw, JSON- and
   XML-escaped form (51-06 B1: Playwright titles fill steps `Fill "<value>"`).
6. **Agent access to `apwt`** (D3c, ADR-083) — browser agents use `npx --no-install apwt` from the run's workspace
   export (never a global `apwt`) on sessions opened, logged in and closed by program nodes, pinned to the QA host;
   credentials appear only in those program subprocesses' environments, never in the agent's shell, tool results,
   files or logs (51-03 S4 recipe followed); no new node runs with `--trust-all-tools` beyond today's behaviour; the
   accepted risk is written into ADR-083 and Phase 52 is referenced.
7. **Reliability** — the ADR-011 trio on every agent node; healing bounds (F10); `validate_library` green. The
   QA-writing workflows (`test-execution`, `action-capture`, `story-verification`, `setup-composer`) carry no `pre_mutation` gate
   (ADR-082 amends ADR-021, D22), and the HITL lint passes them as written.
8. **Lifecycle** — library items and scenarios change status only through `LifecycleService` (ADR-050); retire/delete
   preconditions; contract rule (D16.5).
9. **Lane order** — every consumer listed in 51-09 §2 updated or proven order-free (L-094); audited transitions.
10. **Finalizers** — bound run, idempotent, reconcile, status stored before announce (L-058, L-061, L-093).
11. **Subprocesses** — timeouts and process groups everywhere (F8); nothing left running after cancel/pause.
12. **DB** — m0026 upgrade from a populated v25 DB; the `kb_test_suites` rebuild preserves rows and cascades; m0027
    (51-08, regression notes) from a populated v26 DB; the collaboration pull's feature tombstone (a generic
    `DELETE FROM {binding.table}`) writes the regression note too (51-08 As built 1). Re-review the two 51-08 nits fixed
    after its SHIP (Run now reads the selection once; the regression scenario body reuses Phase 49's `ScenarioCreate`).
    Re-review the 51-04 m1′ fix, which landed after that sub-spec's SHIP: the runner's `foreign_key_check` comparison
    keys on `(table, rowid, parent)` (not `fkid`), so a pre-existing orphan in a table m0026 gives a new FK column is
    tolerated, and a violation the migration adds is still refused.
13. **Web** — primitives/tokens, no `<Button asChild>`, central `/api`, fixtures = contracts, jest-axe, lazy heavy libs.
14. **`playwright-appian`** — any change is additive, recorded in its `DECISIONS.md`, invariants D-02/D-04/D-05 kept,
    its gates green.
15. **Naming** — no new `test_*` module or symbol outside tests (L-092).

## 2. Gates

genesis: `pytest` + `ruff`; fresh DB → v28 and v25 → v28 with data. web: `lint`, `typecheck`, `vitest`, `npm run build`
byte-identical to the committed `web/static`. genesis-workflows: `validate_library`, `validate_skills`, `pytest
workflows`, plus the cross-repo test that compares `action-capture`'s setup checks with Genesis's save checks (51-16;
it skips in CI because it needs both checkouts side by side, so run it locally). playwright-appian: `npm run lint && npm run typecheck && npm test` (+ `npm run build`). project-tracker:
agent-system tests, `genesis-ctx lint`.

## 3. Live acceptance (local `genesis serve`, the four workflows installed, a real tracked app, a **real QA
environment** with test users for two roles — provided by the user)

| # | Step | Expected |
|---|---|---|
| 1 | Settings → Environments: change the Dev entry's type via the select; add a QA entry; try a second QA; try a QA with the Dev host | Dev unchanged in behaviour (KB sync works); second QA and host collision refused |
| 2 | Settings → CLI card; Install Chromium | Node/Chromium/apwt versions shown; Chromium installed under `~/.genesis/testing/browsers` |
| 3 | Testing → Setup: site URL, two test users with passwords, workspace created | Readiness clear; `~/.genesis/testing/apps/<uuid>/` is a git repo with the template; no password in any file (grep) |
| 4 | Record workflow as role A: create an evaluation, add a factor | Headed Chromium signed in as A; Stop → capture analysing → proposals (new actions, contracts with inputs/outputs) with replay results |
| 5 | Accept two, reject one | One commit; accepted items Ready (replay passed) or Draft; rejected absent |
| 6 | Edit an action: break its contract while used; save code with a type error | Refused; Save as new action works; the typecheck error shows inline; history shows commits; Revert works; the CodeMirror editor reads correctly in light and dark |
| 7 | Edit a file in VS Code | "Changed outside Genesis"; an execution before Adopt runs the old code; Adopt commits |
| 8 | Regression: reference two feature scenarios, create one cross-feature regression scenario, set data setups (one shared, one "changes shared data") | Plan shows 2 setup instances; Run now → execution; the data created matches the plan (count evaluations in QA) |
| 9 | Break one step on purpose (a wrong label in a case script) | Result Failed at that case step; later scenarios on the same setup still run; screenshot + Playwright report open |
| 10 | Make a setup fail (wrong input) | Its scenarios Blocked, other setups' scenarios run |
| 11 | Test Impact → pick objects → Run impacted tests | Only scenarios containing affected automated cases run; uncovered cases listed |
| 12 | Schedule daily at a near time; keep Genesis running | `regression-run` starts it once; header badge updates; turning schedule off stops it |
| 13 | Workbench: drag a story Code Review → Deployment → Verification with no QA env configured (temporarily); then with Testing not ready; then while another verification runs | F2 warning, card stays in Deployment; a `not_ready` refusal lists the problems; a start while another execution runs shows the card **Queued** (movable, both themes); dragging it back to Deployment asks "Cancel the queued verification?" — Keep snaps it back, Move and cancel moves it and cancels the verification ("the card left Verification before the run started", shown on the story page); a move from a second tab and a server restart while queued followed by a move both leave the queue skipping it; when the running execution ends nothing starts for that story — no QA writes, no agent turn; a Verifying card cannot be dragged; check the two 51-14 §5 review notes live and decide whether they need a message: a Move and cancel refused because the run started while the dialog was open snaps the card back silently, and a background board refresh can snap the card back behind the open dialog (as the Design/Implementation confirms already do) (D25 as amended, 51-14 §2/§5) |
| 14 | With QA: drag to Verification; confirm | The card goes "Not started" → "Verifying…"; the run explores as each affected role, authors scripts, executes; report on the story page; passing story → Done; proposals listed. **Re-measure F10 on this write flow:** record each `explore` and `author` turn's duration, tool calls and credits against the 900 s `turn_timeout` (51-09 As built), and change F10 if a turn comes within 20 % of it |
| 15 | A story whose feature is genuinely broken in QA | Product defect → card back to Implementation with the defect list |
| 16 | QA unreachable mid-run (block the host); separately, reach the `escalate` gate (a script defect that heal cannot fix) | `escalate_blocked` shows Retry / Send back / Accept as passed and `escalate` shows Send back / Accept as passed / Stop, both rendered from the gate's options; Stop leaves the card in Verification |
| 17 | Accept verification proposals; once, force a 400 on apply (e.g. a proposal whose code no longer typechecks) | One commit; library + regression updated with the added / already referenced / skipped lists shown; after the 400 the page refetches before the retry succeeds |
| 18 | Cancel a running execution | Run and execution end `cancelled` with exactly one `run.final{cancelled}` (51-15 MJ3); no Chromium/apwt daemon left (`ps`) |
| 19 | Security spot checks | A verification turn's shell commands (turn explorer / `run_events`) show no credential in any output; the sessions used are the program-opened ones on the QA host; grep every run folder of the acceptance runs for each test password (raw, JSON- and XML-escaped), **including a failed or cancelled verification run's `apwt-out`**, which cleanup does not scrub (51-09 As built). Any hit is a blocker |
| 20 | **Real-browser width probe (L-090):** run `genesis/scripts/probes/testing-widths.mjs` (51-15) and add what it does not cover; 1280 / 1440 / 1920 px, light + dark — LibraryView, ExecutionsView (fixed px columns), the execution page and results tree, Regression rows, the Setup users table, the Phase 49 CasesTable with its new Automation column (`min-w-[1072px]` set by eye), the CLI tab with the testing card above the list, and the Record, New item, environment, Verification and **Compose with AI** dialogs (including its library picker table, 51-17) | No clipped key/name columns, no horizontal scroll ≥ 1280; measured widths recorded; widths set by eye replaced with measured ones |
| 21 | Restart `serve` while an execution is queued and one is running | Startup reconcile: finished one finalized, queued one starts (L-058, L-097) |
| 22 | Pause/resume, then the known limits | Pause a running execution: it shows `paused` (not failed), Resume continues from the checkpoint and finishes (ADR-009; 51-15 B3); pause one that answered a gate earlier, restart `serve`, and it still shows `paused` with Resume (51-18 R-m1). Then confirm the accepted limits: a paused or gated verification or execution does not hold the one-at-a-time queue (51-06/51-09 As built); resuming it while another runs overlaps them, and nothing else breaks. A card moved out of Verification by a path other than the move routes (e.g. a collaboration pull) in the instant between the launch's last lane check and the run start still lets that verification run once; the finalizer ignores its result (51-14 review nit, accepted 2026-11-04, Q26) |
| 23 | Setup jobs and library Replay, live (51-10 review) | Install Chromium / Create workspace / Update testing runtime each answer 202 and the UI polls to `succeeded`; a second click returns the running job; a **data setup's** Replay on QA runs as a `library-replay` job (actions have no Replay; their page offers Run dependents, D28), a repeat returns the same job, Cancel ends it `cancelled` with no result recorded and nothing left in `ps`, and after either end the page stops polling and shows the result with Open report and the screenshot from the reports origin (51-15 B1, D29); an action becomes Ready after Run dependents passes; restarting `serve` mid-job gives 404 and the Setup view refreshes; no password in any job error or result |
| 24 | Report iframe isolation (51-11 As built; D26 built in 51-15): run `genesis/scripts/probes/reports-origin-isolation.mjs` against each instance, then open an execution's Playwright report on the execution page and the story page | The iframe works **without** `allow-same-origin`. If the report needs it, it must be served from a different origin than the SPA (with `allow-same-origin` on a same-origin URL the sandbox does nothing, so report scripts could call `/api`); record which. A report that can reach `/api` is a blocker |
| 25 | Settings → Environments against the live backend (the 51-11 field mapping was built from source) | The Type select's single-Dev, single-QA and host-collision refusals show as field errors with the server's messages |
| 26 | Record with **Also make a data setup** ticked (name + end state "an evaluation in In Progress; output its id") (51-16, D34). **Before:** install `action-capture` ≥ 0.2.2 (51-18) and the `genesis-test-authoring` skill ≥ 0.3.0 (Record refuses a setup request otherwise) | Proposals: the actions plus one setup that uses them in order, `unique()` values, the id as an output; the replay runs **only the setup**; the panel shows "uses …" and "replay passed in P<n>"; Accept with an action rejected is refused naming it; Accept all → one commit with the actions' `ACT-` keys before the setup's `DS-` key, the setup and its actions Ready, reused Draft actions Ready with "capture #N" as evidence; a scenario using the setup passes in Run now |
| 27 | Testing → New data setup → **Compose with AI**: pick a setup and an action of a second role, end state "an evaluation in Approved" (51-17, D35, D36). **Before:** `genesis install setup-composer` (≥ 0.1.1) and `action-capture` (≥ 0.2.2), the `genesis-test-authoring` skill 0.3.0 from the Skills catalog (compose refuses 409 without both), and a second test user with a password | A "Composed" capture goes `analysing` → one setup proposal with `roles: [...]` and its added items listed, replayed as both roles (the generated config has an `auth:` project for the extra role and the setup project depends on it); Accept → a Ready `DS-` item, with the Draft actions it used Ready through "capture #N"; a scenario on it passes. A second compose whose end state needs a step no library item does ends as a ready capture with no proposal, the step named, **Record workflow** prefilled with it, and Discard. The compose dialog and its picker are in the step-20 width probe (not run in a real browser yet) |

### Re-run scope (after 51-15–51-17)

Before the re-run, back up each instance's `genesis.db` and run `genesis db upgrade` (DB 27 → 28, m0028), then
restart `serve` on each instance **with no run active** (L-061), so the reports listener (D26)
starts on :8860 / :8861 and the 51-15 run-manager fixes (pause, cancel, mi-2 refusals on a finished run) are live
(51-15 As built). The execution page has no Back button since 51-15; the breadcrumb is the way back.

**After 51-18:** install `test-execution` 0.1.1, `action-capture` 0.2.2 and `setup-composer` 0.1.1, then restart
`serve` with no run active (no migration; DB stays v28). Expect:
- existing workspaces to be offered **Update testing runtime** for the new `tsconfig.json` (`noUnusedLocals`); if
  existing code has unused imports, the update stops and names them;
- the first save or compose to add an "Update Genesis's lib/ helpers" commit;
- an action to become Ready only when its own `ACT-… <name>` step passed in the report;
- **Remove script** on the case page, a restored action reading Draft, and a paused run staying paused across a
  restart (step 22).

Re-check 51-18's delta-review m5 fix live, which landed after its second SHIP: Remove script is refused while a story
verification that uses the case is running.

The re-run repeats §1 and §2 on the whole Phase 51 diff and runs **every** §3 step, including the ones the first pass
could not run (12, 13–17 with the F10 re-measure, 19, the rest of 23 and the Verification dialog part of 20), and
re-checks each first-pass finding against its 51-15 fix. Clean up the first pass's leftovers first, with the user:
the `example-qa2` environment, `DS-000002`, `ACT-000005`, the edited `TC-000007`/`TC-000017` scripts (the user decides
whether to revert them), and the "Genesis 51-12 regression" evaluations in QA (the user, in Appian).

## Context manifest

```toml
areas    = ["release-ci", "security"]
adrs     = ["ADR-001", "ADR-011", "ADR-012", "ADR-029", "ADR-050", "ADR-061", "ADR-068", "ADR-077"]
lessons  = ["L-058", "L-069", "L-088", "L-089", "L-090", "L-092", "L-093", "L-094", "L-097"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:agent-system/skills/genesis-live-acceptance/SKILL.md"]
code     = ["genesis/genesis/testexec/**", "genesis/genesis/api/testing.py"]
upstream = ["51-02", "51-03", "51-04", "51-05", "51-06", "51-07", "51-08", "51-09", "51-10", "51-11", "51-14", "51-15", "51-16", "51-17", "51-18"]
```
