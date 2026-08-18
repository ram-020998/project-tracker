# 25-07 — ChatModeProfile (compose chat modes)

- **Status:** ✅ BUILT (2026-08-18, commit `4cfb3fe`) — `ChatModeProfile` drives all per-mode behavior; branch-free session methods; posture regression + no-`self.mode==` guard green. **NOT released** (ships via 25-14). · **Review items:** C-4 · **Roadmap:** Phase 2 · **Repos:** genesis · **Depends on:** nothing (pairs naturally with 25-06)

## As built (commit `4cfb3fe`; 551 pytest [+8] + ruff green)
- **`genesis/chat/mode_profile.py` (NEW):** frozen `ChatModeProfile` (`name`, `mcp_mode`, `permission_mode`, `uses_control_token`, `cwd_sandbox`, `extra_trust`, `steering`, `requires_copilot_enabled`) + `PROFILES{read_only,copilot,feature_spec}` + `resolve_profile(mode, mgr)` (unknown → read_only; copilot with kill-switch off → read_only). The three steering constants relocated here (no test referenced them).
- **`chat/manager.py`:** `_ensure_started` resolves the profile once and builds a **single** `Options(**kwargs)` from its fields (the two divergent `Options(...)` blocks + the cwd/trust/kill-switch branches removed); the 3-way steering pick is now `self.profile.steering`. 716 → 639 LOC.
- **Design note (minor deviation):** `build_chat_mcp` kept intact (well-tested, called directly elsewhere) — the profile supplies its `mode` arg rather than folding the wiring into a `profile.mcp_servers` callable. Lower risk, same outcome.
- **Security posture ported verbatim** and pinned by `tests/test_chat_mode_profile.py` (read_only=auto_deny/no-control; copilot=ask+token+control-read-trusted; feature_spec=fs_read/fs_write+sandbox cwd) + a guard asserting **no `self.mode ==`** remains in manager.py. Existing `test_copilot_mode`/`safety`/`e2e`/`features_api`/`chat_api` unchanged.
- **DoD:** met except genesis release CI + progress doc → deferred to the **25-14** capstone (unreleased; version held 0.48.7).

## 1. Goal
Replace the string-`mode` branching scattered through `ChatSession`/`ChatManager` with a **`ChatModeProfile`** resolved once per session — composition over conditionals — so adding a chat mode is one profile definition, not edits across seven methods.

## 2. Why (review evidence)
- **C-4:** `chat/manager.py` branches on `self.mode == "copilot" / "feature_spec"` in ~7 places (verified: lines 159, 167, 196, 200, 310, 312, 577) for cwd, trust set, MCP wiring, permission behavior, and enablement.
- This is the closest thing in the codebase to the review's `if stage == ...: elif ...:` anti-pattern. Bounded today (3 modes: `read_only`, `copilot`, `feature_spec`) — hence **Medium**, but it will grow (a future "design"/"review" authoring mode).

## 3. Current state (cited)
- Modes: `read_only`, `copilot`, `feature_spec` (`create_session(..., mode=...)`).
- Per-mode differences currently branched inline: **cwd** (`state_dir` vs skill-output sandbox), **fs_write_root**, **trust_tools** (read-only vs fs_read/fs_write for feature_spec), **mcp servers** (genesis-kb / control server / atlas), **permission_mode** (auto_deny vs ask), **enablement gate** (copilot kill-switch).

## 4. Design
### 4.1 The profile (`chat/mode_profile.py` — NEW)
```python
@dataclass(frozen=True)
class ChatModeProfile:
    name: str
    cwd: Callable[[Settings, str], Path]     # (settings, session_id) -> cwd
    fs_write_root: Callable[[Settings, str], Path] | None
    trust_tools: tuple[str, ...]             # namespaced @server/tool allowlist
    mcp_servers: Callable[[deps], list]      # which servers to wire
    permission_mode: str                     # "auto_deny" | "ask"
    enabled: Callable[[deps], bool]           # e.g. copilot kill-switch
PROFILES: dict[str, ChatModeProfile] = {"read_only": ..., "copilot": ..., "feature_spec": ...}
```
- `ChatSession` holds a resolved `profile` and reads `self.profile.trust_tools` etc. — **no `if mode ==`** remains in the session/manager methods.
- The existing `chat/mcp.py` mode wiring (`if mode == "copilot"`) folds into `profile.mcp_servers`.
- Aligns with 25-05: the profile produces `AgentTurnOptions`, provider-neutral.

### 4.2 Adding a mode
= add one `ChatModeProfile` to `PROFILES` (+ its trust set). No method edits. A guard test asserts no `self.mode ==` comparisons remain in `chat/manager.py`.

## 5. Files touched
- **New:** `chat/mode_profile.py`, `tests/test_chat_mode_profile.py`.
- **Edit:** `chat/manager.py` (resolve + consume profile; delete the branches), `chat/mcp.py` (mode wiring → profile).

## 6. Tests
- Each profile resolves the expected cwd/trust/mcp/permission (table test).
- Read-only stays read-only (ADR-031 regression: `auto_deny`, read-only trust set), feature_spec keeps fs_read/fs_write + sandbox cwd (Phase-20 lesson), copilot keeps the ask-bridge + kill-switch.
- Guard: no `mode ==` branch remains in the session methods.

## 7. Risks & mitigations
- **Risk:** silently changing a mode's trust/permission (security-sensitive — ADR-031/033/034). **Mitigation:** port each profile field verbatim from the current branches; the regression tests above assert the exact trust/permission per mode.

## 8. Out of scope
New chat modes; the broader ChatManager responsibility split (that's part of 25-06 if pursued).

## 9. Definition of Done
`ChatModeProfile` drives all per-mode behavior; branch-free session methods; security-posture regression tests green (read-only/copilot/feature_spec unchanged); genesis release CI-green; progress doc.
