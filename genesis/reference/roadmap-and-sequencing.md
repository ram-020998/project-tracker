# Genesis — Roadmap & Sequencing

Phase ordering, milestones, dependencies, and the definition of the "complete
application + ERD" milestone (Q13). This is the map; each phase's detail lives in
`specs/phase-0X-*.md`.

---

## 1. Milestones

| Milestone | Phases | Definition of done |
|---|---|---|
| **M1 — Engine works** | 1 | Smoke workflow runs headless; durable resume; MCP injection; reliability trio. |
| **M2 — Authoring works** | 2 | Scaffold → test → publish a workflow; CI enforces the Q9 trio. |
| **M3 — Distribution works** | 3 | Install/update/remove from GitLab; lockfile; loader runs an installed workflow. |
| **M4 — Configurable** | 4 | Fresh-machine setup: token + MCP secrets + environments + health (incl. MCP literal-env probe). |
| **M5 — Supervised runs** | 5 | Start/stream/pause/resume/edit/fork + gates, demoed in Studio. |
| **M6 — Complete app + ERD** ⭐ | 1–6 | The Q13 milestone: full backend + ERD workflow runnable end-to-end (Studio interim UI). |
| **M7 — Product surface** | 7 | Custom web workbench; Studio no longer required. |
| **M7.2 — Foundation hardening** | 07-code-review-fixes | Persistence/migrations, Overview, Integrations Studio, retention, conversation rich-chat (01–06 ✅). |
| **M8 — Settings & config polish** | 8 | Tabbed Settings workspace + one standardized integration master-detail/add-edit pattern (enterprise polish). A few more polish phases planned next. |
| **M9+ — Coverage (deferred)** | backlog: skill migration | Skills migrated wave-by-wave; flagship SDLC pipeline. **Moved to backlog** (was Phase 8/M8) — resumes after the polish phases. |

**M6 is the primary near-term target** ("we should be completing the full
application along with the ERD workflow", Q13).

---

## 2. Dependency graph

```
Phase 1 (engine, nodes, state, checkpointer, MCP registry, reliability trio)
   │
   ├─▶ Phase 2 (contract, library, scaffolder, CI enforcement)
   │        │
   │        ├─▶ Phase 3 (GitLab pull, install, lockfile, loader)
   │        │        │
   │        │        └─▶ Phase 4 (config + secrets + ${VAR} resolution + health)
   │        │                 │
   │        └─────────────────┴─▶ Phase 5 (run lifecycle, streaming, all 3 HITL, Studio)
   │                                   │
   └───────────────────────────────────▶ Phase 6 (ERD reference workflow)  ── M6 ⭐
                                              │
                                              └─▶ Phase 7 (custom workbench)  ── M7
                                              └─▶ Phase 8 (skill migration, waves A–D) ── M8
```

Notes:
- Phase 4 depends on Phase 2 (MCP registry schema/classification) + Phase 3 (token consumed by the GitLab client).
- Phase 5 depends on Phases 1–4 (needs a loadable, configured workflow to run).
- Phase 6 (ERD) is the integration proof and depends on all of 1–5.
- Phases 7 and 8 both build on the M6 foundation and can proceed in parallel.

---

## 3. Build order within the M6 milestone

Even though the goal is "the complete application," build in the dependency order
above and keep each phase independently verifiable (its acceptance criteria).
The ERD workflow (Phase 6) is deliberately last within M6 because it exercises
everything — it is the end-to-end proof, not the starting point.

Within Phase 8, execute in **waves** (see phase-08 spec):
- **Wave A** — read-path (Dev/PO/Docs/shared) — lowest risk, high value.
- **Wave B** — UX + Tester.
- **Wave C** — write/deploy — **gated on the LCP-authoring spike (OD-1)**.
- **Wave D** — the composed `sdlc-pipeline` flagship (doc-19 flow).

---

## 4. Critical-path items & early spikes

Do these early because they gate large downstream scope:

1. **OD-1 LCP-authoring spike** (Phase 8 prerequisite for Waves C/D). Can an `lcp`
   agent node author + verify an Appian object? Run this spike during Phase 4/6
   even though the workflows land later — it determines whether write-path SDLC is real.
2. **OD-2 ACP + `KIRO_API_KEY`** — needed only if we later add any non-interactive
   run context; local interactive login covers M6.
3. **Reliability lint feasibility** (Phase 2) — prove the static graph check can
   detect a missing validator; it underpins the Q9 hard requirement.
4. **MCP literal-env probe** (Phase 4) — prove Kiro passes literal env into a
   docker MCP over ACP; prevents silent run-time MCP-auth failures.

---

## 5. What is explicitly deferred

- **Custom workbench UI** — Phase 7 (Studio is the interim surface for M6).
- **Keychain SecretProvider** — plaintext `0600` for v1 (interface ready).
- **Agent-assisted authoring workflow** — designed in Phase 2, implemented after primitives stabilize.
- **Session pooling** for ACP — only if latency measurements demand it (OD-3).
- **Multi-user / hosted** — out of program scope (local-only, ADR-003).

---

## 6. Tracking

- Master status: `tracker.md` §6 (status log).
- Migration coverage: `genesis-workflows/MIGRATION.md` (Phase 8) — skill → workflow → status, 100% accounted for.
- Each phase's acceptance criteria are the gate to consider that phase done.
