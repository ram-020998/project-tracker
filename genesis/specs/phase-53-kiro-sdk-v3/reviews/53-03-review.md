# Review 53-03 — base genesis `e824d3d`, change `143e9d2` + project-tracker working tree (genesis-review, 2026-11-10)

What this change does: adds migration m0029, which puts a nullable `chat_sessions.kiro_session_id TEXT` column in place
(DB v28 → v29). It adds `ChatSessionRecord.kiro_session_id` and `ChatStore.set_kiro_session`, and bumps every
version pin. Nothing reads the column until 53-07. In project-tracker (uncommitted) it adds `adr-drafts.md` with the
ADR-086 draft, plus the 53-03 As built.

Resolved: `git rev-parse --short HEAD` = `143e9d2`, the working tree is clean, and `e824d3d..HEAD` is that one commit.
`genesis-ctx check --since e824d3d --repo genesis` maps 14 files to areas chat, db, release-ci and security.

## Checklist

### ADRs
- [N/A] ADR-001: no control-flow change.
- [N/A] ADR-002: the code does not touch the SDK. The draft keeps the rule (item 2: "`session/new.mcpServers` (ADR-002/004)").
- [N/A] ADR-004: no code change. The draft closes the gap ADR-083 (d) names (item 7, P15 against P16).
- [N/A] ADR-005: untouched.
- [OK] ADR-010: the column stores one id, a pointer to the engine's session record (`m0029_chat_kiro_session.py:22`).
- [N/A] ADR-011: no agent node.
- [N/A] ADR-019: no core change. The draft says `CORE_MAJOR` stays 1 (Consequences, "Unchanged").
- [N/A] ADR-020: no code change. The draft says Genesis neither mutates nor reads the global configuration.
- [N/A] ADR-021, ADR-068: no gates and no mutation.
- [OK] ADR-024: the store keeps the existing sync `Database.tx()` pattern, and nothing new runs on an event loop.
- [N/A] ADR-026, ADR-028, ADR-085: no endpoint. `api/chat.py:52-55` `_session_dict` builds its dict field by field, so the column is not exposed.
- [N/A] ADR-027, ADR-055: no web change.
- [OK] ADR-029: the draft amends it (item 7 and Consequences), and the wording matches 53-01 D9(2) and §9.3 item 7.
- [OK] ADR-030: SQLite stays, and `set_kiro_session(session_id, kiro_session_id)` has a DB-agnostic signature (`store.py:153`).
- [OK] ADR-031: no chat behaviour changes. The draft amends the enforcement mechanism (see nit n2) and the cold-client preamble ("bounded transcript preamble", ADR-031 text).
- [OK] ADR-032: the code adds no figure. Draft item 4 matches F17 and `eventlog.py:188-207`, where `partial` is an aggregate only.
- [N/A] ADR-033: unchanged. The draft keeps the confirm cards (item 3: copilot mutating tools reach `ask`).
- [OK] ADR-034: the draft's amendment matches the ADR's own text, "Genesis does **not** set `KIRO_HOME` … The user's own global `~/.kiro/skills/` remain active". `fs_write_root` is unchanged.
- [N/A] ADR-035, 036, 037, 041, 042, 046, 047, 050, 053, 054, 059, 060, 063, 065, 070, 072, 073, 074, 075, 076, 078, 080, 081: these areas are not touched (no KB, document, stage, story, memory, test or release code).
- [OK] ADR-045: the draft's amendment matches P11/P12 and W7/W8/W10.
- [N/A] ADR-051: no change. The draft lists it as unchanged.
- [OK] ADR-069: the draft reconciles alternative (c), which the ADR states as "Set `KIRO_HOME` to relocate skills — rejected (… relocates the user's agents/sessions/auth)", using P16.
- [N/A] ADR-077: no agent-system change.
- [N/A] ADR-082: no execution.
- [OK] ADR-083: the draft's risks (a)–(d) match the ADR's accepted-risks text word for word in substance. (d) closes, and (a)–(c) stay open.

