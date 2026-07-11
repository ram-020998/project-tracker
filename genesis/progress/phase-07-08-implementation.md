# Genesis — Phase 7.8 (Web Revamp: Node Inspection, Kiro Conversation & HITL) Implementation Record

> As-built record of `specs/phase-07-08-node-inspection-conversation-hitl.md` — where the
> platform's full HITL power finally reaches the UI. **Frontend-only** (the 07-02 data plane
> already exposed everything needed). Part of milestone M7.1.

**Date:** 2026-07-11 · **Status:** ✅ COMPLETE — committed `b23c5b1` (42 web tests, tsc
strict, temp vite build OK). **No backend/core change → no release** (genesis stays v0.10.0).
Build-alongside (served `static/` untouched — cutover 07-10).

---

## 1. Summary

The Run Detail inspector is now a real **tabbed node inspector** with the **live Kiro
conversation** as its marquee tab, and a prominent **HITL bar** that surfaces all three HITL
modes from **durable run state** (`run.status` + `run.gate`) — never from a transient event.
This structurally delivers the ADR-028/07-02 "approval-from-durable-state" guarantee to the
UI: the gate controls are correct after reload/restart.

**No new dependencies.** Everything composes from the 07-03 design system + the 07-02 APIs.

---

## 2. Backend contract (already present — verified, not changed)

07-08 is entirely frontend. The endpoints it consumes all shipped in 07-02/Phase-5:
`GET /runs/{id}` (returns `.gate` = GateDescriptor via `manager.pending_gate`, durable-first),
`GET /runs/{id}/events?node=&kinds=`, `GET /runs/{id}/state`, `POST /respond`, `POST /pause`,
`POST /resume`, `POST /cancel`, `PATCH /state` (guardrails via `check_editable`), `POST /fork`
(ADR-025). The GateDescriptor shape (`{node, kind, prompt, options, context_refs, raised_at}`)
and the `agent.*` payloads were read from `genesis-core` (`hitl_gate`, `kiro_node`,
`reliability.py`) and mirrored in the FE types + fixtures so a drift fails a test.

---

## 3. Data layer additions (`lib/`)

- `lib/api/client.ts` — added a `patch()` verb (state edits are `PATCH /runs/{id}/state`).
- `lib/api/runs.ts` — added `state`, `resume`, `respond(decision, gate)`, `patchState(patch)`
  (wraps body as `{patch}`), `fork(asNode, values)`; exported the `GateDecision` type
  (`string | {feedback}`).
- `types/run.ts` — added the typed `GateDescriptor` + `GateKind` (mirrors `hitl_gate`), and
  typed `RunRecord.gate`.
- `query/keys.ts` — added `runs.state(id)`.
- `features/run-detail/hooks.ts` — added `useRunState`.
- `features/run-detail/hitl-hooks.ts` (new) — `useRespondGate / usePauseRun / useResumeRun /
  useCancelRun / usePatchState / useForkRun`, each reconciling the detail+events+steps+state
  caches and toasting (patchState stays silent — the dialog surfaces the 400 inline).

---

## 4. Conversation transcript (`conversation.ts` + `components/inspector/Conversation.tsx`)

- **`buildTranscript(events)`** — a **pure**, framework-free fold of a node's `agent.*` +
  `validator.result` / `retry.scheduled` events into ordered `TranscriptItem[]`. Coalesces
  consecutive `agent.message` (and `agent.thought`) chunks into one growing bubble; tool cards
  are keyed by `tool_call_id` and updated in place by `agent.tool_update`. Purity makes the DoD
  fixture test drive it directly.
- **`Conversation`** renderer: assistant message bubbles (whitespace-pre-wrap; MarkdownView is
  deferred to 07-09 to avoid pulling react-markdown early), collapsible muted "thinking" blocks,
  tool-call cards (name + kind + status icon + expandable result preview), turn-result chips
  (ok/fail + stop reason + duration + tool count), and inline validator/retry system notes.
  Live auto-scroll with a "jump to latest" affordance (guarded to a no-op under jsdom); empty
  states for program nodes ("deterministic code — no agent conversation") and not-yet-started.

---

## 5. Inspector tabs (`components/Inspector.tsx` + `components/inspector/panels.tsx`)

Tabbed panel bound to the selected node (`/runs/:runId/node/:nodeId`), with a header
(KindBadge + StatusPill + prev/next node nav) and a counter strip (messages / tool calls /
attempts / duration):

1. **Conversation** — the transcript (§4).
2. **Inputs / Outputs** — the node's state delta (from `node.completed.delta_keys`) resolved
   against the checkpointed run state, plus any documents it produced (links to 07-09 preview).
