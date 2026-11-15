# Phase 53 — Kiro SDK v3: kiro-agent-sdk rebuilt for kiro-cli's v3 engine — as built

> **Status:** 🚢 SHIPPED (live acceptance open) 2026-11-15 · playwright-appian **v0.3.1** (`38f87fd`) → genesis
> **v0.82.0** (`00e8078` = release commit `08f5142` + the idle-reap test fix; the app and the three packages at 0.82.0,
> `CORE_MAJOR` 1 and `KB_FORMAT_VERSION` 1 unchanged) → genesis-workflows **v0.26.0** (`d0c0f53`; skill `appian` 1.0.0,
> no workflow version changed; all internal pins on `genesis.git@v0.82.0`) · m0029 (DB 28 → 29; memory.db v1) ·
> **ADR-086** Accepted (amends ADR-029, 031, 032, 034, 045, 069, 083) · verified on kiro-cli **2.37.1** only.
> **Live acceptance is partly open (D24, D26):** 4 of 15 agent-node workflows were accepted on v3 before the release;
> the rest of 53-11 §5 and Phase 51's postponed acceptance (D20) run after it; findings ship as v0.82.x patches.
> Spec: `specs/phase-53-kiro-sdk-v3.md` + `53-01..53-13` (each with its As built; 53-12 has the As run). Reviews:
> `specs/phase-53-kiro-sdk-v3/reviews/`. Follow-ups: `specs/backlog/phase-53-follow-ups.md`.
> CI: playwright-appian main #7425672 + tag #7425696 (publish, verify-published); genesis master #7425756 (red, the
> Linux `monotonic()` test) → #7425785 + tag #7425844 (six jobs); genesis-workflows master #7425893 + tag #7425904.
> Published tarball sha256 `1388cf9b…2155` (746,256 bytes).

## What changed

- **For a user:** Kiro runs on its v3 engine. Genesis no longer loads the user's global Kiro MCP servers or personal
  skills: add a server as a custom MCP server in Settings, install skills from Settings → Catalog → Skills (which gains
  Update; the `appian` skill is new in the library). In chat, Send during a turn steers it, Stop keeps the session
  (the next prompt starts with a fixed cancelled-request note), a restarted chat resumes its Kiro session, the `/`
  palette offers `/clear`, `/compact` and the managed skills, an MCP server that fails to start shows a notice, and a
  model fallback shows "answered by <model>". Preflight and Settings → General show the kiro-cli version (minimum
  2.37.1; a newer unverified release warns). Applications with a testing workspace run Update testing runtime once
  (playwright-appian 0.3.1).
- **For a developer:** `packages/kiro-agent-sdk` is v3 only (new `launch`, `transport`, `session`, `updates`, `usage`,
  `errors`, `timeouts`, `agent_spec`, `permissions`, `tool_ids`; the v2 client is deleted); `TrustPolicy`, `KiroError`,
  `AgentNotActive`, `SessionStatus`, `check_kiro` are public; `KiroAgentOptions` lost the v2 trust options and gained
  `trust`, `kiro_home`, `skill_dirs` and the rest of F1; recorded v3 fixtures and a replaying fake engine replace
  live-only tests; an import gate enforces the public surface. `kiro_node` keeps its signature (no workflow changed).
  `POST /chat/sessions/{id}/steer` is new; `GET /skills` lost `shadows_personal`; `GET /system/kiro` gained `version`,
  `minimum`, `verified`, `engine_v3`. Code map: `bible/03` "Phase 53" block. Architecture docs: genesis `ea00dfd`.
- **For the agent system:** the `sdk-acp` and `config-secrets` areas now route `runtime/preflight.py`,
  `runtime/kiro_auth.py`, `runtime/context.py` and the SDK's `tests/fixtures/**`; the `genesis-release` skill gained the
  registry-13864 download step and the D27 window.

## Delivered (by sub-spec)

