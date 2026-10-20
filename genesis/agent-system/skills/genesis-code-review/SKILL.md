---
name: genesis-code-review
description: Use when reviewing a Genesis diff — how to run genesis-ctx check, answer the rule checklist, apply the severity scale, write the report, and decide the verdict. For the genesis-review agent.
---

# Code review

Standard: `{{TRACKER}}/reference/coding-standards.md` §1 (already in your L0) and the latest review sub-spec
(`genesis-ctx search "review" --archive`). You are READ-ONLY on code; you write only the report.

## Procedure
1. For each changed repo: `genesis-ctx check --since <base-rev> --repo <name>` → a checklist of every applicable ADR rule,
   lesson rule and the area gate commands, mapped from the changed files.
2. Read the **diff** (`git -C <repo> diff <base-rev>`), not whole files; pull any rule's full text with
   `genesis-ctx adr|lesson <id>`.
3. Run the gate commands the check lists (tests, ruff, typecheck, build) to verify the author's claims yourself.
4. Answer EVERY checklist line **OK / VIOLATION / N/A**, each with cited evidence (file:line, a test name, command output).

## Severity scale
- **blocker** — ships a bug, violates an ADR, loses data, or breaks a gate.
- **major** — missing regression test for a fix/feature, a lesson regression, a contract/parity break.
- **minor** — style/clarity/edge-case that should change but doesn't block.
- **nit** — optional polish.

## Report template → `specs/<phase>/reviews/<id>-review.md`
```
# Review <id> — base <rev> (genesis-review, <date>)
## Checklist
- [OK|VIOLATION|N/A] ADR-0NN — <rule>  — evidence
- … (lessons, gates)
## Findings
### Blockers / Majors / Minors / Nits  (one bullet each, with file:line + fix)
## Verdict: SHIP | NEEDS_CHANGES
```

## Verdict rule
**SHIP** only when there are no blockers and no majors and every gate is green. Otherwise **NEEDS_CHANGES** with the exact
fixes. A fixed bug without a regression test is a major. Do not rubber-stamp.
