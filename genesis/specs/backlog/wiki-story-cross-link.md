# Backlog — Story → Object Wiki cross-link ("Objects changed" on the story Implementation tab)

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-10-21 (Phase 48 spin-off, 48-01 D5). · Depends on Phase 48
> (the Object Wiki tab + object page `/applications/:appUuid/wiki/:objectUuid` and the wiki read API).

## Context
Phase 48 shows the Object Wiki in the application page (a tab + one page per object). The canonical story page
(ADR-071) has an **Implementation** tab that is a master-detail viewer over two documents — the implementation report
(HTML, iframe) and the rollback document (`genesis/web/src/features/workbench/StoryWorkspacePage.tsx:224-262`). The
per-object table exists **only inside the report HTML**, so there is no link from a story to the objects it changed.

## The deferred capability
Add a third rail item **"Objects changed"** to the story's Implementation tab: a compact list built from this story's
wiki entries (object name · type · change-kind badge), each row linking to the object's wiki page — so a user can go
story → object history and back (the wiki page already links entries to their story).

## Shape when picked up
- Backend: a story filter on the Phase 48 wiki read API (entries whose `story_sync_uuid` matches the story's
  `sync_uuid`, else whose `story_key` matches its `key`, scoped to the app) — the same resolution Phase 48 uses in the
  other direction. Read-only; local tables only (ADR-070).
- Web: a rail item + list in `ImplementationTab`, reusing the Phase 48 object-type map and change-kind badge.
- No workflow change (the report HTML is untouched).

## Open questions
- Show the item only when the story has wiki entries, or always with an empty state?
- Also link wiki objects from ⌘K global search (Phase 48 Q5 option B) — same pickup or separate?
