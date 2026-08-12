# 21-07 — Release, acceptance & bible refresh

> **Status:** 📝 DRAFT · **Phase:** 21 · **Repo:** all touched · **Depends on:** 21-02..21-06

## Goal

Ship Phase 21: run the full gate, release the chain, flip the ADRs, live-accept, and refresh the docs + bible.

## Release chain (order matters — tags must exist before pins)

1. **`kiro-agent-sdk`** (21-04) — bump `[project].version` + tag + push; SDK unit suite green.
2. **`genesis-core`** — bump the SDK pin to the new tag (pin-only change; `CORE_MAJOR` unchanged) + bump + tag + push.
3. **`genesis`** — bump the `genesis-core` **and** `kiro-agent-sdk` pins, bump `[project].version` + `api/app.py` version
   string, rebuild + commit `web/static/`, tag + push. (If `m0011 chat_sessions.model` was added, it ships here.)

## Gate (all green before release)

- Backend: `pytest -q` (genesis + genesis-core) + `ruff` (both, `ruff==0.15.20`).
- SDK: its unit suite.
- Web: `npm run lint && npm run typecheck && npm test && npm run build` (stale-bundle guard).
- CI green on every pushed repo (`glab ci list -R ramaswamy.u/<repo>`) — the tag pipeline, not just master.

## ADRs

- **ADR-044** (feature = artifact-stage workspace) → **Accepted (shipped)**.
- **ADR-045** (chat mirrors the CLI/ACP surface; revises ADR-031) → **Accepted (shipped)** — and add a cross-reference note on
  **ADR-031** that it is refined by ADR-045.

## Live acceptance (browser, user-driven — headless-undrivable parts noted)

- Feature workspace: landing shows the artifact pipeline; Design/Breakdown disabled; Spec card **Edit**→builder, **View**→
  read-only preview; feature card shows no status.
- Builder: full-width chat; **Preview** opens the full-screen doc + comment-queue rail; queue visible; **Send all** reaches the
  agent; no copilot banner; the spec session is **absent** from the main Chat list.
- Chat parity: model chosen at creation; `/` autocomplete; context/compaction meter; clear/compact; image attach; **all in both
  places**. A write-capable command still prompts a confirm card (ADR-045 backstop).
- Export: `.md` transcript downloads (incl. tools + thinking) from both chats.

## Docs + bible refresh (Definition of Done)

- `tracker.md` §3 (phase index) + §6 (status log) — Phase 21 shipped entry.
- `progress/phase-21-feature-workspace-and-chat-parity.md` — as-built.
- `README.md` phase table — Phase 21 row.
- `reference/decision-log.md` — ADR-044/045 accepted; ADR-031 cross-ref.
- **`AGENT_ONBOARDING.md`** — header (Last refreshed + latest tags: new sdk + genesis + core-pin), §2 (tag table + test counts
  + screens: feature workspace + chat parity), §4 (map: `features/features` workspace, chat parity in `chat/` + `Composer`,
  SDK ACP methods, `api/chat` new routes, chat export), §5 (ADR-044/045), §7 (any new lessons — e.g. the ACP-extension quirks
  from 21-01, the `ChatThread` chrome-variant pattern), §9 (Phase-21 SHIPPED block).

## Definition of done

- Chain released, all CI green; ADR-044/045 Accepted; live-acceptance checklist passed (or the headless-undrivable items
  explicitly noted for the user); tracker/progress/README/decision-log/bible updated + project-tracker pushed.
