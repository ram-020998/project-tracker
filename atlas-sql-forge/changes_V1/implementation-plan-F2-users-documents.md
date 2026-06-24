# Feature 2 — User & Document Configuration: Implementation Plan

**Status:** ✅ IMPLEMENTED — Part 1 (group-aware users) and Part 2 (document library) complete and live-verified. CRUD UI built as the ADG_DocumentLibrary interface + site. Remaining: commit/deploy DG MCP image + seed the library operationally.
**Spec:** `changes_V1/spec.md` §3 (decisions D7–D10)
**Goal:**
- **Part 1 (Users):** populate initiator/`createdBy`-type fields with **group-appropriate** users — drawn from the **effective (nested) members** of the group(s) that gate the workflow's launch action, chosen **randomly across the union** of eligible groups.
- **Part 2 (Documents):** give the agent a **user-maintained, queryable document library** organized by **Application**, so Document-type fields are filled with a real `documentId` chosen by **description match** — never invented.

> Two largely independent tracks. Part 1 is steering + one ADG API + one DG tool (no parser change). Part 2 is two new ADG record types + CRUD interfaces + a query path + one DG tool.

---

## PART 1 — Group-aware user resolution (D7–D9)

### 1.1 Current state (grounded)
| Area | Finding |
|------|---------|
| User API | `ADG_API_users` (`users/list`) returns **all** usernames, unfiltered. Backed by `ADG_UT_queryUsersFromEnvironment`. |
| DG tool | `list_users` (no args) → `client.list_users()` → `POST /suite/webapi/users/list`. |
| Eligibility source | Launch eligibility lives in the **record action / related action / start-process link `VISIBILITY` expression**, already captured in the KB at `type_specific.actions[].expressions.VISIBILITY` (e.g. `rule!AS_GSS_BL_getVisibilityToCreateEvaluation(user: loggedInUser())`). **No parser change needed.** |
| Tracing | Agent can follow the visibility rule via `get_object_code` / dependency graph to find the gating group(s). |

### 1.2 Design (resolved)
- **D7:** group→users returns **effective (nested) members** (matches Appian permission semantics).
- **D8:** field→group mapping handled in **steering** — agent reads the action `VISIBILITY` expr (already in KB), traces the referenced rule to the group. Scope = the **initiator** field; other role fields fall back to the global pool unless analysis surfaces a specific filter.
- **D9:** multiple eligible groups → **random across the union** of effective members.

### 1.3 Work item P1-A — ADG group-filtered user API
- **New expression rule `ADG_UT_queryUsersByGroup`** in the ADG app: input `groupName` (or `groupUuid`); returns **effective members** using Appian group-membership functions (e.g. `a!groupMembers(...)` with nested expansion / `members()` traversal). Return shape parallel to `ADG_UT_queryUsersFromEnvironment` (`{users: [username,…]}`).
- **Expose** via the `users` Web API router: extend `users/list` to accept an optional `groupName`/`groupUuid` filter, **or** add a `users/byGroup` method. Prefer extending `users/list` (one method, optional arg) to minimize surface.
- Accept **multiple groups** in one call (`groupNames[]`) and return the **deduplicated union** so D9 can be satisfied server-side or client-side.

### 1.4 Work item P1-B — DG MCP `list_users(group)`
- **`client.py`:** change `list_users()` → `list_users(group_names: list[str] | None = None)`; include `{groupNames: [...]}` in the POST body when provided.
- **`tools/users.py`:** `UsersTools.list_users` reads optional `arguments["groups"]` (string or array) and passes through.
- **`models.py`:** add optional `groups` property (array of strings) to the `list_users` schema; keep back-compat (no args = all users).
- No session/rollback impact (read-only).

