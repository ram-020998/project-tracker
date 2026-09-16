# Backlog — ERD generation improvements (Lucid ids, layout/grouping, token)

> **Status:** 📝 BACKLOG (not scheduled). · **Created:** 2026-09-16 · **Repos:** genesis-workflows
> (`workflows/erd-generation/`) + the external `erd-gen` CLI (prebuilt binary, ADR-006/Phase-6). ·
> **Origin:** troubleshooting run `r-1b2d8cb87feb` (erd-generation, app "Connected Claims Management",
> 210 tables / 220 relationships) on 2026-09-15/16.

## Context
`erd-generation` fetches an app's schema (Atlas), an agent (`assign_domains`) assigns each table a
**domain**, a program (`assemble`) builds the `erd-gen` input JSON, and the `run_erdgen` CLI node calls
the external **`erd-gen`** binary to render + upload the ERD to **Lucidchart**. The input shape is:
`{title, tables:[{name, domain, fields:[…]}], relationships:[{from,to,type}], domains:{name:hexColor}}`.

Three real issues surfaced (in the order they blocked the run). None is a Genesis platform bug — they're
`erd-generation`/`erd-gen`/Lucid limitations worth fixing so large apps render cleanly and unattended.

## Finding 1 — Lucid auth: `run_erdgen` failed with HTTP 401 "Missing or invalid access token"
- The run reached `assemble` (all agent nodes ok, `assign_domains` even self-recovered a validator retry)
  and then **failed at `run_erdgen`**: `cli_node 'run_erdgen' failed (rc=1): Error: upload: HTTP 401
  {"code":"unauthorized","message":"Missing or invalid access token"}`.
- `erd-gen` handles its own Lucid auth via `erd-gen config --token …` (stored in `~/.config/erd-gen/config.json`);
  the workflow injects no token. The stored token was expired/invalid.
- **Gotcha:** `erd-gen config --check` only verifies a token is **present**, not **valid** — it reported
  `✅ Lucid API token configured` while Lucid still 401'd. So `config --check` is a weak preflight.
- **Fix ideas:** (a) treat a Lucid 401 in `run_erdgen` as an actionable, non-generic error ("refresh the
  erd-gen Lucid token: `erd-gen config --token …`"); (b) add a real *validating* auth preflight (a cheap
  authenticated Lucid call) rather than presence-only; (c) optionally surface the erd-gen token in the
  Settings preflight/readiness like the dev-env creds.

## Finding 2 — Lucid truncates shape ids to 36 chars → **duplicate-id 400 on large apps**
- After the token was fixed, the upload failed with HTTP 400 `invalid_file`: **"Duplicate id"** for several
  tables. `assemble` uses each table's **full `name` as the Lucid shape id**, and **Lucid truncates ids to
  36 characters**. This app had **44 names > 36 chars**, of which **~21 collided into 8 groups** after
  truncation (e.g. 4 tables → `CCM_CFG_CATEGORY_WORKERS_COMPENSATIO`; 3 → `CCM_WFL_CFG_CLAIM_TYPE_WORKFLOW_TA`).
- Lucid keeps the **first** 36 chars, so a suffix does nothing — disambiguation must happen **within** the
  first 36 chars.
- **One-off workaround applied (not a fix):** a script renamed the 13 colliding tables to unique 36-char
  forms (`name[:34] + NN`) and rewrote the matching relationship endpoints, producing
  `~/Genesis/runs/erd-generation/r-1b2d8cb87feb/erd-input.lucidfix.json`, which imported. Those 13 tables
  show shortened/suffixed labels.
- Also observed: **6 dangling relationships** (from/to referencing tables not in the 210 — a source/parse
  artifact); Lucid tolerated them but they should be dropped/repaired.
- **Fix (in `assemble`):** generate **Lucid-safe, unique ≤36-char ids** for every table (deterministic:
  truncate + a short stable disambiguator/hash), keep the **full table name as the display label**
  (separate from the id), map relationship endpoints by the id, and **drop/repair dangling relationships**.
  This makes any large app import cleanly with correct labels.

