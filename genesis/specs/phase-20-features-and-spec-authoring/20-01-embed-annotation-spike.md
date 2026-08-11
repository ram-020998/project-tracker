# 20-01 — Embedded annotation spike (load-bearing feasibility)

> **Status:** 📋 DRAFT. **Type:** time-boxed spike (throwaway code, durable findings under `spike/`). **Gates:** 20-05 (the
> whole embedded review surface). Do this FIRST. **Repo:** genesis (scratch only — no production code).

## Why a spike
The whole review surface (20-05) rests on one assumption verified only by reading Lavish's source: that the injected
**`artifact-sdk.js`** can be **lifted out of Lavish's server/chrome** and driven by *our* React host, purely over
`parent.postMessage`, with no Lavish Express server, CLI, or long-poll. Reading the code says yes (the SDK makes **no**
fetch/XHR/WebSocket calls and posts events like `lavish:queuePrompt` to `parent`). This spike **proves it end-to-end in a
browser** before we build the data model + page around it — same discipline as the 13-01 permission spike and the 19-01 gws
spike.

## Questions to answer (pass/fail)
1. **Vendor + bundle.** `artifact-sdk.js` + its `mermaid-node.js` import build cleanly as **vendored source** through our
   existing Vite/esbuild (Node 20) into a single `/sdk.js` — **no `lavish-axi` npm dependency, no Node ≥22 at runtime.**
2. **Same-origin serve.** A `spec.html` with `<script src="/sdk.js">` injected before `</body>` (the `injectLavishSdk`
   contract) served **same-origin** loads the SDK and boots the annotation UI inside an `<iframe>`.
3. **Sandbox compatibility.** The iframe with `sandbox="allow-scripts"` (**without** `allow-same-origin`) still runs the SDK
   and its `parent.postMessage` reaches our host (confirm the SDK's `"*"` target origin works under sandbox).
4. **Element annotation round-trips.** Hovering/clicking an element and typing a comment emits a `lavish:queuePrompt` with the
   element `{uid, selector, tag, text}`; **Send** emits `lavish:sendQueuedPrompts`; our host receives both.
5. **Text-range annotation round-trips.** Selecting a text range + commenting emits a `type:"text-range"` prompt carrying the
   **selected text** + range anchors; our host receives the exact passage.
6. **Live reload.** Overwriting `spec.html` and reloading the iframe re-renders the new content and re-boots the SDK; queued
   (unsent) annotations behavior is characterized (kept vs dropped) so 20-05 can decide the UX.
7. **No external dependency at runtime.** With the network blocked, the annotation loop still works (no CDN/font requirement
   for the SDK itself; any agent-authored CDN use is the artifact's concern, not the SDK's).

## Method
- Vendor `src/artifact-sdk.js` + `src/mermaid-node.js` (+ the `injectLavishSdk` from `src/html-transform.js`) from
  `kunchenguid/lavish-axi` (MIT, pin the commit) into a scratch `web/src/dev/lavish/`.
- Add a throwaway `/dev` route (or a KitchenSink panel) that: serves a sample `spec.html` + the bundled `/sdk.js`, iframes it,
  and logs every `message` event's `{type, payload}`.
- Exercise element + text-range annotations by hand; capture the exact payload shapes; try the sandbox attribute matrix.
- Record the full **message schema** (every `lavish:*` type + payload) and the **injection recipe**.

## Deliverable
- `spike/2026-08-<dd>-lavish-embed.md`: the vendored file list + pinned commit, the `/sdk.js` build recipe, the **iframe +
  sandbox** attributes that work, the complete `postMessage` **message schema** (queuePrompt / sendQueuedPrompts / reviewState
  / status / scroll / endSession / layoutDiagnostics — fields + example payloads), the live-reload behavior for unsent
  annotations, and the recommended host contract for 20-05. **No production code in this sub-phase** (scratch is deleted or
  clearly quarantined under `web/src/dev/`).

## Exit criteria
All seven questions answered; a working browser demo where a highlight + comment (both element and text-range) arrives in a
host-side log with usable anchors, under a sandboxed same-origin iframe, with `/sdk.js` built from vendored source on Node 20
and no runtime network dependency. If (1)/(3) fail, 20-05's approach adjusts (e.g. a build shim, or `allow-same-origin` with a
documented rationale) and the finding is recorded before proceeding.
