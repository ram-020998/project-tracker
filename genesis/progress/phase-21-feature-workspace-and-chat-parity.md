# Progress — Phase 21: Feature Workspace, Spec-Builder UX & Chat Parity

> **Status (2026-08-12):** 🚧 IN PROGRESS. **21-01 ✅ (spike, committed)** · **21-02 ✅ (code-complete, uncommitted)** ·
> **21-03 ✅ (code-complete, uncommitted)**. Next: **21-04** (kiro-agent-sdk — its own repo/release). Per the user, **all
> genesis-repo code changes for 21-02..21-07 are held for a single release at the end of Phase 21** — only project-tracker
> (specs/progress/spike) is committed as we go. Spec: `specs/phase-21-feature-workspace-and-chat-parity.md` (+ `21-01..21-07`).
> **ADR-044/045** (Proposed).

## 21-01 — ACP parity spike ✅ (committed to project-tracker)

Verified the ACP-extension surface against the installed **kiro-cli 2.16.2** (throwaway stdlib harness). **GO.** Findings +
recommended SDK surface: `spike/2026-08-12-acp-parity.md`. Headlines:
- **Model list is free at `session/new`** — result `.models = {currentModelId, availableModels[{modelId,name,description}]}`
  (no Settings fallback needed as primary). `session/set_model {sessionId, modelId}` works; agents live under `.modes` +
  `session/set_mode`.
- **`_kiro.dev/commands/available`** is a **notification** (not a request → -32601) carrying the full slash catalog + prompts +
  tools. Per-command `optionsMethod` is advertised but **not wired** in 2.16.2 → **autocomplete client-side** off the catalog.
- **`_kiro.dev/commands/execute`** exists but a headless request **times out** on panel commands → treat as **streaming**; nail
  the terminal signal in 21-04 (fallback: send slash text via the normal prompt path).
- `contextUsagePercentage` (via `_kiro.dev/metadata`) + `promptCapabilities.image: true` present.
- **Impact:** 21-05 sources models from `session/new`; recommend a `chat_sessions.model` column (`m0011`).

## 21-02 — Feature workspace landing ✅ (code-complete; genesis working tree, uncommitted)

Turned the feature page into a **workspace landing** (ADR-044) instead of dropping into the spec builder.

**Backend** (`genesis/api/features.py`): `spec_artifact` gained `annotate: int = 1`. `annotate=0` serves the spec HTML with
**theme only, no Lavish SDK** (the read-only "eye" preview); default `annotate=1` still injects the SDK (the builder's editable
surface). Test `test_artifact_readonly_mode_omits_sdk` added — **13** features-API tests + ruff clean.

**Frontend** (`web/src/features/features/`):
- **`ArtifactPipeline.tsx`** (new) — the ordered pipeline ① Spec ② Design ③ Breakdown with connectors. `SpecCard`: status pill
  + **Edit** (pencil → `…/spec`) + **View** (eye → a full-screen read-only `Dialog` preview at `previewUrl`, `annotate=0`), or a
  single **Create spec** button when none (→ creates then routes to the builder). `PlaceholderCard` (Design/Breakdown): a
  purpose-built **disabled** state — dashed border, muted surface, lock glyph + "Coming soon" (non-interactive). Sequential
  unlock deferred (ADR-044).
- **`FeaturePage.tsx`** rewritten as the landing (renders `ArtifactPipeline`).
- **`SpecBuilderPage.tsx`** (new) at route **`/applications/:appUuid/features/:featureId/spec`** — renders the existing
  `SpecWorkspace` unchanged (the full-width + Preview-popup re-layout is 21-03).
- `lib/api/features.ts` `previewUrl(featureId, theme)` → `artifact?annotate=0`; `shared/ui/icons.ts` + Eye/Lock/Layers/ListChecks;
  `router.tsx` + the `/spec` route; **`FeaturesTab` feature card drops the spec-status badge** (item 1 — a spec's status is not
  the feature's status; no feature status shown yet).

**Gate:** typecheck + eslint clean; **147** Vitest (18 files); `npm run build` OK. `web/static/` rebuilt (uncommitted).

**Note for 21-03:** `SpecBuilderPage` currently renders the OLD 2-column `SpecWorkspace` — 21-03 replaces that with the
full-width chat + full-screen annotatable Preview (our comment-queue + Send-all), the `ChatThread` `chrome="spec"` variant, and
`feature_spec` session isolation from the main chat list.

## 21-03 — Spec-builder re-layout, comment queue & session isolation ✅ (code-complete; uncommitted)

The spec builder is now **chat-first** with an on-demand full-screen review, and its sessions are isolated from the main chat.

**Backend:**
- `ChatStore.list(exclude_modes=())` → `WHERE mode NOT IN (…)`; `ChatManager.list_sessions(exclude_modes=())`; the **main** chat
  list endpoint (`api/chat.py`) now passes `exclude_modes=("feature_spec",)`. `get()`/unfiltered list still return them (the
  feature page loads its session by id). Test `test_list_sessions_excludes_feature_spec`.

**Frontend:**
- **`ChatThread`** gained `chrome?: "full" | "spec"` (default `"full"`). In `"spec"` the **mode banner + Enable-copilot toggle**
  are hidden (item 6); the supervised-runs strip + copilot cards were already gated by copilot mode. The main chat is unchanged.
- **`SpecWorkspace`** rewritten: a **full-width** `ChatThread(chrome="spec")` under a top action bar (Add context · status ·
  Export .md · Save milestone · **Preview**). The always-on right iframe is gone. **Preview** opens a **full-screen `Dialog`**
  (`h-[92vh] w-[94vw]`): the annotatable spec iframe (left) + **our own comment-queue rail** (right). Every `lavish:queuePrompt`
  lands in React state and renders as a removable row (quoted anchor + comment); a single **Send all to agent** composes one
  chat turn (`composeFeedback` → the thread's `send`) and clears the queue. The queue persists across open/close; the iframe
  live-reloads on each new assistant message. (Added the `Send` icon.)

**Gate:** backend **399** pytest + ruff clean; web typecheck + eslint clean, **149** Vitest (18 files), build OK.

**Note:** the Composer's small hint line still reads "Read-only assistant · type / for skills" (a visible span, not the banner) —
left as-is; the Composer is revamped in **21-05** (chat parity).