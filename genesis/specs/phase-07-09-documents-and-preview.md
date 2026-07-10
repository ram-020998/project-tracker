# Phase 7.9 — Documents & Artifact Preview

> **Goal:** Surface the documents a workflow produces as first-class output. Show the
> run's artifacts in a dedicated panel, and let the user click any document to preview
> its rendered contents (markdown, JSON, mermaid, CSV, text) inline — plus download.
> This closes the loop: the user not only watches the work happen but reads what it
> produced.

Prereq: 07-02 (artifact listing with media_type/preview_kind, content, download),
07-03 (design system: MarkdownView, CodeBlock, JsonTree, Drawer), 07-07 (Run Detail
layout). Feature dirs: `features/run-detail/components/docs/` + shared
`features/documents/` renderers. Route: `/runs/:runId/docs/:docName`.

---

## 1. Objective & user story

"As the workflow runs (and after it finishes), I see the documents it's creating on
the side. I click `erd-input.json` or `domains.md` and read it rendered nicely,
right there — and download it if I want."

---

## 2. Documents drawer (Run Detail right region)

- Collapsible right **Drawer** (toggle in the Run Detail header, 07-07).
- **List** from `GET /runs/{id}/artifacts` (extended: `name`, `bytes`, `media_type`,
  `preview_kind`). Each row: file icon by kind, name, size, RelativeTime (if
  available), a preview affordance, and a download icon.
- **Live updates**: new documents appear as `artifact.written` events arrive (append
  to the list; subtle "new" marker). The list is also refetched on run status change.
- **Grouping/sorting**: sort by recent/name; optionally group by producing node
  (from `artifact.written.node` if present).
- **Empty**: "No documents yet — they'll appear here as the workflow produces them."

---

## 3. Preview surface

Clicking a document opens a preview (deep-linkable `/runs/:runId/docs/:docName`).
Presentation: a **large right sheet** or centered **Dialog** (choose the sheet for
side-by-side reading with the graph; configurable). Fetches
`GET /runs/{id}/artifacts/{name}?mode=preview` (then `full` on demand).

### 3.1 Renderer by `preview_kind`

| preview_kind | Renderer |
|---|---|
| `markdown` | `MarkdownView` (react-markdown + remark-gfm; embedded ```mermaid``` fences rendered) |
| `mermaid` | Mermaid diagram render (with source toggle) |
| `json` | `JsonTree` (collapsible) + raw toggle (shiki) |
| `csv` | Parsed table (virtualized; header row; column sort) with raw toggle |
| `text` / logs | `CodeBlock` (shiki, language auto/plain), wrap toggle |
| `binary` | No inline preview → icon + size + Download only |

### 3.2 Preview UX

- Header: name, kind badge, size, `truncated` indicator when preview was capped,
  actions (Download, Copy, Open raw, Load full).
- **Truncation**: if `truncated`, show a banner "Showing first 256KB — Load full"
  → refetches `mode=full` (guarded by max size; very large → download only).
- **Loading/error**: skeleton; error with retry; 404 → "document no longer available"
  (e.g. pruned by retention).
- **Large/virtualized**: CSV/text virtualization; mermaid render guarded with error
  boundary (invalid diagram → show source).
- **Security**: name is path-safe on the server (07-02 §8.2); the client never
  constructs paths beyond the artifact name.

---

## 4. Cross-links

- Gate `context_refs` (07-08 §4.1) and node I-O docs (07-08 §2) link directly into
  this preview (open the doc sheet) so review-at-a-gate is one click.
- The final result document(s) are highlighted on a terminal run (e.g. a "Result"
  badge on `result.json`/`erd-input.json`).

---

## 5. Reusable document renderers

The renderers live in `features/documents/` and are **reused** by:
- Run Detail documents drawer (this doc),
- gate/node context previews (07-08),
- potentially future doc-centric screens.

They accept `{name, media_type, preview_kind, content, truncated}` and are pure
(testable in isolation).

---

## 6. Data & hooks

- `useRunArtifacts(runId)` — list; refetch on status change; append on
  `artifact.written`.
- `useArtifactContent(runId, name, mode)` — content fetch (preview/full), cached by
  `['run',id,'artifact',name,mode]`.
- `useSelectedDoc()` — route-driven (`/docs/:docName`).

---

## 7. Definition of done

1. Documents drawer lists a run's artifacts with kind/size, updates live as
   `artifact.written` events arrive, and links from gate/node contexts.
2. Clicking a document previews it rendered by kind (markdown/mermaid/json/csv/text),
   with truncation handling, download, copy, and raw toggle; deep-linkable.
3. Binary/oversized files degrade to download-only gracefully; 404/pruned handled.
4. Renderers are reusable and unit-tested with representative fixtures for each kind.
5. States (loading/empty/error/truncated) designed; a11y (focus in sheet, escape to
   close) verified.
