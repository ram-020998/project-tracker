# 26-08 — Memory Management UI & curation API (visual browse, edit, and an Obsidian-style memory graph)

> **Status:** 📋 DRAFT · **Repos:** genesis (curation API + web) · **Depends on:** 26-01 (store/graph + new provenance columns), 26-02 (embedder for manual-add embedding), 26-05 (retrieval/ranking reuse) · **Interacts with:** 26-04 (maintenance must respect human curation) · **Proposed ADRs:** ADR-053 (human curation is authoritative) + an **extension note to ADR-027** (graph-viz lib) + **ADR-049** (IA placement)
> **Goal:** Let users **see, explore, and edit** their memory through a **rich, standard, accessible** UI — a **list/table
> workbench**, a **detail/inspector editor**, a **review queue** for newly-formed memories, and, as the centerpiece, an
> **Obsidian-like force-directed memory graph** of entities + relationships (and more: bi-temporal time-scrub, community
> coloring, importance weighting, local-graph focus). Human edits are **authoritative** and **protected from the nightly
> "dreaming"**; the **agent-facing `genesis-memory` MCP stays strictly read-only** (curation is browser-only).

## 1. Principles (the "very standard, very good UX" bar)
- **Reuse the design system, don't reinvent** (ADR-027): design tokens (never raw palette), `shared/ui/**` primitives, the
  Settings **master-detail** pattern (`ResourceManager`/`ResourceFormDialog`/`ConfirmDialog`), TanStack Query **hooks** →
  `lib/api/*` → typed client (`/api` prepend), Zustand only for ephemeral view state, feature-folder structure
  (`web/src/features/memory/**`), and **accessibility as a requirement** (labels, `aria-*`, keyboard, **jest-axe green**).
- **Three coordinated views, one mental model** (industry-standard for knowledge tools — Obsidian, Logseq, Zep's graph
  explorer): **Graph** (explore) ⇄ **List/Table** (work) ⇄ **Inspector** (edit), kept in sync via a shared selection + filter
  state. A **review queue** for curation.
- **Human curation is authoritative + safe:** every edit is **bi-temporal** (edit = supersede, history kept), **protected
  memories are exempt from auto-maintenance**, and destructive actions are confirmed. The **write API is browser-only** — the
  agent's memory MCP remains read-only (ADR-031/045 intact).

## 2. Data-model additions (folded into 26-01 `mm0001`)
Add to `memories` (and mirror on `memory_relationships` where sensible):
```
origin         TEXT NOT NULL DEFAULT 'consolidation'  -- 'consolidation'|'reflection'|'user'   (already partly in 26-01; extend values)
pinned         INTEGER NOT NULL DEFAULT 0             -- user-pinned: always retrievable, never auto-forgotten
protected      INTEGER NOT NULL DEFAULT 0             -- user-curated: exempt from auto merge/decay/invalidate
user_verified  INTEGER NOT NULL DEFAULT 0             -- user reviewed/approved (a trust signal + a ranking boost)
confidence     REAL                                   -- model confidence at write (0..1); user edits set high/verified
review_status  TEXT NOT NULL DEFAULT 'approved'       -- 'pending'|'approved'|'discarded'  (the review queue)
edited_by      TEXT                                   -- username of the last human editor (provenance)
INDEX(review_status), INDEX(pinned), INDEX(protected)
```
- **`review_status='pending'`** is set by the consolidation write path when curation-before-live is enabled (§6); otherwise new
  memories are `approved` (auto-live) and the queue is used for spot-curation. (Toggle in 26-06 config.)
- These are additive to 26-01's schema (no new migration if 26-01 ships after this is agreed; else a follow-on `mm0002`).

## 3. Curation API (`genesis/api/memory.py`) — human write, browser-only
All under `/api` (ADR-028); **not** exposed to the agent/MCP. Writes go to `memory.db` via the store (sync route handlers in the
threadpool → `tx()` + WAL; atomic per the §7 secret-write discipline).

**Reads (drive the three views):**
- `GET /api/memory` — list/search/filter: `?scope&owner&types&entity_ref&query&pinned&review_status&include_invalidated&page`.
- `GET /api/memory/{id}` — full detail incl. **version history** (bi-temporal chain) + provenance (source session link).
- `GET /api/memory/graph` — the graph payload: `{nodes:[entities(+optional memory nodes)], edges:[relationships,
  entity-links, memory-links]}` with `?scope&owner&entity_ref&depth&at(=timestamp)&include_invalidated&community` — server-side
  scoped/filtered so the client never over-fetches; supports **local graph** (`entity_ref` + `depth`) and **point-in-time**
  (`at`).
