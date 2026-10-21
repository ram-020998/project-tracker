# Phase 48 — The Object Wiki in the application page

> **Status:** 🟡 **SPEC-DRAFTED 2026-10-21** (awaiting build sign-off). · **Author:** genesis-spec agent.
> Sub-specs: `phase-48-object-wiki-ui/48-01..48-05`. Findings (code facts + every decision): `48-01-findings.md`.
> Repo: **genesis** only (backend + web). No new ADR (applies ADR-070/071/027/055/028). No migration (DB stays v24).
> Also the first real phase run end to end with the Phase-47 agent system (pilot).

## 1. Why this phase exists

The Object Wiki (ADR-070, Phase 42) records, per Appian object, *what changed and why* — a business and a technical
description per change, the story, the author, the version — and is shared with teammates through the Hub. But
**nothing in the Genesis UI shows it**: no API reads it and no web code references it (48-01 §2.2). The history is
written on every implementation and then is invisible.

## 2. Goal

1. A new **Object Wiki** tab on the application page, right after **Overview**: a searchable, filterable, sortable
   table of the application's documented objects.
2. Clicking an object opens its **wiki page** (own URL): the current summary and the object's full change history as
   a timeline, switchable between the business view, the technical view, or both.
3. Standard, consistent UI: existing tokens, primitives and layouts only (ADR-027/055), accessible (jest-axe).

## 3. Decisions (locked with the user, 2026-10-21 — detail and rationale in `48-01-findings.md` §3)

| # | Decision |
|---|---|
| D1 | Object page at its own URL `/applications/:appUuid/wiki/:objectUuid`; the application tabs become URL-addressable (`?tab=`) so Back returns to the Object Wiki tab. |
| D2 | Documents-style table: Object · Type · Summary · Changes · Last change · Last changed by; search + Type + Change filters; default sort newest change first; sortable headers. |
| D3 | Object page: header + metadata line + Current summary + newest-first History timeline; a Business / Technical / Both switch. |
| D4 | Name/type from the current KB row when present, else the page's own values; backend normalizes the type to a canonical key; one shared web object-type map (label + icon). |
| D5 | No cross-links this phase (story → wiki, ⌘K) — backlog `specs/backlog/wiki-story-cross-link.md`. |
| D6 | Story references resolved server-side to the canonical story page (ADR-071); unresolved → plain key. |
| D7 | Tab "Object Wiki"; all rows returned, client-side search/filter/sort; refetch on focus; deprecated shown; genesis-only minor v0.78.0. |

## 4. Current state (code-grounded — full detail in `48-01-findings.md` §2)

| Area | Today | File(s) |
|---|---|---|
| Wiki data | `wiki_object_pages` + append-only `wiki_object_entries` (m0021); pulled rows land in the same tables | `genesis/db/migrations/m0021_object_wiki.py`, `genesis/collab/service.py:117-125` |
| Wiki store | `ObjectWikiStore` (list pages by app, entries oldest → newest); used only by workflow nodes | `genesis/kb/object_wiki.py`, `genesis/runtime/context.py:157` |
| Wiki API / UI | **none** | — |
| App page tabs | Radix `Tabs`, local state, default Business Map | `genesis/web/src/features/applications/ApplicationDetail.tsx:92-107` |
| List/detail patterns | `DocumentTable` + `LibraryPage` toolbar; `DocumentDetailPage`; `ActivityFeed` | `genesis/web/src/features/library/**`, `genesis/web/src/features/features/ActivityFeed.tsx` |
| Story page | `/applications/:appUuid/stories/:storyId` (local int id) | `genesis/web/src/app/router.tsx:65`, `genesis/api/workbench.py:400-409` |

## 5. Design overview

```
genesis.db ── wiki_object_pages ⟕ kb_objects (current row) ⟕ entry aggregates
   │                                         (ObjectWikiStore read methods — 48-02)
   ▼
GET /api/applications/{app}/wiki                    → { app_uuid, objects: [WikiObjectRow] }
GET /api/applications/{app}/wiki/{object_uuid}      → { object: WikiObjectRow, entries: [WikiEntry] }  (newest first)
   │
   ▼
/applications/:appUuid?tab=object-wiki   ObjectWikiTab  (table + toolbar; client-side search/filter/sort)
/applications/:appUuid/wiki/:objectUuid  ObjectWikiPage (header · metadata · summary · History timeline)
```

