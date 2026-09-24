# Genesis Hub API — Object Wiki addition (ADR-070, Phase 42-06)

> **Status:** 🟢 FROZEN ADDITION to the v1.0.0 contract — **additive, backward-compatible** (ADR-064
> amendment, exactly like the v0.69.0 `on_board` field addition). It introduces **two new record kinds**
> served by the **existing generic** `/records/{kind}` + `/changes` endpoints — **NO new Web API object is
> required**. Built Appian-side by the separate write-capable Dev-MCP agent; genesis stays read-only against
> Appian (ADR-036/037). The genesis-side binding (`CollaborationService._BINDINGS` `wiki_page`/`wiki_entry`)
> + publish/pull already exist (42-06); this doc is the Hub-side half.
>
> **Lossless sync is the hard invariant** (36-01 §2.0): `local → PUT → Hub → GET → local` reproduces every
> field byte-for-byte (unicode, ordering, empty-vs-null). Fixtures: `./fixtures/object_wiki_page.json`,
> `./fixtures/object_wiki_entry.json`.

---

## 1. What this adds

The **Object Wiki** (ADR-070) is a local-first, Hub-shared, **append-only per-object change ledger**: one
**page** per Appian object, and one immutable **entry** per change (a business + a technical description, the
change kind, the originating story, the object version). **No object source code is ever stored** — the ledger
is descriptions + metadata only (ADR-037 stays true). The Hub aggregates each object's change history across
all teammates, the same publish/pull pattern as `feature`/`story`/`stage_artifact`.

- **Two new `{kind}` values:** `wiki_page` and `wiki_entry` — added to the kinds set of §2 (now 9 record
  kinds). The generic `PUT/GET /records/{kind}/{syncUuid}`, `GET /records/{kind}`, and `/changes` endpoints
  serve them unchanged (§3.2–3.4 semantics apply verbatim: base-version CAS, change-log row, snake_case keys).
- **Two new record types** (Appian-side): **`GH Object Wiki Page`** + **`GH Object Wiki Entry`**, UUID-keyed on
  `sync_uuid`, with record-level security matching the existing kinds (service-account writes; attribution via
  the payload `*_by` fields, not Appian auth).
- **No `GH Story Item`-style child normalization** — neither kind has array fields (unlike `story`). Both are
  flat records.

---

## 2. Field tables (response shape per kind)

**wiki_page** — `sync_uuid`, `app_uuid`, `object_uuid`, `object_type`, `object_name`, `current_summary`,
`owner_username`, `team_uuid`, `version`, `created_by`, `modified_by`, `created_at`, `updated_at`.

**wiki_entry** — `sync_uuid`, `page_sync_uuid`, `parent_kind` (constant `"wiki_page"`), `change_kind`
(`created` | `updated` | `deprecated`), `business_description`, `technical_description`, `story_key`,
`story_sync_uuid`, `is_bugfix` (Integer `0`/`1`), `change_reason`, `object_version`, `author_username`,
`created_at`, `version`, `published_by`, `published_at`, `updated_at`.

### 2.1 Parent linkage (cross-machine, like `stage_artifact`)

- A **`wiki_entry`** references its page by the page's global **`page_sync_uuid`** (+ a constant
  `parent_kind="wiki_page"`), never a local integer id. Genesis publishes the **page first**, then its entries,
  so a puller can resolve `page_sync_uuid` → its own local page (an entry whose page isn't present yet is
  **skipped and retried** on the next pull — the same rule as `stage_artifact` under `feature`).
- **`wiki_page`** has **no parent record** — it round-trips on the **global `app_uuid`** (a plain shared column,
  like `feature`). The Hub does **not** store the page's local `latest_entry_id` pointer (a machine-local
  integer; genesis excludes it from the payload).
- **`story_sync_uuid`** on an entry is an **optional plain shared column** — the global id of the originating
  story when present (a puller may resolve it to its local story; else it is left as-is). It is **not** a
  hard parent (an entry never blocks on the story being present).

### 2.2 Append-only semantics

`wiki_entry` rows are **append-only** — an entry publishes **once** and is not rewritten in normal operation
(the page's mutable summary lives on `wiki_page.current_summary`). Genesis keys each entry by its own stable
`sync_uuid`; a rare re-publish (e.g. a same-story implementation re-launch that Genesis dedupes locally by
`(page, story)`) arrives as a normal base-version CAS upsert on that entry's `sync_uuid`. The Hub needs no
special-casing — standard §3.2 upsert semantics.

## 3. Text field tiers (Appian Text/Paragraph sizing)

Honor the existing tiering (Text 255 / Long 4000 / **Extra Long 64000**; ≤3 Extra-Long per record type):

| Field | Kind | Tier |
|---|---|---|
| `current_summary` | wiki_page | Long Text (4000) |
| `business_description` | wiki_entry | **Extra Long Text (64000)** |
| `technical_description` | wiki_entry | **Extra Long Text (64000)** |
| `change_reason` | wiki_entry | Long Text (4000) |
| `object_name` / `object_type` / `object_uuid` / `app_uuid` / `story_key` / `story_sync_uuid` / `object_version` / `change_kind` / `author_username` / `parent_kind` | — | Text (255) |

`wiki_entry` uses **2** Extra-Long fields (within the ≤3 budget).

## 4. Change feed + blobs

- Both kinds append a `GH Change Log` row on upsert (the `/changes` feed) exactly like the other kinds, so the
  genesis puller's `changes_since` cursor drains them. `parent_kind`/`page_sync_uuid` ride the record payload.
- **No blobs.** Unlike `stage_artifact`, the Object Wiki stores **no artifact bytes** — descriptions are inline
  text fields. `POST /blobs` is not involved.

## 5. Acceptance (round-trip fidelity — the 42-08 gate)

A `wiki_page` + a set of `wiki_entry` records PUT then GET reproduce every field byte-for-byte (unicode in the
business/technical descriptions; `is_bugfix` 0/1; a null `story_sync_uuid`; ordering of a page's entries by
`created_at`). The genesis-side `LocalHubProvider` round-trip test (`tests/test_object_wiki_collab.py`) asserts
the local↔local half; the live Appian round-trip is validated by the separate agent against the dev-env Hub,
appended to the 36-06 contract-validation harness.
