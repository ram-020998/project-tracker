# Review 53-08 — base 2af786f, change bde09e7 (genesis-review, 2026-11-12)

What this change does: preflight gains a required `kiro-cli` item (missing / too old / no v3 engine / no version
answer / ok) and an optional `kiro-cli-verified` warning, both from `kiro_agent_sdk.check_kiro()` and placed before the
`kiro` sign-in item; `GET /api/system/kiro` adds `version, minimum, verified, engine_v3`. The skills store and model
drop `personal_dir` and `shadows_personal`, and docstrings now say chat sees only the managed workspace. The SDK's
`check_kiro()` also returns `minimum`. Chat and run refusal adds no product code; new tests prove it on the real SDK.

Reviewed: `git diff 2af786f bde09e7` (11 files, +386/−31), tree clean at HEAD = bde09e7, spec set at project-tracker
c2c5f8a. Web is out of scope (53-10, user's call) and is not flagged.

## Checklist

ADRs named by the brief and by `genesis-ctx check` that this diff touches:

- [OK] ADR-026 — local single-user, no auth — no new surface; `/system/kiro` is a GET on the existing localhost router
  (`genesis/api/system.py:59-65`).
- [OK] ADR-028 — all endpoints under `/api` — the new fields ride the existing `/system/kiro`, registered on the `/api`
  router (`system.py:59`); the test mounts it with `prefix="/api"` (`tests/test_kiro_readiness.py:183-187`).
- [OK] ADR-034 (as amended by the Phase 53 draft: chat no longer sees `~/.kiro/skills`) — `SkillStore.__init__` takes
  only `skills_dir` (`genesis/skills/store.py:61-62`); the shadowing check is gone (`store.py` −`:116`); docstrings
  corrected (`skills/__init__.py:6-8`, `runtime/settings.py:119-122`); chat runs with `chat_kiro_home`
  (`chat/manager.py:265,778,991`). `grep -rn "~/.kiro/skills\|shadow" genesis --include=*.py` finds only the corrected
  "never" sentences (`runtime/context.py:80,96`, `settings.py:122`, `skills/__init__.py:8`).
- [OK] ADR-046 — Genesis does not install kiro-cli — the items only link to `KIRO_INSTALL_URL`
  (`preflight.py:22-23,53`) or say `kiro-cli update`; nothing runs an installer.
- [OK] ADR-069 — workflow skills come from the blackboard, never `~/.kiro/skills` — `runtime/context.py` untouched;
  the store change cannot reach the node path.
- [OK] ADR-080 — one repo, no internal dependency entries — the SDK change is inside `packages/kiro-agent-sdk`
  (`launch.py:126-131`), no `pyproject.toml` touched; Genesis imports only the public `check_kiro`
  (`kiro_agent_sdk/__init__.py:20,66`); `tests/test_sdk_import_boundary.py` passes in the full run.
- [OK] ADR-012 — the app never imports workflow Python — the run test calls `kiro_node` in-process, but that is a test;
  product code unchanged.
- [OK] ADR-011 — reliability trio — no node change. A `KiroError` from `collect` propagates out of the agent node before
  the validator (`reliability.py` catches only inside `_emit`), so no retries are spent on a refused start.
- [OK] ADR-020 / ADR-002 / ADR-004 — no global Kiro config touched; the probe runs `--version` and `acp --help` only.
- [N/A] ADR-001, 005, 010, 013, 019, 021, 022, 023, 027, 029–033, 035–045, 047–068, 070–079, 081–085 — listed by area
  mapping; the diff touches none of their subjects (no graph, state, registry, DB, web, KB, lane, or report code).

Lessons:

- [OK] L-044 — spike the installed CLI — I re-ran the installed 2.37.1: `kiro-cli acp --help` prints
  `[possible values: v2, v1, v3]` under `--agent-engine`; `kiro-cli acp --agent-engine v9` prints
  `error: invalid value 'v9' for '--agent-engine <ENGINE>'` + the possible values + `For more information, try
  '--help'.` These match the fake in `test_kiro_readiness.py:33-66` and the SDK regexes (`launch.py` `_ENGINE_RE`,
  `errors.py:110`).
- [OK] L-083 — fixtures use real shapes — same evidence; `--version` prints `kiro-cli 2.37.1` on this host as in the fake
  (`:52`). The whoami fake (`_WHOAMI`, `:30`) matches the shape `kiro_auth.status` parses (`kiro_auth.py:55-77`).
- [OK] L-089 — the commit carries every changed file: `git diff --stat` shows the implementation with its tests; no web
  bundle involved.
- [OK] L-094 — every consumer of a removed name: `grep -rn "personal_skills_dir\|personal_dir\|shadows_personal"` finds
  no backend caller left (`dist/skill_install.py:25` and `skills/service.py:24` already call `SkillStore(skills_dir)`);
  the remaining hits are `web/src/types/skill.ts:16` and `SkillCard.tsx:14,27,61`, which read the field optionally
  (`"shadows_personal" in s`) and so degrade to "no badge" — 53-10's job by the user's scope. Consumers of
  `preflight.check`: only `api/system.py:84`.
- [OK] L-098 — a missing library must not crash the read — `kiro_cli_status` guards the import (`preflight.py:38-46`).
  See n1 for the hint it then shows.
- [OK] L-109 — one home for the minimum — `minimum` comes from `MIN_KIRO_VERSION` via `check_kiro()`
  (`launch.py:130-131`); the label, the too-old hint and `/system/kiro` all read it (`preflight.py:51,56,59`;
  `system.py:63-65`); the tests assert `"2.37.1"` in the output only, which is the parity check.
- [OK] L-110 — proven by what ran — I ran the gates myself at bde09e7 with a clean tree (below).
- [OK] L-112 — no test assumes a tool the CI image lacks — the new tests set `PATH` to one tmp folder and `HOME` to an
  empty folder (`test_kiro_readiness.py:72-85`), so they pass without kiro-cli. See m2 for the old preflight tests.
- [OK] L-024 — skills load from the filesystem — unchanged; `chat/mcp.py:16-21` still states it.
- [OK] L-039 — list and single-get share derived fields — `to_public()` is the one shape for both (`model.py:74-84`);
  `test_listed_skills_carry_no_shadows_personal_field` pins the list keys.
- [N/A] all other lessons in the check list — no event, SSE, secret, MCP, export, finalizer, route-order, job, release or
  web code changed.

Gates (run by me at bde09e7):

- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings` → **1913 passed** in 564.64 s.
- [OK] `cd genesis && .venv/bin/ruff check genesis` → All checks passed!
- [OK] `cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/python -m pytest -q` → **266 passed**.
- [OK] `cd genesis/packages/kiro-agent-sdk && ../../.venv/bin/ruff check src tests` → All checks passed!
- [N/A] web `lint/typecheck/test/build` — no `web/**` file changed (`git diff --stat`).

## The developer's decisions, checked

- **Item 2 adds no product code.** Agreed. Chat: `test_chat_returns_the_classified_error_on_the_first_turn` drives the
  real SDK client (factory cleared, `test_kiro_readiness.py:194-218`) and gets `error` + `agent.result` with
  `kiro_too_old` / `engine_missing` / `kiro_missing`. Runs: `test_a_run_fails_at_its_first_agent_node_with_the_classified_error`
  builds a `KiroAcpProvider` from the SDK's own `collect`/`collect_streaming`, so the stub-leak risk that genesis-core's
  `_STUBBED` path carries (`nodes/agent.py:80-94`) cannot hide it; the node raises `KiroError(code)` with no
  `agent.result`. From there `worker.main` reports `str(e)` (`runs/worker.py:194-201`); `KiroError.__str__` is the
  message with the remedy plus the detail (`errors.py:73-74`). The spec's "the same error" is met in substance: the run
  fails at the first agent node, before any turn or retry, with the classified message. The code string does not reach
  the run's `error` event (see n2). The test stops at the node and does not go through `worker.main`; that last step is
  pre-existing code and I read it.
- **SDK `check_kiro()` returns `minimum`.** Correct and the lean choice (L-109, public import surface). SDK tests updated
  (`test_v3_trust.py:565-568,583-587`).
- **Item ids with hyphens, both before `kiro`, verified optional.** Matches spec §2. The order of the old items is
  pinned by `OLD_ORDER` (`test_kiro_readiness.py:27,99`).
- **"When kiro-cli is unusable the verified item reads missing."** Not always true; see m1.
- **`fix_link` `/settings/general` for both.** Correct: the web renders `fix_link` through a router `Link`
  (`web/src/features/system/PreflightChecklist.tsx:29-30`), and the Kiro card lives there.
- **Install URL.** Not re-fetched by me (no network check); the constant is in one place (`preflight.py:22-23`).
- **`installed` from `kiro_auth.status()` (PATH only) while `check_kiro` also tries `~/.local/bin`.** Pre-existing and
  accepted by the developer, but the new fields make it visible; see m3.
- **KiroCrew.** The cache keyed on path + mtime (+ size) and the "probe failure is a row, not a traceback" rule are
  what the SDK does (`launch.py` `probe_version`, `probe_engine_v3`; `check_kiro` never raises). Not copying the
  PATH-excluding pin is consistent with 53-04.
- **Fake scripts.** POSIX sh, builtins only, shapes match the real binary (L-044 above). `HOME` is an empty tmp dir.

## Findings

### Blockers
none

### Majors
none

### Minors

- m1 **The verified item can read ok while the kiro-cli item fails** (`genesis/runtime/preflight.py:61-62`) — What: the
  `kiro-cli-verified` status is `bool(k.get("verified"))`, independent of `usable`; only its hint looks at `usable`.
  Problem: on kiro-cli 2.37.1 (a verified version) whose `acp --help` fails or times out, `probe_engine_v3` returns
  False (`launch.py`, the `except` branch, not cached) while `verified` is True. Preflight then shows `kiro-cli`
  missing ("has no v3 agent engine") and `kiro-cli-verified` **ok**, which contradicts the developer's stated rule
  ("when kiro-cli is unusable the verified item reads missing with 'Fix the kiro-cli item first.'"). No test covers
  verified-but-unusable. Fix: `bool(k.get("verified")) and usable` as the item's `ok`, plus one test with the fake
  printing an `acp --help` without `v3` on version 2.37.1 (`fake_kiro(bin_dir, v3=False)` already gives exactly this
  case: assert `items["kiro-cli-verified"]["status"] == "missing"` and its hint). If skipped: a confusing checklist in
  a rare state; nothing breaks.

- m2 **The Phase 22 preflight tests now execute the host's real kiro-cli** (`tests/test_preflight.py:22-53`) — What:
  `preflight.check` now calls `check_kiro()` first; these three tests stub only `kiro_auth.status`, so on a dev machine
  they spawn the real `kiro-cli --version` and `kiro-cli acp --help` (this host: `~/.local/bin/kiro-cli` 2.37.1).
  Problem: `test_optional_missing_does_not_block_ready` asserts `ready == (database ok)`; it passes today only because
  the tmp DB is unmigrated, so both sides are False. On a host with a usable kiro-cli and a migrated DB the assertion
  would hold, but on one without it (CI) it holds for a different reason; the test no longer proves "optional missing
  does not block ready". Testing conventions §4 ("no test should need a live Kiro"). Fix: in that file's `settings`
  fixture, `monkeypatch.setattr(preflight, "kiro_cli_status", lambda: {"installed": True, "version": "2.37.1",
  "minimum": "2.37.1", "minimum_ok": True, "engine_v3": True, "verified": True})`. If skipped: host-dependent tests
  that can mask a regression in the `ready` rule.

- m3 **`/system/kiro` can return `installed: false` together with a version** (`genesis/api/system.py:63-65`) — What:
  `installed`/`authenticated` come from `kiro_auth.status()` (`shutil.which` only, `kiro_auth.py:59-61`), the new
  fields from `check_kiro()`, which also finds `~/.local/bin/kiro-cli` (`launch.py:61-64`). Problem: with kiro-cli only
  in `~/.local/bin` and not on the server's `PATH` (the default Kiro install location, as on this host), the payload is
  `{"installed": false, "authenticated": false, "version": "2.37.1", "engine_v3": true, ...}` and preflight shows
  `kiro-cli` ok but `kiro` sign-in missing, while chat and runs work (the SDK resolves the same binary). The mismatch
  pre-dates 53-08, but this change publishes both answers side by side in one contract that 53-10 will render. Fix
  (smallest): leave the code, and record it for 53-09/53-10 so the Kiro card trusts `version` for "installed"; or have
  `kiro_auth._kiro()` use the SDK's `resolve_binary` (one resolver, L-109). If skipped: a confusing Kiro card for users
  whose kiro-cli is only in `~/.local/bin`.

### Nits

- n1 **SDK import failure reads as "Install kiro-cli"** (`preflight.py:44-46,52-53`) — the fallback dict says
  `installed: False`, so a broken SDK install shows the kiro-cli install link. A server that serves this route has
  already imported the SDK for chat, so the case is near-theoretical. Optional: a distinct hint ("kiro-agent-sdk is not
  installed; run scripts/install-packages.sh").
- n2 **A run's error event has no `code`** (`runs/worker.py:194-201`) — chat events carry `code`; a run's `error` carries
  only `str(e)`. Fine for 53-08's wording, but if 53-09/53-10 want to map run failures to the same remedy UI they will
  need `getattr(e, "code", None)` in that event. Record, do not change here.

## Not checked

- The install URL resolves and the redirect from `kiro.dev/docs/cli/installation` (no network check by me).
- The web: new items rendering, `shadowsPersonal` removal, web types and fixtures (53-10, by the user's scope).
- Live behaviour on the fleet (53-11).

## Verdict: SHIP

No blockers or majors; every gate is green at bde09e7. m1 and m2 are small and worth fixing in this sub-spec's next
commit or the first 53-09 commit; m3 should be carried into 53-09/53-10 so the Kiro card does not show contradictory
fields.

---

# Round 2 — change d2bdec5 on bde09e7 (genesis-review, 2026-11-12)

Reviewed: `git show d2bdec5` (3 files, +15/−4). Tree clean at HEAD = d2bdec5; `git diff --stat bde09e7 d2bdec5 --
packages` is empty, so the SDK is unchanged.

## Round 1 findings, checked

- **m1: fixed.** `genesis/runtime/preflight.py:66-67`: the `kiro-cli-verified` item's `ok` is now
  `bool(k.get("verified")) and usable`, so it can no longer read ok while the `kiro-cli` item fails. Its hint already
  says "Fix the kiro-cli item first." when `usable` is False (`:64-65`). Regression test:
  `tests/test_kiro_readiness.py::test_kiro_cli_without_the_v3_engine_says_update` (`:126-135`) now asserts the
  verified item's status is `missing` and its hint. I confirmed the test would fail on the old line without
  reverting code. The fake defaults to version 2.37.1 (`:32`), and the SDK sets `verified` from the version alone
  (`launch.py:143`, `tool_ids.verified(version)`). `.venv/bin/python -c "...tool_ids.verified('2.37.1')"` prints
  `True`. So the old `bool(k.get("verified"))` gave `ok` with `v3=False`, and the new assertion catches that. This
  matches the developer's AssertionError report.
- **m2: fixed.** `tests/test_preflight.py:15-18`: the `settings` fixture stubs `preflight.kiro_cli_status` with a
  usable, verified 2.37.1 dict. `check()` calls that name through the module (`preflight.py:77`), so the stub stops
  every host probe in the file. `test_optional_missing_does_not_block_ready` (`:50-61`) migrates the tmp DB, asserts
  `database` ok and `dev_environment` missing, then asserts `ready is True`. The test now proves its own claim and no
  longer passes vacuously.
- **m3, n1, n2: carried forward without code changes. Acceptable, with one condition.**
  - m3 predates 53-08: `kiro_auth` finds kiro-cli through PATH only, while `check_kiro` also tries `~/.local/bin`. The
    surface it affects, the Kiro card, belongs to 53-09/53-10. The smallest correct fix (one resolver) belongs with
    the code that renders the card, so deferring it is reasonable.
  - n1 is near-theoretical, and n2 matters only if a later sub-spec maps run failures to the remedy UI. Neither
    belongs in 53-08.
  - **Condition:** the record the brief cites does not exist yet. At project-tracker HEAD the sub-spec's `## As built`
    still reads `_To be filled by genesis-dev._` (`53-08-readiness-and-skills.md:46-48`). No 53-09 or 53-10 spec
    mentions m3, `kiro_auth` or the run `error` code (`grep -rln kiro_auth specs/phase-53-kiro-sdk-v3/` hits only
    53-01, 53-08, 53-12 and this report). The As built must carry m3, n1 and n2 under "Changes for 53-09..53-12",
    with m3 tagged for whoever owns the Kiro card, before 53-08 counts as closed. Until then this report is their only
    record.

## Gates (run by me at d2bdec5)

- [OK] `cd genesis && .venv/bin/python -m pytest -q -p no:warnings`: **1913 passed** in 566.07 s. This matches the
  developer's figure and round 1's count. The changes alter assertions and add no new tests, so the count is unchanged.
- [OK] `.venv/bin/python -m pytest -q tests/test_kiro_readiness.py tests/test_preflight.py`: 18 passed.
- [OK] `.venv/bin/ruff check genesis`: All checks passed!
- [N/A] SDK pytest and ruff: no SDK file changed since bde09e7 (round 1: 266 passed, ruff clean).
- [N/A] web: no `web/**` file changed.

## Checklist delta

Round 1's checklist still holds. The diff changes only one boolean in `_kiro_cli_items` plus tests. Lines affected:
- [OK] L-083 (real shapes): the m2 stub has the exact key set `check_kiro()` returns (`launch.py:128-131`).
- [OK] L-112 and coding standards §4 (no test needs a live Kiro): `test_preflight.py` no longer executes the host's
  kiro-cli.
- [OK] L-110: every gate above was run by me on a clean tree at the recorded HEAD.

## Findings (round 2)

No new blockers, majors or minors.

## Not checked

- Unchanged from round 1: the install URL, the web (53-10) and live fleet behaviour (53-11).

## Verdict: SHIP

m1 and m2 are fixed, each with a test that fails without its fix. All gates are green at d2bdec5. Carrying m3/n1/n2
forward is acceptable on one condition: the developer writes them into the 53-08 As built ("Changes for
53-09..53-12") before closing the sub-spec. It is still empty.
