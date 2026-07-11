# Genesis — Coding Standards

> A **working**, enforcement-anchored reference for anyone (agent or human) writing Genesis code.
> Read it before your first change; skim it before each session. **It is intentionally short** —
> it captures the decisions this project actually cares about, not a general style guide.
>
> **Golden rule of this doc:** *prose does not prevent drift — tooling does.* Everything in §1 is
> enforced by a linter/typechecker/CI gate and will fail your build. Everything in §2–§6 is a
> convention we haven't (yet) automated; follow it, and prefer to **promote it into a lint rule**
> (§8) rather than rely on memory. When a rule here conflicts with an ADR (`reference/decision-log.md`),
> the ADR wins — tell the user.

---

## 1. Enforced by tooling (the hard floor — do not fight these)

| Area | Rule | Enforced by |
|------|------|-------------|
| Python lint | ruff clean (no errors) | `ruff check genesis` / `genesis_core` (CI python job) |
| Python tests | `pytest` green (incl. `pytest-asyncio`) | CI python job |
| Workflow contract | `workflow.yaml` mirrors `META`; UI-only keys exempt (`YAML_ONLY_KEYS`) | `genesis/lint/contract.py` |
| Reliability trio | every agent node has validator + retry + escalation | `genesis/lint/reliability.py` (CI) |
| Core compat | library `genesis_core_major` == `CORE_MAJOR` | loader `check_compat` (refuses to load on mismatch) |
| TS types | `tsc --noEmit` strict, `noUnusedLocals`/`noUnusedParameters` | `npm run typecheck` (CI frontend) |
| JS/TS lint | eslint flat config (typescript-eslint + react-hooks) clean | `npm run lint` (CI frontend) |
| Web tests | Vitest + RTL + MSW green, incl. contract-fixture drift tests | `npm test` (CI frontend) |
| Accessibility | jest-axe has no violations on rendered screens | Vitest (`toHaveNoViolations`) |
| Committed bundle | `web/static/` equals a fresh `npm run build` | **stale-bundle guard** (CI frontend) |
| Contract fidelity | web types/fixtures match the 07-02 event/gate/topology shapes | `web/src/test/.../contract.test.ts` |

If a change requires relaxing any of these, that's a decision — flag it and get sign-off; don't
disable a lint to make a commit pass.

---

## 2. Python conventions (`genesis`, `genesis-core`, `kiro-agent-sdk`)

