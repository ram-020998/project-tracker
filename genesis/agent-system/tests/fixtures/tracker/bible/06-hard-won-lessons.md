<!-- GENESIS BIBLE — CHUNK 06 (fixture). -->
> **This file is one chunk of the Genesis bible.** Fixture.

---

## 7. Hard-won lessons (do not regress these)

- <!-- L-001 --> **ACP MCP env MUST be a list of `{name,value}`** (`McpRegistry.acp_servers`). A dict silently drops
   env in kiro-cli acp.
- <!-- L-002 --> **Chat sessions stay read-only even when a skill asks to write** (chat). The copilot proposes; a
   human confirms.
- <!-- L-003 --> **SSE frames split on `\r?\n\r?\n`, never `\n\n` alone.** A LF-only fixture hides the bug.
- <!-- L-004 --> **Board membership is explicit, never derived (Phase 36).** Reconciling derived membership carded
   every story.
- <!-- L-005 --> **A bold lead that wraps across
   two lines is still one bold lead.** The parser reads the collapsed bullet.
