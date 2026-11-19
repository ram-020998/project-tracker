# 54-10 — Review, hardening and live acceptance

> **Status:** SPEC-DRAFTED 2026-11-19. Repos: genesis, genesis-workflows. Parent:
> `specs/phase-54-schedules-and-fixes.md`. Run by **genesis-review** (read-only on code) after 54-02..54-09 are BUILT;
> report in `specs/phase-54-schedules-and-fixes/reviews/54-10-review.md` with SHIP / NEEDS_CHANGES. Findings are fixed
> by genesis-dev before the release; each fix gets a regression test. **D20: the release waits for §3.**

## 1. Independent review (file:line evidence for each; plus `genesis-ctx check --since <phase base>` per repo)

1. **Unattended trust (D2, D3):** the `agent-prompt` node's projected agent has exactly Phase 53 D9's built-ins, never
   `delete_file`; no server outside `pickable_servers` can reach a schedule, a custom agent, the node or a chat
   session, checked at create, update, fire and node start; the classification test covers every curated registry
   name; `appian-dev-write`, `appian-dev-packages`, `appian-devops`, `jira`, `jarvis`, `appian-data-generator` refused.
2. **Chat (D6, ADR-031/034):** a session with a custom agent has no shell, writes only in its sandbox, only read-only
   MCP tools; activation verified (L-113); other modes reject `agent_id`.
3. **Engine rules (D8, D10, D12, D30, D31):** missed/overlap/gate/timeout/failure logic matches 54-04 §3 and its As
   built; every cancel goes through the stop-intent + CAS path (L-108); every handler reaches a terminal `schedule_runs`
   row on every error path (L-107); the tick runs only under the run-owner lock (L-097). **Review `9a365c0`** (54-04
   m3, a past `once` cannot be turned on): fixed after 54-04's SHIP and not yet reviewed.
4. **Migration (L-081, L-102, L-103):** m0030 forward-only; user-modified app sync kept; regression entries became rows
   once; `regression-run` not re-created by `ensure_defaults`; deleting a schedule removes its `schedule_runs` rows.
5. **Credits (ADR-032):** history credits come only from metered run usage, with provenance; no estimate.
6. **Contracts (54-06):** fixtures from real responses; removed endpoints have no remaining consumer (L-094); route
   order proven (L-096).
7. **Fixes (54-02):** each has its failing-first test; B2's old `custom` rows fold.
8. **genesis-core (ADR-019):** the `kiro_node` change is additive; `CORE_MAJOR` = 1; every existing workflow's tests
   pass unchanged.
9. **Web:** tokens only, no `Button asChild`, jest-axe on new views, no removed component still imported.
10. **ADR draft** matches what was built (`adr-drafts.md`), including ADR-049's navigation list.

## 2. Gates

genesis-core (pytest, ruff), kiro-agent-sdk (pytest, ruff), genesis (pytest, ruff), web (`npm run lint && npm run
typecheck && npm test`, `npm run build` + committed `web/static/`), genesis-workflows (`ci/validate_library.py`,
skills validation, pytest), one CI run or a run in the CI image before the release commit (L-112).

## 3. Live acceptance (separate `genesis serve` on the release candidate, the user's real login; D20)

