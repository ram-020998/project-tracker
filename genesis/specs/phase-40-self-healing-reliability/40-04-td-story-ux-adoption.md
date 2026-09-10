# 40-04 — technical-design + story-design + ux-design adoption

> **Gate:** independent review = SHIP. Parent: `../phase-40-self-healing-reliability.md`.

## Scope — fan the pattern out to the remaining three workflows
For each of `technical-design-analysis`, `story-design-analysis`, `ux-design-analysis`:
- **Stable ids** on the granular blocks so fixes are addressable: `design_sections.json` sections (TD), `design_objects.json` objects (story-design), per-screen sections (ux — screen ids exist).
- **`verify` → `VerificationReport`** (item-keyed fixes over the granular blocks / HTML).
- **New `heal` agent** (trio-wrapped, full context): `patch` edits **only the flagged section/object/screen block** → the existing deterministic `assemble` re-renders the doc.
- **Rewire via `attach_healing`** — replaces today's `revise → synthesize` (which could not fix frozen per-block content). Restart re-entry: `plan_sections` (TD) / `plan_objects` (story-design) / `screen_inventory` (ux), with guidance injected into their prompts.

## Tests (per workflow)
- a single flagged block → one heal turn patches just that block → re-verify ok (the frozen-block-can't-be-fixed regression is gone).
- large → one guided restart → re-verify → escalate.
- shape validation + pass increment.

## Note
This removes the structural gap in the umbrella §1 (TD/story-design revise→synthesize couldn't touch frozen blocks).
