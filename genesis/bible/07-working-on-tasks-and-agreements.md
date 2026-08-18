<!-- GENESIS BIBLE — CHUNK 07. DO NOT summarize or drop content when editing; keep it verbatim-faithful. -->
> **This file is one chunk of the Genesis bible.** The bible is split across `bible/` and indexed by
> [`../AGENT_ONBOARDING.md`](../AGENT_ONBOARDING.md). **When asked to "read the bible", read the index AND every
> chunk it lists, then follow all of it religiously.** This chunk holds: **§8 How to work on ANY task (the loop) + §10 Working agreements.**
> Section numbers (§0–§10) are the ORIGINAL bible sections and are preserved here; the §→chunk map lives in the index.

---

## 8. How to work on ANY task (the loop)

1. **Understand + restate.** State your understanding of the task, which layer(s)/repo(s)/files it touches, and any ADR that applies. Read the relevant spec's "current state" citations and the cited code FIRST — don't guess. For a broad investigation, delegate to a sub-agent to preserve context.
2. **Verify against real code.** For a bug, write a failing test/repro first. For a feature, confirm the backend/API/types already support it (or plan the additions).
3. **Change in the smallest correct scope.** Match existing style/patterns and reuse existing primitives. Don't refactor unrelated code.
4. **Test.** pytest for backend/core; Vitest for web. For bugs, add a regression test that would have caught it — and if a stub hid the bug, fix the stub to mirror reality. Add jest-axe for new interactive UI.
5. **Run all affected gates until green:** backend `pytest` + `ruff`; web `lint` + `tsc` + `vitest`. For web changes, also `npm run build` and **commit the updated `web/static/`** (the stale-bundle guard requires it).
6. **Release (if a code repo changed):** bump version(s) + tag + push + update dependent pins; verify CI green via `glab`. Frontend-only genesis changes still ship a genesis release.
7. **Document:** update `tracker.md` §6 + a `progress/` doc (and the spec/README status tables); push
   project-tracker. **Also refresh THIS doc (`AGENT_ONBOARDING.md`)** when tags/architecture/ADRs/
   hard-won lessons change — §2 (state + tag table + test counts), §4 (map), §5 (ADRs), §7 (lessons),
   §9 (roadmap), and the "Last refreshed" header. Keeping the bible current is part of Definition of Done.
8. **Report with cited evidence** (test output, run ids, CI pipeline ids, file diffs). Be honest about what you verified vs. couldn't — live Kiro/MCP/browser steps can't be driven headlessly; say so and give the manual check.

**When the task is planning/analysis** (not "make this change"): respond with the plan/analysis and, if asked, write it as a spec + update the phase docs — but do NOT start implementing until asked.

---

## 10. Working agreements (how the human wants you to operate)

- **Honest pushback** — correct the human when they're wrong; flag any ADR deviation and confirm before proceeding.
- **Ask before destructive/irreversible actions** (force push, history rewrite, deleting data, anything "prod").
- **Don't push to shared repos beyond the normal Genesis release flow;** never commit secrets; reference secrets by key name only.
- **If stuck twice on the same error,** stop and diagnose the root cause; try a fundamentally different approach.
- **Keep changes scoped** to the task; don't refactor unrelated code.
- **Prefer dedicated tools** (file read/edit/search) over shell equivalents; make independent tool calls in parallel.
- **This document assigns no task** — after restating the architecture + current state + non-negotiables, do the work the human gives you.
