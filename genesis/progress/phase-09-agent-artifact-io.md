# Phase 9 — Agent Artifact I/O (as-built)

**Shipped 2026-07-13.** Spec: `specs/phase-09-agent-artifact-io.md`.
Releases: **kiro-agent-sdk v0.2.0 · genesis-core v0.6.0 · genesis v0.17.0 · genesis-workflows v0.4.0.**

## What shipped
A **session tool-output store** + **agent-driven save-by-reference**: an agent can persist arbitrarily
large MCP tool results to the blackboard without re-emitting the bytes through the model (the
`erd-generation` `fetch_schema` `turn_timeout` bug). Default-on for every agent node; generic across
workflows (Genesis needs no domain identifier — the agent selects).

## Components
- **kiro-agent-sdk (v0.2.0):** `ToolCall`/`ToolCallUpdate.name` (`_meta.kiro.toolName`, fallback title),
  `.raw_input` (`rawInput`), `ToolCallUpdate.output` (extracted from `rawOutput`); `extract_tool_output`
  helper exported. Correction from the spike: MCP results arrive in `rawOutput`, not `content`.
- **genesis-core (v0.6.0):** `genesis_core/nodes/tool_store.py` (`ToolOutputStore` → `<run>/_toolcalls/`
  index + `<ref>.out`, atomic writes, continue-numbering); `genesis_core/mcp/blackboard_server.py`
  (stdlib stdio MCP: `list_tool_outputs`, `save_tool_output`, `read_tool_output`; `_safe_path` escape
  guard; bounded retry); `kiro_node(blackboard=True)` default-on injection + trust auto-add + recording
  + `tool_output.recorded`/`artifact.saved` events + `tool_outputs_recorded`/`documents_saved`
  telemetry. `CORE_MAJOR` unchanged (1; additive).
- **genesis (v0.17.0):** `purge_tool_store_on_final` setting (default on; `GENESIS_PURGE_TOOL_STORE_ON_FINAL=0`
  to keep) + eager `_toolcalls/` purge in `RunManager._finalize`. Baseline retention still reclaims it.
- **genesis-workflows (v0.4.0):** erd `fetch_schema` prompt → navigate + `list_tool_outputs` +
  `save_tool_output` (validator unchanged); docs establish it as a standard authoring convention
  (steering 01–04, README, `erd-generation/README.md`, MIGRATION).

## Evidence
- Tests: sdk 48 · genesis-core 54 (incl. Spike-2 multi-app integration) · genesis 89 (incl. 3 purge
  tests) · genesis-workflows 9 + `validate_library`. ruff clean across all.
- Spikes (real kiro-cli 2.12.1): (1) ACP `tool_call` carries `rawInput` + `_meta.kiro.toolName`, result
  in `rawOutput`; (2) full loop — agent fetched alpha/beta/gamma (~107 KB each), saved the **full
  107,839-byte gamma** to `raw_schema.json` by reference, `MARKER-gamma` absent from the model's
  messages (zero re-emission).
- CI green on genesis-core / genesis / genesis-workflows (sdk repo has no CI pipeline).

## Design decision (cross-process coordination)
`kiro_node` writes the store to the run dir; the blackboard server (a separate kiro-cli child, launched
`sys.executable -m genesis_core.mcp.blackboard_server --root <run>`) reads/copies within that shared
dir — neither process touches the other's memory. `save_tool_output` copies from the on-disk store with
a bounded retry for a just-written file (spike-proven).

## Honest caveat
Fixes the **output** re-emission (the `turn_timeout` bug). The model still *receives* each tool result
once in its input context because kiro-cli owns the model loop and Genesis only observes ACP — trimming
input context would need an MCP gateway (deferred, spec §9).

## Pending / follow-ups
- **Manual acceptance:** a live `genesis serve` erd run against Atlas (Docker up) to confirm one short
  `fetch_schema` turn, no `turn_timeout`, and that the real Atlas `rawOutput` wrapping matches
  `extract_tool_output` (spike used an echo stub with the same MCP content shape).
- Deferred: automatic/threshold capture, `write_document` authoring tools, the MCP gateway.
