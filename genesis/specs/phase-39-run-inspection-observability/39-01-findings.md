# 39-01 findings — locked contracts + mockup

> Output of 39-01 (research/contracts/ADR + mockup). **Awaiting user sign-off before 39-02 build.** Parent: `../phase-39-run-inspection-observability.md`.

## Mockup (built, ready to view)
- Route **`/dev/run-inspection`** (`web/src/dev/mockups/RunInspectionMockups.tsx`) — committed locally in genesis (not released). A **Scenario** control cycles the five shapes (single turn · retries · MAP loop · +heal pass · program node) so the **adaptive turn explorer** can be judged; theme toggle; tokens/primitives only. Gates: tsc + eslint clean; `npm run build` ok; `web/static` refreshed.
- **View it:** `cd genesis/web && npm run dev` → http://localhost:5173/dev/run-inspection (or it's in the built bundle a running `genesis serve` serves at `/dev/run-inspection`).
- Shows: the single-click **summary pane** (node `description` → metrics: executions, per-execution response times, credits per/total, tool calls, total time) + a **View details** button → the very large **modal** (left adaptive tree that renders only the dimensions that occurred; right pane = Prompt · Artifacts/inputs · Conversation · Output · Metrics). Program node = summary only, no modal.

## Locked capture contract (genesis-core, additive — no schema change)
- **`agent.prompt`** emitted per turn *before* the model call: `{node, prompt_ref, model, mcp:[...], tools:[effective], image_docs:[...], iteration, attempt}`. `prompt_ref` = a blackboard file `_prompts/<node>-p<pass>-a<attempt>-<seq>.txt` holding the exact rendered prompt (never inlined — ADR-010/018). Fetched lazily by the modal via the existing `GET /runs/{id}/artifacts/{ref}`.
- **`agent.result`** gains `attempt` + `iteration` (rides `_CANONICAL_CUSTOM` verbatim into `run_events`).
- **`_iteration` convention:** a reserved state key `{pass:int, item_label:str|None, item_index:int|None}` stamped by loop/heal **program** nodes; `kiro_node` copies it onto the two events opaquely. Shared with Phase 40's `pass`.

## Locked decisions (the 39-01 open points)
1. **Endpoint:** a **new** `GET /runs/{id}/nodes/{node}/iterations` (keeps `/steps` lean; the modal is its only consumer). Returns the `fold_iterations` tree (per umbrella §6).
2. **Prompt-file retention:** **keep** prompt files — they are the point of this phase. Add `_prompts/` to the workflows' `cleanup` keep-set so the scratch-deletion node preserves them.
3. **Secrets:** prompts contain only artifact text + instructions; secrets are injected as **MCP env** (never in the prompt string), so no redaction is required — add a capture-time assertion/note that the prompt string is not scanned for/does not carry secret values.
4. **Program/validator per-turn artifacts:** attribute artifacts saved within the turn's `seq` window + the node's declared output doc; program/validator turns render summary + generated artifact only (no prompt/conversation), per the mockup.
5. **New-runs-only:** old runs (no capture) show a "capture unavailable for this run" state in the modal — no backfill.

## ADR
ADR-066 (Proposed) is in `reference/decision-log.md` + `../phase-39-run-inspection-observability.md` §8.

## Next (39-02, on sign-off)
genesis-core emits `agent.prompt` + the `agent.result` additions + documents the `_iteration` convention; tests.
