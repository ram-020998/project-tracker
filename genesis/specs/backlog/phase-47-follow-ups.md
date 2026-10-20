# Backlog — Phase 47 follow-ups (agent context system)

> **Status:** 📝 BACKLOG (not scheduled). · **Created:** 2026-10-20 · **Repo:** project-tracker (`genesis/agent-system/`)
> Source: `specs/phase-47-agent-context-system/reviews/47-09-review.md` (round 3). None blocks normal use.

1. **B2 — allow-listed commands that write through flags (known minor, accepted).** `ruff format`, `ruff check --fix`,
   `*/.venv/bin/ruff format`, `git diff|log --output=<path>` and `genesis-ctx … --out <path>` match existing allow rules
   and are not seen by `shell-guard.sh` (it checks redirects/`tee`/`cp`/`mv`/`rm`/`sed -i`/`dd`, not flags). Effect: the
   read-only reviewer could auto-format/lint-fix uncommitted code, or overwrite one file. Suggested remedy (≈10 min):
   shell `deny` rules — genesis-review: `*ruff format*`, `*--fix*`, `*--unsafe-fixes*`, `*--output*`, `* --out *`,
   `* -o *`, `*--write*`; genesis-spec/docs: `*--output*`, `* --out *`; genesis-dev unchanged. Tests + `update.sh`.
2. **`--trust-all-tools`-only gaps.** `touch`, `ln -s`, `python -c "open(…)"`, `git checkout`, `echo push | xargs git`,
   `git send-pack`. Without trust-all these still prompt for approval. Mitigation in place: OPERATOR_GUIDE golden rule
   7 ("never launch Genesis agents with `--trust-all-tools`"). Optional: extend `shell-guard.sh`.
3. **Skills via prompt paths.** In KAS 0.66.43 profile `skill://` resources are not registered when a session starts
   with `chat --agent` (default session, then switch); every role prompt lists absolute `SKILL.md` paths instead (the
   installer enforces it). Re-check on each CLI upgrade; drop the prompt list if native registration works.
4. **Docs-agent area additions (47-08 dry run).** The Phase-46 dry run proposed area additions for ADR-075/076 beyond
   the 47-08 routing table — confirm them in the first real write-back (Phase 48).
5. **Ruff `ambiguous variable name` warnings** (22, pre-existing) in `agent-system/tools/genesis_ctx/` — cosmetic.
6. **Live pilot (47-09 §5)** — carried into Phase 48 (the first phase built end to end with the new agents); record the
   `/context show` numbers and any operator-guide gaps there.