### 1.5 Work item P1-C — Steering
- **Update `step-1-workflow-analysis.md`:** when identifying the launch action, read its `VISIBILITY` expression (already in the bundle's record-type object), trace the referenced rule via `get_object_code`, and record the **eligible group(s)** for the initiator.
- **Update `step-4-data-payloads.md`:** for the initiator / `createdBy`-type field, call `list_users(groups: [eligible groups])` and pick **randomly across the returned union**; document the choice in `field_reasoning`. Other user fields keep using the global `list_users()`.
- **Correctness rule:** the chosen initiator MUST be an effective member of ≥1 eligible group.
- Apply to **both** power copies (dev + prod).

### 1.6 Part 1 tests
- ADG rule: unit-verify nested membership (a user in a child group is returned for the parent group).
- DG MCP: `list_users` with/without `groups` (mock client); union dedup.
- Manual: pick an action with a known group-gated visibility rule; confirm the steering selects only members of that group.

---

## PART 2 — Document library (D10)

### 2.1 Current state (grounded)
- ADG has **no record types** today; it operates on other apps by UUID.
- `record` Web API router supports record CRUD/query generically; DG MCP `query_records` already works against any record type UUID.
- SAIL best-practices + accessibility guides live under `appian-application/sail-best-practices/` (UI must follow them).

### 2.2 Data model (two CDM-backed record types)
**`ADG_Application`** — user-maintained catalog of target applications:
| Field | Type | Notes |
|-------|------|-------|
| `id` | Integer PK | auto |
| `name` | Text (unique) | **the agent's match key** |
| `description` | Text | |
| `isActive` | Boolean | soft-delete |
| `createdBy`/`createdOn`/`modifiedBy`/`modifiedOn` | audit | |

**`ADG_Document`** — documents belonging to an application:
| Field | Type | Notes |
|-------|------|-------|
| `id` | Integer PK | auto |
| `applicationId` | Integer FK → `ADG_Application.id` | |
| `documentId` | Document (or Integer doc id) | the Appian document reference the agent returns |
| `name` | Text | |
| `description` | Text | **what the agent reads to choose** |
| `isActive` | Boolean | soft-delete |
| audit fields | | |

- Relationship: `ADG_Application` 1—* `ADG_Document`.
- Create both as CDM record types (`createTable`); files live in an ADG knowledge-center folder; `documentId` points to the uploaded Appian doc.

### 2.3 Work item P2-A — Record types + table
- Create `ADG_Application` and `ADG_Document` record types (CDM) in the ADG app via lcp-mcp-server design tools (`createRecordType`, `addRecordTypeField`, `addRecordTypeRelationship`).
- Add the 1—* relationship and a `documentFolder` (ADG knowledge-center folder) for uploads.
- Apply ADG default security (admin group manage; users read as appropriate).

### 2.4 Work item P2-B — CRUD interfaces (NO process models)
- **Application CRUD** interface(s): list (read-only grid) + create/edit/deactivate form. All writes via **`a!writeRecords` directly in `saveInto`** — no process models.
- **Document CRUD** interface(s): per selected application — list + create/edit/deactivate, with **`a!fileUploadField`** writing the uploaded doc into `ADG_Document.documentId`, plus `name` + `description` inputs; write via `a!writeRecords`.
- Modern, standard UI; follow `appian-application/sail-best-practices/` (layouts, components) and the accessibility guide.
- Host as a small **ADG site** (or a record-list with these interfaces as record actions/views). Validate each interface with `testInterface` before wiring.

### 2.5 Work item P2-C — Exposure to the agent
- **Option (preferred, least work):** the agent uses the existing `query_records` DG tool directly against `ADG_Document`, filtered by `applicationId` (resolved from `ADG_Application.name`). No new Web API needed.
- **Optional convenience Web API:** add a `documents/list` method (or extend `record`) that takes an **application name** and returns `{documentId, name, description}` rows — useful if we want a single round-trip (name→app→documents).
- **Decision:** start with `query_records` (zero new API surface); add `documents/list` only if the two-step (resolve app id, then query docs) proves clunky in steering.

### 2.6 Work item P2-D — DG MCP `list_documents` / `find_document`
- **`client.py`:** `list_documents(application_name)` — resolve app id (query `ADG_Application` by `name`) then query `ADG_Document` by `applicationId`; return `{documentId, name, description}` rows.
- **`find_document(application_name, query)`:** same, plus a simple description contains/keyword rank so the agent gets best matches first (final pick still by the agent reading descriptions).
- **New tool class** `DocumentTools` in `tools/documents.py`; register in `models.py` + `server.py` + `tools/__init__.py`.
- Read-only; no session impact.

### 2.7 Work item P2-E — Steering
- **Update `step-4-data-payloads.md`:** when a payload field is **Document-type**, resolve it from the library — match the **target application by name**, call `find_document(application, contextHint)` / `list_documents(application)`, read candidate **descriptions**, pick the best-fit `documentId`. **Never invent a doc id.** Record the choice in `field_reasoning`.
- Add a short note to `step-0-initialize.md` / `step-3-data-architecture.md` that the document library is keyed by application name and must exist for Document-type fields (else flag to the user to populate it via the CRUD UI).
- Update `tool-reference-data-generator.md` with `list_documents` / `find_document`.
- Apply to **both** power copies.

### 2.8 Part 2 tests
- Record types: create + relationship verified (`getRecordType`, `listRecordTypeRelationships`).
- Interfaces: `testInterface` renders list/create/edit without runtime errors; `a!writeRecords` saveInto round-trips a row; `a!fileUploadField` stores a `documentId`.
- DG MCP: `list_documents`/`find_document` against seeded `ADG_Application`+`ADG_Document` rows (mock client); name→app→docs resolution + description ranking.
- Manual: seed one application + 2–3 documents via the UI; confirm the agent picks the right `documentId` for a Document field by description.

---

## 3. Affected components

| Component | Part 1 (Users) | Part 2 (Documents) |
|-----------|----------------|--------------------|
| ADG Appian app | `ADG_UT_queryUsersByGroup` rule + `users` API group filter | `ADG_Application`+`ADG_Document` RTs, CRUD interfaces (a!writeRecords, fileUploadField), optional `documents/list` |
| DG MCP | `list_users(groups)` (client+tool+schema) | `list_documents`/`find_document` (`tools/documents.py`) |
| Parser / Atlas MCP | — (VISIBILITY already in KB) | — |
| Power steering | step-1 (trace visibility→group), step-4 (group-scoped initiator, random across union) | step-4 (resolve Document fields via library), step-0/3 note, tool-reference |

---

## 4. Sequencing
- **Part 1 and Part 2 are independent** and can be built in parallel.
- Within Part 1: P1-A (ADG rule/API) → P1-B (DG tool) → P1-C (steering).
- Within Part 2: P2-A (record types) → P2-B (interfaces) + P2-C (exposure) → P2-D (DG tool) → P2-E (steering).
- No parser/KB re-parse required for either part.

## 5. Deployment
1. Deploy ADG changes (rule + API for Part 1; record types + interfaces + folder for Part 2) to the ADG app.
2. Deploy DG MCP image with the new tools.
3. Update both power copies; dev first, then prod.
4. Seed the document library via the CRUD UI (operational step, owned by users/admins).

## 6. Risks & mitigations
| Risk | Mitigation |
|------|-----------|
| Visibility rule doesn't reduce to a single group (complex expr) | Steering records all eligible groups; union pool (D9). If unresolvable, fall back to global pool and flag in `field_reasoning`. |
| Empty group (no members) | API returns empty; steering falls back to global pool with a recorded note. |
| Document library empty for the target app | Steering flags to the user to populate via the CRUD UI before filling Document fields; do not invent ids. |
| `a!writeRecords` saveInto pitfalls (validation, refresh) | Follow `sail-common-mistakes.md`; `testInterface` each interface; keep forms simple (no PM). |
| File upload → documentId typing | Confirm `ADG_Document.documentId` type matches `a!fileUploadField` output; test round-trip. |

## 7. Acceptance criteria
- [ ] `ADG_UT_queryUsersByGroup` returns **effective (nested)** members; `users` API accepts a group filter and returns the union for multiple groups.
- [ ] DG `list_users(groups)` returns the group-scoped pool; back-compat (no args) unchanged.
- [ ] Steering selects the initiator **randomly from the union** of eligible groups, traced from the action `VISIBILITY` rule, with reasoning recorded.
- [ ] `ADG_Application` + `ADG_Document` record types exist (CDM) with the 1—* relationship; CRUD interfaces create/edit/deactivate via **direct `a!writeRecords`** (no PMs) and upload via `a!fileUploadField`.
- [ ] DG `list_documents`/`find_document` resolve by application name and return `{documentId, name, description}`.
- [ ] Steering fills Document-type fields from the library by description match, never inventing a doc id.
- [ ] All new unit tests pass; interfaces render via `testInterface`.
