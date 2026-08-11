# 20-05 — Embedded review surface + annotation → chat bridge (web)

> **Status:** 📋 DRAFT. **Repo:** genesis. **This is ADR-043** (embed the vendored Lavish SDK). **Depends on:** 20-01 (proven
> embed contract + message schema), 20-04 (spec chat + authoring seam). The visible heart of the phase.

## Goal
Render the spec **HTML** in an **embedded, annotatable** surface inside the feature page, beside the reused chat, and pipe the
user's highlights + comments straight into the conversation so the agent revises the exact passage — all inside the Genesis
SPA, no second window.

## Vendored SDK (ADR-043)
- Vendor `artifact-sdk.js` + `mermaid-node.js` (+ `injectLavishSdk`) from `kunchenguid/lavish-axi` (MIT, **pin the commit**
  recorded in the 20-01 spike) into `web/src/features/features/lavish/` (or a shared `web/src/shared/lavish/`). Attribution in
  `THIRD-PARTY-NOTICES.md`. Bundle to a single **`/sdk.js`** via our existing Vite/esbuild (Node 20). **No `lavish-axi` npm
  dependency; no Lavish server/CLI/poll/export/share.**

## Serving the artifact (backend, same-origin)
- A scoped route serves the spec HTML with the SDK injected + the bundled SDK script:
  `GET /api/features/{id}/spec/artifact` → the authoritative `spec.html` (from the session sandbox or the store) transformed
  by `injectLavishSdk` (adds `<script src="/api/features/{id}/spec/sdk.js">` before `</body>`); `GET …/spec/sdk.js` → the
  bundled vendored SDK. Same-origin so `postMessage` + the script load work under the iframe sandbox.

## The review surface (frontend)
- **Layout.** The feature page spec workspace = a split view: **left** the reused Chat (`features/chat` `ChatThread` +
  `Composer`, bound to the spec's session), **right** the **spec review iframe**.
- **Iframe.** `<iframe src="/api/features/{id}/spec/artifact" sandbox="allow-scripts">` (no `allow-same-origin` /
  `allow-top-navigation` — see the umbrella §6 security note; confirm against the 20-01 sandbox finding). A **React host**
  (our replacement for Lavish's `chrome-client.js`) attaches a `window` `message` listener for the SDK events.
- **Annotation → chat bridge.** On `lavish:queuePrompt`, show the queued annotation(s) in a small host-side panel (or inline
  pills); on `lavish:sendQueuedPrompts`, compose **one chat message** that references each annotation's anchored text/element +
  the user's comment (e.g. `> "\<selected text>"` + the note, per annotation) and **send it into the spec chat**. The agent
  revises `spec.html`.
- **Live reload.** When a turn completes and `spec.html` changed (content hash differs), **reload the iframe** so the user
  sees the revision (reuse the 20-01 live-reload finding for unsent-annotation handling).
- **Status control.** A status selector (`draft → in-progress → in-review → completed`) on the spec header →
  `PATCH …/spec/status`. Milestone **Save** button → `POST …/spec/milestone`; a revisions list/drawer shows snapshots.
- **Export as Markdown.** An **Export MD** action → `GET /api/features/{id}/spec/export.md` (server converts the authoritative
  `spec.html` → Markdown) → download; preview via the 07-09 `MarkdownView`. (Conversion approach — a server-side HTML→MD pass;
  finalize the converter in implementation, prefer a small dependency-light path.)
- **Add context.** The composer's **Add context** control opens a picker of the app's linked business artifacts (20-04) →
  `POST …/spec/context`.

## Security (enforced here — umbrella §6)
Agent-generated HTML executes in the browser. Serve **same-origin from the scoped route only**, render in a **sandboxed
iframe** (`allow-scripts` without `allow-same-origin`), and never widen the sandbox without an ADR note. Local single-user
(ADR-026) bounds the blast radius; the sandbox is still applied.

## Tests
- `features/features.test.tsx` (extended) / a `spec-review.test.tsx`: a mocked SDK `postMessage` (`queuePrompt` +
  `sendQueuedPrompts`) produces a correctly-formatted chat message; the status control PATCHes; Export-MD calls the endpoint;
  **jest-axe** on the workspace. Backend: artifact route injects the script + serves same-origin; export route returns
  Markdown. Keep a golden fixture of the `postMessage` payload shapes (from 20-01) so an upstream SDK drift fails a test
  (the "stub hid the contract" lesson).

## Exit criteria
On a feature page I can chat to author a spec, see it rendered as HTML in the embedded surface, **highlight a passage + comment
and have it arrive in the chat**, watch the agent revise + the iframe reload, set status, save a milestone, and export
Markdown — all in one Genesis page. Tests + `ruff`/`tsc`/`eslint`/`npm run build` green (commit `web/static/`). **ADR-043 →
Accepted** on ship.
