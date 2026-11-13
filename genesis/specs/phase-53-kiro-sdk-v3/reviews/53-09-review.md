# Review 53-09 — base bf908ae (genesis-review, 2026-11-13)

What this change does: it makes the 53-09 contract table match the routes. Two code fixes on the steer route:
`POST /steer` now answers `message_seq`, and it returns 409 with nothing stored when the engine does not queue the
steer. It fixes `/system/kiro` `installed` by reading the binary `check_kiro()` resolves, through a new additive
`binary` key (53-08 m3). It adds a contract test per row and records 16 web contract fixtures
(`web/src/test/fixtures/{chat,system,skills}/`) from responses of the real app.

Reviewed: `git diff bf908ae` in genesis (uncommitted working tree, 10 modified files) plus the untracked
`tests/test_phase53_api_contract.py` and the 16 fixture files. Base `bf908ae` exists and is local master HEAD. Nothing
committed, pushed or tagged by this review.

## Checklist

ADRs
- [N/A] ADR-001 — no graph or control-flow change.
- [N/A] ADR-002 / ADR-004 / ADR-020 — no MCP injection or Kiro config change; `check_kiro()` only reports the path
  `resolve_binary` already used (`launch.py:137-140`).
- [N/A] ADR-005 / ADR-029 — no registry or trust change.
- [OK] ADR-010 — the steer stores only the user's text (`manager.py:636`); no bulk in state.
- [N/A] ADR-011 — no agent node added.
- [OK] ADR-012 — the run-row test imports `genesis_core.kiro_node` inside the test only; app code imports no
  workflow Python.
- [N/A] ADR-019 / ADR-080 — `binary` is additive on an SDK function within the one shared version; no consumer in
  genesis-workflows or genesis-core (grep `check_kiro` across both repos: only `preflight.py`, `chat/manager.py:758`,
  SDK tests).
- [N/A] ADR-021 / ADR-068 / ADR-082 — no gate, mutation or QA path.
- [OK] ADR-023 — the routes stay FastAPI routes in `api/chat.py` / `api/system.py`.
- [OK] ADR-026 — no new route or bind. `/system/kiro` builds its fields explicitly (`system.py:63-65`), so the new
  `binary` path does not reach the API.
- [N/A] ADR-027 / ADR-055 — no web UI code (fixtures only).
- [OK] ADR-028 — every tested path is `/api/...` (`test_phase53_api_contract.py`); no new route.
- [N/A] ADR-030 / ADR-037 / ADR-041 / ADR-059 / ADR-060 / ADR-063 / ADR-065 / ADR-073 / ADR-074 / ADR-081 — no
  persistence, KB, document, collaboration or testexec change.
- [OK] ADR-031 / ADR-033 — the steer only adds the user's own text to the user's own turn; the change adds no
  mutation and no tool. A refused steer now stores nothing (`manager.py:632-633`).
- [OK] ADR-032 — `turn-cancelled.json` and `session-stopped.json` carry the stopped turn's real metered credits
  (`0.05054713875621891`, `provenance: "metered"`); `turn-start-error.json` reads `credits: null`,
  `provenance: "unavailable"`; nothing is estimated.
- [N/A] ADR-034 / ADR-042 / ADR-069 / ADR-075 / ADR-076 — no skills-sandbox, spec or skill-provisioning change.
- [N/A] ADR-035 / ADR-043 / ADR-047 / ADR-050 / ADR-071 / ADR-085 — not touched.
- [OK] ADR-045 — `/chat/commands` stays `/clear` and `/compact` (`commands.json`, test
  `test_models_and_commands_keep_their_shapes_from_the_v3_catalog`).
- [N/A] ADR-051 / ADR-053 — not touched.
- [N/A] ADR-077 — no agent-system change.
- [N/A] ADR-083 — no browser-agent change.

