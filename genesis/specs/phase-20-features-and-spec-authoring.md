# Phase 20 — Features & Spec Authoring (umbrella)

> **Status:** ✅ **SHIPPED — COMPLETE (20-01..20-06)** — genesis **v0.45.0**, CI green; ADR-042/043 Accepted. · **Author:**
> Genesis agent · **Date:** 2026-08-11
> **Goal:** Give an Appian application a first-class notion of a **Feature** (the unit of work an engineer develops), and make
> the **feature page** the workspace where a feature's artifacts are authored. This phase delivers the **first** such artifact:
> a **Spec**, authored **conversationally** with a Kiro agent that already knows the application (via the `genesis-kb` MCP)
> and can be handed the application's **business artifacts** (Phase-19 linked documents) as context. The spec is authored as
> an **HTML artifact** (the authoritative form while editing) rendered in an **embedded, annotatable review surface** — the
> user highlights text/elements and comments, and those annotations flow straight into the chat for the agent to address. The
> spec carries a lifecycle status (**draft → in-progress → in-review → completed**), is snapshotted at **milestones**, and can
> be **exported to Markdown at any time**.
> **Repos:** almost entirely **genesis** (migration **m0010** `kb_features`/`kb_feature_specs`/`kb_feature_spec_revisions`, a
> `FeatureStore`, `api/features.py`, a Chat extension for spec sessions, and the web **Features** surface + **feature page** +
> the **embedded review surface** with a vendored, MIT Lavish annotation SDK). **genesis-core / genesis-workflows /
> kiro-agent-sdk / genesis-appian-parser: unchanged** (no new engine capability, no new workflow — spec authoring is a Chat,
> not a LangGraph workflow, so ADR-001 is preserved).
> **Non-negotiable framing:** spec authoring is a **conversation, not an orchestrated workflow** (ADR-031/034 lineage — Chat
> observes/collaborates; LangGraph is untouched, ADR-001 intact); the **HTML is authoritative**, Markdown is a derived export;
> the agent writes the HTML into its **per-session `fs_write_root` sandbox** (Phase 14 — no new write authority); bulk HTML +
> snapshots live **on disk** (ADR-010/018) with pointers/status in `genesis.db` (ADR-030); the annotation surface is the
> **vendored Lavish SDK driven by `postMessage` inside a same-origin sandboxed iframe** — Genesis does **not** run Lavish's
> server, CLI, long-poll, export, or ht-ml.app sharing (see ADR-043). See **ADR-042** (Features & Specs as first-class
> sub-entities of an application; Chat-authored; HTML-authoritative; the status model) + **ADR-043** (embed the Lavish
> annotation SDK, vendored under MIT).

---

## 0. TL;DR

Phase 16 gave Genesis the *technical* knowledge of an app; Phase 17 the *business* picture; Phase 19 the *human context*
(business documents). Phase 20 opens the **workspace where new work is authored**: a Feature, and inside it, a Spec.

1. **Features are first-class sub-entities of an application.** A new `kb_features` table (FK → `kb_applications`). The app
   detail page gains a **Features** tab listing feature cards + a **Create feature** dialog (name + description). Creating a
   feature navigates to the **feature page** (`/applications/:uuid/features/:featureId`) — the main work area.
2. **The feature page hosts artifacts; this phase ships the Spec.** With no spec yet, the page shows a single **Create spec**
   empty state. (Design docs, user stories, etc. are later phases — the page is built to grow.)
3. **Spec authoring is a Chat.** Clicking **Create spec** opens a chat surface (a reuse of the Phase-10 Chat) **bound to this
   feature**. The session is seeded with the application/feature identity; the `genesis-kb` MCP (already wired into chat)
   gives it the app's KB; so the agent designs the spec *for this specific application*.
4. **Add context = the app's business artifacts.** A composer **"Add context"** action opens a picker of the application's
   **linked documents** (Phase-19 `kb_document_links` / `DocumentStore`). Selected documents' parsed Markdown is injected into
   the session as grounding context (reusing the `build_evidence_pack` document mechanism).
5. **The spec is an HTML artifact, authored by the agent.** The agent writes rich, reviewable **HTML** (`spec.html`) into its
   per-session sandbox (Phase-14 `fs_write_root`). HTML is the **authoritative** form; the user can **Export as Markdown** at
   any time.
