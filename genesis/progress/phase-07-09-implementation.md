# Genesis — Phase 7.9 (Web Revamp: Documents & Artifact Preview) Implementation Record

> As-built record of `specs/phase-07-09-documents-and-preview.md` — surfaces the documents a
> workflow produces as first-class output, rendered inline by kind. **Frontend-only** (the
> 07-02 artifact APIs already exist). Part of milestone M7.1.

**Date:** 2026-07-11 · **Status:** ✅ COMPLETE — committed `4dc31a0` (52 web tests, tsc strict,
temp vite build OK). **No backend/core change → no release** (genesis stays v0.10.0).
Build-alongside (served `static/` untouched — cutover 07-10).

**New deps (public npm):** `react-markdown@9`, `remark-gfm@4`, `mermaid@11`.

---

## 1. Summary

The Run Detail **documents drawer** lists a run's blackboard artifacts, and clicking any
document opens a **deep-linkable preview sheet** (`/runs/:runId/docs/:docName`) that renders it
by kind — markdown, mermaid, JSON, CSV, or text — with download, copy, raw toggle, truncation
handling, and graceful degradation for binary (415) and pruned (404) files. The renderers are
**pure and reusable**; gate `context_refs` (07-08) and node Inputs/Outputs docs now cross-link
straight into the preview.

---

## 2. Backend contract (already present — verified, not changed)

07-09 consumes the 07-02 artifact APIs unchanged: `GET /runs/{id}/artifacts` (manifest →
`docs[name] = {path, bytes, media_type, preview_kind}`), `GET /runs/{id}/artifacts/{name}?mode=preview|full`
(`{name, media_type, preview_kind, truncated, content}`; **415** for binary, **413** for oversized
full, **404** for missing/pruned, path-safe on the server), and `.../download` (FileResponse).

---

## 3. Data layer (`lib/` + `features/documents/hooks.ts`)

- `types/artifact.ts` — `PreviewKind`, `ArtifactEntry`, `ArtifactsManifest`, `ArtifactContent`.
- `lib/api/runs.ts` — `artifacts()`, `artifactContent(name, mode)`, and `artifactDownloadHref(id,name)`
  (a browser-link href, centralized so components never hard-code the `/api` prefix — ADR-028).
- `lib/query/keys.ts` — `runs.artifacts(id)` + `runs.artifact(id, name, mode)`.
- `useRunArtifacts(runId, active)` — flattens the manifest to a sorted `ArtifactEntry[]`; polls
  every 4s while the run is **active** (there is no `artifact.written` event yet — a 07-02
  deferred item — so we poll rather than append). `useArtifactContent(runId, name, mode)` —
  cached per (name, mode); `retry:false` so 404/415 surface immediately.

---

## 4. Reusable renderers (`features/documents/`)

All pure + unit-tested; reused by the drawer preview, the gate/node context previews (07-08),
and any future doc screen. `DocumentPreview` dispatches by `preview_kind`:

