# 27-08 — Chat & Copilot

> **Phase 27 (UI/UX Revamp) · sub-phase 08 of 11.** Umbrella: `specs/phase-27-ui-ux-revamp.md`. Depends on: **27-04, 27-05**.
> **Status:** ✅ **BUILT (unreleased) — 2026-08-24** (genesis `f541af1`, LOCAL/untagged; independent review = SHIP).

## Objective
Redesign the conversational surface to the approved mockups, behaviour-preserving: the **Chat** page (session list, thread, composer with the Kiro/ACP parity toolbar + commands palette + images), inline **cards**, the **launch dialog**, and **session outputs**.

## Scope (components)
`chat/{ChatPage,ChatThread,Composer,SessionList,cards,LaunchDialog,SessionOutputs,conversation}`.

## Deliverables
- Modern chat layout: session list + thread + composer, with a refined message/typography rhythm, streaming affordances, and the parity toolbar/commands palette restyled.
- Inline agent cards + session outputs re-themed to the new language; attachment/image UX.
- Empty/loading/streaming/error states consistent with the pattern library.

## Acceptance / gates
- Chat streaming, commands, model select, clear/compact, images, and launch-from-chat all work; chat/copilot/skills-chat tests updated + green.
- Light default + dark parity; jest-axe green; long-thread performance acceptable; responsive.
- `tsc/eslint/vitest/build` green; `web/static` rebuilt + committed; released per umbrella §5.

## Out of scope
No change to chat/ACP protocol, session modes, or MCP wiring (presentation only).