- `GET /api/memory/entities` / `GET /api/memory/entities/{id}` / `GET /api/memory/relationships`.
- `GET /api/memory/review` — the pending queue.

**Writes (curation):**
- `POST /api/memory` — **manual add** (text/type/scope/entities/tags → embed via the Embedder → store; `origin='user'`,
  `user_verified=1`).
- `PATCH /api/memory/{id}` — edit text/summary/importance/type/scope/tags/entity-links → **supersede** (new version;
  `origin='user'`, `edited_by`, bumps `confidence`). Re-scope personal↔shared requires an explicit `confirm_scope_change` flag
  (guarded — moving a personal memory to shared is a visibility change).
- `POST /api/memory/{id}/pin` · `/protect` · `/verify` (+ un-*) — the protection/trust flags.
- `POST /api/memory/{id}/invalidate` · `/archive` — **soft** ("forget", recoverable; bi-temporal close / archived flag).
- `DELETE /api/memory/{id}?hard=true` — **hard delete** (row + vector + links purged) — confirmed; the legitimate user-owns-
  their-memory purge (the umbrella §9 "gated purge" lands here for the human path only).
- **Relationships:** `POST/PATCH/DELETE /api/memory/relationships[/{id}]` — add/edit/delete edges (type/fact/confidence/validity)
  between entities; entity `PATCH` for name/attributes.
- **Review queue:** `POST /api/memory/{id}/approve` · `/discard` · edit-then-approve.
- **Bulk:** `POST /api/memory/bulk` — multi-id archive/tag/pin/verify.

Every write records `edited_by = memory_owner_username` (26-06) and preserves history (supersede, not overwrite) — except
`hard=true`.

## 4. Web surfaces (`web/src/features/memory/**`)
**IA (proposed — extends ADR-049):** a **first-class "Memory" workspace** (its own route; primary-nav or a prominent Settings
zone — decision §8.1) reached at `/memory`, PLUS two **contextual, scoped reuses** of the same components:
- **Application detail → "Memory" tab** — shared memory + graph **scoped to that app's entities** (sits beside Business Map /
  Overview / Syncs / Features). This is the entity-anchored shared view, in context.
- **Settings → "Your Memory"** — **personal** memory for the configured named user (preferences/rules/habits), editable.

The `/memory` workspace layout (`SplitPane`, master-detail, standard):

### 4.1 Graph view (the centerpiece — Obsidian-like, and more)
- **Force-directed** graph of **entities** (nodes) linked by **relationships** (edges); optional overlay of **memory nodes**
  linked to their entities and to each other (A-MEM `memory_links`) — toggle "show memories".
- **Obsidian-parity interactions:** zoom/pan, drag nodes, **hover → highlight neighbors + dim the rest**, **click → open the
  Inspector** for that node, **double-click → "local graph"** (n-hop neighborhood of the node; a depth slider), a **search box**
  that locates/filters nodes, and a **filters panel** (scope, memory type, entity kind, tags).
