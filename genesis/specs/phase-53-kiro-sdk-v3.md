# Phase 53 — Kiro SDK v3: rebuild `kiro-agent-sdk` for kiro-cli's v3 engine

> **Status:** SPEC-DRAFTED 2026-11-03 · **Author:** genesis-spec agent.
> Sub-specs: `phase-53-kiro-sdk-v3/53-01..53-12`. Findings (code facts, the live v3 probe, KiroCrew research, every
> decision): `53-01-findings.md`. Probe scripts and raw frames: `phase-53-kiro-sdk-v3/evidence/`.
> Repos: **genesis** (`packages/kiro-agent-sdk` rebuilt, `packages/genesis-core` `kiro_node`, chat backend, preflight,
> skills, web, one migration), **genesis-workflows** (the `appian` skill published), **playwright-appian** (0.3.1: the
> skill's front matter, D14), **project-tracker** (areas, ADRs).
> Proposed ADR: **ADR-086** (number fixed at write-back) — Genesis drives Kiro only through the v3 engine with a
> Genesis-owned `KIRO_HOME` and a projected custom agent; managed skills only. Amends ADR-029, ADR-031, ADR-032,
> ADR-034, ADR-045, ADR-069, ADR-083.
> **Phase 51 shipped 2026-11-08 (genesis v0.81.0, genesis-workflows v0.25.0), so D11 is met; its live acceptance is
> still open (Phase 51 D38).** Specs re-checked against that code: `53-01-findings.md` §9. Phase 52 (agent runtime
> isolation) builds on this phase.

## 1. Why this phase exists

Kiro CLI V3 becomes the default with CLI 3.0 ([Kiro blog](https://kiro.dev/blog/cli-3/)). Genesis starts every Kiro
session with `--trust-tools` or `--trust-all-tools`, which `kiro-cli acp --agent-engine v3` rejects at launch (probe P1).
Most of the rest of what the SDK relies on is gone or moved on v3: credits (`_kiro.dev/metadata`), the command catalog
and execute method, compaction status, `session/set_model`, slash commands sent as prompts (findings §3). The SDK also
has gaps unrelated to v3: no Stop that keeps the session, no resume, unknown requests answered with an empty result, no
process-group cleanup, one flat timeout, and no test that touches the real wire (findings §2.1). And every Genesis
session loads the user's global Kiro MCP servers, contrary to ADR-004 (51-03 P10).

## 2. Goal

1. **One engine:** every Kiro session (chat in every mode, workflow agent nodes, the catalog probe) runs on
   `kiro-cli acp --agent-engine v3`; the v2 path is deleted (D5).
2. **Trust as a projected custom agent:** an explicit tool list and permission rules sent in `session/new`, activated
   and checked with `session/set_mode`; ADR-031's fail-closed chat and ADR-029's MCP cap enforced by the engine's tool
   list, with a Genesis allowlist check behind it (D1, D9, F2).
3. **Isolation from the user's Kiro setup:** a Genesis-owned `KIRO_HOME` per workflow run and one for chat (D6);
   managed skills only, for chat and workflows (D7, D8).
4. **The v3 surface kept working:** credits and context per turn (ADR-032), models, the `/` palette, Compact, Clear,
   Stop that keeps the session, resume with `session/load`, steering (D10), model-fallback reporting (F6).
5. **A hardened SDK:** named timeouts, one error classification, MCP readiness, refusal notices, elicitation declined,
   process-tree cleanup, an enforced import surface, recorded v3 fixtures with a fake engine, a measured tool-id table
   with verified kiro-cli versions (D3).

## 3. Decisions (locked with the user, 2026-11-03 — detail and rationale in `53-01-findings.md` §7–§8)

| # | Decision |
|---|---|
| D1 | Complete rebuild of `kiro-agent-sdk` for v3; learn from KiroCrew, not its multi-harness design. Out: other runtimes, warm pool, recovery ladder, crash log, non-SDK KiroCrew ideas. |
| D2 | Phase 53, `phase-53-kiro-sdk-v3`. |
| D3 | All fourteen KiroCrew ideas in scope (timeouts, error classification, MCP readiness, session cleanup, `session/load` resume, `-32601`, elicitation, refusal notice, process tree, import boundary, re-measured fixtures, steering, model fallback, access-token requests). |
| D4 / D12 | No v2-pin hotfix, also after D11; risk accepted until this phase ships. |
| D5 | Single switch to v3; v2 deleted; every workflow agent node and chat mode run live on v3 before release. |
| D6 | `KIRO_HOME` = `<run>/_kiro/` per workflow run, `~/.genesis/kiro-home/chat/` for chat; the user's `~/.kiro` is never read for agents, MCP, skills or steering. |
| D7 | Chat uses managed skills only; Settings → Catalog → Skills stays; add an Update button only; drop the "shadows personal" warning. |
| D8 | Workflows use managed skills only; remove the `~/.kiro/skills` fallback; publish `appian` to the library. |
| D9 | Workflow nodes: today's built-ins, auto-approved; MCP limited to `node.tools ∩ allowlist` by the tool list; no `delete_file`. |
| D10 | Chat steering: Send steers while a turn runs; an unread steer is sent as the next message; Stop keeps the session. |
| D11 | Phase 51 completes and ships first; Phase 53 starts after. |
| D13 | After W1's gate failure, W2–W5 ran before the re-spec (all PASS). |
| D14 | The `playwright-appian` skill's invalid front matter is fixed upstream (0.3.1, re-vendored byte for byte); Genesis refuses to provision a skill with invalid front matter. |
| D15 | Stop keeps the session; the next prompt starts with a fixed "previous request was cancelled" note (KiroCrew's approach), read from the stored transcript; no revert. |
| D16 | No path scope on agents' file reads in this phase; confinement stays with Phase 52 (53-02 W15 path-rule findings are its input). |
| D17 | Genesis's skill store accepts bundled files in any subfolder, as the Agent Skills standard does (traversal, dot-file and size caps kept); `appian` is published with its `registry/` folder. |
| D20 | The fleet runs the build-in-progress; the four affected workflows are not run on it until 53-12, and Phase 51's live acceptance is postponed until after the Phase 53 release. |
| D21 | The chat `/` palette offers only `/clear` and `/compact`; engine agent commands are not offered or sent (their trust was never measured). |

Defaults F1–F15 (confirmed): `53-01-findings.md` §8. F16 (composer during a turn: Send and Stop both shown, text-only
steer; confirmed 2026-11-10): §9.5. F17 (per-turn credit provenance on aborted turns): §10.2.

## 4. Current state (code-grounded — full detail in `53-01-findings.md` §2–§3)

| Area | Today | File(s) |
|---|---|---|
| SDK | v2 launch with trust flags; one flat timeout; `_kiro.dev/*` extensions; unknown requests → `{}`; no cancel/load/close; 79 unit tests, no wire tests | `packages/kiro-agent-sdk/src/kiro_agent_sdk/client.py`, `__init__.py`, `messages.py` |
| Workflow nodes | `--trust-tools` / `--trust-all-tools`, SDK default `auto_approve`; tool name from `_meta.kiro.toolName` | `packages/genesis-core/genesis_core/nodes/agent.py:137-406`, `agents/provider.py`, `agents/kiro.py` |
| Chat | `--trust-tools` + `auto_deny`/`ask`; Stop kills kiro-cli; preamble replay; `/clear` `/compact` as prompts; catalog from `session/new.models` + `_kiro.dev/commands/available` | `genesis/genesis/chat/manager.py`, `chat/mcp.py`, `chat/mode_profile.py`, `api/chat.py` |
| Skills | managed workspace + user's `~/.kiro/skills` (chat, and the workflow fallback) | `genesis/genesis/skills/store.py:55-63`, `runtime/context.py:76-97` |
| Readiness | Kiro sign-in only (plus Phase 51's optional Node and Chromium items); no kiro-cli version or engine check | `genesis/genesis/runtime/preflight.py`, `runtime/kiro_auth.py` |
| Phase 51 callers | 3 agent workflows driving `npx --no-install apwt` through the shell (no tool list, 600–900 s turns, inherited env); `playwright-appian` skill from the run checkout; ADR-083's accepted risks | `53-01-findings.md` §9.2–§9.3 |
| Web | model picker, `/` palette, context meter, Clear/Compact, Stop, credit badge, permission card | `genesis/web/src/features/chat/**`, `features/run-detail/**`, `features/catalog/skills/**` |

## 5. Design overview

```
 caller (kiro_node · ChatSession · catalog probe)
   │  KiroAgentOptions(trust=TrustPolicy(builtins, mcp_tools, auto_approved), kiro_home, env, agent_prompt, …)   (F1)
   ▼
 kiro_agent_sdk  ── public names only (import gate, F13) ─────────────────────────────────────────────────────────
   launch     kiro-cli acp --agent-engine v3 [--auth-method]   own process group · explicit env · KIRO_HOME (D6)
   transport  JSON-RPC · unknown request → -32601 · extension requests · notification hook
   session    initialize → session/new {cwd, mcpServers, _meta.kiro.customAgents:[agent_spec]} → set_mode → confirm
              (config_option_update mode = ours, origin client) → MCP readiness (_kiro/mcp/status) → prompt / steer /
              cancel / compact / set_config_option(model) / load / close / delete
   agent_spec Genesis trust → {id, prompt, tools:[v3 ids], permissions:{rules:[mcp allow …]}}  (tool-id fixture)
   permissions identity from _meta → Genesis allowlist backstop → mode (auto_deny · ask · auto_approve) → notice
   updates    session/update → AgentMessageChunk · AgentThoughtChunk · ToolCall · ToolCallUpdate (name, arguments, output)
              session_info_update → usage {credits, context_pct, turn_duration_ms, provenance, model, fallback_from}
   errors · timeouts · auth (access-token responder, used from Phase 52)
   ▼
 kiro-cli v3 engine  ──►  Genesis MCP servers (from the registry, per session) · skills from <cwd>/.kiro/skills
```

| Building block | Sub-spec |
|---|---|
| Findings + decisions | 53-01 |
| Spike: the remaining v3 unknowns, recorded fixtures (gate) | 53-02 |
| ADR draft + data model (Kiro session id per chat) | 53-03 |
| SDK core: launch, transport, session, updates and usage, errors, timeouts, process tree, import gate, fake engine | 53-04 |
| Trust and permissions: agent projection, tool-id table, permission ladder, refusal notice, elicitation, access-token responder | 53-05 |
| Workflow nodes and skills: `kiro_node` on v3, per-run home, managed-only skill resolver, `appian` published | 53-06 |
| Chat backend on v3: modes, catalog, Compact/Clear, Stop, steering, resume, records, MCP notice | 53-07 |
| Readiness: preflight, kiro-cli versions, Settings health; skills cleanup + Update | 53-08 |
| HTTP API | 53-09 |
| Web experience | 53-10 |
| Review, hardening, live acceptance | 53-11 |
| Release + docs write-back | 53-12 |

## 6. Session plan

S1 = 53-02 spike (genesis-dev; **gate**: a "FAIL" on any must-pass item stops the phase for a re-spec of the sub-specs
it affects before anything else is built) → S2 = 53-03 → S3 = 53-04 → S4 = 53-05 → S5 = 53-06 (genesis +
genesis-workflows) → S6 = 53-07 → S7 = 53-08 → S8 = 53-09 (each backend sub-spec adds its routes; 53-09 owns the
contract table and fixtures) → S9 = 53-10 → S10 = 53-11 (genesis-review) → S11 = 53-12 (genesis-release, then
genesis-docs). One at a time: they share the genesis checkout. The v2 path is deleted in the sub-spec that replaces its
last caller (53-07); until then the old client stays importable so every intermediate commit keeps the gates green.

## 7. Sub-phase ledger

| Sub-phase | Repo | Content |
|---|---|---|
| 53-01 | project-tracker | Findings, decisions D1–D12, defaults F1–F15, probe evidence |
| 53-02 | genesis (spike harness + fixtures) | The v3 unknowns (shell, env values, workspace skills under a private home, `session/load` after restart, images, Clear, `tool_load` setting, steering method, model fallback shape, credit-less turns, auth client, HTTP MCP, timings, tool ids vs 2.37.1); recorded frames into `packages/kiro-agent-sdk/tests/fixtures/v3/` |
| 53-03 | genesis, project-tracker | ADR-086 draft (`adr-drafts.md`); migration `m0029`: `chat_sessions.kiro_session_id` (DB v28 → v29) |
| 53-04 | genesis (`packages/kiro-agent-sdk`) | New modules (launch, transport, session, updates, errors, timeouts), process tree, fake engine + fixture replay tests, import-boundary test |
| 53-05 | genesis (`packages/kiro-agent-sdk`) | `TrustPolicy`, agent projection, tool-id fixture + verified versions, permission ladder, refusal notice, elicitation decline, access-token responder |
| 53-06 | genesis (`packages/genesis-core`, `genesis/runtime`), genesis-workflows, playwright-appian | `kiro_node` on v3 (per-run home, D9 trust, v3 tool shapes, credits), managed-only `_skill_source` with a front-matter check, the `appian` skill in the library, `playwright-appian` 0.3.1 skill fix (D14) |
| 53-07 | genesis (`genesis/chat`, `genesis/api/chat.py`) | Chat on v3: chat home, per-mode agents (F2), catalog from `configOptions` + `available_commands_update`, Compact/Clear, Stop = `session/cancel`, steering, `session/load` resume, record deletion, MCP notice, model fallback; v2 client removed |
| 53-08 | genesis | Preflight v3 + minimum version + verified-version warning; Settings health; skills: `personal_dir`/`shadows_personal` removed, Update wired |
| 53-09 | genesis | Contract table (steer endpoint, `usage.model` / `fallback_from`, `session.notice`, preflight items), fixtures, tests |
| 53-10 | genesis (`web/`) | Composer steering, Stop, "answered by <model>", MCP notice, Skills Update button, warning removed, preflight message |
| 53-11 | all | Review + gates + live acceptance on v3 (all 15 agent-node workflows, 53-01 §9.2, and all eight chat modes) |
| 53-12 | genesis, genesis-workflows, project-tracker | Releases + docs write-back (ADR-086, lessons, areas, state, progress) |

## 8. Release plan

One release at the end (D5), after Phase 51's: first **playwright-appian 0.3.1** (D14), published and re-vendored byte for
byte into genesis; then **genesis** next minor after Phase 51's (expected v0.82.0, after any
v0.81.x patches; the
migration from 53-03; SDK, genesis-core and parser at the same shared version, ADR-080), then **genesis-workflows** next
minor (the `appian` skill; pins on the new genesis tag, L-057). Users: Genesis sessions stop loading global Kiro MCP
servers and personal skills; the release notes say how to add a server as a Genesis custom MCP server and how to install
a skill from Settings → Catalog → Skills. kiro-cli must be at least the verified minimum (F5).

## 9. Scope

**In:** §2. **Out:** other agent runtimes; warm process pool; KiroCrew's recovery ladder and crash log; an elicitation
form in chat (F8); live model switching mid-session (models stay "applied at next start", 21-05); multi-user anything
(ADR-026). **Deferred to the backlog** (`specs/backlog/phase-53-follow-ups.md`, created at write-back): the non-SDK
KiroCrew ideas from the 2026-11-03 research (secret-value redaction at write, a tool-call audit log, MCP quarantine,
`genesis doctor`, SSE reconnect, learning from runs, skill usage and evals, CI ratchets), and, for Phase 52, the 53-02
W15 path-rule finding (`fs_read` `match: ["./**"]` confines absolute-path reads; `../`, symlinks, `~` and the search
tools untested; D16), and two 53-08 review nits: a broken SDK install shows the "Install kiro-cli" hint (n1), and a
run's `error` event carries the message and remedy but no `code` (n2).

## 10. Defaults

F1–F15 in `53-01-findings.md` §8 (confirmed 2026-11-03).

## 11. Risks

| Risk | Mitigation |
|---|---|
| CLI 3.0 switches `kiro-cli acp` to v3 before this phase ships (D4/D12) | Accepted; start Phase 53 at once if it happens, or pin `acp.agentEngine` by hand |
| v3 wire behaviour differs from the probe on a later kiro-cli | Recorded fixtures + verified-version list + warning (F5, F14); the spike re-measures |
| A workflow relies on something only v2 did (global MCP server, personal skill, `toolName`) | D5 live acceptance of every agent node; D8 publishes `appian`; release notes |
| The engine drops our custom agent (schema) and runs its default agent | Activation check fails the session closed (53-05) |
| On-demand MCP loading (`tool_load`) costs extra steps | Spike measures; F10 turns it off if so |
| Kiro removes v2 before the release | No effect on this phase (v3 only); Genesis ≤ the previous release stops working; users update |
| Phase 51's open live acceptance ships v0.81.x patches that change its workflows while Phase 53 builds | Each sub-spec rebases on current master before it starts; 53-06 and 53-11 re-diff genesis-workflows (53-01 §9.3 item 8). Since D20, Phase 51's live acceptance waits for the Phase 53 release, so no such patches are expected |
| The fleet runs unreleased Phase 53 code (D20) | Accepted: the four affected workflows are not run on the fleet until 53-12; a chat problem after a fleet restart is fixed in the dev checkout |
| Phase 51 shell turns break on v3 (env, timeouts, process kill) | 53-02 W3/W14/W16 use the real `apwt` workload; 53-04 keeps the inherited env and the program's process reaping; 53-11 A1/A6 |
| QA is unavailable at 53-11, so the three Phase 51 workflows cannot run live | Run everything else; release only with the user's go-ahead, and say plainly that A1 is open for those three (L-111) |

## 12. ADR summaries

- **ADR-086 (proposed) — Kiro v3 engine, Genesis-owned Kiro home, projected trust, managed skills.** Genesis starts
  Kiro only as `kiro-cli acp --agent-engine v3` with a Genesis-owned `KIRO_HOME` (per run; one for chat) and never
  reads the user's `~/.kiro` for agents, MCP servers, skills or steering; tool trust is a projected custom agent
  (explicit tool list + permission rules, activated and verified) plus a Genesis allowlist check; skills come only from
  the managed workspace. Amends **ADR-031** (fail-closed by agent projection, not `--trust-tools`), **ADR-032** (credits
  from `session_info_update` `turn_completion`), **ADR-034** (sanctioned `KIRO_HOME`; personal skills no longer in
  chat), **ADR-045** (the v3 methods: config options, `available_commands_update`, `_kiro/session/compact`,
  `session/cancel`), **ADR-069** (no global-skills fallback; the Phase 51 checkout source for `playwright-appian`
  stays), **ADR-083** (accepted risk d closes; risks a–c stay until Phase 52) and **ADR-029** (a node with no tool
  list gets D9's built-ins and its own servers, not every tool). Draft in 53-03.

## Context manifest

```toml
areas    = ["sdk-acp", "chat", "core-engine", "runs-worker", "config-secrets", "api", "web-runs", "workflows-library", "db", "browser-testing"]
adrs     = ["ADR-002", "ADR-004", "ADR-020", "ADR-029", "ADR-031", "ADR-032", "ADR-033", "ADR-034", "ADR-045", "ADR-051", "ADR-069", "ADR-080", "ADR-083"]
lessons  = ["L-001", "L-011", "L-016", "L-017", "L-024", "L-041", "L-044", "L-046", "L-057", "L-108", "L-111"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-52-agent-runtime-isolation/52-01-findings.md"]
code     = ["genesis/packages/kiro-agent-sdk/**", "genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/genesis/chat/manager.py"]
upstream = []
```
