# Phase 16 — Appian Knowledge Base (Atlas-into-Genesis) (umbrella)

> **Status:** DRAFT (planning only — do NOT implement until approved) · **Author:** Genesis agent · **Date:** 2026-08-04
> **Goal:** Bring the Appian **knowledge base** *inside* Genesis. Today Genesis reaches an **external** Atlas MCP
> (GitLab-served, pre-parsed) and Jarvis (in-Appian) for Appian application intelligence. Phase 16 makes Genesis own
> the whole loop: a **Genesis-native Appian parser**, a **local knowledge base in `genesis.db`** (metadata / structure
> / dependencies / bundles — **no source code**), an **Applications** page where a user selects an app from the one
> connected Appian environment and Genesis exports + parses + stores it, a **sync workflow** that keeps it current, and
> a **read-only `genesis-kb` MCP server** that serves this KB to agents — with **live code fetched on demand from the
> environment via the Appian Dev MCP**. This fuses Atlas's *structural intelligence + release history* with Jarvis's
> *always-current live access*, with none of the external moving parts.
> **Repos:** a **new pinned repo `genesis-appian-parser`** (the parser) + **genesis** (KB store, migration m0007, the
> `genesis-kb` MCP server, the Applications API + page, deterministic REST export) + **genesis-workflows** (the
> `sync-application` workflow + curated Dev/DevOps MCP registry entries). **genesis-core** likely unchanged.
> **Non-negotiable framing:** the KB stores **NO object source code** — only metadata, structure, dependency graph,
> and bundles. Current *and* historical code is fetched **live** from the connected environment through the **Appian
> Dev MCP** (version-parameterized). See **ADR-036** (Internalized Appian KB) and **ADR-037** (code-free temporal KB).
> **Near-term intent (the guardrail for scope):** *swap the KB source* — replace the external `appian-atlas` MCP that
> chat / `erd-generation` / `design-doc` use today with the internal `genesis-kb`, **preserving existing
> functionality**. Write/deploy authoring is explicitly **out of scope** (Dev MCP is used **read-only**).

---

## 0. TL;DR

Genesis becomes an agentic **Appian development environment**, and the knowledge base is the foundation. We stop
depending on the external Atlas pipeline (Appian API → `sync_packages.py` → parser → GitLab KB → Atlas MCP over the
GitLab API) and internalize it:

1. **A Genesis-native parser** (`genesis-appian-parser`) — seeded from the proven Atlas parser's front-half
   (unzip → type-detect → 15 object parsers → UUID/URN reference resolution → dependency graph → entry-point bundles →
   content diff-hash), but **Genesis-owned, evolvable, and stripped of code persistence**. It emits an **in-memory
   structured result** (objects, edges, bundles, hashes), not files, and never keeps SAIL.
2. **A local KB in `genesis.db`** (migration **m0007**, `kb_*` tables) — a **temporal (SCD-2) model** that tracks
   object + dependency metadata continuously as an app evolves, plus **user-tagged releases** that name a point in
   time. **Cross-app queryable.** No source code stored.
3. **An `Applications` page** — the user tags one Appian environment as **dev** (existing Environments registry + a new
   `is_dev` toggle), sees its
   applications (via the Dev MCP), and **adds** the app(s) a team is working on. Adding triggers a **baseline sync**.
4. **A `sync-application` LangGraph workflow** — deterministic program/CLI nodes: **export the package via the Appian
   Deployment REST API** (no agent — deterministic, no credits) → **parse** with the native parser → **merge** into the
   KB + recompute bundles → **record the sync**. Run-tracked, retryable, error-surfacing (it *is* a Genesis run).
5. **A read-only `genesis-kb` MCP server** — the local counterpart of the external Atlas MCP: `list_applications`,
   `get_app_overview`, `search_objects`, `search_bundles`, `get_bundle`, `get_dependencies`, `get_object_detail`,
   `list_orphans`, plus **`get_object_code(object_uuid, version?)`** which fetches SAIL **live** from the environment
   via the Dev MCP. Wired into chat and available to workflow nodes; **chat / erd / design-doc are cut over from the
   external `appian-atlas` to `genesis-kb`.**
6. **Version tagging + point-in-time** — the user marks a release in Genesis ("released, v1.0"); Genesis snapshots the
   metadata state and records the environment's version handle so any object's code *at that release* is retrievable
   live from the env (once Dev MCP versioned retrieval — **AP-62096**, 26.8 GA — ships; current code works now).
7. **Delta refresh** — a small **new Appian API** (owned by the Appian side) returns *objects changed in
   `[start,end]`*; a scheduled/manual delta sync exports only the changed objects, delta-merges, and archives history.

