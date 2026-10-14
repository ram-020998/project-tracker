# 46-07 — Web experience (spec workspace, CR flow, preview tabs, coverage)

> **Status:** 🟡 DRAFTED 2026-10-14. Repo: **genesis** (`web/`). Parent: `specs/phase-46-spec-change-requests.md`.
> Story-side UI (answers, references, history, badges) is in 46-08. Follows ADR-055 (design language, tokens, no
> hard-coded brand hex) and ADR-028 (typed client, `/api` prefix centrally); every new interactive surface gets a
> jest-axe test; `web/static` rebuilt and committed.

## 1. Principles

- **One place.** Everything happens in the spec's stage workspace: the toolbar, a CR banner, the chat, and the
  full-screen preview. No new pages.
- **Two clicks matter:** **Analyze impact** (prepare) and **Apply changes** (commit). Both always say what they
  will do before doing it.
- **The document is the truth.** The CR document shows exactly what Apply will execute; the chat is where it is
  discussed.

## 2. Spec workspace toolbar (`StageArtifactWorkspace.tsx`, spec stage)

| Spec state | Toolbar actions (left → right, existing items unchanged unless noted) |
|---|---|
| Draft / In progress / In review | unchanged (Start / Submit for review / Approve / Request changes) |
| Completed, breakdown **not** complete | unchanged (**Reopen**) |
| Completed, breakdown complete or stories finalized | **Initiate change request** (primary) replaces Reopen · **Change requests (n)** · Export .md · Publish to team · Preview. *Save milestone hidden.* |
| Under change | status badge **"Under change · CR-03"** (warning tone) · **Change requests (n)** · Export .md (working copy) · Preview. *Save milestone and Publish hidden.* The CR banner (§4) appears under the toolbar. |
| Pulled read-only mirror | no actions except **Change requests (n)** (read-only) and Preview; when the owner has a CR open: an `AdvisoryMarker` "Spec under change by ram" (46-09 §5). |

`status.ts`: `SPEC_STATUSES` += `under-change`; `SPEC_STATUS_LABEL["under-change"] = "Under change"`;
`specStatusTone("under-change") = "warning"`; `SPEC_ACTION_LABEL` is unchanged (CR actions are not generic actions).
`types/features.ts`: `SpecStatus` += `"under-change"`; new `ChangeRequest`, `ChangeRequestDetail`, `CrAnalysis`,
`CrPlanValidation`, `ApplyReport`, `ClauseCoverage` types mirroring 46-04 §5 / 46-05 / 46-06 §8.

## 3. Initiate change request

`InitiateChangeRequestDialog`: title "Start change request CR-03"; one optional field "What's changing?"
(placeholder "e.g. Accept LEI for corporate applicants"); text: "While CR-03 is open, developers keep working from
spec revision 6. Your edits take effect only when you apply the change request." Buttons **Start CR-03** /
Cancel. On success the chat shows the CR divider and the banner appears.

## 4. The CR banner (`ChangeRequestBanner`)

A slim bar under the toolbar, one row, content by `analysis.state`:

| State | Text | Buttons |
|---|---|---|
| No analysis yet | "**CR-03 open** — edit the spec in the chat, then analyze the impact on stories." | **Analyze impact** · Discard change request |
| Analyzing (chat turn streaming) | "Analyzing the impact of CR-03…" (spinner) | — |
| Awaiting plan (analysis computed, no plan for it yet, chat idle) | "The impact input is ready but the agent hasn't written the plan yet." | **Ask the agent to write the plan** (sends "Please write ./cr/CR-03/plan.json for the latest impact analysis.") · Analyze again · Discard |
| Current, plan valid | "**CR-03 impact analysis ready** — 3 to update · 1 new · 2 unchanged (past Design)." | Open impact analysis · **Apply changes** · Analyze again · Discard |
| Current, plan has errors | "The impact analysis has **2 problems** to resolve." | Open impact analysis · **Ask the agent to fix** · Discard |
| Stale | "You changed the spec after the analysis." | **Analyze impact** · Open previous analysis · Discard |

- **Analyze impact** → `POST …/analyze`; if `no_changes`, toast "No spec changes since CR-03 opened". Otherwise the
  web sends the visible chat message "Analyze impact for CR-03." through the normal `ChatThread` send path (the
  agent instructions arrive as an agent note posted by the endpoint). When the turn ends, the banner refetches the CR
  detail.
- **Ask the agent to fix** sends "Please fix these problems in plan.json: …" with the validation errors.
- **Open impact analysis** opens the preview on the CR tab (§6).
- Disabled states always carry a tooltip with the reason (e.g. "Wait for the chat to finish").

## 5. Apply and discard dialogs

**`ApplyChangesDialog`** (opened by Apply changes; fetches the CR detail first):
- Heading "Apply CR-03?"; a compact summary list: "Update 3 stories", "Create 1 story", "Remove 0 stories",
  "Leave 2 stories unchanged (past Design)", "Spec becomes revision 7", "UX Design and Technical Design will be
  marked *spec changed*".
