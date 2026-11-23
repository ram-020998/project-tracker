# 55-09 — Web: the Documents tab revamp and the Resolve tab

> **Status:** SPEC-DRAFTED 2026-11-22. Repo: genesis (`web/src/features/run-detail/`, `web/src/features/chat/`,
> `web/src/features/notifications/`). Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**.
> Decisions: D7, D8, D9, D12–D15 (`55-01-findings.md`). The 55-02 mockups are **approved** (D12, at genesis `d0aa1b2`):
> build what `/dev/phase-55` shows, with D13–D15.

## 1. Documents tab (`components/docs/`)

- Replace the flat rail (`DocumentsTab.tsx:74-165`) and the filename "Result" regex (`doc-utils.ts:20`) with the
  approved layout, fed only by `GET /runs/{id}/documents` (55-05/55-08): search; **By step** (default) / **By type**
  toggle (persisted pref); groups Output (pinned, auto-selected) · Inputs · Steps in graph order (files, check pass/fail,
  "Prompts (n)") · Tool outputs (metadata; "files removed at the end of the run" once gone, D9) · System (collapsed).
- Row: label, file name, step, relative written time (exact on hover), size, "written N times · latest" only when
  `writes > 0` (0 = unknown on old runs: show nothing; tooltip: earlier writes are not kept, D12); "being written"
  for a zero-byte file during its node (`writing`, true only while the run is running, 55-08). The memory brief sits under
  Inputs with the step "Run start (before the first step)"; System is kept, collapsed, in By type too (D12).
- Pseudo-steps from 55-05/55-06: `_launch` files (uploads, a test checkout) under Inputs as "Run start"; `_memory`
  (the brief); `_resolve` as "Fixed in Resolve"; `_parallel` rows named with their nodes and no step. Prompt labels
  "Turn k · <item>" as built. A list-form workflow (no roles declared) still shows each file's step.
- **System files are listed but neither previewed nor downloadable** (`_kiro/`, `.kiro/`, `.pids/`, `checkout/`):
  `_kiro/` holds the run's Kiro home (settings, sessions, logs), not yet confirmed free of secrets (55-05 review).
- A validator step whose check failed reads "OK · check failed N times" (D12 n3).
- Viewer header: category, step · pass · attempt, written time, size, write count, **Open in step** (selects the node
  in the graph inspector), Download; the existing previews (`DocumentViewer.tsx`, `DocumentPreview`) unchanged; agent
  HTML keeps its sandboxed frame / CSP (54-10 §1 9b).
- Old runs: name-rule categories, "step unknown", the one-line note (F12).
- Polling: refetch while active on the same rhythm as the graph — on each `/live` lifecycle hint (a `node.completed`
  is when a node's files are diffed, 55-05) and the 3 s poll floor — never per keystroke; no new hint kind.

## 2. Resolve tab (D14)

- A **Resolve** tab in Run Detail beside Flow and Documents, with the facts sidebar on the right, as approved in
  `/dev/phase-55` (genesis `d0aa1b2`); reached at the SPA route `/runs/:runId/resolve` (registered before any generic
  run route, L-096). Shown when the run waits at an escalation gate, and kept readable afterwards for the history.
  Key it on `snapshot.run.status`, `snapshot.run.gate` (which carries the 55-06 payload) and `active_nodes` from
  55-03's `useRunSnapshot`; do not add a second poll of the run.
  The run pill of a run waiting at an escalation gate reads "Needs you" (D12 n1): change `statusMeta` for the
  escalation-gate case (55-03 left it unchanged).
- Not opened yet: the summary strip (failed step, one-line reason, **Open Resolve**) → `POST /runs/{id}/resolve`.
- The conversation reuses the chat components (`ChatThread`, composer, the turn stream) bound to the Resolve session;
  no second chat UI.
- **Proposal cards** from `resolve.proposal` events: action, parameters (editable guidance text for retry; an
  **instructions** text box for "Rerun from the start with additional instructions" — no input form, the run's inputs
  are reused, D13; the step picker for restart from a step; the diff for fix-then-accept; the reason for stop),
  rationale, Confirm / Dismiss; stale and superseded states. Labels and hints as the mockup's `ACTIONS`.
- **Manual action menu**: the six actions without the agent, same dialogs, same routes.
- Unavailable actions disabled with their reason from `allowed` (L-106). Stop and fix-then-accept use a confirm
  dialog. The relaunch and restart-from dialogs say that the feature stage (or story) moves to the new run and that
  this run ends Cancelled and links to it (D13, D15).
- After an action: its result shown **inside the Resolve tab** (D14) — the outcome note in the thread and the result
  card as mocked, with a link to the new run for relaunch and restart from a step; the graph and Documents refresh
  through 55-03.
- Credits of the conversation shown in the tab ("This chat") with provenance, and included in the run header's total
  (ADR-032, D12).
- The legacy gate panel (`hitl/HitlBar.tsx` `GatePanel`) stays for approval / pre_mutation / review gates and for a
  legacy escalation payload; Feedback there maps to retry with guidance (55-06).

## 3. Bell

The `needs_you` escalation notification (55-07) links to `/runs/<id>/resolve`; opening it does not start the agent
(opening Resolve does), and it shows as read once the gate is answered (D12 item 8).

## 4. Tests and probes

Vitest per state of 55-02 (documents: live, finished, old run, no output, several outputs; resolve: not opened, first
turn, proposals, each confirm, stale, unavailable, each action's result in the tab); the `/runs/:runId/resolve` route;
jest-axe on each new view (L-014); a real-browser width probe at
1280 / 1440 / 1920 px, light and dark, for the Documents list and the Resolve tab, screenshots in As built (L-090);
token colours only (L-123); no `Button asChild` (L-069).

## 5. Gates

`cd genesis/web && npm run lint && npm run typecheck && npm test`; `npm run build`, then commit `web/static/` as a
separate step, checked with `git show --stat <sha> -- web/static` after the build settled (L-089).

## Context manifest

```toml
areas    = ["web-runs", "web-shell", "chat"]
adrs     = ["ADR-009", "ADR-027", "ADR-028", "ADR-032", "ADR-033", "ADR-055", "ADR-066"]
lessons  = ["L-007", "L-011", "L-014", "L-015", "L-069", "L-089", "L-090", "L-096", "L-106", "L-123"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/55-02-mockups.md"]
code     = ["genesis/web/src/features/run-detail/**", "genesis/web/src/features/chat/**", "genesis/web/src/features/notifications/**"]
upstream = ["55-02", "55-03", "55-05", "55-07", "55-08"]
```
