# Review 55-13 — base 361c99a6 → head 15ac92c1 (genesis-review, 2026-11-24)

What this change does: the run graph card shows its status as a token-tinted card with a status border and a lucide
status icon instead of a StatusPill row, back at 84 px (D28). A workflow can name a model per agent node
(`META.models`, `META.default_model`). genesis-core picks the first candidate that Kiro lists for the account, reads
that list once per worker from a bare session at the provider seam, and records a canonical `model.fallback` that Run
Detail shows as "used X instead of Y" (D29). Documents no longer lists System files, and lists tool outputs only while
one of their files exists (D30).

Commits: `7cf01475` (source, tests, probes) and `15ac92c1` (web/static), both resolved; local, not pushed, not tagged.
No genesis-workflows change.

## Gates (re-run by the reviewer)

- genesis-core: `pytest -q` → **172 passed**; `ruff check genesis_core` → clean.
- genesis: `pytest -q` (scratch `GENESIS_STATE_DIR=/tmp/gr-55-13-review/state`) → **2399 passed, 4 skipped** (14m20s);
  `ruff check genesis` → clean.
- web: `npm run lint` → 0 errors / 20 warnings (baseline); `npm run typecheck` → clean; `vitest run` → **86 files /
  1050 passed**.
- Stale bundle: `npx vite build --outDir /tmp/gr-55-13-review/static` then `diff -r … web/static` → **identical**;
  `git show --stat 15ac92c1 -- web/static` → 67 files; `git status` empty.
- Built CSS contains every new class (`ring-offset-surface-2`, `border-border-strong`, `bg-{success,danger,warning}-subtle`,
  `grad-brand-soft`, `motion-reduce:animate-none`, `before:content-['·']`). This confirms L-123 in the real bundle.
- genesis-workflows `ci/validate_library.py` → **LIBRARY VALIDATION PASSED (19)**.

## Checklist

The `genesis-ctx check` output lists every ADR and lesson for the touched areas. Only the lines this diff can affect
are answered one by one below. Every other listed rule is N/A: the diff does not touch HITL gates, KB, documents
store, stages, stories, schedules, hub, chat, testing, MCP trust/registry, migrations or distribution (ADR-003…010,
013…018, 020…026, 028…031, 033…050, 052…054, 056…065, 067…068, 070…085, 087; L-001…L-004, L-006, L-008…L-010,
L-012, L-015…L-089 not named below).

- [OK] **ADR-001/011** — the change adds no control flow, and the reliability trio is untouched. The fallback is
  decided inside the turn (`nodes/agent.py:475-488`). `test_node_models.py` PICK uses `attach_reliability` and passes
  the lint.
- [OK] **ADR-002/004** — the turn keeps its per-node MCP servers. The list-read session drops them
  (`replace(options, mcp_servers=[], model=None)`, `agents/kiro.py:44`). Proof: `test_the_list_read_uses_the_turns_shape_without_servers_or_model`.
- [OK] **ADR-012** — the app process does not import workflow code. The worker reads `parse_models(meta)`
  (`worker.py:319`), and `meta` comes from `loader.load_build` (`worker.py:292`). A real subprocess worker test exists:
  `test_a_real_worker_hands_meta_models_to_the_nodes_and_logs_the_fallback`.
- [OK] **ADR-019** (additive within CORE_MAJOR 1) — all core additions are new (`agents/models.py`,
  `KiroAcpProvider.advertised_models`, five new exports). `advertised_models` is optional and kept out of the
  runtime-checked Protocol (`provider.py:41-43`). The default behaviour is unchanged when nothing is set: no
  candidates means no list read and `model=None` (parametrised case `(None, {}, None)` asserts `probes == 0`). The one
  behaviour change is deliberate (D29 B): a code-set `model=` that the account does not list now falls back instead of
  failing at session start.
