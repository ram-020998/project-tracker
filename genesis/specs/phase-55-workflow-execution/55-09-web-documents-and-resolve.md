# 55-09 — Web: the Documents tab revamp and the Resolve panel

> **Status:** SPEC-DRAFTED 2026-11-22. Repo: genesis (`web/src/features/run-detail/`, `web/src/features/chat/`,
> `web/src/features/notifications/`). Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev**.
> Decisions: D7, D8, D9 (`55-01-findings.md`). **Starts only after the user approved the 55-02 mockups**; build what was
> approved, with the changes recorded in 55-01 §9.

## 1. Documents tab (`components/docs/`)

- Replace the flat rail (`DocumentsTab.tsx:74-165`) and the filename "Result" regex (`doc-utils.ts:20`) with the
  approved layout, fed only by `GET /runs/{id}/documents` (55-05/55-08): search; **By step** (default) / **By type**
  toggle (persisted pref); groups Output (pinned, auto-selected) · Inputs · Steps in graph order (files, check pass/fail,
  "Prompts (n)") · Tool outputs (metadata; "files removed at the end of the run" once gone, D9) · System (collapsed).
- Row: label, file name, step, relative written time (exact on hover), size, write count, latest mark; "being written"
  for a zero-byte file during its node.
- Viewer header: category, step · pass · attempt, written time, size, write count, **Open in step** (selects the node
  in the graph inspector), Download; the existing previews (`DocumentViewer.tsx`, `DocumentPreview`) unchanged; agent
  HTML keeps its sandboxed frame / CSP (54-10 §1 9b).
- Old runs: name-rule categories, "step unknown", the one-line note (F12).
- Polling: refetch while active (or on a 55-03 `file.written` hint if the live stream carries it), never per keystroke.

## 2. Resolve panel

- Placed as the user chose in 55-02 (side panel or tab). Visible when the run waits at an escalation gate, and kept
  readable afterwards for the history.
- Not opened yet: the summary strip (failed step, one-line reason, **Open Resolve**) → `POST /runs/{id}/resolve`.
- The conversation reuses the chat components (`ChatThread`, composer, the turn stream) bound to the Resolve session;
  no second chat UI.
- **Proposal cards** from `resolve.proposal` events: action, parameters (editable guidance text; the input form
  prefilled for relaunch, built with `buildLaunchForm`; the step picker for restart; the diff for fix-then-accept; the
  reason for stop), rationale, Confirm / Dismiss; stale and superseded states.
- **Manual action menu**: the six actions without the agent, same dialogs, same routes.
- Unavailable actions disabled with their `why_not` (L-106). Stop and fix-then-accept use a confirm dialog.
- After an action: the outcome note in the thread and a link to the new run (relaunch, fork); the graph and Documents
  refresh through 55-03.
- Credits of the conversation shown with provenance (ADR-032).
- The legacy gate panel (`hitl/HitlBar.tsx` `GatePanel`) stays for approval / pre_mutation / review gates and for a
  legacy escalation payload; Feedback there maps to retry with guidance (55-06).

## 3. Bell

The `needs_you` escalation notification (55-07) links to Run Detail with the Resolve panel open.

## 4. Tests and probes

Vitest per state of 55-02 (documents: live, finished, old run, no output, several outputs; resolve: not opened, first
turn, proposals, each confirm, stale, unavailable); jest-axe on each new view (L-014); a real-browser width probe at
1280 / 1440 / 1920 px, light and dark, for the Documents list and the Resolve panel, screenshots in As built (L-090);
token colours only (L-123); no `Button asChild` (L-069).

## 5. Gates

`cd genesis/web && npm run lint && npm run typecheck && npm test`; `npm run build`, then commit `web/static/` as a
separate step, checked with `git show --stat <sha> -- web/static` after the build settled (L-089).

## Context manifest

```toml
areas    = ["web-runs", "web-shell", "chat"]
adrs     = ["ADR-009", "ADR-027", "ADR-028", "ADR-032", "ADR-033", "ADR-055", "ADR-066"]
lessons  = ["L-007", "L-011", "L-014", "L-015", "L-069", "L-089", "L-090", "L-106", "L-123"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/55-02-mockups.md"]
code     = ["genesis/web/src/features/run-detail/**", "genesis/web/src/features/chat/**", "genesis/web/src/features/notifications/**"]
upstream = ["55-02", "55-03", "55-05", "55-07", "55-08"]
```
