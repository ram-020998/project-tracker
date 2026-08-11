# 19-07 — Web: global Document Library page + per-app Business Artifacts tab

> **Status:** ✅ **CODE-COMPLETE — UNCOMMITTED** (commit at 19-08 per the user). Global **Document Library** page
> (`features/library/`), a per-app **Business Artifacts** tab, and a **Settings→CLI Google Workspace connector card**;
> `lib/api/documents.ts` + `configApi` gws methods + query keys; Sidebar entry + `/documents` routes; reuses the 07-09
> `DocumentPreview`/`MarkdownView`. Verified: **tsc clean, eslint 0 errors, 138 Vitest (17 files) incl. jest-axe a11y,
> `npm run build` OK** (`web/static/` rebuilt, uncommitted). See `progress/phase-19-document-library.md`. **Repo:** genesis
> (`web/`). **Depends on:** 19-05 (API), 19-02 (connector auth routes). Frontend-only changes still ship a genesis release.

## Goal
Two surfaces for the library + the connector control, reusing existing primitives/tokens (ADR-027) and the 07-09
`DocumentPreview` renderer.

## A. Global "Document Library" page (new Sidebar entry `features/documents`)
- **List:** all documents — title, source (upload / Drive icon + link), **linked apps** (chips), status
  (`parsed`/`stale`/`error`/`source_missing`), last-synced, byte size. Filter by app / source / status; search box.
- **Add:** dialog with **Upload** (FileDropList, ADR-035 multipart) or **Paste Google Drive link**. On add → optionally link to
  one or more apps.
- **Open:** rendered Markdown via `DocumentPreview` (md/tables); show metadata + linked apps.
- **Actions:** **Sync now** (per-doc + a library-wide sync), manage links (link/unlink apps), **remove from library**
  (confirm; removes artifacts).

## B. Per-app "Business Artifacts" tab (`features/applications` detail)
- Add the tab to the detail set → **Business Map · Overview · Syncs · Releases · Business Artifacts**.
- Shows the app's **linked** documents (same row shape). **Add documents** dialog: **Upload** / **Paste Drive link** / **Pick
  from library** (link an existing document without re-adding — reinforces dedup). Per-row: status, **Sync now**, **Unlink**
  (removes the app link only; the document stays in the library).

## C. Settings → CLI — Google Workspace connector card
- Managed-native install status + version, install/rollback, **Connect / Reconnect** (opens the `gws` sign-in URL from
  `POST /api/config/gws/auth/login`), connection status, configured **read-only** scopes. "Reconnect" prompt on auth error.

## Client
- `lib/api/documents.ts` (+ `postForm` multipart for upload); TanStack Query keys/hooks; wire the not-installed **409** to a
  clear "install the sync-documents workflow" empty-state (17-06 lesson).
- Sidebar entry; route `/documents` + `/documents/:id`.

## Tests
- Vitest + MSW: list/add(upload)/add(drive-link)/link/unlink/sync/remove; app tab shows linked docs + pick-from-library;
  connector card connect flow (mock auth-URL); **jest-axe** on the new dialogs/pages. `npm run build` + commit `web/static/`.

## Exit criteria
A user can add a document (upload or Drive link) from the app's Business Artifacts tab or the global Library, see it parsed,
link/unlink across apps (single stored copy), sync it, and connect Google Workspace from Settings → CLI. a11y clean, bundle
rebuilt.
