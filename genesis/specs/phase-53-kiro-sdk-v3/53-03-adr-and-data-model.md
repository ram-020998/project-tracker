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
   Genesis's homes are separate folders and the login does not live in `KIRO_HOME`.) What this does **not** promise:
   the engine loads nothing from `~/.kiro`, but an agent's built-in read tools can still read any path the user can,
   including `~/.kiro` (53-02 W1: the agent listed it unprompted; ADR-083 risk a). That closes in Phase 52; this phase
   adds no path scope (D16).)
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

_2026-11-10, genesis-dev._ Base: genesis `e824d3d` (= `62537c2` + the five 53-02 commits, local `master`, clean; no
rebase needed). project-tracker `fb51bd1` (spec set final through `3f46621`).

**Task restated.** Write the ADR-086 draft (§2 items 1–7, each with its reason and 53-01/53-02 evidence, reflecting D6
with D16's "what this does not promise", D14, D15, the W4 activation rule and F17), and add the one column chat needs to
resume a v3 session: m0029 `chat_sessions.kiro_session_id`, with the store field and setter, unused until 53-07.
Rules applied: ADR-030 (SQLite, DB-agnostic repository signatures), ADR-031/032/034/045/069/029/083 (the ADRs the draft
amends), ADR-004/020 (per-session MCP, no global Kiro mutation); L-004 (DDL only in a migration), L-024 (reconciled in
item 2), L-091 (`set_kiro_session` is a single UPDATE, no read-validate-write), L-092 (no `test_*` name in the
migration module), L-102 (an `ADD COLUMN`, not a rebuild, so no `foreign_keys_off`).

### Commits

- genesis `143e9d2` — feat(db,chat,53-03): m0029 + store + tests + README DB line.
- project-tracker — `adr-drafts.md`, this As built and `reviews/53-03-review.md` (one commit, after the review).

### Changed

- `genesis/db/migrations/m0029_chat_kiro_session.py` (new): `ALTER TABLE chat_sessions ADD COLUMN kiro_session_id
  TEXT`, guarded by `PRAGMA table_info` (re-run is a no-op), `Migration(version=29, name="chat_kiro_session")`.
- `genesis/db/migrations/__init__.py`: m0029 appended to `MIGRATIONS`.
- `genesis/chat/store.py`: `ChatSessionRecord.kiro_session_id: str | None = None` (before `message_count`; every
  construction is by keyword), read tolerant of the column's absence like `model`; `ChatStore.set_kiro_session(
  session_id, kiro_session_id | None)`. `get`/`list` already `SELECT s.*`, so they carry it. `api/chat.py:54` builds
  the session dict field by field, so the column does not reach the web (53-09 decides).
- `README.md`: "migrations m0001–m0029 (DB v29)". The status line still names v0.81.0 (the release, not the DB).
- `specs/phase-53-kiro-sdk-v3/adr-drafts.md` (new): ADR-086, header table for `genesis-ctx add adr` + body.

### Tests

- New, `tests/test_chat_store.py`: m0029 on a fresh DB → v29, column `TEXT` / nullable / no default, `_up` re-run
  no-op, no `test_*` names (L-092); a populated v28 DB (`MIGRATIONS[:28]`: a copilot chat with a model, a spec chat,
  messages with usage and meta) → `migrate == [29]`, every session and message row identical apart from the new NULL
  column, `foreign_key_check` empty, the old row reads `kiro_session_id is None`; `set_kiro_session` round trip in
  `get` and `list`, replace, clear with `None`, `updated_at` unchanged, an unknown chat is a no-op; a pre-m0029 DB read
  through the store returns `None`.
- Version pins 28 → 29 in `test_db.py` (applied lists, row count, a row-29 name check, `current_version`, `pending`),
  `test_board_store`, `test_chat_store`, `test_collab_migration`, `test_document_store`, `test_feature_store`,
  `test_kb_store`, `test_object_wiki`, `test_stage_store`; the m0028 tests in `test_testexec_recording.py` now pin
  `MIGRATIONS[:28]` (the precedent m0027's tests set).
- **Real-data copy** (one-off, not in the suite): a `sqlite3` backup-API copy of `~/.genesis/genesis.db` (opened
  `mode=ro`) in a temp folder: v28, 32 sessions / 123 messages → applied `[29]`, v29, counts unchanged, 0 non-null
  `kiro_session_id`, 0 foreign-key violations, `integrity_check` ok, `ChatStore.list` 32, second `migrate` `[]`; temp
  folder removed. The live DB was not migrated (the fleet migrates at its next update, after a backup).
- Gates: `pytest -q` **1843 passed** (4 of them new here); `ruff check genesis` clean; the touched test files are
  clean apart from the pre-existing `tests/test_db.py:16` F401 (unused `tempfile`, present at `e824d3d`). `ruff check
  genesis tests` reports 26 findings, all in code this change did not touch; CI runs `ruff check genesis`.

### Review

- Round 1 (`reviews/53-03-review.md`): **NEEDS_CHANGES**, from the ADR draft only; the code was found ready as
  committed. Fixed in `adr-drafts.md`: M1 `--amends` as seven space-separated ids after one flag (`nargs="+"`; a
  repeated flag would keep only ADR-083), the "repeat the flag" hint removed; m1 filing note: `--status accepted`,
  `--body-file` from `- **Context.**` on (the tool writes the Status line); m2 item 5: W19 b tested a shorter line, the
  D15 wording is first tested in 53-11 A3, and the note is adapted from KiroCrew's flag but carries no stopped-turn text
  (checked: `KiroCrew/src/kiro_crew/context_assembly/replay.py:565-573`); m3 the rule; n1 KiroCrew cite `:856-930`
  (checked: `_verify_spawn_agent_active` `:875`, `activation_refusal` `:903`); n2 ADR-031 items 1–2, item 3 unchanged;
  n3 "MCP read tools"; n4, n5 in this As built.
- Round 2 (same report): **SHIP**. Its optional nit r2-n1 (the `prev_turn_cancelled` cite pointed at `replay.py`) is
  fixed: `session_parts/record.py:151`, consumed at `dashboard/chat_turn/prompt_assembly.py:712` (checked).

### Decisions / deviations

- **`set_kiro_session` does not touch `updated_at`** (unlike `set_model`): the Chat page orders by it, and a new Kiro
  session (start, resume, Clear) is not user activity. No ADR deviation.
- **ADR draft `--rule`** (214 chars) says "nothing loaded from ~/.kiro; reads unscoped", so the digest line alone
  carries D6's limit; the body's "what this does not promise" gives the detail (D16, ADR-083 a). Review m3.
- **For 53-07 (review n4):** `ChatStore.create` inserts five named columns and does not write `kiro_session_id`; a
  record passed to `create` with the field set loses it. Store the id only with `set_kiro_session` after `session/new`.
- **For genesis-docs (review m2):** 53-01 D15 says "the same instruction stopped it 0/3", but W19 b ran a shorter line,
  not the D15 wording, and KiroCrew's `cancelled_turn_preamble` re-sends the stopped turn's text, which Genesis's note
  does not. The ADR draft says so; D15's wording in the findings should match at write-back.
- **Item 6 includes D8's "a declared skill that is not installed fails the run at the start"** and §10.1's "check the
  engine's skill list, not a canary", both from the spec set, so 53-06/53-08 cite one rule.
- No ADR deviation.

### Lesson candidates

- None new. (Reconfirmed: a column added for a later sub-spec needs every `current_version == N` pin bumped and the
  previous migration's tests pinned to `MIGRATIONS[:N]`; 13 files here.)

### Code-map changes

- `genesis/genesis/db/`: m0029 `chat_kiro_session` (`chat_sessions.kiro_session_id`), DB v29.
- `genesis/genesis/chat/store.py`: `ChatSessionRecord.kiro_session_id`, `ChatStore.set_kiro_session`.

## Context manifest

```toml
areas    = ["db", "chat", "sdk-acp"]
adrs     = ["ADR-030", "ADR-031", "ADR-032", "ADR-034", "ADR-045", "ADR-069", "ADR-029", "ADR-004", "ADR-020", "ADR-083"]
lessons  = ["L-004", "L-024", "L-091"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md", "tracker:specs/phase-51-test-execution-engine/adr-drafts.md"]
code     = ["genesis/genesis/db/migrations/**", "genesis/genesis/db/__init__.py", "genesis/genesis/chat/store.py"]
upstream = ["53-02"]
```