3. **Validation** — the reliability-trio outcome: validator checks (name/ok/detail) + retry
   attempts, clear pass/fail.
4. **Raw** — the node's raw event stream as a copyable JSON block.

---

## 6. HITL bar (`components/hitl/`) — the full model, from durable state

`HitlBar` is a **pure function of `run.status` + `run.gate`**, rendered above the tabs and
hidden entirely on terminal runs (history-only, §6 of the spec):

- **Mode 1 — designed gates** (`status == awaiting_input:gate`, driven by `run.gate`):
  `GatePanel` styled by `gate.kind` (approval/escalation/**pre_mutation** gets an explicit
  "modifies external systems" warning/review), renders the prompt + `context_refs` chips, and
  buttons derived from `gate.options` — **Approve** → `{decision:"approve"}`, **Reject** →
  ConfirmDialog → `{decision:"reject"}`, **Feedback** → textarea → `{decision:{feedback}}`. The
  panel is an `aria-live="polite"` region so a gated run is announced.
- **Mode 2 — pause/resume/cancel**: buttons reflect status (Pause when running, Resume when
  paused, Cancel with ConfirmDialog on any non-terminal).
- **Mode 3 — edit state & fork**: `EditStateDialog` (JSON patch of editable keys; server
  `check_editable` 400 surfaced **inline** as `role="alert"`, current state shown read-only) and
  `ForkDialog` (choose seed node + optional edits → `POST /fork` → navigate to the new run;
  original untouched, ADR-025).

---

## 7. Verification

- `npx tsc --noEmit` strict — clean.
- `npx vitest run` — **42 passed** (added 8 in `run-detail-hitl.test.tsx`): `buildTranscript`
  coalescing + tool-update-in-place + notes; non-conversation events ignored; `Conversation`
  renders messages/tool cards/results/notes + expands thoughts + program empty-state; `HitlBar`
  gate approve/reject(confirm)/feedback submit the correct decision bodies (captured via MSW);
  edit-state guardrail **400 surfaced inline**.
- `npx vite build --outDir /tmp/... --emptyOutDir` — OK (pre-existing Recharts chunk-size warning;
  code-splitting deferred to 07-10). `git status web/static` — **untouched**.
- Frontend + genesis CI: **green** (commit `b23c5b1`).

---

## 8. Definition of done (07-08) — status

1. Node tabs (Conversation / I-O / Validation / Raw) with accurate per-node data — ✅.
2. Kiro transcript renders messages/thoughts/tool calls+updates/results, live + from the durable
   log, with coalescing — ✅ (virtualization deferred — see §9).
3. All three HITL modes work from the UI, surfaced from durable state; approval reachable after
   reload/restart — ✅.
4. Mutations safe (confirm on destructive, toasts, inline 400s); gate announced via aria-live;
   keyboard-accessible — ✅.
5. Component tests: scripted `agent.*` fixture renders the transcript; gate fixture submits each
   response; edit-state guardrail rejection surfaces — ✅.

---

## 9. Decisions & honest deviations

- **MarkdownView deferred to 07-09.** Assistant text renders as whitespace-pre-wrap rather than
  markdown, to avoid pulling `react-markdown`/`remark-gfm` in this phase (they're on the 07-09
  dependency list). The renderer is a drop-in slot when 07-09 lands.
- **No list virtualization yet.** The transcript is a plain list. Local single-user runs are
  small; a virtualized list can slot in with the 07-10 perf pass alongside the Recharts split.
- **Fork/edit availability.** Edit-state + Fork + Cancel are offered on *any* non-terminal run
  (not only when gated), matching §6 "mode 3 always available on non-terminal". Terminal runs
  show **no** controls (history-only) per the spec — fork-from-terminal was intentionally not
  added here.
- **Benign Radix "DialogContent missing Description" console warning** on confirm dialogs —
  consistent with the existing RunsPage/Settings confirm dialogs; non-failing. A later a11y
  polish can add `aria-describedby` uniformly.
- **Live Kiro/browser QA is manual** — the transcript is proven from scripted fixtures + the
  durable-log path; a real streaming ACP turn can't be driven headlessly here.

---

## 10. Next

07-09 (Documents & preview) — the artifacts drawer (the toggle already exists in Run Detail)
+ rendered preview (md/json/mermaid/csv/text) via the `/artifacts` + `/artifacts/{name}` APIs.
This is also where MarkdownView lands and back-fills the conversation/inputs-outputs preview slots.