| Sub-spec | Result | Commits |
|---|---|---|
| 53-01 | Findings; probes P1–P17; decisions D1–D27; defaults F1–F18 | — |
| 53-02 | Spike gate: W1 FAIL (playwright-appian 0.3.0 skill front matter, D14; W1 re-run PASS in 53-06), W2–W5 PASS, W6–W19 recorded; 28 fixture pairs + `tool-ids.json`; review SHIP | genesis `c7c05b2`, `a885ca3`, `a13798d`, `a54b1f4`, `e824d3d` |
| 53-03 | ADR-086 draft; m0029 `chat_sessions.kiro_session_id` (DB v29) + `ChatStore.set_kiro_session`; review SHIP (round 2) | genesis `143e9d2` |
| 53-04 | SDK core: launch, transport, session, updates, usage, errors, timeouts, process tree, fake engine, import gates; review SHIP (round 2) | genesis `beea49b`, `07b6d07` |
| 53-05 | `TrustPolicy` + projection, tool-id table, permission ladder (D18, D19), notices, elicitation decline, access-token responder, `check_kiro`; zero-credit projection probe; review SHIP (round 2) | genesis `57a18f9`, `466d51a` |
| 53-06 | `kiro_node` on v3 (per-run `KIRO_HOME`, D9 trust, `_node_mcp_trust`), public names on v3, managed-only skills with the front-matter check, store accepts any folder (D17); `appian` in the library; playwright-appian 0.3.1; live `hello-appian` + a Phase 51-shaped node; review SHIP (round 2) | genesis `0c0a4aa`, `d5a6a4e`; workflows `b097719`; playwright-appian `38f87fd` |
| 53-07 | Chat on v3 (chat home, per-mode policies, resume by load, steering, Stop + D15 note, Clear/Compact/delete), v2 client removed; all eight modes live, Stop carried out 0/7; review SHIP (round 2) | genesis `8139cd2`, `b46c877`, `2af786f` |
| 53-08 | Preflight `kiro-cli` + `kiro-cli-verified`, `/system/kiro` fields, `shadows_personal` removed; review SHIP (round 2) | genesis `bde09e7`, `d2bdec5` |
| 53-13 | Spec-style chat modes reach managed skills through the agent's `resources` (`skill_dirs`); probe R1–R4 + nesting PASS; review SHIP | genesis `480bae9`, `bf908ae` |
| 53-09 | Contract table reconciled (steer `message_seq`, 409 on an unqueued steer, one kiro-cli resolver), contract tests, 16 web fixtures; review SHIP | genesis `330905b` |
| 53-10 | Web: composer steering, Stopped, AnsweredBy, MCP notice card, Skills Update, kiro-cli items, the F18 paragraph break, width probe; review SHIP (round 2) | genesis `b9ba5d9` |
| 53-11 | Independent review: round 1 NEEDS_CHANGES (M1 = D25 skills as engine commands, m1 Skills Update killed a running turn), round 2 NEEDS_CHANGES (B1 a lone `/` crashed, m1 steer path, n1), **round 3 SHIP**; before-release live rows PASS (6.569 credits); python:3.13 image run | genesis `483170e`, `dd27c46`, `61ec063` |
| 53-12 | Release (As run): playwright-appian 0.3.1 published and re-vendored byte for byte; genesis v0.82.0 (first master CI red on a Linux `monotonic()` test, fixed by `00e8078`); genesis-workflows v0.26.0; fleet deployed; this write-back | genesis `08f5142`, `00e8078`; workflows `d0c0f53` |

Tests at release: genesis app pytest **1943** locally (2 deselected: the Docker-hanging readiness probe and the D27
clock test, run alone), **1884 passed + 61 skipped** in CI (1832 / 1778 at v0.81.0); web vitest **764** (66 files; 726
before); genesis-core **109** (96), kiro-agent-sdk **302** (79), genesis-appian-parser all passed + 1 skipped;
genesis-workflows `validate_library` **18**, `validate_skills` **5** (4), pytest **432** (428); playwright-appian
**1402** (1399); agent-system **399**.

## Deploy (53-12 §2, 2026-11-15 03:31–03:36 IST)

Before: both instances healthy, 0 running runs, 0.81.0. **main was already on DB v29** (an earlier restart during the
build applied m0029, D20); **userb was on v28** and migrated at this restart. userb had one run parked at a gate
(`memory-maintenance` at `escalate_reflect`, "could not load the list of models"; left for the user). Backups (SQLite
online backup, integrity ok) under `/tmp/genesis-release-53-12/backup/`. `gsm provision --all --no-mcp --no-env
--force` (18 workflows each), `gsm restart --all`. After: `/openapi.json` 0.82.0 and schema v29 on both;
`/api/system/kiro` 2.37.1, `verified`, `engine_v3` on both; `appian` 1.0.0 installed on both through
`POST /api/skills/install`; main's one testing workspace updated to apwt 0.3.1 (userb has none).

## Live acceptance (53-11 §3, §5)