6. **Embedded, annotatable review surface (Lavish, embedded).** The feature page shows the chat beside the rendered spec HTML
   in a **sandboxed iframe** injected with the **vendored Lavish annotation SDK**. The user highlights text ranges or elements
   and comments; the SDK emits those over `postMessage`; our React host formats each annotation ("Re: '\<selected text>' —
   \<comment>") and sends it into the chat, so the agent revises the exact passage. The iframe live-reloads on each revision.
7. **Milestones + status.** The spec is snapshotted at **milestones** (user asks "save"/"draft"; the agent is also instructed
   to periodically remind + persist). Snapshots are `kb_feature_spec_revisions`. The spec's status moves **draft →
   in-progress → in-review → completed** (user-set; the agent may suggest a transition).

Bulk HTML + snapshots on disk (ADR-010/018); compact metadata/status/pointers in `genesis.db` (m0010); no new orchestration
(ADR-001); no new agent write authority beyond the existing sandbox (ADR-034); the annotation tooling is a **vendored library**
(ADR-043), not a running external service.

---

## 1. Motivation & user story

> *"We've created applications. When we develop in Appian, we work on **features**, one by one. Inside an application I want a
> **Features** tab that lists the features and lets me create a new one (just a name + description). Creating one drops me into
> the **feature page** — the main work area where all the artifacts for that feature will live: the spec, the design doc, the
> user stories. For now focus on the **spec**. On the feature page, if there's no spec, give me one button: **Create spec**.
> That opens a **chat** — like the one we already have — that has the whole knowledge base, so it knows which application this
> is and designs the spec accordingly. In the chat I want to **add documents** from the application's business artifacts into
> the conversation's context. As we talk, the spec should take shape, saved at **milestones** with a **status** (in progress,
> completed, …). And I don't want a plain Markdown file while editing — I want an **HTML page that looks like a spec**, where I
> can **highlight content and leave comments** that go to the agent, instead of describing changes in prose. I can export it as
> Markdown whenever I want."*

Net: Phase 16/17/19 gave Genesis knowledge *about* an application; Phase 20 is where an engineer *produces new work* on top of
that knowledge — starting with a conversationally-authored, visually-reviewable spec.

---

## 2. Background — what we build on (all reuse)

- **Applications surface (16-04) + Business Artifacts (19-07).** `api/applications.py`, `web/features/applications`
  (`ApplicationDetail` tabs: Business Map · Overview · Syncs · Releases · Business Artifacts). Phase 20 adds a **Features** tab
  and a new full-page **feature page** route.
- **`KbStore` + `kb_*` schema + migration idiom (16-02 m0007, 17-01 m0008, 19-03 m0009).** `Migration(version=N, …)`,
  `CREATE TABLE IF NOT EXISTS`, `kb_*` namespace, FK to `kb_applications(app_uuid) ON DELETE CASCADE`. **m0010** follows this
  exactly. `FeatureStore` mirrors `DocumentStore`'s shape (DB-agnostic signatures, blocking writes callable via `to_thread`).
- **Chat (Phase 10, ADR-031) + Skills sandbox (Phase 14, ADR-034).** In-process `ChatManager`/`ChatStore` over ACP; sessions +
  messages + usage persisted in `genesis.db` (`chat_sessions`/`chat_messages`); the `genesis-kb` MCP already wired into chat
  (16-05); the agent already writes documents into a **per-session `fs_write_root` sandbox** (`~/.genesis/skill-output/<sid>/`).
  Phase 20's spec session **is** a chat session (tagged/typed for a feature-spec) — reuse, not a rewrite.
- **Documents (Phase 19, ADR-041).** `DocumentStore` + `kb_document_links` list an app's linked business artifacts;
  `KbStore.build_evidence_pack` already carries a `documents` key of bounded, code-free document excerpts. The **"Add context"**
  action reuses this to inject selected documents.
- **Documents & preview (07-09).** `DocumentPreview`/`MarkdownView`/renderers are reused for the exported-Markdown preview and
  any document previews in the context picker.
- **Lavish annotation SDK (`kunchenguid/lavish-axi`, MIT).** Investigated in 20-01: the injected browser SDK (`artifact-sdk.js`
  + its `mermaid-node.js` helper) is **host-agnostic** — it makes **no server calls** and communicates only via
  `parent.postMessage` (events `lavish:queuePrompt`, `lavish:sendQueuedPrompts`, `lavish:reviewState`, …), with durable
  text-range anchoring (`getRangeAt` + `rangeBoundary`). We **vendor** those source files and host the artifact iframe
  ourselves; we do **not** use Lavish's Express server, CLI, poll, export, or share (ADR-043).

---