- **`from __future__ import annotations`** at the top of every module (already universal).
- **Module docstring states the "why" + the governing ADR/spec** (e.g. `eventlog.py`: "…the DURABLE
  backbone… (07-02 §2)"). Keep this pattern — it's the project's living design memory.
- **Type-hint everything**; use `dataclass` for records (`RunRecord`, `EventRecord`, `ConfigField`,
  `McpCard`) and `TypedDict` for graph state (`PlatformState`). Use `Protocol` for pluggable interfaces
  (`SecretProvider`). Prefer explicit return types.
- **No side effects on import.** `META` is a static dict; `build(ctx)` is the only entry that constructs
  a graph. Workflow `graph.py` is imported standalone — keep it self-contained (no sibling-package imports).
- **Naming:** `snake_case` functions/vars, `PascalCase` classes, `_leading_underscore` for private
  helpers/attrs, `UPPER_SNAKE` module constants (`TERMINAL`, `CORE_MAJOR`, `GLOBAL_KEYS`).
- **Errors:** raise **specific** exceptions (`McpResolutionError`, `RunStateError`, `GateResponseError`,
  `CliError`) — not bare `Exception`. **Fail fast** on unrecoverable config (unresolved required MCP var
  raises *before* spawning Kiro). A broad `except Exception` is allowed **only** for a graceful fallback
  and must be marked `# noqa: BLE001` with a comment saying why (see `agent.py` streaming fallback).
- **Async:** node fns are `async fn(state, config: RunnableConfig)`; the engine is async-first
  (`AsyncSqliteSaver` + `aiosqlite`, ADR-024). Never use the sync `SqliteSaver` under async.
- **Layering (import direction):** `kiro-agent-sdk` ← `genesis-core` ← `genesis`. `genesis-core` must
  import cleanly **without** the SDK present (lazy-bind the SDK, as `agent.py` does). The app process
  **never imports workflow Python** — only the subprocess worker does (ADR-012).
- **Persistence (after spec 01):** raw `import sqlite3` + DDL live **only** in `genesis/db/`; everything
  else goes through the `Database`/repository layer. No hand-written `CREATE TABLE`/`ALTER` elsewhere.
- **Secrets:** values never leave `ConfigService`; log/return **key names only**. Never echo a secret.

---

## 3. Frontend conventions (`genesis/web`, ADR-026/027)

- **Data access is layered — components never call `fetch`.** UI → a TanStack Query **hook** →
  `src/lib/api/*` resource → the typed client (`src/lib/api/client.ts`, which **prepends `/api`** and
  throws `ApiError`). **Never** hard-code a URL or the `/api` prefix in a component (ADR-028).
- **Query keys** come from the `src/lib/query/keys.ts` factory — don't inline key arrays.
- **State boundaries:** server state → TanStack Query (caching/polling/invalidation); ephemeral UI state
  → Zustand (`src/stores/*`) or local `useState`. Don't mirror server data into Zustand.
- **Feature folders:** `src/features/<feature>/` holds that screen's `*.tsx`, `hooks.ts`, pure logic, and
  `*.test.tsx`. Shared primitives live in `src/shared/ui/**`; compose from them — don't re-roll a Button.
- **Pure logic is pure + separately tested.** Event/topology folds (`buildTranscript`, `deriveNodeStates`,
  `groupTurns`) are framework-free functions with unit tests; components render their output. Keep it so.
- **Icons** come from the curated `src/shared/ui/icons.ts` re-export — add there, don't import `lucide-react`
  ad hoc.
- **Types:** model domain data with **discriminated unions** (`TranscriptItem`, `RunEvent`) and mirror the
  backend contract in `src/types/**`; a drift must break a test (§1).
- **Accessibility is a requirement, not a nice-to-have:** label controls, use `aria-*`, keep jest-axe green.
- **Dependencies:** justify new deps; prefer the ADR-027 set. **Keep heavy libs lazy** (mermaid is
  dynamic-imported into its own chunk) — don't bloat the main bundle.
- **After any web change:** `npm run build` and **commit `web/static/`** (CI stale-bundle guard, §1).

---

## 4. Testing conventions

- **Write the test with the change.** New feature → tests; bug fix → a **regression test that would have
  caught it**.
- **Stubs must mirror the real contract.** The costliest bug in this project (ACP env dropped) hid for
  weeks behind a permissive stub. When you stub an external contract, assert its **real shape**; keep the
  golden fixtures (`web/src/test/fixtures`, `contract.test.ts`) faithful.
- **Backend:** pytest + `pytest-asyncio`; run offline (stub the SDK via `set_collect_impl`, use
  `LocalSource`, subprocess-stub MCP introspection). No test should need a live Kiro/MCP/network.
- **Web:** Vitest + RTL + MSW; MSW handlers use **`/api/...`** paths; test behavior, not implementation.
- **Determinism:** no real clocks/network/sleeps in unit tests; inject `now`/fakes.

---

## 5. Cross-cutting

- **Comments explain *why*, not *what*.** Match the existing dense-docstring style that cites the ADR/spec.
- **Small, scoped changes.** Don't refactor unrelated code in a fix. Match the surrounding style.
- **Security:** no secrets in code, state, logs, or commits; reference by key name. Flag any
  network-exposed surface without auth (there is none today — keep it that way unless asked; ADR-026).
- **Commits:** `git -c user.name=Genesis -c user.email=genesis@local commit -m "…"`. Conventional-ish
  prefixes (`feat(web):`, `fix:`, `genesis:`). Never change git config. Don't push to shared repos beyond
  the normal release flow.
- **Releases:** bump version + tag `vX.Y.Z` + push + bump dependent pins; order **core → genesis →
  genesis-workflows**; verify CI green via `glab ci list`.

---

## 6. Definition of Done (every item)
1. Behavior implemented in the smallest correct scope; matches existing patterns.
2. Tests added/updated (incl. a regression test for bugs); **all** affected suites green
   (backend `pytest`+`ruff`; web `lint`+`typecheck`+`vitest`).
3. Web changes: `npm run build` run and `web/static/` committed.
4. Repo(s) released + pinned if code changed; CI verified green.
5. `tracker.md §6` + a `progress/` note updated and project-tracker pushed.
6. Report cites evidence (test output, run ids, diffs) and is **honest about what wasn't verified**
   (live Kiro/MCP/browser can't be driven headlessly — give the manual check).

---

## 7. "When in doubt, match these" (canonical exemplars)
- Backend repository + durable store: `genesis/runs/eventlog.py`, `store.py`.
- Config facade + secret handling: `genesis/config/service.py`, `secrets.py`.
- Agent node + reliability: `genesis-core/nodes/agent.py`, `reliability.py`.
- Frontend data hook + resource: `web/src/features/*/hooks.ts` + `web/src/lib/api/*`.
- Pure fold + its test: `web/src/features/run-detail/{node-states.ts, conversation.ts}` + tests.
- Screen composition: `web/src/features/settings/**` (master-detail), `run-detail/**` (tabs + SplitPane).

---

## 8. Roadmap — promote conventions into enforcement
Prose rots; lints don't. As capacity allows, encode the highest-value §2–§4 rules as automated checks:
- eslint rule (or a tiny CI grep) banning `fetch(` outside `src/lib/api/` and literal `"/api` in components.
- ruff/CI check forbidding `import sqlite3` outside `genesis/db/` (after spec 01).
- a check that every `src/features/*` screen has a `*.test.tsx`.
- keep expanding the golden contract fixtures as the API grows.
Each promotion lets us delete a line from this doc — that's the goal.

---

*Keep this file short and current. If a rule stops being true, fix the code or fix the rule — don't let
them diverge.*