- [OK] **ADR-027/055** — tokens only (`card-tone.ts`), primitives reused, icons come through `shared/ui/icons.ts`.
- [OK] **ADR-032** — no credit logic changed. The live fallback turn recorded 0.337 metered credits.
- [OK] **ADR-051** — the check runs at the provider seam. `choose_model(provider, …)` uses
  `getattr(provider, "advertised_models")`, so a stub or another provider without the method is trusted
  (`test_an_unknown_list_is_trusted[absent]`). Nodes do not touch the Kiro loader.
- [OK] **ADR-066** — `agent.prompt.model` is the model actually used (`agent.py:483`), and the fallback is visible in
  the node summary and the turn explorer.
- [OK] **ADR-069/086** — the list-read session uses the turn's own options: the run's `_kiro` home, `NODE_AGENT_ID`,
  agent prompt and trust (test asserts `cwd, kiro_home, agent_id, agent_prompt, trust, turn_timeout, startup_timeout`
  are equal). Nothing is read from `~/.kiro`. The spike used the same shape (`spike_models.py:45-47`).
- [OK] **ADR-077** — no agent-system change.
- [OK] **L-005/L-011/L-122** — `model.fallback` is in `_CANONICAL_CUSTOM` (`manager.py:59-61`), `CANONICAL_EVENT_KINDS`,
  `canonical-kinds.json` and a golden event (`events.ts:77-79`). The three-way check in `contract.test.ts` is green.
  The real-worker test asserts the event is stored with its node column and not as `custom`.
- [OK] **L-007** — the fold is pure: `modelFallbacks` / `fallbackIn` in `conversation.ts`, with unit tests.
- [OK] **L-013** — `models` and `default_model` are META keys mirrored in the yaml, not yaml-only. The parity cases
  cover META-only, yaml-only and drift.
- [OK] **L-014** — jest-axe is run on every tint (`node-card.test.tsx` "no a11y violations on any tint") and on the
  Inspector with the note. No new ambient types were needed.
- [OK] **L-020** — the retry key is still the node name. `choose_model` runs per attempt, and the list read is cached.
- [OK] **L-044/L-117** — the spike ran on the installed kiro-cli 2.37.1 with the product session shape and a negative
  control (S3, an unlisted id). Recorded in `evidence/55-13/spike/result.json` (13 ids, current `claude-sonnet-5.5`).
- [OK] **L-069** — no `<Button asChild>`.
- [OK] **L-089** — the bundle is a separate commit and was checked after the build. The reviewer's rebuild is
  identical to `web/static`.
- [OK] **L-090** — real-browser probe at 1280/1440/1920 in light and dark, with per-card contrast composited over the
  canvas (opacity included) and the card height. The reviewer re-read `graph/result.json`. Minimum text contrast is
  5.64 (running, dark) and minimum icon contrast is 3.78 (pending, light). All heights are 84 and there are no
  layout problems.
- [OK] **L-094** — callers checked. `agent.prompt.model` is read by the iterations fold and the turn header, which now
  get the used id. The only `aria-label` status readers are the probe and tests, which were updated. A grep for
  `: running|: ok…` aria labels finds nothing else. `groupByStep().system` has no remaining reader.
- [OK] **L-109** — one reader. `parse_models` feeds both the worker and `check_models`.
  `test_the_lint_reports_exactly_the_readers_errors_on_each_side` proves the lint's errors are the reader's errors.
- [OK] **L-110/L-111** — every claim was re-run here. The live run is one cheap hello-appian turn (r-c5a2e2990b13).
- [OK] **L-123** — no opacity modifiers (the test asserts no `/\d` in any tint class), and every class exists in the
  built CSS (above).
- [OK] **L-025/L-027/L-030** — ruff is pinned and unchanged. The web job runs because `web/**` changed.
- [N/A] **L-056/L-057/L-112** — no release in this sub-spec (that is 55-12).

## Findings

### Blockers
none

### Majors
none

### Minors

