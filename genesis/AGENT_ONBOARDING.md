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
> **Last refreshed: 2026-09-04 — latest SHIPPED: genesis v0.60.0 + genesis-workflows v0.15.0 — **Phase 32 Finalize Stories COMPLETE** (finalize a completed Feature Breakdown → first-class, editable kb_epics/kb_stories; m0016; ADR-060) + genesis-core v0.9.6 +
> kiro-agent-sdk v0.7.1 + genesis-appian-parser v0.2.0.** (genesis v0.52.0 + genesis-workflows v0.10.0 = the
> **Phase 26 — Agentic Memory Layer** release, 26-01..26-08, ADR-053/054 Accepted, CI green — Phase 26 COMPLETE.)
> **Latest patch: genesis v0.52.1 — the `/memory` graph view redesigned as a dark d3-force "constellation" (UI only, no API/DB change).**
> **⭐ SHIPPED — Phase 27 (UI/UX Revamp) — COMPLETE: genesis v0.53.0** (2026-08-24; release `fba9a94`, tag `v0.53.0`;
> CI green — #6641436 master + #6641437 tag). A light-first, modern (**Indigo·Slate**) re-theme + UX overhaul of the
> entire web app (27-01..27-11 + user refinements: Home dashboard, tables/markdown/chat legibility, sidebar to mockup).
> Frontend-only; web **vitest 204**, genesis pytest **635**. See §9 + `progress/phase-27-ui-ux-revamp.md`.
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

## ⭐ SHIPPED — Phase 30 (Technical Design Stage) — COMPLETE · genesis v0.57.0 + genesis-workflows v0.13.0 (2026-09-03, CI green)

> **Phase 30 made the THIRD feature stage live: Technical Design (ADR-058, Accepted) — and the first stage that
> depends on its predecessors.** Once the **Spec + UX Design** artifacts exist (in-review/completed), the user opens
> the Technical Design card, provides an optional **comment**, and clicks **Start** → a supervised
> **`technical-design-analysis`** run ("Technical Design Preparation"): plan the work into **functional workstreams**
> → per-workstream **existing-state grounding** against the live app (structure via **genesis-kb**, actual code via
> **appian-dev**, read-only) → per-workstream **design drafting** → an **agent assemble** (coherence) → a **grounded
> verify** critic (bounded → escalate) → present. A **`technical_design` completion chat** finalizes it via the same
> annotatable review (only the steering prompt changed). The doc is **object-level + code-grounded** (the inverse of
> ADR-057's intent-level UX doc), organized by workstream for readability; every change names a real object or is
> marked NEW; the agent never assumes — blind spots become Open Questions.
>
> **Amends ADR-056** — a stage MAY declare **prerequisites** (`StageDescriptor.requires`): TD requires Spec + UX,
> enforced UI (locked card) + backend (409). **Reuses the Phase-29 surface wholesale** (m0015 StageStore, the stage
> components, the StageFinalizer — now a **workflow→stage binding registry** serving both workflows); **no migration**,
> **genesis + genesis-workflows only** (no core/SDK). Also folded in **two UX refinements**: the whole **stage card is
> clickable** (no Open button, all stages; locked/not-available cards not navigable) and **artifacts are openable**
> (generated → read-only preview; reference → the Document Library viewer). **Released:** genesis **v0.57.0**
> (`0878b13`) + genesis-workflows **v0.13.0** (`ae1181c`), CI green — genesis **#6725001** / workflows **#6725004**.
> Gates: genesis pytest **665** + ruff; web **vitest 224** + build; workflows **validate_library 11 + pytest 126**.
> Specs: `specs/phase-30-technical-design-stage.md` (+ `30-01..30-07`, `30-01-findings.md`); **ADR-058** (Accepted).
> **Live acceptance** (a real Kiro run → the completion chat) is user-driven / headless-undrivable. **PHASE 30
> COMPLETE — no active phase.**
>
> **▸ Post-ship — genesis v0.58.0 + genesis-workflows v0.14.0 (CI green — genesis #6727262 / workflows #6727270).** From the first real live TD run (`r-4567cd05bcca`): the `assemble` agent turn **timed out** on a ~12-workstream doc → truncated HTML + no metering (the 239-vs-~400 credit gap) → **redesigned** to a bounded `synthesize` agent + a **deterministic program `assemble`** (technical-design-analysis **v0.2.0**) + a `cleanup` node; `worker._snapshot` fix so an **approved escalation finalizes** (was stranded 'running'); run-detail **graph revamp** (elkjs layered LR + orthogonal routing, executed path GREEN + ×N counts, `/runs/{id}/transitions`) + **perf** (per-node events + /steps-driven graph) + honest partial credit provenance + no-cache `index.html`. Gates: genesis pytest **667** + web vitest **224**; workflows validate_library **11** + pytest **133**.

---

## ⭐ SHIPPED — Phase 29 (UX Design Stage) — COMPLETE · genesis v0.55.1 + genesis-workflows v0.12.0 + genesis-core v0.9.6 + kiro-agent-sdk v0.7.1 (2026-08-28, CI green)

> **Phase 29 made the first Phase-28 plug-in stage LIVE: UX Design (ADR-057, Accepted).** A user uploads a
> **mockup PDF** on a feature's UX Design stage → a supervised **`ux-design-analysis`** workflow renders the
> pages (PyMuPDF), runs a **per-screen multimodal** analysis, grounds each screen against the feature's **Spec**
> + the **live Appian env** (**genesis-kb** = structure/impact, **appian-dev** = actual code), and synthesizes a
> grounded, **intent-level** **"UX Implementation Analysis"** HTML doc (per-screen delta + blind-spot/ripple +
> open questions) behind a **grounded verification** critic → a **`StageFinalizer`** (RunManager observer) opens
> a bound **`ux_design`** completion chat + copies `analysis.html` + moves the stage to **in-review** →
> annotatable Lavish review + **Mark complete**.
>
> **Reuses the Spec-page components GENERALIZED (D0)** — `SpecWorkspace`→`StageArtifactWorkspace`,
> `PreviewDialog`→`AnnotatablePreviewDialog`, `SpecBuilderPage`→`StageBuilderPage`, the reused `ChatThread`, and
> stage-scoped hooks — Spec unchanged. Spec **repointed** onto the generalized **m0015** `kb_feature_stages`/
> StageStore (**Decision A**, data-safe: m0015 copies specs + revisions at the offline `genesis db upgrade`,
> preserving `html_path`/`chat_session_id`; `kb_feature_specs` kept as a dead table for rollback). `current_version`
> → **15**. **Enablers:** additive **`images` in `kiro_node`** (→ `client.prompt(images=)`, gated on
> `promptCapabilities.image`) · **PyMuPDF** PDF→PNG (off the event loop) · a `ux_design` chat mode (`_STEERING_UX`) ·
> the generalized `/features/{id}/stages/{stage}` API · the worker resolves the internal **managed `genesis-kb`**
> so workflow nodes can inject it. **Read-only** against Appian (ADR-036/037; read-only allowlists).
>
> **Sub-phases:** 29-01 research → 29-02 mockup (`/dev/ux-design`) → 29-03 locked design (D0–D13) → 29-04 build
> (7 tasks + the StageFinalizer bridge) → 29-05 **independent review = SHIP** (M1 re-upload fix + D2 validator
> hardening) → 29-06 **coordinated release**, then **v0.55.1** patch (two live fixes: the UX builder shows the
> Upload/running entry state until a completion chat is bound; the ADR-035 upload allowlist gains `.pdf` + cap
> 10→25 MB). **Released (ADR-019 order):** kiro-agent-sdk **v0.7.1** → genesis-core **v0.9.6** → genesis **v0.55.1**
> → genesis-workflows **v0.12.0**, CI green (core #6680648 · genesis #6680663 + patch #6681514 · workflows
> #6680673; sdk validated transitively). Pin chain consistent (clean-install + library-validate green).
>
> **Specs:** `specs/phase-29-ux-design-stage.md` + `29-01..29-06`; as-built `progress/phase-29-ux-design-stage.md`;
> **ADR-057** (Accepted). **Live acceptance** (a real mockup PDF → the multimodal run → grounding → completion
> chat) is user-driven / headless-undrivable — the manual check is in the 29-06 spec Notes. **PHASE 29 COMPLETE —
> no active phase.**

---

## ⭐ SHIPPED — Phase 28 (Feature Revamp) — COMPLETE · genesis v0.54.0 + genesis-workflows v0.11.0 (2026-08-25, CI green)

> **Phase 28 = the Feature Workspace framework (ADR-056, supersedes ADR-044's sequential unlock).** A Feature is a
> **parallel, plug-in workspace**: a command-center Overview + peer **stage cards** (Spec live; UX/Technical-Design/
> Breakdown first-class **"arriving in a later phase"**, NOT gated) + a **derived** rolled-up status + a non-gating
> progress indicator; opening a stage routes to its **full-bleed** workspace (`…/features/:id/:stage`; the Spec
> builder gained **Expand→immersive**). A self-describing `StageDescriptor` (`stages.ts`) + a data-only
> `stage-registry.tsx` let a future stage plug in with **no shell edits** (independent review = SHIP). Frontend-only
> (no migration; stages/status derived client-side). Also shipped **genesis-workflows v0.11.0** — 2 new library
> skills (`appian-object-generation`, `sail-mockup-generation`). Releases: genesis `8ab4b41` / **v0.54.0** (CI
> **#6650764** master + **#6650766** tag) + genesis-workflows `db45cb7` / **v0.11.0** (CI **#6650936** + **#6650937**).
> **No active phase** — await direction. See §9 + `progress/phase-28-feature-revamp.md`.

---

## ⭐ SHIPPED — Phase 27 (UI/UX Revamp) — COMPLETE · genesis v0.53.0 (2026-08-24, CI green)

> **Phase 27 = a light-first, modern, MUI-inspired look-and-feel + UX modernization of the ENTIRE web app**
> (frontend-only, **genesis** repo; **NO API/DB/behavioural change** — presentation + IA only). Specs: umbrella
> `specs/phase-27-ui-ux-revamp.md` + `27-01..27-11`; as-built `progress/phase-27-ui-ux-revamp.md`; **ADR-055 Accepted**.
> Everything here **SHIPPED as genesis v0.53.0** (2026-08-24; release `fba9a94`, tag `v0.53.0`; CI green — #6641436
> master + #6641437 tag). **Phase 27 COMPLETE** — frontend-only, other repos unchanged.
>
> **Locked design decisions (ADR-055):** light is the **default** theme (dark retained + toggleable); **evolve** the
> existing Tailwind/token/shadcn primitives to a MUI-inspired language (do **NOT** adopt `@mui/material`); palette =
> **Indigo `#4f46e5` + Slate `#475569`** on cool neutrals; **single-source theming** — two `:root` knobs
> (`--brand` / `--brand-secondary`) in `web/src/styles/tokens.css` drive both themes + all gradients/glows via
> `color-mix` (change once → everywhere; **no hardcoded brand hex** in components); **Poppins** self-hosted
> (`@fontsource/poppins`, latin subset); the coded hi-fi **mockups at `/dev/mockups`** are the reference for every page.
>
> **Done (✅):** 27-01 research/audit · 27-02 wireframes · 27-03 mockups (**APPROVED**; mockup commits pushed to master
> through `16c2b8a`) · **27-04** design-system foundation (global light-first `tokens.css`, Poppins, default flip
> dark→light, per-theme shadows, motion utils) — genesis **`286528c`** · **27-05** app shell & navigation
> (differentiated **Sidebar**, glassy **TopBar** + route **breadcrumbs** + **⌘K CommandPalette**; new
> `shared/layout/{nav,breadcrumbs,command-palette-store,CommandPalette,TopBar}` + recomposed `AppShell`) — genesis
> **`cf8bfb8`** · **27-06** Applications/Features/Spec — the core SDLC surface rebuilt to the mockups (gradient brand
> tiles, rounded-2xl, hover-lift + staggered motion, glassy spec-builder chrome, business-map tokenized) + real
> breadcrumb names via `useSetCrumb(app:<uuid>)` / `useSetCrumb(feature:<id>)` — genesis **`a85dd83`** · **27-07**
> Runs & Run detail (runs table + glassy run header + rounded run-graph nodes + HITL gate card; `useSetCrumb(run:<runId>)`)
> — genesis **`1000af0`** · **27-08** Chat & Copilot (soft-gradient session list, glassy composer, rounded copilot
> cards, gradient empty-state) — genesis **`f541af1`** · **27-09** Documents & Memory — restyled + **tokenized the
> `/memory` d3-force constellation** (the last hardcoded-dark surface → light-first with dark parity; new `--mem-*`
> tokens) — genesis **`9b2e733`** · **27-10** Catalog/Settings/Overview (gradient catalog cards + Overview motion) —
> genesis **`bf41220`** · **27-11** final polish + a11y (memory-graph keyboard nav + jest-axe on every mountable page;
> hex gate CLEAN; dark parity verified) — genesis **`b8defa0`**. All independently reviewed = **SHIP**. **web vitest 204.** Gates green: **web vitest 200**, tsc/eslint/build clean; genesis pytest unaffected
> (web-only).
>
> **✅ RELEASED — genesis v0.53.0 (2026-08-24). Phase 27 COMPLETE.** All 11 sub-phases + the user refinements shipped:
> release commit `fba9a94`, tag `v0.53.0`, pushed to master; **CI green — #6641436 (master) + #6641437 (v0.53.0 tag)**.
> Frontend-only — genesis-core / kiro-agent-sdk / genesis-workflows / genesis-appian-parser unchanged; `pyproject`
> `[project].version` + FastAPI `create_app` + `web/src/version.ts` all at 0.53.0. Gates at release: web **vitest 204**
> (jest-axe) + tsc/eslint/build, genesis pytest **635** + ruff, stale-bundle guard clean. **There is NO active phase —
> do NOT start backlog or a new phase unless the human asks.** Non-blocking follow-ups (polish): optional Home stat-card
> sparklines / recent-activity feed; the now-unused `MetricsSection` component may be deleted if desired.
>
> **Per-sub-phase loop (every time):** verify against real code → smallest correct change to the mockup language →
> `cd genesis/web && npx tsc --noEmit && npx eslint . && npx vitest run && npm run build` → rebuild + **commit
> `web/static`** (stale-bundle guard) → check **both themes** + **jest-axe** on touched pages → **no hardcoded brand
> hex** → keep prop APIs stable (minimize churn) → commit **LOCAL** on genesis master (do **NOT** push/tag a release
> without the user's go-ahead) → update `progress/phase-27-ui-ux-revamp.md` + `tracker.md` §6 + this handoff → get an
> independent review.
>
> **Resolved:** the `/memory` d3 constellation is now token-driven (27-09) — no hardcoded-dark surfaces remain.
> **Deferred:** system banners get deeper polish in **27-11**; memory-graph keyboard-nav is a known a11y follow-up (27-11).
> Remaining phases: **27-10** Catalog/Settings/Overview · **27-11** polish + a11y/responsive + dark-parity + release.
> **Do NOT start other new-phase/backlog work unless the human asks.**

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
> (**200**) `+ npm run build`; workflows `cd genesis-workflows && ../genesis/.venv/bin/python
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
