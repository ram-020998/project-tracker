# Backlog — Re-verify the v3 SDK on kiro-cli 3.x

> **Status:** 📝 BACKLOG (not scheduled). · Created 2026-11-11 from Phase 53 Q17 → D22
> (`specs/phase-53-kiro-sdk-v3/53-01-findings.md` §10.5). · Areas: sdk-acp, chat, core-engine, config-secrets.
> · Trigger: kiro-cli 3.x becomes available on the user's machine (2026-11-11: still 2.37.1, 3.x not offered).

## 1. Why

Phase 53 rebuilt `kiro-agent-sdk` for the v3 engine and verified it on kiro-cli **2.37.1** only: the 53-02 spike,
its 28 fixture pairs under `genesis/packages/kiro-agent-sdk/tests/fixtures/v3/`, the D19 activation probe, and
`tool_ids.json` `kiro_cli_verified: ["2.37.1"]`. Kiro CLI 3.0.0 shipped on 2026-11-03, followed by 3.1.0 (11-05),
3.2.0 (11-10) and 3.2.1 (11-11) ([changelog](https://kiro.dev/changelog/cli/),
[upgrade guide](https://kiro.dev/docs/cli/v3/)). On a 3.x release Genesis shows the "unverified version" warning
(Phase 53 F5) and runs, but the wire frames the SDK depends on may differ.

What the 3.x notes say that touches Phase 53:

| 3.x change | Phase 53 code that depends on it |
|---|---|
| "'Vibe' concept removed … 'Default' mode is the standard name" | 53-04 activation: the fallback agent named in `_kiro/customAgent/not_found` (W4); 53-05 reserved mode ids |
| Fixes to permissions, session reload, Skills, `/model` fallback (3.1.0, 3.2.x) | W15 permission ids and rules; W6 `session/load` replay; W1 skill discovery; W10 model options and the unmeasured fallback frame |
| ACP: "new clients start on V3; existing clients stay on V2 unless already supported" | None: Genesis passes `--agent-engine v3` explicitly. Check the flag is still accepted |
| Session credits shown in `/usage` (3.1.0) | 53-04 `usage.py`: `turn_completion` credit entries (W5) |
| PreCompact / PostCompact Hooks (3.1.0) | 53-04 `compact`: `summarization_completed` (W8) |
| `acp --help` text may change | 53-08 preflight's v3-engine check (`check_kiro()`) |

## 2. Scope

1. Update kiro-cli on the user's machine to the current 3.x. V2 stays available as `kiro-cli --v2` for the user's own
   work. Record the version.
2. Re-run the 53-02 harness (`genesis/scripts/spikes/53-02/`) under a private `KIRO_HOME` for the items the 3.x
   changes touch:
   - the gate items W1–W5;
   - W6 (load), W7 and W7b (steer), W8 (compact), W10 (model; try again to capture a fallback frame), W15 (tool ids
     and rules) and W19 (Stop, with the D15 note).
   Re-run the D19 projection probe for every caller shape, and `check_kiro()` against the real binary.
3. For every behaviour that differs, add a 3.x fixture beside the 2.37.1 one (both stay, so both versions are
   tested), and fix the SDK: for example the fallback-agent name, reserved ids, and preflight parsing.
4. Add the verified 3.x version to `tool_ids.json` `kiro_cli_verified`. Keep 2.37.1 while it is still in use.
5. Live: one workflow node (`hello-appian`) and each chat mode once, on 3.x.
6. Budget: about 5–10 credits. Never write a token or `~/.kiro` contents into evidence (53-02 §3 rules apply).

## 3. When

- If 3.x becomes available **before Phase 53's 53-11 acceptance**: run this as sub-spec 53-13 before 53-11, and
  release with both versions verified.
- If it becomes available **after the Phase 53 release**: run it as its own small phase and ship a patch release
  (genesis `v0.82.x`).
- Until then, a user on 3.x sees the unverified-version warning. If Genesis fails on 3.x, the recovery is
  `kiro-cli` 2.37.1 or this backlog item.

## 4. Done when

Every re-run item has a PASS/FAIL line with evidence; the SDK, genesis-core and genesis suites pass on both versions'
fixtures; `tool_ids.json` lists the 3.x version; genesis-review SHIP.
