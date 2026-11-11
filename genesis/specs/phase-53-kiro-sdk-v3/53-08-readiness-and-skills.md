# 53-08 — Readiness (kiro-cli version and v3) and skills cleanup

> **Status:** BUILT 2026-11-12 (genesis bde09e7 + d2bdec5; review SHIP, round 2). SPEC-DRAFTED 2026-11-03.
> Repo: **genesis** (`genesis/runtime/preflight.py`, `genesis/runtime/kiro_auth.py`,
> `genesis/skills/**`, `genesis/api/system.py`, `genesis/api/skills.py`). Parent: `specs/phase-53-kiro-sdk-v3.md`.
> Decisions: 53-01 D7, D8; F5.

## 1. Goal

Genesis tells the user, before anything fails, when kiro-cli is missing, too old or lacks the v3 engine; and the skills
code stops knowing about `~/.kiro/skills`.

## 2. Preflight (`runtime/preflight.py`)

- New required item `kiro-cli` (before `kiro` sign-in): from `kiro_agent_sdk.check_kiro()` (53-05 §4). States:
  missing ("Install kiro-cli: <official install link>"), too old ("kiro-cli <x> is older than <min>; run `kiro-cli
  update`"), no v3 engine (same remedy), ok. The minimum is the version 53-02 verified: **2.37.1** (`tool-ids.json`
  `kiro_cli_verified`).
- An **optional** item `kiro-cli-verified`: ok when the installed version is in the verified list; otherwise "kiro-cli
  <x> has not been verified with this Genesis release; it should work — report problems." (warn, F5).
- Chat and runs refuse to start while the required item fails: chat returns the classified error on the first turn
  (`kiro_too_old` / `engine_missing`); a run fails at its first agent node with the same error (53-04 `errors.py`).
- Same `_item` shape and "optional = warning" convention as Phase 51's Node 20+ and Playwright Chromium items
  (`preflight.py:67-78`); the new items go before the `kiro` sign-in item without reordering the others (the web
  fixtures pin the order).
- `check_kiro()` runs `kiro-cli --version` and `kiro-cli acp --help` once and caches by binary path + mtime (no network).

## 3. Settings health

`GET /api/system/kiro` (`api/system.py:60-62`) adds `{version, minimum, verified, engine_v3}` beside
`{installed, authenticated, email?, start_url?}`; Settings → General's Kiro card shows the version and the warning.

## 4. Skills cleanup (D7, D8)

- `skills/store.py:55-63`: remove `personal_dir` (`:56-63`) and the shadowing computation (`:111`);
  `skills/model.py:72-74`, `:86`: remove `shadows_personal` (the API field is dropped; 53-09 records it).
- `api/skills.py`: keep `POST /skills/update` (`:100`) as is; it already reinstalls the latest library ref and closes live
  chat clients (`_reload`).
- Docstrings that say chat also sees `~/.kiro/skills` (`skills/__init__.py`, Phase 14 notes) are corrected.

## 5. Tests

Preflight with fake `kiro-cli` scripts (missing, too old, no v3, ok, newer unverified); `GET /system/kiro` shape;
skills list without `shadows_personal` (`tests/test_skills_store.py:158-161` asserts it today and is rewritten);
`POST /skills/update` happy path and "not in the library" (404).

## As built (2026-11-12, genesis-dev) — review SHIP (round 2)

**Task restated.** In genesis: put a required `kiro-cli` item (missing / too old / no v3 engine / ok, each with its
remedy) and an optional `kiro-cli-verified` warning at the head of the preflight list, from
`kiro_agent_sdk.check_kiro()`, keeping the `_item` shape, the optional = warning rule and the order of the existing
items; have chat and runs refuse to start with the classified error while the required item fails; add `{version,
minimum, verified, engine_v3}` to `GET /api/system/kiro`; remove `personal_dir`, the shadowing check and
`shadows_personal` from the skills code and API, and correct the docstrings that said chat sees `~/.kiro/skills`
(D7, D8); keep `POST /skills/update` as is. The web is 53-10's (user). Rules applied: ADR-026 and ADR-028 (one GET on
the existing `/api` router, no new surface), ADR-034 as the Phase 53 draft amends it (chat sees only the managed
workspace), ADR-046 (Genesis never installs kiro-cli; the items link and say `kiro-cli update`), ADR-069, ADR-080 (only
the public SDK name `check_kiro`, `tests/test_sdk_import_boundary.py`); L-044, L-083 (fakes shaped on the installed
2.37.1), L-089, L-094, L-098, L-109 (the minimum has one home), L-110, L-112 (no test needs a kiro-cli). KiroCrew read
as a reference only: `src/kiro_crew/kiro_cli.py` (`kiro_cli_version_at`: one `--version` answer per binary identity,
keyed by path and mtime, so an update invalidates it; an unknown version never raises) and `src/kiro_crew/cli_doctor.py`
`_kiro_cli_version_row` (a probe that fails or hangs is a row, not a traceback; its hint names no URL). The SDK's
`check_kiro()` already does both (53-05). Not copied: KiroCrew's `pin_kiro_cli`, which excludes `PATH`; Genesis resolves
kiro-cli through `PATH` (53-04). No ADR deviation.

### Commits (genesis, local, base 2af786f, not pushed)

- `bde09e7` feat(preflight,skills,53-08): everything under Changed.
- `d2bdec5` fix(preflight,53-08): review m1/m2.
- project-tracker: this As built, the status line and `reviews/53-08-review.md` (one commit).

### Changed

genesis — app:
- `runtime/preflight.py`:
  - `KIRO_INSTALL_URL` = `https://kiro.dev/docs/getting-started/installation/` (`kiro.dev/docs/cli/installation`
    redirects there; fetched 2026-11-12).
  - `kiro_cli_status()` = `check_kiro()`, with a guarded import (L-098) that reads as not installed.
  - `_kiro_cli_items(k)`, two items placed before `kiro`, with every existing item after them in its old order:
    - `kiro-cli`: required. Label "kiro-cli 2.37.1+ with the v3 engine"; `fix_link` `/settings/general` (the web
      renders `fix_link` as a router `Link`, so the URL goes in the hint). Hints by state:
      - missing: "Install kiro-cli: <url>";
      - no `--version` answer: "kiro-cli did not report its version … Reinstall kiro-cli: <url>";
      - too old: "kiro-cli <x> is older than 2.37.1; run `kiro-cli update`.";
      - no v3: "kiro-cli <x> has no v3 agent engine; run `kiro-cli update`.".
    - `kiro-cli-verified`: optional. It is ok only when the version is verified **and** kiro-cli is usable (review m1).
      Otherwise it shows the F5 text "kiro-cli <x> has not been verified with this Genesis release; it should work —
      report problems.", or "Fix the kiro-cli item first." while `kiro-cli` fails.