## 3. Architecture (the mental model)

```
Applications → <app> → Features (tab)                 Feature page  (/applications/:uuid/features/:featureId)
   └─ feature cards + "Create feature" (name, desc)       ├─ (no spec yet) → "Create spec"
            │  create → navigate                          └─ Spec workspace  ─────────────────────────────────
            ▼                                                   ┌───────────────────────┬───────────────────────┐
   kb_features (FK → kb_applications)                           │  Chat (reused Phase-10)│  Spec review surface   │
                                                                │  • genesis-kb MCP (KB) │  • sandboxed <iframe>  │
                                                                │  • "Add context" ──────┼──► spec.html + vendored│
                                                                │      picks app's linked│    Lavish SDK (/sdk.js)│
                                                                │      documents (19)    │  • highlight → comment │
                                                                │  • agent writes spec   │  • postMessage events  │
                                                                │    .html to fs sandbox │        │               │
                                                                └───────────▲────────────┴────────┼───────────────┘
                                                                            │  annotations formatted│ lavish:queuePrompt
                                                                            └───────────────────────┘  / sendQueuedPrompts
                                                                            │
                                        milestone save → kb_feature_spec_revisions (+ status draft→…→completed)
                                        export → HTML → Markdown (download)
```

- **Control flow:** none new. Spec authoring is a **conversation** (ChatManager, in-process ACP). LangGraph is not involved
  (ADR-001). The only "loop" is human annotation → chat turn → agent HTML revision → iframe reload.
- **Authoring seam:** the agent writes/overwrites `spec.html` in its per-session sandbox (Phase-14 `fs_write_root`). Genesis
  serves that file (same-origin, scoped route) into the review iframe and, on a **milestone**, copies it into the feature-spec
  store as a revision.
