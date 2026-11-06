# 51-17 — Compose a data setup with AI (`setup-composer`) and multi-role setups

> **Status:** BUILT 2026-11-06 (genesis-review NEEDS_CHANGES → delta SHIP — `reviews/51-17-review.md`). SPEC-DRAFTED 2026-11-04. Repos: **genesis** (backend + web), **genesis-workflows** (`setup-composer`
> 0.1.0; skill `genesis-test-authoring`). Parent: `specs/phase-51-test-execution-engine.md`. Decisions: 51-01 D33,
> D35, D36 (and D8, D22, D27, D28). Uses m0028 from 51-16. Built after 51-16.

## 1. Goal

**New data setup → Compose with AI:** the person picks actions and existing data setups from the library, chooses the
role(s), and describes the end state; an agent writes the setup from those pieces only, Genesis checks and replays it on
QA, and the person reviews it as a proposal. Data setups may span several roles (D36), so end states that need two
people can be composed.

## 2. Multi-role setups (D36)

- `lib/`: `SetupMeta` gains `roles?: string[]` (extra roles; the main role stays `role`); `defineSetup` passes them
  through; `ctx.as(role)` already gives a role's page. Template and skill §2 updated.
- **Generator (51-06):** read a setup's extra roles from its committed code (a literal string array, like a case's
  role; anything else → the setup's scenarios not automated, with the reason); add an `auth:<role>` project for each
  and make the `setup:<instance>` project depend on all of them; `Catalog.roles` includes them; golden files.
- **Readiness (51-05):** every role a selected setup declares needs a test user with a password.
- **Save checks (51-07):** extra roles must be test-user roles of the app; the main role still equals
  `kb_test_setups.role_key`.

## 3. Compose dialog and API