Everything is **read-only against Appian** (Dev MCP read, Deployment API export). All the heavy artifacts (the package
zip, the parser's intermediate output) live in the **run blackboard** (ADR-010/018); only compact metadata reaches
`kb_*` and only pointers reach LangGraph state.

---

## 1. Motivation & user story

> *"Genesis is becoming a tool that provides an agentic way to develop Appian applications — development, testing, spec
> creation, all against a real Appian app. An Appian application has 4,000–6,000+ objects, and general agents struggle
> to navigate the objects and their relationships. Atlas solved that: give it an application export zip, its parser
> builds a knowledge base of **bundles** (an entry point + its full object traversal) and dependency graphs, stores it
> in GitLab, and exposes it via an MCP server so the agent retrieves only what it needs. Jarvis does the same but
> stores the KB inside Appian and queries the live environment — so it's always current but has no release history.
> Atlas has multi-release history but only parses once a day.*
>
> *I want to bring both advantages inside Genesis. Move the externally-stored Atlas knowledge into Genesis and serve
> it to the agent directly — incorporate the parser into Genesis, and have Genesis pull application packages from the
> connected environment, parse them, and store/update the KB. I don't want all the applications in the environment —
> a team works on one app at a time — so we need an **Applications** page (application containers, like Appian
> environments) where I click **Add Application**, see the apps in the connected environment, and select the one(s) I
> need. Only then is the zip exported, parsed, and stored. Keep the KB **lightweight but intelligent**: no object
> source code in the KB — fetch that from the environment at runtime. Track object versions against releases I tag in
> Genesis, so I can always ask what an object looked like at v1.0. Keep it fresh with a delta: a new API in the
> environment lists objects changed in a time window, and a periodic/manual sync updates only the delta. And use the
> native Appian **Dev MCP** (development tools) and **DevOps MCP** (deployment/export) directly — those are the basic
> building blocks for any interaction with an Appian environment."*

Net: **Genesis owns the KB.** External Atlas/Jarvis are the inspiration and the interim source; after Phase 16 the KB
is a first-class Genesis subsystem fed by the single **dev-tagged** environment.

---

## 2. Background — the pieces (verified from source) and why we internalize

**Atlas Parser** (`appian/prod/solutions-atlas-parser`) — pure-stdlib Python. `PackageReader` (unzip + discover XML)
→ `TypeDetector` (root-tag → object type) → `ParserRegistry` (15 type parsers + fallback) → in-memory `ParsedObject`s.
Resolves opaque identifiers **in-memory** (`#"_a-…"` UUID → `rule!Name`; record-field/translation URNs → readable
names). Builds the **dependency graph** and detects **entry points**; generates 6 **bundle** types
(action/process/page/site/dashboard/web_api) by BFS from each entry point — each bundle is a self-contained functional
flow. `DiffHashService` gives every object a SHA-512 content hash (change detection). Fast (~1.9s for ~2,461 objects).
It also ships a real **versioning/delta engine** (`versioning/`): `parsed_state.json` cache + `DeltaMerger` (merge only
changed objects by `diff_hash`), `ModeDetector` (daily_update vs new_release by the app's version constant),
`HistoryArchiver` (`history/<uuid>/<version>.json`), `ChangelogBuilder`, `RetentionPruner` (`max_retained_releases`).

**Atlas KB** (`appian/prod/solutions-atlas-kb`) — the data + orchestrator. Per app: `app_config.json`
(name + version_constant + retention), `release_index.json`, `current/` (manifest, objects/, **code/**, bundles/,
graph, search_index, orphans), `history/`, `changelogs/`, `release_snapshots/`. `sync_packages.py` downloads a FULL
package from an Appian Web API (`/suite/webapi/pck-package`, header `Appian-Api-Key`, `packageType=FULL&releaseVersion`),
quick-parses the version constant, and either delta-parses (same version, via a `-d:m~1` delta package) or full-parses
(new/first version). CI runs it `sync-full` (manual) / `sync-delta` (daily). The **Atlas MCP** reads this KB **over the
GitLab API** (LRU cache + pinned anchor files) and is **read-only** (rejects write-scoped tokens). Tools:
`list_applications`, `get_app_overview`, `search_bundles`, `get_bundle`, `search_objects`, `get_dependencies`,
`get_object_detail`, `list_orphans`, `get_orphan`.

**Jarvis** (`solutions-os/ai-framework/tools/Jarvis`) — the in-Appian counterpart: a Docker MCP
(`APPIAN_BASE_URL` + `APPIAN_API_KEY`) storing its KB **inside Appian** and querying **live** (kb/knowledge/object/
package/deployment/creation/refactor/site handlers). Always-current, can mutate/deploy, **no release history**.

**Appian Dev MCP** (docs 26.7 — the `lcp-mcp-server`; = Genesis's `lcp` registry placeholder) — community plug-in that
**reads and writes Appian design objects** ("list applications on my site", read/create a rule/interface/record type).
Local (`uv`/python), talks to an Appian plug-in over HTTPS (`LCP_URL`, credentials, `LCP_API_PATH`). **Version-aware
object retrieval** (list versions · read a prior version · compare) is tracked as **AP-62096** (child of **AP-54865**,
Fix Version **26.8 GA / 2026-08-28**), in **Code Review** as of 2026-08-04; the version-UUID plumbing (**AP-51279** +
AP-52939) is already **Done**. This is what Genesis uses for both current and historical code (historical waits on
AP-62096 shipping).

**Appian DevOps MCP** (docs 26.7 — the Appian **Deployment MCP**) — wraps the **Deployment REST API**. Tools:
`get_application_packages`, `export_package`, `inspect_package`, `deploy_package`, `download_exported_package`
(+scripts/plugins/customization), `export_and_deploy`, polling, and pipeline orchestration. Requires **External
Deployments** enabled + a service-account API key. **No "list all applications" tool** (that comes from the Dev MCP).

**Why internalize.** The external chain has four moving parts (Appian API, a standalone `sync_packages.py`, a GitLab
KB repo, an MCP that reads GitLab), a **daily** freshness ceiling, and an agent round-trip over the network for every
query. Bringing the parser + KB into Genesis gives: direct local access (no GitLab round-trip), on-demand + delta
freshness under Genesis's control, a KB tuned to Genesis's needs (code-free, temporal, cross-app), and a single
**dev-tagged** environment as the source of truth — which is exactly the posture Genesis already has (local, single-user,
its own SQLite data plane).

---

## 3. Concept & scope boundary

**What changes.** The *source* of Appian application intelligence moves from *external Atlas (GitLab) / Jarvis
(in-Appian)* to an *internal Genesis KB fed by the one connected environment*. A new **Applications** subsystem
(containers + sync + KB) appears. The native **Dev MCP** and **DevOps MCP** become curated, first-class environment
connectors.

**What is preserved (the guardrail).** Everything Genesis does today keeps working — the concrete near-term milestone
is **cutting chat / `erd-generation` / `design-doc` off the external `appian-atlas` and onto `genesis-kb`** with an
equivalent-or-better tool surface. No workflow loses a capability.

**What is explicitly deferred.** Writing/deploying Appian objects (authoring, refactor, promote) is **out of scope**;
the Dev MCP is used **read-only**. Folding Jarvis's *live mutation* capabilities into Genesis is a later track. Semantic
/ RAG search over parsed content (pgvector) is a future ADR-030 trigger, not this phase.

**Concept — Application container vs Environment vs Workflow.**

| | **Environment** (existing) | **Application** (new) | **Workflow** (existing) |
|---|---|---|---|
| What | a connected Appian site (url + endpoint) | an Appian app tracked in Genesis (KB container) | a LangGraph graph (staged activity) |
| Identity | registry label | **Appian application UUID** | workflow id |
| Cardinality | **many** registered; **one tagged `dev`** (Phase 16 uses it) | many (on-demand, "add application") | many (installed) |
| Holds | connection + public vars | metadata KB + releases + sync history | graph + META |
| Lives in | `~/.genesis/environments.json` | `genesis.db` `kb_*` | `~/.genesis/library/workflows/` |

**Rule:** one registered **Environment** is tagged **dev** (the Appian connection Phase 16 uses); a team **adds** the **Applications** they work on; each Application's KB is
a **code-free temporal metadata store**; a **Workflow** (the new `sync-application`) is what *populates/updates* it.

---

## 4. System overview

```
        ┌──────────────────────── Connected Appian environment (exactly one) ────────────────────────┐
        │  Deployment REST API (export)      Dev MCP (list apps, read object code — current+version)  │
        │  NEW: "changed in [start,end]" API (delta; Appian-side, owned by the Appian team)           │
        └───────────┬───────────────────────────────┬───────────────────────────────┬───────────────┘
                    │ export package (zip)           │ list apps / live code         │ changed-object list
                    │ (deterministic REST)           │ (agent + kb_server)           │ (delta sync)
   ┌────────────────▼───────────────────── genesis app ───────────────────────────────▼───────────────┐
   │  sync-application WORKFLOW (LangGraph, run-tracked):                                                │
   │    resolve → export(REST, →blackboard) → parse(genesis-appian-parser) → merge(KbStore) →           │
   │    recompute bundles → record sync                                                                 │
   │                                                                                                    │
   │  KB in genesis.db (m0007, kb_* temporal tables) ◄── KbStore ──►  genesis-kb MCP server (read-only) │
   │                                                                    │  get_object_code → Dev MCP    │
   │  Applications API (/api/applications*) ── RunManager.start("sync-application", env=<label>)         │
   └───────────────┬────────────────────────────────────────────────────┬──────────────────────────────┘
                   │ list/add/sync/status/releases                       │ @genesis-kb/* injected
   ┌───────────────▼──────── Applications page (web) ──────┐   ┌──────────▼── chat / erd / design-doc ──┐
   │  connect env → list apps → add → sync status →        │   │  cut over from @appian-atlas/*          │
   │  releases / changelog / object browser                │   │  to @genesis-kb/* (equal-or-better)     │
   └───────────────────────────────────────────────────────┘   └─────────────────────────────────────────┘
```

Key properties:
- **The dev-tagged environment is the source of truth.** Many environments may be registered; the one tagged **dev**
  (single-select `is_dev`) supplies the URL + credentials (`APPIAN_API_KEY` / Dev-MCP creds in the SecretProvider,
  server-scoped) for the REST export, the Dev MCP, and the DevOps MCP. Its label is passed to the sync run
  (`RunManager.start(..., environment=<dev env label>)`).
- **Deterministic export.** The sync pipeline calls the Deployment REST API from a **program node** (like
  `sync_packages.py`), not an agent — no credits, fully reproducible (ADR-001). The Dev/DevOps MCPs are still
  registered for *agent* use (chat, future authoring).
- **Code-free KB.** `kb_*` holds metadata/structure/deps/bundles; **never** SAIL. Code (current + historical) is fetched
  live from the env via the Dev MCP, keyed by object UUID (+ version for point-in-time).
- **Temporal + cross-app.** SCD-2 rows track every metadata change; releases name points in time; queries span apps.
- **Bulk → blackboard.** The package zip and parser intermediate JSON live in the run's `RunWorkspace`, not state, not
  `kb_*`, not chat (ADR-010/018).
- **`genesis-kb` mirrors the internal-MCP pattern** (introspection/control/blackboard servers): a stdio JSON-RPC server
  launched by Genesis, read-only over `genesis.db` (`mode=ro`), injected into chat + nodes via the `@server/tool` trust
  form.

---

## 5. The data model (the crux) — `genesis.db` migration m0007, `kb_*` tables

A **temporal (bitemporal-lite, SCD-2)** model: object and dependency **metadata** is versioned by validity range keyed
to **syncs**; **releases** are named labels pointing at a sync (a point in time). No source code anywhere.

```sql
-- Application containers (one row per tracked Appian app; keyed by Appian application UUID)
CREATE TABLE kb_applications (
  app_uuid            TEXT PRIMARY KEY,          -- Appian application UUID (stable identity)
  name                TEXT NOT NULL,
  env_label           TEXT NOT NULL,             -- Environments-registry label (the one connected env)
  version_constant    TEXT,                      -- optional: constant name for auto version detection (Atlas-style)
  baseline_sync_id    INTEGER,                   -- first successful full sync
  current_release     TEXT,                      -- latest tagged release label (e.g. "1.0")
  status              TEXT NOT NULL DEFAULT 'active',  -- active | archived
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL
);

-- Every sync attempt (baseline or delta); links to the sync workflow run for status/retry/errors
CREATE TABLE kb_syncs (
  sync_id             INTEGER PRIMARY KEY AUTOINCREMENT,
  app_uuid            TEXT NOT NULL REFERENCES kb_applications(app_uuid) ON DELETE CASCADE,
  kind                TEXT NOT NULL,             -- baseline | delta
  window_start        TEXT,                      -- delta only
  window_end          TEXT,                      -- delta only
  run_id              TEXT,                      -- the sync-application run (RunStore)
  status              TEXT NOT NULL,             -- running | succeeded | failed
  objects_added       INTEGER DEFAULT 0,
  objects_modified    INTEGER DEFAULT 0,
  objects_removed     INTEGER DEFAULT 0,
  started_at          TEXT NOT NULL,
  finished_at         TEXT
);

-- Object metadata, SCD-2 (NO code). A new row opens when diff_hash changes; the old row's valid_to_sync closes.
CREATE TABLE kb_objects (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  app_uuid            TEXT NOT NULL,
  object_uuid         TEXT NOT NULL,             -- Appian object UUID (handle for live code fetch)
  name                TEXT NOT NULL,
  type                TEXT NOT NULL,             -- Interface, Expression Rule, Process Model, Record Type, ...
  qname               TEXT,                      -- namespaced QName when present (Phase-12 lesson)
  type_id             TEXT,                      -- separate typeId when present
  description         TEXT,
  diff_hash           TEXT NOT NULL,             -- SHA-512 content hash (change detection)
  is_entry_point      INTEGER NOT NULL DEFAULT 0,
  is_orphan           INTEGER NOT NULL DEFAULT 0,
  metadata_json       TEXT,                      -- parameters, output type, flags, entry-point kind, etc. (NO SAIL)
  valid_from_sync     INTEGER NOT NULL REFERENCES kb_syncs(sync_id),
  valid_to_sync       INTEGER,                   -- NULL = current
  UNIQUE(app_uuid, object_uuid, valid_from_sync)
);

-- Dependency edges, SCD-2
CREATE TABLE kb_dependencies (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  app_uuid            TEXT NOT NULL,
  source_uuid         TEXT NOT NULL,
  target_uuid         TEXT NOT NULL,
  dep_type            TEXT NOT NULL,             -- rule_call | interface_call | constant_ref | record_ref | ...
  valid_from_sync     INTEGER NOT NULL,
  valid_to_sync       INTEGER
);

-- Bundles: maintained for CURRENT state (overwritten each sync) + snapshotted per RELEASE tag
CREATE TABLE kb_bundles (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  app_uuid            TEXT NOT NULL,
  bundle_id           TEXT NOT NULL,             -- stable bundle key/name
  bundle_type         TEXT NOT NULL,             -- action | process | page | site | dashboard | web_api
  root_uuid           TEXT NOT NULL,
  name                TEXT NOT NULL,
  parent_name         TEXT,
  object_count        INTEGER NOT NULL DEFAULT 0,
  key_objects_json    TEXT,                      -- JSON array of key-object names (overview/search cards)
  flow_json           TEXT,                      -- JSON array of the textual traversal ("Action: … → …") — get_bundle returns verbatim
  snapshot_sync       INTEGER NOT NULL,          -- the sync this bundle set belongs to (current) ...
  release_label       TEXT,                      -- ... or a release snapshot (NULL = current set)
  UNIQUE(app_uuid, bundle_id, snapshot_sync)
);

CREATE TABLE kb_bundle_members (
  bundle_pk           INTEGER NOT NULL REFERENCES kb_bundles(id) ON DELETE CASCADE,
  object_uuid         TEXT NOT NULL,
  role                TEXT,                      -- entry_point | member
  flow_order          INTEGER
);

-- User-tagged releases: name a point in time; env_version_ref is the handle Dev MCP uses to fetch code at that release
CREATE TABLE kb_releases (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  app_uuid            TEXT NOT NULL REFERENCES kb_applications(app_uuid) ON DELETE CASCADE,
  version_label       TEXT NOT NULL,             -- "1.0", "2.0", ...
  tagged_at           TEXT NOT NULL,
  sync_id             INTEGER NOT NULL,          -- the sync/point this release snapshots
  env_version_ref     TEXT,                      -- Dev MCP version handle for point-in-time code fetch
  notes               TEXT,
  UNIQUE(app_uuid, version_label)
);

-- Indexes
CREATE INDEX idx_kb_objects_cur    ON kb_objects(app_uuid, object_uuid, valid_to_sync);
CREATE INDEX idx_kb_objects_name   ON kb_objects(app_uuid, name);
CREATE INDEX idx_kb_objects_type   ON kb_objects(app_uuid, type, valid_to_sync);
CREATE INDEX idx_kb_deps_src       ON kb_dependencies(app_uuid, source_uuid, valid_to_sync);
CREATE INDEX idx_kb_deps_tgt       ON kb_dependencies(app_uuid, target_uuid, valid_to_sync);
CREATE INDEX idx_kb_bundles_cur    ON kb_bundles(app_uuid, snapshot_sync);
```

**Design notes**
- **Current state** = rows with `valid_to_sync IS NULL`. Every read tool defaults to current.
- **Point-in-time** = for release `R`: `sid = (SELECT sync_id FROM kb_releases WHERE app_uuid=? AND version_label=R)`,
  then objects/edges where `valid_from_sync <= sid AND (valid_to_sync IS NULL OR valid_to_sync > sid)`. This
  reconstructs the exact metadata graph at that release from the continuous history — no per-version copies.
- **Code is never stored.** `object_uuid` (+ the release's `env_version_ref`) is the handle handed to the Dev MCP to
  fetch SAIL live. Historical code lights up when Dev MCP versioned retrieval (**AP-62096**, 26.8 GA) ships; current code works now.
- **Bundles** are recomputed **in full** each sync (global BFS is seconds at 6k objects — simpler + correct than
  incremental patching) and stored as the *current* set (`release_label IS NULL`, overwritten each sync). On a
  **release tag**, the current bundle set is copied into a `release_label`-stamped snapshot so point-in-time bundles are
  cheap without keeping a snapshot per daily sync.
- **Deletions** (from delta) close the object/edge rows (`valid_to_sync = sync_id`); the object stays queryable
  historically.
- **Retention** (optional, later): prune SCD-2 rows and release snapshots older than the oldest retained release
  (Atlas `max_retained_releases` analogue). `kb_*` prune is **table-scoped** and must never touch runs/chat tables.
- **Cross-app** queries are natural (`WHERE app_uuid IN (...)` or omit). Fuzzy name/description search can add an
  **FTS5** virtual table later (additive) without schema churn.
- **`metadata_json`** carries the structural detail an agent needs *without* code: parameters + types, output type,
  entry-point kind, record-type fields (names/types), site/page targets, etc. — the same fields Atlas puts in
  `structure.json`, minus `sail_code`.

---

## 6. The version / release model

The user's mental model, made concrete:
1. A team develops in the connected env; Genesis **delta-syncs** continuously (scheduled/manual), so `kb_objects`
   accumulates SCD-2 history of *metadata* changes with each sync.
2. When the team cuts a release, they open the app in Genesis and **"Mark released → v1.0"**. Genesis writes a
   `kb_releases` row pointing at the latest successful sync (`sync_id`) and records `env_version_ref` — the version
   handle the environment/Dev MCP understands for that release.
3. To answer *"what did object X look like at v1.0?"*, Genesis resolves the release → `sync_id` for the **metadata**
   (structure/deps/bundles at that point) and hands `(object_uuid, env_version_ref)` to the **Dev MCP** to fetch the
   **code** at that version, live.

**Load-bearing dependency (identified + tracked):** point-in-time *code* requires the env to return an object's content
**at a past version**. This is delivered by Appian **Dev MCP** story **[AP-62096](https://appian-eng.atlassian.net/browse/AP-62096)**
(list versions · read a prior version · compare · revert), Fix Version **26.8 GA (2026-08-28)**, in **Code Review** as of
2026-08-04 (its version-UUID plumbing **AP-51279** + AP-52939 is already **Done**). So **all** code fetch (current +
historical) goes through the Dev MCP. Sequencing: current-code fetch works today; **historical fetch lights up when
AP-62096 ships in 26.8 GA** — this gates only 16-06's point-in-time *code* view, not the metadata history (which is fully
in `kb_*`) and not phases 16-01…16-05.

---

## 7. The sync pipeline (`sync-application` workflow)

A **LangGraph workflow** so it gets Genesis's run tracking, retry, checkpoint, and error surfacing for free — the user
can start a sync and watch it, and re-trigger/inspect failures like any run. **Export is deterministic REST, not an
agent turn** (ADR-001, no credits).

```
resolve_inputs (program)
  → export_package (program: Appian Deployment REST API → zip in RunWorkspace blackboard)
      → v_export (validator: zip present, non-empty, expected app)
  → parse_package (program/cli: genesis-appian-parser → structured result JSON in blackboard)
      → v_parse (validator: object count > 0, no fatal errors, version constant found if configured)
  → detect_mode (program: baseline | delta; new_release vs update by version constant when configured)
  → write_kb (program: KbStore.apply(result, sync) — SCD-2 upsert objects/edges, recompute + store bundles)
      → v_kb (validator: kb_syncs row succeeded, counts reconcile)
  → present (program: sync summary → report.json)
```

- **Baseline** (on Add Application, or first sync): full export → full parse → open all `kb_objects`/`kb_dependencies`
  rows at the baseline sync; set `kb_applications.baseline_sync_id`.
- **Delta** (16-07): call the new "changed in `[start,end]`" API → get changed (and deleted) object UUIDs → export just
  those (Deployment API package by object set, or per-object) → parse → `DeltaMerger`-style merge (close changed rows,
  open new ones; update edges) → recompute affected bundles (recompute-all for correctness) → record the sync window.
- **Reliability:** any *agent* node would get the mandatory trio (ADR-011); this pipeline is program/CLI-only, so the
  validators after export/parse/write are the correctness gates. No `pre_mutation` gate — Appian access is read-only
  (export) and the only write is the **local** KB.
- **Bulk handling:** the zip (tens of MB) and parser intermediate JSON live in the `RunWorkspace` blackboard; only
  counts/pointers reach state; only compact metadata reaches `kb_*` (ADR-010/018). Export ≤300s fits under the default
  node timeouts; a per-object parse loop (if modeled as one) sets `META.execution.recursion_limit`.

---

## 8. The delta / refresh model (new Appian API contract)

We do **not** reuse Atlas's package-repo-specific `-d:m~1` delta. Instead (user-owned Appian work — "a small app + a
few Web APIs, no product change"):
- **`GET changed-objects?app=<uuid>&start=<iso>&end=<iso>`** → returns the objects **modified in the window**: at
  minimum `{object_uuid, name, type, last_modified, change_kind: added|modified|removed}`. Ideally it can also return
  (or link to) the object content/XML so Genesis parses without N per-object exports.
- Genesis's delta sync passes `[last_successful_sync_end, now]`; the scheduler can run hourly/daily; a manual "Sync now"
  is always available.
- **Contract points to settle with the Appian side (16-07):** does the API return content or just identifiers (drives
  whether Genesis exports the subset via the Deployment API afterward)? How are **deletes** and **renames** reported
  (renames are fine — UUID-keyed; deletes must be explicit to close rows)? Pagination for large windows? Auth (the same
  service-account API key).

---

## 9. The `genesis-kb` MCP server + cutover

A Genesis-owned, **read-only** stdio MCP server modeled exactly on `mcp/introspection_server.py` (JSON-RPC over stdio,
a read-only `file:...?mode=ro` connection to `genesis.db`, 32 KB payload cap, secret redaction).

**Authoritative tool surface:** see **`phase-16-appian-knowledge-base/genesis-kb-tool-contracts.md`** — built from a
full audit of the **Atlas MCP (34 tools)** + **Jarvis MCP (50 tools)**, it gives the exact params, return JSON, backing
`kb_*` query, and parser fields for every tool. The **iteration-1 surface = 16 read-only Tier-1 tools**:
`list_applications`, `get_app_overview`, `search_objects`, `get_dependencies`, `get_object_detail`,
`get_entry_points_for_object`, `get_dependents_batch`, `get_precedents_batch`, `get_shared_objects`, `search_bundles`,
`get_bundle`, `list_orphans`, `get_orphan`, `get_dependency_path`, `get_transitive_dependencies`, `get_hub_objects`, and
`get_object_code` (live via Dev MCP). Return shapes **mirror the Atlas MCP** so the cutover is lossless. **Versioning
tools (`list_releases`/`get_changelog`/`compare_releases`/`get_object_history`/`get_object_at_release`/
`get_release_impact`) are BACKLOG** (16-06, gated on AP-62096), and schema/DDL tools are **deferred** (Section C).

**Live-code wiring (decided):** **co-inject the Dev MCP** alongside `genesis-kb` — `genesis-kb` serves structure from
`kb_*`; `get_object_code` (and the code field of `get_orphan`) fetch SAIL **live via `@appian-dev`**; no code is stored.
All other environment reads (SAIL eval, SQL, env info, live object/XML, app enumeration) also go through the native
**Dev / DevOps MCP**, never Atlas/Jarvis (see the contracts doc §3).

**Cutover:** chat (`chat/mcp.py` `_kb_entry` + `@genesis-kb/*` trust), `erd-generation`, and `design-doc` switch from
`@appian-atlas/*` to `@genesis-kb/*` (+ `@appian-dev` for code). Update the workflow prompts/allowlists + tests to the
contract shapes. `appian-atlas` stays registered (deprecated) until the cutover is verified, then is removed.

---

## 10. The native parser (`genesis-appian-parser`)

**Strategy: port the front-half, rewrite the back-half, drop code persistence.** "Genesis-native" = a Genesis-owned
copy we then evolve — **not** a clean-room rewrite (the Appian XML/SAIL parsing + reference resolution is exactly the
fidelity-sensitive logic we must not re-derive; Phase-12's live-run lessons apply).

- **Port as-is (Genesis-owned):** `PackageReader`, `TypeDetector`, the 15 object parsers, reference resolution
  (UUID/URN/translation), the dependency-graph builder, the bundle builder (entry-point BFS), diff-hashing.
- **Rewrite for Genesis:** the **output** — instead of writing Atlas's JSON file tree, emit an **in-memory structured
  result** (dataclasses: `KbObject`, `KbEdge`, `KbBundle`, `KbParseResult`) the `KbStore` consumes. The versioning
  layer moves into `KbStore`'s SCD-2 model.
- **Drop entirely:** `code.json`/code-file writers and any code persistence. We still **parse SAIL** (to extract
  dependency references + descriptions) — we just **never store it**.
- **Packaging:** a **new pinned repo `genesis-appian-parser`** (stdlib-only, its own tests against real captured
  packages), pinned into `genesis` by tag like `genesis-core` (ADR-019 discipline; a compat note if we add a
  major-gate). `KbStore` (which owns `genesis.db`) stays in `genesis`.

---

## 11. Applications surface (page + API + container model)

- **Model:** `kb_applications` (above). One env connected; an app belongs to it via `env_label`.
- **API** (`genesis/api/applications.py`, `register_applications_routes(api, ...)`, all under `/api`):
  - `GET /api/applications` → tracked apps (name, counts, current release, last sync status).
  - `GET /api/applications/available` → apps **in the connected env** (via Dev MCP "list applications"), minus
    already-tracked.
  - `POST /api/applications` → add/track an app (app_uuid + name + env_label) → kick a **baseline sync**
    (`RunManager.start("sync-application", {...}, environment=<label>)`).
  - `GET /api/applications/{app_uuid}` → detail (overview, releases, sync history).
  - `POST /api/applications/{app_uuid}/sync` → manual sync (baseline/delta).
  - `GET /api/applications/{app_uuid}/sync-status` → latest sync run status (from `RunStore`/`kb_syncs`).
  - `POST /api/applications/{app_uuid}/releases` → **tag a release** (version_label [+ env_version_ref]).
  - `GET /api/applications/{app_uuid}/objects|bundles|changelog` → KB browse (reuses `KbStore`).
  - `DELETE /api/applications/{app_uuid}` → untrack (table-scoped `kb_*` delete).
- **Web** (`web/src/features/applications/`): `ApplicationsPage` (tracked list + "Add application" dialog that lists
  available apps from the env), `ApplicationDetail` (overview / objects / bundles / releases / sync history), a live
  **SyncStatus** view (reuses the run/SSE machinery), a "Mark released" action. One nav entry in `Sidebar` `GROUPS`
  (under **Library**, beside Catalog). `applicationsApi` in `lib/api/applications.ts` (client prepends `/api`).
  Rebuild + commit `web/static/` (stale-bundle guard).

---

## 12. Environment & secrets model (the **dev-tagged** environment)

Genesis's Environments registry may hold **many** environments. Phase 16 adds a single **`is_dev` toggle** on an
environment: **exactly one** registered environment may be tagged **dev** (single-select — tagging one clears any
prior). That **dev-tagged environment is the source of truth for all Phase-16 auth/connectivity** — the Deployment REST
export, the Dev MCP, the DevOps MCP, and the changed-objects API all resolve their URL + credentials from it. (Concrete
implementation — the `is_dev` field, the single-select invariant, the `EnvironmentRegistry.dev_environment()` resolver,
and the Settings toggle + "test connection" — is specified in **16-08 §2.0**.)

- **The env record** (existing registry, `~/.genesis/environments.json`): `url`, `api_endpoint`, **+ the new `is_dev`
  flag**. It stays **credential-free** — `APPIAN_API_KEY` (Deployment API / DevOps MCP) and the Dev MCP credentials
  (`LCP_USERNAME`/`LCP_PASSWORD`) live in the **SecretProvider**, scoped to the `appian-dev` / `appian-devops` server
  names. The Settings UI surfaces those credential fields **alongside the dev-tagged environment** so the whole Appian
  connection is configured in one place (secret *values* still land in the 0600 SecretProvider, referenced by key —
  never in `environments.json`).
- **Resolution order** at MCP launch is unchanged: SecretProvider → EnvironmentRegistry (public URL vars, from the
  **dev-tagged** env) → `os.environ` (`genesis-core/mcp/registry.py`). MCP `env` is emitted as a **LIST of
  `{name,value}`** (the load-bearing ACP lesson).
- **Deployment REST export** (16-03) reads the **dev-tagged env's** URL + `APPIAN_API_KEY` directly (deterministic
  program node), mirroring `sync_packages.py`'s `requests` call. If **no** env is tagged dev, the sync (and the
  "available apps" enumeration) **fail fast** with an actionable "tag a dev environment in Settings" error.
- **Prereqs on the dev environment** (out of Genesis's control, accepted): **External Deployments** enabled + a
  service-account API key; the Dev MCP plug-in installed/enabled; the new "changed-objects" API deployed (16-07). The
  dev-tagged env is expected to have these — Genesis requires a properly configured dev environment to operate.

---

## 13. Sub-phases (each has its own detailed spec under `phase-16-appian-knowledge-base/`)

| Sub-phase | Title | Repos | Iteration | Outcome |
|---|---|---|---|---|
| **16-01** | Native Appian parser | genesis-appian-parser (new) | **1** | Port the Atlas parser front-half into a Genesis-owned, stdlib-only package that emits an **in-memory structured result** (objects/edges/bundles+**flow**/hashes), **no code persistence**, no file output, **no schema/DDL module** (Section C deferred). Tests vs real captured packages. Tag v0.1.0. |
| **16-02** | KB schema + store | genesis | **1** | Migration **m0007** (`kb_*` tables; SCD-2 columns + `kb_releases` kept **version-ready but additive**) + `KbStore` read methods returning the **exact tool-contract shapes** (`genesis-kb-tool-contracts.md`). Iteration 1 = **current-state** reads/writes only. Tests. |
| **16-03** | Sync workflow (baseline) | genesis-workflows (+ genesis) | **1** | `sync-application` LangGraph workflow: deterministic REST **export → parse → merge → recompute bundles → record sync** (baseline/full). Register `appian-dev` + `appian-devops` curated MCPs (read/export-only). |
| **16-08** | Native MCP integration & updatability | genesis (+ registry) | **1** | **Connectivity foundation (build first): an `is_dev` toggle on the Environments registry** (many envs may exist; single-select; the dev-tagged env's URL + creds feed all Phase-16 auth) + a "test connection". Then integrate the **Dev MCP** (`lcp-mcp-server`) + **DevOps MCP** (`appian-deployment-mcp`) as **managed, versioned, updatable** local servers (`~/.genesis/mcp-servers/<id>/versions/<v>/` via `uv sync`; launch from the venv; read-only allowlists). **Update-from-source without forking:** Dev = re-fetch from the connected site's bundle servlet; DevOps = configured/drop-in artifact; both reversible. Prereq for 16-04/16-05. **ADR-038.** |
| **16-04** | Applications surface | genesis (+ web) | **1** | `kb_applications` container model, `/api/applications*` routes, **Applications** page (connect env → list available apps via Dev MCP → add → baseline sync → status). |
| **16-05** | `genesis-kb` MCP + cutover | genesis (+ genesis-workflows) | **1** | Read-only `genesis-kb` stdio MCP over `genesis.db` exposing the **16 Tier-1 tools** in `genesis-kb-tool-contracts.md`; live `get_object_code` via **Dev MCP**; **cut chat / erd-generation / design-doc off `appian-atlas` onto `genesis-kb`** (+ Dev/DevOps for env calls). ← "KB swapped, functionality preserved" milestone. |
| — | **`genesis-kb-tool-contracts.md`** | (reference) | **1** | The authoritative per-tool contract (params · exact return JSON · backing `kb_*` query · parser fields) for all 16 tools + the Dev/DevOps env-call mapping + implementation order. Built from the Atlas (34) + Jarvis (50) tool audit. |
| **16-07** | Delta refresh + scheduling | genesis (+ Appian-side API) | **1** | Integrate the new "changed in [start,end]" API; delta-sync path (changed/deleted UUIDs → subset export → delta-merge) keeping **current state** fresh; manual + scheduled triggers. |
| **16-06** | Version tagging + point-in-time | genesis (+ web) | **BACKLOG** | 📋 **Not iteration 1.** `kb_releases`, "Mark released → vX", point-in-time metadata + code. **Gated on Dev MCP `AP-62096`** (26.8 GA). Schema is kept version-ready in 16-02 so this lands as code-only later. |

**Scope decisions (2026-08-04):** Section A / Tier-1 KB tools = **iteration 1**; Section B versioning = **backlog** (16-06,
gated on AP-62096); Section C schema/DDL = **deferred**; Section D live-env reads = **iteration 1 but via Dev/DevOps MCP
only** (never Atlas/Jarvis as a service); Sections E (write/deploy) + F (documents/git-content/pipeline-refresh) = **out**.

**Sequencing rationale:** 16-01 (parser) + 16-02 (store) are the load-bearing, env-free foundation. 16-03 makes the
pipeline real; 16-04 gives the add/track/sync surface; 16-05 is the headline milestone (KB swapped, everything still
works); 16-07 keeps the current-state KB fresh. **16-06 (versioning) is deferred to a later iteration** once Dev MCP
AP-62096 ships. Each iteration-1 sub-phase is independently valuable and shippable.

---

## 14. Release chain & versioning (ADR-019)

`genesis-appian-parser` (new, 16-01 — tag v0.1.0) → `genesis` (16-02..16-06: m0007, KbStore, kb_server, applications
api + web, releases; pins the parser by tag) → `genesis-workflows` (16-03: `sync-application` + Dev/DevOps registry
entries). `genesis-core` likely unchanged (unless we add a reusable HTTP/program-node helper — flag if so). Every
`web/src` change rebuilds + commits `web/static/` (stale-bundle guard). Release order per sub-phase: parser tag first
(so genesis can pin it), then genesis, then genesis-workflows (so a library ref with the workflow + registry exists).

---

## 15. ADR proposals (to add to `reference/decision-log.md`)

- **ADR-036 — Internalized Appian Knowledge Base (Proposed).** Genesis owns the Appian KB: a Genesis-native parser, a
  local KB in `genesis.db`, fed by the **one connected environment** (Deployment REST export + Dev MCP). The external
  Atlas MCP (GitLab-served) and Jarvis-as-KB are **retired as the KB source** (Atlas remains only the design
  inspiration + the interim source until 16-05 cutover). Rationale: remove external moving parts + the daily-freshness
  ceiling + the network round-trip; put freshness/shape under Genesis's control; align with the local single-user,
  one-environment, own-data-plane posture (ADR-023/026/030). Preserves ADR-001 (sync is a deterministic workflow, not
  an agent orchestrator).
- **ADR-037 — Code-free temporal KB + live code via Dev MCP (Proposed).** The KB stores **only** metadata / structure /
  dependency graph / bundles — **never** object source code. All code (current + historical) is fetched **live** from
  the environment through the **Appian Dev MCP** (version-parameterized). Object history is a **temporal SCD-2** model
  keyed to syncs; **user-tagged releases** name points in time; `env_version_ref` bridges a release to the env's version
  for code retrieval. Consequences: KB stays lightweight + always-fresh for code; code reads couple to env
  availability/latency/auth (accepted, known mechanism); historical code depends on Dev MCP versioned retrieval
  (**AP-62096**, targeted 26.8 GA / 2026-08-28; in Code Review as of 2026-08-04).
  Refines ADR-030 (SQLite, `kb_*` tables; pgvector over parsed content would be a future trigger + its own ADR) and
  ADR-010/018 (bulk export/parse → blackboard; only metadata → `kb_*`).
- **ADR-021 note:** the sync pipeline touches Appian **read-only** (export + Dev MCP read); the only write is the
  **local** KB, so **no `pre_mutation` gate** is required. Authoring/deploy (Dev MCP write, DevOps deploy) stays out of
  scope and, when added later, must sit behind `pre_mutation` + copilot confirmation (ADR-021/033).
- **ADR-038 — Managed native Appian MCP servers (Proposed).** The Dev MCP (`lcp-mcp-server`) + DevOps MCP
  (`appian-deployment-mcp`) are integrated as **managed, versioned, opaque, updatable** local servers (installed under
  `~/.genesis/mcp-servers/` via `uv sync`, launched from the per-server venv, registered as a **managed reference** with
  read-only allowlists). **Updatable without forking:** Dev = re-fetch from the connected site's bundle servlet (tracks
  the plugin version); DevOps = configured/drop-in artifact; both versioned + reversible; the bundle is never modified.
  New prereq: `uv` at install time. See 16-08 + the decision log.

---

## 16. Constraints, risks & open questions

- **R1 — Parser fidelity is the tall pole.** *Mitigation:* port the Atlas parser front-half (don't rewrite); test
  against **real** captured packages, not stubs (Phase-12 lesson: "stubbed tests won't catch real tool-output shapes").
  Keep the QName/`typeId` and preamble-coercion lessons in the parser's tests.
- **R2 — Live-code coupling.** Every code read hits the env (latency, availability, auth). *Accepted* (known
  mechanism); `genesis-kb` degrades gracefully (returns metadata + a clear "code unavailable" when the env/Dev MCP is
  down), never fabricates.
- **R3 — Historical code depends on a dated Dev MCP story.** *Status (verified 2026-08-04 via Jira):* **AP-62096**
  (list versions · read a prior version · compare · revert; child of AP-54865) is in **Code Review**, Fix Version
  **26.8 GA (2026-08-28)**; the version-UUID plumbing **AP-51279** (+ AP-52939) is **Done**. 16-06's point-in-time
  *code* view is gated on AP-62096 shipping; metadata history + current code do **not** depend on it (unblocking
  16-01…16-05). Re-check AP-62096's status before starting 16-06's historical-code path.
- **R4 — Delta API is an Appian-side dependency.** *Status:* user owns it ("small app + a few Web APIs"). We design the
  contract with them in 16-07; until then, delta can fall back to **full export + hash-diff** (the SCD-2 merge makes the
  parse side cheap even on a full export).
- **R5 — Cutover parity.** chat/erd/design-doc reference specific `appian-atlas` tool names/shapes. *Mitigation
  (16-05):* `genesis-kb` provides a superset surface; where names differ, update the workflow prompts/allowlists + their
  tests; keep `appian-atlas` registered until the cutover is verified live.
- **R6 — Heavy sync in a subprocess worker.** Export can be tens of MB / ≤300s. *Mitigation:* bulk → blackboard
  (ADR-010/018); default node timeouts (>300s) suffice; `recursion_limit` from META if a per-object parse loop is
  modeled; run tracking/retry come free (ADR-012).
- **R7 — App identity & renames.** Key by **application UUID** (stable across renames). Object renames are UUID-keyed
  (fine); deletes must be explicit in the delta API to close SCD-2 rows.
- **R8 — Bundle recompute cost on delta.** *Decision:* recompute **all** bundles per sync (seconds at 6k objects) rather
  than incremental patching — simpler + correct.
- **R9 — `kb_*` in `genesis.db`.** *Discipline:* namespace `kb_*`; a KB rebuild/untrack is a **table-scoped** operation
  (never touches runs/chat/copilot tables); retention/pruning never reaches `kb_*` and `kb_*` prune never reaches the
  rest.
- **Q1 — Deterministic REST export vs DevOps MCP export.** *Resolved:* **deterministic program-node REST** for the sync
  pipeline (ADR-001, no credits); the DevOps MCP is still **registered** for agent/dev use.
- **Q2 — Parser packaging.** *Resolved:* **new pinned repo `genesis-appian-parser`**; `KbStore` stays in `genesis`.
- **Q3 — Live-code wiring (co-inject Dev MCP vs proxy through `genesis-kb`).** *Leaning:* co-inject (single-purpose
  servers); finalize in 16-05.
- **Q4 — Version auto-detection vs manual tagging.** The user model is **manual tagging** in Genesis; `version_constant`
  is optional metadata for future auto-detection (Atlas-style). Manual is the v1 path.
- **Q5 — Retention.** Keep-last-N releases + prune older SCD-2 rows/snapshots — spec'd but can land after 16-07 (not
  required for correctness at current scale).

---

## 17. Scale analysis (from the counts + real SourceSelection numbers)

SourceSelection (real): ~2,461 objects → ~5,234 dependencies (~2 edges/object). Extrapolating to the user's
**6,000 objects/app**, and **~10 tracked apps** with **~10 releases of retained history**:

| Data | Per app (~6k objects) | ~10 apps + ~10 releases |
|---|---|---|
| `kb_objects` current (no code) | ~6k rows, ~3 MB | ~30–40 MB |
| `kb_dependencies` current | ~12k rows, ~2 MB | ~25 MB |
| `kb_bundles` + members | a few hundred bundles | small |
| SCD-2 history (~15% change/release) | +~1k object rows/release | included above |
| **Total** | **~5–8 MB** | **~50–150 MB** |

SQLite handles multi-GB comfortably; graph BFS over ~12k indexed edges is milliseconds; name search via index (FTS5
later). **Scale is a non-issue for SQLite** at these counts — and it is decisively better than a file tree for the two
hard requirements (cross-app queries, point-in-time reconstruction).

---

## 18. Out of scope (this phase)

- **Writing / deploying Appian objects** (authoring, refactor, promote) — Dev MCP is **read-only** here; DevOps MCP is
  used only for **export**. A later phase adds write/deploy behind `pre_mutation` + copilot confirmation.
- **Folding Jarvis's live *mutation* capabilities** into Genesis (a later track; near-term is KB-source swap only).
- **Semantic / RAG search over parsed content** (pgvector) — a future ADR-030 trigger + its own ADR.
- **Multi-environment** connection (exactly one env; ADR-026 single-user local).
- **Executing anything from the KB** — it is data; the sync never runs Appian code, only reads/exports.
- **Retention automation** may be deferred past 16-07 (see Q5).
