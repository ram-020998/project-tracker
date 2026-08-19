# 26-07 — Release & acceptance

> **Status:** 📋 DRAFT · **Repos:** genesis + genesis-workflows (+ genesis-core only if a helper is added) · **Depends on:** 26-01..26-06 · **Proposed ADRs:** ADR-053 + ADR-054 → **Accepted** here
> **Goal:** Ship the Agentic Memory Layer as a coordinated release, verify CI green, flip ADR-053/054 to Accepted, and update the
> bible + tracker + progress. Follows the bible §8 loop + §6 release protocol.

## 1. Release chain (order matters — pins resolve by tag)
1. **genesis-core** — only if a shared helper is added (likely **unchanged**). If touched: bump + tag + push first; `CORE_MAJOR`
   stays 1 (additive).
2. **genesis** — the store (`memory.db` + `mm0001`), `MemoryStore`/`GraphStore`/`VectorIndex`/`Embedder`, the local embedder dep,
   the `genesis-memory` MCP, the `chat_read` accessor + `ctx.extras` wiring, the two scheduler jobs + `memory_owner_username`
   setting + `GET /api/system/memory`. Bump `[project].version` (**minor** — additive + a new DB) + `FastAPI(version=...)` + tag +
   push.
3. **genesis-workflows** — the `memory-consolidation` + `memory-maintenance` workflows + `registry.json`/`mcp-registry.json`
   (`genesis-memory`) entries; pins the new genesis tag as its dev pin. Bump + tag + push.

`genesis db upgrade` upgrades **both** `genesis.db` (unchanged version) and `memory.db` (`mm0001`). After releasing the workflow
library, `genesis install --from ../genesis-workflows` so a running `genesis serve` can start the new workflows (the §7
"install first" lesson).

## 2. Gates (all green before tagging — the §6 protocol + the §7 "verify the commit is complete" lesson)
- **genesis:** `pytest -q` (memory store/graph/vector/retrieval + workflow-wiring + scheduler + MCP contract + status) + `ruff`
  (pinned `ruff==0.15.20`, §7). `genesis.db` `current_version==N` tests **unchanged** (memory.db is separate); a `memory.db`
  migration round-trip + a fresh+existing upgrade test.
- **genesis-workflows:** `ci/validate_library.py` (7-gate) + `pytest workflows` (the two new workflows) + the **reliability-trio
  lint** on every agent node.
- **web:** only if a status chip/panel lands — else untouched. If it lands: `lint`+`typecheck`+`vitest`+`build` + commit
  `web/static` (stale-bundle guard).
- **CI:** push tags; verify green via `glab ci list -R ramaswamy.u/<repo>` (genesis: `genesis` + `frontend`[if web] +
  `clean-install`; genesis-workflows: the library gate). **Confirm `git status` is clean/fully-staged AFTER staging, BEFORE
  committing** (the v0.51.0 unstaged-file lesson) — memory is many new files; stage the whole `genesis/memory/` tree +
  migrations + MCP + tests.

## 3. ADRs → Accepted + mirrored
- **ADR-053** (Genesis Agentic Memory Layer) and **ADR-054** (memory store/infra + local embedder) flipped Proposed → **Accepted**
  in `bible/04-adrs-and-constraints.md` (§5) and mirrored to `reference/decision-log.md` (the "why").

## 4. Bible / tracker / progress (Definition of Done)
- **bible/01** (§2): add the memory-layer capability to the genesis row + `memory.db`/`mm0001` to the data-plane line + updated
  test counts + the new tags; **bible/03** (§4): the `genesis/memory/**` + `mcp/memory_server.py` modules + the two workflows;
  **bible/04** (§5): ADR-053/054 Accepted; **bible/06** (§7): any new hard-won lessons (e.g. embedder-in-subprocess, sqlite-vec dim
  binding); **bible/08** (§9): flip the Phase-26 block to shipped; the **Last refreshed** banner in bible/00 + `AGENT_ONBOARDING.md`.
- **tracker.md** §6: a status-log entry per sub-phase + the release; **`progress/phase-26-agentic-memory-layer.md`** as-built
  (commits, tags, CI pipeline ids, decisions, deviations). Push project-tracker (`git pull --rebase` → push); discard
  `.obsidian/workspace.json`.

## 5. Acceptance (user-driven / observed — the reasoning can't be driven headlessly)
1. With Kiro signed in and a day of chats present, trigger `memory-consolidation` → `memory.db` gains correctly-scoped
   (personal/shared), typed, **entity-anchored** memories with **relationships**; secrets are absent.
2. Query `genesis-memory` (via chat or a direct tool call) for an application/feature → relevant memories return; personal memory
   returns only the configured user's; `get_related_entities` traverses the graph.
3. Trigger `memory-maintenance` → near-duplicates merge, a contradicted fact is **invalidated (not deleted)**, stale low-value
   memories are archived, communities recomputed — and a second run converges (NOOP-heavy).
4. Leave `genesis serve` up across the nightly slot → `memory-consolidation` fires once, records `last_run_*`; `GET
   /api/system/memory` reflects the counts.
5. Retrieval quality + Kiro reasoning quality are **observed over time** (headless-undrivable) — the manual triggers above are the
   release check.

## 6. Non-goals confirmed at release (see umbrella §9)
Multi-user ACL enforcement; the Postgres+pgvector migration (seam only); a memory-browser UI; hot-path in-turn writes; auto
pre-fetch injection; hard-delete/purge. All are seams-built-now / deferred, recorded in ADR-053/054.
