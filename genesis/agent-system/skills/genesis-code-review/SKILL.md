---
name: genesis-code-review
description: Use when reviewing a Genesis diff — how to run genesis-ctx check, answer the rule checklist, read the callers a change can break, apply the severity scale, write the report, and decide the verdict. For the genesis-review agent.
---

# Code review

Standard: `{{TRACKER}}/reference/coding-standards.md` §1 and §5 (already in your L0) and the latest review sub-spec
(`{{GENESIS_HOME}}/bin/genesis-ctx search "review" --archive`). You are READ-ONLY on code; you write only the report.

## Procedure
1. For each changed repo: `{{GENESIS_HOME}}/bin/genesis-ctx check --since <base-rev> --repo <name>` → a checklist of every applicable ADR rule,
   lesson rule and the area gate commands, mapped from the changed files.
2. Read the **diff** (`git -C <repo> diff <base-rev>`), not whole files; pull any rule's full text with
   `{{GENESIS_HOME}}/bin/genesis-ctx adr|lesson <id>`.
3. Read what the diff can break outside itself. When a function's signature, return value or behaviour changes, grep
   its callers in every repo and read those call sites in ranges (L-094). Read the tests of the changed code too.
4. Run the gate commands the check lists (tests, ruff, typecheck, build) to verify the author's claims yourself.
   - Resolve the brief's commit first (`git -C <repo> rev-parse --short <sha>`); if it doesn't exist, review HEAD and
     say so in the report (48-04: a brief named a non-existent sha).
   - Stale-bundle check without touching the tree: `npx vite build --outDir /tmp/<id>-static` then
     `diff -r /tmp/<id>-static web/static` (identical = fresh). An in-tree build dirties `web/static`, and `git clean`
     is denied to you.
5. Answer EVERY checklist line **OK / VIOLATION / N/A**, each with cited evidence (file:line, a test name, command output).
6. Beyond the checklist, look for, in this order:
   - **Bug:** a wrong result, a crash, a missed edge case (empty, zero, last item, time zones), a caller the change
     broke, a fix made in one caller while the shared function stays broken.
   - **Risk:** a secret in code or logs, unchecked input at a trust boundary, a swallowed error or a write order that
     can lose data.
   - **Concurrency:** Genesis is single-user, but two servers, run workers and background jobs share one SQLite DB. Look
     for check-then-write races (L-091), recovery that assumes no peer (L-097), terminal writes that are not a
     compare-and-set (L-108).
   - **Missing test:** risky new logic (a branch, a parser, a data write, a fix) with no test that fails when it breaks.
   - **Lean** (coding-standards §5): code that should not exist, a helper the repo already has (name its path), an
     abstraction or option with one user, near-copies that must change together.

## Before you report a finding
- Give a concrete case: this input or situation gives this wrong result. No case, no finding.
- Re-read the lines to confirm it: the caller exists, the value can be empty, the code really is unused.
- Propose the smallest fix that works; prefer one that deletes code. No style taste, no "consider", no vague worry.

## Severity scale
- **blocker** — ships a bug, violates an ADR, loses data, or breaks a gate.
- **major** — missing regression test for a fix/feature, a lesson regression, a contract/parity break.
- **minor** — style/clarity/edge-case that should change but doesn't block; most lean findings.
- **nit** — optional polish.

## Report template → `specs/<phase>/reviews/<id>-review.md`
```
# Review <id> — base <rev> (genesis-review, <date>)
What this change does: <two or three plain sentences>
## Checklist
- [OK|VIOLATION|N/A] ADR-0NN — <rule>  — evidence
- … (lessons, gates)
## Findings
### Blockers / Majors / Minors / Nits
- B1 **<title>** (`file:line`) — What: <what the code does>. Problem: <the concrete case>. Fix: <smallest fix>.
  If skipped: <what happens>.
## Not checked
<one line per thing that mattered and you could not check, e.g. the live look in both themes; "none" if none>
## Verdict: SHIP | NEEDS_CHANGES
```

## Verdict rule
**SHIP** only when there are no blockers and no majors and every gate is green. Otherwise **NEEDS_CHANGES** with the exact
fixes. A fixed bug without a regression test is a major. Do not rubber-stamp.