- `api/system.py`: `GET /system/kiro` = `kiro_auth.status()` plus `version`, `minimum`, `verified` and `engine_v3`,
  all from the same probe. `POST /system/kiro/logout` still returns `kiro_auth.status()` only.
- `skills/store.py`: `SkillStore(skills_dir)`. The `personal_skills_dir` parameter, `personal_dir` and the shadowing
  check are gone. `skills/model.py`: `SkillInfo.shadows_personal` and its `to_public()` key are gone, so `GET /skills`
  no longer has the field.
- Docstrings: `skills/__init__.py` and `runtime/settings.py` `skills_dir` now say chat runs with its own `KIRO_HOME`
  (D6), sees only the managed workspace and never `~/.kiro/skills` (D7). `api/system.py`'s module note was updated
  too.
- `api/skills.py`: unchanged. `POST /skills/update` reinstalls the library's latest ref and closes the live chat
  clients.

genesis — `packages/kiro-agent-sdk`: `launch.check_kiro()` also returns `minimum` (`MIN_KIRO_VERSION` as text), so
Genesis never restates 2.37.1 (L-109). `test_v3_trust.py` was updated for the new key.

**Chat and runs refusing to start: no product code.** The SDK already refuses at session start:
- `check_version` raises `kiro_too_old` before it spawns anything;
- a kiro-cli without v3 fails at argument parse, and `classify_stderr(at_start=True)` turns that into
  `engine_missing`;
- no binary gives `kiro_missing`.

Chat's `_ensure_started` already turns a start failure into the turn's `error` and an `agent.result` with the code
(53-07). `kiro_node` lets the `KiroError` propagate before any turn or retry, and the worker reports `str(e)`, which is
the message with the remedy.

### Tests

- New `tests/test_kiro_readiness.py` (14). The fake `kiro-cli` scripts are POSIX `sh` with builtins only. They are
  shaped on the installed 2.37.1, recorded this session:
  - `--version` prints `kiro-cli 2.37.1`;
  - `acp --help` prints `[possible values: v2, v1, v3]` under `--agent-engine`;
  - `acp --agent-engine v9` prints `error: invalid value 'v9' for '--agent-engine <ENGINE>'` and the possible values,
    and exits 2.

  `PATH` holds only the fake's folder, and `HOME` is an empty folder, so the SDK's `~/.local/bin` fallback never finds
  the real binary. The tests:
  - **preflight:**
    - ok: ids = `kiro-cli, kiro-cli-verified` followed by the old order pinned, and ready;
    - missing: the URL hint, not ready;
    - too old (2.30.4);
    - no v3: the verified item is not ok (m1; fails without d2bdec5: `'ok' == 'missing'`);
    - no `--version` answer;
    - newer unverified (2.38.0): a warning, still ready;
    - the probe runs once for two preflights, and again after an in-place update (same path, new mtime).
  - **`/system/kiro`:** the exact shapes with 2.38.0 signed in, and with no kiro-cli.
  - **chat:** on the real SDK client, the first turn is `error` + `agent.result` with `kiro_too_old`,
    `engine_missing` or `kiro_missing`.
  - **runs:** `kiro_node` on a `KiroAcpProvider` built from the SDK's own `collect` / `collect_streaming`, so a stub
    another test left in `nodes/agent.py` cannot hide the result, raises `KiroError` `kiro_too_old` /
    `engine_missing`, and no `agent.result` is emitted.
