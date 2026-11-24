# 55-13 — Live-testing changes: status-coloured graph cards, a model per agent node, a leaner Documents list

> **Status:** BUILT 2026-11-24 (review SHIP; see As built). Spec drafted 2026-11-23. Repo: genesis (`web/src/features/run-detail/`, `web/src/shared/ui/`,
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

## As built

**Status:** BUILT 2026-11-24, review **SHIP** (first review) and **SHIP** at re-run 1 (`reviews/55-13-review.md`).
Repo genesis, branch master, base `361c99a6`, head `76b27a57`, 5 local commits (not pushed, not tagged). genesis-core
additive (`CORE_MAJOR` 1), no genesis.db migration (DB v30), no kiro-agent-sdk change, no genesis-workflows change.

### Commits (genesis)

| sha | what |
|---|---|
| `7cf01475` | source, tests, the probe's contrast check, `scripts/probes/phase55-13-seed.py` |
| `15ac92c1` | `web/static` for 7cf01475 (67 files) |
| `75500834` | review m2 (list read under a lock, failure cached), n1 (model named once), n2 (badge test) |
| `f9ac5013` | `web/static` for 75500834 (66 files) |
| `76b27a57` | review re-run n3: assertion for n1 (test only, no bundle change) |

Bundle proof (L-089): each bundle commit checked with `git show --stat <sha> -- web/static` in its own call after the
build had exited; a rebuild in a later call left `git status --short --untracked-files=all` empty both times. The
reviewer's out-of-tree builds were identical to `web/static` at 15ac92c1 and f9ac5013.

### §2 spike result (kiro-cli 2.37.1, v3 engine)

`evidence/55-13/spike/spike_models.py` (`result.json`, `result-s5.json`). The session is built as `kiro_node` builds a
turn: cwd = a scratch run folder, `KIRO_HOME` = `<run>/_kiro`, the projected `genesis-node` agent with
`NODE_AGENT_PROMPT`, the D9 trust policy and the blackboard server; one case per session (L-117).

- **S1, no model:** `session/new` advertises `configOptions.model` with 13 ids (`auto`, `claude-opus-5.5`,
  `claude-sonnet-5.5`, `claude-haiku-5.5`, `claude-opus-5`, `claude-sonnet-5`, `claude-opus-4.8/4.7/4.6`,
  `claude-sonnet-4.6`, `claude-opus-4.5`, `claude-sonnet-4.5`, `claude-haiku-4.5`); the current one is the account
  default, `claude-sonnet-5.5`. The SDK exposes it as `client.available_models` / `current_model_id` and on
  `SystemInit.models` (`{currentModelId, availableModels:[{modelId, name, description}]}`).
- **S2, positive control:** a listed id (`auto`) becomes the session's current model.
- **S3, negative control:** an unlisted id makes the SDK raise `KiroError model_unavailable` during `start()` (its
  own check against the advertised list, the list in `detail`), before any message is yielded (S3b through the
  product's `collect_streaming`). Without a fallback the node fails.
- **S4, the SDK check bypassed:** the engine accepts the id on `session/set_config_option` (`currentValue` = the bad
  id); the next prompt fails `-32000 "The model '…' is not available"`, `stop_reason: error`, no credits
  (`provenance: unavailable`), and no fallback frame. Same as 53-02 W10. Kiro has no fallback of its own here.
- **S5, the cost of reading the list alone:** start + close with no MCP server and no model: 3.6 / 2.3 / 2.3 s, the
  same 13 ids as S1.

### Changed

- **Graph card (§1):** `web/src/features/run-detail/graph/NodeCard.tsx` rewritten: no `StatusPill` row; two rows
  (kind icon · truncated label · 14 px status icon; one fixed-height meta line: elapsed / time spent, round k,
  ×attempts, ↻ runs, tools, messages); `aria-label` and `title` = `<label>: <statusMeta label>[, round k]`;
  `data-status`. New `graph/card-tone.ts` (`CARD_TINT`, `cardTone`): the fill (`bg-{success,danger,warning}-subtle`,
  `grad-brand-soft`) on an inner layer over the opaque card, a status border, the icon in the status colour.
  `layout.ts` `NODE_H = 84`. `shared/ui/icons.ts` `NODE_STATUS_ICON` and the nine lucide re-exports.
- **Models (§2), genesis-core:** `agents/models.py` (new): `model_candidates`, `choose_model`, `ModelChoice`,
  `MODEL_FALLBACK`, the `ctx.extras` keys `NODE_MODELS` / `DEFAULT_MODEL`. `agents/kiro.py`:
  `KiroAcpProvider.advertised_models(options)` (one bare session per worker process in the turn's own shape, under an
  `asyncio.Lock`, failure cached; None when stubbed or unreadable). `agents/provider.py`: the optional method
  documented, outside the runtime-checked Protocol. `nodes/agent.py`: `kiro_node` builds its options once as
  `opt_kw`, calls `choose_model` before `agent.prompt` (whose `model` is now the one used) and emits `model.fallback`
  right after it.
- **Models, genesis:** `genesis/runs/node_models.py` (new, the one reader): `parse_models`, `NodeModels.extras()`.
  `runs/worker.py` puts `parse_models(meta).extras()` into `ctx.extras`. `runs/manager.py` `model.fallback` in
  `_CANONICAL_CUSTOM`. `lint/contract.py` `check_models` (in `check_meta_yaml_parity`) and `check_node_models`
  (exported from `genesis.lint`, called by `genesis test-workflow`). `cli/create_workflow.py` shows both keys commented
  out in `graph.py` and `workflow.yaml`.
- **Models, web:** `conversation.ts` `modelFallbacks`, `fallbackIn`; `shared/ui/format.tsx` `ModelFallbackNote`
  ("used X instead of Y", reason in the tooltip and for screen readers); `Inspector.tsx` per-execution chip and
  `NodeIterationsDialog.tsx` header show it beside 53-06's `AnsweredBy`; `types/event.ts` comment; fixtures:
  `CANONICAL_EVENT_KINDS`, one golden `model.fallback` event, `events/canonical-kinds.json` regenerated.
- **Documents (§3):** `components/docs/run-docs.ts` `visibleDocuments` (System never; tool outputs only while one has
  `file_available`); `groupByStep` lost `system`; `DocumentsTab.tsx` feeds the rail, the header counts and the empty
  state from it (the System group is gone); a deep link to a System path still finds its record in the full list,
  so it is never fetched (D20); `RunDetailPage.tsx` tab badge counts visible documents.
- **Probe:** `scripts/probes/phase55-run-graph.mjs` records per card (`cards`) the text and status-icon contrast on
  its tint (fill composited over the card, every gradient stop, a card with opacity over the canvas) and its height,
  and with `--fallback` shoots the agent run's note in the node summary and the turn explorer.
  `scripts/probes/phase55-13-seed.py` seeds a scratch state (refuses the fleet's).

### Tests

- genesis-core `tests/test_agent_models.py` (16): candidates' order, blanks, repeats; the turn gets per-run → node →
  default → none (static and callable; no list read when nothing is set); the list read uses the turn's shape without
  servers or model; an unlisted default → Kiro's default (`agent.prompt.model` = the list's current, event right after
  `agent.prompt`, exact payload); an unlisted node model and node entry → the default model; an unknown list
  (no method, None, empty) is trusted; the Kiro provider reads once and caches, returns None when stubbed or failing;
  parallel calls share one read and a failure is not retried. Mutation: `choose_model` ignoring the list fails 2; the
  lock test fails on the old `kiro.py` (`assert 3 == 1`, reproduced by the reviewer).
- genesis `tests/test_node_models.py` (11): `parse_models` shapes; the lint's errors are the reader's own on each side
  (L-109); parity (ok, non-string, drift, META only, yaml only); a `models` key that is not an agent node (a validator,
  an unknown name); the scaffold shows both keys and still lints; `model.fallback` canonical and in the web list; a
  REAL subprocess worker: META `models`/`default_model` reach the nodes, the node's own entry is used, the unlisted
  default falls back, the event is stored canonical with its node right after `agent.prompt`.
- Web: `graph/node-card.test.tsx` (23: 84 px; the map covers every status; per status the tint, border, icon class,
  `aria-hidden`, label and title, no status tag; tones from `statusMeta`, tokens only, no `/NN` modifier; dashed
  pending, dashed warning idle gate, pulse and spinner with `motion-reduce:animate-none`; selection ring on each tint;
  the meta line; empty meta line height and the truncated label; jest-axe on every tint), `documents.test.tsx`
  (System absent in both views, counts, search, deep link not fetched, only-System run; tool outputs at a gate paged,
  absent after the purge and on an old run, counts), `resolve.test.tsx` (the rendered tab badge excludes System),
  `model-fallback.test.tsx` (the folds, the note, the Inspector chip and the explorer header with the model named
  once; jest-axe). Mutation: removing the Inspector note fails 1; `visibleDocuments` returning everything fails 5;
  the old badge line fails 1; the old dialog header fails 1.
- **Gates:** genesis-core **173 passed**, `ruff check genesis_core` clean. genesis full pytest **2399 passed, 4
  skipped** at 7cf01475 (scratch `GENESIS_STATE_DIR`; reviewer reproduced; no `genesis/` file changed after), `ruff
  check genesis` clean. Web lint 0 errors / 20 warnings (baseline), typecheck clean, vitest **86 files / 1051
  passed** (1018 at 55-09). genesis-workflows `ci/validate_library.py` **PASSED (19)**, library pytest **678 passed**.

### Real-browser check and live run (L-090; screenshots in `evidence/55-13/`)

Scratch `genesis serve` on :8790, `GENESIS_STATE_DIR=/tmp/gr-55-13/live/state` (system schedules turned off, no
memories: D19), seeded with `liveness-probe` and a copy of `hello-appian` with `default_model:
genesis-no-such-model-55-13`; stopped after. Fleet (:8760/:8761) not touched, not restarted.

- `evidence/55-13/graph/`: the six program states (program running, loop re-entry, paused, gate waiting, done,
  failed) × 1280/1440/1920 × light/dark, 36 shots, `result.json`: **0 layout problems, 0 low-contrast cards, every
  card 84 px**. Minimum text contrast 5.64:1 (running, dark), minimum status-icon contrast 3.78:1 (pending, light).
  The first measured run found a running card's elapsed time in `text-primary` at 4.45:1 on the dark tint; it is now
  `text-fg` with the timer icon in primary. (The probe's first version read React Flow's handle as the fill; the fill
  is now `data-card-fill`.)
- `evidence/55-13/agent/`: the seventh state, one real `hello-appian` run **r-c5a2e2990b13** (one Kiro turn, **0.337
  metered credits**): agent running and ended × widths × themes (12 shots), `agent-fallback-inspector-1440-{light,dark}`
  and `agent-fallback-explorer-1440-{light,dark}`. Events: `agent.prompt` model `claude-sonnet-5.5` (seq 140),
  `model.fallback {requested: genesis-no-such-model-55-13, used: claude-sonnet-5.5, reason: "… is not among the models
  Kiro lists for this account; used Kiro's default"}` (seq 141), `agent.result` metered, run done. The explorer shots
  predate 75500834 (n1: the header then named the model twice).

### Review

`reviews/55-13-review.md`. First review **SHIP** with m1 (the agent-node lint does not run in library CI), m2 (the
list read had no lock and cached only success), n1, n2. m2, n1, n2 fixed in 75500834/f9ac5013. **Re-run 1: SHIP**
with m3 (m1's record was not on disk) and n3; n3 fixed in 76b27a57 (test only, not re-reviewed; fail-first checked,
the file's 7 tests pass). m1/m3: one task line added to `55-12-release-and-onboarding.md` §1 item 2 (below).

### Decisions / deviations

No ADR deviation. Choices the spec did not cover:
1. **Where the fallback is decided:** before the turn, from a list read (`advertised_models`), not by reacting to the
   SDK's start-time `model_unavailable`. Reacting would cost nothing when the model is listed, but `agent.prompt` is
   announced before the session starts, so it would carry the wrong model or have to move after the MCP start-up
   (the turn explorer would be empty during it). The price: one bare kiro-cli session (2.3–3.6 s, no prompt, no
   credits) per worker process, only when a candidate is set. An unknown list is trusted (KiroCrew
   `docs/system-specs/common/model-selection.md`, `resolve_usable_model`: an empty or unknown advertised set is not
   checked).
2. **Falling back to Kiro's default sends no model** (`options.model = None`); `used` and `agent.prompt.model` carry
   the list's current id (the account default), so the note names a real model.
3. **One `model.fallback` per turn**, `requested` = the first candidate; the `reason` names every skipped id.
4. **A code-set `kiro_node(model="…")` that the account does not list now falls back** instead of failing at session
   start (the D29 order applies to it too). No library workflow sets one; agent-prompt's per-run model is the only
   caller.
5. **The agent-node check needs the compiled graph**, so it is its own function (`check_node_models`), called by
   `genesis test-workflow`; `validate_library` calls it from 55-12 (it runs against the pinned genesis, which does not
   have it yet).
6. **Pending reads as neutral** (`statusMeta` gives it `info`); it keeps `opacity-70` and the dashed border (measured
   ≥ 6.8:1 text, ≥ 3.78:1 icon). **`awaiting` keeps its warning ring** beside the warning tint, so "needs you" stays
   apart from paused. The failed/paused rings are gone (the border carries the colour).
7. **The selection ring has an offset** (`ring-offset-2 ring-offset-surface-2`), so it stays distinct from a
   primary-bordered running card.
8. **The meta line does not wrap** (one line, clipped if long); no state in the probe overflowed.
9. **The card's `title` carries the full label and the status** (no separate title on the label span).
10. **Tool outputs, when shown, list every record of the run** (some may have no file); the group hides only when no
    record has one.
11. **A deep link to a System path** keeps 55-09's "System files are not shown" viewer (looked up in the full list).

### What reaches the fleet before the release

The fleet's workers import HEAD from the editable dev venv; the servers (:8760/:8761, not restarted) keep their
in-memory manager.
- Every new fleet run: the worker passes `META.models`/`default_model` (no v0.27.0 workflow sets either, so nothing).
  `kiro_node` reads Kiro's list only when a model is set, which today is only an agent-prompt run with a model: one
  extra bare session (~2.3–3.6 s, no credits) per worker, and an unlisted id now falls back to Kiro's default
  instead of failing the node. `agent.prompt.model` is then the used id.
- `model.fallback` is not in the running servers' canonical list, so it is stored as `custom` (no node) and shown
  nowhere until a server restart.
- The servers serve `web/static` from the checkout, so the new graph cards, the Documents rules and the fallback note
  show on a page reload (the note only for rows stored after a restart).
- `genesis create-workflow` / `genesis test-workflow` from the dev venv: the commented keys and the `[models]` check.

### Lesson candidates

1. **A probe that reads "the first child" of a third-party component measures the wrong element:** React Flow's
   handle is the card's first `div`, so the first contrast run reported 1.1–1.6:1 on every card. Mark the element a
   probe measures (`data-card-fill`) and sanity-check a probe's first numbers against a screenshot.
2. **A colour that passes on the light tint can fail on the dark one:** `text-primary` on `grad-brand-soft` was fine
   in light and 4.45:1 in dark (the dark tint is 22% primary). Measure every tint in both themes, not one.
3. **An advisory read that runs per turn needs a lock and a cached failure** (review m2): parallel nodes multiply it,
   and a failing read is paid again by every retry.

### Code-map changes (for genesis-docs, bible/03)

- genesis-core `agents/models.py` (new): `model_candidates`, `choose_model`, `ModelChoice`, `MODEL_FALLBACK`,
  `NODE_MODELS`, `DEFAULT_MODEL`; `agents/kiro.py` `KiroAcpProvider.advertised_models` / `_read_models`;
  `nodes/agent.py` the model choice before `agent.prompt`, `model.fallback`.
- genesis `runs/node_models.py` (new): `parse_models`, `NodeModels`, `MODELS_KEY`, `DEFAULT_KEY`; `runs/worker.py`
  extras; `runs/manager.py` `model.fallback` canonical; `lint/contract.py` `check_models`, `check_node_models`
  (`genesis.lint`); `cli/test_workflow.py` `[models]`; `cli/create_workflow.py` commented keys.
- Web: `graph/card-tone.ts` (new), `NodeCard.tsx`, `layout.ts` `NODE_H` 84; `shared/ui/icons.ts` `NODE_STATUS_ICON`;
  `shared/ui/format.tsx` `ModelFallbackNote`; `conversation.ts` `modelFallbacks`, `fallbackIn`;
  `components/docs/run-docs.ts` `visibleDocuments` (`ByStep.system` removed).
- `scripts/probes/phase55-13-seed.py` (new); `scripts/probes/phase55-run-graph.mjs` `contrastOfCards`, `--fallback`.

### For 55-11 / 55-12

- **55-11:** the selection ring on each tint in a real browser (class tests only; the probe shoots no selected card);
  a `cancelled` card live; a live fallback to a *listed* next candidate (only the Kiro's-default branch ran live);
  a real fan-out with `default_model` sharing one list read; the explorer header after n1 live; the fleet's
  `model.fallback` rows read as `custom` until a restart (above).
- **55-12:** (added to its §1 item 2) `ci/validate_library.py` step 3 calls `genesis.lint.check_node_models` with the
  pin move; the write-back documents `models` / `default_model`, the precedence, the fallback and its cost
  (decision 1); kiro-cli 3.x list shape stays in `specs/backlog/kiro-cli-3x-reverify.md`.
- Observed, not changed: the graph's legend panel overlaps the leftmost card at 1440 px on `hello-appian`
  (`agent-fallback-inspector-1440-light.jpg`); it is the existing bottom-left Panel, not the card.
- Cleanup for you: `/tmp/gr-55-13/` (scratch state, probe runs, test logs; the server is stopped), `/tmp/spike-55-13/`,
  and the reviewer's `/tmp/gr-55-13-review*` / `/tmp/gr-55-13-rr1`.
