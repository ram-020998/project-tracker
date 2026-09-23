# 42-06 — Object Wiki: collaboration bindings + the Genesis Hub record type

> **Status:** 🟡 DRAFTED. Repo: **genesis** (`collab/service.py` bindings) + the **Appian Genesis Hub** (a new record type, built by the separate write-capable Dev-MCP agent per ADR-064). Implements **ADR-070**; reuses ADR-063/065. Parent: `specs/phase-42-code-implementation.md`. (The local tables + `ObjectWikiStore` are in 42-05.)

## 1. Goal

Make the Object Wiki **local-first + Hub-shared** exactly like features/stories/boards: write local (42-05), publish to the Hub when available, and pull teammates' entries when available — so the Hub aggregates per-object change history across all users, with **no hard Hub dependency** (implementation runs whether or not collaboration is enabled).

## 2. Collaboration bindings (`genesis/collab/service.py`)

- Add two `_BINDINGS` entries (mirroring `story`/`stage_artifact`):
  - **`wiki_page`** — table `wiki_object_pages`; parent = the **global `app_uuid`** (no cross-machine int-FK remap needed — round-trips like `feature`); `published_version` column present.
  - **`wiki_entry`** — table `wiki_object_entries`; parent = `wiki_page` via a `_ParentRef("page_id", "page_sync_uuid", "wiki_object_pages", parent_kind="wiki_page")`; **append-only** (published once; the optional `story_sync_uuid` travels as a plain shared column, resolvable to a local story when present, else left as-is).
- **Publish path:** the `author_wiki` program step (42-04) calls `publish("wiki_page", …)` (lazy, once per object) then `publish("wiki_entry", …)` per new entry — **best-effort** (guarded by `is_enabled()`/`is_available()`; a disabled/unreachable Hub is a no-op, the local write already succeeded). Append-only entries never CAS-conflict.
- **Pull path:** `pull("wiki_page")` + `pull("wiki_entry")` join the standard `pull_all`/`autopull_tick` so teammates' entries appear locally. `_LOCAL_ONLY`/`to_payload` guarantees no machine-local leakage; the read-only mirror rules apply.

## 3. The Genesis Hub record type (Appian-side, ADR-064 additive)

- Freeze a **contract addition** in `specs/phase-36-genesis-hub-appian-app/contract/` for the separate write-capable Dev-MCP agent to build (like the v0.69.0 `on_board` addition, round-trip verified):
  - **`GH Object Wiki Page`** — `sync_uuid` (UUID key) + `version` + `app_uuid` + `object_uuid` + `object_type` + `object_name` + `current_summary` (Long/Extra-Long Text) + attribution (`created_by`/`modified_by`/`owner_username`/`team_uuid`).
  - **`GH Object Wiki Entry`** — `sync_uuid` + `version` + `page_sync_uuid` (parent) + `change_kind` + `business_description` (Extra Long Text 64000) + `technical_description` (Extra Long Text) + `story_key` + `story_sync_uuid` + `is_bugfix` + `change_reason` + `object_version` + attribution + `created_at`.
- Text tiers honored (Text 255 / Long 4000 / Extra Long 64000, ≤3 per record type — the descriptions are Extra Long). The existing Web-API surface (`PUT/GET /records/{kind}`, `/changes`) serves the two new kinds generically — **no new Web API needed** if the kinds plug into the existing generic records endpoints (confirm in the contract). Lossless round-trip is the invariant (a fidelity fixture, 42-08).

## 4. Tests

- Binding tests: `wiki_page`/`wiki_entry` map out/in losslessly (parent `page_id ↔ page_sync_uuid`; append-only entry publishes once; `story_sync_uuid` optional). A guard test: every `_BINDINGS` kind is a real contract record kind (the §7 "permissive local emulator hid the contract" lesson) — the two new kinds included.
- `LocalHubProvider` round-trip for the wiki (publish → pull into a second instance → identical entries).

## 5. Out of scope

Agents reading the wiki as grounding/memory (backlog `wiki-as-agent-memory.md`); a wiki browse/search UI beyond the read-only implementation review surface (a future nicety — the wiki is primarily a shared record + agent-memory seam this phase); enforcing per-team visibility.
