# Genesis Agents — Operator Guide

> **Status:** FINAL 2026-10-20 (Phase 47 shipped; ADR-077). Verified live on this machine (Kiro CLI with the V3 engine,
> KAS 0.66.43). Piloted end to end on Phase 48 (2026-10-21) — what changed as a result is in §10. Note anything unclear
> here and ask `genesis-docs` to fix it. Known limits: `specs/backlog/phase-47-follow-ups.md`.

This guide is for you, the human running Genesis development. It tells you which agent to start, when, with what
prompt, and in what order. You never paste the bible again.

---

## 1. At a glance

| Agent | Start it when | You give it | It produces | It may write |
|---|---|---|---|---|
| `genesis-spec` | a new phase / feature begins | the feature idea | findings + umbrella + sub-specs (each with a context manifest) | `project-tracker/genesis/specs/**` |
| `genesis-dev` | to build **one** sub-spec | the sub-spec id | code + tests + local commits + the sub-spec's **As built** | the code repos (local commits only) + the sub-spec |
| `genesis-review` | after all build sub-specs (whole phase), or any time you want a second opinion | phase/sub-spec ids + base tags | a review report (SHIP / NEEDS_CHANGES) + live-acceptance evidence | review reports only |
| `genesis-release` | the review says SHIP and you want to ship | the release sub-spec id | version bumps, tags, pushes (each asked), CI ids, **As run** | version files, commits; tag/push only after you say yes |
| `genesis-docs` | after release (or at any phase end) | the phase id | ADRs, lessons, code map, state, progress doc, changelog, README row | `project-tracker/genesis/**` only |

Every agent starts with the same small core (L0: architecture, work loop, a one-line rule for **every** ADR and lesson,
the area catalog, current state) and the live repo status. Each one pulls the rest itself with `genesis-ctx`.

```
 spec ──► dev (48-02) ──► dev (48-03) ──► … ──► review (+ live acceptance) ──► release ──► docs
          │  each dev session: pack → build → test → sub-agent review → As built → local commit
          └─ one sub-spec per session; a fresh session for the next one
```

---

## 2. One-time setup *(installed 2026-10-20, 47-07)*

```bash
# 1. Kiro CLI with the V3 engine. `kiro-cli --version` prints 2.x — that is fine as long as `--v3` exists:
kiro-cli --help-all | grep -- --v3      # "Launch the next generation Kiro agent"

# 2. (optional) machine settings — only if your paths differ from the defaults, or to override the model
cp /Users/ramaswamy.u/repo/project-tracker/genesis/agent-system/install.conf.example \
   /Users/ramaswamy.u/repo/project-tracker/genesis/agent-system/install.conf

# 3. Install
/Users/ramaswamy.u/repo/project-tracker/genesis/agent-system/install.sh --dry-run   # see the plan
/Users/ramaswamy.u/repo/project-tracker/genesis/agent-system/install.sh

# 4. Check
kiro-cli --v3 agent list | grep genesis-     # five agents
~/.kiro/genesis/bin/genesis-ctx status --brief
```

**Launching.** The profiles are V3-format JSON (`~/.kiro/agents/genesis-*.json`), so every launch line in this guide
uses **`kiro-cli --v3 chat --agent <name>`**. *Optional:* `kiro-cli settings chat.agentEngine v3` makes plain
`kiro-cli` start the V3 engine — but it is a **global** setting that changes the engine for **every** agent and session
on this machine, not only the Genesis ones; leave it unset unless you want that. With it set, the `--v3` in the lines
below is redundant but harmless.

The agents call `genesis-ctx` by its absolute path (`~/.kiro/genesis/bin/genesis-ctx`); your PATH is not changed. For
your own terminal you may add `export PATH="$HOME/.kiro/genesis/bin:$PATH"` (the installer prints this hint).

**Always launch from your root workspace**, e.g. `cd ~/repo-gitlab/ramaswamy.u`. Never from inside project-tracker.
The agents use absolute paths, so the folder you launch from doesn't matter for them; it only keeps unrelated
`README.md`/`AGENTS.md` files out of the context.