- **Annotation seam:** our React host (replacing Lavish's `chrome-client.js`) listens for the SDK's `postMessage` events,
  renders queued annotations, and on send composes a single chat message referencing the anchored text/element + comment.

---

## 4. Data model (migration `m0010`) — see 20-02 for DDL

- **`kb_features`** — `id` PK, `app_uuid` FK → `kb_applications(app_uuid) ON DELETE CASCADE`, `name`, `description`,
  `created_at`, `updated_at`. (A feature is **intrinsic** to its app — untracking the app cascade-deletes its features, unlike
  Phase-19 shared documents.)
- **`kb_feature_specs`** — `id` PK, `feature_id` FK → `kb_features(id) ON DELETE CASCADE`, `title`, `status`
  (`draft|in-progress|in-review|completed`), `chat_session_id` (→ the reused `chat_sessions` row), `html_path` (authoritative
  HTML on disk), `content_hash`, `md_export_path?`, timestamps. **One spec per feature in v1** (the singular "Create spec"
  empty state); the FK model already allows many for a later phase.
- **`kb_feature_spec_revisions`** — `id` PK, `spec_id` FK `ON DELETE CASCADE`, `revision_no`, `html_path` (snapshot), `note`,
  `created_at`. Milestone history.
- **On disk (ADR-010/018):** `~/.genesis/feature-specs/<spec_id>/spec.html` (authoritative latest) + `revisions/<n>.html`.
  `current_version` → **10**; additive + forward-only.

---

## 5. Sub-phases (all in `phase-20-features-and-spec-authoring/`)

| # | Spec | What | Repo |
|---|---|---|---|
| **20-01** | `20-01-embed-annotation-spike.md` | **Load-bearing spike** — prove the Lavish SDK embeds: vendor `artifact-sdk.js`(+`mermaid-node.js`), serve `spec.html`+`/sdk.js` same-origin, iframe it in a throwaway page, capture `lavish:queuePrompt`/`sendQueuedPrompts`, confirm text-range + element annotations round-trip. Throwaway code; findings under `spike/`. | genesis (spike) |
| **20-02** | `20-02-data-model-and-store.md` | **m0010** (`kb_features`/`kb_feature_specs`/`kb_feature_spec_revisions`, schema v10) + **`FeatureStore`** (feature CRUD, spec CRUD + status transitions, revision snapshots, on-disk layout). **ADR-042.** | genesis |
| **20-03** | `20-03-features-surface-web.md` | **Features tab** on `ApplicationDetail` (feature cards + **Create feature** dialog) + the **feature page** route + shell + the **Create spec** empty state. `api/features.py` (features CRUD; spec create). | genesis |
| **20-04** | `20-04-spec-chat-backend.md` | The **spec chat**: a feature-bound chat session (app/feature seeding + `genesis-kb`), the **"Add context"** document injection (reuse `DocumentStore`/`build_evidence_pack`), the agent's HTML-authoring instruction, **milestone save** → revision + status API. | genesis |
| **20-05** | `20-05-embedded-review-and-annotation-bridge.md` | The **embedded review surface** (sandboxed iframe + vendored SDK served same-origin) + the **annotation → chat bridge** + iframe **live-reload** on revision + the **status control** + **Export as Markdown**. **ADR-043.** | genesis |
| **20-06** | `20-06-release-and-acceptance.md` | Release (bump + tag + push genesis; pins; CI green), **ADR-042/043 → Accepted**, **live acceptance**, docs + **bible** refresh. | genesis |

**Suggested build order:** 20-01 → 20-02 → 20-03 → 20-04 → 20-05 → 20-06. **Release chain:** a single **genesis** release (with
the rebuilt, committed `web/static/`). genesis-core/genesis-workflows only touched if a follow-on wants a spec-authoring
*skill/steering* (deferred, §7).

---

## 6. Cross-cutting concerns

- **Security — agent-generated HTML runs in the browser.** The spec HTML is authored by the agent and executes scripts (the
  vendored SDK; author JS such as Mermaid). It is served **same-origin from a scoped route** and rendered in a **sandboxed
  `<iframe>`** (`sandbox="allow-scripts"` — scripts for the SDK, **without** `allow-same-origin`/`allow-top-navigation` so it
  cannot reach app cookies/storage or navigate the shell; `postMessage` still works across the boundary). This is a **local,
  single-user** app (ADR-026), so the blast radius is the user's own machine, but the sandbox is still applied and called out
  here so nobody later removes it unknowingly. No remote fetch of the artifact; the vendored SDK makes no network calls.
- **Reuse over rebuild.** The chat, the KB MCP, the document store + evidence pack, the fs-write sandbox, the document
  renderers, and the annotation SDK are all **existing** — Phase 20 is mostly wiring + a small data model + one new page.
- **HTML → Markdown export.** HTML is authoritative; Markdown is generated on demand (a server-side HTML→MD conversion of the
  authoritative `spec.html`, or an agent-produced MD companion). Chosen approach fixed in 20-05.
- **ADR-001 preserved.** No workflow, no orchestration, no new gate classes. If a later phase wants a *staged* spec pipeline
  (e.g. auto-research → draft → review gate), that would be a new LangGraph workflow and a separate ADR.

---

## 7. Deferred / out of scope (this phase)

- **Design docs, user stories, and other feature artifacts** — later phases; the feature page is built to grow tabs/sections.
- **Multiple specs per feature / spec templates** — schema allows it; UI ships one spec per feature for v1.
- **Mermaid-as-Excalidraw whiteboard editing** (Lavish's heavier feature, pulls `@excalidraw/*`) — text/element annotation
  first; the whiteboard is a candidate follow-up.
- **A spec-authoring Kiro *skill*/steering package** (genesis-workflows `skills/`) — v1 uses a system/seed instruction; a
  formal skill is optional polish.
- **Automatic status transitions / approvals** — status is user-set (agent may suggest); no gated approval flow.
- **Sharing/publishing the HTML externally** (Lavish's `share`/ht-ml.app) — explicitly out (local-first, ADR-026).

---

## 8. ADRs introduced

- **ADR-042** — Features & Specs are first-class sub-entities of an application; a spec is authored **conversationally** (Chat,
  not a workflow — ADR-001 preserved), the **HTML artifact is authoritative** (Markdown is a derived export), and it carries a
  **draft → in-progress → in-review → completed** lifecycle with milestone snapshots. Proposed → Accepted at 20-06.
- **ADR-043** — Embed the **Lavish annotation SDK** (`kunchenguid/lavish-axi`, MIT) by **vendoring** its browser SDK
  (`artifact-sdk.js` + `mermaid-node.js`) and hosting the artifact in a **same-origin sandboxed iframe** whose host is our own
  React chrome listening on `postMessage`; Genesis does **not** run Lavish's server, CLI, long-poll, export, or ht-ml.app
  sharing. Rationale: the SDK is host-agnostic and makes no server calls, so embedding fits Genesis's single-SPA UX +
  in-process ChatManager and avoids a second browser window, an unauthenticated `:4387` server, and a Node-≥22 runtime
  dependency. Upstream tracked manually; attribution in `THIRD-PARTY-NOTICES`. Proposed → Accepted at 20-06.
