# 53-03 — ADR draft and data model

> **Status:** SPEC-DRAFTED 2026-11-03. Repos: **genesis** (one migration, store change), **project-tracker**
> (`phase-53-kiro-sdk-v3/adr-drafts.md`). Parent: `specs/phase-53-kiro-sdk-v3.md`. Decisions: 53-01 D1, D5–D10; F4.
> genesis-docs adds the ADR at write-back (53-12); this sub-spec writes the draft only.

## 1. Goal

Write the ADR text the phase builds under, so every later sub-spec cites one rule, and add the one column chat needs to
resume a Kiro session (F4).

## 2. ADR draft (`specs/phase-53-kiro-sdk-v3/adr-drafts.md`)

**ADR-086 (proposed; number fixed at write-back, after Phase 51's ADR-081..085) — Genesis drives Kiro only through the
v3 engine, with a Genesis-owned Kiro home, projected trust and managed skills.** Areas: `sdk-acp`, `chat`,
`core-engine`, `config-secrets`, `security`. Amends ADR-029, ADR-031, ADR-032, ADR-034, ADR-045, ADR-069, ADR-083.

The draft states, each with its reason and evidence (53-01 §3 probe ids, §7 decision ids):

1. Every Kiro process Genesis starts is `kiro-cli acp --agent-engine v3` (no trust flags; they are rejected, P1).
2. Every process gets an explicit, Genesis-owned `KIRO_HOME`: `<run folder>/_kiro/` per workflow run,
   `~/.genesis/kiro-home/chat/` for chat and the catalog probe. Genesis never reads the user's `~/.kiro` for agents, MCP
   servers, skills or steering (D6). The user's login is unaffected (P16). (Reconciles ADR-034's and L-024's "never set
   `KIRO_HOME`": that warning was about relocating the user's agents, sessions and login inside the user's own home;
   Genesis's homes are separate folders and the login does not live in `KIRO_HOME`.)
3. Tool trust is a **projected custom agent** sent in `session/new` (`_meta.kiro.customAgents`): an explicit tool list in
   v3 ids, permission rules that auto-approve only what Genesis trusts, and activation by `session/set_mode` that is
   **verified** (fail closed if the agent is not the active mode or not `origin: client`). Behind it, the SDK checks
   every permission request against the Genesis allowlist before answering. ADR-031's fail-closed chat and ADR-029's
   `node.tools ∩ allowlist` cap are enforced this way (D9, F2).
4. Credits and context come from `session_info_update` (`turn_completion` → `promptTurnSummaries` credit entries;
   `context_usage`); the ADR-032 rule (real, per turn, provenance, never estimated) is unchanged (P10).
5. The chat surface uses v3's methods: models via `session/set_config_option`, the command list from
   `available_commands_update`, Compact via `_kiro/session/compact`, Clear by a new Kiro session, Stop via
   `session/cancel` (keeps the session), steering; `_kiro.dev/commands/execute` and `session/set_model` are not used
   (P11, P12, P13; D10).
6. Skills come only from Genesis's managed workspace, for chat and workflows; no fallback to `~/.kiro/skills` (D7, D8).
   The one other source is Phase 51's `playwright-appian` skill, read from the run's own workspace export (51-07 §7,
   53-01 §9.3 item 5).
7. **ADR-083 and ADR-029 (53-01 §9.3 item 7).** ADR-083's accepted risk (d) closes: no workflow turn loads the user's
   global Kiro MCP servers. ADR-029/083's "a node with no tool list trusts every tool" becomes "D9's built-ins plus the
   node's own servers within their allowlists", enforced by the projected tool list. ADR-083's risks (a)–(c) stay
   open until Phase 52, and the agent shell still inherits the worker's environment.

## 3. Data model

- **Migration** (next free number after Phase 51's last `m0028_capture_request`, so `m0029`; DB v28 → v29): `ALTER TABLE chat_sessions ADD COLUMN
  kiro_session_id TEXT` (nullable). The id of the v3 session a chat last used, so the chat can `session/load` it after an
  idle reap or restart (F4). Forward-only, idempotent per the runner's rules (`genesis/genesis/db/`).
- **Store** (`genesis/genesis/chat/store.py`): `ChatSessionRecord.kiro_session_id`; `set_kiro_session(id, value)`;
  read tolerant of the column's absence like `model` (`store.py:50-53`).
- No change to `chat_messages`: a steered message is a user message with `meta_json.kind = "steer"` (D10), the existing
  meta column (Phase 46-04). `usage` JSON gains the optional `model` and `fallback_from` keys (F6); no schema change.

## 4. Tests

Migration up on a v(current) DB copy and on an empty DB; store round-trip of `kiro_session_id`; an old row reads as
`None`.

## As built

_To be filled by genesis-dev._

## Context manifest

```toml
areas    = ["db", "chat", "sdk-acp"]
adrs     = ["ADR-030", "ADR-031", "ADR-032", "ADR-034", "ADR-045", "ADR-069", "ADR-029", "ADR-004", "ADR-020", "ADR-083"]
lessons  = ["L-004", "L-024", "L-091"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-51-test-execution-engine/adr-drafts.md"]
code     = ["genesis/genesis/db/migrations/**", "genesis/genesis/db/__init__.py", "genesis/genesis/chat/store.py"]
upstream = ["53-02"]
```