---

## 3. Golden rules

1. **One job per session.** One spec session per phase; one dev session per sub-spec; one review, one release, one docs
   session per phase. A fresh session costs ~5 % context; a tired one costs correctness.
2. **Never say "read the bible".** The agent already has the core. If you want it to look at something specific, name
   it ("check ADR-062", "look at the Phase 34 progress doc").
3. **The sub-spec is the handoff.** Specs hand off to dev through the sub-spec + its context manifest; dev hands off to
   review/docs through the **As built** section. If it's not written there, the next session won't know it.
4. **Start a new session at ~60 % context.** The dev agent writes a *Resume note* and tells you; continue with the
   resume prompt (§5.3).
5. **Pushes, tags, fleet restarts and anything destructive are always your call.** The agents ask; answer explicitly.
6. **If an agent says something contradicts an ADR, stop and decide.** That's the system working.
7. **Never launch a Genesis agent with `--trust-all-tools`.** The role boundaries depend on the per-agent
   permission rules and on the `shell-guard.sh` hook, which blocks `git push`/`tag` (every agent but
   `genesis-release`) and any shell write outside the agent's write roots **even under trust-all** — but
   `--trust-all-tools` removes the "ask" backstop for everything else. Launch with
   `kiro-cli --v3 chat --agent genesis-…` and answer the prompts; `genesis-dev` and `genesis-release` in
   particular must never run trusted.

---

## 4. Phase lifecycle — step by step

Replace `NN` with the phase number (e.g. 48) and `<slug>` with its spec folder name.

### Step 1 — Spec session (`genesis-spec`)

```bash
cd ~/repo-gitlab/ramaswamy.u && kiro-cli --v3 chat --agent genesis-spec
```

**Prompt:**

```text
New phase: Phase NN — <title>.

What I want: <2–10 sentences: the problem, who it's for, what "done" looks like, anything you already decided>.

Research it (code, existing specs, and the web where useful), then ask me your questions one at a time until
everything is clear. Then write the spec set in our format: NN-01 findings, the umbrella, and the sub-specs —
the mandatory ones (API or N/A, review & acceptance, release & onboarding) plus the feature-specific ones —
each with a context manifest. Don't write any code.
```

During the session:
- Answer the questions; say "use your default" when you have no preference — it records that too.
- When it has written the set, it runs `genesis-ctx lint --specs-only` itself. Then **you** review the umbrella's
  decisions table and sub-phase ledger.
- Ask for changes in the same session while the context is still well below 60 %.

**Closing prompt:**

```text
Spec approved. Mark it APPROVED (today's date) in the umbrella Status line, update the README row, and commit project-tracker.
Don't push.
```

*(Push yourself, or tell it "push" — it will ask to confirm.)*

### Step 2 — Dev sessions (`genesis-dev`), one per sub-spec

Follow the **build order** in the umbrella's sub-phase ledger. For each sub-spec:

```bash
cd ~/repo-gitlab/ramaswamy.u && kiro-cli --v3 chat --agent genesis-dev
```

**Prompt:**

```text
Implement NN-0X (specs/phase-NN-<slug>/NN-0X-<name>.md).
```

That's usually enough. Optional additions:

```text
Constraints for this session: <e.g. "backend only, the web part is NN-07" / "don't touch genesis-core">.
```

