# 07 — Sequencing Plan

No big-bang. Legacy `solutions-os` powers keep working until their replacement is verified.

| Phase | Work | Exit criterion |
|---|---|---|
| **0 — Docs & scaffold** | Write approach docs (this folder). Scaffold `solutions-copilot` per doc 04: `agents/`, `prompts/`, `skills/`, `steering/`, manifest, `setup.sh` skeleton, `.env.example`. | `clone → setup.sh` loads an (empty) agent/skill set on CLI **and** IDE. |
| **1 — Inventory (Gate 1+2)** | Full branch inventory → traceability matrix; review & sign-off. | Matrix at 100% coverage, reviewed. |
| **2 — Vertical slice (Gate 3)** | Shared skills (`sail-reference`, `aurora`, `a11y-audit`) + `atlas-intel` sub-agent + **Developer** role with its skills. | Developer answers a real query end-to-end via atlas-intel; no bundled MCP; works on both surfaces. |
| **3 — Scale (Gate 4)** | `jarvis-intel`, Data-Gen, and the remaining roles (PO, UX, Tester). Migrate all matrix rows. | Every project lands in its target; matrix done; acceptance passes. |
| **4 — Hardening** | `setup.sh` profiles, steering for source-routing, CI manifest validation, CODEOWNERS. **+ BL-1 Environment/Secrets registry, then BL-2 Installer web app/HTML page** (see `10-backlog-future-work.md`; start after the Developer slice). | One-command onboarding < 5 min; CI green; user can manage envs/secrets + install via UI. |
| **5 — Deferred** | Orchestrator (thin router to one role agent); revisit Atlas/Jarvis merge. | Out of scope for v1. |

## Parallelization

- Phase 1 inventory work fans out cleanly **by branch** → ideal for parallel sub-agents.
- Within Phase 3, the three remaining roles are independent → can be built in parallel once the
  vertical slice (Phase 2) proves the pattern.

## Current position

- Phase 0: docs **done**.
- Phase 1: inventory + matrix **done** (awaiting Gate-2 sign-off).
- Phase 2 (vertical slice): **built & structurally validated** — `solutions-copilot` scaffolded with
  a `.kiro/` workspace; `developer` role + `atlas-intel` sub-agent + skills (`appian-explore`,
  `impact-analysis`, `code-review`, `design-document`, shared `sail-reference` with full reference
  bodies) + steering (`source-routing`, `naming-conventions`). `kiro-cli agent list` discovers both
  agents; all JSON valid, all paths resolve, all SKILL.md frontmatter valid.
- **Remaining for Gate 3:** live functional run (needs `GITLAB_TOKEN` + Docker) to confirm
  `developer` → `subagent(atlas-intel)` delegation returns real KB findings end-to-end.