Before the release, on a separate `genesis serve` at `61ec063` (kiro-cli 2.37.1, the fleet untouched): A1 for
`hello-appian`, `generate-business-map`, `memory-consolidation`, `memory-maintenance` (7 agent turns, all metered);
A3 (Stop 4 + 1 tries, no carry-over; resume by load; models, Compact, Clear, palette); A3b (steers during a tool, late,
after the answer, unread; browser Stop; a mode change that moves the cwd; a Feature Spec skill turn; a skill found
after a load; `~/.local/bin`); A4's chat part; A5 (MCP notice, too-old and newer fakes); A6 (no stray processes); A7
(24 live width checks). Total 6.569 credits. No model-fallback frame occurred.
**Still open (D24, D26):** A1 for the other 8 Appian workflows when Dev is up (`story-implementation` only with the
user's go-ahead, ADR-068), A2's remaining modes, A8, A9(a); and with Phase 51's postponed acceptance (51-12 steps 1–27
on QA, D20), `story-verification`, `action-capture`, `setup-composer` on v3 and the cancelled-run `apwt` reap check.

## Decisions and deviations

- Every decision is in `53-01-findings.md` §7–§10 (D1–D27) and §8 (F1–F18). The spike gate failed on W1 (D14: fix the
  skill upstream, refuse invalid front matter in Genesis); D15 (Stop note, no revert) and D16 (no path scope, Phase 52)
  came from the W19 and W15 results; D18/D19 from the 53-05 build; D20 put the fleet on the build-in-progress and moved
  Phase 51's acceptance after this release; D21 and D25 limit the palette; D22 ships on 2.37.1 only; D23 added 53-13;
  D24, D26 released before all live rows; D27 chose a CI time window over a pre-release test fix.
- No ADR deviation. One spec deviation (53-06 decision 1): `_node_mcp_trust` replaced `_compute_effective_trust`, whose
  `@server/tool` vs bare-name intersection had returned `[]` for every allowlisted server since v2 (L-116).
- **Record vs code, reported:** ADR-086 item 3 says workflow nodes are auto-approved with
  `permission_mode="auto_approve"`; that option no longer exists, the code uses `TrustPolicy(mode="auto_approve")`
  (`genesis_core/nodes/agent.py`). The 53-02 As built and `kiro-cli-3x-reverify.md` §1 count 28 fixture pairs; there
  are 30 (53-05 `projection-probe`, 53-13 `agent-resources-skills`). 53-07's "Final event and record shapes" names the
  steer answer `seq`; 53-09 renamed it `message_seq` (the code). `messages.py` `PermissionRequest` and `ToolCall.name`
  docstrings still describe v2 (backlog-sized). The D15 wording in the findings already matches the ADR (53-03 m2) and
  53-10's W8 already says "not `binary`".
- Release (53-12 As run): the first CI run of Phase 53's 26 code commits was the release commit; Linux `monotonic()`
  counts from boot, so a test using `0` as "long ago" failed on a fresh runner. Fixed test-only in `00e8078` with
  fail-first evidence, not re-reviewed by genesis-review. One playwright-appian push ran inside the D27 window by the
  user's decision (its pipeline does not run the affected test).

## Lessons (write-back decisions)

