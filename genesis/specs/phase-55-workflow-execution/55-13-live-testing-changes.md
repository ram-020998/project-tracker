# 55-13 — Live-testing changes: status-coloured graph cards, a model per agent node, a leaner Documents list

> **Status:** SPEC-DRAFTED 2026-11-23. Repo: genesis (`web/src/features/run-detail/`, `web/src/shared/ui/`,
> `packages/genesis-core/genesis_core/nodes/agent.py`, `genesis/runs/worker.py`, `genesis/lint/contract.py`).
> Parent: `specs/phase-55-workflow-execution.md`. Built by **genesis-dev** after 55-10 and before 55-11.
> Decisions: D28, D29, D30 (`55-01-findings.md` §19), from the user's live testing during 55-10.

## 1. Graph cards: the status is the card's colour (D28)

`web/src/features/run-detail/graph/NodeCard.tsx` (55-03 made it 104 px: `layout.ts NODE_H`; v0.83.0 had 84 px).

- **Remove the status tag row** (`StatusPill` and the run count beside it). The card returns to **84 px**
  (`NODE_H = 84`); ELK still routes edges to the middle of `NODE_SIZE`.
- **Tint by status:** a `*-subtle` background and a status-coloured border from the existing tokens (success, danger,
  warning, primary, neutral as `statusMeta(status).tone` maps them; no raw palette colours, no opacity modifiers on
  token colours, L-123). Keep the pending dashed border, the gate's warning border when idle, the running pulse ring
  and the selection ring (selection must stay visible on every tint).
- **Status icon (non-colour cue, WCAG 1.4.1):** a 14 px icon at the right end of the header row, from a new
  `NODE_STATUS_ICON` map in `web/src/shared/ui/icons.ts` beside `NODE_KIND_ICON` (one home; lucide-react 0.451.0, the
  app's set; confirm each name exists in that version, else the nearest standard lucide icon, and record it): ok
  `CircleCheck`, failed `CircleX`, running `LoaderCircle` (spinning; respects `prefers-reduced-motion`), paused
  `CirclePause`, awaiting `Hourglass`, retrying `RotateCcw`, skipped `CircleMinus`, pending `CircleDashed`, cancelled
  `Ban`. The icon carries `aria-hidden`; the card's `aria-label` and a `title` tooltip keep the status name
  (`statusMeta(status).label`).
- **Layout and readability:** two rows — header (kind icon, label, status icon) and one meta line (elapsed or time
  spent, round k, ×attempts, ↻ runs when > 1, tools, messages) — on one baseline each, left-aligned, the label
  truncated with the full name on hover; text no smaller than today; contrast of text and icons on every tint at least
  4.5:1 (text) / 3:1 (icons) in light and dark. When the meta line has nothing, the card is the header plus empty space
  of the same height (no reflow between states).
- `StatusPill` stays for every other surface (Runs list, headers); the List view of the graph is unchanged.

## 2. A model per agent node from the workflow files (D29)

- **Contract:** `META.models: {<agent node>: "<model id>"}` and optional `META.default_model: "<model id>"`, both
  mirrored in `workflow.yaml`. `genesis/lint/contract.py`: parity of both keys; a `models` key that is not an agent node
  of the compiled graph, or a non-string value, is an error; one reader shared by the lint and the worker (L-109, a
  parity test). Not editable in the app.
- **Resolution** (genesis-core `kiro_node`, additive, `CORE_MAJOR` 1): the worker passes the map and the default in
  `ctx.extras` (e.g. `node_models`, `default_model`); for each turn the model is the first set of: the node's per-run
  `model` (a callable or value given in code — agent-prompt's input, its custom agent's model) → `META.models[node]` →
  `META.default_model` → nothing (Kiro's default, today's behaviour). No `graph.py` changes.
- **Spike first** (record in As built): on the installed kiro-cli (v3 engine, ADR-086), how the SDK reports the models
  advertised at session start, and what selecting an id that is not in that list does (error, silent default, or
  Kiro's own fallback). Probe with the product's own session shape and a negative control (L-044, L-117).
- **Fallback (D29 B):** when the chosen model is not among the advertised ones, use the next one in the order above
  (ending at Kiro's default) and record a canonical **`model.fallback`** `{node, requested, used, reason}` event
  (`CANONICAL_KINDS`, the web list and fixtures, both ways, L-122); the turn's `agent.prompt` `model` is the one used.
  Put the check at the provider seam (`AgentProvider`, ADR-051), not in each node.
- **Run Detail:** the turn explorer and the node summary show "used X instead of Y" for a `model.fallback`, beside
  53-06's engine fallback note (`web/src/features/run-detail/model-fallback.test.tsx` covers the existing one).
- **Docs:** the scaffolder template (`genesis/cli/create_workflow.py`) shows `models` / `default_model` commented out;
  55-12's write-back documents both keys for workflow authors.

## 3. Documents: hide System and spent Tool outputs (D30)

`web/src/features/run-detail/components/docs/` (55-09):
- **System** is not shown in either view (By step, By type); its rows and the "show" control go. The API may keep
  returning them; the file routes keep refusing them (D20).
- **Tool outputs** shows only while at least one of its entries has `file_available` (during a run and at a gate, D9);
  otherwise the group and its rows are hidden, including on old runs. Counts in headers and the tab badge exclude
  hidden rows.
- The search box searches only what is shown. Nothing else changes in the approved layout.

## 4. Tests and probes

- Graph: one test per status (tint class, icon, `aria-label`/`title` with the status name), the 84 px height constant,
  no `StatusPill` on the card, selection ring on each tint; jest-axe (L-014). Real-browser probe of the seven 55-02
  graph states at 1280 / 1440 / 1920 px, light and dark, with a contrast check of text and icon on each tint and
  screenshots in `evidence/55-13/` (L-090); `scripts/probes/phase55-run-graph.mjs` can drive it.
- Models: the lint cases (unknown node, non-string, yaml/META mismatch); the precedence order (per-run → node →
  default → none) with a stub provider; the fallback with the spike's real advertised-model shape; the event both ways.
  One cheap live run (hello-appian or agent-prompt in a scratch `GENESIS_STATE_DIR`) with `default_model` set to an id
  not on the account, to see the fallback and the note; ask the user before anything costlier.
- Documents: System absent in both views; Tool outputs present while a file exists, absent after the purge and on an
  old run; counts.

## 5. Gates

genesis-core pytest + ruff; genesis pytest + ruff; web `npm run lint && npm run typecheck && npm test`; `npm run
build`, then commit `web/static/` as a separate step, checked after the build settles (L-089). genesis-workflows
`ci/validate_library.py` still passes (no workflow sets `models` yet).

## Context manifest

```toml
areas    = ["web-runs", "core-engine", "runs-worker"]
adrs     = ["ADR-019", "ADR-027", "ADR-051", "ADR-055", "ADR-066", "ADR-086"]
lessons  = ["L-013", "L-014", "L-044", "L-069", "L-089", "L-090", "L-109", "L-117", "L-122", "L-123"]
docs     = ["tracker:specs/phase-55-workflow-execution/55-01-findings.md", "tracker:specs/phase-55-workflow-execution/55-02-mockups.md"]
code     = ["genesis/web/src/features/run-detail/graph/**", "genesis/web/src/features/run-detail/components/docs/**", "genesis/web/src/shared/ui/icons.ts", "genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/genesis/runs/worker.py", "genesis/genesis/lint/contract.py"]
upstream = ["55-03", "55-05", "55-09", "55-10"]
```