- **Richer than Obsidian:**
  - **Bi-temporal time-scrubber** — a timeline slider that renders the graph **as of a chosen date** (`?at=`) and can **animate
    how memory evolved** (invalidated edges fade out); a toggle to **show invalidated/archived** (history) in muted styling.
  - **Community coloring** — color/cluster by `memory_communities` (26-04); **node size by importance/degree**; **edge thickness
    by confidence**.
  - **Scope lensing** — personal vs shared as distinct visual channels; a "focus entity" pin (like Zep's central-node rerank).
- **Rendering/perf (standard + ADR-027-conscious):** a **force-graph library** rendered on **canvas/WebGL** for smooth large
  graphs, **lazy-loaded into its own chunk** (§7 "keep heavy libs lazy"). **Recommended:** `react-force-graph-2d` (d3-force +
  canvas — the closest to Obsidian's feel) or `cytoscape.js` (`fcose` layout) if we want built-in graph analytics. This is a
  **new dependency → an ADR-027 stack-extension decision** (§8.2) — the curated Business Map keeps React Flow + dagre (a
  *designed* layout); the memory graph is *exploratory/organic* → a force sim is the right, standard tool. Progressive
  expansion + a node cap keep it responsive.

### 4.2 List / table workbench
- Virtualized, searchable, filterable table (scope · type · entity · importance · pinned · verified · updated · source session),
  sortable, with **bulk select** → archive/tag/pin/verify. Row → opens the Inspector. Full-text search hits FTS5; semantic
  "find similar" reuses 26-05 retrieval.

### 4.3 Inspector / editor (side drawer)
- Edit **text/summary** (markdown editor — reuse the existing renderer), **importance** slider, **type** select, **scope** toggle
  (with the confirm-guard), **tags** (chips), **entity links** (add/remove via an entity picker), **relationships** (edit/add/
  delete edges from this entity), **pin/protect/verify** toggles, and a **provenance block** (origin badge, source-session
  deep-link, `edited_by`, created/updated). A **version-history** accordion shows the bi-temporal chain (prior versions,
  read-only). Actions: **Forget (soft)**, **Delete permanently** (confirm), **Invalidate**.

### 4.4 Review queue
- A card stream of `review_status='pending'` memories (when curation-before-live is on) or recently-consolidated ones: each card
  shows the memory, its scope/type/entities, and the **cited source session**; one-click **Approve / Edit-then-approve /
  Discard / Merge-into-existing** (merge reuses the reconcile primitives). Keyboard-driven (j/k/a/d) for fast triage — a standard
  review UX (mirrors how the app reviews specs).

## 5. Interaction with the nightly "dreaming" (26-04) — the guardrail
- The `memory-maintenance` workflow **skips `protected` and `pinned` and `origin='user'` and `user_verified` memories** for
  auto-merge, decay/forget, and auto-invalidation. It may *suggest* changes (surface them in the review queue) but never
  overrides human curation. (This rule is added to 26-04.)
- User edits are **higher trust** in retrieval (26-05): `user_verified`/`pinned` get a ranking boost; `pinned` is always eligible.

## 6. Files & tests
- **New (genesis):** `genesis/api/memory.py` (curation endpoints) + store write methods used by it (edit/supersede/pin/protect/
  verify/hard-delete/relationship CRUD/review) added to 26-01's `MemoryStore`; the 26-01 schema columns (§2).
- **New (web):** `web/src/features/memory/**` — `MemoryWorkspace` (SplitPane), `MemoryGraph` (lazy force-graph chunk) +
  `graph.ts` (pure node/edge fold + layout config, unit-tested), `MemoryList`, `MemoryInspector`, `ReviewQueue`, `hooks.ts`,
  `lib/api/memory.ts`, `types/memory.ts`; the Application-detail **Memory tab** + Settings **Your Memory** reuses. `web/static`
  rebuilt + committed (stale-bundle guard).
- **Tests:** API contract + guard tests (writes are browser-only; hard-delete confirmed; re-scope guarded; edits supersede +
  preserve history; protected/pinned respected). Pure `graph.ts` fold units (entities+edges→graph payload; local-graph depth;
  point-in-time filter). RTL + **jest-axe** on the workspace, inspector, list, review queue. A maintenance test asserting
  protected/user/pinned memories are skipped by 26-04. The heavy graph lib is lazy (bundle-guard/lazy-chunk test if we assert it).

## 7. Acceptance criteria
1. Users can **see** memory in three synced views (graph/list/inspector) + a review queue, **edit** every attribute, add/edit/
   delete relationships, manually add memories, pin/protect/verify, soft-forget, and hard-delete — all through a **rich,
   token-based, accessible** UI (jest-axe green).
2. The **memory graph** is an Obsidian-style force-directed explorer with hover-highlight, local-graph focus, search/filters, and
   the richer extras (time-scrub, community coloring, importance/confidence weighting), lazy-loaded.
3. Human edits are **bi-temporal + authoritative**; `memory-maintenance` **never overrides** protected/pinned/user memories.
4. The **agent-facing `genesis-memory` MCP stays read-only**; curation is browser-only.
5. genesis pytest + ruff green; web lint/tsc/vitest + jest-axe green; `web/static` rebuilt/committed.

## 8. Decisions to confirm at build
1. **IA placement** — a **primary-nav "Memory"** entry (richest, my lean) vs a Settings-zone workspace, plus the per-app tab +
   Settings personal panel either way (extends ADR-049).
2. **Graph library** — `react-force-graph-2d` (Obsidian-feel, canvas, lean; my lean) vs `cytoscape.js`/`fcose` (analytics) — an
   ADR-027 stack extension, lazy-loaded regardless.
3. **Curation-before-live** — do new consolidated memories land `pending` (must be approved) or `approved` (auto-live, queue used
   for spot-curation)? My lean: **auto-live + a review queue for spot-curation** (less friction; the maintenance job + protection
   flags keep quality), with a config toggle (26-06) to require approval.

## 9. Out of scope
- Multi-user sharing/permissions on memories (ADR-026 multi-user track); collaborative/real-time graph editing; a 3D graph;
  exposing any write tool to the agent (the MCP stays read-only).
