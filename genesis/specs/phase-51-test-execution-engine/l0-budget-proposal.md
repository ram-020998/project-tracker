# L0 budget proposal (Phase 51) — PROPOSAL, not applied

> **Status:** PROPOSED 2026-11-02 by genesis-docs (51-02 review-fix session). Needs the user's choice before anyone
> applies it. Measured with `genesis-ctx`'s own estimator (characters / 2.5, `tools/genesis_ctx/config.py` `tokens`).

## 1. Why

`genesis-ctx lint` reports **L0 ~23,845 / 24,000** tokens (`L0_BUDGET`). 51-13 adds four ADR digest lines
(ADR-081..084). At today's average digest line (~87 tokens per ADR line including its area tags) that is about
**+350**, so lint would fail at ~24,200. Goal: free **at least 600** tokens without dropping any rule, one home per fact.

Where the 23,845 tokens are today:

| L0 file | ~tokens |
|---|---:|
| `context/_generated/lesson-digest.md` | 7,367 |
| `context/_generated/adr-digest.md` | 6,946 |
| `context/L0-core.md` | 2,669 |
| `context/state/current.md` | 2,612 |
| `bible/07-working-on-tasks-and-agreements.md` | 1,559 |
| `bible/02-architecture.md` | 1,412 |
| `context/_generated/area-catalog.md` | 1,280 |

## 2. Option A (recommended): drop the area tags from the two generated digests — frees ~2,820

Every digest line carries its routing tags, e.g. `- ADR-001 [core-engine,runs-worker,chat,workflows-library,features-stages] — …`.
The rule text, the `{amended}`/`{superseded}` flag and the amendment links stay; only the `[areas]` bracket goes.

| Cut | ~tokens | Where the text already lives |
|---|---:|---|
| A1 `[areas]` on 80 ADR digest lines | 1,506 | `context/tags/adr.toml` `areas` (the source); printed by `genesis-ctx adr <id>` (meta line), `genesis-ctx area <name>` (ADR list), and used by `pack` / `check` routing |
| A2 `[areas]` on 100 lesson digest lines | 1,314 | `context/tags/lesson.toml` `areas`; printed by `genesis-ctx lesson <id>` and `genesis-ctx area <name>` |

- **Change:** `agent-system/tools/genesis_ctx/index.py` `adr_digest` (line 36) and `lesson_digest` (line 48) stop
  emitting the bracket (keep `[untagged]` for an untagged id, so a routing gap stays visible); each digest's header line
  gains "Areas: `genesis-ctx area <name>`". Tests: `tests/test_commands.py:253` (the expected `- L-001 [chat,core-engine] — …`
  line) and any fixture expectations. Then `genesis-ctx index && genesis-ctx lint`.
- **After:** L0 ≈ 21,025; ADR-081..084 bring it to ≈ 21,400, leaving ~2,600 for later phases.
- **Trade-off:** an agent with no pack can no longer see from the digest which rules belong to an area. It runs
  `genesis-ctx area <name>` or `pack --areas …`, one call — the program-selection path ADR-077 asks for
  ("rules are selected by program … never by search"). No rule text and no ADR/lesson id leaves L0.

## 3. Option B: text-only edits, no tool change — frees ~810

| Cut | ~tokens | Where the text already lives |
|---|---:|---|
| B1 Remove `context/L0-core.md` §5 "Non-negotiables in one breath" (5 bullets) | 234 | `bible/07` §10 (in L0): honest pushback + flag ADR deviations, ask before destructive actions, no pushes beyond the release flow, never commit secrets / key names only, stuck twice → root cause, scoped changes. "Re-read the full lesson before touching its area" = L0-core §3 ("Before acting on an area, get the full text"). Every role prompt repeats "ADRs are non-negotiable; lessons are do-not-regress; ask before destructive or irreversible actions". |
| B2 Shrink the `bible/02` and `bible/07` preamble blockquotes to one line each (`> Always-loaded core (ADR-077); §-numbers are the original bible sections.`) | ~360 (442 → ~80) | `AGENT_ONBOARDING.md` (no "read the bible"; the L0 list), ADR-077 (tiers). The `<!-- GENESIS BIBLE — CHUNK NN … -->` comment line stays. |
| B3 State "Agent system (Phase 47)" bullet → one line ("five role agents, see L0-core §6 and `agent-system/OPERATOR_GUIDE.md`") | ~165 (206 → ~40) | L0-core §6 (agents, launch command, never `--trust-all-tools`), `OPERATOR_GUIDE.md` §2 (install/update/uninstall). Apply in the Phase 51 write-back, which overwrites the state anyway. |
| B4 `bible/02` §3 "Release/versioning (ADR-019)" paragraph → one sentence pointing at ADR-019 + ADR-080 | ~50 | ADR-019 / ADR-080 digest lines and full text. **Also a correctness fix:** the paragraph still describes "git+ssh tag pins along genesis → genesis-core → kiro-agent-sdk", which ADR-080 replaced (one repo, one tag). |

- **After:** L0 ≈ 23,035; ADR-081..084 bring it to ≈ 23,385 (~600 headroom: about one more phase).
- **Check before applying B2/B4:** `bible/02` and `bible/07` are verbatim chunks under `verify-lossless`; the preambles
  were added in Phase 47, but run `genesis-ctx verify-lossless` after the edit to prove no baseline unit is lost.

## 4. Also possible, not recommended now

- Strip the provenance tails from lesson digest lines (`… (Phase 16-02).`, `(v0.51.0 → v0.51.1)`): ~596 tokens on 72
  lines. The phase is in `context/tags/lesson.toml` `phase` and in the full text. Not recommended: the tail is often
  the only cue to how recent or how live-verified a lesson is, and the change would need a `rule` override in the tags
  or a regex in the generator.
- Shorten L0-core §1 "What Genesis is" (714): it is the product description and the only place that states the
  workflow/skill split in prose; ADR-034's digest line does not carry the provisioning path or the `/` palette.

## 5. Recommendation

Apply **A** (generator change, ~2,820) in the 51-13 write-back before adding ADR-081..084, and **B4** regardless
(stale text). B1–B3 only if A is rejected. Either way the change is genesis-docs work in project-tracker
(`agent-system/` + `context/`), with the agent-system suite and `genesis-ctx lint` green, and `update.sh` is not needed
(the digests are read from the tracker, not installed).
