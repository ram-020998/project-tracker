<!--
  L0-core.md — PLACEHOLDER (skeleton created in Phase 47 session S2 / sub-spec 47-02).

  This is the hand-curated always-loaded core. Its real content is authored in 47-05
  (see specs/phase-47-agent-context-system/47-05-*.md) and must stay <= 4K tokens.

  Per 47-02 §6, L0-core.md is resource #1 in the L0 load order and must contain:
    1. What Genesis is — the bible §0 paragraph, verbatim (moved in from bible/00 at 47-04).
    2. The five repos + the repos root path.
    3. The retrieval protocol — how/when to call `genesis-ctx`; never read the bulk
       files (decision-log.md, bible/03/04/06, archive/**) whole.
    4. The key implementation contracts — moved from bible/04 "Key implementation contracts".
    5. The definition of "nothing missed" — every rule is in the generated digests
       (_generated/adr-digest.md, _generated/lesson-digest.md); full text via
       `genesis-ctx adr|lesson`.

  Do not fill this in during 47-02. 47-02 only creates the skeleton.
-->

# L0 core (placeholder — authored in 47-05)

_Intentionally empty. See the comment above and `specs/phase-47-agent-context-system/47-02-layout-and-metadata.md` §6._
