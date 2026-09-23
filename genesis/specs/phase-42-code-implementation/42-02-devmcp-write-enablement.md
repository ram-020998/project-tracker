# 42-02 — Dev-MCP write enablement (the `appian-dev-write` registry entry)

> **Status:** 🟡 DRAFTED. Repo: **genesis-workflows** (`mcp-registry.json`) + **genesis** (worker injection). Implements **ADR-068** (write) + relaxes **ADR-038** (read-only allowlist). Parent: `specs/phase-42-code-implementation.md`.

## 1. Goal

Enable Dev-MCP object **writes** for the implement/heal nodes ONLY, in isolation from the read-only `appian-dev` used by chat / KB grounding / design — realized as a **dedicated, write-scoped managed-native registry entry** so `appian-dev` stays literally read-only (defense in depth + clean audit; `node.tools ∩ server.allowlist`, ADR-029).

## 2. The new registry entry (`genesis-workflows/mcp-registry.json`)

- **`appian-dev-write`** — the SAME managed-native binary as `appian-dev` (`"managed": "appian-dev"` install; the write entry does not require a second install — it reuses the installed server via the launch provider), env identical (`LCP_URL` + basic auth from the dev-tagged env via ADR-048), **`mode: "read-write"`**, and a **`tool_allowlist` of every `create*`/`update*` tool + `updateObjectSecurity`** across all object modules (interfaces, expression rules, record types + components, constants, process models + nodes, web APIs, sites, connected systems, integrations, folders, groups, applications, portals, record data). **Zero `delete*` tools** (Q3). A `note` documents: write is enabled deliberately (ADR-068), dev-env only, no deletes (deprecate-in-description), injected only by the `story-implementation` implement/heal nodes.
- The exact per-module tool list is copied from the installed `tools/list` filtered to `action_type ∈ {CREATE, UPDATE}` (42-01 §1), minus any destructive-shaped update we choose to withhold (none for v1 — Q11 "include everything" except delete).

## 3. Injection (genesis worker)

- The worker's `launch_provider` already resolves `"managed"` MCP ids to the per-server venv launch spec (ADR-038). `appian-dev-write` resolves to the SAME spec as `appian-dev` (same binary), differing only in the allowlist the registry entry carries — so no second install, no second process contract.
- Only the `story-implementation` **implement** and **heal** agent nodes list `mcp=["appian-dev-write", "genesis-kb"]` + a `tools=` that includes the write tools; every other node keeps `appian-dev`/`genesis-kb` read-only. Effective trust stays `node.tools ∩ server.allowlist`.

## 4. Safety posture (ADR-068)

- **No delete tools exist in the write allowlist** — deletion is impossible by construction; a design that retires an object → `updateX` setting the description to a "deprecated by Genesis — <ticket>" marker.
- **Dev-tagged env only** — auth resolves from the dev environment (ADR-048); there is no other target.
- **Base-version stale-write protection** is enforced by the Dev MCP itself (the object version fields) — a concurrent external edit → the update fails rather than clobbering.
- The write entry is **never** wired into chat, KB grounding, the design workflow, or any read-only node.

## 5. Tests

- A registry-shape test: `appian-dev-write` exists, `mode=read-write`, allowlist ⊇ the expected create/update set, allowlist ∩ `delete*` == ∅ (the no-delete guarantee — a guard test).
- `validate_library` passes with the new entry.

## 6. Out of scope

DevOps/deploy tools (a package deploy is not part of object-level implementation); any `delete*`; non-dev environments.
