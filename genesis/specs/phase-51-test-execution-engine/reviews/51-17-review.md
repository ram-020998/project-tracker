# Review 51-17 — base genesis 4f6f283, genesis-workflows f6b9397 (genesis-review, 2026-11-06)

Sub-spec: `51-17-setup-composer.md` ("Compose a data setup with AI (`setup-composer`) and multi-role setups");
decisions 51-01 D8, D13, D22, D27, D28, D33, D35, D36. Commits reviewed (all resolve, local, not pushed): genesis
**96dceeb** (source, tests, contract fixtures) + **2621743** (`web/static` only); genesis-workflows **24145bf**
(setup-composer 0.1.0, action-capture 0.2.1, skill genesis-test-authoring 0.3.0, registries, fixtures);
project-tracker: the uncommitted `51-10-api.md` edit. Offline review only: no live acceptance (that is the 51-12
re-run, step 27).

Read: `genesis-ctx check --since` for both repos, both diffs (`git diff 4f6f283..96dceeb`, `git diff
f6b9397..24145bf`), the spec, 51-01 D8/D13/D22/D27/D28/D33/D35/D36, ADR-011/021/067, L-020/033/058/061/093/094, and
the code around the change (`RunManager._meta`/`reconcile_status`, `promote_proven_actions`, `library_snapshot`,
`attach_healing`, `PlatformState` reducers, `runner.scrub_dir`, `lib/index.ts` `withAppian`).

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/ruff check genesis` + the three changed test files | All checks passed |
| genesis `.venv/bin/python -m pytest -p no:warnings` | **1781 passed** in 691.68 s (log `/tmp/51-17-pytest.log`) |
| genesis changed tests (`test_testexec_compose.py`, `test_testing_api.py`, `test_testexec_recording.py`) | 85 passed |
| genesis-workflows `ci/validate_library.py` | LIBRARY VALIDATION PASSED (18 workflows); reliability-lint and internal-pin self-tests OK |
| genesis-workflows `ci/validate_skills.py` | SKILLS VALIDATION PASSED (4) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **419 passed** |
| genesis-workflows `ruff check workflows/action-capture workflows/setup-composer ci` | All checks passed |
| web `npx tsc --noEmit` | clean |
| web `npx eslint .` | 0 errors, 20 warnings (the base count) |
| web `npx vitest run` | **721 passed** (62 files) |
| stale bundle: `vite build --outDir /tmp/51-17-static` then `diff -rq … web/static` | IDENTICAL |
| genesis `git status --short --untracked-files=all` (own call) | empty |

Environment note: my first full pytest run hung for 28 min in the unchanged `tests/test_config.py::
test_server_readiness_probe`, which starts a real `docker` handshake; its `docker-credential-osxkeychain get` child
waited on the keychain in this non-interactive session. Killing that helper let the test finish (it expects the
handshake to fail). Not related to 51-17; the author's run did not hit it.

## Spec conformance

- **§2 multi-role setups (D36).** `lib/index.ts` `SetupMeta.roles?`; `scan-refs.mjs:114` reports `roles`.
  Generator `setup_extra_roles` (`generator.py:164-180`) reads a literal array; unreadable → not automated
  (`generator.py:301-303`); one `auth:<role>` project per role and the setup project depends on all
  (`generator.py:533-536`, golden `generated-roles/playwright.config.ts:31-32`); `Catalog.roles` includes extra roles
  (`generator.py:120`). Readiness: library Replay asks for every role (`library_service.py:954-957`, test
  `test_a_library_replay_of_a_two_role_setup_needs_and_signs_in_every_role`); story scope (`verification.py:412-415`,
  test `test_story_verification_scope_includes_a_setups_extra_roles`). Save checks
  `_setup_roles_problems` (`library_service.py:415-440`): literal, no main role, no repeat, test-user roles. OK.
- **§3 dialog and API.** Choice dialog + Compose dialog (`ComposeDialog.tsx`; picker excludes retired, shows contract
  and role; extra roles; end state; QA/credits note bound to the Compose button by `aria-describedby`). `POST
  …/testing/compose` (`api/testing.py:785-797`) → `ComposeService.start` (`compose.py:171-211`): 400 request problems,
  409 readiness for every role, skill ≥ 0.3.0 with its compose section, workflow ≥ 0.1.0 (YAML only through
  `RunManager._meta`, no graph import, ADR-012), one compose per app under a lock. Panel labels "Recording" /
  "Composed" (`CapturesPanel.tsx`). 51-10 table updated (project-tracker, uncommitted). OK.
- **§4 setup-composer 0.1.0.** `prepare → compose (kiro_node, trio) → v_compose → after_compose → [attach_healing:
  replay → heal → reassemble] → present`, `escalate` gate Retry / Discard. META ↔ YAML parity and the trio pass
  `validate_library`; no `pre_mutation` gate per D22 (ADR-082 is proposed, added by 51-13). OK, with m-1 and m-2.
- **§5 applying.** Same `ProposalService.apply` path; origin `compose`; Ready when the replay passed at the code;
  `missing` result → Record workflow prefilled with the step and the main role (`LibraryView.tsx`, test in
  `compose.test.tsx`). OK, except M-1.
- **§6 tests.** Present for the generator golden files, readiness per role, save checks on the real scanner + tsc, the
  dialog (jest-axe), the route's refusals, the workflow's nodes with stubbed agent turns, the finalizer through the
  real `RunManager._finalize`, apply. Missing: the on-read settle of a compose capture (M-2).
- **As built:** not yet written in the sub-spec. genesis-dev records it after this review.

## Checklist — genesis (`genesis-ctx check --since 4f6f283 --repo genesis`)

### ADRs
- [OK] ADR-011 — trio on every agent node: `compose` via `attach_reliability` (`graph.py` build), `replay`/`heal` via
  `attach_healing`; `validate_library` reliability lint passed.
- [OK] ADR-012 — the app never imports workflow Python: `compose.py` reads META through `RunManager._meta`
  (`manager.py:111-113`, "yaml, no graph import"); the graph is imported only by tests (`_wf()` in
  `test_testexec_compose.py`).
- [OK] ADR-019 — no change to `CORE_MAJOR` or the loader; additive only.
- [OK] ADR-023 — a FastAPI route over the embedded RunManager.
- [N/A] ADR-026 — no bind/auth change.
- [OK] ADR-027 — `ComposeDialog.tsx` composes `Dialog`, `Field`, `Select`, `Badge`, the grid primitives
  (`GridCard`, `Pager`, `CountOf`, `rowClickProps`); design tokens only (`bg-surface-1`, `text-warning`,
  `bg-primary-subtle`), no raw palette colours.
- [OK] ADR-028 — route under `/api` (`api.post("/applications/{app_uuid}/testing/compose")`); the client uses
  `testing(appUuid)` (`lib/api/testing.ts:107`), no literal `/api` in components.
- [N/A] ADR-031 / ADR-033 / ADR-034 / ADR-045 — chat untouched.
- [OK] ADR-035 — no file inputs; inputs are JSON fields, the checkout and snapshot are written by `prepare` into the
  run folder.
- [N/A] ADR-043 — no annotation SDK change.
- [N/A] ADR-046 / ADR-080 — no packaging or version change.
- [N/A] ADR-047 / ADR-074 — no sync change.
- [OK] ADR-050 — status changes of library items go through `LifecycleService.transition` (`proposals.py` apply
  "approve"; `promote_proven_actions`); capture status is the capture store's CAS, as before.
- [OK] ADR-055 — shadcn-style primitives, no MUI.
- [OK] ADR-063 / ADR-065 — local only: `compose` origin and capture kind are not Hub-synced (the test library is
  local-only), checked per L-094 below.
- [N/A] ADR-071 / ADR-076 — no story page or spec change.
- [OK] ADR-077 — agents untouched; the review used `genesis-ctx`.

### Lessons
- [OK] L-003 / L-018 — no SSE change.
- [OK] L-004 — state in SQLite (`kb_test_captures.request_json`, `proposals_json`); no JSON-file store.
- [OK] L-010 — `/api` prefix centrally.
- [N/A] L-017 / L-045 — no chat trust change.
- [N/A] L-019 — no secret writes.
- [OK] L-025 / L-027 — ruff pinned, clean.
- [OK] L-030 — this change touches `web/**`, so the frontend job runs.
- [N/A] L-031 — no Appian export.
- [OK] L-039 — `list_captures` and the single get both return `_with_run(…)` rows with the same fields.
- [N/A] L-048 — packaging unchanged.
- [N/A] L-051 — no release.
- [OK] L-056 — `git status` empty; 96dceeb holds source + tests + fixtures, 2621743 only `web/static`.
- [N/A] L-057 — no tag bump yet (51-13).
- [OK] L-068 — `index.html` serving unchanged.
- [N/A] L-087 / L-088 — no corpus or hook change.
- [OK] L-089 — rebuild identical and empty status, each checked in its own call.
- [OK] L-092 — no new `tests/__init__.py`; module name `test_testexec_compose.py` unique.
- [OK] L-096 — `POST …/testing/compose` has no path-param sibling; existing route-order test still passes.
- [N/A] L-098 / L-099 / L-100 — no packaging, version or CI-variable work.

### Manifest lessons (from the sub-spec)
- [OK] L-011 — new fixtures `compose`, `capture-compose`, `capture-compose-missing`, `capture-compose-apply`,
  `error-compose` recorded from real responses (`_compose_rows`), checked in `contract.test.ts`.
- [OK] L-020 — `execution.recursion_limit: 120`; `_after_gate` resets `retries` keyed by agent node name
  (`compose`, `heal`, `replay`); `_inc_merge` is absolute-last-writer (`state.py:21-25`), so the reset takes.
- [OK] L-033 — missing / old workflow → 409 with a fix link (`compose.py:158-169`, `problems.ts` `setup-composer`).
- [OK] L-042 — picked items, snapshot and checkout are files; the prompt names paths only.
- [VIOLATION → M-2] L-058 — the on-read recovery exists (`api/testing.py:778-782`, `:823-829`, `:850`) but no test
  exercises it for a compose capture.
- [OK] L-061 — `finalize_run` requires `cap.run_id == run_id` and `cap.kind == self.KIND`
  (`capture_finalizer.py:170`); test `test_the_bound_run_guard_and_the_startup_reconcile_of_its_own_kind_only`.
- [OK] L-064 / L-076 — one turn writes one file.
- [OK] L-083 — fixtures use the real result shapes (`result.json` with `proposal.replay.used`).
- [OK] L-093 — finalizer tests end runs through the real `RunManager._finalize` (`_end` in
  `test_testexec_compose.py:347-355`).
- [OK] L-094 — `VALID_LIBRARY_ORIGINS` / `VALID_CAPTURE_KINDS` consumers: only the store writers
  (`testexec_store.py:280`, `:1299`); web `LibraryItem.origin` widened; captures routes filter on `_LISTED_KINDS`;
  `CaptureFinalizer` now filters by kind. No collab consumer.

### Gates
- [OK] `pytest` — 1781 passed. [OK] `ruff check genesis` — clean.

## Checklist — genesis-workflows (`genesis-ctx check --since f6b9397 --repo genesis-workflows`)

### ADRs
- [OK] ADR-001 — the graph routes; the agent writes one file and `compose.json`.
- [OK] ADR-003 / ADR-007 — registry entry with roles as tags.
- [N/A] ADR-005 / ADR-029 / ADR-020 — `required_mcp: []`, no registry change.
- [OK] ADR-006 — self-contained folder (`workflow.yaml` + `graph.py`), `registry.json` entry.
- [OK] ADR-010 / ADR-018 / ADR-022 — state holds pointers and small decisions; code, checkout, reports live in the run
  folder.
- [OK] ADR-011 — trio on `compose`, `replay`, `heal` (lint passed; test
  `test_meta_mirrors_the_yaml_and_every_agent_wears_the_trio`).
- [OK] ADR-012 — imports only `genesis_core` and langgraph; replay generators and scanner rules are copies with
  parity tests in both repos.
- [OK] ADR-014 / ADR-015 / ADR-017 — Python, library steering (skill §7).
- [OK] ADR-019 — no core-major change.
- [OK] ADR-021 (as amended by D22 / proposed ADR-082) — `auto_approve: true`; the only gate is `escalation`; no
  `pre_mutation` because the Compose click is the approval for QA data writes as test users. ADR-082 is not yet in
  the ADR index (51-13 adds it); same posture as action-capture 0.2.0.
- [N/A] ADR-026 / ADR-030 / ADR-031 / ADR-033 / ADR-036–039 / ADR-041 / ADR-045 / ADR-046 / ADR-048 / ADR-056–059 /
  ADR-061–063 / ADR-065 / ADR-073–076 / ADR-078 — not touched by this workflow (no Appian MCP, no KB, no stages).
- [OK] ADR-034 / ADR-069 — skills declared via `kiro_node(skills=SKILLS)`; provisioned by Genesis.
- [OK] ADR-035 — no file inputs.
- [OK] ADR-067 — `attach_healing(…, max_heal=1, max_restart=1)` from `META.healing`; escalate on exhaustion.
- [OK] ADR-068 — no delete tool, no MCP.
- [OK] ADR-077 / ADR-080 — n/a to code; no pins changed.

### Lessons
- [OK] L-006 / L-013 — `workflow.yaml` carries the `graph:` topology (parity lint passed).
- [OK] L-009 — async nodes, checkpointer-compiled graph.
- [N/A] L-017 / L-045 — no chat.
- [OK] L-020 — see above.
- [OK] L-021 / L-023 — no MCP output; `composed_from_run` and `_load` are defensive.
- [OK] L-022 — no custom reducer keys; `from __future__ import annotations` is safe.
- [OK] L-024 — skills from the filesystem.
- [OK] L-025 / L-027 — ruff clean.
- [OK] L-026 — `tsc`, the scanner and Playwright run in `asyncio.to_thread` (`_prepare`, `_v_compose`, `_replay`).
- [N/A] L-029 / L-049 / L-053 — no managed MCP or core Appian credential (test-user credentials go to the Playwright
  child through the platform runner).
- [N/A] L-030 / L-051 / L-056 / L-057 / L-087 / L-088 / L-098–L-100 — no release yet.
- [OK] L-033 — Genesis refuses before the run (see above).
- [OK] L-042 / L-064 / L-075 / L-076 — files in the workspace; one turn per deliverable; heals in place.
- [OK] L-089 — n/a here (no bundle).
- [OK] L-092 — `tests/` has no `__init__.py`; unique module name.

### Gates
- [OK] `validate_library.py` (18) · [OK] `pytest workflows` (419) · [OK] genesis `pytest` (1781) · [OK] `ruff`.

## The author's decisions (a)–(l)

- **(a) action-capture 0.2.1, gate stays 0.2.0** — agree. With 0.2.0 still installed, a recording setup that declares
  `roles` would replay with only the main role signed in, so `ctx.as('<other>')` fails and the setup stays Draft; no
  unearned Ready. The re-recorded fixture only adds `roles: null` per define plus the two new samples (diffed).
- **(b) `missing` = a `ready` capture with no proposals** — agree; apply on it writes nothing and moves to `applied`
  harmlessly; the panel offers Record and Discard only.
- **(c) limits and the off-role 400** — agree. See m-3 for a multi-role *setup* picked with fewer roles.
- **(d) Retry / Discard** — agree; the reset works because `retries` uses an absolute merge (`state.py:21-25`) and
  `_healing` a shallow merge.
- **(e) the D35 screen-step regex** — agree in principle; nit n-2 on the comment stripper.
- **(f) `uses` and `replay.used`** — agree for direct uses; disagree that it covers what the replay ran (M-1).
- **(g) list reconciles on read; kind filter** — agree with the code; it needs a test (M-2).
- **(h) `_save_code` syncs `lib/` first** — agree; nit n-3.
- **(i) new origin/kind values, no migration** — agree (writer-validated; no CHECK in m0026–m0028; L-094 consumers
  checked).
- **(j) create `analysing`, then `bind_run`** — agree. A run that ends before `bind_run` is skipped by the live
  finalizer (`for_run` finds nothing) and settled by the next read once bound; the 3 s panel poll makes that prompt.
- **(k) extra roles signed in inside the replay** — agree; the runner gets every role, so `scrub_dir` covers every
  password in reports and zipped traces (`runner.py:149-170`); one-role text unchanged (parity test passes for 0, 1
  and 2 extra roles).
- **(l) regex in the generator, scanner in the save** — agree; the cross-repo test proves the scanner side; the
  generator regex is pinned by `test_setup_extra_roles_reads_only_a_literal_array`.

## Findings

### Blockers
None.

### Majors

- **M-1 — Staleness is checked only for direct uses, so an action reached through a used data setup can be proven
  Ready by a replay that ran different code (the 51-16 m-2 rule, which §6 says to keep).**
  `ProposalService._stale_reuses` (`genesis/testexec/proposals.py:270-291`) compares only the keys in the setup's
  `uses`, and the workflow records hashes only for them (`setup-composer/graph.py:745`, `used = {k: … for k in
  uses}`). A composed setup may import a picked **data setup** (D33: "pick actions and existing data
  setups"; `setup_problems` resolves imports against every snapshot item, setups included, `graph.py:302-313`). `_prove_used_actions` then calls `promote_proven_actions(app, commit=<the apply commit>, [("setup", DS)])`
  (`proposals.py:316`), which walks `kb_test_refs` transitively and checks each file's content **at the apply
  commit** against its current hash (`library_service.py:891-917`). That check always passes for an action edited
  after the compose export and before the apply, so the action gets `last_replay = passed` and moves Draft → Ready,
  and the composed setup is Ready too, although the QA replay ran the old code. 51-16 had no such path because a
  recording's setup "calls actions only". Proposals can wait days for review, so the window is real.
  **Fix:** record the hash of every library file the replay ran, transitively (the replay workspace has the files;
  `scan_refs` over the used setups' files, or Genesis's own `kb_test_refs` walk at export time), and have
  `_stale_reuses` walk the same closure; or pass the compose export commit (keep it in `request_json` or the result)
  and prove at that commit. Add a test: a composed setup using `DS-x` whose action `ACT-y` is saved between compose
  and apply → the setup and `ACT-y` stay Draft, `proven == []`.

- **M-2 — The on-read settle of a compose capture has no test (L-058).** `_settle_on_read`
  (`genesis/api/testing.py:778-782`) picks the finalizer by kind and is now called from the list
  (`:823-829`) and the single get (`:850`). Nothing tests that a compose capture whose `setup-composer` run is
  terminal (live `run.final` missed, e.g. ended before `bind_run`, or across a restart) is settled by `GET
  …/captures` or `GET …/captures/{id}`. The only list read of a compose capture (`test_testing_api.py:612`) happens
  while the run is still running; `_compose_rows` then sets the status by hand. A wrong dispatch (e.g. the recording
  finalizer, which now returns early on kind) would leave the capture `analysing` forever and block every later
  compose for the app ("one compose at a time"). **Fix:** a test that creates a compose capture bound to a run
  stored `done` with a `result.json`, with no live finalize, then asserts `GET …/captures` returns it `ready` (and one
  for the single get); optionally one for a recording capture to pin the refactor.

### Minors

- **m-1 — A re-compose (guided restart or gate Retry) sees the previous pass's file under `proposed/`.** Nothing clears
  `<run>/proposed/` or `compose.json` before `compose` re-runs. `compose_doc_problems` then refuses a new slug ("write
  only the one setup file", `graph.py:250`) and refuses a `missing` outcome outright ("a missing result writes no
  setup file", `graph.py:213`). Each costs a retry turn and can exhaust the budget into the gate. **Fix:** clear
  `proposed/` (and the old `compose.json`) when routing back to `compose` from `heal_route` restart and from
  `after_gate` Retry, or tell the agent in the prompt to remove its earlier file; add a node test for restart →
  `missing`.

- **m-2 — The composer's replay leaves saved logins on disk if the runner raises.** `_replay_sync` removes
  `replay-ws/.auth` only after `runner.run` returns (`graph.py:734-741`), not in a `finally`. The extra roles'
  `storageState` files (session cookies of test users, new in 51-17) then stay in the run folder; Genesis's
  `library_service.replay` uses a `finally` for the same cleanup (`library_service.py:1013-1015`). **Fix:** wrap the
  run in `try/finally` and remove `.auth` there.

- **m-3 — A picked multi-role data setup's extra roles are not required of the composed setup.** `ComposeService._items`
  checks only an item's main `role_key` (`compose.py:140`); the snapshot carries `role` but not `roles`
  (`recording.py:417-419`), so `setup_problems` checks only main roles too (`graph.py:309`). Picking `DS-x` (buyer +
  approver) for a buyer-only setup passes both checks; the replay then fails on `ctx.as('approver')` (no saved login)
  and the heal cannot fix it without changing the roles the person chose. The generator would also not create
  `auth:approver` for scenarios on the new setup, since it reads only the composed setup's own `roles`. The replay
  stops an unearned Ready, so this costs a run rather than shipping a bug. **Fix:** add `roles` to the snapshot items
  (the scanner already reports them), treat a used setup's extra roles like its main role in `_items` and
  `setup_problems`, and show them in the picker's Role column.

### Nits

- **n-1 — The `used` hash and Genesis's `content_hash` are compared across repos without a test that computes both.**
  The workflow hashes file bytes (`sha256_file`); Genesis hashes UTF-8 text (`sha256_text`). They agree for a git
  export, but the Genesis tests feed `act["content_hash"]` straight in as `used`. A one-line assertion in the
  cross-repo test (`wf.sha256_file(ws.root / act["path"]) == act["content_hash"]`) would pin it.
- **n-2 — The D35 comment stripper also eats string text after `//`.** `_COMMENT` (`graph.py:137`) removes from any
  `//` to end of line, including inside a string literal (`page.goto('https://…'); await x.click()` on one line hides
  the click). The replay and review still see the code; low risk.
- **n-3 — A code save can add a "Update Genesis's lib/ helpers" commit even when the save itself is refused or a
  no-op** (`library_service.py:693`). Harmless and idempotent; worth one line in the As built.
- **n-4 — `ComposeService` reads `RunManager._meta` (private), as `RecordingService` already does.** A public
  `meta_of` on RunManager would make both cleaner.

## Not verified here
A real Kiro compose and heal turn, a QA replay signing two roles in, and the web UI in a real browser. These belong to
the 51-12 re-run, step 27.

## Verdict: NEEDS_CHANGES

Every gate is green and the design decisions (a)–(l) hold up, but two majors block SHIP:
1. **M-1:** make staleness (and the proof) cover what the replay ran transitively, with the regression test named
   above.
2. **M-2:** add the on-read settle test for a compose capture (list and single get).

The minors m-1–m-3 should be fixed in the same pass or recorded as follow-ups in the As built; the nits are optional.

---

# Delta review — genesis 2621743..2b2cf9d, genesis-workflows 24145bf..69bface (genesis-review, 2026-11-06)

Both commits resolve and are the HEADs (`git log --oneline`); both trees clean (`git status --short
--untracked-files=all` empty). Read: `genesis-ctx check --since 2621743 --repo genesis` and `--since 24145bf --repo
genesis-workflows`, both diffs in full, and the code each fix relies on (`TestStore.refs_from`
`kb/testexec_store.py:469-476`, `TestWorkspace.show` `workspace.py:467-471`, `sha256_text` `library_service.py:109`,
`setup_extra_roles` `generator.py:164-180`, `overlay` use in `_check_setup` `graph.py:667-684`, `apply_patches`
`graph.py:555-562`). Offline only.

## Gates (re-run by the reviewer)

| Gate | Result |
|---|---|
| genesis `.venv/bin/python -m pytest -p no:warnings -q --deselect tests/test_config.py::test_server_readiness_probe` | **1784 passed, 1 deselected** in 548 s (= the author's 1785; the deselected test is the docker-keychain hang noted above, unchanged code) |
| genesis `ruff check genesis tests/test_testexec_compose.py tests/test_testing_api.py` | All checks passed |
| genesis-workflows `ci/validate_library.py` | LIBRARY VALIDATION PASSED (18 workflows) |
| genesis-workflows `pytest -q workflows --ignore=workflows/_fixtures` | **421 passed** |
| genesis-workflows `ruff check workflows/setup-composer workflows/action-capture ci` | All checks passed |
| web `npx tsc --noEmit` | clean |
| web `npx eslint .` | 0 errors, 20 warnings (the base count) |
| web `npx vitest run` | **721 passed** (62 files) |
| stale bundle: `vite build --outDir /tmp/51-17-delta-static` then `diff -rq … web/static` | IDENTICAL |
| M-1 regression proof: tree of 2b2cf9d with 2621743's `genesis/testexec/proposals.py`, `PYTHONPATH` first | `…[True]` **FAILED** (`assert status == "draft"`, got `ready`), `…[False]` passed; on 2b2cf9d both pass |

## Per finding

- **M-1 — resolved.** `ComposeService.start` stores the export commit (`compose.py:208`, the same `commit` the
  snapshot and checkout use, `:213`). `_stale_reuses` routes a composed setup's library keys to `_stale_composed`
  (`proposals.py:277-279`), which walks `refs_from` from those keys (`proposals.py:290-323`) and flags an item when its
  current `content_hash` differs from `sha256_text(ws.show(<export commit>, path))`, when a direct key's `replay.used`
  hash differs from that, or when the commit or the file is missing (fail safe). Both callers pass `cap`
  (`proposals.py:219` Ready decision, `:342` `_prove_used_actions`), so a stale closure keeps the setup Draft and
  proves nothing. The walk uses the current `kb_test_refs`; that is sound because a used setup whose imports changed
  since the export has a different hash and is flagged before its refs are read. The regression test
  `test_an_action_inside_a_used_data_setup_changed_since_the_compose_keeps_everything_draft`
  (`test_testexec_compose.py:506`) runs on the real workspace and fails on the old code (table above). The `[False]`
  case also proves the positive path: the action reached through the used setup is proven (`proven == [ACT]`).
- **M-2 — resolved.** `test_reading_the_captures_settles_a_compose_capture_whose_run_ended`
  (`test_testing_api.py:651`): two compose captures bound to runs stored `done` with a `result.json` and no live
  finalize; `GET …/captures` settles one to `ready` with the `missing` step, `GET …/captures/{id}` settles the other
  to `failed` with the error, and `capture_finalizer.reconcile_capture` returns False for a compose capture (the
  dispatch by kind is pinned). Fixtures changed only by `request.commit` plus timestamps, run ids and commit shas
  (diffed); `CaptureRequest.commit?` added (`web/src/types/testing.ts:294-295`).
- **m-1 — resolved.** `compose_doc_problems` no longer lists `proposed/` (`graph.py:211-215`, the extra-file check
  removed). Only the proposal's own file is laid over the checkout (`_check_setup` → `overlay(…, p["path"],
  p["code"])`, `graph.py:673`) and patched (`apply_patches`, `graph.py:558`), so a stray file is never run. Test
  `test_an_earlier_passs_file_under_proposed_does_not_block_a_new_slug_or_a_missing_result` (`test_setup_composer_workflow.py:115`).
- **m-2 — resolved.** `runner.run` in `try/finally` removing `replay-ws/.auth` (`graph.py:735-740`). Test
  `test_the_replay_removes_every_saved_login_even_when_the_runner_raises` (`:184`) writes a `storageState` in the
  runner and raises.
- **m-3 — resolved on the server; the picker remains (author records it).** Snapshot items carry `roles`
  (`recording.py:407-422`, from `scan-refs` defines); `picked_items` passes them on (`graph.py:194`); `setup_problems`
  treats a used item's extra roles like its main role (`graph.py:307-312`); `ComposeService._items` refuses a picked
  data setup whose committed code declares unchosen extra roles (`compose.py:143-148`, `_extra_roles` `:154-163`).
  Tests: `test_a_used_data_setups_extra_roles_must_be_the_setups_roles_too` (workflow, `:163`) and
  `test_compose_refusals[… "also signs in as 'approver'" …]` (genesis, a real committed two-role setup in the `comp`
  fixture). An unreadable `roles` returns `[]` here, but such code cannot be committed (`_setup_roles_problems` at
  save), so no gap.
- **n-1 — resolved.** `test_testexec_compose.py:583` asserts `wf.sha256_file(file) == content_hash`.
- **n-2 — resolved.** `_strip_comments` keeps string and template literals (`graph.py:137-142`); test
  `test_the_screen_step_check_strips_comments_but_not_strings` (`:175`).
- **n-3, n-4 — left as they are by choice**, to be recorded in the As built. Agreed; both are nits.

## Checklist (delta)

genesis (`check --since 2621743`; the changed `genesis/testexec/*` files map to no area, so only always-on rules):
- [OK] ADR-011 — no agent node changed in genesis. [OK] ADR-019 / ADR-080 / ADR-046 — no core-major, packaging or
  version change. [N/A] ADR-026 / ADR-063 / ADR-065 / ADR-074 — no bind, Hub or sync change; `request.commit` is local
  capture data. [OK] ADR-027 / ADR-055 — web change is one optional type field. [OK] ADR-077 — review via
  `genesis-ctx`.
- [OK] L-011 — fixtures re-recorded from real responses, shape change only `request.commit`. [OK] L-025 / L-027 —
  ruff clean. [OK] L-030 — `web/**` touched (types, fixtures). [OK] L-056 — 2b2cf9d holds source, tests, fixtures and
  type together. [OK] L-058 — the recovery is now tested (M-2). [OK] L-089 — rebuild identical; status empty in its own
  call. [OK] L-092 — no new test package or `test_*` symbol outside tests. [N/A] L-017 / L-045 / L-051 / L-057 / L-087 /
  L-088 / L-098 / L-099 / L-100 — no chat, release, corpus, hook, packaging or CI-variable work.

genesis-workflows (`check --since 24145bf`):
- [OK] ADR-001 — routing unchanged; the change is validator rules and cleanup. [OK] ADR-010 / ADR-018 / ADR-022 —
  state untouched; files stay in the run folder. [OK] ADR-011 / ADR-067 — trio and `attach_healing` unchanged
  (`validate_library` passed). [OK] ADR-012 — `graph.py` still imports only `genesis_core`/langgraph. [OK] ADR-021 —
  no gate change. [OK] ADR-068 — no MCP, no delete tool. [OK] ADR-069 — skills unchanged. [N/A] ADR-003/005/006/007/
  014/015/017/019/020/026/029–031/033–039/041/045/046/048/056–059/061–063/065/073–076/078/080 — not touched by this
  delta.
- [OK] L-006 / L-013 — `graph:` topology unchanged (parity passed). [OK] L-020 — retry keys unchanged. [OK] L-022 — no
  reducer keys added. [OK] L-026 — the replay still runs in `asyncio.to_thread`. [OK] L-042 / L-064 / L-075 / L-076 —
  unchanged design. [OK] L-092 — no `tests/__init__.py`. [N/A] L-009 / L-017 / L-021 / L-023 / L-024 / L-029 / L-033 /
  L-045 / L-049 / L-051 / L-053 / L-056 / L-057 / L-087–L-089 / L-098–L-100 — not touched.
- Gates: [OK] `validate_library.py` · [OK] `pytest workflows` (421) · [OK] genesis `pytest` (1784 + 1 deselected) ·
  [OK] `ruff check genesis`.

## New findings

### Blockers / Majors / Minors
None.

### Nits
- **dn-1 — The old `.auth` cleanup after the replay is now redundant** (`graph.py:744-745`, `if ws is not None:
  shutil.rmtree(ws / ".auth", …)` right after the new `finally`). It still covers the `problems` branch, where no run
  happens and no `.auth` is written, so it can go. Harmless.
- **dn-2 — The Compose picker's Role column still shows only the main role** (the library list API carries no
  `roles`). The 400 from `_items` names the missing role, so the person learns it on submit; as the author says,
  record it in the As built (or add `roles` to the list rows later).
- **dn-3 — `_strip_comments` does not know JavaScript regex literals**: a `/https:\/\//` literal would start a `//`
  comment and hide the rest of the line from the D35 screen-step check. Composed setups have no reason to use regex
  literals, and the replay and review still see the code. Optional.

## Verdict: SHIP

Both majors are fixed with regression tests; I confirmed the M-1 test fails on 2621743's `proposals.py` and passes on
2b2cf9d. The three minors are fixed with tests, n-1 and n-2 are fixed, and n-3/n-4 are left by choice for the As
built. Every gate I re-ran is green. Not verified here: a real Kiro compose and heal turn, a two-role QA replay and
the dialog in a real browser (the 51-12 re-run, step 27).