| Candidate (source) | Decision |
|---|---|
| v3 rejects the trust flags; `tools` absent = no tools (53-01 P1, P5) + `set_mode` answers `{}` for a dropped agent (W4) + v3 accepts and silently ignores (W4, W10, W15) + never choose `*_always` (53-05) + a cancel before the turn begins is `-32603` (53-07) | **Added L-113** (merged) |
| MCP arguments nested under `rawInput.arguments`, `tool_load`, update without a call (P8, W5) + engine steps are not tool output (53-06 m1) + a dead server sends no status (W5) | **Added L-114** (merged) |
| A skill valid for one engine is invisible to another (W1) + tightening a format breaks a writer (`install --skills`, 53-06) | **Added L-115** (merged) |
| v2 hid the allowlist-format bug in `_compute_effective_trust` (53-06) | **Added L-116** |
| A spike recording cannot pin a product shape; probe with a negative control (53-05) + catalog recorded with a bare agent (53-07) + harness answers with the product ladder, a control that lists nothing, the production layout (53-13) + one case per session (53-02) | **Added L-117** (merged) |
| sse-starlette cancels the task group; test the real mechanism (53-07 M1) + TestClient returns a stream only at its end (53-09) | **Added L-118** (merged) |
| Registry 13864 answers 404 anonymously; `npm pack --registry` (53-12) + a vendored-version literal in a test (53-12) | **Added L-119** (merged); the step is also in the `genesis-release` skill |
| Credits moved to `turn_completion`; one prompt is not one engine turn (W5, W7b, F17) | **Extended L-016** (the user's "credits in turn_completion": one home, no new line) |
| Genesis-owned `KIRO_HOME` is sanctioned; skills via cwd or `resources` (D6, 53-13) | **Extended L-024** |
| The v3 methods; the installed engine is a readable bundle (53-02); a version cache keyed on path outlives an update (53-04 m1) | **Extended L-044** |
| No `/` prompt reaches the engine on v3 (D21, D25) | **Extended L-046** (its lead now says "v2 only") |
| `kiro_node` options on v3 | **Extended L-002** (stale v2 field list) |
| `monotonic()` counts from boot on Linux (53-12, CI #7425756) + a global `commit.gpgsign` reaches tests (53-09) + the D27 clock window | **Extended L-112** |
| An import gate misses `from pkg import private_module` (53-04 M1) | **Extended L-088** |
| `readline()` discards an over-limit line; use `readuntil` (53-04) | **Extended L-028** |
| A stale `.pyc` made a mutation check pass (53-08) | **Extended L-110** |
| A new dependency in an aggregate reaches old tests (53-08) | **Extended L-094** |
| Point the fakes at the new recording (53-11 a) | **Extended L-011** |
| Taking a blocking call off the loop removes its accidental serialization (53-11 b) | **Extended L-026** |
| A client joining two streams must key on the stream's events (53-10 M1) | **Extended L-003** |
| A geometry probe on a fixture mock, no backend (53-10) | **Extended L-090** |
| A stopped prompt is not a cancelled request (W19) | **Dropped** as a lesson: home is ADR-086 item 5 (the D15 note) |
| The model writes the `[STEERING …]` acknowledgement into its reply (53-07) | **Dropped**: fixed in code (`strip_steering_acks`, `steering.ts`), narrow |
| Truncating a file at a grep'd line cut appended code (53-05) | **Dropped**: a one-off editing slip |
| A column added for a later sub-spec needs every version pin bumped (53-03, reconfirmed) | **Dropped**: covered by the `genesis-db-migration` skill |
| L-089 batching recurred in 53-06 (`diff -r` with the edit it proved) | **No change**: L-089 covers it; 53-12 reports no recurrence |

## Architecture documents (genesis `ea00dfd`, local)

Rewritten: `modules/kiro-agent-sdk.md`. Updated: `modules/core-engine.md`, `chat-and-skills.md` (the old `:421-427`
skills text, Stop/steer/resume, D21/D25), `configuration-and-secrets.md`, `api.md`, `web-app.md`,
`data-and-migrations.md`, `observability-and-credits.md`, `testing.md` (the 0.3.1 tarball at the old `:144`),
`workflow-library.md`, `runs-and-workers.md`, and all numbered documents, the glossary and the README (ADR-086 and the
seven amended ADRs in `10`). The folder holds none of `trust_tools`, `--trust`, `~/.kiro/skills`, `_kiro.dev/`,
`agent_engine`; `shadows_personal` appears once, in a sentence saying Phase 53 removed it. Not reviewed (their modules
did not change in this release; headers still say v0.81.0): `scheduler-and-jobs`, `collaboration-hub`,
`features-and-stages`, `appian-parser`, `stories-and-workbench`, `memory`, `distribution`, `knowledge-base`,
`documents`. No module document is "planned". The edits were drafted by three genesis-dev sub-agents with disjoint
files and checked here (stale-term grep, headers, cross-document anchors; one broken anchor in `07` fixed).

## Agent-system notes

1. Areas: `sdk-acp` gains `runtime/preflight.py`, `runtime/kiro_auth.py`, `runtime/context.py` and
   `packages/kiro-agent-sdk/tests/fixtures/**`; `config-secrets` gains the three runtime files (so `check` prints the
   genesis gates for them).
2. Skill changed: `genesis-release` (download a published tarball with `npm pack --registry`, compare `dist.shasum`,
   re-vendor; the D27 CI window). Run `agent-system/update.sh` to install it.
3. L0: ADR-086, seven lessons and the amendment tags pushed L0 past 24,000 tokens; the state snapshot was compressed
   (Testing and Applications detail now point to their progress docs) and the ADR-029 one-liner rewritten for ADR-086.
   No rule was dropped.
4. ADR-086's body and lesson bodies were written from scratch files under `context/.packs/` (git-ignored); every
   `genesis-ctx add` ran alone.