- `tests/test_skills_store.py`: the shadowing test is replaced by
  `test_store_lists_a_skill_without_any_personal_skills_field`. A same-named `~/.kiro/skills/gam` changes nothing, the
  `to_public()` keys are exact, and the old parameter raises `TypeError`.
- `tests/test_skills_api.py`:
  - `GET /skills` items have exactly the eight keys, without `shadows_personal`;
  - `POST /skills/update` happy path: the library publishes 1.1.0, the response is version 1.1.0, the body is new, the
    skill is still `library`, and live chat clients are closed once;
  - "not in the library" → 404, and nothing is closed.
- `tests/test_preflight.py` (review m2): the fixture stubs `kiro_cli_status`, so no host kiro-cli is probed.
  `test_optional_missing_does_not_block_ready` migrates its DB and asserts `ready is True`; before, it passed only
  because both sides of its check were False.
- **Gates at d2bdec5:** genesis `pytest -q` **1913 passed** (1896 at 2af786f), `ruff check genesis` clean.
- **Gates at bde09e7** (the SDK has not changed since): SDK `pytest -q` **266 passed**, `ruff check src tests` clean.
- **Not run:**
  - genesis-core and the web gates: nothing changed there, and no web test can see the backend;
  - the `python:3.13` image (L-112, 53-12);
  - live: no credits spent.

### Review

`reviews/53-08-review.md`. Round 1 **SHIP** at bde09e7, with three minors and two nits:
- m1: the verified item could read ok while `kiro-cli` failed;
- m2: the Phase 22 preflight tests probed the host's kiro-cli, and one passed vacuously;
- m3: `/system/kiro` can say `installed: false` beside a version;
- n1: a broken SDK import reads as "Install kiro-cli";
- n2: a run's `error` event has no `code`.

m1 and m2 were fixed in d2bdec5, and round 2 was **SHIP**. m3, n1 and n2 are carried below, which was the condition of
round 2.

### Decisions / deviations

No ADR deviation.
1. **`check_kiro()` gains `minimum`** (an additive key on the public SDK function), rather than Genesis importing
   `launch.MIN_KIRO_VERSION`, which the import gate forbids, or restating "2.37.1".
2. **Item ids are the spec's** (`kiro-cli`, `kiro-cli-verified`, with hyphens), although older ids use underscores.
   Both new items come first, as §2 says, so the optional one sits among the required ones.
3. **Status stays `ok` / `missing`** for every state, the `_item` shape (as Node 19 reads "missing"). The state is
   in the hint.
4. **A fifth state:** a kiro-cli that does not answer `--version` (`installed` true, `version` null) gets its own
   reinstall hint.
5. **Run errors carry the message, not the code** (n2). "Fails at its first agent node with the same error" holds for
   the classified message and its remedy, and the reviewer agreed.
6. **Not done here:** the 53-07 hand-off "check that a skill installed meanwhile is discovered after a `session/load`"
   needs a live session. It stays in 53-11's list (53-07 Changes, 53-11 item).

### Lesson candidates

- **A stash-and-rerun check of a regression test can pass for the wrong reason:** the first run against the reverted
  file passed. The second, after clearing the module's `__pycache__`, failed as expected. The likely cause is a stale
  `.pyc`: the stash and the run fell within the same timestamp, and the edit did not change the file size. To prove that
  a test fails without a fix, delete the module's bytecode (or use `PYTHONDONTWRITEBYTECODE=1`) before the run, and
  never trust a single pass (extends L-110).
- **A new probe added to an aggregate check reaches every old test of that check:** `preflight.check` gained a
  subprocess call, and three Phase 22 tests silently started to run the host's kiro-cli. One of them became vacuous.
  When an aggregate gains a dependency, stub it in the old tests' fixture in the same change (L-094: list the consumers
  of the function, not just of the name).

### Code-map changes

- `genesis/genesis/runtime/preflight.py`: `KIRO_INSTALL_URL`, `kiro_cli_status()`, `_kiro_cli_items()`; items
  `kiro-cli` (required) and `kiro-cli-verified` (optional) first.