- **Locked changes** (only when the plan changes a Design Review+ story at the user's request): a warning box with
  one checkbox per story — "Change **GNS_000057** (Implementation) as you asked" — all must be ticked to enable
  Apply; their IDs are sent as `confirm_locked_story_ids`.
- Buttons **Apply changes** / Cancel. On 409 `apply_blocked` the dialog lists the blockers with the next step
  ("Analyze impact again").
- On success: toast "CR-03 applied — 3 updated, 1 created"; the banner disappears; the toolbar returns to the
  Completed set; the preview CR tab shows the frozen *Applied* document.

**`DiscardChangeRequestDialog`**: "Discard CR-03? The spec goes back to revision 6. No stories change. The CR stays
in the list as *Discarded*." Buttons **Discard CR-03** (destructive tone) / Cancel.

## 6. Preview with tabs (`AnnotatablePreviewDialog`)

- Gains a `documents: {key, label, artifactUrl}[]` prop (backward compatible: a single document → no tab strip).
- While a CR is open (or when opened from the CR list), the tabs are **Spec** (working copy) and
  **CR-03 Impact Analysis**. Opening from the CR list of a closed CR shows that CR's frozen document plus the spec
  revision it produced.
- Annotations work on both tabs; the composed chat message names the document
  (`> [CR-03 Impact Analysis] "GNS_000057 …"` + the comment) so the agent knows which file the comment is about.
- **Refresh** re-renders the current tab (the CR document is rendered live from the plan, 46-05 §9).

## 7. Clause numbers and coverage in the spec preview

- The served spec shows clause labels in the left margin and a badge in the right margin (46-02 §11): filled with the
  number of stories (or backlog items), **hollow "no story"** when uncovered, dashed when only suggested links exist.
- Clicking a badge posts `genesis:clause` to the host; `ClauseCoveragePopover` (anchored near the dialog's
  right edge) lists the items: key, title, lane chip, a "suggested" tag where applicable; each row links to the
  Story Workspace (`/applications/:app/stories/:id?from=feature`) in a new tab. Uses `GET …/spec/coverage`.
- Toolbar inside the preview: a **Coverage** toggle (default on when items exist) to hide/show the margin badges.

## 8. "Link stories to the spec" banner (existing features)

Shown in the spec workspace when `coverage.unlinked_items > 0` and the `spec-story-linking` workflow is installed:
"**12 stories aren't linked to the spec yet.** Link them so spec changes can find the stories they affect."
Button **Link stories to the spec** → `POST …/spec/link-stories` → a run link ("Linking… view run") → on
completion the banner disappears and the coverage badges appear. Not shown while a CR is open.

## 9. Change requests list (`ChangeRequestsPanel`)

Opened from **Change requests (n)** as a right-side `Drawer`. Rows newest first: **CR-03** · title · status chip
(Open / Applied / Discarded) · opened by + date · closed date · "rev 6 → 7" · counts ("3 updated · 1 created").
Clicking a row opens the preview on that CR's document. Empty state: "No change requests yet. Once the breakdown is
complete, spec changes go through change requests."

## 10. Elsewhere

- **Feature overview, Spec stage card:** a chip "CR-03 open" (warning) or "Last change: CR-02 · 12 Oct" (neutral).
- **Feature Activity feed:** the audited transitions already appear; render `initiate-change` / `apply-change` /
  `discard-change` with friendly text ("ram opened CR-03", "ram applied CR-03").
- **Chat dividers (`ChatThread`):** `system` messages with `meta.kind` ∈ `cr-divider | cr-analyzed | cr-applied |
  cr-discarded` render as a full-width divider with the CR label and a link "Open CR-03"; other system messages keep
  `SystemNudge`. The chat API includes `meta` (parsed `meta_json`, **without** `agent_text`) on messages.

## 11. Client plumbing

`lib/api/features.ts` (or `changeRequests.ts`): `listChangeRequests`, `getChangeRequest`, `initiateChangeRequest`,
`analyzeChangeRequest`, `applyChangeRequest`, `discardChangeRequest`, `crDocumentUrlFor`, `crExportUrlFor`,
`specCoverage`, `specClauses`, `linkStories`. `lib/query/keys.ts`: `qk.features.changeRequests(featureId)`,
`qk.features.changeRequest(featureId, crNo)`, `qk.features.specCoverage(featureId)`. Hooks in
`features/features/hooks.ts`: `useChangeRequests`, `useChangeRequest` (polls every 5 s while a chat turn is
streaming), `useInitiateChangeRequest`, `useAnalyzeChangeRequest`, `useApplyChangeRequest`,
`useDiscardChangeRequest`, `useSpecCoverage`, `useLinkStories`. Mutations invalidate the spec, its `allowed`, the CR
queries, coverage, and the feature's stories.

## 12. Tests (Vitest + RTL + MSW + jest-axe)

Toolbar per state (§2 table); Initiate dialog; banner per analysis state incl. disabled tooltips; Analyze →
`no_changes` toast vs chat send; Apply dialog summary + locked-story checkboxes gate the button + 409 blocker list;
Discard dialog; preview tabs (single-document back-compat, annotation message names the document); coverage popover
from a `genesis:clause` message; link-stories banner visibility; CR list; chat divider rendering; feature card chip;
jest-axe on the workspace in Under change, the three dialogs, the drawer and the popover.

## 13. Acceptance (manual, live)

On a finalized feature: Initiate CR-01 → edit two clauses and add one in the chat → Analyze impact → the document
lists the right stories with sensible defaults → change one decision in the chat → the document updates → Apply →
stories updated/created, document frozen, spec revision +1, coverage badges updated; Discard on a second CR restores
the spec exactly.
