# 55-02 — Mockups: Documents tab, Resolve panel and run graph states, approved before the build

> **Status:** SPEC-DRAFTED 2026-11-22. Repo: genesis (`web/src/dev/`). Parent: `specs/phase-55-workflow-execution.md`.
> Built by **genesis-dev**. **Gate (D8):** the user reviews `/dev/phase-55` in the browser; the web parts of 55-03 and
> all of 55-09 do not start until the user approves (55-03's backend may start). Each change the user asks for is
> recorded as a decision in `55-01-findings.md` §9 and folded into 55-03 / 55-09 by the spec agent before they start.

## 1. What to build

One route `/dev/phase-55`, lazy-loaded like `/dev/phase-54` (`web/src/app/router.tsx:40,119`), under
`web/src/dev/mockups/phase55/`. A page of sections with a jump list, light and dark theme, **stub data only** (no API
calls), built only from the shared primitives and design tokens (ADR-027, ADR-055; no raw palette colours, no
opacity modifiers on token colours, L-123; no `Button asChild`, L-069). Each section is drawn inside a frame that looks
like Run Detail (header, tabs Flow · Documents · …), so the user judges it in place.

**Stub data uses real shapes (L-083):** file names, steps and counts from the real runs in `55-01-findings.md` §4.2
(e.g. `technical-design-analysis` r-d5ed99071d49: 31 files, steps `load_inputs`, `plan_sections`, `assemble`,
`verify`, `heal`; `_prompts/<node>-p<pass>-a<attempt>-<ms>.txt`; `tool_output.recorded` with tool names such as
`getRecordType`); gate payloads with the F6 fields; memory ids and texts shaped like `memory.db` rows (§2.1); run
statuses from `statusMeta`; credits with provenance.

## 2. Surfaces

1. **Documents tab — By step (default view, D8).** Left: search, the By step / By type toggle, then the groups:
   **Output** (pinned, auto-selected; label from META, e.g. "Technical design document", the file name under it),
   **Inputs** (uploaded, built from input, memory brief), **Steps** in graph order (each step collapsible: its files
   with a pass/fail mark on checks such as `verify.json`, and "Prompts (n)"), **Tool outputs (n)** (tool, step, size,
   time), **System** (collapsed, "show"). Each row: label, file name, step, written time (relative; exact on hover),
   size, **write count** ("written 3 times", D9), latest mark. Right: the viewer with its header (category badge, step
   · pass · attempt, written time, size, write count, Open in step, Download) and the existing preview.
2. **Documents tab — By type.** Flat sections Output · Inputs · Intermediate · Checks · Prompts · Tool outputs.
3. **Documents states:** a live run (a file being written: empty placeholder "being written by `assemble`", the
   Output group showing "not produced yet"); a finished run whose tool outputs are metadata only ("files removed at the
   end of the run", D9); an old run (no write records: "step unknown", name-rule categories, a one-line note); a run
   with no output (failed early); a workflow with several outputs (story-implementation: report + rollback).
4. **Resolve panel (D7).** Where it sits in Run Detail (a side panel beside the graph, or a Resolve tab; show both and
   let the user choose). States:
   - escalated, not opened yet: a summary strip (failed step, reason in one line, "Open Resolve");
   - the agent's first turn: what went wrong (failed step, validator messages, retry and heal history), the files that
     exist (linking into Documents), and **proposal cards** — one per suggested action, with its parameters (the
     guidance text, the input changes, the step to restart from, the file diff for fix-then-accept) and Confirm /
     Dismiss;
   - the user chatting (composer, a follow-up proposal replacing an earlier one);
   - a **manual action menu** (the six actions without the agent) with the same confirm dialogs;
   - the confirm dialog for each action (stop asks for a reason; relaunch shows the input form prefilled; fix-then-accept
     shows the diff);
   - after each action: retry running, accepted → done + "moved to the feature stage", relaunched → link to the new run,
     forked → link, stopped → failed with reason;
   - Accept unavailable (output missing or empty, L-106) shown disabled with the reason;
   - credits of the Resolve conversation on the panel (metered, provenance).
5. **Bell notification** for an escalation ("needs you", run name, failed step, link to the Resolve panel).
6. **Run graph states (D10):** a program node running (no agent events), an agent node running for minutes (elapsed
   time on the node), a loop re-entry (a node that was ok running again, round 2 of 3), waiting at the escalation gate,
   paused, done, failed; the edge into the running node lit and no other; the Live badge connected / reconnecting /
   polling; the Refresh control.

## 3. Review with the user

The dev opens each section at 1280 / 1440 / 1920 px, light and dark, in a real browser (L-090) and attaches
screenshots to As built. The user then reviews live. Record the verdict per surface (approved / changes) in As built;
changes go to 55-01 §9 as new decisions.

## 4. Gates

`cd genesis/web && npm run lint && npm run typecheck && npm test` (a smoke render of the route and a jest-axe check of
each section, L-014); `npm run build`, then commit `web/static/` as a separate step (L-089).

## Context manifest

```toml
areas    = ["web-runs", "web-shell"]
adrs     = ["ADR-027", "ADR-055", "ADR-066", "ADR-009"]
lessons  = ["L-014", "L-069", "L-083", "L-089", "L-090", "L-123"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-54-schedules-and-fixes/54-03-mockups.md"]
code     = ["genesis/web/src/dev/mockups/**", "genesis/web/src/app/router.tsx"]
upstream = []
```
