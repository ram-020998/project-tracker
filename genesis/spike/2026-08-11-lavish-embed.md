# Spike (2026-08-11) — Embedding the Lavish annotation SDK inside the Genesis SPA (Phase 20-01)

> **Verdict:** ✅ **PASS (load-bearing mechanics verified) — proceed with 20-02..20-05.** The Lavish browser SDK embeds cleanly
> under Genesis's own toolchain: it is **plain browser ESM (MIT)**, makes **zero network calls**, and communicates **only** via
> `parent.postMessage`. Our own **esbuild (Node 20)** bundles the two vendored source files into a **70.5 kb self-contained
> IIFE** — no `lavish-axi` npm dependency, no Express server, no CLI/poll, **no Node ≥22**. The exact annotation **message
> schema** is captured below (the 20-05 bridge contract). **One item is user-verified in a real browser** (the click/select →
> comment round-trip + the sandbox attribute), via the runnable harness in §6 — same posture as the 19-01 gws live step.
>
> **Upstream pinned:** `github.com/kunchenguid/lavish-axi` @ **`899747a3d7e03d1e3b8061fc3869331e514c2917`** (npm `0.1.50`, MIT).

## Why this spike
20-05 (the embedded review surface) rests on one claim only established by reading source: that Lavish's injected
`artifact-sdk.js` can be lifted out of Lavish's server/chrome and driven by *our* React host over `postMessage`, with no Lavish
runtime. This spike proves it end-to-end before we build the data model + page (same discipline as 13-01/19-01).

## How Lavish itself serves the SDK (the contract we reproduce)
- **Injection** (`src/html-transform.js` `injectLavishSdk`): a single `<script src="/sdk.js?key=…">` inserted before
  `</body>`; the artifact runs in an **iframe**.
- **The served `/sdk.js`** (`src/server.js` `createSdkJs`): Lavish does **not** ship a browser bundle — it **`.toString()`-
  serializes** `createArtifactSdk` + its pure helpers (`deriveLavishQueueKey`, `isNativeInteractiveControl`, the layout
  classifiers, and every `mermaid-node.js` export) into one IIFE and invokes
  `createArtifactSdk(deriveQueueKey, isNativeInteractive, mermaidHelpers, artifactRevision, artifactLoadToken, key)`. This works
  only because those functions are self-contained (no closed-over module state beyond the passed args).
- **Genesis's cleaner equivalent:** a 2-line browser **entry** that `import`s the factory and lets **esbuild** resolve
  `./mermaid-node.js` — no `.toString()` assembly, no hand-kept helper list. See §5.

## The 7 questions — verdicts

| # | Question | Verdict | Evidence |
|---|---|---|---|
| 1 | Vendor + bundle via our esbuild (Node 20), no npm dep / no Node ≥22 | ✅ PASS | `esbuild 0.21.5` (from `genesis/web`) bundled `entry.js` → **70.5 kb** browser IIFE, **0** leftover `import`/`export`. |
| 2 | Same-origin serve of `spec.html`+`/sdk.js` loads the SDK in an iframe | ✅ PASS (HTTP) | `host.html`/`spec.html`/`sdk.js` all **200**; `spec.html` carries `<script src="./sdk.js">`; bundle contains `annotationMode` + `parent.postMessage`. Visual boot = user-verify (§6). |
| 3 | `sandbox="allow-scripts"` (no `allow-same-origin`) still delivers `postMessage` | ⏳ USER-VERIFY | Reasoned correct — the SDK posts `parent.postMessage(…, "*")` (opaque-origin sandboxes may still post to the parent). Harness uses exactly this attribute; confirm in browser. |
| 4 | Element annotation round-trips (`lavish:queuePrompt` + element `{uid,selector,tag,text}`; `sendQueuedPrompts`) | ✅ schema / ⏳ round-trip | Schema extracted from source (below); click round-trip = user-verify (§6). |
| 5 | Text-range annotation round-trips (`target.type:"text-range"` + selected text + range anchors) | ✅ schema / ⏳ round-trip | `textSelectionContext` builds durable `start`/`end` anchors via `rangeBoundary` (below); select round-trip = user-verify. |
| 6 | Live reload re-renders + re-boots the SDK | ⏳ USER-VERIFY | Lavish watches the file + preserves unsent card text/scroll; **our** embed reloads the iframe on a spec revision — confirm the unsent-annotation UX in browser. |
| 7 | No runtime external dependency | ✅ PASS | `grep` of the produced bundle: **0** `fetch`/`XMLHttpRequest`/`WebSocket`/`EventSource`/`sendBeacon`/dynamic-`import`. |

