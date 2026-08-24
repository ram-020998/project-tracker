# Genesis — Agent Onboarding & Reference ("the bible") — INDEX

> **This is the bible index.** The Genesis bible is the single, task-agnostic source of truth that brings any agent
> session fully up to speed on Genesis and defines every practice you must follow. It has been **split into functional
> chunks** under [`bible/`](./bible/) so that agents can find + update the right part without wrestling a 1,300-line file.
> **Splitting changed the packaging, NOT the authority: the bible is still one document — read + obey all of it.**
>
> ## ⛔ MANDATORY — what "read the bible" means
> When the human says **"read the bible"** (or points you at `AGENT_ONBOARDING.md`), you MUST:
> 1. Read **this index**, then
> 2. Read **every chunk listed in the manifest below, in order** — not just the one that looks relevant. The chunks are
>    interdependent (architecture ↔ ADRs ↔ lessons ↔ the loop); skipping any means you will violate a constraint you
>    never read.
> 3. Then **follow all of it religiously** for the rest of the session — the ADRs (§5) and working agreements (§8/§10)
>    are non-negotiable; the lessons (§7) are do-not-regress.
>
> After reading, briefly **restate** the architecture + current state + the non-negotiables, then do the work the human
> gives you following the loop in `bible/07-working-on-tasks-and-agreements.md` (§8). **This document assigns no task.**
>
> **Last refreshed: 2026-08-21 — latest SHIPPED: genesis v0.52.1 + genesis-core v0.9.5 + genesis-workflows v0.10.0 +
> kiro-agent-sdk v0.7.0 + genesis-appian-parser v0.2.0.** (genesis v0.52.0 + genesis-workflows v0.10.0 = the
> **Phase 26 — Agentic Memory Layer** release, 26-01..26-08, ADR-053/054 Accepted, CI green — Phase 26 COMPLETE.)
> **Latest patch: genesis v0.52.1 — the `/memory` graph view redesigned as a dark d3-force "constellation" (UI only, no API/DB change).**
> **Newest SHIPPED: Phase 26 — Agentic Memory Layer — COMPLETE (26-01..26-08): genesis v0.52.0 +
> genesis-workflows v0.10.0, CI green; ADR-053 + ADR-054 Accepted.** A persistent, self-maintaining memory
> distilled from chats: separate `memory.db` (bi-temporal entity-relationship graph + FTS5 + `sqlite-vec`),
> a nightly `memory-consolidation` + weekly `memory-maintenance` workflow, a read-only `genesis-memory` MCP
> (hybrid retrieval, chat-wired), and a browser-only curation API + `/memory` web workspace. See
> `bible/08` §9 + `specs/phase-26-agentic-memory-layer.md` + `progress/phase-26-agentic-memory-layer.md`.
> See `bible/08-roadmap-and-backlog.md` §9 + `specs/phase-26-agentic-memory-layer.md` + `progress/phase-26-agentic-memory-layer.md`.
> (Full phase/release banner + version detail live in
> `bible/00-onboarding-and-overview.md` and `bible/01-current-state.md`.)

---