### Lessons
- [N/A] L-001: no MCP env built. The draft cites W2's list form.
- [OK] L-004: the DDL lives only in the migration. The store issues plain UPDATE and SELECT.
- [N/A] L-007, L-018, L-041, L-042, L-046, L-047, L-058, L-061, L-069, L-073, L-086, L-093: no transcript, SSE, fs, finalizer or web code.
- [N/A] L-016: no credits change. Draft item 4 says the rule is unchanged.
- [N/A] L-017: no trust code. Draft item 3 keeps fail-closed.
- [OK] L-024: draft item 2 reconciles it with evidence (P16: credentials are not under `KIRO_HOME`).
- [OK] L-025/L-027: ruff is pinned (`ruff 0.15.20` in the venv), unchanged.
- [OK] L-026: no blocking write inside an async node. `set_kiro_session` has no caller yet. 53-07 must call it off the loop, the same way `set_model` is used today.
- [N/A] L-030, L-051, L-056, L-057, L-098, L-099, L-100, L-101, L-104, L-105, L-111, L-112: no release, pin, CI-variable, npx, process or report work. No live acceptance is required (brief).
- [OK] L-039: `get` and `list` both `SELECT s.*` through the same `_from_row` (`store.py:105-127`). `test_set_kiro_session_round_trip_and_clear` asserts the value via both.
- [OK] L-044, L-087: the draft's claims rest on the installed CLI (P1–P17 and W1–W19 on 2.37.1).
- [N/A] L-045: no chat surface change.
- [N/A] L-088, L-089: no hook or bundle.
- [OK] L-091: `set_kiro_session` is one UPDATE with no read-validate-write (`store.py:159`).
- [OK] L-092: the migration module has no `test_*` name, and the test asserts this (`test_chat_store.py:95`).
- [OK] L-102: this is an `ADD COLUMN`, not a rebuild, so `foreign_keys_off` stays False (asserted at `test_chat_store.py:94`). `foreign_key_check` is empty after the upgrade (`:116`).
- [N/A] L-103: no derived index.