- m1 **The agent-node check of `models` never runs in the library's CI, and no spec says when it will**
  (`genesis/lint/contract.py:97-106`, `genesis/cli/test_workflow.py:56-58`).
  - What: `check_node_models` is called only by `genesis test-workflow`. `check_meta_yaml_parity` checks only the
    shape.
  - Problem: a library workflow could ship `models: {draft_sectoin: …}` with a typo. `validate_library` would pass,
    and the step would quietly run on the default model. That is the case D29 says must be a lint error. The dev
    brief says the wiring is "for 55-12", but `55-12-release-and-onboarding.md` mentions `models` only in docs lines
    49/62. No task to call `check_node_models` from `ci/validate_library.py` after the pin bump exists.
  - Fix: add one line to 55-12, for example: "genesis-workflows `ci/validate_library.py` calls
    `genesis.lint.check_node_models(compiled, meta)` beside `check_required_mcp` once pinned on the 55-13 tag."
  - If skipped: the first workflow that sets `models` is unguarded in CI. No workflow sets it today.

- m2 **The list read has no lock and caches only success** (`packages/genesis-core/genesis_core/agents/kiro.py:36-55`).
  - What: `if self._advertised is not None: return …`, then `await client.start()`. `_advertised` is set only on
    success.
  - Problem, case 1: in a `_parallel` fan-out, LangGraph runs the branch nodes as concurrent tasks in one worker. With
    `default_model` set, every branch enters before the first read finishes, so N agent nodes start N bare kiro-cli
    sessions (2.3–3.6 s each, per the spike) instead of one.
  - Problem, case 2: when the read keeps failing (for example a `startup_timeout` on a slow machine), every turn and
    every retry pays the probe again and logs the warning again. That cost is up to `startup_timeout` per turn,
    before the real session starts.
  - Fix: hold an `asyncio.Lock` around the read, and cache the failure for the process (store `{"ids": []}`, which
    `choose_model` already treats as "trust the first candidate"). Add one test that runs two concurrent calls and
    asserts `len(started) == 1`, and one that asserts a failed read is attempted once.
  - If skipped: no wrong model and no credits are lost. The cost is extra seconds and extra kiro-cli processes per
    run.

### Nits

- n1 **The turn explorer header names the model twice** (`NodeIterationsDialog.tsx:199-201`). The header reads "ok ·
  claude-sonnet-5.5 · used claude-sonnet-5.5 instead of genesis-no-such-model-55-13" (see
  `evidence/55-13/agent/agent-fallback-explorer-1440-dark.jpg`). Optional: hide `turn.model` when `modelFb` is set.
- n2 **The tab-badge count has no rendered test.** `RunDetailPage.tsx:139` is a one-line call to the tested
  `visibleDocuments`, but nothing asserts the badge itself excludes System files.

## Not checked

- The selection ring on each tint in a real browser. Only class assertions exist in jsdom, and the probe shoots no
  selected card.
- `cancelled` and `retrying` cards in a real browser. `cancelled` shares the neutral tone with `skipped`, which was
  measured (≥ 16:1 text, ≥ 7.98:1 icon). `retrying` is not a `NodeStatus` the snapshot emits today.
- A live fallback to a *listed* next candidate (the `chosen` branch). Only the "Kiro's default" branch ran live; the
  other is covered by `test_an_unlisted_node_model_falls_back_to_the_default_model` and the real-worker stub test.
- kiro-cli 3.x list shape (`specs/backlog/kiro-cli-3x-reverify.md`).
- The probe and the live run themselves were not re-run by the reviewer. Their `result.json` files and screenshots
  were read.

## Verdict: SHIP

There are no blockers or majors, and every gate is green on re-run. m1 is a tracking line for 55-12. m2 is a small
hardening that can go into 55-11/55-12 or a v0.84.x patch.

---

# Re-run 1 — delta 15ac92c1 → f9ac5013 (genesis-review, 2026-11-24)

What the delta does: it fixes m2, n1 and n2 from the first review. `KiroAcpProvider.advertised_models` now reads Kiro's
model list under an `asyncio.Lock` created on first use, and caches a failed read as `{}`. The method returns `{}` as
None, so `choose_model` trusts the first candidate. The read itself moved to `_read_models`. The turn explorer header
no longer prints `· <model>` when a `model.fallback` note is shown. A rendered test checks the Documents tab badge.