Lessons
- [N/A] L-001 / L-002 / L-021 / L-024 / L-041 / L-042 / L-064 — no ACP options, MCP env or tool-output change.
- [OK] L-003 — the run-row test reads the SSE replay after `cbus("r-53").close()`; no bus lifetime change.
- [OK] L-004 — the steer message is stored in SQLite through `msgs.append`.
- [N/A] L-007 / L-069 / L-086 — no web transcript or HTML code.
- [OK] L-010 — all paths `/api/...`.
- [OK] L-011 — fixtures recorded from real responses; the backend test fails on shape drift (`record`). The web-side
  drift test is handed to 53-10 (As built decision 4), which is the sub-spec's stated split (web types are 53-10's).
- [OK] L-016 — see ADR-032.
- [N/A] L-017 — no trust change.
- [OK] L-018 — `_sse()` splits on `\r?\n\r?\n` (`test_phase53_api_contract.py:70`) and checks the event name
  equals `type`.
- [N/A] L-019 — no secret write.
- [OK] L-025 / L-027 — `ruff check genesis` and the SDK's `ruff check src tests` clean with the pinned ruff.
- [N/A] L-030 — no `web/**` file the bundle builds from; the new JSON is test-only and imported by nothing yet.
- [N/A] L-031 / L-044 / L-045 / L-046 / L-047 / L-048 / L-051 / L-058 / L-061 / L-068 / L-073 / L-081 / L-087 /
  L-088 / L-100 / L-101 / L-104 / L-105 / L-107 — not touched.
- [OK] L-039 — `GET /chat/sessions/{id}` keeps its shape; `session-*.json` match `_session_dict` (no
  `kiro_session_id`).
- [OK] L-056 — reminder for the commit: the untracked test file and the three fixture folders must be in it (git
  status shows them `??`).
- [N/A] L-057 — no pin moves here (53-12).
- [OK] L-089 — the bundle check was not run because nothing bundled changed.
- [OK] L-092 — `contract_fixtures.py` is not test-named; the SDK `tests/` dir on `sys.path` shares no module name
  with `genesis/tests` (`comm` of both listings is empty); the same insert already exists in
  `test_chat_v3_engine.py`.
- [OK] L-093 — the cancelled turn is stored before `agent.result` is read back (`session-stopped.json` has
  `meta.turn_status` and metered usage).
- [OK] L-094 — callers of the changed behaviour: `kiro_auth._kiro` (status / whoami / logout / start_login /
  _run_login, all in `kiro_auth.py`), `kiro_auth.status` (`system.py:64`, `preflight.py:81`, `memory_jobs.py:59`),
  `check_kiro` (above), `ChatSession.steer` (`ChatManager.steer` → `api/chat.py:285`); tests that patch
  `preflight.kiro_cli_status` without `binary` (`test_preflight.py:16`) still pass through `.get("binary")`. See n3
  for the one caller the As built's L-026 note misses.
- [OK] L-096 — no new route.
- [OK] L-098 — the import guard in `kiro_cli_status()` now also returns `binary: None`, and `kiro_auth` goes through
  it, so a missing SDK reads not installed rather than raising.
- [N/A] L-099 — no version-keyed behaviour.
- [OK] L-109 — one kiro-cli resolver: `shutil.which` is gone from `kiro_auth.py`; `resolve_binary` is the only
  resolver, and sessions call it the same way (`client.py:136`, env = `os.environ` + `KIRO_HOME`, the same `PATH` /
  `HOME`).
- [OK] L-110 — my own mutation run: with `kiro_auth._kiro` reverted to `shutil.which` (a pytest plugin from `/tmp`,
  no code edit), `test_system_kiro_finds_a_kiro_cli_only_in_local_bin` and
  `test_system_kiro_never_shows_a_version_beside_installed_false[local-bin]` fail and the other 19 pass. The steer
  refusal test fails without the check by construction: the old code stored the message, which the test's message
  list assertion rejects.
- [OK] L-111 — no live claim made; 53-11 holds the live check of `~/.local/bin` (As built hand-off).
- [OK] L-112 — no new tool assumed by the tests (POSIX `sh` fakes; the fake engine is pure Python).

Gates (run by me)
- [OK] `pytest -q -p no:warnings` (genesis): **1933 passed** with `GIT_CONFIG_COUNT=1
  GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=false`. Without the override, `-x` stopped at
  `test_testexec_library.py::test_adopt_also_takes_a_change_someone_committed_outside_genesis` (`git commit` exit
  128), the environment failure the As built names. Nothing in this diff touches testexec.
