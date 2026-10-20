<!-- archived verbatim by Phase 47-10 (2026-10-20) from AGENT_ONBOARDING.md; never mandatory reading -->

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
> **Last refreshed: 2026-10-15 (✅ LATEST SHIPPED **Phase 46 Spec Change Requests & Story Traceability — genesis v0.77.0 → genesis-workflows v0.22.0 + the Genesis Hub contract addition (2026-10-15; ADR-075/076 Accepted; CI green — genesis #7087827 + #7087831, genesis-workflows #7087975 + #7087976; m0024, DB→v24)** — program-maintained spec clause IDs, story↔spec links captured at breakdown, per-clause coverage, and numbered chat-driven change requests (Initiate → Analyze impact → Apply changes | Discard) with story answers, change history, spec-changed badges and Hub sync; live-accepted on merge-assist-dev (46-10 steps 1–12) — `progress/phase-46-spec-change-requests.md`) — Prior: **Phase 45 Incremental Delta Sync — genesis-appian-parser v0.3.0 → genesis v0.76.0 → genesis-workflows v0.21.0 (2026-10-13; ADR-073/074 Accepted; CI green — parser #7059369, genesis #7059384 (master) + #7059385 (v0.76.0 tag: genesis + frontend + clean-install), genesis-workflows #7059427 + #7059428 (v0.21.0); m0023, DB→v23)** — package-scoped incremental KB sync via Dev MCP 26.6.110 (`listObjects` + temporary, always-deleted `genesis-delta-*` packages), KB-aware incremental parse + never-removing merge, automatic full-sync fallbacks, a configurable global schedule in Settings → General (designated machine when collaborating), and a KB snapshot published to the Hub after every sync with teammate auto-pull; live-accepted on merge-assist-dev — `progress/phase-45-incremental-delta-sync.md`) — Prior: **genesis v0.75.0 — Phase 44 Workbench, SDLC & Workspace Fixes (2026-09-25; ADR-072 Accepted; CI green; genesis-only; m0022, DB→v22)** (a 12-issue bug bundle: the Workbench finalizers publish system lane moves to the Hub [fixes design→design-review not sticking + propagation]; real-time live streaming in the run node View-Details; runs server-side pagination; global GNS_ story ids; chat + catalog internal-component filters; + UI-layout fixes — `progress/phase-44-fixes-bundle.md`) — Prior: **genesis v0.74.0 — Phase 43 The Unified Story Workspace (2026-09-24; ADR-071 Accepted; CI green; genesis-only, no migration)** (ONE canonical, consolidated story view from anywhere — Overview / Design [read-only + Edit-chat in a new tab] / Implementation [master-detail doc viewer]; origin-aware breadcrumb; `progress/phase-43-unified-story-workspace.md`) — Prior: **genesis v0.73.0 + genesis-workflows v0.20.0 + genesis-core v0.9.8 — Phase 42 Code Implementation (2026-09-24; ADR-068/069/070 Accepted; CI green)** (Genesis's first write-capable stage: drag a story into the Workbench **Implementation** lane → an unattended `story-implementation` workflow reverifies the design vs the Technical Design → prepares a local rollback doc → a single agent implements the object changes in the dev env via Dev-MCP **write** tools [no deletes — deprecate-in-description] → verify → heal → updates the shared **Object Wiki** → moves the card to Code Review; ADR-068/069/070; m0021; `specs/phase-42-code-implementation.md`)** — **Phase 41: Dev MCP 26.6.90 upgrade (basic auth) + SAIL CLI install** [v0.72.2 CLI `install-native` parity; **v0.72.3** managed-CLI cards resolve via the installer (sail/gws now show **reachable** in Settings → CLI, not a PATH probe) + the fleet provisioner shares `cli-tools`; **deployed + live-verified** against merge-assist-dev — listApplications OK via basic auth on the host + the running fleet; sail/gws reachable on both fleet instances] — pin `LCP_AUTH_METHOD=basic`, drop the obsolete `LCP_API_PATH` (removed end-to-end), +5 read tools; install the bundled **SAIL CLI** in ONE action as a managed CLI wired to the dev-env basic creds + isolated `SAIL_HOME` (no consumer yet); browser/SSO auth deferred → `specs/backlog/devmcp-browser-sso-auth.md`. See `progress/phase-41-devmcp-upgrade-and-sail-cli.md`. Prior: **genesis v0.71.0** — a Workbench board→application-page link (the app name in a board header opens `/applications/:uuid` in a new tab; frontend-only). Prior: **genesis v0.70.0** — **Phase 39 Run Inspection & Node Observability** [ADR-066] + **Phase 40 Self-Healing Reliability** [ADR-067]; genesis-core v0.9.7 · genesis-workflows v0.17.0; both ADRs Accepted; see `progress/phase-39-run-inspection-observability.md` + `progress/phase-40-self-healing-reliability.md`.) — latest SHIPPED: **genesis v0.67.0 — ✅ Two-toggle collaboration enablement (ADR-065) + the collaboration puller-fidelity fixes: a Settings-level enable switch gated on Genesis Hub availability, on top of the env master; Hub URL auto-derived from the dev env (`/suite/webapi`) + a one-time Hub-app-UUID field; plus the v0.66.2–v0.66.5 fixes that make a PULLER see everything — the `stage_artifact` contract mapping, the pull mirror filling local NOT-NULL cols + deriving `stories_finalized_at` (the Hub drops both), and a read-only view of pulled stage artifacts (no Hub change needed); plus **auto-pull** (v0.67.0) so a puller reflects teammate changes automatically — app load / route change / refocus + a board-aware poll [**10s on a board**, 30s idle] that pulls when the Hub change cursor advances; reload always re-pulls. **v0.68.0**: a **backend** always-on auto-pull loop (browser-independent — fixes background-tab timer throttling) + a sticky Workbench board header; measured Hub read-back ~0.9s, no Appian lag. **v0.69.0** — Workbench board fixes: finalized stories default to **to-do** (entry lane, not 'design'); board membership is **explicit** (a shared `kb_stories.on_board` flag set on Import, m0020 — no longer auto-adding every finalized story); a drag-vs-refetch guard; + sticky/shared-scroll board. **v0.68.1**: sticky/shared-scroll Workbench board + a UX-analysis spec-load fix (snapshot the current spec HTML, not the null html_path).** Prior: **genesis v0.65.0 — ✅ Phase 38 Collaborative SDLC COMPLETE** (the local-first → shared-Hub collaboration program is DELIVERED for the human-authored SDLC: per-entity publish/pull for **features + published stage artifacts** [publish-on-complete, artifact-only — chat/run stay local; pull = a read-only mirror on the puller's disk; cross-machine parent resolution], **epics/stories** [Finalize/edit/delete; lists lossless via GH Story Item; tombstone deletes], and **boards** [lane=shared story status; auto membership; in-lane order + sidebar curation stay local], the **collaboration UX** [`<PublishToTeamButton>` publish-on-complete + Sync-now/auto-pull + advisory markers, reusing the Phase-37 components], and a one-time confirmed **adoption** bulk-publish; **opt-in / off by default** — solo installs unchanged; genesis-only, no migration; `scripts/acceptance/phase-38-collaborative-sdlc-acceptance.py`. Shared-memory sync is the one deferred future phase). Prior: **genesis v0.64.0 — ✅ Phase 37 Hub Wire-up COMPLETE** (the collaboration mechanism LIVE against the real Appian Hub for the KB + identity/teams: `AppianHubProvider` [the frozen Phase-36 contract] + `KbStore.hydrate_from_blob` pull-first KB sharing + `publish_kb`/`pull_kb_if_newer` [content-hash dedup, per-app lock, Hub-app exclusion] + live identity/teams + an onboarding-before-first-publish gate + the sync-UX foundation [`/collab/status`+`/changes`, `<HubStatus>`/`<StalenessBadge>`]; implements ADR-063/064; genesis-only, no migration). Prior: genesis v0.63.0 — **Phase 35 Collaboration Foundations & Identity COMPLETE** (the local-first → shared-Hub substrate, **opt-in/off-by-default** — a solo install is unchanged: **m0019** `sync_uuid`/`row_version` backfill + owner/team/provenance + `collab_*` tables [`current_version` 18→19]; **`genesis/collab/`** — the pluggable `SyncProvider` seam + file-backed `LocalHubProvider` + `CollaborationService` [publish/pull + provenance + a no-leak payload] + `build_sync_provider()` opt-in registry; **self-asserted identity** + `canonical_username()` threaded into `LifecycleService.transition(actor=)`; a **Settings→Collaboration** page + first-run onboarding; ADR-063 **Accepted**). ✅ **Phase 36 — the Genesis Hub Appian application — COMPLETE** (ADR-064 Accepted; built + **live-validated** in the team dev env by a separate write-capable Dev-MCP agent — genesis stays read-only per ADR-036/037). The isolated `Genesis Hub` app + 11 UUID-keyed record types + 13 relationships + record-level security + 9 constants + the base64 blob store + **11 Web APIs + 12 helper expression rules**, plus a **frozen JSON contract + fixtures** checked into genesis (`specs/phase-36-genesis-hub-appian-app/contract/`). Every endpoint validated end-to-end against the live dev env with the service-account key. **See `progress/phase-36-genesis-hub-appian-app.md`.** Then 37 Hub wire-up + 38 Collaborative SDLC (see §9). Prior: genesis v0.62.0 + genesis-workflows v0.16.0 — **Phase 34 Design Lane Automation COMPLETE** (the first Workbench per-lane automation — drag a ticket into **Design** → a grounded `story-design-analysis` run writes an object-level, code-level design → the card auto-advances to **Design Review** for a chat + annotatable review; m0018; ADR-062; removed the superseded `design-doc`). Prior: **Phase 33 The Workbench COMPLETE** (a per-application Kanban board over finalized stories — curated boards as left-sidebar sub-tabs, batched import → To Do, drag across 8 lanes + intra-lane reorder; m0017; ADR-061). Prior: **Phase 32 Finalize Stories** (m0016; ADR-060) + genesis-core v0.9.6 +
> kiro-agent-sdk v0.7.1 + genesis-appian-parser v0.2.0 (then; parser v0.3.0 since Phase 45).** (genesis v0.52.0 + genesis-workflows v0.10.0 = the
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
     - bible/04-adrs-and-constraints.md      (ADR-001..074 — non-negotiable)
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

> 📦 Moved verbatim to [archive/onboarding-banners.md](archive/onboarding-banners.md) (Phase 47-04, 2026-10-20). Search with `genesis-ctx search <term> --archive`.

## 📚 The bible manifest (read all, in this order)

| # | Chunk | Original § | What it holds — why you read it |
|---|---|---|---|
| 0 | [`bible/00-onboarding-and-overview.md`](./bible/00-onboarding-and-overview.md) | header + §0 + §1 | Purpose + how to keep the bible current; the phase/release banner; **what Genesis is** (one paragraph); the **onboarding read-order** (which design docs + code to read before touching an area). **Start here.** |
| 1 | [`bible/01-current-state.md`](./bible/01-current-state.md) | §2 | **Current state** — the five-repo tag table, dependency chain, test counts, milestones, and "what works today". *Changes every release.* |
| 2 | [`bible/02-architecture.md`](./bible/02-architecture.md) | §3 | **Architecture / mental model** — layered design (agents never orchestrate), the reliability trio, state/blackboard rule, subprocess-worker execution, the SQLite data plane, HITL modes, release/versioning. |
| 3 | [`bible/03-codebase-map.md`](./bible/03-codebase-map.md) | §4 | **Codebase map** — where every module lives across genesis-core / genesis / genesis-workflows / kiro-agent-sdk / genesis-appian-parser. |
| 4 | [`bible/04-adrs-and-constraints.md`](./bible/04-adrs-and-constraints.md) | §5 | **Non-negotiable constraints** — ADR-001..074 + key implementation contracts. **Do not violate; flag + confirm if a task requires it.** |
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