Commits: `75500834` (source and tests) and `f9ac5013` (web/static), both resolved. HEAD is `f9ac5013`, the tree is
clean, and nothing is pushed or tagged. The delta touches 4 source files: `packages/genesis-core/genesis_core/agents/kiro.py`,
`tests/test_agent_models.py`, `web/src/features/run-detail/components/NodeIterationsDialog.tsx` and
`web/src/features/run-detail/resolve.test.tsx`. It also touches 66 bundle files. No `genesis/` app file changed, and
no genesis-workflows file changed.

## Gates (re-run by the reviewer)

- genesis-core: `pytest -q -p no:warnings` → **173 passed** (172 before, plus the new test); `ruff check genesis_core`
  → **All checks passed**.
- web: `npm run lint` → 0 errors / 20 warnings (baseline); `npm run typecheck` → clean; `vitest run` → **86 files /
  1051 passed** (1050 before, plus the badge test).
- Stale bundle: `npx vite build --outDir /tmp/gr-55-13-rr1/static --emptyOutDir`, then `diff -r … web/static` →
  **IDENTICAL**. `git show --stat f9ac5013 -- web/static` → 66 files. `git status --short` → empty.
- Fail-first of the m2 test: I extracted `15ac92c1:packages/genesis-core` to `/tmp/gr-55-13-rr1/old`, added the new
  test file from `f9ac5013`, and confirmed that `genesis_core` imported from the copy. Result:
  `test_the_list_is_read_once_for_parallel_turns_and_a_failure_is_not_retried` **FAILED** with `assert 3 == 1`
  (three concurrent calls started three sessions). The other 15 tests passed. The test catches the old behaviour.
- genesis app pytest: not re-run, because the delta changes no `genesis/` file. The change at the provider seam is
  covered by the genesis-core suite. The genesis tests that touch it (`test_node_models.py`, `test_kiro_readiness.py`)
  use their own providers or stubs and never reach the changed read path.

## Checklist (delta only)

`genesis-ctx check --since 15ac92c1 --repo genesis` maps the delta to the areas core-engine, web-runs, release-ci and
security. The lines below are the ones this delta can affect. Every other listed ADR and lesson is N/A. The delta adds
no node, no gate, no state, no event kind, no endpoint, no MCP or trust change, no migration, no schedule and no
release.

- [OK] **ADR-002/004/069/086**: the session shape that reads the list is unchanged. `_read_models` still builds
  `KiroACPClient(replace(options, mcp_servers=[], model=None))` (`agents/kiro.py:53-54`), and the earlier test
  `test_the_list_read_uses_the_turns_shape_without_servers_or_model` still passes.
- [OK] **ADR-011/020/L-020**: the reliability trio is untouched. A retry still calls `choose_model` on each attempt. After
  the fix it gets the cached answer, including a cached failure, so a retry no longer pays for the read again.
- [OK] **ADR-019** (additive within CORE_MAJOR 1): the public return type is still `{ids, current} | None`. `{}` is
  internal and is turned into None at both returns (`kiro.py:39,48`). `_read_models` is private. No export changed.
- [OK] **ADR-024** (async-first): the lock is `asyncio.Lock`, created lazily inside the running loop
  (`kiro.py:43-44`). After the first read, `_advertised` is set and the lock is never entered again, so a provider
  used across event loops (pytest) cannot hit "bound to a different loop". A `CancelledError` during the read is not
  caught by `except Exception`. It leaves `_advertised = None` and releases the lock, and the next waiter tries the
  read again. That behaviour is correct.
- [OK] **ADR-051**: the fix stays inside `KiroAcpProvider`. `choose_model` and the nodes are unchanged
  (`agents/models.py:63-65` reads `(listed or {}).get("ids")`, so None and `{}` would both mean "trust").
