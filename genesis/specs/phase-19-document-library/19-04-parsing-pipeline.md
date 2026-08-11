# 19-04 — Parsing pipeline (documents → structured, LLM-ready content)

> **Status:** DRAFT — spec only. **Repo:** genesis. Can proceed in parallel with 19-02 after the spike (uses the `gws_client`
> seam once available; binary parsing is independent).

## Goal
Convert every ingested document into a **canonical Markdown body** (+ **JSON tables** for spreadsheets, + optional
heading-scoped **sections**), stored as **latest-version-only** artifacts on disk, with a `content_hash` and honest error
status. This is the content that feeds the KB/evidence pack.

## Two source classes
1. **Google-native (Docs / Sheets / Slides)** — via the `gws_client` **export** (no extra dependency):
   - Docs → Markdown (or HTML→MD if MD export unavailable).
   - Sheets → CSV/JSON **per tab** → `tables.json` (keep structure; don't flatten to prose) + a Markdown rendering for the body.
   - Slides → text/Markdown (title + bullets per slide).
2. **Binary uploads (PDF / DOCX / XLSX)** and text (MD/TXT/CSV) — a **server-side converter to Markdown**.
   - **Dependency decision (made here, pinned):** evaluate **MarkItDown** (single dep; PDF/Word/Excel/PPT → LLM-oriented MD)
     vs à-la-carte **`pypdf`** (PDF text) + **`python-docx`** (DOCX) + **`openpyxl`** (XLSX → per-sheet JSON + MD). Recommend
     MarkItDown for breadth + `openpyxl` where we want clean spreadsheet JSON. **Pin exact versions** (supply-chain caution);
     record the choice + rationale in the progress doc. MD/TXT pass through; CSV → `tables.json` + MD table.

## Output contract (`parse_document(source) -> ParsedDocument`)
- `content_md: str` (canonical body), `tables: list[dict] | None`, `sections: list[{ordinal, heading, text}] | None`,
  `content_hash: str`, `title`, `mime_type`, `byte_size`.
- Written by the caller (workflow/connector) via `DocumentStore.set_content`/`set_sections` to
  `~/.genesis/kb-documents/<id>/latest.md` (+ `tables.json`), **overwriting** the prior latest.
- On failure: raise/return an error → `status=error` + `parse_error`; **never** a fabricated body.

## Execution
- Runs **off the event loop** (in the `sync-documents` worker subprocess, ADR-012; or `asyncio.to_thread` for the
  upload path) — binary parsing is CPU/IO heavy. Bulk output → files (ADR-010/018); only pointers/hash reach `genesis.db`.
- Size guard + extension allowlist consistent with ADR-035 (`.pdf .docx .xlsx .md .txt .csv` + Google-native mime types).

## Tests
- Golden fixtures per type: a small PDF, DOCX, XLSX (multi-tab), CSV, MD, and a mocked `gws` Docs/Sheets export → assert MD +
  `tables.json` + sections + a stable `content_hash`. Parse-failure → `status=error` (no fabricated content). Mirror **real**
  export shapes in stubs (the "stub hid the contract" lesson).

## Exit criteria
All six source types produce a canonical `latest.md` (+ `tables.json` where tabular) + `content_hash`; dependency chosen +
pinned; errors surfaced honestly.
