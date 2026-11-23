# 55-11 — Review, hardening and live acceptance (Phase 55 only)

> **Status:** SPEC-DRAFTED 2026-11-22. Repos: genesis, genesis-workflows. Parent:
> `specs/phase-55-workflow-execution.md`. Run by **genesis-review** (read-only on code) after 55-02..55-10 are BUILT;
> report in `specs/phase-55-workflow-execution/reviews/55-11-review.md` with SHIP / NEEDS_CHANGES. Findings are fixed
> by genesis-dev before the release, each with a regression test. **D11:** the release waits for §3; the open Phase
> 51/53/54 acceptance is not part of it.

## 1. Independent review (file:line evidence each; plus `genesis-ctx check --since <phase base>` per repo)

1. **Memory brief (ADR-088 draft, D2–D5, D17, F1–F5):** built only for `op == "run"`, only with an agent node, honours
   `memory_brief: false`; never fails a run on any error path; personal memories only in their section and never in
   anything published to the Hub; the brief marked as data; the memory MCP trusted for exactly its six read tools on the
   real projection; the embedder never loaded in the web process (ADR-054); the model never downloaded inside a run.
   **Review genesis `419d8363`** (55-04's review fixes: not re-reviewed, full suite not re-run after it).
2. **Escalation (ADR-089 draft, D6, F6, F8):** every action routed and stored as specified in every adopted workflow
   (L-106); Reject / stop ends `failed`, never `done`; accept and fix-then-accept refused when unavailable; the agent
   cannot answer a gate, relaunch, fork or stop (ADR-033) — only `propose_action`; every action audited on the run's
   events with actor, source, action, parameters and proposal id (D22); relaunch
   cancels through the stop-intent + CAS path with no second `run.final` (L-108); rerun reuses the inputs unchanged
   and puts the instructions in every agent node's prompt (D13); restart from a step cancels the original and moves
   the binding before the new run starts (D15); bound runs rebound (L-061); the
   lint refuses an escalation that is not the standard gate; payload and action names match the approved mockup (D12);
   `relaunchable` defaults to false and is read through one reader; no workflow using `appian-dev-write` can be
   relaunched or restarted whatever its flag says (D23, ADR-068).
   From 55-06's As built: the untested path where a relaunch's rebind raises after the old run was cancelled; a fork
   whose process exits before its final event is applied (n4); a relaunch skips the stage re-run's prerequisite checks
   and reads the old snapshots (decision 5a, inherent to D13); queue-managed workflows refused; the launch environment
   is not stored (m1, as for resume).
3. **Resolve chat (ADR-031/034/086):** no shell; writes only in the sandbox; activation verified (L-113); a write outside
   the sandbox and an unlisted tool refused live (negative control, L-117).
4. **Liveness (ADR-090 draft, D10, D16):** `node.started` canonical in both lists and the fixtures (L-122); the snapshot fold
   is incremental (no whole-log read per call, L-066); SSE never replays the log, honours `Last-Event-ID`, bounded
   queues, cleanup shielded (L-118); edges lit only into a running node; cursor semantics unchanged for its other
   readers (L-094). 55-03 was reviewed SHIP on its own; re-check only what later sub-specs changed in its files.
   Not covered by 55-03: edge counts under a parallel fan-out, and two `serve` processes watching one live run (the
   second relies on the 3 s poll by design).
5. **Documents (D8, D9, D20, F10–F12):** categories by rule, not by guessed names; tool-output files still purged at the end;
   old runs fall back honestly; agent HTML never runs on the app's origin; 55-08's `legacy` and `writing` fixes; no
   System file previewable; the fan-out start order under the real runner (55-05 did not spike it).
6. **Contracts (55-08):** fixtures from real responses; route order proven (L-096); m0031 (if built) forward-only
   (L-102).
7. **genesis-core (ADR-019):** additive; `CORE_MAJOR` 1; an old library version still runs (legacy escalation payload).
8. **Web:** tokens only, no `Button asChild`, jest-axe on new views.
9. **ADR drafts** match what was built (`adr-drafts.md`).

## 2. Gates

genesis-core, kiro-agent-sdk, genesis (pytest, ruff); web (`npm run lint && npm run typecheck && npm test`, `npm run
build` + committed `web/static/`); genesis-workflows (`ci/validate_library.py`, skills validation, pytest); one CI run
or a run in the CI image before the release commit (L-112) — **with fastembed installed on the python:3.13 image**
(55-04 proved the offline model load on macOS only; the CI test jobs install with `--no-model`, so add one job or one
image run that fetches the model and loads it with the network off, on Linux).

## 3. Live acceptance (the release candidate on a copy of the user's real Genesis home)

**Set-up:** copy `~/.genesis` to a throwaway folder (mode 700) with SQLite's online backup for `genesis.db` and
`memory.db` (L-125); start the candidate on another port against the copy; collaboration and system schedules off on
the copy except what a row tests; Appian writes only with the user's go-ahead; the user sets the credit budget before
the agent rows; never print, commit or attach the copy's files; delete it at the end. **No memory text in any commit
(D19):** a brief, a captured prompt, a Resolve sandbox file or a tool output that carries memory text is shown to the
user locally and committed to `evidence/` only redacted (ids, types, scores, lengths). The fleet is not restarted.

| # | Check | Pass |
|---|---|---|
| A1 | Mockup sign-off carried through: Documents, the Resolve tab and graph states match the approved `/dev/phase-55` (genesis `d0aa1b2`, D12–D15) | user confirms |
| A2 | **Graph liveness** on a long run (technical-design-analysis or test-design-analysis on a real feature): program nodes show running; a minutes-long agent node shows running throughout with elapsed time; only the edge into the running node is lit; a loop re-entry shows round 2; at five random moments the graph equals the event log within 3 s | as stated |
| A3 | **Liveness under faults:** block the SSE (devtools offline for the stream, or stop the proxy) → badge Polling, graph still current within 3 s; reconnect resumes without replaying; restart `genesis serve` mid-run (no other run active) → the snapshot rebuilds; pause / resume and a gate show correctly | as stated |
| A4 | **Memory brief:** after `scripts/install-packages.sh`, the embedder is ready and the back-fill embedded every current memory (count); three real runs (a feature-stage, a story and an agent-prompt run) each have `_memory/brief.md`; the user reviews them for relevance, **including the two 55-04 calls (D17):** memory #27 is not in the feature-4 brief (ranking), and a run with no context still gets 12 weakly related memories (no minimum similarity); the captured prompts carry the line; the memory jobs and a sync run have none; **live negative control:** in the same run an agent asked to call a tool outside the six memory tools and its node's own list is refused | user reviews the briefs |
| A5 | **Escalation, stage workflow:** a real escalation of a stage run (a forced validator failure on the candidate, or a real one); the bell notice opens `/runs/<id>/resolve` without starting the agent; opening Resolve starts it and its first turn explains the failure and proposes actions; **accept** → `done`, the stage shows the artifact (finalizer); a second escalation → **fix then accept** with a reviewed diff | as stated |
| A6 | **Escalation, every action:** on cheap runs (agent-prompt / hello-appian with a forced failure): retry with guidance (guidance in the captured prompt, run continues); **rerun from the start with additional instructions** (the new run has the same inputs, the instructions are in every agent node's captured prompt and survive a pause/resume, the old run `cancelled` and linked; on a stage-bound run the stage moves to the new run, D13); **restart from an earlier step** (the new run starts from that step's checkpoint and runs, the original's checkpoints unchanged, the old run `cancelled` and linked, a stage-bound run's stage moves to the new run, D15); stop (`failed`, reason shown); an unavailable action disabled with its reason; a stale proposal refused; **Rerun and Restart disabled with their hint on a non-relaunchable workflow** (story-implementation, if one escalates; else a fixture workflow with `relaunchable: false`, D23); each result shown in the Resolve tab (D14) | as stated |
| A7 | **Resolve safety:** ask the agent to apply an action itself, write outside its sandbox, run a shell command → each refused | as stated |
| A8 | **Documents:** the four stage workflows, story-implementation, test-execution and one old run: every file in the right category and step; Output pinned; write counts after a retry; tool outputs as metadata after the end; Open in step; **during a real agent run**, `file.written` rows arrive per task finish and `/documents` shows "being written" only while running (not when paused or at a gate); System files not previewable; known limits shown honestly (a file written before a pause-kill reads "step unknown", 55-05) | as stated |
| A9 | **Width probe** (L-090): Documents and Resolve at 1280 / 1440 / 1920 px, light and dark, screenshots | no overflow, user confirms |
| A10 | **Credits:** the Resolve conversation's credits are metered with provenance on the panel (ADR-032) | as stated |

Rows that cannot run (e.g. Dev down for a stage run) are recorded "not run" with the reason and named in the release
notes (L-111).

## Context manifest

```toml
areas    = ["runs-worker", "web-runs", "chat", "workflows-library"]
adrs     = ["ADR-011", "ADR-019", "ADR-031", "ADR-032", "ADR-033", "ADR-034", "ADR-053", "ADR-054", "ADR-086"]
lessons  = ["L-061", "L-066", "L-090", "L-094", "L-106", "L-108", "L-110", "L-111", "L-112", "L-113", "L-117", "L-122", "L-125"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/adr-drafts.md", "tracker:specs/phase-54-schedules-and-fixes/54-10-review-and-acceptance.md"]
code     = ["genesis/genesis/runs/**", "genesis/genesis/memory/brief.py", "genesis/web/src/features/run-detail/**"]
upstream = ["55-02", "55-03", "55-04", "55-05", "55-06", "55-07", "55-08", "55-09", "55-10"]
```
