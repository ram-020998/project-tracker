# 43-03 — Documents-viewer chrome + Design & Implementation tabs + default-tab logic

> **Phase 43 · sub-phase 03** — the document tabs + the single doc-viewer chrome + stage-aware default tab.
> Depends on 43-01 (data) + 43-02 (shell). Read `StoryDesignWorkspace.tsx`, `AnnotatablePreviewDialog.tsx`,
> `ImplementationReviewWorkspace.tsx`, `features/documents/renderers/MarkdownView`, `lib/api/workbench.ts`.

## Goal

Add the **Design** and **Implementation** tabs, unify their presentation under **one documents-viewer chrome**
(Q8), identify each document by type (Q7), and land the page on the **stage-relevant tab** (Q3). The design is
chat-editable **in a new browser tab** only while in Design/Design-Review (Q5), read-only afterward (Q6).

## Build

1. **`StoryDocument` chrome** (the one net-new component) — a labelled container:
   - Props: `label` (the document **type** — "Design document" / "Implementation report" / "Objects modified" / "Rollback document"), optional header `actions`, and the body.
   - Consistent header (type label + a subtle "read-only" hint where applicable + optional actions like "Open full screen" / "Edit / chat"), consistent spacing/tokens — so every document tab looks the same and each doc's type is unambiguous.
   - The body is passed in; `StoryDocument` does **not** re-implement renderers — it wraps them.

2. **Design tab** (visible when `design != null`, i.e. a design stage exists):
   - Render `design.html` **read-only** — reuse the themed artifact (`workbenchApi.designArtifactUrl(appUuid, storyId, theme, bust)` with `annotate=0`) in a preview surface (an iframe or the `AnnotatablePreviewDialog` in a non-annotating read mode — pick the lighter one; the tab is a read view, full-screen/annotate lives in the chat).
   - **"Edit / chat" button** — shown **only when `context.lane ∈ {design, design-review}`** AND `design.chat_session_id` exists; it **opens the design chat workspace in a NEW BROWSER TAB** (`window.open(target, "_blank", "noopener")` or an `<a target="_blank" rel="noopener">`) at the dedicated design-chat route (43-02). After implementation (code-review+) the button is **absent** — the design is view-only (Q6).
   - If a design run is **running/failed** (from `design.run_status`), show the running/failed panel (reuse the existing panels from `StoryCardPage`) instead of a stale artifact.

3. **Implementation tab** (visible when `implementation != null`):
   - Re-home the `ImplementationReviewWorkspace` content into the tab, wrapped in `StoryDocument` sections: **Objects modified** (the per-object table), **Implementation report** (the sandboxed `iframe srcDoc` — no scripts), **Rollback document** (`MarkdownView`). Read-only.
   - Running/failed panels from `implementation.run_status` as today.

4. **Default tab (Q3)** — a pure `defaultStoryTab(ws: StoryWorkspace): "overview"|"design"|"implementation"`:
   - implementation if `implementation` has content (report/objects) OR lane ∈ {code-review, verification, deployment, done};
   - else design if `design` has an artifact OR lane ∈ {design, design-review};
   - else overview.
   - Unit-tested in isolation (framework-free), like `stages.ts`/`design-state.ts`.

5. **Tab set** — build the tab list from what exists: always Overview; push Design if `design`; push Implementation if `implementation`. Select `defaultStoryTab(ws)` on first load (respect a `?tab=` override for deep links if cheap).

## Consistency

- Reuse `MarkdownView`, the sandboxed iframe pattern, the themed design artifact, the `Tabs` primitive, `shared/ui` badges/tokens. The **only** new component is `StoryDocument`.
- Match the library `DocumentDetailPage` conventions where sensible (header + type + a single scroll body per document) so the story docs feel like the rest of the app.

## Tests

- Web (vitest + jest-axe): Design tab renders read-only + shows "Edit / chat" only in design/design-review (and it targets `_blank`); Implementation tab renders objects/report/rollback; tabs appear only for present stages; `defaultStoryTab` unit tests cover every lane/stage combination; a code-review story defaults to Implementation and the design is view-only. axe clean on the mountable tab surfaces (the sandboxed iframe body is excluded from axe as in the existing impl-review test).

## Done when

All three tabs render under one consistent chrome with clear type labels; the page lands on the stage-relevant tab; the design "Edit / chat" opens the chat in a new tab only when editable; `defaultStoryTab` is tested; tsc/eslint/vitest(+axe) green; `web/static` rebuilt + committed.
