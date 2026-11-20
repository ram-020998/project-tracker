# Genesis phase recipe: proposed step design and open questions

Status: waiting for the user's answers. Nothing has been written to the recipe yet. Once the questions below are
answered, `design-decisions.md` in this directory will record the agreed design.

## Proposed step outline

**Agent per step.** "Orchestrator" means a plain workflow step, not one of the Genesis agents. Every agent step is a
fresh session. Each step prompt tells the agent to run `~/.kiro/genesis/bin/genesis-ctx status --brief` itself, because
the SessionStart hook may not fire inside a workflow step.

**How a step pauses.** The step stops and asks the user, and never answers for them. It pauses for:
- design questions
- any ADR conflict
- anything destructive
- every push

No step pushes on its own. If the user says "push" at a pause, the step tries it. If the CLI denies it inside the
workflow, the step gives the user the command to run themselves.

0. **Read state (orchestrator).** Reads the umbrella's Status line and sub-phase ledger, each sub-spec's As built,
   `reviews/*-review.md`, `genesis-ctx status --brief` and the exit code of `genesis-ctx lint --specs-only`. From these
   it picks the stage to start at.
   - Presence checks are not enough. Phase 54 today has Status SPEC-DRAFTED while 54-02..54-09 are BUILT. Every
     sub-spec has an `## As built` heading from day one, holding a `_(… fill in …)_` placeholder. 54-03 has a
     `### Resume note` even though it is finished. Review files hold several verdicts.
   - So the rules are:
     - **Built:** the ledger row says "— **BUILT**", or the As built starts "**Status:** BUILT" with review SHIP.
     - **Not started:** the As built is still the placeholder.
     - **Resume:** there is a `### Resume note` and the sub-spec is not built.
     - **Verdict:** the last `## Verdict…` heading in the review file wins.
   - **Pause:** the umbrella says SPEC-DRAFTED but some sub-specs are already built. The step asks whether to treat
     the spec as approved.
1. **Worktree setup (orchestrator).** For each of the three code repos:
   - Pause if the tree is dirty.
   - Record `git -C <repo> rev-parse HEAD` and the branch, if one is checked out.
   - Create branch `genesis/phase-NN` and its worktree.
   - Create a separate `.venv` with editable installs, and run `npm ci`. The current `genesis/.venv` has editable
     `.pth` files that point at the main checkout's `packages/*`, so tests run from a worktree would import the user's
     checkout's code.
   - Write the base revisions and paths to a run-state file.
2. **Spec (genesis-spec).** Uses OPERATOR_GUIDE §4 Step 1 prompt. Each Q&A question is a pause.
   - **Pause: spec approval.** On "approved" it uses the closing prompt: mark APPROVED, update the README row, commit
     project-tracker, no push.
3. **Dev stage**, repeated until no unbuilt build sub-spec is left:
   - **3a Pick next (orchestrator).** Takes the ledger rows in order. It skips NN-01 findings, the review & acceptance
     sub-spec, the release & onboarding sub-spec, "N/A" rows and rows already built.
   - **3b genesis-dev.** Prompt: `Implement NN-0X (path)`, plus the worktree rules:
     - run git with the worktree as cwd;
     - pass `genesis-ctx --repos <worktree root>`;
     - give the same `--repos` and the base revision to the genesis-review sub-agent.
     - It fixes the reviewer's findings until SHIP, commits locally and writes As built. Review stays inside this
       step, as the user decided.
   - **3c Resume.** If the sub-spec has a Resume note and is not built, a fresh genesis-dev session runs
     `Resume NN-0X from its As built / Resume note.` After 3 resumes it pauses.
   - **3d Sub-spec gate.** If the sub-spec's banner declares a **Gate**, it pauses for the user's approval. Example:
     54-03's mockup gate (D17).
   - **3e Fold (genesis-spec).** It folds the new As built into the later sub-specs and their manifests: decisions,
     "Changes for NN-xx" notes and the decisions from the user's gate review. It records the decisions in NN-01,
     re-checks the acceptance steps, runs `genesis-ctx lint --specs-only` and commits project-tracker.
     - **Pause:** if a sub-spec that is already built is affected, the user decides whether it gets reworked
       (OPERATOR_GUIDE §5.3).
4. **Whole-phase review (genesis-review).** The base for each repo is its latest released tag from
   `genesis-ctx status`, and the review runs against the worktrees via `--repos`. The report goes to
   `reviews/<review-sub-spec-id>-review.md`, as in the exemplar `53-11-review.md`.
   - **On NEEDS_CHANGES:** a fresh genesis-dev session gets
     `Fix the findings in reviews/<id>-review.md (B1, M2…)`. Then a fresh genesis-review session gets
     `Re-review only the fixes`. Then the verdict is checked again.
   - **Pause** after 3 rounds (53-11 needed 3).
5. **Live acceptance (genesis-review).** Uses OPERATOR_GUIDE §4 Step 4 prompt. It cannot be skipped (L-111).
   - **Pauses:** every HITL gate; every fleet update or restart, which the user runs themselves; the DB backup before
     any fleet update.
   - A failed scenario is a major finding. It goes through the same fix → re-review loop, then the failed rows are
     run again.