## The annotation message schema (the 20-05 bridge contract)
All events are `window.postMessage` from the artifact iframe to its host, shaped `{ type, ...payload, artifact_load_token }`.
Types emitted (`src/artifact-sdk.js`): `lavish:queuePrompt`, `lavish:sendQueuedPrompts`, `lavish:reviewState`,
`lavish:status`, `lavish:scroll`, `lavish:snapshot`, `lavish:toggleAnnotationMode`, `lavish:layoutDiagnostics`,
`lavish:artifactAssetFailure`, `lavish:endSession`.

**The two that matter for us:**
- **`lavish:queuePrompt`** → `{ prompt: item }`, one per queued annotation. `item`:
  ```jsonc
  {
    "uid": "12",                 // element uid ("" for a text-range)
    "selector": "article > h2:nth-of-type(4)",  // CSS path to the (common ancestor) element
    "tag": "h2",                 // element tag, or "text" for a text-range
    "text": "Open questions",    // element innerText OR the selected text, ≤240 chars
    "prompt": "make this a numbered list",       // the user's typed comment
    "target": {                  // present for text-range (and mermaid-node) selections:
      "type": "text-range",
      "text": "Should a partial-failure batch roll back entirely…",
      "selector": "article", "commonAncestorSelector": "article",
      "start": { "selector": "article > p:nth-of-type(4)", "path": [/* childIndex path */], "offset": 0 },
      "end":   { "selector": "article > p:nth-of-type(4)", "path": [/* … */], "offset": 41 }
    },
    "_lavishQueueKey": "…"       // internal dedup key — STRIP before sending to the agent
  }
  ```
- **`lavish:sendQueuedPrompts`** → no payload; fired when the user clicks Send (or Ctrl/Cmd+Enter). **Host action:** compose
  **one** chat message from the queued items — e.g. per item a block quote of `text` + the `prompt` comment — strip
  `_lavishQueueKey`, and send it into the spec's chat session. The agent revises `spec.html`; we reload the iframe.

## Recommended host contract for 20-05
- Serve `GET /api/features/{id}/spec/artifact` → the authoritative `spec.html` transformed by our own `injectLavishSdk`
  (adds `<script src="…/spec/sdk.js">`); `GET …/spec/sdk.js` → the esbuild-bundled vendored SDK. **Same-origin.**
- `<iframe sandbox="allow-scripts">` (no `allow-same-origin`/`allow-top-navigation`), a `window` `message` listener as the
  host; collect `queuePrompt` items → on `sendQueuedPrompts` compose + send a chat turn; reload iframe on revision.