- [OK] `ruff check genesis` plus the five touched test files: clean.
- [OK] SDK `pytest -q`: **302 passed**; `ruff check src tests`: clean.
- [OK] web `npm run lint`: 0 errors (20 pre-existing warnings); `npm run typecheck`: clean; `npm test`: **726
  passed** (62 files).
- [N/A] `npm run build` / stale bundle: no source file in the bundle changed.
- Flakiness: `tests/test_phase53_api_contract.py` passed **6 of 6** repeated runs (8.6–10.0 s each). This matters
  because `every=True` compares the steered stream's event order.

## The points you asked about

- **"From the running backend" (decision 1): satisfied.** Every recorded body comes from `create_app(...)` behind
  `TestClient`. That covers the real routes, `ChatManager`, the real `kiro_agent_sdk.KiroACPClient`, the real JSON-RPC
  framing and the process launch, with only kiro-cli replaced by the fake engine replaying kiro-cli 2.37.1's recorded
  frames. The fixture asserts that every client frame matched the recording (no `mismatch` / `stalled` / `bad_json`).
  `record()` writes the files, so none is hand-written. Only `<tmp>` paths and the recording's `<TOOL_CALL_n>` ids
  are normalized. This is the Phase 51 precedent (51-10). A running fleet would add only the uvicorn socket, and the
  fleet is excluded (D20).
- **`check_kiro` `binary` (decision 3): OK as an additive public change.** The key is new, there are no
  exact-dict consumers outside the SDK's own tests (updated), and the value is the path `resolve_binary` returns
  for sessions. It stays out of the HTTP response. Release-note it (53-12 already lists it).
- **The kiro_auth → preflight lazy import: works and is tested; layering nit (n1).** `preflight` imports `kiro_auth`
  at the top and `kiro_auth._kiro()` imports `preflight` lazily. That cycle is safe, and it has one benefit: tests
  that patch `preflight.kiro_cli_status` also steer `kiro_auth`.
- **Steer not-queued refusal: correct.** `manager.py:632-633` raises before `msgs.append`, so nothing is stored and
  no `user.steer` goes out. The route maps it to 409 (`chat.py:286-287`), and an engine exception maps to the
  catch-all 409 (`chat.py:288-289`). Both are tested through the app with nothing stored
  (`test_steer_is_409_when_the_engine_did_not_queue_it[answer0/1]`) and at the manager. The strict
  `queued is True` matches the engine: both recorded `_session/steer` answers carry `"queued": true`
  (`packages/kiro-agent-sdk/tests/fixtures/v3/steer*.jsonl`), and `FakeV3Client.steer` returns `queued: True`
  (`chat_fakes.py:152`). The web hand-off for this 409 is inexact; see m1.
- **Rows still inexact:** one row is still inexact. The steer row's "the web then sends the text as a normal message"
  (m1) does not work as written mid-turn. Every other row matches the code. `{ok, error}` with `error` null is
  `manager.py:667/678`. The busy-race `error {type, detail}` is `chat.py:308-310`. `/system/kiro` keys are
  `system.py:64` plus `kiro_auth.status`. `email` and `start_url` are present only when signed in, and `start_url`
  may be null. Preflight items are `preflight.py:_item`. The skills set is asserted exactly in `test_skills_api.py`.

## Findings

### Blockers
None.

### Majors
None.