6. **Integrate (orchestrator).** For each repo with new commits:
   - Check that the user's checkout is clean and still on the recorded branch.
   - Rebase the worktree branch onto the checkout's current HEAD.
   - On a conflict: abort the rebase and pause.
   - Run `merge --ff-only`.
   - If SHAs changed, write an old→new SHA map, because As built sections and review reports cite SHAs.
   - Remove the worktrees and run `git branch -d`.
   - A detached HEAD has no branch to fast-forward, so the step pauses.
   - This step has to come before release, because the user releases from their own checkout. It therefore cannot be
     the final step, which changes the brief's order.
7. **Docs (genesis-docs).** Depends on question 1.

## Write-root finding (open point 4)

genesis-dev **can** write inside `<repo>/.worktrees/<name>`. Both the profile and shell-guard allow it:
- **Write tool:** `genesis/agent-system/agents/genesis-dev.json:27` allows `{{REPOS}}/**`. The deny rule
  `{{REPOS}}/**/.git/**` on line 28 does not match: a worktree's `.git` is a file, and git writes
  `<repo>/.git/worktrees/<name>/` itself, not through the write tool.
- **shell-guard:** `genesis-dev.json:49` passes `--write-root {{REPOS}}`. The installed copy renders this as
  `/Users/ramaswamy.u/repo-gitlab/ramaswamy.u`. `genesis/agent-system/hooks/shell-guard.sh:465-466` (`inside`) is a
  plain prefix check after normalising the path (457-462). A relative target with no known cwd is refused (line 460).
- **Other agents:** genesis-release is the same (`genesis-release.json` lines 20 and 35). genesis-spec and
  genesis-review are denied writes anywhere under REPOS, as intended.

Three things do break with the in-repo layout:
- **genesis-ctx cannot find the worktrees.** It resolves repos as `<root>/{genesis,genesis-workflows,playwright-appian}`
  (`genesis/agent-system/tools/genesis_ctx/config.py:8,73-80`). The `--repos` override exists (`cli.py:19`), and a probe
  confirmed it works. But no single root gives those three names for `<repo>/.worktrees/<name>`, so pack, check and
  status would read the user's checkout. A sibling layout fixes this: `<REPOS>/.worktrees/phase-NN/<repo>`, passed as
  `--repos <REPOS>/.worktrees/phase-NN`. It is still inside the write root.
- **`.worktrees/` is not ignored** in any of the three repos (`git check-ignore`). The user's checkout would show it as
  untracked, and pytest, ruff and eslint runs in the main checkout would walk into it.
- **dev's git commands only run from the cwd.** Its allow list (`genesis-dev.json:32-33`) has no `git -C` form, so dev
  must run git with the worktree as cwd. This is true for either layout.

## Risks for the recipe-writing step to check

- **Pausing tool:** the Genesis profiles' `tools` lists do not include the workflow messaging tool the steps use to
  pause. If the workflow does not add it, pauses have to be separate orchestrator steps.
- **Live acceptance commands:** acceptance needs `node *` (an "ask" rule), plus `cp`/`sqlite3` for the DB backup and
  `gsm`, which are not on genesis-review's allow list. These have the same unknown that kept release out of the
  workflow. If they are denied, the user runs them at a pause.

## Questions for the user

1. **The docs gap.** Which option?
   - **A.** After step 6 the workflow pauses with "release Phase NN manually, tell me when done", then runs docs with
     the standard prompt. One run, but a long pause.
   - **B.** The run ends after step 6, and docs comes from a later resume run or a manual session. This needs resume
     support (question 2).
   - **C.** Docs runs before release. Not recommended: the genesis-doc-writeback skill needs the new tag
     (`git log <prev>..<new-tag>`, the "Describes" header, ADRs set to Accepted at release).
   - Also: do you accept that integration (step 6) comes before release and docs, instead of last?
2. **Inputs.** Which option?
   - **A.** New phase only: phase number, title and feature idea.
   - **B.** New or resume: phase number required; title and idea only when no umbrella exists; the start stage is
     detected from the files.
   - **C.** B plus an explicit `start_at` override.
   - Also: do you want optional inputs, for example per-session constraints or a maximum number of fix rounds?
3. **project-tracker worktree.**
   - **A.** No worktree. Specs, As built sections and reviews are committed straight to project-tracker `main` during
     the run, so you should not edit specs while it runs.
   - **B.** A worktree. This cannot work without changing the profiles:
     - genesis-spec and genesis-docs commit only with a literal `git -C {{TRACKER}} …` (`genesis-spec.json:25`,
       `genesis-docs.json:31-33`);
     - the write roots are the main path (`genesis-dev.json:27,49`, `genesis-spec.json:20,36`);
     - genesis-ctx finds the tracker from where it is installed (`config.py:68`).
4. **Worktree layout.** In-repo `<repo>/.worktrees/<name>`, as in the brief, or the sibling layout
   `<REPOS>/.worktrees/phase-NN/<repo>`, which genesis-ctx `--repos` can address?
5. **Two optional extra pauses.** Do you want either?
   - Before the fast-forward of your checkout, showing the commits.
   - At a whole-phase SHIP, showing its "Not checked" section before acceptance starts.