- Keep a **golden fixture** of these payload shapes; a shape drift after a vendored-SDK bump fails a test (the "stub hid the
  contract" lesson).

## Vendoring plan (20-05)
Vendor **only** `src/artifact-sdk.js` + `src/mermaid-node.js` (pinned commit above) into `web/src/…/lavish/`; attribute in the
genesis `THIRD-PARTY-NOTICES.md` (MIT). The Mermaid-as-Excalidraw whiteboard (`whiteboard-*`, `@excalidraw/*`) is **out** for
v1 — text/element annotation ships first.

## The harness (throwaway — recipe so it's reproducible)
Location this session: `/tmp/lavish-embed-spike/`. Files: `vendor/{artifact-sdk,mermaid-node}.js` (from the pinned commit),
`entry.js`, `spec.html` (sample spec + injected `./sdk.js`), `host.html` (iframe `sandbox="allow-scripts"` + a `postMessage`
log panel standing in for our React chrome), `sdk.js` (the bundle).
```bash
# entry.js — the clean replacement for Lavish's .toString() assembly:
#   import { createArtifactSdk, deriveLavishQueueKey } from "./vendor/artifact-sdk.js";
#   createArtifactSdk(deriveLavishQueueKey);
genesis/web/node_modules/.bin/esbuild entry.js --bundle --format=iife --platform=browser --outfile=sdk.js
cp sdk.js ./sdk.js        # beside spec.html/host.html
python3 -m http.server 8099
# open http://127.0.0.1:8099/host.html → annotate an element / select text → type a comment →
#   Enter to queue, Ctrl/Cmd+Enter to queue+send → watch queuePrompt / sendQueuedPrompts in the host log.
```

## Theming — make the annotation UI use Genesis tokens (ADR-027), not Lavish yellow
**User-confirmed** the round-trip in-browser (element + text-range annotations arrive with anchors), and flagged the default
**yellow** comment box. Root: the SDK builds its whole palette as CSS custom properties on the shadow-root **`:host`**
(`--accent:#f4c95d`, `--brass-*`, `--bg`/`--bg-panel`/`--fg`/`--border`, `color-scheme:dark`) — defined *inside* the shadow
style, so an outer document can't override them without a seam.

**Seam (applied in the harness; the plan for 20-05):** since we vendor the SDK, expose a theming API by making the `:host`
palette + the highlight rules **consume `--lavish-*` overrides with the original values as fallbacks** — a single, localized
patch to the one `:host` style string (custom properties still inherit through `:host{all:initial}`, and fallbacks mean it
degrades to stock Lavish if unset). Then **inject Genesis design tokens** into the artifact document (our `injectLavishSdk`
adds a `<style>` alongside the `<script>`). Map (Genesis **dark** default shown; inject the `.theme-light` set when the user's
Genesis theme is light):

| `--lavish-*` override | Genesis token (dark) | value |
|---|---|---|
| `--lavish-accent` | `--primary` | `#6d8bff` |
| `--lavish-accent-hover` | `--accent` | `#b892ff` |
| `--lavish-accent-ink` | `--primary-fg` | `#0b0c0e` |
| `--lavish-bg` (textarea) | `--surface-1` | `#141619` |
| `--lavish-bg-panel` (card) | `--surface-2` | `#1b1e22` |
| `--lavish-bg-elevated` | `--surface-3` | `#22262b` |
| `--lavish-fg` | `--fg` | `#f2f4f7` |
| `--lavish-fg-faint` | `--fg-muted` | `#9ba3ae` |
| `--lavish-border` | `--border` | `#232629` |
| `--lavish-annotate-outline` | (from `--primary`) | `2px solid #6d8bff` |
| `--lavish-highlight-bg` / `-ring` / `-soft` | (from `--primary`) | `rgb(109 139 255 / .24 / .5 / .22)` |

Patched regions in `artifact-sdk.js` (the `:host` block: `--bg`/`--bg-panel`/`--bg-elevated`/`--fg`/`--fg-faint`/`--border`/
`--brass-ink`/`--accent`/`--accent-hover`; `.lavish-text-highlight`; `.lavish-reveal-marker`) — **record this diff in
`THIRD-PARTY-NOTICES.md` / a patch note so a future upstream bump re-applies it**; `color-scheme` stays `dark` for v1 (switch to
the active theme in 20-05). Verified: the rebuilt bundle carries `var(--lavish-accent,#f4c95d)` etc. (override + fallback).

## Exit
All programmatically-verifiable questions PASS (1,2,7 + the full schema for 4/5). The browser round-trip (3,4,5,6) is ready to
confirm via the harness. **No production code written; no spec change required — proceed to 20-02 (m0010 + `FeatureStore`) and
20-05 (embed) using the schema + host contract above.**