| kind | renderer |
|---|---|
| markdown | `MarkdownView` — react-markdown + remark-gfm; fenced ` ```mermaid ` → `MermaidView`, other fences → `CodeBlock`; `prose prose-invert` |
| mermaid | `MermaidView` — **dynamic** `import("mermaid")` (lazy chunk), theme-aware, source toggle, error → source fallback (never throws) |
| json | `JsonTree` — collapsible recursive tree + raw toggle; falls back to `CodeBlock` on unparseable (e.g. truncated mid-token) |
| csv | `CsvTable` — minimal RFC-4180 parser (`parseCsv`), header + column sort + raw toggle; capped at 500 rows (virtualization deferred) |
| text/log | `CodeBlock` — monospace + wrap toggle + copy (shiki syntax highlighting deferred to 07-10) |
| binary | no inline preview (415) → icon + size + Download |

---

## 5. Drawer + preview sheet (`features/run-detail/components/docs/`)

- `DocumentsList` — drawer body: kind icon, name, size (`formatBytes`), a preview affordance, and
  a per-row Download link; a **Result** badge on `result*`/`erd-input`/`output` docs on terminal
  runs; empty + loading states.
- `DocumentPreviewSheet` — a wide right `Drawer` (max-w-3xl) driven by the `:docName` route param.
  Header: name + kind badge + size + Truncated badge; action bar: Download / Copy / Raw toggle /
  Load full. States: loading skeleton, 404 → "Document no longer available (pruned by retention)",
  415 → binary download-only, error → retry, truncated → banner + Load-full (refetch `mode=full`).

`RunDetailPage` wires both: the existing header **Documents** button opens the list drawer; the
`:docName` route opens the preview sheet on top; closing returns to `/runs/:runId[/node/:nodeId]`.

---

## 6. Cross-links (§4)

- Gate `context_refs` chips (07-08 HITL bar) and node **Inputs/Outputs** "Documents produced" rows
  are now buttons that call `onOpenDoc(name)` → navigate to the preview — review-at-a-gate is one click.
- Final result documents get a "Result" badge on terminal runs.

---

## 7. Verification

- `npx tsc --noEmit` strict — clean.
- `npx vitest run` — **52 passed** (added 10 in `documents.test.tsx`): `parseCsv` (quoted/escaped/CRLF);
  `DocumentPreview` dispatch for json/csv(+sort)/markdown/text; `DocumentsList` (size, download href,
  Result badge, open callback, empty); `DocumentPreviewSheet` (truncation → Load full, 415 binary
  download-only, 404 pruned). mermaid mocked for speed/determinism.
- `npx vite build --outDir /tmp/... --emptyOutDir` — OK. **mermaid is lazy-loaded** (separate chunks
  via the dynamic import), so the main bundle grew only ~170KB (react-markdown). `git status web/static`
  — **untouched**.
- Frontend + genesis CI: green (commit `4dc31a0`).

---

## 8. Definition of done (07-09) — status

1. Documents drawer lists artifacts (kind/size), updates live (**polled** while active — no
   `artifact.written` event yet), links from gate/node contexts — ✅ (see §9).
2. Click → preview rendered by kind (md/mermaid/json/csv/text), truncation/download/copy/raw, deep-link — ✅.
3. Binary/oversized → download-only; 404/pruned handled — ✅.
4. Renderers reusable + unit-tested per kind — ✅.
5. States (loading/empty/error/truncated) + a11y (focus-trapped sheet, escape to close via Radix) — ✅.

---

## 9. Decisions & honest deviations

- **Live updates are polled, not event-driven.** `artifact.written` events don't exist yet (a
  07-02 deferred backend item), so the list refetches every 4s while the run is active and on
  status change. When the event lands, `useRunArtifacts` can append instead of poll (small change).
- **shiki syntax highlighting deferred to 07-10.** `CodeBlock` is plain monospace + wrap; adding
  shiki now would bloat the bundle before the code-splitting pass. Markdown/mermaid — the visually
  important renderers — are in.
- **CSV/text virtualization deferred** (rows capped at 500 with a note); fine at local single-user
  scale, revisited in the 07-10 perf pass with the mermaid/Recharts split.
- **mermaid is a large dep** (pulls cytoscape/katex/dagre) — mitigated by the **dynamic import** so
  it only loads when a mermaid document is previewed. `npm audit` flags transitive advisories in its
  tree; not auto-fixed (`--force` would break) — acceptable for a local single-user app, flagged.
- **Benign Radix "DialogContent missing Description"** console warning on the sheet — consistent
  with existing drawers/dialogs; non-failing.
- MarkdownView also back-fills the 07-08 assistant-text slot conceptually, but the conversation
  bubble was intentionally left as plain pre-wrap to avoid re-touching 07-08 in this phase.

---

## 10. Next

07-10 (Testing / CI / rollout) — MSW contract fixtures, Playwright smoke (incl. approve-a-gate),
CI (lint/typecheck/test/build + stale-bundle guard), route-level **code-splitting** (mermaid is
already split; add Recharts + shiki), then the **cutover**: repoint the served bundle to the new
app, delete the interim files, rebuild + commit `static/`.