## Finding 3 — no layout/grouping control → a 210-table single page is congested
- The user's core complaint: "grouping is not proper, everything is too congested."
- `erd-gen generate` exposes **no layout/grouping/pagination flags** (`--input/--output/--title/--token`
  only). It hands tables+relationships to Lucid, which **auto-lays out all 210 on one page**; the exported
  doc has **empty `data.collections`** (no containers/swimlanes). The `domain` field is used **only as a
  fill color**, not as spatial grouping.
- `assign_domains` produced **lopsided domains** (Evaluation 69 / Other 59 / Task Management 45 / AI 22 /
  Vendor 8 / Consensus 7) — "Other" a 59-table dumping ground — so even the coloring read as noise.
- **One-off workaround applied:** re-classified all 210 into **13 balanced functional domains** with a
  deterministic, priority-ordered keyword classifier over the CCM table-name families, regenerated with
  distinct colors. Distribution: Categories & LOB 46, Workflow & Tasks 31, Claims 20, Reference Data 18,
  Customer & Parties 16, Email & Correspondence 16, System/Script-History 15, Financials 14, Policy &
  Product 11, Documents & Comments 9, Surveys & Staff 6, AI Agents 6, Events & History 2. Saved at
  `~/Genesis/runs/erd-generation/r-1b2d8cb87feb/erd-input.regrouped.json`.
- **Reality check:** finer domains improve the **coloring/legend**, but do NOT decongest — Lucid still
  auto-lays one page and doesn't spatially cluster by domain. True decongestion needs either (a) `erd-gen`/
  Lucid layout support (containers/swimlanes per domain, or one page per domain — a feature request to the
  `erd-gen` tool, which is a prebuilt binary we don't own), or (b) splitting into **per-domain ERDs**
  (multiple docs, loses cross-domain edges).
- **Fix ideas:** (1) improve `assign_domains` to emit **finer, balanced functional domains** (or make the
  target granularity configurable) — the CCM keyword taxonomy is a good starting reference; (2) pursue
  `erd-gen` **layout/grouping** (domain containers or per-domain pages) — the only thing that truly
  decongests a large app; (3) offer a per-domain multi-doc mode as a fallback.

## `erd-gen update` limitation (noted)
`erd-gen update --document-id <id>` did a `DELETE /v1/documents/<id>` that returned **404** (token likely
lacks delete scope, or the doc isn't erd-gen-owned) — so "update in place" failed and a fresh `generate`
was used instead. If we want idempotent re-renders of the same doc, this needs the delete scope or an
update path that doesn't delete.

## Artifacts / references (this session's one-offs)
- Run: `r-1b2d8cb87feb` (erd-generation). Blackboard: `~/Genesis/runs/erd-generation/r-1b2d8cb87feb/`
  (`erd-input.json` original, `erd-input.lucidfix.json` id-deduped, `erd-input.regrouped.json` 13-domain).
- Lucid docs created (manual one-offs, can be deleted): `02e1fbd9-0f17-4476-bd96-7ad52786ba6a` (id-fixed,
  6 domains) and `ff7fbf7c-bf14-42dd-9c84-6566d39b11fe` (13 functional domains).
- Token config: `erd-gen config --token "…"` → `~/.config/erd-gen/config.json`.

## Suggested scope when picked up
1. `assemble`: Lucid-safe unique ≤36-char ids + full-name labels + dangling-relationship cleanup (Finding 2).
2. `assign_domains`: finer/balanced functional domains (Finding 3.1).
3. `run_erdgen`/preflight: actionable 401 message + a validating Lucid auth check (Finding 1).
4. Investigate `erd-gen` layout/grouping (containers/per-domain pages) or a per-domain multi-doc fallback
   (Finding 3.2) — likely a request to the `erd-gen` tool owner.
