# 31-05 — Jira-importable export (CSV from the canonical backlog)

> **Status:** ✅ SHIPPED (2026-09-04; genesis v0.59.0 + genesis-workflows v0.15.0, CI green). · Part of Phase 31. Repo: **genesis** (backend + a web Export button).

## Purpose

Let the user export the finished breakdown as a **Jira-importable file** — create-new-epics + stories/tasks
with Gherkin acceptance criteria — with no manual re-keying. Deterministic; from the canonical backlog data.

## Source of truth

The canonical `backlog.json` is **embedded** in `breakdown.html` as
`<script type="application/json" id="genesis-backlog">…</script>` (rendered by the workflow's `assemble` node;
kept in sync by the completion-chat steering). The export reads that block from the **current** artifact (the
chat-edited sandbox copy via `_current_stage_html`), so refinements are reflected. Fallback: the run's
`backlog.json` if the embedded block is missing/garbled.

## Endpoint

`GET /features/{id}/stages/feature_breakdown/export.csv` (mirrors the existing `export.md` route) — parse the
embedded JSON → build a Jira-importable CSV → stream as a file download (`Content-Disposition`). Built with the
stdlib `csv` module (and/or the already-pinned `openpyxl` if an `.xlsx` variant is wanted; **no new
dependency**). Jira's classic External-System importer consumes **CSV** and links a hierarchy via
**Issue ID → Parent ID**.

## Column contract (the skill's proven Full-Breakdown/Jira mapping)

| Column | Value |
|---|---|
| **Issue ID** | sequential integer across all epics + stories/tasks |
| **Issue Type** | `Epic` \| `Story` \| `Task` |
| **Summary** | title |
| **Description** | As-a/I-want/So-that + a blank line + the one-line `devNoteRef` (TD pointer) + (if present) a `QUESTIONS:` block |
| **Parent ID** | the epic's Issue ID (empty for epic rows) — the Jira epic↔story link |
| **Acceptance Criteria** | the Gherkin block, newline-separated (empty for Tasks with none) |
| **Labels** | `category` (`nice-to-have`) + inferred labels, comma/space per Jira convention |

Rules: **always create new epics** (epics are rows; no existing-epic-key attach). **No custom-field columns**
(Component/Fix Version/Team/Work Category/… ) — the team maps org-specific fields during Jira's column-mapping
step. Rows ordered epic-then-its-stories (core first, then nice-to-have), matching the GSS sheets.

## Web

An **Export** button in the stage workspace header + the Artifacts tab (visible once the stage has an
artifact) → triggers the `export.csv` download. Disabled while a run is in progress.

## Tests

- Round-trip: a fixture `backlog.json` → export → re-parse the CSV → assert every epic + story/task is present,
  Issue ID/Parent ID linkage is correct (each story's Parent ID = its epic's Issue ID), Issue Types map, Gherkin
  AC survive, Stories have AC + Tasks may not.
- The endpoint reads the embedded JSON from a chat-edited `breakdown.html` (not just the run's `backlog.json`),
  and falls back cleanly when the block is missing.
- Column-completeness assertion (the 7 columns, exact header names) so a drift fails a test.

## Gate

Independent review = SHIP: the CSV imports into Jira as epics + stories/tasks (manually verified — headless-
undrivable; the manual check is in 31-06 notes); deterministic; reads the freshest artifact; no new dependency.
