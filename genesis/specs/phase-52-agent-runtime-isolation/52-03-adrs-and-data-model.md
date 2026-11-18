# 52-03 — ADR drafts, event kinds and data model

> **Status:** SPEC-DRAFTED 2026-11-18. Repos: **project-tracker** (ADR drafts), **genesis** (event-kind constants,
> contract fixtures). Parent: `specs/phase-52-agent-runtime-isolation.md`. Decisions: D21, D25, D26, D28; all of §14 for
> the ADR text. Upstream: 52-02's As built.

## 1. Goal

Settle the three ADRs and the data shapes every later sub-spec writes, before code depends on them.

## 2. ADRs

Review `adr-drafts.md` (ADR-A agent runtime, ADR-B containerized distribution, ADR-C API token) against 52-02's results
and the then-current code; fold any re-spec; keep them **Proposed** (filed at 52-16 with `genesis-ctx add adr`). A
manifest cannot name a draft: later sub-specs list `adr-drafts.md` in `docs` and the amended ADRs in `adrs`.

## 3. Event kinds (L-005 keeps the canonical list closed; this sub-spec extends it on purpose)

New kinds in the run event log, each with a payload schema, a contract fixture in `web/src/types` (L-011) and a fold
in the turn explorer (52-14):

| Kind | Payload (key fields) | Written by |
|---|---|---|
| `sandbox.started` | `sandbox_id`, `runtime`, `image_digest`, `policy_hash`, `profile`, `node`, `limits` | controller client (52-06) |
| `sandbox.ended` | `sandbox_id`, `reason` (`completed` · `timeout` · `cancelled` · `paused` · `oom` · `crashed` · `policy_refusal` · `self_test_failed`), `peak_cpu_pct`, `peak_mem_bytes`, `peak_pids`, `duration_ms` | controller client |
| `egress.decision` | `sandbox_id`, `host`, `port`, `decision` (`allowed` · `denied`), `reason` (`not_listed` · `ip_literal` · `private_address` · `port` · …), `bytes_out`, `bytes_in` | proxy via controller (52-07) |
| `egress.dropped` | `sandbox_id`, `counts` by protocol / destination class (firewall drop counters, sampled at turn end) | controller |
| `mcp.call` | `sandbox_id`, `server`, `tool`, `decision` (`allowed` · `refused`), `duration_ms`, `result_ref` (blackboard pointer when saved, L-021) | gateway (52-08) |
| `credential.event` | `sandbox_id`, `kind` (`kiro_token_issued` · `kiro_token_refused` · `relay_token_issued` · `relay_token_revoked` · `relay_token_refused`), `expires_at` | broker / gateway (52-08) |

Rules: no secret, token or full URL query in any payload (host and path only); events are bounded per turn (the proxy
coalesces repeated identical decisions with a count). The existing `agent.tool_call` events stay the record of
agent-issued commands (D28).

## 4. Data model

- **No `genesis.db` migration is expected:** sandbox telemetry lives in `run_events` (§3); the controller keeps its own
  registry as container labels (`genesis.run_id`, `genesis.turn_id`, `genesis.policy_hash`, `genesis.owner`) so the
  orphan sweep needs no table; backups keep their catalogue as a manifest file in the backups volume (52-12).
- **`AgentSecurityPolicy`** — the frozen dataclass and its canonical JSON (sorted keys) whose SHA-256 is
  `policy_hash`: `profile`, `runtime`, `image_digest`, `mounts` (run subfolder path, mode), `env` (fixed allow-list of
  names and values, no secrets), `egress` (hosts, ports), `mcp` (server → tools), `credentials` (`kiro_broker: bool`,
  `relay: bool`), `limits` (cpus, memory, pids, wall clock), `lifecycle` (turn timeout, margin). Owned by
  `genesis/agent_runtime/policy.py` (52-06); this sub-spec fixes the schema and a fixture.
- If 52-02 shows a need for a table (e.g. a sandbox queue that must survive an app restart), add one migration here
  with the migration skill and say so in the As built.

## 5. Tests

Schema fixtures for every event kind and the policy JSON; a test that the canonical list of event kinds includes the
new ones and nothing else changed; a contract-drift test on the web types (L-011).

## Context manifest

```toml
areas    = ["runs-worker", "observability-credits", "web-runs", "security", "db"]
adrs     = ["ADR-010", "ADR-012", "ADR-029", "ADR-032", "ADR-066", "ADR-083", "ADR-086"]
lessons  = ["L-005", "L-011", "L-021", "L-066"]
docs     = ["tracker:specs/phase-52-agent-runtime-isolation/adr-drafts.md", "tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md"]
code     = ["genesis/genesis/runs/**", "genesis/web/src/types/**"]
upstream = ["52-02"]
```
