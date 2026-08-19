# Per-sheet spreadsheet viewer (2026-08-19) — genesis v0.51.1

A follow-up to the v0.50.2 document-viewer fix: multi-tab Excel documents were flattened into one
Markdown page. The viewer now renders the parser's structured `tables.json` as an **Excel-like grid**
(sheet-tab strip + paged grid), so each worksheet shows separately.

## What shipped
- **Backend** (`genesis/api/documents.py`): `GET /documents/{id}/tables` serves the parser's `tables.json`
  as `{sheets: [{sheet, rows}]}`, read lazily from the row's `tables_path`. Non-tabular docs → `{sheets: []}`;
  a corrupt/unreadable file degrades to `[]` (never a 500); unknown doc → 404. +`test_document_tables_endpoint`.
- **Frontend** (`web/features/library`):
  - `documentView.ts` — a **third view mode `sheets`**; `defaultDocViewMode({hasTables, contentLength})` defaults a
    doc **with a `tables_path` to Sheets** (else the v0.50.2 large→source / small→rendered rule); `viewModeOptions`
    adds a Sheets tab only when tabular.
  - `SpreadsheetView.tsx` — a **sheet-tab strip** (one tab per Excel worksheet, horizontally scrollable) + a
    **paged grid** (100 rows/page) with **column letters** (A, B, …, AA), **1-based row numbers**, and horizontal
    scroll. **No header-row assumption** (real exports have blank leading rows) — a raw grid with spreadsheet
    coordinates. Pure helpers in `spreadsheet.ts` (`columnLabel`/`sheetColumnCount`/`pageCount`/`pageRange`/
    `sheetLabel`/`cellText`), separately unit-tested.
  - `documentsApi.tables` + `useDocumentTables(id, enabled)` (lazy — fetched only when Sheets mode is active) +
    `qk.documents.tables`; `DocumentTables`/`DocumentSheet`/`CellValue` types.
  - `DocumentDetailPage` split into a `DocumentBody` sub-component (so the mode state + lazy tables query are
    unconditional hooks) offering **Sheets | Rendered | Source**.

## Data shape (verified on doc #4)
`tables.json` = a JSON **list of `{sheet, rows}`** — one entry per Excel tab (doc #4 had 18 tabs); `rows` is a
ragged 2D array of cells (openpyxl yields strings/numbers/bools/null). `content_md` already delimited tabs with
`## <SheetName>` headings, but rendered them all on one page — that's the flattening the Sheets mode replaces.

## Gates
Backend **574 → 575** pytest + ruff clean. Web **168 → 179** vitest (+11: `spreadsheet.test.ts`,
`SpreadsheetView.test.tsx`, `document-view-mode.test.ts` updated), lint 0 errors (18 benign react-refresh
warnings), tsc clean, build green, `web/static` rebuilt. **genesis v0.51.1** (feature; genesis-core/workflows
unchanged). Commit `938af9b`, tag **v0.51.1**.

## Notes
- A spreadsheet doc still keeps `content_md` (Rendered/Source remain available); Sheets is just the default.
- Paging (100/page) is dep-free; true windowed virtualization (react-window) was not needed and would add a dep.
- Live acceptance: reopen `/documents/4` after upgrading — it opens in Sheets with 18 tabs, each paged.