| # | Check | Pass |
|---|---|---|
| A1 | Mockup sign-off carried through: each new and revamped page matches the approved mockup (`/dev/phase-54` at genesis `b09b08e`, D22–D28) | user confirms |
| A2 | **Agent-prompt schedule:** create a custom agent (instructions + one managed skill + `genesis-kb`), schedule a prompt "once" 2 minutes ahead; it fires, writes `output.md`, the run shows it in Run Detail's documents, history shows the run with metered credits; repeat with `appian-dev` if Dev is up (else recorded as skipped, D20) | as stated |
| A3 | **Workflow schedule:** `sync-documents` (or another flagged workflow) with stored inputs, every 1 h window; Run now; history; Runs list badge links back | as stated |
| A4 | **Regression schedule:** an app's migrated row (or a new one from Testing → Setup's link) starts a `TE-` execution on QA (if QA is up; else recorded) | as stated |
| A5 | **Missed slot:** stop `genesis serve` across a slot, start it within grace → one catch-up run; across two slots → one run + one `missed` row + one bell notice; a `once` beyond grace → `missed` and completed | as stated |
| A6 | **Overlap:** a slot due while the previous run is still running → `skipped` with the reason | as stated |
| A7 | **Gate wait:** a schedule whose run reaches an escalation gate (an `agent-prompt` prompt that cannot produce output, or a fixture) → "needs you" notice; unanswered → cancelled at the next slot / max wait, `failed` "gate not answered", no second `run.final`; a run answered at its gate after a while, or paused by hand and resumed, is not cancelled as "timed out" because of that idle time (D31), also across a `genesis serve` restart while it waits | as stated |
| A8 | **Failures:** three failing runs → Paused (failing) + notice; Resume clears; a readiness skip (sign Kiro out, or uninstall the workflow) is `skipped`, not a failure; a regression run with red tests is `failed` with a notice but does not count toward the pause (D30) | as stated |
| A9 | **System rows:** app sync edited from its row (all former Settings fields), runs from Run now; document sync shows `failed` when its run fails; Reset to default; Settings → General has no sync card | as stated |
| A10 | **Catalog → Agents:** create, edit, Run once, delete refused while a schedule uses it; a model change while the model list cannot be read is refused (D35); an agent whose skill was uninstalled shows which field blocks a save | as stated |
| A10b | **Agent-prompt live turn (54-05 could run none live):** a real v3 turn with a per-run model, a provisioned managed skill and a picked server (`genesis-kb`), and one with a custom server marked read-only (D32); the turn's projected agent lists only those servers; at the escalation gate, **Feedback** re-runs the agent with the note in its prompt and Reject ends the run failed | as stated |
| A11 | **Chat with a custom agent:** read-only session, the agent's instruction visibly applied, an installed skill used, a picked server's read tool used; a mutating or shell request refused with the notice, and a picked server's non-allowlisted tool refused on the wire; a custom server with no allowlist not started, with the notice (D43); resume after a `genesis serve` restart keeps the agent; deleting the agent from Catalog → Agents while its chat is open leaves the chat working; in a real browser, both themes, the New chat panel (focus returns on close), the agent header and the list marker. Re-run `scripts/spikes/54-08/probe_chat_agent.py` against the release candidate (0 credits) | as stated |
| A12 | **Bell:** notices from A5/A7/A8 listed, mark read, mark all read, links open the right page | as stated |
| A13 | **Fixes (54-02, as built):** B1 edit a paused run's state and a gated run's state → each keeps its status, no `run.final` row, a `state.edited` note in the events, resume runs the edit; a failing edit answers 400 and leaves the run as it was; B2 a run that saves tool output shows the per-turn artifact list, and an old run stored before the fix shows its artifacts too; O1 discard a failed compose, and discard a compose waiting at its gate (a confirm dialog, then its run is cancelled with one `run.final`); O4 add, make Dev (`POST /config/environments/dev`) and delete an environment labelled `https://example-qa2.appianpreview.com`; an unknown `/api` path answers 404 JSON for GET and DELETE, a real route with the wrong method 405 | each reproduced on v0.82.0 first, then passes |
| A14 | **UX revamps:** story Design, Implementation (Objects changed table), Verification tab; feature Overview (Needs attention across stages), Activity (all stages, filter, paging) on a real feature with history | as stated |
| A15 | **Width probe (L-090):** the Schedules list and history, Agents tab, bell popover, story Implementation objects table, feature Activity at 1280 / 1440 / 1920 px, light and dark, in a real browser; plus the `MultiSelect`, row menu and `TimeInput` (24-hour, D29) driven by keyboard only (focus kept after removing a chip, names match visible text) | no overflow or clipping; keyboard path works |
| A16 | **Process hygiene:** after A2–A11 no stray `kiro-cli` or MCP processes (`ps -ww`, L-104) | none |
| A17 | **54-07 rows it could not run offline:** a scheduled run waiting at a gate (row tint, banner, Open run, the tooltip's cancel time); Run now on a real run with the run link appearing; Delete and Reset to default through the row menu's confirm dialogs; Kiro's real model list in the wizard and the agent editor; the migrated regression and app-sync rows on the Schedules page; the bell with real scheduler notices. Re-run `scripts/probes/phase54-pages.mjs` against the release candidate's own throwaway server (never the fleet before the release, D36) | as stated |

## As built

_(genesis-review / genesis-dev fill in: review rounds, fixes with commits, live rows with evidence.)_

## Context manifest

```toml
areas    = ["runs-worker", "web-shell"]
adrs     = ["ADR-011", "ADR-021", "ADR-031", "ADR-047", "ADR-049", "ADR-068", "ADR-073", "ADR-083", "ADR-086"]
lessons  = ["L-081", "L-089", "L-090", "L-094", "L-096", "L-097", "L-102", "L-103", "L-104", "L-107", "L-108", "L-110", "L-111", "L-112", "L-113"]
docs     = ["tracker:specs/phase-54-schedules-and-fixes.md", "tracker:specs/phase-54-schedules-and-fixes/54-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/adr-drafts.md"]
code     = ["genesis/genesis/runtime/scheduler.py", "genesis/genesis/runtime/schedule_store.py"]
upstream = ["54-02", "54-03", "54-04", "54-05", "54-06", "54-07", "54-08", "54-09"]
```