What it does on its own: `genesis-ctx pack NN-0X` → reads the pack + the upstream As-built sections → restates the
task and the ADRs that apply (**read this restatement; it's your cheapest checkpoint**) → builds → runs the gates →
spawns `genesis-review` as a sub-agent → fixes → commits locally → writes **As built** in the sub-spec.

You answer: design questions it raises, and confirmations for anything destructive.

**Closing check (ask if it didn't report it):**

```text
Show me the As built section, the test counts, and the review verdict.
```

### Step 2b — Resuming a sub-spec in a new session

When the agent says context is high, or you come back the next day:

```text
Resume NN-0X. Read its As built / Resume note and continue from there.
```

### Step 3 — Phase review (`genesis-review`)

After the last build sub-spec (before release):

```bash
cd ~/repo-gitlab/ramaswamy.u && kiro-cli --v3 chat --agent genesis-review
```

**Prompt:**

```text
Whole-phase review of Phase NN (specs/phase-NN-<slug>.md). Base revisions: genesis vX.Y.Z,
genesis-workflows vA.B.C (the last released tags), others unchanged. Run genesis-ctx check on each changed repo,
run all gates, and write the review report with a SHIP / NEEDS_CHANGES verdict.
```

- If **NEEDS_CHANGES**: start a `genesis-dev` session with
  `Fix the findings in specs/phase-NN-<slug>/reviews/NN-review.md (items B1, M2, …).` Then re-run the review prompt
  with `Re-review only the fixes.`

### Step 4 — Live acceptance (`genesis-review`, same or new session)

```text
Run the live acceptance in NN-<review & acceptance sub-spec> §<n> against the fleet (:8760, :8761).
Back up the DBs first, stop at every HITL gate and ask me, and save screenshots as evidence.
```

It will ask before updating or restarting the fleet. It never approves a gate on your behalf.

### Step 5 — Release (`genesis-release`)

```bash
cd ~/repo-gitlab/ramaswamy.u && kiro-cli --v3 chat --agent genesis-release
```

**Prompt:**

```text
Release Phase NN per NN-<release sub-spec>. Review verdict is SHIP (reviews/NN-review.md).
```

It bumps versions in the right order (ADR-019), shows you the release commit, and **asks before every tag and push**.
Answer `yes` per repo. Then it watches CI (`glab ci list`) and records the pipeline ids. Fleet refresh only if you say:

```text
CI is green — refresh the fleet.
```

### Step 6 — Documentation write-back (`genesis-docs`)

```bash
cd ~/repo-gitlab/ramaswamy.u && kiro-cli --v3 chat --agent genesis-docs
```

**Prompt:**

```text
Phase NN is released. Do the documentation write-back for Phase NN.
```

It gathers the As-built / As-run sections, review reports and git logs; marks ADRs Accepted; adds lessons, code-map
entries and tags; overwrites the current state; writes the progress doc, the changelog line, the ≤ 5-line tracker entry
and the README row; runs `genesis-ctx index` + `lint`; commits project-tracker and asks before pushing.

**Check:** `genesis-ctx status --brief` in a terminal now shows "Active phase: none — Phase NN complete".

---

## 5. Other situations

### 5.1 A bug (no phase)

`genesis-dev`:

```text
Bug: <what happens, where, steps to reproduce, expected vs actual>.
Areas I think it touches: <e.g. chat, runs-worker> (use genesis-ctx pack --areas to load them).
Write a failing test first, then fix it. Add a lesson candidate if it's a class of bug we could repeat.
```

Then `genesis-release` for a patch release (if you want it shipped) and `genesis-docs`:

```text
Write back the fix for <bug> released as genesis vX.Y.Z (commit <sha>): lesson if any, state, changelog.
```

### 5.2 A small change without a spec

Same as 5.1 with `Change: …` instead of `Bug: …`. If it grows past one session, stop and go to `genesis-spec`.

### 5.3 The spec changes in the middle of the build

Go back to `genesis-spec`:

```text
Change to Phase NN: <what changed and why>. Update the affected sub-specs (and their manifests), record the decision in
NN-01 findings, and list which already-built sub-specs are affected.
```

Then `genesis-dev` on the affected sub-specs: `Rework NN-0X for the change recorded in NN-01 findings §<n>.`

### 5.4 "Why did we do X?" / "When did Y change?"

Any agent (cheapest: `genesis-docs`):

```text
Why did we decide <X>? Look it up with genesis-ctx (ADRs first, then the archive) and cite the sources.
```

### 5.5 A second opinion on any change

`genesis-review`: `Review commits <sha1>..<sha2> in genesis against the rules (genesis-ctx check --since <sha1>).`

### 5.6 Appian-side (Genesis Hub) work

Genesis agents stay read-only against Appian. Hub/app changes still go to the separate write-capable Dev-MCP agent, as
today; the spec agent writes the hand-off prompt (as in 46-09).

---

## 6. Prompt cheat sheet

| Situation | Agent | Prompt |
|---|---|---|
| New phase | spec | `New phase: Phase NN — <title>. What I want: … Research, ask me one question at a time, then write the spec set with manifests. No code.` |
| Approve spec | spec | `Spec approved. Mark APPROVED, update README row, commit. Don't push.` |
| Build a sub-spec | dev | `Implement NN-0X.` |
| Resume | dev | `Resume NN-0X from its As built / Resume note.` |
| Fix review findings | dev | `Fix the findings in reviews/NN-review.md (B1, M2).` |
| Phase review | review | `Whole-phase review of Phase NN. Base: <tags>. Report with verdict.` |
| Live acceptance | review | `Run the live acceptance in NN-<id> §<n>; back up DBs; stop at HITL gates.` |
| Release | release | `Release Phase NN per NN-<release id>. Review is SHIP.` |
| Write-back | docs | `Phase NN is released. Do the documentation write-back.` |
| Bug | dev | `Bug: … Areas: … Failing test first.` |
| History question | docs | `Why/when did we …? Use genesis-ctx, cite sources.` |
| Context check | any | `/context show` |

---

## 7. Context hygiene

- At the start of every session you can type `/context show` to see what's loaded. A fresh `genesis-dev` measured
  **≈ 5.5 %** of the window on 2026-10-20: ≈ 1.6 % is Genesis (the eight L0 files ≈ 14.7K tokens + role prompt +
  status) and ≈ 3.9 % is Kiro's own system prompt and built-in tools, which a plain session has too. After the pack a
  dev agent should stay **≤ 12 %**.
- Let the agents use **sub-agents** for broad exploration (they do this by default); only the summary comes back.
- Prefer a **new session** over compaction when switching sub-specs; compaction is fine within one sub-spec.
- If an agent starts reading huge files whole, say: `Use genesis-ctx for that, not a full read.` (A guard hook also
  blocks the biggest ones.)

---

## 8. Maintaining the agents

All sources live in `project-tracker/genesis/agent-system/`.

Two skills help the agents here: `genesis-ctx` (every agent — all `genesis-ctx` commands, flags, the manifest format and
how packs are built) and `genesis-agent-system` (genesis-docs — how to change agents, skills, hooks and the installer
safely, plus the CLI-3 quirks we found). Every agent also knows the five roles and their handoffs (`context/L0-core.md` §6).

| You want to | Edit | Then |
|---|---|---|
| Change a role's behaviour | `agents/genesis-<role>.json` (the `prompt` string) | `agent-system/update.sh` |
| Change permissions / tools / hooks | the profile's `permissions` / `tools` / `hooks` fields | `update.sh` |
| Change a procedure (release, review, spec format…) | `skills/genesis-<name>/SKILL.md` | `update.sh` |
| Add a skill | new `skills/genesis-<name>/SKILL.md` + add `skill://…` to the profiles that need it **and** name its path in their prompt's "Skills" paragraph (the installer checks) | `update.sh` |
| Pin a different model | `MODEL=` in `install.conf` (overrides the `claude-opus-5.5` pinned in each profile) | `update.sh` |
| Fix `genesis-ctx` | `tools/genesis_ctx/` | nothing — the shim runs the source |
| Add an area | `context/areas.toml` + tags | `genesis-ctx index && genesis-ctx lint` |

`update.sh --dry-run` shows exactly what will change (with diffs); `update.sh --pull` pulls project-tracker first.
Old versions are kept in `~/.kiro/genesis/backups/`. `uninstall.sh` removes only what the installer put there (the
files listed in `~/.kiro/genesis/install.json`). The installer refuses to overwrite a `genesis-*` file it did not
install; `--force` backs it up first.

You can also ask `genesis-docs` to make these edits: `Change the release skill so that … ; then tell me to run update.sh.`

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Agent not listed | Run `install.sh`; check `~/.kiro/agents/genesis-*.json` exists; list with `kiro-cli --v3 agent list` (the V2 engine skips V3-format profiles) |
| Launched without `--v3` | The V2 engine ignores the `permissions` block / skips the profile — relaunch with `kiro-cli --v3 chat --agent …` |
| Agent seems to know nothing about Genesis | `/context show` — the eight L0 files must be listed; if not, `update.sh` (paths may have changed; check `install.conf`) |
| Skill tool lists only `appian`, not the `genesis-*` skills | Expected with this CLI (it registers profile skills only for sessions *created* in that agent's mode). Each prompt names its skills by absolute path and the agent reads the `SKILL.md` directly — no action needed |
| A sub-agent (`genesis-review` spawned by `genesis-dev`) has no status block | SessionStart hooks don't run for sub-agents; its prompt tells it to run `genesis-ctx status --brief` itself |
| "genesis-ctx: command not found" | Agents use the absolute `~/.kiro/genesis/bin/genesis-ctx`; if that is missing → `install.sh`; Python ≥ 3.11 needed. In your own terminal, use the full path or the PATH hint from §2 |
| `install.sh` says "Refusing … not installed by Genesis" | A `genesis-*` file you made yourself sits at a destination; move it, or `install.sh --force` (backs it up) |
| Pack too large (> 60K warning, > 120K fail) | Ask the agent to narrow `areas` in the manifest; nothing is hidden — one-liners stay in L0 |
| Lint fails at the end of a docs/spec session | The Stop hook makes the agent fix it (up to 2 tries); if it still fails, the summary is shown — ask it to fix the listed items |
| Agent missed a rule | Tell `genesis-docs`: `ADR-0NN/L-0NN should apply to <area/path>; fix the tags.` — then it's fixed for every future pack |
| An agent wants to push/tag and you didn't ask | Say no; only `genesis-release` may, and only with your yes |
| You're tempted to pass `--trust-all-tools` | Don't (golden rule 7). `shell-guard.sh` still blocks `git push`/`tag` (non-release) and writes outside the agent's roots under trust-all, but trust-all drops the "ask" gate for everything else. Relaunch without it. |
| `shell-guard` refused a command | It blocks `git push`/`tag` for every agent but `genesis-release`, and shell writes (`>`, `tee`, `cp`, `mv`, `rm`, `sed -i`, `dd of=`) outside the agent's write roots. Use the `write` tool, or a path under `/tmp` or the agent's repo; let `genesis-release` do pushes/tags |

---

## 10. Pilot notes (Phase 48, 2026-10-21)

Phase 48 ran spec → dev ×3 → review → release → docs end to end; the 48-0x As built / review files report no role-boundary
breach and no rule a pack failed to load. What to do differently:

- **Give the reviewer the real commit.** One delta-review brief named a sha that didn't exist; the reviewer fell back to
  HEAD. When you brief a review yourself, paste `git -C <repo> log -1 --oneline` (or just say "HEAD").
- **UI layout needs a browser.** Expect the reviewer to drive the API and headless Playwright (read-only route guard);
  the *look* (both themes, narrow windows) and a two-machine collaboration pull still need you. For table/list UI, ask
  the dev for a real-browser width probe up front (L-090) — Phase 48 spent five delta reviews on narrow-width fixes.
- **One mutating step per tool call.** A parallel edit + build + commit shipped a stale bundle once (48-04 B1), and a
  parallel `gsm provision` + `gsm restart` ran in the wrong order (L-089). The dev, release and review skills now say so;
  if you see an agent batch dependent commands, stop it.
- **Live acceptance may need a server restart on unreleased code.** In 48-04 the dev backed up the DB and restarted :8760
  on the branch so the new routes existed; that is fine when no run is active — the agents ask first.
- **Fleet:** agents call `gsm` by its absolute path (`~/repo-gitlab/ramaswamy.u/genesis-fleet/bin/gsm`) and read the
  running version from `/openapi.json` (`info.version`).
- **As built after the review:** a dev's sub-agent review flags "As built not written yet" as a minor; that's expected
  — the dev writes it after the verdict.
