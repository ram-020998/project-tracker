# Phase 21 — Feature Workspace, Spec-Builder UX & Chat Parity (umbrella)

> **Status:** ✅ **SHIPPED — COMPLETE (21-01..21-07)** — genesis **v0.46.0** + genesis-core **v0.9.3** + kiro-agent-sdk
> **v0.7.0**, CI green; ADR-044/045 Accepted (045 refines ADR-031). · **Author:** Genesis agent · **Date:** 2026-08-12
> **Goal:** Act on the user's live-use feedback after Phase 20 shipped. Three things: **(A)** turn the feature page into a real
> **feature workspace** — a landing of **artifact cards** (Spec functional now; Design/Breakdown as disabled placeholders),
> not an immediate drop into the spec builder; **(B)** overhaul the **spec-builder UX** — a full-width chat with an on-demand
> **full-screen annotatable Preview** (document + our own comment-queue panel + one Send-all button), the spec-builder chat
> **isolated** from the main Chat page, and the copilot banner removed there; and **(C)** bring the reused **chat component to
> parity with the Kiro CLI/ACP surface** — model selection (at creation), slash commands + autocomplete, context-usage &
> compaction indicators, clear/compact, and image attachments — in **both** the main chat and the spec builder. Plus a shared
> **chat transcript export** (PDF + Markdown, server-side, includes tool calls + thinking).
> **Repos:** **genesis** (web + `api` + `chat` wiring + a small `chat_sessions` column) **and `kiro-agent-sdk`** (the ACP
> extensions the parity work needs — `session/set_model`, `_kiro.dev/commands/*`, `_kiro.dev/compaction|clear/status`, image
> prompt capability). genesis-core: a pin bump only. genesis-workflows / genesis-appian-parser: unchanged.
> **Non-negotiable framing:** no new orchestration — chat stays a **conversation** (ADR-001 intact). The parity work
> **revises ADR-031** (Chat is read-only) — see **§8 / ADR-045** and the **decision that needs sign-off in §10** — because
> exposing the full CLI command + model surface changes the read-only posture; write-capable actions stay governed by the
> existing **human-confirmed permission bridge** (Phase 13), not blanket-denied.

---

## 0. TL;DR

Phase 20 shipped Features + a conversational, annotatable Spec, and the user has been using it live. This phase is the
**feedback pass**: make the feature page a proper workspace, make the spec builder chat-first with an on-demand full-screen
review, isolate spec sessions, and close the gap between our hand-built chat and the native Kiro CLI experience.

**A. Feature workspace (items 1–2, 4).**
1. Clicking a feature no longer lands in the spec builder. It lands on a **feature workspace**: a polished **artifact
   pipeline** of cards — **Spec** (functional), **Design** and **Breakdown** (disabled placeholders, clearly "coming soon",
   not stale-looking). Sequential unlock-on-completion is **deferred** until those cards exist.
2. The **Spec card** shows the spec's **own** status and two actions: a **pencil (Edit → the spec builder)** and an **eye
   (Preview → a read-only full-screen view)**. With no spec yet it shows a single **Create spec** action.
3. The **feature card** (on the Features tab) **no longer shows the spec's status** (a spec's status is not the feature's
   status). No feature-level status is shown yet (feature status is a later phase).