Onboard to the Genesis project by reading its bible before doing anything else.
  
  1. Read the bible INDEX first:
     /Users/ramaswamy.u/repo/project-tracker/genesis/AGENT_ONBOARDING.md
  
  2. Then read EVERY chunk it lists, in order — do not skip any (they are interdependent):
     - bible/00-onboarding-and-overview.md   (purpose, what Genesis is, read-order)
     - bible/01-current-state.md             (repos/tags, tests, what works)
     - bible/02-architecture.md              (mental model)
     - bible/03-codebase-map.md              (where code lives)
     - bible/04-adrs-and-constraints.md      (ADR-001..054 — non-negotiable)
     - bible/05-dev-loop-and-release.md      (env, tests, release, CI)
     - bible/06-hard-won-lessons.md          (do-not-regress bugs)
     - bible/07-working-on-tasks-and-agreements.md (the work loop + working agreements)
     - bible/08-roadmap-and-backlog.md       (shipped phases + what's next)
  
  3. Then read the supporting docs the bible points to (at least):
     - tracker.md  — read §6 STATUS LOG top-down (the running history / source of truth for "what is done")
     - reference/decision-log.md      (the ADRs — the "why")
     - reference/coding-standards.md  (§1 is the hard floor)
     For the specific area you'll touch, also read the relevant specs/<phase>.md and progress/<phase>.md,
     and the cited source files, BEFORE editing.
  
  4. When done, briefly RESTATE: the layered architecture, the reliability trio, the state/blackboard rule,
     the subprocess-worker model, the SQLite data plane, and the release/versioning protocol — plus the
     current shipped versions.
  
  Then follow the bible religiously for the rest of the session: obey the ADRs (§5) and working agreements
  (§8/§10), respect the hard-won lessons (§7), and use the work loop in §8 (understand → verify against real
  code → smallest correct change → test → run all gates green → release if a repo changed → update the bible
  + tracker + progress → report with cited evidence). Do NOT start backlog or a new phase unless I explicitly
  ask. Ask before any destructive/irreversible action.
  
  Do not write any code or make changes until you have read the above and given me the restatement.
  
  If you want a shorter version for quick use:
  
  Read the Genesis bible before doing anything: start at
  /Users/ramaswamy.u/repo/project-tracker/genesis/AGENT_ONBOARDING.md and read the INDEX plus EVERY chunk in
  bible/ (00–08) in order — don't skip any. Then read tracker.md §6, reference/decision-log.md, and
  reference/coding-standards.md, plus the specs/ + progress/ docs and source files for the area I name.
  Briefly restate the architecture + current state + non-negotiables, then follow the bible religiously
  (ADRs and working agreements are non-negotiable; use the §8 work loop). Don't start backlog/new-phase work
  unless I ask, and ask before destructive actions. No code changes until you've read it and restated.
  
  Both point at the index, which itself enforces the read-all rule — so even the short one will pull the whole bible.

## ▶ ACTIVE — Phase 27 (UI/UX Revamp) — PLANNING (specs authored; research → wireframes → mockups are review-gated)

> **Active phase: Phase 27 — UI/UX Revamp.** A ground-up **light-first, modern, MUI-inspired** look-and-feel + UX
> modernization of the **entire** web app (drop the dark default). **Frontend-only (genesis)** — **no API/DB/behavioural
> change**. **Specs authored 2026-08-21:** umbrella `specs/phase-27-ui-ux-revamp.md` + sub-specs `27-01..27-11` +
> `progress/phase-27-ui-ux-revamp.md` + `bible/08` §9 NEXT block + **ADR-055 (Proposed)**. **Pipeline (review-gated):**
> 27-01 research + functional audit (→ decide **ADR-055**: light-first + MUI adopt-vs-evolve, *with the user*) → 27-02
> UX + lo-fi wireframes → 27-03 hi-fi light-first mockups (**⭐ user-approval gate**) → 27-04 design-system foundation +
> light-first tokens/theme-toggle → 27-05 shell/nav → 27-06 Applications/Features/Spec → 27-07 Runs/Run-detail → 27-08
> Chat/Copilot → 27-09 Documents/Memory (+ reconcile the v0.52.1 constellation to tokens) → 27-10 Catalog/Settings/
> Overview → 27-11 polish/a11y/dark-parity/release (likely v0.53.0). **Do NOT start implementation (27-04+) until the
> 27-03 mockups are approved; do NOT start other new-phase/backlog work unless the human asks.** **27-01 ✅ COMPLETE**
> (2026-08-21 — findings `27-01-findings.md`, **ADR-055 Accepted**: light-first + *evolve* the token/Tailwind primitives
> to a MUI-inspired language, no `@mui/material`, coded mockups in `/dev`). **27-02 DELIVERED — FOR REVIEW** (wireframes
> `27-02-wireframes.md`: revamped IA/nav + top app bar + ⌘K + flows + responsive strategy + lo-fi wireframes for all 16
> surfaces; open decisions **D1** promote Catalog / **D2** Applications KPI strip / **D3** expanded nav). **27-03
> DELIVERED — FOR REVIEW**: coded light-first mockups live at **`/dev/mockups`** (`web/src/dev/mockups/*`, scoped
> `.theme-next` preview so the live default is untouched) + `27-03-design-language.md`; iterated to a **Mira-Pro
> style then the user's brand feedback** (primary **`#C2410C`** orange + secondary **`#57534E`** stone, **Poppins**,
> differentiated elevated side-nav, Home-rooted breadcrumb, more motion). **27-03 ✅ APPROVED (2026-08-21)** — genesis
> mockup commits **pushed to master** (`…16c2b8a`), **no tag** (ships with 27-04). **27-04 ✅ BUILT (unreleased,
> 2026-08-24, genesis `286528c` LOCAL/untagged):** Indigo·Slate promoted to the **global default** — light-first
> `tokens.css` (two `:root` brand knobs = single source; both themes + gradients derive via `color-mix`), Poppins
> self-hosted, default flipped dark→light (no-FOUC), per-theme shadows, motion utils; independent review = SHIP;
> gates green (vitest 191). **Next action = release 27-04 as v0.53.0 on the user's go-ahead** (bump pyproject+FastAPI
> version, tag, push, CI) → then **27-05** (app shell & navigation — first structural UX phase). Known: `/memory`
> constellation still dark → reconciled in 27-09.
>
> **27-05 ✅ BUILT (unreleased, 2026-08-24, genesis `cf8bfb8` LOCAL/untagged):** app shell & navigation — single-source
> `nav.ts` (Catalog promoted), rebuilt differentiated **Sidebar** (expanded+labelled), glassy **TopBar** (route
> breadcrumbs ancestors-only + **⌘K** palette + theme toggle), `breadcrumbs.ts` + **CommandPalette** (Radix Dialog,
> listbox nav) + recomposed `AppShell`. Independent review = SHIP (all fixes applied); gates green (**vitest 200**,
> +9 shell tests). **Next action = 27-06** (Applications / Application detail / Features / Spec builder). Release train
> 27-04+27-05(+…) → **v0.53.0** on go-ahead.
> Grounding: theming is **already token-driven** (`tokens.css` has a full `.theme-light`), so light-first ≈ palette-refine
> + default-flip + toggle + reconcile the one hardcoded-hex file (`memory/MemoryGraph.tsx`) — not a rewrite.
>
> **Prior phase — Phase 26 (Agentic Memory Layer, 26-01..26-08) — SHIPPED** (genesis **v0.52.0** + genesis-workflows
> **v0.10.0**, CI green, ADR-053/054 Accepted, installed; + the **v0.52.1** memory-graph constellation UI patch). If
> asked about it, read `bible/08` §9 + the newest `tracker.md` §6 entries first.
>
> **Phase-26 backlog / deferred follow-ups (NOT started — pick up only if asked):** the 26-05 internal-server
> node-injection seam (let agentic workflow nodes inject `genesis-memory` — needs a genesis-core mechanism, as
> the shared `mcp-registry.json` can't express the venv `command`); the two 26-08 contextual reuses
> (Application-detail "Memory" tab + Settings "Your Memory" panel — thin wiring over the existing components);
> a canvas force-graph lib swap (`react-force-graph`) for very large memory graphs; an OS-user default for
> `memory_owner_username`; and the umbrella §9 non-goals (multi-user ACL, Postgres+pgvector migration,
> auto-prefetch injection, hard-delete/purge) which are seams-built-now.
>
> **Dev/test (bible §6):** venv `genesis/.venv`. `cd genesis && .venv/bin/python -m pytest -q -p no:warnings`
> (**635**) `+ ruff check genesis`; web `cd genesis/web && npx tsc --noEmit && npx eslint . && npx vitest run`
> (**191**) `+ npm run build`; workflows `cd genesis-workflows && ../genesis/.venv/bin/python
> ci/validate_library.py + ... -m pytest -q workflows --ignore=workflows/_fixtures` (**93**).

---

## 📚 The bible manifest (read all, in this order)

| # | Chunk | Original § | What it holds — why you read it |
|---|---|---|---|
| 0 | [`bible/00-onboarding-and-overview.md`](./bible/00-onboarding-and-overview.md) | header + §0 + §1 | Purpose + how to keep the bible current; the phase/release banner; **what Genesis is** (one paragraph); the **onboarding read-order** (which design docs + code to read before touching an area). **Start here.** |
| 1 | [`bible/01-current-state.md`](./bible/01-current-state.md) | §2 | **Current state** — the five-repo tag table, dependency chain, test counts, milestones, and "what works today". *Changes every release.* |
| 2 | [`bible/02-architecture.md`](./bible/02-architecture.md) | §3 | **Architecture / mental model** — layered design (agents never orchestrate), the reliability trio, state/blackboard rule, subprocess-worker execution, the SQLite data plane, HITL modes, release/versioning. |
| 3 | [`bible/03-codebase-map.md`](./bible/03-codebase-map.md) | §4 | **Codebase map** — where every module lives across genesis-core / genesis / genesis-workflows / kiro-agent-sdk / genesis-appian-parser. |
| 4 | [`bible/04-adrs-and-constraints.md`](./bible/04-adrs-and-constraints.md) | §5 | **Non-negotiable constraints** — ADR-001..054 + key implementation contracts. **Do not violate; flag + confirm if a task requires it.** |
| 5 | [`bible/05-dev-loop-and-release.md`](./bible/05-dev-loop-and-release.md) | §6 | **Environment, dev loop, release, CI** — the venv, how to run tests/app, the versioning/tag/push protocol, CI, npm/gitignore gotchas. |
| 6 | [`bible/06-hard-won-lessons.md`](./bible/06-hard-won-lessons.md) | §7 | **Hard-won lessons** — concrete bugs + root causes you must not regress. *Grows often.* |
| 7 | [`bible/07-working-on-tasks-and-agreements.md`](./bible/07-working-on-tasks-and-agreements.md) | §8 + §10 | **The work loop** (understand→verify→scope→test→gates→release→document→report) + the **working agreements** (honest pushback, ask before destructive actions, keep scope tight). |
| 8 | [`bible/08-roadmap-and-backlog.md`](./bible/08-roadmap-and-backlog.md) | §9 | **Roadmap & backlog** — the shipped-phase as-builts (context) + what is next. *Largest; grows every phase.* |

Adjacent authoritative folders (referenced throughout the chunks): [`specs/`](./specs/) (per-phase plans + `specs/backlog/` deferred work + `specs/bugs/` filed defects), [`progress/`](./progress/) (as-built records), [`reference/`](./reference/) (decision-log/ADRs, coding-standards, taxonomies), [`spike/`](./spike/), [`tracker.md`](./tracker.md) (§6 status log = running history).

---

## 🔁 Cross-reference map (§N → chunk)

The chunks preserve the original section numbers, so references inside them like *"see §7"* / *"per §2"* still resolve.
Use this map:

- **§0** What Genesis is → chunk 00 · **§1** How to onboard → chunk 00
- **§2** Current state → chunk 01
- **§3** Architecture → chunk 02
- **§4** Codebase map → chunk 03
- **§5** ADRs / constraints → chunk 04
- **§6** Environment / dev loop / release / CI → chunk 05
- **§7** Hard-won lessons → chunk 06
- **§8** The work loop → chunk 07 · **§10** Working agreements → chunk 07
- **§9** Roadmap & backlog → chunk 08

---

## ✍️ Keeping the bible current (part of Definition of Done)

When tags, architecture, ADRs, or hard-won lessons change, update the **specific chunk** (not a monolith) and this
index's "Last refreshed" stamp. Routing:

- **A release** (new tag / version / test counts / "what works") → `bible/01-current-state.md` (§2) + this index's
  Last-refreshed line + the release banner in `bible/00-onboarding-and-overview.md`.
- **A new/changed ADR** → `bible/04-adrs-and-constraints.md` (§5) — and mirror the decision in `reference/decision-log.md`.
- **A new hard-won lesson** → `bible/06-hard-won-lessons.md` (§7).
- **A new module / moved code** → `bible/03-codebase-map.md` (§4).
- **A roadmap/phase change** → `bible/08-roadmap-and-backlog.md` (§9).
- **A change to the process/loop or working agreements** → `bible/07-working-on-tasks-and-agreements.md` (§8/§10).

Rules for editing a chunk: **keep it verbatim-faithful — never summarize away or drop existing content when adding an
entry** (the intelligence of the bible is the accumulated detail). Append/refine in place. If you add a NEW chunk, add a
row to the manifest above and to the §→chunk map. Then push project-tracker (`git pull --rebase` → push) per §6.
