# 53-11 — Review, hardening and live acceptance

> **Status:** SPEC-DRAFTED 2026-11-03. Repos: genesis, genesis-workflows. Parent: `specs/phase-53-kiro-sdk-v3.md`. Run
> by **genesis-review** (read-only on code) after 53-02..53-10 are BUILT; report in
> `specs/phase-53-kiro-sdk-v3/reviews/53-11-review.md` with SHIP / NEEDS_CHANGES. Findings are fixed by genesis-dev before
> release; each fix gets a regression test.

## 1. Independent review (file:line evidence for each; plus `genesis-ctx check --since <phase base>` per repo)

1. **v3 only** (D5): no `--trust-tools`, `--trust-all-tools`, `--agent-engine v2`, `_kiro.dev/metadata`,
   `_kiro.dev/commands/*`, `_kiro.dev/{compaction,clear}/status`, `session/set_model`, `execute_command`, or slash commands
   sent to make the engine act, anywhere in genesis, genesis-core, the SDK or genesis-workflows.
2. **Kiro home** (D6): every Kiro process has an explicit Genesis-owned `KIRO_HOME`; the SDK refuses to start without one;
   nothing reads `~/.kiro` for agents, MCP, skills or steering (grep `Path.home() / ".kiro"` and `~/.kiro`).
3. **Trust** (D9, F2, 53-05): the projection never emits `all`/`builtin`/`filesystem`, a server glob, or `delete_file`;
   `tools` is always explicit; activation is verified and fails closed; identity comes only from `_meta`; the backstop
   denies anything outside the policy; read-only chat has no built-ins and no mutating tool; copilot's mutating tools
   reach the confirm card (ADR-031, ADR-033).
4. **Credits** (ADR-032): every `credits` value comes from a `turn_completion` credit entry; cancelled / timed-out turns
   per 53-02 W5; `provenance` honest; no number invented.
5. **Contracts** (53-09): the web's shapes unchanged except the listed additions; fixtures regenerated from real
   responses (L-011, L-083).
6. **Process hygiene** (F12): close leaves no kiro-cli or MCP process (checked live, §3).
7. **Import surface** (F13): the gate test exists and passes; no private SDK import.
8. **Secrets / tokens:** no access token, refresh token or secret value in logs, events, evidence or fixtures (F9).
9. **Skills** (D7, D8): no `~/.kiro/skills` fallback; `shadows_personal` gone; `appian` in the library.

## 2. Gates

SDK (`cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q`, `ruff check src tests`), genesis-core
(pytest, ruff), genesis (pytest, ruff), web (`npm run lint && npm run typecheck && npm test`, `npm run build` +
committed `web/static/`), genesis-workflows (`validate_library`, `validate_skills`, pytest), clean-install CI job.

## 3. Live acceptance (local `genesis serve` on the release candidate, kiro-cli at the verified minimum, the user's real
login and apps)

| # | Check | Pass |
|---|---|---|
| A1 | **Every genesis-workflows agent node runs on v3** (D5): run each of the 15 agent-node workflows in 53-01 §9.2 once (or a fixture input that reaches each agent node), including the Implementation lane's `story-implementation` against Dev and Phase 51's `story-verification` (Verification lane), `action-capture` (Record) and `setup-composer` (Compose with AI) on QA, whose shell turns run `npx --no-install apwt` from the run checkout. Prerequisites: QA and its test users available (ADR-082); each tested application's testing workspace updated to `playwright-appian` 0.3.1 (Update testing runtime, D14), with `playwright-appian` and `genesis-test-authoring` both in the engine's skill list of a Phase 51 turn (`_kiro/progressive_context/items_changed`, not a canary in the reply); the `jira`, `jarvis` and `appian-atlas` servers configured in Genesis, since `~/.kiro` no longer supplies them (D6). Before the run, re-diff genesis-workflows against the version the specs were checked at (v0.25.0) for Phase 51 v0.81.x patches | each run completes or reaches its designed gate; every agent turn has `provenance: metered` credits; run detail shows the conversation; no Phase 51 turn ends on a silent or tool-stall limit |
| A2 | Each of the eight chat modes: read-only, copilot (start + supervise a run; confirm card), `feature_spec`, `ux_design`, `technical_design`, `feature_breakdown`, `story_design`, `test_design` | answers; read-only refuses a mutating tool with the notice; copilot's mutation waits for confirm; each spec-style mode writes only inside its sandbox |
| A3 | Chat surface: model picker list + model at start; `/` palette; Compact; Clear; Stop then a fast next turn (no cold start); **Stop before the answer (D15):** in 3 tries, stop a request with a visible side effect (a tool call) about 1 s after sending, then send an unrelated message; repeat once with a `genesis serve` restart between the Stop and the next message; steering (delivered, and one unread re-sent after the turn); restart `genesis serve` and continue a chat (resume by load) | all behave as specified in 53-07 / 53-10; the stopped request is never carried out (any carry-over is a finding that reopens D15) |
| A4 | Isolation: with a server in `~/.kiro/settings/mcp.json` and a skill only in `~/.kiro/skills`, neither appears in chat or a workflow turn; `story-implementation` gets `appian` from the library | as stated |
| A5 | Failure paths: an MCP server that fails to start (chat notice; node fails before the prompt, no credits); kiro-cli below the minimum (preflight + refusal message); an unverified newer kiro-cli (warning only) | as stated |
| A6 | Process hygiene: after A1–A3, no stray `kiro-cli`, `kiro-cli-chat` or MCP server processes (`ps`); after a cancelled `story-verification` run, its `apwt` daemons and Chromium are reaped by the program (`<run>/.pids`), not left behind and not killed early by the SDK | none |
| A7 | Web: real-browser check of the steered bubble, the "answered by" text, the MCP notice card and the Skills Update action at 1280 / 1440 / 1920 px, light and dark (L-090) | no overflow or clipping |
| A8 | Credits sanity: A1's per-node credits in the same range as the same workflow's last v2 runs (± the `tool_load` effect measured in 53-02 W9) | no unexplained jump |

## As built

_To be filled by genesis-review (report path, verdict) and genesis-dev (fixes)._

## Context manifest

```toml
areas    = ["sdk-acp", "chat", "core-engine", "workflows-library", "security"]
adrs     = ["ADR-004", "ADR-011", "ADR-020", "ADR-029", "ADR-031", "ADR-032", "ADR-033", "ADR-034", "ADR-045", "ADR-051", "ADR-069", "ADR-082", "ADR-083"]
lessons  = ["L-011", "L-016", "L-017", "L-041", "L-083", "L-088", "L-089", "L-090", "L-093", "L-101", "L-104", "L-108", "L-111"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3.md", "tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md"]
code     = ["genesis/packages/kiro-agent-sdk/**", "genesis/packages/genesis-core/genesis_core/nodes/agent.py", "genesis/genesis/chat/**", "genesis/genesis/api/chat.py", "genesis/web/src/features/chat/**"]
upstream = ["53-02", "53-03", "53-04", "53-05", "53-06", "53-07", "53-08", "53-09", "53-10"]
```