- `genesis/genesis/api/system.py`: `GET /system/kiro` adds `version, minimum, verified, engine_v3`.
- `genesis/genesis/skills/store.py`: `SkillStore(skills_dir)` (no personal dir). `skills/model.py`: `SkillInfo` without
  `shadows_personal`.
- `packages/kiro-agent-sdk/src/kiro_agent_sdk/launch.py`: `check_kiro()` returns `minimum`.
- Tests: `genesis/tests/test_kiro_readiness.py` (fake kiro-cli scripts `fake_kiro()`).

### Changes for 53-09..53-12

- **53-09 (API):**
  - Record the real shapes for the contract table and the web fixtures:
    - `GET /system/kiro` = `{installed, authenticated, email?, start_url?, version, minimum, verified, engine_v3}`.
      `version` is null when kiro-cli is missing or does not answer; `minimum` is always `"2.37.1"`.
    - `GET /system/preflight`: two new items at the head, `{id: "kiro-cli", label: "kiro-cli 2.37.1+ with the v3
      engine", required: true, fix_link: "/settings/general"}` and `{id: "kiro-cli-verified", label: "kiro-cli
      version verified with this release", required: false, fix_link: "/settings/general"}`, with `status` "ok" or
      "missing" and the hints above.
    - `GET /skills` items have exactly `{id, name, description, source, has_scripts, has_references, has_assets,
      bytes}`.
  - `POST /system/kiro/logout` still answers the old four-key shape.
  - **m3 (for whoever owns the Kiro card, 53-09/53-10):** `installed` and `authenticated` come from `kiro_auth`, which
    finds kiro-cli only on `PATH` (`kiro_auth._kiro`, `shutil.which`). `version` and `engine_v3` come from
    `check_kiro`, which also tries `~/.local/bin/kiro-cli`, the default install location and the binary chat and runs
    actually launch. With kiro-cli only in `~/.local/bin` and not on the server's `PATH`, the payload says
    `installed: false` beside `version: "2.37.1"`, and preflight shows `kiro-cli` ok while `kiro` sign-in fails, yet
    chat works. There are two fixes:
    - the Kiro card treats `version != null` as installed;
    - better, one resolver: `kiro_auth` runs the binary the SDK would launch. That needs a public SDK name, for example
      a `binary` key on `check_kiro()`.
  - **n2:** a run's `error` event carries only `str(e)`. If the web should map a run failure to the same remedy UI as
    chat's `code`, add `"code": getattr(e, "code", None)` in `runs/worker.py`'s error emit.
- **53-10 (web):**
  - W6: `SkillCard` reads `shadows_personal` optionally, so the badge already never shows; remove the field and the
    text.
  - W7: render the two new items (an optional item that is not ok is the warning style Node and Chromium use), and on
    the Kiro card show `version`, the minimum and the unverified warning. See m3 for `installed`.
  - W8: the skill type loses `shadows_personal`, and the Kiro status type gains the four fields.
- **53-11 (acceptance):**
  - Live on the fleet: the two preflight items on 2.37.1, both ok.
  - A newer kiro-cli, if one is out by then: the warning, and chat still runs.
  - Still open from 53-07: whether a skill installed while a chat is open is discovered after the next turn's
    `session/load`.
  - Also check whether the spec-style chat modes, whose cwd is the skill-output sandbox rather than `state_dir`, see
    managed skills at all. `chat/manager.py:11` says they do; nothing measured it.
- **53-12 (release):**
  - kiro.dev documents kiro-cli **3.0.0**, where V3 is the default harness (`kiro.dev/docs/cli/v3`, read 2026-11-12).
    If 3.x changes `acp --help` so that `--agent-engine` no longer lists `v3`, preflight reads "no v3 engine" while
    the launch may still work. The SDK's `probe_engine_v3`, `MIN_KIRO_VERSION` and `tool_ids.json`
    `kiro_cli_verified` need a 53-02 W15 re-measure on 3.x before it is listed as verified.
  - Release notes: `check_kiro()` gained `minimum`, and `GET /skills` lost `shadows_personal`.
- **Backlog:** n1 (a broken SDK import shows the kiro-cli install hint; a distinct "run scripts/install-packages.sh"
  hint).

## Context manifest

```toml
areas    = ["config-secrets", "chat", "api", "distribution"]
adrs     = ["ADR-034", "ADR-046", "ADR-069", "ADR-026"]
lessons  = ["L-044", "L-098", "L-012"]
docs     = ["tracker:specs/phase-53-kiro-sdk-v3/53-01-findings.md"]
code     = ["genesis/genesis/runtime/preflight.py", "genesis/genesis/runtime/kiro_auth.py", "genesis/genesis/api/system.py", "genesis/genesis/api/skills.py", "genesis/genesis/skills/**", "genesis/tests/test_skills_store.py"]
upstream = ["53-05"]
```
