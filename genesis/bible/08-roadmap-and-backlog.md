<!-- GENESIS BIBLE — CHUNK 08. DO NOT summarize or drop content when editing; keep it verbatim-faithful. -->
> **Part of the Genesis context layer (Phase 47, ADR-077).** Agents load this file **per task** through
> `genesis-ctx` (pack / adr / lesson / area) or by ranged reads — never whole, and there is no "read the bible"
> any more (see [`../AGENT_ONBOARDING.md`](../AGENT_ONBOARDING.md)). This file holds: **§9 Roadmap & backlog — shipped-phase as-builts + what is next.**
> Section numbers (§0–§10) are the original bible sections, kept so old references still resolve.

---

## 9. Roadmap & backlog (what's next — context, not an assignment)

### ✅ SHIPPED — Phase 47: Agent Context System (2026-10-20)

"Read the bible" is replaced by tiered, program-compiled context and five CLI-3 role agents (`genesis-spec/dev/review/
release/docs`) installed globally from `agent-system/`. Spec + as-built: `specs/phase-47-agent-context-system.md`,
`progress/phase-47-agent-context-system.md`; ADR-077 Accepted; follow-ups `specs/backlog/phase-47-follow-ups.md`;
operator guide `agent-system/OPERATOR_GUIDE.md`. project-tracker only — no Genesis release. The live pilot is carried
into Phase 48 (the first phase built end to end with the new agents).

### Deferred items (pointers)

Shipped-phase detail now lives in `archive/bible-08-shipped-phases.md` (Phase 47-04). Open items stay findable here.

**Backlog specs** (`specs/backlog/`):

- [Backlog — Dev MCP browser-based SSO authentication](../specs/backlog/devmcp-browser-sso-auth.md)
- [Backlog — ERD generation improvements (Lucid ids, layout/grouping, token)](../specs/backlog/erd-generation-improvements.md)
- [Backlog — Implementation packages (one deployment package per story)](../specs/backlog/implementation-packages.md)
- [Backlog — Implementation rollback execution](../specs/backlog/implementation-rollback-execution.md)
- [Backlog — Faster incremental sync: stop re-adding every bundle root to each delta package](../specs/backlog/incremental-sync-performance.md)
- [Backlog — Auto KB re-sync after implementation](../specs/backlog/kb-resync-after-implementation.md)
- [Backlog — Multi-repo update version check](../specs/backlog/multi-repo-version-check.md)
- [Phase 15 — Follow-up Fixes (design-doc live-run issues)](../specs/backlog/phase-15-followup-fixes.md)
- [Phase 16 — Deferred / Backlog register](../specs/backlog/phase-16-deferred.md)
- [25-11 — Per-Story Execution & WorkflowRun Linkage](../specs/backlog/phase-25-11-per-story-execution.md)
- [25-12 — AI Cost & Performance Pass](../specs/backlog/phase-25-12-ai-cost-and-performance-pass.md)
- [Backlog — Phase 46 follow-ups (recorded 2026-10-15 at the v0.77.0 release)](../specs/backlog/phase-46-follow-ups.md)
- [Backlog — Skill → Workflow Migration Program (formerly Phase 8)](../specs/backlog/skill-migration-program.md)
- [Backlog — The Object Wiki as agent grounding/memory](../specs/backlog/wiki-as-agent-memory.md)

**Deferred inside shipped phases (not in `specs/backlog/`):**

- PPTX mockup input for the UX Design stage (v1 is PDF-only) (Phase 29) — archived detail: search `genesis-ctx search "PPTX deferred" --archive`
- Memory follow-ups: the 26-05 internal-server node-injection seam (agentic nodes injecting `genesis-memory`), the two 26-08 contextual reuses (Application-detail "Memory" tab + Settings "Your Memory"), a canvas force-graph lib swap; non-goals with seams built: multi-user ACL, Postgres+pgvector migration, auto-prefetch injection, hard-delete/purge (Phase 26) — archived detail: search `genesis-ctx search "node-injection seam" --archive`
- Chat session-provider over the `AgentProvider` interface (ADR-051) (Phase 25) — archived detail: search `genesis-ctx search "chat session-provider deferred" --archive`
- Wheel + package-index transport; Windows-native beyond WSL (Phase 22) — archived detail: search `genesis-ctx search "package-index transport" --archive`
- PDF export of chat transcripts (Markdown export only; browser print for PDF) (Phase 21) — archived detail: search `genesis-ctx search "PDF deferred" --archive`
- Tempo Report parser + generic-haul fallback (Phase 18) — archived detail: search `genesis-ctx search "Tempo Report" --archive`
- Executing bundled skill scripts (ADR-034) (Phase 14) — archived detail: search `genesis-ctx search "executing bundled scripts" --archive`
- Home stat-card sparklines / recent-activity feed (Phase 27) — archived detail: search `genesis-ctx search "sparklines" --archive`

> 📦 Moved verbatim to [archive/bible-08-shipped-phases.md](../archive/bible-08-shipped-phases.md) (Phase 47-04, 2026-10-20). Search with `genesis-ctx search <term> --archive`.

---

- **Backlog (`specs/backlog/`):** the **skill → workflow migration program** (the 45 solutions-copilot
  skills, waves A–D) — deferred; the methodology is intact and resumes when scheduled.
- **Open follow-ups (may be assigned):** the Phase-12 **live run** against a real GAMS ticket/package
  (needs a `genesis serve` restart on ≥ v0.20.2 + the connected jarvis/jira secrets) to confirm per-object
  findings, checklist coverage, SQL checks, the diff baseline rule, and metered credits; restart the
  running `genesis serve` to load v0.20.x; harden the other JSON stores' writes to be atomic (like
  secrets); **rotate the shared `GITLAB_PUSH_TOKEN`** + refresh the expired Artifactory npm token; the
  `lcp` MCP image placeholder (`<lcp-image>`) in `mcp-registry.json`.

**Do not start backlog or a *new* phase unless explicitly asked.** **(As of 2026-10-15 there is NO active build — Phases 1–46 are shipped (Phase 46: genesis v0.77.0 + genesis-workflows v0.22.0; follow-ups in `specs/backlog/phase-46-follow-ups.md`). The Phase-16 note that follows is historical.)** (Phase 16 is **actively being implemented** with the
human's go-ahead — specs are pushed and 16-01/16-02 are shipped + CI-green; continue in the build order per §9's Phase-16
block. This does not authorize starting any phase *beyond* 16 or any `specs/backlog/` work.)

---
