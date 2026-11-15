# Backlog — Phase 53 follow-ups (kiro-agent-sdk v3)

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-11-15 at the Phase 53 write-back, from the umbrella §9 Deferred
> list (`specs/phase-53-kiro-sdk-v3.md`) and the build and release findings (53-02..53-13 As built, 53-12 As run).
> The live acceptance still open after the release is **not** backlog: it is 53-11 §5 (and Phase 51's 51-12 steps
> 1–27), recorded in `context/state/current.md`. kiro-cli 3.x re-verification has its own spec:
> `kiro-cli-3x-reverify.md` (D22).

## 1. Non-SDK KiroCrew ideas (umbrella §9, D1, 2026-11-03 research)

Out of Phase 53's scope by D1: secret-value redaction at write time, a tool-call audit log, MCP quarantine,
`genesis doctor`, SSE reconnect, learning from runs, skill usage and evals, CI ratchets. Each needs its own Q&A; KiroCrew
(`/Users/ramaswamy.u/repo/KiroCrew`) is the reference.

## 2. Phase 52 input: path-scoped reads (53-02 W15, D16)

`fs_read` with `match: ["./**"]` confines `read_file` / `list_directory` to the cwd for absolute paths; `match: ["**"]`
allows any path without asking. Untested: `../`, a symlink pointing out, `~`, and `grep_search` / `file_search`
(53-02 review m5). An unknown rule `capability` is accepted and never matches (a typo silently disables a rule). Phase 52
(agent runtime isolation) owns confinement; ADR-086 says reads are unscoped (ADR-083 risk a).

## 3. Readiness and sign-in

- **n1 (53-08 review):** a broken SDK import reads as "Install kiro-cli"; give it its own hint ("run
  `scripts/install-packages.sh`").
- **n2 (53-08 review):** a run's `error` event carries the message and remedy but no `code`; add
  `"code": getattr(e, "code", None)` in `runs/worker.py`'s error emit if the web should map a run failure to the same
  remedy UI as chat.
- **n1 (53-09 review):** the import between the sign-in and preflight code runs the wrong way (`kiro_auth` imports
  `preflight.kiro_cli_status`); move `kiro_cli_status` into `kiro_auth` or invert it.
- **n2 (53-09 review):** one `GET /system/kiro` probes `check_kiro()` three times (cached unless `--version` fails);
  pass the resolved binary from `kiro_auth.status()` to `_whoami_raw`.
- **n3 (53-09 review, L-026):** `memory_jobs._kiro_ready` calls the sign-in check and the kiro-cli probe on the
  scheduler loop; run it with `asyncio.to_thread`.
- **n2 (53-11 live):** the too-old message repeats the version.

## 4. Chat

- **`reap_idle` has no caller** (53-07 review n2, pre-existing): "idle reap = `session/close`" is not live behaviour
  until something schedules it.
- **Unread steer after a reload** (53-10 review m2): after a full page reload an unread steer row reads "sent during
  the turn" and its re-sent text shows as a second, unlabelled message. Store `meta.steer_status = "unread"` on the steer
  row at `agent.result` and read it in `steerLabel`.
- **The MCP notice is not stored** (53-10): the card lasts only for the page session.
- **n1 (53-11 live):** the MCP notice names the server twice ("appian-dev did not start: appian-dev: …").
- **n2 (53-11 round 3): one home for `Use the <id> skill.`** The string is built in the web (`ChatThread.tsx`
  `onPickSkill`) and the backend (`skill_prompt`), each pinned by a test; the web could send `/<id> <text>` and let the
  backend rewrite it. Open for the spec agent.
- **Engine logs in the chat Kiro home are never pruned** (53-11 review): `~/.genesis/kiro-home/chat/logs/`, about
  67 KB per chat process start.
- The Clear button stores no exchange, so after Stop → Clear the D15 note is still sent once (53-07 decision 8;
  harmless, no stopped text).
- r2-n1 (53-07): a test with POST `/cancel` arriving during the shielded drain (the reviewer's probe showed it works).
- A steer whose `_session/steer` is in flight as the turn ends is reported unread and re-sent; whether the engine also
  queues it for the next prompt is unmeasured (`_session/steer/clear` exists, unused).
- Measure a sub-agent's trust if a later engine lists bundled sub-agents for a projected agent (D21).
- The `act()` warning in `chat.test.tsx` "has no a11y violations" (pre-existing); 53-10 review n3: assert the "Could not
  send" toast in the 500 test (render the toaster in the harness).

## 5. Workflow nodes and skills

- 53-06 review: n1 (the YAML error counts lines within the front-matter block: "line 2" for file line 3), n2 (an
  unreadable `SKILL.md` reads as "invalid front matter"), n5 (no test pins that an MCP output is still recorded), n6
  (the skill-load test's frames are simplified from the recording), n7 (an empty engine-step id would skip id-less
  updates; none recorded).
- `playwright-appian` `SKILL.md:100,110`: a bare `npx playwright test` (53-06 n3; L-101).
- Consider installing a workflow's declared library skills at `genesis install` (53-06: `story-implementation` needs
  `appian` installed by hand).
- The first model-fallback frame (`model` / `fallback_from`) has never been seen live; record it as a fixture when it
  occurs (F6).
- The engine's reaction to a `-32000` access-token answer is unmeasured (only `-32601` was, W12); Phase 52's client
  auth needs it.

## 6. Tests and release

- **m1 (53-11 live, D27):** `test_regression_job_handler_starts_due_apps_and_skips_busy_ones` mixes a faked clock with
  real stored timestamps and fails 00:00–02:00 IST (18:30–20:30 UTC). Until it is fixed, tag and re-run CI outside that
  window.
- The testexec tests' `git commit` inherits a global `commit.gpgsign` (exit 128 under signing): pass
  `-c commit.gpgsign=false` (53-09).
- playwright-appian `tests/cli/agent-nav.test.ts` "goto without a URL is exit 2" failed once under load in a full
  `npm test` (passes alone): a timeout candidate like `f00cebb`'s (53-12 As run). The live `npm run e2e` was not run for
  0.3.1.
- `scripts/probes/chat-steer-widths.mjs:83` mocks `/api/system/update` as v0.81.0 (probe data, not a version source).
- The 53-02 scrubber works per frame: the model's echo of a steer `messageId` stays raw across chunks in `steer`,
  `steer-at-turn-end` and `w7/w7b/w8.jsonl`; re-scrub before a replay test depends on it (53-02 review m6).
- `tests/fixtures/apwt/apwt-0.3.0-*.json` were recorded on apwt 0.3.0 (0.3.1 changes only the skill and
  `install --skills`); re-record at the next CLI change.