- **New data setup** opens a choice: **Write it myself** (today's template) or **Compose with AI**.
- **Compose with AI** dialog: name; main role (+ extra roles, D36); a library picker (search, kind, area; actions and
  data setups, Ready or Draft, never retired; shows each item's contract and role); the **end state** in words; a note
  that the run writes data on QA as the test users and spends agent credits (the click is the approval, D8 / ADR-082).
- `POST …/testing/compose` `{name, role_key, roles, item_keys, end_state}` → 202 `{capture}`: a `kb_test_captures` row
  with `kind = "compose"` (no CHECK on `kind`; no migration) and the request in `request_json` (m0028), then a
  `setup-composer` run started and bound to it; refusals 409 `problems` (readiness for every role, the workflow and the
  skill installed, L-033) or 400 (unknown or retired key, empty end state). One compose at a time per app (as one
  recording at a time).
- The capture appears in the Library's **Proposals to review** panel with its status (`analysing` → `ready` /
  `failed`); `/testing/captures` lists recording **and** compose captures (51-10 decision updated); the panel labels
  them "Recording" / "Composed".

## 4. `setup-composer` 0.1.0 (genesis-workflows `workflows/setup-composer/`)

    prepare(program) → compose(agent, trio) → v_compose(validator) → [attach_healing: replay(verify) → heal(agent, trio)] → present

- **`prepare`** — the workspace export (`<run>/checkout`), the picked items' code + contracts + roles, and the whole
  catalog snapshot as files (L-042); no browser session, no credentials in the agent's view.
- **`compose`** (ordinary `kiro_node`, D3c, no browser; skills `genesis-test-authoring` + the workspace's
  `playwright-appian`; `turn_timeout` 900 s) — writes **one** setup under `proposed/setups/<slug>.ts` that reaches the
  end state using the picked items and, where they leave a gap, other library items (D35); `unique()` for per-run
  values; the end state's ids as outputs; `ctx.as(role)` for the extra roles. Writes `compose.json`: `{status:
  "proposed" | "missing", proposal, added: [{key, why}], missing: "<the step no library item does>"}`.
- **`v_compose`** (program) — exactly one setup; imports only library items; every added item is listed with a
  reason; outputs only; main and extra roles as requested; `export default`; typecheck over the checkout with the
  proposal laid over it. `status: "missing"` is a valid outcome: it skips replay and ends with the message.
- **`replay`** — the 51-07 setup replay (program; the 51-06 runner; credentials only in the Playwright child; report
  scrubbed) as each role the setup declares. A pass marks the setup and the actions it used as passed at that code.
- **`heal`** — ADR-067 (≤ 1 patch in place from the replay's error and screenshot, ≤ 1 guided restart of `compose`);
  never adds screen steps (D35). Budgets spent → the `escalate` gate (Retry / Discard) → `present`.
- **`present`** — `result.json` `{status, proposal, added, missing, replay}`; a `ComposeFinalizer` (the
  `CaptureFinalizer` pattern: bound run, idempotent, reconcile, store before announce; L-058, L-061, L-093) stores it
  on the capture.
- ADR-011 trio on both agent nodes; no `pre_mutation` gate (D22; ADR-082 as amended: the person's Compose click is the
  approval); `META` ↔ `workflow.yaml` parity; registry entry; `validate_library` green.

## 5. Applying

The same apply path as 51-07 §6: Accept creates the setup with a real `DS-` key (Ready when the replay passed at that
code), one commit; Reject discards. A `missing` result offers **Record workflow** prefilled with the missing step as
the intent.

## 6. Tests

**From 51-15 (As built):** the composed setup must declare its `outputs` literally (a save without them is refused,
D27); save results carry `changed`; reuse `promote_proven_actions` when the replay passes, `report_url` for its
report link (D26), the grid helpers (`web/src/features/testing/grid.tsx`, `grid-logic.ts`) for the library picker,
and `FakeRunner(evidence=True)` in tests that need report files. The Library's kind filter lives in the URL
(`?kind=`, `kindFromUrl` and `LIBRARY_KIND_LABEL` in `logic.ts`); the compose capture's "Composed" label goes there
too.

**From 51-16 (As built):**
- `request_json` (m0028) is in place: store the compose request there.
- **Extend, don't copy, the dependency rule** (`dependency_problems`, `setup_uses`): it assumes `uses` holds proposal
  ids; a composed setup uses library keys. One rule for both.
- **The validator pattern** is `action-capture`'s setup checks (the same rules as the library save, 51-16 m-1); reuse
  them for `v_compose` and extend them — and the library save checks — to accept D36's `roles: [...]`, so both
  workflows and the save stay in step (keep the cross-repo comparison test passing).
- Proving the actions a passing replay used goes through `promote_proven_actions`; a reused action whose code changed
  since the replay is not proven, and neither is the setup that used it (51-16 m-2).
- **Version gate:** as Record refuses a setup request unless `action-capture` ≥ 0.2.0, the compose route refuses unless
  `setup-composer` ≥ 0.1.0 and the skill carries its compose section; bump the `genesis-test-authoring` skill to 0.3.0
  (compose section + `roles`).

Generator golden files for a two-role setup; readiness per role; save checks; the dialog (picker, roles, end state,
jest-axe); the route's refusals; the workflow's nodes with stubbed agent turns (a proposed setup, a `missing` result, a
`v_compose` refusal, a failing replay healed); the finalizer through the real `RunManager._finalize`; apply. Gates as
51-15 §5. Live: 51-12 re-run step 27.

## Context manifest

```toml
areas    = ["workflows-library", "core-engine", "runs-worker", "stories-workbench"]
adrs     = ["ADR-011", "ADR-012", "ADR-021", "ADR-050", "ADR-067", "ADR-069"]
lessons  = ["L-011", "L-020", "L-033", "L-042", "L-058", "L-061", "L-064", "L-076", "L-083", "L-089", "L-093"]
docs     = ["tracker:specs/phase-51-test-execution-engine/51-01-findings.md", "tracker:specs/phase-51-test-execution-engine/51-07-action-library-and-recording.md", "tracker:specs/phase-51-test-execution-engine/51-16-record-as-data-setup.md"]
code     = ["genesis/genesis/testexec/**", "genesis/genesis/kb/testexec_store.py", "genesis/genesis/api/testing.py", "genesis/web/src/features/testing/**", "genesis-workflows/workflows/action-capture/**", "genesis-workflows/workflows/story-verification/**", "genesis-workflows/skills/genesis-test-authoring/**"]
upstream = ["51-05", "51-06", "51-07", "51-15", "51-16"]
```

## As built (2026-11-06, genesis-dev)

**Task restated.** A data setup may now span several roles: the main role stays `role` (`kb_test_setups.role_key`)
and the others are a literal `roles: [...]` in `defineSetup` (D36). The generator, readiness, the library save and
the library Replay all read them. **New data setup** opens a choice: Write it myself, or **Compose with AI**. Compose
takes a name, the roles, picked library items and an end state, and starts one `setup-composer` run bound to a
`compose` capture. The run writes ONE setup from library items only (no browser, no screen steps, D35), checks it
like a save, replays it on QA as every role it declares, and heals once. It ends with a proposal, or names the
missing step (`missing`) so the person can record it. The person applies the proposal through the same
`ProposalService` path as a recording's setup (D28: the actions it used are proven). Applicable rules: ADR-011 (the
trio on `compose` and `heal`), ADR-012 (Genesis reads only META; `graph.py` is self-contained, with copies pinned by
parity tests), ADR-021 as amended by D22 / ADR-082 (no `pre_mutation` gate; the Compose click is the approval),
ADR-050 (status changes only through `LifecycleService`), ADR-067 (≤ 1 patch, ≤ 1 restart), ADR-069 (skills per
node). Lessons: L-011/L-083 (fixtures from real responses and real scans), L-020, L-033, L-042, L-058, L-061, L-064,
L-076, L-089, L-093, and L-094 (new registry values checked).

### Commits

Base: genesis `4f6f283`, genesis-workflows `f6b9397`. Local only, not pushed or tagged.

| Repo | Commit | What |
|---|---|---|
| genesis | `96dceeb` | multi-role setups (lib, scanner, generator, readiness, save checks, Replay), ComposeService + route, ComposeFinalizer, the dependency rule for library keys, web source, tests, contract fixtures, golden files |
| genesis | `2621743` | `web/static` for `96dceeb`. A rebuild followed, then `git status --short --untracked-files=all` was empty (its own call). |
| genesis | `2b2cf9d` | review M-1 (transitive staleness against the export commit), M-2 (on-read settle tests), m-3 (picked setup's extra roles), n-1. Types only on the web side; a rebuild followed and the status was empty (its own call). |
| genesis-workflows | `24145bf` | setup-composer 0.1.0, action-capture 0.2.1, skill genesis-test-authoring 0.3.0, registry entries, real scan fixtures |
| genesis-workflows | `69bface` | review m-1, m-2, m-3, n-2 |
| project-tracker | this commit | this As built, `reviews/51-17-review.md`, the 51-10 contract table (POST `…/compose`; captures list both kinds) |

### Changed (genesis)

- **Templates.** `lib/index.ts`: `SetupMeta.roles?: readonly string[]`, comments. `lib/scan-refs.mjs` also reports
  `roles` (a `roles: null` key on every define; a non-literal `roles` is in `dynamic`). Old workspaces get both
  through `sync_lib`.
- **`testexec/generator.py`.**
  - `setup_extra_roles(text)` → `(roles, unreadable)` reads the literal array with a regex, as a case's role is read.
  - `SetupPlan.roles` / `all_roles`. `Catalog.roles` includes the extra roles, so execution readiness and `grep_for`
    cover them.
  - The `setup:<instance>` project depends on `auth:<role>` for every role. Unreadable `roles` → the setup's
    scenarios are not automated, with the reason.
- **`testexec/verification.py`** `story_context`: the scope's roles include a setup's extra roles (an unreadable
  list sets `roles_unknown`).
- **`testexec/replay.py`** `replay_spec_ts(roles=)`: each extra role is signed in first in its own context and its
  `storageState` saved to `authFile(role)`, so `ctx.as(role)` works. Without `roles` the text is byte-identical
  (action-capture parity holds).
- **`testexec/library_service.py`.**
  - `_setup_roles_problems`: refuses a dynamic, repeated or non-test-user role, and the main role listed again.
  - `_save_code` runs `sync_lib` first (see n-3 below).
  - `check_replay` / `replay` ask readiness for every role and pass all roles to the runner. The runner scrubs every
    password.
- **`testexec/compose.py`** (new).
  - `ComposeService.start` and `compose_request` refuse a bad request with a 400: no name or end state, a bad role,
    no item, an unknown, foreign or retired key, or a picked item whose role, or (m-3) picked setup's extra roles,
    are not chosen.
  - It refuses with a 409 for: readiness for every role; the skill ≥ 0.3.0 with "Composing a data setup from the
    library"; setup-composer ≥ 0.1.0 read through `RunManager._meta`; one compose per app, under a lock.
  - Then: `sync_lib` → the capture (`compose`, `analysing`, `request = {compose, commit}`) → `rm.start(prepare=…)`
    (checkout + `library.json`) → `CaptureStore.bind_run`. A start failure fails the capture and answers 409.
- **`testexec/capture_finalizer.py`.**
  - `CaptureFinalizer` is parametrised by `WORKFLOW` / `KIND`. Its reconcile, on-read and live paths now act only on
    their own capture kind.
  - `ComposeFinalizer` and `composed_from_run` turn a ready result into one `setup` proposal: `match: new`, `uses` =
    library keys, `replay.used`, the code copied from the run. `missing` → a `ready` capture with no proposal and the
    step. Anything else → `failed` with the run's reason.
- **`testexec/proposals.py`.**
  - `dependency_problems(library=)` is one rule for proposal ids and library keys: a key must be an item of the app
    and not retired.
  - `_stale_reuses` → `_stale_composed` walks the `kb_test_refs` closure from the keys. Every item must still have
    its code at the compose's export commit, and every direct key must match `replay.used` (M-1).
  - A used key stays a key in the result's `uses`. Apply uses origin `compose` and the message "Apply composed data
    setup (capture #N: …)".
- **`testexec/recording.py`** `library_snapshot` items carry `roles`.
- **`kb/testexec_store.py`.** `VALID_CAPTURE_KINDS` and `VALID_LIBRARY_ORIGINS` gain `compose`. These are
  writer-validated, with no CHECK and no migration (DB stays v28). The library is local-only, so no Hub consumer is
  affected (L-094). New `CaptureStore.bind_run`.
- **`api/testing.py` + `api/app.py`.**
  - POST `…/testing/compose` → 202 `{capture}`. `ComposeError` maps to 400 or 409.
  - `/captures` lists recording and compose captures. Reading the list or one capture settles an analysing capture
    with its kind's finalizer.
  - The startup reconcile also runs the compose finalizer.
- **web.**
  - `ComposeDialog.tsx` (new): `NewSetupChoiceDialog`, and `ComposeDialog` with the grid picker (search, kind and
    area filters, the D31 helpers, never retired, contract and role per row), main and extra roles, end state, the
    QA/credits note, and refusals with fix links.
  - `problems.ts` (new): `fixForProblem`, moved out of `RecordDialog`, with a `setup-composer` link.
  - `RecordDialog` gains `initialIntent` and `initialRole`.
  - `CapturesPanel` shows both kinds with "Recording" / "Composed", compose-specific texts, the `missing` step with
    Record workflow and Discard, and the added items.
  - `LibraryView` wires the choice, the compose dialog and the prefilled Record.
  - `logic.ts`: `CAPTURE_KIND_LABEL`, `composeResultOf`, `composePickable`, `rolesNotChosen`, `contractSummary`.
    `setupBlockedBy` ignores library keys.
  - Types `ComposeRequest`, `ComposeResult`, `ComposeStarted`, `CaptureRequest.compose` / `commit`,
    `Capture.kind` `compose`, `origin` `compose`. API `composeSetup`.

### Changed (genesis-workflows)

- **`workflows/setup-composer/`** 0.1.0 (new; `registry.json`). The graph is
  `prepare → compose → v_compose → after_compose → (missing → present | replay → [attach_healing] → present)`, with
  `escalate` (retry / discard) → `after_gate`. Its parts:
  - `compose_doc_problems` checks the document.
  - `setup_problems` checks the code on the workspace's scanner: export default, DS-NEW, the main role, exactly the
    requested extra roles, literal outputs only, non-retired library imports, unpicked imports in `added` with a
    reason, used items' roles (main and extra) among the setup's, and no screen steps (`_strip_comments` keeps string
    literals).
  - `replay` re-runs the checks before Playwright, because a heal goes reassemble → replay. It writes `uses`, the
    `used` hashes and `roles`, and removes `.auth` in a `finally`.
  - Retry resets `retries` (compose, heal, replay) and `_healing`.
  - `present` writes `result.json`; a code change after the last replay marks the replay `not-run`.
  - `workflow.yaml` mirrors META. The graph carries copies of the replay generators.
- **`workflows/action-capture/`** 0.2.1: `setup_code_problems` refuses `roles` (literal or not) on a recording's
  setup (D13). The real scan fixture was re-recorded with the new scanner; only a `roles: null` key was added. Two
  new samples were added (`with-roles`, `dynamic-roles`).
- **Skill `genesis-test-authoring` 0.3.0** (`skills-registry.json`): §2 covers multi-role setups and calling an
  action as another role (`{ ...ctx, page: await ctx.as('approver') }`); new §7 "Composing a data setup from the
  library".
- **Fixtures** `setup-composer/tests/fixtures/compose-scan/`: sample actions and setups plus `scan-refs-0.1.json`, the
  **real** output of the new `lib/scan-refs.mjs` (TypeScript 5.9.3) over a good two-role setup, dynamic roles, the
  main role repeated, screen steps and a non-library import. The replay reports were copied from action-capture.

### Tests

- **genesis**: full pytest **1785 passed** (1745 at base + 40); `ruff check genesis` clean.
  - `test_testexec_compose.py` (39): `setup_extra_roles`; two-role golden files
    (`fixtures/testexec/generated-roles/`); unreadable roles → not automated; story scope roles; a library Replay of a
    two-role setup (readiness for both roles, both credentials, the extra sign-in).
  - Save checks on the **real** scanner and tsc: a two-role setup with `{ ...ctx, page }` typechecks and saves; four
    refusals; an old scanner is synced at save.
  - ComposeService: 6 request 400s, 9 refusals, start (capture, bound run, checkout with the new lib, snapshot, one
    per app), and a run that cannot start.
  - ComposeFinalizer through the real `RunManager._finalize`: ready, missing, failed, cancelled, discarded, no
    result, the bound-run guard, and a reconcile of its own kind only.
  - Apply on the real workspace: Ready + proven; a stale direct use; a used data setup's action changed after the
    compose (M-1, fails on the old code); retired and unknown keys → 409.
  - Cross-repo parity with the sibling checkout: the replay generator for 0, 1 and 2 extra roles; the code rules vs
    the save on the real scanner; the hashes agree (n-1).
  - `test_testing_api.py`: `_compose_rows` covers the route, refusals, busy, listing, missing and apply. New:
    `test_reading_the_captures_settles_a_compose_capture_whose_run_ended` (M-2). Fixtures `compose`,
    `capture-compose`, `capture-compose-missing`, `capture-compose-apply` and `error-compose` were recorded from real
    responses; value-only regenerations were reverted.
  - `test_testexec_recording.py`: the dependency-rule isolation test covers library keys.
- **genesis-workflows**: `validate_library` PASSED (18), `validate_skills` PASSED (4), pytest **421 passed** (387 at
  base + 34; setup-composer 32, action-capture +2). `ruff check workflows/action-capture workflows/setup-composer ci`
  clean (repo-wide 20 errors were already there at base, none in changed files).
- **web**: tsc clean; eslint 0 errors / 20 warnings (the base count); vitest **721 passed (62 files)** (707 at base
  + 14).
  - `compose.test.tsx` (6): the choice dialog; the picker (no retired items, contracts), the off-role warning, extra
    roles and the exact request body; filters; a 409 with its fix link; a composed proposal in the panel; the missing
    step → Record prefilled → Discard. jest-axe runs on the choice dialog, the compose dialog, the refusal and the
    panel.
  - `logic.test.ts` (3) and `contract.test.ts` (5 fixture checks).
- **Bundle**: `2621743` is web/static only. After each later web change a rebuild left `git status` empty, checked in
  its own call. The reviewer's out-of-tree build was identical.

### Review

`reviews/51-17-review.md`. The first pass was **NEEDS_CHANGES**, with decisions (a)–(l) agreed:

- **M-1**: staleness checked direct uses only, so an action inside a used data setup could be proven by a replay of
  older code.
- **M-2**: no test of the on-read settle.
- **m-1**: an earlier pass's file blocked a re-compose.
- **m-2**: `.auth` was not removed in a `finally`.
- **m-3**: a picked setup's extra roles were not required.
- Nits n-1 to n-4.

M-1, M-2, m-1 to m-3, n-1 and n-2 were fixed in `2b2cf9d` / `69bface`. The M-1 test fails on the old code (the
reviewer confirmed this). The delta review was **SHIP**, with nits only:

- dn-1: the second `.auth` cleanup is now redundant. It is harmless and left as is.
- dn-2: below (d).
- dn-3: `_strip_comments` does not know JavaScript regex literals. It is optional and left.

### Decisions / deviations

No ADR deviation.

1. **(a) action-capture 0.2.1** is the only change to an existing workflow (the shared scanner check). Genesis's
   Record gate stays at action-capture ≥ 0.2.0. An older action-capture would accept `roles`, but its one-role
   replay would then fail, so nothing becomes Ready without proof.
2. **(b) `missing`** is stored as a `ready` compose capture with `proposals.status = "missing"` and no proposals. The
   person can discard it, or Record with the step as the intent and the setup's main role.
3. **(c) Request limits**: at least one picked item and at most 30, at most 5 extra roles, name ≤ 120 and end state
   ≤ 2000 characters. A picked item whose role (or, for a data setup, extra role) is not chosen → 400.
4. **(d) The picker's Role column shows only the main role** (dn-2). The library list API carries no `roles`; the
   server's refusal is authoritative. Showing extra roles there would need a list-field addition.
5. **(e) D35 is enforced in code.** `v_compose` and `replay` refuse screen steps (`.click/.fill/.locator/getBy…`,
   `appian.`); only `page.goto` is allowed.
6. **(f) Staleness of a composed setup** is decided against the compose's **export commit** (`request.commit`), over
   the whole refs closure (M-1). No commit counts as stale.
7. **(g)** `/captures` (list and single) settles analysing captures on read. The finalizers act only on their own
   capture kind; before, the recording finalizer reconciled every analysing capture.
8. **(h) n-3**: `_save_code` runs `sync_lib` first, so a code save on an old workspace may add an
   "Update Genesis's lib/ helpers" commit, even when the save is then refused or changes nothing. It is idempotent.
9. **(i) n-4**: `ComposeService` reads `RunManager._meta`, as `RecordingService` already does.
10. **(j)** The compose capture is created `analysing` and then bound to its run (`bind_run`, CAS). A run that ends
   before the bind is settled on the next read.
11. **(k)** The generator reads `roles` with a regex (like a case's role); the save and `v_compose` read them with the
   scanner. Both are pinned by tests.

### Lesson candidates

- **A proof rule that checks only direct dependencies breaks as soon as a dependency can have dependencies of its
  own.** 51-16's staleness check compared the setup's direct uses because a recording's setup calls only actions. A
  composed setup can call a data setup, so an action two levels down could be proven by a replay of its older code
  (M-1). Record the base the evidence ran on (the export commit) and walk the whole closure against it.
- **When a finalizer class gains a sibling for another kind, give every sweep a kind guard.** The capture finalizer's
  startup reconcile had acted on every analysing capture. That was harmless while only recordings waited in
  `analysing`. A second kind would have been failed with the wrong workflow's message.
- L-089 held: every build, commit and verifying `git status` ran as a separate call.

### Code-map changes

- `genesis/testexec/compose.py` (new): `ComposeService`, `ComposeError`, `compose_request`, `skill_version`,
  `COMPOSE_WORKFLOW_VERSION` (0.1.0), `COMPOSE_SKILL_VERSION` (0.3.0).
- `genesis/testexec/capture_finalizer.py`: `CaptureFinalizer.WORKFLOW/KIND`, `ComposeFinalizer`,
  `composed_from_run`.
- `genesis/testexec/generator.py`: `setup_extra_roles`, `SetupPlan.roles/all_roles`. `replay.py`:
  `replay_spec_ts(roles=)`.
- `genesis/testexec/proposals.py`: `dependency_problems(library=)`, `_stale_composed`, `_library_item`.
- `genesis/testexec/library_service.py`: `_setup_roles_problems`, `_setup_roles`.
- `genesis/kb/testexec_store.py`: `CaptureStore.bind_run`; capture kind and library origin `compose`.
- `genesis/api/testing.py`: POST `…/testing/compose`, `_settle_on_read`.
- `genesis/web/src/features/testing/ComposeDialog.tsx`, `problems.ts` (new); `logic.ts` compose helpers.
- genesis-workflows `workflows/setup-composer/` 0.1.0 (new): `request_of`, `picked_items`, `compose_doc_problems`,
  `setup_problems`, `_strip_comments`, `replay_spec_ts(roles=)`, `verify_report`, `_after_gate`. action-capture
  0.2.1. Skill `genesis-test-authoring` 0.3.0 §7.

### For the 51-12 re-run (step 27)

- **Before:**
  - `genesis install` setup-composer 0.1.0 and action-capture 0.2.1.
  - Install skill genesis-test-authoring 0.3.0 from the Skills catalog. Compose refuses with a 409 otherwise.
  - Restart `serve` with no run active (L-061).
  - No migration (DB stays v28).
  - For a two-role setup, add a second test user with a password.
- **Expect, live:**
  - **Library:** New data setup → the choice → Compose with AI.
  - **Panel:** the capture shows as "Composed", analysing, then either:
    - ready, with one Data setup proposal (uses `ACT-…`/`DS-…`, replay passed); or
    - the missing step, with Record workflow prefilled.
  - **Accept:** a `DS-` item, Ready, origin compose, with the used Draft actions Ready through "capture #N".
  - **Two-role run:** the replay spec signs the extra role in first.
  - **Execution:** the generated config has `auth:<extra role>`, and `setup:<DS>` depends on it.
  - **Old workspaces:** the first compose or save adds an "Update Genesis's lib/ helpers" commit.
- **Not verified here:**
  - a real Kiro compose or heal turn;
  - a QA replay signing two roles in (the `storageState` written by `context.storageState({ path: authFile(role) })`
    inside the replay test);
  - the dialogs in a real browser, including an L-090 width probe of the picker table (jsdom computes no layout).