| Building block | Sub-spec |
|---|---|
| Findings + decisions | 48-01 |
| Store read methods, type normalization, story resolution, the two endpoints | 48-02 |
| URL tabs, the Object Wiki tab, the object page, the shared object-type map | 48-03 |
| Review, hardening, live acceptance | 48-04 |
| Release + docs write-back | 48-05 |

## 6. Session plan

S1 = 48-02 (backend, genesis-dev) → S2 = 48-03 (web, genesis-dev; reads 48-02 As built) → S3 = 48-04 (genesis-review)
→ S4 = 48-05 (genesis-release, then genesis-docs).

## 7. Sub-phase ledger

| Sub-phase | Repo | Content |
|---|---|---|
| 48-01 | project-tracker | Findings, decisions D1–D7 |
| 48-02 | genesis | API: `ObjectWikiStore.list_objects` / `get_object`, `normalize_object_type`, story resolution, `GET …/wiki[/{object_uuid}]` + tests |
| 48-03 | genesis (web) | URL-addressable app tabs, Object Wiki tab, object page, shared object-type map, hooks/types/keys + tests, `web/static` |
| 48-04 | genesis | Independent review + gates + live acceptance |
| 48-05 | genesis, project-tracker | Release genesis v0.78.0 + deploy + docs write-back |

## 8. Release plan

genesis **v0.78.0** only (minor: new read API + UI). genesis-core v0.9.8, kiro-agent-sdk v0.7.1,
genesis-appian-parser v0.3.0 pins unchanged; genesis-workflows untouched (its dev pin may move later, not required).
No migration (DB v24). Detail: 48-05.

## 9. Scope

- **In:** the two read-only endpoints; the tab; the object page; URL-addressable application tabs; the shared
  object-type map; tests (pytest, Vitest + jest-axe).
- **Out:** writing/editing the wiki; agents reading the wiki (backlog `wiki-as-agent-memory.md`); Hub contract or
  Hub site changes; object code (ADR-037); re-pointing other screens (Overview) to the new type map.
- **Deferred:** story → wiki "Objects changed" link and ⌘K search over wiki objects (backlog
  `wiki-story-cross-link.md`).

## 10. Defaults

Tab id `object-wiki`; default app tab stays Business Map; History newest first; switch default **Both**; deprecated
objects shown; no pagination (tens–hundreds of objects per app).

## 11. Risks

| Risk | Mitigation |
|---|---|
| Pulled pages have no `latest_entry_id` (local-only) → blank "last change" | Derive latest from entries in SQL (48-02 §3); test with a pulled-shape page |
| Hub date strings in another format (L-084) | Sort by `created_at, id`; web parses with `Date`; test a `Z`-suffixed and a `+00:00` value |
| Inconsistent `object_type` values | One backend normalizer, table-driven tests incl. real variants (48-01 §2.4) |
| URL tabs change the app page's behaviour | Unknown/absent `?tab` → Business Map; `replace` navigation (no history spam); tests for each tab |

## 12. ADR summaries

No new ADR. Applies: **ADR-070** (wiki is local-first, append-only; this phase only reads it), **ADR-071** (story links go
to the one canonical story page), **ADR-027/055** (existing stack, tokens, primitives), **ADR-028** (`/api`),
**ADR-037** (no code shown or stored).

## Context manifest

```toml
areas    = ["stories-workbench", "api", "web-shell"]
adrs     = ["ADR-027", "ADR-028", "ADR-037", "ADR-055", "ADR-070", "ADR-071"]
lessons  = ["L-011", "L-039", "L-083", "L-084"]
docs     = ["tracker:specs/phase-48-object-wiki-ui/48-01-findings.md"]
code     = ["genesis/genesis/kb/object_wiki.py", "genesis/genesis/api/object_wiki.py",
            "genesis/web/src/features/object-wiki/**", "genesis/web/src/features/applications/ApplicationDetail.tsx"]
upstream = []
```
