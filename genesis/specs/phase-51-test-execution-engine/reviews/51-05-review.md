# Review 51-05 — base 316ac5a (genesis-review, 2026-11-03)

Scope: `git diff 316ac5a` in `genesis` (7 modified files, uncommitted) plus the untracked files from
`git status --short --untracked-files=all`: `genesis/api/testing.py`, `genesis/integrations/apwt/{__init__,client,errors,factory}.py`,
`genesis/testexec/{__init__,procs,runtime,settings_service,vendor,workspace}.py`, `genesis/testexec/templates/*`,
`genesis/testexec/vendor/playwright-appian-0.3.0.tgz`, `tests/fixtures/apwt/apwt-0.3.0-outputs.json` and five new test
files. Base `316ac5a` resolves (HEAD). `genesis-ctx check --since 316ac5a --repo genesis` → 30 files, areas api,
config-secrets, runs-worker (+ always-on release-ci, security). The sub-spec has no As built yet (expected after review).
No live acceptance in this review: no fleet update and no QA mutation were needed. I reproduced the two env-type bugs
below with the real `EnvironmentRegistry` in a temp folder.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/ruff check genesis` + the new/touched test files (ruff 0.15.20) | All checks passed |
| `.venv/bin/python -m pytest -q -p no:warnings` | **1520 passed** in 670 s |
| web lint / typecheck / vitest / build | N/A: no `web/**` file changed (`git status`) |
| Vendored tarball sha256 (`shasum -a 256`) | `5712a7a5…0750f0ed`, equal to `VENDORED_APWT_SHA256`; `package/package.json` version 0.3.0; `playwright-appian` HEAD is `5d7ae2d` |
| Package data | `git check-ignore` matches neither the `.tgz` nor the templates, so hatch includes them. I could not rebuild a wheel (`hatchling` is not in the venv); the author's wheel check stands unverified by me |
| apwt error codes vs `playwright-appian/src/agent/protocol.ts:59` `AGENT_ERROR_CODES` | every code in `errors._BY_CODE` exists upstream; unmapped codes fall back to `ApwtError` |

## Checklist

### ADRs
- [N/A] ADR-001 — no graph or control flow.
- [OK] ADR-002 / ADR-004 / ADR-020 — no MCP injection or global Kiro config touched; apwt runs as a program subprocess.
- [OK] ADR-005 / ADR-029 — no registry change.
- [N/A] ADR-008, ADR-009, ADR-025 — no HITL/fork change. Pause reaps processes (`manager.py:326-329`); resume semantics unchanged.
- [OK] ADR-010 / ADR-018 — credentials never enter state: the resolver is called inside `open_session`/`login` only (`client.py:189-194, 205-210`), `TestCredentials.__repr__` redacts (`settings_service.py:50-51`), output is scrubbed (`client.py:_scrub`); test `test_resolver_returns_values_but_never_shows_them`, `test_password_is_scrubbed_from_output`.
- [N/A] ADR-011 — no agent node.
- [OK] ADR-012 — the factory is built in `build_context` (`context.py:72,160`) for the worker; the API imports only platform modules (`api/testing.py`), never workflow code.
- [OK] ADR-013 — Genesis-owned config surface.
- [N/A] ADR-019 — no genesis-core change.
- [N/A] ADR-021 — no write node yet (51-06+).
- [OK] ADR-022 — run-scoped files under `<artifacts>/<wf>/<run>/` (`.pids`, `.apwt`, `apwt-out`), `factory.py:52-58`.
- [OK] ADR-023 / ADR-024 — plain FastAPI sync handlers; no engine change.
- [OK] ADR-026 — no bind change, no auth added.
- [OK] ADR-028 — every route is on the `/api` router (`app.py:156-158`); tests call `/api/...`.
- [N/A] ADR-030 — no persistence change (uses 51-04's `TestSettingsStore`).
- [OK] ADR-031 / ADR-033 / ADR-034 / ADR-045 — no chat tool added; the new routes are config routes, not copilot tools.
- [N/A] ADR-032 — no credits.
- [N/A] ADR-035 — no file inputs.
- [VIOLATION — see Major 2] ADR-036 / ADR-048 — "exactly one dev, single-select" still holds, but the current web form can now move or keep the dev tag against its own Dev switch, which changes which environment feeds the KB and resolves the core MCP credentials.
- [N/A] ADR-037, ADR-039, ADR-041, ADR-043, ADR-047, ADR-049, ADR-050, ADR-054, ADR-061, ADR-062, ADR-063, ADR-065, ADR-066, ADR-069, ADR-071, ADR-073, ADR-074, ADR-076 — not touched.
- [OK] ADR-038 / ADR-040 — vendored, versioned, sha-checked tarball (`vendor.py:43-52`); no Node download, no auto-update; Chromium install is an explicit POST only (`api/testing.py:73-78`).
- [OK] ADR-046 — ships inside the clone/package; no new install step.
- [OK] ADR-068 — no Appian write tool; no delete.
- [OK] ADR-077 — reviewer used `genesis-ctx check`; no bulk docs read.
- [OK] ADR-080 — no new internal dependency entry in `pyproject.toml`.

### Lessons
- [N/A] L-001, L-002, L-017, L-028 — no ACP/MCP env or chat trust.
- [N/A] L-003, L-018 — no SSE change.
- [OK] L-004 — test settings/users in SQLite (51-04 store); passwords in the SecretProvider.
- [OK] L-005 / L-008 — no new event kinds; `_finalize` order unchanged, reap is after `run.final` and never raises (`manager.py:155-167`).
- [N/A] L-009, L-020, L-059, L-060, L-065, L-066 — no graph/run-detail change.
- [OK] L-010 — routes under `/api`.
- [N/A] L-012 — no MCP/CLI card change.
- [OK] L-011 — no web consumer yet; contract fixtures deferred to 51-10/51-11 (deviation 6, accepted).
- [N/A] L-016 — no credits.
- [OK] L-019 — passwords written via `SecretProvider.set/delete` (atomic, serialized).
- [OK] L-021 — no MCP output in context.
- [OK] L-023 — apwt output parsed defensively (`run_json` handles non-JSON, usage exit 2, ok:false with result).
- [OK] L-025 / L-027 — ruff pinned 0.15.20.
- [OK] L-026 — handlers are `def` (threadpool); npm/git/tsc never on the event loop.
- [OK] L-029 / L-049 / L-053 / L-070 — the Dev-account warning resolves `LCP_USERNAME` through `resolve_var` (dev env scope only), `settings_service.py:206-216`.
- [N/A] L-030 — no web change.
- [N/A] L-031, L-050 — no Appian export.
- [N/A] L-033 — no workflow.
- [OK] L-039 — `list_users` and `get_user` share `_user_dto`.
- [OK] L-045 — no chat CLI surface.
- [OK] L-048 — tarball and templates are package data; `test_vendored_tarball_is_package_data_and_sha_checked` asserts the path is inside the package (wheel not rebuilt by me, see Gates).
- [OK] L-051 / L-087 — real CLI probed: fixtures recorded from apwt 0.3.0, `version_mismatch` flagged `derived`.
- [N/A] L-054 — no `--output` flag.
- [OK] L-056 — not yet committed; the commit must include all 23 untracked files listed above (`.tgz` and `templates/lib/index.ts` included).
- [N/A] L-057 — no tag bump.
- [N/A] L-058, L-061, L-062 — no finalizer.
- [N/A] L-068 — SPA serving unchanged.
- [N/A] L-081 — no default turned on.
- [N/A] L-088 — no agent-shell guard change.
- [N/A] L-089 — no bundle commit.
- [OK] L-092 — `__test__ = False` on `TestWorkspace`, `TestSettingsService`, `TestCredentialResolver`, `TestCredentials`, `TestSettingsError`; no `tests/__init__.py` added.
- [OK] L-093 — reap runs after the status is stored and `run.final` emitted; tested through the real `cancel`/`pause`/`fail_orphaned_runs` (`test_run_end_reaps_recorded_process_groups`).
- [OK] L-096 — no route overlaps a generic path-param route (`grep '"/config/{'` finds none).
- [OK] L-097 — the sweep's adopt-branch reap is inside the owner-lock section (`manager.py:429`); the fail branch reaps through `_finalize`. Parametrized `sweep` case passes.
- [N/A] L-098 — no new internal library.
- [OK] L-099 — `VENDORED_APWT_VERSION` is its own constant, independent of the Genesis version.
- [OK] L-100 — no CI-variables call.

### Gates
- [OK] `pytest -q -p no:warnings` (api, config-secrets, runs-worker) — 1520 passed.
- [OK] `ruff check genesis` — clean.
- [N/A] `web: lint && typecheck && test`, `npm run build` — no web change.

## Findings

### Blockers
None.

### Majors

1. **The apwt session daemons (and their signed-in Chromium) are never recorded in `<run>/.pids`, so cancel, pause, a killed worker and the startup sweep leave them running for up to 30 minutes.**
   `run_bounded` records only the `apwt open` CLI process and deletes that record when the call returns
   (`procs.py:133-150`). The daemon that `open` starts is spawned `detached: true` in its own process group
   (`playwright-appian/src/cli/agent/client.ts:247-253`), as the `run_bounded` docstring itself says. Nothing records it.
   `RunManager._reap_run_processes` only reaps `.pids` (`manager.py:155-167`) and never runs `close-all`.
   `ApwtFactory.cleanup_run` does run `close-all`, but only when a caller passes a client, which never happens on the
   RunManager paths. Spec §4 F8 names "daemons, recorders, Playwright runs" as the groups to record and kill, and keeps
   `close-all` "as a last resort". The comment at `manager.py:328` ("pause = kill leaves no browser") is not true for
   sessions. A failed `open --login` can also leave a daemon behind. No test covers a session daemon.
   *Fix:* after `open` (on success, and on failure when `<apwt_home>/<session>/state.json` exists), record the daemon's
   pid from `state.json` (`pid`; detached, so pgid == pid) in `<run>/.pids` with the `apwt_home` marker. The daemon's
   argv carries `--root <apwt_home>`, so the marker check matches. Or, on the RunManager paths, also run
   `<export>/node_modules/.bin/apwt close-all` with `PLAYWRIGHT_APPIAN_HOME=<run>/.apwt` when that folder exists.
   Add a test: a fake detached daemon whose pid is written to a `state.json`, then cancel → the daemon is gone.

2. **On write, a free-text `type: "dev"` overrides the `is_dev` flag, which inverts the read rule and breaks the current web form's Dev switch** (`environments.py:166-171`).
   On read, `type: dev` without `is_dev` is *not* dev (`normalize_record`, tested by `test_type_dev_without_the_flag_is_not_dev`).
   On write, `_legacy_type("dev")` returns `dev` even when `is_dev=False`. The current form always sends both fields
   (`EnvironmentsSection.tsx:83, 244`), and after this change its Type field is pre-filled with the stored enum. I reproduced both cases:
   - (a) Edit the Dev env, switch Dev **off**, save. The Type field still says "dev", so the env **stays dev**. Before 51-05 this untagged it.
   - (b) Add or edit any env with the Dev switch **off** and type "dev" in Type. The **dev tag moves** to that env, changing the KB source and the core-MCP credential env (ADR-036/048) against the switch the user set.

   `test_old_client_is_dev_flag_still_means_dev` covers only an empty type, which the form never sends after its first save.
   *Fix:* make `EnvBody.is_dev` `Optional[bool] = None` so the route can tell "not sent" from `false`. When `is_dev` is
   explicitly `False` and `type` is `dev`, either store `other` (mirroring the read rule) or refuse with 400. Add
   regression tests for (a) and (b) through `POST /api/config/environments`.

### Minors

3. **`TestWorkspace.write` leaves the new content on disk when `typecheck()` raises instead of returning errors** (`workspace.py:259-270`).
   A tsc timeout or a missing `npx` raises `WorkspaceError` before the restore branch runs. The file stays modified and
   uncommitted, and later shows up as an "outside edit" in `status()`. Wrap the typecheck in `try/except` and restore on any exception. Add a test.
4. **`create()` can leave a half-built workspace that `exists()` then reports as created** (`workspace.py:176-199`).
   `package.json` is written before `_copy_vendor()` checks the tarball's sha. A `VendorError` (or a git failure) leaves
   `.git` plus `package.json` with no commit, so `exists()` is True from then on and `create()` returns False. The
   workspace has no HEAD, and `ensure()` goes on to `npm install` it. Verify the tarball before writing, or make
   `exists()` require a HEAD.
5. **`set_dev_environment(<the QA env>)` silently drops the QA environment** (`environments.py:272-281`; reproduced: `qa_environment_label()` → None).
   Test executions then report "No QA environment" with no hint why. Refuse with a clear message ("change its type first"), as a second QA is refused.
6. **`POST /config/testing/runtime/chromium` has no lock**, so two clicks run two concurrent `npm install` + `playwright install` into the same `testing/runtime` and `testing/browsers` folders.
   Use `path_lock(runtime_project_dir)`, as the workspace already does.
7. **The `reap()` marker check has not been tested against a real apwt or Chromium command line.** The tests put the marker in argv themselves.
   For a Playwright run started through `npx` from an export whose `node_modules` is a symlink, check that at least one
   process in the group names the export path or the browsers folder. If none does, the record is dropped and the group
   survives. Add one real-process check in 51-06, where the Playwright runs start.

### Nits
8. `ensure_workspace` finds the blocking problems by matching text (`"Chromium" not in p`, `api/testing.py:139`). Return typed problem codes from `detect()` instead.
9. The workspace and Chromium routes block an HTTP request for 26–45 s (up to 900 s timeout). This is fine for now; 51-11 may want a background job with status polling.
10. Spec §7 still says "fixtures copied from real apwt 0.2.0 output" and §4 says "always `--json`". Docs should record deviations 1 and 2 in the As built.

### Deviations (judged)
1. `close`/`close-all` parsed from `KEY: value` text. **Accepted**: the recorded 0.3.0 outputs show they have no `--json`. Suggest a `playwright-appian` follow-up to add one.
2. Fixtures from 0.3.0, not 0.2.0. **Accepted**: 0.3.0 is the vendored version and the 51-03 minimum. `version_mismatch` is honestly marked derived.
3. Free-text type on write is mapped, not refused. **Accepted for every value except `dev`** (Major 2).
4. `.gitignore` also ignores `output/`. **Accepted**: it is apwt's scratch folder.
5. Site suggestions are empty on today's KBs. **Accepted** as a parser follow-up. The code path is tested with a seeded `url_stub`.
6. Web types and fixtures deferred to 51-10/51-11. **Accepted**: no web consumer exists yet.

## Verdict: NEEDS_CHANGES

Fix Majors 1 and 2, each with its regression test, and re-run `pytest` + `ruff`. Minors 3–6 should land in the same
change. Minor 7 can move to 51-06 if it is recorded there.

---

## Re-review — base 316ac5a, still uncommitted (genesis-review, 2026-11-03)

Scope: `git diff 316ac5a` (the same 8 modified files) plus the same untracked set (`git status --short`). I read the
fix diffs in `procs.py`, `integrations/apwt/client.py`, `config/environments.py`, `api/_shared.py`, `runs/manager.py`,
`testexec/workspace.py`, `testexec/runtime.py`, `api/testing.py` and the new tests. No live acceptance: no fleet update
or QA mutation was needed. I did not repeat the author's live `apwt open` → `reap()` run; that evidence is the author's.

### Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| `.venv/bin/ruff check genesis` + the six touched test files | All checks passed |
| `.venv/bin/python -m pytest -q -p no:warnings` | **1529 passed** in 251 s (was 1520; +9 regression tests) |
| Wheel contents (`unzip -l /tmp/gwheel-5105/genesis-0.80.0-py3-none-any.whl`) | lists `genesis/testexec/vendor/playwright-appian-0.3.0.tgz` and the five `templates/*` files. This closes the L-048 gap from the first review |
| web gates | N/A: no `web/**` change |

### Earlier findings

- **Major 1: FIXED.** `ApwtClient.open_session` calls `_track_daemon(session)` in a `finally` (`client.py:205-207`). It
  reads `<apwt_home>/browsers/<session>/state.json`, which matches upstream (`playwright-appian/src/agent/state.ts:137,175`;
  my first review gave the wrong path). When `status != "closed"` and `pid > 1`, it calls
  `record_group(pid_dir, pid, name="apwt-daemon-<session>", markers=[apwt_home])` (`client.py:272-281`, `procs.py:record_group`).
  The daemon's argv carries `--root` (`client.ts:221`), which names the home, so `reap()`'s marker check matches.
  `close()` forgets the record only after `apwt close` succeeds (`client.py:236-237`). A failed close keeps the record,
  so the reap still covers that session. `close_all()` forgets every `apwt-daemon-*`. The factory sets
  `pid_dir = <run>/.pids` (`factory.py:55`), the folder the RunManager reaps on `_finalize`, pause and the sweep. Tests:
  `test_open_records_the_daemon_and_reap_stops_it[open|open_host_not_allowed]` uses a real detached process with
  `--root <home>` argv and proves that `reap()` kills it. `test_close_and_close_all_forget_the_daemon` and
  `test_a_closed_session_is_not_recorded` cover the other paths. The pause comment is corrected (`manager.py:328`).
- **Major 2: FIXED.** `EnvBody.is_dev: Optional[bool] = None` (`_shared.py:77`) is passed through unchanged
  (`config_routes.py:80`). `upsert` (`environments.py:upsert`) resolves the type as follows:
  `is_dev=True` gives dev. A typed `dev` with an explicit `is_dev=False` gives `other`, which mirrors
  `normalize_record`. With no type sent, an existing dev keeps dev only when `is_dev` was not sent. `is_dev=True` with
  `qa` is refused. I traced both reproduced cases. In (a), the old form saves the Dev env with Type "dev" and the switch
  off; the env becomes `other` and is untagged. In (b), typing "dev" on another env with the switch off stores `other`,
  and the tag stays on `Dev`. Both run through `POST /api/config/environments` in
  `test_api_old_form_dev_switch_off_untags_and_does_not_move_the_tag`; the registry-level cases are covered by
  `test_explicit_is_dev_false_wins_over_a_typed_dev`. The `ADR-036 / ADR-048` checklist line is now **OK**.
- **Minor 3: FIXED.** `write()` restores the file when the typecheck raises
  (`test_write_restores_the_file_when_the_typecheck_itself_fails`).
- **Minor 4: FIXED.** `create()` verifies the tarball before writing anything. It builds in `<root>.creating`, commits,
  then `os.replace`s the folder into place, and removes the build folder on any failure. It refuses a non-empty folder
  that is not a workspace (`workspace.py:create`; `test_a_failed_create_leaves_no_half_built_workspace`).
- **Minor 5: FIXED.** `set_dev_environment(<QA env>)` raises "change its type first"
  (`test_dev_and_qa_on_one_environment_are_refused`).
- **Minor 6: FIXED.** `install_chromium` runs under `path_lock(runtime_project_dir(settings))` (`runtime.py:147`).
  There is no concurrency test, which is acceptable for a lock wrapper.
- **Minor 7: DEFERRED to 51-06** as agreed. It must appear in 51-06's As built with one real-process reap check.
- **Nit 8: FIXED.** `detect()` returns `problem_codes` aligned with `problems` (`runtime.py:110-116`), and
  `ensure_workspace` filters by `chromium-missing` (`api/testing.py:138-139`).
- **Nits 9 and 10:** moved to the As built, as stated.

### New findings

#### Blockers / Majors
None.

#### Minors
None.

#### Nits
11. **`_track_daemon` runs in a `finally`, so an `OSError` from `record_group` would replace the real `apwt open`
    error.** This can happen when `<run>/.pids` cannot be written. On a successful open it would also raise for a session
    that is in fact open (`client.py:206-207`). Catch `OSError` inside `_track_daemon`, log it, and let the original
    outcome stand.
12. **Only the daemon's group is recorded. Chromium runs in its own group (63074 in the author's live check) and depends
    on the daemon's SIGTERM handler** (`daemon.ts:159`, `shutdown('killed')`). `kill_group` sends SIGKILL after a
    3 s grace. If the daemon's shutdown takes longer than that (for example while it writes a trace during a recording),
    Chromium's cleanup then depends on its pipe to the dead parent closing. Check this once in 51-06's live run while
    recording, along with Minor 7.

### Checklist delta
Only the `ADR-036 / ADR-048` line changes: VIOLATION → **OK** (Major 2 evidence above). Every other line from the first
review still holds. L-048 is now verified by the reviewer from the wheel listing. L-056 still applies at commit time:
the commit must include every untracked file (`genesis/api/testing.py`, `genesis/integrations/apwt/`, `genesis/testexec/`
including the `.tgz` and `templates/lib/index.ts`, `tests/fixtures/apwt/` and the five new test files).

## Re-review verdict: SHIP

Both majors are fixed with regression tests that exercise the real paths (a real detached process for the reap; the
real `/api/config/environments` route for the Dev switch). Minors 3–6 and Nit 8 are fixed. ruff is clean and pytest
passes 1529. Nits 11–12 are optional. Minor 7 and Nit 12 move to 51-06's As built and live check.