- [OK] **ADR-066**: the turn explorer still shows which model was used. When a fallback happened, the note "used X
  instead of Y" names it (`NodeIterationsDialog.tsx:199-201`). When there was no fallback, the `· <model>` span is
  still rendered (the `!modelFb` guard affects only the fallback case).
- [OK] **ADR-027/055, L-069, L-123**: the web change only adds a condition. It adds no class, no colour and no
  `asChild`.
- [OK] **L-011**: the badge test uses the real `/documents` shape (`category: "system"`, `roles_declared`,
  `tool_outputs`, `legacy`). It renders the real router and RunDetailPage, so a stub does not stand in for the badge.
  Of the 3 documents, 1 is System, so the old count (3) and the new count (2) differ, and the test can tell them apart.
- [OK] **L-089**: the bundle is its own commit. I checked it after the build had exited, and a reviewer rebuild is
  identical to it.
- [OK] **L-025/L-027/L-030**: ruff is pinned and unchanged. The frontend CI job runs, because `web/**` changed.
- [OK] **L-110**: every claim in the dev brief was re-run here: counts, lint, typecheck, bundle and fail-first. The
  claimed record of m1 did not check out (see m3).
- [N/A] **L-056/L-057/L-111/L-112**: no release in this sub-spec. The release is 55-12.

## Disposition of the first-review findings

- **m1: open, and the claimed record does not exist.** See m3 below. No code change was expected.
- **m2: fixed.** The lock and the cached failure match the fix I asked for. Both cases have assertions in one test:
  3 concurrent calls start 1 session, and a failing read is attempted once over 3 calls. The test fails on the old
  code (above).
- **n1: fixed** (`NodeIterationsDialog.tsx:199`). It has no test of its own; see n3.
- **n2: fixed** by `resolve.test.tsx` "55-13 (D30): the Documents tab badge leaves System files out". The badge text
  must match `^Documents\s*2$`.

## Findings

### Blockers
none

### Majors
none

### Minors

- m3 **The m1 record that the brief describes is not on disk.**
  (`specs/phase-55-workflow-execution/55-13-live-testing-changes.md`, `55-12-release-and-onboarding.md`)
  - What: the brief says m1 "is recorded for 55-12 in the As built (a validate_library call to check_node_models after
    the pin bump)".
  - Problem: 55-13 has no As built section. Its headings are §1–§5 and the Context manifest. `grep -rn
    check_node_models specs/phase-55-workflow-execution/` matches only this review. 55-12 has no such task either.
    Its only `models` lines are the docs lines that the first review cited. As things stand, the first workflow that
    sets `models` with a typo would pass `validate_library`, which is the gap m1 describes.
  - Fix: write the 55-13 As built, including the commits `7cf01475`, `15ac92c1`, `75500834` and `f9ac5013` and the
    review verdicts. Add one task line to 55-12: "genesis-workflows `ci/validate_library.py` calls
    `genesis.lint.check_node_models(compiled, meta)` beside `check_required_mcp` once pinned on the 55-13 tag."
  - If skipped: the release agent has nothing telling it to wire the lint, and m1 is lost.

### Nits

- n3 **The n1 fix has no assertion.** `model-fallback.test.tsx` "the node summary's per-execution chip and the turn
  explorer's header both show it" opens the dialog and finds the note, but it does not check that the duplicate is
  gone. Optional fix: add one line after `within(dialog).getByText(text)`:
  `expect(within(dialog).queryByText(/^· claude-sonnet-5\.5$/)).not.toBeInTheDocument()`.

## Not checked

- The genesis app suite (2399 tests) on the delta. No `genesis/` file changed, and the provider path it uses is stubbed.
- The live turn explorer header after n1. No fleet use and no live runs were allowed by this brief. jsdom does not
  assert the header either (n3).
- A real `_parallel` fan-out sharing one list read in a real worker. Only the unit test with a slow fake client covers
  it.

## Verdict: SHIP

There are no blockers or majors in the delta. Every gate is green on re-run, and the m2 regression test fails on the
old code. m3 is a documentation gap, not a code defect. It should be closed before 55-12 starts, because m1 depends on
it. n3 is optional.