### Gates
- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings`: **1843 passed** in 584 s (run by me at `143e9d2`). The touched files alone: 77 passed.
- [OK] `cd genesis && .venv/bin/ruff check genesis`: clean. The touched test files are clean except `tests/test_db.py:16` F401 (unused `tempfile`), which is already present at `e824d3d` (`git show e824d3d:tests/test_db.py`). See nit n5.
- [N/A] `packages/kiro-agent-sdk` pytest: the SDK is not touched.
- [N/A] web lint/typecheck/test/build: no `web/**` file changed.
- [OK] Downstream pins: `genesis-workflows/workflows/**` has no `current_version` or `== 28` pin, so m0029 breaks no library test.

## Findings

### Blockers
None.

### Majors
- M1 **The `--amends` row does not match `genesis-ctx add adr`, and the fallback hint would silently drop six amendments**
  (`adr-drafts.md`, header table row `--amends` and the Status note).
  - What: the row gives one comma-joined value, `ADR-029,ADR-031,ADR-032,ADR-034,ADR-045,ADR-069,ADR-083`. The note
    adds: "If `add adr` takes one id per `--amends`, repeat the flag."
  - Problem: `cli.py:72` declares `--amends` with `nargs="+"` (space-separated ids after one flag). `add.py:57-60`
    runs `md.parse_adr_id` on each value, and `parse_adr_id` uses `re.fullmatch(r"(?:ADR-?)?0*(\d{1,3})", …)`
    (`md.py:82`). The comma string therefore fails with `--amends ADR-029,ADR-031,…: no tag entry for that ADR`.
    Following the hint is worse: argparse's default `store` action keeps only the last `--amends`. ADR-086 would then
    amend only ADR-083, and `amended_by` would never be set on ADR-029, 031, 032, 034, 045 or 069. Those six digest
    lines (L0, e.g. "ADR-029 (amends 005,020; amended by 083)") would not point at ADR-086. No warning fires, because
    the body names all seven ADRs (`add.py:69-71` warns only for amended ids).
  - Fix: set the row to `ADR-029 ADR-031 ADR-032 ADR-034 ADR-045 ADR-069 ADR-083` (space-separated, one flag) and
    delete the "repeat the flag" sentence.
  - If skipped: genesis-docs either hits an error at 53-12, or files an ADR whose amendment chain covers one of seven
    ADRs, and the digests every agent loads miss the new rule.

### Minors
- m1 **Following the filing note gives a doubled Status line and a stale `proposed` tag** (`adr-drafts.md` note and the `--status` row).
  - What: `add.py:65-68` already writes `## ADR-086 — <title> — **Proposed**` and `- **Status:** **Proposed** — <date>.`.
    The body file the note prescribes (the bullet list) also starts with `- **Status:** **Proposed** — 2026-11-10 …`.
  - Problem: the decision log gets two Status bullets. Editing "the Status line to Accepted" afterwards leaves
    `tags/adr.toml` `status = "proposed"` and the heading `**Proposed**`, so `genesis-ctx` keeps reporting it as proposed.
  - Fix: in the note, tell genesis-docs to pass `--status accepted` at write-back and to start `--body-file` at
    `- **Context.**`, folding the Status details (versions, spec set) into the tool's Status line by one edit. Or keep
    the body's Status bullet and delete the tool's.
- m2 **Item 5 overstates the evidence for the Stop note**, also in "Reason" (item 5, Evidence and Reason).
  - What: the draft says "W19 (b: the fixed line stopped the carry-over 0/3)" and "the note is KiroCrew's approach
    (`context_assembly/replay.py` `cancelled_turn_preamble`)".
  - Problem: W19 b tested a different, shorter line, "The previous request was cancelled by the user. Do not continue
    it." (53-02 As built, W19 row). The chosen D15 wording ("…Answer only the request below; use the cancelled request
    only if this request refers to it.") has not run once. KiroCrew's `cancelled_turn_preamble` does the opposite of
    Genesis's guarantee: its docstring (`replay.py:566-573`) says it "takes the user message that opened the turn …
    plus the assistant text", while the draft promises the note "never contains the stopped request's text". A reader
    of the ADR would believe the exact note and the reference design were both validated.
  - Fix: "W19 b: a shorter fixed line stopped the carry-over 0/3; the D15 wording is first tested in 53-11 A3", and
    "adapted from KiroCrew's one-shot cancelled-turn flag (`prev_turn_cancelled`); unlike KiroCrew's preamble, the note
    carries no text from the stopped turn". The same looseness is in 53-01 D15 ("the same instruction stopped it 0/3"),
    so report it to genesis-docs.
- m3 **The digest rule drops D6/D16's limit** (`--rule`).
  - What: the rule (208 chars, within the 220 limit, `config.py:24`) says "never loading ~/.kiro".
  - Problem: the rule is the only line most agents see (the L0 ADR digest). Read alone, it says agents cannot reach
    `~/.kiro`, which W1 disproves (the agent listed `~/.kiro/skills` unprompted). The brief asks the ADR to carry D6
    with the "what this does not promise" wording, and the body does. The As built's "Decisions" note explains the
    intent, but that note is not filed.
  - Fix (214 chars, verified with `len`): `Start Kiro only as kiro-cli acp --agent-engine v3 under a Genesis-owned KIRO_HOME
    (nothing loaded from ~/.kiro; reads unscoped); trust: a projected agent, activation verified, fail closed; skills
    only from Genesis.`

### Nits
- n1 The KiroCrew citation `acp/runtime_session_create.py:776-866` (item 3 Evidence) points mostly at handle
  bookkeeping. The activation guards (A2 `_verify_spawn_agent_active`, A, C `activation_refusal`) and the `set_mode`
  call are at `:856-930`. Cite `:856-930`.
- n2 Consequences, "Amends ADR-031: enforcement items 1–3 change mechanism". ADR-031 item 3 (`allow_fs_write=False`,
  the client refuses `fs/write_text_file`) does not change: P9 shows the write is still a client call the client can
  refuse. Say "items 1–2", and add the SDK backstop as new.
- n3 Item 3, "chat `read_only` and `copilot` list only the mode's MCP tools, read tools with allow rules". F2 says
  "MCP read tools get allow rules". Write "MCP read tools" so no one reads it as built-in `read_file` in those modes.
- n4 `ChatStore.create` (`store.py:96-99`) inserts five named columns, so a `ChatSessionRecord(kiro_session_id="x")`
  passed to `create` loses the value silently. No caller does this today (`chat/manager.py:427`), and the field
  comment says only `set_kiro_session` writes it. Leaving it is fine. 53-07 should know.
- n5 The As built Gates line says "`ruff check genesis` + every touched test file clean", but touched
  `tests/test_db.py:16` has an F401. It is pre-existing, and the same paragraph cites it. Reword to "clean apart from
  the pre-existing `tests/test_db.py:16`".

## Not checked
- The original evidence files the draft cites but that sit outside this phase's folders: `d3c-p10.json` (51-03 P10),
  52-01 D11 and 51-07 §7. I took their content from 53-01 §7 and §9.3 as quoted.
- The real-data migration on a copy of `~/.genesis/genesis.db` (the author's one-off: 32 sessions, applied `[29]`). I
  did not repeat it. The suite's populated-v28 upgrade test covers the same path.
- The fleet DB migration (main and userb at v28). It happens at the next fleet update, after a backup, and is not
  needed for this sub-spec (brief: no live acceptance).
- Whether `playwright-appian` 0.3.1 (item 6, "fixed upstream") exists yet. Item 6 describes D14's planned end state.
  The repo shows 1 dirty file, not inspected.

## Verdict: NEEDS_CHANGES
The code is ready to ship as committed: the migration, the store change, the tests and the pins are correct, and all
gates are green. The verdict comes only from the ADR draft. Before the project-tracker commit, fix M1 (the
`--amends` value and the hint). m1–m3 are small text edits in the same file and should go in the same pass. Re-review
needs only `adr-drafts.md`.

---

# Round 2 — project-tracker working tree only (genesis-review, 2026-11-10)

Scope, per the round-1 verdict: the uncommitted `adr-drafts.md`, plus the 53-03 As built "Tests", "Review" and
"Decisions / deviations" entries. genesis is unchanged: `rev-parse --short HEAD` = `143e9d2`, working tree clean, so the
round-1 code checklist and gates (pytest 1843 passed, ruff clean) stand.

## Round-1 findings, re-checked

- [OK] **M1** — the `--amends` row is now `ADR-029 ADR-031 ADR-032 ADR-034 ADR-045 ADR-069 ADR-083`, which matches
  `cli.py:72` (`nargs="+"`). Each id passes `md.parse_adr_id`, and all seven have tag entries (they appear in the
  digest). The "repeat the flag" hint is gone. The filing note explains why ("a repeated flag keeps only the last id,
  and a comma-joined value is refused"). The body has an "Amends ADR-0NN" phrase for all seven ids, so
  `add.py:69-71` will print no warning.
- [OK] **m1** — the note says to pass `--status accepted`, which `cli.py:73` allows (`choices=["proposed", "accepted"]`).
  The `--body-file` starts at `- **Context.**`, so `add.py:66-67` writes the one heading and the one Status line as
  Accepted, and the tag reads `status = "accepted"` (`add.py:80`). The `--status` row says "`accepted` at filing".
- [OK] **m2** — item 5's Evidence quotes W19 b's shorter line and says the D15 wording is first tested in 53-11 A3. The
  Reason says the note is adapted from KiroCrew's `prev_turn_cancelled` flag and, unlike `cancelled_turn_preamble`
  (`KiroCrew/src/kiro_crew/context_assembly/replay.py:565`), carries no stopped-turn text. The Risk line names 53-11
  A3. The As built Decisions entry reports the D15 mismatch to genesis-docs. See nit r2-n1 for the citation path.
- [OK] **m3** — the `--rule` is the proposed text, 214 chars (`python3 len`), within `RULE_MAX_CHARS` (220,
  `add.py:28`).
- [OK] **n1** — the cite is now `:856-930`. `_verify_spawn_agent_active` is at `runtime_session_create.py:875`
  (grep confirms), and the set_mode block starts at `:856`.
- [OK] **n2** — Consequences now says "items 1–2 change mechanism". It names the SDK backstop as new and item 3 as
  unchanged (P9).
- [OK] **n3** — item 3 now reads "MCP read tools with allow rules".
- [OK] **n4** — As built Decisions, "For 53-07 (review n4)", tells 53-07 to store the id only with `set_kiro_session`.
- [OK] **n5** — As built Tests, Gates now reads "clean apart from the pre-existing `tests/test_db.py:16` F401". It also
  records the 26 `ruff check genesis tests` findings in untouched code and that CI runs `ruff check genesis`.

Also checked: `_with_phase` (`add.py:39-44`) leaves the title alone because it already contains "(Phase 53)", so
`--phase 53` does not double it. The `--areas` value names five areas that are in the catalog.
`genesis-ctx lint --specs-only` → "0 errors, 0 warnings" (run by me). The As built Review entry gives an accurate
account of round 1.

## New findings

### Blockers / Majors / Minors
None.

### Nits
- r2-n1 **The `prev_turn_cancelled` citation points at the wrong file** (`adr-drafts.md` item 5, Reason).
  - What: the draft writes "`prev_turn_cancelled`, `context_assembly/replay.py`".
  - Problem: the flag is not in `replay.py`. It is defined in `kiro_crew/session_parts/record.py:151` and consumed in
    `kiro_crew/dashboard/chat_turn/prompt_assembly.py:712-713`, which clears it after one use. `replay.py` holds only
    `cancelled_turn_preamble`. A reader who follows the cite will not find the flag there.
  - Fix: "(`prev_turn_cancelled`, `session_parts/record.py:151`, consumed once in
    `dashboard/chat_turn/prompt_assembly.py:712`)". Optional. genesis-docs can make this edit at filing.

## Not checked (round 2)
- Same as round 1. Also, I did not rerun the gates on genesis: the code is unchanged since round 1 (`143e9d2`, clean
  tree).

## Verdict: SHIP
M1 and m1–m3 are fixed, all nits are handled, and the specs lint is green. The genesis commit `143e9d2` and the
project-tracker files (`adr-drafts.md`, the 53-03 As built, this report) are ready to commit. r2-n1 is optional.
