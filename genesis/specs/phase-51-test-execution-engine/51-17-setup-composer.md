# 51-17 — Compose a data setup with AI (`setup-composer`) and multi-role setups

> **Status:** SPEC-DRAFTED 2026-11-04. Repos: **genesis** (backend + web), **genesis-workflows** (`setup-composer`
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