### Minors
- m1 **The new 409 case sends the web to a route that also answers 409** (`53-09-api.md` §2 steer row;
  `api/chat.py:299-300`). What: the row (and the 53-10 hand-off "on a 409 from `/steer` send the text as a normal
  message, now also when the engine did not queue it") tells the web to POST the text to `/messages`. Problem: the
  new case, an engine that answers without `queued: true`, happens while a turn is running, and `/messages` answers
  `409 "a turn is already in progress"` until that turn's lock is released. Concrete case: turn running → the user
  steers → the engine answers `{queued: false}` → 409 → the web POSTs `/messages` at once → 409 → the text is
  dropped. The same applies to the existing end-of-turn race (`_accept_steers` false while the lock is still held).
  Fix (table + hand-off only, no code): "…409; nothing is stored; the web sends the text as a normal message once
  the running turn's `agent.result` has arrived (as it re-sends `unread_steers`)". Put the same words in the "Changes
  for 53-10" bullet. If skipped: 53-10 implements an immediate re-send that silently drops a refused steer.
- m2 **The Clear / Compact row's 409 has no test** (`53-09-api.md` §2 row 4; `api/chat.py:218-219, 226-227`).
  What: §3 asks for a contract test per row covering status codes. Row 4 says "409 while a turn runs".
  `test_clear_and_compact_answer_ok_and_error` covers `{ok, error}` and the 404s. No test anywhere POSTs
  `/clear` or `/compact` during a turn (grep for `is_busy` / "turn is already in progress" in `tests/`: only the CR
  routes). Fix: in `test_phase53_api_contract.py`, inside the existing `queued: false` test's `steer_then_stop`
  (a turn is running there), add
  `assert tc.post(f"/api/chat/sessions/{sid}/clear").status_code == 409` and the same for `/compact` before the
  cancel. That is two lines with no new fixture. If skipped: a row in the table the sub-spec owns stays unproven.

### Nits
- n1 **Import cycle `kiro_auth` ⇄ `preflight`** (`runtime/kiro_auth.py:38`). This works, but the lower-level module
  now reaches up into the aggregator. Optional: move `kiro_cli_status()` into `kiro_auth` and keep
  `preflight.kiro_cli_status = kiro_auth.kiro_cli_status` as the re-export (`system.py:63`, `test_preflight.py:16`
  unchanged). If you do, patch `test_preflight.py` on `kiro_auth`, or the patch no longer reaches `_kiro`.
- n2 **One `GET /system/kiro` runs the kiro-cli probe three times** (`system.py:63`, `kiro_auth.py:44, 62`). The
  route calls `kiro_cli_status()`, then `status()` calls `_kiro()`, then `_whoami_raw()` calls `_kiro()` again. Each
  call is `check_kiro()`. A good binary hits the SDK cache. A binary whose `--version` fails is not cached
  (`launch.py:90-92`), so it runs `--version` three times per request, with a 15 s timeout each if it hangs.
  Optional: `status()` passes its `exe` to `_whoami_raw(exe)`, which removes one probe.
- n3 **The As built's L-026 note misses one async caller.** "kiro_auth already ran in sync routes" holds for the
  routes. `memory_jobs._kiro_ready()` (`memory_jobs.py:57-61`) calls `kiro_auth.status()` from the async `_run` on
  the scheduler loop. That is pre-existing (it already ran `whoami`), and it now also runs the cached
  `--version` / `acp --help` probe once per binary file. No fix needed in 53-09. Correct the sentence, or add a
  backlog line for an `asyncio.to_thread` there.
- n4 **The runs-row test re-implements `RunManager._spawn`'s custom-event split**
  (`test_phase53_api_contract.py:383-386` copies `runs/manager.py:233-237`). It proves the API passes `model` /
  `fallback_from` through, which is the row's claim. It would not catch a change in `_spawn`. A comment saying
  "copy of `_spawn`'s split" would make that visible. No change required.

## Not checked
- Live kiro-cli and the fleet (excluded by the brief; 53-11 owns the `~/.local/bin` live check).
- The web-side drift test against these fixtures (no Phase 53 web types yet; 53-10).
- The full genesis suite without the gpgsign override past the first testexec failure. I ran it with `-x` and it
  stopped at the first `git commit` exit 128. With the override, all 1933 passed.
- The steer and not-queued mutations (L-110). I re-ran only the m3 mutation myself. The steer ones I checked by
  reading the tests' assertions against the old code.

## Verdict: SHIP

No blocker or major, and every gate is green (the testexec failures come from this machine's global
`commit.gpgsign`, not this change). Fix m1 (wording only) and m2 (two asserts) before the commit if convenient;
otherwise carry them as named items into 53-10. The commit must include the untracked test file and the three
fixture folders (L-056).
