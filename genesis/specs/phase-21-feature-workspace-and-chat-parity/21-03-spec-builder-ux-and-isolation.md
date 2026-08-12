# 21-03 — Spec-builder re-layout, comment queue & session isolation

> **Status:** ✅ CODE-COMPLETE (2026-08-12) — genesis working tree (uncommitted; ships in the Phase-21 end-of-phase release).
> Backend **399** pytest + ruff clean; web typecheck + eslint clean, **149** Vitest / 18 files, build OK. · **Phase:** 21 ·
> **Repo:** genesis (web + chat api/store) · **Depends on:** 21-02 (route split)

## Goal

Turn the spec builder into a **full-width chat** with an on-demand **full-screen annotatable Preview** that owns its **comment
queue** and a single **Send-all** button; **remove the copilot banner** in the builder; and **isolate `feature_spec` sessions**
from the main Chat page.

## Current state (verified)

- `SpecWorkspace.tsx` — a fixed 2-col grid (`ChatThread` left; annotatable `<iframe>` right, always shown). The annotation
  bridge pushes `lavish:queuePrompt` into an **invisible** `queuedRef` and only flushes on `lavish:sendQueuedPrompts` (the
  **SDK's own in-iframe button**) → `composeFeedback` → `sendRef`. Right pane also holds status/refresh/export/milestone.
- `ChatThread.tsx` — renders the mode banner + "Enable copilot" toggle **unconditionally**; also the supervised-runs strip.
- `chat/store.py › ChatStore.list()` — returns **all** sessions regardless of `mode`; the main `SessionList` (`useSessions`)
  renders them → `feature_spec` sessions leak.

## Changes

### A. Full-width chat + top action bar
- `SpecWorkspace` becomes a single-column **full-width** `ChatThread` (`chrome="spec"` — see B) under a **top action bar**:
  **Add context** · **status** select · **Save milestone** · **Export** (21-06) · **Preview** (primary).
- The always-on right iframe is **removed**; its controls move to the action bar.

### B. `ChatThread` chrome variant
- Add `chrome?: "full" | "spec"` (default `"full"`). In `"spec"`: **hide** the mode banner + "Enable copilot" toggle + the
  supervised-runs strip + copilot cards (item 6). No behavior change to the main chat (`"full"`).

### C. Full-screen Preview popup with our comment queue (items 3, 4)
- **Preview** opens a **full-height/full-width** overlay (`Dialog`, ~`inset-4`, header + close):
  - **Left (major):** the sandboxed, annotatable spec `<iframe>` (existing `artifactUrl`, annotate=1) — large + readable.
  - **Right (rail):** **our** comment-queue panel. Our host intercepts **every** `lavish:queuePrompt` into React state and
    renders one row per item (quoted anchor text + the comment + a **remove ✕**), a count, and a single **Send all to agent**
    button (disabled when empty). We **no longer depend** on the SDK's internal button / `lavish:sendQueuedPrompts`.
  - **Send all** → `composeFeedback(items)` → the thread's `send` (via `registerSend`) → clears the queue; the popup may close;
    the iframe live-reloads on the next assistant revision (existing `bust` behavior, kept).
- Queue state persists while the popup is closed/reopened within the session.

### D. Session isolation (item 5/6)
- `ChatStore.list(exclude_modes: tuple[str,...] = ())` — filter in SQL (`WHERE mode NOT IN (...)`). The **main** chat list
  endpoint (`api/chat.py` list-sessions) passes `exclude_modes=("feature_spec",)`. `get()` is unchanged (the builder still
  loads its session by id). Feature-spec sessions remain reachable only via the feature page.

## Testing

- **Backend (pytest):** `list()` excludes `feature_spec` when asked; `get()` still returns them; the main list endpoint hides a
  seeded feature_spec session while showing read_only/copilot ones.
- **Web (Vitest):** builder renders full-width chat, no mode banner (`chrome="spec"`); Preview opens the overlay; a simulated
  `lavish:queuePrompt` appears in the queue rail; remove drops it; **Send all** calls `send` with the composed feedback and
  clears; main `SessionList` does not render feature_spec sessions.

## Definition of done

- Builder is chat-first; document only appears in the full-screen Preview; the queue + send are visible and ours.
- No copilot banner in the builder; main chat unchanged.
- `feature_spec` sessions absent from the main Chat list.
- Backend + web gates green; `web/static/` rebuilt + committed.