**B. Spec-builder UX (items 3–6).**
4. The builder becomes a **full-width chat**. A **Preview** button opens a **full-height, full-width popup** with the rendered
   spec on the left and, on the **right**, **our own comment-queue panel** listing every highlight+comment the user has queued,
   with a single **Send all to agent** button (we stop relying on the vendored SDK's internal button).
5. The spec-builder chat **session is isolated** — `feature_spec` sessions no longer appear in the main **Chat** page list.
6. The **copilot banner / "Enable copilot" toggle is removed in the spec builder only** (it stays in the main chat).

**C. Chat parity + export (items 7–8).**
7. **Chat transcript export** (server-side) as **PDF and Markdown**, including **tool calls + thinking**, in **both** the main
   chat and the spec builder.
8. **Kiro CLI/ACP parity** in the shared chat: **model selection at creation**, **slash commands with autocomplete**
   (`/context`, `/compact`, `/clear`, `/model`, `/tools`, `/usage`, …), a **context-usage + compaction** indicator, a
   **clear/compact** control, and **image attachments** — all wired through new **`kiro-agent-sdk`** ACP methods.

No new LangGraph workflow (ADR-001). One new small migration at most (`chat_sessions.model` to remember the per-session
model). The parity work is the load-bearing part and starts with a **spike** against the installed kiro-cli.

---

## 1. Motivation & user feedback (verbatim intent)

After Phase 20 shipped and was live-accepted, the user reported (paraphrased from the session):

- *"In the feature I can see the status as 'completed' — but that's the **spec's** status, not the feature's. Don't show the
  spec status on the feature card."*
- *"Clicking a feature drops me straight into the spec builder. Instead I should land on a page with **cards** — Spec, Design,
  Breakdown — each with its status; the rest disabled until earlier ones are done (that gating can come later). The **Spec**
  card should have a **pencil to edit** (→ the builder) and an **eye to view** (→ preview the generated doc)."*
- *"In the builder I don't want the doc pinned on the right. Give the **chat the full space**, and a **Preview** button that
  opens the document in a **popup** where I can highlight + comment."*
- *"When I highlight and comment I **can't see the queue** of comments I've added, and there's **no button to send them all** to
  the agent."*
- *"Remove the **enable-copilot banner** in the spec builder."*
- *"The **spec-builder sessions show up in the main Chat page** — they shouldn't; only normal chats there."*
- *"Add **export the whole chat as PDF or MD** — in both the main chat and the spec builder."*
- *"The native Kiro CLI has model switching, slash commands, context views, etc. We rebuilt the chat and lost all that —
  **implement as much of the ACP surface as possible** in both places."* (Reference: <https://kiro.dev/docs/cli/acp/>.)
- *"Make the feature-card / spec-card **UI/UX genuinely good and standard — no stale-looking cards.**"*

---

## 2. Background — what we build on (all reuse)

- **Feature page + spec workspace (Phase 20).** `web/features/features/{FeaturePage,FeaturesTab,SpecWorkspace,status,hooks}`,
  `api/features.py`, `FeatureStore`, `m0010`. Today `FeaturePage` is binary (Create-spec empty state **or** `SpecWorkspace`);
  `SpecWorkspace` is a fixed 2-column grid (chat | annotatable iframe); `FeatureCard` renders `feature.spec_status`.
- **Reused chat (`ChatThread` + `Composer` + `chat/hooks`).** In-process `ChatManager` over ACP; `ChatThread` renders the mode
  banner unconditionally and is shared by the main Chat page and the spec builder (via `registerSend`). `chat/store.py`
  `ChatSessionRecord.mode ∈ {read_only, copilot, feature_spec}`; `ChatStore.list()` returns **all** modes (root cause of the
  spec-session leak). Slash launch (`/`) + skills palette already exist in `Composer` (copilot).
- **Annotation bridge (Phase 20-05).** `SpecWorkspace` listens for `lavish:queuePrompt` (pushes into an invisible ref) and
  `lavish:sendQueuedPrompts` (emitted by the **SDK's own in-iframe button**) → composes one chat turn. Item 4 replaces the
  invisible ref + SDK button with **our** visible queue + send control.
- **`kiro-agent-sdk`.** Implements `collect`/`collect_streaming`, `permission_mode` (`auto_approve`/`auto_deny`/`ask`) +
  `on_permission`, `allow_fs_write` + `fs_write_root`, per-turn credit metering, `KiroAgentOptions.model`. It does **not** yet
  implement `session/set_model`, the `_kiro.dev/commands/*` slash-command extensions, `_kiro.dev/compaction|clear/status`, or
  image prompt content — those are new in this phase (confirmed by search: no such methods in the SDK today).
- **Permission bridge (Phase 13, ADR-033).** `permission_mode="ask"` + `on_permission` → in-chat confirm cards. This is the
  mechanism that keeps write-capable actions **human-confirmed** when we broaden the chat surface (ADR-045).
- **Export/render primitives.** `markdownify` (HTML→MD, Phase 20), the run-detail `buildTranscript`/`Conversation` folds, and
  `DocumentPreview`/`MarkdownView` renderers. PDF is new (a server-side renderer dependency — §6).
- **Design system (ADR-027, "Overcut").** `Card`/`CardBody`, `Badge` (tones), `MetricCard`, `Tabs`, `EmptyState`, `Dialog`,
  tokens (`surface-1/2/3`, `fg/fg-muted/fg-subtle`, `border`/`border-strong`, `primary`, `focus`). The UX (§9) is built
  **only** from these — no new palette, no new heavy deps.

---

## 3. The three themes → sub-phases

| Theme | Item(s) | Sub-phase(s) |
|---|---|---|
| **A. Feature workspace** | 1, 2, 3 (feedback) | **21-02** feature workspace landing + artifact cards + read-only preview |
| **B. Spec-builder UX** | 3, 4, 5, 6 | **21-03** builder re-layout + our comment queue + session isolation + banner removal |
| **C. Chat parity + export** | 7, 8, 9, 10, 11 | **21-01** ACP parity spike · **21-04** SDK ACP extensions · **21-05** chat parity backend+UI · **21-06** chat transcript export |
| **Release** | — | **21-07** release + acceptance + bible refresh |

---

## 4. Data model

Phase 21 is **mostly additive UI + SDK**, so it needs **little or no schema**:
- **No new tables.** Features/specs/revisions from `m0010` are sufficient; the artifact "cards" (Design/Breakdown) are
  **placeholders only** and carry no data yet.
- **Possibly one column — `chat_sessions.model` (candidate `m0011`)** to remember the model chosen at session creation (so a
  reloaded session shows/uses the same model). If the ACP `session/set_model`-at-creation is captured purely at spawn time and
  never needs to be re-read, this can be skipped; decided in **21-05**.
- **Feature-level status is deferred** (a later phase) — this phase deliberately shows **no** status on the feature card.

---

## 5. Sub-phases (all in `phase-21-feature-workspace-and-chat-parity/`)

| # | Spec | What | Repo |
|---|---|---|---|
| **21-01** | `21-01-acp-parity-spike.md` | **Load-bearing spike** — against the installed `kiro-cli acp`, confirm we can drive `session/set_model` (and read available models), `_kiro.dev/commands/available` (list after `session/new`), `_kiro.dev/commands/options` (autocomplete), `_kiro.dev/commands/execute` (run a `/command`), and observe `_kiro.dev/compaction|clear/status` + image prompt content. Throwaway harness; findings under `spike/`. Decides the SDK surface for 21-04. | genesis (spike) |
| **21-02** | `21-02-feature-workspace-landing.md` | The **feature workspace**: `FeaturePage` becomes an **artifact pipeline** (Spec card functional + Design/Breakdown disabled placeholders); **Spec card** = status pill + **Edit (pencil → builder)** + **Preview (eye → read-only full-screen view)**, or **Create spec** when none; **feature card drops spec status**. New builder route split. **ADR-044.** | genesis |
| **21-03** | `21-03-spec-builder-ux-and-isolation.md` | Builder → **full-width chat**; **Preview** opens a **full-screen popup** (document + right-hand **comment-queue panel** owning `lavish:queuePrompt` + one **Send-all** button); **remove the copilot banner** in the builder (a `ChatThread` variant); **isolate `feature_spec` sessions** from the main Chat list (backend list filter). | genesis |
| **21-04** | `21-04-sdk-acp-extensions.md` | **`kiro-agent-sdk`**: implement `session/set_model` (+ advertise/read available models), `_kiro.dev/commands/{available,options,execute}`, `_kiro.dev/{compaction,clear}/status` notifications, and image prompt content, exposed on the client API the ChatManager uses. New SDK release. | kiro-agent-sdk |
| **21-05** | `21-05-chat-parity.md` | **Chat parity UI + backend** (both places): **model select at creation**, **slash-command palette + autocomplete** (execute/options/available), **context-usage + compaction indicator**, **clear/compact** control, **image attachments**. `ChatManager`/`api/chat.py` wiring + `Composer`/`ChatThread`. **ADR-045** (revises ADR-031). | genesis (+ genesis-core pin) |
| **21-06** | `21-06-chat-transcript-export.md` | **Export the full chat** as **Markdown** (server-side, includes tool calls + thinking; **PDF optional via browser print-to-PDF, no native dep**), in the main chat and the builder. New `GET /api/chat/sessions/{id}/export.md` + a small export button in the chat chrome. | genesis |
| **21-07** | `21-07-release-and-acceptance.md` | Release chain (`kiro-agent-sdk` → genesis-core pin → genesis; tags; CI green), **ADR-044/045 → Accepted**, live acceptance, docs + **bible** refresh. | all |

**Suggested build order:** 21-01 (spike) → 21-02 → 21-03 → 21-04 → 21-05 → 21-06 → 21-07. Themes A and B (21-02/21-03) are
independent of theme C and can proceed in parallel with the spike/SDK work. **Release chain:** `kiro-agent-sdk` (new ACP
methods) → genesis-core (SDK pin bump only) → **genesis** (everything else, with the rebuilt/committed `web/static/`).

---

## 6. Cross-cutting concerns

- **Read-only posture changes (ADR-031 → ADR-045).** Exposing the full slash-command + model surface means the chat is no
  longer categorically read-only. **Decision required (§10).** Proposed stance: keep the **default** trust set read-only, keep
  **`permission_mode="ask"`** so any write-capable tool a command triggers still raises a **human-confirmed** card (Phase-13
  bridge) rather than being silently allowed or blanket-denied; document which commands are inherently safe (introspection:
  `/context`, `/usage`, `/tools`, `/help`) vs. state-changing (`/clear`, `/compact`, `/model`, `/agent`). Local single-user
  (ADR-026) bounds the blast radius, but this is a conscious relaxation and must be an ADR.
- **Export is MD-first (no native dep).** Markdown export reuses the existing transcript fold + `markdownify`; it includes tool
  calls + thinking. **PDF is optional** and, if shipped, is **browser print-to-PDF** driven by a print stylesheet — **no
  server-side/Python PDF library** is added.
- **Model list provenance.** Model-at-creation requires the installed kiro-cli to advertise models over ACP (verified in the
  21-01 spike). If it doesn't, fall back to a configured list in Settings. No mid-conversation switch in v1 (deferred).
- **Shared `ChatThread` variants.** The same component serves the main chat, the copilot chat, and the spec builder. Introduce
  an explicit **variant/config** (e.g. `chrome: "full" | "spec"`) so the builder hides the mode banner + supervised-runs strip
  and shows a **Preview** action, without forking the component.
- **Annotation queue ownership.** Our host must intercept every `lavish:queuePrompt`, render it in the right-hand panel
  (with per-item remove), and drive send from **our** button — we no longer depend on the SDK's internal "send" button firing
  `lavish:sendQueuedPrompts`. Keep the golden postMessage-schema fixture (ADR-043 lesson) so an upstream bump can't break it.
- **Reuse over rebuild.** Everything here layers on existing chat/feature/preview/permission machinery; the only genuinely new
  capability is the SDK's ACP-extension methods (21-04) and the PDF renderer (21-06).
- **Frontend cutover rule.** After any `web/src` change, `npm run build` + commit `web/static/` (stale-bundle guard).

---

## 7. Deferred / out of scope (this phase)

- **Sequential card unlocking** (a later card enables when the previous completes) — deferred until Design/Breakdown exist.
- **Design docs, breakdown, and other artifacts** — placeholders only; their authoring is later phases.
- **Feature-level status** (marking a whole feature complete) — later phase; no feature status shown now.
- **Mid-conversation model switching** (`session/set_model` on a live client) — v1 is model-at-creation only.
- **Multiple specs per feature / spec templates** — unchanged from Phase 20 (one spec per feature).
- **Sharing/publishing** the spec HTML externally — still out (local-first, ADR-026/043).

---

## 8. ADRs introduced

- **ADR-044 — A Feature is a workspace of sequential artifact stages.** A feature page is a **pipeline of artifact cards**
  (Spec → Design → Breakdown → …), each artifact carrying **its own** status; the **feature** has no derived status from any
  single artifact (feature-level status is a separate later concept). Artifacts open in two modes: **Edit** (author — e.g. the
  spec builder) and **View** (read-only preview). Sequential unlock-on-completion is part of the model but **deferred** to when
  ≥2 artifacts exist. Proposed → Accepted at 21-07.
- **ADR-045 — The reused chat mirrors the Kiro CLI/ACP surface; revises ADR-031.** Genesis adopts the ACP extension methods
  (`session/set_model`, `_kiro.dev/commands/{available,options,execute}`, `_kiro.dev/{compaction,clear}/status`, image prompts)
  so the in-app chat offers the CLI's model selection, slash commands, context/compaction views, and attachments. This
  **relaxes ADR-031's "Chat is read-only"**: the chat surface is no longer categorically read-only, but **write-capable actions
  remain human-confirmed** via the existing `permission_mode="ask"` bridge (ADR-033) rather than blanket-denied; safe
  introspection commands run freely. Bounded by local single-user (ADR-026). Applies to both the main chat and the spec
  builder. Proposed → Accepted at 21-07. **(Needs the user's explicit sign-off — §10.)**

---

## 9. UX design direction (the "standard, good-looking" ask)

Grounded entirely in the existing Overcut design system (Card/CardBody, Badge tones, tokens) so it feels native, not bolted-on.

### 9.1 Feature workspace — the artifact pipeline

Landing on a feature shows the feature header (name + description + "Back to application", reusing `Page`), then an **artifact
pipeline** — a responsive row/grid of cards read left-to-right as stages, with a subtle connector so they read as a *sequence*,
not a scatter of disconnected tiles:

```
  ┌───────────────────┐        ┌───────────────────┐        ┌───────────────────┐
  │ ①  Spec           │        │ ②  Design         │        │ ③  Breakdown      │
  │    ● In progress  │  ─ ─▶  │    Coming soon 🔒 │  ─ ─▶  │    Coming soon 🔒 │
  │  A structured,    │        │  Technical design │        │  Work breakdown & │
  │  reviewable spec  │        │  for this feature │        │  task estimates   │
  │                   │        │  (disabled)       │        │  (disabled)       │
  │  [✎ Edit] [👁 View]│        │                   │        │                   │
  └───────────────────┘        └───────────────────┘        └───────────────────┘
```

- **Active (Spec) card:** full `surface-1` card, leading **step index** (①) + artifact **icon**, a **status pill** top-right
  (`specStatusTone`), a one-line description, and a footer **action row**: **Edit** (pencil, primary/outline → the builder) and
  **View** (eye, ghost → the read-only preview). Hover raises `border-strong`; keyboard-focusable.
- **No-spec state:** the Spec card collapses its actions to a single **Create spec** button (primary), keeping the same card
  frame (so the layout never shifts).
- **Placeholder (Design/Breakdown) cards:** deliberately *designed* disabled state — muted `surface`/`text-fg-subtle`, a
  **dashed** border, a small **lock** glyph + a neutral **"Coming soon"** chip, non-interactive (`aria-disabled`). Distinct
  from the active card but intentional and tidy — **not** a greyed-out clone. The step index (②③) communicates order.
- The connector between cards is a subtle `border`-toned line/chevron; on small screens the row stacks vertically with the
  connector rotated — still reads as a pipeline.
- Rationale: a numbered, connected pipeline of purpose-built cards conveys "these are the stages of building this feature,"
  makes the disabled ones obviously *future* rather than *broken*, and reuses only existing primitives.

### 9.2 Spec card actions → routes/surfaces

- **Edit (pencil)** → navigates to the **spec builder** (`/applications/:uuid/features/:featureId/spec`).
- **View (eye)** → opens a **read-only full-screen preview** of `spec.html` (the artifact route in a non-annotatable mode) — a
  dialog/overlay with a close affordance; no comment tools (annotation belongs to the builder's Preview).

### 9.3 Spec builder — chat-first + on-demand full-screen review

- The builder is a **full-width chat** (the `ChatThread`, `chrome: "spec"` — no mode banner, no supervised strip) with a top
  action bar carrying **Add context**, the **status** control, **Save milestone**, **Export**, and a prominent **Preview**
  button.
- **Preview** opens a **full-height, full-width popup** (an overlay `Dialog`, ~`inset-4`, rounded, with a header + close):
  - **Left (major):** the annotatable spec `<iframe>` (the existing sandboxed Lavish surface) — the document is large and
    clearly readable.
  - **Right (rail):** **our** comment-queue panel — a scrollable list of queued highlights (each: the quoted anchor text +
    the user's comment + a remove ✕), a count, and a single **Send all to agent** button (disabled when empty). Closing the
    popup keeps the queue intact.
- Sending composes one chat message from the queue (the existing `composeFeedback`) via the thread's `send`, the popup can
  close, and the iframe live-reloads on the agent's next revision (existing behavior).

### 9.4 Chat parity chrome (both places)

- **Composer** gains: a **model** selector (at creation / new-chat), an enriched **`/` palette** driven by
  `_kiro.dev/commands/available` + `_kiro.dev/commands/options` (autocomplete as the user types a command), an **attach image**
  control (`promptCapabilities.image`), and a **context-usage meter** (a slim bar using the `contextUsagePercentage` we already
  receive) with a **compaction** status hint and a **Clear/Compact** action. All rendered with existing primitives; the spec
  builder gets the same Composer, minus the copilot-only workflow launcher.

---

## 10. Decisions — RESOLVED (2026-08-12, user sign-off)

1. **ADR-045 / ADR-031 relaxation — APPROVED.** Full CLI command + model surface exposed in both chats; **safe introspection
   commands run freely**; **write-capable actions stay human-confirmed** via the Phase-13 permission bridge (not blanket-denied).
2. **Model list source — APPROVED.** Source the model list from the installed kiro-cli's ACP advertisement (21-01 spike), with a
   Settings-configured fallback if it doesn't advertise one. Model chosen **at creation** only (mid-conversation switch deferred).
3. **Export — MD-first.** Ship **Markdown export** (server-side, trivial — reuses the transcript fold; includes tool calls +
   thinking). **PDF is optional / stretch** and, if done, via **browser print-to-PDF** (a print stylesheet) — **no native/Python
   PDF dependency**. This drops the §6 PDF-renderer concern entirely.

**Status: approved to author sub-specs + build.**
