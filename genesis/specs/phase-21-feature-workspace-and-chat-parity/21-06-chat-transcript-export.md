# 21-06 — Chat transcript export (Markdown-first)

> **Status:** 📝 DRAFT · **Phase:** 21 · **Repo:** genesis · **Depends on:** — · Applies to **both** the main chat + builder

## Goal

Export the **complete** chat conversation as **Markdown** (server-side; **includes tool calls + thinking**), in both the main
Chat page and the spec builder. **PDF is optional / stretch** via **browser print-to-PDF** (a print stylesheet) — **no
server-side PDF dependency** (per the resolved umbrella decision).

## Current state (verified)

- No chat export today (only the *spec* has `export.md` via `markdownify`).
- `chat_messages` persists per-turn `events` (JSON of folded thoughts/tool items) + `content` + `role` + `usage`; the web folds
  them with `buildTranscript`/`Conversation`. The backend has everything needed to render a full transcript server-side.

## Changes

### Backend — `GET /api/chat/sessions/{id}/export.md`
- Build a Markdown document from the session's ordered messages:
  - Header: session title, created/updated, mode, model (if known), total credits.
  - Per message: **User** / **Assistant** / **System** heading; assistant turns include **thinking** and **tool calls**
    (name + params + result summary) rendered from the stored `events`, then the answer; per-turn credits footer.
- Include everything (tools + thinking) — this is a faithful transcript, not the cleaned view.
- `Content-Disposition: attachment; filename="<slug>-<id>.md"`. Pure string building (no new deps).

### Frontend — export control (both chrome variants)
- A small **Export** action in the chat chrome (main chat header + the spec builder action bar): **Download .md** (links to the
  endpoint) and an optional **Print / Save as PDF** (opens the browser print dialog against a print-friendly transcript view or
  the downloaded content). MD is the guaranteed path.

## Testing

- **Backend (pytest):** export.md for a seeded session with a user turn + an assistant turn (with a tool call + thinking) →
  contains the headings, the tool call, the thinking, the answer, and the credit footer; empty session → a valid minimal doc.
- **Web (Vitest):** the Export control renders in both chrome variants and points at the endpoint.

## Definition of done

- Full transcript (incl. tools + thinking) downloads as `.md` from both the main chat and the spec builder.
- No new backend dependency; PDF (if shipped) is browser-print only.
- Backend + web gates green; `web/static/` rebuilt + committed.
